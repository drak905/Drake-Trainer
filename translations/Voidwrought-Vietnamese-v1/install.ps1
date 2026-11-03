# Voidwrought - Vietnamese language pack installer (BepInEx 5 plugin). Safe to re-run.
# Usage: double-click Install.bat   or   install.ps1 -GameDir "D:\Games\VoidwroughtFq9Qv"
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeName = "Voidwrought.exe"
$DataDir = "Voidwrought_Data"
$ManifestName = "VwVietnamese_install_manifest.txt"
$TestedAssemblySha256 = "1B093F6D297CFE3D39377B3E46F42883E645157EB4977F248B6143712071CA62"   # Epic Win.1.1.33

function Test-GameDir([string]$p) {
  return ($p -and (Test-Path -LiteralPath (Join-Path $p $ExeName)) -and (Test-Path -LiteralPath (Join-Path $p "$DataDir\Managed\Assembly-CSharp.dll")))
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
  foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Za-z]:\\$' })) {
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
if (-not (Test-Path -LiteralPath (Join-Path $GameDir "MonoBleedingEdge"))) { Write-Warning "No MonoBleedingEdge folder: this is not the Unity-Mono PC build this pack was made for." }
$sha = (Get-FileHash (Join-Path $GameDir "$DataDir\Managed\Assembly-CSharp.dll") -Algorithm SHA256).Hash
if ($sha -ne $TestedAssemblySha256) { Write-Warning "Game build differs from the tested one (Assembly-CSharp.dll sha256 $($sha.Substring(0,12))...). The pack looks terms up by English text, so it will still work; texts that changed stay in English." }

$manifest = Join-Path $GameDir $ManifestName
$rel = @()
$installedBepInEx = $false
if ((Test-Path -LiteralPath $manifest) -and ((Get-Content -LiteralPath $manifest) -contains "#BEPINEX_INSTALLED_BY_THIS_PACK")) {
  $installedBepInEx = $true
  $rel += (Get-Content -LiteralPath $manifest | Where-Object { $_ -and -not $_.StartsWith("#") -and (($_ -like "BepInEx\core\*") -or ($_ -in @("winhttp.dll","doorstop_config.ini",".doorstop_version"))) })
}

# --- 1) BepInEx (only when the game does not have it yet, e.g. not installed by the Voidwrought trainer) -------------------
if (-not (Test-Path -LiteralPath (Join-Path $GameDir "BepInEx\core\BepInEx.dll"))) {
  $src = Join-Path $PSScriptRoot "payload\bepinex"
  foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
    $r = $f.FullName.Substring($src.Length + 1)
    $dst = Join-Path $GameDir $r
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    if ((Test-Path -LiteralPath $dst) -and $r -in @("winhttp.dll","doorstop_config.ini") -and -not (Test-Path -LiteralPath "$dst.orig")) { Copy-Item -LiteralPath $dst "$dst.orig" -Force }
    Copy-Item -LiteralPath $f.FullName $dst -Force
    $rel += $r
  }
  $installedBepInEx = $true
  Write-Host "Installed BepInEx 5.4.23.3 (mod loader)."
} else { Write-Host "BepInEx already present - reusing it." }

# --- 2) the Vietnamese plugin -------------------------------------------------------------------------------------------
$src = Join-Path $PSScriptRoot "payload\plugin"
foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
  $r = $f.FullName.Substring($src.Length + 1)
  $dst = Join-Path $GameDir $r
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  Copy-Item -LiteralPath $f.FullName $dst -Force
  $rel += $r
}
$lines = @()
if ($installedBepInEx) { $lines += "#BEPINEX_INSTALLED_BY_THIS_PACK" }
$lines += $rel
$lines | Set-Content -LiteralPath $manifest -Encoding ASCII

Write-Host ""
Write-Host "Installed the Vietnamese language pack into $GameDir"
Write-Host "Start the game, then choose:  Settings > Game > Language > 'Tieng Viet'  (the 12th entry, press Right 11 times from English)."
