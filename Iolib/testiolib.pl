#! /usr/bin/perl

use strict;
use DBI();
use Data::Dumper;

use iolib;



my $base = iolib::connect();

# print iolib::add_job($base,1,1,"ls");

my $id = iolib::add_job($base,1,1,"ls");
print "$id\n";

print iolib::frag_job($base,$id)."\n";

print  Dumper(iolib::get_job_host($base,"4"));
print  Dumper(iolib::get_host_job($base,'icluster14'));
#print Dumper(iolib::list_nodes($base));
#print Dumper(iolib::get_node_info($base,"Wichita"));
#print Dumper(iolib::list_current_jobs($base));
#iolib::add_node_job_pair($base,9,"wichita");
#print Dumper(iolib::get_free_shareable_nodes($base));
#print iolib::get_maxweight_node($base);
#iolib::set_job_state($base,9,"Waiting");
#print Dumper(iolib::get_alive_node($base));
#print Dumper(iolib::get_job($base,9))."\n";
#print iolib::get_oldest_waiting_idjob($base)."\n";
#print Dumper(iolib::get_running_host($base));
#iolib::add_job($base,1,1,"ls");

iolib::disconnect($base);
