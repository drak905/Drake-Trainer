# Guacamelee! Super Turbo Championship Edition - Vietnamese language patch installer. Safe to re-run.
# Adds "Tieng Viet" as the 7th entry of Options > Language.  Patches two game files:
#   Game.exe  (adds the 7th language entry)      misc.dat  (Vietnamese text + fonts with Vietnamese letters)
# The originals are kept in <game folder>\VietnamesePatch_backup so Uninstall.bat can restore them.
# Usage: install.ps1 [-GameDir "D:\Games\GuacameleeSTCE"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"

$ExeVanilla  = "DE6CEC52F06B8E0FC835356B31AB80891BC4BA6431823B0EEF6FC02C480209F2"
$ExePatched  = "70FC09A0CA9BCA527A06246550514E75E818A741EDC4FAAF35A42405E39D9818"
$MiscVanilla = "B52125AB0FBFF97F7FA7E05C41E2B09F8ECDBA26F33C94D39ED11C29F9FD658C"
$MiscPatched = "5362DB2EA62F26A83D9B59A5B9523D4D0A4A22D859E356A0FE24A064E042F84B"

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path (Join-Path $p "Game.exe")) -and (Test-Path (Join-Path $p "fmodstudio.dll")) -and (Test-Path (Join-Path $p "misc.dat")))
}
function Find-Game {
  $mdir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
  if (Test-Path $mdir) {
    foreach ($f in Get-ChildItem $mdir -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.DisplayName -match 'Guacamelee' -and (Test-GameDir $j.InstallLocation)) { return $j.InstallLocation }
    }
  }
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
  $names = @("GuacameleeSTCE","Guacamelee Super Turbo Championship Edition","Guacamelee! Super Turbo Championship Edition","Guacamelee STCE")
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
    foreach ($base in @("EpicGames","Epic Games","Program Files\Epic Games","GOG Games","GOGGalaxy","GOG Galaxy\Games","Program Files (x86)\GOG Galaxy\Games","Games","SteamLibrary\steamapps\common","Program Files (x86)\Steam\steamapps\common")) {
      foreach ($n in $names) { $p = Join-Path $d.Root "$base\$n"; if (Test-GameDir $p) { return $p } }
    }
  }
  return ""
}
function Sha([string]$f) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToUpper() }

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Game folder not found automatically. Paste the folder that contains Game.exe" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "Game.exe / misc.dat not found in '$GameDir'." }
if (Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$GameDir*" }) { throw "Close the game first, then run the installer again." }

$xd      = Join-Path $PSScriptRoot "tools\xdelta3.exe"
$payload = Join-Path $PSScriptRoot "payload"
$backup  = Join-Path $GameDir "VietnamesePatch_backup"
$manifest = Join-Path $GameDir "VietnamesePatch_install_manifest.txt"
if (-not (Test-Path $xd)) { throw "tools\xdelta3.exe is missing - extract the whole zip, not only some files." }

$files = @(
  @{ Name = "Game.exe"; Vanilla = $ExeVanilla;  Patched = $ExePatched;  Delta = "Game.exe.xdelta" },
  @{ Name = "misc.dat"; Vanilla = $MiscVanilla; Patched = $MiscPatched; Delta = "misc.dat.xdelta" }
)

# 1) check what we have
$todo = @()
foreach ($f in $files) {
  $path = Join-Path $GameDir $f.Name
  $h = Sha $path
  if ($h -eq $f.Patched) { Write-Host "$($f.Name): already patched"; continue }
  if ($h -ne $f.Vanilla) {
    throw ("$($f.Name) is not the build this patch was made for (SHA-256 $h).`n" +
           "Expected the Epic build GuacSTCE_29-06-2023 (Game.exe 5,607,424 bytes).`n" +
           "If the game was updated or modified, restore the original files (Epic: Verify) and try again.")
  }
  $todo += $f
}
if ($todo.Count -eq 0) { Write-Host "Nothing to do - the Vietnamese patch is already installed in $GameDir"; exit 0 }

# 2) back up the originals once, then patch through temp files (the game files are replaced only after the result is verified)
New-Item -ItemType Directory -Force $backup | Out-Null
foreach ($f in $todo) {
  $path = Join-Path $GameDir $f.Name
  $bak  = Join-Path $backup $f.Name
  if (-not (Test-Path $bak)) { Copy-Item $path $bak -Force }
  $tmp = Join-Path $GameDir ($f.Name + ".vi_tmp")
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  & $xd -d -f -s $bak (Join-Path $payload $f.Delta) $tmp
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmp)) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; throw "xdelta failed for $($f.Name)." }
  if ((Sha $tmp) -ne $f.Patched) { Remove-Item $tmp -Force; throw "Patched $($f.Name) failed verification - nothing was changed." }
  Move-Item $tmp $path -Force
  Write-Host "Patched $($f.Name)"
}
@("Game.exe","misc.dat","VietnamesePatch_backup") | Set-Content $manifest
Write-Host ""
Write-Host "Done.  Start the game, then choose:  Options > Language > Tieng Viet  (confirm with 'Yes')."
Write-Host "To undo: run Uninstall.bat.  (Epic's 'Verify' also restores the original files.)"
