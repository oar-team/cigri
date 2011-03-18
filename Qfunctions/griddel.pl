#!/usr/bin/perl

# Tool to delete a MJob or a job

use strict;
use IO::Socket::INET;

use Data::Dumper;
use Sys::Hostname;
use Getopt::Std;
BEGIN {
    #update module path for our modules
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
    unshift(@INC, $relativePath."ConfLib");
    unshift(@INC, $relativePath."Iolib");
    unshift(@INC, $relativePath."Colombo");
}
use iolibCigri;
use colomboCigri;
use ConfLibCigri;

sub usage(){
    print(STDERR "usage: griddel.pl [-m -j] id \n");
    print(STDERR "\t -m for a multiplejob id \n");
    print(STDERR "\t -j for a job id \n");
    exit 1;
}

#
# Main
#

# Options on arg command line
my %opts;
Getopt::Std::getopts('m:j:', \%opts);

my $MJobId = undef;
my $jobId = undef;

my $base = iolibCigri::connect();

my $user = getpwuid($<);
my $exit_code = 0;

if (defined($opts{"m"})){
    $MJobId = $opts{"m"};
    my $MJobUser = iolibCigri::get_MJob_user($base,$MJobId);
    my $MJobState = iolibCigri::get_MJob_state($base,$MJobId);
    if ($MJobUser eq $user){
		if($MJobState eq "TERMINATED"){
			print("The MJob $MJobId has already terminated or deleted. Exiting...\n");
			$exit_code = 1;
		}else{
	        colomboCigri::add_new_mjob_event($base,$MJobId,"FRAG","user frag event");
    	    print("Delete the MJob $MJobId\n");
		}
    }else{
        print("/!\\ You are not the right user\n");
        $exit_code = 1;
    }
}elsif(defined($opts{"j"})){
    $jobId = $opts{"j"};
    my $jobUser = iolibCigri::get_job_user($base,$jobId);
    my $jobState = iolibCigri::get_job_state($base,$jobId);
    if ($jobUser eq $user){
		if($jobState eq "Terminated"){	
			print("The job $jobId has already terminated. Exiting...\n");
			$exit_code = 1;
		}elsif ($jobState eq "Event"){
			print("The job $jobId has failed. Exiting...\n");
			$exit_code = 1;
		}else{
	        iolibCigri::set_job_state($base, $jobId, "Event");
    	    colomboCigri::add_new_job_event($base,$jobId,"FRAG","user frag event");
        	print("Delete the job $jobId\n");
		}
    }else{
        print("/!\\ You are not the right user\n");
        $exit_code = 1;
    }
}else{
    usage();
}

iolibCigri::disconnect($base);

exit $exit_code;

