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

my @jobsToCollect = iolibCigri::get_tocollect_files($base);

#print(Dumper(@jobsToCollect));
#Be carefull : the home directory of each user must be executable

my @fileToDownload;
my %clusterVisited;

foreach my $i (@jobsToCollect){
	my %cmdResult;
	# create/empty right folder on cluster
	if (!defined($clusterVisited{$$i{nodeClusterName}})){
		%cmdResult = SSHcmd::submitCmd($$i{nodeClusterName}, "if [ -d ~/results ]; then rm -rf ~/results/* ; else mkdir ~/results ; fi");
#		print(Dumper(%cmdResult));
		if ($cmdResult{STDERR} ne ""){
			die("[COLLECTOR] SSHcmd::submitCmd($$i{nodeClusterName}, \"if [ -d ~/results ]; then rm -rf ~/results/* ; else mkdir ~/results ; fi\") -- $cmdResult{STDERR} \n");
		}
		my %initHash;
		$clusterVisited{$$i{nodeClusterName}} = \%initHash;

	}

	undef(%cmdResult);
	@fileToDownload = 	(	"OAR.cigri.tmp.$$i{jobId}.$$i{jobBatchId}.stdout",
							"OAR.cigri.tmp.$$i{jobId}.$$i{jobBatchId}.stderr"
						);
	foreach my $j (@fileToDownload){
		print("[COLLECTOR] tar rf ~/results/$$i{jobMJobsId}.tar -C ~$$i{userLogin} $j  -- on $$i{nodeClusterName}\n");
		%cmdResult = SSHcmd::submitCmd($$i{nodeClusterName}, "tar rf ~/results/$$i{jobMJobsId}.tar -C ~$$i{userLogin} $j");
		if ($cmdResult{STDERR} ne ""){
			die("SSHcmd::submitCmd($$i{nodeClusterName}, \"tar rf ~/results/$$i{jobMJobsId}.tar -C ~$$i{userLogin} $j\") -- $cmdResult{STDERR}\n");
		}
	}

	if (!defined(${$clusterVisited{$$i{nodeClusterName}}}{$$i{jobMJobsId}})){
		my @initArray;
		${$clusterVisited{$$i{nodeClusterName}}}{$$i{jobMJobsId}} = [ "$$i{userGridName}", ["$$i{jobId}"]]
	}else{
		push(@{${${$clusterVisited{$$i{nodeClusterName}}}{$$i{jobMJobsId}}}[1]},"$$i{jobId}") ;
	}
	${${$clusterVisited{$$i{nodeClusterName}}}{$$i{jobMJobsId}}}[0] = $$i{userGridName} ;

	print("--\n");
}

my $fileName;
foreach my $i (keys(%clusterVisited)){
	foreach my $j (keys(%{$clusterVisited{$i}})){
		my @resColl = iolibCigri::create_new_collector($base,$i);
		print("mkdir -p ~cigri/results/${${$clusterVisited{$i}}{$j}}[0]/$j \n");
		system("mkdir -p ~cigri/results/${${$clusterVisited{$i}}{$j}}[0]/$j");
		if( $? != 0 ){
			die("mkdir -p ~cigri/results/${${$clusterVisited{$i}}{$j}}[0]/$j\nexit_code=$?\n");
		}
		print("scp -qC $i:~cigri/results/$j.tar ~cigri/results/${${$clusterVisited{$i}}{$j}}[0]/$j/$resColl[1].tar \n");
		system("scp -qC $i:~cigri/results/$j.tar ~cigri/results/${${$clusterVisited{$i}}{$j}}[0]/$j/$resColl[1].tar");
		if( $? != 0 ){
			die("scp -qC $i:~cigri/results/$j.tar ~cigri/results/${${$clusterVisited{$i}}{$j}}[0]/$j/$resColl[1].tar\nexit_code=$?\n");
		}
		foreach my $k (@{${${$clusterVisited{$i}}{$j}}[1]}){
			iolibCigri::set_job_collectedId($base,$k,$resColl[0]);
		}
	}
}

iolibCigri::disconnect($base);

