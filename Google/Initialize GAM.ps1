<#
.SYNOPSIS
    Sets up GAM7 for a new Google Workspace customer connection.

.DESCRIPTION
    Guides a technician through the full GAM7 initialization process for
    connecting to a Google Workspace tenant for remote management. Handles:

      - Installing GAM7 via winget (if not already installed)
      - Creating configuration and working directories
      - Setting required environment variables (GAMCFGDIR, PATH)
      - Initializing the GAM configuration file
      - Creating a GCP API project with the required Google APIs and a service account
      - Authorizing OAuth client scopes for the admin account (browser-based)
      - Configuring service account domain-wide delegation (requires Google Admin Console)
      - Saving the customer ID and primary domain to the GAM config

    Designed to be run once per customer workspace. After initialization, all
    subsequent scripts (e.g., Audit Shared Drive Folder.ps1) can target that
    workspace without further setup.

    Steps requiring browser interaction (GCP project creation, OAuth, domain-wide
    delegation) are launched interactively - the script guides you through each
    step and waits for confirmation before proceeding.

.PARAMETER AdminEmail
    The Super Admin email address for the target Google Workspace tenant.

.PARAMETER GamDir
    GAM7 installation directory. Defaults to C:\GAM7.

.PARAMETER ConfigDir
    Base directory for per-customer GAM configuration folders. At startup the script
    lists customer subdirectories found here and prompts you to select one or create
    a new one. Each customer is stored as <ConfigDir>\<domain>. Defaults to C:\GAMConfig.

.PARAMETER WorkDir
    Base directory for GAM working files. Each customer workspace uses a per-customer
    subdirectory (<WorkDir>\<domain>). Computed automatically from ConfigDir if omitted.

.EXAMPLE
    .\Initialize GAM.ps1 -AdminEmail admin@customer.com

    Runs the full initialization flow for the customer.com Google Workspace tenant.

.EXAMPLE
    .\Initialize GAM.ps1

    Prompts for the admin email interactively.

.NOTES
    Name:       Initialize GAM
    Author:     RTT Support
    Requires:   winget (for auto-install) or GAM7 pre-installed
    Context:    Technician workstation (interactive)
#>

param(
    [string]$AdminEmail,
    [string]$GamDir    = "C:\GAM7",
    [string]$ConfigDir = "C:\GAMConfig",
    [string]$WorkDir   = ""
)

$ProgressPreference = "SilentlyContinue"

# -- Transcript logging --------------------------------------------------------
$TranscriptDir  = Join-Path $env:USERPROFILE "Documents\GAM Logs"
if (-not (Test-Path $TranscriptDir)) { New-Item -ItemType Directory -Path $TranscriptDir -Force | Out-Null }
$TranscriptFile = Join-Path $TranscriptDir ("Initialize-GAM_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
Start-Transcript -Path $TranscriptFile -Append
Write-Host "Transcript: $TranscriptFile" -ForegroundColor DarkGray

# -- Helper functions ----------------------------------------------------------
function Write-Step {
    param([string]$Number, [string]$Message)
    Write-Host ""
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Step $Number - $Message" -ForegroundColor Cyan
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

function Wait-ForConfirmation {
    param([string]$Prompt = "Press Enter when ready to continue...")
    Write-Host ""
    Write-Host $Prompt -ForegroundColor Yellow
    Read-Host | Out-Null
}

# -- Select or create customer workspace --------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Customer Workspace Selection" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$existingWorkspaces = @()
if (Test-Path $ConfigDir) {
    $existingWorkspaces = Get-ChildItem -Path $ConfigDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "gam.cfg") } |
        Select-Object -ExpandProperty Name | Sort-Object
}

