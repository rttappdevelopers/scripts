# Insecure guest logon for SMB - Disable [WIN]
# Disables the local group policy Enable insecure guest logons, located in Computer Configuration\Administrative Templates\Network\Lanman Workstation; a common infection vector per BitDefender.
$regpath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
if (!(Test-Path $regpath)) { New-Item $regpath }
Set-ItemProperty -Path $regpath -Name AllowInsecureGuestAuth -Value "0" -Type DWord

$regpath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation\"
if (!(Test-Path $regpath)) { New-Item $regpath }
Set-ItemProperty -Path $regpath -Name AllowInsecureGuestAuth -Value "0" -Type DWord