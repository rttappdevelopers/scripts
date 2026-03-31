# Microsoft Defender Repair Script
## Simulation Results & End User Impact Analysis

**Script Version:** 1.1  
**Date:** January 6, 2026  
**Author:** Brad Brown  
**Developed with:** Claude Sonnet 4.5

---

## Executive Summary

This document provides simulation results and end-user impact analysis for the Microsoft Defender Repair script deployed via NinjaRMM. The script offers six repair options with varying levels of intervention, from passive diagnostics to forced repair sequences.

### Key Features
- ✅ Multiple repair strategies with intelligent decision-making
- ✅ Minimal end-user disruption (most operations are invisible)
- ✅ Comprehensive logging for troubleshooting
- ✅ Safe by default with escalation options
- ✅ Third-party antivirus detection and guidance

---

## Repair Options Overview

| Option | Purpose | User Impact | Duration | Recommended Use |
|--------|---------|-------------|----------|-----------------|
| **Diagnostic Check Only** | Status validation | None | 6-8s | Initial assessment |
| **Enable Defender** | Activate protection | Minimal | 5-10s | Post-AV removal |
| **Reset to Default** | Clear policy conflicts | Moderate | 10-15s | Policy issues |
| **Remove Third-Party AV** | Detection & guidance | None | 5-8s | AV conflicts |
| **Full Repair (Smart)** | Intelligent repair | None to Minimal | 8-20s | **Primary option** |
| **Force Full Repair** | Nuclear option | Moderate | 18-25s | Last resort |

---

## Simulation Scenarios

### Scenario 1: Full Repair (Intelligent) - Healthy System

**System State:**
- Microsoft Defender: ✅ Running
- Real-Time Protection: ✅ Enabled
- Third-Party AV: ❌ None detected

**Console Output:**
```
[2026-01-06 15:15:22] [INFO] === Microsoft Defender Repair Script Started ===
[2026-01-06 15:15:22] [INFO] Selected Action: Full Repair (All Steps)
[2026-01-06 15:15:22] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:15:23] [INFO] Initial Status - Service Running: True
[2026-01-06 15:15:23] [INFO] Initial Status - Real-Time Protection: True
[2026-01-06 15:15:23] [INFO] Initial Status - Antivirus Enabled: True
[2026-01-06 15:15:23] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:15:24] [INFO] Performing intelligent full repair sequence...
[2026-01-06 15:15:24] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:15:25] [INFO] No third-party antivirus detected
[2026-01-06 15:15:25] [INFO] No third-party AV detected - skipping removal step
[2026-01-06 15:15:25] [INFO] Defender settings appear normal - skipping reset
[2026-01-06 15:15:25] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:15:26] [INFO] Defender already enabled and running - skipping enable step
[2026-01-06 15:15:29] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:15:30] [INFO] === Final Status ===
[2026-01-06 15:15:30] [INFO] Service Running: True
[2026-01-06 15:15:30] [INFO] Real-Time Protection: True
[2026-01-06 15:15:30] [INFO] Antivirus Enabled: True
[2026-01-06 15:15:30] [INFO] ✓ Microsoft Defender is now active
[2026-01-06 15:15:30] [INFO] === Script Completed ===
```

**End User Experience:**
| Metric | Value |
|--------|-------|
| Duration | 8 seconds |
| Screen Impact | None - completely invisible |
| Performance Impact | Minimal - status checks only |
| Interruption Level | **Zero** |
| User Notifications | None |
| Service Interruption | No |
| Result | ✅ Validation only, no changes needed |

**Outcome:** Script intelligently detected healthy system and skipped all repair steps.

---

### Scenario 2: Full Repair (Intelligent) - Broken System

**System State:**
- Microsoft Defender: ⚠️ Service running but disabled
- Real-Time Protection: ❌ Disabled
- Third-Party AV: ⚠️ AVG AntiVirus detected

