#!/usr/bin/perl

use strict;
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
    unshift(@INC, $relativePath."Net");
    unshift(@INC, $relativePath."Iolib");
    unshift(@INC, $relativePath."Colombo");
}
use iolibCigri;
use Data::Dumper;
use SSHcmd;
use colomboCigri;
use NetCommon;

my $base = iolibCigri::connect();
# connection to the database for the lock
my $baseLock = iolibCigri::connect();
# only one instance of the collector
iolibCigri::lock_collector($baseLock);

# id of MJobs to collect
my @MjobsToCollect;

# if an argument --> a MJob id
if ($ARGV[0] =~ /^\d+$/ ){
    push(@MjobsToCollect, $ARGV[0]);
}else{
    @MjobsToCollect = iolibCigri::get_tocollect_MJobs($base, 1);
}

foreach my $i (@MjobsToCollect){
    iolibCigri::begin_transaction($base);
    print("\n[COLLECTOR] I collecte the MJob $i\n");
    # get clusters userLogins jobID jobBatchId clusterBatch userGridName
    my @jobs = iolibCigri::get_tocollect_MJob_files($base,$i);
    my %clusterVisited;
    my %collectedJobs;
    my @errorJobs;

    foreach my $j (@jobs){
        my %cmdResult;

        if ((colomboCigri::is_cluster_active($base,"$$j{nodeClusterName}",$i) > 0) || (colomboCigri::is_collect_active($base,$i,"$$j{nodeClusterName}") > 0)){
                # le code qui delete un caractere : \x8
                #print("[COLLECTOR] the cluster $$j{nodeClusterName} is blacklisted : ");
            print("*");
            next;
        }
        print("\n");

        # clean the repository on the remote cluster
        if (!defined($clusterVisited{$$j{nodeClusterName}})){
            my $cmd = "if [ -d ~cigri/results_tmp ]; then rm -rf ~cigri/results_tmp/* ; else mkdir ~cigri/results_tmp ; fi";
            %cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, $cmd);
            if ($cmdResult{STDERR} ne ""){
                if (NetCommon::checkSshError($base,$$j{nodeClusterName},$cmdResult{STDERR}) != 1){
                    colomboCigri::add_new_cluster_event($base,$$j{nodeClusterName},0,"COLLECTOR","There is an error in the collector : SSHcmd::submitCmd($$j{nodeClusterName}, $cmd) -- $cmdResult{STDERR}");
                }
                iolibCigri::commit_transaction($base);
                iolibCigri::begin_transaction($base);
                print("[COLLECTOR] ERROR --> SSHcmd::submitCmd($$j{nodeClusterName}, $cmd)  -- $cmdResult{STDERR} \n");
                next;
            }
        }

        # make the tar on remote cluster
        undef(%cmdResult);
        my $error = 0;
        my %hashfileToDownload = get_file_names($j);
        my @fileToDownload = keys(%hashfileToDownload);
        my $k;
        my @jobTaredTmp;
        while((($k = pop(@fileToDownload)) ne "") and ($error == 0)){
            if ($error == 0){
                my $cmd = "";
                if ("$hashfileToDownload{$k}" ne ""){
                    $cmd = "test ! -e ~$$j{userLogin}/$hashfileToDownload{$k} && test -e ~$$j{userLogin}/$k && sudo -u $$j{userLogin} mv ~$$j{userLogin}/$k ~$$j{userLogin}/$hashfileToDownload{$k} ; test -e ~$$j{userLogin}/$hashfileToDownload{$k} && tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $hashfileToDownload{$k} && echo nimportequoi";
                    print("[COLLECTOR] tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $hashfileToDownload{$k}  -- on $$j{nodeClusterName}\n");
                }else{
                    $cmd = "test -e ~$$j{userLogin}/$k && tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $k && echo nimportequoi";
                    print("[COLLECTOR] tar rf ~cigri/results_tmp/$i.tar -C ~$$j{userLogin} $k  -- on $$j{nodeClusterName}\n");
                }
                %cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, $cmd);
                #print(Dumper(%cmdResult));
                if ($cmdResult{STDERR} ne ""){
                    warn("ERREUR -- $cmdResult{STDERR}\n");

                    if (NetCommon::checkSshError($base,$$j{nodeClusterName},$cmdResult{STDERR}) != 1){
                        colomboCigri::add_new_cluster_event($base,$$j{nodeClusterName},$i,"COLLECTOR","There is a tar  error in the collector : SSHcmd::submitCmd($$j{nodeClusterName}, $cmd) -- $cmdResult{STDERR}");
                    }
                    iolibCigri::commit_transaction($base);
                    iolibCigri::begin_transaction($base);

                    # Delete previous files in the tarball
                    #foreach my $l (@jobTaredTmp){
                    #    undef(%cmdResult);
                    #    my $cmdErase = "";
                    #    if ("$hashfileToDownload{$l}" ne ""){
                    #        $cmdErase = "tar --delete -f ~cigri/results_tmp/$i.tar $hashfileToDownload{$l}";
                    #    }else{
                    #        $cmdErase = "tar --delete -f ~cigri/results_tmp/$i.tar $l";
                    #    }
                    #    %cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, $cmdErase);
                    #    if ($cmdResult{STDERR} ne ""){
                    #        # A traiter
                    #        warn("Can t delete $l in ~cigri/results_tmp/$i.tar\n");
                    #    }
                    #}

                    $error = 1;
                }else{
                    if ($cmdResult{STDOUT} ne "\n"){
                        push(@jobTaredTmp, $k);
                    }else{
                        warn("/!\\ Can t collect : the file does not exist or i can t rename the file\n");
                    }
                }
            }
        }

        if (($error == 0) && ($#jobTaredTmp >= 0)){
            $collectedJobs{$$j{jobId}} = $j;
            $clusterVisited{$$j{nodeClusterName}} = 1;
        }else{
            push(@errorJobs, $j);
        }
    }

    # feedback for jobs which we can t collect
    foreach my $j (@errorJobs){
        iolibCigri::set_job_collectedJobId($base,$$j{jobId},-1);
    }

    iolibCigri::commit_transaction($base);
    iolibCigri::begin_transaction($base);

    my $userGridName = ${$jobs[0]}{userGridName};

    # copy the tar on the grid server
    my %jobToRemove;
    foreach my $j (keys(%clusterVisited)){
        if (colomboCigri::is_cluster_active($base,"$j",0) > 0){
            #print("[COLLECTOR] the cluster $j is blacklisted\n");
            print("*");
            next;
        }
        print("\n");
        my @resColl = iolibCigri::create_new_collector($base,$j,$i);
        print("mkdir -p ~cigri/results/$userGridName/$i \n");
        system("mkdir -p ~cigri/results/$userGridName/$i");
        if( $? != 0 ){
            iolibCigri::rollback_transaction($base);
            die("DIE exit_code=$?\n");
        }

        # voir pour mettre un timeout sur le gzip???????
        print("ssh $j gzip ~cigri/results_tmp/$i.tar\n");
        system("ssh $j gzip \"~cigri/results_tmp/$i.tar\"");
        if ($? != 0){
            iolibCigri::rollback_transaction($base);
            iolibCigri::begin_transaction($base);
            colomboCigri::add_new_cluster_event($base,$j,0,"COLLECTOR","There is a GZIP  error in the collector : system(ssh $j gzip ~cigri/results_tmp/$i.tar) -- retCode=$?");
            warn("Error exit_code=$?\n");
        }else{
            print("scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz \n");
            system("scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz");
            if( $? != 0 ){
                iolibCigri::rollback_transaction($base);
                iolibCigri::begin_transaction($base);
                colomboCigri::add_new_cluster_event($base,$j,0,"COLLECTOR","There is a SCP  error in the collector : system(scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz) -- retCode=$?");
                #colomboCigri::add_new_cluster_event($base,$j,0,"COLLECTOR","There is a SCP  error in the collector");
                warn("Error scp exit_code=$?\n");
            }else{
                foreach my $k (keys(%collectedJobs)){
                    if("${$collectedJobs{$k}}{nodeClusterName}" eq "$j"){
                        print("set collectedJobId de $k = $resColl[1]\n");
                        iolibCigri::set_job_collectedJobId($base,$k,$resColl[1]);
                        $jobToRemove{$k} = $collectedJobs{$k};
                    }
                }
            }
        }
        iolibCigri::commit_transaction($base);
        iolibCigri::begin_transaction($base);
    }

    # remove collected files
    foreach my $l (keys(%jobToRemove)){
        my %cmdResult;
        my $j = $jobToRemove{$l};
        if (colomboCigri::is_cluster_active($base,"$$j{nodeClusterName}",0) > 0){
            #print("[COLLECTOR] the cluster $$j{nodeClusterName} is blacklisted\n");
            print("*");
            next;
        }
        print("\n");
        my %hashfileToDownload = get_file_names($j);
        my @fileToDownload = keys(%hashfileToDownload);
        foreach my $k (@fileToDownload){
            my $cmd = "";
            if ("$hashfileToDownload{$k}" ne ""){
                $cmd = "sudo -u $$j{userLogin} test -e ~$$j{userLogin}/$hashfileToDownload{$k} && sudo -u $$j{userLogin} rm -rf ~$$j{userLogin}/$hashfileToDownload{$k}";
                print("[COLLECTOR] rm file ~$$j{userLogin}/$hashfileToDownload{$k} on cluster $$j{nodeClusterName}\n");
            }else{
                $cmd = "sudo -u $$j{userLogin} test -e ~$$j{userLogin}/$k && sudo -u $$j{userLogin} rm -rf ~$$j{userLogin}/$k";
                print("[COLLECTOR] rm file ~$$j{userLogin}/$k on cluster $$j{nodeClusterName}\n");
            }
            %cmdResult = SSHcmd::submitCmd($$j{nodeClusterName}, $cmd);
            if ($cmdResult{STDERR} ne ""){
                warn("ERROR -- $cmdResult{STDERR}\n");
                if (NetCommon::checkSshError($base,$$j{nodeClusterName},$cmdResult{STDERR}) != 1){
                    colomboCigri::add_new_cluster_event($base,$$j{nodeClusterName},0,"COLLECTOR","There is a RM error in the collector : SSHcmd::submitCmd($$j{nodeClusterName}, $cmd) -- $cmdResult{STDERR}");
                }
            }
        }
    }
    iolibCigri::commit_transaction($base);
}

iolibCigri::unlock_collector($baseLock);
iolibCigri::disconnect($base);

print("\n");
exit 0;

# get files to collect for a job
# arg1 --> struct of the job
sub get_file_names($){
    my $j = shift;
    my %result ;
    if($$j{jobName} ne ""){
        $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout"} = "$$j{jobName}.$$j{jobId}.stdout";
        $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"} = "$$j{jobName}.$$j{jobId}.stderr";
        $result{"$$j{jobName}"} = "";
    }else{
        $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout"} = "";
        $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"} = "";
    }

    return %result;
}

