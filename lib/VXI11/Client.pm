package VXI11::Client;

use 5.014002;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use VXI11::Client ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	vxi_startinterruptserver
	vxi_stopinterruptserver
 	vxi_open
	vxi_wait_for_interrupt	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('VXI11::Client', $VERSION);

sub vxi_enable_srq {
	return vxi_enable_srq_long($_[0], 1, $_[1]);
}


sub vxi_disable_srq {
	return vxi_enable_srq_long($_[0], 0 , "");
}


sub vxi_wait_for_interrupt {
	my %args = (
                timeout_ms => 250,
                @_
        );

	return vxi_wait_for_interrupt_long ($args{timeout_ms});
}


sub vxi_clear {
        my $self = shift;
	my %args = (
                waitforlock => 0,
                @_
        );
	return vxi_clear_long ($self, $args{waitforlock});
}


sub vxi_local {
        my $self = shift;
        my %args = (
                waitforlock => 0,
                @_
        );
        return vxi_local_long ($self, $args{waitforlock});
}


sub vxi_remote {
        my $self = shift;
        my %args = (
                waitforlock => 0,
                @_
        );
        return vxi_remote_long ($self, $args{waitforlock});
}


sub vxi_trigger {
        my $self = shift;
        my %args = (
                waitforlock => 0,
                @_
        );
        return vxi_trigger_long ($self, $args{waitforlock});
}


sub vxi_lock {
        my $self = shift;
        my %args = (
                waitforlock => 0,
                @_
        );
        return vxi_lock_long ($self, $args{waitforlock});
}


sub vxi_open {
        my %args = (
		address => '127.0.0.1',
		device => 0,
		@_
        );
        return vxi_open_long ($args{address}, $args{device});
}


sub vxi_write {
	my $self = shift;
	my $data = shift;
	my %args = (
		len => -1,
		waitforlock => 0,
		end => 1,
		@_
	);
	return vxi_write_long($self, $data, $args{len}, $args{waitforlock}, $args{end});
}


sub vxi_read {
	my $self = shift;
	my %args = (
                bufferlen => 1024,
                waitforlock => 0,
                termchrset => 0,
		termchr => 0,
		autochomp => 1,
                @_
        );

	my ($bytes, $string, $reason) = vxi_read_long($self, $args{bufferlen}, $args{waitforlock}, $args{termchrset},$args{termchr});

	if (defined($string) && $args{autochomp}) {
		chomp ($string);
	}
	
	return ($bytes, $string, $reason);
}


sub vxi_readstatusbyte {
        my $self = shift;
        my %args = (
                waitforlock => 0,
                @_
        );
        return vxi_readstatusbyte_long ($self, $args{waitforlock});
}


sub vxi_docmd {
        my $self = shift;
        my $cmd = shift;
	my %args = (
                datain => "",
		datainlen => -1,
		dataoutbufferlen => 256,
                waitforlock => 0,
		autochomp => 1,
                @_
        );

        my ($ret, $dataout, $dataoutlen) = vxi_docmd_long($self, $args{datain}, $args{datainlen}, $args{dataoutbufferlen}, $args{waitforlock});

        if (defined($dataout) && $args{autochomp}) {
                chomp ($dataout);
        }

        return ($ret, $dataout);
}

1;
__END__

=head1 NAME

VXI11::Client - Implements a Linux VXI-11 client for controlling test and measurement equipment

=head1 DOWNLOAD

=begin html

Latest release: <a href="http://www.avtechpulse.com/options/vxi/client/VXI11-Client-1_0_1.zip">VXI11-Client-1_0_1.zip</a>.

=end html

Once unzipped, use the standard perl module install sequence:

  perl Makefile.PL
  make
  sudo make install

