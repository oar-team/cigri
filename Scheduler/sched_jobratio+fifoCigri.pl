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

my %nbRemainedTestJobs = iolibCigri::get_nb_remained_jobs_by_type($base,"test");
my %nbRemainedDefaultJobs = iolibCigri::get_nb_remained_jobs_by_type($base, "default");

# TODO emathias vim replace %s/nbRemoteWaitingJobWeight/nbRemoteWaitingJobNb/g

#enforce priority to test jobs
if (scalar(keys %nbRemainedTestJobs) > 0){
    match_resources_and_schedule($base, \%nbRemainedTestJobs);
} elsif (scalar(keys %nbRemainedDefaultJobs) > 0){
	match_resources_and_schedule($base,\%nbRemainedDefaultJobs);
}


print "[SCHEDULER]   End of scheduler FIFO\n";
iolibCigri::disconnect($base);
exit(0);


sub match_resources_and_schedule ($$) {
my	($base,$nbRemainedJobsRef)	= @_;

my %nbRemainedJobs = %$nbRemainedJobsRef;

foreach my $mjobid (sort {$a <=> $b} keys %nbRemainedJobs){
    if(iolibCigri::get_data_synchronState($base, $mjobid) eq 'ISSUED'){   
        iolibCigri::set_data_synchronState($base, $mjobid, "INITIATED");
	my $user = "cigri";
	my $command ="sudo -u " . $user . " " . $path ."/Hermes/hermesCigri.pl ";
	print"Initiating data synchronization... Executing: $command\n";
	exec"$command";	
    }

   
	foreach my $cluster (iolibCigri::get_MJobs_ActiveClusters($base, $mjobid)){
       if((iolibCigri::get_propertiesData_synchronState($base, $mjobid,
$cluster) eq 'TERMINATED') || (iolibCigri::get_propertiesData_synchronState($base, $mjobid, $cluster) eq '')){
       	  if (colomboCigri::is_cluster_active($base,$cluster,$mjobid) == 0){
			 my $jobratio = iolibCigri::get_last_jobratio ($base, $mjobid, $cluster);
			 my $nb_of_jobs_to_launch = iolibCigri::jobratio_to_absolute($base,
$cluster, $jobratio);
             
			 #TODO emathias: control nb of jobs based on free resources + FLOOD_RATE   
			 print("[SCHEDULER]   add toLaunch MJob : $mjobid; cluster :$cluster; nb jobs: $nb_of_jobs_to_launch\n");
             iolibCigri::add_job_to_launch($base,$mjobid,$cluster,$nb_of_jobs_to_launch);
                #$nbRemainedJobs{$i} -= $number;
          }
       }
    }	                       
}
}
