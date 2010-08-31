package SSHcmd;

#this module enable to connect and execute a command via SSH
#the user must have right keys to log automatically on the remote host

use strict;
use Net::SSH qw(sshopen3);
use NetCommon;

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


require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(submitCmd);

my $sshErrorPrefix = NetCommon::getSshErrorPrefix();

# Send a command via ssh
# arg1 --> clusterName
# arg2 --> command
sub submitCmd($$){
  my $clusterName = shift;
  my $command = shift;
  my $stdout="";
  my $stderr="";
  my $timeout=60;
  my $pid;
  eval {
    local $SIG{ALRM} = sub { die "Timeout!\n" };
    alarm $timeout;

    $pid=sshopen3($clusterName, *WRITER, *READER, *ERROR, $command);
   
    while (<READER>) {
      chomp();
      $stdout.= "$_\n";
    }
    while (<ERROR>) {
      chomp();
      $stderr.= "$_\n";
    }

    close(READER);
    close(ERROR);
    close(WRITER);

    waitpid($pid,0);
    my $exit = $? >> 8;
    if ($exit == 255) {
      $stderr= "$sshErrorPrefix $stderr";
    }
    alarm 0;
  };

  if ($@) {
    $stderr="$sshErrorPrefix timeout!\n";
  }
 
  my %result = (
    'STDOUT' => $stdout,
    'STDERR' => $stderr
  );

  return %result;
}

# check ssh control master
# arg1 --> clusterName
sub checkControlmaster($){
    my $clusterName = shift;
    my $SSH_CMD="";
    my $SSH_CONTROL_MASTER_KEEPALIVE="43200";
    if (!defined(ConfLibCigri::get_conf("SSH_CMD"))) {
       $SSH_CMD="ssh ";
    }else{
       $SSH_CMD=ConfLibCigri::get_conf("SSH_CMD");
    }
    if (defined(ConfLibCigri::get_conf("SSH_CONTROL_MASTER_KEEPALIVE"))) {
       $SSH_CONTROL_MASTER_KEEPALIVE=ConfLibCigri::get_conf("SSH_CONTROL_MASTER_KEEPALIVE");
    }
    if (system("$SSH_CMD -O check $clusterName >/dev/null 2>&1")) {
      # Just to be sure, exit from the old control master
      exitControlMaster($clusterName);
      # Start a sleep for the control master
      print "[SSH]         Starting a control master to $clusterName\n";
      system("$SSH_CMD -f -M $clusterName sleep $SSH_CONTROL_MASTER_KEEPALIVE &");
      sleep(5);
    }
}

# exit from the controlmaster
# arg1 --> clustername
sub exitControlMaster($){
    my $clusterName = shift;
    my $SSH_CMD="";
    if (!defined(ConfLibCigri::get_conf("SSH_CMD"))) {
       $SSH_CMD="ssh ";
    }else{
       $SSH_CMD=ConfLibCigri::get_conf("SSH_CMD");
    }
    print "[SSH]         CLEARING the control master to $clusterName\n";
    system("$SSH_CMD -O exit $clusterName >/dev/null 2>&1");
    system("rm -f ~/.ssh/master*$clusterName*");
}


return 1;