if ($existingWorkspaces.Count -gt 0) {
    Write-Host ""
    Write-Host "Existing customer workspaces:" -ForegroundColor White
    for ($i = 0; $i -lt $existingWorkspaces.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $existingWorkspaces[$i]) -ForegroundColor Green
    }
    $newIndex = $existingWorkspaces.Count + 1
    Write-Host ("  [{0}] Initialize a new customer workspace" -f $newIndex) -ForegroundColor Yellow
    Write-Host ""
    $sel = Read-Host ("Select workspace [1-{0}]" -f $newIndex)
    $selInt = 0
    if ([int]::TryParse($sel.Trim(), [ref]$selInt) -and $selInt -ge 1 -and $selInt -le $existingWorkspaces.Count) {
        $ConfigDir = Join-Path $ConfigDir $existingWorkspaces[$selInt - 1]
        $env:GAMCFGDIR = $ConfigDir
        Write-Host ""
        Write-Host "Selected:  $($existingWorkspaces[$selInt - 1])" -ForegroundColor Green
        Write-Host "ConfigDir: $ConfigDir" -ForegroundColor DarkGray
        Write-Host ""
        $reinit = Read-Host "This workspace is already initialized. Re-run initialization? [y/N]"
        if ($reinit -notmatch '^[Yy]') {
            Write-Host ""
            Write-Host "Workspace is ready. To use it in other scripts, set:" -ForegroundColor White
            Write-Host ("  `$env:GAMCFGDIR = '$ConfigDir'") -ForegroundColor DarkGray
            Write-Host "  gam info domain" -ForegroundColor DarkGray
            Stop-Transcript
            return
        }
    } elseif ($selInt -eq $newIndex) {
        $newDomain = Read-Host "Enter the primary domain for the new customer (e.g., contoso.com)"
        if ([string]::IsNullOrWhiteSpace($newDomain)) {
            throw "Domain is required."
        }
        $ConfigDir = Join-Path $ConfigDir ($newDomain.Trim().ToLower())
        $env:GAMCFGDIR = $ConfigDir
        Write-Host "New workspace path: $ConfigDir" -ForegroundColor Green
    } else {
        throw "Invalid selection. Exiting."
    }
} else {
    Write-Host "No existing customer workspaces found under: $ConfigDir" -ForegroundColor Yellow
    $newDomain = Read-Host "Enter the primary domain for the new customer (e.g., contoso.com)"
    if ([string]::IsNullOrWhiteSpace($newDomain)) {
        throw "Domain is required."
    }
    $ConfigDir = Join-Path $ConfigDir ($newDomain.Trim().ToLower())
    $env:GAMCFGDIR = $ConfigDir
    Write-Host "New workspace path: $ConfigDir" -ForegroundColor Green
}

# Derive per-customer work directory if not explicitly provided
if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    $WorkDir = Join-Path "C:\GAMWork" (Split-Path $ConfigDir -Leaf)
}

# -- Step 1: Install GAM if needed ---------------------------------------------
Write-Step "1 of 7" "Install GAM7"

$gamCmd = Get-Command gam -ErrorAction SilentlyContinue
if ($gamCmd) {
    Write-Host "GAM is already installed: $($gamCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "GAM is not installed. Checking winget..." -ForegroundColor Yellow
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        Write-Host "Installing GAM7 via winget..." -ForegroundColor Yellow
        try {
            & winget install --id GAM-Team.gam --accept-package-agreements --accept-source-agreements
            # Refresh PATH in current session
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
            $gamCmd = Get-Command gam -ErrorAction SilentlyContinue
            if ($gamCmd) {
                Write-Host "GAM7 installed successfully." -ForegroundColor Green
            } else {
                throw "GAM7 installed but 'gam' is not yet on PATH. Add $GamDir to your system PATH, restart this terminal, and re-run."
            }
        } catch {
            throw "winget install failed: $($_.Exception.Message). Install GAM7 manually: https://github.com/GAM-team/GAM/releases"
        }
    } else {
        throw "winget is not available on this system. Install GAM7 manually from: https://github.com/GAM-team/GAM/releases"
    }
}

# -- Step 2: Create directories and set environment variables ------------------
Write-Step "2 of 7" "Create directories and set environment variables"

foreach ($dir in @($ConfigDir, $WorkDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "Exists:  $dir" -ForegroundColor DarkGray
    }
}

