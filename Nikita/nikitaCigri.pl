#! /usr/bin/perl

# This program deletes toFrag jobs

use strict;
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
	unshift(@INC, $relativePath."Net");
	unshift(@INC, $relativePath."Iolib");
}
use iolibCigri;
use SSHcmdClient;

# List of pbsnodes commands
my %qdelCommand = ( 'PBS' => 'qdel',
					'OAR' => 'qdel.pl' );

my $base = iolibCigri::connect() ;

#Get MJobs to frag
my @MJobsToFrag = iolibCigri::get_tofrag_MJobs($base);

foreach my $i (@MJobsToFrag){
	iolibCigri::delete_all_MJob_parameters($base,$i);
	#Frag it jobs
	iolibCigri::set_frag_flag_specific_MJob($base,$i);
	#change state
	iolibCigri::set_MJobState_fragged($base,$i);
}

#Get jobs to frag
my @jobsToFrag = iolibCigri::get_tofrag_jobs($base);

foreach my $i (@jobsToFrag){
	#Delete this job
	if (($$i{jobBatchId} ne "") && ($$i{userLogin} ne "") && ($$i{clusterName} ne "")){
		print("ssh $$i{clusterName} -c sudo -u $$i{userLogin} $qdelCommand{$$i{clusterBatch}} $$i{jobBatchId}\n");
		my %cmdResult = SSHcmdClient::submitCmd($$i{clusterName},"sudo -u $$i{userLogin} $qdelCommand{$$i{clusterBatch}} $$i{jobBatchId}");
		print(Dumper(%cmdResult));
		if ($cmdResult{STDERR} ne ""){
			print("ERREUR A TRAITER\n");
		}else{
			print("OK\n");
			#change state
			iolibCigri::set_jobState_fragged($base,$$i{jobId});
		}
	}
}

iolibCigri::disconnect($base);
