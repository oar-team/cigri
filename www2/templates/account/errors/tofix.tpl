<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<table border="0"><tr><td><a href="account.php?submenu=errors&option=fixed">Fixed errors</a></td><td>&nbsp;-&nbsp;</td><td style="font-weight: bold;">Errors to fix</td></tr></table>
	<p></p>
	{if $nbitems neq 0}
		Errors to fix {$minindex} - {$maxindex} out of {$nbitems}
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<form action="account.php" method="get">
		<input type="hidden" name="submenu" value="errors">
		<input type="hidden" name="option" value="fixaction">
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th></th>
			<th><a href="{$itemsorderby[0]}">Error&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Error date{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[2]}">MultiJob&nbsp;name{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">Job Name{$itemsorderimgs[3]}</a></th>
			<th><a href="{$itemsorderby[4]}">Return Code{$itemsorderimgs[4]}</a></th>
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
				<td><input type="checkbox" name="errorcb[]" value="{$secondkey[0]}"></td>
				<td align="center"><a href="account.php?submenu=errors&option=tofixdetails&id={$secondkey[0]}">{$secondkey[0]}</a></td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
				<td align="center">{$secondkey[4]}</td>
			</tr>
		{/foreach}
		</table>
		<table border="0" cellpadding="5" cellspacing="0">
		<tr><td colspan="3">&nbsp;</td></tr>
		<tr><td><input type="submit" name="fix" value="Fix errors"></td><td>&nbsp;</td><td><input type="submit" name="resub" value="Re-submit Jobs"></td></tr>
		</table>
		</form>

		{include file="pages.tpl"}
	{else}
		<p>No error to fix for {$login}</p>
	{/if}
</td></tr>
</table>
