# Removes the Guacamelee! STCE Vietnamese patch (restores the original Game.exe and misc.dat). Safe to re-run.
# Usage: uninstall.ps1 [-GameDir "D:\Games\GuacameleeSTCE"]
param([string]$GameDir = "")
$ErrorActionPreference = "Stop"
$ExeVanilla  = "DE6CEC52F06B8E0FC835356B31AB80891BC4BA6431823B0EEF6FC02C480209F2"
$ExePatched  = "70FC09A0CA9BCA527A06246550514E75E818A741EDC4FAAF35A42405E39D9818"
$MiscVanilla = "B52125AB0FBFF97F7FA7E05C41E2B09F8ECDBA26F33C94D39ED11C29F9FD658C"
$MiscPatched = "5362DB2EA62F26A83D9B59A5B9523D4D0A4A22D859E356A0FE24A064E042F84B"
function Test-GameDir([string]$p) { return ($p -and (Test-Path (Join-Path $p "Game.exe")) -and (Test-Path (Join-Path $p "fmodstudio.dll"))) }
function Sha([string]$f) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToUpper() }
if (-not $GameDir) {
  $mdir = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
  if (Test-Path $mdir) {
    foreach ($f in Get-ChildItem $mdir -Filter *.item -ErrorAction SilentlyContinue) {
      try { $j = Get-Content $f.FullName -Raw | ConvertFrom-Json } catch { continue }
      if ($j.DisplayName -match 'Guacamelee' -and (Test-GameDir $j.InstallLocation)) { $GameDir = $j.InstallLocation; break }
    }
  }
}
if (-not $GameDir) { $GameDir = Read-Host "Paste the game folder (contains Game.exe)" }
$GameDir = $GameDir.Trim('"').TrimEnd('\')
if (-not (Test-GameDir $GameDir)) { throw "Game.exe not found in '$GameDir'." }
if (Get-Process -Name "Game" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$GameDir*" }) { throw "Close the game first." }

$xd      = Join-Path $PSScriptRoot "tools\xdelta3.exe"
$payload = Join-Path $PSScriptRoot "payload"
$backup  = Join-Path $GameDir "VietnamesePatch_backup"
$manifest = Join-Path $GameDir "VietnamesePatch_install_manifest.txt"
$files = @(
  @{ Name = "Game.exe"; Vanilla = $ExeVanilla;  Patched = $ExePatched;  Delta = "Game.exe.revert.xdelta" },
  @{ Name = "misc.dat"; Vanilla = $MiscVanilla; Patched = $MiscPatched; Delta = "misc.dat.revert.xdelta" }
)
foreach ($f in $files) {
  $path = Join-Path $GameDir $f.Name
  $h = Sha $path
  if ($h -eq $f.Vanilla) { Write-Host "$($f.Name): already original"; continue }
  $bak = Join-Path $backup $f.Name
  if ((Test-Path $bak) -and ((Sha $bak) -eq $f.Vanilla)) {
    Copy-Item $bak $path -Force
    Write-Host "Restored $($f.Name) from backup"
  } elseif ($h -eq $f.Patched) {
    $tmp = "$path.vi_tmp"
    & $xd -d -f -s $path (Join-Path $payload $f.Delta) $tmp
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmp) -or (Sha $tmp) -ne $f.Vanilla) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; throw "Could not rebuild the original $($f.Name)." }
    Move-Item $tmp $path -Force
    Write-Host "Restored $($f.Name) (rebuilt from the patched file)"
  } else {
    Write-Warning "$($f.Name) is neither the original nor the patched file - left untouched (use Epic 'Verify' to restore it)."
  }
}
Remove-Item $backup -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $manifest -Force -ErrorAction SilentlyContinue
Write-Host "Vietnamese patch removed from $GameDir (saves were never touched)."
Write-Host "Note: if the game language was left on Tieng Viet it simply falls back to the default language."
