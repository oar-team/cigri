#!/usr/bin/perl -I../Iolib -I ../JDLLib -I ../ConfLib

use strict;
BEGIN {
	my $scriptPath = readlink($0);
	if (!defined($scriptPath)){
		$scriptPath = $0;
	}
	# Relative path of the package
	my @relativePathTemp = split(/\//, $scriptPath);
	my $relativePath = "";
	for (my $i = 0; $i < $#relativePathTemp; $i++){
		$relativePath = $relativePath.$relativePathTemp[$i]."/";
	}
	$relativePath = $relativePath."../";
	# configure the path to reach the lib directory
	unshift(@INC, $relativePath."lib");
	unshift(@INC, $relativePath."Iolib");
}
use iolibCigri;
use Data::Dumper;

my $base = iolibCigri::connect();

print "[SCHEDULER] Begining of scheduler FIFO\n";

my %nbFreeNodes = iolibCigri::get_nb_freeNodes($base);
my %nbRemainedJobs = iolibCigri::get_nb_remained_jobs($base);

foreach my $i (keys(%nbRemainedJobs)){
	my @propertiesClusterName = iolibCigri::get_MJobs_Properties($base, $i);
	foreach my $j (@propertiesClusterName){
		my $number = 0 ;
		if ($nbRemainedJobs{$i} <= $nbFreeNodes{$j}){
			$number = $nbRemainedJobs{$i};
		}else{
			$number = $nbFreeNodes{$j};
		}
		if ($number > 0){
			iolibCigri::add_job_to_launch($base,$i,$j,$number);
			print("[Scheduler] add toLaunch job : $i; cluster : $j; number : $number\n");
			$nbFreeNodes{$j} -= $number;
			$nbRemainedJobs{$i} -= $number;
		}
	}
}

iolibCigri::disconnect($base);
