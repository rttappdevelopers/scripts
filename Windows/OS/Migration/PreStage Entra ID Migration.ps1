# Azure AD Prestage Profile Migration [WIN]
# This is to be used with the Profile_Wiz migration component.  The Profile_Wiz component must be installed first.
# Varuables: AzureProvisioningURL, UserMappingXML

$WebClient = New-Object System.Net.WebClient
$url = $env:AzureProvisioningURL
write-host "Downloading $url"
$WebClient.DownloadFile("$url","C:\Profile_Wiz\bin\AzureJoin.ppkg")
$url = $env:UserMappingXML
write-host "Downloading $url"
$WebClient.DownloadFile("$url","C:\Profile_Wiz\bin\ForensiTAzureID.xml")
