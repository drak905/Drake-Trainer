# Afterimage - Vietnamese language pack - uninstaller. Run via Uninstall.bat.
param([string]$GameDir = "", [switch]$Quiet)
$ErrorActionPreference = "Stop"
function Find-GameDir {
    $libs = @(); $steam = $null
    try { $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath } catch {}
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
Write-Host "=== Afterimage Vietnamese pack - uninstall ===" -ForegroundColor Cyan
if (-not $GameDir) { $GameDir = Find-GameDir }
if (-not $GameDir -and -not $Quiet) { $GameDir = Read-Host "Enter the game folder (the one containing Afterimage.exe)" }
if (-not $GameDir) { throw "Game folder not found." }
$GameDir = $GameDir.Trim('"')
$win64 = Join-Path $GameDir "Afterimage\Binaries\Win64"
if (Get-Process -Name "Afterimage-Win64-Shipping" -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifestPath = Join-Path $win64 "AI_Vietnamese_install.json"
$man = $null; if (Test-Path $manifestPath) { try { $man = Get-Content $manifestPath -Raw | ConvertFrom-Json } catch {} }

$modsDir = Join-Path $win64 "ue4ss\Mods"
# remove the mod folder
$modDst = Join-Path $modsDir "AI_Vietnamese"
if (Test-Path $modDst) { Remove-Item $modDst -Recurse -Force; Write-Host "removed AI_Vietnamese mod" }
# drop the entry from mods.txt
$modsTxt = Join-Path $modsDir "mods.txt"
if (Test-Path $modsTxt) {
    $lines = @(Get-Content $modsTxt | Where-Object { $_ -notmatch '^\s*AI_Vietnamese\s*:' -and $_ -ne "" })
    Set-Content $modsTxt (($lines -join "`r`n") + "`r`n") -Encoding ASCII
}
# drop the entry from mods.json (build the string by hand for PS 5.1 safety)
$modsJson = Join-Path $modsDir "mods.json"
if (Test-Path $modsJson) {
    try {
        $parsed = Get-Content $modsJson -Raw | ConvertFrom-Json
        $entries = @()
        foreach ($e in $parsed) {
            if ($e.mod_name -and $e.mod_name -ne "AI_Vietnamese") {
                $en = $(if ($e.mod_enabled) { "true" } else { "false" })
                $entries += ('{"mod_name":"' + $e.mod_name + '","mod_enabled":' + $en + '}')
            }
        }
        Set-Content $modsJson ("[" + ($entries -join ",") + "]") -Encoding ASCII
    } catch {}
}

# only remove the UE4SS loader if WE installed it AND no other of our mods (e.g. AI_Trainer) remain
$removeLoader = $false
if ($man -and $man.we_installed_loader) {
    $others = @()
    if (Test-Path $modsDir) {
        $others = Get-ChildItem $modsDir -Directory | Where-Object { $_.Name -ne "shared" }
    }
    if ($others.Count -eq 0) { $removeLoader = $true }
    else { Write-Host "Keeping the UE4SS loader - other mods still use it: $($others.Name -join ', ')" }
}
if ($removeLoader) {
    foreach ($n in @("dwmapi.dll", "ue4ss", "ue4ss_recon")) { $p = Join-Path $win64 $n; if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "removed $n" } }
    if ($man.loader_backup -and (Test-Path $man.loader_backup)) {
        $b = Join-Path $man.loader_backup "dwmapi.dll"
        if (Test-Path $b) { Move-Item $b (Join-Path $win64 "dwmapi.dll"); Write-Host "restored your previous dwmapi.dll" }
        Remove-Item $man.loader_backup -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (Test-Path $manifestPath) { Remove-Item $manifestPath -Force }
Write-Host "Vietnamese pack uninstalled. Game files and saves were never modified." -ForegroundColor Green
