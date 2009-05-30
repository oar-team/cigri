package iolibCigri;
require Exporter;

use Data::Dumper;
use DBI;
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
    unshift(@INC, $relativePath."ConfLib");
    unshift(@INC, $relativePath."JDLLib");
    unshift(@INC, $relativePath."Colombo");
    unshift(@INC, $relativePath."Mailer");
}
use JDLParserCigri;
use ConfLibCigri qw(init_conf get_conf is_conf);
use colomboCigri;
#use mailer;

# Connect to the database and give the ref
sub connect() {
    # Connect to the database.
    ConfLibCigri::init_conf();

    my $host = ConfLibCigri::get_conf("DATABASE_HOST");
    my $name = ConfLibCigri::get_conf("DATABASE_NAME");
    my $user = ConfLibCigri::get_conf("DATABASE_USER_NAME");
    my $pwd  = ConfLibCigri::get_conf("DATABASE_USER_PASSWORD");

    return(DBI->connect("DBI:mysql:database=$name;host=$host", $user, $pwd,    {'RaiseError' => 1,'InactiveDestroy' => 1}));
}

# Disconnect from the database referenced by arg1
# arg1 --> database ref
sub disconnect($) {
    my $dbh = shift;

    # Disconnect from the database.
    $dbh->disconnect();
}

# get the name of the remote file which contains grid informations
# arg1 --> grid job id
sub get_cigri_remote_file_name($){
    my $jobId = shift;
    return("cigri.$jobId.log");
}

# get the name of the remote script which is executed
# arg1 --> grid job id
sub get_cigri_remote_script_name($){
    my $jobId = shift;
    return("cigri.tmp.$jobId");
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
    #$dbh->do("TRUNCATE TABLE clusterFreeNodes");
    #$dbh->do("TRUNCATE TABLE multipleJobsRemained");
    $dbh->do("TRUNCATE TABLE jobsToSubmit");
}

