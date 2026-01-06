Helpdesk Repair + Cleanup Tool (Local Run)

Overview
This PowerShell script runs common Windows repair and cleanup tasks and produces a
ticket-ready summary plus a detailed log file. It is intended for helpdesk use on
machines running low on disk space.

What it does
- Runs DISM /RestoreHealth (optional)
- Runs SFC /scannow (optional)
- Clears temp folders and Recycle Bin
- Runs DISM /StartComponentCleanup (optional)
- Logs all actions and outputs a summary

Requirements
- Windows 10/11
- Run in an elevated PowerShell (Administrator)

Usage (examples)
1) Full run (repair + cleanup)
   .\Repair-Cleanup.ps1

2) Cleanup only (fast)
   .\Repair-Cleanup.ps1 -SkipDISM -SkipSFC

3) SFC only
   .\Repair-Cleanup.ps1 -SkipDISM -SkipCleanup

Parameters
-SkipDISM     Skip DISM /RestoreHealth
-SkipSFC      Skip SFC /scannow
-SkipCleanup  Skip cleanup steps
-SkipComponentCleanup  Skip DISM /StartComponentCleanup
-LogDir       Log directory (default: C:\ProgramData\HelpdeskTools\Logs)

Output
- A detailed log file is written to the LogDir path.
- The console prints a ticket-ready summary including disk space before/after.

Notes
- DISM may return 3010 which indicates a reboot is recommended.
- SFC can return non-zero codes; the script logs them and completes.
- Use at your own risk; review the script before running in production.
