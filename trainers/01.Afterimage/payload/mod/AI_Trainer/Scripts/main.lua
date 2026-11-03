-- AI_Trainer v1.4.0  - Afterimage (UE 4.26, Steam) in-game trainer, UE4SS Lua mod.
-- Offline / single-player only. No game files are modified; everything happens in memory.
local VERSION = "1.4.0"
local function script_dir()
    local s = debug.getinfo(1, "S").source:sub(2)
    return s:match("(.*[\\/])") or ""
end
local DIR = script_dir()
local function log(s) print("[AI_Trainer] " .. s .. "\n") end
-- IsValid() on a userdata whose UObject was destroyed during a level change can itself raise; treat that as invalid.
local function valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end

local ok_cfg, CFG = pcall(dofile, DIR .. "config.lua")
if not ok_cfg then log("config.lua failed: " .. tostring(CFG)); return end
-- fill anything missing from an older / hand-edited config.lua with the shipped defaults
do
    local DEF_KEYS = { god = "F1", items = "F2", jump = "F3", speed = "F4", mana = "F5", ohk = "F6", heal = "F7", hud = "F8",
        speed_cycle = "F9", money_big = "F10", map_items = "PAGE_UP", map_reveal = "DEL", talent = "PAGE_DOWN", dash = "END", minimap = "F12", mouse = "INS" }
    CFG.keys = CFG.keys or {}
    for k, v in pairs(DEF_KEYS) do if CFG.keys[k] == nil then CFG.keys[k] = v end end
    CFG.defaults = CFG.defaults or {}
    if CFG.defaults.minimap == nil then CFG.defaults.minimap = 1 end
    if CFG.defaults.minimap == true then CFG.defaults.minimap = 1 elseif CFG.defaults.minimap == false then CFG.defaults.minimap = 0 end
    CFG.minimap = CFG.minimap or {}
    CFG.speed_steps = CFG.speed_steps or { 2.0, 3.0, 4.0, 1.5 }
    CFG.money_big = CFG.money_big or 100000
    CFG.bag_item_amount = CFG.bag_item_amount or 100
    CFG.bag_item_cap = CFG.bag_item_cap or 999
    CFG.talent_points = CFG.talent_points or 5
    CFG.map_item_types = CFG.map_item_types or { TreasureBoxHigh = true, DropActorAdv = true, MoneyStone = true, NPC_Soul_Echo = false }
    CFG.map_icons = CFG.map_icons or {}
    CFG.hud_x, CFG.hud_y = CFG.hud_x or 20.0, CFG.hud_y or 150.0
    CFG.hud = CFG.hud or {}
    if CFG.show_hud == nil then CFG.show_hud = true end
    local DEF_ID = { hp = 1, max_hp = 2, mana = 3, max_mana = 4, money = 20, walk_speed = 36, object_open = 11,
        dash_max = 37, dash_remain = 38, talent_sum = 182, talent_used = 183, actor_dead = 51,
        item_bag = 19, item_storage = 112, item_view = 237 }
    CFG.sprop = CFG.sprop or {}
    for k, v in pairs(DEF_ID) do if CFG.sprop[k] == nil then CFG.sprop[k] = v end end
end
local ID = CFG.sprop
-- UE4SS finishes its own start-up (FName hook removal, UObject hash-table switch-over) ~16 s after the mod is
-- loaded; touching UObjects from Lua during that window crashed the game on some launches. Stay idle until then.
local T0 = os.clock()
local STARTUP_DELAY = CFG.startup_delay or 30.0
local function ready() return os.clock() - T0 >= STARTUP_DELAY end
local SCOPE_SPEED = "AI_TRAINER_SPEED"

---------------------------------------------------------------- state
local D = CFG.defaults
local S = {
    god = D.god, jump = D.jump, speed = D.speed, mana = D.mana, ohk = D.ohk,
    map_items = D.map_items == true, map_reveal = D.map_reveal == true, dash = D.dash == true,
    speed_idx = 1, hud = CFG.show_hud, last_ground = 0,
}
local H = { widget = nil, text = nil }      -- HUD widget refs
local T = { hooks_ok = {}, jump_calls = 0 } -- telemetry for self-test

---------------------------------------------------------------- helpers
local PC_CACHE, CTRL_CACHE = nil, nil
local function player()
    if valid(PC_CACHE) then return PC_CACHE end
    PC_CACHE = nil
    local pc = FindFirstOf("PlayerCharacter")
    if pc and pc:IsValid() and not pc:GetFullName():find("Default__") then PC_CACHE = pc; return pc end
    return nil
end
local function controller()
    if valid(CTRL_CACHE) then return CTRL_CACHE end
    CTRL_CACHE = nil
    local c = FindFirstOf("AiPlayerController")
    if c and c:IsValid() and not c:GetFullName():find("Default__") then CTRL_CACHE = c; return c end
    return nil
end
local function sget(sp, id)
    local ok, v = pcall(function() return sp:GetSPropertyNumberValue(id) end)
    if ok and type(v) == "number" then return v end
    return nil
end
local function sbase(sp, id)
    local ok, v = pcall(function() return sp:GetPropertyBaseNumberValue(id) end)
    if ok and type(v) == "number" then return v end
    return nil
end
local function sset_cur(sp, id, v) return pcall(function() sp:SetSPropertyCurrNumberValue(id, v) end) end
local function sset_base(sp, id, v) return pcall(function() sp:SetSPropertyNumberValue(id, v) end) end
local function is_paused(pc)
    local ok, r = pcall(function()
        local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
        return gs:IsGamePaused(pc:GetWorld())
    end)
    return ok and r == true
end
local function speed_mult() return CFG.speed_steps[S.speed_idx] or 2.0 end

---------------------------------------------------------------- map / talent / dash state (v1.1.0)
local M = { cands = nil, icons = {}, expected = 0, dirty = false, last_count = nil, orig_fog = nil, white = nil, hooked = false }
local B = { pool = nil, last = nil }   -- bag items (add_bag_items)
local SPLIB = nil
local function splib()
    if valid(SPLIB) then return SPLIB end
    SPLIB = StaticFindObject("/Script/SPropertySystem.Default__SPropertyBlueprintLib")
    return valid(SPLIB) and SPLIB or nil
end
local function talent_text()
    local pc = player(); if not pc then return "?" end
    local sum, used = sget(pc.SProp, ID.talent_sum), sget(pc.SProp, ID.talent_used)
    if not sum or not used then return "?" end
    return string.format("%d free", math.floor(sum - used + 0.5))
end

---------------------------------------------------------------- HUD (UMG built at runtime, see hud.lua)
local NICE = { PAGE_UP = "PgUp", PAGE_DOWN = "PgDn", INS = "Ins", DEL = "Del", HOME = "Home", END = "End" }
local function nice_key(v) return (v:gsub("[%u_]+", function(s) return NICE[s] or s end)) end
local function with_commas(n)
    local s = string.format("%d", math.floor(n + 0.5))
    local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (r:gsub("^,", ""))
