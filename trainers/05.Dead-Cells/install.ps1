# Dead Cells - Trainer v1 installer (patches the HashLink bytecode embedded in deadcells.exe).
# Touches two game files: deadcells.exe (cheats) and libhl.dll (quit-hang fix); originals are kept as *.trainer-backup.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Builds this package was made and tested with (Epic Games, v35 "1.25.2Win-8b5231cd25").
$VanillaSha = "FFC17ED5DCB4B5A4C0D647E917DC0BC58441A4ADB650A7E84F761212EE2E5A77"
$PatchedSha = "5514FD6759F8C82813FD34B8B250390668A01CD51CF7038D3FEEB373156C6E39"
$LibhlVanillaSha = "638F8CDCF56E36FBF74D1359072496AA01D0D8F89C9E06629A0674B6E81804F7"
$LibhlPatchedSha = "3A936EEA0945646F8E329BE4F50E287C97AFEF93C174B5FD0F8A81FFCC9A4513"

function Find-Game {
    # Epic Games launcher
    $dat = "C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
    if (Test-Path $dat) {
        try {
            foreach ($e in (Get-Content $dat -Raw | ConvertFrom-Json).InstallationList) {
                if ($e.InstallLocation -and (Test-Path (Join-Path $e.InstallLocation "deadcells.exe"))) { return $e.InstallLocation }
            }
        } catch {}
    }
    # Steam libraries
    foreach ($sk in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam")) {
        try {
            $s = Get-ItemProperty $sk -ErrorAction Stop
            $root = if ($s.SteamPath) { $s.SteamPath } else { $s.InstallPath }
            if ($root) {
                $cands = @(Join-Path $root "steamapps\common\Dead Cells")
                $vdf = Join-Path $root "steamapps\libraryfolders.vdf"
                if (Test-Path $vdf) {
                    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                        $cands += (Join-Path ($m.Groups[1].Value -replace '\\\\', '\') "steamapps\common\Dead Cells")
                    }
                }
                foreach ($c in $cands) { if (Test-Path (Join-Path $c "deadcells.exe")) { return $c } }
            }
        } catch {}
    }
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        foreach ($rel in @("EpicGames\DeadCells", "Epic Games\DeadCells", "Program Files\Epic Games\DeadCells",
                           "GOG Games\Dead Cells", "Games\Dead Cells", "SteamLibrary\steamapps\common\Dead Cells")) {
            $p = Join-Path $d.Root $rel
            if (Test-Path (Join-Path $p "deadcells.exe")) { return $p }
        }
    }
    return ""
}

function Sha([string]$p) { (Get-FileHash -Algorithm SHA256 $p).Hash }

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir "deadcells.exe"))) {
    Write-Host "Dead Cells not found. Run:  powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir ""D:\Path\To\DeadCells""" -ForegroundColor Red
    exit 1
}
$Exe = Join-Path $GameDir "deadcells.exe"
$Backup = "$Exe.trainer-backup"
$Libhl = Join-Path $GameDir "libhl.dll"
Write-Host "Game folder: $GameDir"

if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe }) {
    Write-Host "Dead Cells is running. Close the game first, then run the installer again." -ForegroundColor Red
    exit 1
}

function Find-Python {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    return $py
}

