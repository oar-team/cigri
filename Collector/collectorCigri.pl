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
	unshift(@INC, $relativePath."Net");
	unshift(@INC, $relativePath."Iolib");
	unshift(@INC, $relativePath."Colombo");
}
use iolibCigri;
use Data::Dumper;
use SSHcmd;
use colomboCigri;

my $base = iolibCigri::connect();
# connection to the database for the lock
my $baseLock = iolibCigri::connect();
# only one instance of the collector
iolibCigri::lock_collector($baseLock);

# id of MJobs to collect
my @MjobsToCollect;

# if an argument --> a MJob id
if ($ARGV[0] =~ /^\d+$/ ){
	push(@MjobsToCollect, $ARGV[0]);
}else{
	@MjobsToCollect = iolibCigri::get_tocollect_MJobs($base);
}

foreach my $i (@MjobsToCollect){
	iolibCigri::begin_transaction($base);
	print("[COLLECTOR] I collecte the MJob $i\n");
	# get clusters userLogins jobID jobBatchId clusterBatch userGridName
	my @jobs = iolibCigri::get_tocollect_MJob_files($base,$i);
	my %clusterVisited;
	my %collectedJobs;
	my @errorJobs;

	foreach my $j (@jobs){
		my %cmdResult;

		if ((colomboCigri::is_cluster_active($base,"$$j{nodeClusterName}",$i) > 0) || (colomboCigri::is_collect_active($base,$i,"$$j{nodeClusterName}") > 0)){
			print("[COLLECTOR] the cluster $$j{nodeClusterName} is blacklisted\n");
			next;
		}

		# clean the repository on the remote cluster
		if (!defined($clusterVisited{$$j{nodeClusterName}})){
			%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "if [ -d ~cigri/results_tmp ]; then rm -rf ~cigri/results_tmp/* ; else mkdir ~cigri/results_tmp ; fi");
			if ($cmdResult{STDERR} ne ""){
				iolibCigri::rollback_transaction($base);
				die("[COLLECTOR] DIE --> SSHcmd::submitCmd($$j{nodeClusterName}, \"if [ -d ~cigri/results_tmp ]; then rm -rf ~cigri/results_tmp/* ; else mkdir ~cigri/results_tmp ; fi\") -- $cmdResult{STDERR} \n");
			}
		}

		# make the tar on remote cluster
		undef(%cmdResult);
		my $error = 0;
		my %hashfileToDownload = get_file_names($j);
		my @fileToDownload = keys(%hashfileToDownload);
		my $k;
		my @jobTaredTmp;
		while((($k = pop(@fileToDownload)) ne "") and ($error == 0)){
			if ($error == 0){
				if ("$hashfileToDownload{$k}" ne ""){
					print("[COLLECTOR] tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $hashfileToDownload{$k}  -- on $$j{nodeClusterName}\n");
					%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "test ! -e ~$$j{userLogin}/$hashfileToDownload{$k} && test -e ~$$j{userLogin}/$k && sudo -u $$j{userLogin} mv ~$$j{userLogin}/$k ~$$j{userLogin}/$hashfileToDownload{$k} && tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $hashfileToDownload{$k} && echo nimportequoi");
				}else{
					print("[COLLECTOR] tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $k  -- on $$j{nodeClusterName}\n");
					%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "test -e ~$$j{userLogin}/$k && tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $k && echo nimportequoi");
				}
				#print(Dumper(%cmdResult));
				if ($cmdResult{STDERR} ne ""){
					warn("ERREUR -- $cmdResult{STDERR}\n");
					foreach my $l (@jobTaredTmp){
						undef(%cmdResult);
						if ("$hashfileToDownload{$l}" ne ""){
							%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "tar --delete -f ~cigri/results_tmp/$i.tar $hashfileToDownload{$l}");
						}else{
							%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "tar --delete -f ~cigri/results_tmp/$i.tar $l");
						}
						if ($cmdResult{STDERR} ne ""){
							warn("Can t delete $l in ~cigri/results_tmp/$i.tar\n");
						}
					}
					$error = 1;
				}else{
					if ($cmdResult{STDOUT} ne "\n"){
						push(@jobTaredTmp, $k);
					}else{
						print("Can t collect this : the file does not exist or i can t rename the file\n");
					}
				}
			}
		}

		if (($error == 0) && ($#jobTaredTmp >= 0)){
			$collectedJobs{$$j{jobId}} = $j;
			$clusterVisited{$$j{nodeClusterName}} = 1;
		}else{
			push(@errorJobs, $j);
		}
	}

	# feedback for jobs which we can t collect
	foreach my $j (@errorJobs){
		iolibCigri::set_job_collectedJobId($base,$$j{jobId},-1);
	}

	my $userGridName = ${$jobs[0]}{userGridName};

	# copy the tar on the grid server
	my %jobToRemove;
	foreach my $j (keys(%clusterVisited)){
		if (colomboCigri::is_cluster_active($base,"$j",0) > 0){
			print("[COLLECTOR] the cluster $j is blacklisted\n");
			next;
		}
		my @resColl = iolibCigri::create_new_collector($base,$j,$i);
		print("mkdir -p ~cigri/results/$userGridName/$i \n");
		system("mkdir -p ~cigri/results/$userGridName/$i");
		if( $? != 0 ){
			iolibCigri::rollback_transaction($base);
			die("DIE exit_code=$?\n");
		}

		my %cmdResult = SSHcmd::submitCmd($j, "gzip ~cigri/results_tmp/$i.tar");
		if ($cmdResult{STDERR} ne ""){
			warn("ERREUR --> SSHcmd::submitCmd($j, \"gzip ~cigri/results_tmp/$i.tar\") -- $cmdResult{STDERR}\n");
		}else{
			print("scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz \n");
			system("scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz");
			if( $? != 0 ){
				warn("Error exit_code=$?\n");
				undef(%collectedJobs);
			}else{
				foreach my $k (keys(%collectedJobs)){
					if("${$collectedJobs{$k}}{nodeClusterName}" eq "$j"){
						print("set collectedJobId de $k = $resColl[1]\n");
						iolibCigri::set_job_collectedJobId($base,$k,$resColl[1]);
						$jobToRemove{$k} = $collectedJobs{$k};
					}
				}
			}
		}
	}

	# remove collected files
	foreach my $l (keys(%jobToRemove)){
		my %cmdResult;
		my $j = $jobToRemove{$l};
		if (colomboCigri::is_cluster_active($base,"$$j{nodeClusterName}",0) > 0){
			print("[COLLECTOR] the cluster $$j{nodeClusterName} is blacklisted\n");
			next;
		}
		my %hashfileToDownload = get_file_names($j);
		my @fileToDownload = keys(%hashfileToDownload);
		foreach my $k (@fileToDownload){
			if ("$hashfileToDownload{$k}" ne ""){
				print("[COLLECTOR] rm file ~$$j{userLogin}/$hashfileToDownload{$k} on cluster $$j{nodeClusterName}\n");
				%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "sudo -u $$j{userLogin} test -e ~$$j{userLogin}/$hashfileToDownload{$k} && sudo -u $$j{userLogin} rm -rf ~$$j{userLogin}/$hashfileToDownload{$k}");
			}else{
				print("[COLLECTOR] rm file ~$$j{userLogin}/$k on cluster $$j{nodeClusterName}\n");
				%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "sudo -u $$j{userLogin} test -e ~$$j{userLogin}/$k && sudo -u $$j{userLogin} rm -rf ~$$j{userLogin}/$k");
			}
			if ($cmdResult{STDERR} ne ""){
				warn("ERROR -- $cmdResult{STDERR}\n");
			}
		}
	}
	iolibCigri::commit_transaction($base);
}

iolibCigri::unlock_collector($baseLock);
iolibCigri::disconnect($base);

# get files to collect for a job
# arg1 --> struct of the job
sub get_file_names($){
	my $j = shift;
	my %result ;
	if($$j{jobName} ne ""){
		$result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout"} = "$$j{jobName}.$$j{jobId}.stdout";
		$result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"} = "$$j{jobName}.$$j{jobId}.stderr";
		$result{"$$j{jobName}"} = "";
	}else{
		$result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout"} = "";
		$result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"} = "";
	}

	return %result;
}

