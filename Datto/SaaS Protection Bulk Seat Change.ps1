# Bulk seat changes in Datto SaaS Protection with Datto API
# Reference: https://celerium.github.io/Datto-PowerShellWrapper/
if (-not (Get-Module -ListAvailable -Name DattoAPI)) {
    Install-Module -Name DattoAPI
}

# Import the DattoAPI module
Import-Module -Name DattoAPI

# Prompt for API keys
$DattoAPIPrivKey = Read-Host -Prompt "Enter your Datto API Private key"
$DattoAPIPubKey = Read-Host -Prompt "Enter your Datto API Public key"
Add-DattoAPIKey -Api_Key_Public $DattoAPIPubKey -Api_Key_Secret $DattoAPIPrivKey

#Capture URL to customer in SaaS Protection portal and extrapolate the customer ID from it
# Customer URL format: https://use1-saas-p6-app-11-ext.backupify.com/447522/google?datto_sso_token=58689&external_customer_id=0908194b-0177-11ef-aea4-06ef8ff98232
$CustomerURL = Read-Host -Prompt "Enter the URL to the customer in the SaaS Protection portal"
$CustomerID = $CustomerURL.Split("/")[-2]
Write-Output "Customer ID: $CustomerID"

# Test by getting list of seats
Get-DattoSeat -saasCustomerId $CustomerID

#Prompt for the carriage return delimited list of email addresses to remove from the customer
#$EmailAddresses = Read-Host -Prompt "Enter the email addresses to remove from the customer, separated by carriage returns"

