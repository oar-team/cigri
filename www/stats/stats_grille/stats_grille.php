<?php
include "../../functions.inc";
define('SMARTY_DIR','../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY

$smarty = new Smarty;
$smarty->template_dir  = '../tpl/templates/' ;
$smarty->compile_dir  = '../tpl/templates_c/' ;

$smarty->assign('bouton',$bouton);

$smarty->display('stats_grille.tpl');
?>
