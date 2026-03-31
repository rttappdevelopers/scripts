# Check for C:\Temp, create it if missing
if (!(Test-Path -Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory
}

# Download from: https://cf-dl.datto.com/cc4pc/DattoCloudContinuityInstaller.exe
$downloadURL = "https://cf-dl.datto.com/cc4pc/DattoCloudContinuityInstaller.exe"
$downloadPath = "C:\Temp\DattoCloudContinuityInstaller.exe"

# Download the installer
Invoke-WebRequest -Uri $downloadURL -OutFile $downloadPath

# Install the software
Start-Process -FilePath $downloadPath -ArgumentList "/install /quiet /norestart" -Wait

# Clean up the installer
Remove-Item -Path $downloadPath

