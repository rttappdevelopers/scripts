# Get current user
$CurrentUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
Write-Output "Current user: $CurrentUser"

# Add current user to local administrators group
net localgroup administrators $CurrentUser /add