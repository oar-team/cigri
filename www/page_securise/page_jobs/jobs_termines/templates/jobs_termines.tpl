
{include file="header.tpl" title1= "Finished Multijobs" title2="FINISHED MULTIJOBS"}<HTML>

			 	your login: {$login}
				</br>
				<h1> Pages of the finished  Multijobs </h1>
				</br>

				<!--
				--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				-->

				{if $nb_total > 100}
					<!--nombre de job par page-->
					<form method="post" action="jobs_termines.php">

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

								</td>

								<td></td>


							</tr>


							<tr>
								<td>
									<!--clé primaire-->
									primary key
								</td>

								<td>
									<select name="cleprimaire">

										{if $cleprimaire == "MJobsId"} <option value="MJobsId" selected >
										{else}<option value="MJobsId"  >
										{/if}Job Id
										{if $cleprimaire == "MJobsName"} <option value="MJobsName" selected >
										{else}<option value="MJobsName"  >
										{/if}Job Name
										{if $cleprimaire == "MJobsTSub"} <option value="MJobsTSub" selected >
										{else}<option value="MJobsTSub"  >
										{/if}JobSub
 									</select>
								</td>
								<td>
									{if  $sensprim== "croissant"} <input type="radio" name="sensprim" value="croissant" checked>
									{else}  <input type="radio" name="sensprim" value="croissant" >
									{/if} increasing

									{if  $sensprim== "decroissant"} <input type="radio" name="sensprim" value="decroissant" checked>
									{else}  <input type="radio" name="sensprim" value="decroissant" >
									{/if} decreasing

								</td>
							</tr>


							<tr>
								<td>
									<!--clé secondaire-->
									Secondary key
								</td>

								<td>
 									<select name="clesecondaire">
										{if  $clesecondaire== "null"} <option value="null" selected >
										{else}<option value="null"  >
										{/if} null
										{if  $clesecondaire== "MJobsId"} <option value="MJobsId" selected >
										{else}<option value="MJobsId"  >
										{/if}Job Id
										{if  $clesecondaire== "MJobsName"} <option value="MJobsName" selected >
										{else}<option value="MJobsName"  >
										{/if}Job Name
										{if  $clesecondaire== "MJobsTSub"} <option value="MJobsTSub" selected >
										{else}<option value="MJobsTSub"  >
										{/if}Job TSub
	 								</select>
								</td>

								<td>
									{if  $senssecond== "croissant"} <input type="radio" name="senssecond" value="croissant" checked>
									{else}  <input type="radio" name="senssecond" value="croissant" >
									{/if} increasing

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


					<form method="post" action="jobs_termines.php">
						<table  width = "100%">
							<tr>

								<td >
									{if $page_courante != 1}
									<input type="submit"  name="page" value="< PREV">
									{/if}
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
										<p align="right">
										<input type="submit"  name="page" value="NEXT >">
										</p>
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



			{elseif $nb_total != 0 &&  $nb_total != 1}

				<form method="post" action="jobs_termines.php">
						<table border bordercolor="#9999CC" cellspacing="1">
							<tr>
								<td>
									<!--clé primaire-->
									primary key
								</td>
								<td>
									<select name="cleprimaire">
										{if $cleprimaire == "MJobsId"} <option value="MJobsId" selected >
										{else}<option value="MJobsId"  >
										{/if}Job Id
										{if $cleprimaire == "MJobsName"} <option value="MJobsName" selected >
										{else}<option value="MJobsName"  >
										{/if}Job Name
										{if $cleprimaire == "MJobsTSub"} <option value="MJobsTSub" selected >
										{else}<option value="MJobsTSub"  >
										{/if}Job TSub
 									</select>
								</td>
								<td>
									{if  $sensprim== "croissant"} <input type="radio" name="sensprim" value="croissant" checked>
									{else}  <input type="radio" name="sensprim" value="croissant" >
									{/if} increasing

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
									{if  $clesecondaire== "MJobsId"} <option value="MJobsId" selected >
									{else}<option value="MJobsId"  >
									{/if}Job Id
									{if  $clesecondaire== "MJobsName"} <option value="MJobsName" selected >
									{else}<option value="MJobsName"  >
									{/if}Job Name
									{if  $clesecondaire== "MJobsTSub"} <option value="MJobsTSub" selected >
									{else}<option value="MJobsTSub"  >
									{/if}Job TSub
 									</select>
								</td>

								<td>
									{if  $senssecond== "croissant"} <input type="radio" name="senssecond" value="croissant" checked>
									{else}  <input type="radio" name="senssecond" value="croissant" >
									{/if} increasing

									{if  $senssecond== "decroissant"} <input type="radio" name="senssecond" value="decroissant" checked>
									{else}  <input type="radio" name="senssecond" value="decroissant" >
									{/if} decreasing
								</td>
							</tr>

							<tr>
								<td colspan="3">
									<input type="hidden"  name="page_courante" value="{$page_courante}">
									<input type="hidden"  name="ID" value="{$ID}">
									<input type="hidden"  name="nb_jobs" value="100">
									<center>
									<input type="submit"  name="valid" value="valid">
									</center>
								</td>
							</tr>
						</table>
				</form>

			{/if}
 			<!--
				----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
				-->



				</br>
				</br>
				the number of finished MultiJobs: {$nb_total}
				</br>
				</br>
				{if $nb_ligne != 0 }
					<table border="1" cellspacing="0" cellpadding="0">
						 <tr>
							<td  bgcolor ="#FFFFCC"width="5">Job Id </td>
							<td bgcolor ="#FFFFCC">Job Sub</td>
							<td bgcolor ="#FFFFCC"></td>
							<td bgcolor ="#FFFFCC"></td>
							<td bgcolor ="#FFFFCC">Job Name</td>
						</tr>

     						{section name=i loop=$reponse}
							<tr>
								<td>{$reponse[i].MJobsId}</td>
								<td>{$reponse[i].MJobsTSub}</td>
								<td>
									<form method="post" action="jobs_termines_details.php">
 										<input type="submit" name="bidule" value="details">
 										<input type="hidden" name="ID" value="{$reponse[i].MJobsId}">
 									</form>
								</td>
								<td>
									<form method="post" action="jobs_termines_proprietes.php">
 										<input type="submit" name="bidule" value="Properties">
 										<input type="hidden" name="ID" value="{$reponse[i].MJobsId}">
 									</form>
								</td>
								<td>{$reponse[i].MJobsName}</td>
							</tr>
						{/section}
					</table>
				{else}
					</BR>
					<H1>NO FINSHED MULTIJOBS</H1>
					</BR>
 				{/if}



				</br>

				<!--
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-->
{if $nb_total > 100}
			 pages :
			 {section name=i loop=$pages}

 				<a Href= "jobs_termines.php?ID={$ID}&page_courante={$pages[i]}&nb_jobs={$nb_jobs}&cleprimaire={$cleprimaire}&clesecondaire={$clesecondaire}&sensprim={$sensprim}&senssecond={$senssecond}&clic=1">
				{if $page_courante == $pages[i]}
					<font color="#FF0000">	{$pages[i]}</font></a>
				{else}
				{$pages[i]}</a>
				{/if}

			  {/section}

{/if}
<!--
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-->
{include file="../../../../foot.tpl"}
