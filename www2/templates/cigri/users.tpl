<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		Users {$minindex} - {$maxindex} out of {$nbitems}
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<colgroup><col width="50%"><col width="50%"></colgroup>
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Login{$itemsorderimgs[0]}</a></th>
			<th>Action</a></th>
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
				<td align="center"><a href="index.php?submenu=users&option=chpass&login={$secondkey[0]}">Change password</a></td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No Users registered</p>
	{/if}
</td></tr>
</table>
