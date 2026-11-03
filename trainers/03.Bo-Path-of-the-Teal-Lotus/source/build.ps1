# Builds BoTrainer.dll with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 [-Game "E:\GOGGalaxy\Bō Path of the Teal Lotus"] [-Bep "<path to BepInEx core folder>"]
param(
    [string]$Game = "E:\GOGGalaxy\B$([char]0x014D) Path of the Teal Lotus",
    [string]$Bep  = (Join-Path $PSScriptRoot "..\tools\bepinex\pkg\BepInEx\core"),
    [string]$Out  = (Join-Path $PSScriptRoot "out")
)
$ErrorActionPreference = "Stop"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "Bo_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
# Unity + game assemblies (System.* facades are not needed: netstandard.dll + mscorlib.dll cover them)
$refs = Get-ChildItem $m -Filter *.dll | Where-Object {
    $_.Name -in @("mscorlib.dll","netstandard.dll","System.dll","System.Core.dll","Assembly-CSharp.dll","Assembly-CSharp-firstpass.dll") -or
    $_.Name -like "UnityEngine*.dll" -or $_.Name -like "Unity.*.dll" -or
    $_.Name -in @("FMODUnity.dll","DOTween.dll","PlayMaker.dll","PixelCrushers.dll","DialogueSystem.dll","InputIcons.dll","ParticleImage.dll","Cinemachine.dll","AstarPathfindingProject.dll","DOTween.dll")
} | ForEach-Object { "/r:" + $_.FullName }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
$rsp = Join-Path $Out "build.rsp"
$args2 = @("/nologo","/nostdlib+","/target:library","/optimize+","/debug-","/warn:4","/langversion:5","/out:$Out\BoTrainer.dll") + ($refs | ForEach-Object { '"' + $_ + '"' }) + (Get-ChildItem $(if (Test-Path (Join-Path $PSScriptRoot "src")) { Join-Path $PSScriptRoot "src" } else { $PSScriptRoot }) -Filter *.cs | ForEach-Object { '"' + $_.FullName + '"' })
$args2 | Set-Content $rsp -Encoding UTF8
$log = & cmd /c "`"$csc`" /noconfig @`"$rsp`" 2>&1"
$log | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\BoTrainer.dll"

