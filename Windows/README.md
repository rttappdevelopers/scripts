# Windows

## Scripts

Scripts are organized into subfolders by function. For guidance on downloading and running any script, see [HOWTO.md](../HOWTO.md).

### Applications

| Script | Description |
|---|---|
| [Cleanup Dell SupportAssist Snapshots.ps1](Applications/Cleanup%20Dell%20SupportAssist%20Snapshots.ps1) | Removes accumulated Dell SupportAssist snapshot files to recover disk space |
| [Cleanup MS Teams Cache.ps1](Applications/Cleanup%20MS%20Teams%20Cache.ps1) | Clears the Microsoft Teams local cache to resolve performance and login issues |
| [Cleanup Outlook OST Files.ps1](Applications/Cleanup%20Outlook%20OST%20Files.ps1) | Removes stale Outlook OST files for users no longer on the machine |
| [Cleanup QuickBooks Update Cache.ps1](Applications/Cleanup%20QuickBooks%20Update%20Cache.ps1) | Deletes cached QuickBooks update files |
| [Cleanup UniFi Controller MongoDB.bat](Applications/Cleanup%20UniFi%20Controller%20MongoDB.bat) | Shrinks the MongoDB database used by the UniFi controller |
| [Configure CCH Engagement SQL.bat](Applications/Configure%20CCH%20Engagement%20SQL.bat) | Configures SQL Server settings required for CCH Engagement |
| [Configure Chrome Updates.bat](Applications/Configure%20Chrome%20Updates.bat) | Configures Google Chrome update policy via registry |
| [Configure FortiClient VPN.ps1](Applications/Configure%20FortiClient%20VPN.ps1) | Deploys FortiClient VPN configuration |
| [Enable Outlook Meeting Copy.bat](Applications/Enable%20Outlook%20Meeting%20Copy.bat) | Enables the copy-to-calendar feature for Outlook meeting responses |
| [Get Application Version.ps1](Applications/Get%20Application%20Version.ps1) | Reports the installed version of a specified application |
| [Get Datto Cloud Continuity Logs.ps1](Applications/Get%20Datto%20Cloud%20Continuity%20Logs.ps1) | Retrieves Datto Cloud Continuity agent logs for diagnostics |
| [Install AnyConnect.bat](Applications/Install%20AnyConnect.bat) | Installs Cisco AnyConnect VPN client |
| [Install AnyDesk.ps1](Applications/Install%20AnyDesk.ps1) | Silently installs AnyDesk remote access |
| [Install BitDefender GravityZone.ps1](Applications/Install%20BitDefender%20GravityZone.ps1) | Installs the BitDefender GravityZone endpoint agent |
| [Install ConnectSecure Agent.ps1](Applications/Install%20ConnectSecure%20Agent.ps1) | Installs the ConnectSecure (CyberCNS) vulnerability scanning agent |
| [Install Datto Endpoint Backup.ps1](Applications/Install%20Datto%20Endpoint%20Backup.ps1) | Installs the Datto Endpoint Backup for PCs agent |
| [Install Dialpad.ps1](Applications/Install%20Dialpad.ps1) | Silently installs the Dialpad softphone client |
| [Install Dropbox.ps1](Applications/Install%20Dropbox.ps1) | Silently installs Dropbox |
| [Install Google Drive File Stream.ps1](Applications/Install%20Google%20Drive%20File%20Stream.ps1) | Installs Google Drive for Desktop |
| [Install JumpCloud Agent.ps1](Applications/Install%20JumpCloud%20Agent.ps1) | Installs the JumpCloud directory agent using a connect key |
| [Install MSI Package.ps1](Applications/Install%20MSI%20Package.ps1) | Generic silent MSI installer — accepts path or URL and optional install arguments |
| [Install NordLayer VPN.ps1](Applications/Install%20NordLayer%20VPN.ps1) | Installs the NordLayer business VPN client |
| [Install PowerShell.bat](Applications/Install%20PowerShell.bat) | Installs PowerShell 7 via winget |
| [Install Splashtop SOS.ps1](Applications/Install%20Splashtop%20SOS.ps1) | Installs Splashtop SOS remote support client |
| [PreStage JumpCloud Migration.ps1](Applications/PreStage%20JumpCloud%20Migration.ps1) | Prepares a device for JumpCloud migration before agent installation |
| [Remove Dell OEM Software.ps1](Applications/Remove%20Dell%20OEM%20Software.ps1) | Removes Dell bloatware and OEM preinstalled applications |
| [Remove HP Bloatware.ps1](Applications/Remove%20HP%20Bloatware.ps1) | Removes HP bloatware and OEM preinstalled applications |
| [Remove HP Wolf Security.vbs](Applications/Remove%20HP%20Wolf%20Security.vbs) | Removes HP Wolf Security when the standard uninstaller fails |
| [Remove Unwanted UWP Apps.ps1](Applications/Remove%20Unwanted%20UWP%20Apps.ps1) | Removes a configurable list of built-in Windows UWP apps |
| [Repair Microsoft Defender.ps1](Applications/Repair%20Microsoft%20Defender.ps1) | Re-registers and repairs a broken Microsoft Defender installation |
| [Start JumpCloud Migration.ps1](Applications/Start%20JumpCloud%20Migration.ps1) | Executes the JumpCloud migration workflow after prestaging |
| [Uninstall AnyDesk.ps1](Applications/Uninstall%20AnyDesk.ps1) | Silently uninstalls AnyDesk |
| [Uninstall ConnectWise.ps1](Applications/Uninstall%20ConnectWise.ps1) | Removes ConnectWise Manage or ConnectWise Control agent |
| [Uninstall Datto RMM Agent.bat](Applications/Uninstall%20Datto%20RMM%20Agent.bat) | Uninstalls the Datto RMM (formerly Autotask) agent |
| [Uninstall Dropbox.ps1](Applications/Uninstall%20Dropbox.ps1) | Silently uninstalls Dropbox |
| [Uninstall ESET Antivirus.bat](Applications/Uninstall%20ESET%20Antivirus.bat) | Removes ESET endpoint antivirus |
| [Uninstall Huntress.bat](Applications/Uninstall%20Huntress.bat) | Removes the Huntress agent |
| [Uninstall Malwarebytes.ps1](Applications/Uninstall%20Malwarebytes.ps1) | Silently uninstalls Malwarebytes |
| [Uninstall Out-N-About.bat](Applications/Uninstall%20Out-N-About.bat) | Removes Out-N-About time tracking software |
| [Uninstall Sage Timeslips.bat](Applications/Uninstall%20Sage%20Timeslips.bat) | Removes Sage Timeslips |
| [Uninstall SonicWall Global VPN.ps1](Applications/Uninstall%20SonicWall%20Global%20VPN.ps1) | Silently uninstalls the SonicWall Global VPN client |
| [Uninstall Sophos Endpoint.ps1](Applications/Uninstall%20Sophos%20Endpoint.ps1) | Removes Sophos Endpoint using the Sophos uninstaller |
| [Uninstall Webroot.bat](Applications/Uninstall%20Webroot.bat) | Removes the Webroot SecureAnywhere agent |

