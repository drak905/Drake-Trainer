#Requires -Version 5.1
<#
.SYNOPSIS
    Rebuilds gunslugs-trainer.jar from source against Gunslugs' gunslugs.dat.

.PARAMETER GameDir
    Path to the Gunslugs game directory containing gunslugs.dat.
    Defaults to auto-detecting E:\GOGGalaxy\Gunslugs or standard GOG locations.
#>
[CmdletBinding()]
param(
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir

if ([string]::IsNullOrWhiteSpace($GameDir)) {
    foreach ($cand in @("E:\GOGGalaxy\Gunslugs", "C:\GOG Games\Gunslugs", "D:\GOG Games\Gunslugs", "E:\GOG Games\Gunslugs")) {
        if (Test-Path (Join-Path $cand "gunslugs.dat")) {
            $GameDir = $cand
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GameDir) -or -not (Test-Path (Join-Path $GameDir "gunslugs.dat"))) {
    throw "Could not find gunslugs.dat. Pass -GameDir '<path to Gunslugs>'."
}

$DataArchive = Join-Path $GameDir "gunslugs.dat"
$BuildDir    = Join-Path $ScriptDir "build"
$OutJar      = Join-Path $RootDir "payload\gunslugs-trainer.jar"

if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

$JavaSources = @(
    (Join-Path $ScriptDir "com\orangepixel\gunslugs\Trainer.java"),
    (Join-Path $ScriptDir "com\orangepixel\gunslugs\Player.java"),
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
