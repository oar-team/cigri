#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use IO::Socket::INET;
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
use SSHcmd;

my $markerTag = "<SSHserverTag>";

ConfLibCigri::init_conf();
my $sshServerPort = ConfLibCigri::get_conf("SSH_SERVER_PORT") if ConfLibCigri::is_conf("SSH_SERVER_PORT") or die("Can't get value of the SSH_SERVER_PORT tag in cigri.conf\n");

my $server = IO::Socket::INET->new(	LocalPort=> $sshServerPort,
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

