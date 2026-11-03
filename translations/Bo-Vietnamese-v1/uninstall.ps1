# Removes everything install.ps1 added. BepInEx itself is removed only if this pack installed it AND no other mod is using it.
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
$ExeName = "Bo.exe"
$ManifestName = "BoVietnamese_install_manifest.txt"
if (-not $GameDir) {
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1882554410","HKLM:\SOFTWARE\GOG.com\Games\1882554410")) {
    try { $p = (Get-ItemProperty $k -ErrorAction Stop).path; if ($p -and (Test-Path -LiteralPath (Join-Path $p $ManifestName))) { $GameDir = $p; break } } catch {}
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process -Name "Bo" -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir $ManifestName
if (-not (Test-Path -LiteralPath $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }

$all = Get-Content -LiteralPath $manifest
$ownsBep = $all -contains "#BEPINEX_INSTALLED_BY_THIS_PACK"
$files = $all | Where-Object { $_ -and -not $_.StartsWith("#") }
$otherMods = (Test-Path -LiteralPath (Join-Path $GameDir "BoTrainer_install_manifest.txt"))
foreach ($r in $files) {
  $isBep = ($r -like "BepInEx\core\*") -or ($r -in @("winhttp.dll","doorstop_config.ini",".doorstop_version"))
  if ($isBep -and ($otherMods -or -not $ownsBep)) { continue }   # keep BepInEx for the other mod
  $p = Join-Path $GameDir $r
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
if ($ownsBep -and -not $otherMods) {
  foreach ($o in @("winhttp.dll","doorstop_config.ini")) { $p = Join-Path $GameDir "$o.orig"; if (Test-Path -LiteralPath $p) { Move-Item -LiteralPath $p (Join-Path $GameDir $o) -Force } }
}
Remove-Item -LiteralPath $manifest -Force
Remove-Item -LiteralPath (Join-Path $GameDir "BepInEx\config\com.research.bovietnamese.cfg") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $GameDir "vi_selftest_report.json") -Force -ErrorAction SilentlyContinue
if ($Purge -and $ownsBep -and -not $otherMods) { Remove-Item -LiteralPath (Join-Path $GameDir "BepInEx") -Recurse -Force -ErrorAction SilentlyContinue }
else { foreach ($d in @("BepInEx\plugins\BoVietnamese","BepInEx\core","BepInEx\plugins","BepInEx\patchers","BepInEx\config","BepInEx\cache","BepInEx")) { $p = Join-Path $GameDir $d; if ((Test-Path -LiteralPath $p) -and -not (Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $p -Force } } }
Write-Host "Vietnamese language pack removed from $GameDir (the game falls back to its previous language automatically)."
