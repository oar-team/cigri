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
use mailer;

my $run = 1;

# Init the request to the cigri.conf file
init_conf();

# number of seconds between two updates
my $timeout = 5;

my $tag = "[ALMIGHTY]   ";

my $path;
if (is_conf("INSTALL_PATH")){
    #$path = get_conf("INSTALL_PATH")."/bin/";
    $path = get_conf("INSTALL_PATH");
}else{
    die("You must have a cigri.conf (in /etc or in \$CIGRIDIR) script with a valid INSTALL_PATH tag\n");
}

#set paths of executables
my $runner_command = $path."/Runner/runnerCigri.pl";
my $updator_command = $path."/Updator/updatorCigri.pl";
my $gridstatus_command = $path."/Updator/gridstatus.rb";
my $nikita_command = $path."/Nikita/nikitaCigri.pl";
my $spritz_command = $path."/Spritz/spritzCigri.pl";
my $autofix_command = $path."/Colombo/autofixCigri.rb";
my $phoenix_command = $path."/Phoenix/phoenixCigri.rb";
my $metascheduler_command = $path."/Scheduler/MetaScheduler.rb";

#OLDSCHED------------------------------------------
# my $scheduler_path = $path."/Scheduler/";
#-------------------------------------------------- 

#my $base = iolibCigri::connect();

# launch a command and monitor it
# arg1 --> command name
sub launch_command($){
    my $command = shift;
    print "$tag [".localtime()."] Launching command : [$command]\n";
    system $command;
    my $exit_value  = $? >> 8;
    my $signal_num  = $? & 127;
    my $dumped_core = $? & 128;
    if ($exit_value > 0 || $signal_num > 0 || $dumped_core > 0) {
      print "$tag $command terminated :\n";
      print "Exit value : $exit_value\n";
      print "Signal num : $signal_num\n";
      print "Core dumped : $dumped_core\n";
    }
    if ($signal_num || $dumped_core){
        mailer::sendMail("/!\\ Signal or core dumped","The command ($command) can not be executed correctly :\n\tExit value = $exit_value\n\tSignal num = $signal_num\n\tCore dumped = $dumped_core");
        die "Something wrong occured (signal or core dumped) !!!\n";
    }
    return $exit_value;
}

my $base = iolibCigri::connect();


#OLDSCHED-------------------------------------------
# 
# # launch a scheduler or blacklist it
# sub scheduler(){
#     #my $base = iolibCigri::connect();
#     iolibCigri::update_current_scheduler($base);
#     my $sched = iolibCigri::get_current_scheduler($base);
#     #return launch_command($scheduler_command);
#     if (defined($$sched{schedulerFile})){
#         if ( -x $scheduler_path.$$sched{schedulerFile} ){
#             my $exitValue = launch_command($scheduler_path.$$sched{schedulerFile});
#             if ($exitValue != 0){
#                 colomboCigri::add_new_scheduler_event($base,$$sched{schedulerId},"EXIT_VALUE","bad exit value $exitValue for $scheduler_path$$sched{schedulerFile}");
#             }
#             #print("---------------->".${iolibCigri::get_current_scheduler($base)}{schedulerFile}."\n");
#             #iolibCigri::disconnect($base);
#             return $exitValue;
#         }else{
#             print("$tag Bad scheduler file\n");
#             colomboCigri::add_new_scheduler_event($base,$$sched{schedulerId},"ALMIGHTY_FILE","Can t find the file $scheduler_path$$sched{schedulerFile}");
#         }
#     }else{
#         print("$tag NO SCHEDULER " . $scheduler_path.$$sched{schedulerFile} . " -> " . $$sched{schedulerFile} .  " TO LAUNCH :-(\n");
#     }
#     #iolibCigri::disconnect($base);
# }
#-------------------------------------------------- 



#launch the metasched command
sub metascheduler(){
    return launch_command($metascheduler_command);
}

# launch the runner command
sub runner(){
    return launch_command($runner_command);
}

# launch updator command
sub updator(){
    return launch_command($updator_command);
}

# Launch gridstatus command
sub gridstatus(){
    return launch_command($gridstatus_command);
}

# launch nikita command
sub nikita(){
    return launch_command($nikita_command);
}

# launch spritz, the weather man
sub spritz(){
    
	return launch_command($spritz_command);
}

# launch autofix, the checker for fixable events
sub autofix(){
    return launch_command($autofix_command);
}

# launch phoenix, the checkpoint manager
sub phoenix(){
    return launch_command($phoenix_command);
}

if ($run == 0){
	exit 0;
}

# core of the AlmightyCigri
my $exitValue;
LBL:while (1){

	$exitValue = autofix();
    next LBL if ($exitValue != 0);
    $exitValue = updator();
	next LBL if ($exitValue != 0);
	$exitValue = gridstatus();
    next LBL if ($exitValue != 0);
    	$exitValue =  spritz();
    next LBL if ($exitValue != 0);
    $exitValue = metascheduler();
    next LBL if ($exitValue != 0);
    $exitValue = runner();
	next LBL if ($exitValue != 0);
	$exitValue = phoenix();
    next LBL if ($exitValue != 0);

    $exitValue = nikita();
	if ($exitValue != 0) { 
	   print "$tag WARNING! Nikita exited abnormaly!\n"; 
	   sleep(5);
	}
	$exitValue = 0;

    print("\n$tag I make a pause of $timeout seconds :-)\n");
    sleep($timeout);
}




#OLDSCHED-------------------------------------
# my $exitValue;
# LBL:while (1){
#     $exitValue = nikita();
# 	if ($exitValue != 0) { 
# 	   print "$tag WARNING! Nikita exited abnormaly!\n"; 
# 	   sleep(5);
# 	}
# 	$exitValue = 0;
# #        sleep(5);
#     next LBL if ($exitValue != 0);
# 	$exitValue = autofix();
#     next LBL if ($exitValue != 0);
#     $exitValue = updator();
# #        sleep(5);
#     next LBL if ($exitValue != 0);
#     $exitValue = scheduler();
# #        sleep(5);
# 	next LBL if ($exitValue != 0);
# 	$exitValue = gridstatus();
# #        sleep(5);
#     next LBL if ($exitValue != 0);
#     $exitValue = runner();
# 	next LBL if ($exitValue != 0);
# 	$exitValue = phoenix();
# #        sleep(5);
#     next LBL if ($exitValue != 0);
# 	$exitValue =  spritz();
#     print("\n$tag I make a pause of $timeout seconds :-)\n");
#     sleep($timeout);
# }
#-------------------------------------------------- 
