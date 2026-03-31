# Description: This script applies a Windows license key to the system.
# The license key can be supplied from:
# 1. NinjaOne custom variable: $env:windowsLicenseKey
# 2. Command line parameter: -LicenseKey "key"
# 3. Prompted via user input if not provided

param(
    [Parameter(Mandatory = $false)]
    [string]$LicenseKey
)

# Check if running as administrator
$isAdmin = [Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544'
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Determine the license key source
if (-not $LicenseKey) {
    # Check for NinjaOne environment variable
    if ($env:windowsLicenseKey) {
        $LicenseKey = $env:windowsLicenseKey
        Write-Host "Using license key from NinjaOne environment variable" -ForegroundColor Cyan
    }
    else {
        # Prompt for license key
        $LicenseKey = Read-Host "Enter Windows license key"
    }
}

# Validate that a license key was provided
if (-not $LicenseKey) {
    Write-Error "No license key provided"
    exit 1
}

# Function to get current license status
function Get-LicenseStatus {
    try {
        $output = cscript.exe C:\Windows\System32\slmgr.vbs /dli 2>&1 | Out-String
        return $output
    }
    catch {
        Write-Error "Failed to retrieve license status: $_"
        return $null
    }
}

# Display current license status before changes
Write-Host "Current license status (before):" -ForegroundColor Yellow
Write-Host (Get-LicenseStatus) -ForegroundColor Gray

# Apply the license key
Write-Host "Applying Windows license key..." -ForegroundColor Cyan
try {
    cscript.exe C:\Windows\System32\slmgr.vbs /ipk $LicenseKey | Out-Null
    Start-Sleep -Seconds 3
    
    # Activate the license
    Write-Host "Activating Windows..." -ForegroundColor Cyan
    cscript.exe C:\Windows\System32\slmgr.vbs /ato | Out-Null
    Start-Sleep -Seconds 3
    
    # Display license status after changes
    Write-Host "`nLicense status after application:" -ForegroundColor Yellow
    Write-Host (Get-LicenseStatus) -ForegroundColor Green
    Write-Host "License key applied and activated successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to apply license key: $_"
    exit 1
}
