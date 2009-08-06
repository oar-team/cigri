#!/bin/sh


path="/home/cigri/CIGRI"

runner_command="${path}/Runner/runnerCigri.pl";
updator_command=${path}"/Updator/updatorCigri.pl";
gridstatus_command=${path}"/Updator/gridstatus.rb";
nikita_command=${path}"/Nikita/nikitaCigri.pl";
spritz_command=${path}"/Spritz/spritzCigri.pl";
autofix_command=${path}"/Colombo/autofixCigri.rb";
phoenix_command=${path}"/Phoenix/phoenixCigri.rb";
sched_command=${path}"/Scheduler/sched_fifoCigri.pl";
meta_sched_command=${path}"/Scheduler/MetaScheduler.rb";


#--------------------------------------------------
# - AutoFix
# - Updator
# - Spritz
# - Scheduler
# - Gridstatus
# - Runner
# - Phoenix
# - Nikita
#-------------------------------------------------- 

while [ 1 ] 
do

echo " Please chose the module to run: "
echo " 1 - AutoFix"
echo " 2 - Updator"
echo " 3 - Spritz"
echo " 4 - Scheduler"
echo " 4b - MetaScheduler"
echo " 5 - Gridstat"
echo " 6 - Runner"
echo " 7 - Phoenix"
echo " 8 - Nikita"
echo " * - Run a whole Almighty iteration"
echo " - - Give your own command"
echo " x|q - Exit"

read opt

echo "------------------------"
case $opt in
   1)  echo "Running AutoFix:"; time $autofix_command ;;
   2)  echo "Running Updator:"; time $updator_command ;;
   3)  echo "Running Spritz:"; time $spritz_command ;;
   4)  echo "Running Scheduler:"; time $sched_command ;;
   4b)  echo "Running Scheduler:"; time $meta_sched_command ;;
   5)  echo "Running Gridstatus:"; time $gridstatus_command ;;
   6)  echo "Running Runner:"; time $runner_command ;;
   7)  echo "Running Phoenix:"; time $phoenix_command ;;
   8)  echo "Running Nikita:"; time $nikita_command ;;
   \*)  echo "Running an Almighty iteration:"; 
						echo "========= AUTOFIX ============";
						time $autofix_command;  
						echo "========= UPDATOR ============";
						time $updator_command;   
						echo "========= SPRITZ =============";
						time $spritz_command ;
						echo "========= SCHED ==============";
						#time $sched_command; 
						time $meta_sched_command; 
						echo "========= GSTAT ==============";
 						time $gridstatus_command;
						echo "========= RUNNER =============";
						time $runner_command; 
						echo "========= PHOENIX ============";
						time $phoenix_command;
						echo "========= NIKITA =============";
						time $nikita_command;;

   x|q) exit 0;;
   -)  echo "Give your own command:"
	   read cmd
	   time $cmd;;
esac
echo "------------------------"

done

