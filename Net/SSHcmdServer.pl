#!/usr/bin/perl

use warnings;
use Data::Dumper;
use IO::Socket::INET;
use SSHcmd;

my $markerTag = "<SSHserverTag>";

# Server part
my $server = IO::Socket::INET->new(	LocalPort=> 6694,
									Type => SOCK_STREAM,
									Reuse => 1,
									Listen => 10)
					or die "ARG.... Can't open server socket\n";

sub qget($){
	my $readerTimeout = shift;
	my $answer;
	my $rin = '';
	my $res;
	my $carac;

	my $client=$server->accept();

	vec($rin,fileno($client),1) = 1;
	$res = select($rin, undef, undef, $readerTimeout);
	$carac="A";
	while (($res > 0) && ($carac ne "\n")){
		die "Fin d'ecoute appendiciale" unless sysread($client, $carac, 1);
		if ($carac ne "\n"){
			$answer = $answer.$carac;
			$res = select($rin, undef, undef, $readerTimeout);
		}
	}
	print("$answer\n");
	$answer =~ m/^(<\w+>)\s([\w\-\.]+)\s(.+)\s(<\\\w+>)$/;
	if (("$1" eq "<submitCmd>") && ("$4" eq "<\\submitCmd>")){
		my %cmdResult = SSHcmd::submitCmd("$2","$3");
		print(Dumper(%cmdResult));
		print $client "<SSHserverTagSTDOUT>\n";
		if ("$cmdResult{STDOUT}" ne ""){
			chomp($cmdResult{STDOUT});
			print $client "$cmdResult{STDOUT}\n";
		}
		print $client "<\\SSHserverTagSTDOUT>\n";
		print $client "<SSHserverTagSTDERR>\n";
		if ("$cmdResult{STDERR}" ne ""){
			print $client "$cmdResult{STDERR}\n";
		}
		print $client "<\\SSHserverTagSTDERR>\n";
	}else{
		print $client "Bad request\n";
	}
	close($client);
	return $answer;
}

while (1){
	my @answer = qget(1000);
}

