<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		<h5>MultiJob #{$jobid} Properties - {$MJstate} MultiJob</h5>
		<table border="0">
		<tr>
			{if $MJstate eq 'Running' and $nbrunning > 0}<td><a href="account.php?submenu=jobs&option=runningparams&id={$jobid}">Running Jobs</a>{else}<td style="font-style: italic;">Running Jobs{/if}</td>
			<td>&nbsp;-&nbsp;</td>
			{if $nbexecuted > 0}<td><a href="account.php?submenu=jobs&option=executedparams&id={$jobid}">Executed Jobs</a>{else}<td style="font-style: italic;">Executed Jobs{/if}</td>
			<td>&nbsp;-&nbsp;</td>
			{if $MJstate eq 'Running' and $nbwaiting > 0}<td><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Waiting Parameters</a>{else}<td style="font-style: italic;">Waiting Parameters{/if}</td>
		</tr>
		</table>
		<p>MultiJob execution properties {$minindex} - {$maxindex} out of {$nbitems}</p>

		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Cluster Name{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Execution Command{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[4]}">Exec Directory{$itemsorderimgs[4]}</a></th>
			<th><a href="{$itemsorderby[2]}">Wall Time{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">Weight{$itemsorderimgs[3]}</a></th>
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
				<td align="center">{$secondkey[4]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No execution properties for Running MultiJob {$jobid}</p>
	{/if}
</td></tr>
</table>
