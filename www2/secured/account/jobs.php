<?php

	require_once("../dbfunctions.inc");
	require_once("../outputfunctions.inc");

	$link = dbconnect();

	// We check the 'option' value
	// default value if not set: "running"
	if (!isset($_GET['option'])) {
		$option = "running";
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
// {{{ Running jobs

// {{{ running jobs
	case "running":
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
	AND MJobsState ='IN_TREATMENT'
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
	AND MJobsState = 'IN_TREATMENT'
EOF;
		$query .= $orderby;
		$query .= <<<EOF
 LIMIT
 	$minindex,$step
EOF;
		unset($res);
		list($res,$nb) = sqlquery($query,$link);
	
		// display parameters
		cigri_register_menu_item($menu,$currentarray,"jrunning","Running MultiJobs","account.php?submenu=jobs&option=running",3,true);
		$smarty->assign('contenttemplate',"account/jobs/running.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]) ;
			$res[$i][2] = htmlentities($res[$i][2]) ;
			$res[$i][3] = htmlentities($res[$i][3]) ;
		}
		$smarty->assign('nb',$nb);
		$smarty->assign('eventarray',$res);

		break;

// }}}

// {{{ Running jobs details
	case "runningdetails":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$jobid = $_GET['id'];
				$selectnames[] = "propertiesClusterName";
				$selectnames[] = "propertiesJobCmd";
				$selectnames[] = "propertiesJobWallTime";
				$selectnames[] = "propertiesJobWeight";
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
	propertiesClusterName, propertiesJobCmd, propertiesJobWallTime, propertiesJobWeight
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
				cigri_register_menu_item($menu,$currentarray,"jrunning","Running MultiJobs","account.php?submenu=jobs&option=running",3,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=runningdetails&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/jobs/runningdetails.tpl");
				for($i = 0; $i < $nb;$i++) {
					$res[$i][0] = htmlentities($res[$i][0]) ;
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

// {{{ Executed parameters
	case "executedparams":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$jobid = $_GET['id'];
				$selectnames[] = "jobId";
				$selectnames[] = "jobParam";
				$selectnames[] = "jobName";
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
	jobId, jobParam, jobName, jobCollectedJobId, jobTStart,jobTStop,  SEC_TO_TIME(UNIX_TIMESTAMP(jobTStop) -  UNIX_TIMESTAMP(jobTStart)) AS duration, jobClusterName, jobNodeName
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
				cigri_register_menu_item($menu,$currentarray,"jrunning","Running MultiJobs","account.php?submenu=jobs&option=running",3,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=runningdetails&id=".$jobid,4,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningexecutedp","Executed parameters","account.php?submenu=jobs&option=executedparams&id=".$jobid,5,true);
				$smarty->assign('contenttemplate',"account/jobs/runningexecutedparams.tpl");
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

// {{{ Running parameters
	case "runningparams":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$jobid = $_GET['id'];
				$selectnames[] = "jobId";
				$selectnames[] = "jobParam";
				$selectnames[] = "jobTStart";
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
	jobId, jobParam, jobTStart, jobClusterName
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
				cigri_register_menu_item($menu,$currentarray,"jrunning","Running MultiJobs","account.php?submenu=jobs&option=running",3,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=runningdetails&id=".$jobid,4,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningrunningp","Running parameters","account.php?submenu=jobs&option=runningparams&id=".$jobid,5,true);
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
				$jobid = $_GET['id'];
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
				cigri_register_menu_item($menu,$currentarray,"jrunning","Running MultiJobs","account.php?submenu=jobs&option=running",3,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=runningdetails&id=".$jobid,4,true);
				cigri_register_menu_item($menu,$currentarray,"jrunningwaitingp","Waiting parameters","account.php?submenu=jobs&option=waitingparams&id=".$jobid,5,true);
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
		
		cigri_register_menu_item($menu,$currentarray,"jrunning","Running MultiJobs","account.php?submenu=jobs&option=running",3,true);
		cigri_register_menu_item($menu,$currentarray,"jrunningdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=runningdetails&id=".$jobid,4,true);
		cigri_register_menu_item($menu,$currentarray,"jrunningwaitingp","Waiting parameters","account.php?submenu=jobs&option=waitingparams&id=".$jobid,5,true);
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
				cigri_register_menu_item($menu,$currentarray,"jrunningaction","Remove parameters","account.php?submenu=errors&option=paramsaction&remove=ok&id=".$jobid,6,true);
				$smarty->assign('action','Parameters deletion');
				$smarty->assign('shortaction','remove');
			}
			else if (isset($_GET['priority'])) {
				// change priorities)
				cigri_register_menu_item($menu,$currentarray,"jrunningaction","Change priority","account.php?submenu=errors&option=paramsaction&priority=ok&id=".$jobid,6,true);
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

// {{{ CLUSTER

// {{{ Clusters
	case "cluster":
		$selectnames[] = "clusterName";
		$selectnames[] = "clusterAdmin";
		$selectnames[] = "clusterBatch";
		cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
		$query = <<<EOF
SELECT
	clusterName, clusterAdmin, clusterBatch
FROM
	clusters
EOF;
                $query .= $orderby;

		list($res,$nb) = sqlquery($query,$link);

		// display parameters
		cigri_register_menu_item($menu,$currentarray,"cluster","Clusters","account.php?submenu=jobs&option=cluster",3,true);
		$smarty->assign('contenttemplate',"account/jobs/cluster.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]);
			$res[$i][2] = htmlentities($res[$i][2]);
			// Store clusterName in HTML format in a new column
			$res[$i][3] = htmlentities($res[$i][0]);
			// and convert it to query string format
			$res[$i][0] = rawurlencode($res[$i][0]);
		}
		$smarty->assign('nb',$nb);
		$smarty->assign('eventarray',$res);
		break;
						    
// }}}

// {{{ Cluster details
	case "clusterdetails":
		if (isset($_GET['name'])) {
			$clustername = $_GET['name'];
			$name = addslashes($clustername);
			$selectnames[] = "j.jobMJobsId";
			$selectnames[] = "mj.MJobsName";
			$selectnames[] = "mj.MJobsState";
			cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
			$query = <<<EOF
SELECT
	COUNT(DISTINCT(j.jobMJobsId))
FROM
	jobs j, multipleJobs mj
WHERE
	j.jobClusterName= '$name'
	AND mj.MJobsId = j.jobMJobsId
EOF;

			list($res,$nb) = sqlquery($query,$link);
			$nbitems = $res[0][0];

			// Do all the stuff to set page parameters before display
			cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

			$query = <<<EOF
SELECT
	DISTINCT (j.jobMJobsId) , mj.MJobsName, mj.MJobsState
FROM
	jobs j, multipleJobs mj
WHERE
	j.jobClusterName= '$name'
	AND mj.MJobsId = j.jobMJobsId
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step;
EOF;
			unset($res);
			list($res,$nb) = sqlquery($query,$link);
	
			// display parameters
			cigri_register_menu_item($menu,$currentarray,"cluster","Clusters","account.php?submenu=jobs&option=cluster",3,true);
			cigri_register_menu_item($menu,$currentarray,"cdetails",$clustername,"account.php?submenu=jobs&option=clusterdetails&name=".rawurlencode($clustername),4,true);
			$smarty->assign('contenttemplate',"account/jobs/clusterdetails.tpl");
			for($i = 0; $i < $nb;$i++) {
				$res[$i][1] = htmlentities($res[$i][1]) ;
				$res[$i][2] = htmlentities($res[$i][2]) ;
			}
			$smarty->assign('name',$clustername);
			$smarty->assign('queryname',rawurlencode($clustername));
			$smarty->assign('eventarray',$res);
		}
		else {
			$smarty->assign('contenttemplate',"error.tpl");
		}

		break;
// }}}

// {{{ cluster params
	case "clusterdistribution":
		if (isset($_GET['name']) && isset($_GET['multijobid'])) {
			if (is_numeric($_GET['multijobid'])) {
				$clustername = $_GET['name'];
				$name = addslashes($clustername);
				$multijobid = $_GET['multijobid'];
				$selectnames[] = "jobId";
				$selectnames[] = "jobName";
				$selectnames[] = "jobTStop";
				$selectnames[] = "jobState";
				$selectnames[] = "jobTStart";
				$selectnames[] = "jobParam";
				$selectnames[] = "jobTSub";
				cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
				$query = <<<EOF
SELECT
	count(jobId)
FROM
	jobs
WHERE
	jobClusterName= '$name'
	AND jobMJobsId = $multijobid
EOF;
			
				list($res,$nb) = sqlquery($query,$link);
				$nbitems = $res[0][0];

				// Do all the stuff to set page parameters before display
				cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

				$query = <<<EOF
SELECT
	jobId, jobName, jobTStop, jobState, jobTStart,  jobParam, jobTSub
FROM
	jobs
WHERE
	jobClusterName= '$name'
	AND jobMJobsId = $multijobid
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;
				unset($res);
				list($res,$nb) = sqlquery($query,$link);
	
				// display parameters
				cigri_register_menu_item($menu,$currentarray,"cluster","Clusters","account.php?submenu=jobs&option=cluster",3,true);
				cigri_register_menu_item($menu,$currentarray,"cdetails",$clustername,"account.php?submenu=jobs&option=clusterdetails&name=".rawurlencode($clustername),4,true);
				cigri_register_menu_item($menu,$currentarray,"cdistri","MultiJob #".$multijobid,"account.php?submenu=jobs&option=clusterdistribution&name=".rawurlencode($clustername)."&multijobid=".$multijobid,5,true);
				$smarty->assign('contenttemplate',"account/jobs/clusterdistribution.tpl");
				for ($i = 0; $i < $nb;$i++) {
					$res[$i][1] = htmlentities($res[$i][1]) ;
					$res[$i][2] = htmlentities($res[$i][2]) ;
					$res[$i][3] = htmlentities($res[$i][3]) ;
					$res[$i][4] = htmlentities($res[$i][4]) ;
					$res[$i][5] = htmlentities($res[$i][5]) ;
					$res[$i][6] = htmlentities($res[$i][6]) ;
				}
				$smarty->assign('name',$clustername);
				$smarty->assign('queryname',rawurlencode($clustername));
				$smarty->assign('id',$multijobid);
				$smarty->assign('eventarray',$res);
			}
			else {
				$smarty->assign('contenttemplate',"error.tpl");
			}
		}
		else {
			$smarty->assign('contenttemplate',"error.tpl");
		}
		break;
// }}}

// }}}

// {{{ terminated jobs management

// {{{ terminated jobs
	case "terminated":
		$selectnames[] = "MJobsId";
		$selectnames[] = "MJobsName";
		$selectnames[] = "MJobsTSub";
		cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
		$query = <<<EOF
SELECT
	count(MJobsId)
FROM
	multipleJobs
WHERE
	MJobsUser = '$login'
	AND MJobsState = 'TERMINATED'
EOF;

		list($res,$nb) = sqlquery($query,$link);
		$nbitems = $res[0][0];

		// Do all the stuff to set page parameters before display
		cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");
								
		$query = <<<EOF
SELECT
	MJobsId, MJobsName, MJobsTSub
FROM
	multipleJobs
WHERE
	MJobsUser = '$login'
	AND MJobsState = 'TERMINATED'
EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;

		unset($res);
		list($res,$nb) = sqlquery($query,$link);

		// display parameters
		cigri_register_menu_item($menu,$currentarray,"tjobs","Terminated MultiJobs","account.php?submenu=jobs&option=terminated",3,true);
		$smarty->assign('contenttemplate',"account/jobs/terminated.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]) ;
			$res[$i][2] = htmlentities($res[$i][2]) ;
		}
		$smarty->assign('eventarray',$res);
		break;
// }}}

// {{{ terminated jobs details
	case "terminateddetails":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$jobid = $_GET['id'];
				$selectnames[] = "jobId";
				$selectnames[] = "jobParam";
				$selectnames[] = "jobName";
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
	jobId, jobParam, jobName, jobCollectedJobId, jobTStart,jobTStop,  SEC_TO_TIME(UNIX_TIMESTAMP(jobTStop) -  UNIX_TIMESTAMP(jobTStart)) AS duration, jobClusterName, jobNodeName
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
				cigri_register_menu_item($menu,$currentarray,"tjobs","Terminated MultiJobs","account.php?submenu=jobs&option=terminated",3,true);
				cigri_register_menu_item($menu,$currentarray,"tjobsdetails","MultiJob #".$jobid,"account.php?submenu=jobs&option=terminateddetails&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/jobs/terminateddetails.tpl");
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
// }}}

	default:
		// Unknown option -> error
		$smarty->assign('contenttemplate','error.tpl');
		break;
}
}
	mysql_close($link);
?>
