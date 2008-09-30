package SSHcmdClient;

use strict;
use warnings;
use IO::Socket::INET;
use Data::Dumper;

# this module is an interface to connect with the SSHcmdServer

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
}
use ConfLibCigri qw(init_conf dump_conf get_conf is_conf);
use NetCommon;
use SSHcmd;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(submitCmd);

my $sshErrorPrefix = NetCommon::getSshErrorPrefix();
ConfLibCigri::init_conf();
#my $sshServerPort = ConfLibCigri::get_conf("SSH_SERVER_PORT") if ConfLibCigri::is_conf("SSH_SERVER_PORT") or die("Can't get value of the SSH_SERVER_PORT tag in cigri.conf\n");
my $sshServerPort = 0;
if (ConfLibCigri::is_conf("SSH_SERVER_PORT")) {
    $sshServerPort = ConfLibCigri::get_conf("SSH_SERVER_PORT");
}
my $sshControlmaster = 0;
if (ConfLibCigri::is_conf("SSH_CONTROL_MASTER")) {
    $sshControlmaster = ConfLibCigri::get_conf("SSH_CONTROL_MASTER");
}


# submit a command to the given cluster
# arg1 --> clusterName
# arg2 --> command
sub submitCmdToSSHServer($$){
    my $clusterName = shift;
    my $command = shift;

    my %cmdResult = ("STDOUT" => "",
                     "STDERR" => ""
                    );

    my $socket = IO::Socket::INET->new(    PeerAddr => "127.0.0.1",
                                        PeerPort => $sshServerPort,
                                        Proto => "tcp",
                                        Type  => SOCK_STREAM);
#                    or die "Couldn't connect to SSH daemon $@ \n";
    if (defined($socket)){
        print $socket "<submitCmd> $clusterName $command <\\submitCmd>\n";

        my $result = 0;

        while (<$socket>){
            chomp;
            if (substr($_,0,2) eq "<\\"){
                $result = 0;
            }

            if ($result == 1){
                $cmdResult{STDOUT} .= $_."\n" ;
            }elsif ($result == 2){
                $cmdResult{STDERR} .= $_."\n" ;
            }

            if ( "$_" eq "<SSHserverTagSTDOUT>"){
                $result = 1;
            }elsif ("$_" eq "<SSHserverTagSTDERR>"){
                $result = 2;
            }
        }
    }else{
        $cmdResult{STDERR} = "$sshErrorPrefix Can t connect to the local SSH server\n";
    }
    #    print("\n".Dumper(%cmdResult));
    return %cmdResult;
}

# submit a command to the given cluster
# arg1 --> clusterName
# arg2 --> command
sub submitCmd($$){
    my $clusterName = shift;
    my $command = shift;
    
    if ($sshControlmaster == 1){
        SSHcmd::checkControlmaster($clusterName);
    }
    if ($sshServerPort < 1024){
        return(SSHcmd::submitCmd($clusterName, $command));
    }else{
        print("{SSHcmdClient} I use the SSH daemon\n");
        return(submitCmdToSSHServer($clusterName, $command));
    }
}

return 1;
