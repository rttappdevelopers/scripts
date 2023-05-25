# Run as-is to search for any service running as a non-system user account
# Uncomment line 5 and comment line 8 to specify usernames to look for when run locally
# Uncomment line 6 and remove line 8 for execution by RMM

## $searchterm = "admin"
## $searchterm = $env:searchterm

clear-variable searchterm

Write-Output "Checking for services running as usernames containing: $searchterm"

function Get-ServiceLogonAccount {
[cmdletbinding()]            
param (
$ComputerName = $env:computername,
$LogonAccount
) 
    if($logonAccount) {
        Get-WmiObject -Class Win32_Service -ComputerName $ComputerName |`
Where-Object { $_.StartName -match $LogonAccount } | Select-Object DisplayName, StartName, State 
    } else { 
        Get-WmiObject -Class Win32_Service -ComputerName $ComputerName | `
Select-Object DisplayName, StartName, State
    }     
}

# Poll for services matching substring if specified, otherwise any services using non-system accounts
if (($null -eq $searchterm) -or ($searchterm -eq "")) {
    # Get all services utilizing non-system (user) accounts
    $results = Get-ServiceLogonAccount | Where-Object {($_.StartName -ne “LocalSystem”) -and ($_.StartName -ne “NT Authority\LocalService”) -and ($_.StartName -ne “NT Authority\NetworkService”) -and ($_.StartName -ne $null)} | Where-Object {$_.State -eq “Running”}
    }
    else {
    # Get services with specified substring
    $results = Get-ServiceLogonAccount | Where-Object {($_.StartName -match $searchterm)}
}

# Output results to stdout, count to RMM UDF and stdout
if ($null -ne $results){
    Write-Output "`nServices found: " $results
    $count = $results | Measure-Object | Select-Object -ExpandProperty count
    Write-Output "`nNumber of services: " $count
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v Custom30 /t REG_SZ /d "$count" /f
}
else{
    REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage /v Custom30 /t REG_SZ /d "0" /f
    Write-Output "No results"
}