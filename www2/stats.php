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
	$smarty->assign('contenttemplate',"stats.tpl");
}
else {
	if ($_GET['submenu'] == 'grid') {
//		cigri_register_menu_item($menu,$currentarray,"istats","Main","stats.php",2,false);
		cigri_register_menu_item($menu,$currentarray,"gstats","Clusters&nbsp;time&nbsp;repartition","stats.php?submenu=grid",2,true);
		cigri_register_menu_item($menu,$currentarray,"cstats","Computing&nbsp;power","stats.php?submenu=power",2,false);
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
		if (!$_GET['eday']) {
		        $ok = false;
		} else {
			if (is_numeric($_GET['eday'])) $eday = $_GET['eday'];
			else $ok = false;
		}
		if (!$_GET['emonth']) {
		        $ok = false;
		} else {
		        if (is_numeric($_GET['emonth'])) $emonth = $_GET['emonth'];
		        else $ok = false;
		}
		if (!$_GET['eyear']) {
		        $ok = false;
		} else {
		        if (is_numeric($_GET['eyear'])) $eyear = $_GET['eyear'];
			        else $ok = false;
			}
			if ($ok) {
			        if ($eyear < $byear) {
			                $eyear = $byear;
			        }
			        if ($eyear == $byear) {
			                if ($emonth < $bmonth) {
			                        $emonth = $bmonth;
			                }
			                if ($emonth == $bmonth) {
			                        if ($eday < $bday) {
			                                $eday = $bday+1;
			                        }
			                }
			        }
			}
			if ($ok) {
			        if ($bday >= 1 && $bday <= 31 && $bmonth >= 1 && $bmonth <= 12 && $byear >= 1990 && $byear <= 2100) {
					if (!checkdate($bmonth,$bday,$byear)) {
			                        // This can only be a bad day number
			                        if (checkdate($bmonth,30,$byear)) {
			                               $bday = 30;
		                               } else {
		                                       if (checkdate($bmonth,29,$byear)) $bday = 29;
		                                       else $bday = 28;
		                               }
		                       }
		               } else {
		                       $ok = false;
		               }
			       if ($eday >= 1 && $eday <= 31 && $emonth >= 1 && $emonth <= 12 && $eyear >= 1990 && $eyear <= 2100) {
					if (!checkdate($emonth,$eday,$eyear)) {
		                               // This can only be a bad day number
		                               if (checkdate($emonth,30,$eyear)) {
		                                      $eday = 30;
		                              } else {
		                                      if (checkdate($emonth,29,$eyear)) $eday = 29;
		                                      else $eday = 28;
		                              }
		                      }
		              } else {
		                      $ok = false;
		              }
		      	}
			if ($ok) {
				if ($byear == $eyear && $bmonth == $emonth && $bday == $eday) {
					if (checkdate($emonth,$eday+1,$eyear)) $eday++;
			                else $bday--;
		        	}
			}
			else {
				$now = getdate();
				$eday = $now['mday'];
				$emonth = $now['mon'];
				$eyear = $now['year'];
				$lastm = getdate(strtotime("-1 month"));
				$bday = $lastm['mday'];
				$bmonth = $lastm['mon'];
				$byear = $lastm['year'];
			}
			$smarty->assign('bday',$bday);
			$smarty->assign('bmonth',$bmonth);
			$smarty->assign('byear',$byear);
			$smarty->assign('eday',$eday);
			$smarty->assign('emonth',$emonth);
			$smarty->assign('eyear',$eyear);
			$smarty->assign('gran',$granularity);
			$smarty->assign('grantype',$grantype);
			$years = array();
			for ($i = 2000;$i <= 2020;$i++) $years[] = $i;
			$months = array(1 => "January",2 => "February",3 => "March",4 => "April",5 => "May",6 => "June",7 => "July",8 => "August",9 => "September",10 => "October",11 => "November",12 => "December");
			$days = array();
			for ($i = 1;$i <= 31;$i++) $days[] = $i;
			$smarty->assign('years',$years);
			$smarty->assign('months',$months);
			$smarty->assign('days',$days);
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
