<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<table border="0" cellpadding="2" cellspacing="10">
	<tr>
		<td>
			<form method="get" action="{$formdest}">
			{* set hidden items *}
			{foreach from=$getitems key=hiddenkey item=hiddenvalue}
		        {if $hiddenkey neq "page" and $hiddenkey neq "step"}
		                <input type="hidden" name="{$hiddenkey}" value="{$hiddenvalue}">
		        {/if}
			{/foreach}
			<input type="hidden" name="step" value="{$step}">
			<input type="hidden" name="page" value="1">
			<input type="submit" value="<<">
			</form>
		</td>
		<td>
			<form method="get" action="{$formdest}">
			{* set hidden items *}
			{foreach from=$getitems key=hiddenkey item=hiddenvalue}
		        {if $hiddenkey neq "page" and $hiddenkey neq "step"}
		                <input type="hidden" name="{$hiddenkey}" value="{$hiddenvalue}">
		        {/if}
			{/foreach}
			<input type="hidden" name="step" value="{$step}">
			<input type="hidden" name="page" value="{$prevpage}">
			<input type="submit" value="<">
			</form>
		<td>
			<form method="get" action="{$formdest}">
			{* set hidden items *}
			{foreach from=$getitems key=hiddenkey item=hiddenvalue}
		        {if $hiddenkey neq "page" and $hiddenkey neq "step"}
		                <input type="hidden" name="{$hiddenkey}" value="{$hiddenvalue}">
		        {/if}
			{/foreach}
			<input type="hidden" name="step" value="{$step}">
			<input type="hidden" name="page" value="0">
			Page <input name="page" value="{$page}" size="4"> / {$maxpages} with <input name="step" value="{$step}" size="3"> items per page <input type="submit" value="Update">
			</form>
		</td>
		<td>
			<form method="get" action="{$formdest}">
			{* set hidden items *}
			{foreach from=$getitems key=hiddenkey item=hiddenvalue}
		        {if $hiddenkey neq "page" and $hiddenkey neq "step"}
		                <input type="hidden" name="{$hiddenkey}" value="{$hiddenvalue}">
		        {/if}
			{/foreach}
			<input type="hidden" name="step" value="{$step}">
			<input type="hidden" name="page" value="{$nextpage}">
			<input type="submit" value=">"></td>
			</form>
	 	<td>
			<form method="get" action="{$formdest}">
			{* set hidden items *}
			{foreach from=$getitems key=hiddenkey item=hiddenvalue}
		        {if $hiddenkey neq "page" and $hiddenkey neq "step"}
		                <input type="hidden" name="{$hiddenkey}" value="{$hiddenvalue}">
		        {/if}
			{/foreach}
			<input type="hidden" name="step" value="{$step}">
			<input type="hidden" name="page" value="{$maxpages}">
			<input type="submit" value=">>">
			</form>
		</td>
	</tr>
	</table>
</td></tr>
</table>
