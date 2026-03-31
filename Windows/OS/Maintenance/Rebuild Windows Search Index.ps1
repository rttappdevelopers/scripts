# Rebuild Windows Search DB
# Do not run this while users are using the servers and schedule this only in maintenance windows.

# From https://www.cyberdrain.com/370/
Stop-Service Wsearch
$CurrentLoc = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Search" -name DataDirectory
remove-item $CurrentLoc.DataDirectory -force -Recurse
Start-Service Wsearch