<?php

include "../../../functions.inc";
define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
$smarty = new Smarty; // On crée un objet SMARTY
$login = $REMOTE_USER;
$insertion=0;

if ($bouton2 =="add"){
 	//on regarde si la priorité est bien un nombre
    $est_un_nombre = verif_nombre($priorite);

    if ($est_un_nombre &&$parametersParam !="" &&  $priorite !="" ){
        $link = dbconnect();
        //on regarde si le num du parametre n'existe pa deja
        $query1 = " select  *
                    from  parameters
                    where  parametersParam= '$parametersParam' ";
        list($reponse1,$nb_ligne1) = sql_query($query1);
        $dejala=0;
        if($nb_ligne1 != 0){
            $dejala=1;
        }else{
            // insertion des parametres dans la bases
            $insert = " INSERT INTO parameters
                        ( parametersMJobsId, parametersParam, parametersPriority)
                        values ($ID,'$parametersParam',$priorite)";
            mysql_query($insert);
            $insertion=1;

            //verif que dans la table Multiple job le job est toujours en traitement
            $verif="update multipleJobs
                    set MJobsState = \"IN_TREATMENT\"
                    where MJobsId = $ID ";
            mysql_query($verif);
        }
        mysql_close($link);
	}
}

$smarty->assign('ID',$ID );
$smarty->assign('login',$login );
$smarty->assign('parametersParam', $parametersParam);
$smarty->assign('priorite', $priorite);
$smarty->assign('bouton2', $bouton2);
$smarty->assign('est_un_nombre', $est_un_nombre);
$smarty->assign('dejala',$dejala );
$smarty->assign('insertion',$insertion );

$smarty->display('ajouter_param.tpl');

?>
