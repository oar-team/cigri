#!/usr/bin/perl -I ../ConfLib -I ../Iolib
use strict;
use Data::Dumper;
use IO::Socket::INET;

use ConfLibCigri qw(init_conf dump_conf get_conf is_conf);

# Init the request to the cigri.conf file
init_conf();

my $path;
if (is_conf("installPath")){
	$path = get_conf("installPath")."/bin/";
}else{
	die("You must have a cigri.conf script with a valid installPath tag\n");
}

my $scheduler_command = $path."sched_fifoCigri.pl";
my $runner_command = $path."runnerCigri.pl";
my $updator_command = $path."updatorCigri.pl";

my $server;
my $serverport;
if (is_conf("CIGRI_SERVER_PORT")){
	$serverport = get_conf("CIGRI_SERVER_PORT");
}else{
	die("You must have a cigri.conf script with a valide CIGRI_SERVER_PORT tag\n");
}
my $servermaxconnect=10;

my $internaltimeout = 0;
# age of the christ at death time
my $schedulertimeout = 33;
my $lastscheduler;
my @internal_command_file;

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

sub init(){
	$server = IO::Socket::INET->new(LocalPort=> $serverport,
									Type => SOCK_STREAM,
									Reuse => 1,
									Listen => $servermaxconnect)
			or die "ARG.... Can't open server socket\n";
	$lastscheduler= time;
	@internal_command_file = ();
	print "Init done\n";
}

#################
# TESTS
################
#init();
#my $client = $server->accept();
#$_ = <$client>;
#if ( $_ =~ /^\[DEBUG\]*/){
#	print("TOTO\n");
#	print($_);
#}else{
#	print("TITI\n");
#}
#while (<$client>) {
#	print("$_\n");
#}
#exit 0;

sub scheduler()
{
	return launch_command($scheduler_command);
}

sub qget()
{
	my $answer;
	my $rin = '';
	my $carac;
	vec($rin,fileno($server),1) = 1;
	my $res = select($rin, undef, undef, $internaltimeout);
	if($res > 0){
		my $client = $server->accept();
		$answer = <$client>;
		# cleans the answer of all unwanted trailing characters
		$carac = chop($answer);
		while ($carac !~ '[a-zA-Z0-9]'){
			$carac = chop($answer);
		}
		$answer = $answer.$carac;
		# special case to print what want to say the remote command
		if ( $answer =~ /^\[DEBUG\]*/){
			print($answer);
			$answer = "Time";
		}else{
			print($client "Votre requete [$answer] a bien ete prise en compte. Merci de nous avoir accorde votre confiance.\nToute l'equipe de CIGRI vous souhaite une bonne journee.\n");
		}
		close($client);
	}else{
		$answer = "Time";
	}
	return $answer;
}

sub runner()
{
	return launch_command($runner_command);
}

sub updator(){
	return launch_command($updator_command);
}

sub time_update()
{
	my $current = time;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($current);

	$year+=1900;
	$mon+=1;
	print("Timeouts check : $year-$mon-$mday $hour:$min:$sec\n");
	# check timeout for scheduler
	if ($current >= ($lastscheduler+$schedulertimeout))
	{
		print("Scheduling timeout\n");
		$lastscheduler = $lastscheduler+$schedulertimeout;
		push(@internal_command_file,"Scheduling");
	}
}

#// debut du prog
my $state= "Init";
my $command;
my $id;
my $node;
my $pid;

while (1){
	print("Current state [$state]\n");
	SWITCH:{
		# INIT
		if($state eq "Init")
		{
			init();
			$state="Qget";
			last SWITCH;
		}
		# QGET
		elsif($state eq "Qget")
		{
			my $qget_result = qget();
			push(@internal_command_file, $qget_result)
				unless ($qget_result eq "Time") && (scalar @internal_command_file);
			print("Command queue : @internal_command_file\n");
			my $current_command = shift(@internal_command_file);
			my ($command,$arg1,$arg2,$arg3) = split(/ /,$current_command);
			print("Qtype = [$command]\n");
			if (($command eq "gridsub")){
				$state="Scheduler";
			}elsif ($command eq "Time"){
				$state="Time update";
			}else{
				warn("unknown command found in queue\n");
			}
			last SWITCH;
		}
		# SCHEDULER
		elsif($state eq "Scheduler"){
			updator();
			my $scheduler_result=scheduler();
			if ($scheduler_result == 0){
				$state="Runner";
			}else{
				die("Scheduler returned an unknown value\n");
			}
			last SWITCH;
		}

		# RUNNER
		elsif($state eq "Runner"){
			runner();
			$state="Time update";
			last SWITCH;
		}

		# TIME UPDATE
		elsif($state eq "Time update"){
			updator();
			scheduler();
			runner();
			time_update();
			$state="Qget";
			last SWITCH;
		}else{
			print("Critical bug !!!!\n");
			die("Almighty just falled into an unknown state !!!\n");
		}
	}
}
