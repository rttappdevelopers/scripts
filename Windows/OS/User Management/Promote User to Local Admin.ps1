# If environment variable $cs_user is set, use it. Otherwise, use the current user.
$cs_user = $env:cs_user
If ([string]::IsNullOrEmpty($cs_user)) {
    $cs_user = (Get-WmiObject -Class Win32_ComputerSystem).UserName
    Write-Output "Current user: $cs_user"
}

# Add current user to local administrators group
net localgroup administrators $cs_user /add

# Check if the user is a member of the Administrators group
net localgroup administrators