### CVE Mitigations

| Script | Description |
|---|---|
| [Detect CVE FireEye Compromise.ps1](CVE%20Mitigations/Detect%20CVE%20FireEye%20Compromise.ps1) | Checks for indicators of the FireEye/SolarWinds supply chain compromise |
| [Mitigate CVE-2020-1350 DNS.bat](CVE%20Mitigations/Mitigate%20CVE-2020-1350%20DNS.bat) | Applies the registry workaround for the Windows DNS Server SIGRed vulnerability |
| [Mitigate CVE-2021-3922 Lenovo.ps1](CVE%20Mitigations/Mitigate%20CVE-2021-3922%20Lenovo.ps1) | Applies mitigation for the Lenovo ImController privilege escalation vulnerability |
| [Mitigate CVE-2022-30190 Follina.ps1](CVE%20Mitigations/Mitigate%20CVE-2022-30190%20Follina.ps1) | Disables the MSDT URL protocol handler to mitigate the Follina vulnerability |
| [Mitigate Log4j APC PowerChute.ps1](CVE%20Mitigations/Mitigate%20Log4j%20APC%20PowerChute.ps1) | Applies Log4Shell mitigation specific to APC PowerChute Business Edition |
| [Mitigate Log4j Lookups.ps1](CVE%20Mitigations/Mitigate%20Log4j%20Lookups.ps1) | Disables Log4j JNDI lookups system-wide to mitigate Log4Shell |

