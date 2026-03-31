<# 
Written by Chaim Black

Verion 1.1

Created on 12/21/2021

Last update: 12/21/2021

Change log:

    Version 1.1: Adds support to check for APC PowerChute Network Shutdown service in addition to APC PowerChute Business Edition

Warning!! This script has not been verified by APC nor has this been tested on many systems or versions. Run at your own risk. 

This script is in response to to CVE-2021-44228 (Log4Shell) to remediate the APC PowerChute software. This remdiates APC PowerChute Network Shutdown and APC PowerChute Business Edition.

Based off of information from https://www.se.com/ww/en/download/document/SESB-2021-347-01/
This script searches for and removes 'JndiLookup.class' from the log4j file. 
Requires .Net 4.5

Outputs:

    "Success"                      = Script was a success
    "NoIssueFound"                 = Located and found file and no detection of JndiLookup.class
    "FailedToStop"                 = Failed to stop service
    "DotNetError"                  = Missing required .Net 4.5
    "FailedToLocate"               = Failed to locate any log4j files
    "CompressionError"             = Failed to load compression
    "FailedToFix"                  = Failed to remediate file by removing JndiLookup.class
    "Success_FailedToRestart"      = Failed to restart service after removing JndiLookup.class
    "NoIssueFound_FailedToRestart" = Failed to restart service after not finding any issue

#>
$NetVerify = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -ge 378389
if (!($NetVerify)) {Write-Host "DotNetError"; break}

$TargetFile = (Get-ChildItem -Path 'C:\Program Files (x86)\apc' -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.FullName -like "*log4j-core-*"}).FullName
if (!($TargetFile)) {
    $TargetFile = (Get-ChildItem -Path 'C:\Program Files\apc' -Recurse -ErrorAction SilentlyContinue | Where-Object {$_.FullName -like "*log4j-core-*"}).FullName
}
if (!($TargetFile)) {
    Write-Host "FailedToLocate"
    break
}

$Service_APCPBEAgent = Get-Service -Name APCPBEAgent -ErrorAction SilentlyContinue
$Service_PCNS1       = Get-Service -Name PCNS1 -ErrorAction SilentlyContinue

if ($Service_APCPBEAgent) {
    $ServiceName   = 'APCPBEAgent'
    $ServiceExists = $True
}
if ($Service_PCNS1) {
    $ServiceName   = 'PCNS1'
    $ServiceExists = $True
}

if ($ServiceExists) {
    if ((Get-Service -Name $ServiceName).Status -like "Running") { Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue}
    if ((Get-Service -Name $ServiceName).Status -like "Running") {
        Start-Sleep -Seconds 20
        if ((Get-Service -Name $ServiceName).Status -like "Running") {Write-Host "FailedToStop"; break}
    }
}

$Load = [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression')
if (!($Load)) {Write-Host "CompressionError"; break}
$stream = New-Object IO.FileStream($TargetFile, [IO.FileMode]::Open)
$mode   = [IO.Compression.ZipArchiveMode]::Update
$zip    = New-Object IO.Compression.ZipArchive($stream, $mode)
$Remove = ($zip.Entries | Where-Object {$_.FullName -like "*JndiLookup*"}) 
if ($Remove) {
    $Remove | ForEach-Object { $_.Delete() }
    $zip.Dispose()
    $stream.Close()
    $stream.Dispose()
}
Else {
    $zip.Dispose()
    $stream.Close()
    $stream.Dispose()
    if ($ServiceExists) {
        Start-Service -Name $ServiceName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if ((Get-Service -Name $ServiceName).Status -like "Running"){
            Write-Host "NoIssueFound"
        }
        Else {
            Start-Sleep -Seconds 10
            if ((Get-Service -Name $ServiceName).Status -like "Running"){
                Write-Host "NoIssueFound"
            }
            Else{
                Write-Host "NoIssueFound_FailedToRestart"
            }
        }
        break
    }
    Else {Write-Host "NoIssueFound"; Break}
}

#Verify
$Load = [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression')
if (!($Load)) {Write-Host "CompressionError"; break}
$stream = New-Object IO.FileStream($TargetFile, [IO.FileMode]::Open)
$mode   = [IO.Compression.ZipArchiveMode]::Update
$zip    = New-Object IO.Compression.ZipArchive($stream, $mode)
$Entry = ($zip.Entries | Where-Object {$_.FullName -like "*JndiLookup*"}) 
$zip.Dispose()
$stream.Close()
$stream.Dispose()
if ($Entry){Write-Host "FailedToFix"}
Else {
    if ($ServiceExists) {
        Start-Service -Name $ServiceName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if ((Get-Service -Name $ServiceName).Status -like "Running"){
            Write-Host "Success"
        }
        Else {
            Start-Sleep -Seconds 10
            if ((Get-Service -Name $ServiceName).Status -like "Running"){
                Write-Host "Success"
            }
            Else{
                Write-Host "Success_FailedToRestart"
            }
        }
    }
    Else {Write-Host "Success"}
}