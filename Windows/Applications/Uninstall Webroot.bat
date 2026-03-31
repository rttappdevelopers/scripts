@ECHO OFF 
ECHO "Uninstalling webroot"

IF EXIST "C:\Program Files\Webroot\" (
	IF EXIST "C:\Program Files\Webroot\WRSA.exe" (
		"C:\Program Files\Webroot\WRSA.exe" -uninstall)
	RMDIR /S /Q "C:\Program Files\Webroot\"
	ECHO "32-bit installation removed"
) ELSE (ECHO "No 32-bit installation found")

IF EXIST "C:\Program Files (x86)\Webroot\" (
	IF EXIST "C:\Program Files (x86)\Webroot\WRSA.exe" (
		"C:\Program Files (x86)\Webroot\WRSA.exe" -uninstall)
	RMDIR /S /Q "C:\Program Files (x86)\Webroot\"
	ECHO "64-bit installation removed"
) ELSE (ECHO "No 64-bit installation found")

ECHO "Cleaning up program data, if found."
IF EXIST "%PROGRAMDATA%\WRData" (RMDIR /S /Q "%PROGRAMDATA%\WRData")
IF EXIST "%PROGRAMDATA%\WRCore" (RMDIR /S /Q "%PROGRAMDATA%\WRCore")

ECHO "Work completed, reboot needed."