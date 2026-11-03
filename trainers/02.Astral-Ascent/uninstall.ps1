# Astral Ascent trainer - uninstaller.  Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-GameDir "..."]
param([string]$GameDir = "")
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ours = (Get-FileHash (Join-Path $here 'winmm.dll') -Algorithm SHA256).Hash
if (-not $GameDir) {
  $m = 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests'
  if (Test-Path $m) {
    foreach ($f in Get-ChildItem $m -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.LaunchExecutable -eq 'Astral Ascent.exe' -and (Test-Path $j.InstallLocation)) { $GameDir = $j.InstallLocation; break }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Path of the Astral Ascent folder" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-Path (Join-Path $GameDir 'Astral Ascent.exe'))) { throw "'Astral Ascent.exe' not found in '$GameDir'." }
if (Get-Process -Name 'Astral Ascent' -ErrorAction SilentlyContinue) { throw "Close Astral Ascent first." }
$t = Join-Path $GameDir 'winmm.dll'
if (Test-Path $t) {
  if ((Get-FileHash $t -Algorithm SHA256).Hash -eq $ours) { Remove-Item $t -Force; Write-Host "Removed trainer winmm.dll" }
  else { Write-Warning "winmm.dll in the game folder is not this trainer's - left untouched." }
}
$bak = Join-Path $GameDir 'winmm.dll.pre-trainer.bak'
if ((Test-Path $bak) -and -not (Test-Path $t)) { Move-Item $bak $t; Write-Host "Restored previous winmm.dll" }
foreach ($n in 'aa_debugmenu.log','trainer_selftest_report.json','trainer_selftest.flag') {
  $p = Join-Path $GameDir $n; if (Test-Path $p) { Remove-Item $p -Force }
}
Write-Host "Done. (Your save files were never touched.)"
