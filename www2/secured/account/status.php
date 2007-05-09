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
