<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		Grid events {$minindex} - {$maxindex} out of {$nbitems}
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Event&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Event Type{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[2]}">Event State{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">Cluster{$itemsorderimgs[3]}</a></th>
			<th><a href="{$itemsorderby[4]}">Submission Date{$itemsorderimgs[4]}</a></th>
			<th><a href="{$itemsorderby[5]}">Job Name{$itemsorderimgs[5]}</a></th>
			<th><a href="{$itemsorderby[6]}">User{$itemsorderimgs[6]}</a></th>
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
				<td align="center">{$secondkey[4]}</td>
				<td align="center">{$secondkey[5]}</td>
				<td align="center">{$secondkey[6]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No Grid event</p>
	{/if}
</td></tr>
</table>
