package NetCommon;

use strict;
use warnings;
use Data::Dumper;

# this module gives global variable

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
    unshift(@INC, $relativePath."Net");
    unshift(@INC, $relativePath."Colombo");
}
use colomboCigri;

my $sshErrorPrefix = "[SSHcmd]";

sub getSshErrorPrefix(){
    return $sshErrorPrefix ;
}

# add an event when there is a mistake with ssh connection
# detected in the error String
# arg1 --> database ref
# arg2 --> cluster name
# arg3 --> ssh error string
# return 0 if is not an ssh error and 1 otherwise
sub checkSshError($$$){
    my $base = shift;
    my $clusterName = shift;
    my $errorStr = shift;

    if (index($errorStr,$sshErrorPrefix) == 0){
        print("!SSH error!\n");
        #add an event in the database
        colomboCigri::add_new_ssh_event($base,"$clusterName","$errorStr");
        return 1;
    }else{
        print("No SSH error\n");
        return 0;
    }
}

return 1;
