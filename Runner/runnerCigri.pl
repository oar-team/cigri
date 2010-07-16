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

my @jobs;
foreach my $j (keys(%clusterNames)){
    print("[RUNNER]      check for cluster $j\n");
    my $pid=fork;
    if ($pid == 0){
        $base = iolibCigri::connect() ;
        while (iolibCigri::get_cluster_job_toLaunch($base,$j,\@jobs) == 0){

    		my @cmdSSH;
		print "[RUNNER] Got @jobs to launch on $j\n";

		if (@jobs == 0) {
	    		print("[RUNNER]	Problem : jobs array void\n"); die();
		} elsif (! exists ($jobs[0]->{batchId})) {
            		my %job = %{$jobs[0]};
			print("[RUNNER]      Launch the job $job{id} on the cluster $job{clusterName} ($clusterNames{$j})\n");
           		#print(Dumper(%job));
		
            		my $jobId = $job{id};
            		#my $tmpRemoteFile = "cigri.tmp.$jobId";
            		my $tmpRemoteFile = "~cigri/".iolibCigri::get_cigri_remote_script_name($jobId);
            		my $resultFile = "$job{execDir}/".iolibCigri::get_cigri_remote_file_name($jobId);
	
       		     	print("[RUNNER]      The job $jobId is in treatment...\n Remote : $tmpRemoteFile\nres:$resultFile\n");	

	            	# command to launch on the frontal of the cluster
	
		    	#print "JOB PARAM: ". $job{param} ."\n";
	    		#protect variables into parameters and cmd
	    		$job{param}=~s/\$/\\\$/g;
	    		$job{cmd}=~s/\$/\\\$/g;
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

        	
		} else { # @jobs is a batch
		
			print("[RUNNER]      Launch the batch job $jobs[0]->{batchId} on the cluster $jobs[0]->{clusterName} ($clusterNames{$j})\n");
			print("[RUNNER]      But not yet.\n");

            		my $tmpRemoteFile = "~cigri/".iolibCigri::get_cigri_remote_script_name($jobs[0]->{id});
       	    		my $resultFile = "$jobs[0]->{execDir}/".iolibCigri::get_cigri_remote_file_name($jobs[0]->{id});

			foreach (@jobs) {

		    		$_->{param}=~s/\$/\\\$/g;
		    		$_->{cmd}=~s/\$/\\\$/g;
			}

                        #Batch submission script
                        print "[RUNNER] Job is a batch.\n";
       		     	print("[RUNNER]      The job $jobs[0]->{id} is in treatment...\n Remote : $tmpRemoteFile\nres:$resultFile\n");	

                        @cmdSSH = (  "echo \\#\\!/bin/bash > $tmpRemoteFile;",
                                     "echo \"echo \\\"ISABATCH\\\" >> $resultFile\" >> $tmpRemoteFile;",
                                     "echo \"echo \\\"NODE=\\\"\\`cat \\\$OAR_FILE_NODES | head -1\\` >> $resultFile\" >> $tmpRemoteFile;",
                                     "echo \"echo \\\"BEGIN_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;");


                        #$job{param} =~ m/^((\\,|[^,])+),?(.*)/;
                        @cmdSSH = (     @cmdSSH,
                                        "echo $jobs[0]->{cmd} $jobs[0]->{param} >> $tmpRemoteFile;",
                                        "echo \"RET=\\\$?\" >> $tmpRemoteFile;",                                        
					"echo \"echo \\\"JOBID=$jobs[0]->{id}\\\" >> $resultFile \" >> $tmpRemoteFile;",
					"echo \"echo \\\"PARAM=$jobs[0]->{param}\\\" >> $resultFile \" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"CODE=\\\$RET\\\" >> $resultFile \" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"NOW=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"NEXT_TASK\\\" >> $resultFile \" >> $tmpRemoteFile;"
                                );


                        for(1..@jobs-1) {
                              my $arg = $jobs[$_]->{param};
                              #$arg =~ s/\\,/,/g;
                              @cmdSSH = (@cmdSSH,
                                        "echo $jobs[$_]->{cmd} $arg >> $tmpRemoteFile;",
                                        "echo \"RET=\\\$?\" >> $tmpRemoteFile;",
					"echo \"echo \\\"JOBID=$jobs[$_]->{id}\\\" >> $resultFile \" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"PARAM=$arg\\\" >> $resultFile \" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"CODE=\\\$RET\\\" >> $resultFile \" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"NOW=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
                                        "echo \"echo \\\"NEXT_TASK\\\" >> $resultFile \" >> $tmpRemoteFile;"
                                );
                        }

                        @cmdSSH = ( @cmdSSH,
                                    "echo \"echo \\\"END_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> $tmpRemoteFile;",
                                    "echo \"echo \\\"FINISH\\\" >> $resultFile\" >> $tmpRemoteFile;",
                                    # this line is not valid "echo rm ~$job{user}/$tmpRemoteFile >> $tmpRemoteFile;",
                                    "chmod +x $tmpRemoteFile ;",
                                    #"cd $job{execDir} ;",
                                    "sudo -H -u $jobs[0]->{user} bash -c \"cp $tmpRemoteFile $jobs[0]->{execDir}/. \" ;",
                                    "rm $tmpRemoteFile ;"
                           );

                        print join "\n",@cmdSSH;

		}

       		my $cmdString = join(" ", @cmdSSH);
	       	#print  " ---------  $cmdString\n";
        	my %cmdResult = SSHcmd::submitCmd($jobs[0]->{clusterName},$cmdString);

            	if ($cmdResult{STDERR} ne ""){
                	print("[RUNNER]      ERROR: $cmdResult{STDERR}");
                	# test if this is a ssh error
                	if (NetCommon::checkSshError($base,$jobs[0]->{clusterName},$cmdResult{STDERR}) != 1){
				iolibCigri::set_batch_state($base,$_->{batchId},"Event");

	 			foreach (@jobs) {
                	    		# treate the SSH error
                	    		colomboCigri::add_new_job_event($base,$_->{id},"RUNNER_SUBMIT",$cmdResult{STDERR});
                		}
			}
                	exit(66);
            	}else{
                	my @blackNodes = colomboCigri::get_blacklisted_nodes($base,$jobs[0]->{mjobid},$jobs[0]->{clusterName});
                	my $remoteScript = "$jobs[0]->{execDir}/".iolibCigri::get_cigri_remote_script_name($jobs[0]->{id});
                	my $retCode = jobSubmit::jobSubmit($jobs[0]->{clusterName},\@blackNodes,$jobs[0]->{user},$remoteScript,
				$jobs[0]->{walltime}*@jobs,
				$jobs[0]->{resources},$jobs[0]->{execDir},
				$jobs[0]->{id}, #on prend la plus grande
				"Batch".$jobs[0]->{name});
                	if ($retCode < 0){
                		if ($retCode == -2){
                		        print("[RUNNER]      There is a mistake, the job $_->{id} state = ERROR, bad remote id\n");
	                		iolibCigri::set_batch_state($base, $jobs[0]->{batchId}, "Event");

					foreach (@jobs) {
	                       			colomboCigri::add_new_job_event($base,$_->{id},"RUNNER_JOBID_PARSE","There is a mistake, the job $_->{id} state = ERROR, bad remote id");
					}	
                		}
                		exit(66);
                	} else {
	               		iolibCigri::set_batch_state($base, $jobs[0]->{batchId}, "Running");

				foreach (@jobs) {
        	        	 	iolibCigri::set_job_remote_id($base,$_->{id},$retCode);
	                	 	#iolibCigri::set_job_state($base,$_->{id},"Running");
				}
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

