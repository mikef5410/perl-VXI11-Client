#include <EXTERN.h>
#include <perl.h>
#include "libvxi11client.h"

char* glue_wait_for_interrupt(int timeout);
VXI11Context* glue_open(char* address, char* device);
int glue_start_interrupt_server();
int glue_stop_interrupt_server();