=head1 SYNOPSIS

  use VXI11::Client;

  vxi_startinterruptserver();

  my $instr = vxi_open(address => "192.168.0.62") or die;

  $instr->vxi_lock();
  $instr->vxi_write("*idn?");
  my ($bytes, $buff, $reason) = $instr->vxi_read();
  print "got " . $bytes . ";" . $buff . " reason " . $reason ."\n";

  my ($error, $statusbyte) = $instr->vxi_readstatusbyte();
  print "status byte is " . $statusbyte . "\n";

  $instr->vxi_create_intr_chan();
  $instr->vxi_enable_srq("myhandle");
  vxi_wait_for_interrupt();
  $instr->vxi_disable_srq();
  $instr->vxi_destroy_intr_chan();
  $instr->vxi_abort();
  $instr->vxi_clear();
  $instr->vxi_trigger();
  $instr->vxi_local();
  $instr->vxi_remote();
  $instr->vxi_unlock();

  $instr->vxi_close();

  vxi_stopinterruptserver();


=head1 DESCRIPTION

=begin html

VXI11::Client implements a Linux client for VXI-11 networked instruments.
This module was developed to support 
<a href="http://www.avtechpulse.com/">Avtech Electrosystems</a>
pulse generators with the
<a href="http://www.avtechpulse.com/options/vxi/">-VXI option</a>,
as well as VXI-11.3 instrumentation from other manufacturers (oscilloscopes, etc).

=end html

Tested on Linux (Fedora 17 x86_64, primarily). It has not been tested on other
operating systems at this time. This module relies on the glib and gthread
libraries.

=head2 BASIC I/O

A VXI11 connection to an instrument involves establishing a link with up to three 
"channels" - core (for normal reads and writes), abort (for cancelling commands), 
and interrupt (for receiving instrument-initiated messages and errors).

Most communication happens using the core channel. To send a query to an instrument,
you need to open the instrument and then call the vxi_write and vxi_read methods
on the returned instrument object:

  $instr = vxi_open( address => "192.168.0.62" ) or die;
  $instr->vxi_write("*idn?");
  ( $bytes, $idn, $reason ) = $instr->vxi_read();
  print "This instrument is: $idn\n";
  $instr->vxi_close();

=head2 ABORT CHANNEL

The abort channel is occasionally used, depending on the capabilities of the
instrument. To signal an abort, simply call:

  $instr->vxi_abort();

The abort channel is automatically created with the core channel during a
vxi_open.

=head2 INTERRUPT CHANNEL

The interrupt channel can be used to watch for error conditions and to
signal service requests. Alternatively, you can manually check for errors
and service requests by polling the error queue or the status byte. If you wish
to use the interrupt channel, your computer must be running an RPC port mapper
service. (On Fedora Linux, this is provided by rpcbind.) Then, you must start
the global (rather than per-object) interrupt listener provided by this module:

  vxi_startinterruptserver();

This listener can serve multiple instrument objects. If you wish to use an
instrument's interrupt channel, you must start it after launching the
listener:

  $instr->vxi_create_intr_chan();

In contrast to the core and abort channels, the interrupt channel is not
automatically created by vxi_open.

To receive service requests on this channel, do:

  $instr->vxi_enable_srq("myhandle");

The "myhandle" identifier must be unique for each object, so that the global
listener can deliver interrupts to the right object. 

At this point, you may need to send additional commands (based on the
IEEE-488.2 standard, usually) using vxi_write to enable service request
generation within your instrument. These are typical:

  $instr->vxi_write("*ese 60");     # Flag command-related errors.
  $instr->vxi_write("*sre 48");     # Request service when they occur.

When you are expecting the possibility of an interrupt, you watch for the
interrupt using:

  $handle = vxi_wait_for_interrupt()

If the returned handle is the same as the identifier set above, then an
interrupt been signalled in your instrument. The wait period is 250 ms
by default, but it may be set to a different value.

The interrupts can be shut down using:

  $instr->vxi_disable_srq();		# local to your instrument
  $instr->vxi_destroy_intr_chan();	# local to your instrument
  vxi_stopinterruptserver();		# affects all instruments

Use of the interrupt channel is optional. Simpler applications can 
omit it, and rely on explicit status checks of the instrument. To
check the status byte (STB), you can use:

  my ($error, $statusbyte) = $instr->vxi_readstatusbyte();

