{include file="header.tpl" title1= "repartition of the clusters (details parameters)" title2= "CLUSTER REPARTITION"}

				votre login: {$login}
				  <a href = "repartition_cluster_details.php?clustername={$clustername}">  <p align="right">return</p></a>

				</br>
				<center><h1>PARAMETERS OF THE JOBS  {$ID} ON THE CLUSTER "{$clustername}"</h1></center>
				</br>



				<!--
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-->

{if $nb_total > 100}

	<!--nombre de job par page-->
	<form method="post" action="repartition_cluster_details_parametres.php">

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
				primary key
				</td>
				<td>
					<select name="cleprimaire">

						{if $cleprimaire == "jobTStart"} <option value="jobTStart" selected > {else}<option value="jobTStart"  > {/if}job Start
						{if $cleprimaire == "jobState"} <option value="jobState" selected > {else}<option value="jobState"  > {/if}job State
						{if $cleprimaire == "jobTStop"} <option value="jobTStop" selected > {else}<option value="jobTStop"  > {/if}job TStop
						{if $cleprimaire == "jobParam"} <option value="" selected > {else}<option value="jobParam"  > {/if}job Param


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
				Secondary key
				</td>

				<td>
 					<select name="clesecondaire">
						{if  $clesecondaire== "null"} <option value="null" selected > {else}<option value="null"  > {/if} null
						{if  $clesecondaire== "jobTStart"} <option value="jobTStart" selected > {else}<option value="jobTStart"  > {/if}job Start
						{if  $clesecondaire== "jobState"} <option value="jobState" selected > {else}<option value="jobState"  > {/if}job State
						{if  $clesecondaire== "jobTStop"} <option value="jobTStop" selected > {else}<option value="jobTStop"  > {/if}job TStop
						{if  $clesecondaire== "jobParam"} <option value="" selected > {else}<option value="jobParam"  > {/if}job Param
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
					<center><input type="submit"  name="valid" value="valider"></center>
					<input type="hidden"  name="page_courante" value="{$page_courante}">
					<input type="hidden"  name="ID" value="{$ID}">
					<input type="hidden"  name="clustername" value="{$clustername}">

				</td>
			</tr>
		</table>
	</form>



	</br>
	</br>
	</br>
	</br>


	<form method="post" action="repartition_cluster_details_parametres.php">
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
				</center>
			</tr>
		</table>
	 	<input type="hidden"  name="page_courante" value="{$page_courante}">
		 <input type="hidden"  name="ID" value="{$ID}">
		<input type="hidden"  name="nb_jobs" value="{$nb_jobs}">

		<input type="hidden"  name="cleprimaire" value="{$cleprimaire}">
		<input type="hidden"  name="clesecondaire" value="{$clesecondaire}">
		<input type="hidden"  name="sensprim" value="{$sensprim}">
		<input type="hidden"  name="senssecond" value="{$senssecond}">

		<input type="hidden"  name="clustername" value="{$clustername}">
		</form>
{elseif $nb_total != 0 && $nb_total !=1}


	<form method="post" action="repartition_cluster_details_parametres.php">
		<table border bordercolor="#9999CC" cellspacing="1">



		<tr>
			<td>
				<!--clé primaire-->
				primary key
			</td>
			<td>
				<select name="cleprimaire">
					{if $cleprimaire == "jobTStart"} <option value="jobTStart" selected > {else}<option value="jobTStart"  > {/if}job Start
					{if $cleprimaire == "jobState"} <option value="jobState" selected > {else}<option value="jobState"  > {/if}job State
					{if $cleprimaire == "jobTStop"} <option value="jobTStop" selected > {else}<option value="jobTStop"  > {/if}job Stop
					{if $cleprimaire == "jobParam"} <option value="jobParam" selected > {else}<option value="jobParam"  > {/if}job Param
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
				secondary key
			</td>

			<td>
 				<select name="clesecondaire">
					{if  $clesecondaire== "null"} <option value="null" selected > {else}<option value="null"  > {/if} null
					{if  $clesecondaire== "jobTStart"} <option value="jobTStart" selected > {else}<option value="jobTStart"  > {/if}job Start
					{if  $clesecondaire== "jobState"} <option value="jobState" selected > {else}<option value="jobState"  > {/if}job State
					{if  $clesecondaire== "jobTStop"} <option value="jobTStop" selected > {else}<option value="jobTStop"  > {/if}job Stop
					{if  $clesecondaire== "jobParam"} <option value="" selected > {else}<option value="jobParam"  > {/if}job Param
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
				<input type="hidden"  name="ID" value="{$ID}">
				<input type="hidden"  name="nb_jobs" value="100">
				<input type="hidden"  name="clustername" value="{$clustername}">
			</td>
		</tr>
	</table>
</form>

{/if}
<!--
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-->

				</br>
				the number of parameters : {$nb_total}
				</br>
				</br>
				{if $nb_ligne != 0 }
					<table border="1" cellspacing="0" cellpadding="0">
						 <tr>
							<td bgcolor ="#FFFFCC" width="5">job Start</td>
							<td bgcolor ="#FFFFCC">job State</td>
						 	<td bgcolor ="#FFFFCC">job Stop</td>
					 		<td bgcolor ="#FFFFCC">job Param</td>
						</tr>

     						{section name=i loop=$reponse}
						<tr>
							<td>{$reponse[i].jobTStart}</td>
							<td>{$reponse[i].jobState}</td>
							<td>{$reponse[i].jobTStop}</td>
							<td>{$reponse[i].jobParam}</td>
					       </tr>
						{/section}
					</table>
				{/if}

				<a href = "repartition_cluster_details.php?clustername={$clustername}">  <p align="right">return</p></a>

				<!--
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-->
{if $nb_total > 100}
			pages :
			 {section name=i loop=$pages}

 				<a Href= "repartition_cluster_details_parametres.php?ID={$ID}&page_courante={$pages[i]}&nb_jobs={$nb_jobs}&cleprimaire={$cleprimaire}&clesecondaire={$clesecondaire}&sensprim={$sensprim}&senssecond={$senssecond}&clustername={$clustername}&clic=1">
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
