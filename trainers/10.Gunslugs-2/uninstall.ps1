# Removes everything install.ps1 added and restores app\Gunslugs2.json.orig.
param([string]$GameDir = "", [switch]$Quiet)
$ErrorActionPreference = "Stop"

function Find-Game {
  foreach ($reg in @(
    "HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1679659438",
    "HKLM:\SOFTWARE\GOG.com\Games\1679659438"
  )) {
    try {
      if (Test-Path $reg) {
        $p = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).path
        if ($p -and (Test-Path (Join-Path $p "Gunslugs2.jar"))) { return $p }
      }
    } catch {}
  }
  foreach ($p in @(
    "E:\GOGGalaxy\Gunslugs2",
    "C:\GOG Games\Gunslugs 2",
    "C:\GOG Games\Gunslugs2",
    "D:\GOG Games\Gunslugs 2",
    "D:\GOG Games\Gunslugs2",
    "E:\GOG Games\Gunslugs 2",
    "E:\GOG Games\Gunslugs2",
    "C:\Program Files (x86)\GOG Galaxy\Games\Gunslugs 2",
    "C:\Program Files (x86)\GOG Galaxy\Games\Gunslugs2",
    "C:\Program Files (x86)\Steam\steamapps\common\Gunslugs 2",
    "D:\SteamLibrary\steamapps\common\Gunslugs 2",
    "E:\SteamLibrary\steamapps\common\Gunslugs 2"
  )) {
    if (Test-Path (Join-Path $p "Gunslugs2.jar")) { return $p }
  }
  return ""
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains Gunslugs2.exe and Gunslugs2.jar" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')

if (Get-Process Gunslugs2 -ErrorAction SilentlyContinue) {
  throw "Close Gunslugs 2 first."
}

$cfgOrig = Join-Path $GameDir "app\Gunslugs2.json.orig"
$cfgPath = Join-Path $GameDir "app\Gunslugs2.json"
if (Test-Path $cfgOrig) {
  Move-Item $cfgOrig $cfgPath -Force
} else {
  $defaultCfg = @"
{
  "classPath": [
    "Gunslugs2.jar"
  ],
  "mainClass": "com.orangepixel.gunslugs2.Main",
  "vmArgs": [
    "-Xmx1G"
  ]
}
"@
  [System.IO.File]::WriteAllText($cfgPath, $defaultCfg, [System.Text.Encoding]::ASCII)
}

foreach ($f in @(
  "gunslugs2-trainer.jar",
  "Gunslugs2Trainer_install_manifest.txt",
  "trainer_selftest_report.json",
  "trainer_selftest_screenshot.png"
)) {
  $p = Join-Path $GameDir $f
  if (Test-Path $p) { Remove-Item $p -Force }
}

if (-not $Quiet) {
  Write-Host "Gunslugs 2 Trainer removed from $GameDir" -ForegroundColor Green
}
