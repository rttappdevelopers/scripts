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

    Outputs four files to the specified output directory:
      1. FolderDetails.csv - folder-level stats from GAM enriched with ownership/sharing
                             columns computed from FileDetails (see column legend at the end
                             of the run for definitions of script-added columns)
      2. FileDetails.csv   - every file with owner, path, size, and permissions
      3. Summary.csv       - one row per top-level folder with recursive totals and
                             cumulative external ownership and sharing counts
      4. FolderTree.txt    - indented folder hierarchy annotated with direct counts

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
    Your Google Workspace primary domain, or a comma-separated list of all
    domains considered internal to this tenant (e.g., "contoso.com,contoso.net").
    Used to classify file owners and share recipients as internal or external.
    All listed domains are treated as equally internal; any email address whose
    domain is not in this list is classified as external.

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
    [string]$ConfigDir     = "",
    # When the script is re-run against an existing OutputDir containing a state
    # file, -Resume continues from the next un-processed subtree and -Restart
    # discards prior progress and starts over. If neither switch is supplied
    # and a state file is detected, the script prompts interactively.
    [switch]$Resume,
    [switch]$Restart
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

# Save the original GAMCFGDIR now so the finally block can restore it even if
# the script is interrupted (Ctrl+C) before the restore line at the end.
$originalGamCfgDir = $env:GAMCFGDIR

# Tracks whether all steps completed cleanly. Any step failure or missing data
# degrades this to 'Partial'. The completion banner reflects the final value.
$runStatus = 'Success'

try {

# -- Helper functions ---------------------------------------------------------
# Invoke-GamStream: run a GAM command and stream its output line-by-line to a
# CSV file on disk. Each non-progress line containing a comma is appended to
# the target file as soon as it arrives, so a long-running walk produces a
# growing CSV that survives an unexpected reboot. A heartbeat is printed every
# $HeartbeatSeconds with the current row count and rate.
#
# Returns a hashtable with the row count and exit code so callers can decide
# whether the run succeeded.
function Invoke-GamStream {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string]   $OutputCsv,
        [string] $Label = 'rows',
        [int]    $HeartbeatSeconds = 30,
        [switch] $WriteHeader
    )

    # Use a .partial file while writing so a Ctrl+C or crash leaves an obvious
    # marker that the file is incomplete; rename to final on success.
    $partial = "$OutputCsv.partial"
    if (Test-Path $partial) { Remove-Item $partial -Force }

    $writer = [System.IO.StreamWriter]::new($partial, $false, [System.Text.UTF8Encoding]::new($false))
    $rowCount     = 0
    $headerWritten = $false
    $startTime    = Get-Date
    $nextBeat     = $startTime.AddSeconds($HeartbeatSeconds)

    try {
        # Stream stdout AND stderr together so GAM progress lines (stderr)
        # interleave with CSV rows (stdout) in the order GAM emits them.
        # Out-Null on the file write would buffer; StreamWriter.WriteLine
        # flushes on each AutoFlush=true call.
        $writer.AutoFlush = $true

        & gam @Arguments 2>&1 | ForEach-Object {
            $line = "$_"
            if ($line -match ',' -and $line -notmatch '^\s*User:' -and $line -notmatch '^Getting ' -and $line -notmatch '^Got ') {
                # CSV data line: header arrives first, then rows.
                if (-not $headerWritten) {
                    if ($WriteHeader) { $writer.WriteLine($line) }
                    $headerWritten = $true
                } else {
                    $writer.WriteLine($line)
                    $rowCount++
                }
            } else {
                # Progress / status line: echo to console only.
                Write-Host "    $line" -ForegroundColor DarkGray
            }

            $now = Get-Date
            if ($now -ge $nextBeat) {
                $elapsed = ($now - $startTime).TotalSeconds
                $rate    = if ($elapsed -gt 0) { [int](($rowCount / $elapsed) * 60) } else { 0 }
                Write-Host ("    [{0:HH:mm:ss}] {1}: {2:N0} {3} written ({4:N0}/min)" -f $now, (Split-Path $OutputCsv -Leaf), $rowCount, $Label, $rate) -ForegroundColor Cyan
                $nextBeat = $now.AddSeconds($HeartbeatSeconds)
            }
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $writer.Close()
    }

    if ($exitCode -eq 0) {
        Move-Item -Path $partial -Destination $OutputCsv -Force
    }

    return @{ RowCount = $rowCount; ExitCode = $exitCode; HeaderWritten = $headerWritten }
}

# Save-AuditState / Load-AuditState: persist a small JSON manifest in the
# OutputDir describing the audit scope and per-subtree completion. This is
# what enables -Resume after an interruption (Ctrl+C, reboot, network drop).
function Save-AuditState {
    param([Parameter(Mandatory)][hashtable]$State, [Parameter(Mandatory)][string]$Path)
    $json = $State | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Load-AuditState {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content -Raw -Path $Path
    return ($raw | ConvertFrom-Json -AsHashtable)
}
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
# (The original value is captured before the try block above; no assignment needed here.)

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
        # Wrap in @() to guarantee an array even when only one workspace exists.
        # Without it, a single result is unwrapped to a bare string and indexing
        # into it ($existingWorkspaces[$i]) returns individual characters.
        $existingWorkspaces = @(
            Get-ChildItem -Path $ConfigBaseDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "gam.cfg") } |
                Select-Object -ExpandProperty Name | Sort-Object
        )
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
        $selInt = 0
        do {
            $sel = Read-Host ("Select workspace [1-{0}]" -f $existingWorkspaces.Count)
        } while (-not ([int]::TryParse($sel.Trim(), [ref]$selInt) -and $selInt -ge 1 -and $selInt -le $existingWorkspaces.Count))
        $ConfigDir = Join-Path $ConfigBaseDir $existingWorkspaces[$selInt - 1]
        $env:GAMCFGDIR = $ConfigDir
        Write-Host "Selected: $($existingWorkspaces[$selInt - 1])" -ForegroundColor Green
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
# This makes the script safe to run with no arguments - it will always ask
# for everything it needs before touching the Drive API.

