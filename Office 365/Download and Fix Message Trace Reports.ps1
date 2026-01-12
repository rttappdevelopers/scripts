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
            $tempFile = "$env:TEMP\messagetrace_temp.csv"
            [System.IO.File]::WriteAllText($tempFile, $content, $utf8NoBom)
            
            Write-Output "Parsing and reorganizing columns..."
            
            # Import the CSV
            $csvData = Import-Csv $tempFile
            
            # Process each row
            $processedData = @()
            foreach ($row in $csvData) {
                # Get all properties
                $properties = $row.PSObject.Properties | Where-Object { $_.Name -ne "recipient_status" }
                
                # Create new object with reordered columns
                $newRow = [ordered]@{}
                
                # Add all columns except recipient_status
                foreach ($prop in $properties) {
                    $newRow[$prop.Name] = $prop.Value
                }
                
                # Parse recipient_status (column C) and add parsed columns at the end
                $recipientStatus = $row.recipient_status
                
                if (![string]::IsNullOrWhiteSpace($recipientStatus)) {
                    # Split by semicolon to get individual recipients
                    $recipients = $recipientStatus -split ';'
                    
                    # Extract unique email addresses and statuses
                    $emailAddresses = @()
                    $statuses = @()
                    
                    foreach ($recipient in $recipients) {
                        if ($recipient -match '(.+?)##(.+)') {
                            $email = $matches[1].Trim()
                            $status = $matches[2].Trim()
                            
                            if ($email -notin $emailAddresses) {
                                $emailAddresses += $email
                            }
                            if ($status -notin $statuses) {
                                $statuses += $status
                            }
                        }
                    }
                    
                    $newRow["recipient_addresses"] = ($emailAddresses -join "; ")
                    $newRow["delivery_statuses"] = ($statuses -join "; ")
                    $newRow["recipient_count"] = $emailAddresses.Count
                } else {
                    $newRow["recipient_addresses"] = ""
                    $newRow["delivery_statuses"] = ""
                    $newRow["recipient_count"] = 0
                }
                
                # Add original recipient_status at the very end
                $newRow["recipient_status_raw"] = $recipientStatus
                
                $processedData += [PSCustomObject]$newRow
            }
            
            # Export the processed data
            $processedData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
            
            # Clean up temp file
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            
            # Verify the output
            $lines = Get-Content $outputFile -First 5
            Write-Output "`nFirst few lines of fixed file:"
            $lines | ForEach-Object { Write-Output $_ }
            
            Write-Output "`nFixed report saved to: $outputFile"
            
            # Count rows (excluding header)
            $rowCount = (Get-Content $outputFile | Measure-Object -Line).Lines - 1
            Write-Output "Rows in file: $rowCount"
            Write-Output ""
            Write-Output "Columns added:"
            Write-Output "  - recipient_addresses: List of unique email addresses"
            Write-Output "  - delivery_statuses: List of delivery statuses"
            Write-Output "  - recipient_count: Number of unique recipients"
            Write-Output "  - recipient_status_raw: Original raw data (moved to end)"
        }
        
    }
    catch {
        Write-Error "Failed to process report $($report.JobId): $($_.Exception.Message)"
    }
}

Write-Output "`nDisconnecting from Exchange Online..."
Disconnect-ExchangeOnline -Confirm:$false

Write-Output "`nDone!"