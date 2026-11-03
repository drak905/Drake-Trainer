[CmdletBinding()]
param(
    [string]$GamePath = ''
)

$ErrorActionPreference = 'Stop'

$trainerName = 'SpeedBrawl In-Game Trainer'
$pluginRelative = 'BepInEx\plugins\SpeedBrawlTrainer.dll'
$manifestRelative = 'BepInEx\plugins\SpeedBrawlTrainer.install.json'

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
    return (Test-Path -LiteralPath (Join-Path $Path 'SpeedBrawl.exe') -PathType Leaf)
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
        if (Test-GameFolder $candidate) {
            $full = (Resolve-Path -LiteralPath $candidate).Path
            if (Test-Path -LiteralPath (Join-Path $full $manifestRelative) -PathType Leaf) { return $full }
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-GameFolder $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    return $null
}

Write-Host ''
Write-Host ('  ' + $trainerName + ' - Uninstall') -ForegroundColor White
Write-Host ''

Write-Step 'Locating SpeedBrawl installation'
$resolvedGamePath = Find-GameFolder
if (-not $resolvedGamePath) {
    throw 'SpeedBrawl was not found. Run: Uninstall-Trainer.bat -GamePath "D:\Path\To\SpeedBrawl"'
}
Write-Ok ('Game folder: ' + $resolvedGamePath)

$manifestPath = Join-Path $resolvedGamePath $manifestRelative
$manifest = $null
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warn 'Install manifest is unreadable; falling back to default removal.'
    }
}

$pluginPath = Join-Path $resolvedGamePath $pluginRelative
if (Test-Path -LiteralPath $pluginPath -PathType Leaf) {
    Remove-Item -LiteralPath $pluginPath -Force
    Write-Ok 'Trainer plugin removed.'
}
else {
    Write-Ok 'Trainer plugin was not present.'
}

if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    Remove-Item -LiteralPath $manifestPath -Force
}

$restored = $false
if ($manifest -and $manifest.backupDir -and (Test-Path -LiteralPath $manifest.backupDir -PathType Container)) {
    Write-Step 'Restoring files backed up during installation'
    foreach ($item in @($manifest.backupItems)) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        $source = Join-Path $manifest.backupDir $item
        if (-not (Test-Path -LiteralPath $source)) { continue }
        if ($item -eq 'SpeedBrawlTrainer.dll') {
            $target = Join-Path $resolvedGamePath $pluginRelative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        else {
            Copy-Item -LiteralPath $source -Destination $resolvedGamePath -Recurse -Force
        }
        Write-Ok ('Restored ' + $item)
        $restored = $true
    }
    Remove-Item -LiteralPath $manifest.backupDir -Recurse -Force
    Write-Ok 'Backup folder removed.'
}

if ($manifest -and $manifest.bepinexInstalledByTrainer) {
    Write-Step 'Checking whether BepInEx is used by other mods'
    $pluginsDir = Join-Path $resolvedGamePath 'BepInEx\plugins'
    $otherPlugins = @()
    if (Test-Path -LiteralPath $pluginsDir -PathType Container) {
        $otherPlugins = @(Get-ChildItem -LiteralPath $pluginsDir -Filter '*.dll' -File -ErrorAction SilentlyContinue)
    }
    if ($otherPlugins.Count -gt 0) {
        Write-Warn 'Other BepInEx plugins are installed. Keeping BepInEx and its loader files.'
    }
    else {
        $backedItems = @()
        if ($manifest.backupItems) { $backedItems = @($manifest.backupItems) }
        foreach ($item in @('BepInEx', 'winhttp.dll', 'doorstop_config.ini', '.doorstop_version')) {
            if ($backedItems -contains $item) { continue }
            $path = Join-Path $resolvedGamePath $item
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
                Write-Ok ('Removed ' + $item)
            }
        }
    }
}

Write-Host ''
Write-Host '  Uninstall complete.' -ForegroundColor Green
Write-Host '  Launch the game normally. No trainer files should remain.'
Write-Host ''

