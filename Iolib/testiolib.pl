#! /usr/bin/perl

use strict;
use DBI();
use Data::Dumper;

use iolibCigri;



my $base = iolibCigri::connect();

# print iolibCigri::add_job($base,1,1,"ls");

my $id = iolibCigri::add_job($base,1,1,"ls");
print "$id\n";

print iolibCigri::frag_job($base,$id)."\n";

print  Dumper(iolibCigri::get_job_host($base,"4"));
print  Dumper(iolibCigri::get_host_job($base,'icluster14'));
#print Dumper(iolibCigri::list_nodes($base));
#print Dumper(iolibCigri::get_node_info($base,"Wichita"));
#print Dumper(iolibCigri::list_current_jobs($base));
#iolibCigri::add_node_job_pair($base,9,"wichita");
#print Dumper(iolibCigri::get_free_shareable_nodes($base));
#print iolibCigri::get_maxweight_node($base);
#iolibCigri::set_job_state($base,9,"Waiting");
#print Dumper(iolibCigri::get_alive_node($base));
#print Dumper(iolibCigri::get_job($base,9))."\n";
#print iolibCigri::get_oldest_waiting_idjob($base)."\n";
#print Dumper(iolibCigri::get_running_host($base));
#iolibCigri::add_job($base,1,1,"ls");

iolibCigri::disconnect($base);
