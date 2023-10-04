# Be SUPER careful with this script!!
# Always run the audit with "assess only" first and make sure it doesn't delete all users or the last active user
# This can happen if the system uses a domain and the domain isn't reachable at the tme of audit

# Convert environment / passthrough variables from RMM
# Set these directly if running from command line
if ($env:domain -eq "true") { $domain = "/domain" }
if ($env:assessonly -eq "true") { $assessonly = "true" }
$extexclude = $env:extexclude

# Get current user
$CurrentUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName

# List exclusions
$ExcludeValues=@("Public", "Administrator", "Guest", "MSSQL$MICROSOFT##WID", ".NET v4.5", $extexclude, $CurrentUser) # Add any other common admin accounts here

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