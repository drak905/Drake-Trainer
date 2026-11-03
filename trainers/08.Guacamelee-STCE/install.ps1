# Guacamelee! Super Turbo Championship Edition - Trainer installer. Safe to re-run.
# Copies dinput8.dll (+ GuacTrainer.ini) next to Game.exe. No game file is modified.
# Usage: install.ps1 [-GameDir "D:\Games\GuacameleeSTCE"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "Game.exe"
$KnownExeSize = 5607424          # Epic build GuacSTCE_29-06-2023 (tested)

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path (Join-Path $p $ExeName)) -and (Test-Path (Join-Path $p "fmodstudio.dll")) -and
          ((Test-Path (Join-Path $p "resources.dat")) -or (Test-Path (Join-Path $p "levels.dat"))))
}
function Find-Game {
  # 1) Epic Games Launcher manifests
  $mdir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
  if (Test-Path $mdir) {
    foreach ($f in Get-ChildItem $mdir -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.DisplayName -match 'Guacamelee' -and (Test-GameDir $j.InstallLocation)) { return $j.InstallLocation }
    }
  }
  # 2) Steam libraries (app 214770)
  $steamRoots = @()
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam","HKLM:\SOFTWARE\Valve\Steam","HKCU:\Software\Valve\Steam")) {
    try { $v = (Get-ItemProperty $k -ErrorAction Stop); foreach ($n in "InstallPath","SteamPath") { if ($v.$n) { $steamRoots += $v.$n } } } catch {}
  }
  foreach ($s in ($steamRoots | Select-Object -Unique)) {
    $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
    $libs = @($s)
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\','\') } }
    foreach ($l in $libs) {
      foreach ($n in @("Guacamelee Super Turbo Championship Edition","Guacamelee! Super Turbo Championship Edition","GuacameleeSTCE")) {
        $p = Join-Path $l "steamapps\common\$n"; if (Test-GameDir $p) { return $p }
      }
    }
  }
  # 3) common folders on every fixed drive
  $names = @("GuacameleeSTCE","Guacamelee Super Turbo Championship Edition","Guacamelee! Super Turbo Championship Edition","Guacamelee STCE")
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
    foreach ($base in @("EpicGames","Epic Games","Program Files\Epic Games","GOG Games","GOGGalaxy","GOG Galaxy\Games","Program Files (x86)\GOG Galaxy\Games","Games","SteamLibrary\steamapps\common","Program Files (x86)\Steam\steamapps\common")) {
      foreach ($n in $names) { $p = Join-Path $d.Root "$base\$n"; if (Test-GameDir $p) { return $p } }
    }
  }
  return ""
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "'$ExeName' (with fmodstudio.dll / resources.dat) not found in '$GameDir'." }
if (Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$GameDir*" }) { throw "Close the game first, then run the installer again." }

$exe = Get-Item (Join-Path $GameDir $ExeName)
$bytes = [IO.File]::ReadAllBytes($exe.FullName)[0..0x3FF]
$pe = [BitConverter]::ToInt32($bytes, 0x3C)
$machine = [BitConverter]::ToUInt16($bytes, $pe + 4)
if ($machine -ne 0x14c) { throw "Game.exe is not a 32-bit executable - this trainer is for the 32-bit Guacamelee! STCE build." }
if ($exe.Length -ne $KnownExeSize) {
  Write-Warning "Game.exe differs from the tested build (size $($exe.Length), tested $KnownExeSize). The trainer locates everything by byte signatures at start-up and greys out any feature it cannot find (see GuacTrainer.log)."
}

$payload  = Join-Path $PSScriptRoot "payload"
$dll      = Join-Path $GameDir "dinput8.dll"
$manifest = Join-Path $GameDir "GuacTrainer_install_manifest.txt"
if ((Test-Path $dll) -and -not (Test-Path $manifest)) {
  # a different dinput8.dll is already there (another mod?) - keep a copy, do not silently destroy it
  Copy-Item $dll "$dll.orig" -Force
  Write-Warning "An existing dinput8.dll was found and copied to dinput8.dll.orig. The trainer forwards to the Windows dinput8, not to that file."
}
Copy-Item (Join-Path $payload "dinput8.dll") $dll -Force
$ini = Join-Path $GameDir "GuacTrainer.ini"
if (-not (Test-Path $ini)) { Copy-Item (Join-Path $payload "GuacTrainer.ini") $ini -Force } else { Write-Host "Keeping your existing GuacTrainer.ini" }
@("dinput8.dll","GuacTrainer.ini","GuacTrainer.log","dinput8.dll.orig") | Set-Content $manifest
Write-Host "Installed trainer into $GameDir"
Write-Host ""
Write-Host "Start the game normally (Epic / Steam / GOG). In-game hotkeys (the game window must be focused):"
Write-Host "  F1 God Mode        F2 Infinite Stamina   F3 +10,000 pesos      F4 Unlimited Money"
Write-Host "  F5 Unlimited Jump  F6 Move Speed x2      F7 Show entire map    F8 One-Hit Kill"
Write-Host "  F9 Cycle speed x2/x3/x4   F10 Infinite Intenso   F11 Game debug menu   F12 hide/show panel"
