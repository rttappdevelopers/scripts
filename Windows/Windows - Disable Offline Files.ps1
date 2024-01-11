# Disable offline files for all users

$RegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\NetCache"
$RegValue = "Enabled"
$RegType = [Microsoft.Win32.RegistryValueKind]::DWord
$RegData = 0


# Disable offline files for all users
Set-ItemProperty -Path $RegKey -Name $RegValue -Type $RegType -Value $RegData -Force
