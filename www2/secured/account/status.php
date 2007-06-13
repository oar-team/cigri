<?php
	require_once("../dbfunctions.inc");
	require_once("../outputfunctions.inc");

	$link = dbconnect();
	// We check the 'option' value
	// default value if not set: "current"
	if (!isset($_GET['option'])) {
		$option = "current";
	}
	else {
		$option = $_GET['option'];
	}

function is_blacklisted($cluster,$link) {
  $query = "SELECT eventType FROM events WHERE eventState='ToFIX'
                                                AND eventClusterName='$cluster'
                                                AND eventMJobsId is null";
  list($res,$nb) = sqlquery($query,$link);
  return $nb;
}


if ($_SESSION['auth']) {
  switch ($option) {
	case 'current':
	    # Getting the latest timestamp
            $query = <<<EOF
		SELECT
          	  timestamp
		FROM
        	  gridstatus
		ORDER BY 
                  timestamp desc
		LIMIT 1
EOF;
            list($res,$nb) = sqlquery($query,$link);
	    # Getting the clusters status at the latest timestamp
            if ($res[0][0]) { 
	        $smarty->assign("Timestamp",$res[0][0]);
		$query = "SELECT * from gridstatus where timestamp=";
		$query .= $res[0][0];
		$query .=" order by maxResources desc";
		list($res,$nb) = sqlquery($query,$link);
		$TotalMax=0;
                $TotalFree=0;
		$TotalUsed=0;
		$TotalLocal=0;
		$TotalBlacklisted=0;
                for($i = 0; $i < $nb;$i++) {
		        $TotalLocal+=($res[$i][2] - $res[$i][3] - $res[$i][4]);
                        $res[$i][5] = htmlentities($res[$i][2] - $res[$i][3] - $res[$i][4]) ;
                        $res[$i][1] = htmlentities($res[$i][1]) ;
			$TotalMax+=$res[$i][2];
                        $res[$i][2] = htmlentities($res[$i][2]) ;
			$TotalFree+=$res[$i][3];
                        $res[$i][3] = htmlentities($res[$i][3]) ;
			$TotalUsed+=$res[$i][4];
                        $res[$i][4] = htmlentities($res[$i][4]) ;
			if (is_blacklisted($res[$i][1],$link) != 0) {
			  $res[$i][6]="<b>YES</b>";
			  $TotalBlacklisted+=1;
			}
                        else {$res[$i][6]="no";}
                }

                $smarty->assign('nb',$nb);
                $smarty->assign('array',$res);
		$smarty->assign('TotalMax',$TotalMax);
		$smarty->assign('TotalFree',$TotalFree);
		$smarty->assign('TotalUsed',$TotalUsed);
		$smarty->assign('TotalLocal',$TotalLocal);
		$smarty->assign('TotalBlacklisted',$TotalBlacklisted);
		$smarty->assign("Date",date("Y-m-d H:i:s",$res[0][0]));
	    }
            else { $smarty->assign("Timestamp",$nb); }

	    # Getting the running or waiting multijobs
            $query = "SELECT multipleJobs.MjobsId,MJobsState,MJobsUser,average,stddev,throughput 
	              FROM multipleJobs,forecasts
	              WHERE not MJobsState='TERMINATED'
		      AND multipleJobs.MjobsId=forecasts.MjobsId
		      ";
            list($res,$nb) = sqlquery($query,$link);
	    if ($nb != 0)  {
	        $smarty->assign('nbjobs',$nb);
                for($i = 0; $i < $nb;$i++) {
		    $res[$i][0]=htmlentities($res[$i][0]) ;
		    $res[$i][1]=htmlentities($res[$i][1]) ;
		    $res[$i][2]=htmlentities($res[$i][2]) ;
		    $res[$i][3]=htmlentities(floor($res[$i][3])) ;
		    $res[$i][4]=htmlentities($res[$i][4]) ;
		    $res[$i][5]=htmlentities(floor($res[$i][5]*3600)) ;
		    # Calculate the resubmission number
		    $mjobid=$res[$i][0];
		    $query="SELECT count(*) FROM events,resubmissionLog 
		            WHERE eventMjobsId='$mjobid'
		            AND resubmissionLogEventId=eventId";
	            list($r,$n)=sqlquery($query,$link);
		    if ($n) { $resubmited=$r[0][0];}
		    else {$resubmited=0;}
		    # Count the waiting jobs
		    $query="SELECT count(*) FROM parameters 
		            WHERE parametersMjobsId='$mjobid' 
		            ";
	            list($r,$n)=sqlquery($query,$link);
		    if ($n) { $res[$i][7]=htmlentities($r[0][0]);}
		    # Count the running jobs
		    $query="SELECT count(*) FROM jobs 
		            WHERE jobMjobsId='$mjobid' 
		            AND jobState='Running'";
	            list($r,$n)=sqlquery($query,$link);
		    if ($n) { $res[$i][9]=htmlentities($r[0][0]);}
		    # Count the terminated jobs
		    $query="SELECT count(*) FROM jobs 
		            WHERE jobMjobsId='$mjobid' 
		            AND jobState='Terminated'";
	            list($r,$n)=sqlquery($query,$link);
		    if ($n) { $res[$i][8]=htmlentities($r[0][0]);}
		    # Calculate the resubmission percentage
		    $res[$i][6]=htmlentities(floor($resubmited*100/($r[0][0]+$resubmited)));
	        }
		$smarty->assign('jobarray',$res);
	    }
            else {
	        $smarty->assign('nbjobs',0);
            }

	    $smarty->assign('contenttemplate','status/current.tpl');
	    break;

        default:
	    // Unknown option -> error
	    $smarty->assign('contenttemplate','error.tpl');
	    break;
								
  }
}

	mysql_close($link);
       
?>