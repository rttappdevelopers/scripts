#Requires -Version 7
<#
.SYNOPSIS
    Generates a merged Microsoft 365 user activity report covering licenses,
    sign-in activity, mailbox usage, OneDrive storage, and MFA status.

.DESCRIPTION
    Connects to Microsoft Graph and pulls four pre-built tenant-level reports,
    then joins them by UserPrincipalName into a single CSV. Uses only the
    Microsoft.Graph.Authentication module and Invoke-MgGraphRequest (REST),
    avoiding the heavy autorest-based Graph SDK submodules entirely.

    Reports consumed:
      - getOffice365ActiveUserDetail  (licenses, last activity dates)
      - getMailboxUsageDetail         (mailbox size, item count)
      - getOneDriveUsageAccountDetail (OneDrive storage)
      - userRegistrationDetails       (MFA registration status)

    Report data may be up to 48 hours behind real-time. The report freshness
    date is included in the output.

.PARAMETER OutputPath
    Path for the merged CSV report. Defaults to M365_User_Report.csv in the
    script directory.

.PARAMETER ReportPeriod
    Graph reporting period. Valid values: D7, D30, D90, D180. Default: D180.

.EXAMPLE
    .\Get Mailbox Usage.ps1
    Generates the default report in the script directory.

.EXAMPLE
    .\Get Mailbox Usage.ps1 -OutputPath "C:\Reports\Contoso.csv" -ReportPeriod D30
    Generates a 30-day report at the specified path.

.NOTES
    Name:    Get Mailbox Usage
    Author:  Brad Brown, with the help of GitHub Copilot
    Date:    2025-06-27
    Version: 3.0 - Rewritten to use bulk Graph report APIs

.PERMISSIONS
    - Reports.Read.All   (delegated)
    - AuditLog.Read.All  (delegated)
    The signed-in user must hold at least the Reports Reader role.
#>

param(
    [string]$OutputPath   = "$PSScriptRoot\M365_User_Report.csv",
    [ValidateSet('D7','D30','D90','D180')]
    [string]$ReportPeriod = 'D180'
)

$ErrorActionPreference = 'Stop'

# --- Module check ---
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host "Installing Microsoft.Graph.Authentication..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Write-Host "Microsoft.Graph.Authentication loaded." -ForegroundColor Green

# --- Connect ---
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes 'Reports.Read.All', 'AuditLog.Read.All' -NoWelcome
    Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
}
catch {
    throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
}

# --- Helper: download a Graph report CSV and return parsed objects ---
function Get-GraphReportCsv {
    param([string]$Uri)
    $tempFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.csv'
    try {
        Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputFilePath $tempFile
        Import-Csv $tempFile
    }
    finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
}

# --- Helper: page through a Graph JSON collection ---
function Get-GraphJsonAll {
    param([string]$Uri)
    $results = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    while ($nextLink) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
        if ($response.value) { $results.AddRange($response.value) }
        $nextLink = $response.'@odata.nextLink'
    }
    $results
}

# --- Pull reports ---
Write-Host "Downloading Office 365 Active User Detail..." -ForegroundColor Cyan
$activeUsers = Get-GraphReportCsv -Uri "/v1.0/reports/getOffice365ActiveUserDetail(period='$ReportPeriod')"
Write-Host "  $($activeUsers.Count) records." -ForegroundColor Gray

Write-Host "Downloading Mailbox Usage Detail..." -ForegroundColor Cyan
$mailbox = Get-GraphReportCsv -Uri "/v1.0/reports/getMailboxUsageDetail(period='$ReportPeriod')"
Write-Host "  $($mailbox.Count) records." -ForegroundColor Gray

Write-Host "Downloading OneDrive Usage Detail..." -ForegroundColor Cyan
$onedrive = Get-GraphReportCsv -Uri "/v1.0/reports/getOneDriveUsageAccountDetail(period='$ReportPeriod')"
Write-Host "  $($onedrive.Count) records." -ForegroundColor Gray

Write-Host "Downloading MFA Registration Details..." -ForegroundColor Cyan
$mfa = Get-GraphJsonAll -Uri '/v1.0/reports/authenticationMethods/userRegistrationDetails'
Write-Host "  $($mfa.Count) records." -ForegroundColor Gray

# --- Index by UPN for joining ---
$mailboxByUpn  = @{}
foreach ($m in $mailbox)  { if ($m.'User Principal Name') { $mailboxByUpn[$m.'User Principal Name']  = $m } }

$onedriveByUpn = @{}
foreach ($o in $onedrive) { if ($o.'Owner Principal Name') { $onedriveByUpn[$o.'Owner Principal Name'] = $o } }

$mfaByUpn      = @{}
foreach ($r in $mfa)      { if ($r.userPrincipalName) { $mfaByUpn[$r.userPrincipalName] = $r } }

# --- Merge and export ---
Write-Host "Merging reports..." -ForegroundColor Cyan

$activeUsers | ForEach-Object {
    $upn = $_.'User Principal Name'
    $mb  = $mailboxByUpn[$upn]
    $od  = $onedriveByUpn[$upn]
    $mr  = $mfaByUpn[$upn]

    # Mailbox size: convert bytes to GB
    $mailboxSizeGB = ''
    if ($mb.'Storage Used (Byte)' -and $mb.'Storage Used (Byte)' -ne '') {
        $mailboxSizeGB = [math]::Round([long]$mb.'Storage Used (Byte)' / 1GB, 2)
    }

    $onedriveSizeGB = ''
    if ($od.'Storage Used (Byte)' -and $od.'Storage Used (Byte)' -ne '') {
        $onedriveSizeGB = [math]::Round([long]$od.'Storage Used (Byte)' / 1GB, 2)
    }

    [PSCustomObject]@{
        ReportRefreshDate      = $_.'Report Refresh Date'
        UserPrincipalName      = $upn
        DisplayName            = $_.'Display Name'
        IsDeleted              = $_.'Is Deleted'
        AssignedProducts       = $_.'Assigned Products'
        ExchangeLastActivity   = $_.'Exchange Last Activity Date'
        OneDriveLastActivity   = $_.'OneDrive Last Activity Date'
        SharePointLastActivity = $_.'SharePoint Last Activity Date'
        TeamsLastActivity      = $_.'Teams Last Activity Date'
        MailboxCreatedDate     = $mb.'Created Date'
        MailboxLastActivity    = $mb.'Last Activity Date'
        MailboxItemCount       = $mb.'Item Count'
        MailboxSizeGB          = $mailboxSizeGB
        MailboxHasArchive      = $mb.'Has Archive'
        OneDriveSizeGB         = $onedriveSizeGB
        OneDriveFileCount      = $od.'File Count'
        MFACapable             = $mr.isMfaCapable
        MFARegistered          = $mr.isMfaRegistered
        MFAMethodsRegistered   = if ($mr.methodsRegistered) { $mr.methodsRegistered -join '; ' } else { '' }
    }
} | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

$count = ($activeUsers | Measure-Object).Count
Write-Host "Report exported to '$OutputPath' ($count users)." -ForegroundColor Green

# --- Disconnect ---
try { Disconnect-MgGraph | Out-Null } catch {}
Write-Host "Done." -ForegroundColor Green
