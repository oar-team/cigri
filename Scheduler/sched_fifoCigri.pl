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
	unshift(@INC, $relativePath."Colombo");
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
		if (defined($nbFreeNodes{$j})){
		    if ($nbRemainedJobs{$i} <= scalar(@{$nbFreeNodes{$j}})){
			    $number = $nbRemainedJobs{$i};
		    }else{
		    	    $number = scalar(@{$nbFreeNodes{$j}});
		    }
		}
		if ($number > 0){
			my $nodeTmp;
            for (my $k=0; $k < $number; $k++){
                $nodeTmp = pop(@{$nbFreeNodes{$j}});
                print("[Scheduler] add toLaunch MJob : $i; node : $nodeTmp\n");
                iolibCigri::add_job_to_launch($base,$i,$nodeTmp);
            }
			$nbRemainedJobs{$i} -= $number;
		}
	}
}

print "[SCHEDULER] End of scheduler FIFO\n";
iolibCigri::disconnect($base);
exit(0);
