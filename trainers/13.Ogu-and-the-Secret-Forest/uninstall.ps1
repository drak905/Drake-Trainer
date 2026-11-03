# Removes everything install.ps1 added. Use -Purge to also delete the trainer config and BepInEx logs.
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
if (-not $GameDir) {
  foreach ($f in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue)) {
    try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json; if ($j.LaunchExecutable -eq "OguForest.exe") { $GameDir = $j.InstallLocation } } catch {}
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains OguForest.exe" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process OguForest -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir "OguTrainer_install_manifest.txt"
if (-not (Test-Path $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }
foreach ($r in (Get-Content $manifest)) { $p = Join-Path $GameDir $r; if (Test-Path $p) { Remove-Item $p -Force } }
foreach ($o in @("winhttp.dll","doorstop_config.ini")) { $p = Join-Path $GameDir "$o.orig"; if (Test-Path $p) { Move-Item $p (Join-Path $GameDir $o) -Force } }
Remove-Item $manifest -Force
Remove-Item (Join-Path $GameDir "trainer_selftest_report.json") -Force -ErrorAction SilentlyContinue
if ($Purge) { Remove-Item (Join-Path $GameDir "BepInEx") -Recurse -Force -ErrorAction SilentlyContinue }
else { foreach ($d in @("BepInEx\core","BepInEx\plugins","BepInEx\patchers","BepInEx\cache","BepInEx")) { $p = Join-Path $GameDir $d; if ((Test-Path $p) -and -not (Get-ChildItem $p -Force -ErrorAction SilentlyContinue)) { Remove-Item $p -Force } } }
Write-Host "Trainer removed from $GameDir"
