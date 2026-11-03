--[[ ------------------------------------------------------------------
  Figment 2: Creed Valley - resolve player state via Mono metadata.

  Unity + Mono (mono-2.0-bdwgc.dll). IMPORTANT: this project uses Unity
  assembly definitions, so there is **no Assembly-CSharp**. The game code lives
  in an assembly called "Figment" (2337 classes) plus "BedtimeCore" (352).
  Searching for Assembly-CSharp returns nothing and looks like total failure.

  Resolution chain:
    PlayerHealth instances -> the live one has maxHealth > 0
                              (the other is the prefab template)
                           -> health, maxHealth, isInvulnerable, xp
    PlayerManager.animator -> the player's Animator; movement is ROOT-MOTION
                              driven, so Animator.speed is what scales running
    PlayerMovement         -> movementSpeedMultiplier exists but is NOT applied

  Movement speed notes (three approaches tested):
    PlayerMovement.movementSpeedMultiplier = 2   -> no effect
    NavMeshAgent.set_speed(7.0)                  -> no effect (pathfinding only)
    Animator.set_speed(2.0)                      -> WORKS (also speeds combat anims)
  A gentler alternative is the animator float parameter
  "LocomotionSpeedMultiplier" via Animator.SetFloat, which is what the game
  itself drives.

  Usage: attach Cheat Engine to "Figment 2.exe", then
         File -> Execute Script (select this file).
------------------------------------------------------------------ ]]

-- ------------------------------------------------------------------ config
local ADD_TO_TABLE   = true
local VERBOSE        = true

local INVULNERABLE   = true    -- freeze isInvulnerable = 1
local MAX_HEALTH     = nil     -- e.g. 20 for more hearts (nil = leave stock)
local ANIM_SPEED     = 3.0     -- movement + animation rate. 1.0 = normal.
                               -- 2.0 is barely noticeable in practice; 3.0 reads
                               -- as a clear speed-up, 5.0 is very fast.
                               -- Tune live with F2AnimSpeed(n) - no re-run needed.
local SHARDS         = nil     -- "max" to collect all, a number, or nil to only report
local CAMERA_ZOOM    = 5.0     -- ORTHOGRAPHIC scenes: orthographicSizeAddition
                               -- (0.28 stock; larger = wider)
local CAMERA_FOV_MULT = 1.6    -- PERSPECTIVE scenes: multiplies Cinemachine lens
                               -- FOV. 1.0 = stock, 1.6 = noticeably wider.
                               -- Tune live with F2FOV(n).
local KEEP_APPLIED   = true    -- re-apply loop. Safe now: it uses only the fixed
                               -- static-pointer path (a few reads per tick) and
                               -- never scans the Mono heap.
local KEEPER_TICK_MS = 1000
RESOLVE_EVERY_MS     = 30000   -- expensive heap re-enumeration cadence.
                               -- Do NOT lower this: a Mono heap scan takes
                               -- seconds to tens of seconds and runs on CE's
                               -- main thread. Too low and CE stops responding.
local FREEZE         = true

-- ----------------------------------------------------------------- offsets
local PH = { baseMaxHealth = 0x13C, maxHealth = 0x140, xpNeededNext = 0x144,
             regenHealthFactor = 0x160, delayBeforeRegen = 0x164,
             respawnHealthFactor = 0x16C, minimumRespawnHealth = 0x170,
             regenInCombat = 0x174, isInvulnerable = 0x175,
             xp = 0x188, health = 0x190, lastCheckPointHP = 0x1BC }
local PMGR = { animator = 0x30 }
local PMOV = { movementSpeedMultiplier = 0xA8, turnSpeedMultiplier = 0xAC }

-- ------------------------------------------------------------------ helpers
local function log(...) if VERBOSE then print(...) end end
local function rf(a) local v = readFloat(a); return v end
local function ri(a) local v = readInteger(a); return v end
local function rb(a) local v = readBytes(a, 1, false); return v end
local function rq(a) local v = readQword(a); return v end

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

local function findMethod(img, className, methodName)
  local cls = findClass(img, className)
  if not cls then return nil end
  for _, m in ipairs(mono_class_enumMethods(cls) or {}) do
    if tostring(m.name or "") == methodName then return m.method end
  end
  return nil
end

