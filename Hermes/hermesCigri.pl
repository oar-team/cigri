#!/usr/bin/perl 

use strict;
use DBI ;
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
    # configure the path to reach the lib directory
    $relativePath = $relativePath."../";
    unshift(@INC, $relativePath."lib");
    unshift(@INC, $relativePath."Iolib");
    unshift(@INC, $relativePath."Colombo");
}
use String;
use iolibCigri;
use Data::Dumper;
use colomboCigri;
use integer;
use ConfLibCigri qw(init_conf get_conf is_conf);
use Sys::Hostname;
    
my $localhost = hostname();
my $base = iolibCigri::connect();

my %data_synchron_param = iolibCigri::get_data_synchron_param($base);


foreach my $i (keys(%data_synchron_param)){
    iolibCigri::set_data_synchronState($base, $i, "IN_TREATMENT");
    my $local2local = -1;
    print"[HERMES]Initiating clusters\n";
    iolibCigri::set_properties_datasynchron_initstate($base,$i);
    if(iolibCigri::get_properties_cluster_existance($base,$i,$localhost) == 1){
    	if(iolibCigri::get_properties_ExecDirectory($base,$i,$localhost) eq $data_synchron_param{$i}[0]{src}){
		iolibCigri::set_propertiesData_synchronState($base, $i, $localhost, 'TERMINATED');	
	}	
	else{
		my $execDirectory = iolibCigri::get_properties_ExecDirectory($base,$i,$localhost);
    		print"[HERMES]Transfer data from $data_synchron_param{$i}[0]{src} to $execDirectory for data synchronization of $i Mjob\n";
		iolibCigri::set_propertiesData_synchronState($base, $i, $localhost, 'IN_TREATMENT');
		my $user=iolibCigri::get_userLogin4cluster($base, $localhost, $i);
		iolibCigri::disconnect($base);
        	$local2local = rsync_data($data_synchron_param{$i}[0]{src},$execDirectory,$user,$localhost,$data_synchron_param{$i}[0]{timeout},0);
		$base = iolibCigri::connect();
		print"[HERMES]Finished rsync with status:$local2local\n";
		if($local2local == 0){
	        	print"[HERMES]Data synchronization for cluster $localhost and Mjob $i terminated\n";
			iolibCigri::set_propertiesData_synchronState($base, $i, $localhost, 'TERMINATED');		
		}
		elsif($local2local > 0){
	        	print"[HERMES]Error in data synchronization for cluster $localhost and Mjob $i\n";
			iolibCigri::set_propertiesData_synchronState($base, $i, $localhost, 'ERROR');	
			if($local2local == 30){
	                	colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Timeout in data send/receive");
	        	}
	        	elsif($local2local == 1){
	                	colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Syntax or usage error");
	        	}
			elsif($local2local == 23){
				colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Partial transfer due to error...Check if file or directory \"$data_synchron_param{$i}[0]{src} \" exists and if user \"$user\" has <write> permissions on directory \"$execDirectory\".");		
			}
			elsif($local2local == 5){
			        colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error starting client-server protocol");
			}				

			elsif($local2local == 10){
				colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error in socket I/O");
			}							
			elsif($local2local == 11){
	                        colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error in file I/O");
			}
			elsif($local2local == 12){
			        colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error in rsync protocol data stream");
			}
			elsif($local2local == 24){
                                colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Partial transfer due to vanished source files");
                        }												}
    	}
    }	
    
    my %propertiesClusterName = iolibCigri::get_MJobs_Properties($base, $i);
    foreach my $j (keys(%propertiesClusterName)){
    	if(($j ne "localhost") && ($j ne $localhost) && ($j ne $data_synchron_param{$i}[0]{host}) && (iolibCigri::get_propertiesData_synchronState($base, $i, $localhost) eq 'TERMINATED' || iolibCigri::get_propertiesData_synchronState($base, $i, $localhost) eq 'ERROR' ||  iolibCigri::get_properties_cluster_existance($base,$i,$localhost) == 0) && iolibCigri::get_propertiesData_synchronState($base, $i, $j) eq 'INITIATED' && iolibCigri::get_nb_synchronTREAT_clusters($base,$i) == 0){
             print"[HERMES]Transfer data from localhost $localhost to $j for data synchronization of $i Mjob\n";	     
	     iolibCigri::set_propertiesData_synchronState($base, $i, $j, 'IN_TREATMENT');
	     my $user=iolibCigri::get_userLogin4cluster($base, $j, $i);
	     my $execDirectory = iolibCigri::get_properties_ExecDirectory($base,$i,$j);
	     iolibCigri::disconnect($base);
     	     my $local2remote = rsync_data($data_synchron_param{$i}[0]{src},$execDirectory,$user,$j,$data_synchron_param{$i}[0]{timeout},1);	     
	     $base = iolibCigri::connect();
	     print"[HERMES]Finished rsync with status:$local2remote\n";
	     if($local2remote == 0){
	     	     print"[HERMES]Data synchronization for cluster $j and Mjob $i terminated\n";
                     iolibCigri::set_propertiesData_synchronState($base, $i, $j, 'TERMINATED');
             }
             elsif($local2remote > 0){
	     	     print"[HERMES]Error in data synchronization for cluster $j and Mjob $i\n";
	             iolibCigri::set_propertiesData_synchronState($base, $i, $j, 'ERROR');     
		     if($local2remote == 30){
 	                    colomboCigri::add_new_cluster_event($base,$j,$i,"HERMES","Timeout in data send/receive");
	             }
	             elsif($local2remote == 1){
	                    colomboCigri::add_new_cluster_event($base,$j,$i,"HERMES","Syntax or usage error");
	             }
		     elsif($local2remote == 23){
                             colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Partial transfer due to error...Check if file or directory \"$data_synchron_param{$i}[0]{src} \" exists and if user \"$user\" has <write> permissions on directory \"$execDirectory\".");                         }
	     	     }
		     elsif($local2local == 5){
		             colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error starting client-server protocol");
		     }
		     elsif($local2local == 10){
		             colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error in socket I/O");
		     }
		     elsif($local2local == 11){
		             colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error in file I/O");
		     }
		     elsif($local2local == 12){
                             colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Error in rsync protocol data stream");
                     }
                     elsif($local2local == 24){
                             colomboCigri::add_new_cluster_event($base,$localhost,$i,"HERMES","Partial transfer due to vanished source files");
                     }
    	}
   
 }

 if(iolibCigri::get_nb_synchronTERM_clusters($base, $i) == iolibCigri::get_nb_Mjob_clusters($base, $i) && iolibCigri::get_data_synchronState($base, $i) eq "IN_TREATMENT"){
 	iolibCigri::set_data_synchronState($base, $i, "TERMINATED");
	#iolibCigri::disconnect($base);
	print"[HERMES]Finished data synchronization for Mjob $i\n";
 }
 elsif(iolibCigri::get_nb_synchronERR_clusters($base, $i) != 0 && ((iolibCigri::get_nb_synchronTERM_clusters($base, $i)+iolibCigri::get_nb_synchronERR_clusters($base, $i))==iolibCigri::get_nb_Mjob_clusters($base, $i))  && iolibCigri::get_data_synchronState($base, $i) eq "IN_TREATMENT"){
 	iolibCigri::set_data_synchronState($base, $i, "ERROR");
        #iolibCigri::disconnect($base);
	print"[HERMES]Error in data synchronization for Mjob $i\n";
 }
 
}

