<?php
define('SMARTY_DIR','../Smarty-2.5.0/libs/');
require_once(SMARTY_DIR.'Smarty.class.php'); // Load SMARTY
require_once("../dbfunctions.inc");
require_once("../outputfunctions.inc");

$smarty = new Smarty;

$smarty->template_dir  = '../templates/' ;
$smarty->compile_dir  = '../templates_c/' ;

// Path to cigri www root
$smarty->assign('toroot','../');

// Set page vars
$smarty->assign('pagetitle',"CiGri - Grid Management");

// Set header vars
$headername = "CiGri -- Admin";

// Check user authentication
session_start();
$link = dbconnect();

// dirty way to get all GET and POST params in only one array
$_GET = array_merge($_GET,$_POST);

if (!isset($_SESSION['adminauth']) || $_SESSION['adminauth'] == false) {
	// check if user sent log informations
	if (isset($_GET['pass'])) {
		// right pass?
		$query = <<<EOF
SELECT
	pass
FROM
	webusers
WHERE
	login = 'admin'
EOF;
		list($res,$nb) = sqlquery($query,$link);
		
		if ($nb > 0) {
			// No password in database
			if ($res[0][0] == '' && $_GET['pass'] == '') {
				$_SESSION['adminauth'] = true;
			}
			else {
				if (crypt($_GET['pass'],17) == $res[0][0]) {
					$_SESSION['adminauth'] = true;
				}
				else {
					$_SESSION['adminauth'] = false;
				}
			}
		}
		else {
			$_SESSION['adminauth'] = false;
		}
	}
	else {
		$_SESSION['adminauth'] = false;
	}
}
mysql_close($link);

// logout
if (isset($_GET['submenu'])) {
	if ($_GET['submenu'] == 'logout') {
		$_SESSION['adminauth'] = false;
		$_SESSION['auth'] = false;
		header("Location: ../secured/account.php");
		exit;
	}
}

// Set menu items
unset($menu);
unset($currentarray);
cigri_register_menu_item($menu,$currentarray,"admin","Administration","index.php",1,true);

if ($_SESSION['adminauth'] == false) {
	cigri_register_menu_item($menu,$currentarray,"ainfo","Login","index.php",2,true);
	// Login page
	$smarty->assign('headername',$headername);
	$smarty->assign('contenttemplate',"cigri/login.tpl");
}
else {
	if (isset($_GET['submenu'])) {
		$headername .= ".".$_GET['submenu'];
	}
	$smarty->assign('headername',$headername);

	// Assign content
	// Check for submenus
	if (!isset($_GET['submenu'])) {
		$submenu = users;
	} else {
		$submenu = $_GET['submenu'];
	}
	if ($submenu == 'newaccount') {
		cigri_register_menu_item($menu,$currentarray,"ausers","Users","index.php?submenu=users",2,false);
		cigri_register_menu_item($menu,$currentarray,"anew","Create new user","index.php?submenu=newaccount",2,true);
		cigri_register_menu_item($menu,$currentarray,"events","Events","index.php?submenu=events",2,false);
		cigri_register_menu_item($menu,$currentarray,"logout","Logout","index.php?submenu=logout",2,false);
		include("newaccount.php");
	}
	else if ($submenu == 'users') {
		cigri_register_menu_item($menu,$currentarray,"ausers","Users","index.php?submenu=users",2,true);
		cigri_register_menu_item($menu,$currentarray,"anew","Create new user","index.php?submenu=newaccount",2,false);
		cigri_register_menu_item($menu,$currentarray,"events","Events","index.php?submenu=events",2,false);
		cigri_register_menu_item($menu,$currentarray,"logout","Logout","index.php?submenu=logout",2,false);
		include("users.php");
	}
	else if ($submenu == 'events') {
		cigri_register_menu_item($menu,$currentarray,"ausers","Users","index.php?submenu=users",2,false);
		cigri_register_menu_item($menu,$currentarray,"anew","Create new user","index.php?submenu=newaccount",2,false);
		cigri_register_menu_item($menu,$currentarray,"events","Events","index.php?submenu=events",2,true);
		cigri_register_menu_item($menu,$currentarray,"logout","Logout","index.php?submenu=logout",2,false);
		include("events.php");
	}
	else {
		// unknown parameter
		$smarty->assign('contenttemplate',"error.tpl");
	}
}

$smarty->assign('MENU',$menu);
$smarty->assign('CURRENTARRAY',$currentarray);
// Display page
$smarty->display('main.tpl');
?>
