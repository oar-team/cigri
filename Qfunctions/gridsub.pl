#!/usr/bin/perl -I ../ConfLib -I ../Iolib -I ../JDLLib

# Tool to query the grid for a submission

use strict;
use IO::Socket::INET;

use Data::Dumper;
use Sys::Hostname;
use Getopt::Std;
use iolibCigri;
use ConfLibCigri;

sub usage(){
	print(STDERR "usage: gridSub -f JDLscript \n");
	exit 1;
}

#
# Main
#

# Get the server configuration
ConfLibCigri::init_conf();
my $remote_host = undef;
$remote_host = ConfLibCigri::get_conf("CIGRI_SERVER") if ConfLibCigri::is_conf("CIGRI_SERVER") or die("Can't get value of the CIGRI_SERVER tag in cigri.conf\n");
my $remote_port = undef;
$remote_port = ConfLibCigri::get_conf("CIGRI_SERVER_PORT") if ConfLibCigri::is_conf("CIGRI_SERVER_PORT") or die("Can't get value of the CIGRI_SERVER_PORT tag in cigri.conf\n");

# Options on arg command line
my %opts;
Getopt::Std::getopts('f:', \%opts);

my $JDLfile = undef;
foreach my $key (keys(%opts)){
	if ($key eq "f"){
		$JDLfile = $opts{$key};
		print("JDL file = $JDLfile\n");
	}else{
		print(STDERR "Warning !!! option -$key not yet implemented\n");
	}
}

# If there is no JDL file specified
usage if (! defined($JDLfile));

my $base = iolibCigri::connect();
my $idJob= iolibCigri::add_mjobs($base,$JDLfile);
print "IdJob = $idJob \n";
iolibCigri::disconnect($base);

if ($idJob == -1){
	print("Bad JDLscript file\n");
	exit(2);
}

#Signal Almigthy
my $socket = IO::Socket::INET->new(PeerAddr => $remote_host,
									PeerPort => $remote_port,
									Proto => "tcp",
									Type  => SOCK_STREAM)
			or die "Couldn't connect executor $remote_host:$remote_port\n";

my $cmd_executor = "gridsub\n";
#my $cmd_executor = "[DEBUG] ddddddddd\n";
print $socket $cmd_executor;

#my $answer=<$socket>;

#print "Almigthy answers : $answer\n";

exit 0;
