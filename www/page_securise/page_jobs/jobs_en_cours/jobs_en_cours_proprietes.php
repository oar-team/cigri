<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );
$plusdecent=0;
$link = dbconnect();

//echo "<font color =\"FF0000\">";
if ( $bout == "suspend"){
    $query2 =
        "update  properties
        set propertiesActivated = 'off'
        where propertiesMJobsId = '$ID'
        and propertiesClusterName = '$propertiesClusterName'
        ";

    mysql_query($query2);
}elseif($bout == "activate"){
    $query2 =
        "update  properties
        set propertiesActivated = 'on'
        where propertiesMJobsId = '$ID'
        and propertiesClusterName = '$propertiesClusterName'
        ";
    mysql_query($query2);
}
//else{echo "arrivée";}

$query1 =
   "select  propertiesClusterName , propertiesJobCmd , userLogin
   from  properties, users
   where propertiesMJobsId = '$ID'
   and userClusterName = propertiesClusterName
   and userGridName ='$login'
  ";
list($reponse1,$nb_ligne1) = sql_query($query1);

   //echo "</font>";

	// POUR AFFICHAGE
$reponse =array();
for($i=0; $i <$nb_ligne1;$i++){
    $tmp=array(
    "propertiesJobCmd" =>htmlentities($reponse1[$i][propertiesJobCmd]),
    "userLogin" =>htmlentities($reponse1[$i][userLogin]),
    "propertiesClusterName_aff" =>htmlentities($reponse1[$i][propertiesClusterName]),
    "propertiesClusterName" =>$reponse1[$i][propertiesClusterName],
    );
    print_r($tmp);
    array_push($reponse ,$tmp );
}


$smarty->assign('nb_ligne1', $nb_ligne1);
$smarty->assign('reponse1', $reponse);

$smarty->assign('ID', $ID);

mysql_close($link);
$smarty->display('jobs_en_cours_proprietes.tpl');

?>
