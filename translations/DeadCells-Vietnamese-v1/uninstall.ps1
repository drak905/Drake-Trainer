# Dead Cells - Vietnamese language patch v1 uninstaller.
# Puts back deadcells.exe.vi-backup and removes the Vietnamese res<N>.pak.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Here "common.ps1")

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir "deadcells.exe"))) {
    Write-Host "Dead Cells not found. Run:  powershell -ExecutionPolicy Bypass -File uninstall.ps1 -GameDir ""D:\Path\To\DeadCells""" -ForegroundColor Red
    exit 1
}
$Exe = Join-Path $GameDir "deadcells.exe"
$Backup = "$Exe.vi-backup"
Write-Host "Game folder: $GameDir"
if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe }) {
    Write-Host "Dead Cells is running. Close the game first." -ForegroundColor Red
    exit 1
}

if (Has-Bytes ([IO.File]::ReadAllBytes($Exe)) $Marker) {
    if ((Test-Path $Backup) -and -not (Has-Bytes ([IO.File]::ReadAllBytes($Backup)) $Marker)) {
        Copy-Item $Backup $Exe -Force
        Remove-Item $Backup
        Write-Host "deadcells.exe restored from the backup."
    } else {
        Write-Host "No usable backup of deadcells.exe. Use the launcher's Verify (Epic: Library > Dead Cells > ... > Manage > Verify)." -ForegroundColor Yellow
    }
} else {
    Write-Host "deadcells.exe has no Vietnamese patch; left unchanged."
}

# Remove our pak; shift later paks down so the game still finds them (it stops at the first missing number).
$paks = @()
for ($i = 1; $i -lt 100; $i++) {
    $p = Join-Path $GameDir "res$i.pak"
    if (-not (Test-Path $p)) { break }
    $paks += $p
}
$keep = @($paks | Where-Object { -not (Pak-IsOurs $_) })
if ($keep.Count -ne $paks.Count) {
    $tmp = @()
    foreach ($p in $keep) { $t = "$p.tmp-move"; Move-Item $p $t -Force; $tmp += $t }
    foreach ($p in $paks) { if (Test-Path $p) { Remove-Item $p -Force } }
    for ($i = 0; $i -lt $tmp.Count; $i++) { Move-Item $tmp[$i] (Join-Path $GameDir ("res" + ($i + 1) + ".pak")) -Force }
    Write-Host "Vietnamese texts and fonts removed."
} else {
    Write-Host "No Vietnamese pak found."
}
Write-Host "Uninstalled. If the game was set to Vietnamese it starts in English now." -ForegroundColor Green
