<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
	<title>{$pagetitle}</title>
	<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
	<meta http-equiv="Content-Script-Type" content="text/javascript">
	<link rel="stylesheet" href="{$toroot}stylesheet/cigri.css" type="text/css">
</head>
<body>
<table border="0" width="100%">
<tr>
<td align="center">
<!-- put an anchor at the top of the page-->
<a name="top"></a>
	<table border="0" width="740" cellpadding="0" cellspacing="0">
	<tr><td>
		<table border="0" width="100%" style="background-color:#AA2200;" cellpadding="1">
		<tr><td>
			<table border="0" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF">
			<tr><td>
				{include file="header.tpl"}
			</td></tr>
			<tr><td>
				{include file="menu.tpl"}
			</td></tr>
			<tr><td>
				{include file=$contenttemplate}
			</td></tr>
			</table>
		</td></tr>
		</table>
	</td></tr>
	<tr><td>
		{include file="footer.tpl"}
	</td></tr>
	</table>
</td>
</tr>
</table>
</body>
</html>

