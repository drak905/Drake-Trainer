# Afterimage Trainer - uninstaller. Run via Uninstall.bat.
# Removes only what the trainer added. The UE4SS loader is kept while another mod (for example the Vietnamese pack) still uses it.
param([string]$GameDir = "", [switch]$Quiet)
$ErrorActionPreference = "Stop"
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
function Remove-ModEntries([string]$modsDir, [string[]]$names) {
    $txt = Join-Path $modsDir "mods.txt"
    if (Test-Path $txt) {
        $lines = @(Get-Content $txt | Where-Object {
            $l = $_; ($l.Trim() -ne "") -and -not ($names | Where-Object { $l -match ('^\s*' + [regex]::Escape($_) + '\s*:') })
        })
        Set-Content $txt (($lines -join "`r`n") + "`r`n") -NoNewline -Encoding ASCII
    }
    $json = Join-Path $modsDir "mods.json"
    if (Test-Path $json) {
        try {
            $parts = @()
            foreach ($e in (Get-Content $json -Raw | ConvertFrom-Json)) {
                if ($e.mod_name -and ($names -notcontains $e.mod_name)) {
                    $parts += ('{"mod_name":"' + $e.mod_name + '","mod_enabled":' + $(if ($e.mod_enabled) { "true" } else { "false" }) + '}')
                }
            }
            Set-Content $json ("[" + ($parts -join ",") + "]") -Encoding ASCII
        } catch {}
    }
}

Write-Host "=== Afterimage Trainer - uninstall ===" -ForegroundColor Cyan
if (-not $GameDir) { $GameDir = Find-GameDir }
if (-not $GameDir -and -not $Quiet) { $GameDir = Read-Host "Enter the game folder (the one containing Afterimage.exe)" }
if (-not $GameDir) { throw "Game folder not found." }
$GameDir = $GameDir.Trim('"')
$win64 = Join-Path $GameDir "Afterimage\Binaries\Win64"
if (Get-Process -Name "Afterimage-Win64-Shipping" -ErrorAction SilentlyContinue) { throw "Close the game first." }
$manifestPath = Join-Path $win64 "AI_Trainer_install.json"
if (-not (Test-Path $manifestPath)) { throw "No AI_Trainer_install.json in $win64 - nothing of ours to remove." }
$m = Get-Content $manifestPath -Raw | ConvertFrom-Json
$legacy = -not ($m.PSObject.Properties.Name -contains "we_installed_loader")      # manifest of trainer 1.0 - 1.2
$weLoader = $(if ($legacy) { $true } else { [bool]$m.we_installed_loader })
$loaderBackup = $(if ($legacy) { $m.backup } else { $m.loader_backup })
$ourKeybinds = $(if ($legacy) { $true } else { [bool]$m.installed_keybinds })

$modsDir = Join-Path $win64 "ue4ss\Mods"
$trainer = Join-Path $modsDir "AI_Trainer"
if (Test-Path $trainer) { Remove-Item $trainer -Recurse -Force; Write-Host "removed AI_Trainer mod" }
$names = @("AI_Trainer")
if ($ourKeybinds) {
    $kb = Join-Path $modsDir "Keybinds"
    if (Test-Path $kb) { Remove-Item $kb -Recurse -Force; Write-Host "removed Keybinds mod" }
    $names += "Keybinds"
}
Remove-ModEntries $modsDir $names
foreach ($n in @("AI_Trainer_selftest_report.json")) { $p = Join-Path $win64 $n; if (Test-Path $p) { Remove-Item $p -Force; Write-Host "removed $n" } }
Get-ChildItem $win64 -Filter "AI_Trainer_config_previous_*.lua" -ErrorAction SilentlyContinue | ForEach-Object { Remove-Item $_.FullName -Force; Write-Host "removed $($_.Name)" }

# the loader goes only if we put it there and no other mod needs it
$others = @()
if (Test-Path $modsDir) { $others = @(Get-ChildItem $modsDir -Directory | Where-Object { $_.Name -ne "shared" -and $_.Name -ne "Keybinds" }) }
if ($weLoader -and $others.Count -eq 0) {
    foreach ($n in @("dwmapi.dll", "ue4ss", "ue4ss_recon")) { $p = Join-Path $win64 $n; if (Test-Path $p) { Remove-Item $p -Recurse -Force; Write-Host "removed $n" } }
    if ($loaderBackup -and (Test-Path $loaderBackup)) {
        foreach ($n in @("dwmapi.dll", "ue4ss")) {
            $b = Join-Path $loaderBackup $n
            if (Test-Path $b) { Move-Item $b (Join-Path $win64 $n); Write-Host "restored previous $n" }
        }
        Remove-Item $loaderBackup -Recurse -Force -ErrorAction SilentlyContinue
    }
} elseif ($weLoader) {
    Write-Host "Keeping the UE4SS loader - other mods still use it: $($others.Name -join ', ')"
    # hand the loader over to the Vietnamese pack so ITS uninstaller cleans it up later
    $viMan = Join-Path $win64 "AI_Vietnamese_install.json"
    if (Test-Path $viMan) {
        try {
            $vm = Get-Content $viMan -Raw | ConvertFrom-Json
            if (-not [bool]$vm.we_installed_loader) {
                $vm.we_installed_loader = $true
                if ($loaderBackup) { $vm.loader_backup = $loaderBackup }
                $vm | ConvertTo-Json -Depth 4 | Set-Content $viMan -Encoding ASCII
                Write-Host "(loader ownership handed to the Vietnamese pack)"
            }
        } catch {}
    }
}
Remove-Item $manifestPath -Force
Write-Host "Uninstalled. Game files were never modified; save files are untouched." -ForegroundColor Green
