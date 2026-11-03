# Builds VwTrainer.dll with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 [-Game "E:\EpicGames\VoidwroughtFq9Qv"] [-Bep "<path to BepInEx core folder>"]
param(
    [string]$Game = "E:\EpicGames\VoidwroughtFq9Qv",
    [string]$Bep  = (Join-Path $PSScriptRoot "..\tools\bepinex\pkg\BepInEx\core"),
    [string]$Out  = (Join-Path $PSScriptRoot "out")
)
$ErrorActionPreference = "Stop"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "Voidwrought_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$refs = @(
  "mscorlib.dll","netstandard.dll","System.dll","System.Core.dll",
  "Assembly-CSharp.dll","PlayMaker.dll","Unity.TextMeshPro.dll","Unity.Addressables.dll","Unity.ResourceManager.dll",
  "Rewired_Core.dll","DOTween.dll","Sirenix.Utilities.dll","Sirenix.Serialization.dll","Sirenix.OdinInspector.Attributes.dll",
  "Cinemachine.dll","Newtonsoft.Json.dll","Unity.Mathematics.dll",
  "UnityEngine.dll","UnityEngine.CoreModule.dll","UnityEngine.IMGUIModule.dll","UnityEngine.InputLegacyModule.dll",
  "UnityEngine.Physics2DModule.dll","UnityEngine.TilemapModule.dll","UnityEngine.UI.dll","UnityEngine.UIModule.dll",
  "UnityEngine.TextRenderingModule.dll","UnityEngine.AudioModule.dll","UnityEngine.AnimationModule.dll",
  "UnityEngine.ParticleSystemModule.dll","UnityEngine.JSONSerializeModule.dll","UnityEngine.SpriteShapeModule.dll","Unity.2D.SpriteShape.Runtime.dll"
) | ForEach-Object { "/r:" + (Join-Path $m $_) }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
& $csc /nologo /noconfig /nostdlib+ /target:library /optimize+ /debug- /warn:4 /langversion:5 "/out:$Out\VwTrainer.dll" @refs (Join-Path $PSScriptRoot "src\VwTrainer.cs")
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\VwTrainer.dll"
