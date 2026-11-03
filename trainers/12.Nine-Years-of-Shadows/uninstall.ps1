# Removes everything install.ps1 added.
# If other BepInEx plugins (for example a language pack) are installed, the shared BepInEx loader is KEPT and only the
# trainer plugin + its config are removed, so those mods keep working.
# Use -Purge to also delete the BepInEx folder (only when no other plugin uses it).
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
$ExeName = "9 Years of Shadows.exe"
$PluginRel = "BepInEx\plugins\NysTrainer.dll"
if (-not $GameDir) {
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\2099051765","HKLM:\SOFTWARE\GOG.com\Games\2099051765")) {
    try { $p = (Get-ItemProperty $k -ErrorAction Stop).path; if ($p -and (Test-Path (Join-Path $p "NysTrainer_install_manifest.txt"))) { $GameDir = $p; break } } catch {}
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process -Name "9 Years of Shadows" -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir "NysTrainer_install_manifest.txt"
if (-not (Test-Path $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }

# other BepInEx plugins present?
$plugDir = Join-Path $GameDir "BepInEx\plugins"
$others = @()
if (Test-Path $plugDir) { $others = @(Get-ChildItem $plugDir -Force | Where-Object { $_.Name -ne "NysTrainer.dll" }) }
$shared = ($others.Count -gt 0)

# always remove the trainer itself and its config / report
Remove-Item (Join-Path $GameDir $PluginRel) -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $GameDir "BepInEx\config\com.research.nystrainer.cfg") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $GameDir "trainer_selftest_report.json") -Force -ErrorAction SilentlyContinue

if ($shared) {
  Write-Host "Other BepInEx plugins found ($($others.Name -join ', ')) - the shared BepInEx loader is kept so they keep working."
  Remove-Item $manifest -Force
} else {
  foreach ($r in (Get-Content $manifest)) { $p = Join-Path $GameDir $r; if (Test-Path $p) { Remove-Item $p -Force } }
  foreach ($o in @("winhttp.dll","doorstop_config.ini")) { $p = Join-Path $GameDir "$o.orig"; if (Test-Path $p) { Move-Item $p (Join-Path $GameDir $o) -Force } }
  Remove-Item $manifest -Force
  if ($Purge) { Remove-Item (Join-Path $GameDir "BepInEx") -Recurse -Force -ErrorAction SilentlyContinue }
  else { foreach ($d in @("BepInEx\core","BepInEx\plugins","BepInEx\patchers","BepInEx\cache","BepInEx")) { $p = Join-Path $GameDir $d; if ((Test-Path $p) -and -not (Get-ChildItem $p -Force -ErrorAction SilentlyContinue)) { Remove-Item $p -Force } } }
}
Write-Host "Trainer removed from $GameDir"
