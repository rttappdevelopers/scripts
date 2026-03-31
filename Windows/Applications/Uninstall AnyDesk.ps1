# Find and remove AnyDesk from Windows
# Reference: https://support.anydesk.com/knowledge/use-cases-for-the-command-line-interface
# Reference: https://support.anydesk.com/Command_Line_Interface

# Check for AnyDesk process and service and kill it
$AnyDeskService = Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($AnyDeskService) {
    Write-Output "Stopping AnyDesk service"
    Stop-Service -Name "AnyDesk" -Force
}
else {
    Write-Output "AnyDesk service not found"
}

$AnyDeskProcess = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($AnyDeskProcess) {
    Write-Output "Killing AnyDesk process"
    Stop-Process -Name "AnyDesk" -Force
}
else {
    Write-Output "AnyDesk process not found"
}

# Check if AnyDesk is installed and uninstall it
$AnyDeskPath = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
$AnyDeskInstalled = Test-Path $AnyDeskPath
if ($AnyDeskInstalled) {
    Write-Output "Uninstalling AnyDesk"
    Start-Process -FilePath $AnyDeskPath -ArgumentList "--remove" -Wait
}
else {
    Write-Output "AnyDesk is not installed"
}