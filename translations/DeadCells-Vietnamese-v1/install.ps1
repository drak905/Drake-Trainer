# Dead Cells - Vietnamese language patch v1 (Tiếng Việt) installer.
# Changes two things in the game folder:
#   1. deadcells.exe : adds "Tiếng Việt" to the game's language list (original kept as deadcells.exe.vi-backup)
#   2. res<N>.pak    : new file with the Vietnamese texts and font glyphs (the game loads res1.pak, res2.pak, ...
#                      after res.pak by itself; res.pak is not modified)
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

# Builds this package was made and tested with (Epic Games, v35 "1.25.2Win-8b5231cd25").
$Known = @{
    "FFC17ED5DCB4B5A4C0D647E917DC0BC58441A4ADB650A7E84F761212EE2E5A77" = @{ name = "original game";          delta = "vanilla_to_vi.xdelta"; out = "FC4450DCA3089CE27DF757C473E5E899B2F1679A1AD20C964EDB6F581C7EEA60" }
    "5514FD6759F8C82813FD34B8B250390668A01CD51CF7038D3FEEB373156C6E39" = @{ name = "game + DC Trainer v1";   delta = "trainer_to_vi.xdelta"; out = "0425A366D2D5D157230D0BEDE729668C6452C88FC57FB7A28B5ECF791DFE2796" }
}

. (Join-Path $Here "common.ps1")

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir "deadcells.exe"))) {
    Write-Host "Dead Cells not found. Run:  powershell -ExecutionPolicy Bypass -File install.ps1 -GameDir ""D:\Path\To\DeadCells""" -ForegroundColor Red
    exit 1
}
$Exe = Join-Path $GameDir "deadcells.exe"
$Backup = "$Exe.vi-backup"
$ResPak = Join-Path $GameDir "res.pak"
Write-Host "Game folder: $GameDir"

if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe }) {
    Write-Host "Dead Cells is running. Close the game first, then run the installer again." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $ResPak)) { Write-Host "res.pak not found in the game folder." -ForegroundColor Red; exit 1 }
$main = Read-PakHead $ResPak
if (-not $main -or $main.version -lt 1) { Write-Host "Unsupported res.pak format (version $($main.version))." -ForegroundColor Red; exit 1 }
$stamp = New-Object byte[] 64
[Array]::Copy($main.bytes, 12, $stamp, 0, 64)

# Back up the saves (Epic keeps them in <game>\save).
$Save = Join-Path $GameDir "save"
if (Test-Path $Save) {
    $dest = Join-Path $GameDir ("save-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item -Recurse $Save $dest
    Write-Host "Saves backed up to $dest"
}

# ---- 1. deadcells.exe ---------------------------------------------------------------------------
if (Exe-IsPatched $Exe) {
    Write-Host "deadcells.exe: Vietnamese entry already present."
} else {
    Copy-Item $Exe $Backup -Force
    Write-Host "Original exe saved as $Backup"
    $cur = Sha $Exe
    if ($Known.ContainsKey($cur)) {
        $k = $Known[$cur]
        Write-Host "deadcells.exe: $($k.name) (known build)."
        $tmp = Join-Path $env:TEMP "deadcells.vi.exe"
        & (Join-Path $Here "payload\xdelta3.exe") -d -f -s $Exe (Join-Path $Here ("payload\" + $k.delta)) $tmp
        if ($LASTEXITCODE -ne 0 -or (Sha $tmp) -ne $k.out) { Write-Host "Patch failed to apply; nothing was changed." -ForegroundColor Red; exit 1 }
        Copy-Item $tmp $Exe -Force
        Remove-Item $tmp
        if ((Sha $Exe) -ne $k.out) { Copy-Item $Backup $Exe -Force; Write-Host "Write failed; original restored." -ForegroundColor Red; exit 1 }
    } else {
        Write-Host "deadcells.exe is a different build than this package was made for; rebuilding the patch for it." -ForegroundColor Yellow
        $py = Find-Python
        if (-not $py) { Write-Host "Install Python 3 (python.org), then run this installer again." -ForegroundColor Red; exit 1 }
        & $py.Source (Join-Path $Here "source\tools\patch_any_version.py") $Exe
        if ($LASTEXITCODE -ne 0 -or -not (Exe-IsPatched $Exe)) {
            Copy-Item $Backup $Exe -Force
            Write-Host "Could not patch this build (see message above); original exe restored." -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "deadcells.exe patched."
}

# ---- 2. res<N>.pak with texts + fonts --------------------------------------------------------------
# The game loads res1.pak, res2.pak, ... in order and stops at the first missing number.
$slot = $null
for ($i = 1; $i -lt 100; $i++) {
    $p = Join-Path $GameDir "res$i.pak"
    if (-not (Test-Path $p)) { if (-not $slot) { $slot = $p }; break }
    if (Pak-IsOurs $p) { $slot = $p; break }
}
$bytes = [IO.File]::ReadAllBytes((Join-Path $Here "payload\dc-vietnamese.pak"))
[Array]::Copy($stamp, 0, $bytes, 12, 64)   # stamp must match the game's res.pak or the game ignores the pak
[IO.File]::WriteAllBytes($slot, $bytes)
Write-Host "Texts and fonts installed as $(Split-Path -Leaf $slot)."

Write-Host ""
Write-Host "Done. Start Dead Cells from the launcher, then on the title screen choose" -ForegroundColor Green
Write-Host "  Options > Language > Tiếng Việt   (the language can only be changed on the title screen)." -ForegroundColor Green
