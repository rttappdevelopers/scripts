Import-Module GroupPolicy

# Get-GPO where name includes either "AEM" or "RMM", and determine if it is enabled or disabled
$gpos = Get-GPO -All | Where-Object { $_.DisplayName -like "*AEM*" -or $_.DisplayName -like "*RMM*" -or $_.DisplayName -like "*CAG*" -or $_.DisplayName -like "*Datto*" } | Select-Object DisplayName, @{Name="Enabled";Expression={$_.GPOStatus}}

# Convert the output to a comma-delimited string
$csv = $gpos | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1

# Display the comma-delimited string
$csv

# Post the list to RMM User Defined Field
Write-Output "Logging resulting GPOs to RMM User Defined Field."
Set-ItemProperty "HKLM:\Software\CentraStage" -Name "Custom11" -Value "$csv"