### OS — Maintenance

| Script | Description |
|---|---|
| [Audit RMM Group Policies.ps1](OS/Maintenance/Audit%20RMM%20Group%20Policies.ps1) | Reports GPOs deployed by RMM tooling to identify conflicts or stale policies |
| [Cleanup Driver Cache.ps1](OS/Maintenance/Cleanup%20Driver%20Cache.ps1) | Removes old cached driver packages from the driver store |
| [Cleanup Intune MSI Cache.ps1](OS/Maintenance/Cleanup%20Intune%20MSI%20Cache.ps1) | Clears the Intune cached MSI installer files |
| [Cleanup Old Drivers.ps1](OS/Maintenance/Cleanup%20Old%20Drivers.ps1) | Removes outdated third-party drivers from the system |
| [Cleanup Old Windows Versions.bat](OS/Maintenance/Cleanup%20Old%20Windows%20Versions.bat) | Removes Windows.old and other old OS installation folders |
| [Cleanup Windows Components.ps1](OS/Maintenance/Cleanup%20Windows%20Components.ps1) | Runs DISM component store cleanup |
| [Cleanup Windows Patches.ps1](OS/Maintenance/Cleanup%20Windows%20Patches.ps1) | Removes superseded Windows update packages |
| [Cleanup Windows Update Cache.ps1](OS/Maintenance/Cleanup%20Windows%20Update%20Cache.ps1) | Clears the Windows Update download cache (SoftwareDistribution folder) |
| [Disable Windows Welcome Experience.bat](OS/Maintenance/Disable%20Windows%20Welcome%20Experience.bat) | Suppresses the Windows Welcome Experience screen shown after updates |
| [Install Hotfix PrintNightmare.bat](OS/Maintenance/Install%20Hotfix%20PrintNightmare.bat) | Applies the PrintNightmare security hotfix |
| [Install Windows Product Key.bat](OS/Maintenance/Install%20Windows%20Product%20Key.bat) | Activates Windows with a provided product key |
| [Rebuild Windows Search Index.ps1](OS/Maintenance/Rebuild%20Windows%20Search%20Index.ps1) | Rebuilds the Windows Search index from scratch |
| [Rebuild WMI Repository.bat](OS/Maintenance/Rebuild%20WMI%20Repository.bat) | Stops WMI, verifies the repository, and rebuilds if corrupt |
| [Remove Windows Hotfix.ps1](OS/Maintenance/Remove%20Windows%20Hotfix.ps1) | Uninstalls a specific Windows update by KB number |
| [Scan and Repair Windows.bat](OS/Maintenance/Scan%20and%20Repair%20Windows.bat) | Runs SFC and DISM to scan and repair Windows system files |
| [Schedule Check Disk.bat](OS/Maintenance/Schedule%20Check%20Disk.bat) | Schedules a chkdsk run on next reboot |
| [Set Windows License Key.ps1](OS/Maintenance/Set%20Windows%20License%20Key.ps1) | Sets and activates a Windows license key via PowerShell |

### OS — Migration

| Script | Description |
|---|---|
| [Enroll Device in Intune.ps1](OS/Migration/Enroll%20Device%20in%20Intune.ps1) | Triggers Intune MDM enrollment on a device |
| [PreStage Entra ID Migration.ps1](OS/Migration/PreStage%20Entra%20ID%20Migration.ps1) | Prepares a device for Entra ID join by installing prerequisites and configuring settings |
| [Run Profile Migration Wizard.ps1](OS/Migration/Run%20Profile%20Migration%20Wizard.ps1) | Launches the User State Migration Tool or profile migration wizard |

### OS — Networking

