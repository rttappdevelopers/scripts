<#
.SYNOPSIS
    Retrieves BitLocker recovery key for C: drive and publishes to Ninja RMM custom field.

.DESCRIPTION
    This script gets the BitLocker recovery password for the system drive (C:) and 
    stores it in a Ninja RMM custom field for easy access in emergencies.

.NOTES
    Requires:
    - PowerShell 5.1 or later
    - Administrative privileges
    - BitLocker enabled on C: drive
    - Ninja RMM agent installed
#>

# Requires -RunAsAdministrator

# Configuration
$DriveLetter = "C:"
$NinjaCustomFieldName = "diskEncryptionKey"

try {
    # Check if BitLocker is enabled on the drive
    $bitlockerVolume = Get-BitLockerVolume -MountPoint $DriveLetter -ErrorAction Stop
    
    if ($bitlockerVolume.ProtectionStatus -eq "Off") {
        Write-Host "BitLocker is not enabled on drive $DriveLetter"
        Ninja-Property-Set $NinjaCustomFieldName "BitLocker Not Enabled"
        exit 0
    }

    # Get the recovery password key protectors
    $recoveryKeys = $bitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

    if ($recoveryKeys) {
        # If multiple recovery keys exist, get the first one
        $primaryRecoveryKey = $recoveryKeys | Select-Object -First 1
        
        # Explicitly convert to string and trim any whitespace
        [string]$recoveryPassword = $primaryRecoveryKey.RecoveryPassword
        $recoveryPassword = $recoveryPassword.Trim()
        
        if ($recoveryPassword) {
            Write-Host "BitLocker recovery key retrieved successfully"
            Write-Host "Recovery Key ID: $($primaryRecoveryKey.KeyProtectorId)"
            Write-Host "Total Recovery Keys Found: $($recoveryKeys.Count)"
            Write-Host "Recovery Password: $recoveryPassword"
            
            # Publish to Ninja RMM custom field
            Ninja-Property-Set $NinjaCustomFieldName $recoveryPassword
            
            Write-Host "BitLocker recovery key published to Ninja RMM custom field: $NinjaCustomFieldName"
        }
        else {
            Write-Warning "Recovery password not found for drive $DriveLetter"
            Ninja-Property-Set $NinjaCustomFieldName "No Recovery Password Found"
        }
    }
    else {
        Write-Warning "No recovery key protector found for drive $DriveLetter"
        Ninja-Property-Set $NinjaCustomFieldName "No Recovery Protector"
    }
}
catch {
    Write-Error "Error retrieving BitLocker information: $_"
    Ninja-Property-Set $NinjaCustomFieldName "Error: $($_.Exception.Message)"
    exit 1
}