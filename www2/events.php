<?php
define('SMARTY_DIR','Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // Load SMARTY
require_once("dbfunctions.inc");
require_once("outputfunctions.inc");
		
$link = dbconnect();

$smarty = new Smarty;

$smarty->template_dir  = 'templates/' ;
$smarty->compile_dir  = 'templates_c/' ;

// Path to cigri www root
$smarty->assign('toroot','');

// Set page vars
$smarty->assign('pagetitle',"CiGri - Grid Management");

// Set header vars
$headername = "CiGri -- Events";
if (isset($_GET['submenu'])) {
	$headername .= ".".$_GET['submenu'];
}
$smarty->assign('headername',$headername);

// Set menu items
unset($menu);
unset($currentarray);
cigri_register_menu_item($menu,$currentarray,"General","General&nbsp;informations","index.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Stats","Statistics","stats.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Events","Events","events.php",1,true);
cigri_register_menu_item($menu,$currentarray,"Account","My&nbsp;account","secured/account.php",1,false);

cigri_register_menu_item($menu,$currentarray,"ievents","Main","events.php",2,false);
$smarty->assign('contenttemplate',"events.tpl");

// {{{ Events query
$selectnames[] = "e.eventId";
$selectnames[] = "e.eventType";
$selectnames[] = "e.eventState";
$selectnames[] = "e.eventClusterName";
$selectnames[] = "mj.MJobsTSub";
$selectnames[] = "mj.MJobsName";
$selectnames[] = "mj.MJobsUser";
cigri_order_by($_GET,$selectnames,'events.php',$orderby,$orderarray,$orderimgs,$smarty,"");
$query = <<<EOF
SELECT
	COUNT(e.eventId)
FROM
	events e,multipleJobs mj
WHERE
	e.eventMJobsId = mj.MJobsId
EOF;
list($res,$nb) = sqlquery($query,$link);
$nbitems = $res[0][0];
// Do all the stuff to set page parameters before display
cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"events.php");

// New query with page limits
$query = <<<EOF
SELECT
	e.eventId, e.eventType, e.eventState, e.eventClusterName, mj.MJobsTSub, mj.MJobsName, mj.MJobsUser
FROM
	multipleJobs mj, events e
WHERE
	e.eventMJobsId = mj.MJobsId

EOF;
$query .= $orderby;
$query .= <<<EOF
 LIMIT
	$minindex,$step
EOF;

unset($res);
list($res,$nb) = sqlquery($query,$link);
// display parameters
for($i = 0; $i < $nb;$i++) {
	$res[$i][1] = htmlentities($res[$i][1]) ;
	$res[$i][2] = htmlentities($res[$i][2]) ;
	$res[$i][3] = htmlentities($res[$i][3]) ;
	$res[$i][4] = htmlentities($res[$i][4]) ;
	$res[$i][5] = htmlentities($res[$i][5]) ;
	$res[$i][6] = htmlentities($res[$i][6]) ;
}
$smarty->assign('eventarray',$res);
// }}}

$smarty->assign('MENU',$menu);
$smarty->assign('CURRENTARRAY',$currentarray);
// Display page
$smarty->display('main.tpl');
mysql_close($link);
?>
