<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
	<h3>Jobs time repartition</h3>
	<p>Display time repartition for last: 
	{if $timerepartition eq 'day'}
		day
	{else}
		<a href="account.php?submenu=stats&option=jobs&timerepartition=day">day</a>
	{/if}
	&nbsp;-&nbsp;
	{if $timerepartition eq 'week'}
		week
	{else}
		<a href="account.php?submenu=stats&option=jobs&timerepartition=week">week</a>
	{/if}
	&nbsp;-&nbsp;
	{if $timerepartition eq 'month'}
		month
	{else}
		<a href="account.php?submenu=stats&option=jobs&timerepartition=month">month</a>
	{/if}
	&nbsp;-&nbsp;
	{if $timerepartition eq 'year'}
		year
	{else}
		<a href="account.php?submenu=stats&option=jobs&timerepartition=year">year</a>
	{/if}
	</p>
	<h4>Jobs time repartition during last {$timerepartition}</h4>
	<!-- display graph -->
	<img src="account/jobsstatsgraph.php?timerepartition={$timerepartition}&login={$login}" alt="graph">
</td></tr>
</table>
