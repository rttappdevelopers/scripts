REM Requires variable: ESETUninstallPW

@echo off

REM Uninstall ESET File Security if installed.
echo Uninstalling ESET File Security
start /wait MsiExec.exe /X{D3BFEFDA-052D-42FD-BEE4-0C82B18A0713} /qn REBOOT="ReallySuppress" PASSWORD="%ESETUninstallPW%"

REM Uninstall ESET Antivirus if installed.
start /wait MsiExec.exe /X{082F6817-E4B9-406D-8E59-0551070D7B97} /qn REBOOT="ReallySuppress" PASSWORD="%ESETUninstallPW%"

REM Uninstall ESET Remote Administration Tool if installed.
Timeout 120 >nul
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41F12F70-5FA9-43F5-94F4-53B54EB4EEC4}
if %ERRORLEVEL% EQU 0 (  
REG ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{41F12F70-5FA9-43F5-94F4-53B54EB4EEC4} /f /v NoRemove /t REG_DWORD /d 0
timeout 5 >nul
start /wait MsiExec.exe /X{41F12F70-5FA9-43F5-94F4-53B54EB4EEC4} /qn
timeout 5 >nul
start /wait MsiExec.exe /X{41F12F70-5FA9-43F5-94F4-53B54EB4EEC4} /qn
)