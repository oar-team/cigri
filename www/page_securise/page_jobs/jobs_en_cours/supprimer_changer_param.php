
<?php
    include "../../../functions.inc";
    define('SMARTY_DIR','../../../Smarty-2.5.0/libs/');
    require(SMARTY_DIR.'Smarty.class.php'); // On charge SMARTY
    $smarty = new Smarty; // On crée un objet SMARTY
    $login = $REMOTE_USER;


echo"<font color=\"FF0000\">";
  //  foreach ($HTTP_POST_VARS as $key => $value) {echo $key. " - " ;var_dump ($value) ; echo  " <br>" ;}



if ($bouton =="frag"){
   // transformation du tablo en string pour le faire passer dans url
   $nb_param_a_sup = count($checkbox);
    if ( $nb_param_a_sup!=0){
   	$str_sup = implode("|", $checkbox);//ce qui est transmis
	//affichage compatible avec le html
	 for($i=0; $i <$nb_param_a_sup;$i++){
     		$checkbox[$i] = htmlentities($checkbox[$i]) ;
   	  }
   	$smarty->assign('str_sup', $str_sup);
   	$smarty->assign('tablo_suppression', $checkbox);
   }
   $smarty->assign('nb_param_a_sup', $nb_param_a_sup);
}


else if ($bouton =="change priority"){
 // transformation du tablo en string pour le faire passer dans url
   $nb_param_a_changer = count($checkbox);
	if ( $nb_param_a_changer !=0){
   		$str_ch=implode("|", $checkbox);
   		$smarty->assign('str_ch', $str_ch);


//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! A FAIRE..........................................................................
		// recupere les priorite des parametres pour les afficher
		//$link = dbconnect();
		//$query_tab = "
	    	//select  parametersParam  , parametersPriority , parametersMJobsId
    	    	//from  parameters, multipleJobs
    	    	//where   MJobsUser='$login'
    	    	//and MJobsId ='$ID'
    	    	//and parametersMJobsId= MJobsId
		//";
		//list($result,$result_nb) = sql_query($query_tab);
   	 	//mysql_close($link);
		for($i=0;$i<$nb_param_a_changer;$i++){
			//for($j=0;$j<$result_nb;$j++){
				//if( $result[$j][parametersParam] == $checkbox[$i]){
					//$tab_prio[$i] =$result[$j][parametersPriority];
					//break;
				//}
			$tab_prio[$i] =10;//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ligne a changer remplacer par les bonnes valeurs..........................................................................
			}
		//}


		//affichage compatible avec le html
	 	for($i=0; $i <$nb_param_a_changer;$i++){
     			$checkbox[$i] = htmlentities($checkbox[$i]) ;
   	  	}
   		$smarty->assign('tablo_changer', $checkbox);
   		$smarty->assign('tab_prio',$tab_prio );
	}
   	$smarty->assign('nb_param_a_changer', $nb_param_a_changer);
}

else{
	$bouton = "autre";
}

if ($bouton2 =="YES"){
	//suppression des parametres
	//$str est la traduction du tablo des casees cochées  en string et $tablo_valeur_supprimer est sa reconversion en tablo

	//echo "on est dans suppression de parametre et on a appuier sur oui, voici le tablo qu'on a";
	$tab_temp=explode("|", $str);
 	$i=0;
 	while(list(,$v)=each($tab_temp)) {
 	$tablo_valeur_supprimer[$i]=$v;
 	$i++;
 	}



	// suppression des parametres demandé
	$link = dbconnect();
	// on verifie que l'id du job correspond bien à un job de l'utilisateur

	$verif = "
	    select  *
    	    from  multipleJobs
    	    where   MJobsUser='$login'
    	    and MJobsId ='$ID'";
	  list($result_verif,$verif_nb) = sql_query($verif);
echo $verif_nb;
	if ( $verif_nb != 0){
		//echo "suppression ok";
		for ($j=0; $j<$i ;$j++){
		//echo $tablo_valeur_supprimer[$j];
		$sup=
		"delete from parameters
		where parametersParam ='$tablo_valeur_supprimer[$j]'
		and parametersMJobsId = $ID";
		$result = mysql_query($sup);
	//echo $sup;
	}
	}
	else{echo " pb suppression";}
   	 mysql_close($link);
	 $smarty->assign('verif_nb', $verif_nb);
	}

