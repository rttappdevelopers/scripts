#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enable and start one or more Windows services.
.DESCRIPTION
    For each named service: if disabled, sets the startup type to Automatic; if stopped,
    starts it; if running, restarts it. Retries up to the configured number of attempts,
    waiting between each, before reporting failure.
.PARAMETER Name
    The Name or DisplayName of one or more services. Accepts a comma-separated string
    or an array. Supports the NinjaRMM environment variable: Name.
.PARAMETER Attempts
    Number of start attempts before giving up. Default: 3.
    Supports the NinjaRMM environment variable: Attempts.
.PARAMETER WaitTimeInSecs
    Seconds to wait between start attempts. Default: 15.
    Supports the NinjaRMM environment variable: WaitTimeInSecs.
.EXAMPLE
     -Name "wuauserv"
    Enables and starts the Windows Update service if disabled or stopped; restarts it if running.
.EXAMPLE
     -Name "wuauserv,Spooler" -Attempts 5 -WaitTimeInSecs 10
    Enables and starts two services with custom retry settings.
.NOTES
    Exit Code 0: All service(s) successfully running.
    Exit Code 1: One or more services failed to reach Running state.
    Designed for RMM deployment (SYSTEM context, no UI).
#>
[CmdletBinding()]
param (
    [Parameter()]
    [string[]]$Name,

    [Parameter()]
    [int]$Attempts = 3,

    [Parameter()]
    [int]$WaitTimeInSecs = 15
)

$ProgressPreference = 'SilentlyContinue'

# NinjaRMM environment variable overrides
if ($env:Name)           { $Name = $env:Name -split ',' | ForEach-Object { $_.Trim() } }
if ($env:Attempts)       { $Attempts = [int]$env:Attempts }
if ($env:WaitTimeInSecs) { $WaitTimeInSecs = [int]$env:WaitTimeInSecs }

if (-not $Name) {
    Write-Host '[ERROR] -Name is required.'
    exit 1
}

# Handle comma-separated value passed as a single string via parameter
if ($Name.Count -eq 1 -and $Name[0] -like '*,*') {
    $Name = $Name[0] -split ',' | ForEach-Object { $_.Trim() }
}

$failedCount = 0

foreach ($serviceName in $Name) {
    try {
        $svc = Get-Service | Where-Object { $_.Name -eq $serviceName -or $_.DisplayName -eq $serviceName } | Select-Object -First 1

        if (-not $svc) {
            Write-Host "[ERROR] Service not found: $serviceName"
            $failedCount++
            continue
        }

        # Refresh to get current StartType and Status
        $svc = Get-Service -Name $svc.Name

        # Set to Automatic if Disabled or Manual
        if ($svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Disabled) {
            Write-Host "[INFO] '$($svc.Name)' startup type is Disabled - setting to Automatic."
            Set-Service -Name $svc.Name -StartupType Automatic
        } elseif ($svc.StartType -eq [System.ServiceProcess.ServiceStartMode]::Manual) {
            Write-Host "[INFO] '$($svc.Name)' startup type is Manual - setting to Automatic."
            Set-Service -Name $svc.Name -StartupType Automatic
        }

        # Restart if already running, otherwise start
        if ($svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
            Write-Host "[INFO] '$($svc.Name)' is Running - restarting."
            Restart-Service -Name $svc.Name -Force
        } else {
            Write-Host "[INFO] '$($svc.Name)' is $($svc.Status) - starting."
            Start-Service -Name $svc.Name
        }

        # Poll for Running state, retrying if needed
        $attempt = 0
        while ($attempt -lt $Attempts) {
            $svc = Get-Service -Name $svc.Name
            if ($svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) { break }
            $attempt++
            if ($attempt -lt $Attempts) {
                Write-Host "[INFO] '$($svc.Name)' not yet Running (attempt $attempt of $Attempts) - waiting $WaitTimeInSecs seconds."
                Start-Sleep -Seconds $WaitTimeInSecs
                Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            }
        }

        $svc = Get-Service -Name $svc.Name
        if ($svc.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
            Write-Host "[SUCCESS] '$($svc.Name)' is Running."
        } else {
            Write-Host "[ERROR] '$($svc.Name)' failed to reach Running state after $Attempts attempt(s)."
            $failedCount++
        }
    } catch {
        Write-Host "[ERROR] Exception handling '$serviceName': $($_.Exception.Message)"
        $failedCount++
    }
}

if ($failedCount -eq 0) {
    Write-Host 'All service(s) successfully running.'
    exit 0
} else {
    Write-Host "$failedCount service(s) failed to reach Running state."
    exit 1
}
