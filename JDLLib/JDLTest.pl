#!/usr/bin/perl

use JDLParser ;

#my $file = "ConfTest.conf";

my $toto = JDLParser::init_jdl("DEFAULT{
	toto = titi;
	dd = tt;
}
i4{
	execFile = /ls;
	ff = ee;
}");

print("Retour function : $toto \n");

foreach my $i (keys(%JDLParser::clusterConf)){
	my $t = $JDLParser::clusterConf{$i};
	print("$i : \n");
	foreach my $j (keys(%$t)){
		print("\t$j --> $JDLParser::clusterConf{$i}{$j} \n");
	}

}
#dump_conf();

#print "\n";

#print "database_host = ".get_conf("database_host")."\n" if is_conf("database_host");
#print "database_name = ".get_conf("database_name")."\n" if is_conf("database_name");

