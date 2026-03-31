#Requires -Version 5.1
# Supplied by NinjaOne

<#
.SYNOPSIS
    Get a tree list of folder sizes for a given path with folders that meet a minimum folder size.
.DESCRIPTION
    Get a tree list of folder sizes for a given path with folders that meet a minimum folder size.
    Be default this looks at C:, with a folder depth of 3, and filters out any folder under 500 MB.
.EXAMPLE
    (No Parameters)
    Gets folder sizes under C:\ for a depth of 3 folders and displays folder larger than 500 MB.
.EXAMPLE
    -Path C:\
    -Path C:\ -MinSize 1GB
    -Path C:\Users\ -Depth 4

PARAMETER: -Path C:\
    Gets folder sizes under C:\.

PARAMETER: -Path C:\ -MinSize 1GB
    Gets folder sizes under C:\, but only returns folder larger than 1 GB.
    Don't use quotes around 1GB as PowerShell won't be able to expand it to 1073741824.

PARAMETER: -Path C:\Users\ -Depth 4
    Gets folder sizes under C:\Users\ with a depth of 4.

.OUTPUTS
    String[] or PSCustomObject[]
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes: Renamed script and added Script Variable support
#>

[CmdletBinding()]
param (
    [String]$Path = "C:\",
    [int]$Depth = 3,
    $MinSize = 500MB
)

begin {
    function Get-Size {
        param ([string]$String)
        switch -wildcard ($String) {
            '*PB' { [int64]$($String -replace '[^\d+]+') * 1PB; break }
            '*TB' { [int64]$($String -replace '[^\d+]+') * 1TB; break }
            '*GB' { [int64]$($String -replace '[^\d+]+') * 1GB; break }
            '*MB' { [int64]$($String -replace '[^\d+]+') * 1MB; break }
            '*KB' { [int64]$($String -replace '[^\d+]+') * 1KB; break }
            '*B' { [int64]$($String -replace '[^\d+]+') * 1; break }
            '*Bytes' { [int64]$($String -replace '[^\d+]+') * 1; break }
            Default { [int64]$($String -replace '[^\d+]+') * 1 }
        }
    }

    $Path = if ($env:rootPath) { Get-Item -Path $env:rootPath }else { Get-Item -Path $Path }
    if ($env:Depth) { $Depth = [System.Convert]::ToInt32($env:Depth) }
    $MinSize = if ($env:MinSize) { Get-Size $env:MinSize }else { Get-Size $MinSize }

    function Test-IsElevated {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    function Test-IsSystem {
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        return $id.Name -like "NT AUTHORITY*" -or $id.IsSystem
    }

    if (!(Test-IsElevated) -and !(Test-IsSystem)) {
        Write-Host "[Warning] Not running as SYSTEM account, results might be slightly inaccurate."
    }
    function Get-FriendlySize {
        param($Bytes)
        # Converts Bytes to the highest matching unit
        $Sizes = 'Bytes,KB,MB,GB,TB,PB,EB,ZB' -split ','
        for ($i = 0; ($Bytes -ge 1kb) -and ($i -lt $Sizes.Count); $i++) { $Bytes /= 1kb }
        $N = 2
        if ($i -eq 0) { $N = 0 }
        if ($Bytes) { "{0:N$($N)} {1}" -f $Bytes, $Sizes[$i] }else { "0 B" }
    }
    function Get-SizeInfo {
        param(
            [parameter(mandatory = $true, position = 0)][string]$TargetFolder,
            #defines the depth to which individual folder data is provided
            [parameter(mandatory = $true, position = 1)][int]$DepthLimit
        )
        $obj = New-Object PSObject -Property @{Name = $targetFolder; Size = 0; Subs = @() }
        # Are we at the depth limit? Then just do a recursive Get-ChildItem
        if ($DepthLimit -eq 1) {
            $obj.Size = (Get-ChildItem $targetFolder -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Sum -Property Length).Sum
            return $obj
        }
        # We are not at the depth limit, keep recursing
        $obj.Subs = foreach ($S in Get-ChildItem $targetFolder -Force -ErrorAction SilentlyContinue) {
            if ($S.PSIsContainer) {
                $tmp = Get-SizeInfo $S.FullName ($DepthLimit - 1)
                $obj.Size += $tmp.Size
                Write-Output $tmp
            }
            else {
                $obj.Size += $S.length
            }
        }
        return $obj
    }
    function Write-Results {
        param(
            [parameter(mandatory = $true, position = 0)]$Data,
            [parameter(mandatory = $true, position = 1)][int]$IndentDepth,
            [parameter(mandatory = $true, position = 2)][int]$MinSize
        )
    
        [PSCustomObject]@{
            Path     = "$((' ' * ($IndentDepth + 2)) + $Data.Name)"
            Size     = Get-FriendlySize -Bytes $Data.Size
            IsLarger = $Data.Size -ge $MinSize
        }

        foreach ($S in $Data.Subs) {
            Write-Results $S ($IndentDepth + 1) $MinSize
        }
    }
    function Get-SubFolderSize {
        [CmdletBinding()]
        param(
            [parameter(mandatory = $true, position = 0)]
            [string]$targetFolder,
    
            [int]$DepthLimit = 3,
            [int]$MinSize = 500MB
        )
        if (-not (Test-Path $targetFolder)) {
            Write-Error "The target [$targetFolder] does not exist"
            exit
        }
        $Data = Get-SizeInfo $targetFolder $DepthLimit
    
        #returning $data will provide a useful PS object rather than plain text
        # return $Data
    
        #generate a human friendly listing
        Write-Results $Data 0 $MinSize
    }
}
process {
    Get-SubFolderSize -TargetFolder $Path -DepthLimit $Depth -MinSize $MinSize | Where-Object { $_.IsLarger } | Select-Object -Property Path, Size
}
end {
    
    
    
}
