# Builds OguTrainer.dll with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 -Game "E:\EpicGames\OguandtheSecretFores6K1u7" [-Bep "<path to BepInEx core folder>"]
param(
    [string]$Game = "E:\EpicGames\OguandtheSecretFores6K1u7",
    [string]$Bep  = (Join-Path $PSScriptRoot "..\tools\bepinex\pkg\BepInEx\core"),
    [string]$Out  = (Join-Path $PSScriptRoot "out")
)
$ErrorActionPreference = "Stop"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "OguForest_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$refs = @(
  "mscorlib.dll","netstandard.dll","System.dll","System.Core.dll",
  "Assembly-CSharp.dll","Unity.InputSystem.dll",
  "UnityEngine.dll","UnityEngine.CoreModule.dll","UnityEngine.IMGUIModule.dll","UnityEngine.InputLegacyModule.dll"
) | ForEach-Object { "/r:" + (Join-Path $m $_) }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
& $csc /nologo /noconfig /nostdlib+ /target:library /optimize+ /debug- /warn:4 /langversion:5 "/out:$Out\OguTrainer.dll" @refs (Join-Path $PSScriptRoot "src\OguTrainer.cs")
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\OguTrainer.dll"
