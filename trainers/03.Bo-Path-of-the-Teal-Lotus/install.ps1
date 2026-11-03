# Bo: Path of the Teal Lotus - Offline Trainer installer (BepInEx 5 + plugin). Safe to re-run.
# Usage: install.ps1 [-GameDir "D:\Games\Bo Path of the Teal Lotus"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "Bo.exe"
$DataDir = "Bo_Data"
$KnownAsmSha256 = "C2BEB51C9FCFB2A5201C92E5302540D740E2C524789587DA6F4E4E6247C538E9"   # GOG build 59597633621004325

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path -LiteralPath (Join-Path $p $ExeName)) -and (Test-Path -LiteralPath (Join-Path $p "$DataDir\Managed\Assembly-CSharp.dll")) -and (Test-Path -LiteralPath (Join-Path $p "MonoBleedingEdge")))
}
function Find-InFolder([string]$root, [int]$depth) {
  # looks for a Bo.exe + Bo_Data game folder directly in $root or up to $depth levels below it
  if (-not (Test-Path -LiteralPath $root)) { return "" }
  if (Test-GameDir $root) { return $root }
  if ($depth -le 0) { return "" }
  foreach ($d in (Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
    $r = Find-InFolder $d.FullName ($depth - 1); if ($r) { return $r }
  }
  return ""
}
function Find-Game {
  # 1) GOG registry (gameId 1882554410)
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1882554410","HKLM:\SOFTWARE\GOG.com\Games\1882554410")) {
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
  # 3) common folders on every fixed drive (GOG Galaxy / GOG Games / Steam / Epic / custom "Games")
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
if (-not (Test-GameDir $GameDir)) { throw "'$ExeName' / '$DataDir\Managed\Assembly-CSharp.dll' / 'MonoBleedingEdge' not found in '$GameDir'. This trainer is for the Unity-Mono PC build." }
if (Get-Process -Name "Bo" -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }

$sha = (Get-FileHash -LiteralPath (Join-Path $GameDir "$DataDir\Managed\Assembly-CSharp.dll") -Algorithm SHA256).Hash
if ($sha -ne $KnownAsmSha256) {
  Write-Warning "Game code differs from the tested build (GOG build 59597633621004325). The trainer hooks methods by name and usually still works; if a feature does nothing, see BepInEx\LogOutput.log."
}

$payload  = Join-Path $PSScriptRoot "payload"
$manifest = Join-Path $GameDir "BoTrainer_install_manifest.txt"
$files = Get-ChildItem -LiteralPath $payload -Recurse -File -Force
$rel = @()
foreach ($f in $files) {
  $r = $f.FullName.Substring($payload.Length + 1)
  $dst = Join-Path $GameDir $r
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if ((Test-Path -LiteralPath $dst) -and $r -in @("winhttp.dll","doorstop_config.ini") -and -not (Test-Path -LiteralPath "$dst.orig") -and ((Get-FileHash -LiteralPath $dst).Hash -ne (Get-FileHash -LiteralPath $f.FullName).Hash)) { Copy-Item -LiteralPath $dst "$dst.orig" -Force }
  Copy-Item -LiteralPath $f.FullName $dst -Force
  $rel += $r
}
$rel | Set-Content -LiteralPath $manifest
Write-Host "Installed $($rel.Count) files into $GameDir"
Write-Host ""
Write-Host "Start the game normally (GOG Galaxy or '$ExeName'). In-game hotkeys:"
Write-Host "  F1 God Mode      F3 Add Money      F4 Infinite Money   F5 Unlimited Jump"
Write-Host "  F6 Speed x2      F7 One-Hit Kill   F8 Infinite Tea     F9 Full Heal"
Write-Host "  F10 Infinite Items   F11 Add Items   F12 hide/show overlay"
Write-Host "  F2 show ALL collectibles on the map (Kodama are always shown; taken ones are faint)"

