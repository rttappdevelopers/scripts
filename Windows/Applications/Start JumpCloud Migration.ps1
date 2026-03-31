# JumpCloud Start Migration
# This script is used to start the migration process to JumpCloud. 
# Requires variables: CompanyID, jcAPIkey, jcOrgkey, LocalUserName, tempPassword, JumpCloudUserName, LeaveDomain, ForceReboot, InstallJCAgent, AutobindJCUser
Set-Location $env:temp | Invoke-Expression

# Not sure if this is needed if we've already run 'JumpCloud Agent Installer'
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module JumpCloud.ADMU -Force

Invoke-RestMethod -Method Get -URI https://raw.githubusercontent.com/TheJumpCloud/jumpcloud-ADMU/master/jumpcloud-ADMU/Powershell/Start-Migration.ps1 -OutFile Start-Migration.ps1 | Invoke-Expression
./Start-Migration.ps1 -JumpCloudConnectKey "$env:CompanyID"

Start-Migration -SelectedUserName $env:LocalUserName -JumpCloudUserName $env:JumpCloudUserName -TempPassword $env:tempPassword -LeaveDomain $env:LeaveDomain -ForceReboot $env:ForceReboot -InstallJCAgent $env:InstallJCAgent -AutobindJCUser $env:AutobindJCUser -JumpCloudAPIKey $env:jcAPIkey -JumpCloudOrgID $env:jcOrgkey

# Note: All credentials and user-specific values must be supplied via
# NinjaOne environment variables — never hard-code them in this script.