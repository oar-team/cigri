<?php
define('SMARTY_DIR','Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // Load SMARTY
include('outputfunctions.inc');

$smarty = new Smarty;

$smarty->template_dir  = 'templates/' ;
$smarty->compile_dir  = 'templates_c/' ;

// Path to cigri www root
$smarty->assign('toroot','');

// Set page vars
$smarty->assign('pagetitle',"CiGri - Grid Management");

// Set header vars
$headername = "CiGri -- Statistics";
if (isset($_GET['submenu'])) {
	$headername .= ".".$_GET['submenu'];
}
$smarty->assign('headername',$headername);

// Set menu items
unset($menu);
unset($currentarray);
cigri_register_menu_item($menu,$currentarray,"General","General&nbsp;information","index.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Stats","Statistics","stats.php",1,true);
cigri_register_menu_item($menu,$currentarray,"Events","Events","events.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Account","My&nbsp;account","secured/account.php",1,false);

// Assign content
// Check for submenus
if (!isset($_GET['submenu'])) {
//	cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
	cigri_register_menu_item($menu,$currentarray,"gstats","Clusters&nbsp;time&nbsp;repartition","stats.php?submenu=grid",2,false);
	cigri_register_menu_item($menu,$currentarray,"cstats","Computing&nbsp;power","stats.php?submenu=power",2,false);
	cigri_register_menu_item($menu,$currentarray,"jstats","Jobs&nbsp;time&nbsp;reparition","stats.php?submenu=jobs",2,false);
	$smarty->assign('contenttemplate',"stats.tpl");
}
else {
	if ($_GET['submenu'] == 'grid') {
//		cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
		cigri_register_menu_item($menu,$currentarray,"gstats","Clusters&nbsp;time&nbsp;repartition","stats.php?submenu=grid",2,true);
		cigri_register_menu_item($menu,$currentarray,"cstats","Computing&nbsp;power","stats.php?submenu=power",2,false);
		cigri_register_menu_item($menu,$currentarray,"jstats","Jobs&nbsp;time&nbsp;reparition","stats.php?submenu=jobs",2,false);
		$smarty->assign('contenttemplate',"stats/grid.tpl");
		// assign time repartition
		if (isset($_GET['timerepartition'])) {
			$smarty->assign('timerepartition',$_GET['timerepartition']);
		}
		else {
			$smarty->assign('timerepartition',"week");
		}
	}
	else if ($_GET['submenu'] == 'power') {
//		cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
		cigri_register_menu_item($menu,$currentarray,"gstats","Clusters&nbsp;time&nbsp;repartition","stats.php?submenu=grid",2,false);
		cigri_register_menu_item($menu,$currentarray,"cstats","Computing&nbsp;power","stats.php?submenu=power",2,true);
		cigri_register_menu_item($menu,$currentarray,"jstats","Jobs&nbsp;time&nbsp;reparition","stats.php?submenu=jobs",2,false);
		$smarty->assign('contenttemplate',"stats/power.tpl");
		$smarty->assign('message',"");
		$ok = true;
		if (!$_GET['bday']) {
			$ok = false;
		} else {
			if (is_numeric($_GET['bday'])) $bday = $_GET['bday'];
			else $ok = false;
		}
		if (!$_GET['bmonth']) {
		        $ok = false;
		} else {
		        if (is_numeric($_GET['bmonth'])) $bmonth = $_GET['bmonth'];
		        else $ok = false;
		}
		if (!$_GET['byear']) {
		        $ok = false;
		} else {
		        if (is_numeric($_GET['byear'])) $byear = $_GET['byear'];
		        else $ok = false;
		}
		if (!$_GET['timerange']) {
		        $ok = false;
		} else {
			$timerange = $_GET['timerange'];
		        switch ($timerange) {
		                case "1 day":
				case "1 week":
				case "2 weeks":
				case "1 month":
				case "1 year":
					break;
				default:
					$ok = false;
			}
		}
		if (!$ok) {
			$lastm = getdate(strtotime("-1 month"));
			$bday = $lastm['mday'];
			$bmonth = $lastm['mon'];
			$byear = $lastm['year'];
			$timerange="1 month";
		}
		$smarty->assign('bday',$bday);
		$smarty->assign('bmonth',$bmonth);
		$smarty->assign('byear',$byear);
		$smarty->assign('timerange',$timerange);
		$timearray = array("1 day","1 week","2 weeks","1 month","1 year");
		$smarty->assign('timerangeget',rawurlencode($timerange));
		$years = array();
		for ($i = 2000;$i <= 2020;$i++) $years[] = $i;
		$months = array(1 => "January",2 => "February",3 => "March",4 => "April",5 => "May",6 => "June",7 => "July",8 => "August",9 => "September",10 => "October",11 => "November",12 => "December");
		$days = array();
		for ($i = 1;$i <= 31;$i++) $days[] = $i;
		$smarty->assign('timearray',$timearray);
		$smarty->assign('years',$years);
		$smarty->assign('months',$months);
		$smarty->assign('days',$days);
	}
	else if ($_GET['submenu'] == "jobs") {
		cigri_register_menu_item($menu,$currentarray,"gstats","Clusters&nbsp;time&nbsp;repartition","stats.php?submenu=grid",2,false);
		cigri_register_menu_item($menu,$currentarray,"cstats","Computing&nbsp;power","stats.php?submenu=power",2,false);
		cigri_register_menu_item($menu,$currentarray,"jstats","Jobs&nbsp;time&nbsp;reparition","stats.php?submenu=jobs",2,true);
		$smarty->assign('contenttemplate',"stats/jobs.tpl");
		// assign time repartition
		if (isset($_GET['timerepartition'])) {
			$smarty->assign('timerepartition',$_GET['timerepartition']);
		}
		else {
			$smarty->assign('timerepartition',"week");
		}
	}
	else {
		$smarty->assign('contenttemplate',"error.tpl");
	}
}

$smarty->assign('MENU',$menu);
$smarty->assign('CURRENTARRAY',$currentarray);
// Display page
$smarty->display('main.tpl');
?>
