<#
.SYNOPSIS
    Audits Google Workspace Groups using GAM7.

.DESCRIPTION
    Generates a security-focused inventory of every Google Group in a Google
    Workspace tenant. For each group it captures:

      - Group email, display name, description
      - Group type: Security, Email (distribution list / discussion forum), or Both
        (derived from Cloud Identity labels on the group object)
      - Member, manager, and owner counts
      - Internal vs external member counts (based on the email domain of each
        member compared against the configured internal domain list)
      - Key access settings (who can join, who can post, who can view membership,
        whether external members are allowed, archive-only status)
      - Risk flags: no owners, has external members, externally postable,
        publicly joinable, external members allowed, security group with external
        members, nested group references

    Uses GAM7 (https://github.com/GAM-team/GAM) to query the Directory API
    (groups), the Cloud Identity Groups API (security labels), and the
    Groups Settings API (access controls). GAM must be installed and configured
    first - run Initialize GAM.ps1 if you have not already done so.

    Outputs three files to the specified output directory:
      1. GroupMembers.csv  - primary export: one row per (group, member) with group name,
                             group email, group type, member display name, member email,
                             role, member type, internal/external classification, and
                             (when -ExpandNestedGroups is used) the direct member group
                             the user comes through (NestedVia)
      2. Groups.csv        - one row per group: type, owner and manager email lists,
                             member counts, access settings, and risk flags
      3. Summary.txt       - human-readable risk highlights listing specific group and
                             member addresses, plus tenant-wide totals

.PARAMETER Domain
    Your Google Workspace primary domain, or a comma-separated list of all
    domains considered internal to this tenant (e.g., "contoso.com,contoso.net").
    Used to classify members as internal or external. Inferred from the selected
    config directory name when not supplied.

.PARAMETER OutputDir
    Directory where reports are saved. Defaults to a timestamped subfolder
    under the current directory. Created automatically if it does not exist.

.PARAMETER ConfigBaseDir
    Base directory containing per-customer GAM config folders (e.g., C:\GAMConfig).
    The script lists subdirectories and prompts you to choose one. Defaults to C:\GAMConfig.

.PARAMETER ConfigDir
    Full path to a specific customer GAM config directory (e.g., C:\GAMConfig\contoso.com).
    When provided, skips the workspace selection prompt and uses this directory directly.

.PARAMETER ExpandNestedGroups
    When specified, member listings recursively expand nested group memberships
    so a user who is only a member via a parent group still appears in
    GroupMembers.csv. Increases runtime on large tenants. Default off.

.PARAMETER SkipSettings
    Skip the Groups Settings API call. Speeds up the audit on large tenants
    but Groups.csv will not include access-control columns or related risk flags.

.EXAMPLE
    .\"Audit Google Groups.ps1"

    Prompts for workspace, domain, then audits every group in the tenant.

.EXAMPLE
    .\"Audit Google Groups.ps1" -Domain "contoso.com,contoso.net" -ExpandNestedGroups

    Treats both contoso.com and contoso.net as internal, expands nested groups
    when listing members.

.NOTES
    Name:       Audit Google Groups
    Author:     RTT Support
    Requires:   GAM7 installed and configured (gam on PATH)
    Context:    Technician workstation (interactive)
#>

param(
    [string]$Domain,
    [string]$OutputDir,
    [string]$ConfigBaseDir = "C:\GAMConfig",
    [string]$ConfigDir     = "",
    [switch]$ExpandNestedGroups,
    [switch]$SkipSettings
)

# -- Transcript logging -------------------------------------------------------
$TranscriptDir = Join-Path $env:USERPROFILE "Documents\GAM Logs"
if (-not (Test-Path $TranscriptDir)) { New-Item -ItemType Directory -Path $TranscriptDir -Force | Out-Null }
$TranscriptFile = Join-Path $TranscriptDir ("Audit-Groups_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))
Start-Transcript -Path $TranscriptFile -Append
Write-Host "Transcript: $TranscriptFile" -ForegroundColor DarkGray

# Save the original GAMCFGDIR so the finally block can restore it even on Ctrl+C.
$originalGamCfgDir = $env:GAMCFGDIR

# Run status: 'Success' unless any step degrades it to 'Partial'.
$runStatus = 'Success'

try {

# -- Helper: stream a GAM CSV to disk with heartbeat -------------------------
function Invoke-GamStream {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string]   $OutputCsv,
        [string] $Label = 'rows',
        [int]    $HeartbeatSeconds = 15
    )

    $partial = "$OutputCsv.partial"
    if (Test-Path $partial) { Remove-Item $partial -Force }

    $writer = [System.IO.StreamWriter]::new($partial, $false, [System.Text.UTF8Encoding]::new($false))
    $writer.AutoFlush = $true
    $rowCount      = 0
    $headerWritten = $false
    $startTime     = Get-Date
    $nextBeat      = $startTime.AddSeconds($HeartbeatSeconds)

    try {
        & gam @Arguments 2>&1 | ForEach-Object {
            $line = "$_"
            if ($line -match ',' -and $line -notmatch '^\s*User:' -and $line -notmatch '^Getting ' -and $line -notmatch '^Got ') {
                if (-not $headerWritten) {
                    $writer.WriteLine($line)
                    $headerWritten = $true
                } else {
                    $writer.WriteLine($line)
                    $rowCount++
                }
            } else {
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

    return @{ RowCount = $rowCount; ExitCode = $exitCode }
}

# -- GAM availability check ---------------------------------------------------
if (-not (Get-Command gam -ErrorAction SilentlyContinue)) {
    throw "GAM7 is not installed or not on PATH. Run '.\Initialize GAM.ps1' first to set up GAM for this workspace."
}

# -- Select customer workspace ------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($ConfigDir)) {
    $env:GAMCFGDIR = $ConfigDir
    Write-Host "Using config directory: $ConfigDir" -ForegroundColor DarkGray
} else {
    $existingWorkspaces = @()
    if (Test-Path $ConfigBaseDir) {
        $existingWorkspaces = @(
            Get-ChildItem -Path $ConfigBaseDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName "gam.cfg") } |
                Select-Object -ExpandProperty Name | Sort-Object
        )
    }

    if ($existingWorkspaces.Count -eq 0) {
        throw "No initialized customer workspaces found under: $ConfigBaseDir. Run '.\Initialize GAM.ps1' first to set up a workspace."
    }

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

# -- Resolve internal domain list --------------------------------------------
if ([string]::IsNullOrWhiteSpace($Domain) -and $ConfigDir) {
    $inferredDomain = Split-Path $ConfigDir -Leaf
    if ($inferredDomain -match '\.') {
        $domainInput = Read-Host "Enter the Google Workspace primary domain (comma-separated for multiple) [$inferredDomain]"
        $Domain = if ([string]::IsNullOrWhiteSpace($domainInput)) { $inferredDomain } else { $domainInput.Trim() }
    }
}
if ([string]::IsNullOrWhiteSpace($Domain)) {
    $Domain = Read-Host "Enter your Google Workspace primary domain (comma-separated for multiple)"
    if ([string]::IsNullOrWhiteSpace($Domain)) { throw "Domain is required." }
}

$InternalDomains = @(
    $Domain.Split(',') |
        ForEach-Object { $_.Trim().ToLower() } |
        Where-Object { $_ }
)

# -- Output directory ---------------------------------------------------------
if (-not $OutputDir) {
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $OutputDir = Join-Path $PWD "GroupAudit_$timestamp"
}
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$groupsCsv     = Join-Path $OutputDir "Groups.csv"
$membersCsv    = Join-Path $OutputDir "GroupMembers.csv"
$summaryTxt    = Join-Path $OutputDir "Summary.txt"
$rawGroupsCsv  = Join-Path $OutputDir "_raw_groups.csv"
$rawCiCsv      = Join-Path $OutputDir "_raw_cigroups.csv"
$rawSetCsv     = Join-Path $OutputDir "_raw_settings.csv"
$rawMembersCsv = Join-Path $OutputDir "_raw_members.csv"

$auditTimer = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Google Workspace Groups Audit" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Domain(s):  $($InternalDomains -join ', ')"
Write-Host "Output:     $OutputDir"
Write-Host "Settings:   $(if ($SkipSettings) { 'SKIPPED' } else { 'included' })"
Write-Host "Nested:     $(if ($ExpandNestedGroups) { 'expanded' } else { 'flat (direct members only)' })"
Write-Host ""

# -- Step 1: Inventory groups (Directory API) --------------------------------
# 'gam print groups' returns email, name, description, member/manager/owner
# counts, and aliases. Fast - one call for the entire tenant.
Write-Host "[1/4] Listing groups (Directory API)..." -ForegroundColor Yellow
$step1 = Invoke-GamStream -Arguments @(
    'print', 'groups',
    'fields', 'email,name,description,adminCreated,aliases',
    'countsonly'
) -OutputCsv $rawGroupsCsv -Label 'groups'
if ($step1.ExitCode -ne 0) {
    throw "gam print groups failed with exit code $($step1.ExitCode)."
}
Write-Host "  Found $($step1.RowCount) group(s)." -ForegroundColor Green

if ($step1.RowCount -eq 0) {
    Write-Warning "No groups found in tenant. Nothing to audit."
    return
}

# -- Step 2: Cloud Identity labels (security vs discussion forum) -------------
# Cloud Identity exposes labels on each group:
#   cloudidentity.googleapis.com/groups.discussion_forum  -> email/distribution
#   cloudidentity.googleapis.com/groups.security          -> security group
# A group with both labels is a security group that also receives email.
Write-Host ""
Write-Host "[2/4] Fetching Cloud Identity labels (security vs distribution)..." -ForegroundColor Yellow
$step2 = Invoke-GamStream -Arguments @(
    'print', 'cigroups',
    'fields', 'groupKey,labels,displayName'
) -OutputCsv $rawCiCsv -Label 'cigroups'
if ($step2.ExitCode -ne 0) {
    Write-Warning "  gam print cigroups failed (exit $($step2.ExitCode)). Group type classification will be unavailable."
    $runStatus = 'Partial'
}

# -- Step 3: Group settings (access controls) --------------------------------
if (-not $SkipSettings) {
    Write-Host ""
    Write-Host "[3/4] Fetching group settings (access controls)..." -ForegroundColor Yellow
    $step3 = Invoke-GamStream -Arguments @(
        'print', 'groups',
        'settings',
        'fields', 'email,whoCanJoin,whoCanPostMessage,whoCanViewMembership,whoCanViewGroup,allowExternalMembers,archiveOnly,isArchived,messageModerationLevel'
    ) -OutputCsv $rawSetCsv -Label 'settings'
    if ($step3.ExitCode -ne 0) {
        Write-Warning "  gam print groups settings failed (exit $($step3.ExitCode)). Access-control columns will be blank."
        $runStatus = 'Partial'
    }
} else {
    Write-Host ""
    Write-Host "[3/4] Skipping group settings (per -SkipSettings)." -ForegroundColor DarkGray
}

# -- Step 4: Membership ------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Listing group members..." -ForegroundColor Yellow
$memberArgs = @(
    'print', 'group-members',
    'fields', 'group,email,name,role,type,status'
)
if ($ExpandNestedGroups) { $memberArgs += 'recursive' }
$step4 = Invoke-GamStream -Arguments $memberArgs -OutputCsv $rawMembersCsv -Label 'memberships'
if ($step4.ExitCode -ne 0) {
    Write-Warning "  gam print group-members failed (exit $($step4.ExitCode)). Membership counts will be incomplete."
    $runStatus = 'Partial'
}

# -- Post-processing ---------------------------------------------------------
Write-Host ""
Write-Host "Aggregating and classifying..." -ForegroundColor Yellow

function Test-IsExternal {
    param([string]$EmailAddress)
    if ([string]::IsNullOrWhiteSpace($EmailAddress)) { return $false }
    if ($EmailAddress -notmatch '@(.+)$') { return $false }
    $emailDomain = $Matches[1].ToLower()
    return -not ($InternalDomains -contains $emailDomain)
}

# Load raw inputs.
$groupsRaw = if (Test-Path $rawGroupsCsv) { @(Import-Csv $rawGroupsCsv) } else { @() }
$ciRaw     = if (Test-Path $rawCiCsv)     { @(Import-Csv $rawCiCsv) }     else { @() }
$setRaw    = if (Test-Path $rawSetCsv)    { @(Import-Csv $rawSetCsv) }    else { @() }
$memRaw    = if (Test-Path $rawMembersCsv){ @(Import-Csv $rawMembersCsv) } else { @() }

# Index settings by group email for fast lookup.
$settingsByEmail = @{}
foreach ($s in $setRaw) {
    if ($s.email) { $settingsByEmail[$s.email.ToLower()] = $s }
}

# Index Cloud Identity labels by group email. The labels column is a
# semicolon-separated list of label keys (GAM serializes them this way).
$labelsByEmail = @{}
foreach ($c in $ciRaw) {
    # GAM7 typically exposes the email at groupKey.id.
    $emailProp = $c.PSObject.Properties | Where-Object { $_.Name -match 'groupKey\.id|email' } | Select-Object -First 1
    if (-not $emailProp) { continue }
    $email = "$($emailProp.Value)".ToLower()
    if (-not $email) { continue }
    $labelsField = $c.PSObject.Properties | Where-Object { $_.Name -match 'labels' } | Select-Object -First 1
    $labelsByEmail[$email] = if ($labelsField) { "$($labelsField.Value)" } else { '' }
}

function Get-GroupType {
    param([string]$EmailLower)
    $labels = $labelsByEmail[$EmailLower]
    if (-not $labels) { return 'Unknown' }
    $isSecurity = $labels -match 'groups\.security'
    $isForum    = $labels -match 'groups\.discussion_forum'
    if ($isSecurity -and $isForum) { return 'Both' }
    if ($isSecurity)               { return 'Security' }
    if ($isForum)                  { return 'Email' }
    return 'Unknown'
}

# Aggregate membership per group.
$membersByGroup = @{}
foreach ($m in $memRaw) {
    $g = "$($m.group)".ToLower()
    if (-not $g) { continue }
    if (-not $membersByGroup.ContainsKey($g)) { $membersByGroup[$g] = New-Object System.Collections.ArrayList }
    [void]$membersByGroup[$g].Add($m)
}

# Build a fast lookup from group email -> group name for use in GroupMembers enrichment.
$groupNameByEmail = @{}
$groupTypeByEmail = @{}
foreach ($g in $groupsRaw) {
    $el = "$($g.email)".ToLower()
    $groupNameByEmail[$el] = $g.name
    $groupTypeByEmail[$el] = Get-GroupType -EmailLower $el
}

# -- Build Groups.csv --------------------------------------------------------
$groupRows = foreach ($g in $groupsRaw) {
    $emailLower = "$($g.email)".ToLower()
    $members    = if ($membersByGroup.ContainsKey($emailLower)) { @($membersByGroup[$emailLower]) } else { @() }

    $owners    = @($members | Where-Object { $_.role -eq 'OWNER' })
    $managers  = @($members | Where-Object { $_.role -eq 'MANAGER' })
    $regular   = @($members | Where-Object { $_.role -eq 'MEMBER' })
    $userMems  = @($members | Where-Object { $_.type -eq 'USER' })
    $groupMems = @($members | Where-Object { $_.type -eq 'GROUP' })
    $svcMems   = @($members | Where-Object { $_.type -eq 'SERVICE_ACCOUNT' })

    $external  = @($members | Where-Object { (Test-IsExternal $_.email) -and $_.type -ne 'CUSTOMER' })
    $internal  = @($members | Where-Object { -not (Test-IsExternal $_.email) -and $_.type -ne 'CUSTOMER' })
    $extOwners = @($owners   | Where-Object { Test-IsExternal $_.email })

    $groupType = Get-GroupType -EmailLower $emailLower
    $settings  = $settingsByEmail[$emailLower]

    $whoCanJoin           = if ($settings) { $settings.whoCanJoin }           else { '' }
    $whoCanPostMessage    = if ($settings) { $settings.whoCanPostMessage }    else { '' }
    $whoCanViewMembership = if ($settings) { $settings.whoCanViewMembership } else { '' }
    $whoCanViewGroup      = if ($settings) { $settings.whoCanViewGroup }      else { '' }
    $allowExternalMembers = if ($settings) { $settings.allowExternalMembers } else { '' }
    $archiveOnly          = if ($settings) { $settings.archiveOnly }          else { '' }
    $isArchived           = if ($settings) { $settings.isArchived }           else { '' }
    $messageModeration    = if ($settings) { $settings.messageModerationLevel } else { '' }

    # Risk flags - true / false strings for easy filtering in Excel.
    $riskNoOwners       = ($owners.Count -eq 0)
    $riskHasExternal    = ($external.Count -gt 0)
    $riskExtOwners      = ($extOwners.Count -gt 0)
    $riskPublicJoin     = ($whoCanJoin -eq 'ANYONE_CAN_JOIN')
    $riskPublicPost     = ($whoCanPostMessage -in @('ANYONE_CAN_POST', 'ALL_IN_DOMAIN_CAN_POST'))
    $riskExtAllowed     = ($allowExternalMembers -eq 'true' -or $allowExternalMembers -eq 'True')
    $riskSecurityWithExt = (($groupType -eq 'Security' -or $groupType -eq 'Both') -and $external.Count -gt 0)
    $riskNested          = ($groupMems.Count -gt 0)

    $ownerEmails   = ($owners   | ForEach-Object { $_.email }) -join '; '
    $managerEmails = ($managers | ForEach-Object { $_.email }) -join '; '
    $externalEmails = ($external | ForEach-Object { $_.email }) -join '; '

    [PSCustomObject]@{
        Email                    = $g.email
        Name                     = $g.name
        Description              = $g.description
        Type                     = $groupType
        AdminCreated             = $g.adminCreated
        Aliases                  = $g.aliases
        OwnerEmails              = $ownerEmails
        ManagerEmails            = $managerEmails
        ExternalMemberEmails     = $externalEmails
        TotalMembers             = $members.Count
        Owners                   = $owners.Count
        Managers                 = $managers.Count
        Members                  = $regular.Count
        UserMembers              = $userMems.Count
        GroupMembers             = $groupMems.Count
        ServiceAccountMembers    = $svcMems.Count
        InternalMembers          = $internal.Count
        ExternalMembers          = $external.Count
        ExternalOwners           = $extOwners.Count
        WhoCanJoin               = $whoCanJoin
        WhoCanPostMessage        = $whoCanPostMessage
        WhoCanViewMembership     = $whoCanViewMembership
        WhoCanViewGroup          = $whoCanViewGroup
        AllowExternalMembers     = $allowExternalMembers
        ArchiveOnly              = $archiveOnly
        IsArchived               = $isArchived
        MessageModerationLevel   = $messageModeration
        Risk_NoOwners            = $riskNoOwners
        Risk_HasExternalMembers  = $riskHasExternal
        Risk_ExternalOwners      = $riskExtOwners
        Risk_PublicJoin          = $riskPublicJoin
        Risk_PublicPost          = $riskPublicPost
        Risk_ExternalsAllowed    = $riskExtAllowed
        Risk_SecurityWithExternal = $riskSecurityWithExt
        Risk_HasNestedGroups     = $riskNested
    }
}

$groupRows | Export-Csv -Path $groupsCsv -NoTypeInformation -Encoding UTF8
Write-Host "  Wrote $($groupRows.Count) rows to Groups.csv" -ForegroundColor Green

# -- Build GroupMembers.csv --------------------------------------------------
# This is the primary export the vCIO asked for: one row per (group, member)
# with all identifying information present so the CSV stands on its own without
# requiring a join to Groups.csv.
$memberRows = foreach ($m in $memRaw) {
    $isExternal  = Test-IsExternal $m.email
    $groupEl     = "$($m.group)".ToLower()
    $groupName   = if ($groupNameByEmail.ContainsKey($groupEl)) { $groupNameByEmail[$groupEl] } else { '' }
    $groupType   = if ($groupTypeByEmail.ContainsKey($groupEl)) { $groupTypeByEmail[$groupEl] } else { 'Unknown' }
    # When -ExpandNestedGroups is used, GAM adds a 'subGroupEmail' column identifying
    # the direct-member group through which this user is transitively included.
    $nestedVia   = if ($m.PSObject.Properties['subGroupEmail']) { $m.subGroupEmail } else { '' }
    [PSCustomObject]@{
        GroupName  = $groupName
        GroupEmail = $m.group
        GroupType  = $groupType
        MemberName = $m.name
        MemberEmail = $m.email
        Role       = $m.role
        MemberType = $m.type
        Status     = $m.status
        Internal   = (-not $isExternal)
        External   = $isExternal
        NestedVia  = $nestedVia
    }
}
$memberRows | Export-Csv -Path $membersCsv -NoTypeInformation -Encoding UTF8
Write-Host "  Wrote $($memberRows.Count) rows to GroupMembers.csv" -ForegroundColor Green

# -- Build Summary.txt -------------------------------------------------------
$summary = @()
$summary += "Google Workspace Groups Audit"
$summary += "Generated:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summary += "Domain(s):   $($InternalDomains -join ', ')"
$summary += "Workspace:   $(Split-Path $ConfigDir -Leaf)"
$summary += ""
$summary += "Totals"
$summary += "------"
$summary += "Groups:                  $($groupRows.Count)"
$summary += "  Security only:         $(@($groupRows | Where-Object { $_.Type -eq 'Security' }).Count)"
$summary += "  Email only:            $(@($groupRows | Where-Object { $_.Type -eq 'Email' }).Count)"
$summary += "  Security + Email:      $(@($groupRows | Where-Object { $_.Type -eq 'Both' }).Count)"
$summary += "  Unknown / unlabeled:   $(@($groupRows | Where-Object { $_.Type -eq 'Unknown' }).Count)"
$summary += "Memberships (rows):      $($memberRows.Count)"
$summary += "  Internal:              $(@($memberRows | Where-Object { $_.Internal }).Count)"
$summary += "  External:              $(@($memberRows | Where-Object { $_.External }).Count)"
$summary += ""
$summary += "Risk Highlights"
$summary += "---------------"

# Add-RiskSection: list groups by email + type.
function Add-RiskSection {
    param([string]$Title, [object[]]$Rows)
    $lines = @()
    $lines += ""
    $lines += "$Title ($($Rows.Count))"
    $lines += ('-' * ($Title.Length + 4 + ([string]$Rows.Count).Length))
    if ($Rows.Count -eq 0) {
        $lines += "  (none)"
    } else {
        foreach ($r in ($Rows | Sort-Object Name | Select-Object -First 50)) {
            $line = "  $($r.Name)"
            if ($r.Email -ne $r.Name) { $line += " <$($r.Email)>" }
            $line += "  [$($r.Type)]"
            $lines += $line
        }
        if ($Rows.Count -gt 50) {
            $lines += "  ... and $($Rows.Count - 50) more (see Groups.csv)"
        }
    }
    return $lines
}

# Add-ExternalMemberSection: list specific external member emails per group.
function Add-ExternalMemberSection {
    param([string]$Title, [object[]]$GroupRows, [object[]]$AllMemberRows)
    $lines = @()
    $extRows = @($GroupRows | Where-Object { $_.Risk_HasExternalMembers })
    $lines += ""
    $lines += "$Title ($($extRows.Count) groups)"
    $lines += ('-' * ($Title.Length + 12 + ([string]$extRows.Count).Length))
    if ($extRows.Count -eq 0) {
        $lines += "  (none)"
    } else {
        foreach ($gr in ($extRows | Sort-Object Name | Select-Object -First 30)) {
            $extMembers = @($AllMemberRows | Where-Object { $_.GroupEmail -eq $gr.Email -and $_.External })
            $lines += "  $($gr.Name) <$($gr.Email)>  [$($gr.Type)]"
            foreach ($em in ($extMembers | Sort-Object MemberEmail)) {
                $nameLabel = if ($em.MemberName) { " ($($em.MemberName))" } else { '' }
                $nestedLabel = if ($em.NestedVia) { "  [nested via $($em.NestedVia)]" } else { '' }
                $lines += ("    - {0}{1}  {2}{3}" -f $em.MemberEmail, $nameLabel, $em.Role, $nestedLabel)
            }
        }
        if ($extRows.Count -gt 30) {
            $lines += "  ... and $($extRows.Count - 30) more groups (see GroupMembers.csv, filter External=True)"
        }
    }
    return $lines
}

$summary += Add-RiskSection "Groups with no owners" @($groupRows | Where-Object { $_.Risk_NoOwners })
$summary += Add-ExternalMemberSection "Groups with external members" $groupRows $memberRows
$summary += Add-RiskSection "Groups with external owners" @($groupRows | Where-Object { $_.Risk_ExternalOwners })
$summary += Add-RiskSection "Security groups containing external members" @($groupRows | Where-Object { $_.Risk_SecurityWithExternal })
$summary += Add-RiskSection "Groups joinable by anyone (ANYONE_CAN_JOIN)" @($groupRows | Where-Object { $_.Risk_PublicJoin })
$summary += Add-RiskSection "Groups postable by anyone or all-in-domain" @($groupRows | Where-Object { $_.Risk_PublicPost })
$summary += Add-RiskSection "Groups with allowExternalMembers = true" @($groupRows | Where-Object { $_.Risk_ExternalsAllowed })
$summary += Add-RiskSection "Groups containing nested groups" @($groupRows | Where-Object { $_.Risk_HasNestedGroups })

$summary | Out-File -FilePath $summaryTxt -Encoding UTF8
Write-Host "  Wrote Summary.txt" -ForegroundColor Green

# -- Cleanup intermediate files ----------------------------------------------
foreach ($tmp in @($rawGroupsCsv, $rawCiCsv, $rawSetCsv, $rawMembersCsv)) {
    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

# -- Report ------------------------------------------------------------------
Write-Host ""
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
if (Test-Path $membersCsv) { Write-Host "  GroupMembers.csv  - Primary export: Group Name, Group Email, Group Type, Member Name, Member Email, Role, Internal/External, NestedVia" -ForegroundColor Green }
if (Test-Path $groupsCsv)  { Write-Host "  Groups.csv        - One row per group: type, owner/manager emails, member counts, access settings, risk flags" -ForegroundColor Green }
if (Test-Path $summaryTxt) { Write-Host "  Summary.txt       - Risk highlights with specific member addresses, plus tenant-wide totals" -ForegroundColor Green }
Write-Host ""

$auditTimer.Stop()
$elapsed = $auditTimer.Elapsed
Write-Host ("Total runtime: {0:00}:{1:00}:{2:00}" -f [int]$elapsed.TotalHours, $elapsed.Minutes, $elapsed.Seconds) -ForegroundColor DarkGray
Write-Host "Log saved to: $TranscriptFile" -ForegroundColor DarkGray

} finally {
    $env:GAMCFGDIR = $originalGamCfgDir
    Stop-Transcript
}
