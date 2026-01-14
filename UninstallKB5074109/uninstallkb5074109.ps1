<#
.SYNOPSIS
  Detects and uninstalls Windows Update KB5074109, then prompts for reboot.

.USAGE
  Run in elevated PowerShell:
    .\Remove-KB5074109.ps1
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$ForceReboot
)

$KB = "KB5074109"

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Error "Run this script as Administrator."
    exit 1
}

Write-Host "Checking for $KB..." -ForegroundColor Cyan

$installed = $false
try {
    # Get-HotFix is quick, but sometimes misses certain packages; we use both checks.
    if (Get-HotFix -Id $KB -ErrorAction SilentlyContinue) { $installed = $true }
} catch {}

if (-not $installed) {
    $qfe = (wmic qfe get HotFixID 2>$null) | Out-String
    if ($qfe -match $KB) { $installed = $true }
}

if (-not $installed) {
    Write-Host "$KB is NOT installed. Nothing to do." -ForegroundColor Green
    exit 0
}

Write-Host "$KB is installed. Attempting uninstall via wusa..." -ForegroundColor Yellow

# wusa exit codes: 0 = success, 3010 = success + reboot required
$arguments = "/uninstall /kb:5074109 /quiet /norestart"
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Uninstall $KB")) {
    $p = Start-Process -FilePath "wusa.exe" -ArgumentList $arguments -Wait -PassThru
}

switch ($p.ExitCode) {
    0 {
        Write-Host "Uninstall command completed successfully." -ForegroundColor Green
    }
    3010 {
        Write-Host "Uninstall completed. Reboot is required." -ForegroundColor Yellow
    }
    2359302 { # sometimes seen when update isn't installed / not applicable
        Write-Warning "WUSA says update is not applicable / not installed (2359302)."
    }
    default {
        Write-Warning "WUSA failed with exit code: $($p.ExitCode)"
        Write-Warning "This can happen if the update is not removable or is installed as a package WUSA can't handle."
    }
}

if ($ForceReboot) {
    Write-Host "Rebooting now (ForceReboot set)..." -ForegroundColor Yellow
    Restart-Computer -Force
} else {
    Write-Host "If performance/auth issues are resolved, reboot at your earliest convenience." -ForegroundColor Cyan
}
