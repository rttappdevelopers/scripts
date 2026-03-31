# Set execution policy based on environment variable ExecPolicy
# Default to RemoteSigned if not set
$ExecPolicy = $env:ExecPolicy
if ($null -eq $ExecPolicy) {
    $ExecPolicy = "RemoteSigned"
}
Set-ExecutionPolicy -ExecutionPolicy $ExecPolicy -Scope Process -Force
