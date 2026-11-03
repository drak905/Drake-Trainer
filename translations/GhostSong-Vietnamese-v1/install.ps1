# Ghost Song - Vietnamese language pack installer (winmm.dll proxy). Safe to re-run.
# Usage: install.ps1 [-GameDir "D:\Games\Ghost Song"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "GhostSong.exe"
$ManifestName = "GhostSongVietnamese_install_manifest.txt"
$RefHash = "43A0C1218FFD9B30487EC4FA96ADF8F896E8313CE7EC868671CE1085AFD66246"   # GameAssembly.dll of the tested build (v1.2.12b)

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path -LiteralPath (Join-Path $p $ExeName)) -and (Test-Path -LiteralPath (Join-Path $p "GameAssembly.dll")) -and (Test-Path -LiteralPath (Join-Path $p "GhostSong_Data")))
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
  # 1) GOG registry (gameId 1305299338)
  foreach ($k in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1305299338","HKLM:\SOFTWARE\GOG.com\Games\1305299338")) {
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
if (-not (Test-GameDir $GameDir)) { throw "'$ExeName' / 'GameAssembly.dll' / 'GhostSong_Data' not found in '$GameDir'. This pack is for the Windows build of Ghost Song." }
if (Get-Process -Name "GhostSong" -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }

$h = (Get-FileHash -LiteralPath (Join-Path $GameDir "GameAssembly.dll") -Algorithm SHA256).Hash
if ($h -ne $RefHash) {
  Write-Warning "GameAssembly.dll differs from the tested build (v1.2.12b). The pack checks every hook/patch itself and skips what does not match,"
  Write-Warning "so it cannot crash the game, but Vietnamese may be incomplete or not appear. Details end up in gs_vi.log."
}

$dstWinmm = Join-Path $GameDir "winmm.dll"
$ours = (Join-Path $PSScriptRoot "payload\winmm.dll")
if ((Test-Path -LiteralPath $dstWinmm) -and ((Get-FileHash $dstWinmm).Hash -ne (Get-FileHash $ours).Hash)) {
  # a foreign winmm.dll (another mod). Keep it so Uninstall can restore it.
  $bak = "$dstWinmm.pre-vi"
  if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $dstWinmm $bak -Force; Write-Host "Existing winmm.dll backed up as winmm.dll.pre-vi" }
  else { Write-Warning "winmm.dll.pre-vi already exists - leaving it as is." }
}

$rel = @()
Copy-Item -LiteralPath $ours $dstWinmm -Force; $rel += "winmm.dll"
$src = Join-Path $PSScriptRoot "payload\GhostSongVietnamese"
New-Item -ItemType Directory -Force (Join-Path $GameDir "GhostSongVietnamese") | Out-Null
foreach ($f in (Get-ChildItem -LiteralPath $src -File)) {
  Copy-Item -LiteralPath $f.FullName (Join-Path $GameDir "GhostSongVietnamese\$($f.Name)") -Force
  $rel += "GhostSongVietnamese\$($f.Name)"
}
$rel | Set-Content -LiteralPath (Join-Path $GameDir $ManifestName) -Encoding ASCII

Write-Host ""
Write-Host "Installed the Ghost Song Vietnamese pack into $GameDir"
Write-Host "Start the game, open  Settings > Game  and press the arrow on the Language row until 'Tieng Viet' is shown (after Korean, before Auto)."