To check the error queue, you can use poll it using something like this:

  my $resp = "";
  until ($resp =~ /No error/) {
	  $instr->vxi_write("syst:err?");
	  (my $bytes, $resp, my $reason) = $instr->vxi_read();
	  if ($resp !~ /No error/) {
  		  print "ERR: $resp\n";
  	  }
  }

=head2 LOCKS

VXI instruments will support more than one VXI link, normally. However,
links can be locked to prevent other links from controlling the
instrument, using:

  $instr->vxi_lock();		# My link shall rule all!
  $instr->vxi_unlock();		# Someone else's turn.

Some functions have an waitforlock optional parameter. If not zero,
this requests that the instrument execute the function later if a lock
is conflicting with execution. The exact nature of this scheme will
be device-dependent.

=head1 USAGE

=over

=item $retcode = vxi_startinterruptserver();

Start the local RPC service for the instrument to connect to and deliver
interrupt/service requests to.
Make sure you have portmapper or rpcbind running and you aren't blocking
the ports it allocates.

=item $retcode = vxi_stopinterruptserver();

Shutdown the local RPC server.

=item $instr = vxi_open( address => STRING, [device => STRING] );

Open a link to an instrument. Use the returned instance to call 
the object methods below.

"address" is the IP address or hostname of your instrument. If
you are using a VXI-to-GPIB gateway, it is the IP address of the
gateway.

"device" is an additional parameter used only when connecting
thorugh a VXI-to-GPIB gateway, such as the ICS 8065. If used,
it will have the form of "gpib0,2", where "gpib0" refers to the
gateway, and ",2" refers to the instrument on the GPIB bus at
GPIB address 2.

=item $retcode = $instr->vxi_close();	

Destroy the link to the instrument and destroy the local RPC client.
You must not use an instance created with vxi_open after calling this.

=item $retcode = $instr->vxi_lock([waitforlock => 'false']);

Lock the instrument. You can tell the instrument to try to wait for 
the lock to become free and lock it via waitforlock,

=item $retcode = $instr->vxi_unlock();

Unlock the instrument. Only makes sense if you are holding the lock.

=item $retcode = $instr->vxi_write(data, [ len => -1, waitforlock => 0, end => 1 ]);

Write data to the instrument. If the data is a terminated string you can 
pass -1 as the length to have it calculated for you. If the data is not 
terminated or for some reason you only want to write part of it you need
to provide a length. You can wait for the lock to be freed by via waitforlock.  

=item ($bytes, $data, $reason) = $instr->vxi_read([ bufferlen => 1024, waitforlock => 0, termchrset => 0, termchr => 0, autochomp => 1]);

Read some data from the instrument. The default parameters should be fine
for most cases. If you need to read more than 1024 bytes you should pass 
the required buffer size via bufferlen. This function will not read more 
than the buffer size. The number of bytes returned is what the instrument sent,
not what was copied into the buffer. If the number of bytes returned is
larger than bufferlen the data is truncated. If autochomp is set the newline
from the returned data will be automatically removed.

=item ($retcode, $dataout, $dataoutlen) =  vxi_docmd (INT cmd, [ datain => "", datainlen => -1, dataoutbufferlen => 256, waitforlock => 0, autochomp => 1]);

Send a command to the instrument possibly with some data. The rules for write
apply to datain and the rules for read apply for dataout. 

The docmd message is not implemented in VXI-11.3 instruments - it always
an error. You probably need vxi_write instead.

=item $retcode = $instr->vxi_abort();	

Tell the instrument to abort an in-progress operation, if possible.

=item $retcode = $instr->vxi_readstatusbyte([ waitforlock => 0 ]);

Read the instrument's status byte.

=item $retcode = $instr->vxi_create_intr_chan();   

Creates an interrupt channel from the instrument to this client.
This must be called after vxi_startinterruptserver.

=item $retcode = $instr->vxi_enable_srq(STRING handle);

Tell the instrument to fire interrupts/service requests to the 
interrupt channel. Must be called after vxi_create_intr_chan().
You should give a unique channel handle for each instrument as
you will need this to determine which device sent an interrupt / 
service request. 

