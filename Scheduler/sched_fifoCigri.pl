#!/usr/bin/perl -I../Iolib -I ../JDLLib -I ../ConfLib

use strict;
use iolib;

my $base = iolib::connect();

my $done =0;
my $doneToLaunch=0;

print "[SCHEDULER] Begining of scheduler FIFO\n";

while (iolib::select_sched_FIFO($base) == 0){
	iolib::pre_schedule($base);
}

iolib::disconnect($base);
