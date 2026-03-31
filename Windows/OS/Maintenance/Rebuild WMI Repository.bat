@ECHO OFF

REM Rebuild WMI Repository [WIN]
REM Use this to repair systems that fails to audit: the OS reflects Windows NT instead of the current OS version, policies don't apply, and the initial audit scripts don't run. The telltale sign that this is the issue is to run the PowerShell command 'Get-CimInstance Win32_operatingsystem' and see it fail.

REM Reference https://community.spiceworks.com/topic/36614-trouble-with-wmi
REM Audited and edited by Brad Brown to include output of log to STDOUT

Echo Rebuilding WMI.....Please wait. > c:\wmirebuild.log
ECHO Results will be located at c:\wmirebuild.log
net stop sharedaccess >> c:\wmirebuild.log
net stop winmgmt /y >> c:\wmirebuild.log
cd C:\WINDOWS\system32\wbem >> c:\wmirebuild.log
del /Q Repository >> c:\wmirebuild.log
c:
cd c:\windows\system32\wbem >> c:\wmirebuild.log
rd /S /Q repository >> c:\wmirebuild.log
regsvr32 /s %systemroot%\system32\scecli.dll >> c:\wmirebuild.log
regsvr32 /s %systemroot%\system32\userenv.dll >> c:\wmirebuild.log
mofcomp cimwin32.mof >> c:\wmirebuild.log
mofcomp cimwin32.mfl >> c:\wmirebuild.log
mofcomp rsop.mof >> c:\wmirebuild.log
mofcomp rsop.mfl >> c:\wmirebuild.log
for /f %%s in ('dir /b /s *.dll') do regsvr32 /s %%s >> c:\wmirebuild.log
for /f %%s in ('dir /b *.mof') do mofcomp %%s >> c:\wmirebuild.log
for /f %%s in ('dir /b *.mfl') do mofcomp %%s >> c:\wmirebuild.log
mofcomp exwmi.mof >> c:\wmirebuild.log
mofcomp -n:root\cimv2\applications\exchange wbemcons.mof >> c:\wmirebuild.log
mofcomp -n:root\cimv2\applications\exchange smtpcons.mof >> c:\wmirebuild.log
mofcomp exmgmt.mof >> c:\wmirebuild.log
net stop winmgmt >> c:\wmirebuild.log
net start winmgmt >> c:\wmirebuild.log
gpupdate /force >> c:\wmirebuild.log
type c:\wmirebuild.log