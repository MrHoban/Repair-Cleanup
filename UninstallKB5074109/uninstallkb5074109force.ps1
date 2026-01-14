<#
.SYNOPSIS
  Attempts to uninstall KB5074109 via WUSA, then falls back to DISM package removal if needed.

.USAGE
  Run elevated:
    .\Remove-KB5074109-Fallback.ps1
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$ForceReboot
)

$KB = "KB5074109"
$KbNum = "5074109"

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) { throw "Run as Administrator." }

function Test-KBInstalled {
    try { if (Get-HotFix -Id $KB -ErrorAction SilentlyContinue) { return $true } } catch {}
    $qfe = (wmic qfe get HotFixID 2>$null) | Out-String
    return ($qfe -match $KB)
}

if (-not (Test-KBInstalled)) {
    Write-Host "$KB not found. Exiting." -ForegroundColor Green
    exit 0
}

Write-Host "Trying WUSA uninstall for $KB..." -ForegroundColor Yellow
$wusaArgs = "/uninstall /kb:$KbNum /quiet /norestart"

$wusaExit = $null
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Uninstall $KB via WUSA")) {
    $w = Start-Process wusa.exe -ArgumentList $wusaArgs -Wait -PassThru
    $wusaExit = $w.ExitCode
}

$wusaOk = $wusaExit -in 0,3010

if (-not $wusaOk) {
    Write-Warning "WUSA exit code $wusaExit. Attempting DISM fallback..."

    # Find the package identity that contains the KB number
    $dismList = dism /online /get-packages | Out-String
    $lines = $dismList -split "`r?`n"

    # DISM output is grouped; we hunt for "Package Identity" near the KB string
    $pkgIds = @()
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $KB) {
            # look backwards for "Package Identity"
            for ($j=$i; $j -ge [Math]::Max(0,$i-20); $j--) {
                if ($lines[$j] -match "Package Identity\s*:\s*(.+)$") {
                    $pkgIds += $Matches[1].Trim()
                    break
                }
            }
        }
    }
    $pkgIds = $pkgIds | Select-Object -Unique

    if (-not $pkgIds) {
        throw "Could not find a DISM package identity for $KB. It may be non-removable or listed differently."
    }

    foreach ($pkg in $pkgIds) {
        Write-Host "Removing package: $pkg" -ForegroundColor Yellow
        if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "DISM remove-package $pkg")) {
            dism /online /remove-package /packagename:$pkg /quiet /norestart | Out-Null
        }
    }
}

Write-Host "Done. A reboot is very likely required." -ForegroundColor Cyan
if ($ForceReboot) { Restart-Computer -Force }
