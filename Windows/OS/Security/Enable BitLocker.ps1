# Ensure BitLocker module is available and load it
if (-not (Get-Module -ListAvailable -Name BitLocker)) {
    Write-Host "BitLocker module is not available. Please ensure it is installed."
    exit
}
Import-Module BitLocker -DisableNameChecking

# Chevk for TPM
$tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
if ($null -eq $tpm) {
    Write-Host "No TPM found. BitLocker cannot be enabled."
    exit 1
}
else {
    Write-Host "TPM found. Proceeding with BitLocker encryption."
}

# Identify the system drive
$systemDrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive
Write-Host "System drive is $systemDrive."

# Enable BitLocker on system volume with PowerShell
Enable-Bitlocker -MountPoint $systemDrive -UsedSpaceOnly -SkipHardwareTest -RecoveryPasswordProtector
Write-Host "BitLocker enabled on $systemDrive."

# Check if TPM key protector is already enabled
$bitlockerVolume = Get-BitLockerVolume -MountPoint $systemDrive
if ($bitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }) {
    Write-Host "TPM key protector is already enabled for drive $systemDrive."
}
else {
    Add-BitLockerKeyProtector -MountPoint $systemDrive -TpmProtector
}

# Encrypting the drive takes some time, if this reports a 'not enabled' status, 
# check "Encryption Percentage" column; another audit may be in order later on
Start-Sleep -Seconds 1800
manage-bde -protectors -enable $systemDrive 

# Check results
Write-Host "`nCurrent status of encryption:"
Get-BitLockerVolume