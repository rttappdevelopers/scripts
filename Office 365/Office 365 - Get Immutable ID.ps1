#Requires -Version 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7 or later. Download it from https://aka.ms/powershell"
    exit 1
}
Import-Module MSOnline
Connect-MsolService
$onlineusers = Get-MsolUser -All | Select-Object UserprincipalName,ImmutableID,WhenCreated,LastDirSyncTime #| Export-Csv c:\MyFile.csv -NoTypeInformation