# Add a job to the database in multipleJobs table
# arg1 --> database ref
# arg2 --> JDLfile
# arg3 --> campaign type
# return the request id or
# -1 = bad JDL file or bad param file
# -2 = no cluster defined
# -3 = no execFile in a cluster section
# -4 = duplicate parameters
# -5 = invalid campaign_type
sub add_mjobs($$$) {
    my ($dbh, $JDLfile, $mJobType) = @_;

    #$dbh->do("LOCK TABLES multipleJobs WRITE, parameters WRITE, properties WRITE");
    my $lusr= getpwuid($<);

    begin_transaction($dbh);
    

    #my $sth = $dbh->prepare("SELECT MAX(MJobsId)+1 FROM multipleJobs");
    #$sth->execute();
    #my $ref = $sth->fetchrow_hashref();
    #my @tmp = values(%$ref);
    #my $id = $tmp[0];
    #$sth->finish();
    #if(!defined($id)) {
    #    $id = 1;
    #}

    my $time = get_date();

    my $jdl = "";
    if (defined($JDLfile) && (-r $JDLfile)){
        open(FILE, $JDLfile);
        while (<FILE>){
            $jdl = $jdl.$_;
        }
        close(FILE);
    }else{
        rollback_transaction($dbh);
        return(-1);
    }

	#TODO temporary while admissions rules not available
	$mJobType = 'default' if (!defined($mJobType));
	if(($mJobType ne "default") && ($mJobType ne "test")){
		return(-5);
	}
    
    $dbh->do("INSERT INTO multipleJobs (MJobsId,MJobsUser,MJobsJDL,MJobsTSub)
            VALUES (NULL,\"$lusr\",\"$jdl\",\"$time\")");

    my $sth = $dbh->prepare("SELECT LAST_INSERT_ID()");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values(%$ref);
    my $id = $tmp[0];
    $sth->finish();

	# insert jobtype on table
	$dbh->do("INSERT INTO multipleJobTypes (MJobId,MJobType)
            VALUES ($id,\"$mJobType\")");

    # copy params in the database
    my $Params ="";
    if (JDLParserCigri::init_jdl($jdl) == 0){
        if (defined($JDLParserCigri::clusterConf{DEFAULT}{paramFile}) && (-r $JDLParserCigri::clusterConf{DEFAULT}{paramFile})){
                open(FILE, $JDLParserCigri::clusterConf{DEFAULT}{paramFile});
                my $doRet;
                while (<FILE>){
                    chomp;
                    my @commentaire;
                    ($_, @commentaire) = split("#", $_,2);
                    #if ($_ ne ""){
                    if (not /^\s*$/){
                        my $paramName;
                        my @tmp;
                        ($paramName, @tmp) = split (' ', $_, 2);
                        print("Insert ($id,\'$_\',\'$paramName\')\n");
                        $doRet = $dbh->do("INSERT INTO parameters (parametersMJobsId,parametersParam,parametersName) VALUES ($id,\'$_\',\'$paramName\')");
                        if ($doRet != 1){
                            warn("Duplicate parameters\n");
                            warn("$@");
                            #$dbh->do("DELETE FROM parameters WHERE parametersMJobsId = $id");
                            rollback_transaction($dbh);
                            return -4;
                        }
                    }
                }
                close(FILE);
        }elsif (defined($JDLParserCigri::clusterConf{DEFAULT}{nbJobs})){
            for (my $k=0; $k<$JDLParserCigri::clusterConf{DEFAULT}{nbJobs}; $k++) {
                $dbh->do("INSERT INTO parameters (parametersMJobsId,parametersParam) VALUES ($id,\'$k\')");
            }
        }else{
            print("[iolib] I can't read the param file $JDLParserCigri::clusterConf{DEFAULT}{paramFile} or the nbJobs variable\n");
            rollback_transaction($dbh);
            return -1;
        }
	##added for rsync data synchronization of clusters##
	if ((defined($JDLParserCigri::clusterConf{DEFAULT}{data_to_transfer})) && !($JDLParserCigri::clusterConf{DEFAULT}{data} =~ m/.*\~.*/m)){
                  my $DataSrc = $JDLParserCigri::clusterConf{DEFAULT}{data_to_transfer};
		  $dbh->do("INSERT INTO data_synchron (data_synchronMJobsId,data_synchronSrc) VALUES ($id,\"$DataSrc\")");
		  }															     	
	if ((defined($JDLParserCigri::clusterConf{DEFAULT}{transfer_timeout})) && !($JDLParserCigri::clusterConf{DEFAULT}{data_to_transfer} =~ m/.*\~.*/m)){
	        my $Timeout = $JDLParserCigri::clusterConf{DEFAULT}{transfer_timeout};
		$dbh->do("UPDATE data_synchron SET data_synchronTimeout = \"$Timeout\" WHERE data_synchronMJobsId = $id");
        }



	# Update the properties table
        my @clusters = keys(%JDLParserCigri::clusterConf);
        if ($#clusters > 0){
            foreach my $j (@clusters){
                if ($j ne "DEFAULT"){
                    if (defined($JDLParserCigri::clusterConf{$j}{execFile})){
                        my $jobWalltime = "1:00:00";
                        my $jobWeight = 1;
                        my $execDir = "~";
			my $checkpoint_type="";
			my $checkpoint_period=0;
			my $priority = 1;
                        if (defined($JDLParserCigri::clusterConf{$j}{walltime})){
                            $jobWalltime = $JDLParserCigri::clusterConf{$j}{walltime};
                        }
                        if ((defined($JDLParserCigri::clusterConf{$j}{weight})) && ($JDLParserCigri::clusterConf{$j}{weight} > 0)){
                            $jobWeight = $JDLParserCigri::clusterConf{$j}{weight};
                        }
                        if ((defined($JDLParserCigri::clusterConf{$j}{execDir})) && !($JDLParserCigri::clusterConf{$j}{execDir} =~ m/.*\~.*/m)){
                            $execDir = $JDLParserCigri::clusterConf{$j}{execDir};
			}
                        if ((defined($JDLParserCigri::clusterConf{$j}{checkpoint_type})) && (
			        $JDLParserCigri::clusterConf{$j}{checkpoint_type} == "blcr"
                             || $JDLParserCigri::clusterConf{$j}{checkpoint_type} == "sgi"
			     || $JDLParserCigri::clusterConf{$j}{checkpoint_type} == "NULL"
			   )){
			    $checkpoint_type=$JDLParserCigri::clusterConf{$j}{checkpoint_type};
			}
			if (defined($JDLParserCigri::clusterConf{$j}{checkpoint_period})){
                             $checkpoint_period=$JDLParserCigri::clusterConf{$j}{checkpoint_period};
			}
			if (defined($JDLParserCigri::clusterConf{$j}{priority})){
			    $priority = $JDLParserCigri::clusterConf{$j}{priority};
			}

                        $dbh->do("INSERT INTO properties (propertiesClusterName,propertiesMJobsId,propertiesJobCmd,propertiesJobWalltime,propertiesJobWeight,propertiesExecDirectory,propertiesCheckpointType,propertiesCheckpointPeriod,propertiesClusterPriority)
                                  VALUES (\"$j\",$id,\"$JDLParserCigri::clusterConf{$j}{execFile}\",\"$jobWalltime\",$jobWeight,\"$execDir\",\"$checkpoint_type\",\"$checkpoint_period\",\"$priority\")");
                    }else{
                        rollback_transaction($dbh);
                        return -3;
                    }
                }
            }
        }else{
            rollback_transaction($dbh);
            return -2;
        }
    }else{
        rollback_transaction($dbh);
        return -1;
    }

    my $MJName;
    if (!defined($JDLParserCigri::clusterConf{DEFAULT}{name})){
        $MJName = $id;
    }else{
        $MJName = $JDLParserCigri::clusterConf{DEFAULT}{name};
    }

    $dbh->do("UPDATE multipleJobs SET MJobsName = \"$MJName\" WHERE MJobsId = $id");

    commit_transaction($dbh);

    #$dbh->do("UNLOCK TABLES");
    # notify admin by email
    mailer::sendMail("New MJob $id from user $lusr","Insert new MJob $id.\nJDL:\n$jdl");

    return $id;
}

# get the data_synchronization source directroy 
# # # # arg1 --> database
# # # # arg2 --> MJobId
sub get_source_data_synchron($$){
   my $dbh = shift;
   my $MjobId = shift;
   my $sth = $dbh->prepare("    SELECT data_synchronSrc
                                FROM data_synchron
                                WHERE data_synchronMJobsId = $MjobId;                                
                          ");
   $sth->execute();
   my @src  = $sth->fetchrow_array();
   $sth->finish();
	return @src[0];
}
# get the data_synchronization parameters 
# # # # # arg1 --> database
sub get_data_synchron_param($){
  my $dbh = shift;
  my $sth = $dbh->prepare(" SELECT data_synchronMJobsId,data_synchronSrc,data_synchronTimeout
                            FROM data_synchron
                            WHERE data_synchronState = \'INITIATED\';
                          ");
 $sth->execute();
# my %result;
# while (my @ref = $sth->fetchrow_array()) {
#      $result{$ref[0]} = $ref[1];
# }
# $sth->finish();
# return %result;

  my %resul;

  while (my @ref = $sth->fetchrow_array()) {
     my $tmp = {
    #              "user" => $ref[1],
    #              "host" => $ref[2],
                  "src" => $ref[1],
		  "timeout" => $ref[2]
                };
      push(@{$resul{$ref[0]}},$tmp);
   }
										        $sth->finish();
   return %resul;
}

# set the state of data synchronization of a multijob
# # arg1 --> database ref
# # arg2 --> MjobId
# # arg3 --> state
sub set_data_synchronState($$$) {
    my $dbh = shift;
    my $MidJob = shift;
    my $state = shift;
    my $sth = $dbh->prepare("UPDATE data_synchron SET data_synchronState = \"$state\"
                             WHERE data_synchronMJobsId =\"$MidJob\"");
    $sth->execute();
    $sth->finish();
}
  
# get the userLogin of a specific cluster
# # # arg1 --> database ref
# # # arg2 --> clusterName
   
sub get_userLogin4cluster($$$) {
    my $dbh = shift;
    my $cluster = shift;
    my $MidJob = shift;
    my $sth = $dbh->prepare("SELECT userLogin
    			     FROM users,multipleJobs
                             WHERE userClusterName = \"$cluster\"
			     AND MJobsId = \"$MidJob\"
			     AND MJobsUser = userGridName");
    $sth->execute();
    my @state  = $sth->fetchrow_array();
    $sth->finish();
    
    return @state[0];    
}

# get the the data synchronization state of a multijob
# # # # arg1 --> database ref
# # # # arg2 --> MjobId

sub get_data_synchronState($$) {
    my $dbh = shift;
    my $MidJob = shift;
    my $sth = $dbh->prepare("SELECT data_synchronState
                             FROM users, data_synchron
                             WHERE data_synchronMJobsId =\"$MidJob\"");
    $sth->execute();
    my @state  = $sth->fetchrow_array();
    $sth->finish();
    return @state[0];
}

# get the the data synchronization user of a multijob
# # # # arg1 --> database ref
# # # # arg2 --> MjobId
		
sub get_data_synchronUser($$) {
    my $dbh = shift;
    my $MidJob = shift;
    my $sth = $dbh->prepare("SELECT data_synchronUser
                             FROM data_synchron
                             WHERE data_synchronMJobsId =\"$MidJob\"");
    $sth->execute();
    my @User  = $sth->fetchrow_array();
    $sth->finish();
    return @User[0];
}

# get the the number of multijobs for data synchronization in IN_TREATMENT state
# # # # # arg1 --> database ref
# # # # # arg2 --> MjobId

sub get_nb_data_synchronTREATstate($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
                             FROM data_synchron
                             WHERE data_synchronState=\'IN_TREATMENT\'");
    $sth->execute();
    my @result = $sth->fetchrow_array();


    $sth->finish();
    return $result[0];
}
# get the the number of clusters that the specific user is registered
# # # # # # arg1 --> database ref
# # # # # # arg2 --> user
sub get_nbclusters_4user($$) {
    my $dbh = shift;
    my $user = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
                             FROM users
                             WHERE userGridName=\"$user\"");
    $sth->execute();
    my @result = $sth->fetchrow_array();
    $sth->finish();
    return $result[0];
}

# get the registered user of localhost cluster
# # # # # # # arg1 --> database ref

sub get_localhost_user($) {
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT userGridName
                             FROM users
                             WHERE userClusterName =\'localhost\'");
    $sth->execute();
    my @state  = $sth->fetchrow_array();
    $sth->finish();
    return @state[0];
}

# set the state of data synchronization of a cluster for a specific multijob 
# # # arg1 --> database ref
# # # arg2 --> MjobId
# # # arg3 --> cluster
# # # arg4 --> state
sub set_propertiesData_synchronState($$$$) {
     my $dbh = shift;
     my $MidJob = shift;
     my $cluster = shift;
     my $state = shift;
     my $sth = $dbh->prepare("UPDATE properties SET propertiesData_synchronState = \"$state\"
                              WHERE propertiesMJobsId =\"$MidJob\"
			      AND propertiesClusterName =\"$cluster\"");
     $sth->execute();
     $sth->finish();
     print "UPDATE properties $state $MidJob $cluster\n";
}

# get the state of data synchronization of a cluster for a specific multijob 
# # # # arg1 --> database ref
# # # # arg2 --> MjobId
# # # # arg3 --> cluster
sub get_propertiesData_synchronState($$$) {
    my $dbh = shift;
    my $MidJob = shift;
    my $cluster = shift;
    my $sth = $dbh->prepare("SELECT  propertiesData_synchronState
                             FROM properties
                             WHERE propertiesMJobsId =\"$MidJob\"
			     AND propertiesClusterName =\"$cluster\""
			   );
    $sth->execute();
    my @state  = $sth->fetchrow_array();
    $sth->finish();
    return @state[0];
}

# get the execDirectory of a cluster for a specific multijob 
# # # # # arg1 --> database ref
# # # # # arg2 --> MjobId
# # # # # arg3 --> cluster
sub get_properties_ExecDirectory($$$) {
    my $dbh = shift;
    my $MidJob = shift;
    my $cluster = shift;
    my $sth = $dbh->prepare("SELECT  propertiesExecDirectory
                             FROM properties
                             WHERE propertiesMJobsId =\"$MidJob\"
                             AND propertiesClusterName =\"$cluster\""
                           );
    $sth->execute();
    my @state  = $sth->fetchrow_array();
    $sth->finish();
    return @state[0];
}

# get if a cluster for a specific multijob 
# # # # # # arg1 --> database ref
# # # # # # arg2 --> MjobId
# # # # # # arg3 --> state
sub get_properties_cluster_existance($$$){
    my $dbh = shift;
    my $MJobId = shift;
    my $cluster = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
                             FROM properties
                             WHERE propertiesMJobsId = \"$MJobId\"
                             AND propertiesClusterName = \"$cluster\"");
    $sth->execute();
    my @result = $sth->fetchrow_array();
    $sth->finish();
													        return $result[0];
}

# get the number of clusters that their synchronization state is 'TERMINATED' for a specific MJob
# # arg1 --> database ref
# # arg2 --> MjobId
sub get_nb_synchronTERM_clusters($$){
    my $dbh = shift;
    my $MJobId = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
                             FROM properties
                             WHERE propertiesMJobsId = \"$MJobId\"
                             AND (propertiesData_synchronState = \"TERMINATED\"
			     OR propertiesData_synchronState = \"\")");
    $sth->execute();
    my @result = $sth->fetchrow_array(); 
       
    
    $sth->finish();
    return $result[0];
}
# get the number of clusters that their synchronization state is 'ERROR' for a specific MJob
# # arg1 --> database ref
# # arg2 --> MjobId
sub get_nb_synchronERR_clusters($$){
    my $dbh = shift;
    my $MJobId = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
    			     FROM properties
                             WHERE propertiesMJobsId = \"$MJobId\"
			     AND propertiesData_synchronState = \"ERROR\"");
    $sth->execute();
    my @result = $sth->fetchrow_array();


    $sth->finish();
    return $result[0];

}

# get the number of clusters that their synchronization state is 'IN_TREATMENT' for a specific MJob
# # # arg1 --> database ref
# # # arg2 --> MjobId
sub get_nb_synchronTREAT_clusters($$){
    my $dbh = shift;
    my $MJobId = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
                             FROM properties
                             WHERE propertiesMJobsId = \"$MJobId\"
                             AND propertiesData_synchronState = \"IN_TREATMENT\"");
    $sth->execute();
    my @result = $sth->fetchrow_array();
    $sth->finish();
    return $result[0];
}

# get the number of clusters for a specific MJob
# # # arg1 --> database ref
# # # arg2 --> MjobId
sub get_nb_Mjob_clusters($$){
    my $dbh = shift;
    my $MJobId = shift;
    my $sth = $dbh->prepare("SELECT COUNT(*)
                             FROM properties
                             WHERE propertiesMJobsId = \"$MJobId\"");
    $sth->execute();
    my @result = $sth->fetchrow_array();
    $sth->finish();
    return $result[0];
}

# set INITIATED state for all clusters
# arg1 --> database ref
# arg2 --> MjobId
# arg3 --> cluster synchronizer
sub set_properties_datasynchron_initstate($$){
     my $dbh = shift;
     my $MidJob = shift;
     
         $dbh->do("UPDATE properties SET propertiesData_synchronState = \"INITIATED\"	          
		   WHERE propertiesMJobsId =\"$MidJob\"");
}

# get the cluster names in an array
# arg1 --> database ref
# return --> array of cluster names and their batch scheduler
#            The keys of the hashTable are "NAME" and "BATCH"
sub get_cluster_names_batch($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT clusterName,clusterBatch FROM clusters");
    $sth->execute();

    my %resulHash;

    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_cluster_active($dbh,$ref[0],0) == 0){
            $resulHash{$ref[0]} = $ref[1];
        }
    }
    $sth->finish();

    return %resulHash;
}

