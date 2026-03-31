# AnyDesk Install [Win]
# Downloads and installs latest version of AnyDesk with auto-update enabled

# Download https://download.anydesk.com/AnyDesk.exe
# and install with syntax: AnyDesk.exe --install "C:\Program Files (x86)\AnyDesk" --start-with-win --create-shortcuts --create-desktop-icon --silent --update-auto

# Look for C:\temp and create it if it's not there
if (!(Test-Path -Path "C:\temp")) {
    New-Item -Path "C:\temp" -ItemType "directory"
    Write-Host "Created C:\temp directory."
}

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

# Download the AnyDesk installer
Invoke-WebRequest -Uri "https://download.anydesk.com/AnyDesk.exe" -OutFile "C:\temp\AnyDesk.exe"
Write-Host "Downloaded AnyDesk installer."

# Install AnyDesk
Start-Process -FilePath "C:\temp\AnyDesk.exe" -ArgumentList "--install `"C:\Program Files (x86)\AnyDesk`" --start-with-win --create-shortcuts --create-desktop-icon --silent --update-auto" -Wait
Write-Host "Installed AnyDesk."

# Wait for the AnyDesk installation process to finish
$anyDeskProcess = Get-Process -Name "AnyDesk"
if ($anyDeskProcess) {
    Write-Host "Waiting for AnyDesk installation to complete..."
    Wait-Process -Id $anyDeskProcess.Id
}

# Remove the installer
Remove-Item -Path "C:\temp\AnyDesk.exe" -Force
Write-Host "Removed AnyDesk installer."