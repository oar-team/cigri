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
cigri_register_menu_item($menu,$currentarray,"General","General&nbsp;informations","index.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Stats","Statistics","stats.php",1,true);
cigri_register_menu_item($menu,$currentarray,"Events","Events","events.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Account","My&nbsp;account","secured/account.php",1,false);

// Assign content
// Check for submenus
if (!isset($_GET['submenu'])) {
	cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
	cigri_register_menu_item($menu,$currentarray,"gstats","Grid&nbsp;Statstics","stats.php?submenu=grid",2,false);
	cigri_register_menu_item($menu,$currentarray,"cstats","Cluster&nbsp;Statistics","stats.php?submenu=cluster",2,false);
	$smarty->assign('contenttemplate',"stats.tpl");
}
else {
	if ($_GET['submenu'] == 'grid') {
		cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
		cigri_register_menu_item($menu,$currentarray,"gstats","Grid&nbsp;Statstics","stats.php?submenu=grid",2,true);
		cigri_register_menu_item($menu,$currentarray,"cstats","Cluster&nbsp;Statistics","stats.php?submenu=cluster",2,false);
		$smarty->assign('contenttemplate',"stats/grid.tpl");
		// assign time repartition
		if (isset($_GET['timerepartition'])) {
			$smarty->assign('timerepartition',$_GET['timerepartition']);
		}
		else {
			$smarty->assign('timerepartition',"week");
		}
	}
	else if ($_GET['submenu'] == 'cluster') {
		cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
		cigri_register_menu_item($menu,$currentarray,"gstats","Grid&nbsp;Statstics","stats.php?submenu=grid",2,false);
		cigri_register_menu_item($menu,$currentarray,"cstats","Cluster&nbsp;Statistics","stats.php?submenu=cluster",2,true);
		$smarty->assign('contenttemplate',"stats/cluster.tpl");
		$smarty->assign('message',"");
		$smarty->assign('interval',"12");
		// assign interval value
		if (isset($_GET['interval'])) {
			if (!is_numeric($_GET['interval'])) {
				$smarty->assign('message',"Interval must be a number");
			}
			else {
				if ($_GET['interval'] <= 0 || $_GET['interval'] > 24) {
					$smarty->assign('message',"Please enter an 'Interval' value in [1,24]");
				}
				else {
					$smarty->assign('interval',$_GET['interval']);
				}
			}
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
