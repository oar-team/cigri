{include file="header.tpl" title1= "modifications on  parameters" title2= "CURRENT JOBS"}

	<!--case centrale -->

	<td bgcolor="#FFFFFF">

				<!--partie suppression-->
				{if $bouton=="frag"}

				<!--MultiJob-->
							<center><h1>Deletion of the MultiJob{$ID}</h1></center>
							<p align="right"><a href ="jobs_en_cours.php?ID={$ID}"> return to current jobs</a></p>
							</br>
							</br>
							</br>
							<center><h4>Are you sure to want to kill this Multijobs? </h4></center>

							</br>
							</br>
							</br>
							</br>


							<center>
								<table    cellspacing="2" cellspading="50" width ="70%">
									<tr>
										<td>
											<center>
											<form method="post" action="jobs_en_cours_supprimer.php" >
											<input type="hidden" name="ID"  value="{$ID}">
											<input name="bouton" type="submit" value="YES">
											</form>
											</center>
										</td>
										<td>
											<center>
											<form method="post" action="jobs_en_cours.php">
											<input type="hidden" name="ID"  value="{$ID}">
											<input name="bouton" type="submit" value="NO">
											</form>
											</center>
										</td>
									</tr>
								</table>
							</center>
							</br>
							</br>
							</br>

				{elseif $bouton == "YES"}
				<!--MultiJob-->
							</br>
							</br>
							</br>
							<h1>Multijobs eliminated</h1>
							<a href="jobs_en_cours.php?ID={$ID}">return</a>
							</br>
							</br>
							</br>




				{elseif $bouton == "frag2"}
				<!--parametres d'un MultiJob-->

							<center><h1>deletion of parameters of the  MultiJob{$ID}</h1></center>
							<p align="right">
								<a href ="jobs_en_cours_details_parametres_en_cours.php?ID={$ID}">return to parameters in course of execution</a>
							</p>
							</br>
							</br>
							</br>
							<center><h4> Are you sure to want to kill thoses parameters?</h4></center>

							</br>
							</br>
							</br>
							</br>
							{ if $nb_param_a_sup == 0}
								<center>
								<h4><font color="#FF0000"> You have not choose parameters to kill! </font></h4>
								</center>
							{else}

								<center>
								<table   border  bordercolor="#9999CC" cellspacing="2" cellspading="50" width =" 100%">
									<form method="post" action="jobs_en_cours_supprimer.php" >
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
												<input name="bouton2" type="submit" value="YES">
												<input type="hidden" name="str"  value="{$str_sup}">
												<input type="hidden" name="ID"  value="{$ID}">
											</form>
											</center>
										</td>

										<td>
											<center>
											<form method="post" action="jobs_en_cours_details_parametres_en_cours.php">
											<input type="hidden" name="ID"  value="{$ID}">
											<input name="bouton2" type="submit" value="NO">
											</form>
											</center>
										</td>
									</tr>
								</table>
								</center>
							{/if}

				{elseif $bouton =="YES2"}
					<!--parametres d'un MultiJob-->
							</br>
							</br>
							</br>
							<h1>parameters if the  multijobs {$ID} eliminated</h1>

								<table   cellspacing="2" cellspading="50" width =" 100%">
									{section name=i loop=$tablo_suppression}
									<tr >
										<td colspan="2" >
											<center>
											{$tablo_suppression[i]}
											</center>
										</td>

					       				</tr>
									{/section}
								</table>
								<a href = "jobs_en_cours_details_parametres_en_cours.php?ID={$ID}">return</a>

							</br>

							</br>
							</br>


				{else}</br></br></br></br></br>
					PROBLEME PLEASE CONTACT THE WEBMASTER</br></br></br></br></br>
				{/if}




							</br>
							</br>
							</br>
							</br>






{include file="../../../../foot.tpl" }
