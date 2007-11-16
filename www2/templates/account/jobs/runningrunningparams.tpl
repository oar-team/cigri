<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<h5>MultiJob #{$jobid} - Running</h5>
        <p><b>FORECAST</b>: Avg:<b>{$ForecastAvg}</b> / Stddev:<b>{$ForecastStddev}</b> / Troughput:<b>{$ForecastThroughput} j/h</b> / End:<b> {$ForecastDuration} ({$ForecastEnd})</b>
        <br>
        <b>STATUS</b>: Term: <b>{$n_term}</b> / Run: <b>{$n_run}</b> / RemoteWait: <b>{$n_rwait}</b> / Wait: <b>{$n_wait}</b> / resubmissions: <b>{$resubmissions}</b>%
        <p>

		<table border="0">
	<tr>
		<td style="font-weight: bold;">Running Jobs</td>
		<td>&nbsp;-&nbsp;</td>
		{if $nbexecuted > 0}<td><a href="account.php?submenu=jobs&option=executedparams&id={$jobid}">Executed Jobs</a>{else}<td style="font-style: italic;">Executed Jobs{/if}</td>
		<td>&nbsp;-&nbsp;</td>
		{if $nbwaiting > 0}<td><a href="account.php?submenu=jobs&option=waitingparams&id={$jobid}">Waiting Parameters</a>{else}<td style="font-style: italic;">Waiting Parameters{/if}</td>
		</tr>
	</table>

	{if $nbitems neq 0}
		<p>Running Jobs {$minindex} - {$maxindex} out of {$nbitems}</p>
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th><a href="{$itemsorderby[0]}">Job&nbsp;#{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[1]}">Job&nbsp;name{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[2]}">Submission&nbsp;date{$itemsorderimgs[2]}</a></th>
			<th><a href="{$itemsorderby[3]}">Cluster{$itemsorderimgs[3]}</a></th>
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
				<td align="center"><a href="account.php?submenu=jobs&option=jobdetail&id={$jobid}&jid={$secondkey[0]}&optiontext=Running%20jobs&optionparam=runningparams">{$secondkey[0]}</a></td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[2]}</td>
				<td align="center">{$secondkey[3]}</td>
			</tr>
		{/foreach}
		</table>

		{include file="pages.tpl"}
	{else}
		<p>No running parameters for MultiJob {$jobid}</p>
	{/if}
</td></tr>
</table>
