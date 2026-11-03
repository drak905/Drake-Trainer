param(
  [string]$Src = "E:\002.Github\043.ReverseEngine\game-backup\wol\Assembly-CSharp.dll",
  [string]$Dst = "E:\EpicGames\WizardofLegend\Wizard of Legend_Data\Managed\Assembly-CSharp.dll",
  [string]$Managed = "E:\EpicGames\WizardofLegend\Wizard of Legend_Data\Managed"
)
$ProgressPreference = 'SilentlyContinue'
Add-Type -Path "E:\002.Github\043.ReverseEngine\tools\cecil\pkg\lib\net40\Mono.Cecil.dll"

$resolver = New-Object Mono.Cecil.DefaultAssemblyResolver
$resolver.AddSearchDirectory($Managed)
$rp = New-Object Mono.Cecil.ReaderParameters
$rp.AssemblyResolver = $resolver

$asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($Src, $rp)
$gc = $asm.MainModule.Types | Where-Object { $_.Name -eq 'GameController' }
$update = $gc.Methods | Where-Object { $_.Name -eq 'Update' -and $_.Parameters.Count -eq 0 }
$dbg = $gc.Methods | Where-Object { $_.Name -eq 'InitDebugOptions' }
if (-not $update -or -not $dbg) { throw "target methods not found" }

$il = $update.Body.GetILProcessor()
$first = $update.Body.Instructions[0]
$il.InsertBefore($first, $il.Create([Mono.Cecil.Cil.OpCodes]::Ldarg_0))
$il.InsertBefore($first, $il.Create([Mono.Cecil.Cil.OpCodes]::Call, $dbg))

$tmp = "$Dst.patched"
$asm.Write($tmp)
$asm.Dispose()
Move-Item -Force $tmp $Dst
"patched -> $Dst"