| Script | Description |
|---|---|
| [Disable Offline Files.ps1](OS/Networking/Disable%20Offline%20Files.ps1) | Disables the Windows Offline Files feature |
| [Enable WakeOnLAN.ps1](OS/Networking/Enable%20WakeOnLAN.ps1) | Enables Wake-on-LAN for the active network adapter |
| [Get Mapped Network Drives.ps1](OS/Networking/Get%20Mapped%20Network%20Drives.ps1) | Reports all mapped network drives for all user profiles on the machine |
| [Get Network Name.ps1](OS/Networking/Get%20Network%20Name.ps1) | Retrieves the network profile name shown in Windows |
| [Set Mapped Network Drive.bat](OS/Networking/Set%20Mapped%20Network%20Drive.bat) | Maps a network drive persistently for a specified user |
| [Sync Time to NTP.bat](OS/Networking/Sync%20Time%20to%20NTP.bat) | Forces a time sync against a specified NTP server |

### OS — Reporting

| Script | Description |
|---|---|
| [Audit Server Environment.ps1](OS/Reporting/Audit%20Server%20Environment.ps1) | Inventories a server's OS, roles, hardware, and configuration |
| [Capture Webcam Image.ps1](OS/Reporting/Capture%20Webcam%20Image.ps1) | Captures a still image from the device webcam (for asset verification or theft recovery) |
| [Check Windows 11 Upgrade Capability.ps1](OS/Reporting/Check%20Windows%2011%20Upgrade%20Capability.ps1) | Checks whether the device meets Windows 11 hardware requirements |
| [Get Disk SMART Status.bat](OS/Reporting/Get%20Disk%20SMART%20Status.bat) | Reports SMART health status for all physical drives |
| [Get Files by Type.ps1](OS/Reporting/Get%20Files%20by%20Type.ps1) | Searches a path for files matching a specified extension |
| [Get Folder Sizes.ps1](OS/Reporting/Get%20Folder%20Sizes.ps1) | Reports disk usage by folder under a specified root path |
| [Get Group Policies.ps1](OS/Reporting/Get%20Group%20Policies.ps1) | Reports all GPOs applied to the device |
| [Get Installed Printers.ps1](OS/Reporting/Get%20Installed%20Printers.ps1) | Lists all installed printers and their port/driver details |
| [Get Log File Contents.bat](OS/Reporting/Get%20Log%20File%20Contents.bat) | Reads and outputs the contents of a specified log file |
| [Get Services by Logon Account.ps1](OS/Reporting/Get%20Services%20by%20Logon%20Account.ps1) | Reports all services configured to run as a specific user account |
| [Get Share Permissions.ps1](OS/Reporting/Get%20Share%20Permissions.ps1) | Reports share and NTFS permissions for all shared folders on the machine |
| [Get Windows License Info.ps1](OS/Reporting/Get%20Windows%20License%20Info.ps1) | Reports Windows activation status and license key details |
| [Get Windows Update Log.ps1](OS/Reporting/Get%20Windows%20Update%20Log.ps1) | Converts and exports the Windows Update ETL log to a readable format |

### OS — Security

| Script | Description |
|---|---|
| [Audit Local Admin Users.ps1](OS/Security/Audit%20Local%20Admin%20Users.ps1) | Reports all members of the local Administrators group |
| [Disable Cached Domain Credentials.bat](OS/Security/Disable%20Cached%20Domain%20Credentials.bat) | Sets the registry value to disable cached domain credential storage |
| [Disable SMB Guest Logon.ps1](OS/Security/Disable%20SMB%20Guest%20Logon.ps1) | Disables SMB guest access on the machine |
| [Enable BitLocker.ps1](OS/Security/Enable%20BitLocker.ps1) | Enables BitLocker encryption on the system drive and stores the recovery key |
| [Enable Cached Domain Credentials.bat](OS/Security/Enable%20Cached%20Domain%20Credentials.bat) | Restores cached domain credential storage (reverses the disable) |
| [Enable SMB Guest Logon.ps1](OS/Security/Enable%20SMB%20Guest%20Logon.ps1) | Re-enables SMB guest access (use with caution) |
| [Enable UAC.bat](OS/Security/Enable%20UAC.bat) | Re-enables User Account Control via registry |
| [Get BitLocker Key.ps1](OS/Security/Get%20BitLocker%20Key.ps1) | Retrieves the BitLocker recovery key for the system drive |
| [Set Execution Policy.ps1](OS/Security/Set%20Execution%20Policy.ps1) | Sets the PowerShell execution policy for the machine or current user |

### OS — User Management

