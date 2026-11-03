$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcDir      = Join-Path $ProjectRoot "src"
$BuildDir    = Join-Path $ProjectRoot "build\classes"
$OutJar      = Join-Path $ProjectRoot "gunslugs3-trainer.jar"

$GameDir     = if ($env:GUNSLUGS3_DIR) { $env:GUNSLUGS3_DIR } else { "E:\GOGGalaxy\Gunslugs3RogueTactics" }
$GameDat     = Join-Path $GameDir "gunslugs3.dat"

$JavacExe    = "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot\bin\javac.exe"
$JarExe      = "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot\bin\jar.exe"

if (-not (Test-Path $JavacExe)) {
    $JavacCmd = Get-Command javac -ErrorAction SilentlyContinue
    if ($JavacCmd) { $JavacExe = $JavacCmd.Source }
}
if (-not (Test-Path $JarExe)) {
    $JarCmd = Get-Command jar -ErrorAction SilentlyContinue
    if ($JarCmd) { $JarExe = $JarCmd.Source }
}

if (-not (Test-Path $GameDat)) {
    throw "Could not find gunslugs3.dat at $GameDat"
}

if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$JavaFiles = Get-ChildItem -Path $SrcDir -Recurse -Filter "*.java" | Select-Object -ExpandProperty FullName
Write-Host "[Build] Compiling $($JavaFiles.Count) Java source files (--release 8 -> Java 7 major version 51)..."
& $JavacExe --release 8 -encoding UTF-8 -cp $GameDat -d $BuildDir $JavaFiles
if ($LASTEXITCODE -ne 0) {
    throw "javac compilation failed with exit code $LASTEXITCODE"
}

Get-ChildItem -Path $BuildDir -Recurse -Filter "*.class" | ForEach-Object {
    $b = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($b.Length -ge 8 -and $b[6] -eq 0 -and $b[7] -eq 52) {
        $b[7] = 51
        [System.IO.File]::WriteAllBytes($_.FullName, $b)
    }
}

if (Test-Path $OutJar) {
    Remove-Item -Force $OutJar
}
Write-Host "[Build] Packaging $OutJar..."
& $JarExe cf $OutJar -C $BuildDir .
if ($LASTEXITCODE -ne 0) {
    throw "jar packaging failed with exit code $LASTEXITCODE"
}

$Hash = (Get-FileHash -Path $OutJar -Algorithm SHA256).Hash
Write-Host "[Build] Success! gunslugs3-trainer.jar SHA256: $Hash"
