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
use colomboCigri;

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

    eval {
        $dbh = DBI->connect("DBI:mysql:database=$name;host=$host;port=$port;mysql_ssl=1", $user, $pwd, {'RaiseError' => 1});
    };
    if ($@) {
        colomboCigri::add_new_cluster_event($dbIolibCigri,$host,0,"MYSQL_OAR_CONNECT","There is an error when i try to connect to the MySQL server -- $@");
        print("DBI connection problem --> $@ retCode=$?\n");
       # undef($dbh);
    }
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

    my $sth = $dbh->prepare("SELECT n.hostname, n.state, n.weight
                             FROM nodes n, nodeProperties p
                             WHERE n.hostname = p.hostname
                                AND p.besteffort = \"YES\"
                            ");
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
# arg2 --> jobRemoteId
sub fragRemoteJob($$) {
    my $dbh = shift;
    my $jobRemoteId = shift;

    $dbh->do("UPDATE jobs SET toFrag = \"Yes\" WHERE idJob = $jobRemoteId");
    return 1;
}

# ymdhms_to_sql
# converts a date specified as year, month, day, minutes, secondes to a string
# in the format used by the sql database
# parameters : year, month, day, hours, minutes, secondes
# return value : date string
# side effects : /
sub ymdhms_to_sql($$$$$$) {
    my ($year,$mon,$mday,$hour,$min,$sec)=@_;
    return ($year+1900)."-".($mon+1)."-".$mday." $hour:$min:$sec";
}

# get_date
# returns the current time in the format used by the sql database
# parameters : /
# return value : date string
# side effects : /
sub get_date() {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    return ymdhms_to_sql($year,$mon,$mday,$hour,$min,$sec);
}

# submit a job
# arg1 --> database ref
# arg2 --> cigri_iolib database ref
# arg3 --> clusterName
# arg4 --> username
# arg5 --> jobFile
# arg6 --> blacklisted nodes
# return jobRemoteId
sub submitJob($$$$$$) {
    my $dbh = shift;
    my $cigriDB = shift;
    my $cluster = shift;
    my $user = shift;
    my $jobFile = shift;
    my $blackNodes = shift;

    my $weight = iolibCigri::get_cluster_default_weight($cigriDB,$cluster);
    $dbh->do("LOCK TABLE jobs WRITE");
    my $sth = $dbh->prepare("SELECT MAX(idJob)+1 FROM jobs");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @tmp = values %$ref;
    my $id = $tmp[0];
    $sth->finish();
    if($id eq "") {
        $id = 1;
    }
    my $time = get_date();

    my $propertyString;
    foreach my $i (@$blackNodes){
        $propertyString .= " p.hostname != \\\"$i\\\" AND";
    }
    if (defined($propertyString)){
        $propertyString =~ s/^(.+)AND$/$1/g;
        $propertyString = "(".$propertyString.") AND ";
    }
    $propertyString .= "p.besteffort = \\\"YES\\\"";
    print("Property String = $propertyString\n");
    $dbh->do("INSERT INTO jobs (idJob,jobType,infoType,state,user,nbNodes,weight,command,submissionTime,maxTime,queueName,launchingDirectory,properties) VALUES ($id,\"PASSIVE\",\"\",\"Waiting\",\"$user\",1,$weight,\"~$user/$jobFile\",\"$time\",\"01:00:00\",\"besteffort\",\"~$user\",\"$propertyString\")");

    $dbh->do("UNLOCK TABLES");

    return $id;
}

return 1;