**Console Output:**
```
[2026-01-06 15:20:45] [INFO] === Microsoft Defender Repair Script Started ===
[2026-01-06 15:20:45] [INFO] Selected Action: Full Repair (All Steps)
[2026-01-06 15:20:45] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:20:46] [INFO] Initial Status - Service Running: True
[2026-01-06 15:20:46] [INFO] Initial Status - Real-Time Protection: False
[2026-01-06 15:20:46] [INFO] Initial Status - Antivirus Enabled: False
[2026-01-06 15:20:46] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:20:47] [WARNING] Third-party AV detected: AVG AntiVirus Free
[2026-01-06 15:20:47] [INFO] Performing intelligent full repair sequence...
[2026-01-06 15:20:47] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:20:48] [INFO] Third-party AV detected - attempting removal...
[2026-01-06 15:20:48] [INFO] Attempting to remove third-party antivirus...
[2026-01-06 15:20:48] [INFO] Found: AVG AntiVirus Free
[2026-01-06 15:20:49] [INFO] Found AV program: AVG AntiVirus Free
[2026-01-06 15:20:49] [INFO] Uninstall string: C:\Program Files\AVG\AVG PC TuneUp\TUInstallHelper.exe
[2026-01-06 15:20:49] [WARNING] Please manually uninstall or use vendor-specific removal tool
[2026-01-06 15:20:49] [INFO] Third-party AV check complete. Manual removal may be required.
[2026-01-06 15:20:51] [INFO] Defender policy overrides detected - reset needed
[2026-01-06 15:20:51] [INFO] Performing reset to default settings...
[2026-01-06 15:20:51] [INFO] Resetting Microsoft Defender to default settings...
[2026-01-06 15:20:51] [INFO] Removing policy overrides...
[2026-01-06 15:20:51] [INFO] Removed policy: HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender
[2026-01-06 15:20:52] [INFO] Resetting Defender preferences...
[2026-01-06 15:20:53] [INFO] Restarting Windows Defender service...
[2026-01-06 15:20:58] [INFO] Defender reset to default settings successfully
[2026-01-06 15:21:00] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:21:01] [INFO] Defender needs to be enabled...
[2026-01-06 15:21:01] [INFO] Enabling Microsoft Defender...
[2026-01-06 15:21:01] [INFO] Enabling Real-Time Protection via registry...
[2026-01-06 15:21:02] [INFO] Microsoft Defender enabled successfully
[2026-01-06 15:21:05] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:21:06] [INFO] === Final Status ===
[2026-01-06 15:21:06] [INFO] Service Running: True
[2026-01-06 15:21:06] [INFO] Real-Time Protection: True
[2026-01-06 15:21:06] [INFO] Antivirus Enabled: True
[2026-01-06 15:21:06] [INFO] ✓ Microsoft Defender is now active
[2026-01-06 15:21:06] [INFO] === Script Completed ===
```

**End User Experience:**
| Metric | Value |
|--------|-------|
| Duration | 21 seconds |
| Screen Impact | Windows Security icon briefly changes |
| Performance Impact | Brief CPU spike during service restart |
| Interruption Level | **Minimal (3-5 seconds)** |
| User Notifications | Brief toast: "Windows Security - Taking action..." |
| Service Interruption | Yes - 3-5 second gap during restart |
| Security Icon State | ❌ → ⚠️ → ✅ |

**User-Visible Effects:**
- 🛡️ Windows Security icon shows brief transition
- 📱 Possible notification: "Your device is protected"
- ⚡ Brief system tray activity

**Outcome:** ✅ Successfully repaired Defender, identified third-party AV for manual removal.

---

### Scenario 3: Force Full Repair (No Checks) - Appears Healthy

**System State:**
- Microsoft Defender: ✅ Appears fully functional
- Real-Time Protection: ✅ Enabled
- Issue: Hidden corruption or policy conflict

**Console Output:**
```
[2026-01-06 15:25:10] [INFO] === Microsoft Defender Repair Script Started ===
[2026-01-06 15:25:10] [INFO] Selected Action: Force Full Repair (No Checks)
[2026-01-06 15:25:10] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:25:11] [INFO] Initial Status - Service Running: True
[2026-01-06 15:25:11] [INFO] Initial Status - Real-Time Protection: True
[2026-01-06 15:25:11] [INFO] Initial Status - Antivirus Enabled: True
[2026-01-06 15:25:11] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:25:12] [INFO] Performing FORCED full repair sequence (no checks)...
[2026-01-06 15:25:12] [WARNING] WARNING: This will execute all repair steps regardless of current state
[2026-01-06 15:25:12] [INFO] Attempting to remove third-party antivirus...
[2026-01-06 15:25:12] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:25:13] [INFO] No third-party antivirus detected
[2026-01-06 15:25:13] [INFO] Third-party AV check complete. Manual removal may be required.
[2026-01-06 15:25:15] [INFO] Resetting Microsoft Defender to default settings...
[2026-01-06 15:25:15] [INFO] Removing policy overrides...
[2026-01-06 15:25:15] [INFO] Resetting Defender preferences...
[2026-01-06 15:25:16] [INFO] Restarting Windows Defender service...
[2026-01-06 15:25:21] [INFO] Defender reset to default settings successfully
[2026-01-06 15:25:23] [INFO] Enabling Microsoft Defender...
[2026-01-06 15:25:23] [INFO] Enabling Real-Time Protection via registry...
[2026-01-06 15:25:24] [INFO] Microsoft Defender enabled successfully
[2026-01-06 15:25:27] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:25:28] [INFO] === Final Status ===
[2026-01-06 15:25:28] [INFO] Service Running: True
[2026-01-06 15:25:28] [INFO] Real-Time Protection: True
[2026-01-06 15:25:28] [INFO] Antivirus Enabled: True
[2026-01-06 15:25:28] [INFO] ✓ Microsoft Defender is now active
[2026-01-06 15:25:28] [INFO] === Script Completed ===
```

