@echo off
SET COPYCMD=/Y

msiexec.exe /i cisco-secure-client-win-5.1.2.42-core-vpn-predeploy-k9.msi /qn /norestart
mkdir "C:\ProgramData\Cisco\Cisco Anyconnect Secure Mobility Client\Profile\"
move profile.xml "C:\ProgramData\Cisco\Cisco AnyConnect Secure Mobility Client\Profile\profile.xml"