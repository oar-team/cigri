<?php

	require_once("../dbfunctions.inc");
	require_once("../outputfunctions.inc");

	$link = dbconnect();

	// We check the 'option' value
	// default value if not set: "running"
	if (!isset($_GET['option'])) {
		$option = "jobs";
	}
	else {
		$option = $_GET['option'];
	}

	// Check pages params
	if (isset($_GET['step'])) {
		$step = $_GET['step'];
	}
	else {
		$step = 20;
	}
	if (isset($_GET['page'])) {
		$page = $_GET['page'];
	}
	else {
		$page = 1;
	}
	
if ($_SESSION['auth']) {
switch ($option) {
// {{{ All jobs
// {{{ Propertiies
	case "jobs":
		// if no order is specified, set to default
		if (!isset($_GET['orderby'])) {
			$_GET['orderby'] = "MJobsId";
			$_GET['sort'] = "DESC";
		}
		$selectnames[] = "MJobsId";
		$selectnames[] = "MJobsName";
		$selectnames[] = "MJobsTSub";
		$selectnames[] = "MJobsState";
		cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
		$query = <<<EOF
SELECT
	count(MJobsId)
FROM
	multipleJobs
WHERE
	MJobsUser = '$login'
EOF;
		list($res,$nb) = sqlquery($query,$link);
		$nbitems = $res[0][0];

		// Do all the stuff to set page parameters before display
		cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

		$query = <<<EOF
SELECT
	MJobsId, MJobsName, MJobsTSub, MJobsState
FROM
	multipleJobs
WHERE
	MJobsUser = '$login'
EOF;
		$query .= $orderby;
		$query .= <<<EOF
 LIMIT
 	$minindex,$step
EOF;
		unset($res);
		list($res,$nb) = sqlquery($query,$link);
	
		// display parameters
		$smarty->assign('contenttemplate',"account/jobs/jobs.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]) ;
			$res[$i][2] = htmlentities($res[$i][2]) ;
			$res[$i][3] = htmlentities($res[$i][3]) ;
		}
		$smarty->assign('nb',$nb);
		$smarty->assign('eventarray',$res);

		break;
// }}}
// {{{ job details
	case "details":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$jobid = $_GET['id'];
				get_forecast($link,$jobid);
				$query = <<<EOF
SELECT
	*
FROM
	jobs
WHERE
	jobMJobsId = '{$jobid}'
	AND (jobState = 'Running' OR jobState = 'toLaunch' OR jobState = 'RemoteWaiting')
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbrunning = $nb;
				$smarty->assign("nbrunning",$nbrunning);
				unset($res);
				$query = <<<EOF
SELECT
	*
FROM
	jobs
WHERE
	jobMJobsId = '{$jobid}'
	AND jobState = 'Terminated'
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbexecuted = $nb;
				$smarty->assign("nbexecuted",$nbexecuted);
				unset($res);
				$query = <<<EOF
SELECT
	*
FROM
	parameters
WHERE
	parametersMJobsId = '{$jobid}'
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbwaiting = $nb;
				$smarty->assign("nbwaiting",$nbwaiting);
				unset($res);
				
				$query = <<<EOF
SELECT
	MJobsState
FROM
	multipleJobs
WHERE
	MJobsId = $jobid
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				if ($res[0][0] == 'IN_TREATMENT') {
					$smarty->assign('MJstate','Running');
				} else {
					$smarty->assign('MJstate','Terminated');
				}
				
				$selectnames[] = "propertiesClusterName";
				$selectnames[] = "propertiesJobCmd";
				$selectnames[] = "propertiesJobWallTime";
				$selectnames[] = "propertiesJobWeight";
				$selectnames[] = "propertiesExecDirectory";
				$selectnames[] = "propertiesClusterPriority";
				cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");

				$query = <<<EOF
SELECT
	count(propertiesClusterName)
FROM
	properties
WHERE
	propertiesMJobsId = $jobid
EOF;
				list($res,$nb) = sqlquery($query,$link);
				$nbitems = $res[0][0];

				// Do all the stuff to set page parameters before display
				cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

				$query = <<<EOF
SELECT
	propertiesClusterName, propertiesJobCmd, propertiesJobWallTime, propertiesJobWeight, propertiesExecDirectory, propertiesClusterPriority
FROM
	properties
WHERE
	propertiesMJobsId = $jobid
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;

				unset($res);
				list($res,$nb) = sqlquery($query,$link);

				// display parameters
				cigri_register_menu_item($menu,$currentarray,"jdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=details&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/jobs/jobdetails.tpl");
				for($i = 0; $i < $nb;$i++) {
					$res[$i][0] = htmlentities($res[$i][0]) ;
					$res[$i][1] = htmlentities($res[$i][1]) ;
					$res[$i][2] = htmlentities($res[$i][2]) ;
					$res[$i][3] = htmlentities($res[$i][3]) ;
					$res[$i][4] = htmlentities($res[$i][4]) ;
					$res[$i][5] = htmlentities($res[$i][5]) ;
				}
				$smarty->assign('jobid',$jobid);
				$smarty->assign('eventarray',$res);
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('contenttemplate','error.tpl');
		}
		break;

// }}}

// {{{ Executed parameters
	case "executedparams":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				// if no order is specified, set to default
				if (!isset($_GET['orderby'])) {
					$_GET['orderby'] = "jobId";
					$_GET['sort'] = "DESC";
				}
				$jobid = $_GET['id'];
				get_forecast($link,$jobid);
				$query = <<<EOF
SELECT
	*
FROM
	jobs
WHERE
	jobMJobsId = '{$jobid}'
	AND (jobState = 'Running' OR jobState = 'toLaunch' OR jobState = 'RemoteWaiting')
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbrunning = $nb;
				$smarty->assign("nbrunning",$nbrunning);
				unset($res);
				$query = <<<EOF
SELECT
	*
FROM
	parameters
WHERE
	parametersMJobsId = '{$jobid}'
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbwaiting = $nb;
				$smarty->assign("nbwaiting",$nbwaiting);
				unset($res);
				$query = <<<EOF
SELECT
	MJobsState
FROM
	multipleJobs
WHERE
	MJobsId = $jobid
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				if ($res[0][0] == 'IN_TREATMENT') {
					$smarty->assign('MJstate','Running');
				} else {
					$smarty->assign('MJstate','Terminated');
				}

				$selectnames[] = "jobId";
				$selectnames[] = "jobName";
				$selectnames[] = "jobParam";
				$selectnames[] = "jobCollectedJobId";
				$selectnames[] = "jobTStart";
				$selectnames[] = "jobTStop";
				$selectnames[] = "duration";
				$selectnames[] = "jobClusterName";
				$selectnames[] = "jobNodeName";
				cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");

				$query = <<<EOF
SELECT
	count(jobId)
FROM
	jobs
WHERE
	jobMJobsId = $jobid
	AND jobState = 'Terminated'
EOF;
				list($res,$nb) = sqlquery($query,$link);
				$nbitems = $res[0][0];

				// Do all the stuff to set page parameters before display
				cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

				$query = <<<EOF
SELECT
	jobId, jobName, jobParam, jobCollectedJobId, jobTStart,jobTStop,  SEC_TO_TIME(UNIX_TIMESTAMP(jobTStop) -  UNIX_TIMESTAMP(jobTStart)) AS duration, jobClusterName, jobNodeName
FROM
	jobs
WHERE
	jobMJobsId = $jobid
	AND jobState = 'Terminated'
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;

				unset($res);
				list($res,$nb) = sqlquery($query,$link);

				// display parameters
				cigri_register_menu_item($menu,$currentarray,"jdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=details&id=".$jobid,3,true);
				cigri_register_menu_item($menu,$currentarray,"jexecutedp","Executed jobs","account.php?submenu=jobs&option=executedparams&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/jobs/jobexecutedparams.tpl");
				for($i = 0; $i < $nb;$i++) {
					$res[$i][1] = htmlentities($res[$i][1]) ;
					$res[$i][2] = htmlentities($res[$i][2]) ;
					$res[$i][4] = htmlentities($res[$i][4]) ;
					$res[$i][5] = htmlentities($res[$i][5]) ;
					$res[$i][6] = htmlentities($res[$i][6]) ;
					$res[$i][7] = htmlentities($res[$i][7]) ;
					$res[$i][8] = htmlentities($res[$i][8]) ;
				}
				$smarty->assign('jobid',$jobid);
				$smarty->assign('eventarray',$res);
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('contenttemplate','error.tpl');
		}
		break;