**End User Experience:**
| Metric | Value |
|--------|-------|
| Duration | 18 seconds |
| Screen Impact | Security icon flickers during restart |
| Performance Impact | CPU spike, possible momentary lag |
| Interruption Level | **Moderate (5-8 seconds)** |
| User Notifications | "Windows Security - Restarting..." + "Your device is protected" |
| Service Interruption | Yes - protection down for ~5 seconds |
| Security Icon State | ✅ → ⚠️ (briefly) → ✅ |

**⚠️ Security Window:** System unprotected for approximately 5 seconds during service restart.

**When to Use:**
- Smart repair completed but issues persist
- Subtle corruption not detected by status checks
- Escalation after other options fail

**Outcome:** ✅ Forced rebuild of all Defender components regardless of reported status.

---

### Scenario 4: Force Full Repair - Severely Corrupted System

**System State:**
- Microsoft Defender: ❌ PowerShell module missing/corrupted
- Real-Time Protection: ❌ Cannot determine
- Issue: Deep Windows component corruption

**Console Output:**
```
[2026-01-06 15:30:05] [INFO] === Microsoft Defender Repair Script Started ===
[2026-01-06 15:30:05] [INFO] Selected Action: Force Full Repair (No Checks)
[2026-01-06 15:30:05] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:30:06] [ERROR] Error checking Defender status: The term 'Get-MpComputerStatus' is not recognized
[2026-01-06 15:30:06] [WARNING] Unable to get initial Defender status
[2026-01-06 15:30:06] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:30:07] [INFO] Performing FORCED full repair sequence (no checks)...
[2026-01-06 15:30:07] [WARNING] WARNING: This will execute all repair steps regardless of current state
[2026-01-06 15:30:07] [INFO] Attempting to remove third-party antivirus...
[2026-01-06 15:30:07] [INFO] Checking for third-party antivirus software...
[2026-01-06 15:30:08] [INFO] No third-party antivirus detected
[2026-01-06 15:30:08] [INFO] Third-party AV check complete. Manual removal may be required.
[2026-01-06 15:30:10] [INFO] Resetting Microsoft Defender to default settings...
[2026-01-06 15:30:10] [INFO] Removing policy overrides...
[2026-01-06 15:30:10] [INFO] Removed policy: HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender
[2026-01-06 15:30:11] [INFO] Resetting Defender preferences...
[2026-01-06 15:30:11] [ERROR] Error resetting Defender: The term 'Set-MpPreference' is not recognized
[2026-01-06 15:30:13] [INFO] Enabling Microsoft Defender...
[2026-01-06 15:30:13] [INFO] Starting Windows Defender service...
[2026-01-06 15:30:18] [INFO] Enabling Real-Time Protection via registry...
[2026-01-06 15:30:19] [INFO] Microsoft Defender enabled successfully
[2026-01-06 15:30:22] [INFO] Checking Microsoft Defender status...
[2026-01-06 15:30:22] [ERROR] Error checking Defender status: The term 'Get-MpComputerStatus' is not recognized
[2026-01-06 15:30:22] [INFO] === Final Status ===
[2026-01-06 15:30:22] [WARNING] ⚠ Microsoft Defender may require additional action or system reboot
[2026-01-06 15:30:22] [INFO] === Script Completed ===
```

**End User Experience:**
| Metric | Value |
|--------|-------|
| Duration | 17 seconds |
| Screen Impact | Security icon may remain in error state |
| Performance Impact | Normal |
| Interruption Level | Minimal |
| User Notifications | None (PowerShell module unavailable) |
| Service Interruption | Minimal |
| Security Icon State | Likely stays ⚠️ or ❌ |

**⚠️ Critical Issue:** PowerShell Defender module is missing or corrupted.

**Follow-up Actions Required:**
1. Run DISM: `DISM /Online /Cleanup-Image /RestoreHealth`
2. Run SFC: `sfc /scannow`
3. Consider Windows Repair/Reset
4. Check Windows Update status