-- ------------------------------------------------- FAST RESOLUTION (no scans)
-- Mono heap scans (mono_class_findInstancesOfClassListOnly) take seconds to tens
-- of seconds in this game, run on CE's MAIN thread, and trip CE's "mono operation
-- is taking longer than expected" dialog - which can wedge the GUI and the MCP
-- bridge. Everything below avoids them entirely.
--
--   PlayerManager has a STATIC 'instance' field, so one pointer read gives the
--   live player, and every subsystem hangs off it:
--     instance +0xA0 health(PlayerHealth)  +0x30 animator  +0xC8 movement
--
--   CameraController / ShardSceneManager expose no statics, but both derive from
--   StateBehaviour and the scene registers every StateBehaviour in one array:
--     TriggerManager.instance +0x38 _sceneStateManager
--                             +0x18 IdentifierObjects (StateBehaviour[])
--   Walking it and comparing class pointers costs ~440ms for ~34k entries -
--   bounded, predictable, and not a heap scan.
--
-- Mono array layout (64-bit): +0x18 = length, +0x20 = first element.
-- An object's class = readQword(readQword(obj))  (vtable -> klass).
local PMGR_F  = { animator = 0x30, health = 0xA0, movement = 0xC8,
                  fight = 0x90, inventory = 0xB0, timeManager = 0x138 }
local TRIG_F  = { sceneStateManager = 0x38 }
local SCENE_F = { identifierObjects = 0x18 }
local ARR     = { length = 0x18, data = 0x20 }

local function classOf(obj)
  if not obj or obj <= 0x10000 then return nil end
  local vt = rq(obj)
  if not vt or vt <= 0x10000 then return nil end
  return rq(vt)
end

local function staticInstanceOf(img, name)
  local dom = (mono_enumDomains() or {})[1]
  local cls = findClass(img, name)
  if not dom or not cls then return nil end
  local base = mono_class_getStaticFieldAddress(dom, cls)
  if not base then return nil end
  for _, f in ipairs(mono_class_enumFields(cls) or {}) do
    local fn = tostring(f.name):lower()
    if f.isStatic and (fn == "instance" or fn == "_instance") then
      local p = rq(base + f.offset)
      if p and p > 0x10000 then return p end
    end
  end
  return nil
end

-- Find scene StateBehaviours by class name in ONE pass over the scene registry.
local function findSceneBehaviours(img, names)
  local wanted, result = {}, {}
  for _, n in ipairs(names) do
    local c = findClass(img, n)
    if c then wanted[c] = n end
  end
  local tm = staticInstanceOf(img, "TriggerManager")
  if not tm then return result end
  local ssm = rq(tm + TRIG_F.sceneStateManager)
  if not ssm or ssm <= 0x10000 then return result end
  local arr = rq(ssm + SCENE_F.identifierObjects)
  if not arr or arr <= 0x10000 then return result end
  local len = ri(arr + ARR.length)
  if not len or len <= 0 or len > 2000000 then return result end
  for i = 0, len - 1 do
    local obj = rq(arr + ARR.data + i * 8)
    if obj and obj > 0x10000 then
      local k = classOf(obj)
      local nm = k and wanted[k]
      if nm and not result[nm] then result[nm] = obj end
    end
  end
  return result
end

-- Cheap scene-change detection + re-bind.
-- A class-pointer check is NOT enough for scene objects: after a scene change the
-- OLD CameraController is still a live, valid CameraController, so the check
-- passes while writes land on the object that is no longer driving the camera.
-- The honest signal is the scene registry ARRAY ADDRESS - it is replaced whenever
-- the scene reloads. Detecting that costs ~4 pointer reads per tick; only on an
-- actual change do we pay for the (bounded, ~440ms) array walk.
function F2SceneArray()
  if not F2.trigStaticAddr then return nil end
  local tm = rq(F2.trigStaticAddr)
  if not tm or tm <= 0x10000 then return nil end
  local ssm = rq(tm + TRIG_F.sceneStateManager)
  if not ssm or ssm <= 0x10000 then return nil end
  local arr = rq(ssm + SCENE_F.identifierObjects)
  if not arr or arr <= 0x10000 then return nil end
  return arr
end

