<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
	<h3>Computing Power</h3>
	{if $message neq ""}
		<p>{$message}</p>
	{/if}
	<form method="get" action="stats.php">
		<table border="0" cellpadding="5" cellspacing="0">
		<tr>
			<td>Display</td>
			<td colspan="3">
				<input type="hidden" name="submenu" value="power">
				<select name="timerange" size="1">
				{foreach from=$timearray item=value}
				<option value="{$value}" {if $value eq $timerange} selected{/if}>{$value}</option>
				{/foreach}
				</select>
			</td>
		</tr>
		<tr>
			<td>from</td>
			<td>
				<select name="bmonth" size="1">
				{foreach from=$months key=key item=value}
				<option value="{$key}" {if $key eq $bmonth}selected{/if}>{$value}</option>
				{/foreach}
				</select>
			</td>
			<td>
				<select name="bday" size="1">
				{foreach from=$days item=value}
				<option value="{$value}" {if $value eq $bday} selected{/if}>{$value}</option>
				{/foreach}
				</select>
			</td>
			<td>
				<select name="byear" size="1">
				{foreach from=$years item=value}
				<option value="{$value}" {if $value eq $byear} selected{/if}>{$value}</option>
				{/foreach}
				</select>
			</td>
		</tr>
		<tr>
			<td colspan="4" align="center">
				<input type="submit" value="Display graph">
			</td>
		</tr>
		</table>
	</form>
	<!-- display graph -->
	<img src="stats/powerstatsgraph.php?byear={$byear}&bmonth={$bmonth}&bday={$bday}&timerange={$timerangeget}" alt="graph">
</td></tr>
</table>
