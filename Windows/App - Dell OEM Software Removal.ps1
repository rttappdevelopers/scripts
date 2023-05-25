# This is a three-phase attempt to uninstall Dell OEM bloatware
# SupportAssist is known to fill a disk with snapshots without proper limits, and is detrimental to small disks
# Several of these applications have been listed as a CVE
# It is best to install the OEM software as needed for a specific support task, and then remove it once finished with it
$ErrorActionPreference = "SilentlyContinue"
Install-PackageProvider -Name NuGet -Force # pre-requisite tool

$list = 
    'Dell SupportAssist', 
    'Dell SupportAssist OS Recovery Plugin for Dell Update', 
    'Dell SupportAssist Remediation',
    'Dell Command | Update',
    'Dell System Inventory Agent',
    'Dell Platform Tags',
    'Dell BIOS Flash Utility',
    'Dell Digital Delivery'

foreach ($item in $list) {
    # Phase 1: Uninstall string in Windows Registry
    Write-Output "Checking for $item..."
    $guid = Get-ChildItem 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' | Get-ItemProperty | Where-Object {$_.DisplayName -ceq $item } | Select-Object -ExpandProperty QuietUninstallString
    if ($guid)
    {
        Write-Output "Uninstalling $item"
        Write-Output "Executing $guid"
        Invoke-Expression "& $guid"
        Write-Output `n
    }
    # Phase 2: APplication has been installed as a Universal Windows Program or OWP
    Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*$item*"} | Select-Object Name, PackageFullName | Remove-AppxPackage -allusers
    
    # Phase 3: Application was installed to the Add / Remove programs and does not have an uninstall string, and isn't a UWP
    Get-Package | Where-Object {$_.Name -like "*$item*"} | Uninstall-Package
}