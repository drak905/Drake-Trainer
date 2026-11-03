# Builds a BepInEx plugin for Bo with the .NET Framework C# compiler (no SDK needed).
# Usage: .\build.ps1 -Src src\BoVietnamese.cs -Name BoVietnamese
param(
    [Parameter(Mandatory=$true)][string]$Src,
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$Game = "E:\GOGGalaxy\B$([char]0x014D) Path of the Teal Lotus",
    [string]$Bep  = "",
    [string]$Resource = "",
    [string]$Out  = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Bep) { $Bep = Join-Path $root "..\tools\bepinex\pkg\BepInEx\core" }
if (-not $Out) { $Out = Join-Path $root "out" }
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$m = Join-Path $Game "Bo_Data\Managed"
New-Item -ItemType Directory -Force $Out | Out-Null
$refs = Get-ChildItem $m -Filter *.dll | Where-Object {
    $_.Name -in @("mscorlib.dll","netstandard.dll","System.dll","System.Core.dll","Assembly-CSharp.dll","Assembly-CSharp-firstpass.dll","DialogueSystem.dll","PixelCrushers.dll") -or
    $_.Name -like "UnityEngine*.dll" -or $_.Name -like "Unity.*.dll"
} | ForEach-Object { "/r:" + $_.FullName }
$refs += "/r:" + (Join-Path $Bep "BepInEx.dll")
$refs += "/r:" + (Join-Path $Bep "0Harmony.dll")
$rsp = Join-Path $Out "$Name.rsp"
$srcPath = (Resolve-Path $Src).Path
$args2 = @("/nologo","/nostdlib+","/target:library","/optimize+","/debug-","/warn:4","/langversion:5","/out:$Out\$Name.dll") + ($refs | ForEach-Object { '"' + $_ + '"' }) + $(if ($Resource) { @("/resource:" + '"' + (Resolve-Path $Resource.Split(',')[0]).Path + '"' + "," + $Resource.Split(',')[1]) } else { @() }) + @('"' + $srcPath + '"')
$args2 | Set-Content $rsp -Encoding UTF8
$log = & cmd /c "`"$csc`" /noconfig /utf8output @`"$rsp`" 2>&1"
$log | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Write-Host "Built $Out\$Name.dll"
