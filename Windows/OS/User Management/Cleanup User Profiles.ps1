# Convert environment / passthrough variables
if ($env:domain -eq "true") { $domain = "/domain" }
if ($env:assessonly -eq "true") { $assessonly = "true" }
$extexclude = $env:extexclude

# Get current user
$CurrentUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
$CurrentUser = $CurrentUser -replace ".*\\"
Write-Output "Current user: $CurrentUser"

# Get last logged in user and strip the preceding
$LastUser = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnUser").LastLoggedOnUser
$LastUser = $LastUser -replace ".*\\"
Write-Output "Last user: $LastUser"

# List exclusions
$ExcludeValues=@("Public", "Administrator", "Guest", "MSSQL$MICROSOFT##WID", ".NET v4.5", $extexclude, $CurrentUser, $LastUser) # Add any other common admin accounts here

$CutoffDate = (get-date).AddDays(-30).Date
Write-Output "Username`t`tLast Logon`t`tCutoff Date`t`tAction"
Get-ChildItem C:\users | ForEach-Object { 
    $user = $_.Name
    If($user -in $ExcludeValues){return}
    
    $lastlogon = net user $_.Name $domain | Select-String "Last logon"
    if ($lastlogon -match '\d+/\d+/\d{4}\s{1}\d+:\d+:\d{2}' -eq "True") {
        $dateout = $Matches[0]
        
        if ([DateTime]$dateout -lt [DateTime]$CutoffDate) { 
            if ($assessonly -ne "true") {
                Write-Output "$user `t $dateout `t $cutoffdate, deleting" 
                Get-CimInstance -Class Win32_UserProfile | Where-Object {$_.LocalPath -like "*$user*"} | Remove-CimInstance
            }
            else {
                Write-Output "$user `t $dateout `t $cutoffdate, suggest deleting"
            }
        }
        else
        {
            Write-Output "$user `t $dateout `t $cutoffdate, keeping"
        }
    }
    else {
        if ($assessonly -ne "true") {
            Write-Output "$user not on file, deleting."
            Get-CimInstance -Class Win32_UserProfile | Where-Object {$_.LocalPath -like "*$user*"} | Remove-CimInstance
        }
        else {
            Write-Output "$user not on file, suggest deleting."           
        }
    }
}