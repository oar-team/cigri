{include file="header.tpl" title1= "add parameters" title2= "CURRENT JOBS  "}
{include file="sous_menu.tpl" attente="oui" ID="$ID"}




						</br>
						</br>
						<center><h2>Enter the characteristics of the parameter you want to add</h2></center>
						<a href="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}"><font size="2"><p align = "right">return </p></font></a>
						your login: {$login}
						</br>
						Add to the job {$ID}
						</br>

						{if $insertion}
							<font color="#FF0000"><h4>Parameter added </h4></font>
						{/if}
						</br>

						<center>
							<table  width = "500" cellspacing="0" cellpadding="20">
								<tr><!--case Parametersparametre-->

									<form method="post" action="ajouter_param.php?ID={$ID}" >

									<td bgcolor="#9999CC">
										<center>

											{if $bouton2 == "add" &&  $parametersParam == ""}
											<!-- on a appuier mé le champs parameters param est vide-->
										        	<h4><font color="#FFFFCC">Parametersparam : </font ></h4><input type="text" name="parametersParam" size="50" maxlength="1024" >
												</br><font color="#CCFFCC"><h3> WRONG parameter </h3></font >
											{elseif $bouton2 == "add" &&  $dejala == 1 }
												<!-- on a appuier mé le parametersparam existe deja-->
										        	<h4><font color="#FFFFCC">Parametersparam : </font ></h4><input type="text" name="parametersParam" size="50" maxlength="1024" >
												</br><font color="#CCFFCC"> <h3>parameter already present</h3> </font >

											{elseif ($bouton2 == "add" &&  $parametersParam != ""&& $priorite == "") || ($bouton2 == "add" &&  $parametersParam != ""&& !$est_un_nombre)}
											<!--on a appuiyé sur le bouton valider alors qu'il manque la champs priorité (ou la valeur entré dans le champs priorité n'est pas un nombre->$est_un_nombre)
											alors garde dans le champs la valeur de numparam-->
												<h4><font color="#FFFFCC">Parametersparam : </font ></h4><input type="text" name="parametersParam" size="50" maxlength="1024" value = "{$parametersParam}">
												</br></br>

											{else}
											<!--cas de l'arrivée ou on a pa encore appuier sur le bouton ajouter sur cette page-->
												<h4><font color="#FFFFCC">Parametersparam : </font ></h4><input type="text" name="parametersParam" size="50" maxlength="1024" >
												</br></br>

											{/if}
										</center>

									</td>
									<td>
										<!--case vide pour coherence avec la case du bouton fin-->
									</td>

								</tr>



								<tr><!--case de la priorité-->

									<td bgcolor="#9999CC" >
										<center>

											{if (($bouton2 == "add" && $priorite == "" ) || ($bouton2 == "add" && !$est_un_nombre ))}
												<h4><font color="#FFFFCC">Priority : </font ></h4><input type="text" name="priorite" size="4" maxlength="4" value ="0">
												</br><font color="#CCFFCC"><h3>WRONG parameter </h3></font >


											{elseif ($bouton2 == "add" &&  $parametersParam == "" && $priorite != "" &&  $est_un_nombre) || ($bouton2 == "add" &&  $dejala && $priorite != "" &&  $est_un_nombre)}
												<h4><font color="#FFFFCC">Priority : </font ></h4><input type="text" name="priorite" size="4" maxlength="4"  value = "{$priorite}">
												</br></br>


											{else}
												<h4><font color="#FFFFCC">Priority : </font ></h4><input type="text" name="priorite" size="4" maxlength="4" value ="0" >
												</br></br>

											{/if}

										</center>

									</td>
									<td></td>

								</tr>

								<tr>
									<td>
										<center>
											<input name="bouton2" type="submit" value="add">
											</form>
									</td>
									<td>
											<form method="post" action="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}" >
											<input name="bouton" type="submit" value="fin">
											</form>
										</center>
									</td>
								</tr>
						</table>
					</center>

</br></br></br></br>

						</br>
						</br>
						</br>
						</br>
						</br>


{include file="foot_sous_menu.tpl" }
{include file="../../../../foot.tpl" }
