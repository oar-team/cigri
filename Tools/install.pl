#!/usr/bin/perl


use strict;
use warnings;
use Data::Dumper;
use DBI;


# DataBase hostname
my $dbHost = "localhost";
# DataBase login
my $dbLogin = "root";
# DataBase password or the dbLogin
my $dbPassword = "basket";
# Database base name
my $dbName = "oar";
# DataBase user name
my $dbUserName = "oar";
# DataBase user password
my $dbUserPassword = "oar";
# Installation path
my $installPath = "/usr/local/oar";
# OAR server
my $oarServer = "localhost";
# OAR server port
my $oarServerPort = "6666";

# hash of var which are defined by the user
my %configuredVar = ();

# Relative path of the package
my @relativePathTemp = split(/\//, $0);
my $relativePath = "";
for (my $i = 0; $i < $#relativePathTemp; $i++){
	$relativePath = $relativePath.$relativePathTemp[$i]."/";
}
$relativePath = $relativePath."../";

BEGIN {
	# Relative path of the package
	my @relativePathTemp = split(/\//, $0);
	my $relativePath = "";
	for (my $i = 0; $i < $#relativePathTemp; $i++){
		$relativePath = $relativePath.$relativePathTemp[$i]."/";
	}
	$relativePath = $relativePath."../";
	# configure the path to reach the ConfLib module
	unshift(@INC, $relativePath."ConfLib"); 
}

use ConfLib qw(init_conf get_conf);


# relative path of each file to install
# file => relative install path 
my $filePath = {
				'Almighty/Almighty.pl' => 'bin/Almighty.pl',
				'Leon/Leon.pl' => 'bin/Leon.pl',
				'Runner/OAREXEC.pl' => 'bin/OAREXEC.pl',
				'Leon/OARkill' => 'bin/OARkill',
				'Leon/sentinelle' => 'bin/sentinelle',
				'Runner/bipbip.pl' => 'bin/bipbip.pl',
				'Qfunctions/pbsnodes.pl' => 'bin/pbsnodes.pl',
				'Qfunctions/qdel.pl' => 'bin/qdel.pl',
				'Qfunctions/qstat.pl' => 'bin/qstat.pl',
				'Qfunctions/qsub.pl' => 'bin/qsub.pl',
				'Runner/runner.pl' => 'bin/runner.pl',
				'Sarko/sarko.pl' => 'bin/sarko.pl',
				'Scheduler/sched_fifo.pl' => 'bin/sched_fifo.pl',
				'ConfLib/ConfLib.pm' => 'lib/ConfLib.pm',
				'Iolib/iolib.pm' => 'lib/iolib.pm',
				'Tools/oar.conf' => 'conf/oar.conf'
};

# Configure module perl path
my $perlLibPath;
if (defined($ENV{"PERL_PATH"}) && opendir(DIR, $ENV{"PERL_PATH"})){
	$perlLibPath = $ENV{"PERL_PATH"};
	closedir(DIR);
}elsif (opendir(DIR, "/usr/lib/perl5/5.8.0")){
	$perlLibPath = "/usr/lib/perl5/5.8.0";
	closedir(DIR);
}elsif (opendir(DIR, "/usr/lib/perl/5.8.0")){
	$perlLibPath = "/usr/lib/perl/5.8.0";
	closedir(DIR);
}else{
	print("Can't find perl path\nPlease set your PERL_PATH shell variable\n");
	exit(1);
}

# Lists all links to create and where
my $fileLink = {
				'Almighty/Almighty.pl' => '/usr/bin/Almighty.pl',
				'Leon/Leon.pl' => '/usr/bin/Leon.pl',
				'Runner/OAREXEC.pl' => '/usr/bin/OAREXEC.pl',
				'Leon/OARkill' => '/usr/bin/OARkill',
				'Leon/sentinelle' => '/usr/bin/sentinelle',
				'Runner/bipbip.pl' => '/usr/bin/bipbip.pl',
				'Qfunctions/pbsnodes.pl' => '/usr/bin/pbsnodes.pl',
				'Qfunctions/qdel.pl' => '/usr/bin/qdel.pl',
				'Qfunctions/qstat.pl' => '/usr/bin/qstat.pl',
				'Qfunctions/qsub.pl' => '/usr/bin/qsub.pl',
				'Runner/runner.pl' => '/usr/bin/runner.pl',
				'Sarko/sarko.pl' => '/usr/bin/sarko.pl',
				'Scheduler/sched_fifo.pl' => '/usr/bin/sched_fifo.pl',
				'ConfLib/ConfLib.pm' => $perlLibPath.'/ConfLib.pm',
				'Iolib/iolib.pm' => $perlLibPath.'/iolib.pm',
				'Tools/oar.conf' => '/etc/oar.conf'
};

# Lists all files for which execute chmod +s on
my $cmdCHMODS = [ "Leon/Leon.pl", "Runner/bipbip.pl" ];

# files to install for a userInstall
my $userInstall = ["Qfunctions/pbsnodes.pl", "Qfunctions/qdel.pl", "Qfunctions/qstat.pl", "Qfunctions/qsub.pl", "Iolib/iolib.pm",
					"Tools/oar.conf", "Runner/bipbip.pl", "Leon/sentinelle", "ConfLib/ConfLib.pm"];
# files to install for a serverInstall
my $serverInstall = ["Almighty/Almighty.pl", "Leon/Leon.pl", "Leon/OARkill", "Runner/bipbip.pl", "Runner/runner.pl",
					"Sarko/sarko.pl", "Scheduler/sched_fifo.pl", "ConfLib/ConfLib.pm", "Iolib/iolib.pm", "Tools/oar.conf"];
# files to install for a nodeInstall
my $nodeInstall = ["Runner/OAREXEC.pl", "Tools/oar.conf", "ConfLib/ConfLib.pm"];
# files to install for a databaseInstall
my $databaseInstall = ["ConfLib/ConfLib.pm", "Tools/oar.conf"];

	
# Show a prompt to the user and return what he types or the default value
sub promptUser {
	
	#-------------------------------------------------------------------#
	#  two possible input arguments - $promptString, and $defaultValue  #
	#  make the input arguments local variables.                        #
	#-------------------------------------------------------------------#
   
   	my($promptString,$defaultValue) = @_;

	#-------------------------------------------------------------------#
	#  if there is a default value, use the first print statement; if   #
	#  no default is provided, print the second string.                 #
	#-------------------------------------------------------------------#

	if (defined $defaultValue) {
		print($promptString, "[", $defaultValue, "]: ");
	} else {
		print($promptString, ": ");
	}

	$| = 1;               # force a flush after our print
   
   	$_  = <STDIN> ;         # get the input from STDIN (presumably the keyboard)

	#------------------------------------------------------------------#
	# remove the newline character from the end of the input the user  #
	# gave us.                                                         #
	#------------------------------------------------------------------#

	chomp;

	#-----------------------------------------------------------------#
	#  if we had a $default value, and the user gave us input, then   #
	#  return the input; if we had a default, and they gave us no     #
	#  no input, return the $defaultValue.                            #
	#                                                                 # 
	#  if we did not have a default value, then just return whatever  #
	#  the user gave us.  if they just hit the  key,           #
	#  the calling routine will have to deal with that.               #
	#-----------------------------------------------------------------#

	if (defined($defaultValue)) {
		return $_ ? $_ : $defaultValue;    # return $_ if it has a value
	} else {
		return $_;
	}
}

sub checkDatabaseConnection(){
	# Connect to the database.
    my $dbh = DBI->connect("DBI:mysql:database=mysql;host=$dbHost", $dbLogin, $dbPassword, {'RaiseError' => 1});
	my $query;
	print("toto\n");
}

# Connect to the MySQL database,
# Create the oar database
# Create the user for OAR
# Create needed tables
sub createDatabase(){
	# Connect to the database.
    my $dbh = DBI->connect("DBI:mysql:database=mysql;host=$dbHost", $dbLogin, $dbPassword, {'RaiseError' => 1});
	my $query;
	# Database build
	$query = $dbh->prepare("CREATE DATABASE IF NOT EXISTS $dbName") or die $dbh->errstr;
	$query->execute();
	# Add oar user
	# Test if this user already exists
	$query = $dbh->prepare("SELECT * FROM user WHERE User=\"".$dbUserName."\" and (Host=\"localhost\" or Host=\"%\")");
	$query->execute();
	if (! $query->fetchrow_hashref()){
		$query = $dbh->prepare("INSERT INTO user (Host,User,Password) 
								VALUES('localhost','".$dbUserName."',PASSWORD('".$dbUserPassword."'))") or die $dbh->errstr;
		$query->execute();

		$query = $dbh->prepare("INSERT INTO user (Host,User,Password)
								VALUES('%','".$dbUserName."',PASSWORD('".$dbUserPassword."'))") or die $dbh->errstr;
		$query->execute();

		$query = $dbh->prepare("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) 
								VALUES ('localhost','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y')") or die $dbh->errstr;
		$query->execute();

		$query = $dbh->prepare("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) 
								VALUES ('%','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y')") or die $dbh->errstr;
		$query->execute();

		$query = $dbh->prepare("FLUSH PRIVILEGES") or die $dbh->errstr;
		$query->execute();
	}else{
		print("User for the database already created\n");
	}
	
	# Grant user
	$query = $dbh->prepare("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP
								ON ".$dbName.".* TO ".$dbUserName."\@localhost") or die $dbh->errstr;
	$query->execute();
	
	$query = $dbh->prepare("GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP
								ON ".$dbName.".* TO ".$dbUserName."@\"%\"") or die $dbh->errstr;
	$query->execute();
	
	$query = $dbh->prepare("FLUSH PRIVILEGES") or die $dbh->errstr;
	$query->execute();
	
	$dbh->disconnect();
	
	
	# Connection to the oar database with oar user
	$dbh = DBI->connect("DBI:mysql:database=$dbName;host=$dbHost", $dbLogin, $dbPassword, {'RaiseError' => 1});
	# Create jobs table
#	$query = $dbh->prepare("DROP TABLE IF EXISTS jobs") or die $dbh->errstr;
#	$query->execute();
	
	$query = $dbh->prepare("CREATE TABLE IF NOT EXISTS jobs (
							idJob INT UNSIGNED NOT NULL AUTO_INCREMENT,
							jobType ENUM(\'INTERACTIVE\',\'PASSIVE\') DEFAULT \'PASSIVE\' NOT NULL ,
							infoType VARCHAR( 255 ) ,
							state ENUM(\'Waiting\',\'toLaunch\',\'Launching\',\'Running\',\'Terminated\',\'Error\')  NOT NULL ,
							toFrag ENUM(\'YES\',\'NO\') DEFAULT \'NO\' NOT NULL ,
							user VARCHAR( 20 ) NOT NULL ,
							nbNodes INT UNSIGNED NOT NULL ,
							weight INT UNSIGNED NOT NULL ,
							command VARCHAR( 255 ) NOT NULL ,
							bpid INT UNSIGNED ,
							processId VARCHAR( 100 ) ,
							maxTime TIME NOT NULL ,
							submissionTime DATETIME NOT NULL ,
							startTime DATETIME NOT NULL ,
							stopTime DATETIME NOT NULL ,
							PRIMARY KEY (idJob)
							)") or die $dbh->errstr;
	$query->execute();
	
	# Create processJobs table
#	$query = $dbh->prepare("DROP TABLE IF EXISTS processJobs") or die $dbh->errstr;
#	$query->execute();
	
	$query = $dbh->prepare("CREATE TABLE IF NOT EXISTS processJobs (
							idJob INT UNSIGNED NOT NULL AUTO_INCREMENT,
							hostname VARCHAR( 100 ) NOT NULL ,
							PRIMARY KEY (idJob,hostname)
							)") or die $dbh->errstr;
	$query->execute();
	
	# Create processJobs table
#	$query = $dbh->prepare("DROP TABLE IF EXISTS nodes") or die $dbh->errstr;
#	$query->execute();
	
	$query = $dbh->prepare("CREATE TABLE IF NOT EXISTS nodes (
							hostname VARCHAR( 100 ) NOT NULL ,
							state ENUM(\'Alive\',\'Dead\',\'Suspected\')  NOT NULL ,
							maxWeight INT UNSIGNED DEFAULT 1 NOT NULL ,
							weight INT UNSIGNED NOT NULL ,
							PRIMARY KEY (hostname)
							)") or die $dbh->errstr;
	$query->execute();
	
	$dbh->disconnect();
}

# Create the config file and append the defined variables
# arg1 --> name of the config file
sub writeConfFile($){
	my $fileName = shift(@_);
	print($fileName."\n");
	open(OARCONF,">$fileName");
	if (defined($configuredVar{"dbHost"})){
		print(OARCONF "database_host = ".$dbHost."\n");
	}
	if (defined($configuredVar{"dbName"})){
		print(OARCONF "database_name = ".$dbName."\n");
	}
	if (defined($configuredVar{"dbUserName"})){
		print(OARCONF "database_username = ".$dbUserName."\n");
	}
	if (defined($configuredVar{"dbUserPassword"})){
		print(OARCONF "database_userpassword = ".$dbUserPassword."\n");
	}
	if (defined($configuredVar{"installPath"})){
		print(OARCONF "installPath = ".$installPath."\n");
	}
	if (defined($configuredVar{"oarServer"})){
		print(OARCONF "OAR_SERVER = ".$oarServer."\n");
	}
	if (defined($configuredVar{"oarServerPort"})){
		print(OARCONF "OAR_SERVER_PORT = ".$oarServerPort."\n");
	}
	
	close(OARCONF);
	chmod(0644, $fileName);
}

# Show what OAR needs to be installed
sub neededPackages(){
	print("
You must have installed these packages before :

\t- Perl
\t- Perl-Mysql
\t- Perl-DBI
\t- Perl-base
\t- Perl-suid (if needed)
\t- MySQL-shared
\t- libmysql

You must create a oar user with a oar group
You must specify in /etc/sudoers a line like that
	oar     ALL=(ALL)       NOPASSWD: ALL
Check if you can connect your host via SSH to all cluster nodes (and vice-versa without saying YES to the prompt)
---> Type Crt-C now, if you hadn't perfomed all of that

");
}

# copyFile
# arg1 --> ref of array of files to install
# arg2 --> relative path of these files
# arg3 --> ref of hash which specify where to install
# arg4 --> relative path where files will be installed
# arg5 --> links for the files
sub copyFiles($$$$$){
	my $tableInstall = shift;
	my $rootPath = shift;
	my $hashInstall = shift;
	my $targetPath = shift;
	my $hashLinks = shift;
	my $tmpPath = undef;
	
	my @directoryList = undef;
	my $pathToCopyTmp = "";
	foreach my $i (@$tableInstall){
		$tmpPath = $$hashInstall{$i};
		print($rootPath.$i);
		if (defined($tmpPath)){
			print("-->".$targetPath."/".$tmpPath."\n");
			@directoryList = split(/\//,$targetPath."/".$tmpPath);
			for (my $j = 0; $j<$#directoryList; $j++){
				$pathToCopyTmp = $pathToCopyTmp."/".$directoryList[$j];
				# Test if we must create the directory
				if (! opendir(DIR, $pathToCopyTmp)){
					print("mkdir ".$pathToCopyTmp."\n");
					if (mkdir($pathToCopyTmp)){
						print("chown oar.oar $pathToCopyTmp \n");
						system("chown oar.oar $pathToCopyTmp");
					}else{
						die("Can't create : ".$pathToCopyTmp);
					}
				}else{
					closedir(DIR);
				}
			}
			$pathToCopyTmp = "";
			system("cp ".$rootPath.$i." ".$targetPath."/".$tmpPath) ;
			print("chown oar.oar $targetPath"."/"."$tmpPath \n");
			system("chown oar.oar $targetPath"."/".$tmpPath);
			# Test if we must exec chmod +s on the file
			foreach my $k (@$cmdCHMODS){
				if ( $k eq $i ){
					print("chmod +s ".$targetPath."/".$tmpPath."\n");
					system("chmod +s ".$targetPath."/".$tmpPath);
				}
			}
			if ($? != "0") {die;};
			if (defined($$hashLinks{$i})){
				print("ln -s ".$targetPath."/".$tmpPath." ".$$hashLinks{$i}."\n");
				system("ln -s ".$targetPath."/".$tmpPath." ".$$hashLinks{$i});
			}
		}else{
			die("Il y a une erreur dans la definition des fichiers a copier");
		}
	}
}


# arg1 --> the prompt
# arg2 --> var name to tag this defined
# arg3 --> var ref
sub askUser($$$) {
	my $prompt = shift;
	my $varName = shift;
	my $refVar = shift;
	
	# Test to validate the STDIN filehandle
	if (!-t){
		die "STDIN n est pas ouvert sur un tty\n";
		
	}

	if (! defined($configuredVar{$varName})){
		$$refVar = promptUser($prompt, $$refVar);
		$configuredVar{$varName} = 1;
	}
}

sub usage($){
	print("Bad argument on the command line : $_[0] \n");
	print("arg = userInstall || nodeInstall || databaseInstall || serverInstall || uninstall\n");
	print("\t-userInstall : install all functions for submit and query the system (qsub, qstat, ...)\n");
	print("\t-nodeInstall : install a node of the cluster\n");
	print("\t-databaseInstall : create the database and the user in this database\n");
	print("\t-serverInstall : install server files\n");
	print("\t-unInstall : delete all oar files\n");
}

neededPackages;

$|=1;

# parse command line
foreach my $arg (@ARGV){
	if ($arg eq "userInstall"){
		print("install user\n");
		askUser("Install path : ", "installPath", \$installPath);
		askUser("MySQL database hostname : ", "dbHost", \$dbHost);
		askUser("OAR base name : ", "dbName", \$dbName);
		askUser("OAR user login : ", "dbUserName", \$dbUserName);
		system("stty -echo");
		askUser("OAR user password : ", "dbUserPassword", \$dbUserPassword);
		print("\n");
		system("stty echo");
		askUser("OAR server : ", "oarServer", \$oarServer);
		askUser("OAR server port : ", "oarServerPort", \$oarServerPort);
		checkDatabaseConnection();
		writeConfFile($relativePath."Tools/oar.conf");
		copyFiles($userInstall, $relativePath, $filePath, $installPath, $fileLink);
	}elsif ($arg eq "serverInstall"){
		print("install server\n");
		askUser("Install path : ", "installPath", \$installPath);
		askUser("MySQL database hostname : ", "dbHost", \$dbHost);
		askUser("OAR base name : ", "dbName", \$dbName);
		askUser("OAR user login : ", "dbUserName", \$dbUserName);
		system("stty -echo");
		askUser("OAR user password : ", "dbUserPassword", \$dbUserPassword);
		print("\n");
		system("stty echo");
		askUser("OAR server : ", "oarServer", \$oarServer);
		askUser("OAR server port : ", "oarServerPort", \$oarServerPort);
		checkDatabaseConnection();
		writeConfFile($relativePath."Tools/oar.conf");
		copyFiles($serverInstall, $relativePath, $filePath, $installPath, $fileLink);
#		createDatabase();
	}elsif ($arg eq "nodeInstall"){
		print("install node\n");
		askUser("Install path : ", "installPath", \$installPath);
		askUser("OAR server : ", "oarServer", \$oarServer);
		askUser("OAR server port : ", "oarServerPort", \$oarServerPort);
		writeConfFile($relativePath."Tools/oar.conf");
		copyFiles($nodeInstall, $relativePath, $filePath, $installPath, $fileLink);
	}elsif ($arg eq "databaseInstall"){
		print("install database\n");
		askUser("Install path : ", "installPath", \$installPath);
		askUser("MySQL database hostname : ", "dbHost", \$dbHost);
		askUser("Database super user login : ", "dbLogin", \$dbLogin);
		system("stty -echo");
		askUser("Database super user password : ", "dbPassword", \$dbPassword);
		print("\n");
		system("stty echo");
		askUser("New OAR base name : ", "dbName", \$dbName);
		askUser("New OAR user login : ", "dbUserName", \$dbUserName);
		system("stty -echo");
		askUser("New OAR user password : ", "dbUserPassword", \$dbUserPassword);
		print("\n");
		system("stty echo");
		checkDatabaseConnection();
		writeConfFile($relativePath."Tools/oar.conf");
		copyFiles($databaseInstall, $relativePath, $filePath, $installPath, $fileLink);
		createDatabase();
	}elsif ($arg eq "unInstall"){
		init_conf();
		my $installPreviousPath = get_conf("installPath");
		if ($installPreviousPath){
			print("rm -rf $installPreviousPath \n");
			system("rm -rf $installPreviousPath");
		}else{
			print("Can't find oar.conf\n");
		}
		
		my @tabLinks = values(%$fileLink);
		foreach my $link (@tabLinks){
			if (lstat($link)){
				print("rm ".$link."\n");
				system("rm ".$link);
			}
		}
	}else{
		usage($arg);
	}
}

if ($#ARGV == -1){
	usage("");
}

# A faire :
# un desinstalleur de DB
# tester la connexion à la base
# Penser a tester les chemins en dur pour savoir si il n y a pas deja des fichiers du meme nom

