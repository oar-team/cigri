<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<table border="0">
	<tr>
		<td><h5><a href="account.php?submenu=jobs&option=running">Running MultiJobs</a></h5></td>
		<td><h3>&nbsp;-&nbsp;</h3></td>
		<td><h5><a href="account.php?submenu=jobs&option=terminated">Terminated MultiJobs</a></h5></td>
		<td><h3>&nbsp;-&nbsp;</h3></td>
		<td><h5><a href="account.php?submenu=jobs&option=cluster">Clusters</a></h5></td>
	</tr>
	</table>
	{if $nbitems neq 0}
		MultiJob #{$id} on <a href="account.php?submenu=jobs&option=cluster&option=clusterdetails&name={$queryname}">cluster {$name}</a> - jobs {$minindex} - {$maxindex} out of {$nbitems}
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Job&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Name{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[5]}">Parameters{$itemsorderimgs[5]}</a></th>
			<th><a href="{$itemsorderby[3]}">State{$itemsorderimgs[3]}</a></th>
			<th><a href="{$itemsorderby[6]}">Submission{$itemsorderimgs[6]}</a></th>
			<th><a href="{$itemsorderby[4]}">Start&nbsp;date{$itemsorderimgs[4]}</a></th>
			<th><a href="{$itemsorderby[2]}">End&nbsp;date{$itemsorderimgs[2]}</a></th>
		</tr>
		{foreach from=$eventarray item=secondkey}
			{* check parity *}
			{if $even eq true}
				{assign var="even" value=false}
				{assign var="trclass" value="evenrow"}
			{else}
				{assign var="even" value=true}
				{assign var="trclass" value="oddrow"}
			{/if}
			<tr class="{$trclass}">
				<td align="center">{$secondkey[0]}</td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[5]}</td>
				<td align="center">{$secondkey[3]}</td>
				<td align="center">{$secondkey[6]}</td>
				<td align="center">{$secondkey[4]}</td>
				<td align="center">{$secondkey[2]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No MultiJob on cluster {$name}</p>
	{/if}
</td></tr>
</table>