# get the cluster names in an array
# arg1 --> database ref
# return --> array of cluster names and their resource_unit property (OAR2)
#            The keys of the hashTable are "NAME" and "RESOURCE_UNIT"
sub get_cluster_names_resource_unit($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT clusterName,clusterResourceUnit FROM clusters");
    $sth->execute();

    my %resulHash;

    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_cluster_active($dbh,$ref[0],0) == 0){
	    if ($ref[1]) {
              $resulHash{$ref[0]} = $ref[1];
	      }
	    else {
              $resulHash{$ref[0]} = "cpu";
	    }
        }
    }
    $sth->finish();

    return %resulHash;
}

# get the cluster batch properties in an array
# arg1 --> database ref
# return --> array of cluster names and their resource_unit property (OAR2)
#            The keys of the hashTable are "NAME" and "PROPERTIES"
sub get_cluster_names_properties($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT clusterName,clusterProperties FROM clusters");
    $sth->execute();

    my %resulHash;

    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_cluster_active($dbh,$ref[0],0) == 0){
	    if ($ref[1]) {
              $resulHash{$ref[0]} = $ref[1];
	      }
	    else {
              $resulHash{$ref[0]} = "1=1";
	    }
        }
    }
    $sth->finish();

    return %resulHash;
}

# get the cluster properties in a hash
# arg1 --> database ref
# arg2 --> cluster name
# return --> hash of cluster properties
sub get_cluster_properties($$){
    my $dbh = shift;
    my $clusterName = shift;
    my $sth = $dbh->prepare("SELECT * FROM clusters WHERE clusterName = \"$clusterName\"");
    $sth->execute();
    my %resulHash;
    %resulHash = %{$sth->fetchrow_hashref()} ;
    $sth->finish();

    return %resulHash;
}

