<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nb neq 0}
		<table border="0" cellpadding="5" cellspacing="3" width="80%">
		<tr class="titlerow">
			<th colspan="2">Fixed error - error&nbsp;# {$eventid}</th>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>MultiJob&nbsp;Name</b></td>
			<td align="center" class="evenrow">{$eventarray.MJobsName}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Job&nbsp;Params</b></td>
			<td align="center" class="evenrow">{$eventarray.jobParam}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Error&nbsp;Type</b></td>
			<td align="center" class="evenrow">{$eventarray.errorType}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Error&nbsp;Date</b></td>
			<td align="center" class="evenrow">{$eventarray.errorDate}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Error&nbsp;Message</b></td>
			<td align="center" class="evenrow">{$eventarray.errorMessage}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Node&nbsp;Name</b></td>
			<td align="center" class="evenrow">{$eventarray.nodeName}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Cluster&nbsp;Name</b></td>
			<td align="center" class="evenrow">{$eventarray.nodeClusterName}</td>
		</tr>
		</table>
		<p></p>
	{else}
		<h5>Error: event #{$eventid} not found</h5>
	{/if}
</td></tr>
</table>
