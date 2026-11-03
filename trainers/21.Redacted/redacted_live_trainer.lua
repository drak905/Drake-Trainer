-- REDACTED live trainer (Unreal Engine, 64-bit)
--
-- No Damage and One-Hit Kill share the verified health-component setter. The
-- player-owner vtable selects the protected player path; decreasing health on
-- any other owned component is forced to zero. The pickup multiplier hooks the
-- shared positive item-award function before it updates either live inventory
-- map. Three wallet signatures capture candidates from the generic currency
-- getter,
-- positive update routine, and spend routine; a cheap timer validates them.

if RedactedTrainerStop then
  pcall(function() RedactedTrainerStop(true) end)
end

RDT = {
  version = '1.3.0-dev1',
  moduleName = 'Redacted-Win64-Shipping.exe',
  playerVtableRva = 0x56C6B98,
  currencyAssetVtableRva = 0x5A937B8,
  healthOffset = 0x190,
  outerOffset = 0x20,
  walletArrayOffset = 0x218,
  walletCountOffset = 0x220,
  walletCapacityOffset = 0x224,
  walletRecordStride = 0x110,
  healthSignature =
    'F3 0F 11 B3 90 01 00 00 F3 44 0F 5C C7 76 ?? ' ..
    '41 0F 2F F1 77 ?? 48 8B 03',
  pickupSignature =
    '44 89 44 24 18 41 54 41 56 48 83 EC 78 80 B9 A9 26 00 00 00 ' ..
    '41 8B C0 4C 8B F2 4C 8B E1',
  walletGetterSignature =
    '4C 63 81 20 02 00 00 33 C0 4D 85 C0 7E ?? ' ..
    '48 8B 89 18 02 00 00 48 8B 52 08 48 83 C1 10',
  walletUpdateSignature =
    '40 55 57 41 55 41 57 48 8D AC 24 78 FF FF FF ' ..
    '48 81 EC 88 01 00 00 48 8B 05 ?? ?? ?? ??',
  walletSpendSignature =
    '44 89 44 24 18 89 54 24 10 48 89 4C 24 08 53 56 57 41 55 ' ..
    '48 83 EC 58 48 63 C2 41 8B F0 4C 69 E8 10 01 00 00',
  healthOriginalCode =
    {0xF3, 0x0F, 0x11, 0xB3, 0x90, 0x01, 0x00, 0x00},
  pickupOriginalCode = {0x44, 0x89, 0x44, 0x24, 0x18},
  walletGetterOriginalCode = {0x4C, 0x63, 0x81, 0x20, 0x02, 0x00, 0x00},
  walletUpdateOriginalCode = {0x40, 0x55, 0x57, 0x41, 0x55},
  walletSpendOriginalCode = {0x44, 0x89, 0x44, 0x24, 0x18},
  currencies = {
    {key = 'credits', name = 'Credits', fname = 0x2DBDE,
      symbol = 'redCurrencyCredits'},
    {key = 'keycodes', name = 'Keycodes', fname = 0x2DBE3,
      symbol = 'redCurrencyKeycodes'},
    {key = 'contraband', name = 'Contraband', fname = 0x2DBEA,
      symbol = 'redCurrencyContraband'},
    {key = 'electronics', name = 'Electronics', fname = 0x2DBFA,
      symbol = 'redCurrencyElectronics'},
    {key = 'securityIds', name = 'Security IDs', fname = 0x2DBF2,
      symbol = 'redCurrencySecurityIds'},
    {key = 'souvenirs', name = 'Souvenirs', fname = 0x2DC0B,
      symbol = 'redCurrencySouvenirs'},
    {key = 'samples', name = 'Samples', fname = 0x2DC03,
      symbol = 'redCurrencySamples'},
  },
  records = {},
}

local function valid(address)
  return address and address > 0x10000 and address < 0x7FFF00000000
end

