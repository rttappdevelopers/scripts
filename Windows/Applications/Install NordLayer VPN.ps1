# Get latest version of NordLayer VPN from https://downloads.nordlayer.com/win/releases/rss.xml and download it

# Get the latest version of NordLayer VPN from the RSS feed
$nordLayerURL = "https://downloads.nordlayer.com/win/releases/rss.xml"
$latestVersion = Invoke-RestMethod -Uri $nordLayerURL | Select-Object -First 1 | Select-Object -ExpandProperty link
$filename = $latestVersion.Split('/')[-1]

# Download the latest version of NordLayer VPN
if (-not (Test-Path 'C:\TEMP')) { New-Item -ItemType Directory -Path 'C:\TEMP' }
Start-BitsTransfer -Source $latestVersion -Destination "C:\Temp\$filename"

# Install the latest version of NordLayer VPN with msiexec and the /quiet parameter
Start-Process -FilePath "msiexec" -ArgumentList "/i C:\Temp\$filename /qn" -Wait
Remove-Item -Path "C:\Temp\$filename"
