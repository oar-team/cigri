package colomboCigri;

#This module gives an API to manage all events in the grid

use strict;
use Data::Dumper;
use DBI;
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

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(add_new_event);


# give the date in with the right pattern
sub get_date() {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}

# calculate the id of the next event
# arg1 --> database ref
sub calculate_event_id($){
	my $dbh = shift;
	my $sth = $dbh->prepare("SELECT MAX(eventId)+1 FROM events");
	$sth->execute();
	my $ref = $sth->fetchrow_hashref();
	my @tmp = values(%$ref);
	my $id = $tmp[0];
	$sth->finish();
	if($id eq "") {
		$id = 1;
	}
	return $id;
}

# add a new event relative of a cluster in the database and treate it
# arg1 --> database ref
# arg2 --> clusterName on which event occured
# arg3 --> MJobsId relative of this event (0 if it is for all MJobs)
# arg4 --> event Type
# arg5 --> descriptive message
sub add_new_cluster_event($$$$$){
	my $dbh = shift;
	my $clusterName = shift;
	my $MJobsId = shift;
	my $eventType = shift;
	my $eventMessage = shift;

	$dbh->do("LOCK TABLES events WRITE");
	$dbh->begin_work;

	my $id = calculate_event_id($dbh);
	my $time = get_date();
	$dbh->do("	INSERT INTO events (eventId,eventType,eventClass,eventClusterName,eventMJobsId,eventDate,eventMessage)
				VALUES ($id,\"$eventType\",\"CLUSTER\",\"$clusterName\",$MJobsId,\"$time\",\"$eventMessage\")");

	$dbh->commit;
	$dbh->do("UNLOCK TABLES");

	check_events();
}

# add a new event relative of a job in the database and treate it
# arg1 --> database ref
# arg2 --> jobId on which event occured
# arg4 --> event Type
# arg5 --> descriptive message
sub add_new_job_event($$$$){
	my $dbh = shift;
	my $jobId = shift;
	my $eventType = shift;
	my $eventMessage = shift;

	$dbh->do("LOCK TABLES events WRITE");
	$dbh->begin_work;

	my $id = calculate_event_id($dbh);
	my $time = get_date();
	$dbh->do("	INSERT INTO events (eventId,eventType,eventClass,eventJobId,eventDate,eventMessage)
				VALUES ($id,\"$eventType\",\"JOB\",\"$jobId\",\"$time\",\"$eventMessage\")");

	$dbh->commit;
	$dbh->do("UNLOCK TABLES");

	check_events();
}

# add a new event relative of a scheduler in the database and treate it
# arg1 --> database ref
# arg2 --> schedulerId on which event occured
# arg4 --> event Type
# arg5 --> descriptive message
sub add_new_scheduler_event($$$$){
	my $dbh = shift;
	my $schedId = shift;
	my $eventType = shift;
	my $eventMessage = shift;

	$dbh->do("LOCK TABLES events WRITE");
	$dbh->begin_work;

	my $id = calculate_event_id($dbh);
	my $time = get_date();
	$dbh->do("	INSERT INTO events (eventId,eventType,eventClass,eventSchedulerId,eventDate,eventMessage)
				VALUES ($id,\"$eventType\",\"SCHEDULER\",\"$schedId\",\"$time\",\"$eventMessage\")");

	$dbh->commit;
	$dbh->do("UNLOCK TABLES");

	check_events();
}

# test if the cluster is active for the MJob
# arg1 --> database ref
# arg2 --> clusterName
# arg3 --> MJobsId
# return the number of blacklist
sub is_cluster_active($$$){
	my $dbh = shift;
	my $clusterName = shift;
	my $MJobId = shift;

	my $sth = $dbh->prepare("	SELECT count( * )
								FROM clusterBlackList, events
								WHERE clusterBlackListEventId = eventId
									AND eventState = \"ToFIX\"
									AND clusterBlackListClusterName = \"$clusterName\"
									AND (clusterBlackListMJobsID = $MJobId
										OR clusterBlackListMJobsID = 0)
								");
	$sth->execute();
	my @numErrors = $sth->fetchrow_array();
	$sth->finish();

	return $numErrors[0];
}

# test if the node is active for the MJob
# arg1 --> database ref
# arg2 --> nodeId
# arg3 --> MJobsId
# return the number of blacklist
sub is_node_active($$$){
	my $dbh = shift;
	my $nodeId = shift;
	my $MJobId = shift;

	my $sth = $dbh->prepare("	SELECT count( * )
								FROM nodeBlackList, events
								WHERE nodeBlackListEventId = eventId
									AND eventState = \"ToFIX\"
									AND nodeBlackListNodeId = $nodeId
									AND (nodeBlackListMJobsID = $MJobId
										OR nodeBlackListMJobsID = 0)
								");
	$sth->execute();
	my @numErrors = $sth->fetchrow_array();
	$sth->finish();

	return $numErrors[0];
}

# test if the user is active for the cluster
# arg1 --> database ref
# arg2 --> userName
# arg3 --> clusterName
# return the number of blacklist
sub is_user_active($$$){
	my $dbh = shift;
	my $userName = shift;
	my $clusterName = shift;

	my $sth = $dbh->prepare("	SELECT count( * )
								FROM userBlackList, events
								WHERE userBlackListEventId = eventId
									AND eventState = \"ToFIX\"
									AND userBlackListUserGridName = \"$userName\"
									AND (userBlackListClusterName = \"$clusterName\"
										OR userBlackListClusterName = \"ALL\")
								");
	$sth->execute();
	my @numErrors = $sth->fetchrow_array();
	$sth->finish();

	return $numErrors[0];
}

# test if the collect is active for the MJob and the cluster
# arg1 --> database ref
# arg2 --> MJobsId
# arg3 --> clusterName
sub is_collect_active($$$){
	my $dbh = shift;
	my $MJobsId = shift;
	my $clusterName = shift;

	my $sth = $dbh->prepare("	SELECT count( * )
								FROM collectBlackList, events
								WHERE collectBlackListEventId = eventId
									AND eventState = \"ToFIX\"
									AND (collectBlackListMJobsId = \"$MJobsId\"
										OR collectBlackListMJobsId = 0)
									AND (collectBlackListClusterName = \"$clusterName\"
										OR collectBlackListClusterName = \"ALL\")
								");
	$sth->execute();
	my @numErrors = $sth->fetchrow_array();
	$sth->finish();

	return $numErrors[0];
}

# check events in the database and decide actions to perform
sub check_events(){
	print("I check events\n");
}

return 1;
