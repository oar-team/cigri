#!/usr/bin/perl -I../Iolib -I ../JDLLib -I ../ConfLib

use strict;
use iolibCigri;
use Data::Dumper;

my $base = iolibCigri::connect();

print "[SCHEDULER] Begining of scheduler FIFO\n";

my %nbFreeNodes = iolibCigri::get_nb_freeNodes($base);
my %nbRemainedJobs = iolibCigri::get_nb_remained_jobs($base);

foreach my $i (keys(%nbRemainedJobs)){
	my @propertiesClusterName = iolibCigri::get_MJobs_Properties($base, $i);
	foreach my $j (@propertiesClusterName){
		my $number ;
		if ($nbRemainedJobs{$i} <= $nbFreeNodes{$j}){
			$number = $nbRemainedJobs{$i};
		}else{
			$number = $nbFreeNodes{$j};
		}
		if ($number > 0){
			iolibCigri::add_job_to_launch($base,$i,$j,$number);
			$nbFreeNodes{$j} -= $number;
			$nbRemainedJobs{$i} -= $number;
		}
	}
}

iolibCigri::disconnect($base);
