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
}
use iolibCigri;
use SSHcmdClient;
use colomboCigri;
use NetCommon;

select(STDOUT);
$|=1;

# List of pbsnodes commands
my %pbsCommand = ( 	'PBS' => 'pbsnodes -a',
					'OAR1' => 'pbsnodes.pl -a',
					'OAR' => 'oarnodes -a' );

my %qstatCmd = ( 	'PBS' => 'qstat -f',
					'OAR1' => 'qstat.pl -f',
					'OAR' => 'oarstat -f' );

my $base = iolibCigri::connect();

#check errors in the database
#iolibCigri::analyse_error($base);

# update database
iolibCigri::disable_all_nodes($base);
# Get cluster names
my %clusterNames = iolibCigri::get_cluster_names_batch($base);

# Exec through ssh : pbsnodes command
foreach my $i (keys(%clusterNames)){
	if (colomboCigri::is_cluster_active($base,"$i",0) > 0){
		print("[UPDATOR] the cluster $i is blacklisted\n");
		next;
	}
	print("[UPDATOR] Query free nodes on $i which has a batch-scheduler of the type : $clusterNames{$i}\n");

	my %cmdResult = SSHcmdClient::submitCmd($i,"$pbsCommand{$clusterNames{$i}}");

	my $pbsnodesStr = $cmdResult{STDOUT};

	if ($cmdResult{STDERR} eq ""){
		chomp($pbsnodesStr);
		my @nodesStrs = split(/^\s*\n/m,$pbsnodesStr);
		foreach my $nodeStr (@nodesStrs){
			my @lines = split(/\n/, $nodeStr);
			my $name = shift(@lines);
			$name =~ s/\s//g;
			my $state;
			my $lineTmp;
			my $key;
			# parse pbsnodes command
			while ((! defined($state)) && ($#lines >= 0)){
				$lineTmp = shift(@lines);
				if ($lineTmp =~ /state =/){
					($key, $state) = split("=", $lineTmp);
					# I drop spaces
					$state =~ s/\s//g;
				}
			}
			if (defined($name) && defined($state)){
				# Databse update
				iolibCigri::set_cluster_node_state($base, $i, $name, $state);
			}else{
				print("[UPDATOR] There is an error in the pbsnodes command parse, node=$name;state=$state\n");
				colomboCigri::add_new_cluster_event($base,"$i",0,"UPDATOR_PBSNODES_PARSE","There is an error in the oarnodes command parse, node=$name;state=$state");
                exit(12);
			}
		}
	}else{
		print("[UPDATOR_ERROR] There is an error in the execution of the pbsnodes command via SSH \n--> I disable all nodes of the cluster $i \n");
		print("[UPDATOR_ERROR] $cmdResult{STDERR}\n");
		# test if this is a ssh error
        if (NetCommon::checkSshError($base,$i,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($base,"$i",0,"UPDATOR_PBSNODES_CMD","There is an error in the execution of the pbsnodes command via SSH-->I disable all nodes of the cluster $i;$cmdResult{STDERR}");
        }
        exit(12);
	}
}

# Update jobs which are in the Running state
my %jobRunningHash = iolibCigri::get_job_to_update_state($base);
print("[UPDATOR] Verify if Running jobs are still running:\n");
# Exec qstat cmd for all clusters which have a running job
foreach my $i (keys(%jobRunningHash)){
	if (colomboCigri::is_cluster_active($base,"$i",0) > 0){
		print("[UPDATOR] the cluster $i is blacklisted\n");
		next;
	}
	print("\tcluster = $i\n");
	my %cmdResult = SSHcmdClient::submitCmd($i,"$qstatCmd{$clusterNames{$i}}");
	my $errorFlag = 0;
	my %jobState = ();
	if ($cmdResult{STDERR} ne ""){
		print("\t[UPDATOR_ERROR] $cmdResult{STDERR}\n");
		# test if this is a ssh error
        if (NetCommon::checkSshError($base,$i,$cmdResult{STDERR}) != 1){
		    colomboCigri::add_new_cluster_event($base,"$i",0,"UPDATOR_QSTAT_CMD","$cmdResult{STDERR}");
        }
        exit(12);
	}else{
		my $qstatStr = $cmdResult{STDOUT};
		chomp($qstatStr);
		my @jobsStrs = split(/^s*\n/m,$qstatStr);
		# for each job section, record its state
		foreach my $jobStr (@jobsStrs){
			$jobStr =~ /Job Id: (\d+).*job_state = (.).*/s;
			#print("[UPDATOR_DEBUG] $jobStr\n");
			$jobState{$1} = $2;
		}
	}
	foreach my $j (@{$jobRunningHash{$i}}){
		# Verify if the job is still running on the cluster $i
		if ((!defined($jobState{${$j}{batchJobId}})) and ($cmdResult{STDERR} eq "")){
			# Check the result file on the cluster
			my $remoteFile = iolibCigri::get_cigri_remote_file_name(${$j}{jobId});
			print("[Updator] Check the job ${$j}{jobId} \n");
			my %cmdResult2 = SSHcmdClient::submitCmd($i,"sudo -u ${$j}{user} cat ~${$j}{user}/$remoteFile");
			if ($cmdResult2{STDERR} ne ""){
				print("\t[UPDATOR_ERROR] Can't check the remote file\n");
				print("\t[UPDATOR_STDERR] $cmdResult2{STDERR}");
				# Can t read the file
				# test if this is a ssh error
                if (NetCommon::checkSshError($base,$i,$cmdResult{STDERR}) != 1){
                    iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
                    colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_JOB_KILLED","Can t check the remote file <$remoteFile> : $cmdResult2{STDERR}");
                }
                exit(12);
			}else{
				my @strTmp = split(/\n/, $cmdResult2{STDOUT});
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
                        exit(12);
					}
				}else{
					# the was killed by the batch scheduler of the cluster
					# maybe it was too long, or an other job had to pass
					print("\t[UPDATOR_ERROR] Can't find the FINISH TAG for the job ${$j}{jobId}\n");
					print("\t[UPDATOR_ERROR] cat $remoteFile ==> $cmdResult2{STDOUT}\n");
					iolibCigri::set_job_state($base, ${$j}{jobId}, "Event");
					colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_JOB_KILLED","Can t find the FINISH TAG in the cigri remote file <$remoteFile> : $cmdResult2{STDOUT}");
				}
			}
			my %cmdResultRm = SSHcmdClient::submitCmd($i,"sudo -u ${$j}{user} rm ~${$j}{user}/$remoteFile");
            # test if this is a ssh error
            if ($cmdResultRm{STDERR} ne ""){
                NetCommon::checkSshError($base,$i,$cmdResultRm{STDERR}) ;
                exit(12);
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

