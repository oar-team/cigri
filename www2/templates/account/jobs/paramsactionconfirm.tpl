<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		<h5>Confirm {$action} on following parameters</h5>
		{if $shortaction eq 'priority'}
			{if $wrongpriority eq true}
				<p style="color:#FF0000">Invalid priority value</p>
			{/if}
		{/if}
		{* parity var *}
		{assign var="even" value=true}
		<form action="account.php" method="get">
		<input type="hidden" name="submenu" value="jobs">
		<input type="hidden" name="option" value="paramsaction">
		<input type="hidden" name="id" value="{$jobid}">
		<input type="hidden" name="{$shortaction}" value="current">
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th>Name</th>
			<th>Parameters</th>
			<th>Priority</th>
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
				<td align="center"><input type="hidden" name="paramcb[]" value="{$secondkey[1]}">{$secondkey[1]}</td>
				<td align="center">{$secondkey[0]}</td>
				<td align="center">{$secondkey[2]}</td>
			</tr>
		{/foreach}
		</table>
		<table border="0" cellpadding="5" cellspacing="0">
		{if $shortaction eq 'priority'}
			<tr><td colspan="2"><h5>Set new priority to: </h5></td><td><input name="newpriority" value="0" size="4"></td></tr>
		{else}
			<tr><td colspan="3">&nbsp;</td></tr>
		{/if}
		<tr><td align="right"><input type="submit" name="GO" value="OK"></td><td>&nbsp;</td><td><input type="submit" name="cancel" value="Cancel"></td></tr>
		</table>
		</form>

	{else}
		<p>Please select a parameter.</p>
		<p><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Back to Running MultiJob #{$jobid} waiting parameters</a></p>
	{/if}
</td></tr>
</table>
