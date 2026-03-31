# Set registry key that applies a UDF based on hostname
# Useful for identifying sub-organizations within an RMM client site

# Variables
# Which UDF field number do you wish to populate?
# If $env:udfNumber is not set, use the default value of 28
if ([string]::IsNullOrEmpty($env:udfNumber)) {
    $udfNumber = 28
} else {
    $udfNumber = $env:udfNumber
}
$udfName = "Custom$udfNumber"

# Get hostname
$hostname = hostname

# Extract prefix up to first hyphen from hostname
$prefix = $hostname.split('-')[0]

# Set registry key
Write-Output "Logging resulting UDF $udfNumber to $prefix"
Set-ItemProperty "HKLM:\Software\CentraStage" -Name $udfName -Value "$prefix"