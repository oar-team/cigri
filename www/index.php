<?php
define('SMARTY_DIR','Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY

$smarty = new Smarty;

$smarty->template_dir  = 'index/templates/' ;
$smarty->compile_dir  = 'index/templates_c/' ;
$smarty->config_dir   = 'index/configs/' ;
$smarty->cache_dir  = 'index/cache/' ;

$smarty->display('index.tpl');
?>
