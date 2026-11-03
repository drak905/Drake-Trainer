param(
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"

if ($GameDir -eq "") {
    $candidates = @(
        "E:\EpicGames\DeathsGambitAfterlifMUr7y",
        "$env:ProgramFiles\Epic Games\DeathsGambitAfterlife",
        (Join-Path ([Environment]::GetFolderPath("ProgramFilesX86")) "Epic Games\DeathsGambitAfterlife")
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "data.win")) { $GameDir = $c; break }
    }
    if ($GameDir -eq "") {
        $GameDir = Read-Host "Paste full path to the Death's Gambit Afterlife folder"
    }
}

$dataWin = Join-Path $GameDir "data.win"
$backup  = Join-Path $GameDir "data.win.VANILLA"

if (!(Test-Path $backup)) { Write-Error "No vanilla backup found ($backup). Use Epic 'Verify' to restore original files instead." }

$running = Get-Process deathsgambit397 -ErrorAction SilentlyContinue
if ($running) { Write-Error "Game is running. Close it first, then re-run this script." }

Copy-Item -LiteralPath $backup -Destination $dataWin -Force
Write-Host "Reverted to vanilla (backup restored). You can delete data.win.VANILLA if you need the disk space."
