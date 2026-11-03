# Gunslugs 2 - Offline Trainer v1 installer (Packr classpath override). Safe to re-run.
param([string]$GameDir = "", [switch]$SelfTest, [switch]$Quiet)
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
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains Gunslugs2.exe and Gunslugs2.jar" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')

$exePath = Join-Path $GameDir "Gunslugs2.exe"
$jarPath = Join-Path $GameDir "Gunslugs2.jar"
$cfgPath = Join-Path $GameDir "app\Gunslugs2.json"

if (-not (Test-Path $exePath) -or -not (Test-Path $jarPath) -or -not (Test-Path $cfgPath)) {
  throw "Gunslugs2.exe, Gunslugs2.jar, or app\Gunslugs2.json not found in '$GameDir'."
}

if (Get-Process Gunslugs2 -ErrorAction SilentlyContinue) {
  throw "Close Gunslugs 2 first, then run the installer again."
}

$payloadJar = Join-Path $PSScriptRoot "payload\gunslugs2-trainer.jar"
if (-not (Test-Path $payloadJar)) {
  throw "Missing payload\gunslugs2-trainer.jar in package."
}

$cfgOrigPath = Join-Path $GameDir "app\Gunslugs2.json.orig"
if (-not (Test-Path $cfgOrigPath)) {
  Copy-Item $cfgPath $cfgOrigPath -Force
}

$dstJar = Join-Path $GameDir "gunslugs2-trainer.jar"
Copy-Item $payloadJar $dstJar -Force

$newCfg = @"
{
  "classPath": [
    "gunslugs2-trainer.jar",
    "Gunslugs2.jar"
  ],
  "mainClass": "com.orangepixel.gunslugs2.Main",
  "vmArgs": [
    "-Xmx1G"
  ]
}
"@
[System.IO.File]::WriteAllText($cfgPath, $newCfg, [System.Text.Encoding]::ASCII)

$manifest = Join-Path $GameDir "Gunslugs2Trainer_install_manifest.txt"
@(
  "gunslugs2-trainer.jar",
  "app\Gunslugs2.json"
) | Set-Content -Path $manifest -Encoding ASCII

if (-not $Quiet) {
  Write-Host "Installed Gunslugs 2 Trainer v1 into $GameDir" -ForegroundColor Green
  Write-Host "Original Gunslugs2.exe and Gunslugs2.jar are unmodified (app\Gunslugs2.json backed up to app\Gunslugs2.json.orig)."
  Write-Host "Hotkeys in game: F1 God Mode | F2 +500 Coins | F3 Inf Money+Items | F4 Inf Jump | F5 Speed x2 | F6 Map Item ESP | F7 One-Hit Kill | F8 Cycle Weapon | F9/F10/INSERT Hide Menu"
}

if ($SelfTest) {
  Write-Host "Running automated zero-touch self-test..." -ForegroundColor Cyan
  $reportPath = Join-Path $GameDir "trainer_selftest_report.json"
  if (Test-Path $reportPath) { Remove-Item $reportPath -Force }
  $env:TRAINER_SELFTEST = "1"
  try {
    $proc = Start-Process -FilePath $exePath -WorkingDirectory $GameDir -PassThru
    $finished = $proc.WaitForExit(35000)
    if (-not $finished) {
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
      throw "Self-test timed out after 35 seconds."
    }
    if (-not (Test-Path $reportPath)) {
      throw "Self-test report was not generated at $reportPath."
    }
    $report = Get-Content $reportPath -Raw | ConvertFrom-Json
    if ($report.status -ne "PASS") {
      throw "Self-test reported status: $($report.status)"
    }
    Write-Host "Self-test PASSED! Report written to $reportPath" -ForegroundColor Green
  } finally {
    Remove-Item Env:\TRAINER_SELFTEST -ErrorAction SilentlyContinue
  }
}
