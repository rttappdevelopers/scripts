New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\ -Name MDM -force
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM -Name AutoEnrollMDM -Value 1 -force
 
start-sleep 30
& "$env:windir\system32\deviceEnroller.exe" /c /AutoEnrollMDM
 
