<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty;
$login = $REMOTE_USER;
$smarty->assign('login',$login );


echo "<font color=\"#FF0000\">";
echo "</br>ce qui a dans la variable bouton:  ";
echo $bouton;
echo "</br>";
echo $bouton2;
echo "</br>ID".$ID;


if ($bouton=="frag"){
    // on veut supprimer un multijobs
    echo "</br>on supprime un multiple jobs  avec pour ID :".$ID;
}

if ($bouton=="YES"){
    $link = dbconnect();
    // on verifie que l'utilisateur a bien le droite de modifier les parametres
    $verif = "  select  *
                from  multipleJobs
                where   MJobsUser='$login'
                and MJobsId ='$ID'";
    list($result_verif,$verif_nb) = sql_query($verif);

    echo "verif :".$verif;echo "</br>ID".$ID;

    if ( $verif_nb!= 0){
        $query = "  update multipleJobs
                    set MJobsFrag ='YES'
                    where MJobsId ='$ID'";
        $result = mysql_query($query);

        echo "</br>youhou query :".$query;
    }

    mysql_close($link);
    // on veut supprimer un multijobs et on a validé
    echo "</br>on supprime le multijobs".$ID;
    //faire requete
}

if ($bouton2=="frag"){
    // on veut supprimer des parametres d'un multijobs
    $bouton="frag2";

    $nb_param_a_sup = count($checkbox);
    if ( $nb_param_a_sup!=0){
        $str_sup = implode("|", $checkbox);
        $smarty->assign('str_sup', $str_sup);
        $smarty->assign('tablo_suppression', $checkbox);
    }
    $smarty->assign('nb_param_a_sup', $nb_param_a_sup);
}

if ($bouton2=="YES"){ // on veut supprimer des parametres d'un multijobs et on a valider
    $bouton="YES2";

    //suppression des parametres
    //$str est la traduction du tablo des casees cochées  en string et $tablo_valeur_supprimer est sa reconversion en tablo
    //echo "on est dans suppression de parametre et on a appuier sur oui, voici le tablo qu'on a";
    $tab_temp=explode("|", $str);
    $i=0;
    while(list(,$v)=each($tab_temp)) {
        $tablo_valeur_supprimer[$i]=$v;
        $i++;
    }
    //suppression des parametres

    $link = dbconnect();
    // on verifie que l'id du job correspond bien à un job de l'utilisateur
    $verif = "
        select  *
        from  multipleJobs
        where   MJobsUser='$login'
        and MJobsId ='$ID'";
    list($result_verif,$verif_nb) = sql_query($verif);

    if ( $verif_nb!= 0){
        echo "suppression ok";
        for ($j=0; $j<$i ;$j++){
            //echo $tablo_valeur_supprimer[$j];
            $sup=
                "update jobs
                set jobFrag = 'YES'
                where jobId ='$tablo_valeur_supprimer[$j]'
            ";
            $result = mysql_query($sup);
            echo "</br>query :".$sup;
        }
    }else{
        echo " pb suppression";
    }

 mysql_close($link);

 $smarty->assign('verif_nb', $verif_nb);

}

echo "</font>";

$smarty->assign('ID', $ID);
$smarty->assign('bouton', $bouton);

// $link = dbconnect();

    //$query =
    //"select  *
   // from multipleJobs
   // where MJobsUser = '$login'
  //  and MJobsState ='IN_TREATMENT'";




   // list($reponse2,$nb_total) = sql_query($query);
    //$smarty->assign('param', array("MJobsId", "MJobsTSub","MJobsName","youhou","blabla"));
   // mysql_close($link);
$smarty->display('jobs_en_cours_supprimer.tpl');

?>
