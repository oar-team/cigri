<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nbitems neq 0}
		<h5>{$action} successful on {$updates} errors out of {$nbitems}</h5>
		<p>{$nbitems} selected errors shown below for information</p>
		{* parity var *}
		{assign var="even" value=true}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th>Error&nbsp;#</th>
			<th>Submission date</th>
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
				<td align="center">{$secondkey[0]}</td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>
		<p><a href="account.php?submenu=errors&option=tofix">Back to Errors to fix</a></p>

	{else}
		<p>Please select an error to fix.</p>
		<p><a href="account.php?submenu=errors&option=tofix">Back to Errors to fix</a></p>
	{/if}
</td></tr>
</table>
