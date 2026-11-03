# Launch Dead Cells through the Epic launcher and report whether it is still running after N seconds.
# Prints the game's command line (from WMI) and recent crash events.
param([int]$Seconds = 50, [switch]$Close)
$uri = "com.epicgames.launcher://apps/1368a7f14c3344bbaededbae528fafed%3A5e7f457a3f1041f79ad82499a1cb69bd%3Aca0e1d19d3b640b39d8d20e966067872?action=launch&silent=true"
$start = Get-Date
Start-Process $uri
$p = $null
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep 1
    $p = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\DeadCells\deadcells.exe' } | Select-Object -First 1
    if ($p) { break }
}
if (-not $p) { "NOT_STARTED"; exit 1 }
$cl = (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)").CommandLine
"pid $($p.Id) started after $i s"
"cmdline: $cl"
Set-Content -Path "$env:TEMP\dc_cmdline.txt" -Value $cl
for ($k = 0; $k -lt $Seconds; $k++) { Start-Sleep 1; if ($p.HasExited) { break } }
if ($p.HasExited) {
    "EXITED after ~$k s, code $($p.ExitCode)"
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; StartTime = $start } -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -eq 1000 -and $_.Message -match 'deadcells' } | Select-Object -First 1 |
        ForEach-Object { ($_.Message -split "`n")[0..6] -join "`n" }
    exit 2
}
$p.Refresh()
"RUNNING after $Seconds s, window '$($p.MainWindowTitle)'"
