# Changelog

All notable changes to this repository are documented here. Entries are grouped by date where commit history allows, otherwise by theme.

---

## [Unreleased] — 2026-03-31

### Repository restructure and documentation
- Renamed ~100 scripts to the `Action Product.ext` naming convention
- Renamed `Office 365/` folder to `Microsoft 365/`
- Reorganized `Windows/` into subfolders: `Applications/`, `CVE Mitigations/`, `OS/Maintenance/`, `OS/Migration/`, `OS/Networking/`, `OS/Reporting/`, `OS/Security/`, `OS/User Management/`
- Reorganized `Mac/` into subfolders: `Applications/`, `OS/`, `Security/`
- Reorganized `Linux/` into subfolders: `Agents/`, `Tools/`
- Reorganized `Microsoft 365/` into subfolders: `Entra ID/`, `Exchange Online/`, `Reporting/`, `Security and Compliance/`
- Removed duplicate and superseded scripts (7 files deleted)
- Replaced all EOL `MSOnline` and `AzureAD` cmdlets with `Microsoft.Graph` equivalents across M365 scripts
- Added `HOWTO.md` — guide for finding, downloading, and running scripts
- Added `SECURITY.md` — credential policy and responsible disclosure
- Added `CONTRIBUTING.md` — naming convention, script structure standards, no-secrets checklist, submission process
- Rewrote root `README.md`; added script index tables to all folder READMEs
- Updated `.github/copilot-instructions.md` with naming schema, folder structure, and README maintenance rules

---

## 2026-03-04

### Mac — Install Huntress Agent
- Synced `Install Huntress Agent.sh` from Huntress' GitHub repository (3/4/2026)
- Added reinstall support and network extension auto-install
- Retained NinjaOne RMM custom field support from prior version (`c70a2d7`, `607c817`)

---

## 2026-03

### Mac — Detect MDM Enrollment
- New script: detects MDM enrollment across Mosyle, NinjaOne MDM, Apple Business Essentials, and other platforms (`6fabff6`)
- Improved Apple Business Essentials detection logic (`ad8894e`)

### Windows — Get Windows License Info
- New script: reports Windows activation status and license key details (`a0fb1e6`)

### Windows — Set Windows License Key
- Switched from `.exe` to `.vbs` invocation for broader system compatibility (`5fe6373`)
- Initial version added (`598d8d5`)

### Datto — Uninstall Datto Endpoint Backup
- New script: silently uninstalls the Datto Endpoint Backup for PCs agent (`3c6991a`)

---

## 2026-02

### Microsoft 365 — Authentication overhaul (all scripts)
- Required PowerShell 7 across all M365 scripts with a clear error and download link if running on 5.1 (`b22b3ab`)
- Fixed auth: replaced `-Device` flag (PS7-only) with `-DisableWAM` for PowerShell 5.1 compatibility (`47210b5`)
- Fixed WAM window handle error: switched to device code flow across all M365 scripts (`c696690`)
- Fixed module install failure on machines with outdated `PowerShellGet` (`fc4bda5`)

### Microsoft 365 — Get MFA Status Report
- Retooled from EOL `MSOnline` cmdlets to `Microsoft.Graph`; significantly expanded output (`91854c0`)

### Microsoft 365 — Configure AppRiver Inbound Limit
- Added user prompt for additional IPs and automatic conversion to `/32` subnets (`ac554fe`)
- Fixed module install reliability (`fc4bda5`)

### Microsoft 365 — Download Message Trace Reports / Fix Message Trace Encoding
- Improved M365 output parsing and CSV encoding handling (`07b5961`)

---

## 2025 and earlier

### Microsoft 365 — Exchange Online
- Added `Add Users to Distribution List` script (`b649bfc`)
- Added `Create Contacts from CSV` script (`ac48afb`)
- Added `Get Message Trace` script (`f0402d7`)
- Added `Download Message Trace Reports` and `Fix Message Trace Encoding` scripts (`c0d2d54`, `d656706`)
- Updated `Get Mailbox Rules and Forwards` to include console output in addition to CSV (`292ffee`)
- Added `Get Mailbox Usage` script — iterated through multiple versions (`2dd713c`, `954fb2a`, `c7b1bd1`, `0516e3b`, `d8a2adc`)
- Added `Import AppRiver Users` script; converted from deprecated component to EXO (`bc31cda`)
- Added `Configure AppRiver Bypass Filtering` script (`2b69cc8`, `3de7cf4`)
- Added `Configure AppRiver Inbound Limit` script (`dc6d59d`)
- Added `Configure Defendify Phishing Simulation` script
- Added `Configure Phinsec Phishing Simulation` script — iterated through multiple versions (`1973ca6`, `46d03b0`, `66e4ab9`, `62ab64c`)
- Added `Get Immutable ID` script

