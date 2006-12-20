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
#my $baseLock = iolibCigri::connect();
# only one instance of the collector
#iolibCigri::lock_collector($baseLock);
# lock for 12H
iolibCigri::lock_collector($base,43200);

my %clusterProperties = iolibCigri::get_cluster_names_batch($base);

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

        my $execDir = $$j{propertiesExecDirectory};
        if ($execDir eq "~"){
            $execDir = "~$$j{userLogin}";
        }
        
        if ((colomboCigri::is_cluster_active($base,"$$j{jobClusterName}",$i) > 0) || (colomboCigri::is_collect_active($base,$i,"$$j{jobClusterName}") > 0)){
                # le code qui delete un caractere : \x8
                #print("[COLLECTOR] the cluster $$j{jobClusterName} is blacklisted : ");
            print("*");
            next;
        }
        print("\n");

        # clean the repository on the remote cluster
        if (!defined($clusterVisited{$$j{jobClusterName}})){
            my $cmd = "if [ -d ~cigri/results_tmp ]; then rm -rf ~cigri/results_tmp/* ; else mkdir ~cigri/results_tmp ; fi";
            %cmdResult = SSHcmd::submitCmd($$j{jobClusterName}, $cmd);
            if ($cmdResult{STDERR} ne ""){
                iolibCigri::commit_transaction($base);
                if (NetCommon::checkSshError($base,$$j{jobClusterName},$cmdResult{STDERR}) != 1){
                    colomboCigri::add_new_cluster_event($base,$$j{jobClusterName},0,"COLLECTOR","There is an error in the collector : SSHcmd::submitCmd($$j{jobClusterName}, $cmd) -- $cmdResult{STDERR}");
                }
                iolibCigri::begin_transaction($base);
                print("[COLLECTOR] ERROR --> SSHcmd::submitCmd($$j{jobClusterName}, $cmd)  -- $cmdResult{STDERR} \n");
                next;
            }
        }

        # make the tar on remote cluster
        undef(%cmdResult);
        my $error = 0;
        my %hashfileToDownload = get_file_names($j,$clusterProperties{$$j{jobClusterName}});
        my @fileToDownload = keys(%hashfileToDownload);
        my $k;
        my @jobTaredTmp;
        while((($k = pop(@fileToDownload)) ne "") and ($error == 0)){
            if ($error == 0){
                my $cmd = "";
                if ("$hashfileToDownload{$k}" ne ""){
                    $cmd = "test ! -e $execDir/$hashfileToDownload{$k} && test -e $execDir/$k && sudo -u $$j{userLogin} mv $execDir/$k $execDir/$hashfileToDownload{$k} ; test -e $execDir/$hashfileToDownload{$k} && touch ~cigri/results_tmp/$i.tar && tar rf ~cigri/results_tmp/$i.tar -C $execDir $hashfileToDownload{$k} && echo nimportequoi";
                    print("[COLLECTOR] tar rf ~cigri/results_tmp/$i.tar -C $execDir $hashfileToDownload{$k}  -- on $$j{jobClusterName}\n");
                }else{
                    $cmd = "test -e $execDir/$k && touch ~cigri/results_tmp/$i.tar && tar rf ~cigri/results_tmp/$i.tar -C $execDir $k && echo nimportequoi";
                    print("[COLLECTOR] tar rf ~cigri/results_tmp/$i.tar -C $execDir $k  -- on $$j{jobClusterName}\n");
                }
                %cmdResult = SSHcmd::submitCmd($$j{jobClusterName}, $cmd);
                #print(Dumper(%cmdResult));
                if ($cmdResult{STDERR} ne ""){
                    warn("ERREUR -- $cmdResult{STDERR}\n");
                    iolibCigri::commit_transaction($base);
                    if (NetCommon::checkSshError($base,$$j{jobClusterName},$cmdResult{STDERR}) != 1){
                        colomboCigri::add_new_cluster_event($base,$$j{jobClusterName},$i,"COLLECTOR","There is a tar  error in the collector : SSHcmd::submitCmd($$j{jobClusterName}, $cmd) -- $cmdResult{STDERR}");
                    }
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
                    #    %cmdResult = SSHcmd::submitCmd($$j{jobClusterName}, $cmdErase);
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
            $clusterVisited{$$j{jobClusterName}} = 1;
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
        print("ssh $j gzip \"~cigri/results_tmp/$i.tar\"\n");
        system("ssh $j gzip \"~cigri/results_tmp/$i.tar\"");
        if ($? != 0){
            iolibCigri::rollback_transaction($base);
            colomboCigri::add_new_cluster_event($base,$j,0,"COLLECTOR","There is a GZIP  error in the collector : system(ssh $j gzip ~cigri/results_tmp/$i.tar) -- retCode=$?");
            iolibCigri::begin_transaction($base);
            warn("Error exit_code=$?\n");
        }else{
            print("scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz \n");
            system("scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/.$resColl[2].tar.gz");
            if( $? != 0 ){
                iolibCigri::rollback_transaction($base);
                colomboCigri::add_new_cluster_event($base,$j,0,"COLLECTOR","There is a SCP  error in the collector : system(scp -q $j:~cigri/results_tmp/$i.tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz) -- retCode=$?");
                #colomboCigri::add_new_cluster_event($base,$j,0,"COLLECTOR","There is a SCP  error in the collector");
                iolibCigri::begin_transaction($base);
                warn("Error scp exit_code=$?\n");
            }else{
                system("mv ~cigri/results/$userGridName/$i/.$resColl[2].tar.gz ~cigri/results/$userGridName/$i/$resColl[2].tar.gz");
                #system("sudo chown $userGridName ~cigri/results/$userGridName/$i/$resColl[2].tar.gz");
                system("sudo chown -R $userGridName ~cigri/results/$userGridName/$i");
                foreach my $k (keys(%collectedJobs)){
                    if("${$collectedJobs{$k}}{jobClusterName}" eq "$j"){
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
        if (colomboCigri::is_cluster_active($base,"$$j{jobClusterName}",0) > 0){
            #print("[COLLECTOR] the cluster $$j{jobClusterName} is blacklisted\n");
            print("*");
            next;
        }

        my $execDir = $$j{propertiesExecDirectory};
        if ($execDir eq "~"){
            $execDir = "~$$j{userLogin}";
        }

        print("\n");
        my %hashfileToDownload = get_file_names($j,$clusterProperties{$$j{jobClusterName}});
        my @fileToDownload = keys(%hashfileToDownload);
        foreach my $k (@fileToDownload){
            my $cmd = "";
            if ("$hashfileToDownload{$k}" ne ""){
                $cmd = "sudo -u $$j{userLogin} test -e $execDir/$hashfileToDownload{$k} && sudo -u $$j{userLogin} rm -rf $execDir/$hashfileToDownload{$k}";
                print("[COLLECTOR] rm file $execDir/$hashfileToDownload{$k} on cluster $$j{jobClusterName}\n");
            }else{
                $cmd = "sudo -u $$j{userLogin} test -e $execDir/$k && sudo -u $$j{userLogin} rm -rf $execDir/$k";
                print("[COLLECTOR] rm file $execDir/$k on cluster $$j{jobClusterName}\n");
            }
            %cmdResult = SSHcmd::submitCmd($$j{jobClusterName}, $cmd);
            if ($cmdResult{STDERR} ne ""){
                warn("ERROR -- $cmdResult{STDERR}\n");
                if (NetCommon::checkSshError($base,$$j{jobClusterName},$cmdResult{STDERR}) != 1){
                    iolibCigri::commit_transaction($base);
                    colomboCigri::add_new_cluster_event($base,$$j{jobClusterName},0,"COLLECTOR","There is a RM error in the collector : SSHcmd::submitCmd($$j{jobClusterName}, $cmd) -- $cmdResult{STDERR}");
    		    iolibCigri::begin_transaction($base);
                }
            }
        }
    }
    iolibCigri::commit_transaction($base);
}

#iolibCigri::unlock_collector($baseLock);
iolibCigri::unlock_collector($base);
iolibCigri::disconnect($base);

print("\n");
exit 0;

# get files to collect for a job
# arg1 --> struct of the job
# arg2 --> cluster type
sub get_file_names($$){
    my $j = shift;
    my $clusterType = shift;

    my %result ;
    #A modifier, mais pour le moment je ne sais pas interpreter des chemins
    if ($$j{jobName} =~ m/.*\/.*/m){
        $$j{jobName} = "";
    }
    if($$j{jobName} ne ""){
        if ($clusterType eq "OAR2"){
            $result{"OAR.$$j{jobBatchId}.stdout"} = "$$j{jobName}.$$j{jobId}.stdout";
            $result{"OAR.$$j{jobBatchId}.stderr"} = "$$j{jobName}.$$j{jobId}.stderr";
        }else{
            $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout"} = "$$j{jobName}.$$j{jobId}.stdout";
            $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"} = "$$j{jobName}.$$j{jobId}.stderr";
        }
        $result{"$$j{jobName}"} = "";
    }else{
        if ($clusterType eq "OAR2"){
            $result{"OAR.$$j{jobBatchId}.stdout"} = "";
            $result{"OAR.$$j{jobBatchId}.stderr"} = "";
        }else{
            $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stdout"} = "";
            $result{"OAR.cigri.tmp.$$j{jobId}.$$j{jobBatchId}.stderr"} = "";
        }
    }

    return %result;
}

