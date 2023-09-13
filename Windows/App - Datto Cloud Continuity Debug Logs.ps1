# Pulls logs from Datto Cloud Continuity agent and system event logs for Datto Support

# Establish variables
$tempPath = "C:\Temp"
$fileName = "DattoCloudContinuityDebug.zip"

# Establish location to save results
if (!(Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath
}

# Check for the existence of the resulting zip file
if (Test-Path "$tempPath\$fileName") {
    Write-Output "Removing existing zip file"
    Remove-Item "$tempPath\$fileName"
}

# Create zip file from log folder
Write-Output "Pulling logs from Datto Cloud Continuity"
Compress-Archive -Path "C:\Windows\System32\config\systemprofile\AppData\Local\Datto\Datto Cloud Continuity\logs\" -DestinationPath "$tempPath\$fileName"

# Pull system and application event logs
# Back up Application event log to temp folder
Write-Output "Pulling system and application event logs"
wevtutil epl System $tempPath\System.evtx
wevtutil epl Application $tempPath\Application.evtx

# Add logs to zip file
Compress-Archive -Path C:\temp\*.evtx -DestinationPath "$tempPath\$fileName" -Update
Write-Output "Zip file is ready at $tempPath\$fileName"

# Clean up temp files
Write-Output "Cleaning up temp files"
Remove-Item "$tempPath\Application.evtx"
Remove-Item "$tempPath\System.evtx"
