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
}
use iolibCigri;
use Data::Dumper;
use SSHcmd;

my $base = iolibCigri::connect();
my $baseLock = iolibCigri::connect();
iolibCigri::lock_collector($baseLock);

my @MjobsToCollect;

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
#	my %MjobsInError;
	my @errorJobs;

	foreach my $j (@jobs){
		my %cmdResult;

		if (!defined($clusterVisited{$$j{nodeClusterName}})){
			%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "if [ -d ~cigri/results ]; then rm -rf ~cigri/results/* ; else mkdir ~cigri/results ; fi");
			if ($cmdResult{STDERR} ne ""){
				iolibCigri::rollback_transaction($base);
				die("[COLLECTOR] DIE --> SSHcmd::submitCmd($$j{nodeClusterName}, \"if [ -d ~cigri/results ]; then rm -rf ~cigri/results/* ; else mkdir ~cigri/results ; fi\") -- $cmdResult{STDERR} \n");
			}
		}

		undef(%cmdResult);
		my $error = 0;
		my @fileToDownload = get_file_names($j);
		my $k;
		my @jobTaredTmp;
		while((($k = pop(@fileToDownload)) ne "") and ($error == 0)){
			if ($error == 0){
				print("[COLLECTOR] tar rf ~cigri/results/$i.tar -C ~$$j{userLogin} $k  -- on $$j{nodeClusterName}\n");
				%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "test -e ~$$j{userLogin}/$k && tar rf ~cigri/results/$i.tar -C ~$$j{userLogin} $k && echo nimportequoi");
				#print(Dumper(%cmdResult));
				if ($cmdResult{STDERR} ne ""){
					warn("ERREUR --> SSHcmd::submitCmd($$j{nodeClusterName}, \"tar rf ~cigri/results/$i.tar -C ~$$j{userLogin} $k\") -- $cmdResult{STDERR}\n");
					foreach my $l (@jobTaredTmp){
						undef(%cmdResult);
						%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "tar --delete -f ~cigri/results/$i.tar $l");
						if ($cmdResult{STDERR} ne ""){
							warn("Can t delete $l in ~cigri/results/$i.tar\n");
						}
					}
					$error = 1;
				}else{
					if ($cmdResult{STDOUT} ne "\n"){
						push(@jobTaredTmp, $k);
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

	foreach my $j (@errorJobs){
		iolibCigri::set_job_collectedJobId($base,$$j{jobId},-1);
	}

	my $userGridName = ${$jobs[0]}{userGridName};

	foreach my $j (keys(%clusterVisited)){
		my @resColl = iolibCigri::create_new_collector($base,$j,$i);
		print("mkdir -p ~cigri/results/$userGridName/$i \n");
		system("mkdir -p ~cigri/results/$userGridName/$i");
		if( $? != 0 ){
			iolibCigri::rollback_transaction($base);
			die("DIE exit_code=$?\n");
		}

		my %cmdResult = SSHcmd::submitCmd($j, "gzip ~cigri/results/$i.tar");
		if ($cmdResult{STDERR} ne ""){
			warn("ERREUR --> SSHcmd::submitCmd($j, \"gzip ~cigri/results/$i.tar\") -- $cmdResult{STDERR}\n");
		}else{
			print("scp -q $j:~cigri/results/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz \n");
			system("scp -q $j:~cigri/results/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz");
			if( $? != 0 ){
				warn("Error exit_code=$?\n");
				undef(%collectedJobs);
			}else{
				foreach my $k (keys(%collectedJobs)){
					if("${$collectedJobs{$k}}{nodeClusterName}" eq "$j"){
						print("set collectedJobId de $k = $resColl[1]\n");
						iolibCigri::set_job_collectedJobId($base,$k,$resColl[1]);
					}
				}
			}
		}
	}

	foreach my $l (keys(%collectedJobs)){
		my %cmdResult;
		my $j = $collectedJobs{$l};
		my @fileToDownload = get_file_names($j);
		foreach my $k (@fileToDownload){
			print("[COLLECTOR] rm file ~$$j{userLogin}/$k on cluster $$j{nodeClusterName}\n");
			%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "sudo -u $$j{userLogin} test -e ~$$j{userLogin}/$k && sudo -u $$j{userLogin} rm -rf ~$$j{userLogin}/$k");
			if ($cmdResult{STDERR} ne ""){
				warn("ERROR --> SSHcmd::submitCmd($$j{nodeClusterName}, sudo -u $$j{userLogin} rm -rf ~$$j{userLogin}/$k\n");
			}
		}
	}
	iolibCigri::commit_transaction($base);
}

iolibCigri::unlock_collector($baseLock);
iolibCigri::disconnect($base);

sub get_file_names($){
	my $j = shift;
	my @result ;
	push(@result, "OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout");
	push(@result, "OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr");
	if($$j{jobName} ne ""){
		push(@result, $$j{jobName});
	}

	return @result;
}
