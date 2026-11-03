param(
    [string]$GamePath = 'E:\EpicGames\SpeedBrawl',
    [string]$BepInExCore = ''
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$managed = Join-Path $GamePath 'SpeedBrawl_Data\Managed'

if (-not $BepInExCore) {
    $candidates = @(
        (Join-Path $here '..\payload\BepInEx\core'),
        (Join-Path $GamePath 'BepInEx\core')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $c 'BepInEx.dll')) { $BepInExCore = (Resolve-Path -LiteralPath $c).Path; break }
    }
}
if (-not $BepInExCore) { throw 'BepInEx core folder not found. Pass -BepInExCore <path>.' }

$cscCandidates = @(
    'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe',
    'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) { throw 'csc.exe not found. Install .NET Framework 4.x or use Visual Studio/MSBuild.' }

$out = Join-Path $here 'SpeedBrawlTrainer.dll'
$refs = @(
    (Join-Path $BepInExCore 'BepInEx.dll'),
    (Join-Path $BepInExCore '0Harmony.dll'),
    (Join-Path $managed 'UnityEngine.dll'),
    (Join-Path $managed 'UnityEngine.CoreModule.dll'),
    (Join-Path $managed 'UnityEngine.IMGUIModule.dll'),
    (Join-Path $managed 'UnityEngine.InputLegacyModule.dll'),
    (Join-Path $managed 'UnityEngine.Networking.dll'),
    (Join-Path $managed 'DS.Game.Luna.dll'),
    (Join-Path $managed 'DS.Game.Util.dll'),
    (Join-Path $managed 'DS.Game.Networking.dll')
)

$args = @('/nologo', '/target:library', '/optimize+', ('/out:' + $out))
foreach ($r in $refs) { $args += ('/reference:' + $r) }
$args += (Join-Path $here 'SpeedBrawlTrainer.cs')

& $csc $args
if ($LASTEXITCODE -ne 0) { throw ('Build failed with exit code ' + $LASTEXITCODE) }
Write-Host ('Built: ' + $out) -ForegroundColor Green
