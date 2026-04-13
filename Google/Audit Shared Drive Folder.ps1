<#
.SYNOPSIS
    Audits a Google Drive folder structure using GAM7 for migration planning.

.DESCRIPTION
    Generates CSV reports for a specified Google Drive folder covering:
      - Subfolder count per folder
      - File count per folder and subfolder (direct and total)
      - Files owned by external accounts per folder
      - Files shared externally per folder
      - Total size per folder

    Uses GAM7 (https://github.com/GAM-team/GAM) to query the Google Drive API
    via service account impersonation. GAM must be installed and configured before
    running this script. Run Initialize GAM.ps1 first if you have not already done so.

    Outputs three CSV files to the specified output directory:
      1. DiskUsage.csv    - folder-level stats (counts, sizes, depths)
      2. FileDetails.csv  - every file with owner, path, size, and permissions
      3. Summary.csv      - per-folder aggregation of external ownership and sharing

.PARAMETER UserEmail
    The Google Workspace email address of a user who has access to the target
    folder. GAM impersonates this user via service account delegation.

.PARAMETER FolderName
    The name of the Drive folder to audit. GAM searches for this name in the
    user's accessible files. If multiple folders match, GAM uses the first match.

.PARAMETER FolderId
    The Google Drive folder ID to audit. Use this instead of FolderName when you
    know the exact folder ID (avoids ambiguity with duplicate folder names).
    You can find a folder ID in the URL when viewing it in Google Drive.

.PARAMETER Domain
    Your Google Workspace primary domain (e.g., yourdomain.com). Used to
    distinguish internal vs. external file owners and share recipients.

.PARAMETER OutputDir
    Directory where CSV reports are saved. Defaults to a timestamped subfolder
    under the current directory. Created automatically if it does not exist.

.PARAMETER IncludeSharedDrive
    When specified, treats FolderId as a Shared Drive ID and uses the
    shareddriveid selector instead of drivefilename/id.

.PARAMETER ConfigBaseDir
    Base directory containing per-customer GAM config folders (e.g., C:\GAMConfig).
    The script lists subdirectories and prompts you to choose one. Defaults to C:\GAMConfig.

.PARAMETER ConfigDir
    Full path to a specific customer GAM config directory (e.g., C:\GAMConfig\contoso.com).
    When provided, skips the workspace selection prompt and uses this directory directly.

.EXAMPLE
    .\Audit Shared Drive Folder.ps1 -UserEmail admin@contoso.com -FolderName "Project Files" -Domain contoso.com
    Audits the "Project Files" folder accessible by admin@contoso.com.

.EXAMPLE
    .\Audit Shared Drive Folder.ps1 -UserEmail admin@contoso.com -FolderId "1A2B3C4D5E6F" -Domain contoso.com
    Audits the folder with ID 1A2B3C4D5E6F.

.EXAMPLE
    .\Audit Shared Drive Folder.ps1 -UserEmail admin@contoso.com -FolderId "0AL5LiIe4dqxZUk9PVA" -Domain contoso.com -IncludeSharedDrive
    Audits an entire Shared Drive by its ID.

.NOTES
    Name:       Audit Shared Drive Folder
    Author:     RTT Support
    Requires:   GAM7 installed and configured (gam on PATH)
    Context:    Technician workstation (interactive)
#>

param(
    [string]$UserEmail,
    [string]$FolderName,
    [string]$FolderId,
    [string]$Domain,
    [string]$OutputDir,
    [switch]$IncludeSharedDrive,
    [string]$ConfigBaseDir = "C:\GAMConfig",
    [string]$ConfigDir     = ""
)

# -- Transcript logging --------------------------------------------------------
$TranscriptDir  = Join-Path $env:USERPROFILE "Documents\GAM Logs"
if (-not (Test-Path $TranscriptDir)) { New-Item -ItemType Directory -Path $TranscriptDir -Force | Out-Null }
$TranscriptFile = Join-Path $TranscriptDir ("Audit-SharedDrive_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
Start-Transcript -Path $TranscriptFile -Append
Write-Host "Transcript: $TranscriptFile" -ForegroundColor DarkGray

# -- Verify GAM is installed and configured ------------------------------------
if (-not (Get-Command gam -ErrorAction SilentlyContinue)) {
    throw "GAM7 is not installed or not on PATH. Run '.\Initialize GAM.ps1' first to set up GAM for this workspace."
}

# -- Select customer workspace ------------------------------------------------
$originalGamCfgDir = $env:GAMCFGDIR  # preserve so we can restore on exit
if (-not [string]::IsNullOrWhiteSpace($ConfigDir)) {
    $env:GAMCFGDIR = $ConfigDir
    Write-Host "Using config directory: $ConfigDir" -ForegroundColor DarkGray
} else {
    $existingWorkspaces = @()
    if (Test-Path $ConfigBaseDir) {
        $existingWorkspaces = Get-ChildItem -Path $ConfigBaseDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "gam.cfg") } |
            Select-Object -ExpandProperty Name | Sort-Object
    }

    if ($existingWorkspaces.Count -eq 0) {
        throw "No initialized customer workspaces found under: $ConfigBaseDir. Run '.\Initialize GAM.ps1' first to set up a workspace."
    } else {
        Write-Host ""
        Write-Host "Available customer workspaces:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $existingWorkspaces.Count; $i++) {
            Write-Host ("  [{0}] {1}" -f ($i + 1), $existingWorkspaces[$i]) -ForegroundColor Green
        }
        Write-Host ""
        $sel = Read-Host ("Select workspace [1-{0}]" -f $existingWorkspaces.Count)
        $selInt = 0
        if ([int]::TryParse($sel.Trim(), [ref]$selInt) -and $selInt -ge 1 -and $selInt -le $existingWorkspaces.Count) {
            $ConfigDir = Join-Path $ConfigBaseDir $existingWorkspaces[$selInt - 1]
            $env:GAMCFGDIR = $ConfigDir
            Write-Host "Selected: $($existingWorkspaces[$selInt - 1])" -ForegroundColor Green
        } else {
            throw "Invalid selection."
        }
    }
}

