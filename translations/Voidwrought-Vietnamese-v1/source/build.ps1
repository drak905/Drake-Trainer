# Builds a BepInEx plugin for Voidwrought with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 -Src src\VwVietnamese.cs -Name VwVietnamese [-Resource src\vi.tsv,vi.tsv]
param(
    [Parameter(Mandatory=$true)][string]$Src,
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$Game = "E:\EpicGames\VoidwroughtFq9Qv",
    [string]$Bep  = "",
    [string]$Resource = "",
    [string]$Out  = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Bep) { $Bep = Join-Path $root "..\tools\bepinex\pkg\BepInEx\core" }
if (-not $Out) { $Out = Join-Path $root "out" }
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "Voidwrought_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$want = @("mscorlib.dll","netstandard.dll","System.dll","System.Core.dll","Assembly-CSharp.dll","Assembly-CSharp-firstpass.dll","PlayMaker.dll","Unity.TextMeshPro.dll","Newtonsoft.Json.dll","DOTween.dll","Rewired_Core.dll")
$refs = Get-ChildItem $m -Filter *.dll | Where-Object {
    $_.Name -in $want -or $_.Name -like "UnityEngine*.dll" -or $_.Name -in @("Unity.Addressables.dll","Unity.ResourceManager.dll")
} | ForEach-Object { "/r:" + $_.FullName }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
$rsp = Join-Path $Out "$Name.rsp"
$srcPath = (Resolve-Path $Src).Path
$resArg = @()
if ($Resource) { $p = $Resource.Split(','); $resArg = @("/resource:" + '"' + (Resolve-Path $p[0]).Path + '"' + "," + $p[1]) }
$args2 = @("/nologo","/nostdlib+","/target:library","/optimize+","/debug-","/warn:4","/langversion:5","/out:$Out\$Name.dll") + ($refs | ForEach-Object { '"' + $_ + '"' }) + $resArg + @('"' + $srcPath + '"')
$args2 | Set-Content $rsp -Encoding UTF8
$log = & cmd /c "`"$csc`" /noconfig /utf8output @`"$rsp`" 2>&1"
$log | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\$Name.dll"
