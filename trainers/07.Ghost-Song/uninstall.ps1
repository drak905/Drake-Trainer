# Removes everything install.ps1 added.  -Purge also deletes the trainer's log / settings / self-test files.
param([string]$GameDir = "", [switch]$Purge)
$ErrorActionPreference = "Stop"
$GameId = "1305299338"

function Find-Game {
    foreach ($root in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games", "HKLM:\SOFTWARE\GOG.com\Games")) {
        $k = Join-Path $root $GameId
        if (Test-Path $k) {
            $p = (Get-ItemProperty $k -ErrorAction SilentlyContinue).path
            if ($p -and (Test-Path (Join-Path $p "GhostSong.exe"))) { return $p }
        }
    }
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        foreach ($rel in @("GOGGalaxy\Ghost Song", "GOG Games\Ghost Song", "Games\Ghost Song", "Program Files (x86)\GOG Galaxy\Games\Ghost Song",
                           "Program Files\GOG Galaxy\Games\Ghost Song", "SteamLibrary\steamapps\common\Ghost Song",
                           "Program Files (x86)\Steam\steamapps\common\Ghost Song")) {
            $p = Join-Path $d.Root $rel
            if (Test-Path (Join-Path $p "GhostSong.exe")) { return $p }
        }
    }
    return ""
}

function Test-OurDll([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($Path))
    return $text.Contains("Ghost Song trainer start")
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) { $GameDir = Read-Host "Paste the folder that contains GhostSong.exe" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (Get-Process GhostSong -ErrorAction SilentlyContinue) { throw "Close the game first." }

$manifest = Join-Path $GameDir "GhostSongTrainer_install_manifest.txt"
if (Test-Path $manifest) {
    foreach ($r in (Get-Content $manifest)) {
        if (-not $r) { continue }
        $p = Join-Path $GameDir $r
        if (Test-Path $p) { Remove-Item $p -Force }
    }
    Remove-Item $manifest -Force
} else {
    $v = Join-Path $GameDir "version.dll"
    if (Test-OurDll $v) { Remove-Item $v -Force }
}
# give a foreign version.dll (another mod) back; an old copy of our own trainer is simply discarded
$orig = Join-Path $GameDir "version.dll.orig"
if (Test-Path $orig) {
    if (Test-OurDll $orig) { Remove-Item $orig -Force }
    elseif (-not (Test-Path (Join-Path $GameDir "version.dll"))) { Move-Item $orig (Join-Path $GameDir "version.dll") -Force }
}

if ($Purge) {
    foreach ($n in @("gs_trainer.log", "gs_trainer.ini", "gs_trainer_ui.ini", "trainer_selftest_report.json",
                     "trainer_selftest.flag", "trainer_menu_open.flag")) {
        Remove-Item (Join-Path $GameDir $n) -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "Trainer removed from $GameDir"
Write-Host "Your saves were never touched by the installer."