# Prompt for domain, using workspace directory name as a suggested default
if ([string]::IsNullOrWhiteSpace($Domain) -and $ConfigDir) {
    $inferredDomain = Split-Path $ConfigDir -Leaf
    if ($inferredDomain -match '\.') {
        $domainInput = Read-Host "Enter the Google Workspace primary domain [$inferredDomain]"
        $Domain = if ([string]::IsNullOrWhiteSpace($domainInput)) { $inferredDomain } else { $domainInput.Trim() }
    }
}

# -- Prompt for missing parameters --------------------------------------------
if ([string]::IsNullOrWhiteSpace($UserEmail)) {
    $UserEmail = Read-Host "Enter the Google Workspace admin email (e.g., admin@yourdomain.com)"
    if ([string]::IsNullOrWhiteSpace($UserEmail)) {
        throw "User email is required."
    }
}

if ([string]::IsNullOrWhiteSpace($Domain)) {
    # Try to extract domain from the email address
    if ($UserEmail -match '@(.+)$') {
        $suggestedDomain = $Matches[1]
        $Domain = Read-Host "Enter your Google Workspace primary domain [$suggestedDomain]"
        if ([string]::IsNullOrWhiteSpace($Domain)) { $Domain = $suggestedDomain }
    } else {
        $Domain = Read-Host "Enter your Google Workspace primary domain (e.g., yourdomain.com)"
        if ([string]::IsNullOrWhiteSpace($Domain)) {
            throw "Domain is required."
        }
    }
}

if ([string]::IsNullOrWhiteSpace($FolderName) -and [string]::IsNullOrWhiteSpace($FolderId)) {
    Write-Host ""
    Write-Host "How would you like to identify the folder?" -ForegroundColor Cyan
    Write-Host "  1) Folder name"
    Write-Host "  2) Folder ID (from the Google Drive URL)"
    Write-Host "  3) Shared Drive ID"
    $choice = Read-Host "Enter 1, 2, or 3"
    switch ($choice) {
        '1' {
            $FolderName = Read-Host "Enter the folder name"
            if ([string]::IsNullOrWhiteSpace($FolderName)) {
                throw "Folder name is required."
            }
        }
        '2' {
            $FolderId = Read-Host "Enter the folder ID"
            if ([string]::IsNullOrWhiteSpace($FolderId)) {
                throw "Folder ID is required."
            }
        }
        '3' {
            $FolderId = Read-Host "Enter the Shared Drive ID"
            if ([string]::IsNullOrWhiteSpace($FolderId)) {
                throw "Shared Drive ID is required."
            }
            $IncludeSharedDrive = $true
        }
        default {
            throw "Invalid selection. Please enter 1, 2, or 3."
        }
    }
}

