<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		<h5>Confirm {$action} on following errors</h5>
		{* parity var *}
		{assign var="even" value=true}
		<form action="account.php" method="get">
		<input type="hidden" name="submenu" value="errors">
		<input type="hidden" name="option" value="fixaction">
		<input type="hidden" name="{$shortaction}" value="current">
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th>Error&nbsp;#</th>
			<th>Error date</th>
			<th>MultiJob&nbsp;name</th>
			<th>Job Name</th>
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
				<td align="center"><input type="hidden" name="errorcb[]" value="{$secondkey[0]}">{$secondkey[0]}</td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>
		<table border="0" cellpadding="5" cellspacing="0">
		<tr><td colspan="3">&nbsp;</td></tr>
		<tr><td><input type="submit" name="GO" value="OK"></td><td>&nbsp;</td><td><input type="submit" name="cancel" value="Cancel"></td></tr>
		</table>
		</form>

	{else}
		<p>Please select an error to fix.</p>
	{/if}
	<p>&nbsp;</p>
	<p><a href="account.php?submenu=errors&option=tofix">Back to Errors to fix</a></p>
</td></tr>
</table>
