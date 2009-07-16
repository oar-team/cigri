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
    unshift(@INC, $relativePath."ConfLib");
}
use iolibCigri;
use Data::Dumper;
use colomboCigri;
use integer;
use ConfLibCigri qw(init_conf get_conf is_conf);

# Init the request to the cigri.conf file
init_conf();

my $path;
if (is_conf("INSTALL_PATH")){
    $path = get_conf("INSTALL_PATH");
}else{
    die("You must have a cigri.conf (in /etc or in \$CIGRIDIR) script with a valid INSTALL_PATH tag\n");
}

my $base = iolibCigri::connect();

print "[SCHEDULER]   Begining of scheduler FIFO\n";

my %nbFreeNodes = iolibCigri::get_nb_freeNodes($base);
my %nbRemainedJobs = iolibCigri::get_nb_remained_jobs($base);
my %nbRemoteWaitingJobWeight = iolibCigri::get_cluster_remoteWaiting_job_weight($base);
#print(Dumper(%nbFreeNodes));

foreach my $i (sort(keys(%nbRemainedJobs))){
    if(iolibCigri::get_data_synchronState($base, $i) eq 'ISSUED'){   
        iolibCigri::set_data_synchronState($base, $i, "INITIATED");
	my $user = "cigri";
	my $command ="sudo -u " . $user . " " . $path ."/Hermes/hermesCigri.pl ";
	print"Initiating data synchronization... Executing: $command\n";
	exec"$command";	
    }
    my %propertiesClusterName = iolibCigri::get_MJobs_Properties($base, $i);
    foreach my $j (iolibCigri::get_MJobs_ActiveClusters($base, $i)){
      if((iolibCigri::get_propertiesData_synchronState($base, $i, $j) eq 'TERMINATED') || (iolibCigri::get_propertiesData_synchronState($base, $i, $j) eq '')){
        if (colomboCigri::is_cluster_active($base,$j,$i) == 0){
            my $number = 0 ;
            my $k = 0;
            while (($k <= $#{$nbFreeNodes{$j}}) && ($number < $nbRemainedJobs{$i})){
                #print(Dumper(@{$nbFreeNodes{$j}})."\n---------------------------------------------------\n");
                #check if there are remote waiting jobs
                #print("$i: nbRemoteWaitingJobWeight = $nbRemoteWaitingJobWeight{$j} --> ${${$nbFreeNodes{$j}}[$k]}[1] \n");
                if ((defined($nbRemoteWaitingJobWeight{$j})) && ($nbRemoteWaitingJobWeight{$j} > 0)){
                    if (${${$nbFreeNodes{$j}}[$k]}[1] <= $nbRemoteWaitingJobWeight{$j}){
                        $nbRemoteWaitingJobWeight{$j} = $nbRemoteWaitingJobWeight{$j} - ${${$nbFreeNodes{$j}}[$k]}[1];
                        ${${$nbFreeNodes{$j}}[$k]}[1] = 0;
                    }else{
                        ${${$nbFreeNodes{$j}}[$k]}[1] = ${${$nbFreeNodes{$j}}[$k]}[1] - $nbRemoteWaitingJobWeight{$j};
                        $nbRemoteWaitingJobWeight{$j} = 0;
                    }
                }
                
                if (${${$nbFreeNodes{$j}}[$k]}[1] >= $propertiesClusterName{$j}){
                    $number += ${${$nbFreeNodes{$j}}[$k]}[1] / $propertiesClusterName{$j};
                    if ($number > $nbRemainedJobs{$i}){
                        ${${$nbFreeNodes{$j}}[$k]}[1] = ${${$nbFreeNodes{$j}}[$k]}[1] % $propertiesClusterName{$j} + ($number - $nbRemainedJobs{$i}) * $propertiesClusterName{$j};
                        $number = $nbRemainedJobs{$i};
                    }else{
                        ${${$nbFreeNodes{$j}}[$k]}[1] = ${${$nbFreeNodes{$j}}[$k]}[1] % $propertiesClusterName{$j};
                    }
                }
                $k++;
            }
            if ($number > 0){
                my $flood_value = 0;
                if (ConfLibCigri::is_conf("flood_parameter")){
                    $flood_value = ConfLibCigri::get_conf("flood_parameter");
                }
                my $max_jobs = 300;
                if (ConfLibCigri::is_conf("max_jobs")){
                    $max_jobs = ConfLibCigri::get_conf("max_jobs");
                }
                my $nb_jobs_to_launch = $number + ($number * $flood_value / 100);
                if ($nb_jobs_to_launch > $max_jobs ) { $nb_jobs_to_launch = $max_jobs; }
                print("[Scheduler] add toLaunch MJob : $i; cluster : $j; nb jobs : $nb_jobs_to_launch\n");
                
                iolibCigri::add_job_to_launch($base,$i,$j,$nb_jobs_to_launch);
                $nbRemainedJobs{$i} -= $nb_jobs_to_launch;
               # print("[SCHEDULER]   add toLaunch MJob : $i; cluster : $j; nb jobs : $number\n");
                #iolibCigri::add_job_to_launch($base,$i,$j,$number);
                #$nbRemainedJobs{$i} -= $number;
            }
        }
      }	                       
    }
}

print "[SCHEDULER]   End of scheduler FIFO\n";
iolibCigri::disconnect($base);
exit(0);
