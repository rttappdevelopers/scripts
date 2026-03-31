#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Uninstall Datto Cloud Continuity (Endpoint Backup for PCs) Agent (Silent)

.DESCRIPTION
    Silent uninstall script for Datto Endpoint Backup Agent designed for Ninja RMM deployment.
    Runs without UI interaction at SYSTEM level.
    
    Two uninstall methods are available:
    1. Standard Uninstall: Removes the agent but preserves the backup chain for future restoration
    2. Complete Removal: Removes the agent and permanently deletes the backup chain
    
    IMPORTANT: Complete removal is IRREVERSIBLE. If you need to backup the same device again
    in the future, you will need to create a new backup chain.

.PARAMETER CompleteRemoval
    If specified, performs complete removal including deletion of backup chain data.
    Can be set via:
    - Script parameter: -CompleteRemoval
    - Ninja variable: Set as a checkbox variable named 'CompleteRemoval' in Ninja automation
      (Ninja injects it as $env:completeremoval = "true"/"false")

.EXAMPLE
    .\Uninstall Datto Endpint Backup for PCs.ps1
    Performs silent standard uninstall only

.EXAMPLE
    .\Uninstall Datto Endpint Backup for PCs.ps1 -CompleteRemoval
    Performs silent uninstall plus backup chain removal

.NOTES
    - Runs silently at SYSTEM level without UI prompts
    - Requires administrative privileges
    - Cloud backups are NOT deleted by this process regardless of uninstall method
    - Designed for NinjaOne/NinjaRMM automation
    - Exit code 0 = Success, 1 = Errors occurred
    - Logs to Application Event Log and console (for Ninja logging)
#>

param(
    [switch]$CompleteRemoval
)

# Suppress progress and preference for silent execution
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"
$WarningPreference = "Continue"
$InformationPreference = "SilentlyContinue"

# Check for environment variable from Ninja (support both parameter and env var)
# Ninja lowercases variable names when injecting them as environment variables
$completeRemovalEnv = if ($env:completeremoval) { $env:completeremoval } else { $env:COMPLETE_REMOVAL }
if ($completeRemovalEnv -and ($completeRemovalEnv -eq "true" -or $completeRemovalEnv -eq "1" -or $completeRemovalEnv -eq $true)) {
    $CompleteRemoval = $true
}

# Logging function - outputs to console for Ninja capture
function Write-SilentLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    # Also log to Windows Event Log
    try {
        $eventSource = "DattoUninstall"
        if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
            New-EventLog -LogName Application -Source $eventSource -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $eventSource -EventId 1000 -EntryType Information -Message $logMessage -ErrorAction SilentlyContinue
    } catch {
        # Silently ignore event log errors
    }
}

