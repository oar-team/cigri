<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<h5>MultiJob #{$jobid} - Running</h5>
	<p><b>FORECAST</b>: Avg:<b>{$ForecastAvg}</b> / Stddev:<b>{$ForecastStddev}</b> / Troughput:<b>{$ForecastThroughput} j/h</b> / End:<b> {$ForecastDuration} ({$ForecastEnd})</b>
        <br>
        <b>STATUS</b>: Term: <b>{$n_term}</b> / Run: <b>{$n_run}</b> / RemoteWait: <b>{$n_rwait}</b> / Wait: <b>{$n_wait}</b> / resubmissions: <b>{$resubmissions}</b>%
        <p>
	
	<table border="0">
	<tr>
		{if $nbrunning > 0}<td><a href="account.php?submenu=jobs&option=runningparams&id={$jobid}">Running Jobs</a>{else}<td style="font-style: italic;">Running Jobs{/if}</td>
		<td>&nbsp;-&nbsp;</td>
		{if $nbexecuted > 0}<td><a href="account.php?submenu=jobs&option=executedparams&id={$jobid}">Executed Jobs</a>{else}<td style="font-style: italic;">Executed Jobs{/if}</td>
		<td>&nbsp;-&nbsp;</td>
		<td style="font-weight: bold;">Waiting Parameters</td>
		</tr>
	</table>

	{if $nbitems neq 0}
		<p>Waiting parameters {$minindex} - {$maxindex} out of {$nbitems}</p>
		{* parity var *}
		{assign var="even" value=true}
		{include file="pages.tpl"}
		<form action="account.php" method="get">
		<input type="hidden" name="submenu" value="jobs">
		<input type="hidden" name="option" value="paramsaction">
		<input type="hidden" name="id" value="{$jobid}">
		<table border="0" cellpadding="5" cellspacing="3">
		<tr class="titlerow">
			<th></th>
			<th><a href="{$itemsorderby[1]}">Name{$itemsorderimgs[1]}</a></th>
			<th><a href="{$itemsorderby[0]}">Parameters{$itemsorderimgs[0]}</a></th>
			<th><a href="{$itemsorderby[2]}">Priority{$itemsorderimgs[2]}</a></th>
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
				<td><input type="checkbox" name="paramcb[]" value="{$secondkey[1]}"</td>
				<td align="center">{$secondkey[1]}</td>
				<td align="center">{$secondkey[0]}</td>
				<td align="center">{$secondkey[2]}</td>
			</tr>
		{/foreach}
		</table>
		<table border="0" cellpadding="5" cellspacing="0">
		<tr><td colspan="3">&nbsp;</td></tr>
		<tr><td><input type="submit" name="remove" value="Remove Parameters"></td><td>&nbsp;</td><td><input type="submit" name="priority" value="Change Priority"></td></tr>
		</table>
		</form>

		{include file="pages.tpl"}
	{else}
		<p>No waiting parameters for MultiJob {$jobid}</p>
	{/if}
</td></tr>
</table>