if(iolibCigri::get_nb_data_synchronTREATstate($base) == 0){
	iolibCigri::disconnect($base);
}

exit 0;


#transfer data using the rsync command
#arg1 -> source_directory
#arg2 -> destination_directory
#arg3 -> user
#arg4 -> hostname
#arg5 -> timeout
#arg6 -> mode =0 transfer from local to local, or =1 from local to remote
sub rsync_data($$$$$$){
    my $src = shift;
    my $dest = shift;
    my $user = shift;
    my $host = shift;
    my $timeout = shift;
    my $mode = shift; 
    my $exit_value = -1;
    

    my $rsync_command = "sudo -u ". $user . " rsync --rsh=/usr/bin/ssh --rsync-path=/usr/bin/rsync --recursive --checksum --verbose --compress --archive --timeout=" . $timeout . " ";
    
    if ($mode == 1){
    	 $dest = $user . "@" . $host . ":" . $dest;    
    }
    $rsync_command = $rsync_command . $src . " " . $dest;


    if (!defined(my $kidpid = fork())) {
    	# fork returned undef, so failed
        die "[HERMES]cannot fork: $!";
    }
    elsif ($kidpid == 0) {
    	system($rsync_command);
    	$exit_value  = $? >> 8;
    	my $signal_num  = $? & 127;
    	my $dumped_core = $? & 128;
    	print "[HERMES]$rsync_command terminated :\n";
    	print "[HERMES]Exit value : $exit_value\n";
    	print "[HERMES]Signal num : $signal_num\n";
    	print "[HERMES]Core dumped : $dumped_core\n";
	    
    	if ($signal_num || $dumped_core){
    		print"[HERMES]Signal or core dumped,The command ($rsync_command) can not be executed correctly :\n\tExit value = $exit_value\n\tSignal num = $signal_num\n\tCore dumped = $dumped_core";
    	}
    }
    return $exit_value;
}



