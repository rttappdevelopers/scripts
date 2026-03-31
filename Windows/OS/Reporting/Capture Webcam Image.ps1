# Capture Webcam Image [WIN]
# Captures a webcam image and stores as base64 in the RMM job log file. Click "Download Results" in the stdout log then rename to .htm to see the picture.

[Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”) >$null;
Add-MpPreference -ExclusionProcess "CommandCam.exe"
Start-Process -Wait -FilePath ".\CommandCam.exe" -ArgumentList "/filename $env:TEMP\image.bmp"
$file = new-object System.Drawing.Bitmap("$env:TEMP\image.bmp”);
$file.Save("$env:TEMP\image.jpg","jpeg");
$file.Dispose();
$bytes = [convert]::ToBase64String((get-content "$env:TEMP\image.jpg" -encoding byte))
Write-Host "Computer Name <br>"
Write-Host "$env:computername"
Write-Host "<br><br>"
Write-Host "Public IP address <br>"
(Invoke-WebRequest -UseBasicParsing -uri "http://ifconfig.me/ip").Content
Write-Host "<br><br>"
Write-Host "Date and Time <br>"
Get-Date -Format “MM/dd/yyyy HH:mm K”
Write-Host "<br><br>"
Write-Host "<img src='data:image/jpeg;base64, $bytes '/>"
Write-Host "</html>"