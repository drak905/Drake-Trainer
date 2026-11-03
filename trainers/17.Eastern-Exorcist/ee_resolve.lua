--[[ ------------------------------------------------------------------
  Eastern Exorcist - resolve player state via Mono metadata.

  Unity + Mono (mono-2.0-bdwgc.dll), so class layout is readable at runtime.
  Nothing here relies on scanning for a value; everything is found by class.

  Resolution chain:
    CapacityProp instances --> the one whose PropValueType == 1 is HP
                          --> PropValueType == 2 is EP (stamina)
    PlayerProperties (subclass of CharProperties)
                          --> validated by its Hp pointer matching the HP object
                          --> AttackBase, ToughnessBase
                          --> _adjustableProps : Dictionary<int, AdjustableProp>
                              key = EAdjustPropType (9 = TakeDamageFactor, etc.)
    ProtagRuntimeData     --> _level, _soul (a.k.a. "spiritual energy")
    GameGlobalConfig      --> level-up cost formula, enemy HP factors

  Terminology note: this game calls the player "Protagonist", entities "Unit",
  stamina "EP", and wraps stats in a generic CapacityProp that identifies itself
  through a type tag. No class contains the word "Health".

  Usage: attach Cheat Engine to EasternExorcist.exe, then
         File -> Execute Script (select this file).
------------------------------------------------------------------ ]]

-- ------------------------------------------------------------------ config
local ADD_TO_TABLE = true
local VERBOSE      = true

-- Multipliers to apply. nil = leave the game's value alone.
-- Applied to _baseValue; CurrValue is recomputed by the game from base + buffs,
-- so freezing base keeps the boost without blocking legitimate buffs.
local TAKE_DAMAGE_FACTOR = 0      -- 0 = immune to damage
local ATTACK_FACTOR      = 10
local SOUL_REWARD_FACTOR = 10
local MOVE_SPEED_FACTOR  = 2
local LIFE_STEAL_RATE    = nil

local FREE_LEVEL_UPS     = true   -- zero PlayerExpBase/Linear
local FREE_SKILL_NODES   = true   -- zero skill-node material requirements
local FREE_SKILL_SOUL    = false  -- also zero PriseInSoul / SkillPointCost
local ENEMY_HP_FACTOR    = nil    -- e.g. 0.1 to make all enemies frail

local FREEZE = true               -- freeze the applied values

-- --------------------------------------------------------------- offsets
local CAP = { type = 0x40, value = 0x44, follow = 0x48, capBase = 0x54 }
local CHR = { hp = 0x10, adjustable = 0x18, shield = 0x28,
              attackBase = 0x40, toughnessBase = 0x44 }
local PRD = { level = 0x148, soul = 0x14C, remainHp = 0x144, difficulty = 0x10C }
local ADJ = { baseValue = 0x20, currValue = 0x30, multiplyMode = 0x2C }
local DICT = { entries = 0x18, count = 0x40 }
local ARR_DATA, ENTRY_STRIDE, ENTRY_KEY, ENTRY_VAL = 0x20, 24, 8, 16
local GGC = { enemyHpEasy = 0x1E0, enemyHpNormal = 0x1EC, enemyHpHard = 0x1F8,
              nearDeath = 0x204, overSupplyBase = 0x2B0,
              expBase = 0x2BC, expLinear = 0x2C0, expPower = 0x2C4 }

local PROP_NAMES = { [0]="HpCapFactor","HpCapAdd","HpRecoveryAdd","EpCapFactor",
  "EpCapAdd","EpRecoveryAdd","StrengthAdd","ToughnessAdd","AttackFactor",
  "TakeDamageFactor","LifeStealRate","SoulRewardFactor","MoveSpeedFactor",
  "FatalAttackFactor","DodgeAttackFactor","BlockAttackFactor","AirAttackFactor",
  "FallAttackFactor","TakeHealFactor","PotionFactor","SlaughtAttackFactor" }

-- ------------------------------------------------------------------ helpers
local function log(...) if VERBOSE then print(...) end end
local function rf(a) local v = readFloat(a); return v end
local function ri(a) local v = readInteger(a); return v end
local function rq(a) local v = readQword(a); return v end

-- a pointer that could plausibly be a Mono heap object
local function sane(p) return p and p > 0x10000 and p < 0x7FF000000000 end

local function findImage(name)
  local asms = mono_enumAssemblies()
  if not asms then return nil end
  for _, a in ipairs(asms) do
    local img = mono_getImageFromAssembly(a)
    if img and mono_image_get_name(img) == name then return img end
  end
  return nil
end

