<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<table border="0"><tr><td><h3>Fixed errors</h3></td><td><h3>&nbsp;-&nbsp;</h3></td><td><h5><a href="account.php?submenu=errors&option=tofix">Errors to fix</a></h5></td></tr></table>
	{if $nbitems neq 0}
		Fixed errors {$minindex} - {$maxindex} out of {$nbitems}
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Error&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Submission date{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[2]}">MultiJob&nbsp;name{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">JobName{$itemsorderimgs[3]}</a></th>
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
				<td align="center"><a href="account.php?submenu=errors&option=fixeddetails&id={$secondkey[0]}">{$secondkey[0]}</a></td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No fixed error for {$login}</p>
	{/if}
</td></tr>
</table>
