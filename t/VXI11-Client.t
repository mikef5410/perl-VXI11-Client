# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl VXI11-Client.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 17;
BEGIN { use_ok('VXI11::Client') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

vxi_startinterruptserver();

my $ip_addr = "192.168.0.62";
my $instr = vxi_open(address => $ip_addr);

is($instr->vxi_lock(), 1, "Lock");
ok($instr->vxi_write("*idn?") > 0, "Write");

my ($bytes, $buff, $reason) = $instr->vxi_read();
print "got " . $bytes . ";" . $buff . "\n";
ok($bytes > 0, "Read");

my ($error, $statusbyte) = $instr->vxi_readstatusbyte();
is($error,0, "Read status byte");

is($instr->vxi_create_intr_chan(), 1, "Create intr channel");
is($instr->vxi_enable_srq("myhandle"), 1, "Enable interrupts");
#is(vxi_wait_for_interrupt, "myhandle", "Wait for interrupt");
is($instr->vxi_disable_srq(), 1, "Disable interrupts");
is($instr->vxi_destroy_intr_chan(), 1, "Destroy intr channel");
is($instr->vxi_abort(), 1, "Abort");
is($instr->vxi_clear(), 1, "Clear");
is($instr->vxi_trigger(), -8, "Trigger"); #Not supported by the bb
is($instr->vxi_local(), 1, "Local");
is($instr->vxi_remote(), 1, "Remote");
my ($ret, $dataout, $dataoutlen) = $instr->vxi_docmd("");
ok($ret < 1, "docmd"); #this should fail on the bb server
is($instr->vxi_unlock(), 1, "Unlock");

is($instr->vxi_close(), 1, "Close");

vxi_stopinterruptserver();