# -- Set up output directory --------------------------------------------------
if (-not $OutputDir) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $OutputDir = Join-Path $PWD "DriveAudit_$timestamp"
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$diskUsageCsv  = Join-Path $OutputDir "DiskUsage.csv"
$fileDetailCsv = Join-Path $OutputDir "FileDetails.csv"
$summaryCsv    = Join-Path $OutputDir "Summary.csv"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Google Drive Folder Audit" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "User:       $UserEmail"
Write-Host "Domain:     $Domain"
if ($FolderName) { Write-Host "Folder:     $FolderName" }
if ($FolderId)   { Write-Host "Folder ID:  $FolderId" }
Write-Host "Output:     $OutputDir"
Write-Host ""

# -- Step 1: Disk Usage (subfolder counts, file counts, sizes) ----------------
Write-Host "[1/3] Running disk usage analysis..." -ForegroundColor Yellow
try {
    $diskUsageArgs = @(
        "user", $UserEmail,
        "print", "diskusage"
    )

    if ($IncludeSharedDrive) {
        $diskUsageArgs += @("shareddriveid", $FolderId)
    } elseif ($FolderId) {
        $diskUsageArgs += @("id:$FolderId")
    } else {
        $diskUsageArgs += @("drivefilename", $FolderName)
    }

    $diskUsageOutput = & gam @diskUsageArgs 2>&1
    $diskUsageData = $diskUsageOutput | Where-Object { $_ -notmatch "^(User:|Getting |Got )" }

    if ($diskUsageData) {
        $diskUsageData | Out-File -FilePath $diskUsageCsv -Encoding UTF8
        $rowCount = ($diskUsageData | Measure-Object).Count - 1  # subtract header
        Write-Host "  Saved $rowCount folder records to DiskUsage.csv" -ForegroundColor Green
    } else {
        Write-Warning "  No disk usage data returned. Verify the folder name/ID and user access."
    }
} catch {
    Write-Error "  Disk usage query failed: $($_.Exception.Message)"
}

# -- Step 2: File Details (owner, size, path, permissions) --------------------
Write-Host "[2/3] Retrieving file details with ownership and permissions..." -ForegroundColor Yellow
try {
    $fileListArgs = @(
        "user", $UserEmail,
        "print", "filelist",
        "select"
    )

    if ($IncludeSharedDrive) {
        $fileListArgs += @("shareddriveid", $FolderId)
    } elseif ($FolderId) {
        $fileListArgs += @("id:$FolderId")
    } else {
        $fileListArgs += @("drivefilename", $FolderName)
    }

    $fileListArgs += @(
        "showownedby", "any",
        "fields", "id,name,mimetype,size,owners.emailaddress,basicpermissions",
        "fullpath",
        "showshareddrivepermissions"
    )

    $fileListOutput = & gam @fileListArgs 2>&1
    $fileListData = $fileListOutput | Where-Object { $_ -notmatch "^(User:|Getting |Got )" }

    if ($fileListData) {
        $fileListData | Out-File -FilePath $fileDetailCsv -Encoding UTF8
        $rowCount = ($fileListData | Measure-Object).Count - 1
        Write-Host "  Saved $rowCount file records to FileDetails.csv" -ForegroundColor Green
    } else {
        Write-Warning "  No file data returned. Verify the folder name/ID and user access."
    }
} catch {
    Write-Error "  File list query failed: $($_.Exception.Message)"
}

