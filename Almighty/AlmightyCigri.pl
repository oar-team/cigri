#!/usr/bin/perl
use strict;
use Data::Dumper;
use IO::Socket::INET;
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
	unshift(@INC, $relativePath."ConfLib");
	unshift(@INC, $relativePath."Iolib");
	unshift(@INC, $relativePath."Colombo");
}
use ConfLibCigri qw(init_conf dump_conf get_conf is_conf);
use iolibCigri;

# Init the request to the cigri.conf file
init_conf();

# number of seconds between two updates
my $timeout = 5;

my $path;
if (is_conf("installPath")){
	$path = get_conf("installPath")."/bin/";
}else{
	die("You must have a cigri.conf script with a valid installPath tag\n");
}

#set paths of executables
my $runner_command = $path."runnerCigri.pl";
my $updator_command = $path."updatorCigri.pl";
my $nikita_command = $path."nikitaCigri.pl";

my $base = iolibCigri::connect();

# launch a command and monitor it
# arg1 --> command name
sub launch_command($)
{
	my $command = shift;
	print "Launching command : [$command]\n";
	system $command;
	my $exit_value  = $? >> 8;
	my $signal_num  = $? & 127;
	my $dumped_core = $? & 128;
	print "$command terminated :\n";
	print "Exit value : $exit_value\n";
	print "Signal num : $signal_num\n";
	print "Core dumped : $dumped_core\n";
	die "Something wrong occured (signal or core dumped) !!!\n"
		if $signal_num || $dumped_core;
	return $exit_value;
}

# launch a scheduler or blacklist it
sub scheduler(){
	iolibCigri::update_current_scheduler($base);
	my $sched = iolibCigri::get_current_scheduler($base);
	#return launch_command($scheduler_command);
	if (defined($$sched{schedulerFile})){
		if ( -x $path.$$sched{schedulerFile} ){
			return launch_command($path.$$sched{schedulerFile});
		}else{
			print("Bad scheduler file\n");
			#iolibCigri::insert_new_schedulerError($base,"FILE","Can t find the file $$sched{schedulerFile}");
			colomboCigri::add_new_scheduler_event($base,$$sched{schedulerId},"ALMIGHTY_FILE","Can t find the file $path.$$sched{schedulerFile}");
		}
	}else{
		print("NO SCHEDULER TO LAUNCH :-(\n");
	}
}

# launch the runner command
sub runner(){
	return launch_command($runner_command);
}

# launch updator command
sub updator(){
	return launch_command($updator_command);
}

# launch nikita command
sub nikita(){
	return launch_command($nikita_command);
}

# core of the AlmightyCigri
while (1){
	updator();
	scheduler();
	runner();
	nikita();
	print("I make a pause of $timeout seconds :-)\n");
	sleep($timeout);
}
