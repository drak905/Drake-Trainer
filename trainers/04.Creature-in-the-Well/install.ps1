# Creature in the Well trainer - installer (PowerShell 5.1+).  Offline / single-player use only.
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1 [-GameDir "D:\Games\CreatureintheWell"] [-Force]
param([string]$GameDir = "", [switch]$Force)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dll  = Join-Path $here 'xinput1_3.dll'
if (-not (Test-Path $dll)) { throw "xinput1_3.dll not found next to install.ps1" }

# the exe build this trainer was written and tested against (Epic build 1.0.0-137001-1)
$known = @{ 'C6A31630699E24C7078F2423234D6803ECA96AA9E11A83D81F49A8A6045EAA54' = 'Creature in the Well 1.0.0-137001-1 (Epic)' }

# 1. find the game folder (Epic manifests, else ask)
if (-not $GameDir) {
  $m = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path $m) {
    foreach ($f in Get-ChildItem $m -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.LaunchExecutable -eq 'CITW.exe' -and (Test-Path $j.InstallLocation)) { $GameDir = $j.InstallLocation; break }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Path of the Creature in the Well folder (the one containing CITW.exe)" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
$bin = Join-Path $GameDir 'CITW\Binaries\Win64'
$exe = Join-Path $bin 'CITW-Win64-Shipping.exe'
if (-not (Test-Path $exe)) { throw "'$exe' not found. Point -GameDir at the folder that contains CITW.exe." }
Write-Host "Game folder: $GameDir"

# 2. the game must be closed (xinput1_3.dll is locked while it runs)
if (Get-Process -Name 'CITW-Win64-Shipping','CITW' -ErrorAction SilentlyContinue) { throw "Close Creature in the Well first (check Task Manager)." }

# 3. version check - the trainer also re-checks every hook signature at start-up and disables a hook it cannot find
$h = (Get-FileHash $exe -Algorithm SHA256).Hash
if ($known.ContainsKey($h)) { Write-Host "Detected: $($known[$h])" }
else {
  Write-Warning "Unknown CITW-Win64-Shipping.exe (sha256 $h). The trainer only enables features whose code signature it finds (see citw_trainer.log), but it is only tested on the Epic 1.0.0-137001-1 build."
  if (-not $Force) { $a = Read-Host "Install anyway? (y/N)"; if ($a -notmatch '^[yY]') { Write-Host "Aborted."; exit 1 } }
}

# 4. install (keep any other xinput1_3.dll that was already there)
$target = Join-Path $bin 'xinput1_3.dll'
$ours   = (Get-FileHash $dll -Algorithm SHA256).Hash
if (Test-Path $target) {
  $cur = (Get-FileHash $target -Algorithm SHA256).Hash
  if ($cur -ne $ours) {
    $bak = Join-Path $bin 'xinput1_3.dll.pre-trainer.bak'
    if (-not (Test-Path $bak)) { Copy-Item $target $bak; Write-Host "Existing xinput1_3.dll saved as xinput1_3.dll.pre-trainer.bak" }
  }
}
Copy-Item $dll $target -Force
if ((Get-FileHash $target -Algorithm SHA256).Hash -ne $ours) { throw "Copy verification failed." }
$ini = Join-Path $bin 'citw_trainer.ini'
if (-not (Test-Path $ini)) { Copy-Item (Join-Path $here 'citw_trainer.ini') $ini }
Write-Host ""
Write-Host "Installed to $bin"
Write-Host "Start the game (Epic launcher or CITW.exe), load your save, then use the keys listed in README.md (the overlay shows them)."
Write-Host "Log file: $bin\citw_trainer.log   (should end with 'hooks installed: 8/8')"
