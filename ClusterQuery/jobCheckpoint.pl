#!/usr/bin/perl
# This script checkpoints a job
# It takes 3 arguments: <clustername> <user> <jobRemoteId to checkpoint>

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
use ConfLibCigri qw(init_conf dump_conf get_conf is_conf);


my %checkpointCmd = (
                'OAR' => \&oarcheckpoint,
                'OAR2' => \&oarcheckpoint,
                'OAR2_3' => \&oarcheckpoint,
                'OAR2_4' => \&oarcheckpoint
                 );

#arg1 --> cluster name
#arg2 --> user
#arg3 --> jobRemoteId to checkpoint
sub jobCheckpoint($$$){
    my $cluster = shift;
    my $user = shift;
    my $jobRemoteId = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        print "clusterProperties ($cluster):" . $clusterProperties{$cluster} ."\n";
	$retCode = &{$checkpointCmd{$clusterProperties{$cluster}}}($base,$cluster,$user,$jobRemoteId);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}


#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> user
#arg4 --> jobRemoteId to checkpoint
sub oarcheckpoint($$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobRemoteId = shift;

    print("$cluster --> OAR\n");
    my %cmdResult = SSHcmdClient::submitCmd($cluster,"sudo -u $user oardel -c $jobRemoteId");
    print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
	    my $jobId=iolibCigri::get_job_id_from_remoteid($dbh,$jobRemoteId,$cluster);
            colomboCigri::add_new_job_event($dbh,$jobId,"CHECKPOINT_CMD","$cmdResult{STDERR}");
        }
        return(-1);
    }

    return(1);
}


init_conf();
jobCheckpoint($ARGV[0],$ARGV[1],$ARGV[2]);
