package iolibCigri;
require Exporter;

use Data::Dumper;
use DBI;
#use strict;
BEGIN {
	my $scriptPath = readlink($0);
	if (!defined($scriptPath)){
		$scriptPath = $0;
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
	unshift(@INC, $relativePath."ConfLib");
	unshift(@INC, $relativePath."JDLLib");
}
use JDLParserCigri;
use ConfLibCigri qw(init_conf get_conf is_conf);

# Connect to the database and give the ref
sub connect() {
	# Connect to the database.
	ConfLibCigri::init_conf();

	my $host = ConfLibCigri::get_conf("database_host");
	my $name = ConfLibCigri::get_conf("database_name");
	my $user = ConfLibCigri::get_conf("database_username");
	my $pwd = ConfLibCigri::get_conf("database_userpassword");

	return(DBI->connect("DBI:mysql:database=$name;host=$host", $user, $pwd,	{'RaiseError' => 1}));
}

# Disconnect from the database referenced by arg1
# arg1 --> database ref
sub disconnect($) {
	my $dbh = shift;

	# Disconnect from the database.
	$dbh->disconnect();
}

# give the date in with the right pattern
sub get_date() {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}

# empty temporary tables
# arg1 --> database ref
sub emptyTemporaryTables($){
	my $dbh = shift;
	# Penser a enlever egalement les noeuds de la blacklist
	$dbh->do("TRUNCATE TABLE clusterFreeNodes");
	$dbh->do("TRUNCATE TABLE multipleJobsRemained");
	$dbh->do("TRUNCATE TABLE jobsToSubmit");
}

# Add a job to the database in multipleJobs table
# arg1 --> database ref
# arg2 --> JDLfile
# return the request id or -1 for an error
sub add_mjobs($$) {
	my ($dbh, $JDLfile) = @_;

	#$dbh->do("LOCK TABLES multipleJobs WRITE, parameters WRITE");
	my $lusr= getpwuid($<);

	my $sth = $dbh->prepare("SELECT MAX(MJobsId)+1 FROM multipleJobs");
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	my @tmp = values(%$ref);
	my $id = $tmp[0];
	$sth->finish();
	if($id eq "") {
		$id = 1;
	}

	my $time = get_date();

	my $jdl = "";
	if (defined($JDLfile) && (-r $JDLfile)){
		open(FILE, $JDLfile);
		while (<FILE>){
			$jdl = $jdl.$_;
		}
		close(FILE);
	}else{
		return(-1);
	}

	# copy params in the database
	my $Params ="";
	if (JDLParserCigri::init_jdl($jdl) == 0){
		if (defined($JDLParserCigri::clusterConf{DEFAULT}{paramFile}) && (-r $JDLParserCigri::clusterConf{DEFAULT}{paramFile})){
			open(FILE, $JDLParserCigri::clusterConf{DEFAULT}{paramFile});
			while (<FILE>){
				chomp;
				if ($_ ne ""){
					$dbh->do("INSERT INTO parameters (parametersMJobsId,parametersParam) VALUES ($id,\'$_\')");
				}
			}
			close(FILE);
		}elsif (defined($JDLParserCigri::clusterConf{DEFAULT}{nbJobs})){
			for (my $k=0; $k<$JDLParserCigri::clusterConf{DEFAULT}{nbJobs}; $k++) {
				$dbh->do("INSERT INTO parameters (parametersMJobsId,parametersParam) VALUES ($id,\'$k\')");
			}
		}else{
			print("[iolib] I can't read the param file $JDLParserCigri::clusterConf{DEFAULT}{paramFile} or the nbJobs variable\n");
			return -1;
		}
		# Update the properties table
		my @clusters = keys(%JDLParserCigri::clusterConf);
		if ($#clusters > 0){
			foreach my $j (@clusters){
				if ($j ne "DEFAULT"){
					if (defined($JDLParserCigri::clusterConf{$j}{execFile})){
						$dbh->do("INSERT INTO properties (propertiesClusterName,propertiesMJobsId,propertiesJobCmd) VALUES (\"$j\",$id,\"$JDLParserCigri::clusterConf{$j}{execFile}\")");
					}else{
						return -3;
					}
				}
			}
		}else{
			return -2;
		}
	}else{
		return -1;
	}

	$dbh->do("INSERT INTO multipleJobs (MJobsId,MJobsUser,MJobsJDL,MJobsTSub)
			VALUES ($id,\"$lusr\",\"$jdl\",\"$time\")");

	#$dbh->do("UNLOCK TABLES");
	return $id;
}

# get the cluster names in an array
# arg1 --> database ref
# return --> array of cluster names and their batch scheduler
#			The keys of the hashTable are "NAME" and "BATCH"
sub get_cluster_names_batch($)
{
	my $dbh = shift;
	my $sth = $dbh->prepare("SELECT clusterName,clusterBatch FROM clusters");
	$sth->execute();

	my @resulHash;

	while (my @ref = $sth->fetchrow_array()) {
		$resulHash{$ref[0]} = $ref[1];
	}

	$sth->finish();

	#return @resulArray;
	return %resulHash;
}

# set NODE_STATE to BUSY for all nodes of the specified cluster
# arg1 --> database ref
# arg2 --> cluster name
sub disable_all_cluster_nodes($$){
	my $dbh = shift;
	my $clusterName = shift;
	$dbh->do("UPDATE nodes SET nodeState = \'BUSY\'
					WHERE nodeClusterName = \"$clusterName\"");
}

# tests if the node exists in the database
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> node name
# return 1 if it exists else return 0
sub is_node_exist($$$){
	my $dbh = shift;
	my $clusterName = shift;
	my $nodeName = shift;

	my $sth = $dbh->prepare("SELECT * FROM nodes
								WHERE nodeClusterName = \"$clusterName\"
									and nodeName = \"$nodeName\"");
	$sth->execute();
	my @resulArray = $sth->fetchrow_array();
	$sth->finish();

	if ($#resulArray != -1){
		return 1;
	}else{
		return 0;
	}
}

# add a new node
# arg1 --> database ref
# arg2 --> cluster name
# arg2 --> node name
sub add_node($$$) {
	my ($dbh, $clusterName, $nodeName) = @_;

	$dbh->do("INSERT INTO nodes (nodeName,nodeClusterName)
				VALUES (\"$nodeName\",\"$clusterName\")");
	print("[IoLib] I create the node $nodeName in the cluster $clusterName \n");
}

# set the state of the given cluster node
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> node name
# arg4 --> state
sub set_cluster_node_state($$$$){
	my $dbh = shift;
	my $clusterName = shift;
	my $nodeName = shift;
	my $state = shift;
	# Test if the node exists
	if (is_node_exist($dbh, $clusterName, $nodeName) == 0){
		# The node is created
		add_node($dbh, $clusterName, $nodeName);
	}

	if ($state eq "free"){
		my $sth = $dbh->prepare("UPDATE nodes SET nodeState = \'FREE\'
									WHERE nodeClusterName = \"$clusterName\"
										and nodeName = \"$nodeName\"");
		$sth->execute();
		$sth->finish();
	}
}

# give the id of IN_TREATMENT state MJobs
# arg1 --> database ref
# return an array of id
sub get_IN_TREATMENT_MJobs($){
	my $dbh = shift;
	my $sth = $dbh->prepare("SELECT MJobsId FROM multipleJobs WHERE MJobsState = \'IN_TREATMENT\'");
	$sth->execute();

	my @resulArray;

	while (my @ref = $sth->fetchrow_array()) {
		push(@resulArray, $ref[0]);
	}

	$sth->finish();

	return @resulArray;
}

# give the JDL of a given MJob
# arg1 --> database ref
# arg2 --> MJobsId
# return a string or undef
sub get_MJobs_JDL($$){
	my $dbh = shift;
	my $MJobsId = shift;
	my $sth = $dbh->prepare("SELECT MJobsJDL FROM multipleJobs WHERE MJobsId = $MJobsId");
	$sth->execute();

	my @resulArray = $sth->fetchrow_array();
	$sth->finish();

	return $resulArray[0];
}

#give the cluster name of the given node
# arg1 --> database ref
# arg2 --> nodeId
# return the clusterName of the nodeId
sub get_node_cluster($$){
	my $dbh = shift;
	my $nodeId = shift;
	my $sth = $dbh->prepare("SELECT nodeClusterName FROM nodes WHERE nodeId = $nodeId");
	$sth->execute();
	my @resulArray = $sth->fetchrow_array();
	$sth->finish();

	return $resulArray[0];
}

# FIFO scheduler scpecific code
#sub select_sched_FIFO($){
#	my $dbh = shift;
#	my $sth = $dbh->prepare("SELECT potentialJobNodeMJobsId,potentialJobNodeNodeId,parametersParam
#								FROM potentialJobNode,parameters
#								WHERE potentialJobNodeMJobsId = parametersMJobsId LIMIT 0,1");
#	$sth->execute();
#
#	my @resulArray = $sth->fetchrow_array();
#	$sth->finish();
#
#	if (defined($resulArray[1])){
#		$dbh->do("UPDATE nodes SET nodeState = \"BUSY\" WHERE nodeId = $resulArray[1]");
#		$dbh->do("DELETE FROM parameters WHERE parametersMJobsId = $resulArray[0]
#											AND parametersParam = \"$resulArray[2]\" LIMIT 1");
#		my $time = get_date();
#		my $cluster = get_node_cluster($dbh, $resulArray[1]);
#		my $JDLtmp = get_MJobs_JDL($dbh, $resulArray[0]);
#		print("[IOLIB] Parse mistake with the MJobs $resulArray[0]\n") if (JDLParserCigri::init_jdl($JDLtmp) == -1);
#
#		$dbh->do("INSERT INTO jobs (jobState,jobMJobsId,jobParam,jobNodeId,jobTSub)
#					VALUES (\"toLaunch\",$resulArray[0],\"$resulArray[2]\",$resulArray[1],\"$time\")");
#		return 0;
#	}else{
#		return 1;
#	}
#}

# give the jobs to launch
# arg1 --> database ref
# return an array of hashtables
sub get_launching_job($) {
	my $dbh = shift;
	my $sth = $dbh->prepare("SELECT jobId,jobParam,nodeName,propertiesJobCmd,nodeClusterName,clusterBatch,MJobsUser
							FROM jobs,nodes,clusters,multipleJobs,properties
							WHERE jobState=\"toLaunch\"
								AND jobNodeId = nodeId
								AND nodeClusterName = clusterName
								AND MJobsId = jobMJobsId
								AND propertiesClusterName = clusterName
								And propertiesMJobsId = MJobsId");
	$sth->execute();

	my @result ;
	while (my @ref = $sth->fetchrow_array()){
		my %hash = (
			'id'			=> $ref[0],
			'param'			=> $ref[1],
			'node'			=> $ref[2],
			'cmd'			=> $ref[3],
			'clusterName'	=> $ref[4],
			'batch'			=> $ref[5],
			'user'			=> $ref[6]
		);
		push(@result, \%hash);
	}

	$sth->finish();

	return @result;
}

# set the state of a job
# arg1 --> database ref
# arg2 --> jobId
# arg3 --> state
sub set_job_state($$$) {
	my $dbh = shift;
	my $idJob = shift;
	my $state = shift;
	my $sth = $dbh->prepare("UPDATE jobs SET jobState = \"$state\"
								WHERE jobId =\"$idJob\"");
	$sth->execute();
	$sth->finish();
}

# set the batch id of a job
# arg1 --> database ref
# arg2 --> jobId
# arg3 --> remote batch id
sub set_job_batch_id($$$){
	my $dbh = shift;
	my $idJob = shift;
	my $batchId = shift;
	my $sth = $dbh->prepare("UPDATE jobs SET jobBatchId = \"$batchId\"
								WHERE jobId =\"$idJob\"");
	$sth->execute();
	$sth->finish();
}

# give cluster names where jobs in Running state are executed
# arg1 --> database ref
# return a hashtable of array refs : ${${$resul{pawnee}}[0]}{batchJobId} --> give the first batchId for the cluster pawnee
sub get_job_to_update_state($){
	my $dbh = shift;
	my $sth = $dbh->prepare("	SELECT jobBatchId,nodeClusterName,jobId
								FROM jobs,nodes
								WHERE (jobState = \"Running\" or jobState = \"RemoteWaiting\") and jobNodeId = nodeId");
	$sth->execute();

	my %resul;

	while (my @ref = $sth->fetchrow_array()) {
		my $tmp = {
					"jobId" => $ref[2],
					"batchJobId" => $ref[0]
		};
		push(@{$resul{$ref[1]}},$tmp);
	}
	$sth->finish();

	return %resul;
}

# update the number of free nodes for each cluster and the remained MJobs number
# arg1 --> database ref
sub update_nb_freeNodes($){
	my $dbh = shift;

	emptyTemporaryTables($dbh);

	my $sth = $dbh->prepare("	SELECT nodeClusterName, COUNT(*)
								FROM nodes
								WHERE nodeState = \"FREE\"
								GROUP BY nodeClusterName");
	$sth->execute();

	my %resultNode;
	while (my @ref = $sth->fetchrow_array()) {
		$resultNode{$ref[0]} = $ref[1];
	}

	$sth->finish();

	$sth = $dbh->prepare("	SELECT nodeClusterName, COUNT(*)
							FROM nodes,jobs
							WHERE nodeId = jobNodeId
							AND jobState = \"RemoteWaiting\"
							GROUP BY nodeClusterName");
	$sth->execute();

	my %resultJob;
	while (my @ref = $sth->fetchrow_array()) {
		$resultJob{$ref[0]} = $ref[1];
	}

	$sth->finish();
	foreach my $i (keys(%resultNode)){
		my $tmpNumber;
		if (defined($resultJob{$i})){
			$tmpNumber= $resultNode{$i} - $resultJob{$i};
		}else{
			$tmpNumber = $resultNode{$i};
		}
		$dbh->do("INSERT INTO clusterFreeNodes (clusterFreeNodesClusterName,clusterFreeNodesNumber)
					VALUES (\"$i\",$tmpNumber)");
	}

	$sth = $dbh->prepare("	SELECT parametersMJobsId, COUNT(*)
							FROM parameters,multipleJobs
							WHERE MJobsId = parametersMJobsId
							AND MJobsState = \"IN_TREATMENT\"
							GROUP BY parametersMJobsId");
	$sth->execute();
	my %resultNbRemainedMJob;
	while (my @ref = $sth->fetchrow_array()) {
		$resultNbRemainedMJob{$ref[0]} = $ref[1];
	}
	$sth->finish();

	foreach my $i (keys(%resultNbRemainedMJob)){
		my $tmpNumber = $resultNbRemainedMJob{$i};
		$dbh->do("INSERT INTO multipleJobsRemained (multipleJobsRemainedMJobsId,multipleJobsRemainedNumber)
					VALUES (\"$i\",$tmpNumber)");
	}
}

# get the number of free nodes for each cluster
# arg1 --> database ref
sub get_nb_freeNodes($){
	my $dbh = shift;

	my $sth = $dbh->prepare("	SELECT clusterFreeNodesClusterName, clusterFreeNodesNumber
								FROM clusterFreeNodes");
	$sth->execute();

	my %result;
	while (my @ref = $sth->fetchrow_array()) {
		$result{$ref[0]} = $ref[1];
	}
	$sth->finish();

	return %result;
}

# get the number of remained jobs for MJobs
# arg1 --> database ref
sub get_nb_remained_jobs($){
	my $dbh = shift;

	my $sth = $dbh->prepare("	SELECT  multipleJobsRemainedMJobsId, multipleJobsRemainedNumber
								FROM multipleJobsRemained");
	$sth->execute();

	my %result;
	while (my @ref = $sth->fetchrow_array()) {
		$result{$ref[0]} = $ref[1];
	}
	$sth->finish();

	return %result;
}

# get MJobs properties
# arg1 --> database ref
# arg2 --> MJobsId
sub get_MJobs_Properties($$){
	my $dbh = shift;
	my $id = shift;

	my $sth = $dbh->prepare("	SELECT   propertiesClusterName
								FROM properties
								WHERE propertiesMJobsId = $id");
	$sth->execute();

	my @result;
	while (my @ref = $sth->fetchrow_array()) {
		push(@result, $ref[0]);
	}
	$sth->finish();

	return @result;
}

# Add a job to launch
# arg1 --> database ref
# arg2 --> MJobsId of the job
# arg3 --> clustername where to launch
# arg4 --> number of jobs
sub add_job_to_launch($$$$){
	my $dbh = shift;
	my $MJobsId = shift;
	my $clusterName = shift;
	my $number = shift;

	$dbh->do("INSERT INTO jobsToSubmit (jobsToSubmitMJobsId,jobsToSubmitClusterName,jobsToSubmitNumber) VALUES ($MJobsId,\"$clusterName\",$number)");
}

# create jobs with the content of the jobsToSubmit table
# arg1 --> database ref
sub create_toLaunch_jobs($){
	my $dbh = shift;

	my $sth = $dbh->prepare("	SELECT jobsToSubmitMJobsId,jobsToSubmitClusterName,jobsToSubmitNumber
								FROM jobsToSubmit");

	$sth->execute();

	my @result;
	while (my $ref = $sth->fetchrow_hashref()) {
		push(@result, $ref);
	}
	$sth->finish();

	emptyTemporaryTables($dbh);

	my $time;
	my $query;
	foreach my $i (@result){
		# get parameters for this MJobs on this cluster
		$sth = $dbh->prepare("SELECT parametersParam
								FROM parameters
								WHERE $i->{jobsToSubmitMJobsId} = parametersMJobsId LIMIT 0,$i->{jobsToSubmitNumber}");
		$sth->execute();
		my @parametersTmp;
		while (my @ref = $sth->fetchrow_array()) {
			push(@parametersTmp, $ref[0]);
		}
		$sth->finish();

		if (scalar(@parametersTmp) != $i->{jobsToSubmitNumber}){
			warn("[Iolib] Erreur de choix du scheduler pour le nb de parametres\n");
			return 1;
		}

		# get right nodes
		$sth = $dbh->prepare("	SELECT nodeId
								FROM nodes
								WHERE nodeState = \"FREE\"
								AND nodeClusterName = \"$i->{jobsToSubmitClusterName}\"
								LIMIT $i->{jobsToSubmitNumber}
								");
		$sth->execute();
		my @nodesTmp;
		while (my @ref = $sth->fetchrow_array()) {
			push(@nodesTmp, $ref[0]);
		}
		$sth->finish();

		if (scalar(@nodesTmp) != $i->{jobsToSubmitNumber}){
			warn("[Iolib] Erreur de choix du scheduler pour le nb de noeuds\n");
			return 1;
		}

		for (my $j=0; $j < $i->{jobsToSubmitNumber}; $j++){
			#add jobs in jobs table
			$time = get_date();
			$dbh->do("	INSERT INTO jobs (jobState,jobMJobsId,jobParam,jobNodeId,jobTSub)
						VALUES (\"toLaunch\",$i->{jobsToSubmitMJobsId},$parametersTmp[$j],$nodesTmp[$j],\"$time\")");
		}
		# delete used params
		$query = "";
		foreach my $k (@parametersTmp){
			$query .= " OR parametersParam = \"$k\"";
		}
		#remove first OR or of the query
		$query =~ /\sOR\s(.*)/;
		$query = $1;
		$dbh->do("	DELETE FROM parameters
					WHERE parametersMJobsId = $i->{jobsToSubmitMJobsId}
					AND ( $query )
				");
		# set to BUSY used nodes
		$query = "";
		foreach my $k (@nodesTmp){
			$query .= " OR nodeId = $k";
		}
		#remove first OR or of the query
		$query =~ /\sOR\s(.*)/;
		$query = $1;
		$dbh->do("UPDATE nodes SET nodeState = \"BUSY\" WHERE $query");

	}
}

# check and set the end of each MJob in the IN_TREATMENT state
# arg1 --> database ref
sub check_end_MJobs($){
	my $dbh = shift;
	my @MJobs = get_IN_TREATMENT_MJobs($dbh);

	foreach my $i (@MJobs){
		$sth = $dbh->prepare("	SELECT jobMJobsId, count( * )
								FROM jobs
								WHERE jobMJobsId = $i
								AND jobState != \"Terminated\"
								GROUP BY jobMJobsId
								");
		$sth->execute();
		my @MJobIdTmp = $sth->fetchrow_array();
		$sth->finish();
		if (!@MJobIdTmp){
			# all jobs are terminated
			$sth = $dbh->prepare("	SELECT count( * )
									FROM parameters
									WHERE parametersMJobsId = $i
								");
			$sth->execute();
			my @nbParamsMJob = $sth->fetchrow_array();
			$sth->finish();
			if ($nbParamsMJob[0] == 0){
				print("[Iolib] set to Terminated state the MJob $i\n");
				$dbh->do("	UPDATE multipleJobs SET MJobsState = \"TERMINATED\"
							WHERE MJobsId = $i");
			}
		}
	}
}

