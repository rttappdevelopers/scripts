# From https://www.powershellgallery.com/packages/PSWindowsUpdate/2.2.0.2
# if (-not (Get-Module -Name "PSWindowsUpdate")) {Install-Module PSWindowsUpdate -Confirm:$False -Force}

# Reference: https://community.spiceworks.com/topic/2310498-silently-uninstall-a-windows-update
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path C:\PSLog_Task.txt -append

# "19041.867.1.8" = KB5000802
# "18362.1440.1.7" = KB5000808
# "19041.1288.1.7" = KB5006670

$UpdateArray = @($env:KBorPID)

foreach ($UpdateVersion in $UpdateArray) {
    $SearchUpdates = dism /online /get-packages | findstr "Package_for" | findstr "$UpdateVersion"  
    if ($SearchUpdates) {
        $update = $SearchUpdates.split(":")[1].replace(" ", "")
        write-host ("Update result found: " + $update )
        dism /Online /Remove-Package /PackageName:$update /quiet /norestart
        # Hide-WindowsUpdate -KBArticleID $update
    } else {
        write-host ("Update " + $UpdateVersion + " not found.")
    }
}

Stop-Transcript
exit 0