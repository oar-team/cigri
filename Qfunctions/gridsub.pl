#!/usr/bin/perl

# Tool to query the grid for a submission

use strict;
use IO::Socket::INET;

use Data::Dumper;
use Sys::Hostname;
use Getopt::Long;
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
use ConfLibCigri;
use mailer;

sub usage(){
    print(STDERR "usage: gridSub [-f JDLscript | -r [-j|-m] id]  [-t campaign_type] [-s id] [-c id] \n");
	print(STDERR "\t -f for submitting a new mjob \n");
	print(STDERR "\t -r for resubmitting a job/mjob \n");
	print(STDERR "\t\t -j for resubmit a job \n");
	print(STDERR "\t\t -m for resubmit an mjob \n");
	print(STDERR "\t\t -s for suspending an mjob \n");
	print(STDERR "\t\t -c for continuing a suspended mjob \n");
    exit 1;
}

#
# Main
#

# Options on arg command line
#


my $Error_Prefix = "[ERROR]";

Getopt::Long::Configure ("gnu_getopt");
my $mJobType;
my $sos;
my $JDLfile;
my $resubmit;
my $suspend;
my $continue;
my $jobId;
my $MJobId;

GetOptions ("jdl|f=s" =>  \$JDLfile,
			"type|t=s" => \$mJobType,
			"resubmit|r" => \$resubmit,
			"suspend|s=i" => \$suspend,
			"continue|c=i" => \$continue,
			"job|j=i" => \$jobId,
			"mjob|m=i" => \$MJobId,
			"help|h" => \$sos
			);


if (defined($sos)){
    usage();
    exit(0);
}



if (defined($JDLfile) && 
(defined($resubmit) || defined($suspend) || defined($continue)) 
||
!defined($JDLfile) &&  
(!defined($resubmit) && !defined($suspend) && !defined($continue)) 
){
    print("$Error_Prefix You must EITHER submit a new job, resubmit/suspend/continue an existing\n");
    usage();
    exit(1);
}

if (defined($resubmit) && 
	((!defined($jobId) && !defined($MJobId)) || 
	(defined($jobId) && defined($MJobId)) )){
    print("$Error_Prefix You must define either a job or an mjob to resubmit\n");
    usage();
    exit(1);
}


my $base = iolibCigri::connect();
my $user = getpwuid($<);


if (defined($suspend)) {
	my $mjob_state = iolibCigri::get_MJob_state($base,$suspend);
	my $mjob_user = iolibCigri::get_MJob_user($base,$suspend);

	if (defined ($mjob_state)){
		if ($mjob_user ne $user){
			print("$Error_Prefix $suspend could not be suspended. You are not the right user\n");
	        exit(1);
		}

		if($mjob_state eq 'IN_TREATMENT'){
			iolibCigri::set_mjobs_state($base, $suspend, "PAUSED");
			print("The campaign $suspend was suspended\n");
			exit(0)
		}else{
			print("$Error_Prefix $suspend could not be suspended. Jobs must be \"IN_TREATMENT\" to be suspended and current state is $mjob_state\n");
			usage();
	        exit(1);
		}
	}else{
    	print("$Error_Prefix $suspend is not a valid campaign number\n");
		usage();
        exit(1);
	}

}

if (defined($continue)) {
	my $mjob_state = iolibCigri::get_MJob_state($base,$continue);
    my $mjob_user = iolibCigri::get_MJob_user($base,$continue);

    if (defined ($mjob_state)){ 
	    if ($mjob_user ne $user){            
			print("$Error_Prefix $continue could not be continued. You are not the right user\n");
            exit(1);
    	}

        if($mjob_state eq 'PAUSED'){
            iolibCigri::set_mjobs_state($base, $continue, "IN_TREATMENT");
            print("The campaign $continue was resumed\n");
            exit(0)
        }else{
            print("$Error_Prefix $continue could not be resumed. Jobs must be \"PAUSED\" to be resumed and current state is $mjob_state\n");
            usage();
            exit(1);
        }
    }else{
        print("$Error_Prefix $continue is not a valid campaign number\n");
        usage();
        exit(1);
    }	

}




if (defined($JDLfile)) {
	if ( (-e $JDLfile) && (-r $JDLfile) ){
		print("JDL file = $JDLfile\n");
	}else{	
		print("$Error_Prefix $JDLfile: non-existant or unreadable JDL file \n");
		usage();
    	exit(1);
	}

	my $idJob= iolibCigri::add_mjobs($base, $JDLfile, $mJobType);
	print "IdJob = $idJob \n";

	# -1 = bad JDL file or bad param file
	# -2 = no cluster defined
	# -3 = no execFile in a cluster section
	# -4 = duplicate parameters
	if ($idJob == -1){
 	   print("$Error_Prefix Bad JDL file or Bad param file\n");
   		 exit(2);
	}elsif($idJob == -2){
    	print("$Error_Prefix No cluster defined\n");
    	exit(2);
	}elsif($idJob == -3){
    	print("$Error_Prefix No execFile in a cluster section\n");
	    exit(2);
	}elsif($idJob == -4){
    	print("$Error_Prefix Duplicate parameters\n");
	    exit(2);
	#temporary solution while admission rules are not implemented
	}elsif($idJob == -5){   
    	print("$Error_Prefix $mJobType: invalid campaign type\n");
	    exit(2);
	}

} elsif (defined($resubmit)) {
	if(defined($jobId)){
	    my $jobUser = iolibCigri::get_job_user($base,$jobId);
    	if ($jobUser eq $user){
        	colomboCigri::resubmit_job($base,$jobId);
	        print("The job $jobId has been resubmitted\n");
    	}else{
        	print("/!\\$Error_Prefix You are not the right user\n");
	        exit(1);
		}
	}elsif(defined($MJobId)){
		my $jobUser = iolibCigri::get_MJob_user($base,$MJobId);
		if ($jobUser eq $user){
            colomboCigri::resubmit_mjob($base,$MJobId,$mJobType);
            print("The mjob $MJobId has been resubmitted\n");
		}else{
            print("/!\ $Error_Prefix You are not the right user\n");
            exit(1);
        };
		

	}
}




iolibCigri::disconnect($base);
exit 0;
