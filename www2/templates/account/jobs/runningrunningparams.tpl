<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<h5><a href="account.php?submenu=jobs&option=runningdetails&id={$jobid}">Running MultiJob #{$jobid}</a></h5>
	<table border="0">
	<tr>
		<td><a href="account.php?submenu=jobs&option=runningparams&id={$jobid}">Running Parameters</a></td>
		<td>&nbsp;-&nbsp;</td>
		<td><a href="account.php?submenu=jobs&option=executedparams&id={$jobid}">Executed Parameters</a></td>
		<td>&nbsp;-&nbsp;</td>
		<td><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Waiting Parameters</a></td>
		</tr>
	</table>

	{if $nbitems neq 0}
		<p>Running parameters {$minindex} - {$maxindex} out of {$nbitems}</p>
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Job&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Parameters{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[2]}">Start&nbsp;date{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">Cluster{$itemsorderimgs[3]}</a></th>
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
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No running parameters for MultiJob {$jobid}</p>
	{/if}
</td></tr>
</table>
