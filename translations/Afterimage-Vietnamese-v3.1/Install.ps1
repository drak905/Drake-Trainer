# Afterimage - Vietnamese language pack - installer (PowerShell 5.1+). Run via Install.bat.
#   Install.bat                         auto-detect the Steam install
#   Install.bat -GameDir "D:\...\Afterimage"
param([string]$GameDir = "", [switch]$Quiet)
$ErrorActionPreference = "Stop"
$Version = "3.1.0"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $here "payload"
$KnownExeSha = "48F9EB843E624775E7B6D8C5BE2B3BDB69B8C6E56E4203D28C459249DE67D089"  # Steam buildid 14404437

function Find-GameDir {
    $libs = @(); $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch {}
    if (-not $steam) { try { $steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction Stop).InstallPath } catch {} }
    if ($steam) {
        $steam = $steam -replace "/", "\"; $libs += $steam
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) { foreach ($line in Get-Content $vdf) { if ($line -match '"path"\s+"([^"]+)"') { $libs += ($Matches[1] -replace "\\\\", "\") } } }
    }
    foreach ($l in ($libs | Select-Object -Unique)) {
        $c = Join-Path $l "steamapps\common\Afterimage"
        if (Test-Path (Join-Path $c "Afterimage\Binaries\Win64\Afterimage-Win64-Shipping.exe")) { return $c }
    }
    return $null
}

Write-Host "=== Afterimage Vietnamese pack v$Version - install ===" -ForegroundColor Cyan
if (-not $GameDir) { $GameDir = Find-GameDir }
if (-not $GameDir -and -not $Quiet) { $GameDir = Read-Host "Could not find Afterimage. Enter the game folder (the one containing Afterimage.exe)" }
if (-not $GameDir) { throw "Game folder not found. Re-run: Install.bat -GameDir ""D:\SteamLibrary\steamapps\common\Afterimage""" }
$GameDir = $GameDir.Trim('"')
$win64 = Join-Path $GameDir "Afterimage\Binaries\Win64"
$exe = Join-Path $win64 "Afterimage-Win64-Shipping.exe"
if (-not (Test-Path $exe)) { throw "Not an Afterimage install: $exe not found" }
if (Get-Process -Name "Afterimage-Win64-Shipping" -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }
$sha = (Get-FileHash $exe -Algorithm SHA256).Hash
Write-Host "Game folder : $GameDir"
if ($sha -ne $KnownExeSha) { Write-Host "NOTE: game build differs from the tested one; the pack reads text live so it should still work." -ForegroundColor Yellow }

$ue4ss = Join-Path $win64 "ue4ss"
$dll   = Join-Path $win64 "dwmapi.dll"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$weInstalledLoader = $false
$loaderBackup = $null

if (-not (Test-Path $ue4ss) -and -not (Test-Path $dll)) {
    # no mod loader present: install the bundled UE4SS
    Copy-Item (Join-Path $payload "loader\dwmapi.dll") $win64 -Force
    Copy-Item (Join-Path $payload "loader\ue4ss") $win64 -Recurse -Force
    $weInstalledLoader = $true
    Write-Host "UE4SS loader installed."
} elseif ((Test-Path $dll) -and -not (Test-Path $ue4ss)) {
    # a foreign dwmapi.dll proxy exists but no ue4ss: back it up and install ours
    $loaderBackup = Join-Path $win64 "_AI_Vietnamese_backup_$stamp"; New-Item -ItemType Directory -Force $loaderBackup | Out-Null
    Move-Item $dll (Join-Path $loaderBackup "dwmapi.dll")
    Copy-Item (Join-Path $payload "loader\dwmapi.dll") $win64 -Force
    Copy-Item (Join-Path $payload "loader\ue4ss") $win64 -Recurse -Force
    $weInstalledLoader = $true
    Write-Host "Foreign dwmapi.dll backed up to $loaderBackup; UE4SS loader installed."
} else {
    Write-Host "UE4SS already present (e.g. the Afterimage Trainer) - adding the Vietnamese mod to it."
    # make sure the shared helper exists
    $sharedSrc = Join-Path $payload "loader\ue4ss\Mods\shared\UEHelpers\UEHelpers.lua"
    $sharedDst = Join-Path $win64 "ue4ss\Mods\shared\UEHelpers\UEHelpers.lua"
    if (-not (Test-Path $sharedDst)) { New-Item -ItemType Directory -Force (Split-Path $sharedDst) | Out-Null; Copy-Item $sharedSrc $sharedDst -Force }
}

$modsDir = Join-Path $win64 "ue4ss\Mods"
New-Item -ItemType Directory -Force $modsDir | Out-Null
# install / upgrade the mod (preserve the user's existing config.lua)
$modDst = Join-Path $modsDir "AI_Vietnamese"
$cfg = Join-Path $modDst "Scripts\config.lua"
$savedCfg = $null
if (Test-Path $cfg) { $savedCfg = Get-Content $cfg -Raw -Encoding UTF8 }
Copy-Item (Join-Path $payload "mod\AI_Vietnamese") $modsDir -Recurse -Force
if ($savedCfg) { [System.IO.File]::WriteAllText($cfg, $savedCfg, (New-Object System.Text.UTF8Encoding($false))); Write-Host "kept your existing config.lua" }

# enable AI_Vietnamese in mods.txt (preserve other mods / order)
$modsTxt = Join-Path $modsDir "mods.txt"
$lines = @(); if (Test-Path $modsTxt) { $lines = @(Get-Content $modsTxt | Where-Object { $_ -notmatch '^\s*AI_Vietnamese\s*:' }) }
# AI_Vietnamese should run after other mods; insert before any trailing blank line
$lines = @($lines | Where-Object { $_ -ne "" }) + @("AI_Vietnamese : 1")
Set-Content $modsTxt (($lines -join "`r`n") + "`r`n") -Encoding ASCII

# enable in mods.json too (UE4SS reads either; keep both consistent).
# Build the JSON string by hand - PowerShell 5.1 does not enumerate a JSON array cleanly.
$modsJson = Join-Path $modsDir "mods.json"
$entries = @()
if (Test-Path $modsJson) {
    try {
        $parsed = Get-Content $modsJson -Raw | ConvertFrom-Json
        foreach ($e in $parsed) {
            if ($e.mod_name -and $e.mod_name -ne "AI_Vietnamese") {
                $en = $(if ($e.mod_enabled) { "true" } else { "false" })
                $entries += ('{"mod_name":"' + $e.mod_name + '","mod_enabled":' + $en + '}')
            }
        }
    } catch { $entries = @() }
}
$entries += '{"mod_name":"AI_Vietnamese","mod_enabled":true}'
Set-Content $modsJson ("[" + ($entries -join ",") + "]") -Encoding ASCII

# manifest
$manifest = [ordered]@{
    pack = "AI_Vietnamese $Version"; installed = (Get-Date).ToString("s"); game_exe_sha256 = $sha
    we_installed_loader = $weInstalledLoader; loader_backup = $loaderBackup
}
$manifestPath = Join-Path $win64 "AI_Vietnamese_install.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content $manifestPath -Encoding ASCII

# verify the mod files
$bad = 0
Get-ChildItem (Join-Path $payload "mod\AI_Vietnamese") -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring((Join-Path $payload "mod").Length + 1)
    if ($savedCfg -and $rel -like "*\Scripts\config.lua") { return }   # user's own config was kept on purpose
    $a = (Get-FileHash $_.FullName).Hash
    $b = (Get-FileHash (Join-Path $modsDir $rel)).Hash
    if ($a -ne $b) { Write-Host "MISMATCH: $rel" -ForegroundColor Red; $bad++ }
}
if ($bad -ne 0) { throw "Verification failed for $bad file(s)." }
Write-Host "Vietnamese pack installed OK." -ForegroundColor Green
Write-Host "Start the game from Steam. Keep OPTIONS > GAME > LANGUAGE on English - the pack shows Vietnamese over it."
Write-Host "Press HOME in game to toggle Vietnamese on/off. See README.md."