**Outcome:** ⚠️ Partial repair attempted. Registry keys set but cmdlets unavailable. Deeper Windows repair needed.

---

## Diagnostic Check Only - Sample Output

**Purpose:** Non-invasive status validation before any repair attempts.

**Console Output:**
```
[2026-01-06 14:32:15] [INFO] === Microsoft Defender Repair Script Started ===
[2026-01-06 14:32:15] [INFO] Selected Action: Diagnostic Check Only
[2026-01-06 14:32:15] [INFO] Checking Microsoft Defender status...
[2026-01-06 14:32:16] [INFO] Initial Status - Service Running: True
[2026-01-06 14:32:16] [INFO] Initial Status - Real-Time Protection: False
[2026-01-06 14:32:16] [INFO] Initial Status - Antivirus Enabled: True
[2026-01-06 14:32:16] [INFO] Checking for third-party antivirus software...
[2026-01-06 14:32:17] [WARNING] Third-party AV detected: Avast Free Antivirus
[2026-01-06 14:32:17] [INFO] Diagnostic check completed. No changes made.
[2026-01-06 14:32:20] [INFO] Checking Microsoft Defender status...
[2026-01-06 14:32:21] [INFO] === Final Status ===
[2026-01-06 14:32:21] [INFO] Service Running: True
[2026-01-06 14:32:21] [INFO] Real-Time Protection: False
[2026-01-06 14:32:21] [INFO] Antivirus Enabled: True
[2026-01-06 14:32:21] [WARNING] ⚠ Microsoft Defender may require additional action or system reboot
[2026-01-06 14:32:21] [INFO] === Script Completed ===
```

**End User Experience:**
| Metric | Value |
|--------|-------|
| Duration | 6 seconds |
| Screen Impact | None |
| Performance Impact | Minimal CPU for WMI queries |
| Interruption Level | **Zero** |
| User Notifications | None |
| Service Interruption | No |

**Outcome:** ✅ Identified issue (third-party AV blocking Defender) without making any changes.

---

## Recommended Workflow

```
┌─────────────────────────────┐
│  Start: Defender Issue      │
│  Reported or Detected       │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Step 1: Diagnostic Check   │
│  (0 user impact)            │
└──────────┬──────────────────┘
           │
           ▼
    ┌──────┴──────┐
    │  Healthy?   │
    └──┬───────┬──┘
       │       │
      Yes      No
       │       │
       │       ▼
       │  ┌─────────────────────────────┐
       │  │  Step 2: Full Repair        │
       │  │  (Smart - minimal impact)   │
       │  └──────────┬──────────────────┘
       │             │
       │             ▼
       │       ┌──────┴──────┐
       │       │  Fixed?     │
       │       └──┬───────┬──┘
       │          │       │
       │         Yes      No
       │          │       │
       │          │       ▼
       │          │  ┌─────────────────────────────┐
       │          │  │  Step 3: Force Full Repair  │
       │          │  │  (Nuclear - moderate impact)│
       │          │  └──────────┬──────────────────┘
       │          │             │
       │          │             ▼
       │          │       ┌──────┴──────┐
       │          │       │  Fixed?     │
       │          │       └──┬───────┬──┘
       │          │          │       │
       │          │         Yes      No
       │          │          │       │
       │          │          │       ▼
       │          │          │  ┌─────────────────────────────┐
       │          │          │  │  Step 4: Escalate           │
       │          │          │  │  - DISM/SFC                 │
       │          │          │  │  - Windows Repair           │
       │          │          │  │  - Manual intervention      │
       │          │          │  └─────────────────────────────┘
       │          │          │
       ▼          ▼          ▼
┌─────────────────────────────┐
│  Document & Close Ticket    │
└─────────────────────────────┘
```

---

## NinjaRMM Configuration

### Custom Fields Required

**Field Name:** `defenderRepairStatus`  
**Type:** Text/Wysiwyg  
**Purpose:** Stores last repair action and result

**Possible Values:**
- `Success: Diagnostic Check Only`
- `Success: Enable Defender`
- `Success: Reset to Default`
- `Success: Full Repair (All Steps)`
- `Success: Force Full Repair (No Checks)`
- `Failed: [Action Name]`

### Script Parameters

**Parameter Name:** `repairAction`  
**Type:** Dropdown  
**Values:**
- Diagnostic Check Only (default)
- Enable Defender
- Reset to Default
- Remove Third-Party AV
- Full Repair (All Steps)
- Force Full Repair (No Checks)

### Deployment Settings

- **Run As:** Administrator (required)
- **Script Type:** PowerShell
- **Timeout:** 120 seconds
- **Run Condition:** Manual or scheduled
- **Notification:** On failure only

