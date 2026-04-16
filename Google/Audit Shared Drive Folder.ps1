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
    The name of the Drive folder to audit. The script searches for all folders
    with this name accessible to the specified user. If multiple folders match,
    you will be prompted to select which one to audit.

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

# -- Transcript logging -------------------------------------------------------
# Everything printed to the console during this session is also mirrored to a
# timestamped text file under the technician's Documents\GAM Logs folder.
# This gives you a permanent record of what was queried and what GAM returned,
# which is useful when reviewing the audit later or troubleshooting a failure.
$TranscriptDir  = Join-Path $env:USERPROFILE "Documents\GAM Logs"
if (-not (Test-Path $TranscriptDir)) { New-Item -ItemType Directory -Path $TranscriptDir -Force | Out-Null }
$TranscriptFile = Join-Path $TranscriptDir ("Audit-SharedDrive_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
Start-Transcript -Path $TranscriptFile -Append
Write-Host "Transcript: $TranscriptFile" -ForegroundColor DarkGray

# -- Verify GAM is installed and configured -----------------------------------
# GAM must be on the system PATH before any API calls can be made.
# Get-Command probes PATH without raising a terminating error, so we can give
# a clear, actionable message instead of a raw "not recognized" exception.
if (-not (Get-Command gam -ErrorAction SilentlyContinue)) {
    throw "GAM7 is not installed or not on PATH. Run '.\Initialize GAM.ps1' first to set up GAM for this workspace."
}

# -- Select customer workspace ------------------------------------------------
# GAM reads its configuration from the directory pointed to by the GAMCFGDIR
# environment variable. Each customer has its own subdirectory under
# ConfigBaseDir (default C:\GAMConfig), created by Initialize GAM.ps1.
#
# We save the original value so we can restore it when the script exits,
# avoiding side effects on the calling shell session.
$originalGamCfgDir = $env:GAMCFGDIR

if (-not [string]::IsNullOrWhiteSpace($ConfigDir)) {
    # A specific config directory was passed via -ConfigDir; use it directly
    # and skip the interactive selection menu.
    $env:GAMCFGDIR = $ConfigDir
    Write-Host "Using config directory: $ConfigDir" -ForegroundColor DarkGray
} else {
    # Scan ConfigBaseDir for subdirectories that contain a gam.cfg file.
    # This filters out any partially-initialized or unrelated folders.
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

# The domain is used later to classify file owners and share recipients as
# internal or external. Initialize GAM.ps1 names each workspace directory
# after the customer's primary domain (e.g. C:\GAMConfig\contoso.com), so we
# can infer a sensible default from the selected config directory name.
# The technician can accept it with Enter or type a different value.
if ([string]::IsNullOrWhiteSpace($Domain) -and $ConfigDir) {
    $inferredDomain = Split-Path $ConfigDir -Leaf
    if ($inferredDomain -match '\.') {
        $domainInput = Read-Host "Enter the Google Workspace primary domain [$inferredDomain]"
        $Domain = if ([string]::IsNullOrWhiteSpace($domainInput)) { $inferredDomain } else { $domainInput.Trim() }
    }
}

# -- Prompt for missing parameters --------------------------------------------
# Any value not supplied on the command line is collected interactively here.
# This makes the script safe to run with no arguments — it will always ask
# for everything it needs before touching the Drive API.

# UserEmail is the account GAM impersonates via service account delegation.
# It must be a real user in the target workspace (typically an admin).
if ([string]::IsNullOrWhiteSpace($UserEmail)) {
    $UserEmail = Read-Host "Enter the Google Workspace admin email (e.g., admin@yourdomain.com)"
    if ([string]::IsNullOrWhiteSpace($UserEmail)) {
        throw "User email is required."
    }
}

# Domain may still be unset if the config directory name didn't look like a
# domain. Fall back to prompting, with the email's domain part as a default.
if ([string]::IsNullOrWhiteSpace($Domain)) {
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

# Ask how to identify the target folder. Three modes are supported:
#   1) Folder name  — human-readable search; may return multiple matches
#      which the script will resolve via a follow-up selection prompt.
#   2) Folder ID    — unambiguous; paste from the Drive URL (?id=...)
#   3) Shared Drive ID — audits an entire Shared Drive rather than a subfolder;
#      uses the shareddriveid selector in all GAM calls.
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

# -- Resolve FolderName to a unique FolderId ----------------------------------
# Google Drive allows multiple folders with the same name, even in the same
# parent. Passing a name directly to the audit commands would silently use
# whichever match GAM happens to return first. Instead, we run an explicit
# search up front, show the results to the technician, and require a
# deliberate selection before any audit work begins. Once a unique ID is
# confirmed, FolderName is cleared so all downstream GAM calls use the
# unambiguous id: selector.
if (-not [string]::IsNullOrWhiteSpace($FolderName) -and [string]::IsNullOrWhiteSpace($FolderId)) {
    Write-Host "Searching for folders named '$FolderName'..." -ForegroundColor Yellow

    # Single quotes inside the Drive query must be escaped with a backslash.
    $escapedFolderName = $FolderName -replace "'", "\'"

    $folderSearchArgs = @(
        "user", $UserEmail,
        "print", "filelist",
        # Drive API query: match folders by exact name, exclude trashed items.
        "query", "mimeType='application/vnd.google-apps.folder' and name='$escapedFolderName' and trashed=false",
        "fields", "id,name",
        # fullpath adds a path.N column showing the full Drive path to each folder,
        # which is what we display in the disambiguation menu.
        "fullpath"
    )
    $folderSearchOutput = & gam @folderSearchArgs 2>&1
    # Strip GAM progress lines so only the CSV data remains.
    $folderSearchData   = $folderSearchOutput | Where-Object { $_ -notmatch "^(User:|Getting |Got )" }
    $folderResults      = @($folderSearchData | ConvertFrom-Csv)

    if ($folderResults.Count -eq 0) {
        throw "No folders named '$FolderName' were found accessible by $UserEmail."
    } elseif ($folderResults.Count -eq 1) {
        # Exactly one match — resolve to its ID automatically.
        $FolderId   = $folderResults[0].id
        $FolderName = $null
        Write-Host "  Found: $($folderResults[0].name) (ID: $FolderId)" -ForegroundColor Green
    } else {
        # Multiple matches — show each one's full path so the technician can
        # distinguish between folders with identical names in different locations.
        $pathColName = ($folderResults[0] | Get-Member -MemberType NoteProperty |
            Where-Object { $_.Name -match "^path" } |
            Select-Object -First 1).Name

        Write-Host ""
        Write-Host "Multiple folders named '$FolderName' were found. Select the one to audit:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $folderResults.Count; $i++) {
            # Prefer the full path column; fall back to the raw ID if GAM didn't
            # return path data (e.g. when fullpath is unsupported for this drive type).
            $label = if ($pathColName) { $folderResults[$i].$pathColName } else { $folderResults[$i].id }
            Write-Host ("  [{0}] {1}" -f ($i + 1), $label) -ForegroundColor Green
        }
        Write-Host ""
        $folderSel    = Read-Host ("Select folder [1-{0}]" -f $folderResults.Count)
        $folderSelInt = 0
        if ([int]::TryParse($folderSel.Trim(), [ref]$folderSelInt) -and $folderSelInt -ge 1 -and $folderSelInt -le $folderResults.Count) {
            $FolderId   = $folderResults[$folderSelInt - 1].id
            $FolderName = $null
            Write-Host "Selected: $($folderResults[$folderSelInt - 1].name) (ID: $FolderId)" -ForegroundColor Green
        } else {
            throw "Invalid selection."
        }
    }
}

# -- Set up output directory --------------------------------------------------
# All three CSV reports land in the same directory. The default is a
# timestamped subfolder next to wherever the script was invoked from, so
# repeated runs don't overwrite each other.
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
# 'gam print diskusage' walks the entire folder tree and emits one CSV row per
# folder containing:
#   directFileCount / directFolderCount / directFileSize  — items in this folder only
#   totalFileCount  / totalFolderCount  / totalFileSize   — items in this folder + all descendants
# This gives migration planners a quick top-down view of where data volume lives.
Write-Host "[1/3] Running disk usage analysis..." -ForegroundColor Yellow
try {
    $diskUsageArgs = @(
        "user", $UserEmail,
        "print", "diskusage"
    )

    # The folder selector differs by audit mode:
    #   shareddriveid — root of an entire Shared Drive
    #   id:<guid>     — a specific folder by its Drive ID (unambiguous)
    #   drivefilename — folder by name (only reached if FolderName was never
    #                   resolved to an ID above, which shouldn't happen)
    if ($IncludeSharedDrive) {
        $diskUsageArgs += @("shareddriveid", $FolderId)
    } elseif ($FolderId) {
        $diskUsageArgs += @("id:$FolderId")
    } else {
        $diskUsageArgs += @("drivefilename", $FolderName)
    }

    $diskUsageOutput = & gam @diskUsageArgs 2>&1
    # GAM writes progress lines to stderr that get mixed into the output when
    # 2>&1 is used. Strip them so only valid CSV rows reach the file.
    $diskUsageData = $diskUsageOutput | Where-Object { $_ -notmatch "^(User:|Getting |Got )" }

    if ($diskUsageData) {
        $diskUsageData | Out-File -FilePath $diskUsageCsv -Encoding UTF8
        $rowCount = ($diskUsageData | Measure-Object).Count - 1  # subtract header row
        Write-Host "  Saved $rowCount folder records to DiskUsage.csv" -ForegroundColor Green
    } else {
        Write-Warning "  No disk usage data returned. Verify the folder name/ID and user access."
    }
} catch {
    Write-Error "  Disk usage query failed: $($_.Exception.Message)"
}

# -- Step 2: File Details (owner, size, path, permissions) --------------------
# 'gam print filelist' enumerates every file under the target folder and emits
# one CSV row per file. The fields requested are:
#   id, name, mimetype, size       — basic identity and size
#   owners.emailaddress            — who owns the file (may be external)
#   basicpermissions               — share recipients and their roles
# fullpath adds a path.N column with the full Drive path for each file.
# showshareddrivepermissions includes inherited permissions from the Shared
# Drive itself, which would otherwise be invisible in the permission columns.
# showownedby any ensures files owned by other users (e.g. external accounts)
# are included and not silently skipped.
Write-Host "[2/3] Retrieving file details with ownership and permissions..." -ForegroundColor Yellow
try {
    $fileListArgs = @(
        "user", $UserEmail,
        "print", "filelist",
        "select"   # 'select' introduces the folder scope argument that follows
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
# This step is pure PowerShell post-processing — no additional GAM calls.
# It reads FileDetails.csv and builds a per-folder summary answering two
# questions that matter most for migration risk assessment:
#   ExternallyOwned   — files where the owner email is outside the tenant domain
#                       (these may not migrate cleanly; ownership must be transferred)
#   SharedExternally  — files shared with anyone outside the tenant domain,
#                       including specific external emails, external domains,
#                       and "anyone with the link" (public) permissions
Write-Host "[3/3] Analyzing external ownership and sharing..." -ForegroundColor Yellow
try {
    if (Test-Path $fileDetailCsv) {
        $files = Import-Csv $fileDetailCsv

        # GAM names the full-path column 'path.0' (and 'path.1', 'path.2'... for
        # files with multiple parents). We take the first one.
        $pathCol = ($files | Get-Member -MemberType NoteProperty |
            Where-Object { $_.Name -match "^path" } |
            Select-Object -First 1).Name

        if (-not $pathCol) {
            Write-Warning "  Could not find path column in file details. Skipping summary."
        } else {
            # GAM names the owner column 'owners.0.emailaddress' (or similar).
            $ownerCol = ($files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -match "owners.*emailaddress" } |
                Select-Object -First 1).Name

            # basicpermissions produces columns like:
            #   permissions.0.emailaddress, permissions.0.domain, permissions.0.type
            # We grab all of them and inspect each one per file.
            $permCols = $files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -match "permissions\.\d+\.(emailaddress|domain|type)" }

            # Use a hashtable keyed by folder path to accumulate per-folder counts.
            $summary = @{}

            foreach ($file in $files) {
                $filePath = $file.$pathCol
                if (-not $filePath) { continue }

                # Derive the containing folder path by dropping the last path segment
                # (the file name itself). Files at the root of the audited folder
                # have no parent segment, so we use the full path as the key.
                $pathParts = $filePath -split "/"
                if ($pathParts.Count -gt 1) {
                    $folderPath = ($pathParts[0..($pathParts.Count - 2)]) -join "/"
                } else {
                    $folderPath = $filePath
                }

                # Create an entry for this folder path the first time we see it.
                if (-not $summary.ContainsKey($folderPath)) {
                    $summary[$folderPath] = [PSCustomObject]@{
                        FolderPath       = $folderPath
                        TotalFiles       = 0
                        ExternallyOwned  = 0
                        SharedExternally = 0
                    }
                }

                $entry = $summary[$folderPath]
                $entry.TotalFiles++

                # Check ownership: if the owner email doesn't contain the tenant
                # domain, the file is externally owned.
                if ($ownerCol) {
                    $ownerEmail = $file.$ownerCol
                    if ($ownerEmail -and $ownerEmail -notmatch [regex]::Escape($Domain)) {
                        $entry.ExternallyOwned++
                    }
                }

                # Check permissions: scan every permission column on this file.
                # A file is flagged SharedExternally if any single permission is
                # for an outside email, an outside domain, or type 'anyone'
                # (public / anyone-with-the-link access).
                $isSharedExternally = $false
                foreach ($col in $permCols) {
                    $val = $file.($col.Name)
                    if (-not $val) { continue }

                    if ($col.Name -match "emailaddress") {
                        # A specific person outside the domain has been granted access.
                        if ($val -and $val -notmatch [regex]::Escape($Domain)) {
                            $isSharedExternally = $true
                        }
                    } elseif ($col.Name -match "\.type$") {
                        # type 'anyone' = public link (no sign-in required or anyone signed in).
                        if ($val -eq "anyone") {
                            $isSharedExternally = $true
                        }
                    } elseif ($col.Name -match "\.domain$") {
                        # Shared with an entire external domain.
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

# Restore GAMCFGDIR to its original value so the calling shell session is not
# left pointing at this customer's workspace after the script exits.
$env:GAMCFGDIR = $originalGamCfgDir

Stop-Transcript
