#include <stdbool.h>
#include <rpc/rpc.h>
#include <netinet/in.h>
#include <unistd.h>
#include <glib.h>
#include <poll.h>
#include <errno.h>
#include "libvxi11client.h"
#include "vxi11.h"

// uncomment for debugging output: #define DEBUG

#ifdef DEBUG
#include <stdio.h>
#include <arpa/inet.h>
#endif

/**
 * This is a thin wrapper around the rpcgen generated code to give it a simpler interface.
 */

#define FLAG_TERMCHRSET (1 << 7)
#define FLAG_END (1 << 3)
#define FLAG_WAITLOCK 1

// in milliseconds
#define LOCK_TIMEOUT 1000
#define IO_TIMEOUT 5000
#define POLL_TIMEOUT 1000

static GThread* interruptthread;
static void (*interruptcallback)(char*) = NULL;
static bool interruptserverstarted = false;
static unsigned int interruptserverport = -1;
static GMutex* mutex;
static GCond* cond;

void *
device_intr_srq_1_svc(Device_SrqParms *argp, struct svc_req *rqstp) {
#ifdef DEBUG
	printf("device_intr_srq_1_svc()\n");
#endif

	if (interruptcallback != NULL ) {
		interruptcallback(g_strndup(argp->handle.handle_val, argp->handle.handle_len));
	}

	static char * result;
	return (void *) &result;
}

static void device_intr_1(struct svc_req *rqstp, register SVCXPRT *transp) {
	union {
		Device_SrqParms device_intr_srq_1_arg;
	} argument;
	char *result;
	xdrproc_t _xdr_argument, _xdr_result;
	char *(*local)(char *, struct svc_req *);

	switch (rqstp->rq_proc) {
		case NULLPROC :
			(void) svc_sendreply(transp, (xdrproc_t) xdr_void, (char *) NULL );
			return;

		case device_intr_srq:
			_xdr_argument = (xdrproc_t) xdr_Device_SrqParms;
			_xdr_result = (xdrproc_t) xdr_void;
			local = (char *(*)(char *, struct svc_req *)) device_intr_srq_1_svc;
			break;

		default:
			svcerr_noproc(transp);
			return;
	}
	memset((char *) &argument, 0, sizeof(argument));
	if (!svc_getargs(transp, (xdrproc_t) _xdr_argument, (caddr_t) &argument)) {
		svcerr_decode(transp);
		return;
	}
	result = (*local)((char *) &argument, rqstp);
	if (result != NULL && !svc_sendreply(transp, (xdrproc_t) _xdr_result, result)) {
		svcerr_systemerr(transp);
	}
	if (!svc_freeargs(transp, (xdrproc_t) _xdr_argument, (caddr_t) &argument)) {
		fprintf(stderr, "%s", "unable to free arguments");
		exit(1);
	}
	return;
}

static Device_Flags vxi11_generateflags(bool waitlock, bool end, bool termchrset) {
	Device_Flags flags = 0;
	if (waitlock)
		flags |= FLAG_WAITLOCK;
	if (end)
		flags |= FLAG_END;
	if (termchrset)
		flags |= FLAG_TERMCHRSET;
	return flags;
}

/**
 * create an RPC client and open a link to the server at $address.
 * $device is apparently used for VXI-11 -> GPIB gateways.. this is untested.
 */

int vxi11_open(VXI11Context* context, char* address, char* device) {
	context->clnt = clnt_create(address, DEVICE_CORE, DEVICE_CORE_VERSION, "tcp");

	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	else {
		Create_LinkParms link_parms;
		link_parms.clientId = (long) context->clnt;
		link_parms.lockDevice = 0;
		link_parms.lock_timeout = LOCK_TIMEOUT;
		link_parms.device = device != NULL ? device : "device0";

		Create_LinkResp* linkresp = create_link_1(&link_parms, context->clnt);
		if (linkresp != NULL && linkresp->error == 0) {
			context->devicelink = linkresp->lid;

#ifdef DEBUG
			printf("Link created, lid is %d, abort channel port %d\n", (int) linkresp->lid, linkresp->abortPort);
#endif

			struct sockaddr_in serveraddr;
			if (clnt_control(context->clnt, CLGET_SERVER_ADDR, (char*) &serveraddr)) {
#ifdef DEBUG
				char addressstring[INET_ADDRSTRLEN];
				inet_ntop(AF_INET, &serveraddr.sin_addr, addressstring, sizeof(addressstring));
				printf("Remote is %s\n", addressstring);
#endif
				serveraddr.sin_port = htons(linkresp->abortPort);
				int sock = RPC_ANYSOCK;
				context->abortclnt = clnttcp_create(&serveraddr, DEVICE_ASYNC, DEVICE_ASYNC_VERSION, &sock, 0, 0);
				if (context->abortclnt == NULL )
					return 0;

			}
			else
				// failed!
				return 0;

			context->interruptchannelopen = false;
			context->interruptsenabled = false;

			return 1;
		}
		else if (linkresp == NULL ) {
			errno = ERRNO_NULLRESULT;
			return 0;
		}
		else
			return -(linkresp->error);
	}
}

