<?php

function dbconnect(){
    $link = mysql_connect("localhost", "cigri", "cigri")
        or die("Impossible de se connecter : " . mysql_error());
    mysql_select_db("cigri") or die( "Impossible de se connecter : " . mysql_error());
    return $link;
}

function sql_query($query){
    $nb_ligne=0;
    $result = mysql_query($query);
    $return_array = array();
    while ($row = mysql_fetch_array($result)) {
        $nb_ligne= array_push($return_array, $row);
    }
    mysql_free_result($result);
    return array ($return_array, $nb_ligne);
}

function sql_compter($query){
    $result = mysql_query($query);
    $nb = mysql_num_rows($result);
    mysql_free_result($result);
    return $nb;
}

function verif_nombre($texte){
    $symbole = "0123456789";
    $chaine_ok = true;
    for ($i=0;$i<strlen($texte);$i++) {
        if (!(eregi($texte[$i],$symbole))) $chaine_ok = false;
    }
    return $chaine_ok;
}

//construct the right query with sort directives and execute it
function sortedQuery($baseQuery,$nb_jobs,$page_courante,$pge,$lim_inf,$valid,$page,$clic,$cleprimaire,$clesecondaire,$sensprim,$senssecond){
    $query_tab ="";
    if ($valid == "valid" || $valid =="ok"|| $page == "NEXT >" || $page == "< PREV"|| $clic == "1") { // on a cliqué sur quelque choz

        if ($valid =="ok"){
            // on change de page
            $page_courante=$pge;
        }
        if ($valid =="valid"){
            // on reinitialise
            $page_courante=1;
        }
        if ($page == "NEXT >"){// on change de page
            $page_courante=$page_courante + 1;
        }
        if ($page == "< PREV"){// on change de page
            $page_courante=$page_courante - 1;
        }
///////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////
        if  ($clesecondaire!="null"){// on a donc une cle secondaire
            if ($sensprim == "croissant"){
                if($senssecond == "croissant"){
                    $lim_inf = ($page_courante-1) *$nb_jobs;
                    $query_tab = "  $baseQuery
                                   order by $cleprimaire asc ,  $clesecondaire asc
                                   limit $lim_inf, $nb_jobs";
                }else if($senssecond == "decroissant"){
                    $lim_inf = ($page_courante-1) *$nb_jobs;
                    $query_tab = "  $baseQuery
                                    order by $cleprimaire asc ,  $clesecondaire desc
                                    limit $lim_inf, $nb_jobs";
                }else{
                    echo "ya un probleme avec sens second";
                }
            }else if( $sensprim== "decroissant"){
                if($senssecond == "croissant"){
                    $lim_inf = ($page_courante-1) *$nb_jobs;
                    $query_tab = "  $baseQuery
                                    order by $cleprimaire desc ,  $clesecondaire asc
                                    limit $lim_inf, $nb_jobs";
                }else if($senssecond == "decroissant"){
                    $lim_inf = ($page_courante-1) *$nb_jobs;
                    $query_tab = "  $baseQuery
                                    order by $cleprimaire desc ,  $clesecondaire desc
                                    limit $lim_inf,$nb_jobs ";
                }else{
                    echo "ya un probleme av sens second";
                }
            }else{
                echo "ya un probleme av sens prim";
            }
        }else{// pa de clé secondaire
            if ($sensprim == "croissant") {
                $lim_inf = ($page_courante-1) *$nb_jobs;
                $query_tab = "  $baseQuery
                                order by $cleprimaire asc
                                limit $lim_inf, $nb_jobs";
            }else if( $sensprim== "decroissant"){
                $lim_inf = ($page_courante-1) *$nb_jobs;
                $query_tab = "  $baseQuery
                                order by $cleprimaire desc
                                limit $lim_inf, $nb_jobs";
            }else{
                echo "ya un probleme av sens prim";
            }
        }
    }else{ // page d'arrivé on a cliqué sur rien
        $page_courante=1;
        $nb_jobs=100;

        $cleprimaire = "null";
        $clesecondaire="null";
        $sensprim="croissant";
        $senssecond="croissant";

        $query_tab = "  $baseQuery
                        limit $nb_jobs";

        //echo "page d'arrivée";
    }

    if ($query_tab != ""){
        list($reponse,$nb_ligne) = sql_query($query_tab);
        return array ($reponse, $nb_ligne,$page_courante,$nb_jobs,$page_courante,$sensprim,$senssecond,$cleprimaire,$clesecondaire);
    }else{
        return null;
    }
}

?>