---

## Impact Summary by Option

### Low Impact (Recommended First)
**Diagnostic Check Only**
- Duration: 6-8 seconds
- User awareness: 0%
- Protection gap: None
- Risk level: None

**Full Repair (Smart)**
- Duration: 8-20 seconds (varies)
- User awareness: 0-5%
- Protection gap: 0-5 seconds (if needed)
- Risk level: Very Low

### Moderate Impact (Escalation)
**Enable Defender**
- Duration: 5-10 seconds
- User awareness: 5-10%
- Protection gap: 3-5 seconds
- Risk level: Low

**Reset to Default**
- Duration: 10-15 seconds
- User awareness: 10-15%
- Protection gap: 5-10 seconds
- Risk level: Low-Moderate

### Higher Impact (Last Resort)
**Force Full Repair**
- Duration: 18-25 seconds
- User awareness: 15-20%
- Protection gap: 5-8 seconds
- Risk level: Moderate

---

## Common Issues & Resolutions

| Symptom | Likely Cause | Recommended Action |
|---------|--------------|-------------------|
| Real-Time Protection off | Third-party AV conflict | Full Repair (Smart) |
| Service not running | Manual disable or policy | Enable Defender |
| Policy overrides present | GPO or malware | Reset to Default |
| PowerShell cmdlets missing | Windows corruption | Force Repair → DISM/SFC |
| Appears healthy but isn't | Subtle corruption | Force Full Repair |
| Third-party AV detected | Recent uninstall incomplete | Remove Third-Party AV → Full Repair |

---

## Success Metrics

### Script Success Rates (Expected)
- **Diagnostic Check:** 100% (read-only)
- **Enable Defender:** 85-90%
- **Reset to Default:** 80-85%
- **Full Repair (Smart):** 75-85%
- **Force Full Repair:** 60-70%

### When Scripts Fail
If Force Full Repair fails, the issue is likely:
1. **Windows component corruption** (requires DISM/SFC)
2. **Hardware/firmware TPM issues**
3. **Deep malware infection**
4. **Windows installation requires repair/reset**

---

## Security Considerations

### Protection Gaps
- **Diagnostic Check:** No gap
- **Enable Only:** 3-5 seconds
- **Reset:** 5-10 seconds
- **Full/Force Repair:** 5-8 seconds

### Risk Mitigation
1. Schedule during maintenance windows when possible
2. Ensure third-party AV is removed before repair
3. Verify system is not actively under attack
4. Have rollback plan (though script is non-destructive)

---

## Troubleshooting Guide

### Script Exits with Code 1
**Possible Causes:**
- PowerShell module missing
- Permissions insufficient
- Service cannot start
- Registry access denied

**Resolution:**
1. Verify admin rights
2. Check Windows Update
3. Run DISM/SFC
4. Review Event Viewer logs

### No Changes Made (Smart Repair)
**This is by design when:**
- System is already healthy
- No policy overrides found
- All services running properly

**Next Steps:**
- If issue persists, use Force Full Repair
- Check for hidden malware
- Review application event logs

### Third-Party AV Detected
**Script Action:**
- Logs AV presence
- Shows uninstall string
- Recommends manual removal

**Manual Steps:**
1. Use vendor removal tool
2. Reboot system
3. Run script again

---

## Support Contact

**Script Issues:**
- Review NinjaRMM Activity Log
- Check `defenderRepairStatus` custom field
- Examine full console output

**Escalation Path:**
1. Try next repair level
2. DISM/SFC commands
3. Windows Repair
4. Microsoft Support

---

## Version History

**v1.1 - January 6, 2026**
- Added Force Full Repair option
- Implemented intelligent repair logic
- Enhanced logging detail
- Improved third-party AV detection

**v1.0 - Initial Release**
- Basic repair options
- NinjaRMM integration
- Status diagnostics

---

## Appendix: Technical Details

### Registry Keys Modified
```
HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender
HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection
HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection
```

### Services Affected
- **WinDefend** (Windows Defender Service)
- Startup Type set to: Automatic
- Service action: Start/Restart as needed

### PowerShell Cmdlets Used
- `Get-MpComputerStatus`
- `Get-MpPreference`
- `Set-MpPreference`
- `Get-Service`
- `Set-Service`
- `Start-Service`
- `Restart-Service`
- `Get-CimInstance`

### WMI Namespaces Queried
- `root/SecurityCenter2` (AntiVirusProduct detection)

---

**Document End**

*This simulation document represents expected behavior based on common scenarios. Actual results may vary based on system configuration, Windows version, and specific issues present.*