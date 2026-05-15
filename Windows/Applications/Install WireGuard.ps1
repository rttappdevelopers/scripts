<#
.SYNOPSIS
    Installs WireGuard VPN client on a Windows endpoint and configures it for
    limited non-admin use.

.DESCRIPTION
    Installs WireGuard via winget (WireGuard.WireGuard). If winget is unavailable or
    fails, falls back to downloading and silently installing the latest architecture-
    appropriate MSI from https://download.wireguard.com/windows-client/.

    After installation, the script:
    - Sets HKLM\Software\WireGuard\LimitedOperatorUI = 1, which causes WireGuard to
      display its tray UI to members of the "Network Configuration Operators" group.
      Those users can start and stop tunnels but cannot view private/public/preshared
      keys, add, edit, remove, import, or export configurations, or quit the manager.
    - Adds the built-in Users group to "Network Configuration Operators", granting
      all present and future users on the machine access to WireGuard tunnel management.
    - Optionally reads a WireGuard tunnel config from a NinjaOne organization custom
      field, writes it securely to C:\ProgramData\WireGuard\wg0.conf, and registers
      it as a managed tunnel service available in the WireGuard UI.

    WARNING: Installation and tunnel registration install a kernel-level network
    driver and briefly reset the network stack. Expect a short interruption to
    network connectivity (typically a few seconds). Schedule this deployment
    outside business hours or during a maintenance window when possible.

.PARAMETER WireGuardConfig
    Full contents of a WireGuard tunnel config file (INI/conf format). When provided,
    the config is saved and registered as the 'wg0' tunnel. Can also be set via the
    'wireguardConfig' Ninja environment variable (map a multi-line text organization
    custom field so it is inherited by all devices).

.EXAMPLE
    .\Install WireGuard.ps1

.EXAMPLE
    $env:wireguardConfig = (Get-Content .\office.conf -Raw)
    .\Install WireGuard.ps1

.NOTES
    Deployed via NinjaOne RMM. Runs at SYSTEM level with no interactive UI.
    Can also be run manually on a workstation for testing.

    WireGuard installs to:  C:\Program Files\WireGuard\
    Tunnel configs live in: C:\ProgramData\WireGuard\

    NinjaOne setup for tunnel config deployment:
      1. Create a "Multi-line Text" organization custom field named "WireGuard Config"
         (field name: wireguardConfig). Paste the full .conf file content there.
      2. In the Ninja automation, map wireguardConfig as a script variable so it is
         exposed as $env:wireguardConfig. Organization fields are inherited at the
         device level automatically.

    Without LimitedOperatorUI = 1 the WireGuard UI does not appear for non-admin
    users at all. Note: WireGuard's own documentation flags this key as an
    advanced/unsupported knob that may be removed in a future release.
#>

#Requires -RunAsAdministrator

param(
    [string]$WireGuardConfig = ""
)

$ProgressPreference = "SilentlyContinue"

# Ninja environment variable override
if ($env:wireguardConfig) { $WireGuardConfig = $env:wireguardConfig }

#region Functions

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$ts] [$Level] $Message"
}

function Test-WireGuardInstalled {
    return (Test-Path "C:\Program Files\WireGuard\wireguard.exe")
}

function Get-WingetPath {
    # winget lives inside a versioned WindowsApps folder. Check common patterns
    # for x64 and ARM64. Running as SYSTEM has full filesystem access here.
    $patterns = @(
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe",
        "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_arm64__8wekyb3d8bbwe\winget.exe"
    )
    foreach ($pattern in $patterns) {
        $match = Resolve-Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object Path -Descending |
            Select-Object -First 1
        if ($match) { return $match.Path }
    }
    return $null
}