# -- Step 3: Aggregate external ownership and sharing per folder --------------
Write-Host "[3/3] Analyzing external ownership and sharing..." -ForegroundColor Yellow
try {
    if (Test-Path $fileDetailCsv) {
        $files = Import-Csv $fileDetailCsv

        # Identify the path column (GAM uses path.0 for the first path)
        $pathCol = ($files | Get-Member -MemberType NoteProperty |
            Where-Object { $_.Name -match "^path" } |
            Select-Object -First 1).Name

        if (-not $pathCol) {
            Write-Warning "  Could not find path column in file details. Skipping summary."
        } else {
            # Find the owner email column
            $ownerCol = ($files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -match "owners.*emailaddress" } |
                Select-Object -First 1).Name

            # Find permission email and type columns
            $permCols = $files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -match "permissions\.\d+\.(emailaddress|domain|type)" }

            $summary = @{}

            foreach ($file in $files) {
                $filePath = $file.$pathCol
                if (-not $filePath) { continue }

                # Extract the folder path (everything up to the last path component)
                $pathParts = $filePath -split "/"
                if ($pathParts.Count -gt 1) {
                    $folderPath = ($pathParts[0..($pathParts.Count - 2)]) -join "/"
                } else {
                    $folderPath = $filePath
                }

                # Initialize folder entry
                if (-not $summary.ContainsKey($folderPath)) {
                    $summary[$folderPath] = [PSCustomObject]@{
                        FolderPath      = $folderPath
                        TotalFiles      = 0
                        ExternallyOwned = 0
                        SharedExternally = 0
                    }
                }

                $entry = $summary[$folderPath]
                $entry.TotalFiles++

                # Check if the file is owned by an external account
                if ($ownerCol) {
                    $ownerEmail = $file.$ownerCol
                    if ($ownerEmail -and $ownerEmail -notmatch [regex]::Escape($Domain)) {
                        $entry.ExternallyOwned++
                    }
                }

                # Check if any permission is for an external entity
                $isSharedExternally = $false
                foreach ($col in $permCols) {
                    $val = $file.($col.Name)
                    if (-not $val) { continue }

                    if ($col.Name -match "emailaddress") {
                        if ($val -and $val -notmatch [regex]::Escape($Domain)) {
                            $isSharedExternally = $true
                        }
                    } elseif ($col.Name -match "\.type$") {
                        if ($val -eq "anyone") {
                            $isSharedExternally = $true
                        }
                    } elseif ($col.Name -match "\.domain$") {
                        if ($val -and $val -ne $Domain) {
                            $isSharedExternally = $true
                        }
                    }
                }
                if ($isSharedExternally) {
                    $entry.SharedExternally++
                }
            }

            $summaryData = $summary.Values | Sort-Object FolderPath
            $summaryData | Export-Csv -Path $summaryCsv -NoTypeInformation -Encoding UTF8
            Write-Host "  Saved $($summaryData.Count) folder summaries to Summary.csv" -ForegroundColor Green
        }
    } else {
        Write-Warning "  FileDetails.csv not found - skipping external ownership/sharing analysis."
    }
} catch {
    Write-Error "  Summary aggregation failed: $($_.Exception.Message)"
}

# -- Report -------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Audit Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output files:" -ForegroundColor White

if (Test-Path $diskUsageCsv) {
    Write-Host "  DiskUsage.csv    - Subfolder counts, file counts, and sizes per folder" -ForegroundColor Green
} else {
    Write-Host "  DiskUsage.csv    - NOT GENERATED" -ForegroundColor Red
}

if (Test-Path $fileDetailCsv) {
    Write-Host "  FileDetails.csv  - Every file with owner, size, path, and permissions" -ForegroundColor Green
} else {
    Write-Host "  FileDetails.csv  - NOT GENERATED" -ForegroundColor Red
}

if (Test-Path $summaryCsv) {
    Write-Host "  Summary.csv      - Per-folder external ownership and sharing counts" -ForegroundColor Green
} else {
    Write-Host "  Summary.csv      - NOT GENERATED" -ForegroundColor Red
}

Write-Host ""
Write-Host "DiskUsage.csv columns:" -ForegroundColor DarkGray
Write-Host "  directFileCount    - Files directly in the folder" -ForegroundColor DarkGray
Write-Host "  directFolderCount  - Subfolders directly in the folder" -ForegroundColor DarkGray
Write-Host "  directFileSize     - Size of files directly in the folder (bytes)" -ForegroundColor DarkGray
Write-Host "  totalFileCount     - Files in the folder and all subfolders" -ForegroundColor DarkGray
Write-Host "  totalFolderCount   - Subfolders at all levels below" -ForegroundColor DarkGray
Write-Host "  totalFileSize      - Size of all files at all levels below (bytes)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Log saved to: $TranscriptFile" -ForegroundColor DarkGray

# Restore GAMCFGDIR to whatever it was before this script ran
$env:GAMCFGDIR = $originalGamCfgDir

Stop-Transcript
