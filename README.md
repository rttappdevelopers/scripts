# RTT Scripts

A library of automation scripts used by Round Table Technology support technicians to manage Windows, Mac, and Linux endpoints, Microsoft 365 tenants, and third-party platforms. Scripts are deployed via NinjaOne RMM or run interactively from a technician workstation.

---

## What's Here

| Folder | What it covers |
|---|---|
| [`Windows/`](Windows/README.md) | Applications, OS maintenance, security, user management, networking, reporting, and CVE mitigations for Windows endpoints — includes a [CMD & PowerShell command reference](Windows/README.md#command-reference) |
| [`Mac/`](Mac/README.md) | Agent installs, OS configuration, and security tooling for macOS endpoints — includes a [macOS command reference](Mac/README.md#command-reference) |
| [`Linux/`](Linux/README.md) | Agent installs and diagnostic tools for Linux endpoints — includes a [Bash command reference](Linux/README.md#command-reference) |
| [`Microsoft 365/`](Microsoft%20365/README.md) | Exchange Online, Entra ID, phishing simulation, and reporting scripts for M365 tenants |
| [`RMM/`](RMM/README.md) | NinjaOne agent management and UDF configuration |
| [`Datto/`](Datto/README.md) | Datto SaaS Protection and Endpoint Backup tooling |
| [`IT Glue/`](IT%20Glue/README.md) | IT Glue export and import utilities |
| [`Misc/`](Misc/README.md) | Standalone utilities that don't belong to a specific platform |
| [`Network/`](Network/README.md) | Reference documentation for network device management |

---

## Getting Started

See **[HOWTO.md](HOWTO.md)** for:

- How to find a script and read its built-in documentation
- How to download a script from GitHub to a local machine
- How to run scripts safely using PowerShell, PowerShell ISE, or VS Code
- When to use an elevated (Administrator) session

---

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for naming conventions, required script structure, the no-secrets checklist, and how to submit a new script.

---

## Security

See **[SECURITY.md](SECURITY.md)** for our credential handling policy, how to report a security concern, and the SOC 2 controls this repository supports.

---

## Changelog

See **[CHANGELOG.md](CHANGELOG.md)** for a history of significant changes, additions, and fixes across the library.