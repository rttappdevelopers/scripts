# Check environment variable for $method value, either pnputil or pnpclean
$method = $env:method
if ($method -eq "pnputil") {
    # Clears drivers from the Windows Driver Store with pnputil. Will automatically skip drivers that are still in use (tested).
    Write-Output "Using pnputil"
    
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
    exit
} elseif ($method -eq "pnpclean") {
    # Clears drivers from the Windows Driver Store with pnpclean. May be safer than pnputil.
    Write-Output "Using pnpclean"
    rundll32.exe pnpclean.dll,RunDLL_PnpClean /DRIVERS /MAXCLEAN
    exit
} else {
    Write-Output "No method specified, defaulting to pnputil"    
}



