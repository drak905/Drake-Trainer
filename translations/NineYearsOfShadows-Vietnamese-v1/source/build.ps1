# Builds a BepInEx plugin for 9 Years of Shadows with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 -Src src\NysVietnamese.cs -Name NysVietnamese [-Resource "data\vi.tsv,vi.tsv"] [-Out out]
param(
    [Parameter(Mandatory=$true)][string]$Src,
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$Game = "E:\GOGGalaxy\9 Years of Shadows",
    [string]$Bep  = "",
    [string]$Resource = "",
    [string]$Out  = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Bep) { $Bep = Join-Path $root "..\tools\bepinex\pkg\BepInEx\core" }
if (-not $Out) { $Out = Join-Path $root "out" }
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "9 Years of Shadows_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$want = @("mscorlib.dll","netstandard.dll","System.dll","System.Core.dll","Assembly-CSharp.dll","Assembly-CSharp-firstpass.dll","Unity.InputSystem.dll","Unity.TextMeshPro.dll",
  "UnityEngine.dll","UnityEngine.CoreModule.dll","UnityEngine.IMGUIModule.dll","UnityEngine.InputLegacyModule.dll","UnityEngine.UIModule.dll","UnityEngine.UI.dll",
  "UnityEngine.TextRenderingModule.dll","UnityEngine.TextCoreFontEngineModule.dll","UnityEngine.TextCoreTextEngineModule.dll","UnityEngine.ImageConversionModule.dll","UnityEngine.JSONSerializeModule.dll",
  "UnityEngine.SubsystemsModule.dll","YarnSpinner.dll","YarnSpinner.Unity.dll","CsvHelper.dll","Unity.Addressables.dll","Unity.ResourceManager.dll")
$refs = $want | Where-Object { Test-Path (Join-Path $m $_) } | ForEach-Object { "/r:" + (Join-Path $m $_) }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
$rsp = Join-Path $Out "$Name.rsp"
$srcPath = (Resolve-Path $Src).Path
$res = @()
if ($Resource) { foreach ($r in ($Resource -split ';')) { $p = $r.Split(','); $res += ("/resource:" + '"' + (Resolve-Path $p[0]).Path + '"' + "," + $p[1]) } }
$args2 = @("/nologo","/codepage:65001","/nostdlib+","/target:library","/optimize+","/debug-","/warn:4","/langversion:5","/out:$Out\$Name.dll") + ($refs | ForEach-Object { '"' + $_ + '"' }) + $res + @('"' + $srcPath + '"')
$args2 | Set-Content $rsp -Encoding UTF8
$log = & cmd /c "`"$csc`" /noconfig /utf8output @`"$rsp`" 2>&1"
$log | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\$Name.dll"

