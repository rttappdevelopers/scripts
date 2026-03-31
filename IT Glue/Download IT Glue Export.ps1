# Downloaded from https://github.com/IT-Glue-Public/automation/tree/main/Exports
# Updated to retain last 4 backup files
# Syntax: powershell -command "& { . C:\ITG\ITGlueExportDownload.ps1; Get-ITGlueExportZip }"
$ProgressPreference = 'SilentlyContinue' # Disable progress bar to improve performance
$base_uri = "https://api.itglue.com"
$api_key = $env:ITGLUE_API_KEY
if (-not $api_key) {
    Write-Error "ITGLUE_API_KEY environment variable is not set. Set it before running this script."
    exit 1
}
$destination_path = if ($env:ITGLUE_EXPORT_PATH) { $env:ITGLUE_EXPORT_PATH } else { "C:\ITG\" }

$headers = @{
    "x-api-key" = $api_key
}
# Trim superfluous forward slash from address (if applicable)
if($base_uri[$base_uri.Length-1] -eq "/") {
    $base_uri = $base_uri.Substring(0,$base_uri.Length-1)
}

function Get-ITGlueExportByLast {
    $data = @{}
    $resource_uri = "/exports?page[number]=1&sort=-updated-at&page[size]=1"

    try {
        $rest_output = Invoke-RestMethod -Method get -Uri ($base_uri + $resource_uri) -Headers $headers -ContentType application/vnd.api+json
    } catch {
        Write-Error $_
    }

    $data = $rest_output.data
    return $data
}

function Get-ITGlueExportById([uint64]$id) {
    $data = @{}
    $resource_uri = ('/exports/{0}' -f $id)
    
    try {
        $rest_output = Invoke-RestMethod -Method get -Uri ($base_uri + $resource_uri) -Headers $headers -ContentType application/vnd.api+json
    } catch {
        Write-Error $_
    }

    $data = $rest_output.data
    return $data
}

function Get-DateStamp {
    return (Get-Date).ToString("yyyyMMdd")
}

function Get-ITGlueExportZip {
    Param (
        [Parameter(Mandatory = $false)]
        [uint64]$Export_Id
    )
    
    if ($Export_Id) {
        $export_data = Get-ITGlueExportById($Export_Id)
    }
    else {
        $export_data = Get-ITGlueExportByLast
    }

    if ($export_data) {
        $source = $export_data.attributes."download-url"
        $response_id = $export_data."id"

        if ($source) {
            $datestamp = Get-DateStamp
            $destination_name = "account.zip"
            if ($export_data.attributes."organization-name") {
                $destination_name = $datestamp + "_" + $export_data.attributes."organization-name" + ".zip"
            } else {
                $destination_name = $datestamp + "_" + $destination_name
            }

            $destination = Join-Path -Path $destination_path -ChildPath $destination_name 
            
            $start_time = Get-Date
            Invoke-WebRequest -Uri $source -OutFile $destination
            Write-Output "Export no $response_id for $destination_name is downloaded in: $((Get-Date).Subtract($start_time).Seconds) second(s)"

            # Retain only the last 4 files
            $files = Get-ChildItem -Path $destination_path -Filter "*.zip" | Sort-Object LastWriteTime -Descending
            if ($files.Count -gt 4) {
                $filesToRemove = $files | Select-Object -Skip 4
                foreach ($file in $filesToRemove) {
                    Remove-Item -Path $file.FullName -Force
                }
            }
        }
        else {
            Write-Output "The export ID $response_id doesn't contain a downloadable zip."
        }
    }
    else {
        Write-Output "The requested export is not found. Please refer to the error messages"
    }
}