=item $retcode = $instr->vxi_disable_srq();

Tell the instrument that you don't want it to send interrupts /
service requests anymore. This does not destroy the interrupt 
channel.

=item $retcode = $instr->vxi_destroy_intr_chan();

Tell the instrument to disconnect from the interrupt service that
is running locally. This does not shut down the interrupt service.

=item $handle = vxi_wait_for_interrupt([INT timeout => -1 | 0 | n]);

Waits for an interrupt/service request to be received from a connected 
instrument. When an interrupt is caught the handle of the interrupt will
be returned. If no interrupt is caught undef will be returned.
You can pass a timeout in ms (the default is 250ms), or 0 to never block
and only return interrupts that have already happened or -1 to block until
an interrupt is caught (could block forever!).

=item $retcode = $instr->vxi_remote([waitforlock => 0]);      

Lock out the instrument's local controls (typically the front panel).
(This is not the same as a link lock implemented by vxi_lock.)

=item $retcode = $instr->vxi_local([waitforlock => 0]);

Unlock the instrument's local controls.

=item $retcode = $instr->vxi_clear([waitforlock => 0]);

Clear the instrument's messaging interface.

=item $retcode = $instr->vxi_trigger([waitforlock => 0]);

Trigger the instrument, if the instrument supports this capability.

=item Integer return codes

Return codes work like this:


1 - is a success

0 - means the request failed locally, the state inside the client is
incorrect, i.e. calling to enable interrupts before creating the channel
or that the server couldn't be contacted

< 0 - Any negative value is the negated VXI-11 error code from the server

The only exceptions to this are the read and write methods:

0 - Error as above or zero bytes read/written

> 0 - Number of bytes read/written

=back

=head1 SAMPLE SCRIPTS

These samples assume that the connected instrument follows the IEEE-488.2
and SCPI standards. Beware that some instruments do not follow these
standards!

=head2 MINIMAL IDENTIFICATION SCRIPT

  #!/usr/bin/perl
  use VXI11::Client;

  $instr = vxi_open( address => "192.168.0.62" ) or die;
  $instr->vxi_write("*idn?");
  ( $bytes, $idn, $reason ) = $instr->vxi_read();
  print "This instrument is: $idn\n";
  $instr->vxi_close();

=head2 SIMPLE INTERACTIVE CLIENT

  #!/usr/bin/perl
  use strict;
  use warnings;
  use VXI11::Client;

  # This script provides a simple line-based shell for communicating with
  # a VXI-11.3 instrument. Errors and responses to queries are signaled to
  # this script by polling the instrument status byte. Tested with an
  # Avtech Electrosystems pulse generator.

  my $ip_addr = "192.168.0.62";    # IP address of the instrument,
                                   # or VXI-to-GPIB gateway device.
  my $device  = 0;                 # Only revelant if a VXI-to-GPIB
                                   # gateway is used.

  $SIG{INT} = 'graceful_end';      # end on Ctrl+C

  print "\nTrying to establish link with $ip_addr...";

  my $instr = vxi_open( address => $ip_addr, device => $device )
    or die "Could not open instrument at $ip_addr.";

  my $prompt = "\n> ";
  print " OK\nType your commands. Ctrl+C to exit\n" . $prompt;

  $instr->vxi_write("*ese 60");    # Flag command-related errors.
  $instr->vxi_write("*sre 48");    # Request service when a response is
                                   # available, or an error has occurred.

  while (1) {

      # check for user input
      if ( defined( my $line = <STDIN> ) ) {
          $instr->vxi_write($line);
      }

      my ( $error, $statusbyte ) = $instr->vxi_readstatusbyte();

      # query-response message available according to status byte
      if ( $statusbyte | 0x10 ) {
          my ( $bytes, $response, $reason ) = $instr->vxi_read();
          print $response. "\n";
      }

      # error occurred according to status byte
      if ( $statusbyte | 0x20 ) {
          my $response = "";

          # cycle through all errors in the error queue
          until ( $response =~ /No error/i ) {
              $instr->vxi_write("syst:err?");
              ( my $bytes, $response, my $reason ) = $instr->vxi_read();
              if ( $response !~ /No error/i ) {
                  print "Error message: $response\n";
              }
          }

          # clear the error reporting bits
          $instr->vxi_write("*cls");
      }
      print $prompt;
  }

  sub graceful_end {
      print "\nExiting\n";
      $instr->vxi_close();
      die;
  }