-- Walk a known registry array using CACHED class pointers (no metadata calls).
function F2BindSceneObjects(arr)
  arr = arr or F2SceneArray()
  if not arr then return false end
  local len = ri(arr + ARR.length)
  if not len or len <= 0 or len > 2000000 then return false end
  local cam, shard
  for i = 0, len - 1 do
    local obj = rq(arr + ARR.data + i * 8)
    if obj and obj > 0x10000 then
      local vt = rq(obj)
      local k = (vt and vt > 0x10000) and rq(vt) or nil
      if k then
        if k == F2.camClass and not cam then cam = obj end
        if k == F2.shardClass and not shard then shard = obj end
      end
    end
  end
  if cam then F2.cameraController = cam end
  if shard then F2.shardManager = shard end
  F2.sceneArr = arr
  F2_SCENE_BINDS = (F2_SCENE_BINDS or 0) + 1
  return cam ~= nil
end

F2 = F2 or {}

function F2Resolve()
  if mono_enumAssemblies == nil then
    return nil, "Mono functions unavailable in this Cheat Engine build"
  end
  if LaunchMonoDataCollector then LaunchMonoDataCollector() end

  local img = findImage("Figment")
  if not img then
    return nil, "assembly 'Figment' not found (note: this game has NO Assembly-CSharp)"
  end
  local r = { img = img }

  -- PlayerManager via its STATIC instance field: no heap scan, and always the
  -- live object. Everything about the player hangs off it.
  local pmgr = staticInstanceOf(img, "PlayerManager")
  if pmgr then
    r.playerManager = pmgr
    local anim = rq(pmgr + PMGR_F.animator)
    if anim and anim > 0x10000 then r.animator = anim end
    local ph = rq(pmgr + PMGR_F.health)
    if ph and ph > 0x10000 then
      local mx = ri(ph + PH.maxHealth)
      if mx and mx > 0 and mx < 10000 then r.playerHealth = ph end
    end
    local mv = rq(pmgr + PMGR_F.movement)
    if mv and mv > 0x10000 then r.movement = { mv } end
  end

  -- PlayerMovement now comes from PlayerManager above (no scan needed).
  -- Its multiplier does nothing, but it is kept for reference/table display.

  -- Animator speed accessors live in UnityEngine.AnimationModule
  local animImg = findImage("UnityEngine.AnimationModule")
  if animImg then
    r.animGetSpeed = findMethod(animImg, "Animator", "get_speed")
    r.animSetSpeed = findMethod(animImg, "Animator", "set_speed")
  end
  r.domain = (mono_enumDomains() or {})[1]

  -- CameraController + ShardSceneManager in a single registry pass (no scans)
  local sb = findSceneBehaviours(img, { "CameraController", "ShardSceneManager" })
  r.cameraController = sb["CameraController"]
  r.shardManager     = sb["ShardSceneManager"]

  -- Cache the FIXED address of PlayerManager's static 'instance' slot plus the
  -- class pointers. The static slot never moves for the life of the process, so
  -- the keeper can re-read the live player every tick with a handful of pointer
  -- reads - no metadata calls, no scans.
  do
    local dom = (mono_enumDomains() or {})[1]
    local cls = findClass(img, "PlayerManager")
    if dom and cls then
      local base = mono_class_getStaticFieldAddress(dom, cls)
      if base then
        for _, f in ipairs(mono_class_enumFields(cls) or {}) do
          if f.isStatic and tostring(f.name):lower() == "instance" then
            r.pmStaticAddr = base + f.offset
          end
        end
      end
    end
    r.camClass   = findClass(img, "CameraController")
    r.shardClass = findClass(img, "ShardSceneManager")
    -- Cinemachine core, via its own static sInstance field. Perspective scenes
    -- are driven by Cinemachine, not by CameraController.
    local cimg
    for _, a in ipairs(mono_enumAssemblies() or {}) do
      local i2 = mono_getImageFromAssembly(a)
      if i2 and mono_image_get_name(i2) == "Cinemachine" then cimg = i2 end
    end
    if cimg and dom then
      local ccls
      for _, c in ipairs(mono_image_enumClasses(cimg) or {}) do
        if tostring(c.classname or "") == "CinemachineCore" then ccls = c.class end
      end
      if ccls then
        local cbase = mono_class_getStaticFieldAddress(dom, ccls)
        if cbase then
          for _, f in ipairs(mono_class_enumFields(ccls) or {}) do
            if f.isStatic and tostring(f.name) == "sInstance" then
              local p = rq(cbase + f.offset)
              if p and p > 0x10000 then r.cineCore = p end
            end
          end
        end
      end
    end
    -- fixed static slot for TriggerManager.instance -> lets the keeper detect a
    -- scene change with a few pointer reads
    local tcls = findClass(img, "TriggerManager")
    if dom and tcls then
      local tbase = mono_class_getStaticFieldAddress(dom, tcls)
      if tbase then
        for _, f in ipairs(mono_class_enumFields(tcls) or {}) do
          local fn = tostring(f.name):lower()
          if f.isStatic and (fn == "instance" or fn == "_instance") then
            r.trigStaticAddr = tbase + f.offset
          end
        end
      end
    end
  end

  -- PlayerHealth may legitimately be absent: at the main menu the player object
  -- does not exist yet (PlayerManager is a persistent singleton, PlayerHealth is
  -- not). Return a PARTIAL result rather than failing, so the keeper can start at
  -- the menu and fill in the rest once a level loads.
  if not r.playerHealth then
    r.partial = true
    return r, "partial: no live PlayerHealth yet (main menu?)"
  end
  r.partial = false
  return r, "ok"
