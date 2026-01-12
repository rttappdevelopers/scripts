# Download and Fix Message Trace Reports
Set-ExecutionPolicy RemoteSigned

# Connect to Exchange Online
Write-Output "Connecting to Exchange Online..."
if (!(Get-InstalledModule -Name "ExchangeOnlineManagement" -ErrorAction SilentlyContinue)) {
    Install-Module -Name ExchangeOnlineManagement -Force
    Import-Module ExchangeOnlineManagement
} else {
    Import-Module ExchangeOnlineManagement
}

Connect-ExchangeOnline

# Get available message trace reports
Write-Output "`nRetrieving available message trace reports..."
$reports = Get-HistoricalSearch | Where-Object { $_.Status -eq "Done" } | Sort-Object SubmitDate -Descending

if ($reports.Count -eq 0) {
    Write-Output "No completed message trace reports found."
    exit
}

# Display available reports
Write-Output "`nAvailable Reports:"
for ($i = 0; $i -lt $reports.Count; $i++) {
    Write-Output "$($i + 1). Job ID: $($reports[$i].JobId)"
    Write-Output "   Name: $($reports[$i].ReportTitle)"
    Write-Output "   Date Range: $($reports[$i].StartDate) to $($reports[$i].EndDate)"
    Write-Output "   Submitted: $($reports[$i].SubmitDate)"
    Write-Output "   Rows: $($reports[$i].Rows)"
    Write-Output ""
}

# Select report to download
$selection = Read-Host "Enter the number of the report to download (or 'all' for all reports)"

$reportsToDownload = @()
if ($selection -eq "all") {
    $reportsToDownload = $reports
} else {
    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $reports.Count) {
        $reportsToDownload = @($reports[$index])
    } else {
        Write-Error "Invalid selection."
        exit
    }
}

# Download and fix each report
foreach ($report in $reportsToDownload) {
    Write-Output "`nDownloading report: $($report.ReportTitle) ($($report.JobId))..."
    
    $outputFile = "C:\temp\MessageTrace_$($report.JobId).csv"
    
    try {
        # Get the report data
        $reportUri = (Get-HistoricalSearch -JobId $report.JobId).FileUrl
        
        if ([string]::IsNullOrEmpty($reportUri)) {
            Write-Warning "Report $($report.JobId) has no download URL available."
            continue
        }
        
        # Download the file
        $tempFile = "$env:TEMP\messagetrace_temp_$($report.JobId).csv"
        Invoke-WebRequest -Uri $reportUri -OutFile $tempFile
        
        # Read the file with proper encoding and fix it
        # Try UTF-8 first, then other encodings
        $content = $null
        $encodings = @([System.Text.Encoding]::UTF8, [System.Text.Encoding]::Unicode, [System.Text.Encoding]::Default, [System.Text.Encoding]::ASCII)
        
        foreach ($encoding in $encodings) {
            try {
                $content = [System.IO.File]::ReadAllText($tempFile, $encoding)
                if ($content -match "origin_timestamp_utc" -and $content.Length -gt 100) {
                    Write-Output "Successfully read file with $($encoding.EncodingName) encoding"
                    break
                }
            }
            catch {
                continue
            }
        }
        
        if ([string]::IsNullOrEmpty($content)) {
            Write-Warning "Could not read report with any standard encoding."
            continue
        }
        
        # Write to new file with UTF-8 encoding (no BOM)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($outputFile, $content, $utf8NoBom)
        
        # Verify the output
        $lines = Get-Content $outputFile | Select-Object -First 5
        Write-Output "`nFirst few lines of fixed file:"
        $lines | ForEach-Object { Write-Output $_ }
        
        Write-Output "`nReport saved to: $outputFile"
        Write-Output "Rows: $($report.Rows)"
        
        # Clean up temp file
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
    }
    catch {
        Write-Error "Failed to download or process report $($report.JobId): $($_.Exception.Message)"
    }
}

Write-Output "`nDisconnecting from Exchange Online..."
Disconnect-ExchangeOnline -Confirm:$false

Write-Output "`nDone!"