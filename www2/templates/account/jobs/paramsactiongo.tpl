<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		<h5>{$action} {if $shortaction eq 'priority'}to {$newpriority}{/if} successful on {$updates} parameters out of {$nbitems}</h5>
		<p>{$nbitems} selected parameters shown below for information</p>
		{* parity var *}
		{assign var="even" value=true}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th>Name</th>
			<th>Parameters</th>
			{if $shortaction neq 'priority'}<th>Priority</th>{/if}
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
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[0]}</td>
				{if $shortaction neq 'priority'}<td align="center">{$secondkey[2]}</td>{/if}
			</tr>
		{/foreach}
		</table>
		<p><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Back to Running MultiJob #{$jobid} waiting parameters</a></p>

	{else}
		<p>Please select a parameter.</p>
		<p><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Back to Running MultiJob #{$jobid} waiting parameters</a></p>
	{/if}
</td></tr>
</table>