// }}}

// {{{ One subjob details
	case "jobdetail":
		if (isset($_GET['id']) && isset($_GET['jid'])) {
			if (is_numeric($_GET['id']) && is_numeric($_GET['jid'])) {
				$jobid = $_GET['id'];
				$subjobid = $_GET['jid'];
				$query = <<<EOF
SELECT
	jobState, jobParam,jobName,jobClusterName,jobNodeName,jobBatchId,jobRetCode,jobCollectedJobId,jobTSub,jobTStart,jobTStop,SEC_TO_TIME(UNIX_TIMESTAMP(jobTStop) -  UNIX_TIMESTAMP(jobTStart)) AS duration
FROM
	jobs
WHERE
	jobId = $subjobid
EOF;

				list($res,$nb) = sqlquery($query,$link);
				if ($nb != 0){
					$res[0][0] = htmlentities($res[0][0]);
					$res[0][1] = htmlentities($res[0][1]);
					$res[0][2] = htmlentities($res[0][2]);
					$res[0][3] = htmlentities($res[0][3]);
					$res[0][4] = htmlentities($res[0][4]);
					$res[0][5] = htmlentities($res[0][5]);
					$res[0][6] = htmlentities($res[0][6]);
					$res[0][7] = htmlentities($res[0][7]);
					$res[0][8] = htmlentities($res[0][8]);
					$res[0][9] = htmlentities($res[0][9]);
					$res[0][10] = htmlentities($res[0][10]);
					$res[0][11] = htmlentities($res[0][11]);
				}
				cigri_register_menu_item($menu,$currentarray,"jdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=details&id=".$jobid,3,true);
				cigri_register_menu_item($menu,$currentarray,"jinter",$_GET['optiontext'],"account.php?submenu=jobs&option={$_GET['optionparam']}&id=".$jobid,4,true);
				cigri_register_menu_item($menu,$currentarray,"subjdetails","Job #".$subjobid." details","account.php?submenu=jobs&option=jobdetail&id=".$jobid."&jid=".$subjobid."&optiontext=".rawurlencode($_GET['optiontext'])."&optionparam=".rawurlencode($_GET['optionparam']),5,true);
				$smarty->assign('contenttemplate',"account/jobs/jobjobdetails.tpl");
				$smarty->assign('jobid',$jobid);
				$smarty->assign('subjobid',$subjobid);
				$smarty->assign('nb',$nb);
				$smarty->assign('eventarray',$res);
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('contenttemplate','error.tpl');
		}
		break;
// }}}

// }}}

// {{{ Running jobs

// {{{ Running parameters
	case "runningparams":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				// if no order is specified, set to default
				if (!isset($_GET['orderby'])) {
					$_GET['orderby'] = "jobId";
					$_GET['sort'] = "DESC";
				}
				$jobid = $_GET['id'];
				get_forecast($link,$jobid);
				$query = <<<EOF
SELECT
	*
FROM
	jobs
WHERE
	jobMJobsId = '{$jobid}'
	AND jobState = 'Terminated'
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbexecuted = $nb;
				$smarty->assign("nbexecuted",$nbexecuted);
				unset($res);
				$query = <<<EOF
SELECT
	*
FROM
	parameters
WHERE
	parametersMJobsId = '{$jobid}'
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbwaiting = $nb;
				$smarty->assign("nbwaiting",$nbwaiting);
				unset($res);
				
				$selectnames[] = "jobId";
				$selectnames[] = "jobName";
				$selectnames[] = "jobTSub";
				$selectnames[] = "jobClusterName";
				cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");

				$query = <<<EOF
SELECT
	count(jobId)
FROM
	jobs
WHERE
	jobMJobsId = $jobid
	AND (jobState = 'Running' OR jobState = 'toLaunch' OR jobState = 'RemoteWaiting')
EOF;
				list($res,$nb) = sqlquery($query,$link);
				$nbitems = $res[0][0];

				// Do all the stuff to set page parameters before display
				cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

				$query = <<<EOF
SELECT
	jobId, jobName, jobTSub, jobClusterName
FROM
	jobs
WHERE
	jobMJobsId = $jobid
	AND (jobState = 'Running' OR jobState = 'toLaunch' or jobState = 'RemoteWaiting')
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;

				unset($res);
				list($res,$nb) = sqlquery($query,$link);

				// display parameters
				cigri_register_menu_item($menu,$currentarray,"jdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=details&id=".$jobid,3,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningrunningp","Running jobs","account.php?submenu=jobs&option=runningparams&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/jobs/runningrunningparams.tpl");
				for($i = 0; $i < $nb;$i++) {
					$res[$i][1] = htmlentities($res[$i][1]) ;
					$res[$i][2] = htmlentities($res[$i][2]) ;
					$res[$i][3] = htmlentities($res[$i][3]) ;
				}
				$smarty->assign('jobid',$jobid);
				$smarty->assign('eventarray',$res);
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('contenttemplate','error.tpl');
		}
		break;
// }}}

// {{{ Waiting parameters
	case "waitingparams":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				// if no order is specified, set to default
				if (!isset($_GET['orderby'])) {
					$_GET['orderby'] = "parametersPriority";
					$_GET['sort'] = "DESC";
				}
				$jobid = $_GET['id'];
				get_forecast($link,$jobid);
				$query = <<<EOF
SELECT
	*
FROM
	jobs
WHERE
	jobMJobsId = '{$jobid}'
	AND (jobState = 'Running' OR jobState = 'toLaunch' OR jobState = 'RemoteWaiting')
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbrunning = $nb;
				$smarty->assign("nbrunning",$nbrunning);
				unset($res);
				$query = <<<EOF
SELECT
	*
FROM
	jobs
WHERE
	jobMJobsId = '{$jobid}'
	AND jobState = 'Terminated'
LIMIT 1
EOF;
                                list($res,$nb) = sqlquery($query,$link);
				$nbexecuted = $nb;
				$smarty->assign("nbexecuted",$nbexecuted);
				unset($res);
				$selectnames[] = "parametersParam";
				$selectnames[] = "parametersName";
				$selectnames[] = "parametersPriority";
				cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");

				$query = <<<EOF
SELECT
	count(*)
FROM
	parameters
WHERE
	parametersMJobsId = $jobid
EOF;
				list($res,$nb) = sqlquery($query,$link);
				$nbitems = $res[0][0];

				// Do all the stuff to set page parameters before display
				cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

				$query = <<<EOF
SELECT
	parametersParam, parametersName, parametersPriority
FROM
	parameters
WHERE
	parametersMJobsId = $jobid
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;

				unset($res);
				list($res,$nb) = sqlquery($query,$link);

				// display parameters
				cigri_register_menu_item($menu,$currentarray,"jdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=details&id=".$jobid,3,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningwaitingp","Waiting parameters","account.php?submenu=jobs&option=waitingparams&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/jobs/runningwaitingparams.tpl");
				for($i = 0; $i < $nb;$i++) {
					$res[$i][0] = htmlentities($res[$i][0]) ;
					$res[$i][1] = htmlentities($res[$i][1]) ;
					$res[$i][2] = htmlentities($res[$i][2]) ;
				}
				$smarty->assign('jobid',$jobid);
				$smarty->assign('eventarray',$res);
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('contenttemplate','error.tpl');
		}
		break;
// }}}

// {{{ Waiting parameters actions
	case "paramsaction":
		$jobid = $_GET['id'];
		$smarty->assign('jobid',$jobid);
		if (isset($_GET['cancel'])) {
			// redirect if cancel button clicked
			$newlocation = 'Location: account.php?submenu=jobs&option=waitingparams&id='.$jobid;
			header($newlocation);
			exit;
		}
		
		cigri_register_menu_item($menu,$currentarray,"jdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=details&id=".$jobid,3,true);
		cigri_register_menu_item($menu,$currentarray,"jrunningwaitingp","Waiting parameters","account.php?submenu=jobs&option=waitingparams&id=".$jobid,4,true);
		// Checkboxes => array
		unset($waitingp);
		if (isset($_GET['paramcb']) && is_array($_GET['paramcb'])) {
			$waitingp = $_GET['paramcb'];
			// quote string for sql
			foreach ($waitingp as $key => $value) {
				$waitingp[$key] = "'".$value."'";
			}
		}
		
		if (isset($waitingp)) {
			if (isset($_GET['remove'])) {
				cigri_register_menu_item($menu,$currentarray,"jrunningaction","Remove parameters","account.php?submenu=jobs&option=paramsaction&remove=ok&id=".$jobid,5,true);
				$smarty->assign('action','Parameters deletion');
				$smarty->assign('shortaction','remove');
			}
			else if (isset($_GET['priority'])) {
				// change priorities)
				cigri_register_menu_item($menu,$currentarray,"jrunningaction","Change priority","account.php?submenu=jobs&option=paramsaction&priority=ok&id=".$jobid,5,true);
				$smarty->assign('action','Priority change');
				$smarty->assign('shortaction','priority');
				// check for new priority (must be a positive integer)
				$smarty->assign('wrongpriority',false);
				if (isset($_GET['GO'])) {
					$newpriorityok = false;
					if (isset($_GET['newpriority'])) {
						$newpriority = $_GET['newpriority'];
						if (is_numeric($newpriority) && $newpriority >= 0) {
							$newpriorityok = true;
						}
					}
					if (!$newpriorityok) {
						unset($_GET['GO']);
						$smarty->assign('wrongpriority',true);
					}
					else {
						$smarty->assign('newpriority',$newpriority);
					}
				}
			}
			
			if (isset($_GET['remove']) || isset($_GET['priority'])) {
				if (isset($_GET['GO'])) {
					// extended SELECT - WHERE clause to prevent damage from "funny" users
					$paramids = implode(",",$waitingp);
					$query = <<<EOF
SELECT
	p.parametersParam, p.parametersName, p.parametersPriority
FROM
	parameters p, multipleJobs mj
WHERE
	p.parametersName IN ($paramids)
	AND p.parametersMJobsId = '{$jobid}'
	AND p.parametersMJobsId = mj.MJobsId
	AND mj.MJobsUser = '$login'
EOF;
					list($res,$nb) = sqlquery($query,$link);
					unset($waitingp);
					for ($i = 0;$i < $nb;$i++) {
						// quote string for sql
						$waitingp[] = "'".$res[$i][1]."'";
					}
					$paramids = implode(",",$waitingp);

					if (isset($_GET['remove'])) {
						$query = <<<EOF
DELETE FROM
        parameters
WHERE
        parametersName IN ($paramids)
	AND parametersMJobsId = $jobid
EOF;
						mysql_query($query,$link);
						$smarty->assign('updates',mysql_affected_rows($link));
					} else {
						$query = <<<EOF
UPDATE
	parameters
SET
	parametersPriority = $newpriority
WHERE
	parametersName IN ($paramids)
	AND parametersMJobsId = $jobid
EOF;
						mysql_query($query,$link);
						$smarty->assign('updates',mysql_affected_rows($link));
					}
					for ($i = 0; $i < $nb;$i++) {
						$res[$i][0] = htmlentities($res[$i][0]) ;
						$res[$i][1] = htmlentities($res[$i][1]) ;
					}
					$smarty->assign('nbitems',$nb);
					$smarty->assign('eventarray',$res);
					$smarty->assign('contenttemplate','account/jobs/paramsactiongo.tpl');
				}
				else {
					// Confirm ???
					// extended WHERE clause to prevent damage from "funny" users
					$paramids = implode(",",$waitingp);
					$query = <<<EOF
SELECT
	p.parametersParam, p.parametersName, p.parametersPriority
FROM
	parameters p, multipleJobs mj
WHERE
	p.parametersName IN ($paramids)
	AND p.parametersMJobsId = '{$jobid}'
	AND p.parametersMJobsId = mj.MJobsId
	AND mj.MJobsUser = '$login'
EOF;
					list($res,$nb) = sqlquery($query,$link);
					for($i = 0; $i < $nb;$i++) {
						$res[$i][0] = htmlentities($res[$i][0]) ;
						$res[$i][1] = htmlentities($res[$i][1]) ;
					}
					$smarty->assign('nbitems',$nb);
					$smarty->assign('eventarray',$res);
					$smarty->assign('contenttemplate','account/jobs/paramsactionconfirm.tpl');
				}
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('nbitems',0);
			$smarty->assign('contenttemplate','account/jobs/paramsactionconfirm.tpl');
		}
	break;
// }}}

// }}}

        default:
		// Unknown option -> error
		$smarty->assign('contenttemplate','error.tpl');
		break;
								
}
}

