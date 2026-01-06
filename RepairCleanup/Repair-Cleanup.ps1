<#
.SYNOPSIS
  Helpdesk Repair + Cleanup Tool (Local Run)
  - DISM RestoreHealth (optional)
  - SFC /scannow
  - Safe cleanup (temp + recycle bin + component cleanup)
  - Creates a ticket-ready summary + saves a detailed log file

.USAGE
  Run in an elevated PowerShell:
    .\Repair-Cleanup.ps1
    .\Repair-Cleanup.ps1 -SkipDISM
    .\Repair-Cleanup.ps1 -RunCleanMgr

.NOTES
  Run as Administrator. Windows 10/11.
#>

[CmdletBinding()]
param(
    [switch]$SkipDISM,
    [switch]$SkipSFC,
    [switch]$SkipCleanup,
    [switch]$SkipComponentCleanup,
    [string]$LogDir = "$env:ProgramData\HelpdeskTools\Logs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-Directory([string]$Dir) {
    if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
}

function New-LogFile([string]$Dir) {
    New-Directory $Dir
    $ts = Get-Date -Format "yyyyMMdd_HHmmss"
    Join-Path $Dir "repair_cleanup_$($env:COMPUTERNAME)_$ts.log"
}

$script:LogBuffer = New-Object System.Collections.Generic.List[string]

function Write-Log([string]$Message, [string]$Level = "INFO") {
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    $script:LogBuffer.Add($line) | Out-Null
    Write-Host $line
}

function Invoke-Process([string]$FilePath, [string]$Arguments, [int[]]$AcceptExitCodes = @(0)) {
    Write-Log "Running: $FilePath $Arguments"
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    $code = $p.ExitCode
    if ($AcceptExitCodes -notcontains $code) {
        throw "Command failed (exit code $code): $FilePath $Arguments"
    }
    Write-Log "Exit code: $code"
    return $code
}

function Get-FreeSpaceGB {
    try {
        $c = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        [Math]::Round(($c.FreeSpace / 1GB), 2)
    } catch { $null }
}

# ---------------- Main ----------------
if (-not (Test-IsAdmin)) {
    Write-Host "ERROR: Please run PowerShell as Administrator."
    exit 2
}

$start = Get-Date
$logFile = New-LogFile $LogDir

Write-Log "=== Helpdesk Repair + Cleanup START ==="
Write-Log "Computer: $env:COMPUTERNAME | User: $env:USERNAME"
Write-Log "Start time: $start"
$freeBefore = Get-FreeSpaceGB
if ($null -ne $freeBefore) { Write-Log "Free space before: $freeBefore GB (C:)" }

# Track results for a clean ticket summary
$result = [ordered]@{
    DISM   = "Skipped"
    SFC    = "Skipped"
    Cleanup= "Skipped"
    Notes  = New-Object System.Collections.Generic.List[string]
}

# DISM
if (-not $SkipDISM) {
    try {
        $code = Invoke-Process "dism.exe" "/Online /Cleanup-Image /RestoreHealth" @(0,3010)
        $result.DISM = if ($code -eq 3010) { "OK (Reboot recommended)" } else { "OK" }
        if ($code -eq 3010) { $result.Notes.Add("DISM returned 3010 (reboot recommended).") | Out-Null }
    } catch {
        $result.DISM = "FAILED"
        $result.Notes.Add("DISM failed: $($_.Exception.Message)") | Out-Null
        Write-Log "DISM error: $($_.Exception.Message)" "ERROR"
    }
}

# SFC
if (-not $SkipSFC) {
    try {
        # Accept typical SFC codes so the script still completes + logs everything
        $code = Invoke-Process "sfc.exe" "/scannow" @(0,1,2,3)
        $result.SFC = "Completed (code $code)"
        if ($code -ne 0) { $result.Notes.Add("SFC returned code $code (review CBS.log if needed).") | Out-Null }
    } catch {
        $result.SFC = "FAILED"
        $result.Notes.Add("SFC failed: $($_.Exception.Message)") | Out-Null
        Write-Log "SFC error: $($_.Exception.Message)" "ERROR"
    }
}

# Cleanup
if (-not $SkipCleanup) {
    try {
        Write-Log "Cleanup: safe temp + recycle bin + component cleanup"
        $tempPaths = @("$env:TEMP\*", "$env:WINDIR\Temp\*")

        foreach ($p in $tempPaths) {
            Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Cleanup: cleared $p"
        }

        if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Log "Cleanup: cleared Recycle Bin"
        }

        if (-not $SkipComponentCleanup) {
            try {
                $code = Invoke-Process "dism.exe" "/Online /Cleanup-Image /StartComponentCleanup" @(0,3010)
                if ($code -eq 3010) { $result.Notes.Add("Component cleanup suggests reboot may help.") | Out-Null }
                Write-Log "Cleanup: component cleanup ran"
            } catch {
                Write-Log "Cleanup: component cleanup failed: $($_.Exception.Message)" "WARN"
                $result.Notes.Add("Component cleanup failed (non-fatal): $($_.Exception.Message)") | Out-Null
            }
        } else {
            Write-Log "Cleanup: component cleanup skipped"
        }

        $result.Cleanup = "OK"
    } catch {
        $result.Cleanup = "FAILED"
        $result.Notes.Add("Cleanup failed: $($_.Exception.Message)") | Out-Null
        Write-Log "Cleanup error: $($_.Exception.Message)" "ERROR"
    }
}

$freeAfter = Get-FreeSpaceGB
if ($null -ne $freeAfter -and $null -ne $freeBefore) {
    $delta = [Math]::Round(($freeAfter - $freeBefore), 2)
    Write-Log "Free space after:  $freeAfter GB (C:) ($delta GB)"
}

$end = Get-Date
$duration = New-TimeSpan -Start $start -End $end
Write-Log "End time: $end"
Write-Log ("Duration: {0:hh\:mm\:ss}" -f $duration)
Write-Log "=== Helpdesk Repair + Cleanup END ==="

# Write log
New-Directory $LogDir
$script:LogBuffer | Out-File -FilePath $logFile -Encoding UTF8 -Force

# Ticket-ready summary (prints to screen + captured if you paste output)
Write-Host ""
Write-Host "======== TICKET SUMMARY ========"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host ("Start: {0} | End: {1} | Duration: {2:hh\:mm\:ss}" -f $start, $end, $duration)
if ($null -ne $freeBefore -and $null -ne $freeAfter) {
    Write-Host "Disk (C:): $freeBefore GB free -> $freeAfter GB free"
}
Write-Host "DISM:    $($result.DISM)"
Write-Host "SFC:     $($result.SFC)"
Write-Host "Cleanup: $($result.Cleanup)"
if ($result.Notes.Count -gt 0) {
    Write-Host "Notes:"
    $result.Notes | ForEach-Object { Write-Host " - $_" }
}
Write-Host "Log: $logFile"
Write-Host "==============================="
Write-Host ""

# Exit code: 0 good, 1 had failures
if ($result.DISM -eq "FAILED" -or $result.SFC -eq "FAILED" -or $result.Cleanup -eq "FAILED") { exit 1 } else { exit 0 }

