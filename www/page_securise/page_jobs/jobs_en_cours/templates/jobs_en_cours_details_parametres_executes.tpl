{include file="header.tpl" title1= "details of the current parameters (executed parameters )" title2= "CURRENT JOBS"}

<!--<td bgcolor="#FFFFFF">-->
{include file="sous_menu.tpl" title1= "executes"  ID="$ID"}



							your login: {$login}
							<a href="jobs_en_cours.php"><font size="2"><p align ="right">return to Multijobs pages</p></font></a>
							<center><h1> Details of the Multijobs {$ID} </h1></center>
							</br>
							<center><h1> Executed Parameters  </h1></center>
							</br>
							<!--
							-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
							-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
							-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
							-->

						{if $nb_total > 100}
								<!--nombre de job par page-->
								<form method="post" action="jobs_en_cours_details_parametres_executes.php">

								<table border bordercolor="#9999CC" cellspacing="1">
									<tr>
										<td>
											Number of jobs by page
										</td>
										<td>

 											<select name="nb_jobs">
												{if  $nb_jobs== "100"} <option value="100"selected> {else}<option value="100"> {/if}100
												{if  $nb_jobs== "200"} <option value="200"selected> {else}<option value="200"> {/if}200
												{if  $nb_jobs== "500"} <option value="500"selected> {else}<option value="500"> {/if}500
												{if  $nb_jobs== "1000"} <option value="1000"selected> {else}<option value="1000"> {/if}1000
											</select>
											<!--contient toute les valeurs dont on a besoin dans le php-->
										</td>

										<td></td>

									</tr>


									<tr>
										<td>
											primary key
										</td>
										<td>
											<select name="cleprimaire">
												{if $cleprimaire == "jobId"} <option value="jobId" selected >
												{else}<option value="jobId"  >
												{/if}job Id
												{if $cleprimaire == "jobTStart"} <option value="jobTStart" selected >
												{else}<option value="jobTStart"  >
												{/if}job Start
												{if $cleprimaire == "jobTStop"} <option value="jobTStop" selected >
												{else}<option value="jobTStop"  >
												{/if}job Stop
												{if $cleprimaire == "jobParam"} <option value="jobParam" selected >
												{else}<option value="jobParam"  >
												{/if}job Param
 											</select>
										</td>
										<td>
											{if  $sensprim== "croissant"} <input type="radio" name="sensprim" value="croissant" checked>
											{else}  <input type="radio" name="sensprim" value="croissant" >
											{/if} increasing
											</br>
											{if  $sensprim== "decroissant"} <input type="radio" name="sensprim" value="decroissant" checked>
											{else}  <input type="radio" name="sensprim" value="decroissant" >
											{/if} decreasing
										</td>
									</tr>


									<tr>
										<td>
											secondary key
										</td>

										<td>
 											<select name="clesecondaire">
												{if  $clesecondaire== "null"} <option value="null" selected >
												{else}<option value="null"  >
												{/if} null
												{if  $clesecondaire== "jobId"} <option value="jobId" selected >
												{else}<option value="jobId"  >
												{/if}job Id
												{if  $clesecondaire== "jobTStart"} <option value="jobTStart" selected >
												{else}<option value="jobTStart"  >
												{/if}job Start
												{if  $clesecondaire== "jobTStop"} <option value="jobTStop" selected >
												{else}<option value="jobTStop"  >
												{/if}job Stop
												{if  $clesecondaire== "jobParam"} <option value="jobParam" selected >
												{else}<option value="jobParam"  >
												{/if}job Param
											</select>
										</td>

										<td>
											{if  $senssecond== "croissant"} <input type="radio" name="senssecond" value="croissant" checked>
											{else}  <input type="radio" name="senssecond" value="croissant" >
											{/if} increasing
											</br>
											{if  $senssecond== "decroissant"} <input type="radio" name="senssecond" value="decroissant" checked>
											{else}  <input type="radio" name="senssecond" value="decroissant" >
											{/if} decreasing
										</td>
									</tr>

									<tr>
										<td colspan="3">
											<center><input type="submit"  name="valid" value="valid"></center>
											<input type="hidden"  name="page_courante" value="{$page_courante}">
											<input type="hidden"  name="ID" value="{$ID}">
										</td>
									</tr>
								</table>
							</form>



							</br>
							</br>
							</br>
							</br>


							<form method="post" action="jobs_en_cours_details_parametres_executes.php">
								<table  width = "100%">
									<tr>

										<td >
											{if $page_courante != 1} <input type="submit"  name="page" value="< PREV"> {/if}
										</td>

										<td>
											<center>
 												pages:
												<select name="pge">
													{section name=i loop=$pages}
														{if ($page_courante) == $pages[i]}
 															<option value="{$pages[i]}"selected>{$pages[i]}
														{else}
															<option value="{$pages[i]}">{$pages[i]}
														{/if}
													{/section}
 												</select>

												<input type="submit"  name="valid" value="ok">
											</center>
										</td>
										<td>
											{if $page_courante != $nb_page}
												<p align="right"> <input type="submit"  name="page" value="NEXT >"> </p>
											{/if}
										</td>
									</tr>
								</table>
	 							<input type="hidden"  name="page_courante" value="{$page_courante}">
								<input type="hidden"  name="ID" value="{$ID}">
								<input type="hidden"  name="nb_jobs" value="{$nb_jobs}">
								<input type="hidden"  name="cleprimaire" value="{$cleprimaire}">
								<input type="hidden"  name="clesecondaire" value="{$clesecondaire}">
								<input type="hidden"  name="sensprim" value="{$sensprim}">
								<input type="hidden"  name="senssecond" value="{$senssecond}">
							</form>


					{elseif $nb_total != 0 && $nb_total != 1}
					<!--il y a moins de 100 lignes dans le tablo mais il faut aussi prevoir les changement d'ordre de tri -->

							<form method="post" action="jobs_en_cours_details_parametres_executes.php">
								<table border bordercolor="#9999CC" cellspacing="1">

									<tr>
										<td>
											primary key
										</td>
										<td>
											<select name="cleprimaire">
												{if $cleprimaire == "jobId"} <option value="jobId" selected >
												{else}<option value="jobId"  >
												{/if}job Id
												{if $cleprimaire == "jobTStart"} <option value="jobTStart" selected >
												{else}<option value="jobTStart"  >
												{/if}job Start
												{if $cleprimaire == "jobTStop"} <option value="jobTStop" selected >
												{else}<option value="jobTStop"  >
												{/if}job Stop
												{if $cleprimaire == "jobParam"} <option value="jobParam" selected >
												{else}<option value="jobParam"  >
												{/if}job Param
											</select>
										</td>

										<td>
											{if  $sensprim== "croissant"} <input type="radio" name="sensprim" value="croissant" checked>
											{else}  <input type="radio" name="sensprim" value="croissant" >
											{/if} increasing
											</br>
											{if  $sensprim== "decroissant"} <input type="radio" name="sensprim" value="decroissant" checked>
											{else}  <input type="radio" name="sensprim" value="decroissant" >
											{/if} decreasing
										</td>
									</tr>


									<tr>
										<td>
											secondary key
										</td>

										<td>
 											<select name="clesecondaire">
												{if  $clesecondaire== "null"} <option value="null" selected >
												{else}<option value="null"  >
												{/if} null
												{if  $clesecondaire== "jobId"} <option value="jobId" selected >
												{else}<option value="jobId"  >
												{/if}job Id
												{if  $clesecondaire== "jobTStart"} <option value="jobTStart" selected >
												{else}<option value="jobTStart"  >
												{/if}job Start
												{if  $clesecondaire== "jobTStop"} <option value="jobTStop" selected >
												{else}<option value="jobTStop"  >
												{/if}job Stop
												{if  $clesecondaire== "jobParam"} <option value="jobParam" selected >
												{else}<option value="jobParam"  >
												{/if}job Param
  											</select>
										</td>

										<td>
											{if  $senssecond== "croissant"} <input type="radio" name="senssecond" value="croissant" checked>
											{else}  <input type="radio" name="senssecond" value="croissant" >
											{/if} increasing
											</br>
											{if  $senssecond== "decroissant"} <input type="radio" name="senssecond" value="decroissant" checked>
											{else}  <input type="radio" name="senssecond" value="decroissant" >
											{/if} decreasing
										</td>
									</tr>

									<tr>
										<td colspan="3">
											<center><input type="submit"  name="valid" value="valid"></center>
											<input type="hidden"  name="ID" value="{$ID}">
											<input type="hidden"  name="nb_jobs" value="100">
										</td>
									</tr>
								</table>
	 						</form>
					{/if}
					<!--
					--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
					---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
					--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
					-->





							</br>
							the number of executed parameters : {$nb_total}
							</br>
							</br>

							{if $nb_ligne1 != 0 }
								<table border="1" cellspacing="0" cellpadding="0">
						 			<tr>

										<td bgcolor ="#FFFFCC">job Id</td>
										<td bgcolor ="#FFFFCC">Job Start</td>
										<td bgcolor ="#FFFFCC">Job Stop</td>
										<td bgcolor ="#FFFFCC">Job Param</td>
									</tr>
     									{section name=i loop=$reponse1}
									<tr>

										<td>{$reponse1[i].jobId }</td>
										<td>{$reponse1[i].jobTStart}</td>
										<td>{$reponse1[i].jobTStop}</td>
										<td>{$reponse1[i].jobParam}</td>

					       				</tr>
									{/section}
								</table>
							{else}
								</br></br></br></br></br></br>
								<H1>THERE IS NO EXECUTED PARAMETER</H1>
								</br></br></br></br></br></br>
							{/if}
							</br>

							</br>
							</br>
							</br>


								<!--
								------------------------------------------------------------------------------------------------------------------------------------------------------------------------
								--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
								--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
								-->
								{if $nb_total > 100}
											 pages :
											 {section name=i loop=$pages}

 												<a Href= "jobs_en_cours_details_parametres_executes.php?ID={$ID}&page_courante={$pages[i]}&nb_jobs={$nb_jobs}&cleprimaire={$cleprimaire}&clesecondaire={$clesecondaire}&sensprim={$sensprim}&senssecond={$senssecond}&clic=1">
												{if $page_courante == $pages[i]}
													<font color="#FF0000">	{$pages[i]}</font></a>
												{else}
													{$pages[i]}</a>
												{/if}

											  {/section}

								{/if}
								<!--
								-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
								-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
								-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
								-->

{include file="foot_sous_menu.tpl" }
{include file="../../../../foot.tpl" }
