# Uninstalls Sophos Endpoint Protection
# Tamper Protection should be disabled, and a reboot prior to removal may be required

# Establish commands for uninstall based on version
## For Windows 10 (x64) and Windows 2016 and later running Core Agent 2022.4 and later
$CoreAgentNew = "C:\Program Files\Sophos\Sophos Endpoint Agent\SophosUninstall.exe"
## For Core Agent 2022.2 and older
$CoreAgentOld = "C:\Program Files\Sophos\Sophos Endpoint Agent\uninstallcli.exe"

# Check if the Sophos Endpoint Agent folder exists
## Is the new or older version of the agent installed?
if (Test-Path -Path $CoreAgentNew) {
  # Write output that the new version was found and will be removed
  Write-Host "Uninstalling $CoreAgentNew"

  # Uninstall command
  & $CoreAgentNew --quiet

  # Wait 15 minutes and check to see if the folder was successfully removed
  Start-Sleep -Seconds 900
  if (!(Test-Path -Path $CoreAgentNew)) {Write-Host "Successfully removed"} else {Write-Host "Software folder remains"}

} elseif (Test-Path -Path $CoreAgentOld) {
  # Write output that the old version was found and will be removed
  Write-Host "Uninstalling $CoreAgentOld"

  # Uninstall command
  & $CoreAgentOld --quiet

  # Wait 15 minutes and check to see if the folder was successfulyl removed
  Start-Sleep -Seconds 900
  if (!(Test-Path -Path $CoreAgentOld)) {Write-Host "Successfully removed"} else {Write-Host "Software folder remains"}

} else {
  # Write output that no Sophos folders were found
  Write-Host "Sophos Endpoint Protection does not appear to be installed"
}