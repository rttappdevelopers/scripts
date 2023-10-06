# Download Splashtop SOS from https://my.splashtop.com/src/msi?platform=web&utm_source=direct&utm_medium=direct&page=downloads and install it silently

# Check for temp folder and create if missing
if (!(Test-Path -Path "C:\Temp")) {New-Item -Path "C:\Temp" -ItemType Directory}

# Download Splashtop SOS
$SOSFILE = "C:\Temp\SplashtopSOS.msi"
$SOSURL = "https://my.splashtop.com/src/msi?platform=web&utm_source=direct&utm_medium=direct&page=downloads"
if (Test-Path -Path $SOSFILE) {Remove-Item -Path $SOSFILE -Force}
Invoke-WebRequest -Uri $SOSURL -OutFile $SOSFILE

# Check to see if Splashtop SOS is running and pause script until it is no longer running
$SOSPROCESS = "strwinclt"
while (Get-Process -Name $SOSPROCESS -ErrorAction SilentlyContinue) {
    Write-Output "$SOSPROCESS is running suggesting that SplashTop SOS is in use, waiting 5 minutes"
    Start-Sleep -Seconds 300
}

# Install Splashtop SOS
Write-Output "Installing $SOSFILE"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $SOSFILE /quiet /norestart" -Wait

# Check for msieexec.exe and pause script until it is no longer running
while (Get-Process -Name "msiexec" -ErrorAction SilentlyContinue) {
    Write-Output "msiexec.exe is running suggesting that the installation is in process, waiting 5 minutes"
    Start-Sleep -Seconds 300
}

# Cleanup
Remove-Item -Path $SOSFILE -Force