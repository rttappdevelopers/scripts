# Security Policy

## Credential and Secret Handling

Scripts in this repository **must not contain credentials, passwords, API keys, tenant IDs, or any customer-specific values.** This is a hard requirement, not a guideline.

All runtime values are passed through:
- **Script parameters** — declared in the `param()` block and supplied at execution time
- **NinjaOne environment variables** — read via `$env:VARIABLE_NAME` at the top of the script body
- **Interactive prompts** — only in technician-run scripts where a UI session is guaranteed

If you believe a credential or secret was accidentally committed, report it immediately (see below) and **do not** attempt to overwrite it with a new commit — Git history must be scrubbed using BFG or `git filter-repo`.

---

## Scope

This policy covers all scripts in the `rttappdevelopers/scripts` repository, across all branches. The `_Customer/` folder is excluded from version control entirely (`.gitignore`) and must never be committed.

---

## SOC 2 Relevance

This repository supports RTT's SOC 2 Type II compliance posture. Relevant trust service criteria addressed here include:

- **CC6.1 — Logical access controls:** Scripts do not store or expose credentials; access to the repository is controlled via GitHub organization membership.
- **CC6.3 — Access removal:** User management scripts follow least-privilege principles and are reviewed as part of offboarding procedures.
- **CC7.2 — System monitoring:** Reporting and audit scripts are maintained here and deployed via NinjaOne for continuous endpoint visibility.
- **CC8.1 — Change management:** All script changes go through Git history; significant changes are documented in `audit.md` (which is gitignored and maintained separately).
- **A1.2 — Availability:** RMM scripts are designed to exit with explicit codes so NinjaOne can detect and alert on failures.

---

## Reporting a Security Issue

If you discover a security vulnerability in a script, a leaked credential, or any other concern:

1. **Do not open a public GitHub issue.**
2. Email **security@roundtabletechnology.com** with a description of the issue, the affected file(s), and any relevant commit hashes or output.
3. You will receive a response within one business day.

We treat all security reports seriously and will act immediately on credential exposure reports.

---

## Responsible Disclosure

We ask that you give us a reasonable opportunity to address a reported issue before disclosing it publicly. For vulnerabilities in third-party tools or platforms referenced by scripts in this repository, please report directly to the relevant vendor.

---

## Related Documents

- [CONTRIBUTING.md](CONTRIBUTING.md) — includes the no-secrets checklist required before submitting any script
- [HOWTO.md](HOWTO.md) — safe execution guidance for technicians
