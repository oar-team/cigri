#!/usr/bin/perl -w

# Tool to update NODE_STATE in the database

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

select(STDOUT);
$|=1;

my $base = iolibCigri::connect();

# update database
iolibCigri::disable_all_nodes($base);
# Get cluster names
my %clusterNames = iolibCigri::get_cluster_names_batch($base);

# Exec through ssh : pbsnodes command
foreach my $i (keys(%clusterNames)){
	print("[UPDATOR] Query free nodes on $i which has a batch-scheduler of the type : $clusterNames{$i}\n");

    if (nodeStat::updateNodeStat($i) == -1){
        #something wrong happens
        exit(66);
    }
}

# Update jobs which are in the Running state
my %jobRunningHash = iolibCigri::get_job_to_update_state($base);
print("[UPDATOR] Verify if Running jobs are still running:\n");
# Exec qstat cmd for all clusters which have a running job
foreach my $i (keys(%jobRunningHash)){
	print("\tcluster = $i\n");
    my %jobState = ();
    if (jobStat::jobStat($i, \%jobState) == -1){
        exit(66);
    }
	foreach my $j (@{$jobRunningHash{$i}}){
		# Verify if the job is still running on the cluster $i
		if (!defined($jobState{${$j}{batchJobId}})){
			# Check the result file on the cluster
			my $remoteFile = iolibCigri::get_cigri_remote_file_name(${$j}{jobId});
			print("[Updator] Check the job ${$j}{jobId} \n");
			my %cmdResult = SSHcmdClient::submitCmd($i,"sudo -u ${$j}{user} cat ~${$j}{user}/$remoteFile");
			if ($cmdResult{STDERR} ne ""){
				print("\t[UPDATOR_ERROR] Can't check the remote file\n");
				print("\t[UPDATOR_STDERR] $cmdResult{STDERR}");
				# Can t read the file
				# test if this is a ssh error
                if (NetCommon::checkSshError($base,$i,$cmdResult{STDERR}) != 1){
                    iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
                    colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_JOB_KILLED","Can t check the remote file <$remoteFile> : $cmdResult{STDERR}");
                }
                exit(66);
			}else{
				my @strTmp = split(/\n/, $cmdResult{STDOUT});
				my %fileVars;
				foreach my $k (@strTmp){
					if ($k =~ m/\s*(.+)\s*=\s*(.+)\s*/m){
						$fileVars{$1} = $2;
					}
				}
				print(Dumper(%fileVars));
				if (defined($fileVars{FINISH})){
					# the job is finished
					iolibCigri::update_att_job($base,${$j}{jobId},$fileVars{BEGIN_DATE},$fileVars{END_DATE},$fileVars{RET_CODE});
					if ($fileVars{RET_CODE} == 0){
						print("\t\tJob ${$j}{jobId} Terminated\n");
						iolibCigri::set_job_state($base, ${$j}{jobId}, "Terminated");
					}else{
						print("\t\tJob ${$j}{jobId} Error\n");
						iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
						colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_RET_CODE_ERROR","$cmdResult{STDERR}");
                        exit(66);
					}
				}else{
					# the was killed by the batch scheduler of the cluster
					# maybe it was too long, or an other job had to pass
					print("\t[UPDATOR_ERROR] Can't find the FINISH TAG for the job ${$j}{jobId}\n");
					print("\t[UPDATOR_ERROR] cat $remoteFile ==> $cmdResult{STDOUT}\n");
					iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
					colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_JOB_KILLED","Can t find the FINISH TAG in the cigri remote file <$remoteFile> : $cmdResult{STDOUT}");
				}
			}
			my %cmdResultRm = SSHcmdClient::submitCmd($i,"sudo -u ${$j}{user} rm ~${$j}{user}/$remoteFile");
            # test if this is a ssh error
            if ($cmdResultRm{STDERR} ne ""){
                NetCommon::checkSshError($base,$i,$cmdResultRm{STDERR}) ;
                exit(66);
            }
		}else{
			#verify if the job is waiting
			if (defined($jobState{${$j}{batchJobId}})){
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
iolibCigri::check_end_MJobs($base);

#update database for the scheduler
iolibCigri::update_nb_freeNodes($base);

iolibCigri::disconnect($base);

