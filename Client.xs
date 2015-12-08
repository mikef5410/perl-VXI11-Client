#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "perlglue.h"

typedef VXI11Context* VXI11__Client;

MODULE = VXI11::Client		PACKAGE = VXI11::Client		

PROTOTYPES: DISABLE

int
vxi_startinterruptserver()
	CODE:
		RETVAL = glue_start_interrupt_server(); 
	OUTPUT:
		RETVAL

int 
vxi_stopinterruptserver()
        CODE:  
                RETVAL = glue_stop_interrupt_server();
        OUTPUT:
                RETVAL

int
vxi_abort(context)
	VXI11::Client context
	CODE:
		RETVAL = vxi11_abort(context);
	OUTPUT:
		RETVAL

int
vxi_clear_long(context,waitforlock)
	VXI11::Client context
	bool	waitforlock
	CODE:
		RETVAL = vxi11_clear(context, waitforlock);
	OUTPUT:
		RETVAL

int
vxi_close(context)
	VXI11::Client context
	CODE:
		RETVAL = vxi11_close(context);
	OUTPUT:
		RETVAL

int
vxi_create_intr_chan(context)
	VXI11::Client context
	CODE:
		RETVAL = vxi11_create_intr_chan(context);
	OUTPUT:
		RETVAL

int
vxi_destroy_intr_chan(context)
	VXI11::Client context
	CODE:
		RETVAL = vxi11_destroy_intr_chan(context);
	OUTPUT:
		RETVAL

int
vxi_docmd_long(context, datain, datainlen, OUTLIST dataout, outbufferlen, OUTLIST dataoutlen, cmd, waitforlock = 0)
	VXI11::Client context
	char* datain
	int datainlen
	char* dataout
	int outbufferlen
	int dataoutlen
	unsigned long	cmd
	bool	waitforlock
	CODE:
		RETVAL = vxi11_docmd(context, datain, datainlen, dataout, outbufferlen, &dataoutlen, cmd, waitforlock);
	OUTPUT:
		RETVAL

int
vxi_enable_srq_long(context, enable, handle)
	VXI11::Client context
	bool	enable
	char*	handle
	CODE:
		RETVAL = vxi11_enable_srq(context,enable,handle);
	OUTPUT:
		RETVAL

char*
vxi_wait_for_interrupt_long(timeout)
        int timeout 
	CODE:
                RETVAL = glue_wait_for_interrupt(timeout);
        OUTPUT:
                RETVAL


int
vxi_local_long(context, waitforlock)
	VXI11::Client context
	bool	waitforlock
	CODE:
		RETVAL = vxi11_local(context, waitforlock);
	OUTPUT:
		RETVAL

int
vxi_lock_long(context, waitforlock)
	VXI11::Client	context
	bool	waitforlock
	CODE:
		RETVAL = vxi11_lock(context, waitforlock);
	OUTPUT:
		RETVAL

VXI11::Client
vxi_open_long(address, device)
	char *	address
	char *	device
	CODE:
		RETVAL = glue_open(address, device);	
	OUTPUT:
		RETVAL

void
vxi_read_long(context, OUTLIST bytesread, OUTLIST buffer, bufferlen, waitlock, termchrset, termchr, OUTLIST reason)
	VXI11::Client context
	char *	buffer
	int 	bytesread
	unsigned int	bufferlen
	bool	waitlock
	bool	termchrset
	char	termchr
	unsigned int	reason
	CODE:
		buffer = calloc(bufferlen + 1, 1);
		bytesread = vxi11_read(context, buffer, bufferlen, waitlock, termchrset, termchr, &reason);
	
void
vxi_readstatusbyte_long(context, OUTLIST error, OUTLIST statusbyte, waitforlock)
	VXI11::Client context
	int error
	int statusbyte 
	bool	waitforlock
	CODE:
		error = 0;
		statusbyte = 0;
		int ret = vxi11_readstatusbyte(context, waitforlock);
		if(ret > 0)
			statusbyte = ret & 0xff;
		else 
			error = ret;

int
vxi_remote_long(context, waitforlock)
	VXI11::Client context
	bool	waitforlock
	CODE:
		RETVAL = vxi11_remote(context, waitforlock);
	OUTPUT:
		RETVAL

int
vxi_trigger_long(context, waitforlock)
	VXI11::Client context
	bool	waitforlock
	CODE:
		RETVAL = vxi11_trigger(context, waitforlock);
	OUTPUT:
		RETVAL

int
vxi_unlock(context)
	VXI11::Client context
	CODE:
		RETVAL = vxi11_unlock(context);
	OUTPUT:
		RETVAL

int
vxi_write_long(context,data, len, waitlock, end)
	VXI11::Client context
	char *	data
	int	len
	bool	waitlock
	bool	end
	CODE:
		RETVAL = vxi11_write(context, data, len, waitlock, end);
	OUTPUT:
		RETVAL
