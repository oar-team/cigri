<table border="0" cellpadding="10" cellspacing="0" width="100%">
<tr><td align="center">
	<h3>Change user password</h3>
	<h5>{$MESSAGE}</h5>
	<form action="index.php" method="post">
	<input type="hidden" name="submenu" value="users">
	<input type="hidden" name="option" value="chpass">
	<input type="hidden" name="login" value="{$login}">
	<table border="0" cellpadding="5" cellspacing="5">
	<tr>
		<td>Login</td>
		<td>&nbsp;</td>
		<td>{$login}</td>
	</tr>
	<tr>
		<td>New password</td>
		<td>&nbsp;</td>
		<td><input name="pass1" type="password" size="10"></td>
	</tr>
	<tr>
		<td>Re-enter password</td>
		<td>&nbsp;</td>
		<td><input name="pass2" type="password" size="10"></td>
	</tr>
	<tr>
		<td colspan="3" align="center"><input type="submit" value="OK">&nbsp;<input type="reset" value="Cancel"></td>
	</tr>
	</table>
	</form>
</td></tr>
</table>
