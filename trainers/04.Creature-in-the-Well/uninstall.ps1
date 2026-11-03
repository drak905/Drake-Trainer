# Creature in the Well trainer - uninstaller.  Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-GameDir "..."]
param([string]$GameDir = "")
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ours = (Get-FileHash (Join-Path $here 'xinput1_3.dll') -Algorithm SHA256).Hash
if (-not $GameDir) {
  $m = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path $m) {
    foreach ($f in Get-ChildItem $m -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.LaunchExecutable -eq 'CITW.exe' -and (Test-Path $j.InstallLocation)) { $GameDir = $j.InstallLocation; break }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Path of the Creature in the Well folder" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
$bin = Join-Path $GameDir 'CITW\Binaries\Win64'
if (-not (Test-Path (Join-Path $bin 'CITW-Win64-Shipping.exe'))) { throw "Game not found in '$GameDir'." }
if (Get-Process -Name 'CITW-Win64-Shipping','CITW' -ErrorAction SilentlyContinue) { throw "Close Creature in the Well first." }
$t = Join-Path $bin 'xinput1_3.dll'
if (Test-Path $t) {
  if ((Get-FileHash $t -Algorithm SHA256).Hash -eq $ours) { Remove-Item $t -Force; Write-Host "Removed trainer xinput1_3.dll" }
  else { Write-Warning "xinput1_3.dll in the game folder is not this trainer's - left untouched." }
}
$bak = Join-Path $bin 'xinput1_3.dll.pre-trainer.bak'
if ((Test-Path $bak) -and -not (Test-Path $t)) { Move-Item $bak $t; Write-Host "Restored previous xinput1_3.dll" }
foreach ($n in 'citw_trainer.log','citw_trainer.ini','trainer_selftest_report.json','trainer_selftest.flag') {
  $x = Join-Path $bin $n; if (Test-Path $x) { Remove-Item $x -Force }
}
Write-Host "Done. (Game files and your saves were never modified.)"
