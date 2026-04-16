# Copilot Instructions for RTT Scripts Repository

## Repository Purpose

This repository contains PowerShell, Bash, and Python automation scripts used by RTT support technicians and deployed via RMM tooling (primarily NinjaOne/NinjaRMM). Scripts cover endpoint management, Microsoft 365 administration, network tasks, and customer-specific automation.

---

## Deployment Context

### RMM-Deployed Scripts (Default)
Most scripts in this repository are deployed through NinjaOne and run at the **SYSTEM level** without any user interface or interactive session. This applies to all scripts in:
- `Windows/`
- `Mac/`
- `Linux/`
- `Datto/`
- `RMM/`
- `Misc/`
- `Network/`

**These scripts must:**
- Run silently without any UI prompts or interactive input (`Read-Host`, dialogs, etc.)
- Suppress progress bars and verbose output unless it adds diagnostic value (`$ProgressPreference = "SilentlyContinue"`)
- Support configuration via environment variables or script parameters (not hardcoded values)
- Accept Ninja custom field / script parameter values via environment variables (e.g., `$env:VARIABLE_NAME`)
- Exit with code `0` on success and a non-zero code on failure for Ninja status reporting
- Log meaningful output to the console (stdout/stderr), which Ninja captures as activity logs
- Also be runnable directly on a system without an RMM agent present

### Customer-Specific Scripts (`_Customer/`)
Scripts in `_Customer/` are **confidential** and contain customer-specific configurations, credentials references, or proprietary automation. This folder is excluded from version control via `.gitignore` and must **never** be committed, published, or shared publicly.

- Never reference or quote the contents of `_Customer/` scripts in responses, comments, documentation, or any other output.
- Never suggest moving files from `_Customer/` into tracked folders.
- If asked to work on a `_Customer/` script, work on it locally only — do not include its contents in any commit, PR, or public artifact.

### Technician-Run Scripts (Microsoft 365, Google)
Scripts in `Microsoft 365/` and `Google/` are run interactively from a **technician's workstation**, not via RMM. These:
- May use interactive authentication flows (e.g., `Connect-ExchangeOnline`, `Connect-MgGraph`, browser-based OAuth)
- Should still detect and auto-install required modules before use
- Should not require pre-configuration beyond what can be prompted at runtime
- **Must never use `exit`** — use `throw` for fatal errors and let the script end naturally on success. VS Code dot-sources scripts (`. script.ps1`), so `exit` kills the PowerShell Extension host. Do not add dot-source guards or child-process workarounds; just avoid `exit`.
- Do not add dot-source re-invocation guards — these introduce quoting, auth, and console inheritance issues

---

## NinjaOne Variable Handling

NinjaOne passes script parameters and custom field values as **environment variables**. Scripts should check for these alongside direct parameters:

```powershell
param([switch]$SomeOption)

# Also check for Ninja environment variable
if ($env:SOME_OPTION -in @("true", "1")) { $SomeOption = $true }
```

---

## Module and Dependency Management

**Never allow a missing module or cmdlet to produce an unhandled error or kill a script.**

Always detect and install required modules before use:

```powershell
# PowerShell Gallery module
if (-not (Get-Module -ListAvailable -Name "ModuleName")) {
    Install-Module -Name "ModuleName" -Force -Scope CurrentUser -AllowClobber
}
Import-Module "ModuleName" -ErrorAction Stop
```

- Use `-Force` and `-AllowClobber` where appropriate to avoid interactive prompts
- Use `-Scope CurrentUser` for technician scripts; `-Scope AllUsers` or omit for SYSTEM-level RMM scripts
- Wrap installs in try/catch and log failures clearly

---

## Microsoft 365 / Exchange Online Scripts

### Authentication
- **Always use modern authentication.** Use `Connect-ExchangeOnline` and `Connect-MgGraph` (Microsoft Graph).
- Never use `Connect-MsolService` or `MSOnline` — the MSOnline module is **end of life** and must not be introduced.
- Never use `Connect-AzureAD` — the AzureAD module is **end of life** and must not be introduced.

