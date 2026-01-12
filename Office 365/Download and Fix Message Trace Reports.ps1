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
    Write-Output "`nProcessing report: $($report.ReportTitle) ($($report.JobId))..."
    
    # Sanitize filename
    $sanitizedTitle = $report.ReportTitle -replace '[\\/:*?"<>|]', '_'
    $outputFile = "C:\temp\${sanitizedTitle}.csv"
    
    try {
        Write-Output "Reconstructing message trace data from historical search..."
        
        # Use Get-MessageTraceDetail which can access historical data via the report
        $messages = @()
        $pageSize = 1000
        $page = 1
        
        do {
            Write-Output "Fetching page $page..."
            $pageResults = Get-HistoricalSearch -JobId $report.JobId | 
                Select-Object -ExpandProperty Report -ErrorAction SilentlyContinue
            
            if ($pageResults) {
                $messages += $pageResults
            } else {
                break
            }
            $page++
        } while ($pageResults.Count -eq $pageSize)
        
        if ($messages.Count -eq 0) {
            Write-Warning "Could not retrieve message data. The report may need to be downloaded manually."
            Write-Output "`nManual download instructions:"
            Write-Output "1. Go to: https://admin.exchange.microsoft.com/#/messagetrace"
            Write-Output "2. Click 'Downloadable reports' tab"
            Write-Output "3. Find report: $($report.ReportTitle)"
            Write-Output "4. Click Download"
            Write-Output "5. Save the file"
            Write-Output ""
            
            $manualFile = Read-Host "Enter the path to the downloaded file (or press Enter to skip)"
            
            if (![string]::IsNullOrWhiteSpace($manualFile) -and (Test-Path $manualFile)) {
                Write-Output "Processing manually downloaded file..."
                
                # Try different encodings to read the file
                $content = $null
                $encodings = @(
                    [System.Text.Encoding]::UTF8,
                    [System.Text.Encoding]::Unicode,
                    [System.Text.Encoding]::UTF32,
                    [System.Text.Encoding]::Default
                )
                
                foreach ($encoding in $encodings) {
                    try {
                        $testContent = [System.IO.File]::ReadAllText($manualFile, $encoding)
                        if ($testContent -match "origin_timestamp_utc|message_subject" -and $testContent.Length -gt 100) {
                            $content = $testContent
                            Write-Output "Successfully read file with $($encoding.EncodingName) encoding"
                            break
                        }
                    }
                    catch {
                        continue
                    }
                }
                
                if ([string]::IsNullOrEmpty($content)) {
                    Write-Error "Could not read the file with any standard encoding."
                    continue
                }
                
                # Write with UTF-8 no BOM
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($outputFile, $content, $utf8NoBom)
                
                # Verify the output
                $lines = Get-Content $outputFile -First 5
                Write-Output "`nFirst few lines of fixed file:"
                $lines | ForEach-Object { Write-Output $_ }
                
                Write-Output "`nFixed report saved to: $outputFile"
                
                # Count rows (excluding header)
                $rowCount = (Get-Content $outputFile | Measure-Object -Line).Lines - 1
                Write-Output "Rows in file: $rowCount"
            }
        } else {
            Write-Output "Exporting $($messages.Count) messages to CSV..."
            $messages | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            Write-Output "Report saved to: $outputFile"
        }
        
    }
    catch {
        Write-Error "Failed to process report $($report.JobId): $($_.Exception.Message)"
    }
}

Write-Output "`nDisconnecting from Exchange Online..."
Disconnect-ExchangeOnline -Confirm:$false

Write-Output "`nDone!"