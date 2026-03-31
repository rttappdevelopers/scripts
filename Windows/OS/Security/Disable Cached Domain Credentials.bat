REM Cached Domain Credentials: DISABLE [WIN]
REM Sets registry keys to reduce the cached logons to zero and disable storage of domain credentials used for accessing network resources (causes prompt for password every time). Use this in conjunction with the reboot component to lock out remote users for offboarding.

reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v CachedLogonsCount /t REG_SZ /d 0 /f
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DisableDomainCreds /t REG_DWORD /d 1 /f