# Removes the Guacamelee! STCE trainer (dinput8.dll + settings + log). Safe to re-run.
# Usage: uninstall.ps1 [-GameDir "D:\Games\GuacameleeSTCE"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
function Test-GameDir([string]$p) { return ($p -and (Test-Path (Join-Path $p "Game.exe")) -and (Test-Path (Join-Path $p "fmodstudio.dll"))) }
if (-not $GameDir) {
  $mdir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
  if (Test-Path $mdir) {
    foreach ($f in Get-ChildItem $mdir -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.DisplayName -match 'Guacamelee' -and (Test-GameDir $j.InstallLocation)) { $GameDir = $j.InstallLocation; break }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the game folder (contains Game.exe)" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "Game.exe not found in '$GameDir'." }
if (Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$GameDir*" }) { throw "Close the game first." }
$m = Join-Path $GameDir "GuacTrainer_install_manifest.txt"
if (-not (Test-Path $m)) { Write-Host "No trainer install manifest in '$GameDir' - nothing to remove."; exit 0 }
$dll = Join-Path $GameDir "dinput8.dll"
if (Test-Path "$dll.orig") { Move-Item "$dll.orig" $dll -Force; Write-Host "Restored your previous dinput8.dll" } else { Remove-Item $dll -Force -ErrorAction SilentlyContinue }
foreach ($n in @("GuacTrainer.ini","GuacTrainer.log","trainer_selftest_report.json","trainer_selftest.flag","trainer_cmd.txt","trainer_dump.txt")) { Remove-Item (Join-Path $GameDir $n) -Force -ErrorAction SilentlyContinue }
Remove-Item $m -Force
Write-Host "Trainer removed from $GameDir (game files and saves were never touched)."

