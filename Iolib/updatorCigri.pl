#!/usr/bin/perl -w

# Tool to update NODE_STATE in the database

#use strict;
#no strict 'refs';
use IPC::Open3;
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
	unshift(@INC, $relativePath."Iolib");
	unshift(@INC, $relativePath."Net");
}
use iolibCigri;
use Net::SSH;

select(STDOUT);
$|=1;

# line to print after a ssh command. With that we can know the end of the comman;
my $endLineTag = "lacommandeestterminee";

# List of pbsnodes commands
my %pbsCommand = ( 	'PBS' => 'pbsnodes -a',
					'OAR' => 'pbsnodes.pl -a' );

my %qstatCmd = ( 	'PBS' => 'qstat -f',
					'OAR' => 'qstat.pl -f' );


my $base = iolibCigri::connect();

# Get cluster names
my %clusterNames = iolibCigri::get_cluster_names_batch($base);

my %sshConnections;
my $fileHandleId = 0;

#Connect and set ssh filehansles
# arg1 --> destination connection
sub initSSHConnection($){
	my $server = shift;
	my $i = $fileHandleId;
	$fileHandleId++;
	my $j = $fileHandleId;
	$fileHandleId++;
	my $k = $fileHandleId;
	$fileHandleId++;
	open3( $i, $j, $k, "ssh -T $server");
	$sshConnections{$server} = [ $i, $j, $k];

	#init connection
	print($i "/bin/sh -c \"echo $endLineTag\"\n");
	do {
		$_ = <$j>;
		chomp;
		#print($_."\n");
	} until("$_" eq "$endLineTag");
	print("[Updator] SSH connection to $server is established\n");
}

# submit a command to the given cluster
# arg1 --> clusterName
# arg2 --> command
sub submitCmd($$){
	my $clusterName = shift;
	my $command = shift;
	if (!defined($sshConnections{$clusterName})){
		initSSHConnection($clusterName);
	}
	my $fd0 = $sshConnections{$clusterName}->[0];
	my $fd1 = $sshConnections{$clusterName}->[1];
	my $fd2 = $sshConnections{$clusterName}->[2];

	print($fd0 "$command ; echo $endLineTag\n");

	my $READERStr = "";
	$_ = "";
	while ("$_" ne "$endLineTag") {
		$READERStr .= $_."\n";
		$_ = <$fd1>;
		chomp($_);
	};
	$READERStr = substr($READERStr,1);

	#Test error filehandle
	my $ERRORStr = "";
	my $rin = '';
	my $timeout = 0.25;
	vec($rin,fileno($fd2),1) = 1;
	my $res = select($rin, undef, undef, $timeout);
	while ($res > 0) {
		$_ = <$fd2>;
		$ERRORStr .= $_."\n";
		$rin = '';
		vec($rin,fileno($fd2),1) = 1;
		$res = select($rin, undef, undef, $timeout);
	}

	my %result = (
		'STDOUT' => $READERStr,
		'STDERR' => $ERRORStr
	);

	return %result;
}

# Exec through ssh : pbsnodes command
foreach my $i (keys(%clusterNames)){
	print("[UPDATOR] Query free nodes on $i which has a batch-scheduler of the type : $clusterNames{$i}\n");
#	Net::SSH::sshopen3($i, *WRITER, *READER, *ERROR, $pbsCommand{$clusterNames{$i}}) || die "[UPDATOR] ssh ERROR : $!";
	my %cmdResult = submitCmd($i,"$pbsCommand{$clusterNames{$i}}");

	my $pbsnodesStr = $cmdResult{STDOUT};
	# update database
	iolibCigri::disable_all_cluster_nodes($base, $i);

	#print($pbsnodesStr);

	if ($cmdResult{STDERR} eq ""){
		chomp($pbsnodesStr);
		my @nodesStrs = split(/^\s*\n/m,$pbsnodesStr);
		#print(Dumper(@nodesStrs));
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
				print("[UPDATOR] There is an error in the pbsnodes command parse, node=$name;state=$state\n");
			}
		}
	}else{
		print("[UPDATOR_ERROR] There is an error in the execution of the pbsnodes command via SSH \n--> I disable all nodes of the cluster $i \n");
		print("[UPDATOR_ERROR] $cmdResult{STDERR}\n");
	}
}