# Set GAMCFGDIR for the current user
$currentGamCfgDir = [System.Environment]::GetEnvironmentVariable('GAMCFGDIR', 'User')
if ($currentGamCfgDir -ne $ConfigDir) {
    [System.Environment]::SetEnvironmentVariable('GAMCFGDIR', $ConfigDir, 'User')
    $env:GAMCFGDIR = $ConfigDir
    Write-Host "Set GAMCFGDIR = $ConfigDir (user environment variable)" -ForegroundColor Green
} else {
    Write-Host "GAMCFGDIR already set: $ConfigDir" -ForegroundColor DarkGray
}

# Add GAM to PATH if not already present
$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$GamDir*") {
    [System.Environment]::SetEnvironmentVariable('Path', "$userPath;$GamDir", 'User')
    $env:Path = "$env:Path;$GamDir"
    Write-Host "Added $GamDir to user PATH" -ForegroundColor Green
} else {
    Write-Host "PATH already contains $GamDir" -ForegroundColor DarkGray
}

# -- Step 3: Initialize GAM config file ----------------------------------------
Write-Step "3 of 7" "Initialize GAM config"

Write-Host "Running: gam config drive_dir $WorkDir verify" -ForegroundColor DarkGray
& gam config drive_dir $WorkDir verify
if ($LASTEXITCODE -ne 0) {
    throw "GAM config initialization failed."
}
Write-Host "GAM config initialized." -ForegroundColor Green

# -- Prompt for admin email if not supplied ------------------------------------
if ([string]::IsNullOrWhiteSpace($AdminEmail)) {
    Write-Host ""
    $AdminEmail = Read-Host "Enter the Super Admin email for this Google Workspace tenant"
    if ([string]::IsNullOrWhiteSpace($AdminEmail)) {
        throw "Admin email is required."
    }
}

# -- Step 4: Create GCP project ------------------------------------------------
Write-Step "4 of 7" "Create GCP API project"

Write-Host "This step will:" -ForegroundColor White
Write-Host "  - Open a browser to authenticate as $AdminEmail" -ForegroundColor White
Write-Host "  - Create a GCP project and enable ~23 Google APIs" -ForegroundColor White
Write-Host "  - Generate a service account with a private key" -ForegroundColor White
Write-Host "  - Prompt you to create an OAuth Client ID in the GCP Console" -ForegroundColor White
Write-Host ""
Write-Host "GAM will prompt you several times during this step:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. 'Enter your Google Workspace admin or GCP project manager email':" -ForegroundColor Yellow
Write-Host "       Enter: $AdminEmail" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. 'Enter your project id':" -ForegroundColor Yellow
Write-Host "       Press Enter to accept the auto-generated name (gam-project-xxxxx)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. A numbered list of API scopes will appear:" -ForegroundColor Yellow
Write-Host "       Type 'c' and press Enter to accept all defaults and continue" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4. A browser will open - sign in as $AdminEmail and authorize GAM" -ForegroundColor Yellow
Write-Host ""
Write-Host "  5. 'Please enter your Client ID':" -ForegroundColor Yellow
Write-Host "       Click the GCP Console URL shown in the output, create an OAuth Client ID:" -ForegroundColor Cyan
Write-Host "         - Application type: Desktop App" -ForegroundColor Cyan
Write-Host "         - Name: GAM" -ForegroundColor Cyan
Write-Host "       Then paste the Client ID and Client Secret back here" -ForegroundColor Cyan
Wait-ForConfirmation "Press Enter to begin GCP project creation..."

& gam create project
if ($LASTEXITCODE -ne 0) {
    throw "GCP project creation failed."
}
Write-Host "GCP project created." -ForegroundColor Green

# -- Step 5: Authorize OAuth scopes --------------------------------------------
Write-Step "5 of 7" "Authorize OAuth client scopes"

