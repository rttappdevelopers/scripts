# Silent Install Dropbox 
# Download URL: https://www.dropbox.com/downloading?full=1&os=win

# Path for the workdir
$workdir = "c:\temp\"

# Check if work directory exists, if not create it
if (Test-Path -Path $workdir -PathType Container) {
    Write-Host "$workdir already exists" -ForegroundColor Red
} else {
    New-Item -Path $workdir -ItemType directory
}

# Download the installer
$source = "https://www.dropbox.com/download?full=1&plat=win"
$destination = "$workdir\dropbox.exe"

# Check if Invoke-WebRequest exists, otherwise execute WebClient
if (Get-Command 'Invoke-WebRequest') {
    Invoke-WebRequest $source -OutFile $destination
} else {
    $WebClient = New-Object System.Net.WebClient
    $webclient.DownloadFile($source, $destination)
}

# Start the installation
Start-Process -FilePath "$workdir\dropbox.exe" -ArgumentList "/S"

# Wait XX Seconds for the installation to finish
Start-Sleep -Seconds 300

# Remove the installer
Remove-Item -Force $workdir\dropbox*