| Script | Description |
|---|---|
| [Audit User Profiles.ps1](OS/User%20Management/Audit%20User%20Profiles.ps1) | Reports all user profiles on the machine with last logon and size |
| [Cleanup User Profiles.ps1](OS/User%20Management/Cleanup%20User%20Profiles.ps1) | Removes stale or inactive user profiles based on age or last logon |
| [Create Admin User.bat](OS/User%20Management/Create%20Admin%20User.bat) | Creates a local administrator account |
| [Create User with Random Password.ps1](OS/User%20Management/Create%20User%20with%20Random%20Password.ps1) | Creates a local user account with a randomly generated password |
| [Delete User Profile.ps1](OS/User%20Management/Delete%20User%20Profile.ps1) | Permanently deletes a specific user profile from the machine |
| [Promote User to Local Admin.ps1](OS/User%20Management/Promote%20User%20to%20Local%20Admin.ps1) | Adds an existing user to the local Administrators group |
| [Reset Admin Password.bat](OS/User%20Management/Reset%20Admin%20Password.bat) | Resets the local Administrator account password |
| [Set Local Username.bat](OS/User%20Management/Set%20Local%20Username.bat) | Renames a local user account |

---

## Command Reference

These are commands that one may find useful on Windows workstations and servers. The commands are a mix of DOS/CMD and PowerShell. The easiest way to tell them apart is that DOS commands will be in all capital letters, PowerShell will be mixed-case.

Many of these commands require an elevated command prompt or PowerShell terminal; run as Administrator. Note that any DOS command can be run in PowerShell, but PowerShell can't be run in the DOS command prompt without calling the PowerShell interpreter. If you are working from the DOS command prompt, you can run simple Powershell commands that don't include quotations using the exmaple below:
`powershell -c "Get-Volume C"`

Any text after a # in an example is a remark or comment, which explains what the command does.

<!-- TOC -->

