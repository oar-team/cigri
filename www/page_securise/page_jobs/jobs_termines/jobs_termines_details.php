<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );

$link = dbconnect();
///--------	ATTENTION A NE PA OUBLIER LE NOMBRE TOTALE DE LA REQUETE

//Permet d'avoir le nombre total de ligne pour cette requete
// en fonction de ce nombre on peut donc avoir le nombre de pages présentes
$query = "
    select  count(*) as total
    from  jobs
    where jobMJobsId = '$ID'
    and jobState = 'Terminated '
";
list($reponse2,$nb) = sql_query($query);
$nb_total = $reponse2[0][total];

//les kilés
$kille = "
    select jobParam, count(*)
    from jobs
    where jobState='Killed'
    group by jobParam";
list($killage,$nb_param_kille) = sql_query($kille);

		//echo "<font color = \"FF0000\">";

$query = "  select  jobParam, jobTStart,jobTStop,jobId,jobCollectedJobId,  SEC_TO_TIME(UNIX_TIMESTAMP(jobTStop) -  UNIX_TIMESTAMP(jobTStart)) as duree
 	   	from  jobs
 	   	where jobMJobsId = '$ID'
		and jobState = 'Terminated '";

list($reponse_temp,$nb_ligne,$page_courante,$nb_jobs,$page_courante,$sensprim,$senssecond,$cleprimaire,$clesecondaire) = sortedQuery($query,$nb_jobs,$page_courante,$pge,$lim_inf,$valid,$page,$clic,$cleprimaire,$clesecondaire,$sensprim,$senssecond);

//			echo "les variables:";
//			echo "</br>bouton : ".$valid.$page.$bouton;
//			echo "</br> : nb_jobs : ".$nb_jobs;
//			echo "</br> : page_courante : ".$page_courante;
//			echo "</br> :clesecondaire  : ".$clesecondaire;
//			echo "</br> : cleprimaire : ".$cleprimaire;
//			echo "</br> : sensprim : ".$sensprim;
//			echo "</br> :senssecond :  ".$senssecond;


$nb_page=  ceil($nb_total/$nb_jobs); //ceil pren l'arrondi superieur
$pages=array(); for ($i=1;$i<=$nb_page;$i++){array_push($pages,$i);}// on met les pages dans un tablo pour le derouler dans un checkbox


// tablo final auquel on ajoute le champs killé = valable pour toutes les requetes

$reponse =array();
for($i=0; $i <$nb_ligne;$i++){
    $tmp=array(
        "jobParam" =>htmlentities($reponse_temp[$i][jobParam]),
        "jobTStart" =>htmlentities($reponse_temp[$i][jobTStart]),
        "jobTStop"  =>htmlentities($reponse_temp[$i][jobTStop]),
        "jobId"        =>$reponse_temp[$i][jobId],
        "jobCollectedJobId"=>htmlentities($reponse_temp[$i][jobCollectedJobId]),
        "duree" =>$reponse_temp[$i][duree],
        "kille" => 0//initialisation
    );
    //parcours du tablo des kilé
    for($k=0;$k<$nb_param_kille;$k++){
        if  ( $tmp[jobParam] == $killage[$k][jobParam] ){
            $tmp[kille] =  $killage[$k][1];// $killage[$k][1] = $killage[$k][count(*)]
            //echo "ahhh..1....".$tmp[jobParam]."..2....".$killage[$k][jobParam]."..</br>" ;
            break;
		}
    }
    array_push($reponse ,$tmp );
}

$smarty->assign('nb_total', $nb_total);
$smarty->assign('reponse1', $reponse);
$smarty->assign('nb_ligne1', $nb_ligne);
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


//echo "</font>";

mysql_close($link);

$smarty->display('jobs_termines_details.tpl');

?>
