<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	{if $nb neq 0}
		<table border="0" cellpadding="5" cellspacing="3" width="80%">
		<tr class="titlerow">
			<th colspan="2">Job&nbsp;#{$subjobid} in MultiJob #{$jobid}</th>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Job&nbsp;Name</b></td>
			<td align="center" class="evenrow">{$eventarray[0][2]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Job&nbsp;Parameters</b></td>
			<td align="center" class="evenrow">{$eventarray[0][1]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Job&nbsp;State</b></td>
			<td align="center" class="evenrow">{$eventarray[0][0]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Cluster&nbsp;Name</b></td>
			<td align="center" class="evenrow">{$eventarray[0][3]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Node&nbsp;Name</b></td>
			<td align="center" class="evenrow">{$eventarray[0][4]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Submission&nbsp;date</b></td>
			<td align="center" class="evenrow">{$eventarray[0][8]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Start&nbsp;date</b></td>
			<td align="center" class="evenrow">{$eventarray[0][9]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>End&nbsp;date</b></td>
			<td align="center" class="evenrow">{$eventarray[0][10]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Duration</b></td>
			<td align="center" class="evenrow">{$eventarray[0][11]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Collect&nbsp;#</b></td>
			<td align="center" class="evenrow">{$eventarray[0][7]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Batch&nbsp;Id</b></td>
			<td align="center" class="evenrow">{$eventarray[0][5]}</td>
		</tr>
		<tr>
			<td align="center" class="oddrow"><b>Return&nbsp;Code</b></td>
			<td align="center" class="evenrow">{$eventarray[0][6]}</td>
		</tr>
		</table>
		<p></p>
	{else}
		<h5>Error: Job #{$subjobid} not found</h5>
	{/if}
</td></tr>
</table>
