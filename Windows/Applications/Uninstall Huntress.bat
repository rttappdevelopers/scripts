@ECHO OFF
REM Huntress Uninstall [WIN]
set huninstall="C:\Program Files\Huntress\Uninstall.exe"

IF EXIST %huninstall% (
    %huninstall% /S
	) ELSE (
	"C:\Program Files\Huntress\HuntressAgent.exe" uninstall /S
	"C:\Program Files\Huntress\HuntressUpdater.exe" uninstall /S
	rmdir "c:\Program Files\Huntress" /q /s
	timeout 10 > NULL
	reg delete "HKLM\SOFTWARE\Huntress Labs" /f
)