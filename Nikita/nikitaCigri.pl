#! /usr/bin/perl

# This program deletes toFrag jobs

use strict;
use Data::Dumper;
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
    unshift(@INC, $relativePath."Net");
    unshift(@INC, $relativePath."Iolib");
    unshift(@INC, $relativePath."Colombo");
    unshift(@INC, $relativePath."ClusterQuery");
}
use iolibCigri;
use SSHcmdClient;
use NetCommon;
use jobDel;
use mailer;

my $base = iolibCigri::connect() ;

#handle long-lasting RemoteWaiting jobs
my $remotewaiting_timeout;
if (defined(ConfLibCigri::get_conf("REMOTE_WAITING_TIMEOUT")) &&
      (ConfLibCigri::get_conf("REMOTE_WAITING_TIMEOUT") > 10)) {
           $remotewaiting_timeout=ConfLibCigri::get_conf("REMOTE_WAITING_TIMEOUT");
}else {
           $remotewaiting_timeout=600;
}

my %remoteWaitingJobTimes = iolibCigri::get_remoteWaiting_times($base);
foreach my $jobId (keys (%remoteWaitingJobTimes)){
    if ($remoteWaitingJobTimes{$Idjob} > $remotewaiting_timeout){
        iolibCigri::set_job_state($base, $jobId, "Event");
        colomboCigri::add_new_job_event($base,$jobId,"FRAG","RemoteWaiting too long frag");
        colomboCigri::resubmit_job($base,$jobId);
        print "[NIKITA]     Frag-resubmit job $jobId because of RemoteWaiting for too long.\n";
    }
}


#Get MJobs to frag
my @MJobsToFrag = iolibCigri::get_tofrag_MJobs($base);

print(Dumper(@MJobsToFrag));

foreach my $i (@MJobsToFrag){
    iolibCigri::delete_all_MJob_parameters($base,$i);
    #Frag it jobs
    iolibCigri::set_frag_specific_MJob($base,$i);

    #iolibCigri::disconnect($base);
    # notify admin by email
    mailer::sendMail("Frag MJob $i","");
    #$base = iolibCigri::connect() ;

    #change state
    #iolibCigri::set_MJobState_fragged($base,$i);
    colomboCigri::fix_event($base,iolibCigri::get_MJobs_tofrag_eventId($base,$i));
}

#Get jobs to frag
my @jobsToFrag = iolibCigri::get_tofrag_jobs($base);
print(Dumper(@jobsToFrag));

foreach my $i (@jobsToFrag){
    #Delete this job
    if (($$i{jobBatchId} ne "") && ($$i{userLogin} ne "") && ($$i{clusterName} ne "")){
        if ( jobDel::jobDel($$i{clusterName},$$i{userLogin},$$i{jobBatchId}) == -1){
            exit(66);
        }else{
            print("OK\n");
            #change state
            #iolibCigri::set_jobState_fragged($base,$$i{jobId});
            colomboCigri::fix_event($base,$$i{eventId});
        }
    }else{
        colomboCigri::fix_event($base,$$i{eventId});
    }
}

jobDel::endJobDel();

iolibCigri::disconnect($base);