- [About](#about)
- [Filesystem Operations](#filesystem-operations)
    - [Directories](#directories)
    - [Common locations and their aliases](#common-locations-and-their-aliases)
    - [File operations](#file-operations)
    - [Disks and drives](#disks-and-drives)
- [System Functions](#system-functions)
    - [Operating System Info](#operating-system-info)
    - [Run a command](#run-a-command)
    - [Operations](#operations)
    - [Services](#services)
    - [Process list](#process-list)
    - [Kill](#kill)
    - [Aliases](#aliases)
    - [Connected devices**](#connected-devices)
- [Network](#network)
    - [LAN IP](#lan-ip)
    - [WAN IP](#wan-ip)
    - [Domain Name Lookup and DNS Records](#domain-name-lookup-and-dns-records)
    - [Who owns an IP or domain](#who-owns-an-ip-or-domain)
    - [Where is an IP from](#where-is-an-ip-from)
    - [Who is on the network, are they reachable?](#who-is-on-the-network-are-they-reachable)
    - [Remote Command Line](#remote-command-line)
    - [Get Files from the Internet](#get-files-from-the-internet)
- [User functions](#user-functions)
    - [Who am I](#who-am-i)
    - [Who is signed in](#who-is-signed-in)
    - [Change password](#change-password)
    - [List users and groups](#list-users-and-groups)
    - [Group Policy](#group-policy)
- [References](#references)

<!-- /TOC -->

# Filesystem Operations
##	Directories
**Change Directory**
```bat
CD \                    # Go to root directory of current drive
CD ..                   # Go back one directory
CD ..\..                # Layered to go back two directories
CD C:\Temp\             # Change directory to the Temp folder on the C: drive
CD "C:\Program Files\"  # Changing to a directory with spaces in the name requires quotes
```
**Print working directory**

**List Files**

## Common locations and their aliases
To use these: %AppData% is the current user's full path to their appdata folder;
*e.g.: CD %AppData% = CD C:\Users\username\AppData\Roaming*

- %AllUsersProfile% - Open the All User's Profile C:\ProgramData
- %AppData% - Opens AppData folder C:\Users\{username}\AppData\Roaming
- %CommonProgramFiles% - C:\Program Files\Common Files
- %CommonProgramFiles(x86)% - C:\Program Files (x86)\Common Files
- %HomeDrive% - Opens your home drive C:\
- %LocalAppData% - Opens local AppData folder C:\Users\{username}\AppData\Local
- %ProgramData% - C:\ProgramData
- %ProgramFiles% - C:\Program Files or C:\Program Files (x86)
- %ProgramFiles(x86)% - C:\Program Files (x86)
- %Public% - C:\Users\Public
- %SystemDrive% - C:
- %SystemRoot% - Opens Windows folder C:\Windows
- %Temp% - Opens temporary file Folder C:\Users\{Username}\AppData\Local\Temp
- %UserProfile% - Opens your user's profile C:\Users\{username}
- %AppData%\Microsoft\Windows\Start Menu\Programs\Startup - Opens Windows 10 Startup location for program shortcuts
- ~ - In PowerShell, the tilde can be used as the user's home director, just like in Linux: CD ~

## File operations
**View file contents**

**Find**

**Edit**

**Symbolic Links**
Junctions and Hard Links

**Folders**
```powershell
# Get folder size
(Get-ChildItem C:\Users\username\Downloads | measure Length -s).sum /1GB
```

##	Disks and drives
**Disks and partitions**
```cmd
C:         # Enter drive letter and colon to change drive
FORMAT D:  # Format disk
FDISK
DISKPART
```

**Filesystem and OS image repair**
```cmd
DISM.exe /Online /Cleanup-image /Restorehealth  # Deployment Image Service and Management Tool
sfc /scannow        # Scans and repairs corrupted system files
echo y | chkdsk /r  # Perform offline checkdisk at next boot, assume yes
```

**Get checkdisk results**
```powershell
get-winevent -FilterHashTable @{logname="Application"; id="1001"}| ?{$_.providername –match "wininit"} | Select-Object -first 1 | fl timecreated, message
```

**Disk SMART Status**
```powershell
wmic diskdrive get status  # Get SMART status for each drive
wmic /namespace:\\root\wmi path MSStorageDriver_FailurePredictStatus  # Check for predicted failure of disk
```

# System Functions
## Operating System Info
```powershell
get-timezone | Select-Object DisplayName  # Get Time Zone
```

##	Run a command
##	Operations
```powershell
Get-CimInstance -ClassName win32_operatingsystem | select csname, lastbootuptime  # Get system uptime
shutdown -r -t 0  # Reboot now (wait time is zero seconds)
```

## Services
```powershell
# Get-Service commandlet
Get-Service {service}                        # Get service status, by name with quotes or alias
Get-Service {service} | Restart-Service      # Restart the service

# WMI methods
Get-WmiObject -Class Win32_Service -Filter "Name='ServiceName'"             # Get service info
(Get-WmiObject -Class Win32_Service -Filter "Name='ServiceName'").delete()  # Delete service
```

```cmd
# CMD / DOS batch methods
net start                                    # Show all running services
sc query {service}                           # Get info on a service
sc queryex {service}                         # Get extended info
sc [stop/start/restart/delete] {service}     # Control service state
```
References: 
* https://ss64.com/nt/sc.html
* https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-query

##	Process list
```powershell
get-process                                   # List all processes
get-process -Name "Notepad"                   # Get processes named Notepad
get-process -Name "*notepad*"                 # Get process info for applications with Notepad in their name
```

##	Kill
```powershell
Stop-Process 26152                            # Kill the process with ID #26152, identified above with get-process
Stop-Process -Name "Notepad"                  # Kill the processes named Notepad
get-process -Name "*notepad*" | Stop-Process  # Get and kill the processes with Notepad in their name
```

##	Aliases

## Connected devices**

# Network
## LAN IP
## WAN IP
## Domain Name Lookup and DNS Records
## Who owns an IP or domain
## Where is an IP from
## Who is on the network, are they reachable?
## Remote Command Line
## Get Files from the Internet
```powershell
Start-BitsTransfer -Source {URL}
```

# User functions
##	Who am I
```bat
WHOAMI  # Get current sername, presented as authentication source and username
        # COMPTUERNAME\USER, or DOMAIN\USER
```

##	Who is signed in
##	Change password
```bat
NET USER [username] [password]
```

##	List users and groups
##	Group Policy

# References
- https://superuser.com/questions/217504/is-there-a-list-of-windows-special-directories-shortcuts-like-temp