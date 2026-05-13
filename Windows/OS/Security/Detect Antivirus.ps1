#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Detects installed and active antivirus products on Windows.

.DESCRIPTION
    Uses a tiered detection approach:

      Tier 1 - Windows Security Center (root\SecurityCenter2 WMI namespace).
               Available on Windows 10/11 workstations. Not available on
               Windows Server editions. Products are decoded from the packed
               productState field.

      Tier 2 - Service-based detection for known AV/EDR products. Used on
               Windows Server where WSC is unavailable, and as a supplementary
               check on workstations when WSC returns no active products.

      Tier 3 - Windows Defender / Microsoft Defender Antivirus fallback.
               If no third-party AV is found active, checks for the presence
               of the WinDefend service before querying Get-MpComputerStatus.
               Reports "None detected" on systems where Defender is not
               installed (e.g. Server 2012 R2 without MDE agent). Works on
               both client and server editions where Defender is present.

    The result string is written to a NinjaOne custom device field and printed
    to stdout for NinjaOne activity log capture.

.NOTES
    Designed for NinjaOne RMM deployment at SYSTEM level. Also runs directly
    with Administrator rights.

    Works on Windows 10/11 workstations and Windows Server 2012 R2 and later.
    Windows Security Center is not available on Server editions; the script
    falls back to service-based detection automatically.

    Supported products (service-based tier):
      BitDefender GravityZone, BitDefender Total Security,
      Sophos Endpoint, CrowdStrike Falcon, SentinelOne,
      Microsoft Defender for Endpoint (MDE / Sense sensor),
      Malwarebytes, ESET, Webroot SecureAnywhere,
      Norton / Symantec Endpoint Protection, McAfee / Trellix,
      Trend Micro, Avast, AVG, Kaspersky,
      Carbon Black, Cylance, Cortex XDR, WithSecure (F-Secure),
      Avira, Comodo Internet Security, Panda Dome, Emsisoft, 360 Total Security

    Environment Variables (NinjaOne / RMM):
      NINJA_FIELD_NAME - (optional) Custom field name to write the result into.
                         Defaults to "installedAntivirus".

.EXAMPLE
    .\Detect Antivirus.ps1
#>

param()

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
$NinjaFieldName = if ($env:NINJA_FIELD_NAME) { $env:NINJA_FIELD_NAME } else { 'installedAntivirus' }

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warn', 'Error')]
        [string]$Level = 'Info'
    )
    $prefix = switch ($Level) {
        'Info'    { '[INFO]   ' }
        'Success' { '[SUCCESS]' }
        'Warn'    { '[WARN]   ' }
        'Error'   { '[ERROR]  ' }
    }
    if ($Level -eq 'Error') {
        [Console]::Error.WriteLine("$prefix $Message")
    } else {
        Write-Host "$prefix $Message"
    }
}

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# Decode the packed Windows Security Center productState value.
# Returns $true if the scanner is enabled/active.
# The value is a 24-bit integer; hex digits 2-3 (0-indexed, left-padded to 6)
# encode scanner state: '10' = enabled, '01' = disabled.
function Get-WSCProductActive {
    param([uint32]$ProductState)
    $hex = '{0:X6}' -f $ProductState
    return $hex.Substring(2, 2) -eq '10'
}

# Check a list of service names and return the status of the first one found,
# or $null if none of the services are installed.
function Get-ServiceStatus {
    param([string[]]$ServiceNames)
    foreach ($name in $ServiceNames) {
        try {
            $svc = Get-Service -Name $name -ErrorAction Stop
            return $svc.Status.ToString()
        } catch {
            # Service not found - try next name
        }
    }
    return $null
}

