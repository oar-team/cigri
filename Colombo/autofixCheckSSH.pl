#!/usr/bin/perl
# Sends a simple command on a cluster to check if SSH is working

use Data::Dumper;
use warnings;
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
use SSHcmdClient;
use NetCommon;

# Clear the control master if any
SSHcmd::exitControlMaster($ARGV[0]);
# Test the ssh connexion
my %cmdResult = SSHcmdClient::submitCmd($ARGV[0],"id");
if ($cmdResult{STDERR} ne ""){
  print("[AUTOFIX]     STDERR: $cmdResult{STDERR}");
  exit(1);
}else{
  exit(0);
}