/**
 * read the status byte of the connected server
 * returns the status byte or'ed with 0x100 on success
 * so that you can tell a zero status byte from an error
 */

int vxi11_readstatusbyte(VXI11Context* context, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	Device_GenericParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.lock_timeout = LOCK_TIMEOUT, .io_timeout = IO_TIMEOUT };
	Device_ReadStbResp* resp = device_readstb_1(&params, context->clnt);

	if (resp != NULL && resp->error == 0)
		return resp->stb | (1 << 8); // this sets a bit above the byte so that we can tell whether there was a state issue
									 // or if the instrument returned 0
	else if (resp == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(resp->error);
}

/**
 * write to the connected device. If len is less than 0 the length will be calculated with strlen
 * **only safe for standard terminated strings**
 */

int vxi11_write(VXI11Context* context, char* data, int len, bool waitlock, bool end) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	Device_WriteParms params = { .lid = context->devicelink, .io_timeout = IO_TIMEOUT, .lock_timeout =
			LOCK_TIMEOUT, .flags = vxi11_generateflags(waitlock, end, false) };
	params.data.data_len = len < 0 ? strlen(data) : len;
	params.data.data_val = data;

	Device_WriteResp* resp = device_write_1(&params, context->clnt);
	if (resp != NULL && resp->error == 0) {
		errno = 0;
		return resp->size;
	}
	else if (resp == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(resp->error);
}

/**
 * read from the connected device
 */

int vxi11_read(VXI11Context* context, char* buffer, unsigned int bufferlen, bool waitlock, bool termchrset,
		char termchr, unsigned int* reason) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	Device_ReadParms params = { .lid = context->devicelink, .requestSize = 256, .io_timeout = IO_TIMEOUT,
			.lock_timeout = LOCK_TIMEOUT, .flags = vxi11_generateflags(waitlock, false, termchrset),
			.termChar = termchrset ? termchr : 0 };

	Device_ReadResp* resp = device_read_1(&params, context->clnt);
	if (resp != NULL && resp->error == 0) {
#ifdef DEBUG
		printf("Got \"%s\" from server\n", resp->data.data_val);
#endif
		errno = 0;
		if (buffer != NULL && resp->data.data_val != NULL ) {
			int lengthtocopy = ((bufferlen - 1) < resp->data.data_len ? (bufferlen - 1) : resp->data.data_len);
			strncpy(buffer, resp->data.data_val, lengthtocopy);
		}
#ifdef DEBUG
		else
			printf("Supplied buffer is null!\n");
#endif
		if (reason != NULL )
			*reason = resp->reason;
		return resp->data.data_len;
	}
	else if (resp == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(resp->error);
}

/**
 * call docmd with the specified command
 * datainlen will be calculated with strlen if less than 0
 */

int vxi11_docmd(VXI11Context* context, char* datain, int datainlen, char* dataout, int outbufferlen, int* dataoutlen,
		unsigned long cmd, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	Device_DocmdParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.io_timeout = IO_TIMEOUT, .lock_timeout = LOCK_TIMEOUT, .cmd = cmd, .network_order = 0,
			.datasize = 0 };

	if (datain == NULL )
		datainlen = 0;
	else if (datainlen < 0)
		datainlen = strlen(datain) + 1;

	params.data_in.data_in_len = datainlen;
	params.data_in.data_in_val = datain;

	Device_DocmdResp* resp = device_docmd_1(&params, context->clnt);
	if (resp != NULL && resp->error == 0) {
		if (dataout != NULL )
			strncpy(dataout, resp->data_out.data_out_val,
					(resp->data_out.data_out_len > outbufferlen ? outbufferlen : resp->data_out.data_out_len));
		*dataoutlen = resp->data_out.data_out_len;
		return 1;
	}
	else if (resp == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(resp->error);
}

