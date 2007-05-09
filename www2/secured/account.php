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
$headername = "CiGri -- My Account";

// Check user authentication
session_start();
$link = dbconnect();

function ldap_checkpass($ds,$login,$pass) // check the password against ldap server
{
   global $LDAP_USERS;
   if(!$pass) { $pass = crypt(microtime()); }
   if (!($r=@ldap_bind($ds,"uid=$login,$LDAP_USERS","$pass"))) {
     sleep (3);
   }
   return !$r;
}

if (!isset($_SESSION['auth']) || $_SESSION['auth'] == false) {
	// check if user sent log informations
	if (isset($_POST['login']) && isset($_POST['pass'])) {

	    // Check login (LDAP method)
	    if ($LDAP) {
            	$ds=ldap_connect("$LDAP_HOST");
		ldap_set_option($ds, LDAP_OPT_PROTOCOL_VERSION, 3);
                if (! $ds) {
	            print "Unable to contact LDAP server $LDAP_HOST!";
		    $_SESSION['auth'] = false;
                }
		else {
	 	    $checkpass = ldap_checkpass($ds,$_POST['login'],$_POST['pass']);
	            if($checkpass == 0) {
			$_SESSION['auth'] = true;
			$_SESSION['login'] = $_POST['login'];
			if ($_POST['login'] == 'admin') {
			    $_SESSION['adminauth'] = true;
			    header("Location: ../admin/index.php");
			    exit;
			}
		    }
		    else {
		        $_SESSION['auth'] = false;
		    }
		}						       
	    }

	    // Check login (MYSQL method)
	    else {
		$templog = addslashes($_POST['login']);
		$query = <<<EOF
SELECT
	pass
FROM
	webusers
WHERE
	login = '$templog'
EOF;
		list($res,$nb) = sqlquery($query,$link);
		
		if ($nb > 0) {
			if (crypt($_POST['pass'],17) == $res[0][0]) {
				$_SESSION['auth'] = true;
				$_SESSION['login'] = $_POST['login'];
				if ($templog == 'admin') {
					$_SESSION['adminauth'] = true;
					header("Location: ../admin/index.php");
					exit;
				}
			}
			else {
				$_SESSION['auth'] = false;
			}
		}
		else {
			$_SESSION['auth'] = false;
		}
	    }
	}
	else {
		$_SESSION['auth'] = false;
	}
}
mysql_close($link);

// logout
if (isset($_GET['submenu'])) {
	if ($_GET['submenu'] == 'logout') {
		$_SESSION['auth'] = false;
		unset($_SESSION['login']);
	}
}

// Set menu items
unset($menu);
unset($currentarray);
cigri_register_menu_item($menu,$currentarray,"General","General&nbsp;information","../index.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Stats","Statistics","../stats.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Events","Events","../events.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Account","My&nbsp;account","account.php",1,true);

if ($_SESSION['auth'] == false) {
	cigri_register_menu_item($menu,$currentarray,"ainfo","Login","account.php",2,true);
	// Login page
	$smarty->assign('headername',$headername);
	$smarty->assign('contenttemplate',"account/login.tpl");
}
else {
	$login = $_SESSION['login'];
	$smarty->assign('login',$login);

	if (isset($_GET['submenu'])) {
		$headername .= ".".$_GET['submenu'];
	}
	$smarty->assign('headername',$headername);

	// Assign content
	// Check for submenus
	if (!isset($_GET['submenu'])) {
//		cigri_register_menu_item($menu,$currentarray,"ainfo","Main","account.php",2,false);
		cigri_register_menu_item($menu,$currentarray,"ajobs","MultiJobs","account.php?submenu=jobs",2,false);
		cigri_register_menu_item($menu,$currentarray,"astats","Statistics","account.php?submenu=stats",2,false);
                cigri_register_menu_item($menu,$currentarray,"astatus","Status","account.php?submenu=status",2,false);
		cigri_register_menu_item($menu,$currentarray,"aerrors","Errors","account.php?submenu=errors",2,false);
		cigri_register_menu_item($menu,$currentarray,"alogout",$login.": logout","account.php?submenu=logout",2,false);
		$smarty->assign('contenttemplate',"account.tpl");
	}
	else {
		// PHP code for submenus is in external files for easier update and management
		if ($_GET['submenu'] == 'jobs') {
//			cigri_register_menu_item($menu,$currentarray,"ainfo","Main","account.php",2,false);
			cigri_register_menu_item($menu,$currentarray,"ajobs","MultiJobs","account.php?submenu=jobs",2,true);
			cigri_register_menu_item($menu,$currentarray,"astats","Statistics","account.php?submenu=stats",2,false);
                        cigri_register_menu_item($menu,$currentarray,"astatus","Status","account.php?submenu=status",2,false);
			cigri_register_menu_item($menu,$currentarray,"aerrors","Errors","account.php?submenu=errors",2,false);
			cigri_register_menu_item($menu,$currentarray,"alogout",$login.": logout","account.php?submenu=logout",2,false);
			include("account/jobs.php");
		}
		else if ($_GET['submenu'] == 'stats') {
//			cigri_register_menu_item($menu,$currentarray,"ainfo","Main","account.php",2,false);
			cigri_register_menu_item($menu,$currentarray,"ajobs","MultiJobs","account.php?submenu=jobs",2,false);
			cigri_register_menu_item($menu,$currentarray,"astats","Statistics","account.php?submenu=stats",2,true);
                        cigri_register_menu_item($menu,$currentarray,"astatus","Status","account.php?submenu=status",2,false);
			cigri_register_menu_item($menu,$currentarray,"aerrors","Errors","account.php?submenu=errors",2,false);
			cigri_register_menu_item($menu,$currentarray,"alogout",$login.": logout","account.php?submenu=logout",2,false);
			include("account/stats.php");
		}
		else if ($_GET['submenu'] == 'errors') {
//			cigri_register_menu_item($menu,$currentarray,"ainfo","Main","account.php",2,false);
			cigri_register_menu_item($menu,$currentarray,"ajobs","MultiJobs","account.php?submenu=jobs",2,false);
			cigri_register_menu_item($menu,$currentarray,"astats","Statistics","account.php?submenu=stats",2,false);
                        cigri_register_menu_item($menu,$currentarray,"astatus","Status","account.php?submenu=status",2,false);
			cigri_register_menu_item($menu,$currentarray,"aerrors","Errors","account.php?submenu=errors",2,true);
			cigri_register_menu_item($menu,$currentarray,"alogout",$login.": logout","account.php?submenu=logout",2,false);
			include("account/errors.php");
		}
		else if ($_GET['submenu'] == 'status') {
//                      cigri_register_menu_item($menu,$currentarray,"ainfo","Main","account.php",2,false);
                        cigri_register_menu_item($menu,$currentarray,"ajobs","MultiJobs","account.php?submenu=jobs",2,false);
                        cigri_register_menu_item($menu,$currentarray,"astats","Statistics","account.php?submenu=stats",2,false);
                        cigri_register_menu_item($menu,$currentarray,"astatus","Status","account.php?submenu=status",2,true);
                        cigri_register_menu_item($menu,$currentarray,"aerrors","Errors","account.php?submenu=errors",2,false);
                        cigri_register_menu_item($menu,$currentarray,"alogout",$login.": logout","account.php?submenu=logout",2,false);
                        include("account/status.php");
                }
		else {
			// unknown parameter
			$smarty->assign('contenttemplate',"error.tpl");
		}
	}
}

$smarty->assign('MENU',$menu);
$smarty->assign('CURRENTARRAY',$currentarray);
// Display page
$smarty->display('main.tpl');
?>
