<?php
	require_once("../dbfunctions.inc");
	require_once("../outputfunctions.inc");

	$link = dbconnect();
	// We check the 'option' value
	// default value if not set: "running"
	if (!isset($_GET['option'])) {
		$option = "stats";
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
// {{{ main
	case 'stats':
		$smarty->assign('contenttemplate','account/stats/stats.tpl');
		break;
// }}}

// {{{ Multijob list
	case 'mj':
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
		cigri_register_menu_item($menu,$currentarray,"mj","MultiJob Statistics","account.php?submenu=stats&option=mj",3,true);
		$smarty->assign('contenttemplate',"account/stats/mj.tpl");
		for($i = 0; $i < $nb;$i++) {
			$res[$i][1] = htmlentities($res[$i][1]) ;
			$res[$i][2] = htmlentities($res[$i][2]) ;
			$res[$i][3] = htmlentities($res[$i][3]) ;
		}
		$smarty->assign('nb',$nb);
		$smarty->assign('eventarray',$res);
		break;

// }}}

// {{{ Multijob stats
	case 'details':
		if (isset($_GET['id'])) {
			if (is_numeric($_GET['id'])) {
				$jobid = $_GET['id'];
													
				cigri_register_menu_item($menu,$currentarray,"mj","MultiJob Statistics","account.php?submenu=stats&option=mj",3,true);
				cigri_register_menu_item($menu,$currentarray,"mjdetails","MultiJob #".$jobid,"account.php?submenu=stats&option=details&id=".$jobid,4,true);
				$smarty->assign('contenttemplate',"account/stats/details.tpl");
				$smarty->assign('jobid',$jobid);
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

// {{{ All jobs
	case 'jobs':
		cigri_register_menu_item($menu,$currentarray,"aj","All Jobs","account.php?submenu=stats&option=jobs",3,true);
		$smarty->assign('login',$login);
		$smarty->assign('contenttemplate',"account/stats/jobs.tpl");
		// assign time repartition
		if (isset($_GET['timerepartition'])) {
			$smarty->assign('timerepartition',$_GET['timerepartition']);
		}
		else {
			$smarty->assign('timerepartition',"week");
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
