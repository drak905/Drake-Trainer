# Dead Cells - Trainer v1 uninstaller: puts the original deadcells.exe back.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"

if (-not $GameDir) {
    $dat = "C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
    if (Test-Path $dat) {
        foreach ($e in (Get-Content $dat -Raw | ConvertFrom-Json).InstallationList) {
            if ($e.InstallLocation -and (Test-Path (Join-Path $e.InstallLocation "deadcells.exe.trainer-backup"))) { $GameDir = $e.InstallLocation }
        }
    }
}
if (-not $GameDir) {
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        foreach ($rel in @("EpicGames\DeadCells", "Epic Games\DeadCells", "Program Files\Epic Games\DeadCells",
                           "GOG Games\Dead Cells", "Games\Dead Cells", "SteamLibrary\steamapps\common\Dead Cells",
                           "Program Files (x86)\Steam\steamapps\common\Dead Cells")) {
            $p = Join-Path $d.Root $rel
            if (Test-Path (Join-Path $p "deadcells.exe.trainer-backup")) { $GameDir = $p }
        }
    }
}
if (-not $GameDir) {
    Write-Host "No trainer backup found. Pass -GameDir, or use 'Verify' in the Epic/Steam launcher to restore the game." -ForegroundColor Yellow
    exit 1
}
$Exe = Join-Path $GameDir "deadcells.exe"
if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe }) {
    Write-Host "Dead Cells is running. Close the game first." -ForegroundColor Red
    exit 1
}
Copy-Item "$Exe.trainer-backup" $Exe -Force
Remove-Item "$Exe.trainer-backup"
$Libhl = Join-Path $GameDir "libhl.dll"
if (Test-Path "$Libhl.trainer-backup") {
    Copy-Item "$Libhl.trainer-backup" $Libhl -Force
    Remove-Item "$Libhl.trainer-backup"
    Write-Host "Original libhl.dll restored (the game's own hang-on-quit can come back on some PCs)."
}
Write-Host "Original deadcells.exe restored in $GameDir. Your save-backup-* folders were left in place." -ForegroundColor Green