# UserEmail is the account GAM impersonates via service account delegation.
# It must be a real user in the target workspace (typically an admin).
if ([string]::IsNullOrWhiteSpace($UserEmail)) {
    $UserEmail = Read-Host "Enter the Google Workspace user email to impersonate (e.g., user@yourdomain.com)"
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

# Build the allow list of internal domains. $Domain may contain a single domain
# or a comma-separated list (F-03). All comparisons use this list rather than
# the raw $Domain string so alias domains are handled correctly.
$InternalDomains = @(
    $Domain.Split(',') |
        ForEach-Object { $_.Trim().ToLower() } |
        Where-Object { $_ }
)

# Ask how to identify the target folder. Three modes are supported:
#   1) Folder name  - human-readable search; may return multiple matches
#      which the script will resolve via a follow-up selection prompt.
#   2) Folder ID    - unambiguous; paste from the Drive URL (?id=...)
#   3) Shared Drive ID - audits an entire Shared Drive rather than a subfolder;
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
            # Accept a full Drive URL in addition to a bare ID.
            # Detect resource keys - GAM cannot send the X-Goog-Drive-Resource-Keys
            # header, so folders requiring a resource key will fail with 404.
            if ($FolderId -match '[?&]resourcekey=') {
                $ResourceKey = $true
            }
            # Pattern: /folders/<ID> optionally followed by ? or end of string.
            if ($FolderId -match '/folders/([^/?]+)') {
                $FolderId = $Matches[1]
            }
        }
        '3' {
            $FolderId = Read-Host "Enter the Shared Drive ID"
            if ([string]::IsNullOrWhiteSpace($FolderId)) {
                throw "Shared Drive ID is required."
            }
            # Accept a full Drive URL in addition to a bare ID.
            if ($FolderId -match '[?&]resourcekey=') {
                $ResourceKey = $true
            }
            if ($FolderId -match '/folders/([^/?]+)') {
                $FolderId = $Matches[1]
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
    # Capture stdout only so stderr status/progress lines cannot contaminate
    # CSV parsing (for example if a warning line contains commas).
    $folderSearchOutput = & gam @folderSearchArgs
    if ($LASTEXITCODE -ne 0) {
        throw "GAM folder search command failed (exit $LASTEXITCODE). Check GAM configuration and user access."
    }
    # Strip GAM progress lines so only the CSV data remains.
    $folderSearchData   = $folderSearchOutput | Where-Object { $_ -match ',' -and $_ -notmatch '^\s*User:' }
    $folderResults      = @($folderSearchData | ConvertFrom-Csv)

    if ($folderResults.Count -eq 0) {
        throw "No folders named '$FolderName' were found accessible by $UserEmail."
    } elseif ($folderResults.Count -eq 1) {
        # Exactly one match - resolve to its ID automatically.
        $FolderId   = $folderResults[0].id
        $FolderName = $null
        Write-Host "  Found: $($folderResults[0].name) (ID: $FolderId)" -ForegroundColor Green
    } else {
        # Multiple matches - show each one's full path so the technician can
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

$diskUsageCsv    = Join-Path $OutputDir "FolderDetails.csv"
$fileDetailCsv   = Join-Path $OutputDir "FileDetails.csv"
$summaryCsv      = Join-Path $OutputDir "Summary.csv"
$folderTreeTxt   = Join-Path $OutputDir "FolderTree.txt"
$stateFile       = Join-Path $OutputDir "audit.state.json"
$subtreeDir      = Join-Path $OutputDir "_subtrees"
if (-not (Test-Path $subtreeDir)) { New-Item -ItemType Directory -Path $subtreeDir -Force | Out-Null }

# -- Resume / Restart detection -----------------------------------------------
# If a state file exists in the OutputDir we have a prior run that may be
# resumable. Honor explicit -Resume / -Restart switches; otherwise prompt.
# A non-interactive caller that supplies -OutputDir without either switch will
# get the prompt (we never silently destroy data).
$existingState = Load-AuditState -Path $stateFile
$resumeMode    = $false
if ($existingState) {
    $doneCount    = @($existingState.Subtrees.Values | Where-Object { $_.Status -eq 'done' }).Count
    $totalCount   = $existingState.Subtrees.Count
    $pendingCount = $totalCount - $doneCount

    Write-Host ""
    Write-Host "Existing audit state detected in: $OutputDir" -ForegroundColor Yellow
    Write-Host "  Started:  $($existingState.StartTime)" -ForegroundColor DarkGray
    Write-Host "  Folder:   $($existingState.FolderName) ($($existingState.FolderId))" -ForegroundColor DarkGray
    Write-Host "  Progress: $doneCount of $totalCount subtrees complete ($pendingCount remaining)" -ForegroundColor DarkGray
    Write-Host ""

    if ($Resume) {
        $resumeMode = $true
        Write-Host "  -Resume specified: continuing from subtree $($doneCount + 1) of $totalCount." -ForegroundColor Green
    } elseif ($Restart) {
        Write-Host "  -Restart specified: discarding prior progress." -ForegroundColor Yellow
        Remove-Item $stateFile -Force
        if (Test-Path $subtreeDir) { Get-ChildItem $subtreeDir -File | Remove-Item -Force }
        $existingState = $null
    } else {
        $choice = Read-Host "Resume from subtree $($doneCount + 1)? [Y]es / [N]o (start over) / [Q]uit"
        switch ($choice.Trim().ToUpper()) {
            'Y' { $resumeMode = $true; Write-Host "  Resuming." -ForegroundColor Green }
            'N' {
                Write-Host "  Starting over - prior progress discarded." -ForegroundColor Yellow
                Remove-Item $stateFile -Force
                if (Test-Path $subtreeDir) { Get-ChildItem $subtreeDir -File | Remove-Item -Force }
                $existingState = $null
            }
            default { throw "Aborted by user." }
        }
    }
}

$auditTimer = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Google Drive Folder Audit" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "User:       $UserEmail"
Write-Host "Domain(s):  $($InternalDomains -join ', ')"
if ($FolderName) { Write-Host "Folder:     $FolderName" }
if ($FolderId)   { Write-Host "Folder ID:  $FolderId" }
Write-Host "Output:     $OutputDir"

# Resource keys are required by the Google Drive API for legacy link-shared
# items (pre-September 2021 "anyone with the link" shares). The API expects
# the key in the X-Goog-Drive-Resource-Keys HTTP header, but GAM does not
# send this header. The folder owner can access it without a resource key.
# Try the current user first; only prompt for a different owner if needed.
if ($ResourceKey) {
    Write-Host ""
    Write-Host "WARNING: This folder URL contains a resource key." -ForegroundColor Yellow
    Write-Host "  GAM cannot access resource key-protected folders directly." -ForegroundColor Yellow
    Write-Host "  Verifying whether $UserEmail can access the folder..." -ForegroundColor Cyan

    $verifyResult = gam user $UserEmail show fileinfo "id:$FolderId" fields "name" 2>$null
    if ($LASTEXITCODE -eq 0) {
        # The current user can reach the folder (likely the owner).
        foreach ($line in $verifyResult) {
            if ($line -match '^\s*name:\s*(.+)$') {
                Write-Host "  Folder found: $($Matches[1].Trim())" -ForegroundColor Green
            }
        }
        Write-Host "  $UserEmail has access - proceeding." -ForegroundColor Green
    } else {
        # Current user cannot access; ask for the owner's email.
        Write-Host "  $UserEmail cannot access this folder." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To find the owner: open the folder in Google Drive, click the" -ForegroundColor DarkGray
        Write-Host "  (i) details panel, and look for the Owner field." -ForegroundColor DarkGray
        Write-Host ""

        $ownerEmail = Read-Host "Enter the folder owner's email address"
        if ([string]::IsNullOrWhiteSpace($ownerEmail)) {
            throw "Owner email is required for resource key-protected folders."
        }

        Write-Host ""
        Write-Host "  Verifying access as $ownerEmail..." -ForegroundColor DarkGray
        $verifyResult = gam user $ownerEmail show fileinfo "id:$FolderId" fields "name" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Cannot access folder as $ownerEmail. Verify the email is correct and the user owns the folder."
        }

        foreach ($line in $verifyResult) {
            if ($line -match '^\s*name:\s*(.+)$') {
                Write-Host "  Folder found: $($Matches[1].Trim())" -ForegroundColor Green
            }
        }

        Write-Host "  Audit user changed from $UserEmail to $ownerEmail" -ForegroundColor Green
        $UserEmail = $ownerEmail
    }

    # Clear the resource key flag - the verified user can access the folder.
    $ResourceKey = $false
    Write-Host ""
}
Write-Host ""

# -- Step 1: Enumerate top-level subtrees -------------------------------------
# Rather than hand the entire folder tree to one GAM 'print diskusage' walk
# (which buffers the whole result in memory and gives no progress visibility
# until it finishes - hours later), we split the audit into one GAM call per
# immediate child folder. Each child is a "subtree" that is processed
# independently, streamed to its own CSV file on disk, and checkpointed in
# audit.state.json so a Ctrl+C, reboot, or network drop is fully recoverable.
#
# Two extra entries are added to the work list:
#   __ROOT_FILES__ - files that live directly in the audited folder (not in
#                    any subfolder). Captured with depth 0 against the root.
#   __ROOT_INFO__  - the root folder itself, so it appears in FolderDetails.
#
# We also use 'print filelist' instead of 'print diskusage' for the per-subtree
# walk. filelist returns full file metadata (owner, perms, size, path) AND
# can be used to derive folder-level statistics locally in PowerShell, which
# eliminates the second slow walk that the prior version performed.

if (-not $existingState) {
    Write-Host "[1/4] Enumerating top-level subtrees..." -ForegroundColor Yellow

    $childArgs = @(
        "user", $UserEmail,
        "print", "filelist",
        "select", "id:$FolderId",
        "depth", "0",
        "showmimetype", "gfolder",
        "fields", "id,name",
        "showownedby", "any"
    )
    if ($IncludeSharedDrive) {
        # For Shared Drives the selector is shareddriveid, not id:
        $childArgs = @(
            "user", $UserEmail,
            "print", "filelist",
            "select", "shareddriveid", $FolderId,
            "depth", "0",
            "showmimetype", "gfolder",
            "fields", "id,name",
            "showownedby", "any"
        )
    }

    $childOutput = & gam @childArgs 2>&1 | Where-Object { $_ -match ',' -and $_ -notmatch '^\s*User:' -and $_ -notmatch '^Getting ' -and $_ -notmatch '^Got ' }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enumerate top-level folders (exit $LASTEXITCODE). Check GAM configuration and folder access."
    }

    $childFolders = @($childOutput | ConvertFrom-Csv)
    Write-Host "  Found $($childFolders.Count) top-level subfolder(s)." -ForegroundColor Green

    # Build the work list. Order matters for resume: process root files first
    # so the root folder shows up immediately in FileDetails, then each child.
    $subtrees = [ordered]@{}
    $subtrees['__ROOT_FILES__'] = @{ Name = '(root files)'; FolderId = $FolderId; Depth0 = $true; Status = 'pending' }
    foreach ($cf in $childFolders) {
        $subtrees[$cf.id] = @{ Name = $cf.name; FolderId = $cf.id; Depth0 = $false; Status = 'pending' }
    }

    $auditState = @{
        StartTime    = (Get-Date).ToString('o')
        FolderId     = $FolderId
        FolderName   = if ($childFolders.Count -gt 0) { 'audited folder' } else { '(unknown)' }
        UserEmail    = $UserEmail
        Domain       = $Domain
        SharedDrive  = [bool]$IncludeSharedDrive
        Subtrees     = $subtrees
    }
    Save-AuditState -State $auditState -Path $stateFile
    Write-Host "  State file: $stateFile" -ForegroundColor DarkGray
} else {
    $auditState = $existingState
    Write-Host "[1/4] Reusing prior subtree list ($($auditState.Subtrees.Count) total)." -ForegroundColor Yellow
}
Write-Host ""

# -- Step 2: Walk each subtree (streaming, checkpointed) ----------------------
# For each pending subtree, run a single 'gam print filelist' that returns
# every file and folder under it. Output streams to a per-subtree CSV file
# (e.g. _subtrees/<folderId>.csv) as rows arrive, with a heartbeat printed
# every 30 seconds. When the GAM call finishes successfully, the subtree is
# marked 'done' in the state file and the next one starts. Subtrees marked
# 'done' on a prior run are skipped, enabling -Resume.

Write-Host "[2/4] Walking subtrees (streaming to disk; resumable)..." -ForegroundColor Yellow
$subtreeKeys   = @($auditState.Subtrees.Keys)
$totalSubtrees = $subtreeKeys.Count
$pendingKeys   = @($subtreeKeys | Where-Object { $auditState.Subtrees[$_].Status -ne 'done' })
$skipped       = $totalSubtrees - $pendingKeys.Count
if ($skipped -gt 0) {
    Write-Host "  Skipping $skipped subtree(s) already completed on a prior run." -ForegroundColor DarkGray
}

$subtreeIdx = 0
foreach ($key in $subtreeKeys) {
    $subtreeIdx++
    $entry = $auditState.Subtrees[$key]
    if ($entry.Status -eq 'done') { continue }

    $progressLabel = "[$subtreeIdx/$totalSubtrees] $($entry.Name)"
    Write-Host ""
    Write-Host "  $progressLabel" -ForegroundColor White
    Write-Host "    ID: $($entry.FolderId)" -ForegroundColor DarkGray

    # Build the subtree filelist command. ROOT_FILES uses depth 0 against the
    # audited folder; everything else walks the entire subtree under the child.
    $gamArgs = @("user", $UserEmail, "print", "filelist", "select")
    if ($entry.Depth0 -and $IncludeSharedDrive) {
        $gamArgs += @("shareddriveid", $entry.FolderId, "depth", "0")
    } elseif ($entry.Depth0) {
        $gamArgs += @("id:$($entry.FolderId)", "depth", "0")
    } else {
        $gamArgs += @("id:$($entry.FolderId)")
    }
    $gamArgs += @(
        "showownedby", "any",
        "fields", "id,name,mimetype,size,parents,owners.emailaddress,basicpermissions",
        "fullpath",
        "showshareddrivepermissions"
    )

    $subtreeCsv = Join-Path $subtreeDir ("{0}.csv" -f ($key -replace '[^A-Za-z0-9_-]', '_'))
    $entry.Status     = 'in-progress'
    $entry.StartedAt  = (Get-Date).ToString('o')
    Save-AuditState -State $auditState -Path $stateFile

    try {
        # First subtree writes the header; subsequent ones drop it (we'll
        # concatenate later). Actually each per-subtree CSV needs its own
        # header so it's individually openable for debugging - keep the header.
        $result = Invoke-GamStream -Arguments $gamArgs -OutputCsv $subtreeCsv -Label 'files' -WriteHeader

        if ($result.ExitCode -ne 0) {
            Write-Warning "    GAM exited with code $($result.ExitCode) - subtree may be incomplete."
            $entry.Status     = 'failed'
            $entry.ExitCode   = $result.ExitCode
            $runStatus = 'Partial'
        } else {
            $entry.Status     = 'done'
            $entry.RowCount   = $result.RowCount
            $entry.CompletedAt = (Get-Date).ToString('o')
            Write-Host "    Done. $($result.RowCount) rows captured." -ForegroundColor Green
        }
    } catch {
        Write-Error "    Subtree failed: $($_.Exception.Message)"
        $entry.Status = 'failed'
        $runStatus = 'Partial'
    }

    Save-AuditState -State $auditState -Path $stateFile
}

# -- Step 2.5: Merge subtree CSVs into FileDetails.csv ------------------------
# Each subtree wrote its own per-folder CSV with its own header. The headers
# may differ slightly (different number of permissions.N.* or path.N columns
# depending on the subtree), so we union the columns rather than blindly
# concatenating. Output is a single FileDetails.csv that downstream steps
# already know how to consume.

Write-Host ""
Write-Host "[3/4] Merging subtree results into FileDetails.csv..." -ForegroundColor Yellow
$subtreeFiles = @(Get-ChildItem -Path $subtreeDir -Filter '*.csv' -File -ErrorAction SilentlyContinue)
if ($subtreeFiles.Count -eq 0) {
    Write-Warning "  No subtree CSVs found - nothing to merge."
    $runStatus = 'Partial'
} else {
    # Read all rows. Import-Csv handles header per file; results are PSObjects
    # whose union we can write back via Export-Csv.
    $allRows = @()
    foreach ($sf in $subtreeFiles) {
        try {
            $rows = @(Import-Csv -Path $sf.FullName)
            $allRows += $rows
        } catch {
            Write-Warning "  Failed to read $($sf.Name): $($_.Exception.Message)"
        }
    }
    if ($allRows.Count -gt 0) {
        # Deduplicate by id - the same folder/file can appear in multiple
        # subtrees if a subtree includes its parent (showparent option).
        $deduped = $allRows | Group-Object -Property id | ForEach-Object { $_.Group | Select-Object -First 1 }
        $deduped | Export-Csv -Path $fileDetailCsv -NoTypeInformation -Encoding UTF8
        Write-Host "  Wrote $($deduped.Count) unique records to FileDetails.csv." -ForegroundColor Green
    } else {
        Write-Warning "  Subtree files were empty."
        $runStatus = 'Partial'
    }
}

# -- Step 2.6: Derive FolderDetails.csv locally from FileDetails -------------
# Replaces the per-folder 'gam print diskusage' walk that the prior version
# ran (O(folders) sequential API calls, hours for large trees). Now we read
# the already-collected file list and compute per-folder stats in PowerShell:
#   directFileCount / directFolderCount / directFileSize  - immediate children
#   totalFileCount  / totalFolderCount  / totalFileSize   - recursive totals
# Folder identity comes from rows whose mimeType is application/vnd.google-apps.folder.
# Direct children are computed by parent ID; recursive totals by path prefix.

Write-Host ""
Write-Host "[3b/4] Deriving FolderDetails.csv from FileDetails (no extra API calls)..." -ForegroundColor Yellow
if (Test-Path $fileDetailCsv) {
    $allItems = @(Import-Csv -Path $fileDetailCsv)
    $folderMime = 'application/vnd.google-apps.folder'

    # Identify the path column that GAM produced (path.0, path.1, ...).
    # Match 'path.<digits>' specifically so we do not pick up the 'paths'
    # count column.
    $pathColLocal = ($allItems[0].PSObject.Properties |
        Where-Object { $_.Name -match '^path\.\d+$' } | Select-Object -First 1).Name
    if (-not $pathColLocal) {
        Write-Warning "  No path column found in FileDetails.csv. FolderDetails cannot be derived."
        $runStatus = 'Partial'
    } else {
        # Build folder lookup keyed by ID with depth/path/name and a stats accumulator.
        $folderById = @{}
        foreach ($it in $allItems) {
            if ($it.mimeType -eq $folderMime) {
                $rawPath = ($it.$pathColLocal | ForEach-Object { $_ }) -as [string]
                if ($rawPath) { $rawPath = $rawPath.TrimStart('/') }
                $folderById[$it.id] = [PSCustomObject]@{
                    id                = $it.id
                    name              = $it.name
                    path              = $rawPath
                    parentId          = $it.'parents.0.id'
                    depth             = -2  # filled in below
                    directFileCount   = 0
                    directFolderCount = 0
                    directFileSize    = 0
                    totalFileCount    = 0
                    totalFolderCount  = 0
                    totalFileSize     = 0
                    ownedByMe         = ''
                    trashed           = $false
                    explicitlyTrashed = $false
                    Owner             = ''
                }
            }
        }

        # The audited folder itself may not appear in the file list rows when it
        # is a Shared Drive root or when 'showparent' was suppressed. Derive its
        # full path from any direct child (parent of which is the audited folder)
        # by stripping the child's last segment. This is required for correct
        # depth assignment and recursive prefix matching below.
        $rootPathLocal = $null
        $directChild = $allItems | Where-Object { $_.'parents.0.id' -eq $FolderId -and $_.$pathColLocal } | Select-Object -First 1
        if ($directChild) {
            $childPath = $directChild.$pathColLocal
            $lastSlash = $childPath.LastIndexOf('/')
            if ($lastSlash -gt 0) { $rootPathLocal = $childPath.Substring(0, $lastSlash) }
        }

        if (-not $folderById.ContainsKey($FolderId)) {
            $folderById[$FolderId] = [PSCustomObject]@{
                id = $FolderId; name = '(audited folder)'; path = $rootPathLocal; parentId = $null;
                depth = -1; directFileCount = 0; directFolderCount = 0; directFileSize = 0;
                totalFileCount = 0; totalFolderCount = 0; totalFileSize = 0;
                ownedByMe = ''; trashed = $false; explicitlyTrashed = $false; Owner = ''
            }
        } else {
            $folderById[$FolderId].depth = -1
            if ($rootPathLocal) { $folderById[$FolderId].path = $rootPathLocal }
        }

        # Pass 1: direct counts from each item's parent.
        foreach ($it in $allItems) {
            $parent = $it.'parents.0.id'
            if (-not $parent -or -not $folderById.ContainsKey($parent)) { continue }
            $f = $folderById[$parent]
            if ($it.mimeType -eq $folderMime) {
                $f.directFolderCount++
            } else {
                $f.directFileCount++
                $sz = 0
                if ($it.size -and [long]::TryParse($it.size, [ref]$sz)) { $f.directFileSize += $sz }
            }
        }

        # Pass 2: depth assignment. Direct children of the audited folder are
        # depth 0, grandchildren depth 1, and so on. Use the parent chain via
        # parents.0.id (more reliable than path slash counting because folder
        # names can themselves contain slashes when GAM URL-encodes them).
        foreach ($f in $folderById.Values) {
            if ($f.id -eq $FolderId) { $f.depth = -1; continue }
            $depth = 0
            $current = $f.parentId
            $guard = 0
            while ($current -and $current -ne $FolderId -and $guard -lt 64) {
                if (-not $folderById.ContainsKey($current)) { break }
                $current = $folderById[$current].parentId
                $depth++
                $guard++
            }
            if ($current -eq $FolderId) {
                $f.depth = $depth
            } else {
                # Fall back to path-based depth when parent chain is broken
                # (e.g. shared drive items whose parents we did not capture).
                if ($f.path -and $rootPathLocal -and $f.path.StartsWith("$rootPathLocal/")) {
                    $rel = $f.path.Substring($rootPathLocal.Length + 1)
                    $f.depth = ($rel -split '/').Count - 1
                } else {
                    $f.depth = 0
                }
            }
        }

        # Pass 3: recursive totals via path-prefix matching. For each folder,
        # totalFileCount = sum of direct files in this folder and every folder
        # whose path starts with "$thisPath/".
        $foldersByPath = $folderById.Values | Where-Object { $_.path } | Sort-Object { $_.path.Length }
        foreach ($f in $foldersByPath) {
            $f.totalFileCount   = $f.directFileCount
            $f.totalFolderCount = $f.directFolderCount
            $f.totalFileSize    = $f.directFileSize
            $prefix = "$($f.path)/"
            foreach ($g in $foldersByPath) {
                if ($g.id -eq $f.id) { continue }
                if ($g.path.StartsWith($prefix)) {
                    $f.totalFileCount   += $g.directFileCount
                    $f.totalFolderCount += $g.directFolderCount + 0  # already counted via direct
                    $f.totalFileSize    += $g.directFileSize
                }
            }
            # totalFolderCount = count of all descendant folders.
            $f.totalFolderCount = @($foldersByPath | Where-Object { $_.id -ne $f.id -and $_.path.StartsWith($prefix) }).Count
        }

        # Emit FolderDetails.csv with the column names downstream code expects.
        $folderRows = $folderById.Values |
            Sort-Object depth, path |
            Select-Object @{N='User';E={$UserEmail}},
                          @{N='Owner';E={$_.Owner}},
                          id, name, ownedByMe, trashed, explicitlyTrashed,
                          directFileCount, directFileSize, directFolderCount,
                          totalFileCount, totalFileSize, totalFolderCount,
                          depth, path
        $folderRows | Export-Csv -Path $diskUsageCsv -NoTypeInformation -Encoding UTF8
        Write-Host "  Derived $($folderById.Count) folder records." -ForegroundColor Green
    }
} else {
    Write-Warning "  FileDetails.csv missing - cannot derive FolderDetails."
    $runStatus = 'Partial'
}

# -- Step 3: Aggregate external ownership and sharing per folder --------------
# This step is pure PowerShell post-processing - no additional GAM calls.
# It reads FileDetails.csv and builds a per-folder summary answering two
# questions that matter most for migration risk assessment:
#   ExternallyOwned   - files where the owner email is outside the tenant domain
#                       (these may not migrate cleanly; ownership must be transferred)
#   SharedExternally  - files shared with anyone outside the tenant domain,
#                       including specific external emails, external domains,
#                       and "anyone with the link" (public) permissions
Write-Host "[4/4] Analyzing external ownership and sharing..." -ForegroundColor Yellow
try {
    if (Test-Path $fileDetailCsv) {
        $files = Import-Csv $fileDetailCsv

        if (-not $files) {
            Write-Warning "  FileDetails.csv is empty - no files were returned by GAM. Skipping summary."
            $runStatus = 'Partial'
        } else {
        # GAM names the full-path column 'path.0' (and 'path.1', 'path.2'...
        # Match 'path.<digits>' to avoid matching the 'paths' count column.
        $pathCol = ($files | Get-Member -MemberType NoteProperty |
            Where-Object { $_.Name -match '^path\.\d+$' } |
            Select-Object -First 1).Name

        if (-not $pathCol) {
            Write-Warning "  Could not find path column in file details. Skipping summary."
            $runStatus = 'Partial'
        } else {
            # GAM names the owner column 'owners.0.emailaddress' (or similar).
            $ownerCol = ($files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -match "owners.*emailaddress" } |
                Select-Object -First 1).Name

            # F-06: Warn explicitly when the owner column is missing so the
            # technician knows ExternallyOwned counts will be zero rather than
            # silently wrong. Degrade run status to Partial.
            if (-not $ownerCol) {
                Write-Warning "  Owner email column not found in FileDetails.csv. External ownership cannot be determined. Verify GAM fields include owners.emailaddress."
                $runStatus = 'Partial'
            }

            # basicpermissions produces columns like:
            #   permissions.0.emailaddress, permissions.0.domain, permissions.0.type
            # We grab all of them and inspect each one per file.
            $permCols = $files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -match "permissions\.\d+\.(emailaddress|domain|type)" }

            # F-07: Warn explicitly when no permission columns are found so the
            # technician knows SharedExternally counts will be zero rather than
            # silently wrong. Degrade run status to Partial.
            if (-not $permCols) {
                Write-Warning "  No permission columns found in FileDetails.csv. External sharing cannot be determined. Verify GAM fields include basicpermissions."
                $runStatus = 'Partial'
            }

            # Build a lookup of known folder paths from FolderDetails.csv (if available),
            # sorted longest-first so greedy prefix matching works correctly even when
            # folder names contain a literal '/' character (e.g. "Contracts/Proposals").
            # Without this, splitting the file path on '/' would misidentify the folder.
            #
            # Also capture $rootPath (the depth -1 row's path). GAM sometimes prefixes
            # file paths with parent segments from the shared drive hierarchy that do not
            # appear in diskusage output (e.g. 'Shared Drive Name/Subfolder/...')
            # while diskusage paths start at the audited folder ('Subfolder/...').
            # We use $rootPath to strip that extra prefix inside the file-processing loop.
            $knownFolderPaths = @()
            $rootPath = $null
            if (Test-Path $diskUsageCsv) {
                $diskRowsForEnrich = @(Import-Csv $diskUsageCsv | Where-Object { $_.path -and $_.path -ne 'Trash' })
                $rootPathRow = $diskRowsForEnrich | Where-Object { [int]$_.depth -eq -1 } | Select-Object -First 1
                $rootPath = if ($rootPathRow) { $rootPathRow.path } else { $null }
                $knownFolderPaths = @(
                    $diskRowsForEnrich |
                        Select-Object -ExpandProperty path |
                        Sort-Object { $_.Length } -Descending
                )
            }

            # Detect the mimeType column name for filtering folder entries below.
            $mimeCol = ($files | Get-Member -MemberType NoteProperty |
                Where-Object { $_.Name -eq 'mimeType' } |
                Select-Object -First 1).Name

            if (-not $mimeCol) {
                Write-Warning "  mimeType column not found in FileDetails.csv. Folder entries cannot be distinguished from files and will be counted as files. Verify GAM fields include mimetype."
                $runStatus = 'Partial'
            }

            # Use a hashtable keyed by folder path to accumulate per-folder counts.
            $summary = @{}

            # First pass: count direct subfolders per folder path.
            # This uses the folder entries (mimeType = application/vnd.google-apps.folder)
            # that we skip in the file-counting loop below.
            $folderCounts = @{}
            foreach ($file in $files) {
                if (-not $mimeCol -or $file.$mimeCol -ne 'application/vnd.google-apps.folder') { continue }
                $fp = $file.$pathCol
                if (-not $fp) { continue }
                $fp = $fp.TrimStart('/')
                if ($rootPath -and -not $fp.StartsWith("$rootPath/") -and $fp -ne $rootPath) {
                    $mi = $fp.IndexOf("$rootPath/")
                    if ($mi -gt 0 -and $fp[$mi - 1] -eq '/') { $fp = $fp.Substring($mi) }
                }
                $parentPath = $null
                foreach ($kp in $knownFolderPaths) {
                    if ($fp.StartsWith("$kp/")) { $parentPath = $kp; break }
                }
                if (-not $parentPath) {
                    $pp = $fp -split '/'
                    $parentPath = if ($pp.Count -gt 1) { ($pp[0..($pp.Count - 2)]) -join '/' } else { $fp }
                }
                if (-not $folderCounts.ContainsKey($parentPath)) { $folderCounts[$parentPath] = 0 }
                $folderCounts[$parentPath]++
            }

            # Pre-compute the set of unique permission indices from column metadata.
            # This is constant across all files so it only needs to run once.
            $permIndices = @()
            if ($permCols) {
                $permIndices = $permCols | ForEach-Object {
                    if ($_.Name -match 'permissions\.(\d+)\.') { $Matches[1] }
                } | Select-Object -Unique | Sort-Object { [int]$_ }
            }

            foreach ($file in $files) {
                # GAM's print filelist returns folder entries alongside real files.
                # Folders (mimeType = application/vnd.google-apps.folder) are structural
                # entries, not data - skip them so file counts reflect actual files only.
                if ($mimeCol -and $file.$mimeCol -eq 'application/vnd.google-apps.folder') { continue }

                $filePath = $file.$pathCol
                if (-not $filePath) { continue }

                # GAM sometimes prefixes paths with a leading slash. Trim it so
                # the resulting folder keys match the path values in FolderDetails.csv,
                # which GAM writes without a leading slash.
                $filePath = $filePath.TrimStart('/')

                # GAM may include additional parent-folder segments in file paths
                # (e.g. the shared drive folder name) that do not appear in diskusage
                # output. Strip the leading prefix so the path starts at the audit root.
                if ($rootPath -and -not $filePath.StartsWith("$rootPath/") -and $filePath -ne $rootPath) {
                    $markerIdx = $filePath.IndexOf("$rootPath/")
                    if ($markerIdx -gt 0 -and $filePath[$markerIdx - 1] -eq '/') {
                        $filePath = $filePath.Substring($markerIdx)
                    }
                }

                # Derive the containing folder path using longest-prefix matching
                # against the known folder list from FolderDetails.csv. This correctly
                # handles folder names that contain a literal '/' (e.g. "Contracts/Proposals")
                # which would be ambiguous if we simply split on '/' and dropped the last segment.
                $folderPath = $null
                foreach ($knownPath in $knownFolderPaths) {
                    if ($filePath.StartsWith("$knownPath/")) {
                        $folderPath = $knownPath
                        break
                    }
                }
                # Fallback for files not matched (e.g. FolderDetails.csv unavailable):
                # split on '/' and drop the last segment as before.
                if (-not $folderPath) {
                    $pathParts = $filePath -split "/"
                    $folderPath = if ($pathParts.Count -gt 1) {
                        ($pathParts[0..($pathParts.Count - 2)]) -join "/"
                    } else { $filePath }
                }

                # Create an entry for this folder path the first time we see it.
                if (-not $summary.ContainsKey($folderPath)) {
                    $summary[$folderPath] = [PSCustomObject]@{
                        FolderPath               = $folderPath
                        DirectFiles              = 0
                        DirectFolders            = if ($folderCounts.ContainsKey($folderPath)) { $folderCounts[$folderPath] } else { 0 }
                        ExternallyOwned          = 0
                        SharedExternally         = 0
                        SharedWithGroupsInternal = 0
                        SharedWithGroupsExternal = 0
                        SharedWithUsers          = 0
                    }
                }

                $entry = $summary[$folderPath]
                $entry.DirectFiles++

                # Check ownership: extract the domain component from the owner email
                # and compare against $InternalDomains (F-01). Substring matching
                # (e.g. -notmatch 'contoso.com') would pass 'user@notcontoso.com' as
                # internal because the domain string appears inside it.
                if ($ownerCol) {
                    $ownerEmail  = $file.$ownerCol
                    $ownerDomain = if ($ownerEmail -match '@(.+)$') { $Matches[1].ToLower() } else { '' }
                    if ($ownerDomain -and $ownerDomain -notin $InternalDomains) {
                        $entry.ExternallyOwned++
                    }
                }

                # Check permissions: group permission columns by their numeric index N
                # so that type and emailaddress for the same permission are evaluated
                # together (F-11). This allows correct internal/external group detection.
                # A file is flagged SharedExternally if any permission is:
                #   - type 'anyone' (public / anyone-with-the-link)
                #   - a user or group outside $InternalDomains
                #   - a domain grant for a domain outside $InternalDomains
                # SharedWithGroupsInternal/External are split by the group's email domain.
                $isSharedExternally     = $false
                $isSharedWithGroupInt   = $false
                $isSharedWithGroupExt   = $false
                $isSharedWithUser       = $false

                foreach ($idx in $permIndices) {
                    $type  = $file."permissions.$idx.type"
                    $email = $file."permissions.$idx.emailaddress"
                    $dom   = $file."permissions.$idx.domain"

                    if ($type -eq 'anyone') {
                        # Public or anyone-with-the-link: always external exposure.
                        $isSharedExternally = $true
                    } elseif ($type -eq 'group') {
                        if ($email) {
                            $grpDomain = if ($email -match '@(.+)$') { $Matches[1].ToLower() } else { '' }
                            if ($grpDomain -and $grpDomain -notin $InternalDomains) {
                                $isSharedWithGroupExt = $true
                                $isSharedExternally   = $true
                            } else {
                                $isSharedWithGroupInt = $true
                            }
                        } else {
                            # If group email is missing, fall back to the domain field.
                            if ($dom) {
                                if ($dom.ToLower() -notin $InternalDomains) {
                                    $isSharedWithGroupExt = $true
                                    $isSharedExternally   = $true
                                } else {
                                    $isSharedWithGroupInt = $true
                                }
                            } else {
                                $isSharedWithGroupInt = $true
                            }
                        }
                    } elseif ($type -eq 'user') {
                        $isSharedWithUser = $true
                        if ($email) {
                            $userDomain = if ($email -match '@(.+)$') { $Matches[1].ToLower() } else { '' }
                            if ($userDomain -and $userDomain -notin $InternalDomains) {
                                $isSharedExternally = $true
                            }
                        } elseif ($dom -and $dom.ToLower() -notin $InternalDomains) {
                            $isSharedExternally = $true
                        }
                    } elseif ($dom) {
                        # Domain-level grant: shared with everyone at an external domain.
                        if ($dom.ToLower() -notin $InternalDomains) {
                            $isSharedExternally = $true
                        }
                    }
                }
                if ($isSharedExternally)   { $entry.SharedExternally++ }
                if ($isSharedWithGroupInt)  { $entry.SharedWithGroupsInternal++ }
                if ($isSharedWithGroupExt)  { $entry.SharedWithGroupsExternal++ }
                if ($isSharedWithUser)      { $entry.SharedWithUsers++ }
            }

            # -- Enrich FolderDetails.csv with ownership and sharing columns ----------
            # Join the per-folder ownership/sharing counts (derived from FileDetails.csv)
            # back into FolderDetails.csv so a migration engineer has all metrics in one place.
            # Folders that contain no files get zeroes for all new columns.
            # F-09: DirectFolders uses GAM's authoritative directFolderCount rather than
            # the FileDetails-derived count, which may undercount when data is incomplete.
            # F-10: If the two counts differ, a warning is emitted so the technician knows
            # that FileDetails may be truncated or path attribution is misfiring.
            if (Test-Path $diskUsageCsv) {
                $diskRows = Import-Csv $diskUsageCsv
                $enrichedCsv = foreach ($dRow in $diskRows) {
                    $s = if ($summary.ContainsKey($dRow.path)) { $summary[$dRow.path] } else { $null }

                    # F-10: Reconcile authoritative (GAM) vs. derived (FileDetails) folder count.
                    $authFolderCount    = [int]$dRow.directFolderCount
                    $derivedFolderCount = if ($s) { $s.DirectFolders } else { 0 }
                    if ($s -and $derivedFolderCount -ne $authFolderCount) {
                        Write-Warning "  Folder count mismatch at '$($dRow.path)': GAM=$authFolderCount, derived=$derivedFolderCount. FileDetails may be incomplete."
                    }

                    $dRow | Select-Object *,
                        @{ N = 'DirectFolders';          E = { [int]$_.directFolderCount } },
                        @{ N = 'OwnedInternal';          E = { if ($s) { $s.DirectFiles - $s.ExternallyOwned } else { 0 } } },
                        @{ N = 'OwnedExternal';          E = { if ($s) { $s.ExternallyOwned } else { 0 } } },
                        @{ N = 'SharedExternal';         E = { if ($s) { $s.SharedExternally } else { 0 } } },
                        @{ N = 'SharedWithGroupsInternal'; E = { if ($s) { $s.SharedWithGroupsInternal } else { 0 } } },
                        @{ N = 'SharedWithGroupsExternal'; E = { if ($s) { $s.SharedWithGroupsExternal } else { 0 } } },
                        @{ N = 'SharedWithUsers';        E = { if ($s) { $s.SharedWithUsers } else { 0 } } }
                }
                # Reorder so 'path' is the last column - easier to read in Excel when
                # the metrics columns are adjacent to the folder name columns.
                $colOrder    = @($enrichedCsv[0].PSObject.Properties.Name | Where-Object { $_ -ne 'path' }) + 'path'
                $enrichedCsv = $enrichedCsv | Select-Object $colOrder
                $enrichedCsv | Export-Csv -Path $diskUsageCsv -NoTypeInformation -Encoding UTF8
                Write-Host "  Enriched FolderDetails.csv with ownership and sharing columns" -ForegroundColor Green
            }
            # -- Build folder tree view -------------------------------------------
            # Drive the tree from FolderDetails.csv rows so every folder is represented,
            # including empty ones. GAM's 'depth' column is used for indentation
            # so slash characters in folder names never affect the hierarchy.
            # The root folder (depth -1 per GAM) goes into the header.
            $treeLines = @()

            if (Test-Path $diskUsageCsv) {
                $diskRowsForTree = Import-Csv $diskUsageCsv |
                    Where-Object { $_.path -and $_.path -ne 'Trash' }

                # Root is depth -1 in GAM's output.
                $rootRow = $diskRowsForTree | Where-Object { [int]$_.depth -eq -1 } | Select-Object -First 1
                $rootName = if ($rootRow) { $rootRow.name } else { $FolderId }

                $rootAnnotation = ""
                if ($rootRow) {
                    $s  = if ($summary.ContainsKey($rootRow.path)) { $summary[$rootRow.path] } else { $null }
                    $rf = if ($rootRow.PSObject.Properties.Name -contains 'DirectFolders') { [int]$rootRow.DirectFolders } else { [int]$rootRow.directFolderCount }
                    $rt = if ($s) { $s.DirectFiles } else { 0 }
                    $ri = if ($s) { $s.DirectFiles - $s.ExternallyOwned } else { 0 }
                    $re = if ($s) { $s.ExternallyOwned } else { 0 }
                    $rs = if ($s) { $s.SharedExternally } else { 0 }
                    # F-15: Use same terse numeric format as child rows for consistency.
                    $rootAnnotation = "  ($rf / $rt / $ri / $re / $rs)"
                }

                $treeLines += "Google Drive Folder Ownership Tree"
                $treeLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                $treeLines += "Domain(s): $($InternalDomains -join ', ')"
                $treeLines += "Folder ID: $FolderId"
                $treeLines += "Folder:    $rootName$rootAnnotation"
                $treeLines += ""
                $treeLines += "Legend: # direct folders / # direct files / owned internal / owned external / shared external"
                $treeLines += ""

                # Children start at depth 0. Sort by full path so that children
                # appear immediately after their parent in alphabetical order;
                # depth drives indentation. Sorting by depth first (the old approach)
                # would group all depth-0 folders together then all depth-1 folders,
                # making them appear nested under the last depth-0 folder.
                foreach ($dRow in ($diskRowsForTree | Where-Object { [int]$_.depth -ge 0 } | Sort-Object path)) {
                    $d      = [int]$dRow.depth
                    $indent = "`t" * $d
                    $name   = $dRow.name

                    $s = if ($summary.ContainsKey($dRow.path)) { $summary[$dRow.path] } else { $null }
                    $folders  = if ($dRow.PSObject.Properties.Name -contains 'DirectFolders') { [int]$dRow.DirectFolders } else { [int]$dRow.directFolderCount }
                    $total    = if ($s) { $s.DirectFiles } else { 0 }
                    $internal = if ($s) { $s.DirectFiles - $s.ExternallyOwned } else { 0 }
                    $external = if ($s) { $s.ExternallyOwned } else { 0 }
                    $shared   = if ($s) { $s.SharedExternally } else { 0 }

                    $treeLines += "$indent- $name  ($folders / $total / $internal / $external / $shared)"
                }
            } else {
                # FolderDetails.csv unavailable - fall back to summary-driven tree as before.
                $treeLines += "Google Drive Folder Ownership Tree"
                $treeLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
                $treeLines += "Domain(s): $($InternalDomains -join ', ')"
                $treeLines += "Folder ID: $FolderId"
                $treeLines += ""
                $treeLines += "Legend: # direct folders / # direct files / owned internal / owned external / shared external"
                $treeLines += "(Note: FolderDetails.csv unavailable - empty folders not shown)"
                $treeLines += ""

                foreach ($row in ($summary.Values | Sort-Object FolderPath)) {
                    $trimmedPath     = $row.FolderPath.TrimStart('/')
                    $depth           = ($trimmedPath -split '/').Count - 1
                    $indent          = "`t" * $depth
                    $name            = ($trimmedPath -split '/')[-1]
                    $folders         = $row.DirectFolders
                    $total           = $row.DirectFiles
                    $internal        = $total - $row.ExternallyOwned
                    $treeLines += "$indent- $name  ($folders / $total / $internal / $($row.ExternallyOwned) / $($row.SharedExternally))"
                }
            }

            $treeLines | Out-File -FilePath $folderTreeTxt -Encoding UTF8
            Write-Host "  Saved folder tree to FolderTree.txt" -ForegroundColor Green

            # -- Build Summary.csv (depth-0 rollup) --------------------------------------
            # One row per top-level (depth 0) folder. GAM provides authoritative recursive
            # totals (TotalFiles, TotalFolders, TotalFileSizeBytes). TotalOwnedExternal and
            # TotalSharedExternal are summed from all $summary entries in the subtree so the
            # engineer can scope each group's migration risk at a glance.
            if (Test-Path $diskUsageCsv) {
                $summaryRows = @()
                $depth0Rows = $diskRowsForTree | Where-Object { [int]$_.depth -eq 0 } | Sort-Object name
                foreach ($d0Row in $depth0Rows) {
                    $groupPath      = $d0Row.path
                    $totalOwnedExt  = 0
                    $totalSharedExt = 0
                    foreach ($entry in $summary.Values) {
                        if ($entry.FolderPath -eq $groupPath -or $entry.FolderPath.StartsWith("$groupPath/")) {
                            $totalOwnedExt  += $entry.ExternallyOwned
                            $totalSharedExt += $entry.SharedExternally
                        }
                    }
                    $summaryRows += [PSCustomObject]@{
                        Group               = $d0Row.name
                        DirectFolders       = if ($d0Row.PSObject.Properties.Name -contains 'DirectFolders') { [int]$d0Row.DirectFolders } else { [int]$d0Row.directFolderCount }
                        TotalFolders        = [int]$d0Row.totalFolderCount
                        TotalFiles          = [int]$d0Row.totalFileCount
                        TotalFileSizeBytes  = [long]$d0Row.totalFileSize
                        TotalOwnedExternal  = $totalOwnedExt
                        TotalSharedExternal = $totalSharedExt
                    }
                }
                if ($summaryRows.Count -gt 0) {
                    $summaryRows | Export-Csv -Path $summaryCsv -NoTypeInformation -Encoding UTF8
                    Write-Host "  Saved $($summaryRows.Count) group summaries to Summary.csv" -ForegroundColor Green
                } else {
                    Write-Warning "  No top-level folders (depth 0) found in FolderDetails data. Summary.csv not generated."
                }
            } else {
                Write-Warning "  FolderDetails.csv unavailable - Summary.csv not generated."
                $runStatus = 'Partial'
            }

        }   # end if (-not $pathCol) ... else
        }   # end if (-not $files) ... else
    } else {
        Write-Warning "  FileDetails.csv not found - skipping external ownership/sharing analysis."
        $runStatus = 'Partial'
    }
} catch {
    Write-Error "  Summary aggregation failed: $($_.Exception.Message)"
    $runStatus = 'Partial'
}