end
local function short_amount(n)
    if n >= 1000000 and n % 1000000 == 0 then return string.format("+%dM", n // 1000000) end
    if n >= 1000 and n % 1000 == 0 then return string.format("+%dK", n // 1000) end
    return "+" .. with_commas(n)
end
local function active_count()
    local n = 0
    for _, k in ipairs({ "god", "jump", "speed", "mana", "ohk", "map_items", "map_reveal", "dash" }) do if S[k] then n = n + 1 end end
    if (S.minimap or 0) ~= 0 then n = n + 1 end
    return n
end
-- Everything the HUD shows, as data. Static parts (sections, keys, labels) never change; per-row text / tone / on do.
local function hud_model()
    local K = {}
    for k, v in pairs(CFG.keys) do K[k] = nice_key(v) end
    local mm = ({ [0] = "OFF", [1] = "FOLLOW", [2] = "REGION" })[S.minimap or 0] or "OFF"
    local function tog(id, key, label, on, text)
        return { id = id, key = key, label = label, on = on, text = text or (on and "ON" or "OFF"), tone = on and "on" or "off" }
    end
    local R = {
        god = tog("god", K.god, "God Mode", S.god),
        mana = tog("mana", K.mana, "Infinite Mana", S.mana),
        ohk = tog("ohk", K.ohk, "One-Hit Kill", S.ohk),
        heal = { id = "heal", key = K.heal, label = "Full Heal", on = false, text = "USE", tone = "action" },
        jump = tog("jump", K.jump, "Unlimited Jump", S.jump),
        dash = tog("dash", K.dash, "Infinite Dash", S.dash),
        speed = tog("speed", K.speed, "Game Speed", S.speed, (S.speed and "ON" or "OFF") .. string.format(" x%.1f", speed_mult())),
        items = { id = "items", key = K.items, label = "Add Bag Items", on = false,
            text = B.last and string.format("+%d x%d", CFG.bag_item_amount, B.last) or ("+" .. CFG.bag_item_amount), tone = "action" },
        money_big = { id = "money_big", key = K.money_big, label = "Add Money (" .. "+" .. with_commas(CFG.money_big) .. ")", on = false, text = short_amount(CFG.money_big), tone = "action" },
        talent = { id = "talent", key = K.talent, label = string.format("Add +%d Talent Points", CFG.talent_points or 5), on = false, text = "Free: " .. (talent_text():gsub(" free", "")), tone = "info" },
        map_items = tog("map_items", K.map_items, "Map Item Markers", S.map_items,
            S.map_items and (M.last_count and string.format("ON (%d)", M.last_count) or "ON") or "OFF"),
        map_reveal = tog("map_reveal", K.map_reveal, "Reveal Full Map", S.map_reveal),
        minimap = { id = "minimap", key = K.minimap, label = "Minimap Camera", on = (S.minimap or 0) ~= 0, text = mm, tone = (S.minimap or 0) ~= 0 and "info" or "off" },
    }
    R.speed.sub = "[" .. K.speed_cycle .. "] cycle"
    local model = {
        title = "AFTERIMAGE TRAINER " .. VERSION,
        hint = "[" .. K.hud .. "] Hide",
        mini_title = "AFTERIMAGE TRAINER " .. VERSION,
        active = active_count(),
        sections = {
            { name = "COMBAT & SURVIVAL", rows = { R.god, R.mana, R.ohk, R.heal } },
            { name = "MOVEMENT & SPEED", rows = { R.jump, R.dash, R.speed } },
            { name = "RESOURCES & PROGRESSION", rows = { R.items, R.money_big, R.talent } },
            { name = "MAP & EXPLORATION", rows = { R.map_items, R.map_reveal, R.minimap } },
        },
        byid = R,
        footer_on = S.mouse == true,
        footer = string.format("[%s] Mouse: %s   (click rows, drag the title)", K.mouse, S.mouse and "ON" or "OFF"),
    }
    model.mini_hint = string.format("[%s Show] (%d Active)", K.hud, model.active)
    return model
end

-- window position: config default, overridden by the position saved after the last drag (hud_pos.txt)
local POS_FILE = DIR .. "hud_pos.txt"
local HUDPOS = { x = CFG.hud_x, y = CFG.hud_y }
do
    local f = io.open(POS_FILE, "r")
    if f then
        local s = f:read("a"); f:close()
        local x, y = s:match("(-?[%d%.]+)%s+(-?[%d%.]+)")
        if x and y then HUDPOS.x, HUDPOS.y = tonumber(x), tonumber(y) end
    end
end
local function save_pos(x, y)
    local f = io.open(POS_FILE, "w")
    if f then f:write(string.format("%.1f %.1f\n", x, y)); f:close() end
end

-- legacy single-TextBlock HUD, used only if hud.lua cannot be loaded or built
local function hud_text_legacy()
    local m = hud_model()
    local out = { m.title .. "   " .. m.hint }
    for _, sec in ipairs(m.sections) do
        for _, r in ipairs(sec.rows) do out[#out + 1] = string.format("[%s] %s  %s", r.key, r.label, r.text) end
    end
    return table.concat(out, "\n")
end
local function hud_build_legacy()
    local ok, err = pcall(function()
        local gi = FindFirstOf("GameInstance")
        local UW = StaticFindObject("/Script/UMG.UserWidget")
        local w = StaticConstructObject(UW, gi, FName("AITrainerWidget_" .. tostring(math.floor(os.clock() * 1000))))
        local tree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), w, FName("AITrainerTree_" .. tostring(math.floor(os.clock() * 1000))))
        w.WidgetTree = tree
        local root = StaticConstructObject(StaticFindObject("/Script/UMG.CanvasPanel"), tree, FName("AIRoot_" .. tostring(math.floor(os.clock() * 1000))))
        tree.RootWidget = root
        local tb = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), tree, FName("AIText_" .. tostring(math.floor(os.clock() * 1000))))
        tb:SetText(FText(hud_text_legacy()))
        tb:SetColorAndOpacity({ SpecifiedColor = { R = 1.0, G = 0.92, B = 0.3, A = 1.0 }, ColorUseRule = 0 })
        local slot = root:AddChildToCanvas(tb)
        slot:SetPosition({ X = HUDPOS.x, Y = HUDPOS.y })
        slot:SetAutoSize(true)
        w:AddToViewport(9999)
        w:SetVisibility(4)
        H.widget, H.text = w, tb
    end)
    if not ok then log("legacy HUD build failed: " .. tostring(err)); H.widget, H.text = nil, nil end
end

local HUD = nil
local ACTIONS = {}              -- filled below; shared by hot keys and mouse clicks
do
    local okh, factory = pcall(dofile, DIR .. "hud.lua")
    if okh and type(factory) == "function" then
        local okc, api = pcall(factory, {
            cfg = CFG.hud, valid = valid, log = log, pos = HUDPOS,
            on_click = function(id) local fn = ACTIONS[id]; if fn and ready() then local ok, e = pcall(fn); if not ok then log("click action error: " .. tostring(e)) end end end,
            on_collapse = function() S.hud = false; H.refresh_now() end,
            on_expand = function() S.hud = true; H.refresh_now() end,
            on_moved = function(x, y) save_pos(x, y) end,
        })
        if okc then HUD = api else log("hud init failed: " .. tostring(api)) end
    else
        log("hud.lua failed to load: " .. tostring(factory))
    end
