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


my %nodeCmd = ('PBS' => \&pbsnodes,
               'OAR' => \&oarnodes,
               'OAR_mysql' => \&oarnodesMysql);

#arg1 --> cluster name
sub updateNodeStat($){
    my $cluster = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$nodeCmd{$clusterProperties{$cluster}}}($base,$cluster);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

#arg1 --> db ref
#arg2 --> cluster name
sub pbsnodes($$){
    my $dbh = shift;
    my $cluster = shift;

    print("PBS NOT IMPLEMENTED -- $cluster\n");
    my %nodeState;
    undef(%nodeState);
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
sub oarnodes($$){
    my $dbh = shift;
    my $cluster = shift;

    print("$cluster --> OAR\n");
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
            my $state;
            my $besteffort;
            my $lineTmp;
            my $key;
            # parse pbsnodes command
            while ((! defined($state) || (! defined($besteffort))) && ($#lines >= 0)){
                $lineTmp = shift(@lines);
                if ($lineTmp =~ /state =/){
                    ($key, $state) = split("=", $lineTmp);
                    # I drop spaces
                    $state =~ s/\s//g;
                }elsif ($lineTmp =~ /properties =/){
                    $lineTmp =~ /^.+besteffort=(YES|NO).*$/;
                    $besteffort = $1;
                }
            }
            if (defined($name) && defined($state) && defined($besteffort)){
                if ($besteffort eq "YES"){
                    # Databse update
                    iolibCigri::set_cluster_node_state($dbh, $cluster, $name, $state);
                }
            }else{
                print("[UPDATOR] There is an error in the oarnodes command parse, node=$name;state=$state\n");
                colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_PBSNODES_PARSE","There is an error in the oarnodes command parse, node=$name;state=$state");
                return(-1);
            }
        }
    }else{
        print("[UPDATOR_ERROR] There is an error in the execution of the oarnodes command via SSH \n--> I disable all nodes of the cluster $cluster \n");
        print("[UPDATOR_ERROR] $cmdResult{STDERR}\n");
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
sub oarnodesMysql($$){
    my $dbh = shift;
    my $cluster = shift;

    print("$cluster --> OAR_mysql\n");
    my $OARdb = OARiolib::connect($dbh,$cluster);
    if (!defined($OARdb)){
        return(-1);
    }
    my %nodeState = OARiolib::getFreeNodes($OARdb);
    foreach my $i (keys(%nodeState)){
        iolibCigri::set_cluster_node_state($dbh, $cluster, $i, $nodeState{$i});
    }
    OARiolib::disconnect($dbh);

    return(1);
}

return 1;

