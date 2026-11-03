-- River City Girls live trainer prototype (Unity/Mono, 64-bit)
--
-- This script intentionally follows persistent singleton roots.  Its 3000 ms
-- keeper performs only pointer/field reads and writes; it never scans the Mono
-- heap.  Re-running the script first restores and removes an older instance.

if RiverCityGirlsTrainerStop then
  pcall(function() RiverCityGirlsTrainerStop(true) end)
end

if not mono_isValid() then LaunchMonoDataCollector() end
if not mono_isValid() then
  error('River City Girls: Mono data collector is unavailable')
end

RCGT = {}
RCGT.domain = (mono_enumDomains() or {})[1]
if not RCGT.domain then error('River City Girls: Mono domain not found') end

local function valid(p)
  return p and p > 0x10000 and p < 0x7FFF00000000
end

local function findImage(name)
  for _, assembly in ipairs(mono_enumAssemblies() or {}) do
    local image = mono_getImageFromAssembly(assembly)
    if image and mono_image_get_name(image) == name then return image end
  end
end

local function findClass(image, namespace, name)
  for _, entry in ipairs(mono_image_enumClasses(image) or {}) do
    if tostring(entry.namespace or '') == namespace
        and tostring(entry.classname or '') == name then
      return entry.class
    end
  end
end

local function findMethod(class, name, signature)
  for _, method in ipairs(mono_class_enumMethods(class) or {}) do
    if method.name == name then
      local actual = mono_method_getSignature(method.method)
      if signature == nil or actual == signature then return method.method end
    end
  end
end

local function bytesAt(address, count)
  return readBytes(address, count, true)
end