end
local function hud_refresh()
    if HUD then
        local ok, e = pcall(function()
            local pill = CFG.hud_collapse_to_pill ~= false
            local model = hud_model()
            HUD.refresh(model, S.hud)
            local st = HUD.state()
            if st and valid(st.widget) then st.widget:SetVisibility((S.hud or pill) and 3 or 1) end
        end)
        if ok then return end
        S.hud_err = (S.hud_err or 0) + 1
        if S.hud_err <= 3 then log("HUD error: " .. tostring(e)) end
        if S.hud_err >= 3 then pcall(HUD.destroy); HUD = nil end      -- fall back to the plain text HUD
    end
    if not S.hud then
        if valid(H.widget) then pcall(function() H.widget:SetVisibility(1) end) end
        return
    end
    if not valid(H.widget) then H.widget, H.text = nil, nil; hud_build_legacy() end
    if valid(H.widget) then
        pcall(function()
            if not H.widget:IsInViewport() then H.widget:AddToViewport(9999) end
            H.widget:SetVisibility(4)
            H.text:SetText(FText(hud_text_legacy()))
        end)
    end
end
H.refresh_now = hud_refresh
---------------------------------------------------------------- feature actions
local function apply_speed()
    local pc = player(); if not pc then return end
    local sp = pc.SProp
    pcall(function() sp:RemoveSPropScopeByKey(SCOPE_SPEED) end)
    if S.speed then
        local base = sbase(sp, ID.walk_speed) or 600.0
        pcall(function() sp:AddNumberSPropScope(ID.walk_speed, base * (speed_mult() - 1.0), 0, SCOPE_SPEED) end)
    end
end
local function add_money(amount)
    local pc = player(); if not pc then return false end
    local sp = pc.SProp
    local before = sget(sp, ID.money) or 0
    local want = before + amount
    sset_base(sp, ID.money, want)
    if sget(sp, ID.money) ~= want then sset_cur(sp, ID.money, want) end
    pcall(function() sp:ForceInvokeSPropChangeEvt(ID.money) end)
    local after = sget(sp, ID.money)
    log(string.format("money %s -> %s", tostring(before), tostring(after)))
    return after == want, before, after
