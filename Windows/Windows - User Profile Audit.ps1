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
$CurrentUser = $CurrentUser -replace ".*\\"
Write-Output "Current user: $CurrentUser"

# Get last logged in user and strip the preceding
$LastUser = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name "LastLoggedOnUser").LastLoggedOnUser
$LastUser = $LastUser -replace ".*\\"
Write-Output "Last user: $LastUser"

# List exclusions
$ExcludeValues=@("Public", "Administrator", "Guest", "MSSQL$MICROSOFT##WID", ".NET v4.5", $extexclude, $CurrentUser, $LastUser) # Add any other common admin accounts here

Get-ChildItem C:\users | ForEach-Object { 
    $user = $_.Name
    If($user -in $ExcludeValues){return}   

    if ($assessonly -ne "true") {
        Write-Output "Deleting user $user" 
        Get-CimInstance -Class Win32_UserProfile | Where-Object {$_.LocalPath -like "*$user*"} | Remove-CimInstance
    }
    else {
        Write-Output "Suggest deleting $user"
    }
}