# -- Report -------------------------------------------------------------------
Write-Host ""
# F-08: Banner reflects the actual run outcome so a partial/failed run is
# clearly distinguishable from a clean one without reading the full log.
if ($runStatus -eq 'Success') {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Audit Complete" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
} else {
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  Audit completed with warnings" -ForegroundColor Yellow
    Write-Host "  One or more steps failed or produced incomplete data." -ForegroundColor Yellow
    Write-Host "  Review the warnings above before using the output." -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Output files:" -ForegroundColor White

if (Test-Path $diskUsageCsv) {
    Write-Host "  FolderDetails.csv - Subfolder counts, file counts, and sizes per folder" -ForegroundColor Green
} else {
    Write-Host "  FolderDetails.csv - NOT GENERATED" -ForegroundColor Red
}

if (Test-Path $fileDetailCsv) {
    Write-Host "  FileDetails.csv  - Every file with owner, size, path, and permissions" -ForegroundColor Green
} else {
    Write-Host "  FileDetails.csv  - NOT GENERATED" -ForegroundColor Red
}

if (Test-Path $summaryCsv) {
    Write-Host "  Summary.csv      - Top-level folder rollup with recursive totals and cumulative ownership/sharing" -ForegroundColor Green
} else {
    Write-Host "  Summary.csv      - NOT GENERATED" -ForegroundColor Red
}

if (Test-Path $folderTreeTxt) {
    Write-Host "  FolderTree.txt   - Indented folder tree with internal/external ownership counts" -ForegroundColor Green
} else {
    Write-Host "  FolderTree.txt   - NOT GENERATED" -ForegroundColor Red
}

Write-Host ""
Write-Host "FolderDetails.csv columns (from GAM):" -ForegroundColor DarkGray
Write-Host "  directFileCount    - Files directly in the folder" -ForegroundColor DarkGray
Write-Host "  directFolderCount  - Subfolders directly in the folder" -ForegroundColor DarkGray
Write-Host "  directFileSize     - Size of files directly in the folder (bytes)" -ForegroundColor DarkGray
Write-Host "  totalFileCount     - Files in the folder and all subfolders" -ForegroundColor DarkGray
Write-Host "  totalFolderCount   - Subfolders at all levels below" -ForegroundColor DarkGray
Write-Host "  totalFileSize      - Size of all files at all levels below (bytes)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "FolderDetails.csv columns (added by this script - direct files only):" -ForegroundColor DarkGray
Write-Host "  DirectFolders      - Direct subfolders per GAM (authoritative)" -ForegroundColor DarkGray
Write-Host "  OwnedInternal      - Files owned by accounts in the internal domain(s)" -ForegroundColor DarkGray
Write-Host "  OwnedExternal      - Files owned by accounts outside the internal domain(s)" -ForegroundColor DarkGray
Write-Host "  SharedExternal     - Files shared with external users, domains, or public link" -ForegroundColor DarkGray
Write-Host "  SharedWithGroupsInternal - Files shared with at least one internal Google Group" -ForegroundColor DarkGray
Write-Host "  SharedWithGroupsExternal - Files shared with at least one external Google Group" -ForegroundColor DarkGray
Write-Host "                       (also included in SharedExternal)" -ForegroundColor DarkGray
Write-Host "  SharedWithUsers    - Files shared with at least one specific user" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Summary.csv columns (one row per top-level / depth-0 folder):" -ForegroundColor DarkGray
Write-Host "  Group               - Folder name" -ForegroundColor DarkGray
Write-Host "  DirectFolders        - Direct subfolders (immediate children)" -ForegroundColor DarkGray
Write-Host "  TotalFolders        - All subfolders at any depth (recursive)" -ForegroundColor DarkGray
Write-Host "  TotalFiles          - All files at any depth (recursive)" -ForegroundColor DarkGray
Write-Host "  TotalFileSizeBytes  - Size of all files at any depth, bytes (uploaded files only)" -ForegroundColor DarkGray
Write-Host "  TotalOwnedExternal  - Files with external owners anywhere in the subtree" -ForegroundColor DarkGray
Write-Host "  TotalSharedExternal - Files shared externally anywhere in the subtree" -ForegroundColor DarkGray
Write-Host ""
$auditTimer.Stop()
$elapsed = $auditTimer.Elapsed
Write-Host ("Total runtime: {0:00}:{1:00}:{2:00}" -f [int]$elapsed.TotalHours, $elapsed.Minutes, $elapsed.Seconds) -ForegroundColor DarkGray
Write-Host "Log saved to: $TranscriptFile" -ForegroundColor DarkGray

} finally {
    # Restore GAMCFGDIR and stop the transcript regardless of whether the script
    # completed normally or was interrupted (e.g., Ctrl+C during a long GAM query).
    # Without this, Stop-Transcript is never called on interruption, leaving the
    # transcript active in the session and causing duplicate files on the next run.
    $env:GAMCFGDIR = $originalGamCfgDir
    Stop-Transcript
}
