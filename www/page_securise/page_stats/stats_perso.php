<?php
    define('SMARTY_DIR','../../Smarty-2.5.0/libs/');
    require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
    $smarty = new Smarty;



    $login = $REMOTE_USER;
    $smarty->assign('login',$login );
    $smarty->display('stats_perso.tpl');
?>
