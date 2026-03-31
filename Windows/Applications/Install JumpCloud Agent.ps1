# JumpCloud Agent Installer [WIN]
# Installs the JumpCloud agent on Windows. CompanyID Variable is the ID of the company to join the PC to. Variable must be set.
# Requires variable: CompanyID
cd $env:temp | Invoke-Expression; Invoke-RestMethod -Method Get -URI https://raw.githubusercontent.com/TheJumpCloud/support/master/scripts/windows/InstallWindowsAgent.ps1 -OutFile InstallWindowsAgent.ps1 | Invoke-Expression; ./InstallWindowsAgent.ps1 -JumpCloudConnectKey "$env:CompanyID"