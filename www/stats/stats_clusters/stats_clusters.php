<?php
   include "../../functions.inc";
    define('SMARTY_DIR','../../Smarty-2.5.0/libs/');
    require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
    $smarty = new Smarty;
    
      $smarty->template_dir  = '../tpl/templates/' ;
    $smarty->compile_dir  = '../tpl/templates_c/' ;



    if ($intervalle > 24){$intervalle=12; $trogran ="ouhlala";}



    $smarty->assign('intervalle',$intervalle);
    $smarty->assign('trogran',$trogran);
    $smarty->assign('bouton',$bouton);


    $smarty->display('stats_clusters.tpl');
?>
