# RMM

Scripts for managing the NinjaOne RMM platform itself — agent reinstallation and organization-level configuration. These are deployed via NinjaOne or run directly on a managed endpoint.

See [HOWTO.md](../HOWTO.md) for guidance on downloading and running scripts.

---

## Scripts

| Script | Description |
|---|---|
| [Reinstall NinjaRMM Agent.ps1](Reinstall%20NinjaRMM%20Agent.ps1) | Uninstalls the current NinjaOne agent and reinstalls from a provided installer URL. Accepts installer URL via `$env:NinjaInstallerURL` or parameter. |
| [Set Organization UDF from Hostname.ps1](Set%20Organization%20UDF%20from%20Hostname.ps1) | Sets a NinjaOne custom field (UDF) value derived from the device hostname — used to associate devices with organizations during onboarding. |
