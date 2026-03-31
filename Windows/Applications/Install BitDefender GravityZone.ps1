# Description: Install an MSI package from a URL
# Requires variable: bitdefenderWindowsPackage
$bitdefenderWindowsPackage=Ninja-Property-Get bitdefenderWindowsPackage

# If environment variable is not set and in the correct format, exit with error
if (-not $bitdefenderWindowsPackage -or $bitdefenderWindowsPackage -notmatch '^[a-zA-Z0-9\+\/\=]+$') {
    Write-Host "Environment variable bitdefenderWindowsPackage is not set or not in the correct format, provided value: $bitdefenderWindowsPackage"
    exit 1
}
$bitdefenderURL = "https://cloud.gravityzone.bitdefender.com/Packages/BSTWIN/0/setupdownloader_[$bitdefenderWindowsPackage].exe"
$bitdefenderFile = "C:\TEMP\setupdownloader_[$bitdefenderWindowsPackage].exe"
if (-not (Test-Path 'C:\TEMP')) { New-Item -ItemType Directory -Path 'C:\TEMP' }

# Download the setupdownloader file with its full filename from the bitdefenderURL variable to C:\TEMP
Write-Host "Downloading $bitdefenderFile from $bitdefenderURL`n"
Start-BitsTransfer -Source $bitdefenderURL -Destination $bitdefenderFile

# Run the setupdownloader file with the silent parameter
$process = Start-Process -FilePath $bitdefenderFile -ArgumentList '/bdparams /silent' -PassThru
$process.WaitForExit()
Remove-Item -Path $bitdefenderFile
