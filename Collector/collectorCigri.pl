#!/usr/bin/perl

use strict;
BEGIN {
	my ($scriptPathTmp) = $0 =~ m!(.*/*)!s;
	my ($scriptPath) = readlink($scriptPathTmp);
	if (!defined($scriptPath)){
		$scriptPath = $scriptPathTmp;
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


#tar rf cigTest.tar -C /users/huron/capitn cigri.11322.log
#md5sum
#scp -qC
