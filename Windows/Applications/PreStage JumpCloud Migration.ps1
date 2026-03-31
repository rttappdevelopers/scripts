# JumpCloud PreStage [WIN]
# This is the prestage for Jumpcloud.  It will unbimd from the domain if applicable.  Then it will work with the Profile Wiz component to automate the process.  You need to install the profile Wiz component before using this component
# Requires variable: JumpCloud_Key

New-Item "C:\Profile_Wiz\data\jumpcloud_migrate.txt" -ItemType File -Value $env:JumpCloud_Key
$arg_list = "/NOMIGRATE /NOJOIN /UNJOIN WORKGROUP /NOREBOOT"
$profwiz = Start-Process -FilePath "C:\Profile_Wiz\bin\Profwiz.exe" -ArgumentList $arg_list -wait -PassThru
Restart-Computer -Force