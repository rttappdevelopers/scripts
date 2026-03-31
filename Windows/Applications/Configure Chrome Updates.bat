REM Chrome Update Setting [WIN]
REM Changes Chrome to allow automatic updates

reg add HKLM\SOFTWARE\Policies\Google\Update  /v DisableAutoUpdateChecksCheckboxValue /t REG_DWORD /d 00000000 /f
reg add HKLM\SOFTWARE\Policies\Google\Update  /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 00000120 /f
reg add HKLM\SOFTWARE\Wow6432Node\Policies\Google\Update  /v DisableAutoUpdateChecksCheckboxValue /t REG_DWORD /d 00000000 /f
reg add HKLM\SOFTWARE\Wow6432Node\Policies\Google\Update  /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 00000120 /f