local function bytesMatch(address, expected)
  local actual = bytesAt(address, #expected)
  if not actual then return false end
  for i = 1, #expected do
    if actual[i] ~= expected[i] then return false end
  end
  return true
end

local function putBytes(address, bytes)
  if not (address and bytes) then return end
  for i = 1, #bytes do writeBytes(address + i - 1, bytes[i]) end
end

RCGT.image = findImage('Assembly-CSharp')
if not RCGT.image then error('River City Girls: Assembly-CSharp not found') end

RCGT.classes = {
  player = findClass(RCGT.image, 'RCG', 'Player'),
  playerManager = findClass(RCGT.image, '', 'PlayerManager'),
  playerAttributes = findClass(RCGT.image, 'RCG', 'PlayerAttributes'),
  globalInventory = findClass(RCGT.image, '', 'PlayerGlobalInventory'),
  playerStatSystem = findClass(RCGT.image, 'RCG', 'PlayerStatSystem'),
}
for name, class in pairs(RCGT.classes) do
  if not class then error('River City Girls: class not found: ' .. name) end
end

RCGT.methods = {
  updateAttributes = findMethod(RCGT.classes.player, 'UpdateFromAttributes', ''),
  receiveMoney = findMethod(
    RCGT.classes.globalInventory, 'ReceiveMonies', 'PlayerCharacters,single'),
  addXP = findMethod(RCGT.classes.playerStatSystem, 'AddEXP', 'int'),
}
for name, method in pairs(RCGT.methods) do
  if not method then error('River City Girls: method not found: ' .. name) end
end

RCGT.code = {
  receiveMoney = mono_compile_method(RCGT.methods.receiveMoney),
  addXP = mono_compile_method(RCGT.methods.addXP),
}
for name, address in pairs(RCGT.code) do
  if not valid(address) then
    error('River City Girls: failed to compile method: ' .. name)
  end
end

-- Resolve persistent roots once.  The pointers stored at these static-field
-- addresses may change, but the addresses themselves remain valid for the
-- lifetime of the attached process.
RCGT.static = {
  player = mono_class_getStaticFieldAddress(RCGT.domain, RCGT.classes.player),
  playerManager = mono_class_getStaticFieldAddress(
    RCGT.domain, RCGT.classes.playerManager),
  playerAttributes = mono_class_getStaticFieldAddress(
    RCGT.domain, RCGT.classes.playerAttributes),
  globalInventory = mono_class_getStaticFieldAddress(
    RCGT.domain, RCGT.classes.globalInventory),
}
for name, address in pairs(RCGT.static) do
  if not valid(address) then
    error('River City Girls: static root unavailable: ' .. name)
  end
end

-- Both hooks replace exactly the first eight bytes of their methods.
local moneyPrologue = { 0x55, 0x48, 0x8B, 0xEC, 0x48, 0x83, 0xEC, 0x40 }
local xpPrologue = { 0x55, 0x48, 0x8B, 0xEC, 0x48, 0x83, 0xEC, 0x30 }
if not bytesMatch(RCGT.code.receiveMoney, moneyPrologue) then
  error('River City Girls: unexpected ReceiveMonies prologue')
end
if not bytesMatch(RCGT.code.addXP, xpPrologue) then
  error('River City Girls: unexpected AddEXP prologue')
end
RCGT.original = {
  receiveMoney = bytesAt(RCGT.code.receiveMoney, 8),
  addXP = bytesAt(RCGT.code.addXP, 8),
}

local gainScript = string.format([[
alloc(rcgGainCave,1024,%X)
label(rcgMoneyCode)
label(rcgMoneyOriginal)
label(rcgXPCode)
label(rcgXPOriginal)
label(rcgGainMultiplier)
label(rcgGainMultiplierFloat)
registersymbol(rcgGainMultiplier)
registersymbol(rcgGainMultiplierFloat)

rcgGainCave:
rcgGainMultiplier:
  dd 10
rcgGainMultiplierFloat:
  dd (float)10.0
  align 10 CC

rcgMoneyCode:
  cmp dword ptr [rcgGainMultiplier],1
  jle short rcgMoneyOriginal
  mulss xmm2,[rcgGainMultiplierFloat]
rcgMoneyOriginal:
  push rbp
  mov rbp,rsp
  sub rsp,40
  jmp %X

rcgXPCode:
  test edx,edx
  jle short rcgXPOriginal
  imul edx,[rcgGainMultiplier]
rcgXPOriginal:
  push rbp
  mov rbp,rsp
  sub rsp,30
  jmp %X

%X:
  jmp rcgMoneyCode
  nop 3

%X:
  jmp rcgXPCode
  nop 3
]], RCGT.code.receiveMoney,
    RCGT.code.receiveMoney + 8,
    RCGT.code.addXP + 8,
    RCGT.code.receiveMoney,
    RCGT.code.addXP)

if not autoAssemble(gainScript) then
  error('River City Girls: collection-gain injection failed')
end
RCGT.gainMultiplier = getAddress('rcgGainMultiplier')
RCGT.gainMultiplierFloat = getAddress('rcgGainMultiplierFloat')

-- Editable non-code controls.
RCGT.controls = allocateMemory(32)
if not valid(RCGT.controls) then
  putBytes(RCGT.code.receiveMoney, RCGT.original.receiveMoney)
  putBytes(RCGT.code.addXP, RCGT.original.addXP)
  pcall(function()
    autoAssemble('unregistersymbol(rcgGainMultiplier)\nunregistersymbol(rcgGainMultiplierFloat)\ndealloc(rcgGainCave)')
  end)
  error('River City Girls: control allocation failed')
end
RCGT.noDamageControl = RCGT.controls
RCGT.oneHitControl = RCGT.controls + 4
RCGT.speedControl = RCGT.controls + 8
RCGT.maxStatsControl = RCGT.controls + 12
RCGT.damageControl = RCGT.controls + 16
writeBytes(RCGT.noDamageControl, 1)
writeBytes(RCGT.oneHitControl, 1)
writeFloat(RCGT.speedControl, 2.0)
writeBytes(RCGT.maxStatsControl, 1)
writeFloat(RCGT.damageControl, 100000.0)

function RCGTPlayers()
  if not RCGT then return {} end
  local manager = readPointer(RCGT.static.playerManager)
  local array = valid(manager) and readPointer(manager + 0x18) or nil
  local count = valid(array) and (readQword(array + 0x18) or 0) or 0
  count = math.min(math.max(tonumber(count) or 0, 0), 4)
  local result = {}
  for i = 0, count - 1 do
    local player = readPointer(array + 0x20 + i * 8)
    if valid(player) then result[#result + 1] = player end
  end
  return result
end

function RCGTAttributeObjects()
  if not RCGT then return {} end
  local attributes = readPointer(RCGT.static.playerAttributes)
  local array = valid(attributes) and readPointer(attributes + 0x20) or nil
  local count = valid(array) and (readQword(array + 0x18) or 0) or 0
  count = math.min(math.max(tonumber(count) or 0, 0), 4)
  local result = {}
  for i = 0, count - 1 do
    local object = readPointer(array + 0x20 + i * 8)
    if valid(object) then result[i] = object end
  end
  return result
end

-- Capture the pre-cheat profile bonuses by character index so disabling the
-- toggle restores the values even if Unity rebuilds the managed objects.
RCGT.statOriginal = {}
for index, object in pairs(RCGTAttributeObjects()) do
  RCGT.statOriginal[index] = {}
  for stat = 0, 5 do
    RCGT.statOriginal[index][stat] = readInteger(object + 0x24 + stat * 4) or 0
  end
end

local function updatePlayerAttributes(player)
  pcall(function()
    mono_invoke_method(
      RCGT.domain, RCGT.methods.updateAttributes, player, {})
  end)
end

function RCGTSetGainMultiplier(value)
  value = math.max(1, math.min(100, math.floor(tonumber(value) or 1)))
  writeInteger(RCGT.gainMultiplier, value)
  writeFloat(RCGT.gainMultiplierFloat, value)
  return value
end

function RCGTApply(forceRecalculate)
  if not RCGT then return false end
  local noDamage = readBytes(RCGT.noDamageControl, 1, false) == 1
  local oneHit = readBytes(RCGT.oneHitControl, 1, false) == 1
  local maxStats = readBytes(RCGT.maxStatsControl, 1, false) == 1
  local speed = tonumber(readFloat(RCGT.speedControl)) or 1.0
  local damage = tonumber(readFloat(RCGT.damageControl)) or 1.0
  speed = math.max(0.1, math.min(10.0, speed))
  damage = math.max(1.0, math.min(1000000.0, damage))

  -- Player._debugInvincible is the first static field and is checked before
  -- the per-player Invincible backing field in Player.CanGetHit().
  writeBytes(RCGT.static.player, noDamage and 1 or 0)

  local statsChanged = false
  for index, object in pairs(RCGTAttributeObjects()) do
    local original = RCGT.statOriginal[index]
    if not original then
      original = {}
      RCGT.statOriginal[index] = original
      for stat = 0, 5 do
        original[stat] = readInteger(object + 0x24 + stat * 4) or 0
      end
    end
    for stat = 0, 5 do
      local target
      if maxStats then
        -- Use the class's own six per-profile maximum-level values.
        target = readInteger(object + 0x44 + stat * 4) or original[stat]
      else
        target = original[stat]
      end
      local address = object + 0x24 + stat * 4
      if readInteger(address) ~= target then
        writeInteger(address, target)
        statsChanged = true
      end
    end
  end

  local players = RCGTPlayers()
  if statsChanged or forceRecalculate then
    for _, player in ipairs(players) do updatePlayerAttributes(player) end
  end
  for _, player in ipairs(players) do
    if statsChanged or forceRecalculate then
      local currentStamina = readInteger(player + 0x348)
      local maximumStamina = readInteger(player + 0x2F8)
      if maxStats and currentStamina and currentStamina > 0
          and maximumStamina and currentStamina < maximumStamina then
        -- Top up once when the maximum grows; the keeper does not freeze HP.
        writeInteger(player + 0x348, maximumStamina)
      elseif not maxStats and currentStamina and maximumStamina
          and currentStamina > maximumStamina then
        writeInteger(player + 0x348, maximumStamina)
      end
      local currentSpecial = readInteger(player + 0x560)
      local maximumSpecial = readInteger(player + 0x538)
      if not maxStats and currentSpecial and maximumSpecial
          and currentSpecial > maximumSpecial then
        writeInteger(player + 0x560, maximumSpecial)
      end
    end
    writeBytes(player + 0x528, noDamage and 1 or 0)
    writeFloat(player + 0x56C, speed)
    if oneHit then
      writeFloat(player + 0x2FC, damage)
      writeFloat(player + 0x300, damage)
    elseif forceRecalculate then
      updatePlayerAttributes(player)
      writeFloat(player + 0x56C, speed)
    end
  end
  return true
end

function RiverCityGirlsTrainerStop(restoreDefaults)
  if RCGT_KEEPER then
    pcall(function()
      RCGT_KEEPER.Enabled = false
      RCGT_KEEPER.destroy()
    end)
    RCGT_KEEPER = nil
  end
  RCGT_KEEPER_BUSY = false

  if RCGT then
    if restoreDefaults then
      pcall(function()
        writeBytes(RCGT.noDamageControl, 0)
        writeBytes(RCGT.oneHitControl, 0)
        writeFloat(RCGT.speedControl, 1.0)
        writeBytes(RCGT.maxStatsControl, 0)
        RCGTApply(true)
      end)
    end
    pcall(function()
      putBytes(RCGT.code.receiveMoney, RCGT.original.receiveMoney)
      putBytes(RCGT.code.addXP, RCGT.original.addXP)
    end)
    pcall(function()
      autoAssemble('unregistersymbol(rcgGainMultiplier)\nunregistersymbol(rcgGainMultiplierFloat)\ndealloc(rcgGainCave)')
    end)
  end

  local list = getAddressList()
  for i = list.Count - 1, 0, -1 do
    local record = list[i]
    if record and tostring(record.Description):match('^RCG:') then
      record.OnValueChangedByUser = nil
      record.destroy()
    end
  end
  if RCGT then
    pcall(function() deAlloc(RCGT.controls, 32) end)
  end
  RCGT = nil
end

local list = getAddressList()
for i = list.Count - 1, 0, -1 do
  local record = list[i]
  if record and tostring(record.Description):match('^RCG:') then record.destroy() end
end

local root = list.getMemoryRecordByDescription(
  'River City Girls Trainer - Activate')
if not root then
  root = list.createMemoryRecord()
  root.Description = 'RCG: Live Trainer Controls'
  root.IsGroupHeader = true
end

local function makeRecord(description, address, valueType)
  local record = list.createMemoryRecord()
  record.Description = description
  record.Address = string.format('%X', address)
  record.VarType = valueType
  record.ShowAsHex = false
  record.appendToEntry(root)
  return record
end

local function makeToggle(description, address, callback)
  local record = makeRecord(description, address, vtByte)
  record.DropDownList.Text = '0:Disabled\n1:Enabled'
  record.DropDownReadOnly = true
  record.DropDownDescriptionOnly = true
  record.DisplayAsDropDownListItem = true
  record.Value = '1'
  record.OnValueChangedByUser = function(_, _, newValue)
    callback((tonumber(newValue) or 0) ~= 0)
  end
  return record
end

makeToggle('RCG: No Damage', RCGT.noDamageControl, function(enabled)
  writeBytes(RCGT.noDamageControl, enabled and 1 or 0)
  RCGTApply(true)
end)

makeToggle('RCG: One-Hit Kill', RCGT.oneHitControl, function(enabled)
  writeBytes(RCGT.oneHitControl, enabled and 1 or 0)
  RCGTApply(true)
end)

local damageRecord = makeRecord(
  'RCG: Attack Damage Multiplier', RCGT.damageControl, vtSingle)
damageRecord.Value = '100000'
damageRecord.OnValueChangedByUser = function(_, _, newValue)
  writeFloat(RCGT.damageControl, tonumber(newValue) or 1)
  RCGTApply(false)
end

local gainRecord = makeRecord(
  'RCG: Money + XP Gain Multiplier', RCGT.gainMultiplier, vtDword)
gainRecord.Value = '10'
gainRecord.OnValueChangedByUser = function(_, _, newValue)
  RCGTSetGainMultiplier(newValue)
end

local speedRecord = makeRecord(
  'RCG: Character Speed Multiplier', RCGT.speedControl, vtSingle)
speedRecord.Value = '2'
speedRecord.OnValueChangedByUser = function(_, _, newValue)
  writeFloat(RCGT.speedControl, tonumber(newValue) or 1)
  RCGTApply(false)
end

makeToggle('RCG: Max All Character Stats', RCGT.maxStatsControl,
  function(enabled)
    writeBytes(RCGT.maxStatsControl, enabled and 1 or 0)
    RCGTApply(true)
  end)

root.Collapsed = false
RCGTSetGainMultiplier(10)
RCGTApply(true)

RCGT_KEEPER_BUSY = false
RCGT_KEEPER = createTimer(nil, false)
RCGT_KEEPER.Interval = 3000
RCGT_KEEPER.OnTimer = function()
  if RCGT_KEEPER_BUSY then return end
  RCGT_KEEPER_BUSY = true
  local ok, err = pcall(function() RCGTApply(false) end)
  if not ok and RCGT then RCGT.lastError = tostring(err) end
  RCGT_KEEPER_BUSY = false
end
RCGT_KEEPER.Enabled = true

print('[River City Girls] trainer active; keeper interval = 3000 ms')
