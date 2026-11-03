# Ghost Song - Trainer v2.0 installer (version.dll proxy + in-game Dear ImGui menu).
# Safe to re-run; also upgrades a v1.0 trainer.  Touches exactly one game file: version.dll.
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"

# The game build this trainer was verified against (GameAssembly.dll SHA256).
$SupportedGameAssembly = "43A0C1218FFD9B30487EC4FA96ADF8F896E8313CE7EC868671CE1085AFD66246"
$GameId = "1305299338"

function Find-Game {
    foreach ($root in @("HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games", "HKLM:\SOFTWARE\GOG.com\Games")) {
        $k = Join-Path $root $GameId
        if (Test-Path $k) {
            $p = (Get-ItemProperty $k -ErrorAction SilentlyContinue).path
            if ($p -and (Test-Path (Join-Path $p "GhostSong.exe"))) { return $p }
        }
    }
    try {
        $p = (Get-ItemProperty "HKCU:\Software\GOG.com\Games\$GameId" -ErrorAction Stop).path
        if ($p -and (Test-Path (Join-Path $p "GhostSong.exe"))) { return $p }
    } catch {}
    # Steam libraries
    foreach ($sk in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam")) {
        try {
            $steam = (Get-ItemProperty $sk -ErrorAction Stop)
            $root = if ($steam.SteamPath) { $steam.SteamPath } else { $steam.InstallPath }
            if ($root) {
                $cands = @((Join-Path $root "steamapps\common\Ghost Song"))
                $vdf = Join-Path $root "steamapps\libraryfolders.vdf"
                if (Test-Path $vdf) {
                    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                        $cands += (Join-Path ($m.Groups[1].Value -replace '\\\\', '\') "steamapps\common\Ghost Song")
                    }
                }
                foreach ($c in $cands) { if (Test-Path (Join-Path $c "GhostSong.exe")) { return $c } }
            }
        } catch {}
    }
    # common folders on every fixed drive
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        foreach ($rel in @("GOGGalaxy\Ghost Song", "GOG Games\Ghost Song", "Games\Ghost Song", "Program Files (x86)\GOG Galaxy\Games\Ghost Song",
                           "Program Files\GOG Galaxy\Games\Ghost Song", "SteamLibrary\steamapps\common\Ghost Song",
                           "Program Files (x86)\Steam\steamapps\common\Ghost Song")) {
            $p = Join-Path $d.Root $rel
            if (Test-Path (Join-Path $p "GhostSong.exe")) { return $p }
        }
    }
    return ""
}

# true when the file is one of OUR trainer dlls (v1.0 or v2.x) - never mistaken for a foreign proxy
function Test-OurDll([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
    return $text.Contains("Ghost Song trainer start")
}

if (-not $GameDir) { $GameDir = Find-Game }
if (-not $GameDir) {
    $GameDir = Read-Host "Ghost Song was not found automatically. Paste the folder that contains GhostSong.exe"
}
$GameDir = $GameDir.Trim('"').TrimEnd('\')

$exe = Join-Path $GameDir "GhostSong.exe"
$ga  = Join-Path $GameDir "GameAssembly.dll"
if (-not (Test-Path $exe)) { throw "GhostSong.exe not found in '$GameDir'." }
if (-not (Test-Path $ga))  { throw "GameAssembly.dll not found in '$GameDir' - this is not a Ghost Song install." }
if (Get-Process GhostSong -ErrorAction SilentlyContinue) { throw "Close the game first, then run the installer again." }

$hash = (Get-FileHash $ga -Algorithm SHA256).Hash
if ($hash -ne $SupportedGameAssembly) {
    Write-Warning "This GameAssembly.dll is not the build the trainer was verified against."
    Write-Warning "  expected $SupportedGameAssembly"
    Write-Warning "  found    $hash"
    Write-Warning "The menu still loads, but the hook-based features (speed x2, one-hit kill, per-frame tick) are skipped by the trainer's build guard."
}

$payload  = Join-Path $PSScriptRoot "payload"
$manifest = Join-Path $GameDir "GhostSongTrainer_install_manifest.txt"
$dst      = Join-Path $GameDir "version.dll"
$orig     = Join-Path $GameDir "version.dll.orig"

# 1) a version.dll.orig that is really an old copy of our own trainer must not survive (the uninstaller would "restore" it)
if ((Test-Path $orig) -and (Test-Path $orig) -and (Test-OurDll $orig)) {
    Remove-Item $orig -Force
    Write-Host "Removed a stale copy of an old trainer (version.dll.orig)."
}
# 2) a FOREIGN version.dll (another mod's proxy) is kept as version.dll.orig and restored on uninstall
if ((Test-Path $dst) -and -not (Test-OurDll $dst)) {
    if (-not (Test-Path $orig)) {
        Copy-Item $dst $orig -Force
        Write-Warning "A different version.dll was already in the game folder; it was saved as version.dll.orig and will be restored on uninstall."
        Write-Warning "Two version.dll proxies cannot run at the same time, so that other mod is disabled while this trainer is installed."
    }
}

$rel = @()
foreach ($f in Get-ChildItem $payload -Recurse -File -Force) {
    $r = $f.FullName.Substring($payload.Length + 1)
    $to = Join-Path $GameDir $r
    New-Item -ItemType Directory -Force (Split-Path -Parent $to) | Out-Null
    Copy-Item $f.FullName $to -Force
    $rel += $r
}
$rel | Set-Content $manifest

$ok = (Get-FileHash $dst -Algorithm SHA256).Hash -eq (Get-FileHash (Join-Path $payload "version.dll") -Algorithm SHA256).Hash
Write-Host "Installed $($rel.Count) file(s) into $GameDir  (hash check: $(if ($ok) {'OK'} else {'MISMATCH'}))"
Write-Host ""
Write-Host "Start the game normally (GOG Galaxy, Steam or GhostSong.exe)."
Write-Host "In the game press F10 (or Insert) to open the trainer menu - it is drawn inside the game window."
Write-Host "  F1 god mode      F2 add Spirit       F3 infinite Spirit  F4 unlimited jump"
Write-Host "  F5 speed x2      F6 one-hit kill     F7 heal              F8 infinite stamina"
Write-Host "  F9 show all on map   F10 menu   F11 give all items   F12 write diagnostics"
