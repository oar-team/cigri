#!/usr/bin/perl

use ConfLibCigri qw(init_conf dump_conf get_conf is_conf);

#my $file = "ConfTest.conf";

init_conf();

dump_conf();

print "\n";

print "database_host = ".get_conf("database_host")."\n" if is_conf("database_host");
print "database_name = ".get_conf("database_name")."\n" if is_conf("database_name");

