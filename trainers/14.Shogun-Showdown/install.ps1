# Shogun Showdown - Offline Trainer installer (BepInEx 5 + plugin). Safe to re-run.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$exe = "ShogunShowdown.exe"
$dataDir = "ShogunShowdown_Data"
function Test-Game($p) { return ($p -and (Test-Path (Join-Path $p $exe)) -and (Test-Path (Join-Path $p "$dataDir\Managed\Assembly-CSharp.dll"))) }
function Find-Game {
  # Epic Games Launcher manifests
  foreach ($f in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue)) {
    try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json; if ($j.LaunchExecutable -eq $exe -and (Test-Game $j.InstallLocation)) { return $j.InstallLocation } } catch {}
  }
  # Steam libraries
  $steamRoots = @()
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam", "HKCU:\Software\Valve\Steam")) {
    try { $v = (Get-ItemProperty $k -ErrorAction Stop); foreach ($n in @("InstallPath", "SteamPath")) { if ($v.$n) { $steamRoots += $v.$n } } } catch {}
  }
  foreach ($s in ($steamRoots | Select-Object -Unique)) {
    $libs = @($s)
    $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value -replace '\\\\', '\' } }
    foreach ($l in ($libs | Select-Object -Unique)) { $p = Join-Path $l "steamapps\common\Shogun Showdown"; if (Test-Game $p) { return $p } }
  }
  # Common default folders on every fixed drive
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) {
    foreach ($rel in @("Program Files\Epic Games\ShogunShowdown611f6", "Epic Games\ShogunShowdown611f6", "EpicGames\ShogunShowdown611f6", "SteamLibrary\steamapps\common\Shogun Showdown", "Program Files (x86)\Steam\steamapps\common\Shogun Showdown", "XboxGames\Shogun Showdown\Content")) {
      $p = Join-Path $d $rel; if (Test-Game $p) { return $p }
    }
  }
  return ""
}
if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains $exe" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-Game $GameDir)) { throw "$exe / $dataDir\Managed\Assembly-CSharp.dll not found in '$GameDir'." }
if (Get-Process ShogunShowdown -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }
if (-not (Test-Path (Join-Path $GameDir "MonoBleedingEdge"))) { Write-Warning "No MonoBleedingEdge folder: this is not the Unity-Mono build the trainer was made for." }
$payload = Join-Path $PSScriptRoot "payload"
$manifest = Join-Path $GameDir "ShogunTrainer_install_manifest.txt"
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
Write-Host "Start the game normally (Epic launcher / Steam / ShogunShowdown.exe). The overlay shows once a run is loaded."
Write-Host "Keys: F1 God, F2 +Coins, F3 Infinite Money, F4 Unlimited Special Move, F5 Game Speed x2, F6 Move x2, F7 One-Hit Kill, F8 No Tile Cooldown, F9 Infinite Consumables, F10 Reveal Map, F11 Full Heal, PgUp +Meta, PgDn Give Potion, Insert hide overlay."
