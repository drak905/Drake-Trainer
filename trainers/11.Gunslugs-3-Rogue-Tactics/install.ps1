param(
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
$PatchRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PayloadJar = Join-Path $PatchRoot "payload\gunslugs3-trainer.jar"
$PayloadCfg = Join-Path $PatchRoot "payload\config.json"

$ExpectedDatSha256 = "8E9F0784C8824119AC5572BAA09E9D93E317FFD0A6AD3F1DE1BE4A76E61BEBDF"
$ExpectedDatMd5    = "775B285DA1B558EFB798D6E6CBD83ED0"

function Resolve-GameDirectory {
    param([string]$InputDir)
    $Candidates = @()
    if ($InputDir) { $Candidates += $InputDir }
    if ($env:GUNSLUGS3_DIR) { $Candidates += $env:GUNSLUGS3_DIR }
    $Candidates += @(
        (Get-Location).Path,
        $PatchRoot,
        (Split-Path -Parent $PatchRoot),
        "E:\GOGGalaxy\Gunslugs3RogueTactics",
        "C:\GOG Games\Gunslugs 3 - Rogue Tactics",
        "D:\GOG Games\Gunslugs 3 - Rogue Tactics",
        "E:\GOG Games\Gunslugs 3 - Rogue Tactics",
        "C:\Program Files (x86)\GOG Galaxy\Games\Gunslugs3RogueTactics",
        "C:\Program Files (x86)\Steam\steamapps\common\Gunslugs 3"
    )
    foreach ($cand in $Candidates) {
        if ($cand -and (Test-Path (Join-Path $cand "gunslugs3.dat")) -and (Test-Path (Join-Path $cand "gunslugs3.exe"))) {
            return (Resolve-Path $cand).Path
        }
    }
    return $null
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Gunslugs 3: Rogue Tactics - In-Game Trainer Installer v1.0 " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (-not (Test-Path $PayloadJar) -or -not (Test-Path $PayloadCfg)) {
    throw "Missing payload files in $(Join-Path $PatchRoot 'payload')."
}

$ResolvedDir = Resolve-GameDirectory -InputDir $GameDir
if (-not $ResolvedDir) {
    $UserEntered = Read-Host "Enter the full path to your Gunslugs 3: Rogue Tactics folder (containing gunslugs3.exe and gunslugs3.dat)"
    $ResolvedDir = Resolve-GameDirectory -InputDir $UserEntered
}
if (-not $ResolvedDir) {
    throw "Could not find gunslugs3.exe and gunslugs3.dat in the specified folder."
}

Write-Host "[1/4] Target game folder: $ResolvedDir" -ForegroundColor Green

$DatPath = Join-Path $ResolvedDir "gunslugs3.dat"
$ActualSha256 = (Get-FileHash -Path $DatPath -Algorithm SHA256).Hash.ToUpperInvariant()
$ActualMd5    = (Get-FileHash -Path $DatPath -Algorithm MD5).Hash.ToUpperInvariant()

Write-Host "[2/4] Verifying gunslugs3.dat integrity..."
Write-Host "      SHA256: $ActualSha256"
Write-Host "      MD5   : $ActualMd5"

if ($ActualSha256 -eq $ExpectedDatSha256) {
    Write-Host "      Exact match with verified v1.0.10b release!" -ForegroundColor Green
} else {
    Write-Warning "gunslugs3.dat hash differs from v1.0.10b baseline ($ExpectedDatSha256). Proceeding with classpath injection..."
}

$TargetCfg     = Join-Path $ResolvedDir "config.json"
$TargetCfgOrig = Join-Path $ResolvedDir "config.json.orig"
$TargetJar     = Join-Path $ResolvedDir "gunslugs3-trainer.jar"

if ((Test-Path $TargetCfg) -and -not (Test-Path $TargetCfgOrig)) {
    Write-Host "[3/4] Backing up original config.json -> config.json.orig"
    Copy-Item -Force $TargetCfg $TargetCfgOrig
} else {
    Write-Host "[3/4] Backup config.json.orig already exists (preserving clean backup)"
}

Write-Host "[4/4] Installing gunslugs3-trainer.jar and updating Packr config.json..."
Copy-Item -Force $PayloadJar $TargetJar
Copy-Item -Force $PayloadCfg $TargetCfg

$InstalledJarSha = (Get-FileHash -Path $TargetJar -Algorithm SHA256).Hash.ToUpperInvariant()
Write-Host ""
Write-Host "[SUCCESS] Gunslugs 3 Trainer v1.0 installed!" -ForegroundColor Green
Write-Host "          Installed JAR SHA256: $InstalledJarSha"
Write-Host "          Original gunslugs3.exe and gunslugs3.dat remain 100% unmodified."
Write-Host ""
Write-Host "Hotkeys in-game:" -ForegroundColor Yellow
Write-Host "  F1 : God Mode (ON/OFF)"
Write-Host "  F2 : +500 Coins, +1 Skill Point, +200 XP, Full HP & Unlock All Heroes"
Write-Host "  F3 : Unlimited Money & Items + Free Shops (ON/OFF)"
Write-Host "  F4 : Unlimited Jump / Infinite Air Jump (ON/OFF)"
Write-Host "  F5 : Character Move Speed x2 (ON/OFF)"
Write-Host "  F6 : Show All Items on Map / ESP + Top Radar Bar (ON/OFF)"
Write-Host "  F7 : One-Hit Kill Monsters & Bosses (ON/OFF)"
Write-Host "  F8 : Cycle Weapon (0..18) + Full Ammo"
Write-Host "  F9 / F10 / INSERT : Show/Hide Trainer Menu"
