# Clears drivers from the Windows Driver Store
# Will automatically skip drivers that are still in use (tested)

# Change directory to the Windows INF directory
Set-Location $env:windir\inf

# Get a list of all OEM INF files
$infFiles = Get-ChildItem 'oem*.inf'

# For each INF file, run the pnputil /d command
foreach ($infFile in $infFiles) {
    write-output "Removing $($infFile.Name)"
    pnputil /d $infFile
    Write-output "`n"
}