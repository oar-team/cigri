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
$smarty->assign('headername',"CiGri -- General Informations");

// Set menu items
unset($menu);
unset($currentarray);
cigri_register_menu_item($menu,$currentarray,"General","General&nbsp;informations","index.php",1,true);
cigri_register_menu_item($menu,$currentarray,"S1","Step&nbsp;1","index.php#step1",2,false);
cigri_register_menu_item($menu,$currentarray,"S2","Step&nbsp;2","index.php#step2",2,false);
cigri_register_menu_item($menu,$currentarray,"S3","Step&nbsp;3","index.php#step3",2,false);
cigri_register_menu_item($menu,$currentarray,"S4","Step&nbsp;4","index.php#step4",2,false);
cigri_register_menu_item($menu,$currentarray,"S5","Step&nbsp;5","index.php#step5",2,false);
cigri_register_menu_item($menu,$currentarray,"ex","Example","index.php#example",2,false);
cigri_register_menu_item($menu,$currentarray,"links","Links","index.php#links",2,false);
cigri_register_menu_item($menu,$currentarray,"Stats","Statistics","stats.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Events","Events","events.php",1,false);
cigri_register_menu_item($menu,$currentarray,"Account","My&nbsp;account","secured/account.php",1,false);
$smarty->assign('MENU',$menu);
$smarty->assign('CURRENTARRAY',$currentarray);

// Assign content
$smarty->assign('contenttemplate',"index.tpl");

// Display page
$smarty->display('main.tpl');
?>
