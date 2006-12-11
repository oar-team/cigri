package jobStat;

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


my %qstatCmd = ('PBS' => \&pbsstat,
                'OAR' => \&oarstat,
                'OAR2' => \&oarstat2,
                'OAR_mysql' => \&oarstatMysql);

#arg1 --> cluster name
#arg2 --> ref to the result hash
sub jobStat($$){
    my $cluster = shift;
    my $resRefHash = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$qstatCmd{$clusterProperties{$cluster}}}($base,$cluster,$resRefHash);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> ref to the result hash
sub pbsstat($$$){
    my $dbh = shift;
    my $cluster = shift;
    my $resRefHash = shift;

    print("PBS NOT IMPLEMENTED -- $cluster\n");
    my %jobState;
    undef(%jobState);
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> ref to the result hash
sub oarstat($$$){
    my $dbh = shift;
    my $cluster = shift;
    my $resRefHash = shift;

    print("$cluster --> OAR\n");
    my %jobState;
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarstat -f");
    #print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        print("\t[UPDATOR_ERROR] $cmdResult{STDERR}\n");
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_QSTAT_CMD","$cmdResult{STDERR}");
        }
        return(-1);
    }else{
        my $qstatStr = $cmdResult{STDOUT};
        chomp($qstatStr);
        my @jobsStrs = split(/^\s*\n/m,$qstatStr);
        # for each job section, record its state
        foreach my $jobStr (@jobsStrs){
            $jobStr =~ /Job Id: (\d+).*job_state = (.).*/s;
            #print("[UPDATOR_DEBUG] $jobStr\n");
            $jobState{$1} = $2;
        }
    }

    %{$resRefHash} = %jobState;
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> ref to the result hash
sub oarstat2($$$){
    my $dbh = shift;
    my $cluster = shift;
    my $resRefHash = shift;

    print("$cluster --> OAR2\n");
    my %jobState;
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarstat -f");
    #print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        print("\t[UPDATOR_ERROR] $cmdResult{STDERR}\n");
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_QSTAT_CMD","$cmdResult{STDERR}");
        }
        return(-1);
    }else{
        my $qstatStr = $cmdResult{STDOUT};
        chomp($qstatStr);
        my @jobsStrs = split(/^\s*\n/m,$qstatStr);
        # for each job section, record its state
        foreach my $jobStr (@jobsStrs){
            $jobStr =~ /Job_Id: (\d+).*state = (.).*/s;
            #print("[UPDATOR_DEBUG] $jobStr\n");
            $jobState{$1} = $2;
        }
    }

    %{$resRefHash} = %jobState;
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> ref to the result hash
sub oarstatMysql($$$){
    my $dbh = shift;
    my $cluster = shift;
    my $resRefHash = shift;
    my $nodeRefHash = shift;

    print("OAR_mysql -- $cluster\n");
    my $OARdb = OARiolib::connect($dbh,$cluster);
    if (!defined($OARdb)){
        return(-1);
    }
    my %jobState = OARiolib::listCurrentJobs($OARdb);
    OARiolib::disconnect($dbh);

    %{$resRefHash} = %jobState;
    return(1);
}

return 1;

