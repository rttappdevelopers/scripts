# Contributing to RTT Scripts

Thank you for contributing. This document covers everything you need to know before submitting a new script or modifying an existing one.

---

## Before You Start

Read [HOWTO.md](HOWTO.md) if you haven't already — it covers how scripts in this library are discovered and used by technicians, which will inform how you write and document your contribution.

---

## Naming Convention

All scripts follow the **`Action Product.ext`** pattern — a single approved verb followed by the thing being acted on, in Title Case.

**Format:** `<Verb> <Target or Product>.<ext>`

**Approved verbs:** Add, Audit, Cleanup, Configure, Create, Delete, Detect, Disable, Download, Enable, Enroll, Fix, Generate, Get, Import, Install, Migrate, Mitigate, PreStage, Promote, Rebuild, Remove, Repair, Run, Scan, Schedule, Set, Start, Sync, Uninstall

**Examples:**
```
Install ConnectSecure Agent.ps1      ✅
Get Mailbox Rules and Forwards.ps1   ✅
Cleanup Windows Update Cache.ps1     ✅
Mitigate CVE-2022-30190 Follina.ps1  ✅
```

**Anti-patterns:**
```
App - SomeApp Install.ps1            ❌  Category prefix
NinjaRMM_Removal_and_ReInstall.ps1   ❌  Underscores, multiple verbs
WS_SomeScript.ps1                    ❌  Customer initials prefix
```

Use official product casing (`BitLocker`, `FortiClient`, `NinjaRMM`) and uppercase acronyms (`SMB`, `CVE`, `UWP`).

---

## Required Script Structure

Every script must include the following, in order:

1. **`#Requires` statement** (if applicable — e.g., `#Requires -RunAsAdministrator`)
2. **Comment-based help block** with at minimum `.SYNOPSIS`, `.DESCRIPTION`, and `.EXAMPLE` (PowerShell) or equivalent header comment (Bash/Python)
3. **`param()` block** — even if empty, to support future parameterization
4. **Execution preferences** — `$ProgressPreference = "SilentlyContinue"` and similar for RMM scripts
5. **NinjaOne environment variable overrides** — map `$env:VARNAME` to parameters where applicable
6. **Module/dependency checks** — detect and install before use; never let a missing import kill the script
7. **Main logic** wrapped in `try/catch`
8. **Explicit exit codes** — `exit 0` on success, `exit 1` (or non-zero) on failure

---

## No-Secrets Checklist

Before submitting, verify:

- [ ] No passwords, API keys, or tokens in the script body or comments
- [ ] No hardcoded tenant IDs, customer names, or domain names
- [ ] No hardcoded UNC paths or IP addresses that are customer-specific
- [ ] No credentials embedded in connection strings or URLs
- [ ] All runtime values come from parameters or `$env:` variables

If any of these are present, remove them and parameterize before submitting. See [SECURITY.md](SECURITY.md) for the full policy.

---

## RMM Compatibility

Scripts deployed via NinjaOne run at **SYSTEM level** with no interactive session. They must:

- Never use `Read-Host` or any dialog that requires user input
- Suppress progress bars: `$ProgressPreference = "SilentlyContinue"`
- Support configuration via `$env:VARIABLE_NAME` (NinjaOne script variables / custom fields)
- Exit with `exit 0` / `exit 1` so Ninja can report success or failure

---

## Microsoft 365 Scripts

- Use **`ExchangeOnlineManagement` v3+** and **`Microsoft.Graph`** only
- Never use `MSOnline`, `AzureAD`, `Connect-MsolService`, `Connect-AzureAD` — these modules are end of life
- If modifying an existing script that uses EOL cmdlets, replace them before submitting

Common replacements:

| EOL | Current |
|---|---|
| `Get-MsolUser` | `Get-MgUser` |
| `Set-MsolUser` | `Update-MgUser` |
| `Get-AzureADUser` | `Get-MgUser` |
| `Set-MsolUserLicense` | `Set-MgUserLicense` |

---

## Where to Put Your Script

Use the folder structure below. If your script doesn't fit neatly, ask before creating a new folder.

| Folder | What belongs here |
|---|---|
| `Windows/Applications/` | Install, uninstall, configure, or repair a Windows application |
| `Windows/CVE Mitigations/` | Vulnerability detection or mitigation |
| `Windows/OS/Maintenance/` | DISM, disk cleanup, index rebuild, hotfixes, licensing |
| `Windows/OS/Migration/` | Entra ID prestage, Intune enrollment, profile migration |
| `Windows/OS/Networking/` | Drive mapping, WakeOnLAN, NTP sync, offline files |
| `Windows/OS/Reporting/` | Inventory, audit, and diagnostic reporting |
| `Windows/OS/Security/` | BitLocker, UAC, SMB settings, credential caching, admin audits |
| `Windows/OS/User Management/` | Profile cleanup, user creation, admin promotion, passwords |
| `Mac/Applications/` | macOS agent or application install/uninstall |
| `Mac/OS/` | macOS configuration and user management |
| `Mac/Security/` | macOS security tooling and CVE detection |
| `Linux/Agents/` | Linux agent installs |
| `Linux/Tools/` | Linux diagnostic and utility scripts |
| `Microsoft 365/Exchange Online/` | Mailbox, rules, contacts, distribution lists |
| `Microsoft 365/Entra ID/` | Entra ID / Azure AD identity management |
| `Microsoft 365/Reporting/` | M365 usage and compliance reporting |
| `Microsoft 365/Security and Compliance/` | Phishing simulation, MFA reporting |
| `RMM/` | NinjaOne agent management and configuration |
| `Datto/` | Datto SaaS Protection and Endpoint Backup tooling |
| `IT Glue/` | IT Glue export and import utilities |
| `Misc/` | Standalone utilities that don't belong to a specific platform |

---

## Submitting

1. Add your script to the appropriate folder.
2. Confirm the filename follows the `Action Product.ext` convention.
3. Complete the no-secrets checklist above.
4. **Update the folder `README.md` script index.** This is required — not optional. Add a row for any new script, remove the row for any deleted script, and update the name and description for any renamed script. The index must match the actual files in the folder at all times.
5. Add an entry to [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]` describing what was added, changed, or removed.
6. Open a pull request with a brief description of what the script does and why it was needed.

Questions? Reach out in the team Slack or open a draft PR to discuss before you finalize.