function Install-ViaWinget {
    $winget = Get-WingetPath
    if (-not $winget) {
        Write-Log "winget not found on this system." "Warning"
        return $false
    }

    Write-Log "Found winget at: $winget"
    Write-Log "Attempting install via winget (WireGuard.WireGuard)..."

    $output = & $winget install --id WireGuard.WireGuard --silent --scope machine `
        --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
    Write-Log "winget output: $($output.Trim())"

    if ($LASTEXITCODE -eq 0) {
        Write-Log "WireGuard installed successfully via winget."
        return $true
    }

    Write-Log "winget exited with code $LASTEXITCODE." "Warning"
    return $false
}

function Get-OSArchitecture {
    # PROCESSOR_ARCHITEW6432 is set when a 32-bit process runs on a 64-bit OS
    $native = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } `
              else { $env:PROCESSOR_ARCHITECTURE }
    switch ($native) {
        "ARM64"  { return "arm64" }
        "AMD64"  { return "amd64" }
        default  { return "x86"   }
    }
}

function Install-ViaDirectDownload {
    $arch        = Get-OSArchitecture
    $downloadBase = "https://download.wireguard.com/windows-client"
    $useMsi       = $false
    $installer    = $null

    Write-Log "Fetching WireGuard MSI list for architecture: $arch"

    try {
        $listing = Invoke-WebRequest -Uri "$downloadBase/" -UseBasicParsing

        # Parse links for versioned MSIs matching our architecture
        $msiFile = $listing.Links |
            Where-Object { $_.href -match "^wireguard-$arch-[\d\.]+\.msi$" } |
            ForEach-Object {
                $verStr = $_.href -replace "^wireguard-$arch-", "" -replace "\.msi$", ""
                try   { [PSCustomObject]@{ href = $_.href; Ver = [version]$verStr } }
                catch { $null }
            } |
            Where-Object { $_ } |
            Sort-Object Ver -Descending |
            Select-Object -First 1 -ExpandProperty href

        if (-not $msiFile) {
            throw "No MSI found for architecture '$arch' in directory listing."
        }

        $url       = "$downloadBase/$msiFile"
        $installer = Join-Path $env:TEMP $msiFile
        Write-Log "Downloading: $url"
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
        $useMsi = $true

    } catch {
        Write-Log "MSI discovery/download failed: $($_.Exception.Message)" "Warning"
        Write-Log "Falling back to wireguard-installer.exe..."
        $installer = Join-Path $env:TEMP "wireguard-installer.exe"
        Invoke-WebRequest -Uri "$downloadBase/wireguard-installer.exe" -OutFile $installer -UseBasicParsing
        $useMsi = $false
    }

    Write-Log "Running installer silently..."
    if ($useMsi) {
        $proc = Start-Process msiexec.exe `
            -ArgumentList "/i `"$installer`" /quiet /norestart" `
            -Wait -PassThru -NoNewWindow
    } else {
        # wireguard-installer.exe is NSIS-based; /S = silent
        $proc = Start-Process $installer -ArgumentList "/S" -Wait -PassThru -NoNewWindow
    }

    Remove-Item $installer -Force -ErrorAction SilentlyContinue

    # 0 = success, 3010 = success (reboot required)
    if ($proc.ExitCode -in @(0, 3010)) {
        Write-Log "WireGuard installed via direct download (exit code $($proc.ExitCode))."
        return $true
    }

    Write-Log "Installer exited with code $($proc.ExitCode)." "Error"
    return $false
}

function Set-LimitedOperatorUI {
    Write-Log "Applying LimitedOperatorUI registry key..."
    $regPath = "HKLM:\Software\WireGuard"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "LimitedOperatorUI" -Value 1 -Type DWord
    Write-Log "Set HKLM\Software\WireGuard\LimitedOperatorUI = 1"
}

