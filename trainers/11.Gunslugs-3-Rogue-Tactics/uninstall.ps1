param(
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
$PatchRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-GameDirectory {
    param([string]$InputDir)
    $Candidates = @()
    if ($InputDir) { $Candidates += $InputDir }
    if ($env:GUNSLUGS3_DIR) { $Candidates += $env:GUNSLUGS3_DIR }
    $Candidates += @(
        (Get-Location).Path,
        $PatchRoot,
        (Split-Path -Parent $PatchRoot),
        "E:\GOGGalaxy\Gunslugs3RogueTactics",
        "C:\GOG Games\Gunslugs 3 - Rogue Tactics",
        "D:\GOG Games\Gunslugs 3 - Rogue Tactics",
        "E:\GOG Games\Gunslugs 3 - Rogue Tactics",
        "C:\Program Files (x86)\GOG Galaxy\Games\Gunslugs3RogueTactics",
        "C:\Program Files (x86)\Steam\steamapps\common\Gunslugs 3"
    )
    foreach ($cand in $Candidates) {
        if ($cand -and (Test-Path (Join-Path $cand "gunslugs3.dat")) -and (Test-Path (Join-Path $cand "gunslugs3.exe"))) {
            return (Resolve-Path $cand).Path
        }
    }
    return $null
}

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " Gunslugs 3: Rogue Tactics - In-Game Trainer Uninstaller v1.0 " -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

$ResolvedDir = Resolve-GameDirectory -InputDir $GameDir
if (-not $ResolvedDir) {
    $UserEntered = Read-Host "Enter the full path to your Gunslugs 3: Rogue Tactics folder"
    $ResolvedDir = Resolve-GameDirectory -InputDir $UserEntered
}
if (-not $ResolvedDir) {
    throw "Could not find gunslugs3.exe and gunslugs3.dat in the specified folder."
}

$TargetCfg     = Join-Path $ResolvedDir "config.json"
$TargetCfgOrig = Join-Path $ResolvedDir "config.json.orig"
$TargetJar     = Join-Path $ResolvedDir "gunslugs3-trainer.jar"

if (Test-Path $TargetCfgOrig) {
    Write-Host "[1/2] Restoring original config.json from config.json.orig..."
    Copy-Item -Force $TargetCfgOrig $TargetCfg
    Remove-Item -Force $TargetCfgOrig
} else {
    Write-Host "[1/2] Writing clean default Packr config.json..."
    $CleanConfig = @"
{
  "classPath": [
    "gunslugs3.dat"
  ],
  "mainClass": "com.orangepixel.gunslugs3.desktop.Main",
  "vmArgs": [
    "-Xmx1G"
  ]
}
"@
    Set-Content -Path $TargetCfg -Value $CleanConfig -Encoding ASCII
}

if (Test-Path $TargetJar) {
    Write-Host "[2/2] Removing gunslugs3-trainer.jar..."
    Remove-Item -Force $TargetJar
} else {
    Write-Host "[2/2] gunslugs3-trainer.jar already removed."
}

Write-Host ""
Write-Host "[SUCCESS] Gunslugs 3 Trainer has been completely uninstalled and the original game configuration is restored." -ForegroundColor Green