### Windows — Applications
- Added `Repair Microsoft Defender` script (`9bca5bb`)
- Added `Install ConnectSecure Agent` script (`d1fb311`, `992ece4`)
- Added `Remove Unwanted UWP Apps` script — expanded UWP list to include preinstalled Office apps (`221e78f`)
- Added `Get Application Version` script; updated for NinjaOne custom field output (`3faa957`, `7a6d89d`)
- Added `Install AnyDesk` and `Uninstall AnyDesk` scripts (`8d6f7b3`)
- Added `Install Dropbox` and `Uninstall Dropbox` scripts (`7b93d1f`)
- Added `Install AnyConnect` script (`08b4cb7`)
- Added `Install Splashtop SOS` script (`7f1838d`)
- Added `Remove Dell OEM Software` script (`87e17b0`)
- Added `Uninstall Sophos Endpoint` script (`9da8337`)
- Added `Uninstall Webroot` script (`de45195`)

### Windows — OS
- Added `Enable BitLocker` script (`300c880`)
- Added `Get BitLocker Key` script; secured key from stdout (`726585f`, `e8e818c`)
- Added `Get Share Permissions` script (`fc1a8ec`)
- Added `Get Files by Type` script (`0138f68`)
- Added `Audit RMM Group Policies` script (`eea6efe`)
- Added `Promote User to Local Admin` script (`5109d19`, `c048319`)
- Added `Audit Local Admin Users` script — added NinjaOne output (`0a546bd`)
- Added `Disable Offline Files`, `Sync Time to NTP`, `Cleanup Old Windows Versions` scripts (`b3ce1aa`)
- Added `Cleanup Intune MSI Cache` script (`afdcf31`)
- Added `Schedule Check Disk`, disk management, and scan/repair scripts (`fd659cb`)
- Added `Cleanup Driver Cache` and `Cleanup Old Drivers` scripts (`17d5f84`)
- Added `Rebuild Windows Search Index` script
- Added `Rebuild WMI Repository` script

### Mac
- Added `Install BitDefender GravityZone` script (`00ec129`, `9bbd3fa`)
- Added `Install ConnectSecure Agent` script (`d1fb311`)
- Added `Create Admin User` script (`3bd155f`, `9c9a665`)
- Added `Create Desktop Shortcut` script (`ef3197e`)
- Added `Get FileVault Status` and `Get FileVault Key` scripts
- Added `Audit Admin Users` script (`381cb90`)

### Linux
- Added `Install ConnectSecure Agent` script — added agent/curl pre-checks (`0ef5ee2`, `9410a90`, `7f01f8b`)
- Added `Get GeoIP Location` script (`b8d950c`)
- Added `Ping IP Addresses` script (`b3ce1aa`)
- Added `Scan MX Records` script (`37d3c0b`)
- Added `Scan VPN Connections` script (`f8930dc`)
- Added `Download File List` script
- Expanded `Linux/README.md` command reference (`4dfa860` and others)

### RMM
- Added `Set Organization UDF from Hostname` script (`b3ce1aa`)
- Added `Reinstall NinjaRMM Agent` script

### Datto
- Added `SaaS Protection Bulk Seat Change` (Python) script — initial draft (`a1784ab`)

### IT Glue
- Added `Format Import Template` Python script (`895d0d0`)
- Added `Download IT Glue Export` script

### Misc
- Added `Generate Huntress Site Key` Python script — moved from `_Customer/` to `Misc/` (`e3d7a8d`, `7b2f545`, `b4f1691`)

### Repository maintenance
- Added `.github/copilot-instructions.md` with AI agent framework (`ebb3d5a`)
- Expanded `.gitignore` to cover common OS and IDE files (`fb694ba`, `b8e3c61`)