local function findClass(img, wanted)
  local classes = mono_image_enumClasses(img)
  if not classes then return nil end
  for _, c in ipairs(classes) do
    if tostring(c.classname or "") == wanted then return c.class end
  end
  return nil
end

local function instances(img, name)
  local cls = findClass(img, name)
  if not cls then return {} end
  return mono_class_findInstancesOfClassListOnly(cls) or {}
end

-- ------------------------------------------------------------------ resolve
EE = EE or {}

function EEResolve()
  if mono_enumAssemblies == nil then
    return nil, "Mono functions unavailable in this Cheat Engine build"
  end
  if LaunchMonoDataCollector then LaunchMonoDataCollector() end
  local img = findImage("Assembly-CSharp")
  if not img then return nil, "Assembly-CSharp not found (is the game attached?)" end

  local r = { img = img, props = {} }

  -- HP / EP capacity props, identified by their own type tag
  for _, a in ipairs(instances(img, "CapacityProp")) do
    local ty  = ri(a + CAP.type)
    local cap = rf(a + CAP.capBase)
    if cap and cap > 0 and cap < 1e7 then
      if ty == 1 and not r.hp then r.hp = a end
      if ty == 2 and not r.ep then r.ep = a end
    end
  end

  -- PlayerProperties: validate by its Hp pointer matching the HP object
  for _, a in ipairs(instances(img, "PlayerProperties")) do
    local hp  = rq(a + CHR.hp)
    local atk = rf(a + CHR.attackBase)
    if hp and r.hp and hp == r.hp and atk and atk > 0 and atk < 1e6 then
      r.charProps = a
    end
  end

  -- adjustable property dictionary -> { [name] = AdjustableProp address }
  if r.charProps then
    local dict = rq(r.charProps + CHR.adjustable)
    if sane(dict) then
      local entries, count = rq(dict + DICT.entries), ri(dict + DICT.count)
      if sane(entries) and count and count > 0 and count < 256 then
        for i = 0, count - 1 do
          local e   = entries + ARR_DATA + i * ENTRY_STRIDE
          local key = ri(e + ENTRY_KEY)
          local val = rq(e + ENTRY_VAL)
          if key and PROP_NAMES[key] and sane(val) then
            r.props[PROP_NAMES[key]] = val
          end
        end
      end
    end
  end

  -- ProtagRuntimeData: keep every plausible copy (this game holds several)
  r.runtime = {}
  for _, a in ipairs(instances(img, "ProtagRuntimeData")) do
    local lvl, soul = ri(a + PRD.level), ri(a + PRD.soul)
    if lvl and soul and lvl >= 1 and lvl <= 999 and soul >= 0 and soul < 1e8 then
      r.runtime[#r.runtime + 1] = a
    end
  end

  -- GameGlobalConfig singleton
  local ggc = instances(img, "GameGlobalConfig")
  r.config = ggc[1]

  if not r.hp then return nil, "HP CapacityProp not found (in a level?)" end
  return r, "ok"
end

-- ------------------------------------------------------------------- apply
local function setProp(name, value)
  local a = EE.props and EE.props[name]
  if not a or value == nil then return nil end
  local before = rf(a + ADJ.baseValue)
  writeFloat(a + ADJ.baseValue, value)
  writeFloat(a + ADJ.currValue, value)
  return string.format("%s %s->%s", name, tostring(before), tostring(rf(a + ADJ.baseValue)))
end

function EESoul(value)
  if not EE.runtime then return "not resolved" end
  local outs = {}
  for _, a in ipairs(EE.runtime) do
    local b = ri(a + PRD.soul)
    if value ~= nil then writeInteger(a + PRD.soul, value) end
    outs[#outs + 1] = string.format("%X:%s%s", a, tostring(b),
      value ~= nil and ("->" .. tostring(ri(a + PRD.soul))) or "")
  end
  return table.concat(outs, ", ")
end

-- --------------------------------------------------------------- skill tree
-- SkillNodeData holds four separate material requirements. The suffixes are
-- transliterated Chinese:
--   UnlockItemAmount          generic item
--   UnlockItemAmount_CanPian  残片  fragment
--   UnlockItemAmount_JieKuai  结块  nugget   <- "nugget of spirituality"
--   UnlockItemAmount_JieJing  结晶  crystal
-- Zeroing these is far safer than granting the items: the inventory is a live
-- Dictionary<int,StoryItem> and inserting an entry means allocating an object
-- and fixing up hash buckets.
local SND = { itemAmount = 0x30, canPian = 0x34, jieKuai = 0x38, jieJing = 0x3C,
              skillId = 0x40, pointCost = 0x44, priseInSoul = 0x48 }

function EESkillNodes(zeroMaterials, zeroSoul)
  local img = findImage("Assembly-CSharp")
  if not img then return "Assembly-CSharp not found" end
  local insts = instances(img, "SkillNodeData")
  local patched, skipped, hadReq = 0, 0, 0
  for _, a in ipairs(insts) do
    local id   = ri(a + SND.skillId)
    local amt  = ri(a + SND.itemAmount)
    local cp   = ri(a + SND.canPian)
    local jk   = ri(a + SND.jieKuai)
    local jj   = ri(a + SND.jieJing)
    local soul = ri(a + SND.priseInSoul)
    local pc   = ri(a + SND.pointCost)
    -- reject garbage instances before writing anything
    local ok = id and id >= 0 and id < 100000
      and amt and amt >= 0 and amt < 1000
      and cp  and cp  >= 0 and cp  < 1000
      and jk  and jk  >= 0 and jk  < 1000
      and jj  and jj  >= 0 and jj  < 1000
      and soul and soul >= 0 and soul < 10000000
      and pc  and pc  >= 0 and pc  < 1000
    if ok then
      if (amt + cp + jk + jj) > 0 then hadReq = hadReq + 1 end
      if zeroMaterials then
        writeInteger(a + SND.itemAmount, 0)
        writeInteger(a + SND.canPian,    0)
        writeInteger(a + SND.jieKuai,    0)
        writeInteger(a + SND.jieJing,    0)
      end
      if zeroSoul then
        writeInteger(a + SND.priseInSoul, 0)
        writeInteger(a + SND.pointCost,   0)
      end
      patched = patched + 1
    else
      skipped = skipped + 1
    end
  end
  return string.format("nodes=%d patched=%d skipped=%d hadRequirements=%d",
    #insts, patched, skipped, hadReq)
end

local info, how = EEResolve()if not info then
  print("[EE] FAILED: " .. tostring(how))
  return
end
EE = info

log(string.format("[EE] hp=%X ep=%s charProps=%s config=%s runtimeCopies=%d props=%d",
  EE.hp, EE.ep and string.format("%X", EE.ep) or "nil",
  EE.charProps and string.format("%X", EE.charProps) or "nil",
  EE.config and string.format("%X", EE.config) or "nil",
  #EE.runtime, (function() local n = 0; for _ in pairs(EE.props) do n = n + 1 end; return n end)()))
log(string.format("[EE]   HP=%s/%s EP=%s/%s attack=%s",
  tostring(rf(EE.hp + CAP.value)), tostring(rf(EE.hp + CAP.capBase)),
  EE.ep and tostring(rf(EE.ep + CAP.value)) or "-",
  EE.ep and tostring(rf(EE.ep + CAP.capBase)) or "-",
  EE.charProps and tostring(rf(EE.charProps + CHR.attackBase)) or "-"))
if EE.runtime[1] then
  log(string.format("[EE]   level=%s soul=%s",
    tostring(ri(EE.runtime[1] + PRD.level)), tostring(ri(EE.runtime[1] + PRD.soul))))
end

for _, s in ipairs({
  setProp("TakeDamageFactor", TAKE_DAMAGE_FACTOR),
  setProp("AttackFactor",     ATTACK_FACTOR),
  setProp("SoulRewardFactor", SOUL_REWARD_FACTOR),
  setProp("MoveSpeedFactor",  MOVE_SPEED_FACTOR),
  setProp("LifeStealRate",    LIFE_STEAL_RATE),
}) do log("[EE]   " .. s) end

if EE.config then
  if FREE_LEVEL_UPS then    writeFloat(EE.config + GGC.expBase, 0)
    writeFloat(EE.config + GGC.expLinear, 0)
    log("[EE]   level-up cost zeroed")
  end
  if ENEMY_HP_FACTOR then
    writeFloat(EE.config + GGC.enemyHpEasy,   ENEMY_HP_FACTOR)
    writeFloat(EE.config + GGC.enemyHpNormal, ENEMY_HP_FACTOR)
    writeFloat(EE.config + GGC.enemyHpHard,   ENEMY_HP_FACTOR)
    log("[EE]   enemy HP factor -> " .. tostring(ENEMY_HP_FACTOR))
  end
end

if FREE_SKILL_NODES or FREE_SKILL_SOUL then
  log("[EE]   skill nodes: " .. tostring(EESkillNodes(FREE_SKILL_NODES, FREE_SKILL_SOUL)))
end

-- ------------------------------------------------------------------ symbols
local syms = {
  eeHpObj = EE.hp, eeHp = EE.hp + CAP.value, eeMaxHp = EE.hp + CAP.capBase,
}
if EE.ep then
  syms.eeEpObj = EE.ep; syms.eeEp = EE.ep + CAP.value
  syms.eeMaxEp = EE.ep + CAP.capBase
end
if EE.charProps then
  syms.eeCharProps = EE.charProps
  syms.eeAttack = EE.charProps + CHR.attackBase
  syms.eeToughness = EE.charProps + CHR.toughnessBase
end
if EE.runtime[1] then
  syms.eeRuntime = EE.runtime[1]
  syms.eeLevel = EE.runtime[1] + PRD.level
  syms.eeSoul = EE.runtime[1] + PRD.soul
end
if EE.config then syms.eeGameConfig = EE.config end
for n, a in pairs(syms) do unregisterSymbol(n); registerSymbol(n, a, true) end

-- ------------------------------------------------------------- cheat table
if ADD_TO_TABLE then
  local al = getAddressList()
  for i = al.Count - 1, 0, -1 do
    local rec = al[i]
    if rec and tostring(rec.Description):match("^EE: ") then rec.destroy() end
  end
  local function put(desc, addr, vt, freezeVal)
    local rec = al.createMemoryRecord()
    rec.Description = desc
    rec.Address = string.format("%X", addr)
    rec.Type = vt
    if freezeVal ~= nil and FREEZE then
      rec.Value = tostring(freezeVal); rec.Active = true
    end
    return rec
  end

  put("EE: HP",          EE.hp + CAP.value,   vtSingle)
  put("EE: Max HP",      EE.hp + CAP.capBase, vtSingle)
  if EE.ep then
    put("EE: Stamina (EP)", EE.ep + CAP.value,   vtSingle)
    put("EE: Max Stamina",  EE.ep + CAP.capBase, vtSingle)
  end
  if EE.charProps then
    put("EE: Attack",    EE.charProps + CHR.attackBase,    vtSingle)
    put("EE: Toughness", EE.charProps + CHR.toughnessBase, vtSingle)
  end
  for i, a in ipairs(EE.runtime) do
    local tag = (i == 1) and "" or string.format(" [copy %d]", i)
    put("EE: Level" .. tag, a + PRD.level, vtDword)
    put("EE: Soul (spiritual energy)" .. tag, a + PRD.soul, vtDword)
  end
  -- adjustable properties: freeze only the ones we deliberately set.
  -- MoveSpeedFactor is deliberately NOT frozen so it can be tuned by hand in
  -- the table without CE reverting the edit.
  local frozenVals = {
    TakeDamageFactor = TAKE_DAMAGE_FACTOR,
    AttackFactor     = ATTACK_FACTOR,
    SoulRewardFactor = SOUL_REWARD_FACTOR,
    LifeStealRate    = LIFE_STEAL_RATE,
  }
  local friendly = {
    MoveSpeedFactor  = "EE: Move Speed multiplier  (1=normal, 2=2x, 3=3x)",
    AttackFactor     = "EE: Attack multiplier",
    TakeDamageFactor = "EE: Damage Taken multiplier (0=immune)",
    SoulRewardFactor = "EE: Soul gain multiplier",
  }
  for name, a in pairs(EE.props) do
    local baseDesc = friendly[name] or ("EE: [prop] " .. name .. " (base)")
    put(baseDesc, a + ADJ.baseValue, vtSingle, frozenVals[name])
    put("EE: [prop] " .. name .. " (curr)", a + ADJ.currValue, vtSingle,
        (name == "TakeDamageFactor") and TAKE_DAMAGE_FACTOR or nil)
  end
  if EE.config then
    put("EE: [cfg] LevelUp Cost Base",   EE.config + GGC.expBase,   vtSingle,
        FREE_LEVEL_UPS and 0 or nil)
    put("EE: [cfg] LevelUp Cost Linear", EE.config + GGC.expLinear, vtSingle,
        FREE_LEVEL_UPS and 0 or nil)
    put("EE: [cfg] LevelUp Cost Power",  EE.config + GGC.expPower,  vtSingle)
    put("EE: [cfg] Enemy HP Factor Easy",   EE.config + GGC.enemyHpEasy,   vtSingle)
    put("EE: [cfg] Enemy HP Factor Normal", EE.config + GGC.enemyHpNormal, vtSingle)
    put("EE: [cfg] Enemy HP Factor Hard",   EE.config + GGC.enemyHpHard,   vtSingle)
    put("EE: [cfg] NearDeathPercent",       EE.config + GGC.nearDeath,     vtSingle)
    put("EE: [cfg] OverSupplyCost Base",    EE.config + GGC.overSupplyBase, vtSingle)
  end
  log("[EE] cheat table rebuilt: " .. al.Count .. " entries")
end

print("[EE] done. Re-run after a restart, or if values read wrong.")
print("[EE] helpers: EESoul(99999) | EEResolve() | EE.props table")
