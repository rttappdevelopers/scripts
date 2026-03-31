REM Disable Windows Unwelcome Experience
REM Enters the required registry key and reboots the system. Once back online, the local users shouldn't be required to enter Microsoft account credentials.

REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f
shutdown -r -t 0