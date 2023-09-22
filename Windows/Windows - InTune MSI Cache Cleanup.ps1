# Set folder variable
$folder = $env:windir + "\System32\config\systemprofile\AppData\Local\mdm"

# Change folder to C:\Windows\System32\config\systemprofile\AppData\Local\mdm
Set-Location -Path $folder

# Get count of .msi files
$msiCount = (Get-ChildItem -Path $folder -Filter *.msi).Count

# Get total disk space used by .msi files
$msiSize = (Get-ChildItem -Path $folder -Filter *.msi | Measure-Object -Property Length -Sum).Sum

# Delete all .msi files
Get-ChildItem -Path $folder -Filter *.msi | Remove-Item -Force

# Get SizeRemaining of C:\ in gigabytes (rounded to a whole number) using get-volume
$sizeRemaining = [math]::Round((Get-Volume -DriveLetter C).SizeRemaining / 1GB)

# Write results of cleanup
Write-Host "Deleted $msiCount .msi files totaling $msiSize bytes, freeing $sizeRemaining GB of disk space."
```