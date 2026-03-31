@echo off
REM Enter current version number. Default is 7.4.6 as of 2024-10-28
REM Source: https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi

set powershellversion=%NINJARMMCLI% get %powershellversion%
msiexec /i https://github.com/PowerShell/PowerShell/releases/download/%powershellversion%/PowerShell-%powershellversion%-win-x64.msi /qn