# Removes everything install.ps1 added to Ghost Song (and restores a previously existing winmm.dll).
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "GhostSong.exe"
$ManifestName = "GhostSongVietnamese_install_manifest.txt"
if (-not $GameDir) {
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1305299338","HKLM:\SOFTWARE\GOG.com\Games\1305299338")) {
    try { $p = (Get-ItemProperty $k -ErrorAction Stop).path; if ($p -and (Test-Path -LiteralPath (Join-Path $p $ManifestName))) { $GameDir = $p; break } } catch {}
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains '$ExeName'" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process -Name "GhostSong" -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifest = Join-Path $GameDir $ManifestName
if (-not (Test-Path -LiteralPath $manifest)) { throw "No install manifest in '$GameDir' - nothing to remove." }

foreach ($r in (Get-Content -LiteralPath $manifest | Where-Object { $_ })) {
  $p = Join-Path $GameDir $r
  if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
$bak = Join-Path $GameDir "winmm.dll.pre-vi"
if (Test-Path -LiteralPath $bak) { Move-Item -LiteralPath $bak (Join-Path $GameDir "winmm.dll") -Force; Write-Host "Restored your previous winmm.dll" }
foreach ($o in @("gs_vi.log","vi_selftest_report.json","vi_selftest.flag")) { Remove-Item -LiteralPath (Join-Path $GameDir $o) -Force -ErrorAction SilentlyContinue }
$d = Join-Path $GameDir "GhostSongVietnamese"
if ((Test-Path -LiteralPath $d) -and -not (Get-ChildItem -LiteralPath $d -Force)) { Remove-Item -LiteralPath $d -Force }
Remove-Item -LiteralPath $manifest -Force
Write-Host "Vietnamese pack removed from $GameDir. If the game was set to Vietnamese, it falls back to a normal language (Settings > Game > Language) - choose English or Auto if it looks odd."
