<?php
	require_once("../dbfunctions.inc");
	require_once("../outputfunctions.inc");
	
	$link = dbconnect();

	// We check the 'option' value
	// default value if not set: "fixed"
	if (!isset($_GET['option'])) {
		$option = "fixed";
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
// {{{ FIXED errors
	case "fixed":
		$selectnames[] = "e.eventId";
		$selectnames[] = "j.jobTSub";
		$selectnames[] = "mj.MJobsName";
		$selectnames[] = "j.jobName";
		cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
		$query = <<<EOF
SELECT
	COUNT(e.eventId)
FROM
	multipleJobs mj, jobs j, events e
WHERE
	mj.MJobsUser = '$login'
	AND j.jobMJobsId = mj.MJobsId
	AND e.eventJobId = j.jobId
	AND e.eventState = 'FIXED'
	AND e.eventType = 'UPDATOR_RET_CODE_ERROR'
EOF;

		list($res,$nb) = sqlquery($query,$link);
		$nbitems = $res[0][0];

		// Do all the stuff to set page parameters before display
		cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

		// New query with page limits
		$query = <<<EOF
SELECT
	e.eventId, j.jobTSub, mj.MJobsName, j.jobName
FROM
	multipleJobs mj, jobs j, events e
WHERE
	mj.MJobsUser = '$login'
	AND j.jobMJobsId = mj.MJobsId
	AND e.eventJobId = j.jobId
	AND e.eventState = 'FIXED'
	AND e.eventType = 'UPDATOR_RET_CODE_ERROR'
EOF;
		$query .= $orderby;
		$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;
		unset($res);
		list($res,$nb) = sqlquery($query,$link);

		// display parameters
		cigri_register_menu_item($menu,$currentarray,"aefixed","Fixed errors","account.php?submenu=errors&option=fixed",3,true);
		$smarty->assign('contenttemplate',"account/errors/fixed.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]) ;
			$res[$i][2] = htmlentities($res[$i][2]) ;
			$res[$i][3] = htmlentities($res[$i][3]) ;
		}
		$smarty->assign('eventarray',$res);
		break;
// }}}

// {{{ FIXED errors details
	case "fixeddetails":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$eventid = $_GET['id'];			
				$query = <<<EOF
SELECT
	*
FROM
	multipleJobs mj,jobs j,events e
WHERE
	j.jobMJobsId = mj.MJobsId
	AND e.eventJobId = j.jobId
	AND e.eventId= $eventid
EOF;

				list($res,$nb) = sqlquery($query,$link);
				if ($nb != 0){
					$res[0]['MJobsName'] = htmlentities($res[0]['MJobsName']) ;
					$res[0]['jobParam'] = htmlentities($res[0]['jobParam']) ;
					$res[0]['errorMessage'] = htmlentities($res[0]['eventMessage']) ;
					$res[0]['errorType'] = htmlentities($res[0]['eventType']) ;
					$res[0]['errorDate'] = htmlentities($res[0]['eventDate']) ;
					$res[0]['nodeName'] = htmlentities($res[0]['jobNodeName']) ;
					$res[0]['nodeClusterName'] = htmlentities($res[0]['jobClusterName']) ;
				}

				// display params
				cigri_register_menu_item($menu,$currentarray,"aefixed","Fixed errors","account.php?submenu=errors&option=fixed",3,true);
				cigri_register_menu_item($menu,$currentarray,"aefdetails","Error #".$eventid,"account.php?submenu=errors&option=fixeddetails&id=".$eventid,4,true);
				$smarty->assign('contenttemplate',"account/errors/fixeddetails.tpl");
				$smarty->assign('eventid',$eventid);
				$smarty->assign('nb',$nb);
				$smarty->assign('eventarray',$res[0]);
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


// {{{ TO FIX errors
	case "tofix":
		$selectnames[] = "e.eventId";
		$selectnames[] = "j.jobTSub";
		$selectnames[] = "mj.MJobsName";
		$selectnames[] = "j.jobName";
		cigri_order_by($_GET,$selectnames,'account.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
		$query = <<<EOF
SELECT
	count(e.eventId)
FROM
	jobs j,multipleJobs mj,events e
WHERE
	mj.MJobsUser = '$login'
	AND j.jobMJobsId = mj.MJobsId
	AND e.eventState = 'ToFIX'
	AND e.eventType = 'UPDATOR_RET_CODE_ERROR'
	AND e.eventJobId = j.jobId
EOF;
		list($res,$nb) = sqlquery($query,$link);
		$nbitems = $res[0][0];

		// Do all the stuff to set page parameters before display
		cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"account.php");

		$query = <<<EOF
SELECT
	e.eventId, j.jobTSub, mj.MJobsName, j.jobName
FROM
	jobs j,multipleJobs mj,events e
WHERE
	mj.MJobsUser = '$login'
	AND j.jobMJobsId = mj.MJobsId
	AND e.eventState = 'ToFIX'
	AND e.eventType = 'UPDATOR_RET_CODE_ERROR'
	AND e.eventJobId = j.jobId
EOF;
		$query .= $orderby;
		$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;
		unset($res);
		list($res,$nb) = sqlquery($query,$link);
		
		// display parameters
		cigri_register_menu_item($menu,$currentarray,"aetofix","Errors to fix","account.php?submenu=errors&option=tofix",3,true);
		$smarty->assign('contenttemplate',"account/errors/tofix.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]) ;
			$res[$i][2] = htmlentities($res[$i][2]) ;
			$res[$i][3] = htmlentities($res[$i][3]) ;
		}
		$smarty->assign('eventarray',$res);
	       
	break;
// }}}

// {{{ errors to fix details
	case "tofixdetails":
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$eventid = $_GET['id'];			
				$query = <<<EOF
SELECT
	*
FROM
	multipleJobs mj,jobs j,events e
WHERE
	j.jobMJobsId = mj.MJobsId
	AND e.eventJobId = j.jobId
	AND e.eventId= $eventid
EOF;

				list($res,$nb) = sqlquery($query,$link);
				if ($nb != 0){
					$res[0]['MJobsName'] = htmlentities($res[0]['MJobsName']) ;
					$res[0]['jobParam'] = htmlentities($res[0]['jobParam']) ;
					$res[0]['errorMessage'] = htmlentities($res[0]['eventMessage']) ;
					$res[0]['errorType'] = htmlentities($res[0]['eventType']) ;
					$res[0]['errorDate'] = htmlentities($res[0]['eventDate']) ;
					$res[0]['nodeName'] = htmlentities($res[0]['jobNodeName']) ;
					$res[0]['nodeClusterName'] = htmlentities($res[0]['jobClusterName']) ;
				}

				// display params
				cigri_register_menu_item($menu,$currentarray,"aetofix","Errors to fix","account.php?submenu=errors&option=tofix",3,true);
				cigri_register_menu_item($menu,$currentarray,"aetofixdetails","Error #".$eventid,"account.php?submenu=errors&option=tofixdetails&id=".$eventid,4,true);
				$smarty->assign('contenttemplate',"account/errors/tofixdetails.tpl");
				$smarty->assign('eventid',$eventid);
				$smarty->assign('nb',$nb);
				$smarty->assign('eventarray',$res[0]);
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


// {{{ TO FIX action
	case "fixaction":
		if (isset($_GET['cancel'])) {
			// redirect if cancel button clicked
			header('Location: account.php?submenu=errors&option=tofix');
			exit;
		}
		
		cigri_register_menu_item($menu,$currentarray,"aetofix","Errors to fix","account.php?submenu=errors&option=tofix",3,true);
		// Check whether values are sent through checkboxes or through job details
		// and make a common array for these two data types
		unset($errorstofix);
		if (isset($_GET['errorid'])) {
			if (is_numeric($_GET['errorid'])) {
				$errorstofix[] = $_GET['errorid'];
			}
		}
		else if (isset($_GET['errorcb']) && is_array($_GET['errorcb'])) {
			$errorstofix = $_GET['errorcb'];
		}
		if (isset($errorstofix)) {
			if (isset($_GET['fix'])) {
				cigri_register_menu_item($menu,$currentarray,"aetofixaction","Fix errors","account.php?submenu=errors&option=fixaction&fix=ok",4,true);
				$smarty->assign('action','Fix');
				$smarty->assign('shortaction','fix');
			}
			else if (isset($_GET['resub'])) {
				// Re submit job(s)
				cigri_register_menu_item($menu,$currentarray,"aetofixaction","Job Resubmission","account.php?submenu=errors&option=fixaction&resub=ok",4,true);
				$smarty->assign('action','Jobs resubmission');
				$smarty->assign('shortaction','resub');
			}

			if (isset($_GET['resub']) || isset($_GET['fix'])) {
				if (isset($_GET['GO'])) {
					// extended SELECT - WHERE clause to prevent damage from "funny" users
					$eventids = implode(",",$errorstofix);
					$query = <<<EOF
SELECT
	e.eventId, j.jobTSub, mj.MJobsName, j.jobName, mj.MJobsId, j.jobParam
FROM
	jobs j,multipleJobs mj,events e
WHERE
	e.eventId IN ($eventids)
	AND mj.MJobsUser = '$login'
	AND j.jobMJobsId = mj.MJobsId
	AND e.eventState = 'ToFIX'
	AND e.eventType = 'UPDATOR_RET_CODE_ERROR'
	AND e.eventJobId = j.jobId
EOF;
					list($res,$nb) = sqlquery($query,$link);
					unset($errorstofix);
					for ($i = 0;$i < $nb;$i++) {
						$errorstofix[] = $res[$i][0];
					}
					$eventids = implode(",",$errorstofix);
					if (isset($_GET['fix'])) {
						$query = <<<EOF
UPDATE
	events
SET
	eventState = 'FIXED'
WHERE
	eventId IN ($eventids)
EOF;
						mysql_query($query,$link);
						$smarty->assign('updates',mysql_affected_rows($link));	
					} else {
						$updates = 0;
						for ($i = 0;$i < $nb;$i++) {
							$query = <<<EOF
INSERT INTO
	parameters
VALUES
	({$res[$i][4]},'{$res[$i][3]}','{$res[$i][5]}',0)
EOF;
							mysql_query($query,$link);
							$updates += mysql_affected_rows($link);
						}
						if ($updates < 0) $updates = 0;
						$smarty->assign('updates',$updates);
					}
					for($i = 0; $i < $nb;$i++) {
						$res[$i][1] = htmlentities($res[$i][1]) ;
						$res[$i][2] = htmlentities($res[$i][2]) ;
						$res[$i][3] = htmlentities($res[$i][3]) ;
					}
					$smarty->assign('nbitems',$nb);
					$smarty->assign('eventarray',$res);
					$smarty->assign('contenttemplate','account/errors/fixactiongo.tpl');
					
				}
				else {
					// Confirm ???
					// extended WHERE clause to prevent damage from "funny" users
					$eventids = implode(",",$errorstofix);
					$query = <<<EOF
SELECT
	e.eventId, j.jobTSub, mj.MJobsName, j.jobName
FROM
	jobs j,multipleJobs mj,events e
WHERE
	e.eventId IN ($eventids)
	AND mj.MJobsUser = '$login'
	AND j.jobMJobsId = mj.MJobsId
	AND e.eventState = 'ToFIX'
	AND e.eventType = 'UPDATOR_RET_CODE_ERROR'
	AND e.eventJobId = j.jobId
EOF;

					list($res,$nb) = sqlquery($query,$link);
					for($i = 0; $i < $nb;$i++) {
						$res[$i][1] = htmlentities($res[$i][1]) ;
						$res[$i][2] = htmlentities($res[$i][2]) ;
						$res[$i][3] = htmlentities($res[$i][3]) ;
					}
					$smarty->assign('nbitems',$nb);
					$smarty->assign('eventarray',$res);
					$smarty->assign('contenttemplate','account/errors/fixactionconfirm.tpl');
				}
			}
			else {
				$smarty->assign('contenttemplate','error.tpl');
			}
		}
		else {
			$smarty->assign('nbitems',0);
			$smarty->assign('contenttemplate','account/errors/fixactionconfirm.tpl');
		}
		break;
// }}}

	default:
		// Unknown option -> error
		$smarty->assign('contenttemplate','error.tpl');
		break;
}
}
	mysql_close($link);		       
?>
