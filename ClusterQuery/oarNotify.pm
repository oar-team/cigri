package oarNotify;

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


# notify the Almighty of a given cluster of type OAR_mysql with a specific tag
# arg1 --> cluster name
# arg2 --> tag to send
sub notify($$){
    my $cluster = shift;
    my $tag = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    if (defined($cluster) && defined($clusterProperties{$cluster})){
        if ($clusterProperties{$cluster} eq "OAR_mysql"){
            my %cmdResult = SSHcmdClient::submitCmd($cluster,"oarnotify $tag");
            print(Dumper(%cmdResult));
            if ($cmdResult{STDERR} ne ""){
                # test if this is a ssh error
                if (NetCommon::checkSshError($base,$cluster,$cmdResult{STDERR}) != 1){
                    colomboCigri::add_new_cluster_event($base,$cluster,0,"OAR_NOTIFY","$cmdResult{STDERR}");
                }
                return(-1);
            }
        }
    }
    iolibCigri::disconnect($base);
    return(0);
}

return 1;

