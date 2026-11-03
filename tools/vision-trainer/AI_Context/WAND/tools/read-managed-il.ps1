param(
    [Parameter(Mandatory=$true)][string]$AssemblyPath,
    [string]$MethodPattern = '.*',
    [switch]$ListOnly
)
# Reflection-only loading reads metadata/IL without running target initializers.
$assembly = [Reflection.Assembly]::ReflectionOnlyLoadFrom((Resolve-Path -LiteralPath $AssemblyPath))
foreach ($dependency in $assembly.GetReferencedAssemblies()) {
    try { [void][Reflection.Assembly]::ReflectionOnlyLoad($dependency.FullName) } catch { }
}
$opcodes = @{}
foreach ($field in [Reflection.Emit.OpCodes].GetFields([Reflection.BindingFlags]'Public,Static')) {
    $opcode = $field.GetValue($null)
    $opcodes[[int]$opcode.Value -band 65535] = $opcode
}
$flags = [Reflection.BindingFlags]'Public,NonPublic,Static,Instance,DeclaredOnly'
foreach ($type in $assembly.GetTypes()) {
    foreach ($method in @($type.GetMethods($flags)) + @($type.GetConstructors($flags))) {
        $identity = $type.FullName + '::' + $method.Name
        if ($identity -notmatch $MethodPattern) { continue }
        if ($ListOnly) { $identity; continue }
        "METHOD $identity $method"
        foreach ($attribute in $method.GetCustomAttributesData()) {
            if ($attribute.Constructor.DeclaringType.FullName -match 'DllImport') { $attribute.ToString() }
        }
        $body = $method.GetMethodBody()
        if ($null -eq $body) { continue }
        foreach ($local in $body.LocalVariables) { "LOCAL $($local.LocalIndex) $($local.LocalType.FullName)" }
        $bytes = $body.GetILAsByteArray()
        $stream = [IO.MemoryStream]::new($bytes, $false)
        $reader = [IO.BinaryReader]::new($stream)
        try {
            while ($stream.Position -lt $stream.Length) {
                $offset = $stream.Position
                $value = [int]$reader.ReadByte()
                if ($value -eq 254) { $value = 65280 + [int]$reader.ReadByte() }
                if (!$opcodes.ContainsKey($value)) { throw "Unknown opcode $value at $offset" }
                $opcode = $opcodes[$value]
                $operand = ''
                switch ($opcode.OperandType.ToString()) {
                    InlineNone { }
                    ShortInlineI { $operand = $reader.ReadSByte() }
                    InlineI { $operand = $reader.ReadInt32() }
                    InlineI8 { $operand = $reader.ReadInt64() }
                    ShortInlineR { $operand = $reader.ReadSingle() }
                    InlineR { $operand = $reader.ReadDouble() }
                    ShortInlineVar { $operand = $reader.ReadByte() }
                    InlineVar { $operand = $reader.ReadUInt16() }
                    ShortInlineBrTarget { $delta = $reader.ReadSByte(); $operand = 'IL_{0:X4}' -f ($stream.Position + $delta) }
                    InlineBrTarget { $delta = $reader.ReadInt32(); $operand = 'IL_{0:X4}' -f ($stream.Position + $delta) }
                    InlineSwitch {
                        $count = $reader.ReadInt32()
                        $deltas = @(for ($index = 0; $index -lt $count; $index++) { $reader.ReadInt32() })
                        $next = $stream.Position
                        $operand = ($deltas | ForEach-Object { 'IL_{0:X4}' -f ($next + $_) }) -join ', '
                    }
                    default {
                        $token = $reader.ReadInt32()
                        try {
                            switch ($opcode.OperandType.ToString()) {
                                InlineString { $operand = '"' + $method.Module.ResolveString($token) + '"' }
                                InlineMethod { $member = $method.Module.ResolveMethod($token); $operand = "$($member.DeclaringType.FullName)::$member" }
                                InlineField { $member = $method.Module.ResolveField($token); $operand = "$($member.DeclaringType.FullName)::$member" }
                                InlineType { $operand = $method.Module.ResolveType($token).FullName }
                                InlineTok { $operand = $method.Module.ResolveMember($token).ToString() }
                                InlineSig { $operand = 'signature 0x{0:X8}' -f $token }
                                default { throw "Unsupported operand $($opcode.OperandType)" }
                            }
                        } catch { $operand = 'unresolved token 0x{0:X8}' -f $token }
                    }
                }
                'IL_{0:X4}: {1} {2}' -f $offset, $opcode.Name, $operand
            }
        } finally { $reader.Dispose(); $stream.Dispose() }
    }
}
