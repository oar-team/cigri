<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );

$link = dbconnect();

$query = "
select  count(*) as total
from  parameters, multipleJobs
where   MJobsUser='$login'
and MJobsId ='$ID'
and parametersMJobsId= MJobsId
";

list($reponse2,$nb) = sql_query($query);
$nb_total = $reponse2[0][total];
//echo "<font color=\"#00FF00\">";

$query = "  select  parametersParam  , parametersPriority , parametersMJobsId
            from  parameters, multipleJobs
            where   MJobsUser='$login'
            and MJobsId ='$ID'
            and parametersMJobsId= MJobsId";

list($reponse,$nb_ligne,$page_courante,$nb_jobs,$page_courante,$sensprim,$senssecond,$cleprimaire,$clesecondaire) = sortedQuery($query,$nb_jobs,$page_courante,$pge,$lim_inf,$valid,$page,$clic,$cleprimaire,$clesecondaire,$sensprim,$senssecond);

//			echo "</br>les variables:";
//			echo "</br>bouton : ".$valid.$page.$clic;
//			echo "</br> : nb_jobs : ".$nb_jobs;
//			echo "</br> : page_courante : ".$page_courante;
//			echo "</br> :clesecondaire  : ".$clesecondaire;
//			echo "</br> : cleprimaire : ".$cleprimaire;
//			echo "</br> : sensprim : ".$sensprim;
//			echo "</br> :senssecond :  ".$senssecond;
//			echo "</br> :lim_inf :  ".$lim_inf;


$nb_page=  ceil($nb_total/$nb_jobs); //ceil pren l'arrondi superieur
$pages=array(); for ($i=1;$i<=$nb_page;$i++){array_push($pages,$i);}// on met les pages dans un tablo pour le derouler dans un checkbox

//tableau qui contient le parametre et sa priorite entre parenthese pour permettre l'affichage des 2 en meme temps
$affichage=array();
for ($i=0;$i<=$nb_ligne-1;$i++){
    $temp = $reponse[$i]["parametersParam"]."(".$reponse[$i] ["parametersPriority"].")";
    array_push($affichage,$temp);
}
echo"</font>";

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

$reponse1 =array();
for($i=0; $i <$nb_ligne;$i++){
    $tmp=array(
        "parametersPriority_aff" => htmlentities($reponse[$i][parametersPriority]),
        "parametersParam_aff"    => htmlentities($reponse[$i][parametersParam]),
        "parametersPriority"     => $reponse[$i][parametersPriority],
        "parametersParam"        => $reponse[$i][parametersParam],
    );

    array_push($reponse1 ,$tmp );
}

$smarty->assign('nb_ligne1', $nb_ligne);
$smarty->assign('reponse1', $reponse1);
$smarty->assign('affichage', $affichage);
$smarty->assign('ID', $ID);

mysql_close($link);
$smarty->display('jobs_en_cours_details_parametres_en_attente.tpl');

?>
