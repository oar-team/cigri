{include file="header.tpl" title1= "properties of current jobs" title2= "CURRENT JOBS "}

			 <td bgcolor="#FFFFFF">
				your login: {$login}
				</br>
				<center><h1> Properties of the  jobs {$ID} </h1></center>

				</br>
				</br>
			        <a href = "jobs_en_cours.php">  <p align="right">return</p></a>
				</br>
				</br>
				</br>
				</br>
				</br>


				{if $nb_ligne1 != 0 }
					<table border="1" cellspacing="0" cellpadding="0">
						 <tr>
					 		<td bgcolor ="#FFFFCC">ClusterName</td>
					 		<td bgcolor ="#FFFFCC">JobCommand</td>
							 <td bgcolor ="#FFFFCC">userLogin</td>
							 <!--<td bgcolor ="#FFFFCC">Activated</td>-->
							 <td bgcolor ="#FFFFCC"></td>


						</tr>

     						{section name=i loop=$reponse1}
							<tr>
								<td>{$reponse1[i].propertiesClusterName_aff}</td>
								<td>{$reponse1[i].propertiesJobCmd}</td>
								<td>{$reponse1[i].userLogin}</td>
								<!--<td>{$reponse1[i].propertiesActivated}</td>-->

								{if $reponse1[i].propertiesActivated == "ON" }
								<td>
									<form method="post" action="jobs_en_cours_proprietes.php" >
									<input name="bout" type="submit" width="110" value="suspend">
									<input type="hidden" name="ID"  value="{$ID}">
									<input type="hidden"name="propertiesClusterName" value="{$reponse1[i].propertiesClusterName}">

									</form>
								</td>
								{elseif $reponse1[i].propertiesActivated == "OFF" }
								<td>
									<form method="post" action="jobs_en_cours_proprietes.php" >
									<input name="bout" type="submit" width="110" value="activate">
									<input type="hidden" name="ID"  value="{$ID}">
									<input type="hidden"name="propertiesClusterName" value="{$reponse1[i].propertiesClusterName}">

									</form>
								</td>
								{/if}

							 </tr>
				       		{/section}
					</table>
				{else}
					</br></br></br></br></br></br>
					<h1> PROBLEM NO CLUSTER
					</h1></br></br></br></br></br>
					</br>
				{/if}


				</br>
				</br>
				</br>

				</br>
				</br>
				<a href = "jobs_en_cours.php">  <p align="right">return</p></a>
{include file="../../../../foot.tpl" }
