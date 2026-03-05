Import-Module MSOnline
Connect-MsolService
$onlineusers = Get-MsolUser -All | Select-Object UserprincipalName,ImmutableID,WhenCreated,LastDirSyncTime #| Export-Csv c:\MyFile.csv -NoTypeInformation