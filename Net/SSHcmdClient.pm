package SSHcmdClient;

use strict;
use warnings;
use IO::Socket::INET;
use Data::Dumper;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(submitCmd);

# submit a command to the given cluster
# arg1 --> clusterName
# arg2 --> command
sub submitCmd($$){
	my $clusterName = shift;
	my $command = shift;
	my $socket = IO::Socket::INET->new(	PeerAddr => "127.0.0.1",
									PeerPort => 6694,
									Proto => "tcp",
									Type  => SOCK_STREAM)
					or die "Couldn't connect to SSH daemon $@ \n";

	print $socket "<submitCmd> $clusterName $command <\\submitCmd>\n";

	my $result = 0;
	my %cmdResult = ( 	"STDOUT" => "",
						"STDERR" => ""
					);

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

#		print("$_");
	}

#	print("\n".Dumper(%cmdResult));
	return %cmdResult;
}

return 1;
