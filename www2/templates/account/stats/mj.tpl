<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		MultiJobs {$minindex} - {$maxindex} out of {$nbitems}
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">MultiJob&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">MultiJob&nbsp;name{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[2]}">Submission&nbsp;date{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">State{$itemsorderimgs[3]}</a></th>
			<th></th>
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
				<td align="center"><a href="account.php?submenu=jobs&option=details&id={$secondkey[0]}">{$secondkey[0]}</a></td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
				<td align="center"><a href="account.php?submenu=stats&option=details&id={$secondkey[0]}">Statistics</a></td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No job for {$login}</p>
	{/if}
</td></tr>
</table>
