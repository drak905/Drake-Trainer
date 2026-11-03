# Afterimage Trainer - installer (PowerShell 5.1+). Run via Install.bat.
#   Install.bat                       auto-detect the Steam install
#   Install.bat -GameDir "D:\...\Afterimage"
# Safe next to other UE4SS mods (for example the Afterimage Vietnamese pack): only AI_Trainer / Keybinds are touched,
# the UE4SS loader is installed only when it is missing, and mods.txt / mods.json are merged, never replaced.
param([string]$GameDir = "", [switch]$Quiet)
$ErrorActionPreference = "Stop"
$TrainerVersion = "1.4.0"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $here "payload"
$KnownExeSha = "48F9EB843E624775E7B6D8C5BE2B3BDB69B8C6E56E4203D28C459249DE67D089"   # build the trainer was verified on (Steam buildid 14404437)

function Find-GameDir {
    $libs = @()
    $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch {}
    if (-not $steam) { try { $steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -ErrorAction Stop).InstallPath } catch {} }
    if ($steam) {
        $steam = $steam -replace "/", "\"
        $libs += $steam
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($line in Get-Content $vdf) {
                if ($line -match '"path"\s+"([^"]+)"') { $libs += ($Matches[1] -replace "\\\\", "\") }
            }
        }
    }
    foreach ($l in ($libs | Select-Object -Unique)) {
        $c = Join-Path $l "steamapps\common\Afterimage"
        if (Test-Path (Join-Path $c "Afterimage\Binaries\Win64\Afterimage-Win64-Shipping.exe")) { return $c }
    }
    return $null
}

# --- mods.txt / mods.json merge helpers (keep other mods and their order) ---------------------------------
function Set-ModsTxt([string]$path, [string[]]$names) {
    $lines = @(); if (Test-Path $path) { $lines = @(Get-Content $path | Where-Object { $_.Trim() -ne "" }) }
    foreach ($n in $names) {
        $pat = '^\s*' + [regex]::Escape($n) + '\s*:'
        $idx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $pat) { $idx = $i; break } }
        if ($idx -ge 0) { $lines[$idx] = "$n : 1" }
        else {
            # a language pack wants to run after the other mods: insert before it
            $vi = -1
            for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*AI_Vietnamese\s*:') { $vi = $i; break } }
            if ($vi -ge 0) { $head = @(); if ($vi -gt 0) { $head = @($lines[0..($vi - 1)]) }; $lines = $head + @("$n : 1") + @($lines[$vi..($lines.Count - 1)]) }
            else { $lines = @($lines) + @("$n : 1") }
        }
    }
    Set-Content $path (($lines -join "`r`n") + "`r`n") -NoNewline -Encoding ASCII
}
function Set-ModsJson([string]$path, [string[]]$names) {
    $entries = New-Object System.Collections.ArrayList
    if (Test-Path $path) {
        try {
            foreach ($e in (Get-Content $path -Raw | ConvertFrom-Json)) {
                if ($e.mod_name) { [void]$entries.Add(@($e.mod_name, [bool]$e.mod_enabled)) }
            }
        } catch { $entries.Clear() }
    }
    foreach ($n in $names) {
        $found = $false
        for ($i = 0; $i -lt $entries.Count; $i++) { if ($entries[$i][0] -eq $n) { $entries[$i] = @($n, $true); $found = $true } }
        if (-not $found) {
            $vi = -1
            for ($i = 0; $i -lt $entries.Count; $i++) { if ($entries[$i][0] -eq "AI_Vietnamese") { $vi = $i; break } }
            if ($vi -ge 0) { $entries.Insert($vi, @($n, $true)) } else { [void]$entries.Add(@($n, $true)) }
        }
    }
    $parts = @()
    foreach ($e in $entries) { $parts += ('{"mod_name":"' + $e[0] + '","mod_enabled":' + $(if ($e[1]) { "true" } else { "false" }) + '}') }
    Set-Content $path ("[" + ($parts -join ",") + "]") -Encoding ASCII
}

