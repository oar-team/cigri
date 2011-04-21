package colomboCigri;

#This module gives an API to manage all events in the grid

use strict;
use Data::Dumper;
use DBI;
use IO::File;
use POSIX qw(tmpnam);


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
    unshift(@INC, $relativePath."Mailer");
}
use mailer;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(add_new_cluster_event add_new_mjob_event add_new_job_event add_new_scheduler_event is_cluster_active is_node_active is_user_active is_collect_active is_scheduler_active fix_event);


# give the date in with the right pattern
sub get_date() {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}

# calculate the id of the next event
# arg1 --> database ref
#sub calculate_event_id($){
#    my $dbh = shift;
#    my $sth = $dbh->prepare("SELECT MAX(eventId)+1 FROM events");
#    $sth->execute();
#    my $ref = $sth->fetchrow_hashref();
#    my @tmp = values(%$ref);
#    my $id = $tmp[0];
#    $sth->finish();
#    if(!defined($id)) {
#        $id = 1;
#    }
#    return $id;
#}

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

    #$dbh->do("LOCK TABLES events WRITE");
    $dbh->begin_work;

    #my $id = calculate_event_id($dbh);
    my $time = get_date();
    $eventMessage = $dbh->quote($eventMessage);
    $dbh->do("    INSERT INTO events (eventId,eventType,eventClass,eventClusterName,eventMJobsId,eventDate,eventMessage)
                VALUES (NULL,\"$eventType\",\"CLUSTER\",\"$clusterName\",$MJobsId,\"$time\",\"$eventMessage\")");
    
    #$dbh->do("UNLOCK TABLES");
    $dbh->commit;

    check_events($dbh);
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
    my $eventMessage =  $dbh->quote(shift);

    my $sth = $dbh->prepare("SELECT jobMJobsId,jobClusterName
                             FROM jobs
                             WHERE jobId = $jobId
                            ");
    $sth->execute();
    my @refJob = $sth->fetchrow_array();
    $sth->finish();

    #$dbh->do("LOCK TABLES events WRITE");
    $dbh->begin_work;

    #my $id = calculate_event_id($dbh);
    my $time = get_date();
    $dbh->do("    INSERT INTO events (eventId,eventType,eventClass,eventJobId,eventDate,eventMessage,eventMJobsId,eventClusterName)
                VALUES (NULL,\"$eventType\",\"JOB\",\"$jobId\",\"$time\",\"$eventMessage\",$refJob[0],\"$refJob[1]\")");

    #$dbh->do("UNLOCK TABLES");
    $dbh->commit;

    check_events($dbh);
}

# add a new event relative of a MJob in the database and treate it
# arg1 --> database ref
# arg2 --> MJobsId on which event occured
# arg4 --> event Type
# arg5 --> descriptive message
sub add_new_mjob_event($$$$){
    my $dbh = shift;
    my $mjobId = shift;
    my $eventType = shift;
    my $eventMessage = shift;

    #$dbh->do("LOCK TABLES events WRITE");
    $dbh->begin_work;

    #my $id = calculate_event_id($dbh);
    my $time = get_date();
    $dbh->do("    INSERT INTO events (eventId,eventType,eventClass,eventMJobsId,eventDate,eventMessage)
                VALUES (NULL,\"$eventType\",\"MJOB\",\"$mjobId\",\"$time\",\"$eventMessage\")");

    #$dbh->do("UNLOCK TABLES");
    $dbh->commit;

    check_events($dbh);
}

#OLDSCHED-------------------------------------------
# # add a new event relative of a scheduler in the database and treate it
# # arg1 --> database ref
# # arg2 --> schedulerId on which event occured
# # arg3 --> event Type
# # arg4 --> descriptive message
# sub add_new_scheduler_event($$$$){
#     my $dbh = shift;
#     my $schedId = shift;
#     my $eventType = shift;
#     my $eventMessage = shift;
# 
#     #$dbh->do("LOCK TABLES events WRITE");
#     $dbh->begin_work;
# 
#     #my $id = calculate_event_id($dbh);
#     my $time = get_date();
#     $dbh->do("    INSERT INTO events (eventId,eventType,eventClass,eventSchedulerId,eventDate,eventMessage)
#                 VALUES (NULL,\"$eventType\",\"SCHEDULER\",\"$schedId\",\"$time\",\"$eventMessage\")");
# 
#     #$dbh->do("UNLOCK TABLES");
#     $dbh->commit;
# 
#     check_events($dbh);
# }
#-------------------------------------------------- 

# add a new event relative of a ssh in the database and treate it
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> descriptive message
sub add_new_ssh_event($$$){
    my $dbh = shift;
    my $clusterName = shift;
    my $eventMessage = shift; $eventMessage =~ s/(['"\\])/\\$1/g;

    #$dbh->do("LOCK TABLES events WRITE");
    $dbh->begin_work;

    #my $id = calculate_event_id($dbh);
    my $time = get_date();
    $dbh->do("    INSERT INTO events (eventId,eventType,eventClass,eventClusterName,eventDate,eventMessage)
                VALUES (NULL,\"SSH\",\"CLUSTER\",\"$clusterName\",\"$time\",\"$eventMessage\")");

    #$dbh->do("UNLOCK TABLES");
    $dbh->commit;

    check_events($dbh);
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

    my $sth = $dbh->prepare("    SELECT count( * )
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
# arg2 --> clusterName
# arg3 --> nodeName
# arg4 --> MJobsId
# return the number of blacklist
sub is_node_active($$$$){
    my $dbh = shift;
    my $clusterName = shift;
    my $nodeName = shift;
    my $MJobId = shift;

    my $sth = $dbh->prepare("    SELECT count( * )
                                FROM nodeBlackList, events
                                WHERE nodeBlackListEventId = eventId
                                    AND eventState = \"ToFIX\"
                                    AND nodeBlackListNodeName = \"$nodeName\"
                                    AND nodeBlackListClusterName = \"$clusterName\"
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

    my $sth = $dbh->prepare("    SELECT count( * )
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

    my $sth = $dbh->prepare("    SELECT count( * )
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


#OLDSCHED------------------------------------------
# # test if the scheduler is active
# # arg1 --> database ref
# # arg2 --> schedulerId
# sub is_scheduler_active($$){
#     my $dbh = shift;
#     my $schedId = shift;
# 
#     my $sth = $dbh->prepare("    SELECT count( * )
#                                 FROM schedulerBlackList, events
#                                 WHERE schedulerBlackListEventId = eventId
#                                     AND eventState = \"ToFIX\"
#                                     AND (schedulerBlackListSchedulerId = $schedId
#                                         OR schedulerBlackListSchedulerId = 0)
#                             ");
#     $sth->execute();
#     my @numErrors = $sth->fetchrow_array();
#     $sth->finish();
# 
#     return $numErrors[0];
# }
#-------------------------------------------------- 

sub fix_event($$){
    my $dbh = shift;
    my $eventId = shift;

    $dbh->do("    UPDATE events SET eventState = \"FIXED\"
                WHERE eventId = $eventId
            ");
}

# get blacklisted nodes for a MJob on a cluster
# arg1 --> database ref
# arg2 --> MJobId
# arg3 --> clusterName
sub get_blacklisted_nodes($$$){
    my $dbh = shift;
    my $MJobId = shift;
    my $clusterName = shift;

    my $sth = $dbh->prepare("SELECT  nodeBlackListNodeName
                             FROM nodeBlackList,events
                             WHERE eventState = \"ToFIX\"
                                   AND nodeBlackListEventId = eventId
                                   AND (nodeBlackListMJobsID = $MJobId
                                        OR nodeBlackListMJobsID = 0)
                                   AND nodeBlackListClusterName = \"$clusterName\"
                            ");
    $sth->execute();
    my @nodeNames;
    while (my @ref = $sth->fetchrow_array()) {
        push(@nodeNames, $ref[0]);
    }
    $sth->finish();
    return(@nodeNames);
}



# get jobid number that generated a given blacklisting
# arg1 --> database ref
# arg2 --> clusterBlackListEventId
sub get_jobid_from_blacklistid($$){
    my $dbh = shift;
    my $blacklistid = shift;

	my $sth = $dbh->prepare("SELECT clusterBlackListEventId FROM clusterBlackList WHERE clusterBlackListNum = $blacklistid");
    $sth->execute();
    my @array = $sth->fetchrow_array();
    my $eventid = $array[0];

	$sth = $dbh->prepare("SELECT eventJobId FROM events WHERE eventId = $eventid");
    $sth->execute();
    @array = $sth->fetchrow_array();
    my $jobid = $array[0];

    return $jobid;
}



# check events in the database and decide actions to perform
# arg1 --> database ref
sub check_events($){
    #SCHEDULER
        # ALMIGHTY_FILE, EXIT_VALUE
    #CLUSTER
        # UPDATOR_PBSNODES_PARSE, UPDATOR_PBSNODES_CMD, UPDATOR_QSTAT_CMD, SSH, COLLECTOR, MYSQL_OAR_CONNECT, QDEL_CMD, OAR_OARSUB, OAR_NOTIFY
    #JOB
        # FRAG, UPDATOR_RET_CODE_ERROR, UPDATOR_JOB_KILLED, RUNNER_SUBMIT, RUNNER_JOBID_PARSE

    print("[COLOMBO]     I check events\n");

    #lock tables
    my $dbh = shift;

    #$dbh->do("LOCK TABLES events WRITE, clusterBlackList WRITE, jobs WRITE, nodes WRITE, schedulerBlackList WRITE, resubmissionLog WRITE, parameters WRITE, fragLog WRITE");

    $dbh->do("SELECT GET_LOCK(\"cigriEventLock\",300)");
    
    #list of cluster events used
    my $sth = $dbh->prepare("    SELECT clusterBlackListEventId
                                FROM events, clusterBlackList
                                WHERE clusterBlackListEventId = eventId
                                    AND eventState = \"ToFIX\"
                                ");
    $sth->execute();
    my %eventUsed;
    while (my @ref = $sth->fetchrow_array()) {
        $eventUsed{$ref[0]}=1;
    }
    $sth->finish();

    #search tofix event relative to a cluster error ("UPDATOR_PBSNODES_PARSE","UPDATOR_QSTAT_CMD","UPDATOR_PBSNODES_CMD","SSH","COLLECTOR", ...)
    $sth = $dbh->prepare("    SELECT eventId, eventClusterName, eventMessage
                            FROM events
                            WHERE eventState = \"ToFIX\"
                                AND (eventType = \"UPDATOR_PBSNODES_PARSE\"
                                    OR eventType = \"UPDATOR_PBSNODES_CMD\"
                                    OR eventType = \"UPDATOR_QSTAT_CMD\"
                                    OR eventType = \"SSH\"
                                    OR eventType = \"COLLECTOR\"
                                    OR eventType = \"MYSQL_OAR_CONNECT\"
                                    OR eventType = \"QDEL_CMD\"
                                    OR eventType = \"OAR_NOTIFY\"
                                    OR eventType = \"RUNNER_JOBID_PARSE\"
                                    )
                            ");
    $sth->execute();
    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($eventUsed{$ref[0]})){
            my $sthTmp = $dbh->prepare("SELECT MAX(clusterBlackListNum)+1 FROM clusterBlackList");
            $sthTmp->execute();
            my $refTmp = $sthTmp->fetchrow_hashref();
            my @tmp = values(%$refTmp);
            my $id = $tmp[0];
            $sthTmp->finish();
            if(!defined($id)) {
                $id = 1;
            }

            $dbh->do("    INSERT INTO clusterBlackList (clusterBlackListNum,clusterBlackListClusterName,clusterBlackListEventId )
                        VALUES ($id,\"$ref[1]\",$ref[0])");

            # notify admin by email
            mailer::sendMail("clusterBlackList = $ref[1] for all MJobs; eventId = $ref[0]","$ref[2]");
        }
    }
    $sth->finish();



    # JOB error ----> blacklist a cluster for a MJob
    $sth = $dbh->prepare("    SELECT eventId, eventClusterName, eventMJobsId, eventMessage, eventType
                            FROM events
                            WHERE eventState = \"ToFIX\"
                                AND (eventType = \"UPDATOR_RET_CODE_ERROR\" 
                                OR eventType = \"OAR_OARSUB\"
                                OR eventType = \"JOB_COLLECT\"
                                OR eventType = \"RUNNER_SUBMIT\")
                            ");
    $sth->execute();

    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($eventUsed{$ref[0]})){
            my $sthTmp = $dbh->prepare("SELECT MAX(clusterBlackListNum)+1 FROM clusterBlackList");
            $sthTmp->execute();
            my $refTmp = $sthTmp->fetchrow_hashref();
            my @tmp = values(%$refTmp);
            my $id = $tmp[0];
            $sthTmp->finish();
            if(!defined($id)) {
                $id = 1;
            }

            $dbh->do("    INSERT INTO clusterBlackList (clusterBlackListNum,clusterBlackListClusterName,clusterBlackListMJobsID,clusterBlackListEventId )
                        VALUES ($id,\"$ref[1]\",$ref[2],$ref[0])");


	    	my $msg="This is a message from the CiGri server as an error occured into your MJob #".$ref[2]."\n";
	    	$msg.="This happenned on the ".$ref[1]. " cluster. This host has been disabled for your MJob\n";
	    	$msg.="until you correct the problem and you fix it into the CiGri web interface.\n\n";
	    	$msg.=$ref[3];

            # notify admin by email, but not on OAR errors(which can be a lot)
		    if($ref[4] ne "OAR_OARSUB"){
	            mailer::sendMail("clusterBlackList = $ref[1] for the MJob $ref[2]; eventId = $ref[0]",$msg);
                    print "Disabled EMAIL to admin in the code!\n";
			}

		    # notify the user
	    	mailer::sendMailtoUser("clusterBlackList = $ref[1] for the MJob $ref[2]; eventId = $ref[0]",$msg,iolibCigri::get_MJob_user($dbh,$ref[2]));




			# check if all clusters where blacklisted
			my $nb_cluster_sth = $dbh->prepare("SELECT COUNT(*) FROM properties WHERE propertiesMJobsId = $ref[2]");
			$nb_cluster_sth->execute();
			my @nb_cluster_array = $nb_cluster_sth->fetchrow_array();
			my $nb_cluster = $nb_cluster_array[0];

			my $nb_blcluster_sth = $dbh->prepare("SELECT COUNT(*) FROM clusterBlackList WHERE clusterBlackListMJobsID = $ref[2]");
			$nb_blcluster_sth->execute();
			my @nb_blcluster_array = $nb_blcluster_sth->fetchrow_array();
			my $nb_blcluster = $nb_blcluster_array[0];

			if($nb_blcluster == $nb_cluster){
				print "[COLOMBO]       all clusters were blacklisted for the
Mjob $ref[2]  \n";
				#add_new_mjob_event($dbh,$ref[2],"FRAG","Auto-frag: all clusters blacklisted");
                                print "[COLOMBO]       BB 04/2011 disabled Auto-frag... seems buggy in some cases\n";
				#TODO emathias: mail everybody 
			}else{
				my $job_to_resubmit = get_jobid_from_blacklistid($dbh,$id);
				print "[COLOMBO]     Resubmit job $job_to_resubmit, due to blacklisting \n";
		 		resubmit_job($dbh,$job_to_resubmit);
			}


        }
    }
    $sth->finish();







    # I treate the UPDATOR_JOB_KILLED event type
    # --> resubmit jobs

    $sth = $dbh->prepare("    SELECT eventId, eventJobId
                            FROM events
                            WHERE eventState = \"ToFIX\"
                                AND eventType = \"UPDATOR_JOB_KILLED\"
                            ");
    $sth->execute();

    while (my @ref = $sth->fetchrow_array()) {
            resubmit_job($dbh,$ref[1]);
            $dbh->do("    INSERT INTO resubmissionLog (resubmissionLogEventId)
                        VALUES ($ref[0])");
            fix_event($dbh,$ref[0]);
    }
    $sth->finish();


#OLDSCHED------------------------------------------
#    # scheduler error --> blacklist scheduler
#    #list of scheduler events used
# 
#     $sth = $dbh->prepare("    SELECT schedulerBlackListEventId
#                             FROM events, schedulerBlackList
#                             WHERE schedulerBlackListEventId = eventId
#                                 AND eventState = \"ToFIX\"
#                             ");
#     $sth->execute();
#     undef(%eventUsed);
#     while (my @ref = $sth->fetchrow_array()) {
#         $eventUsed{$ref[0]}=1;
#     }
#     $sth->finish();
# 
#     $sth = $dbh->prepare("    SELECT eventId, eventSchedulerId, eventMessage
#                             FROM events
#                             WHERE eventState = \"ToFIX\"
#                                 AND (eventType = \"ALMIGHTY_FILE\"
#                                     OR eventType = \"EXIT_VALUE\"
#                                 )
#                             ");
#     $sth->execute();
# 
#     while (my @ref = $sth->fetchrow_array()) {
#         if (!defined($eventUsed{$ref[0]})){
#             my $sthTmp = $dbh->prepare("SELECT MAX(schedulerBlackListNum)+1 FROM schedulerBlackList");
#             $sthTmp->execute();
#             my $refTmp = $sthTmp->fetchrow_hashref();
#             my @tmp = values(%$refTmp);
#             my $id = $tmp[0];
#             $sthTmp->finish();
#             if(!defined($id)) {
#                 $id = 1;
#             }
#             $dbh->do("    INSERT INTO schedulerBlackList (schedulerBlackListNum,schedulerBlackListSchedulerId,schedulerBlackListEventId)
#                         VALUES ($id,$ref[1],$ref[0])");
# 
#             # notify admin by email
#             mailer::sendMail("schedulerBlackList = $ref[1]; eventId = $ref[0]","$ref[2]");
#         }
#     }
#     $sth->finish();
# 
#-------------------------------------------------- 
    # treate FRAG events

    $sth = $dbh->prepare("    SELECT fragLogEventId
                            FROM events, fragLog
                            WHERE fragLogEventId = eventId
                                AND eventState = \"ToFIX\"
                            ");
    $sth->execute();
    undef(%eventUsed);
    while (my @ref = $sth->fetchrow_array()) {
        $eventUsed{$ref[0]}=1;
    }
    $sth->finish();

    $sth = $dbh->prepare("    SELECT eventId
                            FROM events
                            WHERE eventState = \"ToFIX\"
                                AND eventType = \"FRAG\"
                            ");
    $sth->execute();

    while (my @ref = $sth->fetchrow_array()) {
        if (!defined($eventUsed{$ref[0]})){
            $dbh->do("    INSERT INTO fragLog (fragLogEventId)
                        VALUES ($ref[0])");
        }
    }
    $sth->finish();

    #$dbh->do("UNLOCK TABLES");
    $dbh->do("SELECT RELEASE_LOCK(\"cigriEventLock\")");
}

# reschedule a job parameter
# arg1 --> database parameter
# arg2 --> idJob to resubmit
sub resubmit_job($$){
    my $dbh = shift;
    my $jobId = shift;
    print("[COLOMBO]     Resubmiting job: $jobId\n");
    $dbh->do("    INSERT INTO parameters (parametersMJobsId,parametersParam,parametersName,parametersPriority)
                SELECT jobMJobsId, jobParam, jobName, 1
                FROM jobs
                WHERE jobId = $jobId
            ");

}

# resubmit an mjob 
# arg1 --> database parameter
# arg2 --> MJobId to resubmit
sub resubmit_mjob($$$){
    my $dbh = shift;
    my $MJobId = shift;
    my $MJobType = shift;

	my $JDLString = iolibCigri::get_MJobs_JDL($dbh,$MJobId);

	my $tmpfilename;	
	my $fh;	

	# try new temporary filenames until we get one that didn't already exist
	do {$tmpfilename = tmpnam()} until $fh = IO::File->new($tmpfilename, O_RDWR|O_CREAT|O_EXCL);
	#print ("Created temp file $tmpfilename\n") ;
	print $fh "\n $JDLString\n";	
	$fh->close;

	my $idJob= iolibCigri::add_mjobs($dbh, $tmpfilename, $MJobType);
    print "IdJob = $idJob \n";

	#delete temp file
	unlink($tmpfilename);

}



return 1;
