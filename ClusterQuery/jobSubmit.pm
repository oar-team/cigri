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
}
use iolibCigri;
use SSHcmdClient;
use colomboCigri;
use NetCommon;
use warnings;
use OARiolib;


my %qdelCmd = ('PBS' => \&pbssubmit,
				'OAR' => \&oarsubmit,
                'OAR_mysql' => \&oarsubmitMysql);

#arg1 --> cluster name
#arg2 --> user
#arg3 --> jobBatchId to delete
sub jobSubmit($$$){
    my $cluster = shift;
    my $user = shift;
    my $jobBatchId = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$qdelCmd{$clusterProperties{$cluster}}}($base,$cluster,$user,$jobBatchId);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

sub notifyBatch($){
    my $cluster = shift;
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobBatchId to delete
sub pbssubmit($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobBatchId = shift;

    print("PBS NOT IMPLEMENTED -- $cluster\n");
    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobBatchId to delete
sub oarsubmit($$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobBatchId = shift;

    print("$cluster --> OAR\n");
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"sudo -u $user oardel $jobBatchId");
    print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($base,$cluster,$cmdResult{STDERR}) != 1){
            print("ERREUR A TRAITER\n");
        }
        return(-1);
    }

    return(1);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobBatchId to delete
sub oarsubmitMysqlt($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobBatchId = shift;

    print("OAR_mysql -- $cluster\n");
    my $OARdb = OARiolib::connect($dbh,$cluster);
    if (!defined($OARdb)){
        return(-1);
    }
    OARiolib::fragRemoteJob($OARdb,$jobBatchId);
    OARiolib::disconnect($dbh);
    #Notify Almighty
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarnotify");
    print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($base,$cluster,$cmdResult{STDERR}) != 1){
            print("ERREUR A TRAITER\n");
        }
        return(-1);
    }

    return(1);
}

return 1;