Write-Host "=== Afterimage Trainer v$TrainerVersion - install ===" -ForegroundColor Cyan
if (-not $GameDir) { $GameDir = Find-GameDir }
if (-not $GameDir -and -not $Quiet) {
    $GameDir = Read-Host "Could not find Afterimage automatically. Enter the game folder (the one containing Afterimage.exe)"
}
if (-not $GameDir) { throw "Game folder not found. Re-run: Install.bat -GameDir ""D:\SteamLibrary\steamapps\common\Afterimage""" }
$GameDir = $GameDir.Trim('"')
$win64 = Join-Path $GameDir "Afterimage\Binaries\Win64"
$exe = Join-Path $win64 "Afterimage-Win64-Shipping.exe"
if (-not (Test-Path $exe)) { throw "Not an Afterimage install: $exe not found" }
if (Get-Process -Name "Afterimage-Win64-Shipping" -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }

$sha = (Get-FileHash $exe -Algorithm SHA256).Hash
Write-Host "Game folder : $GameDir"
Write-Host "Game exe    : $sha"
if ($sha -ne $KnownExeSha) {
    Write-Host "NOTE: this game build differs from the one the trainer was tested on (the trainer uses runtime reflection, so it will probably still work)." -ForegroundColor Yellow
}

$ue4ss = Join-Path $win64 "ue4ss"
$dll = Join-Path $win64 "dwmapi.dll"
$modsDir = Join-Path $ue4ss "Mods"
$manifestPath = Join-Path $win64 "AI_Trainer_install.json"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

# what did an earlier install of this trainer record?
$old = $null
if (Test-Path $manifestPath) { try { $old = Get-Content $manifestPath -Raw | ConvertFrom-Json } catch {} }
$weInstalledLoader = $false
$loaderBackup = $null
$installedKeybinds = $null
$loaderCopied = $false
if ($old) {
    if ($old.PSObject.Properties.Name -contains "we_installed_loader") {
        $weInstalledLoader = [bool]$old.we_installed_loader; $loaderBackup = $old.loader_backup
        if ($old.PSObject.Properties.Name -contains "installed_keybinds") { $installedKeybinds = [bool]$old.installed_keybinds }
    } else {
        # manifest of trainer 1.0 - 1.2: that installer put the loader there itself
        $weInstalledLoader = $true; $loaderBackup = $old.backup; $installedKeybinds = $true
    }
}

# --- 1. UE4SS loader ---------------------------------------------------------------------------------------
if (-not (Test-Path $ue4ss) -and -not (Test-Path $dll)) {
    Copy-Item (Join-Path $payload "loader\dwmapi.dll") $win64 -Force
    Copy-Item (Join-Path $payload "loader\ue4ss") $win64 -Recurse -Force
    $weInstalledLoader = $true; $loaderCopied = $true
    Write-Host "UE4SS loader installed."
} elseif ((Test-Path $dll) -and -not (Test-Path $ue4ss)) {
    $loaderBackup = Join-Path $win64 "_AI_Trainer_backup_$stamp"; New-Item -ItemType Directory -Force $loaderBackup | Out-Null
    Move-Item $dll (Join-Path $loaderBackup "dwmapi.dll")
    Copy-Item (Join-Path $payload "loader\dwmapi.dll") $win64 -Force
    Copy-Item (Join-Path $payload "loader\ue4ss") $win64 -Recurse -Force
    $weInstalledLoader = $true; $loaderCopied = $true
    Write-Host "Foreign dwmapi.dll backed up to $loaderBackup; UE4SS loader installed."
} else {
    Write-Host "UE4SS already present (earlier trainer or another pack) - adding the trainer to it; other mods are left alone."
    $sharedDst = Join-Path $modsDir "shared\UEHelpers\UEHelpers.lua"
    if (-not (Test-Path $sharedDst)) {
        New-Item -ItemType Directory -Force (Split-Path $sharedDst) | Out-Null
        Copy-Item (Join-Path $payload "loader\ue4ss\Mods\shared\UEHelpers\UEHelpers.lua") $sharedDst -Force
    }
}
New-Item -ItemType Directory -Force $modsDir | Out-Null

