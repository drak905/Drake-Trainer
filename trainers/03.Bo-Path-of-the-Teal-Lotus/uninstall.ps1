# Removes everything install.ps1 added. Use -Purge to also delete the trainer config and BepInEx logs.
# If the Bo Vietnamese language pack is installed too, BepInEx (mod loader) is kept for it and ownership passes to that pack.
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
$ExeName = "Bo.exe"
if (-not $GameDir) {
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1882554410","HKLM:\SOFTWARE\GOG.com\Games\1882554410")) {
    try { $p = (Get-ItemProperty $k -ErrorAction Stop).path; if ($p -and (Test-Path -LiteralPath (Join-Path $p "BoTrainer_install_manifest.txt"))) { $GameDir = $p; break } } catch {}
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process -Name "Bo" -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir "BoTrainer_install_manifest.txt"
if (-not (Test-Path -LiteralPath $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }
$viManifest = Join-Path $GameDir "BoVietnamese_install_manifest.txt"
$otherMod = Test-Path -LiteralPath $viManifest
function IsBep([string]$r) { return ($r -like "BepInEx\core\*") -or ($r -in @("winhttp.dll","doorstop_config.ini",".doorstop_version")) }
$files = Get-Content -LiteralPath $manifest | Where-Object { $_ -and -not $_.StartsWith("#") }
foreach ($r in $files) {
  if ($otherMod -and (IsBep $r)) { continue }          # the language pack still needs the mod loader
  $p = Join-Path $GameDir $r; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
if ($otherMod) {
  # hand BepInEx over to the language pack so that its uninstaller removes it later
  $vi = @(Get-Content -LiteralPath $viManifest)
  $bep = @($files | Where-Object { IsBep $_ })
  $out = @()
  if ($vi -notcontains "#BEPINEX_INSTALLED_BY_THIS_PACK") { $out += "#BEPINEX_INSTALLED_BY_THIS_PACK" }
  $out += $vi
  foreach ($b in $bep) { if ($out -notcontains $b) { $out += $b } }
  $out | Set-Content -LiteralPath $viManifest -Encoding ASCII
} else {
  foreach ($o in @("winhttp.dll","doorstop_config.ini")) { $p = Join-Path $GameDir "$o.orig"; if (Test-Path -LiteralPath $p) { Move-Item -LiteralPath $p (Join-Path $GameDir $o) -Force } }
}
Remove-Item -LiteralPath $manifest -Force
Remove-Item -LiteralPath (Join-Path $GameDir "trainer_selftest_report.json") -Force -ErrorAction SilentlyContinue
if ($Purge -and -not $otherMod) { Remove-Item -LiteralPath (Join-Path $GameDir "BepInEx") -Recurse -Force -ErrorAction SilentlyContinue }
else { foreach ($d in @("BepInEx\core","BepInEx\plugins","BepInEx\patchers","BepInEx\cache","BepInEx")) { $p = Join-Path $GameDir $d; if ((Test-Path -LiteralPath $p) -and -not (Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $p -Force } } }
Write-Host "Trainer removed from $GameDir"