end

-- ------------------------------------------------------------------ actions
function F2AnimSpeed(value)
  if not (F2.animator and F2.animGetSpeed and F2.domain) then return "animator unresolved" end
  -- follow the live animator through the fixed static slot
  if F2.pmStaticAddr then
    local pm = rq(F2.pmStaticAddr)
    if pm and pm > 0x10000 then
      local a = rq(pm + PMGR_F.animator)
      if a and a > 0x10000 then F2.animator = a end
    end
  end
  local before = mono_invoke_method(F2.domain, F2.animGetSpeed, F2.animator, {})
  if value ~= nil and F2.animSetSpeed then
    -- Store in a GLOBAL so the keeper enforces the NEW value immediately.
    -- Otherwise the keeper would restore the old config value and silently
    -- undo live tuning within one tick.
    F2_ANIM_SPEED = value
    mono_invoke_method(F2.domain, F2.animSetSpeed, F2.animator, { value })
  end
  local after = mono_invoke_method(F2.domain, F2.animGetSpeed, F2.animator, {})
  return string.format("animator speed %s -> %s (keeper enforces %s)",
    tostring(before), tostring(after), tostring(F2_ANIM_SPEED))
end

function F2Heal()
  if not F2.playerHealth then return "unresolved" end
  local mx = ri(F2.playerHealth + PH.maxHealth)
  writeFloat(F2.playerHealth + PH.health, mx)
  return "health set to " .. tostring(mx)
end

-- --------------------------------------------------------------- shards
-- The blue collectibles are "shards" - NOT orbs/baubles/collectibles, which is
-- what obvious name searches try first and fail on.
-- ShardSceneManager.Collected / MaxShards is the authoritative pair; the HUD
-- percentage is Collected/MaxShards. Reached via ShardUI._shardSceneManager.
local SSM = { unlockPoint = 0x68, collected = 0x6C, maxShards = 0x70 }
local SUI = { shardSceneManager = 0x70, previousPercentage = 0x98 }

function F2Shards(setTo)
  if not F2.shardManager then return "shard manager unresolved" end
  local before = ri(F2.shardManager + SSM.collected)
  local maxv   = ri(F2.shardManager + SSM.maxShards)
  if setTo == "max" then setTo = maxv end
  if setTo ~= nil then writeInteger(F2.shardManager + SSM.collected, setTo) end
  local now = ri(F2.shardManager + SSM.collected)
  return string.format("shards %s -> %s / %s (%.1f%%)", tostring(before),
    tostring(now), tostring(maxv), (maxv and maxv > 0) and (100 * now / maxv) or 0)
end

-- --------------------------------------------------------------- camera zoom
-- The camera is ORTHOGRAPHIC. CameraController.orthographicSizeAddition is an
-- additive offset on the base size; larger = WIDER view. zoomSize is the
-- resulting size and can be read to confirm the change took effect.
-- Scale (base size ~4.3): 0.28 stock | 2 modest | 5 wide | 10 very wide
local CC = { isZoomActive = 0xE9, orthoAdd = 0xEC, zoomSize = 0x188 }

