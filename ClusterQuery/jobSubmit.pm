package jobSubmit;

use Data::Dumper;
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
    unshift(@INC, $relativePath."Iolib");
    unshift(@INC, $relativePath."Net");
    unshift(@INC, $relativePath."Colombo");
    unshift(@INC, $relativePath."ClusterQuery");
}

use iolibCigri;
#use SSHcmdClient;
use SSHcmd;
use colomboCigri;
use NetCommon;
use warnings;
use OARiolib;
use oarNotify;


my %submitCmd = (
                  'OAR' => \&oarsubmit,
                  'OAR2' => \&oarsubmit2,
                  'OAR2_3' => \&oarsubmit2,
                );

#arg1 --> cluster name
#arg2 --> blacklisted nodes
#arg3 --> user
#arg4 --> jobFile to submit
#arg5 --> walltime of the job
#arg6 --> resources required by the job
#arg7 --> execution directory
#arg8 --> jobId
#arg9 --> jobName
#return jobBatchId or -1 or -2 if something wrong happens
sub jobSubmit($$$$$$$$$){
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
    my $resources = shift;
    my $execDir = shift;
    my $jobId = shift;
    my $jobName = shift;

    my $base = iolibCigri::connect();
    my %clusterProperties = iolibCigri::get_cluster_names_batch($base);
    my %result ;
    my $retCode = -1;

    if (defined($cluster) && defined($clusterProperties{$cluster})){
        $retCode = &{$submitCmd{$clusterProperties{$cluster}}}($base,$cluster,$blackNodes,$user,$jobFile,$walltime,$resources,$execDir,$jobId,$jobName);
    }
    iolibCigri::disconnect($base);
    return($retCode);
}

my %clusterToNotify;

#arg1 --> cluster name
# return 0 if Ok
sub endJobSubmissions($){
    my $cluster = shift;

    my $retCode = 0;
    if (defined($clusterToNotify{$cluster})){
        $retCode = oarNotify::notify($cluster,"Qsub");
    }

    return($retCode);
}



#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> blacklisted nodes
#arg4 --> user
#arg5 --> jobFile to submit
#arg6 --> walltime
#arg7 --> required resources (oar -l)
#arg8 --> execDir
#arg9 -> jobId
#arg10 -> jobName
#return jodBatchId or
#   -1 : for a command execution error
#   -2 : for a jobId parse error
sub oarsubmit($$$$$$$$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
 	my $resources = shift;
    my $execDir = shift;
    my $jobId = shift;
    my $jobName = shift;

    #print("$cluster --> OAR\n");

	#if job resources are not defined, 
    #get the default from cigri.conf
	if ($resources eq '') {
    	$resources = iolibCigri::get_default_job_resources();
	}

    my $propertyString;
    foreach my $i (@$blackNodes){
        $propertyString .= " hostname != '\\'$i\\'' AND";
    }
    if (defined($propertyString)){
        $propertyString =~ s/^(.+)AND$/$1/g;
    }else{
        $propertyString = "";
    }

    my $campId = iolibCigri::get_mjob_id($dbh, $jobId);

 	#existing env. variables require double protection
    my $jobEnv = '';
    $jobEnv .= ' export CIGRI_NODE_FILE=\\\\\\$OAR_NODEFILE;';
    $jobEnv .= ' export CIGRI_NODEFILE=\\\\\\$OAR_NODEFILE;';
    $jobEnv .= " export CIGRI_JOB_ID=$jobId;";
    $jobEnv .= " export CIGRI_JOBID=$jobId;";
    $jobEnv .= " export CIGRI_CAMPAIGNID=$campId;";
    $jobEnv .= " export CIGRI_CAMPAIGN_ID=$campId;";
    $jobEnv .= " export CIGRI_JOB_NAME=$jobName;";
    $jobEnv .= " export CIGRI_JOBNAME=$jobName;";
    $jobEnv .= " export CIGRI_USER=$user;";
    $jobEnv .= " export CIGRI_WORKDIR=$execDir;";
    $jobEnv .= " export CIGRI_WORKING_DIRECTORY=$execDir;";
	$jobEnv .= " export CIGRI_RESOURCES=$resources;"; 
    $jobEnv .= " export CIGRI_WALLTIME=$walltime;";
    $jobEnv .= " export CIGRI_WALLTIME_SECONDS=".iolibCigri::get_walltime_in_seconds($walltime).";";  

    #print("Property String = $propertyString\n");
    #my %cmdResult = SSHcmd::submitCmd($cluster,"cd ~$user; sudo -H -u $user oarsub -l nodes=1,weight=$weight,walltime=$walltime -p \"$propertyString\" -q besteffort $jobFile");
    my %cmdResult = SSHcmd::submitCmd($cluster,"sudo -H -u $user bash -l -c \"cd $execDir; oarsub -l $resources,walltime=$walltime -p \\\"$propertyString\\\" -q besteffort \\\" $jobEnv $jobFile \\\"\"");
    #print(Dumper(%cmdResult));
    if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            colomboCigri::add_new_cluster_event($dbh,$cluster,0,"OAR_OARSUB","$cmdResult{STDERR}");
        }
        return(-1);
    }
    my @strTmp = split(/\n/, $cmdResult{STDOUT});
    foreach my $k (@strTmp){
        # search cluster batchId of the job
        if ($k =~ /\s*IdJob\s=\s(\d+)/){
            return($1);
        }
    }
    return(-2);
}

