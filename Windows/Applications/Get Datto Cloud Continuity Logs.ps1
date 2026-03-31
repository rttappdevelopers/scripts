# Pulls logs from Datto Cloud Continuity agent and system event logs for Datto Support

# Establish variables
$tempPath = "C:\TEMP"
$compressedFilename = "DattoCloudContinuityDebug.zip"

# Establish location to save results
if (!(Test-Path $tempPath)) {
    New-Item -ItemType Directory -Path $tempPath
}

# Check for the existence of the resulting zip file
if (Test-Path "$tempPath\$compressedFilename") {
    Write-Output "Removing existing zip file"
    Remove-Item "$tempPath\$compressedFilename"
}

# Create zip file from log folder
Write-Output "Pulling logs from Datto Cloud Continuity"
Compress-Archive -Path "C:\Windows\System32\config\systemprofile\AppData\Local\Datto\Datto Cloud Continuity\logs\" -DestinationPath "$tempPath\$compressedFilename"

# Pull system and application event logs
## Get list of services running
Write-Output "Getting list of services running"
& net start > $tempPath\services.txt
Compress-Archive -Path $tempPath\services.txt -DestinationPath "$tempPath\$compressedFilename" -Update

## List VSS shadow copies
Write-Output "Listing VSS shadow copies"
& vssadmin list shadows > $tempPath\vshadows.txt
Compress-Archive -Path $tempPath\vshadows.txt -DestinationPath "$tempPath\$compressedFilename" -Update

## Get system info
Write-Output "Getting system info"
msinfo32 /report $tempPath\msinfo-datto.txt 
Start-Sleep -Seconds 300
Compress-Archive -Path $tempPath\msinfo-datto.txt -DestinationPath "$tempPath\$compressedFilename" -Update

## Back up Application event log to temp folder
Write-Output "Pulling system and application event logs"
wevtutil epl System $tempPath\System.evtx
wevtutil epl Application $tempPath\Application.evtx
Compress-Archive -Path $tempPath\*.evtx -DestinationPath "$tempPath\$compressedFilename" -Update

# Clean up temp files
Write-Output "Cleaning up temp files"
Remove-Item "$tempPath\Application.evtx"
Remove-Item "$tempPath\System.evtx"
Remove-Item "$tempPath\services.txt"
Remove-Item "$tempPath\vshadows.txt"
Remove-Item "$tempPath\msinfo-datto.txt"

# End
Write-Output "Zip file is ready at $tempPath\$compressedFilename"