function F2CameraZoom(add)
  if not F2.cameraController then return "cameraController unresolved" end
  local before = rf(F2.cameraController + CC.orthoAdd)
  if add ~= nil then writeFloat(F2.cameraController + CC.orthoAdd, add) end
  return string.format("orthoSizeAddition %s -> %s (zoomSize=%s)", tostring(before),
    tostring(rf(F2.cameraController + CC.orthoAdd)),
    tostring(rf(F2.cameraController + CC.zoomSize)))
end

-- ------------------------------------------------------- camera: TWO systems
-- This game uses TWO camera systems and which one is live depends on the scene:
--
--  1. ORTHOGRAPHIC scenes: an active CameraController drives an orthographic
--     camera. CameraController.orthographicSizeAddition widens the view.
--
--  2. PERSPECTIVE scenes: Camera.main.orthographic == 0 and CINEMACHINE drives
--     the view. CameraController is still present but isActive == 0, so writing
--     orthographicSizeAddition does nothing. Writing Camera.main.fieldOfView is
--     also useless - Cinemachine reasserts it from its own lens EVERY FRAME.
--     The real source is the virtual camera lens:
--       CinemachineCore.sInstance (STATIC)
--         +0x18 mActiveCameras : List<CinemachineVirtualCameraBase>
--                +0x10 _items (array)  +0x18 _size
--         each vcam +0x1C0 = m_Lens.FieldOfView   (metadata says 0x10 inside
--                            LensSettings; that includes the boxed-struct
--                            header, so embedded it lands at +0x1C0)
--
-- Baseline FOVs are tiny in this game (~2.2 for gameplay - a telephoto rig), so
-- absolute values are meaningless; a MULTIPLIER is the portable knob. Base values
-- are cached per camera so repeated calls never compound.
local CINE = { activeCameras = 0x18, listItems = 0x10, listSize = 0x18,
               dataStart = 0x20, lensFov = 0x1C0 }
F2_FOV_BASE = F2_FOV_BASE or {}

function F2FOV(mult)
  mult = mult or F2_FOV_MULT or 1.0
  if not F2.cineCore then return "Cinemachine core unresolved" end
  local list = rq(F2.cineCore + CINE.activeCameras)
  if not list or list <= 0x10000 then return "no active camera list" end
  local items = rq(list + CINE.listItems)
  local size  = ri(list + CINE.listSize)
  if not items or not size or size <= 0 then return "camera list empty" end
  local n = 0
  for i = 0, math.min(size, 500) - 1 do
    local vc = rq(items + CINE.dataStart + i * 8)
    if vc and vc > 0x10000 then
      local cur = rf(vc + CINE.lensFov)
      if cur and cur > 0.1 and cur < 180 then
        local base = F2_FOV_BASE[vc]
        if not base then base = cur; F2_FOV_BASE[vc] = base end
        local target = base * mult
        if target > 170 then target = 170 end
        if math.abs(cur - target) > 0.01 then writeFloat(vc + CINE.lensFov, target) end
        n = n + 1
      end
    end
  end
  F2_FOV_MULT = mult
  return string.format("FOV x%.2f applied to %d virtual cameras", mult, n)
end

-- Level changes reset BOTH the camera zoom and the animator speed, and the
-- animator speed is a native property with no address to freeze. A timer that
-- re-applies them (and re-resolves when objects are recreated) is the only
-- reliable fix.
--
-- Note: CE timers run on the main thread. Do NOT call sleep() from a script
-- while testing a timer or freeze - it stalls the very thread that runs them
-- and makes them look broken.
-- ------------------------------------------------------------------- keeper
function F2StopKeeper()

  if F2_KEEPER ~= nil then
    pcall(function() F2_KEEPER.Enabled = false; F2_KEEPER.destroy() end)
    F2_KEEPER = nil
    return "keeper stopped"
  end
  return "keeper was not running"
end

