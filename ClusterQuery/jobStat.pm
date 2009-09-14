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


my %qstatCmd = ( 'OAR' => \&oarstat,
                 'OAR2' => \&oarstat2,
                 'OAR2_3' => \&oarstat2);

#arg1 --> cluster name
#arg2 --> ref to the status hash
#arg3 --> ref to the resources number hash
sub jobStat($$$){
    my $cluster = shift;
    my $statusHash = shift;
    my $resourcesnumberHash = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$qstatCmd{$clusterProperties{$cluster}}}($base,$cluster,$statusHash,$resourcesnumberHash);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> ref to the status hash
#arg4 --> ref to the used resources number hash
sub oarstat($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $statusHash = shift;
    my $resourcesnumberHash = shift;

    #print("$cluster --> OAR\n");
    my %jobState;
    my %jobResources;
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarstat -f");
    #print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        print("\t[UPDATOR]     ERROR: $cmdResult{STDERR}\n");
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
            $jobResources{$1} = 1;
        }
    }

    %{$statusHash} = %jobState;
    %{$resourcesnumberHash} = %jobResources;
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> ref to the status hash
#arg4 --> ref to the used resources number hash
sub oarstat2($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $statusHash = shift;
    my $resourcesnumberHash = shift;

    #print("$cluster --> OAR2\n");
    my %jobState;
    my %jobResources;
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarstat -D");
    #print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        print("\t[UPDATOR]     ERROR: $cmdResult{STDERR}\n");
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"UPDATOR_QSTAT_CMD","$cmdResult{STDERR}");
        }
        return(-1);
    }else{
        my $oarjobs=(eval$cmdResult{STDOUT});
        if (defined %{$oarjobs}) {
          foreach my $job (keys(%{$oarjobs})) {
            $oarjobs->{$job}->{state} =~ /^(.).*/s;
            if ($1 eq "L") {$jobState{$job} = "R"}
            else {$jobState{$job} = $1;}
            $jobResources{$job} = $#{$oarjobs->{$job}->{assigned_resources}}+1;
          }
        }
    }

    %{$statusHash} = %jobState;
    %{$resourcesnumberHash} = %jobResources;
    return(1);
}

return 1;