else if($bouton2 =="ok"){
	//modification de la priorité
	//$str est la traduction du tablo des casees cochées  en string et $tablo_valeur_changer est sa reconversion en tablo
	//echo "on est dans modification de priorité et on a appuier sur ok, voici le tablo qu'on a</br>";
	$prio_ok = 1;
	//$priorité est le tablo des valeur entrer dans le formulaire avec les priorité mé prend en compte mem les champ vide
	$nb_prio= count($priorite);
	//ce tablo contient les parametre correspondant au priorité a changer
	$tab_temp=explode("|", $str);
	//initilisation des variabkle de parcours de tablo
	$i=0;
	$k=0;

	$link = dbconnect();
	$verif = "
	    select *
    	    from  multipleJobs
    	    where   MJobsUser='$login'
    	    and MJobsId ='$ID'";
	  list($result_verif,$verif_nb) = sql_query($verif);

	if ( $verif_nb != 0){
	//echo "on va changer les parametres";

		// on rempli tablo_valeur_changer avec la vameur des parametre auquel on doi changer la priorité
 		while(list(,$v)=each($tab_temp)) {
 			$tablo_valeur_changer[$i]=$v;
 			$i++;
 		}

		//on vide tablo_prio au cas ou il y est l'erreur plusieurs fois tablo prio contiendra les valeurs a reafficher pour changer leur priorité
  		 unset($tablo_prio) ; $tablo_prio = array() ;

		// on parcours le tablo avec les priorité
		for ($j=0; $j<$nb_prio ;$j++){
			$est_un_nombre = verif_nombre($priorite[$j]);
			// on ne tien compte que des priorité qui sont des nombre(dc on ecarte les autre caractere et les champs vide
			if (!$est_un_nombre || $priorite[$j]==""){

				$prio_ok = 0;
				$tablo_prio[$k]=  $tablo_valeur_changer[$j];
				$k ++;
				}
			else{//faire changement => requete sql

  				 $requete="
					update parameters
					set  parametersPriority = $priorite[$j]
					where  parametersParam = '$tablo_valeur_changer[$j]'
					and parametersMJobsId = $ID";
				mysql_query($requete);


				}
		}



		// on va reafficher les parametre ou il a été entrer des mauvaise priorité
		if ($prio_ok == 0){

			$nb_param_a_changer = count($tablo_prio);
				if ( $nb_param_a_changer !=0){
   					$str_ch=implode("|", $tablo_prio);
   					$smarty->assign('str_ch', $str_ch);

					//print_r($tablo_valeur_changer2);



					$query_tab = "
	    				select  parametersParam  , parametersPriority , parametersMJobsId
    	    				from  parameters, multipleJobs
    	    				where   MJobsUser='$login'
    		    			and MJobsId ='$ID'
    		    			and parametersMJobsId= MJobsId
					";
					list($result,$result_nb) = sql_query($query_tab);
					for($i=0;$i<$nb_param_a_changer;$i++){
						for($j=0;$j<$result_nb;$j++){
							if( $result[$j][parametersParam] == $tablo_prio[$i]){
								$tab_prio[$i] =$result[$j][parametersPriority];
								break;
							}
						}
					}
			//tablo contenant les priorites des parametres contenu dans tablo_prio
   			$smarty->assign('tab_prio',$tab_prio );
			//tablo contenant les parametres
			$smarty->assign('tablo_prio', $tablo_prio);
			}
		}
	}
	mysql_close($link);
	$smarty->assign('prio_ok', $prio_ok);
	$smarty->assign('verif_nb', $verif_nb);
}

   $smarty->assign('bouton', $bouton);
   $smarty->assign('bouton2', $bouton2);
   $smarty->assign('ID', $ID);
//echo"</font>";
   $smarty->display('supprimer_changer_param.tpl');


?>
