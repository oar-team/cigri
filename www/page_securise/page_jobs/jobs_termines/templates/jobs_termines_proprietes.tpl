{include file="header.tpl" title1="finished job properties " title2="FINISHED JOBS "}


			        		your login: {$login}
						</br>
						<center><h1> Properties of the  Multijobs {$ID}  </h1></center>
						</br>
			        		<a href = "jobs_termines.php">  <p align="right">return</p></a>
						</br>
						</br>
						</br>
						</br>
						</br>
						</br>
						</br>
						<!--table contenant la requete-->
						{if $nb_ligne != 0}
							<table border="1" cellspacing="0" cellpadding="0">
					 			<tr>
									<td  bgcolor ="#FFFFCC">Cluster Name</td>
									<td  bgcolor ="#FFFFCC">Job Command</td>
									<td  bgcolor ="#FFFFCC">User Login</td>
								</tr>


     								{section name=i loop=$reponse}
								<tr>
									<td>{$reponse[i].propertiesClusterName}</td>
									<td>{$reponse[i].propertiesJobCmd}</td>
									<td>{$reponse[i].userLogin}</td>
								</tr>
								{/section}
							</table>
						{else}
							</br>
								no properties
							</br>
						{/if}

						</br>
						</br>
						</br>
						</br>
						</br>
						<a href = "jobs_termines.php">  <p align="right">return</p></a>
{include file="../../../../foot.tpl" }