Write-Host "This step opens a browser to grant admin consent for required API scopes." -ForegroundColor White
Write-Host "  - Press 'c' to accept the default scope selection when prompted" -ForegroundColor Yellow
Write-Host "  - Enter $AdminEmail when prompted for the admin email" -ForegroundColor Yellow
Write-Host "  - Complete the browser authorization flow" -ForegroundColor Yellow
Wait-ForConfirmation "Press Enter to begin OAuth authorization..."

& gam oauth create
if ($LASTEXITCODE -ne 0) {
    throw "OAuth authorization failed."
}
Write-Host "OAuth scopes authorized." -ForegroundColor Green

# -- Step 6: Service account domain-wide delegation ----------------------------
Write-Step "6 of 7" "Configure domain-wide delegation"

Write-Host "This step authorizes the service account to impersonate users." -ForegroundColor White
Write-Host "  - Press 'c' to accept the default scope selection when prompted" -ForegroundColor Yellow
Write-Host "  - GAM will provide a link to the Google Admin Console - keep it open" -ForegroundColor Yellow
Wait-ForConfirmation "Press Enter to begin service account authorization..."

& gam user $AdminEmail update serviceaccount

Write-Host ""
Write-Host "ACTION REQUIRED in Google Admin Console:" -ForegroundColor Yellow
Write-Host "  1. Click the URL provided in the output above" -ForegroundColor Yellow
Write-Host "  2. Ensure 'Overwrite existing client ID' is checked" -ForegroundColor Yellow
Write-Host "  3. Click AUTHORIZE" -ForegroundColor Yellow
Write-Host "  4. Wait 1-2 minutes for the changes to propagate" -ForegroundColor Yellow
Wait-ForConfirmation "Press Enter after completing the Admin Console authorization..."

Write-Host "Verifying service account scopes..." -ForegroundColor Yellow
& gam user $AdminEmail check serviceaccount
if ($LASTEXITCODE -ne 0) {
    Write-Host "Some scopes may still be pending. If needed, wait a few minutes and run:" -ForegroundColor Yellow
    Write-Host "  gam user $AdminEmail check serviceaccount" -ForegroundColor DarkGray
    Write-Host "All scopes should show PASS when propagation is complete." -ForegroundColor Yellow
}

# -- Step 7: Save customer configuration --------------------------------------
Write-Step "7 of 7" "Save customer configuration"

Write-Host "Retrieving domain info..." -ForegroundColor Yellow
$domainInfo = & gam info domain 2>&1
$customerIdMatch  = $domainInfo | Select-String "Customer ID:\s+(\S+)"
$primaryDomainMatch = $domainInfo | Select-String "Primary Domain:\s+(\S+)"

$customerId    = if ($customerIdMatch)    { $customerIdMatch.Matches.Groups[1].Value }    else { $null }
$primaryDomain = if ($primaryDomainMatch) { $primaryDomainMatch.Matches.Groups[1].Value } else { $null }

if (-not $customerId -or -not $primaryDomain) {
    Write-Host "Could not auto-detect Customer ID or Primary Domain from 'gam info domain'." -ForegroundColor Red
    $domainInfo | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    $customerId    = Read-Host "Enter Customer ID (e.g., C01234567)"
    $primaryDomain = Read-Host "Enter Primary Domain (e.g., yourdomain.com)"
}

Write-Host "Customer ID:    $customerId" -ForegroundColor White
Write-Host "Primary Domain: $primaryDomain" -ForegroundColor White

& gam config customer_id $customerId domain $primaryDomain timezone local save verify
if ($LASTEXITCODE -ne 0) {
    throw "Failed to save GAM configuration."
}

# -- Complete ------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  GAM7 Setup Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "GAM is now connected to: $primaryDomain ($customerId)" -ForegroundColor Green
Write-Host ""
Write-Host "Verify your connection:" -ForegroundColor White
Write-Host "  gam info domain" -ForegroundColor DarkGray
Write-Host "  gam print users maxresults 5" -ForegroundColor DarkGray
Write-Host "  gam user $AdminEmail show filecounts" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Log saved to: $TranscriptFile" -ForegroundColor DarkGray

Stop-Transcript
