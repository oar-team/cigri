<?php
include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );

$link = dbconnect();
$query1 =
    "select  propertiesClusterName , propertiesJobCmd , userLogin
    from  properties, users
    where propertiesMJobsId = '$ID'
    and userClusterName = propertiesClusterName
    limit 100";

list($reponse,$nb_ligne) = sql_query($query1);


for($i=0; $i <$nb_ligne;$i++){
    $reponse[$i][propertiesClusterName] = htmlentities($reponse[$i][propertiesClusterName]) ;
    $reponse[$i][propertiesJobCmd] = htmlentities($reponse[$i][propertiesJobCmd]) ;
    $reponse[$i][userLogin] = htmlentities($reponse[$i][userLogin]) ;
}

$smarty->assign('nb_ligne', $nb_ligne);
$smarty->assign('reponse', $reponse);

//id = identificateur du job sur lequel il a été cliqué: envoi du bouton
$smarty->assign('ID', $ID);
mysql_close($link);
$smarty->display('jobs_termines_proprietes.tpl');

?>
