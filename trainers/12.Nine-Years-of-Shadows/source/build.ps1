# Builds NysTrainer.dll with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 -Game "E:\GOGGalaxy\9 Years of Shadows" [-Bep "<path to BepInEx core folder>"]
param(
    [string]$Game = "E:\GOGGalaxy\9 Years of Shadows",
    [string]$Bep  = (Join-Path $PSScriptRoot "..\tools\bepinex\pkg\BepInEx\core"),
    [string]$Out  = (Join-Path $PSScriptRoot "out")
)
$ErrorActionPreference = "Stop"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "9 Years of Shadows_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$refs = @(
  "mscorlib.dll","netstandard.dll","System.dll","System.Core.dll",
  "Assembly-CSharp.dll","Assembly-CSharp-firstpass.dll","Unity.InputSystem.dll","Unity.TextMeshPro.dll",
  "UnityEngine.dll","UnityEngine.CoreModule.dll","UnityEngine.IMGUIModule.dll","UnityEngine.InputLegacyModule.dll",
  "UnityEngine.Physics2DModule.dll","UnityEngine.AnimationModule.dll","UnityEngine.UIModule.dll","UnityEngine.UI.dll",
  "UnityEngine.AudioModule.dll","UnityEngine.ParticleSystemModule.dll","UnityEngine.TextRenderingModule.dll",
  "UnityEngine.SpriteShapeModule.dll","UnityEngine.TilemapModule.dll","UnityEngine.ImageConversionModule.dll",
  "UnityEngine.JSONSerializeModule.dll","UnityEngine.PhysicsModule.dll","UnityEngine.SubsystemsModule.dll",
  "UnityEngine.AIModule.dll","UnityEngine.UnityWebRequestModule.dll","UnityEngine.VideoModule.dll",
  "DOTween.dll","FMODUnity.dll","spine-unity.dll","spine-csharp.dll","UniTask.dll","YarnSpinner.dll","YarnSpinner.Unity.dll",
  "Unity.Addressables.dll","Unity.ResourceManager.dll","Unity.RenderPipelines.Core.Runtime.dll","Unity.RenderPipelines.Universal.Runtime.dll",
  "LDtkUnity.Runtime.dll","Unity.Postprocessing.Runtime.dll","Unity.Mathematics.dll","Unity.Burst.dll","Unity.AI.Navigation.dll"
) | Where-Object { Test-Path (Join-Path $m $_) } | ForEach-Object { "/r:" + (Join-Path $m $_) }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
$rsp = Join-Path $Out "build.rsp"
$args2 = @("/nologo","/nostdlib+","/target:library","/optimize+","/debug-","/warn:4","/langversion:5","/out:$Out\NysTrainer.dll","/resource:$(Join-Path $PSScriptRoot 'data\items.tsv'),NysTrainer.items.tsv") + ($refs | ForEach-Object { '"' + $_ + '"' }) + @('"' + (Join-Path $PSScriptRoot "src\NysTrainer.cs") + '"')
$args2 | Set-Content $rsp -Encoding ASCII
$log = & cmd /c "`"$csc`" /noconfig @`"$rsp`" 2>&1"
$log | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\NysTrainer.dll"

