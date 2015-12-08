#include <EXTERN.h>
#include <perl.h>
#include <glib.h>
#include "libvxi11client.h"

#define DEBUG

#ifdef DEBUG
#include <stdio.h>
#endif

// thread safe queue for stacking up interrupts
static GAsyncQueue* interruptqueue;

typedef struct {
	gchar* handle;
} Event;

static Event* lastevent = NULL;

// perl is responsible for freeing the handle
static void freeevent(Event* event) {
	g_free(event);
}

static void freelast() {
	if (lastevent != NULL ) {
		freeevent(lastevent);
		lastevent = NULL;
	}
}

/**
 * This is the callback that is passed to the interrupt
 * thread for it to run each time it gets an interrupt.
 * It creates a new event, puts the handle in place and
 * puts in the in the queue for someone to collect later
 */

static void interruptcallback(gchar* handle) {
	Event* event = g_malloc(sizeof(Event));
	event->handle = handle;
	g_async_queue_push(interruptqueue, event);
}

/**
 * This is just for perl, it creates a new "context" and passes
 * that to the real open function
 */

VXI11Context* glue_open(char* address, char* device) {
	VXI11Context* context = g_malloc(sizeof(VXI11Context));
	if (context == NULL )
		return NULL ;

	int ret = vxi11_open(context, address, device);
	// if the connection fails dump the context and return null
	// so perl can see what happened
	if (ret < 1) {
		g_free(context);
		context = NULL;
	}

	return context;
}

/**
 * Create a queue, start the interrupt server, and give it our callback
 */

int glue_start_interrupt_server() {
	interruptqueue = g_async_queue_new();
	return vxi11_start_interrupt_server(interruptcallback);
}

/**
 * Close down the interrupt server and free everything
 */

int glue_stop_interrupt_server() {
	int ret = vxi11_stop_interrupt_server();
	Event* event = NULL;
	// clear everything that is left over
	while ((event = (Event*) g_async_queue_try_pop(interruptqueue)) != NULL ) {
		freeevent(event);
	}
	freelast();
	g_async_queue_unref(interruptqueue);
	interruptqueue = NULL;
	return ret;
}

/**
 * Block until an interrupt happens. A time out of -1 while block until an
 * interrupt happens or forever(!), 0 will not block and only return a handle
 * if an interrupt already happened, any value > 0 will return instantly if there
 * is a queued interrupt or wait for one to happen up to the timeout.
 */

char* glue_wait_for_interrupt(int timeout) {
	if (interruptqueue == NULL ) {
#ifdef DEBUG
		printf("interrupt queue is null!\n");
#endif
		return NULL ;
	}

	// if timeout > 0 pop with a time out,
	// if the timeout is 0 try to pop but don't block
	// if the timeout is -1 block until an interrupt happens
	freelast();

	if (timeout > 0) {
		GTimeVal whentotimeout;
		g_get_current_time(&whentotimeout);
		g_time_val_add(&whentotimeout, timeout * 1000);
		lastevent = (Event*) g_async_queue_timed_pop(interruptqueue, &whentotimeout);
	}
	else if (timeout == 0) {
		lastevent = (Event*) g_async_queue_try_pop(interruptqueue);
	}
	else if (timeout == -1) {
		lastevent = (Event*) g_async_queue_pop(interruptqueue);
	}

	if (lastevent != NULL ) {
		return lastevent->handle;
	}
	else
		return NULL ;
}
