# Take envrioment variable from RMM for user profile name, check for its existence on the system and delete it, and then checks for a profile with the same name and deletes that.

# Make sure environment variable "useracct" is set
if ($null -eq $env:useracct) {
    Write-Output "Environment variable 'username' not set, exiting."
    exit
}
else {
    $useracct = $env:useracct
}

# Check for existence of user account on system and delete it, and exit if not found
if (Get-WmiObject -Class Win32_UserAccount | Where-Object {$_.Name -eq $useracct}) {
    Write-Output "User account found, deleting."
    Remove-LocalUser -Name $useracct
}
else {
    Write-Output "User account not found, exiting."
    exit
}

# Check for profile folder and delete if found
if (Test-Path "C:\Users\$useracct") {
    Write-Output "User profile found, deleting."
    Remove-Item -Recurse -Force "C:\Users\$useracct"
}
else {
    Write-Output "User profile not found, exiting."
    exit
}
