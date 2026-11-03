# Wizard of Legend Trainer / Debug Menu Installer
[CmdletBinding()]
param([string]$GamePath = "")

$candidatePaths = @(
    $GamePath,
    "E:\EpicGames\WizardofLegend",
    "C:\Program Files\Epic Games\WizardofLegend",
    "C:\Program Files (x86)\Steam\steamapps\common\Wizard of Legend",
    "D:\SteamLibrary\steamapps\common\Wizard of Legend",
    "E:\SteamLibrary\steamapps\common\Wizard of Legend"
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path $_) }

$targetDir = $null
foreach ($cand in $candidatePaths) {
    if (Test-Path "$cand\Wizard of Legend_Data\Managed\Assembly-CSharp.dll") {
        $targetDir = $cand
        break
    }
}

if (-not $targetDir) {
    $prompt = Read-Host "Enter full path to Wizard of Legend directory"
    if (Test-Path "$prompt\Wizard of Legend_Data\Managed\Assembly-CSharp.dll") {
        $targetDir = $prompt
    } else {
        Write-Error "Could not locate Wizard of Legend_Data\Managed\Assembly-CSharp.dll at specified path."
        return
    }
}

$managedDir = "$targetDir\Wizard of Legend_Data\Managed"
$dllPath = "$managedDir\Assembly-CSharp.dll"
$backupPath = "$managedDir\Assembly-CSharp.dll.VANILLA"

if (-not (Test-Path $backupPath)) {
    Write-Host "Creating vanilla backup at $backupPath..."
    Copy-Item -Path $dllPath -Destination $backupPath -Force
}

Write-Host "Installing patched Assembly-CSharp.dll to $managedDir..."
Copy-Item -Path "$PSScriptRoot\payload\Assembly-CSharp.dll" -Destination $dllPath -Force
Write-Host "Successfully installed Wizard of Legend Trainer & Debug Menu!" -ForegroundColor Green
Write-Host "Controls: Backspace = Open Debug Menu | 1 = MaxDiff | 2 = GodMode | 3 = Slow-mo | 4 = Fullscreen Map"
