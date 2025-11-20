# Prefer environment variables, fallback to hardcoded values if needed
$cybercnscompany_id = (Ninja-Property-Get connectsecureCompanyId)
$cybercnstenantid   = '' # populate from CS website
$cybercnstoken      = '' # populate from CS website
$serviceName        = 'cybercnsagent'

# Confirm company ID is provided
if (-not $cybercnscompany_id) {
    return "cybercnscompany_id is NULL"
}
# Check if the service already exists
$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($svc) {
    # Service found - check if it's running
    if ($svc.Status -eq 'Running') {
        return "$serviceName found and running."
    } else {
        return "$serviceName found, but it is not running."
    }
} else {
    # Service not found - download and install the agent
    $source = (Invoke-RestMethod -Method "Get" -URI "https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=windows")
    $destination = 'cybercnsagent.exe'
    
    # Download the agent executable
    Invoke-WebRequest -Uri $source -OutFile $destination
    
    # Run the installer with company credentials and tenant information
    & .\cybercnsagent.exe -c $cybercnscompany_id -e $cybercnstenantid -j $cybercnstoken -i
}