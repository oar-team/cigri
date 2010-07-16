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
    my %batchIdTreated;
    my $remotewaiting_timeout;
    print "[UPDATOR]     Checking $i jobs...\n";
    if (jobStat::jobStat($i, \%jobState, \%jobResources) == -1){
        exit(66);
    }

    #print(Dumper(%jobState));
    foreach my $j (@{$jobRunningHash{$i}}){
	
	if (defined($j->{batchId})) { #it's a batch ! so we update it all.
		if (exists $batchIdTreated{$j->{batchId}}) {
			next; #Already seen, so we don't care
			#not pretty, but it's (supposedly) working
		}
		# Verify if the job is still running on the cluster $i
        	if (!defined($jobState{${$j}{remoteJobId}})){
		
			#Treat the batch
			my @jobIds = iolibCigri::get_jobids_from_batchid($base,$j->{batchId});
			if (@jobIds == 0) {
				#empty batch, should not happen
				print "[UPDATOR]	Empty  batch retrieved from a job batchid, so there's a problem.\n";
				exit(1);
			}
			print "[UPDATOR] We've got a batch ($j->{batchId}) containing @jobIds \n";		

			#first jobId is the "main" one, and therefore we have the same remote / script
       			my $remoteFile = "$j->{execDir}/".iolibCigri::get_cigri_remote_file_name($jobIds[0]);
		       	my $tmpRemoteScript = "$j->{execDir}/".iolibCigri::get_cigri_remote_script_name($jobIds[0]);
			
			my %cmdResult = SSHcmdClient::submitCmd($i,"sudo -H -u ${$j}{user} bash -c \"cat $remoteFile\"");
			if ($cmdResult{STDERR} ne ""){
       		        	print("\t[UPDATOR]     ERROR: Can t check the remote file\n");
        		        print("\t[UPDATOR]     ERROR STDERR: $cmdResult{STDERR}");
        		        # Can t read the file
        		        # test if this is a ssh error
        		        if (NetCommon::checkSshError($base,$i,$cmdResult{STDERR}) != 1){
        		        	for (@jobIds) {
				    		iolibCigri::set_job_state($base, $_, "Event");
        		            		colomboCigri::add_new_job_event($base,$_,"UPDATOR_JOB_KILLED","Can t check the remote file <$remoteFile> : $cmdResult{STDERR}");
       		 	       		}
				}else{
	        	            exit(66);
	        	        }
	        	} else { #clear, parse the results


########################### START OF THE BATCH PARSING

my @strTmp = split(/\n/, $cmdResult{STDOUT});
my %foundThisJobId;
my $before;
while(@strTmp) {

	#task-local variables are deleted
	delete $vars{CODE};
	delete $vars{NOW};
	delete $vars{NEXT_TASK};
	delete $vars{PARAM};
	delete $vars{JOBID};

	do {
	        $k = shift @strTmp;
	        print "read : $k\n";
	        if ($k =~ m/^\s*(.+)\s*=\s*(.+)\s*$/m){
	                if ($1 eq "BEGIN_DATE") {
	                        $vars{$1}=$2;
				$before = $2; 
				#sans quoi il se croit contemporain de Jésus et fait tout planter
			} elsif ($1 eq "END_DATE") {
	                        $vars{$1}=$2;
				$vars{NOW} = $2;
	                } else {
	                        if (exists $vars{$1}) {print "[UPDATOR] Overwriting att $1, there's likely".
	                                " a problem (missing NEXT_TASK ?)\n";}
	                        $vars{$1} = $2;
	                }
	        }
	        if ($k =~ m/^\s*(NEXT_TASK)/i or $k =~ m/^\s*(FINISH)/i) {
	                $vars{$1} = 1;
	        }
	} until (!@strTmp || exists $vars{"NEXT_TASK"});
	
	#print "Out of the read loop\n";
	
	if (exists $vars{NEXT_TASK}) {
	
		#print "Found NEXT_TASK\n"; #ou pas, j'ai codé ca n'importe comment
	
	        #pas certain qu'on aie toutes les variables à ce point, éviter les NULL
	        unless (exists $vars{JOBID} and exists $vars{PARAM} 
			and exists $vars{NOW} and exists $vars{CODE}) {
	                
			print "[UPDATOR] Warning : missing info in batch results (task level)".
                        " for batch $j->{batchId}, database may have problems\n";
        
		}
	
		$foundThisJobId{JOBID} = 1;

		iolibCigri::update_att_job(
	                        $base, $vars{JOBID}, $before, $vars{NOW}, $vars{CODE}, $i, $vars{NODE});

	        if ($vars{CODE} == 66){ 
	                print "[UPDATOR] Task exited with resubmit code 66, so we resubmit.\n";
	                iolibCigri::set_job_state($base, $vars{JOBID}, "Event");
	                colomboCigri::resubmit_job($base,$vars{JOBID});
	                        #à vérifier si ca fait bien ce qu'on veut
	        } elsif ($vars{CODE} == 0) {
	                print "[UPDATOR] Job $vars{JOBID} terminated with success.\n";
		        iolibCigri::set_job_state($base, $vars{JOBID}, "Terminated");
	        } else { #CODE != 0 => emmerdes
	                print "[UPDATOR] Job $vars{JOBID} terminated with retcode != 0, error.\n";
                          iolibCigri::set_job_state($base, $vars{JOBID}, "Event");
                          colomboCigri::add_new_job_event($base,$vars{JOBID},
					"UPDATOR_RET_CODE_ERROR","Executable exited with error code".
					" $vars{CODE}; $cmdResult{STDERR}".
					"Check the OAR std* on the cluster for more infos");
	        }
	
		print "[UPDATOR] Warning : missing info in batch results (job level) for batch $j->{batchId}\n"
		        unless(exists $vars{NOW});
	
		$before = $vars{NOW};

	}



}
print "Found eof\n"; #ou pas, j'ai codé ca n'importe comment

#end of the loop, now finishing

if (defined $vars{FINISH}) {
        unless (exists $vars{BEGIN_DATE} and
                exists $vars{END_DATE} and
                exists $vars{NODE}) {
                print "[UPDATOR] Warning : missing info in batch results (batch level)".
                        " for batch ${$j}{batchId}, database may have problems\n";
        }

        print("[UPDATOR] Batch terminated, seems okay\n");


} else { #ni finish ni NEXT_TASK : on a un *gros* problème

        print("[UPDATOR] Batch *not* terminated, problem\n");
             # problème : dégager les tâches du batch dont on a pas de nouvelles

        print("[UPDATOR] Job ${$j}{jobId} Error : batch not finished\n");
        for (@jobIds) {
		if (!exists($foundThisJobId{$_})) {
			iolibCigri::set_job_state($base, ${$j}{jobId}, Event);
        		colomboCigri::add_new_job_event($base,${$j}{jobId},UPDATOR_JOB_KILLED,
                	#Toutes mes excuses si ca peut se produire dans un autre cas
                	"Can't find the FINISH tag, batch probably killed by OAR.\n");
		}
	}
}

########################### END OF THE BATCH PARSING

			}

	        	my %cmdResultRm = SSHcmdClient::submitCmd($i,"sudo -H -u ${$j}{user} bash -c \"rm -f $remoteFile $tmpRemoteScript\"");
	        	# test if this is a ssh error
	        	if ($cmdResultRm{STDERR} ne ""){
	        	     NetCommon::checkSshError($base,$i,$cmdResultRm{STDERR}) ;
	        	     exit(66);
	        	}
		} else { #task not done running


		#Rjamet : à optimiser, ca fait énormément de requêtes très lentes (3*job) alors
		#que se baser sur le batchid accélèrerait tout

		    print "[UPDATOR] We check the status of our batch $j->{batchId}\n";
	            #verify if the job is waiting
	            if (defined($jobState{${$j}{remoteJobId}})){
	                #my @jobIds = iolibCigri::get_jobids_from_batchid($base,$j->{batchId});
			#if (@jobIds == 0) {
		#		#empty batch, should not happen
	#			print "[UPDATOR]	Empty  batch retrieved from a job batchid, so there's a problem.\n";
#				exit(1);
			#}
			#for (@jobIds) {
				iolibCigri::set_batch_number_of_resources($base, $j->{batchId} ,$jobResources{${$j}{remoteJobId}});
	                	if ($jobState{${$j}{remoteJobId}} eq "W"){
	                    	    iolibCigri::set_batch_state($base, $j->{batchId}, "RemoteWaiting");
	                	}else{
	                	    iolibCigri::set_batch_state($base, $j->{batchId}, "Running");
	                	}
			#}
	            }


		}
		$batchIdTreated{$j->{batchId}} = 1;


	} else { #individual task, so we use the old method

	        # Verify if the job is still running on the cluster $i
        	if (!defined($jobState{${$j}{remoteJobId}})){
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
	                          colomboCigri::add_new_job_event($base,${$j}{jobId},"UPDATOR_RET_CODE_ERROR","Executable exited with error code $fileVars{RET_CODE}; $cmdResult{STDERR}\nCheck OAR.${$j}{jobName}.${$j}{RemoteJobId}.stderr on ${$j}{clusterName} for more infos");
	                          #exit(66);
				}
	                    }
	                }else{
	                    # the job was killed by the batch scheduler of the cluster
	                    # maybe it was too long, or an other job had to pass
	                    print("[UPDATOR]     Job killed (Can t find the FINISH TAG for the job ${$j}{jobId})\n");
	                    #print("[UPDATOR]     Error: cat $remoteFile ==> $cmdResult{STDOUT}\n");
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
	            if (defined($jobState{${$j}{remoteJobId}})){
	                iolibCigri::set_job_number_of_resources($base, ${$j}{jobId},$jobResources{${$j}{remoteJobId}});
	                if ($jobState{${$j}{remoteJobId}} eq "W"){
	                    iolibCigri::set_job_state($base, ${$j}{jobId}, "RemoteWaiting");
	                }else{
	                    iolibCigri::set_job_state($base, ${$j}{jobId}, "Running");
	                }
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
