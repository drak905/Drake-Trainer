$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'rcg_live_trainer.lua'
$outputPath = Join-Path $PSScriptRoot 'RiverCityGirls.CT'
$luaSource = [System.IO.File]::ReadAllText($sourcePath)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('[ENABLE]')
$lines.Add('{$lua}')
$lines.Add('if syntaxcheck then return end')
$lines.Add('')
$lines.Add($luaSource.TrimEnd())
$lines.Add('{$asm}')
$lines.Add('')
$lines.Add('[DISABLE]')
$lines.Add('{$lua}')
$lines.Add('if syntaxcheck then return end')
$lines.Add('if RiverCityGirlsTrainerStop then RiverCityGirlsTrainerStop(true) end')
$lines.Add("print('[River City Girls] trainer stopped; defaults and code restored')")
$lines.Add('{$asm}')

$assembler = $lines -join "`r`n"
$escapedAssembler = [System.Security.SecurityElement]::Escape($assembler)
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<CheatTable UsesMono="1" CheatEngineTableVersion="52">
  <CheatEntries>
    <CheatEntry>
      <ID>0</ID>
      <Description>"River City Girls Trainer - Activate"</Description>
      <Options moHideChildren="1" moDeactivateChildrenAsWell="1"/>
      <VariableType>Auto Assembler Script</VariableType>
      <AssemblerScript>$escapedAssembler</AssemblerScript>
    </CheatEntry>
  </CheatEntries>
  <UserdefinedSymbols/>
</CheatTable>
"@

$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($outputPath, $xml, $utf8)
Write-Output $outputPath
