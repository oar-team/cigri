<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );

$link = dbconnect();

$query =" select  * from clusters";

list($reponse,$nb_ligne) = sql_query($query);

$reponse1 =array();
for($i=0; $i <$nb_ligne;$i++){
    $tmp=array(
        "clusterName_aff" =>htmlentities($reponse[$i][clusterName]),
        "clusterName" =>$reponse[$i][clusterName],
        "clusterAdmin"  =>htmlentities($reponse[$i][clusterAdmin]),
        "clusterBatch"        =>htmlentities($reponse[$i][clusterBatch]),
    );
    array_push($reponse1 ,$tmp );
}

$smarty->assign('nb_ligne', $nb_ligne);
$smarty->assign('reponse', $reponse1);

mysql_close($link);
$smarty->display('repartition_cluster.tpl');

?>
