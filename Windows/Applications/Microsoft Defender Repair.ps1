#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Microsoft Defender Repair Script for NinjaRMM
.DESCRIPTION
    Provides multiple repair options for Microsoft Defender including enable, reset, and third-party AV removal
.NOTES
    Author: Brad Brown
    Date: January 6, 2026
    Version: 1.1
    Developed with Claude Sonnet 4.5
    NinjaRMM Integration: Uses Ninja-Property-Set to log results
.PARAMETER RepairAction
    The repair action to perform. Options include:
    - Enable Defender
    - Reset to Default
    - Remove Third-Party AV
    - Full Repair (All Steps)
    - Force Full Repair (No Checks)
    - Diagnostic Check Only
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet(
        "Enable Defender",
        "Reset to Default",
        "Remove Third-Party AV",
        "Full Repair (All Steps)",
        "Force Full Repair (No Checks)",
        "Diagnostic Check Only"
    )]
    [string]$RepairAction = "Diagnostic Check Only"
)

# Get NinjaRMM custom field if parameter not provided
if ($env:repairAction) {
    $RepairAction = $env:repairAction
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    
    # Also output to NinjaRMM custom field if needed
    if ($Level -eq "ERROR") {
        Write-Error $Message
    }
}

# Check current Defender status
function Get-DefenderStatus {
    Write-Log "Checking Microsoft Defender status..."
    
    try {
        $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
        $preferences = Get-MpPreference -ErrorAction Stop
        
        $status = @{
            ServiceRunning = (Get-Service -Name WinDefend -ErrorAction SilentlyContinue).Status -eq 'Running'
            RealTimeProtectionEnabled = $defenderStatus.RealTimeProtectionEnabled
            AntivirusEnabled = $defenderStatus.AntivirusEnabled
            AntispywareEnabled = $defenderStatus.AntispywareEnabled
            DisableRealtimeMonitoring = $preferences.DisableRealtimeMonitoring
            TamperProtectionSource = $defenderStatus.TamperProtectionSource
        }
        
        return $status
    }
    catch {
        Write-Log "Error checking Defender status: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Check for third-party antivirus
function Get-ThirdPartyAV {
    Write-Log "Checking for third-party antivirus software..."
    
    $avProducts = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
    $thirdPartyAV = $avProducts | Where-Object { $_.displayName -notlike "*Windows Defender*" -and $_.displayName -notlike "*Microsoft Defender*" }
    
    return $thirdPartyAV
}

# Enable Microsoft Defender
function Enable-Defender {
    Write-Log "Enabling Microsoft Defender..."
    
    try {
        # Start Windows Defender service
        $service = Get-Service -Name WinDefend -ErrorAction Stop
        if ($service.Status -ne 'Running') {
            Write-Log "Starting Windows Defender service..."
            Set-Service -Name WinDefend -StartupType Automatic
            Start-Service -Name WinDefend
            Start-Sleep -Seconds 5
        }
        
        # Enable Real-Time Protection via Registry
        Write-Log "Enabling Real-Time Protection via registry..."
        $defenderKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        $rtpKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
        
        if (!(Test-Path $defenderKey)) { New-Item -Path $defenderKey -Force | Out-Null }
        if (!(Test-Path $rtpKey)) { New-Item -Path $rtpKey -Force | Out-Null }
        
        Set-ItemProperty -Path $defenderKey -Name "DisableAntiSpyware" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $rtpKey -Name "DisableRealtimeMonitoring" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $rtpKey -Name "DisableBehaviorMonitoring" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $rtpKey -Name "DisableOnAccessProtection" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $rtpKey -Name "DisableScanOnRealtimeEnable" -Value 0 -Type DWord -Force
        
        # Enable via PowerShell cmdlet
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        
        Write-Log "Microsoft Defender enabled successfully"
        return $true
    }
    catch {
        Write-Log "Error enabling Defender: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Reset Defender to default settings
function Reset-DefenderToDefault {
    Write-Log "Resetting Microsoft Defender to default settings..."
    
    try {
        # Remove Defender policy registry keys
        Write-Log "Removing policy overrides..."
        $policyPaths = @(
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection"
        )
        
        foreach ($path in $policyPaths) {
            if (Test-Path $path) {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed policy: $path"
            }
        }
        
        # Reset preferences to default
        Write-Log "Resetting Defender preferences..."
        Set-MpPreference -DisableRealtimeMonitoring $false
        Set-MpPreference -DisableBehaviorMonitoring $false
        Set-MpPreference -DisableBlockAtFirstSeen $false
        Set-MpPreference -DisableIOAVProtection $false
        Set-MpPreference -DisableScriptScanning $false
        Set-MpPreference -SubmitSamplesConsent 1
        Set-MpPreference -MAPSReporting 2
        Set-MpPreference -HighThreatDefaultAction Clean
        Set-MpPreference -ModerateThreatDefaultAction Quarantine
        Set-MpPreference -LowThreatDefaultAction Quarantine
        Set-MpPreference -SevereThreatDefaultAction Remove
        
        # Restart the service
        Write-Log "Restarting Windows Defender service..."
        Restart-Service -Name WinDefend -Force
        
        Write-Log "Defender reset to default settings successfully"
        return $true
    }
    catch {
        Write-Log "Error resetting Defender: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Remove third-party antivirus (basic uninstall)
function Remove-ThirdPartyAV {
    Write-Log "Attempting to remove third-party antivirus..."
    
    $thirdPartyAV = Get-ThirdPartyAV
    
    if (!$thirdPartyAV) {
        Write-Log "No third-party antivirus detected"
        return $true
    }
    
    foreach ($av in $thirdPartyAV) {
        Write-Log "Found: $($av.displayName)"
    }
    
    # Get installed programs
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $installedPrograms = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.UninstallString }
    
    # Common AV product names to look for
    $avKeywords = @("antivirus", "avast", "avg", "mcafee", "norton", "symantec", "kaspersky", "bitdefender", "trend micro", "sophos", "webroot", "malwarebytes")
    
    foreach ($program in $installedPrograms) {
        $displayName = $program.DisplayName.ToLower()
        
        foreach ($keyword in $avKeywords) {
            if ($displayName -like "*$keyword*" -and $displayName -notlike "*defender*") {
                Write-Log "Found AV program: $($program.DisplayName)"
                Write-Log "Uninstall string: $($program.UninstallString)"
                Write-Log "Please manually uninstall or use vendor-specific removal tool" "WARNING"
            }
        }
    }
    
    Write-Log "Third-party AV check complete. Manual removal may be required."
    return $true
}

# Main execution
Write-Log "=== Microsoft Defender Repair Script Started ==="
Write-Log "Selected Action: $RepairAction"

# Run diagnostic check
$initialStatus = Get-DefenderStatus
if ($initialStatus) {
    Write-Log "Initial Status - Service Running: $($initialStatus.ServiceRunning)"
    Write-Log "Initial Status - Real-Time Protection: $($initialStatus.RealTimeProtectionEnabled)"
    Write-Log "Initial Status - Antivirus Enabled: $($initialStatus.AntivirusEnabled)"
} else {
    Write-Log "Unable to get initial Defender status" "WARNING"
}

$thirdPartyAV = Get-ThirdPartyAV
if ($thirdPartyAV) {
    Write-Log "Third-party AV detected: $($thirdPartyAV.displayName -join ', ')" "WARNING"
}

# Execute selected action
$success = $false

switch ($RepairAction) {
    "Enable Defender" {
        $success = Enable-Defender
    }
    "Reset to Default" {
        $success = Reset-DefenderToDefault
    }
    "Remove Third-Party AV" {
        $success = Remove-ThirdPartyAV
    }
    "Full Repair (All Steps)" {
        Write-Log "Performing intelligent full repair sequence..."
        $repairSuccess = $true
        
        # Step 1: Check for third-party AV
        $thirdPartyAVCheck = Get-ThirdPartyAV
        if ($thirdPartyAVCheck) {
            Write-Log "Third-party AV detected - attempting removal..."
            Remove-ThirdPartyAV
            Start-Sleep -Seconds 2
        } else {
            Write-Log "No third-party AV detected - skipping removal step"
        }
        
        # Step 2: Check if reset is needed
        $needsReset = $false
        if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender") {
            Write-Log "Defender policy overrides detected - reset needed"
            $needsReset = $true
        }
        
        $currentStatus = Get-DefenderStatus
        if ($currentStatus -and !$currentStatus.RealTimeProtectionEnabled -and $currentStatus.ServiceRunning) {
            Write-Log "Defender service running but protection disabled - reset needed"
            $needsReset = $true
        }
        
        if ($needsReset) {
            Write-Log "Performing reset to default settings..."
            if (!(Reset-DefenderToDefault)) {
                $repairSuccess = $false
            }
            Start-Sleep -Seconds 2
        } else {
            Write-Log "Defender settings appear normal - skipping reset"
        }
        
        # Step 3: Check if enable is needed
        $currentStatus = Get-DefenderStatus
        if (!$currentStatus -or !$currentStatus.RealTimeProtectionEnabled -or !$currentStatus.ServiceRunning) {
            Write-Log "Defender needs to be enabled..."
            if (!(Enable-Defender)) {
                $repairSuccess = $false
            }
        } else {
            Write-Log "Defender already enabled and running - skipping enable step"
        }
        
        $success = $repairSuccess
    }
    "Force Full Repair (No Checks)" {
        Write-Log "Performing FORCED full repair sequence (no checks)..."
        Write-Log "WARNING: This will execute all repair steps regardless of current state" "WARNING"
        
        # Force all steps
        Remove-ThirdPartyAV
        Start-Sleep -Seconds 2
        
        $resetSuccess = Reset-DefenderToDefault
        Start-Sleep -Seconds 2
        
        $enableSuccess = Enable-Defender
        
        $success = $resetSuccess -and $enableSuccess
    }
    "Diagnostic Check Only" {
        Write-Log "Diagnostic check completed. No changes made."
        $success = $true
    }
}

# Final status check
Start-Sleep -Seconds 3
$finalStatus = Get-DefenderStatus

if ($finalStatus) {
    Write-Log "=== Final Status ==="
    Write-Log "Service Running: $($finalStatus.ServiceRunning)"
    Write-Log "Real-Time Protection: $($finalStatus.RealTimeProtectionEnabled)"
    Write-Log "Antivirus Enabled: $($finalStatus.AntivirusEnabled)"
    
    if ($finalStatus.RealTimeProtectionEnabled) {
        Write-Log "✓ Microsoft Defender is now active" "INFO"
    } else {
        Write-Log "⚠ Microsoft Defender may require additional action or system reboot" "WARNING"
    }
}

Write-Log "=== Script Completed ==="

# Set NinjaRMM custom field with result
if ($success) {
    Ninja-Property-Set defenderRepairStatus "Success: $RepairAction"
    exit 0
} else {
    Ninja-Property-Set defenderRepairStatus "Failed: $RepairAction"
    exit 1
}