#!/usr/bin/perl

# This program launches the jobs on the remote clusters

use strict;
use Data::Dumper;
use IO::Socket::INET;
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
use colomboCigri;
#use SSHcmdClient;
use SSHcmd;
use NetCommon;
use jobSubmit;

my $base = iolibCigri::connect() ;

# Get active cluster names
my %clusterNames = iolibCigri::get_cluster_names_batch($base);
iolibCigri::disconnect($base);
my %job;
foreach my $j (keys(%clusterNames)){
    print("[RUNNER]      check for cluster $j\n");
    my $pid=fork;
    if ($pid == 0){
        $base = iolibCigri::connect() ;
        while (iolibCigri::get_cluster_job_toLaunch($base,$j,\%job) == 0){
            print("[RUNNER]      Launch the job $job{id} on the cluster $job{clusterName}\n");
            #print(Dumper(%job));

            my $jobId = $job{id};
            #my $tmpRemoteFile = "cigri.tmp.$jobId";
            my $tmpRemoteFile = "~cigri/".iolibCigri::get_cigri_remote_script_name($jobId);
            my $resultFile = "$job{execDir}/".iolibCigri::get_cigri_remote_file_name($jobId);

            print("[RUNNER]      The job $jobId is in treatment...\n");

            # command to launch on the frontal of the cluster

	    #print "JOB PARAM: ". $job{param} ."\n";
	    #protect variables into parameters and cmd
	    $job{param}=~s/\$/\\\$/g;
	    $job{cmd}=~s/\$/\\\$/g;
	    my @cmdSSH;
            my $checkpoint_function;

	    # BLCR checkpoint submission script
	    if ($job{checkpointType} eq "blcr") {
	      print("[RUNNER]      This is a BLCR type checkpointable job\n");
	      @cmdSSH = (  "echo \\#\\!/bin/bash > $tmpRemoteFile;",
                            "echo \"echo \\\"BEGIN_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
			    "echo \"function checkpoint() {\" >> $tmpRemoteFile;",
                            "echo \"  echo \\\"CHECKPOINT_START=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
			    "echo \"  cr_checkpoint -T -f ckpt.tmp.\\\$\\\$ \\\$PID\" >> $tmpRemoteFile;",
			    "echo \"  if [ \\\$? = 0 ]\" >> $tmpRemoteFile;",
			    "echo \"    then mv -f ckpt.tmp.\\\$\\\$ $job{name}.ckpt\" >> $tmpRemoteFile;",
                            "echo \"      echo \\\"CHECKPOINT_END=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
			    "echo \"    else rm -f ckpt.tmp.\\\$\\\$\" >> $tmpRemoteFile;",
                            "echo \"      echo \\\"CHECKPOINT_ERROR=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
			    "echo \"  fi\" >> $tmpRemoteFile;",
			    "echo \"}\" >> $tmpRemoteFile;",
			    "echo \"trap checkpoint SIGQUIT\" >> $tmpRemoteFile;",
			    "echo \"if [ -f $job{name}.ckpt ]\" >> $tmpRemoteFile;", 
			    "echo \"  then nohup cr_run cr_restart $job{name}.ckpt &\" >> $tmpRemoteFile;",
                            "echo \"    echo \\\"CHECKPOINT_RESTART=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
			    "echo \"  else nohup cr_run $job{cmd} $job{param} &\" >> $tmpRemoteFile;",
                            "echo \"    echo \\\"INITIAL_START=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
			    "echo \"fi\" >> $tmpRemoteFile;",
			    "echo \"PID=\\\$!\" >> $tmpRemoteFile;",
			    "echo \"while jobs %1 >/dev/null 2>&1\" >> $tmpRemoteFile;",
			    "echo \"  do sleep 1\" >> $tmpRemoteFile;",
			    "echo \"done\" >> $tmpRemoteFile;",
			    "echo \"wait \\\$PID\" >> $tmpRemoteFile;",
                            "echo CODE=\\\$? >> $tmpRemoteFile;",
			    "echo \"rm -f $job{name}.ckpt\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"END_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"RET_CODE=\\\$CODE\\\" >> $resultFile\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"NODE=\\\"\\`cat \\\$OAR_FILE_NODES | head -1\\` >> $resultFile\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"FINISH=1\\\" >> $resultFile\" >> $tmpRemoteFile;",
                            "chmod +x $tmpRemoteFile ;",
                            "sudo -H -u $job{user} bash -c \"cp $tmpRemoteFile $job{execDir}/. \" ;",
                            "rm $tmpRemoteFile ;"
                        );

            # No checkpoint submission script
	    }else{
	      print("[RUNNER]      No checkpointing requiered for this job.\n");
              @cmdSSH = (  "echo \\#\\!/bin/bash > $tmpRemoteFile;",
                            "echo \"echo \\\"BEGIN_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
                            "echo $job{cmd} $job{param} >> $tmpRemoteFile;",
                            "echo CODE=\\\$? >> $tmpRemoteFile;",
                            "echo \"echo \\\"END_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"RET_CODE=\\\$CODE\\\" >> $resultFile\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"NODE=\\\"\\`cat \\\$OAR_FILE_NODES | head -1\\` >> $resultFile\" >> $tmpRemoteFile;",
                            "echo \"echo \\\"FINISH=1\\\" >> $resultFile\" >> $tmpRemoteFile;",
                            # this line is not valid "echo rm ~$job{user}/$tmpRemoteFile >> $tmpRemoteFile;",
                            "chmod +x $tmpRemoteFile ;",
                            #"cd $job{execDir} ;",
                            "sudo -H -u $job{user} bash -c \"cp $tmpRemoteFile $job{execDir}/. \" ;",
                            "rm $tmpRemoteFile ;"
                           );
            }

            my $cmdString = join(" ", @cmdSSH);
	    #print "$cmdString\n";
            my %cmdResult = SSHcmd::submitCmd($job{clusterName},$cmdString);
            if ($cmdResult{STDERR} ne ""){
                print("[RUNNER]      ERROR: $cmdResult{STDERR}");
                # test if this is a ssh error
                if (NetCommon::checkSshError($base,$job{clusterName},$cmdResult{STDERR}) != 1){
                    iolibCigri::set_job_state($base,$jobId,"Event");
                    # treate the SSH error
                    colomboCigri::add_new_job_event($base,$jobId,"RUNNER_SUBMIT",$cmdResult{STDERR});
                }
                exit(66);
            }else{
                my @blackNodes = colomboCigri::get_blacklisted_nodes($base,$job{mjobid},$job{clusterName});
                my $remoteScript = "$job{execDir}/".iolibCigri::get_cigri_remote_script_name($jobId);
                my $retCode = jobSubmit::jobSubmit($job{clusterName},\@blackNodes,$job{user},$remoteScript,$job{walltime},$job{resources},$job{execDir},$jobId,$job{name});
                if ($retCode < 0){
                    if ($retCode == -2){
                        print("[RUNNER]      There is a mistake, the job $jobId state = ERROR, bad remote batch id\n");
                        iolibCigri::set_job_state($base, $jobId, "Event");
                        colomboCigri::add_new_job_event($base,$jobId,"RUNNER_JOBID_PARSE","There is a mistake, the job $jobId state = ERROR, bad remote batch id");
                    }
                    exit(66);
                }else{
                    iolibCigri::set_job_batch_id($base,$jobId,$retCode);
                    iolibCigri::set_job_state($base,$jobId,"Running");
                }
            }
        }
        if (jobSubmit::endJobSubmissions($j) != 0){
            exit(66);
        }
        iolibCigri::disconnect($base);
        exit(0);
    }
}
foreach my $j (keys(%clusterNames)){
    wait();
}

iolibCigri::disconnect($base);

exit(0);

