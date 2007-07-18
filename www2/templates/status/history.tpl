<table border="0" cellpadding="10" cellspacing="0">
<tr><td>
<div align=right>
<a href=account.php?submenu=status&option=current>go to current status >></a>
</div>

       <h3>Grid status history</h3>
        Display for the last:  
	{ if $day } Day -
	{ else } <a href=account.php?submenu=status&option=history&day=1&cluster={$cluster}>Day</a> -
	{ /if }
	{ if $week } Week -
	{ else } <a href=account.php?submenu=status&option=history&week=1&cluster={$cluster}>Week</a> -
	{ /if }
	{ if $month } Month -
	{ else } <a href=account.php?submenu=status&option=history&month=1&cluster={$cluster}>Month</a> -
	{ /if }
	{ if $year } Year
	{ else } <a href=account.php?submenu=status&option=history&year=1&cluster={$cluster}>Year</a>
	{ /if }
	<p>
	{ if $cluster != ''}
          <img src="account/grid_history_graph.php?login={$login}&begin={$begin}&cluster={$cluster}" alt="graph">
	{ else }
          <img src="account/grid_history_graph.php?login={$login}&begin={$begin}" alt="graph">
	{ /if }
	<p>
	Filter the graph for:<br>
	{ foreach from=$clusters item=cluster_row}
	  { if $cluster_row[0] != $cluster }
	    <a href=account.php?submenu=status&option=history&day={$day}&week={$week}&month={$month}&year={$year}&cluster={$cluster_row[0]}>{$cluster_row[0]}</a><br>
	  { else }
	    {$cluster_row[0]}<br>
	  { /if }
	{ /foreach }
	{ if $cluster }
	  <a href=account.php?submenu=status&option=history&day={$day}&week={$week}&month={$month}&year={$year}>ALL THE GRID</a><br>
	{ else }
	  ALL THE GRID
	{ /if }
	  
</td></tr>
</table>

