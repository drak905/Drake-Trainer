$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'redacted_live_trainer.lua'
$outputPath = Join-Path $PSScriptRoot 'Redacted.CT'
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
$lines.Add('if RedactedTrainerStop then RedactedTrainerStop(true) end')
$lines.Add("print('[REDACTED] trainer stopped; original health-write bytes restored')")
$lines.Add('{$asm}')

$assembler = $lines -join "`r`n"
$escapedAssembler = [System.Security.SecurityElement]::Escape($assembler)
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<CheatTable CheatEngineTableVersion="52">
  <CheatEntries>
    <CheatEntry>
      <ID>0</ID>
      <Description>"REDACTED Trainer - Activate"</Description>
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
