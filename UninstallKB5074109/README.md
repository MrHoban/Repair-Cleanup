# Uninstall KB5074109

This repo provides two PowerShell scripts to remove Windows Update **KB5074109**, which has been causing issues for users on Windows 365 / Cloud PC environments. Use the standard script first; use the fallback script if WUSA cannot remove the update.

## Scripts

- `uninstallkb5074109.ps1`
  - Checks for KB5074109 and uninstalls it via `wusa.exe`.
  - Offers optional reboot with `-ForceReboot`.

- `uninstallkb5074109force.ps1`
  - Tries `wusa.exe` first.
  - If WUSA fails, falls back to DISM package removal.
  - Offers optional reboot with `-ForceReboot`.

## Requirements

- Run in an elevated PowerShell session (Administrator).
- Windows Update KB5074109 must be installed for the scripts to take action.

## Usage

Standard uninstall (recommended first):

```powershell
# From the folder containing the script
.\uninstallkb5074109.ps1
```

Force reboot after uninstall:

```powershell
.\uninstallkb5074109.ps1 -ForceReboot
```

Fallback (uses DISM if needed):

```powershell
.\uninstallkb5074109force.ps1
```

Fallback with forced reboot:

```powershell
.\uninstallkb5074109force.ps1 -ForceReboot
```

## Notes

- If the update is not installed, the scripts exit without making changes.
- A reboot is usually required after removal.
- Some systems may mark the update as not applicable or non-removable; the fallback script attempts DISM package removal in those cases.

## Disclaimer

Use at your own risk. Test in a non-production environment before deploying broadly.