function get_forecast($link,$jobid) {
	global $smarty;

  # Forecast
        $query = <<<EOF
SELECT
        *
FROM
        forecasts
WHERE
        MjobsId = '{$jobid}'
LIMIT 1
EOF;
	list($res,$nb) = sqlquery($query,$link);
	if ($res[0][1]) { $smarty->assign("ForecastAvg",$res[0][1]);}
	else { $smarty->assign("ForecastAvg","--");}
	if ($res[0][2]) { $smarty->assign("ForecastStddev",$res[0][2]);}
	else { $smarty->assign("ForecastStddev","--");}
	if ($res[0][3]) { $smarty->assign("ForecastThroughput",round($res[0][3]*3600,2));}
	else { $smarty->assign("ForecastThroughput","--");}
	if ($res[0][4]) { 
	   $smarty->assign("ForecastEnd",date("Y-m-d H:i:s",$res[0][4]));
	   if (($res[0][4]-time(localtime)) > 0) { 
	     $duration=$res[0][4]-time(localtime);
	     $days=floor($duration/86400);
	     $modulo=$duration-($days*86400);
	     $hours=floor($modulo/3600);
	     $modulo=$modulo-($hours*3600);
	     $min=floor($modulo/60);
	     $sec=$modulo-($min*60);
	     $smarty->assign("ForecastDuration","in ". $days ."d,". $hours ."h,". $min ."m,". $sec ."s");
	   }else {
	     $smarty->assign("ForecastDuration","");
	   }
	}
	else { 
	   $smarty->assign("ForecastEnd","--");
	   $smarty->assign("ForecastDuration","--");
	}

   # Numbers
                    # Calculate the resubmission number
                    $mjobid=$jobid;
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
                    if ($n) { $smarty->assign("n_wait",htmlentities($r[0][0]));}
                    # Count the running jobs
                    $query="SELECT count(*) FROM jobs 
                            WHERE jobMjobsId='$mjobid'
                            AND (jobState='Running' or jobState='toLaunch')
                            AND jobClusterName NOT IN
                              (select clusterBlackListClusterName from clusterBlackList,events
                               WHERE clusterBlackListMJobsID='$mjobid'
                                     AND clusterBlackListEventId=events.eventId 
                                     AND eventState=\"ToFIX\")";
                    list($r,$n)=sqlquery($query,$link);
                    if ($n) { $smarty->assign("n_run",htmlentities($r[0][0]));}
                    # Count the remote waiting
                    $query="SELECT count(*) FROM jobs
                            WHERE jobMjobsId='$mjobid'
                            AND ( jobState = 'RemoteWaiting' )";
                    list($r,$n)=sqlquery($query,$link);
                    if ($n) { $smarty->assign("n_rwait",htmlentities($r[0][0]));}
                    # Count the terminated jobs
                    $query="SELECT count(*) FROM jobs
                            WHERE jobMjobsId='$mjobid'
                            AND jobState='Terminated'";
                    list($r,$n)=sqlquery($query,$link);
                    if ($n) { $smarty->assign("n_term",htmlentities($r[0][0]));}
                    # Count the jobs in error state
                    $query="SELECT count(*) FROM events
                            WHERE eventState = 'ToFIX'
                            AND eventClass ='JOB'
                            AND eventMJobsId = '$mjobid'";
                    list($r,$n)=sqlquery($query,$link);
                    if ($n) { $smarty->assign("n_err",htmlentities($r[0][0]));}
                    # Calculate the resubmission percentage
		    if (($r[0][0]+$resubmited) > 0) { 
                      $smarty->assign("resubmissions",htmlentities(floor($resubmited*100/($r[0][0]+$resubmited))));
		    }

}

	mysql_close($link);
?>
