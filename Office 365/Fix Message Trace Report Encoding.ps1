# Fix Message Trace Report Encoding
# This script fixes encoding issues in downloaded Exchange Online message trace reports

param(
    [string]$InputPath = "",
    [string]$OutputPath = ""
)

Write-Output "=== Message Trace Report Encoding Fixer ==="
Write-Output ""

# Get input file if not provided
if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Read-Host "Enter the path to the downloaded message trace report"
}

# Validate input file exists
if (!(Test-Path $InputPath)) {
    Write-Error "File not found: $InputPath"
    exit 1
}

# Set output path if not provided
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $directory = [System.IO.Path]::GetDirectoryName($InputPath)
    $OutputPath = Join-Path $directory "${fileName}_fixed.csv"
}

Write-Output "Input file: $InputPath"
Write-Output "Output file: $OutputPath"
Write-Output ""

try {
    Write-Output "Processing file..."
    
    # Try different encodings to read the file
    $content = $null
    $encodings = @(
        [System.Text.Encoding]::UTF8,
        [System.Text.Encoding]::Unicode,
        [System.Text.Encoding]::UTF32,
        [System.Text.Encoding]::Default,
        [System.Text.Encoding]::ASCII
    )
    
    foreach ($encoding in $encodings) {
        try {
            $testContent = [System.IO.File]::ReadAllText($InputPath, $encoding)
            # Check if it looks like a valid message trace report
            if ($testContent -match "origin_timestamp_utc|message_subject|sender_address" -and $testContent.Length -gt 100) {
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
        Write-Error "Could not read the file with any standard encoding. The file may be corrupted or not a message trace report."
        exit 1
    }
    
    # Write with UTF-8 no BOM for maximum compatibility
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
    $processedData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    # Clean up temp file
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    
    Write-Output ""
    Write-Output "File successfully converted and parsed!"
    Write-Output ""
    
    # Verify the output
    $lines = Get-Content $OutputPath -First 3
    Write-Output "First few lines of fixed file:"
    Write-Output "--------------------------------"
    $lines | ForEach-Object { Write-Output $_ }
    Write-Output "--------------------------------"
    Write-Output ""
    
    # Count rows (excluding header)
    $rowCount = (Get-Content $OutputPath | Measure-Object -Line).Lines - 1
    Write-Output "Total rows in file: $rowCount"
    Write-Output ""
    Write-Output "Columns added:"
    Write-Output "  - recipient_addresses: List of unique email addresses"
    Write-Output "  - delivery_statuses: List of delivery statuses"
    Write-Output "  - recipient_count: Number of unique recipients"
    Write-Output "  - recipient_status_raw: Original raw data (moved to end)"
    Write-Output ""
    Write-Output "Fixed report saved to: $OutputPath"
    Write-Output ""
    Write-Output "You can now open this file in Excel, OnlyOffice, or any CSV viewer."
}
catch {
    Write-Error "Failed to process file: $($_.Exception.Message)"
    exit 1
}