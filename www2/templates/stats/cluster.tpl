<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
	<h3>Cluster Statistics</h3>
	{if $message neq ""}
		<p>{$message}</p>
	{/if}
	<form method="get" action="stats.php">
		<table border="0" cellpadding="5" cellspacing="0">
		<tr>
			<td>Interval</td>
			<td>
				<input type="hidden" name="submenu" value="cluster">
				<input name="interval" type="text" size="2" value="{$interval}">
				hours
				<input type="submit" value="OK"> (max 24)
			</td>
		</tr>
		</table>
	</form>
	<!-- display graph -->
	<img src="stats/clusterstatsgraph.php?interval={$interval}" alt="graph">
</td></tr>
</table>
