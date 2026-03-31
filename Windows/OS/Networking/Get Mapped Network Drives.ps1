$mappeddrives = Get-SMBMapping | Select-Object LocalPath, RemotePath | Format-Table -HideTableHeaders | Out-String
$mappeddrives 
Ninja-Property-Set mappedDrives $mappeddrives