/**
 * trigger the connected device
 */

int vxi11_trigger(VXI11Context* context, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	Device_GenericParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.lock_timeout = LOCK_TIMEOUT, .io_timeout = IO_TIMEOUT };
	Device_Error* error = device_trigger_1(&params, context->clnt);

	if (error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * clear the connected device
 */

int vxi11_clear(VXI11Context* context, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	Device_GenericParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.lock_timeout = LOCK_TIMEOUT, .io_timeout = IO_TIMEOUT };
	Device_Error* error = device_clear_1(&params, context->clnt);
	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * remote the connected device
 */

int vxi11_remote(VXI11Context* context, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	Device_GenericParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.lock_timeout = LOCK_TIMEOUT, .io_timeout = IO_TIMEOUT };
	Device_Error* error = device_remote_1(&params, context->clnt);
	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * local the connected device
 */

int vxi11_local(VXI11Context* context, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	Device_GenericParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.lock_timeout = LOCK_TIMEOUT, .io_timeout = IO_TIMEOUT };
	Device_Error* error = device_local_1(&params, context->clnt);
	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * lock the connected device
 */

int vxi11_lock(VXI11Context* context, bool waitforlock) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	Device_LockParms params = { .lid = context->devicelink, .flags = vxi11_generateflags(waitforlock, false, false),
			.lock_timeout = LOCK_TIMEOUT };
	Device_Error* error = device_lock_1(&params, context->clnt);
	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * unlock the connected device
 */

int vxi11_unlock(VXI11Context* context) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	Device_Error* error = device_unlock_1(&(context->devicelink), context->clnt);
	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

static gpointer interruptthreadfunc(gpointer data) {
#ifdef DEBUG
	printf("Interrupt channel thread started\n");
#endif
	SVCXPRT *transp;
	transp = svctcp_create(RPC_ANYSOCK, 0, 0);
	if (transp == NULL ) {
		fprintf(stderr, "%s", "cannot create tcp service.");
		return 0;
	}

	interruptserverport = transp->xp_port;

#ifdef DEBUG
	printf("Interrupt channel on port %d tcp\n", interruptserverport);
#endif

	if (!svc_register(transp, DEVICE_INTR, DEVICE_INTR_VERSION, device_intr_1, 0)) {
		fprintf(stderr, "%s", "unable to register (DEVICE_INTR, DEVICE_INTR_VERSION, tcp).\n");
		return 0;
	}

	g_mutex_lock(mutex);
	g_cond_signal(cond);
	g_mutex_unlock(mutex);

	int i;
	struct pollfd *my_pollfd = NULL;
	int last_max_pollfd = 0;

	while (interruptserverstarted) {
		int max_pollfd = svc_max_pollfd;
		if (max_pollfd == 0 && svc_pollfd == NULL )
			break;

		if (last_max_pollfd != max_pollfd) {
			struct pollfd *new_pollfd = realloc(my_pollfd, sizeof(struct pollfd) * max_pollfd);

			if (new_pollfd == NULL ) {
				break;
			}

			my_pollfd = new_pollfd;
			last_max_pollfd = max_pollfd;
		}

		for (i = 0; i < max_pollfd; ++i) {
			my_pollfd[i].fd = svc_pollfd[i].fd;
			my_pollfd[i].events = svc_pollfd[i].events;
			my_pollfd[i].revents = 0;
		}

		switch (i = poll(my_pollfd, max_pollfd, POLL_TIMEOUT)) {
			case -1:
				break;
			case 0:
				continue;
			default:
				svc_getreq_poll(my_pollfd, i);
				continue;
		}
		break;
	}

	free(my_pollfd);

#ifdef DEBUG
	printf("Interrupt channel thread ended\n");
#endif
	return NULL ;
}

int vxi11_start_interrupt_server(void (*callback)(gchar* handle)) {
	interruptcallback = callback;
	interruptserverstarted = true;
	g_thread_init(NULL );
	mutex = g_mutex_new();
	cond = g_cond_new();
	g_mutex_lock(mutex);
	interruptthread = g_thread_create(interruptthreadfunc, NULL, true, NULL );
	if (interruptthread == NULL )
		return 0;

#ifdef DEBUG
	printf("Waiting for interrupt thread to start\n");
#endif
	g_cond_wait(cond, mutex);
	g_mutex_unlock(mutex);
	g_cond_free(cond);
	g_mutex_free(mutex);
	cond = NULL;
	mutex = NULL;

#ifdef DEBUG
	printf("Interrupt thread started, port is %d\n", interruptserverport);
#endif

	if (interruptserverport == -1)
		return 0;

	return 1;
}

int vxi11_stop_interrupt_server() {
#ifdef DEBUG
	printf("Waiting for interrupt thread to die\n");
#endif
	interruptserverstarted = false;
	g_thread_join(interruptthread);
	interruptthread = NULL;
	return 1;
}

/**
 * create an interrupt channel from the connected device
 */
int vxi11_create_intr_chan(VXI11Context* context) {
	if (context->clnt == NULL || context->interruptchannelopen) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	else if (interruptthread == NULL ) {
#ifdef DEBUG
		printf("interrupt thread isn't running\n");
#endif
		errno = ERRNO_INTERRUPTHANDLERTHREADISDEAD;
		return 0;
	}

	struct sockaddr_in myaddress;
	get_myaddress(&myaddress);

	Device_RemoteFunc remotefunc = { .hostAddr = ntohl(myaddress.sin_addr.s_addr), .hostPort = interruptserverport,
			.progNum = DEVICE_INTR, .progVers = DEVICE_INTR_VERSION, .progFamily = DEVICE_TCP };
	Device_Error* error = create_intr_chan_1(&remotefunc, context->clnt);
	if (error != NULL && error->error == 0) {
		context->interruptchannelopen = true;
		return 1;
	}
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * destroy an interrupt channel from the connected device
 */

int vxi11_destroy_intr_chan(VXI11Context* context) {
	if (context->clnt == NULL || !(context->interruptchannelopen)) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	else if (interruptthread == NULL ) {
		errno = ERRNO_INTERRUPTHANDLERTHREADISDEAD;
		return 0;
	}

	Device_Error* error = destroy_intr_chan_1(NULL, context->clnt);
	if (error != NULL && error->error == 0) {
		context->interruptchannelopen = false;
		return 1;
	}
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * enable interrupts
 */

int vxi11_enable_srq(VXI11Context* context, bool enable, char* handle) {
	if (context->clnt == NULL || !(context->interruptchannelopen)) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	else if (interruptthread == NULL ) {
		errno = ERRNO_INTERRUPTHANDLERTHREADISDEAD;
		return 0;
	}

	Device_EnableSrqParms params = { .lid = context->devicelink, .enable = enable };
	if (enable) {
		if (handle != NULL ) {
			params.handle.handle_val = handle;
			params.handle.handle_len = strlen(handle);
		}
	}
	else {
		params.handle.handle_val = NULL;
		params.handle.handle_len = 0;
	}
	Device_Error* error = device_enable_srq_1(&params, context->clnt);
	if (error != NULL && error->error == 0) {
		return 1;
	}
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * send an abort to the connected device
 */

int vxi11_abort(VXI11Context* context) {
	if (context->abortclnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}
	Device_Error* error = device_abort_1(&(context->devicelink), context->abortclnt);
	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}

/**
 * close the current link and free the RPC client
 */

int vxi11_close(VXI11Context* context) {
	if (context->clnt == NULL ) {
		errno = ERRNO_BADSTATE;
		return 0;
	}

	Device_Error* error = destroy_link_1(&(context->devicelink), context->clnt);
	clnt_destroy(context->clnt);
	context->clnt = NULL;
	clnt_destroy(context->abortclnt);
	context->abortclnt = NULL;

	if (error != NULL && error->error == 0)
		return 1;
	else if (error == NULL ) {
		errno = ERRNO_NULLRESULT;
		return 0;
	}
	else
		return -(error->error);
}
