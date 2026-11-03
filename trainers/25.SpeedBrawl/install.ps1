[CmdletBinding()]
param(
    [string]$GamePath = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$payloadDir = Join-Path $scriptRoot 'payload'
$trainerName = 'SpeedBrawl In-Game Trainer'
$trainerVersion = '1.0.0'
$pluginRelative = 'BepInEx\plugins\SpeedBrawlTrainer.dll'
$manifestRelative = 'BepInEx\plugins\SpeedBrawlTrainer.install.json'
$expectedLunaSha256 = '76DD93E1EFFB3BD063F47F5EDCF664F2847001457F55B6D84E048B7E72D5BA29'

function Write-Step([string]$Text) {
    Write-Host ('==> ' + $Text) -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host ('    ' + $Text) -ForegroundColor Green
}

function Write-Warn([string]$Text) {
    Write-Host ('    WARNING: ' + $Text) -ForegroundColor Yellow
}

function Test-GameFolder([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'SpeedBrawl.exe') -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath (Join-Path $Path 'SpeedBrawl_Data\Managed\DS.Game.Luna.dll') -PathType Leaf)) { return $false }
    return $true
}

function Find-GameFolder {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($GamePath) { $candidates.Add($GamePath) }
    if ($env:SPEEDBRAWL_DIR) { $candidates.Add($env:SPEEDBRAWL_DIR) }
    $candidates.Add('E:\EpicGames\SpeedBrawl')
    $candidates.Add('C:\Program Files\Epic Games\SpeedBrawl')
    $candidates.Add('C:\Program Files (x86)\Epic Games\SpeedBrawl')
    $candidates.Add('D:\EpicGames\SpeedBrawl')
    $candidates.Add('D:\Games\SpeedBrawl')
    $candidates.Add((Get-Location).Path)

    foreach ($candidate in $candidates) {
        if (Test-GameFolder $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    return $null
}

Write-Host ''
Write-Host ('  ' + $trainerName + ' v' + $trainerVersion) -ForegroundColor White
Write-Host '  Portable installer (BepInEx 5.4.23.6 x64 + trainer plugin)' -ForegroundColor Gray
Write-Host ''

if (-not (Test-Path -LiteralPath $payloadDir -PathType Container)) {
    throw 'Payload folder is missing. Extract the whole portable folder, not only this script.'
}

Write-Step 'Locating SpeedBrawl installation'
$resolvedGamePath = Find-GameFolder
if (-not $resolvedGamePath) {
    throw 'SpeedBrawl was not found. Run: Install-Trainer.bat -GamePath "D:\Path\To\SpeedBrawl"'
}
Write-Ok ('Game folder: ' + $resolvedGamePath)

Write-Step 'Checking game build'
$lunaPath = Join-Path $resolvedGamePath 'SpeedBrawl_Data\Managed\DS.Game.Luna.dll'
$lunaHash = (Get-FileHash -LiteralPath $lunaPath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($lunaHash -ne $expectedLunaSha256) {
    Write-Warn ('DS.Game.Luna.dll hash: ' + $lunaHash)
    Write-Warn ('Expected hash:          ' + $expectedLunaSha256)
    if (-not $Force) {
        throw 'This is a different SpeedBrawl build. The trainer may fail to patch. Re-run with -Force if you want to try anyway.'
    }
    Write-Warn 'Continuing because -Force was supplied.'
}
else {
    Write-Ok 'Game build matches the tested build.'
}

$existingBepInEx = Test-Path -LiteralPath (Join-Path $resolvedGamePath 'BepInEx\core\BepInEx.dll') -PathType Leaf
$backupDir = Join-Path $resolvedGamePath ('_TrainerBackup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$backupItems = @()

if (-not $existingBepInEx) {
    Write-Step 'Backing up loader files if present'
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $possible = @('winhttp.dll', 'doorstop_config.ini', '.doorstop_version', 'BepInEx')
    foreach ($item in $possible) {
        $source = Join-Path $resolvedGamePath $item
        if (Test-Path -LiteralPath $source) {
            $target = Join-Path $backupDir $item
            Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
            $backupItems += $item
            Write-Ok ('Backed up ' + $item)
        }
    }
    if ($backupItems.Count -eq 0) {
        Remove-Item -LiteralPath $backupDir -Recurse -Force
        $backupDir = ''
    }
}
else {
    Write-Warn 'BepInEx is already installed. Keeping the existing loader and installing only the trainer plugin.'
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $doorstop = Join-Path $resolvedGamePath 'doorstop_config.ini'
    if (Test-Path -LiteralPath $doorstop -PathType Leaf) {
        $doorstopBackup = Join-Path $backupDir 'doorstop_config.ini'
        Copy-Item -LiteralPath $doorstop -Destination $doorstopBackup -Force
        if (-not ($backupItems -contains 'doorstop_config.ini')) { $backupItems += 'doorstop_config.ini' }
        $doorstopText = Get-Content -LiteralPath $doorstop -Raw
        if ($doorstopText -match 'ignore_disable_switch\s*=\s*false') {
            $doorstopText = $doorstopText -replace 'ignore_disable_switch\s*=\s*false', 'ignore_disable_switch = true'
            Set-Content -LiteralPath $doorstop -Value $doorstopText -Encoding ASCII
            Write-Ok 'Enabled Doorstop even when Epic sets DOORSTOP_DISABLE.'
        }
    }
    if ($backupItems.Count -eq 0) {
        Remove-Item -LiteralPath $backupDir -Recurse -Force
        $backupDir = ''
    }
}

Write-Step 'Installing loader'
if (-not $existingBepInEx) {
    Copy-Item -LiteralPath (Join-Path $payloadDir 'winhttp.dll') -Destination (Join-Path $resolvedGamePath 'winhttp.dll') -Force
    Copy-Item -LiteralPath (Join-Path $payloadDir 'doorstop_config.ini') -Destination (Join-Path $resolvedGamePath 'doorstop_config.ini') -Force
    Copy-Item -LiteralPath (Join-Path $payloadDir '.doorstop_version') -Destination (Join-Path $resolvedGamePath '.doorstop_version') -Force
    Copy-Item -LiteralPath (Join-Path $payloadDir 'BepInEx') -Destination $resolvedGamePath -Recurse -Force
    Write-Ok 'BepInEx 5.4.23.6 x64 copied.'
}
else {
    Write-Ok 'Existing BepInEx kept.'
}

Write-Step 'Installing trainer plugin'
$pluginsDir = Join-Path $resolvedGamePath 'BepInEx\plugins'
New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null
Copy-Item -LiteralPath (Join-Path $payloadDir 'BepInEx\plugins\SpeedBrawlTrainer.dll') -Destination (Join-Path $resolvedGamePath $pluginRelative) -Force
$installedPlugin = Join-Path $resolvedGamePath $pluginRelative
$installedHash = (Get-FileHash -LiteralPath $installedPlugin -Algorithm SHA256).Hash.ToUpperInvariant()
$payloadHash = (Get-FileHash -LiteralPath (Join-Path $payloadDir 'BepInEx\plugins\SpeedBrawlTrainer.dll') -Algorithm SHA256).Hash.ToUpperInvariant()
if ($installedHash -ne $payloadHash) {
    throw 'Plugin copy verification failed. The destination file does not match the payload.'
}
Write-Ok ('Plugin installed: ' + $pluginRelative)

$manifest = [ordered]@{
    trainer = $trainerName
    version = $trainerVersion
    installedAt = (Get-Date).ToString('o')
    gamePath = $resolvedGamePath
    gameLunaSha256 = $lunaHash
    bepinexInstalledByTrainer = (-not $existingBepInEx)
    backupDir = $backupDir
    backupItems = $backupItems
    pluginSha256 = $installedHash
    loader = 'BepInEx 5.4.23.6 x64'
}
$manifestPath = Join-Path $resolvedGamePath $manifestRelative
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host ''
Write-Host '  Installation complete.' -ForegroundColor Green
Write-Host ('  Game:    ' + $resolvedGamePath)
if ($backupDir) { Write-Host ('  Backup:  ' + $backupDir) }
Write-Host '  Launch SpeedBrawl, then press Insert to show/hide the trainer menu.'
Write-Host '  Use F1..F11 for features. Single-player/offline use only.'
Write-Host ''



