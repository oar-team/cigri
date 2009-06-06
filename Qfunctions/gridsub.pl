#!/usr/bin/perl

# Tool to query the grid for a submission

use strict;
use IO::Socket::INET;

use Data::Dumper;
use Sys::Hostname;
use Getopt::Long;
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
use mailer;

sub usage(){
    print(STDERR "usage: gridSub -f JDLscript [-t campaign_type] \n");
    exit 1;
}

#
# Main
#

# Options on arg command line
#


my $Error_Prefix = "[ERROR]";

Getopt::Long::Configure ("gnu_getopt");
my $mJobType;
my $sos;
my $JDLfile;

GetOptions ("jdl|f=s" =>  \$JDLfile,
			"type|t=s" => \$mJobType,
			"help|h" => \$sos
			);


if (defined($sos)){
    usage();
    exit(0);
}

if (!defined($JDLfile)){
    usage();
    exit(1);
}

if ( (-e $JDLfile) && (-r $JDLfile) ){
	print("JDL file = $JDLfile\n");
}else{	
	print("$Error_Prefix $JDLfile: non-existant or unreadable JDL file \n");
	usage();
    exit(1);
}


my $base = iolibCigri::connect();
my $idJob= iolibCigri::add_mjobs($base, $JDLfile, $mJobType);
print "IdJob = $idJob \n";
iolibCigri::disconnect($base);

# -1 = bad JDL file or bad param file
# -2 = no cluster defined
# -3 = no execFile in a cluster section
# -4 = duplicate parameters
if ($idJob == -1){
    print("$Error_Prefix Bad JDL file or Bad param file\n");
    exit(2);
}elsif($idJob == -2){
    print("$Error_Prefix No cluster defined\n");
    exit(2);
}elsif($idJob == -3){
    print("$Error_Prefix No execFile in a cluster section\n");
    exit(2);
}elsif($idJob == -4){
    print("$Error_Prefix Duplicate parameters\n");
    exit(2);
#temporary solution while admission rules are not implemented
}elsif($idJob == -5){   
    print("$Error_Prefix $mJobType: invalid campaign type\n");
    exit(2);
}

exit 0;
