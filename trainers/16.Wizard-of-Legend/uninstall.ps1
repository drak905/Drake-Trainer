# Wizard of Legend Trainer Uninstaller
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
    if (Test-Path "$cand\Wizard of Legend_Data\Managed\Assembly-CSharp.dll.VANILLA") {
        $targetDir = $cand
        break
    }
}

if (-not $targetDir) {
    $prompt = Read-Host "Enter full path to Wizard of Legend directory"
    if (Test-Path "$prompt\Wizard of Legend_Data\Managed\Assembly-CSharp.dll.VANILLA") {
        $targetDir = $prompt
    } else {
        Write-Error "Could not locate backup at Wizard of Legend_Data\Managed\Assembly-CSharp.dll.VANILLA"
        return
    }
}

$managedDir = "$targetDir\Wizard of Legend_Data\Managed"
$dllPath = "$managedDir\Assembly-CSharp.dll"
$backupPath = "$managedDir\Assembly-CSharp.dll.VANILLA"

Write-Host "Restoring vanilla backup..."
Copy-Item -Path $backupPath -Destination $dllPath -Force
Remove-Item -Path $backupPath -Force
Write-Host "Uninstalled successfully. Game restored to vanilla." -ForegroundColor Green
