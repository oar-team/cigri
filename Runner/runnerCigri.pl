#! /usr/bin/perl -I ../Iolib -I ../ConfLib -I . -I ../JDLLib -I ..
use strict;
use Data::Dumper;
use IO::Socket::INET;
use iolibCigri;
use Net::SSH;


# List of pbsnodes commands
my %qsubCommand = ( 'PBS' => 'qsub',
					'OAR' => 'qsub.pl' );

my $base = iolibCigri::connect() ;

sub forkSSH ($$$$){
	my $cluster = shift;
	my $jobId = shift;
	my $batch = shift;
	my $cmdref = shift;
	my @cmd = @$cmdref;
	my $pid = 0;

	$pid = fork();
	if($pid eq "undef"){
		$pid = -1;
	}
	if($pid != 0){
		#father
		$SIG{CHLD} = "IGNORE";
		return $pid;
	}else{
		#child
		print("[RUNNER] I launch the job $jobId on the cluster $cluster\n");
		Net::SSH::sshopen3($cluster, *WRITER, *READER, *ERROR, @cmd) || die "[RUNNER] ssh ERROR : $!";
		close(WRITER);
		if (defined(<ERROR>)){
			while(<ERROR>){
				print("[RUNNER_STDERR]$_");
			}
			close(ERROR);
			iolibCigri::set_job_state($base,$jobId,"Error");
		}elsif (defined(<READER>)){
			while (<READER>){
				if (($batch eq "OAR") and ($_ =~ /\s*IdJob\s=\s(\d+)/)){
					iolibCigri::set_job_batch_id($base,$jobId,$1);
				}
				print("[RUNNER_STDOUT] $_");
			}
			close(READER);
			iolibCigri::set_job_state($base,$jobId,"Running");
		}else{
			print("[RUNNER] There is a mistake, the job $jobId state is unchanged\n");
		}
		exit 0;
	}
	return $pid;
}

# treate the scheduler output in the jobsToSubmit table
exit 1 if (iolibCigri::create_toLaunch_jobs($base) == 1);

my @jobList = iolibCigri::get_launching_job($base);

my $jobId;
my $jobtype;
my $jobinfo;

my $tmpRemoteFile ;

select(STDOUT);
$| = 1;

foreach my $i (@jobList){
	$jobId = $$i{id};
	$tmpRemoteFile = "cigri.tmp.$jobId";
	print("[RUNNER] The job $jobId is in treatment...\n");

	#iolibCigri::set_job_state($base,$jobId,"Launching");

	my @cmdSSH = ();

	if ($$i{batch} eq "OAR"){
		@cmdSSH = (	"echo \\#\\!/bin/sh > ~/$tmpRemoteFile;",
					"echo $$i{cmd} $$i{param} >> ~/$tmpRemoteFile;",
					"echo rm ~$$i{user}/$tmpRemoteFile >> ~/$tmpRemoteFile;",
					"chmod +x ~/$tmpRemoteFile ;",
					"cd ~$$i{user} ;",
					"sudo -u $$i{user} /bin/cp ~/$tmpRemoteFile . ;",
					"rm ~/$tmpRemoteFile ;",
					"sudo -u $$i{user} $qsubCommand{$$i{batch}} -l nodes=1 `pwd`/$tmpRemoteFile;"
		);
	}else{
		@cmdSSH = (	"echo \\#\\!/bin/sh > ~/$tmpRemoteFile;",
					"echo $$i{cmd} $$i{param} >> ~/$tmpRemoteFile;",
					"echo rm ~$$i{user}/$tmpRemoteFile >> ~/$tmpRemoteFile;",
					"chmod +x ~/$tmpRemoteFile ;",
					"cd ~$$i{user} ;",
					"sudo -u $$i{user} /bin/cp ~/$tmpRemoteFile . ;",
					"rm ~/$tmpRemoteFile ;",
					"$qsubCommand{$$i{batch}} -l nodes=$$i{node} $tmpRemoteFile;"
		);
	}
	if(defined(@cmdSSH)){
		#print("[RUNNER]".Dumper(@cmdSSH)."\n");
		forkSSH($$i{clusterName},$jobId,$$i{batch},\@cmdSSH);
	}
}
#wait;

iolibCigri::disconnect($base);
