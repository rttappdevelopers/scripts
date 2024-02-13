# Find and remove AnyDesk from Windows
# Reference: https://support.anydesk.com/knowledge/use-cases-for-the-command-line-interface
# Reference: https://support.anydesk.com/Command_Line_Interface

# Check for AnyDesk process and service and kill it
$AnyDeskService = Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($AnyDeskService) {
    Write-Output "AnyDesk service found"
    if ($assessonly -ne "true") {
        Write-Output "Stopping AnyDesk service"
        Stop-Service -Name "AnyDesk" -Force
    }
    else {
        Write-Output "Would stop AnyDesk service"
    }
}
else {
    Write-Output "AnyDesk service not found"
}

$AnyDeskProcess = Get-Process -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($AnyDeskProcess) {
    Write-Output "AnyDesk process found"
    if ($assessonly -ne "true") {
        Write-Output "Killing AnyDesk process"
        Stop-Process -Name "AnyDesk" -Force
    }
    else {
        Write-Output "Would kill AnyDesk process"
    }
}
else {
    Write-Output "AnyDesk process not found"
}

# Check if AnyDesk is installed
$AnyDeskPath = "C:\Program Files (x86)\AnyDesk\AnyDesk.exe"
$AnyDeskInstalled = Test-Path $AnyDeskPath
if ($AnyDeskInstalled) {
    Write-Output "AnyDesk is installed"
    # Uninstall AnyDesk
    if ($assessonly -ne "true") {
        Write-Output "Uninstalling AnyDesk"
        Start-Process -FilePath $AnyDeskPath -ArgumentList "--remove" -Wait
    }
    else {
        Write-Output "Would uninstall AnyDesk"
    }
}
else {
    Write-Output "AnyDesk is not installed"
}
