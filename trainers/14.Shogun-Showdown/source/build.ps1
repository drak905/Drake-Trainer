# Builds ShogunTrainer.dll with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 -Game "E:\EpicGames\ShogunShowdown611f6" [-Bep "<path to BepInEx core folder>"] [-Out "<output folder>"]
param(
    [string]$Game = "E:\EpicGames\ShogunShowdown611f6",
    [string]$Bep  = (Join-Path $PSScriptRoot "..\payload\BepInEx\core"),
    [string]$Out  = (Join-Path $PSScriptRoot "out")
)
$ErrorActionPreference = "Stop"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "ShogunShowdown_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$refs = @(
  "mscorlib.dll","netstandard.dll","System.dll","System.Core.dll",
  "Assembly-CSharp.dll","Unity.InputSystem.dll","Unity.TextMeshPro.dll","UnityEngine.UI.dll","Unity.Localization.dll",
  "UnityEngine.dll","UnityEngine.CoreModule.dll","UnityEngine.IMGUIModule.dll","UnityEngine.InputLegacyModule.dll",
  "UnityEngine.AnimationModule.dll","UnityEngine.AudioModule.dll","UnityEngine.UIModule.dll","UnityEngine.TextRenderingModule.dll",
  "UnityEngine.Physics2DModule.dll","UnityEngine.PhysicsModule.dll","UnityEngine.ParticleSystemModule.dll","UnityEngine.SpriteMaskModule.dll",
  "UnityEngine.LocalizationModule.dll"
) | ForEach-Object { Join-Path $m $_ } | Where-Object { Test-Path $_ } | ForEach-Object { "/r:" + $_ }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
& $csc /nologo /noconfig /nostdlib+ /target:library /optimize+ /debug- /warn:4 /langversion:5 "/out:$Out\ShogunTrainer.dll" @refs (Join-Path $PSScriptRoot "src\ShogunTrainer.cs")
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\ShogunTrainer.dll"
