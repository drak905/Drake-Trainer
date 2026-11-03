# Sol Cesto launcher + trainer.
#
# Sets the WebView2 debugging port for THIS launch only, starts the game, waits
# for the debugging port to open, then runs the trainer in auto mode so the
# loadout is applied at the start of every run.
#
# Run it by double-clicking PlaySolCesto.bat, or from PowerShell:
#     .\PlaySolCesto.ps1
#     .\PlaySolCesto.ps1 -Gate        # also force porte_Requis to 1
#     .\PlaySolCesto.ps1 -NoTrainer   # just launch with the port open

param(
    [switch]$Gate,
    [switch]$NoTrainer,
    [int]$Port = 9222,
    [string]$GameExe = "E:\EpicGames\SolCesto\SolCesto.exe",
    [string]$ScriptDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

function Test-Port([int]$p) {
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.Connect("127.0.0.1", $p)
        $c.Close()
        return $true
    } catch { return $false }
}

Write-Host "=== Sol Cesto launcher ===" -ForegroundColor Cyan

if (-not (Test-Path $GameExe)) {
    Write-Host "Game not found at: $GameExe" -ForegroundColor Red
    Write-Host "Edit the -GameExe path at the top of this script."
    Read-Host "Press Enter to exit"; exit 1
}

if (Get-Process SolCesto -ErrorAction SilentlyContinue) {
    Write-Host "SolCesto is already running." -ForegroundColor Yellow
    if (-not (Test-Port $Port)) {
        Write-Host "...and it has NO debugging port, so the trainer cannot attach." -ForegroundColor Red
        Write-Host "Close the game first, then run this script again."
        Read-Host "Press Enter to exit"; exit 1
    }
    Write-Host "Debugging port $Port is already open - reusing it." -ForegroundColor Green
} else {
    # Scoped to this process tree only; does NOT affect other WebView2 apps.
    $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = "--remote-debugging-port=$Port"
    Write-Host "Launching game with debugging port $Port ..." -ForegroundColor Green
    Start-Process -FilePath $GameExe -WorkingDirectory (Split-Path $GameExe)

    Write-Host -NoNewline "Waiting for debugging port"
    $ok = $false
    foreach ($i in 1..60) {
        Start-Sleep -Seconds 1
        Write-Host -NoNewline "."
        if (Test-Port $Port) { $ok = $true; break }
    }
    Write-Host ""
    if (-not $ok) {
        Write-Host "Port $Port never opened. The game may have blocked it." -ForegroundColor Red
        Read-Host "Press Enter to exit"; exit 1
    }
    Write-Host "Debugging port is open." -ForegroundColor Green
}

if ($NoTrainer) {
    Write-Host "-NoTrainer set; leaving the game running without the trainer."
    exit 0
}

Write-Host ""
Write-Host "Starting trainer (continuous enforcement)." -ForegroundColor Cyan
Write-Host "Values are re-applied whenever the game resets them, so they survive"
Write-Host "new runs, character changes and floor transitions."
Write-Host "Leave this window open while you play. Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

Push-Location $ScriptDir
try {
    $trainerArgs = @("-u", "solcesto_trainer.py")
    if ($Gate) { $trainerArgs += "--gate" }
    & python @trainerArgs
} finally {
    Pop-Location
}
