<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
<div align=right>
<a href=account.php?submenu=status&option=current>go to current status >></a>
</div>

       <h3>Grid status history</h3>
        <!-- display graph -->
	{ if $day } Day -
	{ else } <a href=account.php?submenu=status&option=history&day=1>Day</a> -
	{ /if }
	{ if $week } Week -
	{ else } <a href=account.php?submenu=status&option=history&week=1>Week</a> -
	{ /if }
	{ if $month } Month -
	{ else } <a href=account.php?submenu=status&option=history&month=1>Month</a> -
	{ /if }
	{ if $year } Year
	{ else } <a href=account.php?submenu=status&option=history&year=1>Year</a>
	{ /if }
	<p>
          <img src="account/grid_history_graph.php?login={$login}&begin={$begin}" alt="graph">
	<p>
</td></tr>
</table>

