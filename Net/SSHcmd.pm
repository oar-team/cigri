package SSHcmd;

#use strict;
#use warnings;
use Data::Dumper;
use IPC::Open3;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(submitCmd);

# line to print after a ssh command. With that we can know the end of the comman;
my $endLineTag = "lacommandeestterminee";

my %sshConnections;
my $fileHandleId = 0;

#don t crash print or syswrite command on a process closed
$SIG{'PIPE'} = 'IGNORE';

#Connect and set ssh filehandles
# arg1 --> destination connection
sub initSSHConnection($){
	my $server = shift;
	my $i = $fileHandleId;
	$fileHandleId++;
	my $j = $fileHandleId;
	$fileHandleId++;
	my $k = $fileHandleId;
	$fileHandleId++;

	my $timeout = 20;

	my $READERStr = "";
	my $ERRORStr = "";
	my $closeConnection = 0;

	open3( $i, $j, $k, "ssh -T $server");

	$sshConnections{$server} = [ $i, $j, $k];
	#init connection

	if (!(print($i "/bin/sh -c \"echo ; echo $endLineTag\"\n"))){
		#can t write data on the channel --> error
		$closeConnection = 1;
	}else{
		# clear bad lines in the beginning of the ssh session
		my $rin = '';
		my $res = 1;
		my $tmpStr = "";
		my $char;
		$rin = '';
		vec($rin,fileno($j),1) = 1;
		while (("$tmpStr" ne "$endLineTag") and ($closeConnection == 0)) {
			$tmpStr = "";
			$char = "";
			while (($res > 0) and ($char ne "\n")){
				$res = select($rin, undef, undef, $timeout);
				if ($res > 0) {
					sysread($j,$char,1);
					if ($char eq ""){ #error on the medium
						$ERRORStr = "[SSHcmd] connection closed by remote host\n";
						$res = -1;
					}elsif ($char ne "\n"){
						$tmpStr .= $char;
					}
				}
			}

			if ("$tmpStr" ne "$endLineTag"){
				$READERStr .= $tmpStr."\n";
			}
			if ($res <= 0) {
				$ERRORStr = "[SSHcmd] Reader too long...\n";
				$closeConnection = 1;
			}
		}
	}
	if ($closeConnection == 0){
		print("[SSH] SSH connection to $server is established\n");
		return 0;
	}else{
		print("[SSH] BAD SSH connection with $server\n");
		delete($sshConnections{$server});
		close($i);
		close($j);
		close($k);
		return 1;
	}
}

# submit a command to the given cluster
# arg1 --> clusterName
# arg2 --> command
sub submitCmd($$){
	my $clusterName = shift;
	my $command = shift;
	my $READERStr = "";
	my $ERRORStr = "";
	my $closeConnection = 0;
	if (!defined($sshConnections{$clusterName})){
		# we must established a new connection
		my $resultTmp = initSSHConnection($clusterName);
		if ($resultTmp == 1){
			$ERRORStr = "[SSHcmd] Can t connect to $clusterName ...\n";
			$closeConnection = 1;
		}
	}else{
		print("[SSHcmd] I use an existing connection\n");
	}
	if ($closeConnection == 0){
		# get connection filehandle to manage it
		my $fd0 = $sshConnections{$clusterName}->[0];
		my $fd1 = $sshConnections{$clusterName}->[1];
		my $fd2 = $sshConnections{$clusterName}->[2];

		if (!(print($fd0 "/bin/sh -c '$command'; echo ; echo $endLineTag\n"))){
			# can t write on the channel --> error
			$ERRORStr = "[SSHcmd] can t send command\n";
			$closeConnection = 1;
		}else{
			my $rin = '';
			my $timeout = 20;
			my $res = 1;
			my $tmpStr = "";
			my $char;
			$rin = '';
			vec($rin,fileno($fd1),1) = 1;
			while (("$tmpStr" ne "$endLineTag") and ($closeConnection == 0)) {
				$tmpStr = "";
				$char = "";
				while (($res > 0) and ($char ne "\n")){
					$res = select($rin, undef, undef, $timeout);
					if ($res > 0) {
						sysread($fd1,$char,1);
						if ($char ne "\n"){
							$tmpStr .= $char;
						}elsif($char eq ""){
							$ERRORStr = "[SSHcmd] connection closed by remote host\n";
							$res = -1;
						}
					}
				}
				if ("$tmpStr" ne "$endLineTag"){
					$READERStr .= $tmpStr."\n";
				}
				if ($res <= 0) {
					$ERRORStr = "[SSHcmd] Reader too long...\n";
					$closeConnection = 1;
				}
			}

			#Test error filehandle
			$rin = '';
			$timeout = 0.25;
			vec($rin,fileno($fd2),1) = 1;
			$res = select($rin, undef, undef, $timeout);
			while ($res > 0) {
				sysread($fd2,$_,1);
				$ERRORStr .= $_;
				$rin = '';
				vec($rin,fileno($fd2),1) = 1;
				$res = select($rin, undef, undef, $timeout);
				if ($_ eq ""){
					$ERRORStr = "[SSHcmd] connection closed by remote host\n";
					$res = -1;
					$closeConnection = 1;
				}
			}
		}
		if ($closeConnection == 1){
			# invalid connection, something wrong append
			delete($sshConnections{$clusterName});
			close($fd0);
			close($fd1);
			close($fd2);
		}
	}

	my %result = (
		'STDOUT' => $READERStr,
		'STDERR' => $ERRORStr
	);

	return %result;
}

return 1;
