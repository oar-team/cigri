<?php
include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );

$link = dbconnect();

$query ="   select  count(*) as total
            from multipleJobs
            where MJobsUser = '$login'
            and MJobsState ='IN_TREATMENT'";

list($reponse2,$nb) = sql_query($query);
$nb_total = $reponse2[0][total];

// eb fonction de ce nombre on peut donc avoir le nombre de pages présentes
//	echo "<font color = \"FF0000\">";

$query = "select  *
          from multipleJobs
          where MJobsUser = '$login'
          and MJobsState = 'IN_TREATMENT'
          ";

list($reponse,$nb_ligne,$page_courante,$nb_jobs,$page_courante,$sensprim,$senssecond,$cleprimaire,$clesecondaire) = sortedQuery($query,$nb_jobs,$page_courante,$pge,$lim_inf,$valid,$page,$clic,$cleprimaire,$clesecondaire,$sensprim,$senssecond);

//			echo "</br>les variables:";
//			echo "</br>bouton : ".$valid.$page.$clic;
//  		echo "</br> : nb_jobs : ".$nb_jobs;
//			echo "</br> : page_courante : ".$page_courante;
//			echo "</br> :clesecondaire  : ".$clesecondaire;
//			echo "</br> : cleprimaire : ".$cleprimaire;
//			echo "</br> : sensprim : ".$sensprim;
//			echo "</br> :senssecond :  ".$senssecond;
//			echo "</br> :lim_inf :  ".$lim_inf;
//			echo "</font>";


$nb_page = ceil($nb_total/$nb_jobs); //ceil pren l'arrondi superieur

$pages=array(); for ($i=1;$i<=$nb_page;$i++){array_push($pages,$i);}// on met les pages dans un tablo pour le derouler dans un checkbox

$smarty->assign('nb_total', $nb_total);
$smarty->assign('ID', $ID);
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
    $reponse[$i][MJobsTSub] = htmlentities($reponse[$i][MJobsTSub]) ;
    $reponse[$i][MJobsName] = htmlentities($reponse[$i][MJobsName]) ;
}

$smarty->assign('nb_ligne', $nb_ligne);
$smarty->assign('reponse', $reponse);


mysql_close($link);
$smarty->display('jobs_en_cours.tpl');

?>
