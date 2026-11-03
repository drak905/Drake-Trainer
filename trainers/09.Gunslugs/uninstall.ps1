# Removes everything install.ps1 added and restores config.json.orig.
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
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains gunslugs.exe and gunslugs.dat" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')

if (Get-Process gunslugs -ErrorAction SilentlyContinue) {
  throw "Close Gunslugs first."
}

$cfgOrig = Join-Path $GameDir "config.json.orig"
$cfgPath = Join-Path $GameDir "config.json"
if (Test-Path $cfgOrig) {
  Move-Item $cfgOrig $cfgPath -Force
} else {
  $defaultCfg = @"
{
  "classPath": [
    "gunslugs.dat"
  ],
  "mainClass": "com.orangepixel.gunslugs.Main",
  "vmArgs": [
    "-Xmx1G"
  ]
}
"@
  [System.IO.File]::WriteAllText($cfgPath, $defaultCfg, [System.Text.Encoding]::ASCII)
}

foreach ($f in @(
  "gunslugs-trainer.jar",
  "GunslugsTrainer_install_manifest.txt",
  "trainer_selftest_report.json",
  "trainer_selftest_screenshot.png"
)) {
  $p = Join-Path $GameDir $f
  if (Test-Path $p) { Remove-Item $p -Force }
}

if (-not $Quiet) {
  Write-Host "Gunslugs Trainer removed from $GameDir"
}
