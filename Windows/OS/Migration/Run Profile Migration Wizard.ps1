# Name: Profile Wizard Migration Tool
# Description: This script will install the ForensiT Profile Wizard Migration Tool and update the license key in the configuration file.
# Required variable: licenseKey

msiexec.exe -i "https://www.forensit.com/Downloads/Profwiz.msi" /qn /norestart

# Read the existing file
[xml]$xmlDoc = Get-Content "C:\Profile_Wiz\bin\Profwiz.config"

# If it was one specific element you can just do like so:
$xmlDoc.ForensiTUserProfileWizard.licensing = $env:licenseKey
    
# Then you can save that back to the xml file
$xmlDoc.Save("C:\Profile_Wiz\bin\Profwiz.config")