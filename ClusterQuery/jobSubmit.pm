package jobSubmit;

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
    unshift(@INC, $relativePath."ClusterQuery");
}

use iolibCigri;
#use SSHcmdClient;
use SSHcmd;
use colomboCigri;
use NetCommon;
use warnings;
use OARiolib;
use oarNotify;


my %submitCmd = ('PBS' => \&pbssubmit,
                  'OAR' => \&oarsubmit,
                  'OAR2' => \&oarsubmit2,
                  'OAR_mysql' => \&oarsubmitMysql);

#arg1 --> cluster name
#arg2 --> blacklisted nodes
#arg3 --> user
#arg4 --> jobFile to submit
#arg5 --> walltime of the job
#arg6 --> weight of the job
#arg7 --> execution directory
#return jobBatchId or -1 or -2 if something wrong happens
sub jobSubmit($$$$$$$){
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
    my $weight = shift;
    my $execDir = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %clusterResourceUnit = iolibCigri::get_cluster_names_resource_unit($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$submitCmd{$clusterProperties{$cluster}}}($base,$cluster,$blackNodes,$user,$jobFile,$walltime,$weight,$execDir,$clusterResourceUnit{$cluster});
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

my %clusterToNotify;

#arg1 --> cluster name
# return 0 if Ok
sub endJobSubmissions($){
    my $cluster = shift;

    my $retCode = 0;
    if (defined($clusterToNotify{$cluster})){
        $retCode = oarNotify::notify($cluster,"Qsub");
    }

    return($retCode);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> black nodes
#arg4 --> user
#arg5 --> jobFile to submit
#arg6 --> walltime
#arg7 --> weight
#arg8 --> execDir
#arg9 --> resrouce unit (cpu or core, or...)
sub pbssubmit($$$$$$$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
    my $weight = shift;
    my $execDir = shift;
    my $resourceUnit = shift;

    print("PBS NOT IMPLEMENTED -- $cluster\n");
    return(-1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> blacklisted nodes
#arg4 --> user
#arg5 --> jobFile to submit
#arg6 --> walltime
#arg7 --> weight
#arg8 --> execDir
#arg9 --> resrouce unit (cpu or core, or...)
#return jodBatchId or
#   -1 : for a command execution error
#   -2 : for a jobId parse error
sub oarsubmit($$$$$$$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
    my $weight = shift;
    my $execDir = shift;
    my $resourceUnit = shift;

    print("$cluster --> OAR\n");
    #my $weight = iolibCigri::get_cluster_default_weight($dbh,$cluster);
    #my %cmdResult = SSHcmdClient::submitCmd($cluster,"cd ~$user; sudo -u $user oarsub -l nodes=1,weight=$weight -q besteffort ~$user/$jobFile");

    my $propertyString;
    foreach my $i (@$blackNodes){
        $propertyString .= " hostname != '\\'$i\\'' AND";
    }
    if (defined($propertyString)){
        $propertyString =~ s/^(.+)AND$/$1/g;
    }else{
        $propertyString = "";
    }
    print("Property String = $propertyString\n");
    #my %cmdResult = SSHcmd::submitCmd($cluster,"cd ~$user; sudo -H -u $user oarsub -l nodes=1,weight=$weight,walltime=$walltime -p \"$propertyString\" -q besteffort $jobFile");
    my %cmdResult = SSHcmd::submitCmd($cluster,"sudo -H -u $user bash -l -c \"cd $execDir; oarsub -l nodes=1,weight=$weight,walltime=$walltime -p \\\"$propertyString\\\" -q besteffort $jobFile\"");
    #print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"OAR_OARSUB","$cmdResult{STDERR}");
        }
        return(-1);
    }
    my @strTmp = split(/\n/, $cmdResult{STDOUT});
    foreach my $k (@strTmp){
        # search cluster batchId of the job
        if ($k =~ /\s*IdJob\s=\s(\d+)/){
            return($1);
        }
    }
    return(-2);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> blacklisted nodes
#arg4 --> user
#arg5 --> jobFile to submit
#arg6 --> walltime
#arg7 --> weight
#arg8 --> execDir
#arg9 --> resrouce unit (cpu or core, or...)
#return jodBatchId or
#   -1 : for a command execution error
#   -2 : for a jobId parse error
sub oarsubmit2($$$$$$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
    my $weight = shift;
    my $execDir = shift;
    my $resourceUnit = shift;
    if ($resourceUnit eq '') {$resourceUnit="cpu";}

    print("$cluster --> OAR2\n");
    #my $weight = iolibCigri::get_cluster_default_weight($dbh,$cluster);
    #my %cmdResult = SSHcmdClient::submitCmd($cluster,"cd ~$user; sudo -u $user oarsub -l nodes=1,weight=$weight -q besteffort ~$user/$jobFile");

    my $propertyString;
    foreach my $i (@$blackNodes){
        $propertyString .= " network_address != '\\'$i\\'' AND";
    }
    if (defined($propertyString)){
        $propertyString =~ s/^(.+)AND$/$1/g;
    }else{
        $propertyString = "";
    }
    print("Property String = $propertyString\n");
    #my %cmdResult = SSHcmd::submitCmd($cluster,"cd ~$user; sudo -H -u $user oarsub -l nodes=1,weight=$weight,walltime=$walltime -p \"$propertyString\" -q besteffort $jobFile");
    my %cmdResult = SSHcmd::submitCmd($cluster,"sudo -H -u $user bash -l -c \"cd $execDir; oarsub -d $execDir -l nodes=1/$resourceUnit=$weight,walltime=$walltime -p \\\"$propertyString\\\" -t besteffort $jobFile\"");
    print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"OAR_OARSUB","$cmdResult{STDERR}");
        }
        return(-1);
    }
    my @strTmp = split(/\n/, $cmdResult{STDOUT});
    foreach my $k (@strTmp){
        # search cluster batchId of the job
        if ($k =~ /\s*JOB_ID\s*=\s*(\d+)/){
            return($1);
        }
    }
    return(-2);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> blacklisted nodes
#arg4 --> user
#arg5 --> jobFile to submit
#arg6 --> walltime
#arg7 --> weight
#return jodBatchId or -1 for an error
sub oarsubmitMysql($$$$$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    #not implemented
    my $walltime = shift;
    my $weight = shift;

    print("OAR_mysql -- $cluster\n");
    my $OARdb = OARiolib::connect($dbh,$cluster);
    if (!defined($OARdb)){
        return(-1);
    }
    my $jobBatchId = OARiolib::submitJob($OARdb,$dbh,$cluster,$user,$jobFile,$blackNodes);
    OARiolib::disconnect($dbh);

    # Notify OAR
    $clusterToNotify{$cluster} = 1;

    return($jobBatchId);
}

return 1;

