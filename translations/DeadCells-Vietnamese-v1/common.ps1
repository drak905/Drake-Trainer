# Shared helpers for install.ps1 / uninstall.ps1 (Dead Cells Vietnamese patch).
# UTF-8 bytes of the language name added to the exe, and the file name inside our pak
$Marker = [byte[]](0x54,0x69,0xE1,0xBA,0xBF,0x6E,0x67,0x20,0x56,0x69,0xE1,0xBB,0x87,0x74)
$PakMarker = [Text.Encoding]::ASCII.GetBytes("main.vi.mo")

function Find-Game {
    $dat = "C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
    if (Test-Path $dat) {
        try {
            foreach ($e in (Get-Content $dat -Raw | ConvertFrom-Json).InstallationList) {
                if ($e.InstallLocation -and (Test-Path (Join-Path $e.InstallLocation "deadcells.exe"))) { return $e.InstallLocation }
            }
        } catch {}
    }
    foreach ($sk in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam")) {
        try {
            $s = Get-ItemProperty $sk -ErrorAction Stop
            $root = if ($s.SteamPath) { $s.SteamPath } else { $s.InstallPath }
            if ($root) {
                $cands = @(Join-Path $root "steamapps\common\Dead Cells")
                $vdf = Join-Path $root "steamapps\libraryfolders.vdf"
                if (Test-Path $vdf) {
                    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                        $cands += (Join-Path ($m.Groups[1].Value -replace '\\\\', '\') "steamapps\common\Dead Cells")
                    }
                }
                foreach ($c in $cands) { if (Test-Path (Join-Path $c "deadcells.exe")) { return $c } }
            }
        } catch {}
    }
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        foreach ($rel in @("EpicGames\DeadCells", "Epic Games\DeadCells", "Program Files\Epic Games\DeadCells",
                           "GOG Games\Dead Cells", "Games\Dead Cells", "SteamLibrary\steamapps\common\Dead Cells",
                           "Program Files (x86)\Steam\steamapps\common\Dead Cells")) {
            $p = Join-Path $d.Root $rel
            if (Test-Path (Join-Path $p "deadcells.exe")) { return $p }
        }
    }
    return ""
}

function Sha([string]$p) { (Get-FileHash -Algorithm SHA256 $p).Hash }

function Has-Bytes([byte[]]$hay, [byte[]]$needle) {
    $l1 = [Text.Encoding]::GetEncoding(28591)   # byte-preserving
    return $l1.GetString($hay).IndexOf($l1.GetString($needle), [StringComparison]::Ordinal) -ge 0
}

function Exe-IsPatched([string]$exe) { Has-Bytes ([IO.File]::ReadAllBytes($exe)) $Marker }

function Read-PakHead([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try {
        $hdr = New-Object byte[] 16
        [void]$fs.Read($hdr, 0, 16)
        if ([Text.Encoding]::ASCII.GetString($hdr, 0, 3) -ne "PAK") { return $null }
        $size = [BitConverter]::ToInt32($hdr, 4)
        $len = [Math]::Min($size, 4MB)
        $all = New-Object byte[] $len
        $fs.Position = 0
        [void]$fs.Read($all, 0, $len)
        return @{ version = $hdr[3]; bytes = $all }
    } finally { $fs.Close() }
}

function Pak-IsOurs([string]$path) {
    $h = Read-PakHead $path
    return ($h -and (Has-Bytes $h.bytes $PakMarker))
}

function Find-Python {
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    return $py
}

