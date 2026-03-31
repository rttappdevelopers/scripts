# Checks for environment variable that blocks formatted message lookups and apply it if it isn't already
# Reference "mitigation" section of: https://msrc-blog.microsoft.com/2021/12/11/microsofts-response-to-cve-2021-44228-apache-log4j2/

if ([System.Environment]::GetEnvironmentVariable('LOG4J_FORMAT_MSG_NO_LOOKUPS','machine') -eq 'true') {
    write-host "- Log4j 2.10+ exploit mitigation (LOG4J_FORMAT_MSG_NO_LOOKUPS) already set."
} else {
    write-host "- Enabling Log4j 2.10+ exploit mitigation: Enable LOG4J_FORMAT_MSG_NO_LOOKUPS"
    [Environment]::SetEnvironmentVariable("LOG4J_FORMAT_MSG_NO_LOOKUPS","true","Machine")
}

# Writes to RTT's User Defined Field #2
Set-ItemProperty "HKLM:\Software\CentraStage" -Name "Custom2" -Value "LOG4J Exploit Mitigation applied"