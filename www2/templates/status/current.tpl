<table border="0" cellpadding="10" cellspacing="0">
<tr><td>

    <h3>Current grid status</h3>
    {if $Timestamp neq 0}
        <table border="0" cellpadding="5" cellspacing="3">
	<caption>Latest status recorded on : {$Date}</caption>
        <tr class="titlerow">
                        <th>Cluster</th>
                        <th>Max resources</th>
                        <th>Used resources (by cigri)</th>
                        <th>Localy used or unavailable resources</th>
                        <th>Free resources</th>
        </tr>
        {foreach from=$array item=secondkey}
            <tr class="evenrow">
                                <td align="center">{$secondkey[1]}</td>
                                <td align="center">{$secondkey[2]}</td>
                                <td align="center">{$secondkey[4]}</td>
                                <td align="center">{$secondkey[5]}</td>
                                <td align="center">{$secondkey[3]}</td>
            </tr>
        {/foreach}
	    <tr class="oddrow">
                                <td align="center"><b>TOTAL</b></td>
                                <td align="center">{$TotalMax}</td>
                                <td align="center">{$TotalUsed}</td>
                                <td align="center">{$TotalLocal}</td>
                                <td align="center">{$TotalFree}</td>
            </tr>
        </table>
        <!-- display graph -->
	<p>
	<center>
        <img src="status/gridstatusgraph.php" alt="graph">
	</center>
    {else}
        No gridstatus data found!<BR>
    {/if}
</td></tr>
</table>

