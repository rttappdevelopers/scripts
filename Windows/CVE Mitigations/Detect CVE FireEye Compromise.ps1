# CVE: Find FireEye
# This Script looks for FireEye and if found trigger event id 911 in application log for FireEye source
# Requires yara and build23.ps1

$env:usrScanScope=4
./build23.ps1
if (Test-Path "detections.txt") {
  $text = Get-Content .\detections.txt -Raw 
  eventcreate /id 911 /l application /t information /so FireEye /d "$text"
}