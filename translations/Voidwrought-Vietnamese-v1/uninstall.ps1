# Removes everything install.ps1 added. BepInEx itself is removed only if this pack installed it AND the Voidwrought trainer
# is not using it. Also switches the game's saved language back to English if it was set to Vietnamese (otherwise the game
# would fail to start without the pack).
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
$ExeName = "Voidwrought.exe"
$ManifestName = "VwVietnamese_install_manifest.txt"
if (-not $GameDir) {
  foreach ($f in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue)) {
    try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json; if ($j.LaunchExecutable -eq $ExeName -and (Test-Path -LiteralPath (Join-Path $j.InstallLocation $ManifestName))) { $GameDir = $j.InstallLocation } } catch {}
  }
}
if (-not $GameDir) {
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
    foreach ($rel in @("EpicGames\VoidwroughtFq9Qv","Epic Games\VoidwroughtFq9Qv","Program Files\Epic Games\VoidwroughtFq9Qv","Games\Voidwrought","SteamLibrary\steamapps\common\Voidwrought","GOG Games\Voidwrought","GOGGalaxy\Voidwrought")) {
      if (Test-Path -LiteralPath (Join-Path (Join-Path $d.Root $rel) $ManifestName)) { $GameDir = Join-Path $d.Root $rel }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains $ExeName" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process ([IO.Path]::GetFileNameWithoutExtension($ExeName)) -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir $ManifestName
if (-not (Test-Path -LiteralPath $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }

# 1) saved language: index 11 = Vietnamese (the 12th language). Without the pack the game would index past its language list.
$settings = Join-Path $env:USERPROFILE "AppData\LocalLow\Powersnake\Voidwrought\Settings.json"
if (Test-Path -LiteralPath $settings) {
  $txt = [IO.File]::ReadAllText($settings)
  $m = [regex]::Match($txt, '"Language"\s*:\s*(\d+)')
  if ($m.Success -and [int]$m.Groups[1].Value -ge 11) {
    $new = [regex]::Replace($txt, '("Language"\s*:\s*)\d+', '${1}0')
    [IO.File]::WriteAllText($settings, $new, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Saved game language set back to English (Settings.json)."
  }
}

# 2) files
$all = Get-Content -LiteralPath $manifest
$ownsBep = $all -contains "#BEPINEX_INSTALLED_BY_THIS_PACK"
$files = $all | Where-Object { $_ -and -not $_.StartsWith("#") }
$otherMods = (Test-Path -LiteralPath (Join-Path $GameDir "VwTrainer_install_manifest.txt"))
foreach ($r in $files) {
  $isBep = ($r -like "BepInEx\core\*") -or ($r -in @("winhttp.dll","doorstop_config.ini",".doorstop_version"))
  if ($isBep -and ($otherMods -or -not $ownsBep)) { continue }   # keep BepInEx for the trainer
  $p = Join-Path $GameDir $r
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
if ($ownsBep -and -not $otherMods) {
  foreach ($o in @("winhttp.dll","doorstop_config.ini")) { $p = Join-Path $GameDir "$o.orig"; if (Test-Path -LiteralPath $p) { Move-Item -LiteralPath $p (Join-Path $GameDir $o) -Force } }
}
Remove-Item -LiteralPath $manifest -Force
foreach ($x in @("vi_selftest_report.json","vi_selftest.flag","vi_force.flag")) { Remove-Item -LiteralPath (Join-Path $GameDir $x) -Force -ErrorAction SilentlyContinue }
if ($Purge -and $ownsBep -and -not $otherMods) { Remove-Item -LiteralPath (Join-Path $GameDir "BepInEx") -Recurse -Force -ErrorAction SilentlyContinue }
else { foreach ($d in @("BepInEx\plugins\VwVietnamese","BepInEx\core","BepInEx\plugins","BepInEx\patchers","BepInEx\config","BepInEx\cache","BepInEx")) { $p = Join-Path $GameDir $d; if ((Test-Path -LiteralPath $p) -and -not (Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $p -Force } } }
Write-Host "Vietnamese language pack removed from $GameDir"
