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
	unshift(@INC, $relativePath."Colombo");
}
use iolibCigri;
use SSHcmdClient;
use NetCommon;

# List of pbsnodes commands
my %qsubCommand = ( 'PBS' => 'qsub',
					'OAR1' => 'qsub.pl',
					'OAR' => 'oarsub' );

my $base = iolibCigri::connect() ;

# treate the scheduler output in the jobsToSubmit table
if (iolibCigri::create_toLaunch_jobs($base) == 1){
	warn("[Runner] Error when i create_toLaunch_jobs\n");
	exit 1;
}

# list of jobs to launch
my @jobList = iolibCigri::get_launching_job($base);

print(Dumper(@jobList));

my $jobId;
my $jobtype;
my $jobinfo;

my $tmpRemoteFile ;
my $resultFile ;

select(STDOUT);
$| = 1;

foreach my $i (@jobList){
if (colomboCigri::is_cluster_active($base,"$i",0) == 0){
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
		# test if this is a ssh error
        if (NetCommon::checkSshError($base,$$i{clusterName},$cmdResult{STDERR}) != 1){
            iolibCigri::set_job_state($base,$jobId,"Event");
            # treate the SSH error
            colomboCigri::add_new_job_event($base,$jobId,"RUNNER_SUBMIT",$cmdResult{STDERR});
        }
        exit(-1);
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
			iolibCigri::set_job_state($base, $jobId, "Event");
			colomboCigri::add_new_job_event($base,$jobId,"RUNNER_JOBID_PARSE","There is a mistake, the job $jobId state = ERROR, bad remote batch id");
            exit(-1);
		}
	}
}else{
	print("[RUNNER] cluster blacklisted $$i{clusterName}\n");
}
}
iolibCigri::disconnect($base);
