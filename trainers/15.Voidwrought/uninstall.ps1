# Removes everything install.ps1 added. Use -Purge to also delete the trainer config and BepInEx logs.
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
$ExeName = "Voidwrought.exe"
if (-not $GameDir) {
  foreach ($f in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue)) {
    try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json; if ($j.LaunchExecutable -eq $ExeName -and (Test-Path (Join-Path $j.InstallLocation "VwTrainer_install_manifest.txt"))) { $GameDir = $j.InstallLocation } } catch {}
  }
}
if (-not $GameDir) {
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
    foreach ($rel in @("EpicGames\VoidwroughtFq9Qv","Epic Games\VoidwroughtFq9Qv","Program Files\Epic Games\VoidwroughtFq9Qv","Games\Voidwrought","SteamLibrary\steamapps\common\Voidwrought","GOG Games\Voidwrought","GOGGalaxy\Voidwrought")) {
      if (Test-Path (Join-Path (Join-Path $d.Root $rel) "VwTrainer_install_manifest.txt")) { $GameDir = Join-Path $d.Root $rel }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains $ExeName" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process ([IO.Path]::GetFileNameWithoutExtension($ExeName)) -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir "VwTrainer_install_manifest.txt"
if (-not (Test-Path $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }
# keep the BepInEx loader when the Vietnamese language pack is installed (it needs it too)
$viPack = Test-Path (Join-Path $GameDir "VwVietnamese_install_manifest.txt")
foreach ($r in (Get-Content $manifest)) {
  if ($viPack -and (($r -like "BepInEx\core\*") -or ($r -in @("winhttp.dll","doorstop_config.ini",".doorstop_version")))) { continue }
  $p = Join-Path $GameDir $r; if (Test-Path $p) { Remove-Item $p -Force }
}
if (-not $viPack) { foreach ($o in @("winhttp.dll","doorstop_config.ini")) { $p = Join-Path $GameDir "$o.orig"; if (Test-Path $p) { Move-Item $p (Join-Path $GameDir $o) -Force } } }
Remove-Item $manifest -Force
foreach ($x in @("trainer_selftest_report.json","trainer_selftest.flag","trainer_dump.txt")) { Remove-Item (Join-Path $GameDir $x) -Force -ErrorAction SilentlyContinue }
if ($Purge -and -not $viPack) { Remove-Item (Join-Path $GameDir "BepInEx") -Recurse -Force -ErrorAction SilentlyContinue }
else { foreach ($d in @("BepInEx\core","BepInEx\plugins","BepInEx\patchers","BepInEx\cache","BepInEx")) { $p = Join-Path $GameDir $d; if ((Test-Path $p) -and -not (Get-ChildItem $p -Force -ErrorAction SilentlyContinue)) { Remove-Item $p -Force } } }
Write-Host "Trainer removed from $GameDir"