function F2StartKeeper(interval)
  F2StopKeeper()
  F2_KEEPER_FIXES = 0
  F2_KEEPER_RESOLVES = 0
  F2_KEEPER_BUSY = false
  F2_KEEPER = createTimer(nil, false)
  F2_KEEPER.Interval = interval or 1000
  F2_KEEPER.OnTimer = function()
    -- Re-entrancy guard. CE timers run on the MAIN thread, which also serves the
    -- GUI and the MCP bridge; if a tick outlasts its interval the ticks pile up
    -- and CE stops responding. Never omit this.
    if F2_KEEPER_BUSY then return end
    F2_KEEPER_BUSY = true
    pcall(function()
      -- CHEAP path only. Read the live player through the FIXED static slot,
      -- which is always current - no metadata calls, no heap scan.
      local ph, anim
      if F2.pmStaticAddr then
        local pm = rq(F2.pmStaticAddr)
        if pm and pm > 0x10000 then
          F2.playerManager = pm
          local h = rq(pm + PMGR_F.health)
          if h and h > 0x10000 then
            local mx = ri(h + PH.maxHealth)
            if mx and mx > 0 and mx < 10000 then ph = h; F2.playerHealth = h end
          end
          local a = rq(pm + PMGR_F.animator)
          if a and a > 0x10000 then anim = a; F2.animator = a end
        end
      end

      if INVULNERABLE and ph and rb(ph + PH.isInvulnerable) ~= 1 then
        writeBytes(ph + PH.isInvulnerable, 1)
        F2_KEEPER_FIXES = F2_KEEPER_FIXES + 1
      end

      -- Scene-change detection: the registry array is replaced on scene load.
      -- ~4 pointer reads per tick; the bounded walk runs only when it changes.
      local arr = F2SceneArray()
      if arr and arr ~= F2.sceneArr then
        F2BindSceneObjects(arr)
        F2_KEEPER_FIXES = F2_KEEPER_FIXES + 1
      end

      if CAMERA_ZOOM and F2.cameraController then
        local cur = rf(F2.cameraController + CC.orthoAdd)
        if cur == nil or math.abs(cur - CAMERA_ZOOM) > 0.01 then
          writeFloat(F2.cameraController + CC.orthoAdd, CAMERA_ZOOM)
          F2_KEEPER_FIXES = F2_KEEPER_FIXES + 1
        end
      end

      -- Cinemachine FOV: perspective scenes need this, and Cinemachine rewrites
      -- the lens every frame, so it must be re-applied continuously. Cheap:
      -- ~20 float reads.
      if F2_FOV_MULT and F2_FOV_MULT ~= 1.0 and F2.cineCore then
        F2FOV(F2_FOV_MULT)
      end

      local wantSpeed = F2_ANIM_SPEED
      if wantSpeed and anim and F2.animGetSpeed and F2.domain then
        local okc, cur = pcall(function()
          return mono_invoke_method(F2.domain, F2.animGetSpeed, anim, {})
        end)
        if okc and cur and math.abs(cur - wantSpeed) > 0.01 then
          pcall(function()
            mono_invoke_method(F2.domain, F2.animSetSpeed, anim, { wantSpeed })
          end)
          F2_KEEPER_FIXES = F2_KEEPER_FIXES + 1
        end
      end
    end)
    F2_KEEPER_BUSY = false
  end
  F2_KEEPER.Enabled = true
  return string.format("keeper started (%dms, static-pointer path, no heap scans)",
    F2_KEEPER.Interval)
end

local info, how = F2Resolve()
if not info then
  print("[F2] FAILED: " .. tostring(how))
  return
end
F2 = info

-- At the main menu there is no player object yet. Apply what exists, start the
-- keeper, and let it complete the loadout when a level loads.
if F2.partial then
  print("[F2] " .. tostring(how))
  print("[F2] applying what is available; the keeper will finish once in a level.")
  if ANIM_SPEED and F2.animator then log("[F2]   " .. tostring(F2AnimSpeed(ANIM_SPEED))) end
  if CAMERA_ZOOM and F2.cameraController then
    log("[F2]   " .. tostring(F2CameraZoom(CAMERA_ZOOM)))
  end
  if F2.shardManager then log("[F2]   " .. tostring(F2Shards(SHARDS))) end
  if KEEP_APPLIED then print("[F2]   " .. tostring(F2StartKeeper(KEEPER_TICK_MS))) end
  print("[F2] load a level, then re-run for the cheat table entries.")
  return
end

