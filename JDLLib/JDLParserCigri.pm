package JDLParserCigri;

use strict;
use warnings;
use Data::Dumper;
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
}
use iolibCigri;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(init_jdl);

# The JDL
my $jdl = undef;
# The conf : $clusterConf{clusterName}{propertyName} --> value
our %clusterConf;
# default section pattern
my $defaultSection = "DEFAULT";
# needed parameters
my @neededParams = ("execFile","execTime");


# Config init
# arg1 --> JDL string
# return 0 if done
# return a string if there is a mistake in the JDL file
sub init_jdl($) {
	$jdl = shift;
	%clusterConf = ();
	return "[JDLParser]JDL not defined\n" if (! defined($jdl));
	chomp($jdl);
	# remove comments
	$jdl =~ s/\n\s*#.*\n/\n/g;
#	print(Dumper($jdl)."\n\n");
	my @clusters = split(/}/, $jdl);

	#Check cluster names
	my $base = iolibCigri::connect();
	my %clusterNamesHash = iolibCigri::get_cluster_names_batch($base);
	iolibCigri::disconnect($base);
	my %clusterNames = ();
	foreach my $i (keys(%clusterNamesHash)){
		$clusterNames{$i} = 1;
	}

	foreach my $i (@clusters){
		$i =~ m/\s*([\w+\-*\.*]+)\s*{/ ;
		my $clusterName = $1;
		my ($devNull, $clusterBlock) = split(/{/, $i);
		next if (!defined($clusterBlock));
		my @linesConf = split(/;/, $clusterBlock);
		foreach my $j (@linesConf){
			if ($j =~ m/^\s*(\w+)\s*=\s*([\w\.\/-]+)\s*$/){
				$clusterConf{$clusterName}{$1} = $2;
			}
		}
	}
	# At this point %clusterConf is configured
	my @jdlClusterNames = keys(%clusterConf);
	my $boolDEFAULTPresent = 0;
	foreach my $i (@jdlClusterNames){
		if ($i eq $defaultSection){
			$boolDEFAULTPresent = 1;
		}elsif (!exists($clusterNames{$i})){
			print("[JDLParser] The \"$i\" cluster does not exist!\n");
			return -1;
		}else{
			foreach my $j (@neededParams){
				if (!defined($clusterConf{$i}{$j})){
					print("[JDLParser] The parameter $j is not defined in the cluster section $i\n");
					return -1;
				}
			}
		}
		# check needed parameters
	}
	if (!defined($clusterConf{$defaultSection})){
		print("[JDLParser] The \"DEFAULT\" section does not exist or is empty!\n");
		return -1;
	}
}

return 1;
