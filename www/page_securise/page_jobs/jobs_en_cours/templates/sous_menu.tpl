     <td bgcolor="#FFFFFF">

     <table width = "592" height="467" border >
				<!--592 = 80%*740 et 467=85%*550-->
					<!--case du sous menu-->

					<tr>

     						{if $title1 == "executes"}
							<td height ="25">
							<a href="jobs_en_cours_details_parametres_executes.php?ID={$ID}"><font size="2" color="#9999CC"><center>
							Executed Parameters</center></font></a>
							</td>


						{else}
							<td height ="25"  bgcolor="#9999CC">
							<a href="jobs_en_cours_details_parametres_executes.php?ID={$ID}"><font size="2" color="#FFFFCC"><center>
							Executed Parameters</center></font></a>
							</td>
						{/if}

						{if $title1 == "encours"}
							<td height ="25">
							<a href="jobs_en_cours_details_parametres_en_cours.php?ID={$ID}"><font size="2" color="#9999CC"><center>
							Current Parameters</center></font></a>
							</td>
						{else}
							<td height ="25"  bgcolor="#9999CC">
							<a href="jobs_en_cours_details_parametres_en_cours.php?ID={$ID}"><font size="2" color="#FFFFCC"><center>
							Current Parameters</center></font></a>
							</td>
						{/if}

						{if $title1 == "attente"}
							<td height ="25">
							<a href="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}"><font size="2" color="#9999CC"><center>
							Waiting Parameters</center></font></a>
							</td>


						{else}
							<td height ="25"  bgcolor="#9999CC">
							<a href="jobs_en_cours_details_parametres_en_attente.php?ID={$ID}"><font size="2" color="#FFFFCC"><center>
							Waiting Parameters</center></font></a>
							</td>
						{/if}

					</tr>



					<tr>
						<td colspan="3" > <!--fusion des 4 colonnes-->


