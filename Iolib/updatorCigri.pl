#!/usr/bin/perl -w -I ../ConfLib -I . -I ../JDLLib -I ..

# Tool to update NODE_STATE in the database

use strict;

use Data::Dumper;
use iolibCigri;
use Net::SSH;

# List of pbsnodes commands
my %pbsCommand = ( 	'PBS' => 'pbsnodes -a',
					'OAR' => 'pbsnodes.pl -a' );

my %qstatCmd = ( 	'PBS' => 'qstat -f',
					'OAR' => 'qstat.pl -f' );


my $base = iolibCigri::connect();

# Get cluster names
my %clusterNames = iolibCigri::get_cluster_names_batch($base);

# Exec through ssh : pbsnodes command
foreach my $i (keys(%clusterNames)){
	print("[UPDATOR] Query free nodes on $i which has a batch-scheduler of the type : $clusterNames{$i}\n");
	Net::SSH::sshopen3($i, *WRITER, *READER, *ERROR, $pbsCommand{$clusterNames{$i}}) || die "[UPDATOR] ssh ERROR : $!";

	# update database
	iolibCigri::disable_all_cluster_nodes($base, $i);

	# Don t bloc ERROR reading

#$rin = '';
#vec($rin,fileno(READER),1) = 1;
#$res = select($rin, undef, undef, $internaltimeout);

	my $pbsnodesStr = join("",<READER>);

	if (! defined(<ERROR>)){
		chomp($pbsnodesStr);
		my @nodesStrs = split(/^\s*\n/m,$pbsnodesStr);
		foreach my $nodeStr (@nodesStrs){
			my @lines = split(/\n/, $nodeStr);
			my $name = shift(@lines);
			$name =~ s/\s//g;
			my $state;
			my $lineTmp;
			my $key;
			while ((! defined($state)) && ($#lines >= 0)){
				$lineTmp = shift(@lines);
				if ($lineTmp =~ /state =/){
					($key, $state) = split("=", $lineTmp);
					# I drop spaces
					$state =~ s/\s//g;
				}
			}
			if (defined($name) && defined($state)){
				# Databse update
				iolibCigri::set_cluster_node_state($base, $i, $name, $state);
				#print("$name --> $state\n");
			}else{
				print("[UPDATOR] : There is an error in the pbsnodes command parse, node=$name;state=$state\n");
			}
		}
	}else{
		print("[UPDATOR] There is an error in the execution of the pbsnodes command via SSH \n--> I disable all nodes of the cluster $i \n");
		while (<ERROR>){
			print("[UPDATOR]$_");
		}
	}

	close(READER);
	close(WRITER);
	close(ERROR);
}

# Update jobs which are in the Running state
my %jobRunningHash = iolibCigri::get_job_to_update_state($base);
print("[UPDATOR] Verify if Running jobs are still running:\n");
# Exec qstat cmd for all clusters which have a running job
foreach my $i (keys(%jobRunningHash)){
	print("\tcluster = $i\n");
	Net::SSH::sshopen3($i, *WRITER, *READER, *ERROR, $qstatCmd{$clusterNames{$i}}) || die "[UPDATOR] ssh ERROR : $!";
	close(WRITER);
	my $errorFlag = 0;
	my %jobState = ();
	if (defined(<ERROR>)){
		while(<ERROR>){
			print("\t[UPDATOR_STDERR]$_");
		}
		close(ERROR);
		$errorFlag = 1;
	}else{
		my $qstatStr = join("",<READER>);
		chomp($qstatStr);
		my @jobsStrs = split(/^s*\n/m,$qstatStr);
		# for each job section, record its state
		foreach my $jobStr (@jobsStrs){
			#print("--> $jobStr\n");
			$jobStr =~ /Job Id: (\d+).*job_state = (.).*/s;
			$jobState{$1} = $2;
		}
		close(READER);
	}
	foreach my $j (@{$jobRunningHash{$i}}){
		# Verify if the job is still running on the cluster $i
		if (!defined($jobState{${$j}{batchJobId}})){
			print("\t\tJob ${$j}{jobId} Terminated\n");
			iolibCigri::set_job_state($base, ${$j}{jobId}, "Terminated");
			# Increment MJobsNbCompletedJobs
			#iolibCigri::inc_MJobsNbCompletedJobs($base,${$j}{jobId});
		}else{
			#verify if the job is waiting
			if ($jobState{${$j}{batchJobId}} eq "W"){
				iolibCigri::set_job_state($base, ${$j}{jobId}, "RemoteWaiting");
			}else{
				iolibCigri::set_job_state($base, ${$j}{jobId}, "Running");
			}
		}
	}
}

iolibCigri::check_end_MJobs($base);

#iolibCigri::pre_schedule($base);
iolibCigri::update_nb_freeNodes($base);

iolibCigri::disconnect($base);

