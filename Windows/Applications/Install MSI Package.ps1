# Description: Install an MSI package from a URL
# Requires variable: ninjaurl
Write-Host Installing MSI package from $env:ninjaurl
if (-not (Test-Path 'C:\TEMP')) { New-Item -ItemType Directory -Path 'C:\TEMP' }
$msiexec = Get-Command -Name 'msiexec' | Select-Object -ExpandProperty Source

if (Test-Path 'C:\TEMP\package.msi') {
    Write-Host "Using cached package.msi"
    $process = Start-Process -FilePath $msiexec -ArgumentList "/i C:\TEMP\package.msi /qn" -PassThru
    $process.WaitForExit()
    Remove-Item -Path 'C:\TEMP\package.msi'
} else {
    if (Start-BitsTransfer -Source $env:ninjaurl -Destination 'C:\TEMP\package.msi') {
        Write-Host "Downloading package.msi from $env:ninjaurl"
        Start-Sleep -Seconds 120
        $process = Start-Process -FilePath $msiexec -ArgumentList "/i C:\TEMP\package.msi /qn" -PassThru
        $process.WaitForExit()
        Remove-Item -Path 'C:\TEMP\package.msi'
    }
    else {
        Write-Host "Failed to download package.msi from $env:ninjaurl"
    }
}