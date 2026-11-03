--[[ ------------------------------------------------------------------
  Jotun - resolve the player Pawn via Mono metadata.

  Jotun is Unity + Mono, so the game's class layout is readable at runtime.
  Rather than scanning for a health value (impossible: the HUD is a bar with
  no numbers), we read the Pawn class definition and follow a live reference:

      PlayerHealthBar instance --(_pawn @ 0x38)--> Pawn
                                                   _maxHealth  @ 0x50  float
                                                   _health     @ 0x58  float
                                                   _damage     @ 0x5C  float
                                                   _isInvulnerable @ 0x60 int32
                                                   _recievedDamageModifier @ 0x68 float

  Field offsets are fixed by the compiled assembly, so only the instance
  lookup has to be redone. Run this after attaching to Jotun.exe, or after
  any restart / new area load if addresses go stale.

  Usage in Cheat Engine:
      File -> Execute Script   -- or dofile with a long-bracket path string

  It registers symbols so you can type them anywhere CE accepts an address:
      jotunHealth, jotunMaxHealth, jotunDamage, jotunInvuln, jotunDmgTakenMul
  and optionally adds them to the address list.
------------------------------------------------------------------ ]]

local ADD_TO_TABLE = true   -- also create cheat-table entries
local VERBOSE      = true

-- Pawn field offsets (from the Mono metadata; stable for this game build)
local OFF = {
  maxHealth      = 0x50,   -- float
  health         = 0x58,   -- float
  damage         = 0x5C,   -- float
  isInvulnerable = 0x60,   -- int32
  dmgTakenMul    = 0x68,   -- float
}
local PAWN_REF_IN_HEALTHBAR = 0x38   -- HealthBar._pawn

local function log(...)
  if VERBOSE then print(...) end
end

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

