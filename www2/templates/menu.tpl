{* maximum sub level, we assume that level 1 is always reached *}
{assign var="maxsublevel" value=1}
<table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color:#AA2200;">
<tr><td align="center">
	<table border="0" cellpadding="7" cellspacing="0">
	<tr>
		{* flag to check if an empty space must be displayed before the item (ie we are not dealing with the the first item) *}
		{assign var="notfirstitem" value=false}
		{foreach from=$MENU item=secondkey}
			{if $secondkey.level eq 1}
				{* current item? then give it the right design *}
				{if $secondkey.current eq true}
					{assign var="currentparam" value="color:#000000;background-color:#FFFFFF;text-decoration: underline;"}
					{assign var="tdbgcolor" value="#FFFFFF"}
				{else}
					{assign var="currentparam" value="color:#FFFFFF;background-color:#AA2200;"}
					{assign var="tdbgcolor" value="#AA2200"}
				{/if}
				{if $notfirstitem eq true}
					<td></td>
				{/if}
				<td style="background-color:{$tdbgcolor};">
				<a href="{$secondkey.link}" class="menuclass1" style="{$currentparam}">{$secondkey.name}</a>
				</td>
				{assign var="notfirstitem" value=true}
			{else}
				{* check if cuurent level > maxsublevel *}
				{if $secondkey.level > $maxsublevel}
					{assign var="maxsublevel" value=$secondkey.level}
				{/if}
			{/if}
		{/foreach}
	</tr>
	</table>
</td></tr>
</table>
<!-- Menu sub level 2 -->
{if $maxsublevel >= 2}
	<table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color:#FFFFFF;">
	<tr><td align="center">
		<table border="0" cellpadding="7" cellspacing="0">
		<tr>
			{* flag to check if a pipe must be displayed before the item (ie we are not dealing with the the first item) *}
			{assign var="notfirstitem" value=false}
			{foreach from=$MENU item=secondkey}
				{if $secondkey.level eq 2}
					{* current item? then give it the right design *}
					{if $secondkey.current eq true}
						{assign var="currentparam" value="font-weight:bold;text-decoration:underline;"}
					{else}
						{assign var="currentparam" value=""}
					{/if}
					{if $notfirstitem eq true}
						<td>&nbsp;|&nbsp;</td>
					{/if}
					<td>
						<a href="{$secondkey.link}" class="menuclass2" style="{$currentparam}">{$secondkey.name}</a>
						{assign var="notfirstitem" value=true}
					</td>
				{/if}
			{/foreach}
		</tr>
		</table>
	</td></tr>
	</table>
	{* display a thin line under this menu *}
	<table border="0" cellpadding="0" cellspacing="0" width="100%">
		<tr><td align="center">
			<table border="0" cellpadding="1" cellspacing="0" width="95%" style="background-color: #777777;">
				<tr><td></td></tr>
			</table>
		</td></tr>
	</table>
{/if}
<!-- display path -->
<table border="0" cellpadding="10" cellspacing="0" width="100%" style="background-color:#FFFFFF;">
<tr>
	<td>
	You are currently in :
	{assign var="notfirstitem" value=false}
	{foreach from=$CURRENTARRAY item=secondkey}
		{if $notfirstitem eq true}
			&nbsp;&gt;&nbsp;
		{/if}
		<a href="{$secondkey.link}">{$secondkey.name}</a>
		{assign var="notfirstitem" value=true}
	{/foreach}
	</td>
</tr>
</table>

