{include file="header.tpl" title1= "parameters modifications" title2= "CURRENT JOBS"}
{include file="sous_menu.tpl" attente="oui" ID="$ID"}
						<!--case centrale -->
						</br>
						<center><h1>Modification of the parameters of the MultiJob{$ID} </h1></center>
						</br>
						</br>

						<p align="right"><a href ="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}"> return to waiting jobs</a></p>
</br>
</br>

						<!--partie suppression-->
						{if $bouton == "frag"}
							</br>
							</br>
							</br>
							<center><h4>Are you sure to want to kill these parameters? </h4></center>

							</br>
							</br>

							{ if $nb_param_a_sup == 0}
								<center>
								<h4><font color="#FF0000">You have not choose parameters to be killed!  </font></h4>
								</center>
							{else}

								<center>
								<table   border bordercolor = "#9999CC" cellspacing="2" cellspading="50" width =" 100%">
									{section name=i loop=$tablo_suppression}
									<tr >
										<td colspan="2" >
											<center>
											{$tablo_suppression[i]}
											</center>
										</td>


					       				</tr>
									{/section}
									<tr>
										<td>
											<center>
											<form method="post" action="supprimer_changer_param.php?
											ID={$ID}&str={$str_sup}" >
											<input name="bouton2" type="submit" value="YES">
											</form>
											</center>
										</td>
										<td>
											<center>
											<form method="post" action="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}">
											<input name="bouton" type="submit" value="NO">
											</form>
											</center>
										</td>
									</tr>
								</table>
								</center>

							{/if}


							</br>
							</br>
							</br>
							</br>
							</br>
							</br>
							</br>



						<!--changement de priorité entrée des valeur de priorité-->
						{elseif $bouton == "change priority"}

							</br>
							</br>
							</br>
							</br>

							{ if $nb_param_a_changer == 0}
								<center>
								<h4><font color="#FF0000">You have not choose parameters to be changed! </font></h4>
								</center>
							{else}
								<center>
								<table   border bordercolor = "#9999CC" cellspacing="1" cellspading="50" width =" 100%">
									<tr>
										<td>ParamtersParam</td>
										<td>Priorité</td>
									</tr>

									{section name=i loop=$tablo_changer}
									<tr>
										<td>{$tablo_changer[i]}</td>
										<td>

											<form method="post"action="supprimer_changer_param.php?
											ID={$ID}&str={$str_ch}" >
											<input type="text" name="priorite[]" value="{$tab_prio[i]}" maxlength="4">
										</td>

					       				</tr>
									{/section}
									<tr>
										<td>
											<input name="bouton2" type="submit" value="ok">
											</form>
										</td>
										<td>
											<form method="post" action="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}">
											<input name="bouton" type="submit" value="cancelled">
											</form>
										</td>
									</tr>
								</table>
								</center>


							{/if}
						<!--on appuier sur ok pour la suppression de paramètres-->
						{elseif $bouton2 =="YES"}

							</br>
							</br>
							</br>
							</br>
								{if  $verif_nb != 0}

									<center><h4><font color="#FF0000"> parameters eliminated </font></h4></center>
									</br></br></br></br>
								{else}

									<center><h4><font color="#FF0000"> You did not authorize to modify these parameters</font></h4></center>
									</br></br></br></br>
								{/if}
							</br></br></br></br>


						<!--partie changement des parametres et on a appuier sur ok-->
						{elseif $bouton2 =="ok"}

							</br>
							</br>
							</br>
							</br>

								<!--toute les données entrées dans les champs priorité sont ok-->
								{if  $verif_nb != 0}

									{if $prio_ok == 1 }

										<center><h4><font color="#FF0000"> priority changed </font></h4></center>
										</br></br></br></br>


									<!--on reaffiche le tablo avec les parametre ou les priorités rentrées ne sont pas des nombres ou alors le champs est vide-->
									{elseif $prio_ok == 0}
										</br></br>
										<h4><font color="#FF0000">WRONG priority. </br> Please try again </font></h4>
										<center>

										<table   border bordercolor = "#9999CC" cellspacing="2" cellspading="50" width =" 100%">
											<tr>
												<td>ParamtersParam</td>
												<td>Priority</td>
											</tr>

											{section name=i loop=$tablo_prio}
											<tr>
												<td>{$tablo_prio[i]}</td>
												<td>

													<form method="post"action="supprimer_changer_param.php?
													ID={$ID}&str={$str_ch}" >
													<input type="text" name="priorite[]" value ="{$tab_prio[i]}"maxlength="4">
												</td>

					       						</tr>
											{/section}
											<tr>
												<td>
													<input name="bouton2" type="submit" value="ok">
													</form>
												</td>
												<td>
													<form method="post" action="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}">
													<input name="bouton" type="submit" value="CANCELLED">
													</form>
												</td>
											</tr>
										</table>
										<center>
									{/if}
								{else}
									<center><h4><font color="#FF0000"> </font> You did not authorize to modify these paramaters</h4></center>
								{/if}


						{/if}
</br>
</br>
</br>
</br>
</br>
						<p align="right"><a href ="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}"> return to waiting jobs</a></p>
{include file="foot_sous_menu.tpl" }
{include file="../../../../foot.tpl" }
