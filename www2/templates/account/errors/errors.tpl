<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<table border="0"><tr><td><a href="account.php?submenu=errors&option=fixed">Fixed errors</a></td><td>&nbsp;-&nbsp;</td><td><a href="account.php?submenu=errors&option=tofix">Errors to fix</a></td></tr></table>
	<p></p>
	{if $nbitems neq 0}
		<p style="font-weight: bold;">Last {$nbitems} errors</p>
		{* parity var *}
		{assign var="even" value=true}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th>Error&nbsp;#</a></th>
			<th>Error date</a></th>
			<th>Error state</a></th>
			<th>Return Code</a></th>
			<th>MultiJob&nbsp;name</a></th>
			<th>JobName</a></th>
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
				<td align="center"><a href="account.php?submenu=errors&id={$secondkey[0]}&option={if $secondkey[2] eq 'FIXED'}fixeddetails{else}tofixdetails{/if}">{$secondkey[0]}</a></td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[5]}</td>
				<td align="center">{$secondkey[3]}</td>
				<td align="center">{$secondkey[4]}</td>
			</tr>
		{/foreach}
		</table>

	{else}
		<p>No error for {$login}</p>
	{/if}
</td></tr>
</table>
