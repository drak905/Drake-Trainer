# 9 Years of Shadows - Vietnamese language pack installer (BepInEx 5 plugin). Safe to re-run.
# Usage: install.ps1 [-GameDir "D:\Games\9 Years of Shadows"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "9 Years of Shadows.exe"
$DataDir = "9 Years of Shadows_Data"
$ManifestName = "NysVietnamese_install_manifest.txt"

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path -LiteralPath (Join-Path $p $ExeName)) -and (Test-Path -LiteralPath (Join-Path $p "$DataDir\Managed\Assembly-CSharp.dll")) -and (Test-Path -LiteralPath (Join-Path $p "MonoBleedingEdge")))
}
function Find-InFolder([string]$root, [int]$depth) {
  if (-not (Test-Path -LiteralPath $root)) { return "" }
  if (Test-GameDir $root) { return $root }
  if ($depth -le 0) { return "" }
  foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
    $r = Find-InFolder $d.FullName ($depth - 1); if ($r) { return $r }
  }
  return ""
}
function Find-Game {
  # 1) GOG registry (gameId 2099051765)
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
    foreach ($l in $libs) { $r = Find-InFolder (Join-Path $l "steamapps\common") 1; if ($r) { return $r } }
  }
  # 3) common folders on every fixed drive
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
    foreach ($rel in @("GOGGalaxy","GOG Galaxy\Games","GOG Games","Program Files (x86)\GOG Galaxy\Games","Games","SteamLibrary\steamapps\common","Program Files (x86)\Steam\steamapps\common","Program Files\Epic Games","EpicGames")) {
      $r = Find-InFolder (Join-Path $d.Root $rel) 1; if ($r) { return $r }
    }
  }
  return ""
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "'$ExeName' / '$DataDir\Managed\Assembly-CSharp.dll' / 'MonoBleedingEdge' not found in '$GameDir'. This language pack is for the Unity-Mono PC build of 9 Years of Shadows." }
if (Get-Process -Name "9 Years of Shadows" -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }

$manifest = Join-Path $GameDir $ManifestName
$rel = @()
$installedBepInEx = $false
if ((Test-Path -LiteralPath $manifest) -and ((Get-Content -LiteralPath $manifest) -contains "#BEPINEX_INSTALLED_BY_THIS_PACK")) { $installedBepInEx = $true; $rel += (Get-Content -LiteralPath $manifest | Where-Object { $_ -and -not $_.StartsWith("#") -and (($_ -like "BepInEx\core\*") -or ($_ -in @("winhttp.dll","doorstop_config.ini",".doorstop_version"))) }) }

# --- 1) BepInEx (only when the game does not have it yet, e.g. already installed by the 9 Years of Shadows trainer) -------------------------
$bepOk = Test-Path -LiteralPath (Join-Path $GameDir "BepInEx\core\BepInEx.dll")
if (-not $bepOk) {
  $src = Join-Path $PSScriptRoot "payload\bepinex"
  foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
    $r = $f.FullName.Substring($src.Length + 1)
    $dst = Join-Path $GameDir $r
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    if ((Test-Path -LiteralPath $dst) -and $r -in @("winhttp.dll","doorstop_config.ini") -and -not (Test-Path -LiteralPath "$dst.orig")) { Copy-Item -LiteralPath $dst "$dst.orig" -Force }
    Copy-Item -LiteralPath $f.FullName $dst -Force
    $rel += $r
  }
  $installedBepInEx = $true
  Write-Host "Installed BepInEx 5.4.23.3 (mod loader)."
} else {
  Write-Host "BepInEx already present - reusing it."
}

# --- 2) the Vietnamese plugin ----------------------------------------------------------------------------------------------
$src = Join-Path $PSScriptRoot "payload\plugin"
foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
  $r = $f.FullName.Substring($src.Length + 1)
  $dst = Join-Path $GameDir $r
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  Copy-Item -LiteralPath $f.FullName $dst -Force
  $rel += $r
}

$lines = @()
if ($installedBepInEx) { $lines += "#BEPINEX_INSTALLED_BY_THIS_PACK" }
$lines += $rel
$lines | Set-Content -LiteralPath $manifest -Encoding ASCII

Write-Host ""
Write-Host "Installed the Vietnamese language pack into $GameDir"
Write-Host "Start the game, then choose:  OPTIONS > GAME > LANGUAGE > 'Tieng Viet' (use the left/right arrows, then move to another row to confirm)."
