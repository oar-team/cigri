{include file="header.tpl" title1="STATISTICS" title2="clusters stat"}
{include file="sous_menu.tpl" title1="clusters" }


							<h1> Clusters statistics page</h1>
							</br></br></br>





							{if $bouton == "ok"}

									{if $trogran == "ouhlala"} <font color="#FF0000"><h3> veuillez rentrer un intervalle inférieur à 24</h3></font>{/if}

									<form method="post"action="stats_clusters.php" >
									interval:
									<input type="text" name="intervalle" value="{$intervalle}" size="2" maxlength="2">hours
									<input type="submit" name="bouton" value="ok">
									</form>
									(max 24)
									</br>
									</br>
									</br>

									<img src= "graph.php?intervalle={$intervalle}" alt="graph">
							{else}

									<form method="post"action="stats_clusters.php" >
									interval:
									<input type="text" name="intervalle" value="12" size="2" maxlength="2">hours
									<input type="submit" name="bouton" value="ok">
									</form>
									(max 24)
									</br>
									</br>
									</br>
									<img src= "graph.php?intervalle=12" alt="graph">
							{/if}


							</br></br></br></br></br>



{include file="foot_sous_menu.tpl"}
{include file="../../../foot.tpl"}
