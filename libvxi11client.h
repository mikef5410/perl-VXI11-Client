#include <stdbool.h>
#include "vxi11.h"

#define ERRNO_BADSTATE 1
#define ERRNO_INTERRUPTHANDLERTHREADISDEAD 2
#define ERRNO_NULLRESULT 3

#define ERR_SYNTAXERROR -1
#define ERR_DEVICENOTACCESSIBLE -3
#define ERR_INVALIDLINKINDENTIFIER -4
#define ERR_PARAMETERERROR -5
#define ERR_CHANNELNOTESTABLISHED -6
#define ERR_OPERATIONNOTSUPPORTED -8
#define ERR_OUTOFRESOURCES -9
#define ERR_DEVICELOCKEDBYANOTHERLINK -11
#define ERR_NOLOCKHELDBYTHISLINK -12
#define ERR_IOTIMEOUT -15
#define ERR_IOERROR -17
#define ERR_INVALIDADDRESS -21
#define ERR_ABORT -23
#define ERR_CHANNELALREADYESTABLISHED -29

typedef struct {
	CLIENT* clnt;
	CLIENT* abortclnt;
	Device_Link devicelink;
	bool interruptchannelopen;
	bool interruptsenabled;
} VXI11Context;

int vxi11_open(VXI11Context* context, char* address, char* device);
int vxi11_abort(VXI11Context* context);
int vxi11_trigger(VXI11Context* context, bool waitforlock);
int vxi11_clear(VXI11Context* context, bool waitforlock);
int vxi11_write(VXI11Context* context, char* data, int len, bool waitlock, bool end);
int vxi11_read(VXI11Context* context, char* buffer, unsigned int bufferlen, bool waitlock, bool termchrset,
		char termchr, unsigned int* reason);
int vxi11_lock(VXI11Context* context, bool waitforlock);
int vxi11_unlock(VXI11Context* context);
int vxi11_local(VXI11Context* context, bool waitforlock);
int vxi11_remote(VXI11Context* context, bool waitforlock);
int vxi11_readstatusbyte(VXI11Context* context, bool waitforlock);
int vxi11_create_intr_chan(VXI11Context* context);
int vxi11_destroy_intr_chan(VXI11Context* context);
int vxi11_enable_srq(VXI11Context* context, bool enable, char* handle);
int vxi11_start_interrupt_server(void (*callback)(char* handle));
int vxi11_stop_interrupt_server();
int vxi11_docmd(VXI11Context* context, char* datain, int datainlen, char* dataout, int outbufferlen, int* dataoutlen,
		unsigned long cmd, bool waitforlock);
int vxi11_close(VXI11Context* context);
