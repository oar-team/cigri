<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<h5><a href="account.php?submenu=jobs&option=runningdetails&id={$jobid}">Running MultiJob #{$jobid}</a></h5>
	<table border="0">
	<tr>
		{if $nbrunning > 0}<td><a href="account.php?submenu=jobs&option=runningparams&id={$jobid}">Running Parameters</a>{else}<td style="font-style: italic;">Running Parameters{/if}</td>
		<td>&nbsp;-&nbsp;</td>
		<td><a href="account.php?submenu=jobs&option=executedparams&id={$jobid}">Executed Parameters</a></td>
		<td>&nbsp;-&nbsp;</td>
		{if $nbwaiting > 0}<td><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Waiting Parameters</a>{else}<td style="font-style: italic;">Waiting Parameters{/if}</td>
		</tr>
	</table>

	{if $nbitems neq 0}
		<p>Executed parameters {$minindex} - {$maxindex} out of {$nbitems}</p>
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Job&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[3]}">Collect&nbsp;#{$itemsorderimgs[3]}</a></th>
			<th><a href="{$itemsorderby[1]}">Parameters{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[4]}">Start&nbsp;date{$itemsorderimgs[4]}</a></th>
			<th><a href="{$itemsorderby[5]}">End&nbsp;date{$itemsorderimgs[5]}</a></th>
			<th><a href="{$itemsorderby[6]}">Duration{$itemsorderimgs[6]}</a></th>
			<th><a href="{$itemsorderby[7]}">Cluster{$itemsorderimgs[7]}</a></th>
			<th><a href="{$itemsorderby[8]}">Node{$itemsorderimgs[8]}</a></th>
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
				<td align="center">{$secondkey[3]}</td>
				<td align="center"><span title="{$secondkey[1]}">{$secondkey[1]|truncate:30:"...":true}</span></td>
				<td align="center">{$secondkey[4]}</td>
				<td align="center">{$secondkey[5]}</td>
				<td align="center">{$secondkey[6]}</td>
				<td align="center">{$secondkey[7]}</td>
				<td align="center">{$secondkey[8]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No executed parameters for MultiJob {$jobid}</p>
	{/if}
</td></tr>
</table>
