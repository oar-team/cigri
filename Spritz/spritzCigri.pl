#!/usr/bin/perl

# Spritz is the Weather Man
# It calls a forecaster for each running multijob to update the "forecasts" table
# The forecaster must send its output into YAML format.

use strict;
my $forecaster;
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
    my $path=$relativePath;
    $relativePath = $relativePath."../";
    # configure the path to reach the lib directory
    unshift(@INC, $relativePath."lib");
    unshift(@INC, $relativePath."Net");
    unshift(@INC, $relativePath."Iolib");
    unshift(@INC, $relativePath."Colombo");

     ################################################
     #            The forecaster to use:            #

     $forecaster="$path/gridforecast.rb";

     #                                              #
     ################################################
}

use iolibCigri;
use YAML;

my $base = iolibCigri::connect();

# Test the forecaster
if (!-x $forecaster) {
  print "\n[SPRITZ]      ERROR: forecaster $forecaster not found or not executable!\n";
  exit 1;
}

# ids of MJobs to forecast
my @MjobsToForecast;
@MjobsToForecast = iolibCigri::get_IN_TREATMENT_MJobs($base);


 
foreach my $i (@MjobsToForecast){
     print("[SPRITZ]      I'm forecasting the MJob $i\n");
     my $cmd = "$forecaster $i";
     my $output = `$cmd`;
     my ($hashref, $arrayref, $string) = YAML::Load($output) || die "[SPRITZ]      Could not parse output of $forecaster";
 
     iolibCigri::begin_transaction($base);
     iolibCigri::update_mjob_forecast($base,$i,
                                      $hashref->{data}->{average},
 				     $hashref->{data}->{standard_deviation},
 				     $hashref->{data}->{throughput},
 				     $hashref->{end_time}
 				    );
     iolibCigri::commit_transaction($base);
 }

iolibCigri::disconnect($base);

exit 0;

