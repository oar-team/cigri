package nodeStat;

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
    unshift(@INC, $relativePath."Colombo");
}
use iolibCigri;
use SSHcmdClient;
use colomboCigri;
use NetCommon;
use warnings;
use OARiolib;


my %nodeCmd = (
               'OAR' => \&oarnodes,
               'OAR2' => \&oarnodes2,
               'OAR2_3' => \&oarnodes2,
               'OAR2_4' => \&oarnodes2_4,
              );

#arg1 --> cluster name
sub updateNodeStat($){
    my $cluster = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && $clusterProperties{$cluster}){
        $retCode = &{$nodeCmd{$clusterProperties{$cluster}}}($base,$cluster);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}


#arg1 --> db ref
#arg2 --> cluster name
sub oarnodes($$){
    my $dbh = shift;
    my $cluster = shift;

    #print("$cluster --> OAR\n");
    my %nodeState;

    my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarnodes -a");
    my $pbsnodesStr = $cmdResult{STDOUT};
    if ($cmdResult{STDERR} eq ""){
        chomp($pbsnodesStr);
        my @nodesStrs = split(/^\s*\n/m,$pbsnodesStr);
        foreach my $nodeStr (@nodesStrs){
            my @lines = split(/\n/, $nodeStr);
            my $name = shift(@lines);
            $name =~ s/\s//g;
            my $currentWeight;
            my $maxWeight;
            my $besteffort;
            my $state;
            my $lineTmp;
            my $key;
            # parse pbsnodes command
            while ((! defined($currentWeight) || (! defined($maxWeight)) || (! defined($besteffort))) && ($#lines >= 0)){
                $lineTmp = shift(@lines);
                if ($lineTmp =~ /weight =/){
                    ($key, $currentWeight) = split("=", $lineTmp);
                    # I drop spaces
                    $currentWeight =~ s/\s//g;
                }elsif ($lineTmp =~ /pcpus =/){
                    ($key, $maxWeight) = split("=", $lineTmp);
                    # I drop spaces
                    $maxWeight =~ s/\s//g;
                }elsif ($lineTmp =~ /properties =/){
                    $lineTmp =~ /^.+besteffort=(YES|NO).*$/;
                    $besteffort = $1;
                }elsif ($lineTmp =~ /state =/){
                    ($key, $state) = split("=", $lineTmp);
                    # I drop spaces
                    $state =~ s/\s//g;
                }

            }
            if (defined($name) && defined($maxWeight) && defined($currentWeight) && defined($besteffort) && defined($state)){
                if (($besteffort eq "YES") && (($state eq "job") || ($state eq "free"))){
                    # Databse update
                    iolibCigri::set_cluster_node_max_weight($dbh, $cluster, $name, $maxWeight);
                    iolibCigri::set_cluster_node_free_weight($dbh, $cluster, $name, $maxWeight-$currentWeight);
                }
            }else{
                print("[UPDATOR] There is an error in the oarnodes command parse, node=$name;state=$state\n");
                colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_PARSE","There is an error in the oarnodes command parse, node=$name;state=$state");
                return(-1);
            }
        }
    }else{
        print("[UPDATOR]     ERROR: There is an error in the execution of the oarnodes command via SSH \n--> I disable all nodes of the cluster $cluster \n");
        print("[UPDATOR]     ERROR: $cmdResult{STDERR}\n");
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_CMD","There is an error in the execution of the oarnodes command via SSH-->I disable all nodes of the cluster $cluster;$cmdResult{STDERR}");
        }
        return(-1);
    }
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
sub oarnodes2($$){
    my $dbh = shift;
    my $cluster = shift;
    my %clusterResourceUnit = iolibCigri::get_cluster_names_resource_unit($dbh);
    my %clusterProperties = iolibCigri::get_cluster_names_properties($dbh);
    my $filter_prop;
    my $filter_val;
    ($filter_prop,$filter_val)=split(/=/,$clusterProperties{$cluster});
    if ("$filter_prop" eq "1") { $filter_prop="besteffort"; $filter_val="YES";}
    my $resourceUnit=$clusterResourceUnit{$cluster};
    #print("$cluster --> OAR2, unit:$resourceUnit\n");
    my %nodeState;
    #my $properties=$clusterProperties{$cluster};
    #my $cmd="oarnodes -D --sql \"$properties\""; # Doesn't work - quotes problem Mysql/Pg :-(
    my $cmd="oarnodes -D";
   # my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarnodes --backward");
    my %cmdDump = SSHcmdClient::submitCmd($cluster,$cmd);
    my $oarnodesStr = $cmdDump{STDOUT};
    if ($cmdDump{STDERR} eq ""){
      my $oarnodes=eval($oarnodesStr);
      if (%{$oarnodes}) {
        foreach my $node (keys(%{$oarnodes})) {
           my %jobs;
           my %maxWeight;
           my %totalWeight;
           foreach my $resource (keys(%{$oarnodes->{$node}})) {
             if ("$oarnodes->{$node}->{$resource}->{network_address}" ne "") {
	       # Get the id of the "cpu" or "core"
	       $resourceUnitId=$oarnodes->{$node}->{$resource}->{properties}->{$resourceUnit};
	       # Count resources per cpu or core (yes, we can have several resources per core sometimes
	       # on shared memory computers were we have several routers for example)
               $totalWeight{$resourceUnitId}++ if ($oarnodes->{$node}->{$resource}->{properties}->{besteffort} eq "YES"
	                                           &&
						   $oarnodes->{$node}->{$resource}->{properties}->{$filter_prop} eq "$filter_val");
               $maxWeight{$resourceUnitId}++ if (
	                                         (
						  $oarnodes->{$node}->{$resource}->{state} eq "Alive"
	                                             ||
	                                          (
						   $oarnodes->{$node}->{$resource}->{state} eq "Absent" 
						     &&
						   (
						    defined($oarnodes->{$node}->{$resource}->{properties}->{cm_availability})
						       &&
						    $oarnodes->{$node}->{$resource}->{properties}->{cm_availability} > time() 
						       &&
						    $oarnodes->{$node}->{$resource}->{properties}->{cm_availability} != 2147483647
						   )
						  )
						 )
                                                   && 
				                  $oarnodes->{$node}->{$resource}->{properties}->{besteffort} eq "YES"
						   &&
						  $oarnodes->{$node}->{$resource}->{properties}->{$filter_prop} eq "$filter_val"
						);
                 foreach my $line (keys(%{$oarnodes->{$node}->{$resource}})) {
                     if ($line eq "jobs") { $jobs{$resourceUnitId}++; }
                 }
             }else{
               print("[UPDATOR]     ERROR: There is an error in the oarnodes command ($cmd) parsing: network_address not found\n");
               colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_PARSE",
                           "There is an error in the oarnodes command ($cmd) parsing: network_address not found");
               return(-1);
             }
           }
	   # We only want the real resources, so we count unique resourceUnit
	   my $jobs=0;
	   my $maxWeight=0;
	   my $totalWeight=0;	    
	   foreach my $resource (keys(%totalWeight)) { 
	     $jobs++ if($jobs{$resource});
	     $maxWeight++ if ($maxWeight{$resource});
	     $totalWeight++ if ($totalWeight{$resource});
	   }
           # database update
	   if ($totalWeight > 0 ) {
             iolibCigri::set_cluster_node_free_weight($dbh, $cluster, $node, $maxWeight-$jobs);
             iolibCigri::set_cluster_node_max_weight($dbh, $cluster, $node, $totalWeight);
	   }
           #print "$node: $maxWeight-$jobs\n";
        }
      }else{
        print("[UPDATOR]     ERROR: There is an error in the oarnodes command ($cmd) parsing\n");
        colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_PARSE",
                           "There is an error in the oarnodes command ($cmd) parsing");
        return(-1);
      }
    }else{
      print("[UPDATOR]     ERROR: There is an error in the execution of the oarnodes command ($cmd) via SSH\n");
      print("  --> I disable all nodes of the cluster $cluster \n");
      print("[UPDATOR]     ERROR: $cmdDump{STDERR}\n");
      # Test if this is an SSH error
      if (NetCommon::checkSshError($dbh,$cluster,$cmdDump{STDERR}) != 1){
         colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_CMD",
              "There is an error in the execution of the oarnodes command via SSH"
              ." -->I disable all nodes of the cluster $cluster;$cmdDump{STDERR}");
      return(-1);
      }
    }
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
sub oarnodes2_4($$){
    my $dbh = shift;
    my $cluster = shift;
    my %clusterResourceUnit = iolibCigri::get_cluster_names_resource_unit($dbh);
    my %clusterProperties = iolibCigri::get_cluster_names_properties($dbh);
    my $filter_prop;
    my $filter_val;
    ($filter_prop,$filter_val)=split(/=/,$clusterProperties{$cluster});
    if ("$filter_prop" eq "1") { $filter_prop="besteffort"; $filter_val="YES";}
    my $resourceUnit=$clusterResourceUnit{$cluster};
    #print("$cluster --> OAR2, unit:$resourceUnit\n");
    my %nodeState;
    #my $properties=$clusterProperties{$cluster};
    #my $cmd="oarnodes -D --sql \"$properties\""; # Doesn't work - quotes problem Mysql/Pg :-(
    my $cmd="oarnodes.old -D 2>/dev/null";
   # my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarnodes --backward");
    my %cmdDump = SSHcmdClient::submitCmd($cluster,$cmd);
    my $oarnodesStr = $cmdDump{STDOUT};
    if ($cmdDump{STDERR} eq ""){
      my $oarnodes=eval($oarnodesStr);
      if ( %{$oarnodes}) {
        foreach my $node (keys(%{$oarnodes})) {
           my %jobs;
           my %maxWeight;
           my %totalWeight;
           foreach my $resource (keys(%{$oarnodes->{$node}})) {
             if ("$oarnodes->{$node}->{$resource}->{network_address}" ne "") {
	       # Get the id of the "cpu" or "core"
	       $resourceUnitId=$oarnodes->{$node}->{$resource}->{properties}->{$resourceUnit};
	       # Count resources per cpu or core (yes, we can have several resources per core sometimes
	       # on shared memory computers were we have several routers for example)
               $totalWeight{$resourceUnitId}++ if ($oarnodes->{$node}->{$resource}->{properties}->{besteffort} eq "YES"
	                                           &&
						   $oarnodes->{$node}->{$resource}->{properties}->{$filter_prop} eq "$filter_val");
               $maxWeight{$resourceUnitId}++ if (
	                                         (
						  $oarnodes->{$node}->{$resource}->{state} eq "Alive"
	                                             ||
	                                          (
						   $oarnodes->{$node}->{$resource}->{state} eq "Absent" 
						     &&
						   (
						    defined($oarnodes->{$node}->{$resource}->{properties}->{available_upto})
						       &&
						    $oarnodes->{$node}->{$resource}->{properties}->{available_upto} > time() 
						       &&
						    $oarnodes->{$node}->{$resource}->{properties}->{available_upto} != 2147483647
						   )
						  )
						 )
                                                   && 
				                  $oarnodes->{$node}->{$resource}->{properties}->{besteffort} eq "YES"
						   &&
						  $oarnodes->{$node}->{$resource}->{properties}->{$filter_prop} eq "$filter_val"
						);
                 foreach my $line (keys(%{$oarnodes->{$node}->{$resource}})) {
                     if ($line eq "jobs") { $jobs{$resourceUnitId}++; }
                 }
             }else{
               print("[UPDATOR]     ERROR: There is an error in the oarnodes command ($cmd) parsing: network_address not found\n");
               colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_PARSE",
                           "There is an error in the oarnodes command ($cmd) parsing: network_address not found");
               return(-1);
             }
           }
	   # We only want the real resources, so we count unique resourceUnit
	   my $jobs=0;
	   my $maxWeight=0;
	   my $totalWeight=0;	    
	   foreach my $resource (keys(%totalWeight)) { 
	     $jobs++ if($jobs{$resource});
	     $maxWeight++ if ($maxWeight{$resource});
	     $totalWeight++ if ($totalWeight{$resource});
	   }
           # database update
	   if ($totalWeight > 0 ) {
             iolibCigri::set_cluster_node_free_weight($dbh, $cluster, $node, $maxWeight-$jobs);
             iolibCigri::set_cluster_node_max_weight($dbh, $cluster, $node, $totalWeight);
	   }
           #print "$node: $maxWeight-$jobs\n";
        }
      }else{
        print("[UPDATOR]     ERROR: There is an error in the oarnodes command ($cmd) parsing\n");
        colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_PARSE",
                           "There is an error in the oarnodes command ($cmd) parsing");
        return(-1);
      }
    }else{
      print("[UPDATOR]     ERROR: There is an error in the execution of the oarnodes command ($cmd) via SSH\n");
      print("  --> I disable all nodes of the cluster $cluster \n");
      print("[UPDATOR]     ERROR: $cmdDump{STDERR}\n");
      # Test if this is an SSH error
      if (NetCommon::checkSshError($dbh,$cluster,$cmdDump{STDERR}) != 1){
         colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_CMD",
              "There is an error in the execution of the oarnodes command via SSH"
              ." -->I disable all nodes of the cluster $cluster;$cmdDump{STDERR}");
      return(-1);
      }
    }
    return(1);
}


return 1;