=head2 INTERACTIVE CLIENT USING INTERRUPT CHANNEL

  #!/usr/bin/perl
  use strict;
  use warnings;
  use VXI11::Client;

  # This script provides a simple line-based shell for communicating with
  # a VXI-11.3 instrument. Errors and responses to queries are signaled to
  # this script using the interrupt channel. The rpcbind/portmapper service
  # must be running on your system for this to work. If not, see the
  # sample script that does not use the interrupt channel. Tested with an
  # Avtech Electrosystems pulse generator.

  my $ip_addr = "192.168.0.62";    # IP address of the instrument,
                                   # or VXI-to-GPIB gateway device.
  my $device  = 0;                 # Only revelant if a VXI-to-GPIB
                                   # gateway is used.

  $SIG{INT} = 'graceful_end';      # end on Ctrl+C

  vxi_startinterruptserver();      # Launch a server to handle
                                   # interrupts from the instrument.
  my $my_interrupt_handle = "Avtech";    # Each interrupt source needs a name.

  print "\nTrying to establish link with $ip_addr...";

  my $instr = vxi_open( address => $ip_addr, device => $device ) or die "Could not open instrument at $ip_addr.";

  # keep other users away
  $instr->vxi_remote();	           # no other VXI users
  $instr->vxi_lock();              # no front-panel users

  my $prompt = "\n> ";
  print " OK\nType your commands. Ctrl+C to exit\n" . $prompt;

  $instr->vxi_write("*ese 60");          # Flag command-related errors.
  $instr->vxi_write("*sre 48");          # Request service when a response is
                                         # available, or an error has occurred.
  $instr->vxi_create_intr_chan();        # Create interrupt channel.
  $instr->vxi_enable_srq($my_interrupt_handle);
                                         # Enable service requests on the
                                         # interrupt channel
  while (1) {

      # check for user input
      if ( defined( my $line = <STDIN> ) ) {
          $instr->vxi_write($line);
      }

      # was a message response or error reported within
      # the default timeout period of 250 ms?
      my $handle;
      if (   ( $handle = vxi_wait_for_interrupt() )
          && ( $handle eq $my_interrupt_handle ) )
      {
          my ( $error, $statusbyte ) = $instr->vxi_readstatusbyte();

          # query-response message available according to status byte
          if ( $statusbyte | 0x10 ) {
              my ( $bytes, $response, $reason ) = $instr->vxi_read();
              print $response. "\n";
          }

          # error occurred according to status byte
          if ( $statusbyte | 0x20 ) {
              my $response = "";

              # cycle through all errors in the error queue
              until ( $response =~ /No error/i ) {
                  $instr->vxi_write("syst:err?");
                  ( my $bytes, $response, my $reason ) = $instr->vxi_read();
                  if ( $response !~ /No error/i ) {
                      print "Error message: $response\n";
                  }
              }

              # clear the error reporting bits
              $instr->vxi_write("*cls");
          }
      }
      print $prompt;
  }

  sub graceful_end {
      print "\nExiting\n";
      $instr->vxi_disable_srq();
      $instr->vxi_destroy_intr_chan();
      $instr->vxi_unlock();
      $instr->vxi_local();
      $instr->vxi_close();
      vxi_stopinterruptserver();
      die;
  }

=head1 SEE ALSO

The VXI-11.3 specifications.

=head1 AUTHORS

=over

=item Daniel Palmer, daniel@0x0f.com

=item Dr. Michael J. Chudobiak, mjc@avtechpulse.com

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Avtech Electrosystems Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