# Update jobs which are in the Running state
my %jobRunningHash = iolibCigri::get_job_to_update_state($base);
print("[UPDATOR] Verify if Running jobs are still running:\n");
# Exec qstat cmd for all clusters which have a running job
foreach my $i (keys(%jobRunningHash)){
	print("\tcluster = $i\n");
	my %cmdResult = submitCmd($i,"$qstatCmd{$clusterNames{$i}}");
	my $errorFlag = 0;
	my %jobState = ();
	if ($cmdResult{STDERR} ne ""){
		print("\t[UPDATOR_ERROR] $cmdResult{STDERR}\n");
	}else{
		my $qstatStr = $cmdResult{STDOUT};
		chomp($qstatStr);
		my @jobsStrs = split(/^s*\n/m,$qstatStr);
		# for each job section, record its state
		foreach my $jobStr (@jobsStrs){
			#print("--> $jobStr\n");
			$jobStr =~ /Job Id: (\d+).*job_state = (.).*/s;
			$jobState{$1} = $2;
		}
	}
	foreach my $j (@{$jobRunningHash{$i}}){
		# Verify if the job is still running on the cluster $i
		if (!defined($jobState{${$j}{batchJobId}})){
			# Check the result file on the cluster
			my $remoteFile = "~${$j}{user}/cigri.${$j}{jobId}.log";
			#; sudo -u ${$j}{user} rm $remoteFile
			print("[Updator] Check the job ${$j}{jobId} \n");
			#Net::SSH::sshopen3($i, *WRITER, *READER, *ERROR, "cat $remoteFile") || die "[UPDATOR] ssh ERROR : $!";
			my %cmdResult2 = submitCmd($i,"cat $remoteFile");
			if ($cmdResult2{STDERR} ne ""){
				print("\t[UPDATOR_ERROR] Can't check the remote file\n");
					print("\t[UPDATOR_STDERR] $cmdResult2{STDERR}");
				# Can t read the file
				iolibCigri::set_job_state($base, ${$j}{jobId}, "Killed");
				iolibCigri::resubmit_job($base,${$j}{jobId});
			}else{
				my @strTmp = split(/\n/, $cmdResult2{STDOUT});
				my %fileVars;
				foreach my $k (@strTmp){
					if ($k =~ m/\s*(.+)\s*=\s*(.+)\s*/m){
						$fileVars{$1} = $2;
					}
				}
				print(Dumper(%fileVars));
				if ($fileVars{FINISH} == 1){
					iolibCigri::update_att_job($base,${$j}{jobId},$fileVars{BEGIN_DATE},$fileVars{END_DATE},$fileVars{RET_CODE});
					if ($fileVars{RET_CODE} == 0){
						print("\t\tJob ${$j}{jobId} Terminated\n");
						iolibCigri::set_job_state($base, ${$j}{jobId}, "Terminated");
					}else{
						print("\t\tJob ${$j}{jobId} Error\n");
						# mettre a jour egalement la base des erreurs
						iolibCigri::set_job_state($base, ${$j}{jobId}, "Error");
					}
				}else{
					# le job a ete kille par le batch scheduler
					# soit il etait trop long(erreur), soit un autre job a pris sa place(on remet le parametre dans la file)
					iolibCigri::set_job_state($base, ${$j}{jobId}, "Killed");
					iolibCigri::resubmit_job($base,${$j}{jobId});
				}
			}
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

iolibCigri::update_nb_freeNodes($base);

iolibCigri::disconnect($base);

