#!/usr/bin/perl

# Tool to query the grid for a submission

use strict;
use IO::Socket::INET;

use Data::Dumper;
use Sys::Hostname;
use Getopt::Std;
BEGIN {
	#update module path for our modules
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
	unshift(@INC, $relativePath."Iolib");
	unshift(@INC, $relativePath."Colombo");
}
use iolibCigri;
use ConfLibCigri;

sub usage(){
	print(STDERR "usage: gridSub -f JDLscript \n");
	exit 1;
}

#
# Main
#

# Options on arg command line
my %opts;
Getopt::Std::getopts('f:', \%opts);

my $JDLfile = undef;
foreach my $key (keys(%opts)){
	if ($key eq "f"){
		$JDLfile = $opts{$key};
		print("JDL file = $JDLfile\n");
	}else{
		print(STDERR "Warning !!! option -$key not implemented\n");
	}
}

# If there is no JDL file specified
usage if (! defined($JDLfile));

my $base = iolibCigri::connect();
my $idJob= iolibCigri::add_mjobs($base,$JDLfile);
print "IdJob = $idJob \n";
iolibCigri::disconnect($base);

# -1 = bad JDL file or bad param file
# -2 = no cluster defined
# -3 = no execFile in a cluster section
# -4 = duplicate parameters
if ($idJob == -1){
	print("[ERROR] Bad JDL file or Bad param file\n");
	exit(2);
}elsif($idJob == -2){
	print("[ERROR] No cluster defined\n");
	exit(2);
}elsif($idJob == -3){
	print("[ERROR] No execFile in a cluster section\n");
	exit(2);
}elsif($idJob == -4){
	print("[ERROR] Duplicate parameters\n");
	exit(2);
}

exit 0;