# get all the cluster names in an array (even if it is dead)
# arg1 --> database ref
# return --> hash of cluster names
sub get_all_cluster_names($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT clusterName FROM clusters ");
    $sth->execute();

    my %resulHash;
    while (my @ref = $sth->fetchrow_array()) {
        $resulHash{$ref[0]} = 1;
    }
    $sth->finish();

    return %resulHash;
}

# get defaultWeight of a cluster
# arg1 --> database ref
# arg2 --> clusterName
# return --> integer
sub get_cluster_default_weight($$){
    my $dbh = shift;
    my $clusterName = shift;
    my $sth = $dbh->prepare("select clusterDefaultWeight from clusters where clusterName = \"$clusterName\"");
    $sth->execute();

    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return $ref[0];
}

# set NODE_STATE to BUSY for all nodes
# arg1 --> database ref
sub disable_all_nodes($){
    my $dbh = shift;
    $dbh->do("UPDATE nodes SET nodeFreeWeight = 0");
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

# set the number of free weights for the given cluster node
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> node name
# arg4 --> nb free weights
sub set_cluster_node_free_weight($$$$){
    my $dbh = shift;
    my $clusterName = shift;
    my $nodeName = shift;
    my $freeWeight = shift;

    if ($freeWeight > 0){
        my $sth = $dbh->prepare("UPDATE nodes SET nodeFreeWeight = $freeWeight
                                 WHERE nodeClusterName = \"$clusterName\"
                                       and nodeName = \"$nodeName\"");
        $sth->execute();
        $sth->finish();
    }
}

# set the number of max weight for the given cluster node
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> node name
# arg4 --> max weight
sub set_cluster_node_max_weight($$$$){
    my $dbh = shift;
    my $clusterName = shift;
    my $nodeName = shift;
    my $maxWeight = shift;
    # Test if the node exists
    if (is_node_exist($dbh, $clusterName, $nodeName) == 0 ){
        # The node is created
        add_node($dbh, $clusterName, $nodeName);
    }

    if ($maxWeight > 0){
        my $sth = $dbh->prepare("UPDATE nodes SET nodeMaxWeight = $maxWeight
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
#sub get_node_cluster($$){
#    my $dbh = shift;
#    my $nodeId = shift;
#    my $sth = $dbh->prepare("SELECT nodeClusterName FROM nodes WHERE nodeId = $nodeId");
#    $sth->execute();
#    my @resulArray = $sth->fetchrow_array();
#    $sth->finish();
#
#    return $resulArray[0];
#}

#give the nodeId of the given node name
# arg1 --> database ref
# arg2 --> nodeName
# arg3 --> clusterName
# return the nodeId
# sub get_nodeID($$$){
    # my $dbh = shift;
    # my $nodeName = shift;
    # my $clusterName = shift;
#
    # my $sth = $dbh->prepare("SELECT nodeId
                             # FROM nodes
                             # WHERE nodeName = \"$nodeName\"
                                # AND nodeClusterName = \"$clusterName\"
                            # ");
    # $sth->execute();
    # my @resulArray = $sth->fetchrow_array();
    # $sth->finish();
#
    # return $resulArray[0];
# }

# give the job attribute
# arg1 --> database ref
# arg2 --> clusterName
# return a hashtable or id is undef
sub get_launching_job($$) {
    my $dbh = shift;
    my $clusterName = shift;
    my $sth = $dbh->prepare("SELECT jobId,jobParam,propertiesJobCmd,jobClusterName,clusterBatch,userLogin,MJobsId,propertiesJobWalltime,propertiesJobWeight,propertiesExecDirectory,propertiesCheckpointPeriod,propertiesCheckpointType,jobName
                             FROM jobs,clusters,multipleJobs,properties,users
                             WHERE jobState=\"toLaunch\"
                                 AND clusterName = \"$clusterName\"
                                 AND MJobsId = jobMJobsId
                                 AND propertiesClusterName = clusterName
                                 And propertiesMJobsId = MJobsId
                                 AND MJobsUser = userGridName
                                 AND userClusterName = clusterName
                                 AND jobClusterName = clusterName
                                 LIMIT 1
                            ");
    $sth->execute();

    my @ref = $sth->fetchrow_array();
    $sth->finish();

    my %result = (
        'id'            => $ref[0],
        'param'         => $ref[1],
        'cmd'           => $ref[2],
        'clusterName'   => $ref[3],
        'batch'         => $ref[4],
        'user'          => $ref[5],
        'mjobid'        => $ref[6],
        'walltime'      => $ref[7],
        'weight'        => $ref[8],
        'execDir'       => $ref[9],
	'checkpointPeriod' => $ref[10],
	'checkpointType' => $ref[11],
	'name' => $ref[12]
    );

    return %result;
}

# give a job to launch on a specified cluster
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> ref to the job to submit (type = hashtable)
# return a hashtable
sub get_cluster_job_toLaunch($$$) {
    my $dbh = shift;
    my $clusterName = shift;
    my $job = shift;

    #$dbh->do("LOCK TABLES jobs WRITE, jobsToSubmit WRITE, nodes WRITE, parameters WRITE, clusters WRITE, multipleJobs WRITE, properties WRITE, users WRITE, clusterBlackList WRITE, nodeBlackList WRITE, events WRITE");
    #print("Take the LOCK for cluster $clusterName\n");
    my $sth = $dbh->prepare("SELECT jobsToSubmitMJobsId, jobsToSubmitNumber
                             FROM jobsToSubmit
                             WHERE jobsToSubmitClusterName = \"$clusterName\"
                                 AND jobsToSubmitNumber > 0
                             LIMIT 1
                            ");
    $sth->execute();
    my @MJobtoSubmit = $sth->fetchrow_array();
    $sth->finish();

    if (defined($MJobtoSubmit[0])){
        #Verif if the scheduler is right
        if (colomboCigri::is_cluster_active($dbh,$clusterName,$MJobtoSubmit[0]) != 0){
            #$dbh->do("UNLOCK TABLES");
            warn("[Iolib] Erreur de choix du scheduler, le cluster est blackliste\n");
            colomboCigri::add_new_scheduler_event($dbh,${get_current_scheduler($dbh)}{schedulerId},"CLUSTER_BLACKLISTED"," Erreur de choix du scheduler, le cluster $clusterName est blackliste");
            return(1);
        }

        # if (colomboCigri::is_node_active($dbh,$MJobtoSubmit[1],$MJobtoSubmit[0]) != 0){
            # $dbh->do("UNLOCK TABLES");
            # warn("[Iolib] Erreur de choix du scheduler, le noeud $MJobtoSubmit[1] est blackliste\n");
            # colomboCigri::add_new_scheduler_event($dbh,${get_current_scheduler($dbh)}{schedulerId},"NODE_BLACKLISTED"," Erreur de choix du scheduler, le noeud  est $MJobtoSubmit[1] blackliste");
            # return(1);
        # }

        #Lock for integrity in multi-process mode
        $dbh->do("SELECT GET_LOCK(\"cigriParamLock\",3000)");
        
        # get parameter for this MJob on this cluster
        $sth = $dbh->prepare("SELECT parametersParam,parametersName
                              FROM parameters
                              WHERE $MJobtoSubmit[0] = parametersMJobsId
                              ORDER BY parametersPriority DESC
                              LIMIT 1");
        $sth->execute();
        my $parameter = $sth->fetchrow_hashref();
        $sth->finish();

        if (!defined($parameter)){
            #$dbh->do("UNLOCK TABLES");
            $dbh->do("SELECT RELEASE_LOCK(\"cigriParamLock\")");
            warn("[Iolib] Erreur de choix du scheduler pour le nb de parametres\n");
            colomboCigri::add_new_scheduler_event($dbh,${get_current_scheduler($dbh)}{schedulerId},"NB_PARAMS"," Erreur de choix du scheduler pour le nb de parametres");
            return(1);
        }

        #check if the node is FREE
        #my $nbRes = $dbh->do("SELECT * FROM nodes WHERE nodeId = $MJobtoSubmit[1] AND nodeState = \"FREE\"");
        #if ($nbRes < 1){
        #    $dbh->do("UNLOCK TABLES");
        #    warn("[Iolib] Erreur de choix du scheduler pour le noeud\n");
        #    colomboCigri::add_new_scheduler_event($dbh,${get_current_scheduler($dbh)}{schedulerId},"NB_NODES","Erreur de choix du scheduler pour le noeud. Le noeud est BUSY");
        #    return(1);
        #}

        #add jobs in jobs table
        my $time = get_date();
        #$sth = $dbh->prepare("SELECT MAX(jobId)+1 FROM jobs");
        #$sth->execute();
        #my @tmp = $sth->fetchrow_array();
        #$sth->finish();
        #my $id = $tmp[0];
        #if(!defined($id)) {
        #    $id = 1;
        #}

        begin_transaction($dbh);

        $dbh->do("INSERT INTO jobs (jobId,jobState,jobMJobsId,jobParam,jobName,jobClusterName,jobTSub)
        VALUES (NULL,\"toLaunch\",$MJobtoSubmit[0],\"$$parameter{parametersParam}\",\"$$parameter{parametersName}\",\"$clusterName\",\"$time\")");

        # delete used param
        $dbh->do("DELETE FROM parameters
                  WHERE parametersMJobsId = $MJobtoSubmit[0]
                  AND parametersParam = \"$$parameter{parametersParam}\"
                  LIMIT 1
                 ");

        # delete used entry in jobToSubmit
        my $newNumber = $MJobtoSubmit[1] - 1;
        #print("$newNumber\n");
        $dbh->do("UPDATE jobsToSubmit SET jobsToSubmitNumber = $newNumber
                    WHERE jobsToSubmitMJobsId = $MJobtoSubmit[0]
                          AND jobsToSubmitClusterName = \"$clusterName\"
                 ");

        # set to BUSY used nodes
        #$dbh->do("UPDATE nodes SET nodeState = \"BUSY\" WHERE nodeId = $MJobtoSubmit[1]");

        commit_transaction($dbh);
            
        $dbh->do("SELECT RELEASE_LOCK(\"cigriParamLock\")");
    }

    my %jobTmp = get_launching_job($dbh,$clusterName);
    #$dbh->do("UNLOCK TABLES");
    if (defined($jobTmp{id})){
        #print(Dumper(%jobTmp));
        %{$job} = %jobTmp;
        return(0);
    }else{
        return(2);
    }
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

# set the state of a Mjob
# arg1 --> database ref
# arg2 --> MjobsId
# arg3 --> state
sub set_mjobs_state($$$) {
    my $dbh = shift;
    my $idmJob = shift;
    my $state = shift;
    $dbh->do("    UPDATE multipleJobs SET MJobsState = \"$state\"
                WHERE MJobsId =\"$idmJob\"");
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

# get the id of a job using it's batch id and cluster
# arg1 --> database ref
# arg2 --> jobBatchId
# arg3 --> clusterName
sub get_job_id_from_batchid($$$){
    my $dbh = shift;
    my $batchId = shift;
    my $clusterName = shift;
    my $sth = $dbh->prepare("SELECT jobId FROM jobs WHERE jobBatchId = \"$batchId\"
                                AND jobClusterName =\"$clusterName\"");
    $sth->execute();
    my @res  = $sth->fetchrow_array();
    $sth->finish();
    if (defined($res[0])) { return $res[0]; }
    else { return 0; }
}


# give cluster names where jobs in Running state are executed
# arg1 --> database ref
# return a hashtable of array refs : ${${$resul{pawnee}}[0]}{batchJobId} --> give the first batchId for the cluster pawnee
sub get_job_to_update_state($){
    my $dbh = shift;
    my $sth = $dbh->prepare("SELECT jobBatchId,jobClusterName,jobId,userLogin,MJobsId,propertiesExecDirectory,jobState,unix_timestamp(jobTSub),jobName
                             FROM jobs,multipleJobs,users,properties
                             WHERE (jobState = \"Running\" or jobState = \"RemoteWaiting\")
                                and MJobsId = jobMJobsId
                                and MJobsUser = userGridName
                                and jobClusterName = userClusterName
                                and propertiesMJobsId = MJobsId
                                and propertiesClusterName = jobClusterName
                            ");
    $sth->execute();

    my %resul;

    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_cluster_active($dbh,$ref[1],$ref[4]) == 0){
            my $tmp = {
                    "jobId" => $ref[2],
                    "batchJobId" => $ref[0],
                    "clusterName" => $ref[1],
                    "user" => $ref[3],
                    "execDir" => $ref[5],
		    "jobState" => $ref[6],
		    "jobTSub" => $ref[7],
		    "jobName" => $ref[8]
            };
            push(@{$resul{$ref[1]}},$tmp);
        }
	else {
	  print "Job $ref[2] from Mjob $ref[4] is in the blaklisted cluster $ref[1]\n";
	}
    }
    $sth->finish();

    return %resul;
}

# update the number of free nodes which have a remote waiting job on
# arg1 --> database ref
# sub check_remote_waiting_jobs($){
    # my $dbh = shift;
#
    # my $sth = $dbh->prepare("select jobNodeId from jobs where jobState = \"RemoteWaiting\"");
    # $sth->execute();
#
    # my $remoteWaitingJobs ;
    # my %tmp;
    # while (my @ref = $sth->fetchrow_array()) {
        # $tmp{$ref[0]} = 1;
    # }
    # $sth->finish();
#
    # foreach my $i (keys(%tmp)){
        # $remoteWaitingJobs .= " nodeId = $i or";
    # }
    # if (defined($remoteWaitingJobs)){
        # $remoteWaitingJobs =~ s/^(.+)or$/$1/g;
        # $dbh->do("UPDATE nodes SET nodeState = \"BUSY\" WHERE $remoteWaitingJobs");
    # }
# }

# get the number of free nodes for each cluster and their free weights
# arg1 --> database ref
# return a hashtable : clusterName-->[[nodeName,nodeFreeWeight]]
sub get_nb_freeNodes($){
    my $dbh = shift;

    my $sth = $dbh->prepare("   SELECT nodeClusterName,nodeName,nodeFreeWeight
                                FROM nodes
                                WHERE nodeFreeWeight > 0
                            ");
    $sth->execute();

    my %result;
    while (my @ref = $sth->fetchrow_array()) {
        push(@{$result{$ref[0]}}, [$ref[1],$ref[2]]);
    }

    $sth->finish();

    return %result;
}

# get the number of remained jobs for MJobs
# arg1 --> database ref
sub get_nb_remained_jobs($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT parametersMJobsId, COUNT(*)
                             FROM parameters,multipleJobs
                             WHERE MJobsId = parametersMJobsId
                             AND MJobsState = \"IN_TREATMENT\"
                             GROUP BY parametersMJobsId
                             ORDER BY parametersMJobsId ASC");
    $sth->execute();

    my %result;
    while (my @ref = $sth->fetchrow_array()) {
        $result{$ref[0]} = $ref[1];
    }
    $sth->finish();

    return %result;
}

#TODO: will be replaced when new impl. of scheduler
sub get_nb_remained_jobs_by_type($$){
    my $dbh = shift;
	my $type = shift;

    my $sth = $dbh->prepare("SELECT parametersMJobsId, COUNT(*)
                             FROM parameters,multipleJobTypes
                             WHERE MJobId = parametersMJobsId
                             AND MJobTypeIndex = \"CURRENT\"
                             AND MJobType = \"$type\"
                             GROUP BY parametersMJobsId
                             ORDER BY parametersMJobsId ASC");
    $sth->execute();

    my %result;
    while (my @ref = $sth->fetchrow_array()) {
        $result{$ref[0]} = $ref[1];
    }
    $sth->finish();

    return %result;
}



# get the global weight of remote waiting jobs
# arg1 --> database ref
sub get_cluster_remoteWaiting_job_weight($){
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT jobClusterName,SUM(propertiesJobWeight)
                             FROM jobs,properties
                             WHERE jobState = \"RemoteWaiting\"
                                AND jobMJobsId = propertiesMJobsId
                             GROUP BY jobClusterName
                            ");
    $sth->execute();

    my %result;
    while (my @ref = $sth->fetchrow_array()) {
        if ($ref[1] ne "NULL"){
            $result{$ref[0]} = $ref[1];
        }
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

    my $sth = $dbh->prepare("   SELECT   propertiesClusterName,propertiesJobWeight
                                FROM properties, users, multipleJobs
                                WHERE propertiesMJobsId = $id
                                    AND propertiesClusterName = userClusterName
                                    AND userGridName = MJobsUser
                                    AND MJobsId = propertiesMJobsId
                            ");
    $sth->execute();

    my %result;
    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_cluster_active($dbh,$ref[0],$id) == 0){
            $result{$ref[0]} = $ref[1];
        }
    }
    $sth->finish();

    return %result;
}

# get MJobs active clusters ordered by priority and power
# arg1 --> database ref
# arg2 --> MJobsId
sub get_MJobs_ActiveClusters($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("   SELECT   propertiesClusterName
                                FROM properties, users, multipleJobs, clusters
                                WHERE propertiesMJobsId = $id
                                    AND propertiesClusterName = userClusterName
                                    AND userGridName = MJobsUser
                                    AND MJobsId = propertiesMJobsId
				    AND propertiesClusterName = clusterName
				    ORDER BY propertiesClusterPriority,clusterPower desc
                            ");
    $sth->execute();

    my @result;
    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_cluster_active($dbh,$ref[0],$id) == 0){
            push(@result,$ref[0]);
        }
    }
    $sth->finish();

    return @result;
}



# Add a job to launch
# arg1 --> database ref
# arg2 --> MJobsId of the job
# arg3 --> cluster name
# arg4 --> number of jobs to submit
sub add_job_to_launch($$$$){
    my $dbh = shift;
    my $MJobsId = shift;
    my $clusterName = shift;
    my $nbJobs = shift;

    $dbh->do("INSERT INTO jobsToSubmit (jobsToSubmitMJobsId,jobsToSubmitClusterName,jobsToSubmitNumber) VALUES ($MJobsId,\"$clusterName\",$nbJobs)");
}

# check and set the end of each MJob in the IN_TREATMENT state
# arg1 --> database ref
sub check_end_MJobs($){
    my $dbh = shift;
    my @MJobs = get_IN_TREATMENT_MJobs($dbh);

    my @result;
    
    foreach my $i (@MJobs){
#        print("------check $i --------\n");
        my $sth = $dbh->prepare("    SELECT jobMJobsId, count( * )
                                    FROM jobs
                                    WHERE jobMJobsId = $i
                                    AND (    jobState = \"Running\"
                                            OR jobState = \"toLaunch\"
                                            OR jobState = \"RemoteWaiting\")
                                    GROUP BY jobMJobsId
                                ");
        $sth->execute();
        my @MJobIdTmp = $sth->fetchrow_array();
        $sth->finish();

        $sth = $dbh->prepare("    SELECT jobMJobsId, count( * )
                                FROM jobs, events
                                WHERE jobMJobsId = $i
                                AND eventState = \"ToFIX\"
                                AND jobState = \"Event\"
                                AND eventMJobsId = jobMJobsId
                                AND eventJobId = jobId
                                GROUP BY jobMJobsId
                            ");
        $sth->execute();
        my @nbErrorJob = $sth->fetchrow_array();
        $sth->finish();

        if ((!@MJobIdTmp) and (!@nbErrorJob)){
            # all jobs are terminated
            $sth = $dbh->prepare("    SELECT count( * )
                                    FROM parameters
                                    WHERE parametersMJobsId = $i
                                ");
            $sth->execute();
            my @nbParamsMJob = $sth->fetchrow_array();
            $sth->finish();
            if ($nbParamsMJob[0] == 0){
                print("[Iolib] set to Terminated state the MJob $i\n");
                $dbh->do("    UPDATE multipleJobs SET MJobsState = \"TERMINATED\"
                            WHERE MJobsId = $i");
				$dbh->do("    UPDATE multipleJobTypes SET MJobTypeIndex =\"LOG\"
                            WHERE MJobId = $i");

                # notify admin by email
                #mailer::sendMail("End MJob $i ","[Iolib] set to Terminated state the MJob $i");
                push(@result, $i);
            }
        }
    }
    return(@result);
}

# update job attribute
# arg1 -->database ref
# arg2 --> jobId
# arg3 --> begin date
# arg4 --> end date
# arg5 --> return code
# arg6 --> clusterName
# arg7 --> nodeName
sub update_att_job($$$$$$$){
    my $dbh = shift;
    my $id = shift;
    my $beginDate = shift;
    my $endDate = shift;
    my $retCode = shift;
    my $clusterName = shift;
    my $nodeName = shift;

    $dbh->do("UPDATE jobs SET jobTStart = \"$beginDate\", jobTStop = \"$endDate\", jobRetCode = $retCode, jobNodeName = \"$nodeName\"
              WHERE jobId = $id");
}

# return Mjobs to collect
# arg1 --> database ref
# arg2 --> collect limit number of jobs
# return --> an array of MJobs
sub get_tocollect_MJobs($$){
    my $dbh = shift;
    my $collectLimit = shift;
    my $sth = $dbh->prepare("    SELECT jobMJobsId, COUNT( * )
                                FROM jobs
                                WHERE jobState = \"Terminated\"
                                AND jobCollectedJobId = 0
                                GROUP BY jobMJobsId
                            ");
    $sth->execute();
    my @result;

    while (my @ref = $sth->fetchrow_array()) {
        if ($ref[1] >= $collectLimit){
            push(@result, $ref[0]);
        }
    }

    $sth->finish();
    return @result;
}

# return infos of a specified MJob
# arg1 --> database ref
# arg2 --> MJobId
# return --> an array of jobs with their properties
sub get_tocollect_MJob_files($$){
    my $dbh = shift;
    my $MJobId = shift;
    my $sth = $dbh->prepare("   SELECT jobClusterName, userLogin, jobBatchId, clusterBatch, jobId, userGridName, jobName, propertiesExecDirectory
                                FROM jobs, multipleJobs, users, clusters, properties
                                WHERE jobMJobsId = $MJobId
                                AND jobMJobsId = MJobsId
                                AND propertiesMJobsId = jobMJobsId
                                AND MJobsUser = userGridName
                                AND jobState = \"Terminated\"
                                AND jobCollectedJobId = 0
                                AND clusterName = jobClusterName
                                AND userClusterName = clusterName
                                AND propertiesClusterName = jobClusterName
                                ORDER BY clusterName
                            ");
    $sth->execute();
    my @result;

    while (my $ref = $sth->fetchrow_hashref()) {
        push(@result, $ref);
    }

    $sth->finish();
    return @result;
}

# add a new collector entry
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> MJobId
sub create_new_collector($$$) {
    my $dbh = shift;
    my $cluster = shift;
    my $MJob = shift;

    my $sth = $dbh->prepare("SELECT MAX(collectedJobsId)+1 FROM collectedJobs WHERE collectedJobsMJobsId = $MJob");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values(%$ref);
    my $id = $tmp[0];
    $sth->finish();
    if($id eq "") {
        $id = 1;
    }

    my $fileName = "$id.$cluster";
    $dbh->do("INSERT INTO collectedJobs (collectedJobsMJobsId,collectedJobsId,collectedJobsFileName)
                VALUES (\"$MJob\",\"$id\",\"$fileName\")");
    my @res = ($MJob,$id,$fileName);
    return @res;
}

# set the collectedId cell of a job
# arg1 --> database ref
# arg2 --> jobId
# arg3 --> collectedJobId
sub set_job_collectedJobId($$$){
    my $dbh = shift;
    my $jobId = shift;
    my $collectedJobId = shift;

    $dbh->do("UPDATE jobs SET jobCollectedJobId = $collectedJobId where jobId = $jobId");
}

# return the current scheduler
# arg1 --> database ref
sub get_current_scheduler($){
    my $dbh = shift;

    my $sth = $dbh->prepare("    SELECT schedulerId, schedulerFile
                                FROM currentScheduler, schedulers
                                WHERE currentSchedulerId = schedulerId
                                LIMIT 1
                            ");
    $sth->execute();
    my $result  = $sth->fetchrow_hashref();

    $sth->finish();

    return $result;

}

# set the current scheduler table
# arg1 --> database ref
sub update_current_scheduler($){
    my $dbh = shift;
    my @badScheds;

    my $sth = $dbh->prepare("    SELECT schedulerId, schedulerFile, schedulerPriority
                            FROM schedulers
                            ORDER BY schedulerPriority DESC
                        ");
    $sth->execute();
    my $schedId;
    while (my @ref = $sth->fetchrow_array()) {
        if (colomboCigri::is_scheduler_active($dbh,$ref[0]) == 0){
            $schedId = $ref[0];
            last;
        }
    }

    $sth->finish();

    $dbh->do("TRUNCATE TABLE currentScheduler");
    if (defined($schedId)){
        $dbh->do("INSERT INTO currentScheduler (currentSchedulerId) VALUES ($schedId)");
    }
}

sub begin_transaction($){
    my $dbh = shift;
    $dbh->begin_work;
}

sub commit_transaction($){
    my $dbh = shift;
    $dbh->commit;
}

sub rollback_transaction($){
    my $dbh = shift;
    $dbh->rollback;
}

sub lock_collector($$){
    my $dbh = shift;
    my $lockTime = shift;
    #$dbh->do("LOCK TABLES semaphoreCollector WRITE");
    $dbh->do("SELECT GET_LOCK(\"cigriCollectorLock\",$lockTime)");
}

sub unlock_collector($){
    my $dbh = shift;
    #$dbh->do("UNLOCK TABLES");
    $dbh->do("SELECT RELEASE_LOCK(\"cigriCollectorLock\")");
}

# return MJob to frag
# arg1 --> database ref
# return --> an array of MJobsId
sub get_tofrag_MJobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("    SELECT eventMJobsId
                                FROM fragLog, events
                                WHERE fragLogEventId = eventId
                                AND eventState = \"ToFIX\"
                                AND eventClass = \"MJOB\"
                                AND eventType = \"FRAG\"
                            ");


    $sth->execute();
    my @result;

    while (my @ref = $sth->fetchrow_array()) {
        push(@result, $ref[0]);
    }

    $sth->finish();
    return @result;
}

# return jobId to frag
# arg1 --> database ref
# return --> an array of jobsId
sub get_tofrag_jobs($){
    my $dbh = shift;
    my $sth = $dbh->prepare("    SELECT jobId, jobBatchId, clusterName, clusterBatch, userLogin, eventId
                                FROM fragLog, events, jobs, users, clusters, multipleJobs
                                WHERE fragLogEventId = eventId
                                AND eventState = \"ToFIX\"
                                AND eventClass = \"JOB\"
                                AND eventType = \"FRAG\"
                                AND eventJobId = jobId
                                AND jobClusterName = clusterName
                                AND clusterName = userClusterName
                                AND MJobsUser = userGridName
                                AND jobMJobsId = MJobsId
                            ");
    $sth->execute();
    my @result;

    while (my $ref = $sth->fetchrow_hashref()) {
        push(@result, $ref);
    }

    $sth->finish();
    return @result;
}

# delete all parameters of a MJobs
# arg1 --> database ref
# arg2 --> MJobId
sub delete_all_MJob_parameters($$){
    my $dbh = shift;
    my $MJobId = shift;

    $dbh->do("DELETE FROM parameters WHERE parametersMJobsId = $MJobId");
}

# add FRAG event for all jobs from a specific MJobId
# arg1 --> database ref
# arg2 --> MJobId
sub set_frag_specific_MJob($$){
    my $dbh = shift;
    my $MJobId = shift;

    my $sth = $dbh->prepare("    SELECT jobId
                                FROM jobs
                                WHERE (jobState = \"toLaunch\"
                                    OR jobState = \"RemoteWaiting\"
                                    OR jobState = \"Running\")
                                AND jobMJobsId = $MJobId
                            ");
    $sth->execute();

    while (my @ref = $sth->fetchrow_array()) {
        set_job_state($dbh, $ref[0], "Event");
        colomboCigri::add_new_job_event($dbh,$ref[0],"FRAG","");
    }

    $sth->finish();
    
    # notify admin by email
    #mailer::sendMail("Frag MJob $MJobId","");
}

# get the eventId of the MJobs tofrag
# arg1 --> database ref
# arg2 --> MJobsId
sub get_MJobs_tofrag_eventId($$){
    my $dbh = shift;
    my $MJobId = shift;

    my $sth = $dbh->prepare("    SELECT eventId
                                FROM events
                                WHERE eventState = \"ToFIX\"
                                AND eventMJobsId = $MJobId
                                AND eventClass = \"MJOB\"
                                AND eventType = \"FRAG\"
                                LIMIT 1
                            ");
    $sth->execute();

    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return $ref[0];
}

# get the user name of the specified MJob
# arg1 --> database ref
# arg2 --> MJobId
# return the user name
sub get_MJob_user($$){
    my $dbh = shift;
    my $MJobId = shift;

    my $sth = $dbh->prepare(" SELECT MJobsUser
                              FROM multipleJobs
                              WHERE
                                 MJobsId = $MJobId
                            ");
    $sth->execute();

    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return($ref[0]);
}


# get the user name of the specified Job
# arg1 --> database ref
# arg2 --> JobId
# return the user name
sub get_job_user($$){
    my $dbh = shift;
    my $jobId = shift;

    my $sth = $dbh->prepare(" SELECT MJobsUser
                              FROM multipleJobs, jobs
                              WHERE
                                     jobId = $jobId
                                 AND MJobsId = jobMJobsId
                            ");
    $sth->execute();

    my @ref = $sth->fetchrow_array();
    $sth->finish();

    return($ref[0]);
}

# update the forcecast for a given multijob
# arg1 --> database ref
# arg2 --> MjobsId
# arg3 --> average
# arg4 --> stddev
# arg4 --> throughput
# arg5 --> end time
sub update_mjob_forecast($$$$$$){
    my $dbh = shift;
    my $MjobsId = shift;
    my $average = shift;
    my $stddev = shift;
    my $throughput = shift;
    my $endtime = shift;

    my $sth = $dbh->prepare(" SELECT MjobsId
                              FROM forecasts
                              WHERE
                                     MjobsId = $MjobsId
                            ");
    $sth->execute();

    if ($sth->fetchrow_array()) {
        my $sth = $dbh->prepare(" UPDATE forecasts
	                          SET 
				    average='$average',
                                    stddev='$stddev',
                                    throughput='$throughput',
				    end='$endtime'
	                          WHERE
				    MjobsId='$MjobsId'
				");
        $sth->execute(); 
    }else {
        my $sth = $dbh->prepare(" INSERT INTO forecasts
	                          (MjobsId,average,stddev,throughput,end)
				  VALUES
				  ('$MjobsId','$average','$stddev','$throughput','$endtime')
				");
        $sth->execute();
    }
}    

# get the MjobsId of a jobId
# arg1 --> database ref
# arg2 --> jobId

sub get_MjobsId($$) {
    my $dbh = shift;
    my $jobId = shift;
    my $sth = $dbh->prepare("SELECT jobMJobsId
                             FROM jobs
                             WHERE jobId = $jobId");
    $sth->execute();
    my @res  = $sth->fetchrow_array();
    $sth->finish();
    if (defined($res[0])) { return $res[0]; }
    else { return 0; }
}

return 1;
