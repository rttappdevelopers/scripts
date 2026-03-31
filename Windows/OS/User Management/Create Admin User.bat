@ECHO OFF
REM Created by Jeff Pelletier
REM add user redux build 1/seagull
REM Modified to add/change password Jeff Pelletier

echo Create New Administrative User
echo ================================

REM Username length check
set #=%cs_name%
set /a varUserLength=0
:loop2
if defined # (set #=%#:~1%&set /A varUserLength += 1&goto loop2)

if %varUserLength% gtr 20 (
	echo ERROR: Username must be no greater than 20 characters in length.
	echo Please re-run this Component with a shorter username.
	exit
)

echo --Check for or add user--
NET USER | find /i "%cs_name%" ||  NET USER /add "%cs_name%" "%cs_password%" /y
ping 127.0.0.1 >nul
echo --Set password--
NET USER "%cs_name%" "%cs_password%" /y
WMIC USERACCOUNT WHERE Name='%cs_name%' SET PasswordExpires=FALSE
echo --Add user to local Administrators group if not already there--
NET LOCALGROUP administrators | find /i "%cs_name%" || NET LOCALGROUP administrators "%cs_name%" /add