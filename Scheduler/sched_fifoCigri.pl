#!/usr/bin/perl -I../Iolib -I ../JDLLib -I ../ConfLib

use strict;
use iolibCigri;

my $base = iolibCigri::connect();

my $done =0;
my $doneToLaunch=0;

print "[SCHEDULER] Begining of scheduler FIFO\n";

while (iolibCigri::select_sched_FIFO($base) == 0){
	iolibCigri::pre_schedule($base);
}

iolibCigri::disconnect($base);
