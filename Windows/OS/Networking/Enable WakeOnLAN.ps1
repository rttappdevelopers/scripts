# Requires dell.zip
# Requires -RunAsAdministrator


$hasWifi = "false"
function EnableAdapterWOL($id){
    $nic = Get-NetAdapter | ? {($_.MediaConnectionState -eq "Connected") -and (($_.name -match "Ethernet") -or ($_.name -match "local area connection"))}
    $nicPowerWake = Get-WmiObject MSPower_DeviceWakeEnable -Namespace root\wmi | where {$_.instancename -match [regex]::escape($id) }
    If ($nicPowerWake.Enable -eq $true)
    {
        write-output "Adapter WOL is already set to TRUE"
    }
    Else
    {
        write-output "Adapter WOL is FALSE. Setting to TRUE..."
        $nicPowerWake.Enable = $True
        $nicPowerWake.psbase.Put()
    }

    $nicMagicPacket = Get-WmiObject MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root\wmi | where {$_.instancename -match [regex]::escape($id) }
    If ($nicMagicPacket.EnableWakeOnMagicPacketOnly -eq $true)
    {
        write-output "Device's MagicPacket setting is already set to TRUE"
    }
    Else
    {
        write-output "Device's MagicPacket setting is FALSE. Setting to TRUE..."
        $nicMagicPacket.EnableWakeOnMagicPacketOnly = $True
        $nicMagicPacket.psbase.Put()
    }

    $FindEEELinkAd = Get-ChildItem "hklm:\SYSTEM\ControlSet001\Control\Class" -Recurse -ErrorAction SilentlyContinue | % {Get-ItemProperty $_.pspath} -ErrorAction SilentlyContinue | ? {$_.EEELinkAdvertisement} -ErrorAction SilentlyContinue
    If ($FindEEELinkAd.EEELinkAdvertisement -eq 1)
    {
        Set-ItemProperty -Path $FindEEELinkAd.PSPath -Name EEELinkAdvertisement -Value 0
        
        $FindEEELinkAd = Get-ChildItem "hklm:\SYSTEM\ControlSet001\Control\Class" -Recurse -ErrorAction SilentlyContinue | % {Get-ItemProperty $_.pspath} | ? {$_.EEELinkAdvertisement}
        If ($FindEEELinkAd.EEELinkAdvertisement -eq 1)
        {
            write-output "$($env:computername) - ERROR - EEELinkAdvertisement set to $($FindEEELinkAd.EEELinkAdvertisement)"
        }
        Else
        {
            write-output "$($env:computername) - SUCCESS - EEELinkAdvertisement set to $($FindEEELinkAd.EEELinkAdvertisement)"
        }
    }
    Else
    {
        write-output "EEELinkAdvertisement is already turned OFF"
    }



    If ((gwmi win32_operatingsystem).caption -match "Windows 8")
    {
        write-output "Windows 8.x detected. Disabling Fast Startup, as this breaks Wake On LAN..."
        powercfg -h off
    }
    ElseIf ((gwmi win32_operatingsystem).caption -match "Windows 10")
    {
        write-output "Windows 10 detected. Disabling Fast Startup, as this breaks Wake On LAN..."
        $FindHiberbootEnabled = Get-ItemProperty "hklm:\SYSTEM\CurrentControlSet\Control\Session?Manager\Power" -ErrorAction SilentlyContinue
        If ($FindHiberbootEnabled.HiberbootEnabled -eq 1)
        {
            write-output "HiberbootEnabled is Enabled. Setting to DISABLED..."
            Set-ItemProperty -Path $FindHiberbootEnabled.PSPath -Name "HiberbootEnabled" -Value 0 -Type DWORD -Force | Out-Null
        }
        Else
        {
            write-output "HiberbootEnabled is already DISABLED"
        }
    }
}

Function Get-DellBIOSProvider
{
    [CmdletBinding()]
    param()		
	If (!(Get-Module DellBIOSProvider -listavailable)) 
		{
            If (!(Get-PackageProvider -Name "NuGet" -listavailable)) 
		    {
                Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.206" -Force
            }
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
			Install-Module DellBIOSProvider -ErrorAction SilentlyContinue
			Write-Host -Message_Type "INFO" -Message "DellBIOSProvider has been installed"  			
		}
	Else
		{
			Import-Module DellBIOSProvider -ErrorAction SilentlyContinue
			Write-Host -Message_Type "INFO" -Message "DellBIOSProvider has been imported"  			
		}
}