-- Resolve the player's Pawn address. Returns address or nil, plus a message.
function JotunFindPlayerPawn()
  if mono_enumAssemblies == nil then
    return nil, "Mono functions unavailable - is this build of CE Mono-capable?"
  end
  -- Safe to call repeatedly; needed after re-attaching.
  if LaunchMonoDataCollector then LaunchMonoDataCollector() end

  local img = findImage("Assembly-CSharp")
  if not img then return nil, "Assembly-CSharp not found (is Jotun attached?)" end

  -- Preferred: PlayerHealthBar._pawn
  local phb = findClass(img, "PlayerHealthBar")
  if phb then
    local insts = mono_class_findInstancesOfClassListOnly(phb) or {}
    for _, inst in ipairs(insts) do
      local pawn = readQword(inst + PAWN_REF_IN_HEALTHBAR)
      if pawn and pawn ~= 0 then
        local mx = readFloat(pawn + OFF.maxHealth)
        if mx and mx > 0 then
          return pawn, string.format("via PlayerHealthBar %X", inst)
        end
      end
    end
  end

  -- Fallback: enumerate Pawns and pick the one the player health bar tracks,
  -- or failing that the one with the lowest health fraction (likely the player
  -- after taking damage). This is a heuristic - prefer the path above.
  local pawnCls = findClass(img, "Pawn")
  if not pawnCls then return nil, "Pawn class not found" end
  local list = mono_class_findInstancesOfClassListOnly(pawnCls) or {}
  local best, bestFrac = nil, nil
  for _, addr in ipairs(list) do
    local hp = readFloat(addr + OFF.health)
    local mx = readFloat(addr + OFF.maxHealth)
    if hp and mx and mx > 0 then
      local frac = hp / mx
      if frac < 1.0 and (bestFrac == nil or frac < bestFrac) then
        best, bestFrac = addr, frac
      end
    end
  end
  if best then
    return best, string.format("heuristic: lowest health fraction %.3f (verify!)", bestFrac)
  end
  return nil, string.format("no candidate found among %d Pawn instances", #list)
end

local pawn, how = JotunFindPlayerPawn()
if not pawn then
  print("[Jotun] FAILED: " .. tostring(how))
  return
end

log(string.format("[Jotun] player Pawn = %X  (%s)", pawn, how))
log(string.format("[Jotun]   health   = %s / %s",
  tostring(readFloat(pawn + OFF.health)), tostring(readFloat(pawn + OFF.maxHealth))))
log(string.format("[Jotun]   damage   = %s", tostring(readFloat(pawn + OFF.damage))))
log(string.format("[Jotun]   invuln   = %s", tostring(readInteger(pawn + OFF.isInvulnerable))))
log(string.format("[Jotun]   dmgTaken = %s", tostring(readFloat(pawn + OFF.dmgTakenMul))))

-- Register symbols so the names work anywhere CE takes an address
local SYMS = {
  jotunPawn        = pawn,
  jotunMaxHealth   = pawn + OFF.maxHealth,
  jotunHealth      = pawn + OFF.health,
  jotunDamage      = pawn + OFF.damage,
  jotunInvuln      = pawn + OFF.isInvulnerable,
  jotunDmgTakenMul = pawn + OFF.dmgTakenMul,
}
for name, addr in pairs(SYMS) do
  unregisterSymbol(name)          -- ignore failure on first run
  registerSymbol(name, addr, true)
end
log("[Jotun] symbols registered: jotunHealth, jotunMaxHealth, jotunDamage, jotunInvuln, jotunDmgTakenMul")

if ADD_TO_TABLE then
  local al = getAddressList()
  local function upsert(desc, addr, vt)
    -- replace an existing entry with the same description so re-running
    -- refreshes addresses instead of piling up duplicates
    for i = al.Count - 1, 0, -1 do
      local r = al[i]
      if r and r.Description == desc then r.destroy() end
    end
    local rec = al.createMemoryRecord()
    rec.Description = desc
    rec.Address = string.format("%X", addr)
    rec.Type = vt
    return rec
  end
  upsert("Jotun: Health",              SYMS.jotunHealth,      vtSingle)
  upsert("Jotun: Max Health",          SYMS.jotunMaxHealth,   vtSingle)
  upsert("Jotun: Damage dealt",        SYMS.jotunDamage,      vtSingle)
  local inv = upsert("Jotun: Invulnerable (1=on)", SYMS.jotunInvuln, vtDword)
  upsert("Jotun: Damage taken mult",   SYMS.jotunDmgTakenMul, vtSingle)

  -- Freeze invulnerability. The game clears _isInvulnerable on run restarts and
  -- area transitions, so a one-off write does not stick; CE's freeze reasserts
  -- it continuously. (Note: CE's freeze runs on the main thread, so calling
  -- sleep() from a script will stall it and make it look broken.)
  if inv then
    inv.Value = "1"
    inv.Active = true
    log("[Jotun] invulnerability frozen via cheat-table entry")
  end
  log("[Jotun] cheat table entries refreshed")
end

-- ---------------------------------------------------------------- god powers
-- BaseGodPower._numberOfCharges @ 0x2C (Int32). Seven subclasses exist:
-- Lance, Thunder, Sacrifice(SPEED), Decoy, Revive, Healing, Shield.
-- Set GODPOWER_CHARGES to a number to top them all up, or nil to only report.
local GODPOWER_CHARGES = 99
local FREEZE_GODPOWERS = true    -- freeze so charges never deplete

function JotunGodPowers(setTo)
  local img = findImage("Assembly-CSharp")
  if not img then return "Assembly-CSharp not found" end
  local bgp = findClass(img, "BaseGodPower")
  if not bgp then return "BaseGodPower class not found" end
  local insts = mono_class_findInstancesOfClassListOnly(bgp) or {}
  local lines = {}
  local al = FREEZE_GODPOWERS and getAddressList() or nil
  for _, addr in ipairs(insts) do
    local cls = mono_object_getClass(addr)
    local cn = cls and mono_class_getName(cls) or "?"
    local before = readInteger(addr + 0x2C)
    if setTo ~= nil then writeInteger(addr + 0x2C, setTo) end
    lines[#lines+1] = string.format("%s=%s%s", cn, tostring(before),
      setTo ~= nil and ("->" .. tostring(readInteger(addr + 0x2C))) or "")
    -- freeze each power's charge count via a cheat-table entry
    if al and setTo ~= nil then
      local desc = "Jotun: GodPower " .. tostring(cn)
      for i = al.Count - 1, 0, -1 do
        local r = al[i]
        if r and r.Description == desc then r.destroy() end
      end
      local rec = al.createMemoryRecord()
      rec.Description = desc
      rec.Address = string.format("%X", addr + 0x2C)
      rec.Type = vtDword
      rec.Value = tostring(setTo)
      rec.Active = true
    end
  end
  return table.concat(lines, ", "), #insts
end

local gpInfo, gpCount = JotunGodPowers(GODPOWER_CHARGES)
log(string.format("[Jotun] god powers (%s): %s", tostring(gpCount), tostring(gpInfo)))

-- ---------------------------------------------------------------- move speed
-- PlayerMoveBehaviour inherits MoveBehaviour._speed @ 0xC8 (float).
-- The stock value for Jotun's player is 4.3. _speedModifier @ 0xD8 exists but
-- changing it had no observable effect, so we set the base speed instead.
--
-- SPEED_MULT is applied to BASE_SPEED (not to the current value) so re-running
-- this script never compounds the boost. Set SPEED_MULT = nil to leave alone.
local BASE_SPEED  = 4.3
local SPEED_MULT  = 4.0
local FREEZE_SPEED = true

local OFF_SPEED     = 0xC8
local OFF_SPEEDMOD  = 0xD8

function JotunMoveSpeed(mult)
  local img = findImage("Assembly-CSharp")
  if not img then return nil, "Assembly-CSharp not found" end
  local cls = findClass(img, "PlayerMoveBehaviour")
  if not cls then return nil, "PlayerMoveBehaviour not found" end
  local insts = mono_class_findInstancesOfClassListOnly(cls) or {}
  if not insts[1] then return nil, "no PlayerMoveBehaviour instance" end
  local addr = insts[1]
  local before = readFloat(addr + OFF_SPEED)
  if mult ~= nil then writeFloat(addr + OFF_SPEED, BASE_SPEED * mult) end
  return addr, string.format("speed %s -> %s (mod=%s)", tostring(before),
    tostring(readFloat(addr + OFF_SPEED)), tostring(readFloat(addr + OFF_SPEEDMOD)))
end

local mvAddr, mvInfo = JotunMoveSpeed(SPEED_MULT)
if mvAddr then
  log("[Jotun] move speed: " .. tostring(mvInfo))
  unregisterSymbol("jotunMoveSpeed")
  registerSymbol("jotunMoveSpeed", mvAddr + OFF_SPEED, true)
  if ADD_TO_TABLE then
    local al = getAddressList()
    local desc = "Jotun: Move Speed"
    for i = al.Count - 1, 0, -1 do
      local r = al[i]
      if r and r.Description == desc then r.destroy() end
    end
    local rec = al.createMemoryRecord()
    rec.Description = desc
    rec.Address = string.format("%X", mvAddr + OFF_SPEED)
    rec.Type = vtSingle
    if FREEZE_SPEED then
      rec.Value = tostring(BASE_SPEED * (SPEED_MULT or 1))
      rec.Active = true
    end
  end
else
  log("[Jotun] move speed: " .. tostring(mvInfo))
end

-- ------------------------------------------------------------- attack damage
-- AttackBehaviour._damage @ 0xD8 (float) is inherited by the player's attack
-- behaviours. Stock values: normal 10, charged 55, roll/dodge 10.
--
-- These persist across area changes (verified in play), so they are NOT frozen
-- - the script just re-applies them. Set ATTACK_DAMAGE = nil to leave stock.
--
-- Attack SPEED is not adjustable here: the attack cooldown is already 0 and
-- _releaseTime (PlayerAttackBehaviour @ 0xF0) had no observable effect. Jotun
-- gates attack rate on animation length, so only a global speedhack changes it.
local ATTACK_DAMAGE      = 100    -- normal attack
local CHARGED_DAMAGE     = 100    -- charged attack
local ROLL_DAMAGE        = nil    -- dodge/roll attack (nil = leave stock)

local OFF_DAMAGE = 0xD8

function JotunAttackDamage(normal, charged, roll)
  local img = findImage("Assembly-CSharp")
  if not img then return "Assembly-CSharp not found" end
  local spec = {
    { cls = "PlayerAttackBehaviour",        val = normal,  label = "normal"  },
    { cls = "PlayerChargedAttackBehaviour", val = charged, label = "charged" },
    { cls = "PlayerRollBehaviour",          val = roll,    label = "roll"    },
  }
  local lines = {}
  for _, s in ipairs(spec) do
    local cls = findClass(img, s.cls)
    local insts = cls and mono_class_findInstancesOfClassListOnly(cls) or {}
    if insts[1] then
      local addr = insts[1]
      local before = readFloat(addr + OFF_DAMAGE)
      if s.val ~= nil then writeFloat(addr + OFF_DAMAGE, s.val) end
      lines[#lines+1] = string.format("%s=%s%s", s.label, tostring(before),
        s.val ~= nil and ("->" .. tostring(readFloat(addr + OFF_DAMAGE))) or "")
      -- expose a symbol for each
      local sym = "jotunDmg" .. s.label:sub(1,1):upper() .. s.label:sub(2)
      unregisterSymbol(sym)
      registerSymbol(sym, addr + OFF_DAMAGE, true)
      -- editable cheat-table entry (NOT frozen: these persist across areas,
      -- and freezing would block any legitimate buff the game grants)
      if ADD_TO_TABLE then
        local al = getAddressList()
        local desc = "Jotun: Damage " .. s.label
        for i = al.Count - 1, 0, -1 do
          local r = al[i]
          if r and r.Description == desc then r.destroy() end
        end
        local rec = al.createMemoryRecord()
        rec.Description = desc
        rec.Address = string.format("%X", addr + OFF_DAMAGE)
        rec.Type = vtSingle
      end
    else
      lines[#lines+1] = s.label .. "=<no instance>"
    end
  end
  return table.concat(lines, ", ")
end

log("[Jotun] attack damage: " .. tostring(JotunAttackDamage(ATTACK_DAMAGE, CHARGED_DAMAGE, ROLL_DAMAGE)))

-- ------------------------------------------------------------------- camera
-- CameraController drives the game camera's zoom every frame, so writing the
-- tk2dCamera zoomFactor directly does NOT work - the controller overwrites it
-- within a frame. (Writing tk2dCamera only shrinks the UI cameras, which are
-- not driven by anything.)
--
-- Convention: LOWER zoom = WIDER view.  Stock _maxZoom is 0.8 (close).
--   0.8 stock | 0.6 slight | 0.35 noticeable | 0.2 wide
-- _maxZoom is the resting zoom; _minZoom is how far the game may widen on its
-- own during big encounters. Keep _minZoom <= _maxZoom or the range is invalid.
local CAM_MAX_ZOOM = 0.2      -- resting view width (nil = leave stock)
local CAM_MIN_ZOOM = 0.05     -- stock; raise toward CAM_MAX_ZOOM to limit
                              -- how far the dynamic camera can pull out

local OFF_MINZOOM = 0x38
local OFF_MAXZOOM = 0x3C

function JotunCameraZoom(maxZoom, minZoom)
  local img = findImage("Assembly-CSharp")
  if not img then return "Assembly-CSharp not found" end
  local cls = findClass(img, "CameraController")
  local insts = cls and mono_class_findInstancesOfClassListOnly(cls) or {}
  if not insts[1] then return "no CameraController instance" end
  local addr = insts[1]
  local bMin, bMax = readFloat(addr + OFF_MINZOOM), readFloat(addr + OFF_MAXZOOM)
  if minZoom ~= nil then writeFloat(addr + OFF_MINZOOM, minZoom) end
  if maxZoom ~= nil then writeFloat(addr + OFF_MAXZOOM, maxZoom) end
  -- guard: min must not exceed max
  if readFloat(addr + OFF_MINZOOM) > readFloat(addr + OFF_MAXZOOM) then
    writeFloat(addr + OFF_MINZOOM, readFloat(addr + OFF_MAXZOOM))
  end
  unregisterSymbol("jotunCamMaxZoom")
  registerSymbol("jotunCamMaxZoom", addr + OFF_MAXZOOM, true)
  unregisterSymbol("jotunCamMinZoom")
  registerSymbol("jotunCamMinZoom", addr + OFF_MINZOOM, true)
  -- editable cheat-table entries (not frozen, so you can tune them live).
  -- LOWER value = WIDER view. 0.8 stock, 0.6 slight, 0.35 noticeable, 0.2 wide.
  if ADD_TO_TABLE then
    local al = getAddressList()
    local function put(desc, at)
      for i = al.Count - 1, 0, -1 do
        local r = al[i]
        if r and r.Description == desc then r.destroy() end
      end
      local rec = al.createMemoryRecord()
      rec.Description = desc
      rec.Address = string.format("%X", at)
      rec.Type = vtSingle
    end
    put("Jotun: Camera Max Zoom (lower=wider)", addr + OFF_MAXZOOM)
    put("Jotun: Camera Min Zoom (dynamic limit)", addr + OFF_MINZOOM)
  end
  return string.format("min %s->%s, max %s->%s", tostring(bMin),
    tostring(readFloat(addr + OFF_MINZOOM)), tostring(bMax),
    tostring(readFloat(addr + OFF_MAXZOOM)))
end

log("[Jotun] camera zoom: " .. tostring(JotunCameraZoom(CAM_MAX_ZOOM, CAM_MIN_ZOOM)))

print("[Jotun] done. Re-run this script after a restart or if values read wrong.")