# ==============================================================================
# Known AV / EDR service map (Tier 2 - server / supplementary detection)
# Each entry maps a friendly product name to one or more Windows service names.
# The first service found determines installed/running status.
# ==============================================================================
$avServiceMap = @(
    [PSCustomObject]@{ Name = 'BitDefender GravityZone';               Services = @('EPSecurityService', 'EPIntegrationService', 'bdservicehost') }
    [PSCustomObject]@{ Name = 'BitDefender Total Security';            Services = @('vsserv', 'updatesrv') }
    [PSCustomObject]@{ Name = 'Sophos Endpoint';                       Services = @('SophosService', 'SAVService', 'swi_service', 'SophosMcsAgent') }
    [PSCustomObject]@{ Name = 'CrowdStrike Falcon';                    Services = @('CSFalconService') }
    [PSCustomObject]@{ Name = 'SentinelOne';                           Services = @('SentinelAgent', 'SentinelStaticEngineScanner') }
    [PSCustomObject]@{ Name = 'Microsoft Defender for Endpoint';       Services = @('Sense') }
    [PSCustomObject]@{ Name = 'Malwarebytes';                          Services = @('MBAMService', 'MalwarebytesService') }
    [PSCustomObject]@{ Name = 'ESET';                                  Services = @('ekrn', 'EraAgentSvc') }
    [PSCustomObject]@{ Name = 'Webroot SecureAnywhere';                Services = @('WRSVC') }
    [PSCustomObject]@{ Name = 'Norton / Symantec Endpoint Protection'; Services = @('SepMasterService', 'ccEvtMgr') }
    [PSCustomObject]@{ Name = 'McAfee / Trellix Endpoint Security';    Services = @('mfemms', 'McAfeeFramework', 'TrellixEndpointSecurityHelper') }
    [PSCustomObject]@{ Name = 'Trend Micro';                           Services = @('ntrtscan', 'TmListen', 'TMiACAgentSvc') }
    [PSCustomObject]@{ Name = 'Avast Security';                        Services = @('AvastSvc') }
    [PSCustomObject]@{ Name = 'AVG AntiVirus';                         Services = @('AVGSvc') }
    [PSCustomObject]@{ Name = 'Kaspersky';                             Services = @('AVP', 'klnagent') }
    [PSCustomObject]@{ Name = 'Carbon Black';                          Services = @('CbDefense', 'CarbonBlack') }
    [PSCustomObject]@{ Name = 'Cylance';                               Services = @('CylanceSvc') }
    [PSCustomObject]@{ Name = 'Cortex XDR';                            Services = @('CyveraService', 'Traps Management Service') }
    [PSCustomObject]@{ Name = 'WithSecure (F-Secure)';                 Services = @('FSMA', 'fsorsp') }
    [PSCustomObject]@{ Name = 'Avira';                                 Services = @('AntivirService', 'Avira.ServiceHost') }
    [PSCustomObject]@{ Name = 'Comodo Internet Security';              Services = @('cmdagent', 'CmdVirth') }
    [PSCustomObject]@{ Name = 'Panda Dome';                            Services = @('PSANToManager', 'NanoServiceMain') }
    [PSCustomObject]@{ Name = 'Emsisoft';                              Services = @('a2service') }
    [PSCustomObject]@{ Name = '360 Total Security';                    Services = @('ZhuDongFangYu') }
)