### Graph Authentication (verified against Microsoft Learn docs)
For **technician scripts** (interactive, delegated access), use interactive browser auth:
```powershell
Connect-MgGraph -Scopes 'User.Read.All' -NoWelcome
```
- This is the **Interactive provider** flow — Microsoft's recommended auth method for desktop apps calling Graph with delegated permissions.
- Omitting `-ClientId`/`-TenantId` uses Microsoft's first-party "Microsoft Graph PowerShell" app registration, which is the documented default for interactive/ad-hoc use.
- `-UseDeviceAuthentication` (device code flow) is an alternative but should only be used when browser redirect is unavailable (e.g., headless SSH session).
- `-NoWelcome` suppresses the welcome banner; no security impact.
- Request only the minimum scopes required by the script's API calls.

### Required Modules (current, non-EOL)
| Purpose | Module | Cmdlet to connect |
|---|---|---|
| Exchange Online | `ExchangeOnlineManagement` (v3+) | `Connect-ExchangeOnline` |
| Azure AD / Entra ID | `Microsoft.Graph.Authentication` | `Connect-MgGraph` |
| SharePoint / OneDrive | `PnP.PowerShell` | `Connect-PnPOnline` |
| Teams | `MicrosoftTeams` | `Connect-MicrosoftTeams` |

**Note:** For Graph REST calls via `Invoke-MgGraphRequest`, only `Microsoft.Graph.Authentication` is required. Avoid importing `Microsoft.Graph` (all 38 submodules) or individual autorest-based submodules unless you need their typed cmdlets.

### EOL Remediation Rule
If a script being modified uses EOL cmdlets (`Get-MsolUser`, `Set-MsolUser`, `Get-AzureADUser`, etc.), **retool it to use the current equivalent** before completing the task. Do not patch around EOL cmdlets or leave them in place.

Common replacements:
- `Get-MsolUser` → `Get-MgUser`
- `Set-MsolUser` → `Update-MgUser`
- `Get-MsolGroup` → `Get-MgGroup`
- `Get-AzureADUser` → `Get-MgUser`
- `Set-MsolUserLicense` → `Set-MgUserLicense`

---

## Script Structure Standards

### PowerShell Scripts
All PowerShell scripts should follow this structure:

