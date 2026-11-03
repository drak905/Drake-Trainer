# Ogu and the Secret Forest - Offline Trainer installer (BepInEx 5 + plugin). Safe to re-run.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
function Find-Game {
  foreach ($f in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue)) {
    try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json; if ($j.LaunchExecutable -eq "OguForest.exe" -and (Test-Path (Join-Path $j.InstallLocation "OguForest.exe"))) { return $j.InstallLocation } } catch {}
  }
  foreach ($p in @("C:\Program Files\Epic Games\OguandtheSecretFores6K1u7","D:\Epic Games\OguandtheSecretFores6K1u7","E:\EpicGames\OguandtheSecretFores6K1u7","C:\Program Files (x86)\Steam\steamapps\common\Ogu and the Secret Forest")) { if (Test-Path (Join-Path $p "OguForest.exe")) { return $p } }
  return ""
}
if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains OguForest.exe" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-Path (Join-Path $GameDir "OguForest.exe")) -or -not (Test-Path (Join-Path $GameDir "OguForest_Data\Managed\Assembly-CSharp.dll"))) { throw "OguForest.exe / OguForest_Data\Managed\Assembly-CSharp.dll not found in '$GameDir'." }
if (Get-Process OguForest -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }
if (-not (Test-Path (Join-Path $GameDir "MonoBleedingEdge"))) { Write-Warning "No MonoBleedingEdge folder: this is not the Unity-Mono build the trainer was made for." }
$payload = Join-Path $PSScriptRoot "payload"
$manifest = Join-Path $GameDir "OguTrainer_install_manifest.txt"
$files = Get-ChildItem $payload -Recurse -File -Force
$rel = @()
foreach ($f in $files) {
  $r = $f.FullName.Substring($payload.Length + 1)
  $dst = Join-Path $GameDir $r
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if ((Test-Path $dst) -and $r -in @("winhttp.dll","doorstop_config.ini") -and -not (Test-Path "$dst.orig")) { Copy-Item $dst "$dst.orig" -Force }
  Copy-Item $f.FullName $dst -Force
  $rel += $r
}
$rel | Set-Content $manifest
Write-Host "Installed $($rel.Count) files into $GameDir"
Write-Host "Start the game normally (Epic launcher or OguForest.exe). In-game overlay: F1 God, F2 +Money, F3 Infinite Money, F4 Speed x2, F5 No Cooldown, F6 One-Hit Kill, F7 Heal, F8 hide overlay."