# ==============================================================================
# Main
# ==============================================================================
try {
    $activeProducts    = New-Object 'System.Collections.Generic.List[string]'
    $installedProducts = New-Object 'System.Collections.Generic.List[string]'
    $wscUsed = $false

    # --------------------------------------------------------------------------
    # TIER 1 - Windows Security Center (workstations only)
    # --------------------------------------------------------------------------
    Write-Log 'Attempting Windows Security Center (WSC) detection...'
    try {
        $wscProducts = Get-CimInstance -Namespace 'root\SecurityCenter2' `
            -ClassName 'AntiVirusProduct' -ErrorAction Stop

        $wscUsed = $true
        Write-Log "WSC returned $($wscProducts.Count) registered AV product(s)."

        foreach ($product in $wscProducts) {
            $name = $product.displayName

            # Skip built-in Defender - handled in the fallback tier
            if ($name -match 'Windows Defender|Microsoft Defender Antivirus') { continue }

            if (Get-WSCProductActive -ProductState ([uint32]$product.productState)) {
                $activeProducts.Add($name)
                $installedProducts.Add("$name (Active)")
            } else {
                $installedProducts.Add("$name (Installed, Inactive)")
            }
        }
    } catch {
        Write-Log 'WSC not available (likely Server edition). Using service-based detection.' 'Warn'
    }

    # --------------------------------------------------------------------------
    # TIER 2 - Service-based detection
    # Runs on servers (no WSC), or on workstations where WSC found no active AV.
    # --------------------------------------------------------------------------
    if (-not $wscUsed -or $activeProducts.Count -eq 0) {
        Write-Log 'Running service-based AV detection...'

        foreach ($entry in $avServiceMap) {
            $status = Get-ServiceStatus -ServiceNames $entry.Services
            if ($null -eq $status) { continue }

            if ($status -eq 'Running') {
                $activeProducts.Add($entry.Name)
                $installedProducts.Add("$($entry.Name) (Active)")
            } else {
                $installedProducts.Add("$($entry.Name) (Installed, $status)")
            }
        }
    }

    # --------------------------------------------------------------------------
    # TIER 3 - Windows Defender fallback
    # Reports real-time protection state, running mode, and signature freshness.
    # --------------------------------------------------------------------------
    $result = ''

    if ($activeProducts.Count -gt 0) {
        $result = $activeProducts -join ', '
    } else {
        Write-Log 'No active third-party antivirus detected. Checking Windows Defender...'

        # Check whether Windows Defender is installed at all before querying it.
        # On Server 2012 R2 (and earlier), Defender is not present unless the
        # Microsoft Defender for Endpoint agent has been deployed separately.
        # The WinDefend service is the reliable presence indicator.
        $defenderInstalled = $null -ne (Get-Service -Name 'WinDefend' -ErrorAction SilentlyContinue)

        if (-not $defenderInstalled) {
            $result = 'None detected'
            Write-Log 'Windows Defender service (WinDefend) not found - no AV product detected.' 'Warn'
        } else {
            try {
                $mpStatus = Get-MpComputerStatus -ErrorAction Stop

                $sigVersion = $mpStatus.AntivirusSignatureVersion
                $sigDate    = $mpStatus.AntivirusSignatureLastUpdated.ToString('yyyy-MM-dd')
                $runMode    = $mpStatus.AMRunningMode

                if (-not $mpStatus.AntivirusEnabled) {
                    $result = 'Windows Defender (Disabled)'
                } elseif ($runMode -in @('Passive', 'SxS Passive Mode')) {
                    # Passive mode means another AV is primary but was not identified
                    $result = "Windows Defender (Passive - primary AV not identified, Sigs: v$sigVersion, updated $sigDate)"
                } else {
                    $rtpState = if ($mpStatus.RealTimeProtectionEnabled) { 'Enabled' } else { 'Disabled' }
                    $result   = "Windows Defender (Real-time: $rtpState, Mode: $runMode, Sigs: v$sigVersion, updated $sigDate)"
                }
            } catch {
                $result = 'Windows Defender (status unknown)'
                Write-Log "Could not query Windows Defender status: $($_.Exception.Message)" 'Warn'
            }
        }
    }

    # --------------------------------------------------------------------------
    # Output summary
    # --------------------------------------------------------------------------
    Write-Host ''
    Write-Host '============================================================'
    Write-Host 'Antivirus Detection'
    Write-Host '============================================================'
    if ($installedProducts.Count -gt 0) {
        Write-Host 'Detected products:'
        foreach ($p in $installedProducts) {
            Write-Host "  - $p"
        }
    } else {
        Write-Host 'No third-party antivirus or EDR products detected.'
    }
    Write-Host '------------------------------------------------------------'
    Write-Host "Reported value: $result"
    Write-Host '============================================================'

    # --------------------------------------------------------------------------
    # Write to NinjaOne custom field
    # --------------------------------------------------------------------------
    if ($NinjaFieldName) {
        try {
            Set-NinjaProperty -Name $NinjaFieldName -Value $result
            Write-Log "Wrote '$result' to Ninja field '$NinjaFieldName'." 'Success'
        } catch {
            Write-Log "Could not write to Ninja field '$NinjaFieldName': $($_.Exception.Message)" 'Warn'
        }
    }

} catch {
    Write-Log "Unhandled error: $($_.Exception.Message)" 'Error'
    if ($NinjaFieldName) {
        try { Set-NinjaProperty -Name $NinjaFieldName -Value 'Failed audit' } catch {}
    }
    exit 1
}

exit 0