# Quit-hang fix: libhl.dll!hl_sys_exit calls exit(), whose DLL teardown deadlocks in the Epic overlay +
# GPU driver (happens with the unmodified game too). Replace that call with TerminateProcess.
function Fix-Libhl {
    if (-not (Test-Path $Libhl)) { Write-Host "libhl.dll not found; quit fix skipped." -ForegroundColor Yellow; return }
    $h = Sha $Libhl
    if ($h -eq $LibhlPatchedSha) { Write-Host "Quit fix: already applied."; return }
    if ($h -eq $LibhlVanillaSha) {
        if (-not (Test-Path "$Libhl.trainer-backup")) { Copy-Item $Libhl "$Libhl.trainer-backup" }
        $bytes = [System.IO.File]::ReadAllBytes($Libhl)
        $patch = [byte[]](0x89,0xCA,0x48,0x83,0xC9,0xFF,0xFF,0x15,0xD0,0x58,0x00,0x00)
        [Array]::Copy($patch, 0, $bytes, 0x2ACC4, $patch.Length)
        $tmp = "$Libhl.tmp"
        [System.IO.File]::WriteAllBytes($tmp, $bytes)
        if ((Sha $tmp) -ne $LibhlPatchedSha) { Remove-Item $tmp; Write-Host "Quit fix failed to apply; libhl.dll unchanged." -ForegroundColor Yellow; return }
        Move-Item $tmp $Libhl -Force
        Write-Host "Quit fix applied (libhl.dll)."
        return
    }
    $py = Find-Python
    if ($py) {
        & $py.Source (Join-Path $Here "source\patch_libhl.py") $Libhl
        if ($LASTEXITCODE -eq 0) { Write-Host "Quit fix applied (libhl.dll, built for your version)."; return }
    }
    Write-Host "Quit fix skipped: unknown libhl.dll build (install Python 3 to patch it). If the game hangs on quit, end it in Task Manager." -ForegroundColor Yellow
}

$cur = Sha $Exe
if ($cur -eq $PatchedSha) {
    Write-Host "Trainer is already installed." -ForegroundColor Green
    Fix-Libhl
    exit 0
}

# Upgrade from an older trainer build: go back to the original exe first.
$OlderPatched = @("C4F906F618547D638098868D9A1592BE9A7E938414FBC248364520CF90B69093")
if ($OlderPatched -contains $cur) {
    if ((Test-Path $Backup) -and ((Sha $Backup) -eq $VanillaSha)) {
        Copy-Item $Backup $Exe -Force
        $cur = $VanillaSha
        Write-Host "Older trainer found; upgrading."
    } else {
        Write-Host "Older trainer found but no original backup. Use Epic 'Verify', then run this installer again." -ForegroundColor Red
        exit 1
    }
}

# Back up the saves (Epic keeps them in <game>\save) before the first modded launch.
$Save = Join-Path $GameDir "save"
if (Test-Path $Save) {
    $dest = Join-Path $GameDir ("save-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item -Recurse $Save $dest
    Write-Host "Saves backed up to $dest"
}

if ($cur -eq $VanillaSha) {
    if (-not (Test-Path $Backup)) { Copy-Item $Exe $Backup }
    $tmp = Join-Path $env:TEMP "deadcells.trainer.exe"
    & (Join-Path $Here "payload\xdelta3.exe") -d -f -s $Exe (Join-Path $Here "payload\deadcells.xdelta") $tmp
    if ($LASTEXITCODE -ne 0 -or (Sha $tmp) -ne $PatchedSha) { Write-Host "Patch failed to apply; nothing was changed." -ForegroundColor Red; exit 1 }
    Copy-Item $tmp $Exe -Force
    Remove-Item $tmp
    if ((Sha $Exe) -ne $PatchedSha) { Copy-Item $Backup $Exe -Force; Write-Host "Write failed; original restored." -ForegroundColor Red; exit 1 }
    Fix-Libhl
    Write-Host "Trainer installed. Start Dead Cells from the launcher as usual; F12 shows/hides the menu." -ForegroundColor Green
    exit 0
}

# Different game build: rebuild the patch from this build's own bytecode (needs Python 3.8+).
Write-Host "This deadcells.exe is a different build than the one the package was made for." -ForegroundColor Yellow
$py = Find-Python
if (-not $py) {
    Write-Host "Install Python 3 (python.org), then run this installer again to build a patch for your version." -ForegroundColor Red
    exit 1
}
& $py.Source (Join-Path $Here "source\patch_any_version.py") $GameDir
if ($LASTEXITCODE -ne 0) { Write-Host "Could not patch this build (see message above)." -ForegroundColor Red; exit 1 }
Fix-Libhl
Write-Host "Trainer installed (built for your version)." -ForegroundColor Green

