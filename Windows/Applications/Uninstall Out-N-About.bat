@echo off
REM Kills Outlook process then uninstalls silently the Out-N-About plugin
taskkill /im outlook.exe /f /t
MsiExec.exe /X{D0F9BF0B-9B1F-402C-A27A-63700D3D2F65} /q
if exist "C:\WINDOWS\Out'n About! for Outlook\uninstall.exe" "C:\WINDOWS\Out'n About! for Outlook\uninstall.exe" "/U:C:\Program Files (x86)\Out'n About! for Outlook\Uninstall\uninstall.xml" /S
del "C:\Program Files (x86)\Out'n About! for Outlook\OutAboutOutlook.dll" /f /qREM Kills Outlook process then uninstalls silently the Out-N-About plugin
taskkill /im outlook.exe /f /t
MsiExec.exe /X{D0F9BF0B-9B1F-402C-A27A-63700D3D2F65} /q
"C:\WINDOWS\Out'n About! for Outlook\uninstall.exe" "/U:C:\Program Files (x86)\Out'n About! for Outlook\Uninstall\uninstall.xml" /S
del "C:\Program Files (x86)\Out'n About! for Outlook\OutAboutOutlook.dll" /f /q
