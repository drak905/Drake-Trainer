# Astral Ascent trainer - installer (PowerShell 5.1+).  Offline / single-player use only.
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1 [-GameDir "D:\Games\AstralAscent"] [-Force]
param([string]$GameDir = "", [switch]$Force)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dll  = Join-Path $here 'winmm.dll'
if (-not (Test-Path $dll)) { throw "winmm.dll not found next to install.ps1" }

# exe builds this trainer was written and tested against (Astral Ascent 2.7.1, Epic build, 177430016 bytes)
$known = @{
  'D45E8AC395D6A3D48D3A0D365E88A5247D5EB50DA04FDCA555E3E9CFACFE9300' = 'Astral Ascent 2.7.1 (original)'
  '3B3E8E101B5EE392C1BEAC6CF58101B400D20600B721816F85900D0CE8A508BD' = 'Astral Ascent 2.7.1 (with optional debug-menu default patch)'
}

# 1. the proxy forwards to C:\Windows\System32\winmm.dll (path is fixed inside the DLL)
if ($env:SystemRoot -ne 'C:\Windows') {
  throw "Windows is installed in '$env:SystemRoot'. This build forwards to C:\Windows\System32\winmm.dll and would not load. Rebuild from source\ (edit winmm.def)."
}

# 2. find the game folder
if (-not $GameDir) {
  $m = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path $m) {
    foreach ($f in Get-ChildItem $m -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.LaunchExecutable -eq 'Astral Ascent.exe' -and (Test-Path $j.InstallLocation)) { $GameDir = $j.InstallLocation; break }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Path of the Astral Ascent folder (the one containing 'Astral Ascent.exe')" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
$exe = Join-Path $GameDir 'Astral Ascent.exe'
if (-not (Test-Path $exe)) { throw "'Astral Ascent.exe' not found in '$GameDir'." }
Write-Host "Game folder: $GameDir"

# 3. game must be closed (winmm.dll is locked while it runs)
if (Get-Process -Name 'Astral Ascent' -ErrorAction SilentlyContinue) { throw "Close Astral Ascent first (check Task Manager - it can linger after closing)." }

# 4. version check
$h = (Get-FileHash $exe -Algorithm SHA256).Hash
if ($known.ContainsKey($h)) { Write-Host "Detected: $($known[$h])" }
else {
  Write-Warning "Unknown Astral Ascent.exe (sha256 $h). The trainer checks the game's memory layout and code at start-up and simply disables itself (see aa_debugmenu.log) if it does not match, but it is only tested on 2.7.1."
  if (-not $Force) { $a = Read-Host "Install anyway? (y/N)"; if ($a -notmatch '^[yY]') { Write-Host "Aborted."; exit 1 } }
}

# 5. install (keep any other winmm.dll that was already there)
$target = Join-Path $GameDir 'winmm.dll'
$ours   = (Get-FileHash $dll -Algorithm SHA256).Hash
if (Test-Path $target) {
  $cur = (Get-FileHash $target -Algorithm SHA256).Hash
  if ($cur -eq $ours) { Write-Host "Trainer already installed (identical winmm.dll)."; exit 0 }
  $bak = Join-Path $GameDir 'winmm.dll.pre-trainer.bak'
  if (-not (Test-Path $bak)) { Copy-Item $target $bak; Write-Host "Existing winmm.dll saved as winmm.dll.pre-trainer.bak" }
}
Copy-Item $dll $target -Force
if ((Get-FileHash $target -Algorithm SHA256).Hash -ne $ours) { throw "Copy verification failed." }
Write-Host ""
Write-Host "Installed.  Start the game from the Epic Games launcher, load your save, press F10."
Write-Host "Log file: $GameDir\aa_debugmenu.log   (should contain 'game object verified' and 'hooks: 5/5 call sites patched')"
