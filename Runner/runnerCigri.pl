#! /usr/bin/perl

# This program launch the jobs on remote clusters

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
}
use iolibCigri;
use SSHcmdClient;

# List of pbsnodes commands
my %qsubCommand = ( 'PBS' => 'qsub',
					'OAR' => 'qsub.pl' );

my $base = iolibCigri::connect() ;

# treate the scheduler output in the jobsToSubmit table
if (iolibCigri::create_toLaunch_jobs($base) == 1){
	warn("[Runner] Error when i create_toLaunch_jobs\n");
	exit 1;
}

# list of jobs to launch
my @jobList = iolibCigri::get_launching_job($base);

my $jobId;
my $jobtype;
my $jobinfo;

my $tmpRemoteFile ;
my $resultFile ;
my %blackCluster;

select(STDOUT);
$| = 1;

foreach my $i (@jobList){
if (not defined($blackCluster{$$i{clusterName}})){
	$jobId = $$i{id};
	$tmpRemoteFile = "cigri.tmp.$jobId";
	$resultFile = "~/".iolibCigri::get_cigri_remote_file_name($jobId);

	print("[RUNNER] The job $jobId is in treatment...\n");

	# command to launch on the frontal of the cluster
	my @cmdSSH = (	"echo \\#\\!/bin/sh > ~/$tmpRemoteFile;",
					"echo \"echo \\\"BEGIN_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> ~/$tmpRemoteFile;",
					"echo $$i{cmd} $$i{param} >> ~/$tmpRemoteFile;",
					"echo CODE=\\\$? >> ~/$tmpRemoteFile;",
					"echo \"echo \\\"END_DATE=\\\"\\`date +\%Y-\%m-\%d\\ \%H:\%M:\%S\\` >> $resultFile\" >> ~/$tmpRemoteFile;",
					"echo \"echo \\\"RET_CODE=\\\$CODE\\\" >> $resultFile\" >> ~/$tmpRemoteFile;",
					"echo \"echo \\\"FINISH=1\\\" >> $resultFile\" >> ~/$tmpRemoteFile;",
					"echo rm ~$$i{user}/$tmpRemoteFile >> ~/$tmpRemoteFile;",
					"chmod +x ~/$tmpRemoteFile ;",
					"cd ~$$i{user} ;",
					"sudo -u $$i{user} /bin/cp ~/$tmpRemoteFile . ;",
					"rm ~/$tmpRemoteFile ;",
					"sudo -u $$i{user} $qsubCommand{$$i{batch}} -l nodes=1 -q besteffort `pwd`/$tmpRemoteFile;"
	);

	my $cmdString = join(" ", @cmdSSH);
	my %cmdResult = SSHcmdClient::submitCmd($$i{clusterName},$cmdString);
print(Dumper(%cmdResult));
	if ($cmdResult{STDERR} ne ""){
		print("[RUNNER_STDERR] $cmdResult{STDERR}");
		iolibCigri::set_job_state($base,$jobId,"Error");
		# treate the SSH error
		iolibCigri::insert_new_error($base,"RUNNER_SUBMIT",$jobId,$cmdResult{STDERR});
		iolibCigri::resubmit_job($base,$jobId);
		$blackCluster{$$i{clusterName}} = 1;
	}else{
		my @strTmp = split(/\n/, $cmdResult{STDOUT});
		my $configured = 0;
		foreach my $k (@strTmp){
			# update cluster batchId of the job
			if ($k =~ /\s*IdJob\s=\s(\d+)/){
				iolibCigri::set_job_batch_id($base,$jobId,$1);
				$configured = 1;
			}
			print("[RUNNER_STDOUT] $k\n");
		}
		if ($configured == 1){
			iolibCigri::set_job_state($base,$jobId,"Running");
		}else{
			print("[RUNNER] There is a mistake, the job $jobId state = ERROR, bad remote batch id\n");
			iolibCigri::set_job_state($base, $jobId, "Error");
			iolibCigri::set_job_message($base, $jobId, "can t determine the remoteJobId");
			# bad parsing
			iolibCigri::insert_new_error($base,"JOBID_PARSE","$jobId","There is a mistake, the job $jobId state = ERROR, bad remote batch id");
			iolibCigri::resubmit_job($base,$jobId);
			$blackCluster{$$i{clusterName}} = 1;
		}
	}
}
}
iolibCigri::disconnect($base);
