  			<table width = "592" height="467" border >
					<!--592 = 80%*740 et 467=85%*550-->
					<!--case du sous menu-->

					<tr>

							{if $title1== "presentation"}
								<td height ="25">
								<a href="../stats_presentation/stats_presentation.php">
								<font size="2" color="#9999CC"><center>Presentation</center></font></a>
								</td>
							{else}
								<td height ="25"  bgcolor="#9999CC">
								<a href="../stats_presentation/stats_presentation.php">
								<font size="2" color="#FFFFCC"><center>Presentation</center></font></a>
								</td>
							{/if}


							{if $title1== "grille"}
								<td>
								<a href="../stats_grille/stats_grille.php"><font size="2" color="#9999CC"><center>Grid Stats</center></font></a>
								</td>
							{else}
								<td  bgcolor="#9999CC">
								<a href="../stats_grille/stats_grille.php"><font size="2" color="#FFFFCC"><center>Grid Stats</center></font></a>
								</td>
							{/if}


							{if $title1== "cluster"}
								<td >
								<a href="../stats_clusters/stats_clusters.php"><font size="2" color="#9999CC"><center>Cluster Stats </center></font></a>
								</td>
							{else}
								<td bgcolor="#9999CC">
								<a href="../stats_clusters/stats_clusters.php"><font size="2" color="#FFFFCC"><center>Cluster Stats </center></font></a>
								</td>
							{/if}


							


					</tr>

					<tr>
						<td colspan="4" >