# --- 2. the mods ---------------------------------------------------------------------------------------------
$trainerDst = Join-Path $modsDir "AI_Trainer"
$cfgDst = Join-Path $trainerDst "Scripts\config.lua"
$cfgSrc = Join-Path $payload "mod\AI_Trainer\Scripts\config.lua"
if ((Test-Path $cfgDst) -and ((Get-FileHash $cfgDst).Hash -ne (Get-FileHash $cfgSrc).Hash)) {
    $keep = Join-Path $win64 "AI_Trainer_config_previous_$stamp.lua"
    Copy-Item $cfgDst $keep -Force
    Write-Host "Previous config.lua saved as $keep (the new version has new keys; copy your edits over if you had any)"
}
$kbExisted = Test-Path (Join-Path $modsDir "Keybinds")
if ($installedKeybinds -eq $null) { $installedKeybinds = -not $kbExisted }
Copy-Item (Join-Path $payload "mod\AI_Trainer") $modsDir -Recurse -Force
if (-not $kbExisted) { Copy-Item (Join-Path $payload "mod\Keybinds") $modsDir -Recurse -Force }
$enable = @("AI_Trainer"); if ($installedKeybinds -or -not $kbExisted) { $enable += "Keybinds" }
Set-ModsTxt (Join-Path $modsDir "mods.txt") $enable
Set-ModsJson (Join-Path $modsDir "mods.json") $enable

# --- 3. manifest + verification --------------------------------------------------------------------------------
$modRoot = Join-Path $payload "mod"
$files = @(Get-ChildItem (Join-Path $modRoot "AI_Trainer") -Recurse -File | ForEach-Object { "ue4ss\Mods\" + $_.FullName.Substring($modRoot.Length + 1) })
$m = [ordered]@{
    trainer = "AI_Trainer $TrainerVersion"; installed = (Get-Date).ToString("s"); game_exe_sha256 = $sha
    we_installed_loader = $weInstalledLoader; loader_backup = $(if ($loaderBackup -and (Test-Path $loaderBackup)) { $loaderBackup } else { $null })
    installed_keybinds = [bool]$installedKeybinds; files = $files
}
$m | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding ASCII

$bad = 0
foreach ($f in (Get-ChildItem (Join-Path $modRoot "AI_Trainer") -Recurse -File)) {
    $rel = $f.FullName.Substring($modRoot.Length + 1)
    $b = Join-Path $modsDir $rel
    if (-not (Test-Path $b) -or (Get-FileHash $f.FullName).Hash -ne (Get-FileHash $b).Hash) { Write-Host "MISMATCH: $rel" -ForegroundColor Red; $bad++ }
}
if ($loaderCopied) {
    foreach ($rel in @("dwmapi.dll", "ue4ss\UE4SS.dll")) {
        $a = Join-Path (Join-Path $payload "loader") $rel
        if ((Get-FileHash $a).Hash -ne (Get-FileHash (Join-Path $win64 $rel)).Hash) { Write-Host "MISMATCH: $rel" -ForegroundColor Red; $bad++ }
    }
}
if ($bad -ne 0) { throw "Verification failed for $bad file(s)." }
Write-Host "Installed OK ($($files.Count) trainer files verified)." -ForegroundColor Green
Write-Host "Start the game from Steam and load a save. About 30 s later the trainer panel appears at the left of the screen."
Write-Host "Keys: F1-F10, PageUp map items, DEL reveal map, PageDown talent points, END infinite dash, F12 minimap, INS mouse mode, F8 collapse the panel. See README.md."