function Add-UsersGroupToNetworkConfigOperators {
    $targetGroup = "Network Configuration Operators"

    $existing = Get-LocalGroupMember -Group $targetGroup -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*\Users' -or $_.Name -eq 'Users' }

    if ($existing) {
        Write-Log "'Users' group is already in '$targetGroup'."
        return
    }

    try {
        Add-LocalGroupMember -Group $targetGroup -Member "Users" -ErrorAction Stop
        Write-Log "Added 'Users' group to '$targetGroup'."
    } catch {
        Write-Log "Could not add 'Users' group to '$targetGroup': $($_.Exception.Message)" "Warning"
    }
}

function Install-WireGuardTunnel {
    param([string]$Config)

    $wgExe    = "C:\Program Files\WireGuard\wireguard.exe"
    $confDir  = "C:\ProgramData\WireGuard"
    $confPath = Join-Path $confDir "wg0.conf"

    if (-not (Test-Path $wgExe)) {
        Write-Log "wireguard.exe not found - cannot register tunnel config." "Warning"
        return
    }

    if (-not (Test-Path $confDir)) {
        New-Item -Path $confDir -ItemType Directory -Force | Out-Null
    }

    Set-Content -Path $confPath -Value $Config -Encoding UTF8

    # Restrict config file to SYSTEM and Administrators only - the config
    # contains private keys and must not be world-readable
    try {
        $acl = Get-Acl $confPath
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($identity in @("NT AUTHORITY\SYSTEM", "BUILTIN\Administrators")) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $identity, "FullControl", "Allow")
            $acl.AddAccessRule($rule)
        }
        Set-Acl -Path $confPath -AclObject $acl
        Write-Log "Config file permissions secured: $confPath"
    } catch {
        Write-Log "Could not set config file ACL: $($_.Exception.Message)" "Warning"
    }

    Write-Log "Registering WireGuard tunnel 'wg0'..."
    $output = & $wgExe /installtunnel $confPath 2>&1 | Out-String
    Write-Log "Tunnel registration output: $($output.Trim())"

    # /installtunnel starts the tunnel immediately and sets it to auto-start on
    # boot. Stop it and switch to manual startup so the tunnel is visible in the
    # WireGuard UI but only connects when the user explicitly activates it.
    $svcName = 'WireGuardTunnel$wg0'
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service  -Name $svcName -Force   -ErrorAction SilentlyContinue
        Set-Service   -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue
        Write-Log "Tunnel service stopped and set to manual start - users connect via the WireGuard UI."
    } else {
        Write-Log "Could not locate tunnel service '$svcName' to adjust startup type." "Warning"
    }
}

#endregion

try {
    Write-Log "=== WireGuard Installation Start ==="

    # Install WireGuard if not already present
    if (Test-WireGuardInstalled) {
        Write-Log "WireGuard is already installed - skipping install step."
    } else {
        # Primary: winget
        $success = Install-ViaWinget

        # Fallback: direct download from wireguard.com
        if (-not $success -or -not (Test-WireGuardInstalled)) {
            Write-Log "Trying direct download fallback..."
            $success = Install-ViaDirectDownload
        }

        if (-not (Test-WireGuardInstalled)) {
            Write-Log "WireGuard installation could not be verified after all attempts." "Error"
            exit 1
        }

        Write-Log "WireGuard installation verified."
    }

    # Registry key: enable limited operator UI for non-admin tunnel management
    Set-LimitedOperatorUI

    # Add the Users group to Network Configuration Operators
    Write-Log "Adding Users group to 'Network Configuration Operators'..."
    Add-UsersGroupToNetworkConfigOperators

    # Install tunnel config if one was provided
    if ($WireGuardConfig -ne "") {
        Write-Log "Installing tunnel config as 'wg0'..."
        Install-WireGuardTunnel -Config $WireGuardConfig
    } else {
        Write-Log "No tunnel config provided (wireguardConfig not set) - skipping tunnel registration."
    }

    Write-Log "=== WireGuard setup complete ===" "Success"
    exit 0

} catch {
    Write-Log "Fatal error: $($_.Exception.Message)" "Error"
    exit 1
}
