@echo Off
if exist "%ProgramFiles(x86)%\Timeslips\." (
  @echo Remove program shortcuts
  if exist "%public%\desktop\Sage Timeslips.lnk" del /q /f "%public%\desktop\Sage Timeslips.lnk"
  del /q /f "%programdata%\Microsoft\Windows\Start Menu\Programs\Timeslips\*.lnk"
  rmdir /s /q "%programdata%\Microsoft\Windows\Start Menu\Programs\Timeslips"
  @echo Stop and remove the Timeslips Backup service
  net stop TimeslipsBackup
  sc delete TSScheduleBackup
  @echo End process on any Timeslips related applications
  FOR /F "delims=" %%G in ('FORFILES /P "%ProgramFiles(x86)%\Timeslips" /M *.EXE /S') DO ( TASKKILL /F /IM %%G /T )
  @echo Removing program files and registry entries
  del /q /f /s "%ProgramFiles(x86)%\Timeslips\*"
  rmdir /s /q "%ProgramFiles(x86)%\Timeslips"
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{1169F23D-10DB-4EDF-8FFC-4D8FB93C9824}" /f
  reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Peachtree\Applications\Peachtree Accounting Link for Timeslips" /f
)
exit