end
---------------------------------------------------------------- bag items (prop_item_bag, v1.4.0)
-- The inventory bag is the player SProp table prop_item_bag: itemId -> count (overflow above the carry limit sits in
-- prop_item_storage, shown as "5(11)" = 5 in the bag, 11 in storage). SetSPropTableNumberValue(id, count, { itemId })
-- changes it and the inventory screen shows the new number at once. The SProp API cannot list the keys, so item ids are
-- tried from a pool: the names of the game's item icons (Icon_<ItemId>, listed from the asset registry) plus
-- cfg.bag_extra_ids. Only ids that pass cfg.bag_item_prefixes / cfg.bag_item_ids (consumables and materials, not
-- equipment or story/progress items) and that are in the player's bag, storage or seen-items list are raised.
local function bag_pool()
    if B.pool then return B.pool end
    local names, seen = {}, {}
    local function add(n) if type(n) == "string" and n ~= "" and not seen[n] then seen[n] = true; names[#names + 1] = n end end
    local ok, err = pcall(function()
        local helpers = StaticFindObject("/Script/AssetRegistry.Default__AssetRegistryHelpers")
        local reg = helpers:GetAssetRegistry()
        local arr = {}
        reg:GetAssetsByPath(FName(CFG.bag_icon_path or "/Game/Assets/UMG/TextureAtlases/ItemIcon/Frames"), arr, false, false)
        for i = 1, #arr do add((arr[i]:get().AssetName:ToString():gsub("^Icon_", ""))) end
    end)
    if not ok then log("bag items: icon list unavailable (" .. tostring(err) .. "), using bag_extra_ids only") end
    for _, n in ipairs(CFG.bag_extra_ids or {}) do add(n) end
    for _, n in ipairs(CFG.bag_item_ids or {}) do add(n) end
    local pool = {}
    local prefixes, exclude, force = CFG.bag_item_prefixes or {}, CFG.bag_exclude or {}, {}
    for _, n in ipairs(CFG.bag_item_ids or {}) do force[n] = true end
    for _, n in ipairs(names) do
        local take = force[n] == true
        if not take then for _, p in ipairs(prefixes) do if n:sub(1, #p) == p then take = true break end end end
        if take then for _, p in ipairs(exclude) do if n:find(p, 1, true) then take = false break end end end
        if take then pool[#pool + 1] = n end
    end
    B.pool = pool
    log(string.format("bag items: %d candidate ids (%d icon/extra names)", #pool, #names))
    return pool
end
local function bag_num(sp, prop, id)
    local ok, v = pcall(function() return sp:GetSPropTableNumberValue(prop, { id }) end)
    if ok and type(v) == "number" then return v end
    return nil
end
local function add_bag_items(amount)
    local pc = player(); if not pc then return 0 end
    local sp = pc.SProp
    local cap = CFG.bag_item_cap or 999
    local touched, parts = 0, {}
    for _, id in ipairs(bag_pool()) do
        local have = bag_num(sp, ID.item_bag, id)
        if have then
            local listed = have > 0 or (bag_num(sp, ID.item_storage, id) or 0) > 0 or (bag_num(sp, ID.item_view, id) or 0) > 0
            if listed then
                local want = have + amount
                if cap > 0 and want > cap then want = math.max(have, cap) end
                if want > have and pcall(function() sp:SetSPropTableNumberValue(ID.item_bag, want, { id }) end) then
                    touched = touched + 1
                    parts[#parts + 1] = string.format("%s %d>%d", id, have, bag_num(sp, ID.item_bag, id) or -1)
                end
            end
        end
    end
    if touched > 0 then pcall(function() sp:ForceInvokeSPropChangeEvt(ID.item_bag) end) end
    B.last = touched
    log(string.format("bag items +%d: %d kinds raised%s", amount, touched, touched > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""))
    return touched
end
local function full_heal()
    local pc = player(); if not pc then return false end
    local sp = pc.SProp
    local mh, mm = sget(sp, ID.max_hp), sget(sp, ID.max_mana)
    if mh then sset_cur(sp, ID.hp, mh) end
    if mm then sset_cur(sp, ID.mana, mm) end
    return true
end

---------------------------------------------------------------- talent points (prop_talent_point_sum)
local function add_talent(n)
    local pc = player(); if not pc then return false end
    local sp = pc.SProp
    local before = sget(sp, ID.talent_sum) or 0
    local base = sbase(sp, ID.talent_sum) or before
    local want = before + n
    sset_base(sp, ID.talent_sum, base + n)
    if sget(sp, ID.talent_sum) ~= want then sset_cur(sp, ID.talent_sum, want) end
    pcall(function() sp:ForceInvokeSPropChangeEvt(ID.talent_sum) end)
    local after = sget(sp, ID.talent_sum)
    log(string.format("talent points total %s -> %s (used %s)", tostring(before), tostring(after), tostring(sget(sp, ID.talent_used))))
    return after == want, before, after
end

---------------------------------------------------------------- map item markers (MinimapComponent.NpcMarkMap)
-- Every chest / ground item / money stone of the whole game is listed in the minimap's own DataTable
-- (MinimapComponent.DropItemDT = /Game/Assets/Minimap/DropItemInfo, row struct DropItemInfoRow) with its save id and
-- world location. "Opened" is SProp prop_status_object_open on that save id, readable for unloaded levels too.
-- The map screen wipes NpcMarkMap (ClearNpcMark) and re-adds the NPC icons every time it opens, so markers are
-- re-added by the tick whenever the mark count drops below what we left there.
local function icon_for(t)
    local p = CFG.map_icons and CFG.map_icons[t] or nil
    p = p or "/Game/Assets/UMG/TextureAtlases/Map/Sign/Icon_Explore.Icon_Explore"
    if valid(M.icons[p]) then return M.icons[p] end
    local o = StaticFindObject(p)
    if not valid(o) then pcall(function() LoadAsset(p) end); o = StaticFindObject(p) end
    if valid(o) then M.icons[p] = o; return o end
    return nil
end
local function build_cands(mm)
    local list = {}
    local ok, err = pcall(function()
        mm.DropItemDT:ForEachRow(function(_, row)
            local t = row.Type:ToString()
            if CFG.map_item_types[t] then
                list[#list + 1] = { t = t, sid = row.SaveDataID, x = row.WorldLocation.X, z = row.WorldLocation.Z }
            end
        end)
    end)
    if not ok then log("map items: DropItemInfo read failed: " .. tostring(err)); return nil end
    log("map items: " .. #list .. " candidate pickups in DropItemInfo")
    return list
end
local function our_icon_names()
    local set = {}
    for t, on in pairs(CFG.map_item_types) do
        if on then local ic = icon_for(t); if ic then set[ic:GetFullName()] = true end end
    end
    return set
end
local function remove_marks(mm)
    local set, keys = our_icon_names(), {}
    pcall(function()
        mm.NpcMarkMap:ForEach(function(k, v)
            local ic = v:get()
            if ic and set[ic:GetFullName()] then keys[#keys + 1] = k:get() end
        end)
    end)
    for _, k in ipairs(keys) do pcall(function() mm.NpcMarkMap:Remove(k) end) end
    return #keys
end
local function add_marks(mm)
    if not M.cands then M.cands = build_cands(mm) end
    if not M.cands then return 0 end
    local lib = splib()
    remove_marks(mm)
    local added = 0
    for _, r in ipairs(M.cands) do
        local collected = false
        if r.t ~= "NPC_Soul_Echo" and lib then
            local ok, v = pcall(function() return lib:GetNumberValueBySaveID(r.sid, ID.object_open) end)
            collected = ok and type(v) == "number" and v ~= 0
        end
        if not collected then
            local ic = icon_for(r.t)
            if ic and pcall(function() mm:AddNpcMark(r.x, r.z, ic) end) then added = added + 1 end
        end
    end
    pcall(function() mm:UpdateRenderingMinimapInfo() end)
    M.expected = #mm.NpcMarkMap
    M.last_count = added
    return added
end
local function map_items_tick(pc)
    local mm = pc.MinimapComp
    if not valid(mm) then return end
    if not S.map_items then
        if M.expected > 0 then remove_marks(mm); M.expected = 0; M.last_count = nil; pcall(function() mm:UpdateRenderingMinimapInfo() end) end
        return
    end
    if M.dirty or #mm.NpcMarkMap < M.expected or M.expected == 0 then
        M.dirty = false
        local n = add_marks(mm)
        if CFG.debug then log("map items: marked " .. n) end
    end
end

---------------------------------------------------------------- reveal map (MinimapComponent.MinimapCombinerMID.FogMaskTex)
-- The map material multiplies the map by a fog mask texture; a black mask hides everything, white shows everything.
-- Display only: exploration % and save data are untouched. The game's own mask is put back when turned off.
local function addr(o) local ok, a = pcall(function() return o:GetAddress() end); if ok then return a end return o:GetFullName() end
local function fog_tex(mid)
    local cur = nil
    pcall(function()
        local tp = mid.TextureParameterValues
        for i = 1, #tp do
            if tp[i].ParameterInfo.Name:ToString() == "FogMaskTex" then cur = tp[i].ParameterValue end
        end
    end)
    return cur
end
local function map_reveal_tick(pc)
    local mm = pc.MinimapComp
    if not valid(mm) then return end
    local mid = mm.MinimapCombinerMID
    if not valid(mid) then return end
    if not valid(M.white) then M.white = StaticFindObject("/Engine/EngineResources/WhiteSquareTexture.WhiteSquareTexture") end
    if not valid(M.white) then return end
    local cur = fog_tex(mid)
    local is_white = valid(cur) and addr(cur) == addr(M.white)
    if S.map_reveal then
        if not is_white then
            if valid(cur) then M.orig_fog = cur end
            mid:SetTextureParameterValue(FName("FogMaskTex"), M.white)
        end
    elseif M.orig_fog ~= nil then
        if is_white and valid(M.orig_fog) then mid:SetTextureParameterValue(FName("FogMaskTex"), M.orig_fog) end
        M.orig_fog = nil
        pcall(function() mm:UpdateRenderingMinimapInfo() end)
    end
end

---------------------------------------------------------------- corner minimap (v1.2.0, see minimap.lua)
local MINI = nil
do
    local okm, factory = pcall(dofile, DIR .. "minimap.lua")
    if okm and type(factory) == "function" then
        local okc, api = pcall(factory, {
            cfg = CFG.minimap, valid = valid, log = log, splib = splib, icon_for = icon_for,
            object_open_id = ID.object_open, key_name = CFG.keys.minimap,
            items_on = function() return S.map_items end,
            item_candidates = function()
                if not M.cands then local pc = player(); if pc and valid(pc.MinimapComp) then M.cands = build_cands(pc.MinimapComp) end end
                return M.cands
            end,
        })
        if okc then MINI = api else log("minimap init failed: " .. tostring(api)) end
    else
        log("minimap.lua failed to load: " .. tostring(factory))
    end
end
local MINI_MODES = { [0] = "OFF", [1] = "FOLLOW", [2] = "REGION" }
S.minimap = CFG.defaults.minimap or 0
if MINI then MINI.set_mode(S.minimap) end
local function minimap_frame()
    if not MINI or S.minimap == 0 or not ready() then return end
    local pc = player()
    if pc then local ok, e = pcall(MINI.frame, pc); if not ok then log("minimap frame error: " .. tostring(e)); S.minimap_err = (S.minimap_err or 0) + 1 end end
end
-- Airborne = MOVE_Falling, or a custom move mode (air dash etc.) entered while we were already in the air.
-- (Deliberately avoids CharacterMovement.CurrentFloor: copying that struct from Lua crashed the game.)
local function is_airborne(cm)
    local mode = cm.MovementMode
    if mode == 3 then S.in_air = true; return true end
    if mode == 6 then return S.in_air == true end
    S.in_air = false
    return false
end
local function do_air_jump(force)
    local pc = player(); if not pc then return false end
    local cm = pc.CharacterMovement
    if not force then
        local now = os.clock()
        S.why = nil
        if not is_airborne(cm) then S.why = "grounded"; return false end
        if now - S.last_ground < 0.10 then S.why = "takeoff"; return false end        -- let the game do the first (ground) jump
        if now - (S.last_air_jump or 0) < 0.15 then S.why = "debounce"; return false end
        if is_paused(pc) then S.why = "paused"; return false end
        local ws = false
        pcall(function() ws = cm.bIsWallSliding == true end)
        if ws then S.why = "wallslide"; return false end                               -- the game's own wall jump handles this
    end
    local ok = pcall(function() pc:LaunchCharacter({ X = 0.0, Y = 0.0, Z = cm.JumpZVelocity }, false, true) end)
    if ok then T.jump_calls = T.jump_calls + 1; S.last_air_jump = os.clock() end
    return ok
end

-- The jump key is read from the game's own input mapping (action "ControllerA"), so keyboard re-binds and
-- gamepad A both work. Rising edge of that action while airborne => extra jump.
local jump_key_names, jump_keys_at = {}, -100
local function refresh_jump_keys()
    local names = {}
    pcall(function()
        local am = StaticFindObject("/Script/Engine.Default__InputSettings").ActionMappings
        for i = 1, #am do
            local m = am[i]
            if m.ActionName:ToString() == "ControllerA" then names[#names + 1] = m.Key.KeyName:ToString() end
        end
    end)
    if #names == 0 then names = { "SpaceBar", "Gamepad_FaceButton_Bottom" } end
    jump_key_names, jump_keys_at = names, os.clock()
end
local function jump_poll()
    local pc = player(); if not pc then return end
    local cm = pc.CharacterMovement
    if not (cm and cm:IsValid()) then return end
    local air = is_airborne(cm)
    if not air then S.last_ground = os.clock() end
    if CFG.debug and air ~= S.dbg_air then
        S.dbg_air = air
        log(string.format("airborne=%s mode=%s Vz=%.0f", tostring(air), tostring(cm.MovementMode), cm.Velocity.Z))
    end
    if not S.jump then S.jump_was_down = false; return end
    if os.clock() - jump_keys_at > 2.0 then refresh_jump_keys() end
    local ctrl = controller()
    if not ctrl then return end
    local down = false
    for _, k in ipairs(jump_key_names) do
        local ok, r = pcall(function() return ctrl:IsInputKeyDown({ KeyName = FName(k) }) end)
        if ok and r then down = true break end
    end
    if down and not S.jump_was_down then
        local fired = do_air_jump(false)
        if CFG.debug then
            log(string.format("jump key down (keys=%s) mode=%s since_ground=%.2f fired=%s why=%s", table.concat(jump_key_names, "+"), tostring(cm.MovementMode), os.clock() - S.last_ground, tostring(fired), tostring(S.why)))
        end
    end
    S.jump_was_down = down
end
---------------------------------------------------------------- God Mode HP guard (v1.3.1)
-- A trap / hit that takes HP to 0 (or below) starts the game's death sequence on the very next game tick (~4 ms later),
-- and the 25 ms main loop is too slow for that. This guard runs every rendered frame, before that death handler, and puts
-- HP back, both the current value (SetSPropertyCurrNumberValue) and the base value that scene objects write
-- (SetSPropertyNumberValue). Checked live: HP forced to 0 or to -50 with God Mode ON no longer kills the character.
local function god_heal(sp, mh)
    sset_cur(sp, ID.hp, mh)
    local b = sbase(sp, ID.hp)
    if b and b < mh then sset_base(sp, ID.hp, mh) end
end
local function god_frame()
    if not S.god or not ready() then return end
    local pc = player(); if not pc then return end
    local sp = pc.SProp
    if not valid(sp) then return end
    local h, mh = sget(sp, ID.hp), sget(sp, ID.max_hp)
    if h and mh and mh > 0 and h < mh then
        god_heal(sp, mh)
        S.god_saves = (S.god_saves or 0) + 1
        if h <= 0.5 and CFG.debug then log(string.format("god guard: HP %.1f -> %.1f (saved from death)", h, mh)) end
    end
end
-- Primary protection: pre-hooks on the two HP setters of SPropComponent. With God Mode ON, a write that would take the PLAYER's HP
-- below 1 (a trap, a one-hit kill, fall damage ...) is rewritten to max HP before the game stores it, so the death sequence never
-- starts. Verified live: current-value write of 0 and base-value write of -50 both blocked, no death flag. The setters are rarely
-- called (a handful of times per second at most) and the callback returns at once unless God Mode is on and the property is HP.
-- Installed after the start-up delay; set god_hook = false in config.lua to use only the per-frame / per-tick guards.
local GH = { installed = false, blocked = 0 }
local function god_hook_cb(kind)
    return function(self, a, b)
        if not S.god then return end
        pcall(function()
            if a:get() ~= ID.hp then return end
            local pc = PC_CACHE
            if not valid(pc) then return end
            local sp = pc.SProp
            if self:get():GetAddress() ~= sp:GetAddress() then return end
            local v = b:get()
            if type(v) ~= "number" or v >= 1.0 then return end
            local cur = sget(sp, ID.hp)
            if cur and v >= cur then return end
            local mx = sget(sp, ID.max_hp)
            if mx and mx > 0 then
                b:set(mx)
                GH.blocked = GH.blocked + 1
                log(string.format("God Mode blocked a lethal HP write (%s %.1f, HP was %s) - total blocked %d", kind, v, tostring(cur), GH.blocked))
            end
        end)
    end
end
local function install_god_hooks()
    if GH.installed or CFG.god_hook == false then return end
    GH.installed = true
    local ok1 = pcall(function() RegisterHook("/Script/SPropertySystem.SPropComponent:SetSPropertyNumberValue", god_hook_cb("base")) end)
    local ok2 = pcall(function() RegisterHook("/Script/SPropertySystem.SPropComponent:SetSPropertyCurrNumberValue", god_hook_cb("current")) end)
    GH.ok = ok1 and ok2
    log("God Mode HP pre-hooks installed: " .. tostring(GH.ok))
end
---------------------------------------------------------------- mouse (cursor visible: click rows, drag the title, click the pill)
local function mouse_tick()
    if not HUD or not ready() then return end
    local c = controller()
    if not c then S.cursor_shown = false; return end
    local show = false
    pcall(function() show = c.bShowMouseCursor == true end)
    if S.mouse and not show then pcall(function() c.bShowMouseCursor = true end); show = true end
    S.cursor_shown = show
    if show then
        if not S.mouse_per_frame then local ok, e = pcall(HUD.mouse, c, true); if not ok then log("mouse error: " .. tostring(e)) end end
    else
        pcall(HUD.mouse, c, false)
    end
end
local function mouse_frame()
    if not S.cursor_shown or not HUD then return end
    local c = controller()
    if not c then return end
    local ok, e = pcall(HUD.mouse, c, true)
    if not ok then S.mouse_err = (S.mouse_err or 0) + 1; if S.mouse_err <= 3 then log("mouse error: " .. tostring(e)) end end
end
---------------------------------------------------------------- per-tick logic
local selftest_hook = nil
local tick_n = 0
local function tick()
    if not ready() then return end
    if not GH.installed then install_god_hooks() end
    tick_n = tick_n + 1
    if tick_n == 1 then S.rate_t0 = os.clock() elseif tick_n == 151 then log(string.format("main loop: %.1f ticks/s", 150 / math.max(0.001, os.clock() - S.rate_t0))) end
    local pc = player()
    if not pc then return end
    local sp = pc.SProp
    local cm = pc.CharacterMovement
    if not (sp and sp:IsValid() and cm and cm:IsValid()) then return end
    if S.god then
        local mh, h = sget(sp, ID.max_hp), sget(sp, ID.hp)
        if mh and h and h < mh then god_heal(sp, mh) end
        pcall(function() if pc.Invincible ~= true then pc.Invincible = true end end)
    end
    if S.mana then
        local mm, m = sget(sp, ID.max_mana), sget(sp, ID.mana)
        if mm and m and m < mm then sset_cur(sp, ID.mana, mm) end
    end
    if S.jump then pcall(function() pc:SetJumpCurrentCount(0) end) end
    if S.ohk and tick_n % 4 == 0 then
        local ens = FindAllOf("EnemyCharacter") or {}
        for _, e in ipairs(ens) do
            pcall(function()
                if e:IsValid() and not e:GetFullName():find("Default__") then
                    local esp = e.SProp
                    local h = sget(esp, ID.hp)
                    if h and h > 1.0 then sset_cur(esp, ID.hp, 1.0) end
                end
            end)
        end
    end
    if S.pending_defaults then S.pending_defaults = false; if S.speed then apply_speed() end; hud_refresh() end
    if S.dash then
        local mx, v = sget(sp, ID.dash_max), sget(sp, ID.dash_remain)
        if mx and v and v < mx then sset_cur(sp, ID.dash_remain, mx) end
    end
    if tick_n % 3 == 0 then
        local okm, em = pcall(map_items_tick, pc)
        if not okm then log("map items error: " .. tostring(em)) end
        local okr, er = pcall(map_reveal_tick, pc)
        if not okr then log("map reveal error: " .. tostring(er)) end
        if MINI then
            if tick_n % 9 == 0 then S.paused = is_paused(pc) end
            local okn, en = pcall(MINI.tick, pc, S.paused == true)
            if not okn then log("minimap error: " .. tostring(en)) end
        end
    end
    if MINI and not S.minimap_per_frame then minimap_frame() end
    if selftest_hook then local oks, es = pcall(selftest_hook); if not oks then log("selftest hook error: " .. tostring(es)) end end
    local okj, ej = pcall(jump_poll)
    if not okj then log("jump_poll error: " .. tostring(ej)) end
    mouse_tick()
    if tick_n % 6 == 0 then hud_refresh() end
end

---------------------------------------------------------------- toggles / keys
local function toggle(name)
    S[name] = not S[name]
    if name == "god" and not S.god then
        local pc = player(); if pc then pcall(function() pc.Invincible = false end) end
    end
    if name == "speed" then apply_speed() end
    log(name .. " = " .. tostring(S[name]))
    hud_refresh()
end
local function bind(action, fn)
    local kn = CFG.keys[action]
    if not kn then log("no key configured for " .. action); return end
    local mods, keyname = {}, kn
    for m in kn:gmatch("(%u+)%+") do
        local mk = ModifierKey and ModifierKey[m]
        if mk then mods[#mods + 1] = mk else log("unknown modifier " .. m .. " for " .. action) end
    end
    keyname = kn:match("([^+]+)$")
    local key = Key[keyname]
    if not key then log("unknown key for " .. action .. ": " .. tostring(kn)); return end
    local cb = function() ExecuteInGameThread(function() if ready() then fn() end end) end
    if #mods > 0 then RegisterKeyBind(key, mods, cb) else RegisterKeyBind(key, cb) end
end
ACTIONS.god        = function() toggle("god") end
ACTIONS.jump       = function() toggle("jump") end
ACTIONS.speed      = function() toggle("speed") end
ACTIONS.mana       = function() toggle("mana") end
ACTIONS.ohk        = function() toggle("ohk") end
ACTIONS.items      = function() add_bag_items(CFG.bag_item_amount); hud_refresh() end
ACTIONS.money_big  = function() add_money(CFG.money_big); hud_refresh() end
ACTIONS.heal       = function() full_heal(); log("full heal") end
ACTIONS.map_items  = function() toggle("map_items") end
ACTIONS.map_reveal = function() toggle("map_reveal") end
ACTIONS.dash       = function() toggle("dash") end
ACTIONS.talent     = function() add_talent(CFG.talent_points or 5); hud_refresh() end
ACTIONS.minimap    = function()
    S.minimap = ((S.minimap or 0) + 1) % 3     -- FOLLOW -> REGION -> OFF -> FOLLOW
    if MINI then MINI.set_mode(S.minimap) end
    log("minimap = " .. MINI_MODES[S.minimap])
    hud_refresh()
end
ACTIONS.hud        = function() S.hud = not S.hud; hud_refresh() end
ACTIONS.speed_cycle = function()
    S.speed_idx = (S.speed_idx % #CFG.speed_steps) + 1
    if S.speed then apply_speed() end
    log(string.format("speed multiplier x%.1f", speed_mult()))
    hud_refresh()
end
-- mouse mode: keeps the game's cursor visible so the panel rows can be clicked and the title dragged
ACTIONS.mouse      = function()
    S.mouse = not S.mouse
    local c = controller()
    if c then pcall(function() c.bShowMouseCursor = S.mouse end) end
    log("mouse mode = " .. tostring(S.mouse))
    hud_refresh()
end
for _, name in ipairs({ "god", "jump", "speed", "mana", "ohk", "items", "money_big", "heal", "map_items", "map_reveal", "dash", "talent", "minimap", "hud", "speed_cycle", "mouse" }) do
    bind(name, ACTIONS[name])
end
-- Unlimited jump: extra jump on the jump key (Space / gamepad A) while airborne
-- Raw Space key as a fallback for the poll above (debounced inside do_air_jump)
if CFG.space_fallback ~= false then pcall(function() RegisterKeyBind(Key.SPACE, function() ExecuteInGameThread(function()
    if S.jump and ready() then local r = do_air_jump(false); if CFG.debug then log("space fallback fired=" .. tostring(r) .. " why=" .. tostring(S.why)) end end
end) end) end) end

-- Main loop. v1.1.1: run it with UE4SS's game-thread timer (LoopInGameThreadWithDelay) instead of LoopAsync +
-- ExecuteInGameThread. LoopAsync runs its callback on UE4SS's async thread, so every 33 ms that thread touched the
-- mod's Lua state while the game thread was running trainer Lua too; the rare EXCEPTION_ACCESS_VIOLATION crashes
-- inside UE4SS's Lua code (crash dumps of 16/10 and 30/10) all came from that path. Old UE4SS builds fall back.
local function safe_tick() local ok, e = pcall(tick); if not ok then log("tick error: " .. tostring(e)) end end
local TICK_MODE
if type(LoopInGameThreadWithDelay) == "function" then
    LoopInGameThreadWithDelay(25, safe_tick)
    TICK_MODE = "game-thread timer"
else
    LoopAsync(33, function() ExecuteInGameThread(safe_tick); return false end)
    TICK_MODE = "LoopAsync fallback"
end
-- the minimap is moved every rendered frame (smooth scrolling) when the engine-tick timer exists
if MINI and EngineTickAvailable and type(LoopInGameThreadAfterFrames) == "function" then
    local okf = pcall(function() LoopInGameThreadAfterFrames(1, minimap_frame) end)
    if okf then S.minimap_per_frame = true; TICK_MODE = TICK_MODE .. ", minimap per frame" end
end
if HUD and EngineTickAvailable and type(LoopInGameThreadAfterFrames) == "function" then
    local okf = pcall(function() LoopInGameThreadAfterFrames(1, mouse_frame) end)
    if okf then S.mouse_per_frame = true; TICK_MODE = TICK_MODE .. ", mouse per frame" end
end
if EngineTickAvailable and type(LoopInGameThreadAfterFrames) == "function" then
    local okg = pcall(function() LoopInGameThreadAfterFrames(1, function() local ok, e = pcall(god_frame); if not ok then S.god_err = (S.god_err or 0) + 1; if S.god_err <= 3 then log("god guard error: " .. tostring(e)) end end end) end)
    if okg then S.god_per_frame = true; TICK_MODE = TICK_MODE .. ", god guard per frame" end
end-- (HUD / defaults are applied by the first ticks after the start-up delay)
S.pending_defaults = true

---------------------------------------------------------------- self-test (TRAINER_SELFTEST=1 or selftest.flag)
local function file_exists(p) local f = io.open(p, "r"); if f then f:close(); return true end return false end
local function selftest_requested()
    return os.getenv("TRAINER_SELFTEST") == "1" or file_exists(DIR .. "..\\selftest.flag")
end
local function jstr(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
local function write_report(results)
    local all = true
    local parts = {}
    for _, r in ipairs(results) do
        if r.status ~= "PASS" and r.status ~= "SKIP" then all = false end
        parts[#parts + 1] = string.format('    {"feature_id": %s, "status": %s, "detail": %s}', jstr(r.id), jstr(r.status), jstr(r.detail))
    end
    local f = io.open("AI_Trainer_selftest_report.json", "w")
    if f then
        f:write('{\n  "trainer": "AI_Trainer ' .. VERSION .. '",\n  "overall_status": ' .. jstr(all and "PASS_READY_FOR_HUMAN" or "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL") ..
                ',\n  "feature_results": [\n' .. table.concat(parts, ",\n") .. "\n  ]\n}\n")
        f:close()
    end
    log("self-test report written: " .. (all and "ALL PASS" or "SOME FAILED"))
end
local function after(ms, fn)
    local function step() local ok, e = pcall(fn); if not ok then log("selftest step error: " .. tostring(e)) end end
    if type(ExecuteInGameThreadWithDelay) == "function" then ExecuteInGameThreadWithDelay(ms, step)
    else ExecuteWithDelay(ms, function() ExecuteInGameThread(step) end) end
end

local function run_selftest_core(R)
    local function rec(id, ok, detail) R[#R + 1] = { id = id, status = ok and "PASS" or "FAIL", detail = detail } end
    local pc = player(); local sp = pc.SProp; local cm = pc.CharacterMovement
    local saved = { god = S.god, jump = S.jump, speed = S.speed, mana = S.mana, ohk = S.ohk }
    local mh0, mm0 = sget(sp, ID.max_hp), sget(sp, ID.max_mana)
    local hp0, mana0 = sget(sp, ID.hp), sget(sp, ID.mana)
    -- 1) hooks / invariants
    rec("INVARIANTS", mh0 and mh0 > 0 and mh0 < 1e6 and hp0 and hp0 > 0 and hp0 <= mh0 + 0.01 and mm0 and mm0 > 0,
        string.format("hp=%s/%s mana=%s/%s", tostring(hp0), tostring(mh0), tostring(mana0), tostring(mm0)))
    -- 2) money delta (+10 then -10)
    local ok_m, b, a = add_money(10)
    local back = add_money(-10)
    rec("MONEY", ok_m and a == b + 10 and back, string.format("before=%s after+10=%s", tostring(b), tostring(a)))
    -- 3) heal
    sset_cur(sp, ID.hp, 1.0); sset_cur(sp, ID.mana, 0.0); full_heal()
    rec("HEAL", sget(sp, ID.hp) == mh0 and sget(sp, ID.mana) == mm0, string.format("hp=%s mana=%s", tostring(sget(sp, ID.hp)), tostring(sget(sp, ID.mana))))
    -- 4) speed
    local base_speed = cm.MaxWalkSpeed
    S.speed = true; apply_speed()
    after(400, function()
        local fast = cm.MaxWalkSpeed
        S.speed = false; apply_speed()
        after(400, function()
            local restored = cm.MaxWalkSpeed
            rec("SPEED", math.abs(fast - base_speed * speed_mult()) < 1 and math.abs(restored - base_speed) < 1,
                string.format("base=%s boosted=%s restored=%s", tostring(base_speed), tostring(fast), tostring(restored)))
            -- 5) god mode
            sset_cur(sp, ID.hp, math.max(1.0, mh0 * 0.5)); S.god = true
            after(500, function()
                local hp_g, inv = sget(sp, ID.hp), pc.Invincible
                S.god = false; pc.Invincible = false
                rec("GOD", hp_g == mh0 and inv == true, string.format("hp=%s invincible=%s", tostring(hp_g), tostring(inv)))
                -- 5b) a write that would kill (HP 0) must be rewritten by the God Mode pre-hook, and the death flag must stay 0
                S.god = true; pc.Invincible = true
                sset_cur(sp, ID.hp, 0.0)
                local hl_now = sget(sp, ID.hp)
                after(300, function()
                    local hl, dead = sget(sp, ID.hp), sget(sp, ID.actor_dead)
                    if not saved.god then S.god = false; pc.Invincible = false end
                    rec("GOD_LETHAL_WRITE", hl_now == mh0 and hl == mh0 and dead == 0, string.format("HP written 0 -> now %s, later %s, dead flag %s, hook installed %s, blocked %d", tostring(hl_now), tostring(hl), tostring(dead), tostring(GH.ok), GH.blocked))
                end)
                -- 6) infinite mana
                sset_cur(sp, ID.mana, 0.0); S.mana = true
                after(500, function()
                    local m = sget(sp, ID.mana); S.mana = false
                    rec("MANA", m == mm0, "mana=" .. tostring(m))
                    -- 7) unlimited jump (forced air jump, velocity check)
                    local ok_j = do_air_jump(true)
                    after(60, function()
                        local vz = cm.Velocity.Z
                        rec("JUMP", ok_j and vz > cm.JumpZVelocity * 0.5, string.format("launch ok=%s Vz=%s JumpZ=%s", tostring(ok_j), tostring(vz), tostring(cm.JumpZVelocity)))
                        -- 8) one-hit kill
                        local function find_enemy()
                            local ens = FindAllOf("EnemyCharacter") or {}
                            for _, e in ipairs(ens) do
                                if valid(e) and not e:GetFullName():find("Default__") then
                                    local h = sget(e.SProp, ID.hp)
                                    if h and h > 1.5 then return e end   -- a living enemy
                                end
                            end
                            return nil
                        end
                        local e1 = find_enemy()
                        local waited = 0
                        local function proceed()
                        if not e1 then
                            R[#R + 1] = { id = "ONE_HIT_KILL", status = "SKIP", detail = "no EnemyCharacter loaded" }
                            S.god, S.jump, S.speed, S.mana, S.ohk = saved.god, saved.jump, saved.speed, saved.mana, saved.ohk
                            write_report(R)
                        else
                            local esp = e1.SProp
                            local eh0 = sget(esp, ID.hp)
                            S.ohk = true
                            after(500, function()
                                local eh = sget(esp, ID.hp)
                                S.ohk = false
                                sset_cur(esp, ID.hp, eh0)
                                rec("ONE_HIT_KILL", eh ~= nil and eh <= 1.0 and eh0 > 1.5, string.format("enemy hp %s -> %s", tostring(eh0), tostring(eh)))
                                sset_cur(sp, ID.hp, hp0 or mh0); sset_cur(sp, ID.mana, mana0 or mm0)
                                S.god, S.jump, S.speed, S.mana, S.ohk = saved.god, saved.jump, saved.speed, saved.mana, saved.ohk
                                apply_speed()
                                write_report(R)
                            end)
                        end
                        end -- proceed
                        local function wait_enemy()
                            if e1 or waited >= 20 then proceed(); return end
                            waited = waited + 1
                            after(1000, function() e1 = find_enemy(); wait_enemy() end)
                        end
                        wait_enemy()
                    end)
                end)
            end)
        end)
    end)
end

-- v1.1.0 features: talent points, infinite dash, map item markers, map reveal; then the 1.0 core tests.
local function run_selftest()
    local R = {}
    local function rec(id, ok, detail) R[#R + 1] = { id = id, status = ok and "PASS" or "FAIL", detail = detail } end
    local pc = player(); local sp = pc.SProp; local mm = pc.MinimapComp
    local saved = { map_items = S.map_items, map_reveal = S.map_reveal, dash = S.dash }
    -- TALENT: +1 then -1 on prop_talent_point_sum
    local t_ok, t_b, t_a = add_talent(1)
    local t_ok2 = add_talent(-1)
    rec("TALENT_POINTS", t_ok and t_a == t_b + 1 and t_ok2 and sget(sp, ID.talent_sum) == t_b,
        string.format("sum before=%s after+1=%s restored=%s used=%s", tostring(t_b), tostring(t_a), tostring(sget(sp, ID.talent_sum)), tostring(sget(sp, ID.talent_used))))
    -- DASH: empty the air-dash counter, let the tick refill it
    local d_max = sget(sp, ID.dash_max)
    sset_cur(sp, ID.dash_remain, 0.0); S.dash = true
    after(300, function()
        local d_now = sget(sp, ID.dash_remain); S.dash = saved.dash
        rec("INFINITE_DASH", d_max and d_max >= 1 and d_now == d_max, string.format("max=%s remain after refill=%s", tostring(d_max), tostring(d_now)))
        -- MAP_ITEMS: markers added on top of the game's own marks
        local n0 = #mm.NpcMarkMap
        S.map_items = true
        after(400, function()
            local n1 = #mm.NpcMarkMap
            local added = M.last_count or 0
            S.map_items = false
            after(400, function()
                local n2 = #mm.NpcMarkMap
                rec("MAP_ITEMS", M.cands and #M.cands > 0 and added > 0 and n1 > n0 and n2 == n0,
                    string.format("candidates=%s marks before=%d on=%d (+%d) off=%d", tostring(M.cands and #M.cands), n0, n1, added, n2))
                -- MAP_REVEAL: fog mask swapped to white and restored
                local mid = mm.MinimapCombinerMID
                local f0 = fog_tex(mid)
                S.map_reveal = true
                after(400, function()
                    local f1 = fog_tex(mid)
                    S.map_reveal = false
                    after(400, function()
                        local f2 = fog_tex(mid)
                        local w = M.white
                        rec("MAP_REVEAL", valid(f0) and valid(f1) and valid(w) and addr(f1) == addr(w) and valid(f2) and addr(f2) == addr(f0),
                            string.format("mask %s -> %s -> %s", valid(f0) and f0:GetFName():ToString() or "nil", valid(f1) and f1:GetFName():ToString() or "nil", valid(f2) and f2:GetFName():ToString() or "nil"))
                        S.map_items, S.map_reveal, S.dash = saved.map_items, saved.map_reveal, saved.dash
                        -- MINIMAP: widget shown in REGION mode, player icon follows a forced jump in real time
                        local function finish() run_selftest_core(R) end
                        if not MINI then rec("MINIMAP", false, "minimap.lua not loaded"); finish(); return end
                        local m0 = S.minimap
                        S.minimap = 2; MINI.set_mode(2)
                        after(700, function()
                            local st = MINI.state()
                            local nvis = 0
                            for _, L in ipairs(st.layers or {}) do if L.vis then nvis = nvis + 1 end end
                            local okp, p0 = pcall(function() local v = st.player_slot:GetPosition(); return { X = v.X, Y = v.Y } end)
                            local z0 = pc:K2_GetActorLocation().Z
                            do_air_jump(true)
                            after(350, function()
                                local okq, p1 = pcall(function() local v = st.player_slot:GetPosition(); return { X = v.X, Y = v.Y } end)
                                local z1 = pc:K2_GetActorLocation().Z
                                local moved = okp and okq and p1.Y < p0.Y - 0.2
                                rec("MINIMAP", valid(st.widget) and st.shown == true and nvis > 0 and moved,
                                    string.format("shown=%s regions drawn=%d icon y %.1f -> %.1f while player z %.0f -> %.0f",
                                        tostring(st.shown), nvis, okp and p0.Y or -1, okq and p1.Y or -1, z0, z1))
                                S.minimap = m0; MINI.set_mode(m0)
                                finish()
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end
if selftest_requested() then
    log("SELF-TEST requested")
    local started, stable = false, 0
    selftest_hook = function()
        if started then return end
        local pc = player()
        if pc and sget(pc.SProp, ID.max_hp) then
            stable = stable + 1
            local e = FindFirstOf("EnemyCharacter")
            local enemy_ready = valid(e) and not e:GetFullName():find("Default__")
            -- run once the player has been stable for ~3 s and an enemy is loaded (or after ~90 s regardless)
            local grounded = false
            pcall(function() grounded = pc.CharacterMovement.MovementMode == 1 end)
            S.st_ground = grounded and ((S.st_ground or 0) + 1) or 0
            -- start once the player has stood on the ground for ~5 s (a level that is still loading fails the minimap test)
            if (stable > 90 and enemy_ready and S.st_ground > 150) or stable > 2700 then
                started = true; selftest_hook = nil
                after(500, run_selftest)
            end
        else
            stable = 0
        end
    end
end
log("loaded v" .. VERSION .. " - " .. CFG.keys.god .. " God, " .. CFG.keys.items .. " Bag Items, " .. CFG.keys.money_big .. " Money, " .. CFG.keys.jump .. " Jump, " .. CFG.keys.speed .. " Speed, " .. CFG.keys.mana .. " Mana, " .. CFG.keys.ohk .. " OHK, " .. CFG.keys.heal .. " Heal, " ..
    CFG.keys.map_items .. " Map Items, " .. CFG.keys.map_reveal .. " Reveal Map, " .. CFG.keys.talent .. " Talent Points, " .. CFG.keys.dash .. " Infinite Dash, " .. CFG.keys.minimap .. " Minimap, " .. CFG.keys.mouse .. " Mouse mode; main loop: " .. tostring(TICK_MODE))
