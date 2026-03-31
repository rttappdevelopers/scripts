@ECHO OFF

ECHO SFC Scan
sfc /scannow

ECHO DISM
DISM.exe /Online /Cleanup-image /Restorehealth

ECHO GPUpdate
gpupdate /force

ECHO Scheduling Checkdisk for next boot
echo y | chkdsk /r

if %ERRORLEVEL% NEQ 0 exit %ERRORLEVEL%