try {
    Write-SilentLog "Starting Datto Endpoint Backup Agent uninstall process (Silent mode)" "Info"

    # Find the Datto Cloud Continuity agent using registry
    # Confirmed display name from software audit: "Datto Cloud Continuity"
    # Also matches legacy/variant names as fallback
    $uninstallRegPath   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $uninstallRegPath32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    $dattoApp = $null

    # Check 64-bit registry first, then 32-bit
    foreach ($regPath in @($uninstallRegPath, $uninstallRegPath32)) {
        if (-not $dattoApp -and (Test-Path $regPath)) {
            $dattoApp = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue |
                Where-Object {
                    $name = $_.GetValue("DisplayName")
                    $name -like "*Datto Cloud Continuity*" -or
                    $name -like "*Datto Endpoint Backup*" -or
                    $name -like "*Datto*Backup*"
                } |
                Select-Object -First 1
        }
    }

    # Log what we found (or didn't) for diagnostics
    if ($dattoApp) {
        Write-SilentLog "Found in registry: $($dattoApp.GetValue('DisplayName'))" "Info"
    } else {
        # Dump all installed display names containing 'datto' or 'backup' to help diagnose
        Write-SilentLog "Datto Endpoint Backup Agent not found in registry. Scanning for related entries..." "Warning"
        foreach ($regPath in @($uninstallRegPath, $uninstallRegPath32)) {
            if (Test-Path $regPath) {
                Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue |
                    Where-Object { $_.GetValue("DisplayName") -match 'datto|backup|continuity' } |
                    ForEach-Object { Write-SilentLog "  Found related entry: $($_.GetValue('DisplayName'))" "Info" }
            }
        }
    }

    if ($dattoApp) {
        $displayName = $dattoApp.GetValue("DisplayName")
        $uninstallString = $dattoApp.GetValue("UninstallString")

        Write-SilentLog "Found Datto Endpoint Backup Agent: $displayName" "Info"

        # Stop Datto services and processes before uninstalling to release file locks
        Write-SilentLog "Stopping Datto services and processes..." "Info"
        Get-Service -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -match 'datto|continuity' -or $_.Name -match 'datto|continuity' } |
            ForEach-Object {
                Write-SilentLog "  Stopping service: $($_.DisplayName)" "Info"
                Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
            }
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'datto|continuity' } |
            ForEach-Object {
                Write-SilentLog "  Killing process: $($_.Name)" "Info"
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        Start-Sleep -Seconds 3

        if ($uninstallString) {
            Write-SilentLog "Executing silent uninstall..." "Info"

            if ($uninstallString -like "*msiexec*") {
                # MSI-based uninstaller — extract GUID and run with /quiet /norestart
                $msiPattern = '\{[A-F0-9\-]+\}'
                if ($uninstallString -match $msiPattern) {
                    $msiGuid = $matches[0]
                    $proc = Start-Process -FilePath "msiexec.exe" `
                        -ArgumentList "/x", $msiGuid, "/quiet", "/norestart" `
                        -Wait -PassThru -NoNewWindow
                    $exitCode = $proc.ExitCode
                    if ($exitCode -eq 0) {
                        Write-SilentLog "MSI uninstall completed successfully (exit code: 0)" "Success"
                    } elseif ($exitCode -eq 3010) {
                        Write-SilentLog "MSI uninstall completed successfully — a reboot is required to finish removal (exit code: 3010)" "Success"
                    } else {
                        Write-SilentLog "MSI uninstall exited with unexpected code: $exitCode" "Warning"
                    }
                } else {
                    Write-SilentLog "Could not parse MSI GUID from uninstall string: $uninstallString" "Error"
                    $exitCode = -1
                }
            } else {
                # EXE-based uninstaller — split path and args, run silently
                if ($uninstallString -match '^"([^"]+)"\s*(.*)$') {
                    $exePath = $matches[1]
                    $exeArgs = $matches[2]
                } else {
                    $parts   = $uninstallString -split ' ', 2
                    $exePath = $parts[0]
                    $exeArgs = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                }
                $exeArgs = "$exeArgs /quiet /S".Trim()
                $proc = Start-Process -FilePath $exePath `
                    -ArgumentList $exeArgs `
                    -Wait -PassThru -NoNewWindow
                $exitCode = $proc.ExitCode
                Write-SilentLog "EXE uninstall exited with code: $exitCode" "Info"
            }

            # Verify removal via registry — skip if uninstaller already confirmed success
            # Exit code 3010 means success + reboot pending; registry entry persists until reboot
            if ($exitCode -notin @(0, 3010)) {
                $stillInstalled = foreach ($regPath in @($uninstallRegPath, $uninstallRegPath32)) {
                    if (Test-Path $regPath) {
                        Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue |
                            Where-Object {
                                $name = $_.GetValue("DisplayName")
                                $name -like "*Datto Cloud Continuity*" -or
                                $name -like "*Datto Endpoint Backup*" -or
                                $name -like "*Datto*Backup*"
                            }
                    }
                }
                if (-not $stillInstalled) {
                    Write-SilentLog "Registry verification confirmed: agent removed" "Success"
                } else {
                    Write-SilentLog "Uninstaller exited with code $exitCode and agent is still present in registry" "Warning"
                }
            }
        }
    }

    # If CompleteRemoval is specified, remove the backup chain data
    if ($CompleteRemoval) {
        Write-SilentLog "Performing complete removal - deleting backup chain data..." "Info"

        # Ensure all Datto processes are stopped before attempting folder deletion
        Get-Service -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'datto|continuity' -or $_.Name -match 'datto|continuity' } |
            ForEach-Object { Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue }
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'datto|continuity' } |
            ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 3
        
        $dattoPath = "$env:windir\System32\config\systemprofile\AppData\Local\Datto\Datto Cloud Continuity"
        
        if (Test-Path $dattoPath) {
            Write-SilentLog "Found Datto backup chain directory: $dattoPath" "Info"
            try {
                Remove-Item -Path $dattoPath -Recurse -Force -ErrorAction Stop
                Write-SilentLog "Successfully removed backup chain data" "Success"
                Write-SilentLog "WARNING: This removal is irreversible. A new backup chain will be required if backing up this device in the future." "Warning"
            } catch {
                Write-SilentLog "Failed to remove backup chain directory: $($_.Exception.Message)" "Error"
            }
        } else {
            Write-SilentLog "Backup chain directory not found at: $dattoPath" "Info"
        }
    }

    Write-SilentLog "Datto Endpoint Backup Agent uninstall process completed successfully" "Success"
    exit 0
}
catch {
    Write-SilentLog "An error occurred during uninstall: $($_.Exception.Message)" "Error"
    exit 1
}
