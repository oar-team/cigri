<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
	<h3>Grid Statistics</h3>
	<p>See time repartition for last: 
	{if $timerepartition eq 'day'}
		day
	{else}
		<a href="stats.php?submenu=grid&timerepartition=day">day</a>
	{/if}
	&nbsp;-&nbsp;
	{if $timerepartition eq 'week'}
		week
	{else}
		<a href="stats.php?submenu=grid&timerepartition=week">week</a>
	{/if}
	&nbsp;-&nbsp;
	{if $timerepartition eq 'month'}
		month
	{else}
		<a href="stats.php?submenu=grid&timerepartition=month">month</a>
	{/if}
	&nbsp;-&nbsp;
	{if $timerepartition eq 'year'}
		year
	{else}
		<a href="stats.php?submenu=grid&timerepartition=year">year</a>
	{/if}
	</p>
	<h4>Computing Grid time repartition during last {$timerepartition}</h4>
	<!-- display graph -->
	<img src="stats/gridstatsgraph.php?timerepartition={$timerepartition}" alt="graph">
</td></tr>
</table>
