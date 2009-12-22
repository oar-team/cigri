<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<h5>MultiJob #{$jobid}</h5>
	{if $MJstate eq 'Running'}
	<p><b>FORECAST</b>: Avg:<b>{$ForecastAvg}</b> / Stddev:<b>{$ForecastStddev}</b> / Troughput:<b>{$ForecastThroughput} j/h</b> / End:<b> {$ForecastDuration} ({$ForecastEnd})</b>
        <br>
        <b>STATUS</b>: Term: <b>{$n_term}</b> / Run: <b>{$n_run}</b> / RemoteWait: <b>{$n_rwait}</b> / Wait: <b>{$n_wait}</b> / Errors: <b>{$n_err}</b> / resubmissions: <b>{$resubmissions}</b>%
        <p>
	{/if}
	<table border="0">
	<tr>
		{if $MJstate eq 'Running' and $nbrunning > 0}<td><a href="account.php?submenu=jobs&option=runningparams&id={$jobid}">Running Jobs</a>
		{else}<td style="font-style: italic;">Running Jobs
		{/if}</td>
		<td>&nbsp;-&nbsp;</td>
		<td style="font-weight: bold;">Executed Jobs</td>
		<td>&nbsp;-&nbsp;</td>
		{if $MJstate eq 'Running' and $nbwaiting > 0}<td><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Waiting Parameters</a>{else}<td style="font-style: italic;">Waiting Parameters{/if}</td>
		</tr>
	</table>

	{if $nbitems neq 0}
		<p>Executed Jobs {$minindex} - {$maxindex} out of {$nbitems}</p>
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Job&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Job&nbsp;name{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[4]}">Start&nbsp;date{$itemsorderimgs[4]}</a></th>
			<th><a href="{$itemsorderby[5]}">End&nbsp;date{$itemsorderimgs[5]}</a></th>
			<th><a href="{$itemsorderby[6]}">Duration{$itemsorderimgs[6]}</a></th>
			<th><a href="{$itemsorderby[7]}">Cluster{$itemsorderimgs[7]}</a></th>
			<th><a href="{$itemsorderby[8]}">Node{$itemsorderimgs[8]}</a></th>
			<th><a href="{$itemsorderby[3]}">Collect&nbsp;#{$itemsorderimgs[3]}</a></th>
		</tr>
		{foreach from=$eventarray item=secondkey}
			{* check parity *}
			{if $even eq true}
				{assign var="even" value=false}
				{assign var="trclass" value="evenrow"}
			{else}
				{assign var="even" value=true}
				{assign var="trclass" value="oddrow"}
			{/if}
			<tr class="{$trclass}">
				<td align="center"><a href="account.php?submenu=jobs&option=jobdetail&id={$jobid}&jid={$secondkey[0]}&optiontext=Executed%20jobs&optionparam=executedparams">{$secondkey[0]}</a></td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[4]}</td>
				<td align="center">{$secondkey[5]}</td>
				<td align="center">{$secondkey[6]}</td>
				<td align="center">{$secondkey[7]}</td>
				<td align="center">{$secondkey[8]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No executed parameters for MultiJob {$jobid}</p>
	{/if}
</td></tr>
</table>
