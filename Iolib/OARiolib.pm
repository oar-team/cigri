package OARiolib;
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
}
use iolibCigri;

# Connect to the database and give the ref
# arg1 --> iolibCIGRI db ref
# arg2 --> db host
sub connect($$) {
    my $dbIolibCigri = shift;
    my $host = shift;

    my %clusterProperties = iolibCigri::get_cluster_properties($dbIolibCigri,$host);
    #print(Dumper(%clusterProperties));
    my $dbh;
    if (!defined($clusterProperties{clusterName})){
        return($dbh);
    }
    my $name = $clusterProperties{clusterMysqlDatabase};
    my $user = $clusterProperties{clusterMysqlUser};
    my $pwd = $clusterProperties{clusterMysqlPassword};
    my $port = $clusterProperties{clusterMysqlPort};

    $dbh = DBI->connect("DBI:mysql:database=$name;host=$host;port=$port;mysql_ssl=1", $user, $pwd, {'RaiseError' => 0});
    return($dbh);
}

# Disconnect from the database referenced by arg1
# arg1 --> database ref
sub disconnect($) {
    my $dbh = shift;
    $dbh->disconnect();
}

# list_current_jobs
# returns a list of jobid for jobs that are in one of the states
# Waiting, toLaunch, Running, Launching, Hold or toKill.
# parameters : base
# return value : list of jobid with theirs state
sub listCurrentJobs($) {
    my $dbh = shift;
    my %hashetat = ('Waiting' => 'W',
                    'toLaunch' => 'L',
                    'Launching' => 'L',
                    'Hold' => 'H',
                    'Running' => 'R',
                    'Terminated' => 'T',
                    'Error' => 'E');

    my $sth = $dbh->prepare("SELECT idJob, state FROM jobs j
                             WHERE j.state=\"Waiting\"
                             OR    j.state=\"toLaunch\"
                             OR    j.state=\"Running\"
                             OR    j.state=\"Launching\"
                             OR    j.state=\"Hold\"
                             OR    j.state=\"toKill\"");
    $sth->execute();
    my %res = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        $res{$$ref{idJob}} = $hashetat{$$ref{state}};
    }
    $sth->finish();
    return %res;
}

# get node state
# arg1 --> database ref
# return an hash of node states
sub getFreeNodes($) {
    my $dbh = shift;

    my $sth = $dbh->prepare("SELECT hostname, state, weight FROM nodes");
    $sth->execute();
    my %res = ();
    while (my @ref = $sth->fetchrow_array()) {
        if (($ref[1] eq "Alive") && ($ref[2] == 0)){
            $res{$ref[0]} = "free";
        }else{
            $res{$ref[0]} = "busy";
        }
    }
    $sth->finish();
    return %res;
}

# frag a job
# arg1 --> database ref
# arg2 --> jobBatchId
sub fragRemoteJob($$) {
    my $dbh = shift;
    my $jobBatchId = shift;

    $dbh->do("UPDATE jobs SET toFrag = \"Yes\" WHERE idJob = $jobBatchId");
    return 1;
}

return 1;
