# Voidwrought - Offline Trainer installer (BepInEx 5 + plugin). Safe to re-run.
# Usage: right-click > Run with PowerShell, or double-click Install.bat.
#        install.ps1 -GameDir "D:\Games\VoidwroughtFq9Qv"      (skip auto-detection)
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "Voidwrought.exe"
$DataDir = "Voidwrought_Data"
$TestedAssemblySha256 = "1B093F6D297CFE3D39377B3E46F42883E645157EB4977F248B6143712071CA62"   # game build the trainer was verified on (Epic Win.1.1.33)

function Test-GameDir($p) {
  return ($p -and (Test-Path (Join-Path $p $ExeName)) -and (Test-Path (Join-Path $p "$DataDir\Managed\Assembly-CSharp.dll")))
}

function Find-Game {
  # 1) Epic Games Launcher manifests
  foreach ($f in (Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests\*.item" -ErrorAction SilentlyContinue)) {
    try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json; if ($j.LaunchExecutable -eq $ExeName -and (Test-GameDir $j.InstallLocation)) { return $j.InstallLocation } } catch {}
  }
  # 2) Steam libraries
  $steamRoots = @()
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam","HKLM:\SOFTWARE\Valve\Steam","HKCU:\Software\Valve\Steam")) {
    try { $v = (Get-ItemProperty $k -ErrorAction Stop); foreach ($n in @("InstallPath","SteamPath")) { if ($v.$n) { $steamRoots += $v.$n } } } catch {}
  }
  foreach ($s in ($steamRoots | Select-Object -Unique)) {
    $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
    $libs = @($s)
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\','\') } }
    foreach ($l in $libs) { $c = Join-Path $l "steamapps\common\Voidwrought"; if (Test-GameDir $c) { return $c } }
  }
  # 3) common folders on every fixed drive
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
    foreach ($rel in @("EpicGames\VoidwroughtFq9Qv","Epic Games\VoidwroughtFq9Qv","Program Files\Epic Games\VoidwroughtFq9Qv","Games\Voidwrought","SteamLibrary\steamapps\common\Voidwrought","GOG Games\Voidwrought","GOGGalaxy\Voidwrought")) {
      $c = Join-Path $d.Root $rel
      if (Test-GameDir $c) { return $c }
    }
  }
  return ""
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains $ExeName" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "$ExeName / $DataDir\Managed\Assembly-CSharp.dll not found in '$GameDir'." }
if (Get-Process ([IO.Path]::GetFileNameWithoutExtension($ExeName)) -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }
if (-not (Test-Path (Join-Path $GameDir "MonoBleedingEdge"))) { Write-Warning "No MonoBleedingEdge folder: this is not the Unity-Mono build the trainer was made for." }

$sha = (Get-FileHash (Join-Path $GameDir "$DataDir\Managed\Assembly-CSharp.dll") -Algorithm SHA256).Hash
if ($sha -ne $TestedAssemblySha256) {
  Write-Warning "Game build differs from the one the trainer was tested on (Assembly-CSharp.dll sha256 $($sha.Substring(0,12))...). The trainer hooks methods by name, so it will probably still work; features whose hooks fail are reported in BepInEx\LogOutput.log."
}

$payload = Join-Path $PSScriptRoot "payload"
$manifest = Join-Path $GameDir "VwTrainer_install_manifest.txt"
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
Write-Host ""
Write-Host "Installed $($rel.Count) files into $GameDir"
Write-Host "Start the game normally (Epic Games Launcher), load a save, and the overlay appears top-left."
Write-Host "Keys: F1 God | F2 +Money | F3 Infinite Money+Items | F4 Unlimited Jump | F5 Speed x2 | F6 One-Hit Kill | F7 Heal"
Write-Host "      F8 Infinite Flasks/Charges | F9 Show Items | F10 Reveal Map | F11 Noclip | F12 hide overlay | Home Max materials | End All relics"