#arg1 --> db ref
#arg2 --> cluster name
#arg3 --> blacklisted nodes
#arg4 --> user
#arg5 --> jobFile to submit
#arg6 --> walltime
#arg7 --> job required resources (OAR -l)
#arg8 --> execDir
#arg9 --> jobId
#arg10 -> jobName
#return jodBatchId or
#   -1 : for a command execution error
#   -2 : for a jobId parse error
sub oarsubmit2($$$$$$$$$$){
    my $dbh = shift;
    my $cluster = shift;
    my $blackNodes = shift;
    my $user = shift;
    my $jobFile = shift;
    my $walltime = shift;
    my $resources = shift;
    my $execDir = shift;
    my $jobId = shift;
    my $jobName = shift;
    if (!defined($jobName)) { $jobName="cigri.$jobId" } 

	
    #print("$cluster --> OAR2\n");
    
    #if job resources are not defined, 
    #get the default from cigri.conf
	if ($resources eq '') {
    	my $resources = iolibCigri::get_default_job_resources();
	}
    
	my $propertyString;
    foreach my $i (@$blackNodes){
        $propertyString .= " network_address != '\\'$i\\'' AND";
    }
    if (defined($propertyString)){
        $propertyString =~ s/^(.+)AND$/$1/g;
    }else{
        $propertyString = "";
    }

	my $campId = iolibCigri::get_mjob_id($dbh, $jobId);

	#existing env. variables require double protection
	my $jobEnv = '';
	$jobEnv .= ' export CIGRI_NODE_FILE=\\\\\\$OAR_NODEFILE;'; 
	$jobEnv .= ' export CIGRI_NODEFILE=\\\\\\$OAR_NODEFILE;'; 
	$jobEnv .= " export CIGRI_JOB_ID=$jobId;"; 
	$jobEnv .= " export CIGRI_JOBID=$jobId;"; 
	$jobEnv .= " export CIGRI_CAMPAIGNID=$campId;"; 
	$jobEnv .= " export CIGRI_CAMPAIGN_ID=$campId;"; 
	$jobEnv .= " export CIGRI_JOB_NAME=$jobName;"; 
	$jobEnv .= " export CIGRI_JOBNAME=$jobName;"; 
	$jobEnv .= " export CIGRI_USER=$user;"; 
	$jobEnv .= " export CIGRI_WORKDIR=$execDir;"; 
	$jobEnv .= " export CIGRI_WORKING_DIRECTORY=$execDir;"; 
	$jobEnv .= " export CIGRI_RESOURCES=$resources;"; 
	$jobEnv .= " export CIGRI_WALLTIME=$walltime;"; 
	$jobEnv .= " export CIGRI_WALLTIME_SECONDS=".iolibCigri::get_walltime_in_seconds($walltime).";"; 

    #print (" [RUNNER]     sudo -H -u $user bash -l -c \"cd $execDir; oarsub --name=\\\"$jobName\\\" --signal=3 -d $execDir -l $resources,walltime=$walltime -p \\\"$propertyString\\\" -t besteffort \\\" $jobEnv $jobFile \\\"\"\n");
    my %cmdResult = SSHcmd::submitCmd($cluster,"sudo -H -u $user bash -l -c \"cd $execDir; oarsub --name=\\\"$jobName\\\" --signal=3 -d $execDir -l $resources,walltime=$walltime -p \\\"$propertyString\\\" -t besteffort \\\" $jobEnv $jobFile \\\"\"");
    #print(Dumper(%cmdResult));
    
	if ($cmdResult{STDERR} ne ""){
        # test if this is a ssh error
        if (NetCommon::checkSshError($dbh,$cluster,$cmdResult{STDERR}) != 1){
            #colomboCigri::add_new_cluster_event($dbh,$cluster,iolibCigri::get_MjobsId($dbh,$jobId),"OAR_OARSUB","$cmdResult{STDERR}");
            iolibCigri::set_job_state($dbh, $jobId, "Event");
            colomboCigri::add_new_job_event($dbh,$jobId,"OAR_OARSUB","$cmdResult{STDERR}");
        }
        return(-1);
    }

    my @strTmp = split(/\n/, $cmdResult{STDOUT});
    foreach my $k (@strTmp){
        # search cluster batchId of the job
        if ($k =~ /\s*JOB_ID\s*=\s*(\d+)/){
            return($1);
        }
    }
    return(-2);
}

return 1;

