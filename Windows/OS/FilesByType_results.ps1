# Search filesystem starting at variable "C:\Users" for PST files and list them by file size
$filename = if ($env:fileDescriptor) { $env:fileDescriptor } else { "*.pst" }
$startPath = if ($env:startFrom) { $env:startFrom } else { "C:\Users\" }

# Define the output file path in the temp folder
$tempFolder = "C:\Temp"
if (-not (Test-Path -Path $tempFolder)) {
    New-Item -ItemType Directory -Path $tempFolder | Out-Null
}
$outputFile = "$tempFolder\FilesByType_results.csv"

Write-Host "Searching for files with the name: $filename in $startPath"
Write-Host "Results will be saved to: $outputFile"

# Search for files with the specified filename and sort them by size
$files = Get-ChildItem -Path $startPath -Recurse -Filter $filename -ErrorAction SilentlyContinue | Sort-Object Length

# Calculate file count and total size
$fileCount = $files.Count
$totalSize = ($files | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

# Convert file size to MB and write the results to the output file in CSV format
$files | Select-Object FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}} | Export-Csv -Path $outputFile -NoTypeInformation

# Display the results in a table
$files | Select-Object FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length / 1MB, 2)}} | Format-Table -Property FullName, SizeMB

# Report file count and total size
# Display the results to the console
$results = "Total files: $fileCount, Total size: $totalSizeMB MB"
Write-Host $results

# Export the results to a ninja-property custom field
Ninja-Property-Set fileAudit $results