1. **`#Requires` statement** (if applicable, e.g., `#Requires -RunAsAdministrator`)
2. **Comment-based help block** (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`)
3. **`param()` block** — even if empty for RMM scripts, to allow future parameterization
4. **Execution preferences** — set silently for RMM scripts
5. **Environment variable overrides** — map Ninja vars to params
6. **Module/dependency checks** — detect and install before use
7. **Main logic** in a `try/catch` block
8. **Explicit `exit` codes** — `exit 0` / `exit 1`

### Logging
Use a consistent `Write-Log` or `Write-SilentLog` function pattern with timestamps and severity levels (`Info`, `Warning`, `Error`, `Success`). Output goes to stdout for Ninja capture. Optionally mirror to Windows Event Log or a local log file.

### Error Handling
- Wrap main logic in `try/catch`
- Catch specific exceptions where behavior differs
- Always log the exception message: `$_.Exception.Message`
- Exit with non-zero code on unrecoverable errors

---

## Engineering Principles

- **DRY** — Do not repeat logic. Extract reusable patterns into functions.
- **KISS** — Keep solutions simple, explicit, and maintainable. Avoid unnecessary complexity.
- **SOLID** — Write single-purpose functions with clear inputs/outputs.
- **Root-cause first** — Never patch symptoms. Identify and fix the actual cause.
- **No shortcuts** — Prefer a correct, maintainable fix over a fast workaround.
- **Verify, never assume** — Before adopting a pattern, confirm it is correct by checking official documentation. Do not assume a technique is "industry standard" or "best practice" without verifying against the authoritative source (e.g., Microsoft Learn, RFC, vendor docs). This applies to authentication flows, error-handling patterns, API usage, and any design decision that affects correctness or security.
- **Prefer platform APIs** — Before writing per-item enumeration loops, check whether the platform already provides a bulk report, export, or batch API. One API call returning full-tenant data beats thousands of per-user calls.

---

## Script Naming Convention (Design Schema)

All scripts in this repository follow the **`Action Product.ext`** naming pattern. This is the standard design schema for filenames and must be used when creating or renaming scripts.

### Format
```
<Verb> <Target or Product>[.ext]
```

- **Verb** — A single action word describing what the script does.
- **Target / Product** — The thing being acted upon (application name, OS component, service, etc.).
- **Extension** — `.ps1`, `.sh`, `.py`, `.bat`, `.vbs`, etc.

### Approved Verbs

Use one of these standard verbs as the first word in every script filename:

| Verb | When to use |
|---|---|
| `Install` | Deploys or installs software, agents, hotfixes, or packages |
| `Uninstall` | Removes or uninstalls software |
| `Configure` | Sets configuration, registry keys, policies, or preferences |
| `Get` | Retrieves, queries, or reports information (read-only) |
| `Set` | Assigns a specific value (license key, username, drive mapping, etc.) |
| `Enable` | Turns on a feature, service, or setting |
| `Disable` | Turns off a feature, service, or setting |
| `Repair` | Fixes, restores, or recovers a broken component |
| `Cleanup` | Removes caches, temp files, old versions, or stale data |
| `Migrate` | Moves data, profiles, or configurations between systems/platforms |
| `Audit` | Inspects, inventories, or assesses for compliance/reporting |
| `Detect` | Checks for the presence of a condition (CVE, enrollment, malware) |
| `Mitigate` | Applies a workaround or fix for a specific vulnerability (CVE) |
| `Remove` | Deletes specific items (bloatware, UWP apps, OEM software) |
| `Create` | Creates new objects (users, shortcuts, contacts) |
| `Promote` | Elevates privileges or roles (user to admin) |
| `Rebuild` | Reconstructs a database, index, or repository from scratch |
| `Run` | Executes an external tool, wizard, or ad hoc command |
| `Scan` | Performs a scan operation (repair scan, network scan) |
| `Schedule` | Schedules a future operation (chkdsk at reboot) |
| `Sync` | Synchronizes data or time with an external source |
| `Download` | Downloads files or reports from a remote source |
| `Import` | Imports data from a file or external source |
| `Generate` | Produces output (keys, reports, tokens) |
| `Enroll` | Enrolls a device into a management platform (Intune, MDM) |
| `Start` | Begins a multi-step process (migration, enrollment) |
| `PreStage` | Prepares an environment for a future operation |
| `Delete` | Permanently removes a specific object (user profile, file) |
| `Fix` | Applies a targeted correction to data (encoding, formatting) |
| `Add` | Adds items to an existing collection (users to a group/list) |

### Capitalization
- **Title Case** for every word: `Install BitDefender GravityZone.ps1`
- Product names use their **official casing**: `FortiClient`, `BitLocker`, `NinjaRMM`, `QuickBooks`
- Acronyms stay uppercase: `SMB`, `NTP`, `CVE`, `MSI`, `UWP`, `RMM`, `GPO`

### Examples
```
Install ConnectSecure Agent.ps1       ✅  Verb + Product
Get Mailbox Usage.ps1                 ✅  Verb + Target
Cleanup Windows Update Cache.ps1      ✅  Verb + Component
Mitigate CVE-2022-30190 Follina.ps1   ✅  Verb + CVE identifier
Audit User Profiles.ps1               ✅  Verb + Target
Configure Chrome Updates.bat          ✅  Verb + Product
```

### Anti-Patterns (do not use)
```
App - SomeApp Install.ps1             ❌  Category prefix
NinjaRMM_Removal_and_ReInstall.ps1    ❌  Underscores, multiple verbs
WS_SomeScript.ps1                     ❌  Customer initials prefix
FilesByType_results.ps1               ❌  No verb, underscores
```

---

## Repository Folder Structure

| Folder | Purpose |
|---|---|
| `Windows/Applications/` | Install, uninstall, configure, and repair Windows applications |
| `Windows/CVE Mitigations/` | Vulnerability detection and mitigation scripts |
| `Windows/OS/Maintenance/` | DISM, disk cleanup, cache cleanup, WMI rebuild, hotfixes, GPO cleanup, licensing |
| `Windows/OS/Migration/` | Entra ID prestage, Intune enrollment, profile migration |
| `Windows/OS/Networking/` | Mapped drives, WakeOnLAN, network name, NTP sync, offline files |
| `Windows/OS/Reporting/` | License info, printers, shares, SMART status, folder sizes, service accounts |
| `Windows/OS/Security/` | BitLocker, UAC, SMB, credential caching, admin audits, execution policy |
| `Windows/OS/User Management/` | Profile audit/cleanup/delete, user creation, admin promotion, passwords |
| `Microsoft 365/Exchange Online/` | Message trace, mailbox rules, contacts, distribution lists, AppRiver |
| `Microsoft 365/Security and Compliance/` | Phishing simulation setup, MFA reports |
| `Microsoft 365/Entra ID/` | Immutable ID, user identity management |
| `Microsoft 365/Reporting/` | Mailbox usage reports |
| `Mac/Applications/` | BitDefender, Huntress, ConnectSecure, Webroot |
| `Mac/OS/` | User management, updates, shortcuts, Apple IDs |
| `Mac/Security/` | FileVault, admin audit, MDM detection, CVE mitigation |
| `Linux/Agents/` | ConnectSecure, package installation |
| `Linux/Tools/` | GeoIP, MX scanning, VPN scanning, ping, download utilities |
| `RMM/` | RMM agent management (NinjaOne, Datto) |
| `Datto/` | Datto-specific tools (SaaS Protection, Endpoint Backup) |
| `IT Glue/` | IT Glue documentation platform utilities |
| `GitHub/` | Repository maintenance scripts |
| `Misc/` | Uncategorized utilities |
| `Network/` | Network device documentation and tools |
| `_Customer/` | Customer-specific scripts (**confidential, git-ignored**) |

---

## Version Control and Changelog

Each script in this repository is a **standalone product**. Commit and document changes accordingly.

### Commit Rules
- **One commit per script.** When modifying multiple scripts, commit each one separately with a message specific to what changed in that script.
- Use the format: `<Verb> <Script Name>: <brief description>`
  - Examples: `Update Get Immutable ID: switch to browser auth, install only Microsoft.Graph.Users`
  - Examples: `Fix Get Message Trace: replace exit with throw, add help block`
- Do not batch unrelated script changes into a single commit.
- Batch commits are acceptable only for true cross-cutting changes that apply identically to every file (e.g., a repo-wide rename).

### Changelog
- Maintain `CHANGELOG.md` in the repository root.
- Add an entry for every script change, grouped under a dated section.
- Each entry should explain **what changed and why** — more detail than the commit message.
- Reference commit hashes in changelog entries when available.
- Use the existing format: group by date, then by script or theme.

---

## Planning and Collaboration Rules

- Answer questions directly before making code changes.
- Before implementing a significant change, present:
  - A clear plan of action
  - Open questions that affect implementation
  - Risks or concerns
  - Suggestions and tradeoffs
- For large changes, confirm alignment before proceeding.

---

## Always / Never Rules

- **Always** suppress progress bars and interactive prompts in RMM scripts.
- **Always** detect and install missing modules rather than letting imports fail.
- **Always** use modern authentication for M365 scripts (Graph, ExchangeOnlineManagement v3+).
- **Always** support Ninja environment variable overrides alongside script parameters.
- **Always** exit with explicit codes (`exit 0` / `exit 1`) in RMM scripts.
- **Always** include a comment-based help block.
- **Always** update the folder `README.md` script index when adding, removing, or renaming a script — the index must stay current with the actual files in the folder.
- **Never** use `MSOnline`, `AzureAD`, or `Connect-MsolService` — these are EOL.
- **Never** use `Get-WmiObject` for application detection — use registry lookups or `Get-CimInstance` instead.
- **Never** use `Read-Host` or any interactive prompt in RMM scripts.
- **Never** hardcode credentials, tenant IDs, or customer-specific values in scripts.
- **Never** leave EOL cmdlets in place when modifying an existing script — retool them.
- **Never** use `exit` in technician scripts (`Microsoft 365/`, `Google/`) — use `throw` for fatal errors and let the script end naturally on success.
- **Never** add dot-source re-invocation guards or child-process workarounds — just avoid `exit` in technician scripts.
- **Never** use em dashes (—) in responses or in script content. Em dashes are non-ASCII and break PowerShell string literals. Use plain hyphens (-) instead.

---

## Definition of Done

- The script solves the validated root cause or requirement.
- RMM scripts run silently at SYSTEM level with no interactive dependencies.
- M365 scripts use current, non-EOL authentication and cmdlets.
- Missing modules are detected and installed automatically.
- Ninja variable support is implemented where configuration is needed.
- Exit codes are explicit and meaningful.
- Comment-based help is present and accurate.
- If an existing script was modified, any EOL cmdlets encountered were replaced.
- The folder `README.md` script index has been updated to reflect any added, removed, or renamed scripts.
- Changes are committed per-script with descriptive messages.
- `CHANGELOG.md` has been updated with an entry for each changed script.
