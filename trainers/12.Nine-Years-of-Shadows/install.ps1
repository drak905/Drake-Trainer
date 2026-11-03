# 9 Years of Shadows - Offline Trainer installer (BepInEx 5 + plugin). Safe to re-run.
# If the game already has a BepInEx 5 loader (for example from another mod such as a language pack),
# that loader is kept and only the trainer plugin is added.
# Usage: install.ps1 [-GameDir "D:\Games\9 Years of Shadows"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "9 Years of Shadows.exe"
$DataDir = "9 Years of Shadows_Data"
$KnownAsmSha256 = "DF093CA6701D758E63CB7339274A568D366D80139BAF6EB17EDDB425D83DBC0E"   # GOG v1.0.41
$PluginRel = "BepInEx\plugins\NysTrainer.dll"

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path (Join-Path $p $ExeName)) -and (Test-Path (Join-Path $p "$DataDir\Managed\Assembly-CSharp.dll")))
}
function Find-Game {
  # 1) GOG registry
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\2099051765","HKLM:\SOFTWARE\GOG.com\Games\2099051765")) {
    try { $p = (Get-ItemProperty $k -ErrorAction Stop).path; if (Test-GameDir $p) { return $p } } catch {}
  }
  # 2) Steam libraries
  $steamRoots = @()
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam","HKLM:\SOFTWARE\Valve\Steam","HKCU:\Software\Valve\Steam")) {
    try { $v = (Get-ItemProperty $k -ErrorAction Stop); foreach ($n in "InstallPath","SteamPath") { if ($v.$n) { $steamRoots += $v.$n } } } catch {}
  }
  foreach ($s in ($steamRoots | Select-Object -Unique)) {
    $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
    $libs = @($s)
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\','\') } }
    foreach ($l in $libs) { $p = Join-Path $l "steamapps\common\9 Years of Shadows"; if (Test-GameDir $p) { return $p } }
  }
  # 3) common folders on every fixed drive
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
    foreach ($rel in @("GOG Games\9 Years of Shadows","GOGGalaxy\9 Years of Shadows","GOG Galaxy\Games\9 Years of Shadows","Program Files (x86)\GOG Galaxy\Games\9 Years of Shadows","Games\9 Years of Shadows","003.GOG\9 Years of Shadows","SteamLibrary\steamapps\common\9 Years of Shadows","Program Files (x86)\Steam\steamapps\common\9 Years of Shadows")) {
      $p = Join-Path $d.Root $rel; if (Test-GameDir $p) { return $p }
    }
  }
  return ""
}
function Same-File([string]$a, [string]$b) {
  return ((Test-Path $a) -and (Test-Path $b) -and ((Get-FileHash $a -Algorithm SHA256).Hash -eq (Get-FileHash $b -Algorithm SHA256).Hash))
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "'$ExeName' / '$DataDir\Managed\Assembly-CSharp.dll' not found in '$GameDir'." }
if (Get-Process -Name "9 Years of Shadows" -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }
if (-not (Test-Path (Join-Path $GameDir "MonoBleedingEdge"))) { Write-Warning "No MonoBleedingEdge folder: this is not the Unity-Mono build the trainer was made for." }

$sha = (Get-FileHash (Join-Path $GameDir "$DataDir\Managed\Assembly-CSharp.dll") -Algorithm SHA256).Hash
if ($sha -ne $KnownAsmSha256) {
  Write-Warning "Game code differs from the tested build (GOG v1.0.41). The trainer hooks methods by name and usually still works; if a feature does nothing, see BepInEx\LogOutput.log."
}

$payload  = Join-Path $PSScriptRoot "payload"
$manifest = Join-Path $GameDir "NysTrainer_install_manifest.txt"
$oldManifest = @(); if (Test-Path $manifest) { $oldManifest = @(Get-Content $manifest) }

# Existing BepInEx 5 loader (installed by us earlier or by another mod)? Then keep it untouched.
$keepLoader = $false
$existingCore = Join-Path $GameDir "BepInEx\core\BepInEx.dll"
if ((Test-Path $existingCore) -and (Test-Path (Join-Path $GameDir "winhttp.dll"))) {
  $ver = (Get-Item $existingCore).VersionInfo.FileVersion
  if ($ver -and $ver.StartsWith("5.")) {
    $keepLoader = $true
    if (-not (Same-File $existingCore (Join-Path $payload "BepInEx\core\BepInEx.dll"))) {
      Write-Host "Existing BepInEx $ver found - keeping it and adding only the trainer plugin."
    }
  }
}

$files = Get-ChildItem $payload -Recurse -File -Force
$rel = @()
foreach ($f in $files) {
  $r = $f.FullName.Substring($payload.Length + 1)
  $isLoader = ($r -ne $PluginRel)
  if ($isLoader -and $keepLoader) {
    if ($oldManifest -contains $r) { $rel += $r }   # we installed it earlier: remember that
    continue
  }
  $dst = Join-Path $GameDir $r
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if ((Test-Path $dst) -and $r -in @("winhttp.dll","doorstop_config.ini") -and -not (Test-Path "$dst.orig") -and -not (Same-File $dst $f.FullName)) { Copy-Item $dst "$dst.orig" -Force }
  Copy-Item $f.FullName $dst -Force
  $rel += $r
}
if ($rel -notcontains $PluginRel) { $rel += $PluginRel }
$rel | Select-Object -Unique | Set-Content $manifest
Write-Host "Installed trainer into $GameDir  ($($rel.Count) files tracked)"
Write-Host ""
Write-Host "Start the game normally (GOG Galaxy or '$ExeName'). In-game hotkeys:"
Write-Host "  F1 God Mode   F2 Add Coins   F3 Infinite Money   F4 Unlimited Jump   F5 Speed x2"
Write-Host "  F6 One-Hit Kill   F7 Infinite Magic   F8 Full Heal   F9 hide/show overlay"
Write-Host "  F10 Reveal Map   F11 Items on Map   F12 Unlimited Items"
Write-Host "  Home Walk through Gates   End Walk through Walls   Insert Save diagnostics   Delete Unstick"



