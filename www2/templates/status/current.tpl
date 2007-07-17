<table border="0" cellpadding="10" cellspacing="0">
<tr><td>

<div align=right>
<a href=account.php?submenu=status&option=history>go to grid history >></a>
</div>
    <h3>Current grid status </h3>

    {if $Timestamp neq 0}
        <!-- display graph -->
	<center>
        <img src="../stats/gridstatusgraph.php" alt="graph">
	<p>
	<!-- display table -->
        <table border="0" cellpadding="5" cellspacing="3">
	<caption>Latest status recorded on {$Date} :</caption>
        <tr class="titlerow">
                        <th>Cluster</th>
			<th>Blacklisted</th>
                        <th>Max resources</th>
                        <th>Used resources (by cigri)</th>
                        <th>Localy used or unavailable resources</th>
                        <th>Free resources</th>
        </tr>
        {foreach from=$array item=secondkey}
	     {if $secondkey[6] eq "no"}
             <tr class="evenrow">
	     {else}
             <tr class="disabled">
	     {/if}
                                <td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[6]}</td>
                                <td align="center">{$secondkey[2]}</td>
                                <td align="center">{$secondkey[4]}</td>
                                <td align="center">{$secondkey[5]}</td>
                                <td align="center">{$secondkey[3]}</td>
            </tr>
        {/foreach}
	    <tr class="oddrow">
                                <td align="center"><b>TOTAL</b><br>{$nb} clusters</td>
                                <td align="center">{$TotalBlacklisted} unavailable cluster(s)</td>
                                <td align="center">{$TotalMax}</td>
                                <td align="center">{$TotalUsed}</td>
                                <td align="center">{$TotalLocal}</td>
                                <td align="center">{$TotalFree}</td>
            </tr>
        </table>
    {else}
        No gridstatus data found!<BR>
    {/if}
    <p>
    {if $nbjobs neq 0}
        <table border="0" cellpadding="5" cellspacing="3">
        <caption>Current multiple-jobs :</caption>
        <tr class="titlerow">
                        <th>MjobId</th>
                        <th>Status</th>
                        <th>User</th>
                        <th>Average job duration</th>
                        <th>Job throughput</th>
			<th>term/run/wait</th>
			<th>resubmissions</th>
        </tr>
        {foreach from=$jobarray item=secondkey}
            <tr  class="evenrow">
                                <td align="center"><a href="account.php?submenu=jobs&option=details&id={$secondkey[0]}">{$secondkey[0]}</a></td>
                                <td align="center">{$secondkey[1]}</td>
                                <td align="center">{$secondkey[2]}</td>
                                <td align="center">{$secondkey[3]} s</td>
                                <td align="center">{$secondkey[5]} j/h</td>
                                <td align="center">{$secondkey[8]}/{$secondkey[9]}/{$secondkey[7]}</td>
                                <td align="center">{$secondkey[6]}%</td>
            </tr>
        {/foreach}

      </table>
    {else}
        No running mjob found.<BR>
    {/if}
    </center>

</td></tr>
</table>

