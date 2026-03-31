REM Cached Domain Credentials: ENABLE [WIN]
REM Sets registry keys to restore the cached logons to fifty and enable storage of domain credentials used for accessing network resources (causes prompt for password every time). 

reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v CachedLogonsCount /t REG_SZ /d 50 /f
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DisableDomainCreds /t REG_DWORD /d 0 /f