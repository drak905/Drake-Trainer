# Gunslugs - Offline Trainer v1 installer (Packr classpath override). Safe to re-run.
param([string]$GameDir = "", [switch]$Quiet)
$ErrorActionPreference = "Stop"

function Find-Game {
  foreach ($reg in @(
    "HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1709371377",
    "HKLM:\SOFTWARE\GOG.com\Games\1709371377"
  )) {
    try {
      if (Test-Path $reg) {
        $p = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).path
        if ($p -and (Test-Path (Join-Path $p "gunslugs.dat"))) { return $p }
      }
    } catch {}
  }
  foreach ($p in @(
    "E:\GOGGalaxy\Gunslugs",
    "C:\GOG Games\Gunslugs",
    "D:\GOG Games\Gunslugs",
    "E:\GOG Games\Gunslugs",
    "C:\Program Files (x86)\GOG Galaxy\Games\Gunslugs",
    "C:\Program Files (x86)\Steam\steamapps\common\Gunslugs",
    "D:\SteamLibrary\steamapps\common\Gunslugs",
    "E:\SteamLibrary\steamapps\common\Gunslugs"
  )) {
    if (Test-Path (Join-Path $p "gunslugs.dat")) { return $p }
  }
  return ""
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains gunslugs.exe and gunslugs.dat" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')

$exePath = Join-Path $GameDir "gunslugs.exe"
$datPath = Join-Path $GameDir "gunslugs.dat"
$cfgPath = Join-Path $GameDir "config.json"

if (-not (Test-Path $exePath) -or -not (Test-Path $datPath) -or -not (Test-Path $cfgPath)) {
  throw "gunslugs.exe, gunslugs.dat, or config.json not found in '$GameDir'."
}

if (Get-Process gunslugs -ErrorAction SilentlyContinue) {
  throw "Close Gunslugs first, then run the installer again."
}

$payloadJar = Join-Path $PSScriptRoot "payload\gunslugs-trainer.jar"
if (-not (Test-Path $payloadJar)) {
  throw "Missing payload\gunslugs-trainer.jar in package."
}

$cfgOrigPath = Join-Path $GameDir "config.json.orig"
if (-not (Test-Path $cfgOrigPath)) {
  Copy-Item $cfgPath $cfgOrigPath -Force
}

$dstJar = Join-Path $GameDir "gunslugs-trainer.jar"
Copy-Item $payloadJar $dstJar -Force

$newCfg = @"
{
  "classPath": [
    "gunslugs-trainer.jar",
    "gunslugs.dat"
  ],
  "mainClass": "com.orangepixel.gunslugs.Main",
  "vmArgs": [
    "-Xmx1G"
  ]
}
"@
[System.IO.File]::WriteAllText($cfgPath, $newCfg, [System.Text.Encoding]::ASCII)

$manifest = Join-Path $GameDir "GunslugsTrainer_install_manifest.txt"
@(
  "gunslugs-trainer.jar",
  "config.json"
) | Set-Content -Path $manifest -Encoding ASCII

if (-not $Quiet) {
  Write-Host "Installed Gunslugs Trainer v1 into $GameDir"
  Write-Host "Original gunslugs.exe and gunslugs.dat are unmodified (config.json backed up to config.json.orig)."
  Write-Host "Hotkeys in game: F1 God Mode | F2 +500 Coins | F3 Inf Money+Items | F4 Inf Jump | F5 Speed x2 | F6 Map Item ESP | F7 One-Hit Kill | F8 Cycle Weapon | F9 Hide Menu"
}
