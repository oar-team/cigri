{include file="header.tpl" title1= "repartition of the clusters" title2= "CLUSTER REPARTITION "}


				<center><h1> THE CLUSTERS</h1></center></br>

				</br>
				your login: {$login}
				</br>
				</br>

				</br>
				</br>
				{if $nb_ligne != 0 }
					<table border="1" cellspacing="0" cellpadding="0">
						 <tr>
							<td bgcolor ="#FFFFCC" width="5">cluster Name</td>
							<td bgcolor ="#FFFFCC">cluster Admin</td>
							<td bgcolor ="#FFFFCC">cluster Batch</td>
							<td bgcolor ="#FFFFCC"></td>
						</tr>

     						{section name=i loop=$reponse}
							<tr>
								<td>{$reponse[i].clusterName_aff}</td>
								<td>{$reponse[i].clusterAdmin}</td>
								<td>{$reponse[i].clusterBatch}</td>
								<td>
									<form method="post" action="repartition_cluster_details.php">
 									<input type="submit" name="bidule" value="details">
 									<input type="hidden" name="clustername" value="{$reponse[i].clusterName}">
 									</form>
								</td>
							</tr>
						{/section}
					</table>
				{/if}


				</br>



{include file="../../../../foot.tpl"}

