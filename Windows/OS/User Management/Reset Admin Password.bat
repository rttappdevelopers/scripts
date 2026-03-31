@ECHO OFF & setlocal EnableDelayedExpansion
REM Created by Jeff Pelletier
REM Create or Reset Random admin password [WIN]
REM Creates a randomly generated local admin password and sets it to a UDF field in RMM.
REM If the account does not exist, it will be created.
REM If the account exists, just the password will be reset and recorded.
REM If username is left blank, "RTTLocal" will be used for the username.
REM Variable: cs_name

chcp 1257

set "alpha=abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ!@#^"
set alphaCnt=53

Set "Password="
For /L %%j in (1,1,16) DO (
    Set /a i=!random! %% alphaCnt
    Call Set PASSWORD=!PASSWORD!%%alpha:~!i!,1%%
)
set PASSWORD=!PASSWORD!Z#z%random%
REM echo Your Random Password is [ %PASSWORD% ]

if [%cs_name%]==[] set cs_name=RTTLocal

echo --Check for or add user--
NET USER | find /i "!cs_name!" ||  NET USER /add "!cs_name!" "!PASSWORD!" /y
ping 127.0.0.1 >nul
echo --Set password--
NET USER "!cs_name!" "!PASSWORD!" /y
IF %ERRORLEVEL% EQU 0 (
REM Add UDF to RMM field 22
@echo Adding password to RMM
REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v Custom22 /t REG_SZ /d "!cs_name! - !PASSWORD!" /f
) else (
@Echo Error occurred, Password not updated in RMM.
)
WMIC USERACCOUNT WHERE Name='%cs_name%' SET PasswordExpires=FALSE
echo --Add user to local Administrators group if not already there--
NET LOCALGROUP administrators | find /i "!cs_name!" || NET LOCALGROUP administrators "!cs_name!" /add

Set "Password="