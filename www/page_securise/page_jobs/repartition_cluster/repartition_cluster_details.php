<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );

$link = dbconnect();

$query =
    "select  count(distinct (jobMJobsId)) as total
    from  jobs, multipleJobs
    where  jobClusterName= '$clustername'
    and MJobsId =jobMJobsId
";

list($reponse2,$nb) = sql_query($query);
$nb_total = $reponse2[0][total];


  	 // en fonction de ce nombre on peut donc avoir le nombre de pages présentes
		//echo "<font color = \"FF0000\">";

$query = "  select distinct (jobMJobsId) , MJobsName, MJobsState
            from  jobs, multipleJobs
            where  jobClusterName= '$clustername'
            and MJobsId =jobMJobsId";

list($reponse,$nb_ligne,$page_courante,$nb_jobs,$page_courante,$sensprim,$senssecond,$cleprimaire,$clesecondaire) = sortedQuery($query,$nb_jobs,$page_courante,$pge,$lim_inf,$valid,$page,$clic,$cleprimaire,$clesecondaire,$sensprim,$senssecond);


//			echo "</br>les variables:";
//			echo "</br>cluster : ".$clustername;
//			echo "</br>bouton : ".$valid.$page.$bouton;
//			echo "</br> : nb_jobs : ".$nb_jobs;
//			echo "</br> : page_courante : ".$page_courante;
//			echo "</br> :clesecondaire  : ".$clesecondaire;
//			echo "</br> : cleprimaire : ".$cleprimaire;
//			echo "</br> : sensprim : ".$sensprim;
//			echo "</br> :senssecond :  ".$senssecond;


$nb_page=  ceil($nb_total/$nb_jobs); //ceil pren l'arrondi superieur
$pages=array(); for ($i=1;$i<=$nb_page;$i++){array_push($pages,$i);}// on met les pages dans un tablo pour le derouler dans un checkbox

$smarty->assign('nb_total', $nb_total);

// on met les pages dans un tablo pour le derouler dans un checkbox
$smarty->assign('pages', $pages);
// varaible contenant le nombre totale de page
$smarty->assign('nb_page', $nb_page);
// numero de la page courante
$smarty->assign('page_courante',$page_courante );
// nombre de jobs affiché sur la page
$smarty->assign('nb_jobs', $nb_jobs);
// donne l'ordre d'affichage actuel
$smarty->assign('cleprimaire', $cleprimaire);
$smarty->assign('clesecondaire',$clesecondaire );
$smarty->assign('sensprim', $sensprim);
$smarty->assign('senssecond', $senssecond);


	// POUR AFFICHAGE

for($i=0; $i <$nb_ligne;$i++){
    $reponse[$i][MJobsState] = htmlentities($reponse[$i][MJobsState]) ;
    $reponse[$i][MJobsName] = htmlentities($reponse[$i][MJobsName]) ;
}

$smarty->assign('nb_ligne', $nb_ligne);
$smarty->assign('reponse', $reponse);
$smarty->assign('clustername', $clustername);

mysql_close($link);

$smarty->display('repartition_cluster_details.tpl');

?>
