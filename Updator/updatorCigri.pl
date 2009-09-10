#!/usr/bin/perl

# Tool to update NODE_STATE in the database

use Data::Dumper;
use warnings;
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
    unshift(@INC, $relativePath."Net");
    unshift(@INC, $relativePath."Colombo");
    unshift(@INC, $relativePath."ClusterQuery");
}
use iolibCigri;
use SSHcmdClient;
use colomboCigri;
use NetCommon;
use jobStat;
use nodeStat;
use mailer;

select(STDOUT);
$|=1;

my $base = iolibCigri::connect();

# update database
iolibCigri::disable_all_nodes($base);
# Get cluster names
my %clusterNames = iolibCigri::get_cluster_names_batch($base);

# Exec through ssh : pbsnodes command
foreach my $i (keys(%clusterNames)){
    print("[UPDATOR]     Query free nodes on $i which has a batch-scheduler of the type : $clusterNames{$i}\n");

    if (nodeStat::updateNodeStat($i) == -1){
        #something wrong happens
        exit(66);
    }
}

# Update jobs which are in the Running state
my %jobRunningHash = iolibCigri::get_job_to_update_state($base);
print("[UPDATOR]     Verify if Running jobs are still running\n");
# Exec qstat cmd for all clusters which have a running job
foreach my $i (keys(%jobRunningHash)){
    my %jobState = ();
    my %jobResources = ();
    my $remotewaiting_timeout;
    print "[UPDATOR]     Checking $i jobs...\n";
    if (jobStat::jobStat($i, \%jobState, \%jobResources) == -1){
        exit(66);
    }

    #print(Dumper(%jobState));
    foreach my $j (@{$jobRunningHash{$i}}){
        # Verify if the job is still running on the cluster $i
        if (!defined($jobState{${$j}{batchJobId}})){
            # Check the result file on the cluster
            my $remoteFile = "${$j}{execDir}/".iolibCigri::get_cigri_remote_file_name(${$j}{jobId});
            my $tmpRemoteScript = "${$j}{execDir}/".iolibCigri::get_cigri_remote_script_name(${$j}{jobId});
            print("[UPDATOR]     Check the job ${$j}{jobId} \n");
            my %cmdResult = SSHcmdClient::submitCmd($i,"sudo -H -u ${$j}{user} bash -c \"cat $remoteFile\"");
            if ($cmdResult{STDERR} ne ""){
                print("\t[UPDATOR]     ERROR: Can t check the remote file\n");
                print("\t[UPDATOR]     ERROR STDERR: $cmdResult{STDERR}");
                # Can t read the file
                # test if this is a ssh error
                if (NetCommon::checkSshError($base,$i,$cmdResult{STDERR}) != 1){
                    iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
                    colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_JOB_KILLED","Can t check the remote file <$remoteFile> : $cmdResult{STDERR}");
                }else{
                    exit(66);
                }
            }else{
                my @strTmp = split(/\n/, $cmdResult{STDOUT});
                my %fileVars;
                foreach my $k (@strTmp){
                    if ($k =~ m/\s*(.+)\s*=\s*(.+)\s*/m){
                        $fileVars{$1} = $2;
                    }
                }
                #print(Dumper(%fileVars));
                if (defined($fileVars{FINISH})){
                    # the job is finished
                    iolibCigri::update_att_job($base,${$j}{jobId},$fileVars{BEGIN_DATE},$fileVars{END_DATE},$fileVars{RET_CODE},$i,$fileVars{NODE});
                    if ($fileVars{RET_CODE} == 0){
                        print("\t\tJob ${$j}{jobId} Terminated\n");
                        iolibCigri::set_job_state($base, ${$j}{jobId}, "Terminated");
                    }else{
                        print("\t\tJob ${$j}{jobId} Error\n");
			if ($fileVars{RET_CODE} == 66){
		          print "[UPDATOR]     Job ${$j}{jobId} exited with resubmit code 66, so we resubmit.\n";
			  iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
		          colomboCigri::resubmit_job($base,${$j}{jobId});

			}else{
                          iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
                          colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_RET_CODE_ERROR","Executable exited with error code $fileVars{RET_CODE}; $cmdResult{STDERR}\nCheck OAR.${$j}{jobName}.${$j}{batchJobId}.stderr on ${$j}{clusterName} for more infos");
                          #exit(66);
			}
                    }
                }else{
                    # the job was killed by the batch scheduler of the cluster
                    # maybe it was too long, or an other job had to pass
                    print("[UPDATOR]     Error: Can t find the FINISH TAG for the job ${$j}{jobId}\n");
                    print("[UPDATOR]     Error: cat $remoteFile ==> $cmdResult{STDOUT}\n");
                    iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
                    colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_JOB_KILLED","Can t find the FINISH TAG in the cigri remote file <$remoteFile> : $cmdResult{STDOUT}");
                }
            }
            # cigri script, log and OAR files must be deleted ---> A FAIRE
            my %cmdResultRm = SSHcmdClient::submitCmd($i,"sudo -H -u ${$j}{user} bash -c \"rm -f $remoteFile $tmpRemoteScript\"");
            # test if this is a ssh error
            if ($cmdResultRm{STDERR} ne ""){
                NetCommon::checkSshError($base,$i,$cmdResultRm{STDERR}) ;
                exit(66);
            }
        }else{
            #verify if the job is waiting
            if (defined($jobState{${$j}{batchJobId}})){
                iolibCigri::set_job_number_of_resources($base, ${$j}{jobId},$jobResources{${$j}{batchJobId}});
                if ($jobState{${$j}{batchJobId}} eq "W"){
                    iolibCigri::set_job_state($base, ${$j}{jobId}, "RemoteWaiting");
                }else{
                    iolibCigri::set_job_state($base, ${$j}{jobId}, "Running");
                }
            }
        }
    }
}

#update the state of MJobs
my @MJobs_ended = iolibCigri::check_end_MJobs($base);

#update database for the scheduler
#iolibCigri::check_remote_waiting_jobs($base);



# notify admin by email
foreach my $i (@MJobs_ended){
    mailer::sendMail("End MJob $i ","[Iolib] set to Terminated state the MJob $i");
    mailer::sendMailtoUser("CiGri: end MJob $i ","Your CiGri Mjob $i has just ended.",iolibCigri::get_MJob_user($base,$i));
}

iolibCigri::emptyTemporaryTables($base);
iolibCigri::disconnect($base);