local function bytesMatch(address, expected)
  if not valid(address) then return false end
  local actual = readBytes(address, #expected, true)
  if not actual then return false end
  for i = 1, #expected do
    if actual[i] ~= expected[i] then return false end
  end
  return true
end

local function putBytes(address, bytes)
  if not (valid(address) and bytes) then return end
  for i = 1, #bytes do
    writeBytes(address + i - 1, bytes[i])
  end
end

local function signed32(value)
  value = (tonumber(value) or 0) % 0x100000000
  if value >= 0x80000000 then return value - 0x100000000 end
  return value
end

local function uniqueModuleCode(pattern, description)
  local matches = AOBScan(pattern, '+X')
  local result = {}
  if matches then
    for i = 0, matches.Count - 1 do
      local address = getAddressSafe(matches[i])
      if valid(address)
          and address >= RDT.moduleBase
          and address < RDT.moduleEnd then
        result[#result + 1] = address
      end
    end
    matches.destroy()
  end
  if #result ~= 1 then
    error(string.format(
      'REDACTED: expected one %s signature in %s, found %d',
      description, RDT.moduleName, #result))
  end
  return result[1]
end

RDT.moduleBase = getAddressSafe(RDT.moduleName)
if not valid(RDT.moduleBase) then
  error(
    'REDACTED: attach Cheat Engine to Redacted-Win64-Shipping.exe, ' ..
    'not the small Redacted.exe launcher')
end

RDT.moduleSize = tonumber(getModuleSize(RDT.moduleName)) or 0
RDT.moduleEnd = RDT.moduleBase + RDT.moduleSize
if RDT.moduleSize <= math.max(RDT.playerVtableRva,
    RDT.currencyAssetVtableRva) then
  error('REDACTED: unexpected module size; refusing to install the hook')
end

RDT.processId = getOpenedProcessID()
if not RDT.processId or RDT.processId == 0 then
  error('REDACTED: no process is attached')
end

RDT.playerVtable = RDT.moduleBase + RDT.playerVtableRva
local firstVirtualFunction = readPointer(RDT.playerVtable)
if not valid(firstVirtualFunction)
    or firstVirtualFunction < RDT.moduleBase
    or firstVirtualFunction >= RDT.moduleEnd then
  error('REDACTED: player-vtable validation failed for this game build')
end

RDT.currencyAssetVtable = RDT.moduleBase + RDT.currencyAssetVtableRva
local currencyVirtualFunction = readPointer(RDT.currencyAssetVtable)
if not valid(currencyVirtualFunction)
    or currencyVirtualFunction < RDT.moduleBase
    or currencyVirtualFunction >= RDT.moduleEnd then
  error('REDACTED: currency-asset vtable validation failed for this game build')
end

RDT.healthWrite = uniqueModuleCode(RDT.healthSignature, 'health write')
if not bytesMatch(RDT.healthWrite, RDT.healthOriginalCode) then
  error('REDACTED: health-write bytes do not match the verified build')
end

RDT.pickupEntry = uniqueModuleCode(RDT.pickupSignature, 'item-award entry')
if not bytesMatch(RDT.pickupEntry, RDT.pickupOriginalCode) then
  error('REDACTED: item-award bytes do not match the verified build')
end

RDT.walletGetter = uniqueModuleCode(
  RDT.walletGetterSignature, 'currency getter')
if not bytesMatch(RDT.walletGetter, RDT.walletGetterOriginalCode) then
  error('REDACTED: currency-getter bytes do not match the verified build')
end

RDT.walletUpdate = uniqueModuleCode(
  RDT.walletUpdateSignature, 'wallet update entry')
if not bytesMatch(RDT.walletUpdate, RDT.walletUpdateOriginalCode) then
  error('REDACTED: wallet-update bytes do not match the verified build')
end

RDT.walletSpend = uniqueModuleCode(
  RDT.walletSpendSignature, 'wallet spend entry')
if not bytesMatch(RDT.walletSpend, RDT.walletSpendOriginalCode) then
  error('REDACTED: wallet-spend bytes do not match the verified build')
end

local hookScript = string.format([[
alloc(redTrainerMem,1024,%X)
alloc(redPickupMem,512,%X)
alloc(redWalletMem,512,%X)
label(redHealthHook)
label(redHealthOriginal)
label(redHealthPlayer)
label(redNoDamage)
label(redOneHitKill)
label(redPlayerVtable)
label(redHealthComponent)
label(redNoDamageBlocks)
label(redOneHitComponent)
label(redOneHitEvents)
label(redOneHitPreviousHealth)
label(redOneHitProposedHealth)
label(redPickupHook)
label(redPickupOriginal)
label(redPickupRecordFinal)
label(redPickupMultiplier)
label(redPickupEvents)
label(redPickupBaseAmount)
label(redPickupFinalAmount)
label(redWalletHook)
label(redWalletUpdateHook)
label(redWalletSpendHook)
label(redWalletSpendCapture)
label(redWalletSpendDone)
label(redWalletUpdateCapture)
label(redWalletUpdateDone)
label(redWalletOwner)
label(redWalletGetterCandidate)
label(redWalletUpdateCandidate)
label(redWalletSpendCandidate)
label(redWalletCaptures)
label(redWalletState)
label(redWalletSource)
label(redWalletRecordCount)
label(redCurrencyCredits)
label(redCurrencyKeycodes)
label(redCurrencyContraband)
label(redCurrencyElectronics)
label(redCurrencySecurityIds)
label(redCurrencySouvenirs)
label(redCurrencySamples)
registersymbol(redTrainerMem)
registersymbol(redHealthHook)
registersymbol(redNoDamage)
registersymbol(redOneHitKill)
registersymbol(redPlayerVtable)
registersymbol(redHealthComponent)
registersymbol(redNoDamageBlocks)
registersymbol(redOneHitComponent)
registersymbol(redOneHitEvents)
registersymbol(redOneHitPreviousHealth)
registersymbol(redOneHitProposedHealth)
registersymbol(redPickupMem)
registersymbol(redPickupHook)
registersymbol(redPickupMultiplier)
registersymbol(redPickupEvents)
registersymbol(redPickupBaseAmount)
registersymbol(redPickupFinalAmount)
registersymbol(redWalletMem)
registersymbol(redWalletHook)
registersymbol(redWalletUpdateHook)
registersymbol(redWalletSpendHook)
registersymbol(redWalletOwner)
registersymbol(redWalletGetterCandidate)
registersymbol(redWalletUpdateCandidate)
registersymbol(redWalletSpendCandidate)
registersymbol(redWalletCaptures)
registersymbol(redWalletState)
registersymbol(redWalletSource)
registersymbol(redWalletRecordCount)
registersymbol(redCurrencyCredits)
registersymbol(redCurrencyKeycodes)
registersymbol(redCurrencyContraband)
registersymbol(redCurrencyElectronics)
registersymbol(redCurrencySecurityIds)
registersymbol(redCurrencySouvenirs)
registersymbol(redCurrencySamples)

redTrainerMem:
redHealthHook:
  push rax
  pushfq
  mov rax,[rbx+%X]
  test rax,rax
  je redHealthOriginal
  mov rax,[rax]
  cmp rax,qword ptr [redPlayerVtable]
  je redHealthPlayer
  cmp byte ptr [redOneHitKill],00
  je redHealthOriginal
  comiss xmm6,[rbx+%X]
  jae redHealthOriginal
  mov [redOneHitComponent],rbx
  mov eax,[rbx+%X]
  mov [redOneHitPreviousHealth],eax
  movss [redOneHitProposedHealth],xmm6
  xorps xmm6,xmm6
  inc qword ptr [redOneHitEvents]
  jmp redHealthOriginal
redHealthPlayer:
  mov [redHealthComponent],rbx
  cmp byte ptr [redNoDamage],00
  je redHealthOriginal
  comiss xmm6,[rbx+%X]
  jae redHealthOriginal
  movss xmm6,[rbx+%X]
  inc qword ptr [redNoDamageBlocks]
redHealthOriginal:
  popfq
  pop rax
  movss [rbx+%X],xmm6
  jmp %X

redPickupMem:
redPickupHook:
  test r8d,r8d
  jle redPickupOriginal
  mov [redPickupBaseAmount],r8d
  cmp dword ptr [redPickupMultiplier],01
  jle redPickupRecordFinal
  imul r8d,[redPickupMultiplier]
redPickupRecordFinal:
  mov [redPickupFinalAmount],r8d
  inc qword ptr [redPickupEvents]
redPickupOriginal:
  mov [rsp+18],r8d
  jmp %X

align 8 CC
redPickupMultiplier:
  dd 00000064
redPickupBaseAmount:
  dd 0
redPickupFinalAmount:
  dd 0
align 8 CC
redPickupEvents:
  dq 0

redWalletMem:
redWalletSpendHook:
  mov [rsp+18],r8d
  pushfq
  push rax
  push rdx
  mov rax,[rcx+00000218]
  test rax,rax
  je redWalletSpendDone
  movsxd rdx,edx
  imul rdx,rdx,00000110
  cmp dword ptr [rax+rdx+08],0002DBDE
  je redWalletSpendCapture
  cmp dword ptr [rax+rdx+08],0002DBE3
  je redWalletSpendCapture
  cmp dword ptr [rax+rdx+08],0002DBEA
  je redWalletSpendCapture
  cmp dword ptr [rax+rdx+08],0002DBFA
  je redWalletSpendCapture
  cmp dword ptr [rax+rdx+08],0002DBF2
  je redWalletSpendCapture
  cmp dword ptr [rax+rdx+08],0002DC0B
  je redWalletSpendCapture
  cmp dword ptr [rax+rdx+08],0002DC03
  jne redWalletSpendDone
redWalletSpendCapture:
  mov [redWalletSpendCandidate],rcx
  inc qword ptr [redWalletCaptures]
redWalletSpendDone:
  pop rdx
  pop rax
  popfq
  jmp %X

redWalletUpdateHook:
  pushfq
  cmp dword ptr [rdx+08],0002DBDE
  je redWalletUpdateCapture
  cmp dword ptr [rdx+08],0002DBE3
  je redWalletUpdateCapture
  cmp dword ptr [rdx+08],0002DBEA
  je redWalletUpdateCapture
  cmp dword ptr [rdx+08],0002DBFA
  je redWalletUpdateCapture
  cmp dword ptr [rdx+08],0002DBF2
  je redWalletUpdateCapture
  cmp dword ptr [rdx+08],0002DC0B
  je redWalletUpdateCapture
  cmp dword ptr [rdx+08],0002DC03
  jne redWalletUpdateDone
redWalletUpdateCapture:
  mov [redWalletUpdateCandidate],rcx
  inc qword ptr [redWalletCaptures]
redWalletUpdateDone:
  popfq
  push rbp
  push rdi
  push r13
  jmp %X

redWalletHook:
  pushfq
  mov [redWalletGetterCandidate],rcx
  inc qword ptr [redWalletCaptures]
  popfq
  movsxd r8,dword ptr [rcx+00000220]
  jmp %X

align 8 CC
redWalletOwner:
  dq 0
redWalletGetterCandidate:
  dq 0
redWalletUpdateCandidate:
  dq 0
redWalletSpendCandidate:
  dq 0
redWalletCaptures:
  dq 0
redWalletState:
  dd 0
redWalletSource:
  dd 0
redWalletRecordCount:
  dd 0
redCurrencyCredits:
  dd FFFFFFFF
redCurrencyKeycodes:
  dd FFFFFFFF
redCurrencyContraband:
  dd FFFFFFFF
redCurrencyElectronics:
  dd FFFFFFFF
redCurrencySecurityIds:
  dd FFFFFFFF
redCurrencySouvenirs:
  dd FFFFFFFF
redCurrencySamples:
  dd FFFFFFFF

align 8 CC
redNoDamage:
  db 01
redOneHitKill:
  db 00
align 8 CC
redPlayerVtable:
  dq %X
redHealthComponent:
  dq 0
redNoDamageBlocks:
  dq 0
redOneHitComponent:
  dq 0
redOneHitEvents:
  dq 0
redOneHitPreviousHealth:
  dd 0
redOneHitProposedHealth:
  dd 0

%X:
  jmp redHealthHook
  nop 3

%X:
  jmp redPickupHook

%X:
  jmp redWalletHook
  nop 2

%X:
  jmp redWalletUpdateHook

%X:
  jmp redWalletSpendHook
]], RDT.healthWrite,
    RDT.pickupEntry,
    RDT.walletGetter,
    RDT.outerOffset,
    RDT.healthOffset,
    RDT.healthOffset,
    RDT.healthOffset,
    RDT.healthOffset,
    RDT.healthOffset,
    RDT.healthWrite + #RDT.healthOriginalCode,
    RDT.pickupEntry + #RDT.pickupOriginalCode,
    RDT.walletSpend + #RDT.walletSpendOriginalCode,
    RDT.walletUpdate + #RDT.walletUpdateOriginalCode,
    RDT.walletGetter + #RDT.walletGetterOriginalCode,
    RDT.playerVtable,
    RDT.healthWrite,
    RDT.pickupEntry,
    RDT.walletGetter,
    RDT.walletUpdate,
    RDT.walletSpend)

if not autoAssemble(hookScript) then
  error('REDACTED: trainer hook installation failed')
end

RDT.healthHook = getAddressSafe('redHealthHook')
RDT.noDamage = getAddressSafe('redNoDamage')
RDT.oneHitKill = getAddressSafe('redOneHitKill')
RDT.healthComponent = getAddressSafe('redHealthComponent')
RDT.blockCounter = getAddressSafe('redNoDamageBlocks')
RDT.oneHitComponent = getAddressSafe('redOneHitComponent')
RDT.oneHitEvents = getAddressSafe('redOneHitEvents')
RDT.oneHitPreviousHealth = getAddressSafe('redOneHitPreviousHealth')
RDT.oneHitProposedHealth = getAddressSafe('redOneHitProposedHealth')
RDT.pickupHook = getAddressSafe('redPickupHook')
RDT.pickupMultiplier = getAddressSafe('redPickupMultiplier')
RDT.pickupEvents = getAddressSafe('redPickupEvents')
RDT.pickupBaseAmount = getAddressSafe('redPickupBaseAmount')
RDT.pickupFinalAmount = getAddressSafe('redPickupFinalAmount')
RDT.walletHook = getAddressSafe('redWalletHook')
RDT.walletUpdateHook = getAddressSafe('redWalletUpdateHook')
RDT.walletSpendHook = getAddressSafe('redWalletSpendHook')
RDT.walletOwner = getAddressSafe('redWalletOwner')
RDT.walletGetterCandidate = getAddressSafe('redWalletGetterCandidate')
RDT.walletUpdateCandidate = getAddressSafe('redWalletUpdateCandidate')
RDT.walletSpendCandidate = getAddressSafe('redWalletSpendCandidate')
RDT.walletCaptures = getAddressSafe('redWalletCaptures')
RDT.walletState = getAddressSafe('redWalletState')
RDT.walletSource = getAddressSafe('redWalletSource')
RDT.walletRecordCount = getAddressSafe('redWalletRecordCount')
for _, currency in ipairs(RDT.currencies) do
  currency.address = getAddressSafe(currency.symbol)
end

local function ownsNearJump(address, target)
  if not valid(address) or not valid(target) then
    return false
  end
  if readBytes(address, 1, false) ~= 0xE9 then return false end
  local relative = signed32(readInteger(address + 1))
  return address + 5 + relative == target
end

local function ownsHealthPatch()
  return RDT and ownsNearJump(RDT.healthWrite, RDT.healthHook)
end

local function ownsPickupPatch()
  return RDT and ownsNearJump(RDT.pickupEntry, RDT.pickupHook)
end

local function ownsWalletPatch()
  return RDT and ownsNearJump(RDT.walletGetter, RDT.walletHook)
end

local function ownsWalletUpdatePatch()
  return RDT and ownsNearJump(RDT.walletUpdate, RDT.walletUpdateHook)
end

local function ownsWalletSpendPatch()
  return RDT and ownsNearJump(RDT.walletSpend, RDT.walletSpendHook)
end

local function removeDynamicRecords()
  local list = getAddressList()
  for i = list.Count - 1, 0, -1 do
    local record = list[i]
    if record and tostring(record.Description):match('^REDACTED:') then
      record.OnValueChangedByUser = nil
      record.destroy()
    end
  end
end

function RedactedTrainerStop(restoreCode)
  local sameProcess = RDT and getOpenedProcessID() == RDT.processId
  if RDT and RDT.walletTimer then
    pcall(function() RDT.walletTimer.destroy() end)
    RDT.walletTimer = nil
  end
  if sameProcess and restoreCode and ownsHealthPatch() then
    pcall(function()
      putBytes(RDT.healthWrite, RDT.healthOriginalCode)
    end)
  end
  if sameProcess and restoreCode and ownsPickupPatch() then
    pcall(function()
      putBytes(RDT.pickupEntry, RDT.pickupOriginalCode)
    end)
  end
  if sameProcess and restoreCode and ownsWalletPatch() then
    pcall(function()
      putBytes(RDT.walletGetter, RDT.walletGetterOriginalCode)
    end)
  end
  if sameProcess and restoreCode and ownsWalletUpdatePatch() then
    pcall(function()
      putBytes(RDT.walletUpdate, RDT.walletUpdateOriginalCode)
    end)
  end
  if sameProcess and restoreCode and ownsWalletSpendPatch() then
    pcall(function()
      putBytes(RDT.walletSpend, RDT.walletSpendOriginalCode)
    end)
  end

  pcall(removeDynamicRecords)
  if sameProcess then
    pcall(function()
      autoAssemble([[
unregistersymbol(redNoDamageBlocks)
unregistersymbol(redHealthComponent)
unregistersymbol(redPlayerVtable)
unregistersymbol(redOneHitProposedHealth)
unregistersymbol(redOneHitPreviousHealth)
unregistersymbol(redOneHitEvents)
unregistersymbol(redOneHitComponent)
unregistersymbol(redOneHitKill)
unregistersymbol(redNoDamage)
unregistersymbol(redHealthHook)
unregistersymbol(redTrainerMem)
unregistersymbol(redPickupFinalAmount)
unregistersymbol(redPickupBaseAmount)
unregistersymbol(redPickupEvents)
unregistersymbol(redPickupMultiplier)
unregistersymbol(redPickupHook)
unregistersymbol(redPickupMem)
unregistersymbol(redCurrencySamples)
unregistersymbol(redCurrencySouvenirs)
unregistersymbol(redCurrencySecurityIds)
unregistersymbol(redCurrencyElectronics)
unregistersymbol(redCurrencyContraband)
unregistersymbol(redCurrencyKeycodes)
unregistersymbol(redCurrencyCredits)
unregistersymbol(redWalletRecordCount)
unregistersymbol(redWalletState)
unregistersymbol(redWalletSource)
unregistersymbol(redWalletCaptures)
unregistersymbol(redWalletUpdateCandidate)
unregistersymbol(redWalletGetterCandidate)
unregistersymbol(redWalletSpendCandidate)
unregistersymbol(redWalletOwner)
unregistersymbol(redWalletSpendHook)
unregistersymbol(redWalletUpdateHook)
unregistersymbol(redWalletHook)
unregistersymbol(redWalletMem)
dealloc(redTrainerMem)
dealloc(redPickupMem)
dealloc(redWalletMem)
]])
    end)
  else
    pcall(function()
      for _, symbol in ipairs({
          'redNoDamageBlocks', 'redHealthComponent', 'redPlayerVtable',
          'redOneHitProposedHealth', 'redOneHitPreviousHealth',
          'redOneHitEvents', 'redOneHitComponent', 'redOneHitKill',
          'redNoDamage', 'redHealthHook', 'redTrainerMem',
          'redPickupFinalAmount', 'redPickupBaseAmount', 'redPickupEvents',
          'redPickupMultiplier', 'redPickupHook', 'redPickupMem',
          'redCurrencySamples', 'redCurrencySouvenirs',
          'redCurrencySecurityIds', 'redCurrencyElectronics',
          'redCurrencyContraband', 'redCurrencyKeycodes',
          'redCurrencyCredits', 'redWalletRecordCount', 'redWalletState',
          'redWalletSource', 'redWalletCaptures',
          'redWalletSpendCandidate', 'redWalletUpdateCandidate',
          'redWalletGetterCandidate', 'redWalletOwner',
          'redWalletSpendHook', 'redWalletUpdateHook', 'redWalletHook',
          'redWalletMem'}) do
        unregisterSymbol(symbol)
      end
    end)
  end
  RDT = nil
end

local function makeRecord(root, description, address, valueType)
  local record = getAddressList().createMemoryRecord()
  record.Description = description
  record.Address = address
  record.VarType = valueType
  record.ShowAsHex = false
  record.appendToEntry(root)
  RDT.records[#RDT.records + 1] = record
  return record
end

local function makeGroup(root, description)
  local record = getAddressList().createMemoryRecord()
  record.Description = description
  record.IsGroupHeader = true
  record.appendToEntry(root)
  RDT.records[#RDT.records + 1] = record
  return record
end

local function setCurrencyMirrorsUnavailable(state)
  writeInteger(RDT.walletState, state or 0)
  writeInteger(RDT.walletSource, 0)
  writeInteger(RDT.walletRecordCount, 0)
  for _, currency in ipairs(RDT.currencies) do
    writeInteger(currency.address, -1)
    if currency.record then
      currency.record.Description =
        'REDACTED: ' .. currency.name .. ' (unavailable)'
    end
  end
end

local function readWalletMetadata(owner)
  if not valid(owner) then return nil end
  local array = readPointer(owner + RDT.walletArrayOffset)
  local count = readInteger(owner + RDT.walletCountOffset)
  local capacity = readInteger(owner + RDT.walletCapacityOffset)
  if not count or not capacity or count < 0 or count > 512
      or capacity < count or capacity > 512
      or (count > 0 and not valid(array)) then
    return nil
  end
  return {array = array or 0, count = count, capacity = capacity}
end

local function inspectWallet(owner, byFname)
  local metadata = readWalletMetadata(owner)
  if not metadata then return nil end

  local totals = {}
  local found = {}
  for _, currency in ipairs(RDT.currencies) do
    totals[currency.key] = 0
    found[currency.key] = false
  end

  local validCurrencyCount = 0
  for index = 0, metadata.count - 1 do
    local record = metadata.array + index * RDT.walletRecordStride
    local fname = readInteger(record + 0x08)
    local fnameNumber = readInteger(record + 0x0C)
    local currency = fname and byFname[fname]
    if currency and fnameNumber == 0 then
      local asset = readPointer(record + 0x30)
      local assetVtable = valid(asset) and readPointer(asset) or nil
      local rawQuantity = readInteger(record + 0x10)
      local quantity = rawQuantity and signed32(rawQuantity) or nil
      if assetVtable == RDT.currencyAssetVtable
          and quantity and quantity >= 0 then
        local total = totals[currency.key] + quantity
        if total <= 0x7FFFFFFF then
          totals[currency.key] = total
          found[currency.key] = true
          validCurrencyCount = validCurrencyCount + 1
        end
      end
    end
  end

  return {
    owner = owner,
    array = metadata.array,
    count = metadata.count,
    totals = totals,
    found = found,
    validCurrencyCount = validCurrencyCount,
  }
end

local function refreshWallet()
  if not RDT then return end
  if getOpenedProcessID() ~= RDT.processId then
    if RDT.walletStatusRecord then
      RDT.walletStatusRecord.Description =
        'REDACTED: Currencies - process changed; reactivate trainer'
    end
    if RDT.walletTimer then RDT.walletTimer.Enabled = false end
    return
  end

  local byFname = {}
  for _, currency in ipairs(RDT.currencies) do
    byFname[currency.fname] = currency
  end

  local wallet, pendingWallet, source, pendingSource
  local candidates = {
    {slot = RDT.walletSpendCandidate, source = 3, name = 'spend'},
    {slot = RDT.walletUpdateCandidate, source = 2, name = 'update'},
    {slot = RDT.walletGetterCandidate, source = 1, name = 'getter'},
  }
  for _, candidate in ipairs(candidates) do
    local value = readPointer(candidate.slot)
    local candidateWallet = inspectWallet(value, byFname)
    if candidateWallet and candidateWallet.validCurrencyCount > 0 then
      wallet = candidateWallet
      source = candidate
      break
    elseif candidateWallet and not pendingWallet then
      pendingWallet = candidateWallet
      pendingSource = candidate
    elseif valid(value) then
      writeQword(candidate.slot, 0)
    end
  end

  wallet = wallet or pendingWallet
  source = source or pendingSource
  if not wallet then
    writeQword(RDT.walletOwner, 0)
    setCurrencyMirrorsUnavailable(0)
    if RDT.walletStatusRecord then
      RDT.walletStatusRecord.Description =
        'REDACTED: Currencies - waiting for wallet update/HUD event'
    end
    return
  end

  writeQword(RDT.walletOwner, wallet.owner)
  writeInteger(RDT.walletSource, source.source)
  writeInteger(RDT.walletRecordCount, wallet.count)

  if wallet.validCurrencyCount == 0 then
    writeInteger(RDT.walletState, 3)
    for _, currency in ipairs(RDT.currencies) do
      writeInteger(currency.address, -1)
      if currency.record then
        currency.record.Description =
          'REDACTED: ' .. currency.name .. ' (resolver waiting)'
      end
    end
    if RDT.walletStatusRecord then
      local captures = readQword(RDT.walletCaptures) or 0
      RDT.walletStatusRecord.Description = string.format(
        'REDACTED: Currencies - empty %s candidate; waiting for initialized currency event (%d captures)',
        source.name, captures)
    end
    return
  end

  writeInteger(RDT.walletState, 1)
  for _, currency in ipairs(RDT.currencies) do
    writeInteger(currency.address,
      wallet.found[currency.key] and wallet.totals[currency.key] or -1)
    if currency.record then
      currency.record.Description = 'REDACTED: ' .. currency.name ..
        (wallet.found[currency.key] and ' (current)' or ' (unavailable)')
    end
  end

  if RDT.walletStatusRecord then
    local captures = readQword(RDT.walletCaptures) or 0
    RDT.walletStatusRecord.Description = string.format(
      'REDACTED: Currencies - ready via %s (%d records, %d captures)',
      source.name, wallet.count, captures)
  end
end

local setupOk, setupError = pcall(function()
  removeDynamicRecords()
  local list = getAddressList()
  local root = list.getMemoryRecordByDescription(
    'REDACTED Trainer - Activate')
  if not root then
    root = list.createMemoryRecord()
    root.Description = 'REDACTED: Live Trainer Controls'
    root.IsGroupHeader = true
  end

  local currencyGroup = makeGroup(
    root, 'REDACTED: Currencies - waiting for wallet update/HUD event')
  RDT.walletStatusRecord = currencyGroup
  for _, currency in ipairs(RDT.currencies) do
    local balance = makeRecord(
      currencyGroup, 'REDACTED: ' .. currency.name .. ' (current)',
      currency.symbol, vtDword)
    balance.IsReadOnly = true
    balance.ShowAsSigned = true
    currency.record = balance
  end

  local walletCaptures = makeRecord(
    currencyGroup, 'REDACTED: Wallet resolver captures',
    'redWalletCaptures', vtQword)
  walletCaptures.IsReadOnly = true

  local toggle = makeRecord(
    root, 'REDACTED: No Damage', 'redNoDamage', vtByte)
  toggle.DropDownList.Text = '0:Disabled\n1:Enabled'
  toggle.DropDownReadOnly = true
  toggle.DropDownDescriptionOnly = true
  toggle.DisplayAsDropDownListItem = true
  toggle.Value = '1'

  local oneHitKill = makeRecord(
    root, 'REDACTED: One-Hit Kill', 'redOneHitKill', vtByte)
  oneHitKill.DropDownList.Text = '0:Disabled\n1:Enabled'
  oneHitKill.DropDownReadOnly = true
  oneHitKill.DropDownDescriptionOnly = true
  oneHitKill.DisplayAsDropDownListItem = true
  oneHitKill.Value = '0'

  local multiplier = makeRecord(
    root, 'REDACTED: Collected Item Multiplier',
    'redPickupMultiplier', vtDword)
  multiplier.Value = '100'
  multiplier.OnValueChangedByUser = function(_, _, newValue)
    local value = math.floor(tonumber(newValue) or 100)
    value = math.max(1, math.min(1000, value))
    writeInteger(RDT.pickupMultiplier, value)
  end

  local pickupEvents = makeRecord(
    root, 'REDACTED: Multiplied Item Awards',
    'redPickupEvents', vtQword)
  pickupEvents.IsReadOnly = true

  local basePickup = makeRecord(
    root, 'REDACTED: Last Base Item Amount',
    'redPickupBaseAmount', vtDword)
  basePickup.IsReadOnly = true

  local finalPickup = makeRecord(
    root, 'REDACTED: Last Multiplied Item Amount',
    'redPickupFinalAmount', vtDword)
  finalPickup.IsReadOnly = true

  local blocked = makeRecord(
    root, 'REDACTED: Blocked Health Decreases',
    'redNoDamageBlocks', vtQword)
  blocked.IsReadOnly = true

  local oneHitEvents = makeRecord(
    root, 'REDACTED: One-Hit Kills',
    'redOneHitEvents', vtQword)
  oneHitEvents.IsReadOnly = true

  local oneHitPrevious = makeRecord(
    root, 'REDACTED: Last Enemy Health Before Hit',
    'redOneHitPreviousHealth', vtSingle)
  oneHitPrevious.IsReadOnly = true

  local oneHitProposed = makeRecord(
    root, 'REDACTED: Last Enemy Health After Normal Damage',
    'redOneHitProposedHealth', vtSingle)
  oneHitProposed.IsReadOnly = true

  local health = makeRecord(
    root, 'REDACTED: Last Player Health',
    '[redHealthComponent]+190', vtSingle)
  health.IsReadOnly = true
end)

if not setupOk then
  RedactedTrainerStop(true)
  error('REDACTED: control setup failed: ' .. tostring(setupError))
end

RDT.walletTimer = createTimer(nil)
RDT.walletTimer.Interval = 1000
RDT.walletTimer.OnTimer = refreshWallet
refreshWallet()

print(string.format(
  '[REDACTED v%s] No Damage and x%d items active; wallet resolver armed; ' ..
    'One-Hit Kill is off',
  RDT.version, readInteger(RDT.pickupMultiplier) or 100))
