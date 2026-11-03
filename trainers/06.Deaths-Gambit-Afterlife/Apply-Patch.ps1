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
        $GameDir = Read-Host "Game folder not found automatically. Paste full path to the Death's Gambit Afterlife folder"
    }
}

$dataWin = Join-Path $GameDir "data.win"
$backup  = Join-Path $GameDir "data.win.VANILLA"
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$xd      = Join-Path $here "xdelta3.exe"
$patch   = Join-Path $here "dg_trainer_v4.xdelta"

$expectedVanilla = "C924BC2A7B98B65CF1C376750C39256974E969508194AFF32D85CA4243DC661C"
$expectedPatched = "EBC3582E4C28868AA73E181BCDC313E65A3485A835D94672018DF3494F5C1530"

if (!(Test-Path $xd))    { Write-Error "xdelta3.exe missing next to this script." }
if (!(Test-Path $patch)) { Write-Error "dg_trainer_v4.xdelta missing next to this script." }
if (!(Test-Path $dataWin)) { Write-Error "data.win not found in $GameDir. Run the game once, then retry." }

$running = Get-Process deathsgambit397 -ErrorAction SilentlyContinue
if ($running) { Write-Error "Game is running. Close it first, then re-run this script." }

if (!(Test-Path $backup)) {
    Write-Host "Backing up original data.win -> data.win.VANILLA ..."
    Copy-Item -LiteralPath $dataWin -Destination $backup -Force
} else {
    Write-Host "Backup already exists, keeping it."
}

$srcHash = (Get-FileHash -LiteralPath $dataWin -Algorithm SHA256).Hash
if ($srcHash -eq $expectedPatched) {
    Write-Host "Trainer v4 is already installed. Nothing to do."
    exit 0
}
if ($srcHash -ne $expectedVanilla) {
    Write-Warning "Your data.win does not match the expected vanilla build (different game version?). The patch may fail."
    $ans = Read-Host "Continue anyway? (y/N)"
    if ($ans -ne "y") { exit 1 }
}

Write-Host "Applying trainer v4 patch (this takes ~30 seconds on an SSD) ..."
& $xd -d -s $dataWin $patch "$dataWin.patched"
$newHash = (Get-FileHash -LiteralPath "$dataWin.patched" -Algorithm SHA256).Hash
if ($newHash -ne $expectedPatched) {
    Remove-Item -LiteralPath "$dataWin.patched" -Force -ErrorAction SilentlyContinue
    Write-Error "Patched file verification FAILED (hash mismatch). Your data.win was NOT modified."
}
Move-Item -LiteralPath "$dataWin.patched" -Destination $dataWin -Force

Write-Host ""
Write-Host "Done. Trainer v4 installed."
Write-Host "F1 God+feathers | F2 Stamina/Soul/Ammo | F3 Essence bonus | F4 Unlimited jump | F5 One-hit kill (default OFF) | G +99999 essence"
Write-Host "To uninstall, run Revert-Patch.ps1 (restores your vanilla backup)."
