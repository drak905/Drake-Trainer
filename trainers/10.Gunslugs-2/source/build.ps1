#Requires -Version 5.1
<#
.SYNOPSIS
    Rebuilds gunslugs2-trainer.jar from source against Gunslugs 2's Gunslugs2.jar.

.PARAMETER GameDir
    Path to the Gunslugs 2 game directory containing Gunslugs2.jar.
    Defaults to auto-detecting E:\GOGGalaxy\Gunslugs2 or standard GOG locations.
#>
[CmdletBinding()]
param(
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir

if ([string]::IsNullOrWhiteSpace($GameDir)) {
    foreach ($cand in @("E:\GOGGalaxy\Gunslugs2", "C:\GOG Games\Gunslugs 2", "C:\GOG Games\Gunslugs2", "D:\GOG Games\Gunslugs 2", "E:\GOG Games\Gunslugs 2")) {
        if (Test-Path (Join-Path $cand "Gunslugs2.jar")) {
            $GameDir = $cand
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GameDir) -or -not (Test-Path (Join-Path $GameDir "Gunslugs2.jar"))) {
    throw "Could not find Gunslugs2.jar. Pass -GameDir '<path to Gunslugs2>'."
}

$DataArchive = Join-Path $GameDir "Gunslugs2.jar"
$BuildDir    = Join-Path $ScriptDir "build"
$OutJar      = Join-Path $RootDir "payload\gunslugs2-trainer.jar"

if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

$JavaSources = @(
    (Join-Path $ScriptDir "com\orangepixel\gunslugs2\Trainer.java"),
    (Join-Path $ScriptDir "com\orangepixel\gunslugs2\Player.java"),
    (Join-Path $ScriptDir "com\orangepixel\utils\ArcadeCanvas.java")
)

Write-Host "[*] Compiling trainer classes (Java 8 bytecode)..." -ForegroundColor Cyan
& javac --release 8 -implicit:none -cp $DataArchive -d $BuildDir @JavaSources
if ($LASTEXITCODE -ne 0) {
    throw "javac failed with exit code $LASTEXITCODE"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $OutJar) -Force | Out-Null
if (Test-Path $OutJar) {
    Remove-Item $OutJar -Force
}

Write-Host "[*] Packaging $OutJar ..." -ForegroundColor Cyan
& jar cf $OutJar -C $BuildDir .
if ($LASTEXITCODE -ne 0) {
    throw "jar failed with exit code $LASTEXITCODE"
}

Remove-Item $BuildDir -Recurse -Force
$Hash = (Get-FileHash $OutJar -Algorithm SHA256).Hash.ToLower()
Write-Host "[+] Built $OutJar (SHA-256: $Hash)" -ForegroundColor Green
