# Clears the Teams cache directories of each end user. Kills open Outlook and Teams applications, run off-hours or with end user interaction!
# Source: https://techcommunity.microsoft.com/t5/itops-talk-blog/powershell-basics-how-to-delete-microsoft-teams-cache-for-all/ba-p/1519118
if ($env:assessonly -eq "true") { $assessonly = "true" }

If ($assessonly -ne "true") {
    # Get process of Teams and kill it if it is running
    $TeamsProcess = Get-Process -Name Teams -ErrorAction SilentlyContinue
    If ($TeamsProcess) {
        Stop-Process -Name Teams
        Start-Sleep -Seconds 5
    }
    # Get process of Outlook and kill it if it is running
    $OutlookProcess = Get-Process -Name Outlook -ErrorAction SilentlyContinue
    If ($OutlookProcess) {
        Stop-Process -Name Outlook
        Start-Sleep -Seconds 5
    }
    Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Teams\*" -directory | Where name -in ('application cache','blob_storage','databases','GPUcache','IndexedDB','Local Storage','tmp') | ForEach{Remove-Item $_.FullName -Recurse -Force}
}
else {
    Get-ChildItem "C:\Users\*\AppData\Roaming\Microsoft\Teams\*" -directory | Where name -in ('application cache','blob_storage','databases','GPUcache','IndexedDB','Local Storage','tmp') | ForEach{Remove-Item $_.FullName -Recurse -Force -WhatIf}
}
