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
    print("[SPRITZ]      I'm forecasting the MJob $i...\n");
    print("[SPRITZ]          Updating job stats...\n");
    
    my $cmd = "$forecaster $i";
    my $output = `$cmd`;
    my ($hashref, $arrayref, $string) = YAML::Load($output) || die "[SPRITZ]      Could not parse output of $forecaster";
 
	my %average = %{$hashref->{average}};
	my %stddev = %{$hashref->{stddev}};
	my %throughput = %{$hashref->{throughput}};

        print("[SPRITZ]          Calculating job ratios...\n");
	
	foreach my $cluster (sort keys %average){

	#get previous jobratio, current waiting and running
	my $old_jobratio = iolibCigri::get_last_jobratio($base,$i,$cluster);	
	my $nb_waiting =  iolibCigri::get_cluster_remoteWaiting_job_nb($base, $cluster);
	my $nb_running =  iolibCigri::get_cluster_running_job_nb($base, $cluster);
	my $max_waiting = iolibCigri::get_max_waiting_jobs_by_cluster($base, $cluster); 
	my $last_free = iolibCigri::get_last_cluster_free_nb($base, $cluster); 

        # Jobratio calculation
        ######################
        my $predictor;
	my $jobratio;
	if (!defined(ConfLibCigri::get_conf("RATIO_PREDICTOR"))) {
          $predictor="SIMPLE";
        }
	else { $predictor=ConfLibCigri::get_conf("RATIO_PREDICTOR") }
	# TCP slow-start
        if ($predictor eq "TCP") {
		if ($nb_waiting > $max_waiting) {
			$jobratio = 0;
		}else{
			if ($old_jobratio == 0) {
				$jobratio = 1/$last_free;
			}else{
				$jobratio = $old_jobratio * 2;
			}	
		}
	}
	# Two-way adaptative prediction
        elsif ($predictor eq "TWO_WAY_ADAPTATIVE") {
		if ($nb_waiting > $max_waiting) {
			#avoid division by 0
			if(($old_jobratio*$last_free) > 0){ 
				$jobratio = (($old_jobratio*$last_free)-($nb_waiting -$max_waiting))/($old_jobratio*$last_free);
			}else{
				$jobratio = 0;
			}
		}else{
			if($old_jobratio == 0){
				$jobratio = 1;
			}else{
				#avoid division by 0
				if((($old_jobratio*$last_free) > 0) && $nb_running > 0){
					$jobratio = 1/($nb_running/($old_jobratio*$last_free));
				}else{
					$jobratio *=2;
				}
			}
		}
	}

        # Simple average of used resources per job (no adaptative prediction)
	else {
		my $nb_resources_avg = iolibCigri::get_nb_resources_average($base,$i,$cluster);
 
	        if ($nb_resources_avg == 0){  
       		   $jobratio = 0.5;	# Campain startup
       		}
        	else {
		  $jobratio = 1/$nb_resources_avg;
        	}
        }

	$jobratio = 0 if $jobratio < 0;


	#print "MJobId $i, cluster=$cluster,  Old jr = $old_jobratio, New Jr = $jobratio \n";
	
	#update forecast DB
    #iolibCigri::begin_transaction($base);
	iolibCigri::update_mjob_forecast ($base,$i,$cluster,$average{$cluster},
			$stddev{$cluster},$throughput{$cluster}, $jobratio, $hashref->{end_time});
	}    
	#iolibCigri::commit_transaction($base);
 }

iolibCigri::disconnect($base);

exit 0;