function GetDellBiosCMD {
    Expand-Archive -Path "$(get-location)\dell.zip" -DestinationPath "$(get-location)" -Force
    $pf = "$(get-location)\dell\CCTK\X86\cctk.exe"
    if ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")
    {
        $pf = "$(get-location)\dell\CCTK\X86_64\cctk.exe"
    }
    return $pf
}

function EnableWOLDell {
    $cmd = GetDellBiosCMD
    Write-Host "Dell CCTK found at $cmd"
    Start-Process "$cmd" -ArgumentList "--wakeonlan=enable" -Wait -NoNewWindow
    Start-Process "$cmd" -ArgumentList "--deepsleepctrl=disable" -Wait -NoNewWindow
    if("$global:hasWifi" -eq "true"){
        Start-Process "$cmd" -ArgumentList "--wakeonlan=lanorwlan" -Wait -NoNewWindow
    }
}

function EnableWOLHP {
        $getHPBios = gwmi -class hp_biossettinginterface -Namespace "root\hp\instrumentedbios"
        $pow = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class hp_biosEnumeration | Where-Object { $_.Name -like 'S5 Maximum Power Savings' } | select Name, value
        $setting = $pow.Name
        Write-Host "Setting HP BIOS variable $setting to Disabled"
        $getHPBios.SetBIOSSetting($setting,"Disable")
        $wol = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class hp_biosEnumeration | Where-Object { $_.Name -like '*Wake on LAN' } | select Name, value
        $val = ""
        if($wol.value -match "Enable"){
            $val="Enable"
        }elseif($wol.value -match "Follow Boot Order"){
          $val="Follow Boot Order"
        }
        $setting = $wol.Name
        Write-Host "Setting HP BIOS variable $setting to $val"
        $getHPBios.SetBIOSSetting($setting,$val)
    }

function EnableWOLLenovo {
    $getLenovoBIOS = gwmi -class Lenovo_SetBiosSetting -namespace root\wmi
    $getLenovoBIOS.SetBiosSetting("WakeOnLAN,Enable")
    $SaveLenovoBIOS = (gwmi -class Lenovo_SaveBiosSettings -namespace root\wmi)
    $SaveLenovoBIOS.SaveBiosSettings()
}

function SetBIOSWOL {
    $board=Get-WmiObject -Class Win32_BaseBoard
    $company=$board.Manufacturer.toLower()
    Write-Host "BIOS Manufacturer has been detected as $company"
    if($company -eq "lenovo"){
       EnableWOLLenovo
    }elseif("$company" -eq "dell inc."){
        EnableWOLDell
    }elseif($company -eq "hp"){
        EnableWOLHP
    }elseif($company -eq "hewlett-packard"){
        EnableWOLHP
    
    }else{
       Write-Error "Cannot change Bios settings for Manufacturer $company as it has not been implemented in this script yet"
    }
}

function EnableWOL {
    Write-Host "Starting the WOL Enabler...."
    $nics = Get-NetAdapter -Name "*" -Physical
    ForEach($nic In $nics ){
        $name=$nic.InterfaceDescription
        $state = $nic.MediaConnectionState
        Write-Host "Checking Adapter $name"
        if("$state" -eq "Connected") {
            $dev_id = $nic.PNPDeviceID
            try {
                Write-Host "Processing Device ID: $dev_id"
                EnableAdapterWOL $dev_id
                Write-Host "Checking to see if the Network adapter is a Wifi adapter...."
                $mt = $nic.MediaType
                Write-Host "$mt"
                if("$mt" -like "*802.11*"){
                    Write-Host "This device is a wifi adpater"
                    $global:hasWifi = "true"
                }
            }catch {
                Write-Host "An error occurred:"
                Write-Host $_
            }
        }else{
            Write-Host "Skipping Adapter"
        }   
    }
}

EnableWOL
SetBIOSWOL
#Get-WmiObject -Class Win32_BIOS | Format-List *