log(string.format("[F2] playerHealth=%X animator=%s movementInstances=%d",
  F2.playerHealth, F2.animator and string.format("%X", F2.animator) or "nil",
  #(F2.movement or {})))
log(string.format("[F2]   health=%s/%s baseMax=%s xp=%s invuln=%s regenInCombat=%s",
  tostring(rf(F2.playerHealth + PH.health)), tostring(ri(F2.playerHealth + PH.maxHealth)),
  tostring(ri(F2.playerHealth + PH.baseMaxHealth)), tostring(ri(F2.playerHealth + PH.xp)),
  tostring(rb(F2.playerHealth + PH.isInvulnerable)),
  tostring(rb(F2.playerHealth + PH.regenInCombat))))

if INVULNERABLE then
  writeBytes(F2.playerHealth + PH.isInvulnerable, 1)
  log("[F2]   isInvulnerable -> 1")
end
if MAX_HEALTH then
  writeInteger(F2.playerHealth + PH.maxHealth, MAX_HEALTH)
  writeInteger(F2.playerHealth + PH.baseMaxHealth, MAX_HEALTH)
  writeFloat(F2.playerHealth + PH.health, MAX_HEALTH)
  log("[F2]   maxHealth -> " .. tostring(MAX_HEALTH))
end
if ANIM_SPEED then log("[F2]   " .. tostring(F2AnimSpeed(ANIM_SPEED))) end
if SHARDS ~= nil and F2.shardManager then
  log("[F2]   " .. tostring(F2Shards(SHARDS)))
elseif F2.shardManager then
  log("[F2]   " .. tostring(F2Shards(nil)))
end

if CAMERA_ZOOM and F2.cameraController then
  log("[F2]   " .. tostring(F2CameraZoom(CAMERA_ZOOM)))
end
if CAMERA_FOV_MULT and F2.cineCore then
  log("[F2]   " .. tostring(F2FOV(CAMERA_FOV_MULT)))
end
if KEEP_APPLIED then log("[F2]   " .. tostring(F2StartKeeper(KEEPER_TICK_MS))) end

-- ------------------------------------------------------------------ symbols
for n, a in pairs({
  f2PlayerHealth = F2.playerHealth,
  f2Health       = F2.playerHealth + PH.health,
  f2MaxHealth    = F2.playerHealth + PH.maxHealth,
  f2Invuln       = F2.playerHealth + PH.isInvulnerable,
  f2XP           = F2.playerHealth + PH.xp,
}) do unregisterSymbol(n); registerSymbol(n, a, true) end

-- ------------------------------------------------------------- cheat table
if ADD_TO_TABLE then
  local al = getAddressList()
  for i = al.Count - 1, 0, -1 do
    local rec = al[i]
    if rec and tostring(rec.Description):match("^F2: ") then rec.destroy() end
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
  local p = F2.playerHealth
  put("F2: Invulnerable (1=on)", p + PH.isInvulnerable, vtByte, INVULNERABLE and 1 or nil)
  put("F2: Health",              p + PH.health,        vtSingle)
  put("F2: Max Health",          p + PH.maxHealth,     vtDword)
  put("F2: Base Max Health",     p + PH.baseMaxHealth, vtDword)
  put("F2: XP",                  p + PH.xp,            vtDword)
  put("F2: Regen In Combat (1=on)",  p + PH.regenInCombat,     vtByte)
  put("F2: Regen Health Factor",     p + PH.regenHealthFactor, vtSingle)
  put("F2: Respawn Health Factor",   p + PH.respawnHealthFactor, vtSingle)
  put("F2: Min Respawn Health",      p + PH.minimumRespawnHealth, vtDword)
  -- PlayerMovement multiplier is kept visible even though it has no effect,
  -- so nobody wastes time rediscovering it.
  for k, pm in ipairs(F2.movement or {}) do
    put(string.format("F2: [no effect] movementSpeedMultiplier #%d", k),
        pm + PMOV.movementSpeedMultiplier, vtSingle)
  end
  if F2.shardManager then
    put("F2: Shards Collected", F2.shardManager + SSM.collected,  vtDword)
    put("F2: Shards Max",       F2.shardManager + SSM.maxShards,  vtDword)
    put("F2: Shard Unlock Point (0-1)", F2.shardManager + SSM.unlockPoint, vtSingle)
  end
  log("[F2] cheat table rebuilt: " .. al.Count .. " entries")
end

print("[F2] done. Re-run after a restart or a scene change.")
print("[F2] helpers: F2AnimSpeed(2) | F2Heal() | F2Shards('max') | F2Resolve()")
