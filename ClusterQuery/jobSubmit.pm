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
use SSHcmdClient;
use colomboCigri;
use NetCommon;
use warnings;
use OARiolib;
use oarNotify;


my %submitCmd = ('PBS' => \&pbssubmit,
                  'OAR' => \&oarsubmit,
                  'OAR_mysql' => \&oarsubmitMysql);

#arg1 --> cluster name
#arg2 --> user
#arg3 --> jobFile to submit
#return jobBatchId or -1 or -2 if something wrong happens
sub jobSubmit($$$){
    my $cluster = shift;
    my $user = shift;
    my $jobFile = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$submitCmd{$clusterProperties{$cluster}}}($base,$cluster,$user,$jobFile);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobFile to submit
sub pbssubmit($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobFile = shift;

    print("PBS NOT IMPLEMENTED -- $cluster\n");
    return(-1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobFile to submit
#return jodBatchId or
#   -1 : for a command execution error
#   -2 : for a jobId parse error
sub oarsubmit($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobFile = shift;

    print("$cluster --> OAR\n");
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"sudo -u $user oarsub -l nodes=1,weight=1 -q besteffort ~$user/$jobFile");
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
        if ($k =~ /\s*IdJob\s=\s(\d+)/){
            return($1);
        }
    }
    return(-2);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobFile to submit
#return jodBatchId or -1 for an error
sub oarsubmitMysql($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobFile = shift;

    print("OAR_mysql -- $cluster\n");
    my $OARdb = OARiolib::connect($dbh,$cluster);
    if (!defined($OARdb)){
        return(-1);
    }
    my $jobBatchId = OARiolib::submitJob($OARdb,$user,$jobFile);
    OARiolib::disconnect($dbh);
    my $retCode = oarNotify::notify($cluster,"Qsub");

    return($jobBatchId);
}

return 1;

