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

my @MjobsToCollect;

if ($ARGV[0] =~ /^\d+$/ ){
	push(@MjobsToCollect, $ARGV[0]);
}else{
	@MjobsToCollect = iolibCigri::get_tocollect_MJobs($base);
}

foreach my $i (@MjobsToCollect){
	print("[COLLECTOR] I collecte the MJob $i\n");
	# get clusters userLogins jobID jobBatchId clusterBatch userGridName
	my @jobs = iolibCigri::get_tocollect_MJob_files($base,$i);
	my @jobsBis = @jobs;
	my @clusterVisited;
	my @collectedJobs;
	foreach my $j (@jobs){
		print("[COLLECTOR] $$j{jobId}\n");
		my %cmdResult;

		if ($#clusterVisited < 0){
			%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "if [ -d ~cigri//results ]; then rm -rf ~cigri/results/* ; else mkdir ~cigri/results ; fi");
			if ($cmdResult{STDERR} ne ""){
				die("[COLLECTOR] DIE --> SSHcmd::submitCmd($$j{nodeClusterName}, \"if [ -d ~cigri/results ]; then rm -rf ~cigri/results/* ; else mkdir ~cigri/results ; fi\") -- $cmdResult{STDERR} \n");
			}
			my %initHash;
			push(@clusterVisited, $$j{nodeClusterName});
		}

		undef(%cmdResult);
		my @fileToDownload = 	(	"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout",
									"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"
								);
		foreach my $k (@fileToDownload){
			print("[COLLECTOR] tar rf ~cigri/results/$i.tar -C ~$$j{userLogin} $k  -- on $$j{nodeClusterName}\n");
			%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "tar rf ~cigri/results/$i.tar -C ~$$j{userLogin} $k");
			if ($cmdResult{STDERR} ne ""){
				die("DIE --> SSHcmd::submitCmd($$j{nodeClusterName}, \"tar rf ~cigri/results/$i.tar -C ~$$j{userLogin} $k\") -- $cmdResult{STDERR}\n");
			}
		}
		push(@collectedJobs, $$j{jobId});
	}

	my $userGridName = ${$jobs[0]}{userGridName};

	foreach my $j (@clusterVisited){
		my @resColl = iolibCigri::create_new_collector($base,$j,$i);
		print("mkdir -p ~cigri/results/$userGridName/$i \n");
		system("mkdir -p ~cigri/results/$userGridName/$i");
		if( $? != 0 ){
			die("DIE exit_code=$?\n");
		}
		print("scp -qC $j:~cigri/results/$i.tar ~cigri/results/$userGridName/$i/$resColl[2].tar \n");
		system("scp -qC $j:~cigri/results/$i.tar ~cigri/results/$userGridName/$i/$resColl[2].tar");
		if( $? != 0 ){
			die("DIE exit_code=$?\n");
		}
		foreach my $k (@collectedJobs){
			iolibCigri::set_job_collectedJobId($base,$k,$resColl[1]);
		}
	}

	print("[COLLECTOR] rm all files of the MJob $i\n");
	foreach my $j (@jobsBis){
		my %cmdResult;
		my @fileToDownload =(	"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout",
								"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"
							);
		foreach my $k (@fileToDownload){
			%cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, "sudo -u $$j{userLogin} rm -f ~$$j{userLogin}/$k");
			if ($cmdResult{STDERR} ne ""){
				die("DIE --> SSHcmd::submitCmd($$j{nodeClusterName}, sudo -u $$j{userLogin} rm -f ~$$j{userLogin}/$k\n");
			}
		}
	}
}

iolibCigri::disconnect($base);

