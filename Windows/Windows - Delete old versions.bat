@ECHO OFF
REM Command prompt script to remove previous versions of Windows cached on the hard drive for Windows 10 upgrades and rollbacks

REM Remove folders containing old Windows versions
IF EXIST "C:\$WINDOWS.~BT" (
    ECHO Found and removing $WINDOWS.~BT folder
    RMDIR /S /Q "C:\$WINDOWS.~BT"
)

IF EXIST "C:\$WINDOWS.~WS" (
    ECHO Found and removing $WINDOWS.~WS folder
    RMDIR /S /Q "C:\$WINDOWS.~WS"
)

IF EXIST "C:\windows.old" (
    ECHO Found and removing windows.old folder
    RMDIR /S /Q "C:\windows.old"
)

IF EXIST "C:\$WinREAgent" (
    ECHO Found and removing $WinREAgent folder
    RMDIR /S /Q "C:\$WinREAgent"
)

REM Check for Windows 10 Upgrade Assistant and run ForceUninstall
IF EXIST "C:\Windows10Upgrade\Windows10UpgraderApp.exe" (
    ECHO Found and uninstalling Windows 10 Upgrade Assistant
    "C:\Windows10Upgrade\Windows10UpgraderApp.exe" /ForceUninstall
)

IF EXIST "C:\Windows10Upgrade" (
    ECHO Found and removing Windows 10 Upgrade Assistant folder
    RMDIR /S /Q "C:\Windows10Upgrade"
)