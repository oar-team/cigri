#!/usr/bin/perl

use JDLParserCigri ;

#my $file = "ConfTest.conf";

my $toto = JDLParserCigri::init_jdl("DEFAULT{
	toto = titi;
	dd = tt;
}
i4{
	execFile = /ls;
	ff = ee;
}");

print("Retour function : $toto \n");

foreach my $i (keys(%JDLParserCigri::clusterConf)){
	my $t = $JDLParserCigri::clusterConf{$i};
	print("$i : \n");
	foreach my $j (keys(%$t)){
		print("\t$j --> $JDLParserCigri::clusterConf{$i}{$j} \n");
	}

}
#dump_conf();

#print "\n";

#print "database_host = ".get_conf("database_host")."\n" if is_conf("database_host");
#print "database_name = ".get_conf("database_name")."\n" if is_conf("database_name");

