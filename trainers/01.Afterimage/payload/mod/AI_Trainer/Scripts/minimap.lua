-- AI_Trainer corner minimap (UMG built at runtime). Loaded by main.lua: dofile(DIR .. "minimap.lua")(ctx).
--
-- Data source: the game's own map art. MinimapComponent.MinimapUIInfoCollection (/Game/Assets/Minimap/
-- MinimapEditorUICollection) has, per region, Bound (Box2D in "map units") and Texture_M (room fill) / Texture_S
-- (walls/outline). Map units = world units * 0.04 with Y = -WorldZ, and 1 map unit = 1 texel of those textures.
-- MinimapComponent.MinimapCollection.MinimapInfoMap[region].BaseBound (world units) is the part of a region that
-- has rooms; used to frame the "whole region" view. Everything is placed in one shared coordinate system, so
-- neighbouring regions line up and the view can cross region borders.
return function(ctx)
    local CFGM = ctx.cfg or {}
    local W = CFGM.width or 380.0
    local Hh = CFGM.height or 230.0
    local MX, MY = CFGM.margin_x or 30.0, CFGM.margin_y or 30.0
    local ZOOM = CFGM.zoom or 0.6               -- screen px per map unit in "follow" mode
    -- FOLLOW zoom while Map Item Markers is ON: the normal 0.6 only shows +-317 x +-192 map units, and a pickup is
    -- usually further away than that (measured: nearest one is outside the view in most places), so it looked empty.
    local ZOOM_ITEMS = CFGM.zoom_items or 0.3
    local SCALE = 0.04                          -- MinimapCollection.MinimapScale (world -> map units)
    local MAXICONS = CFGM.max_item_icons or 60
    local valid, log = ctx.valid, ctx.log

    local MM = { widget = nil, root = nil, clip = nil, layers = {}, regions = nil, player_img = nil, player_slot = nil,
                 icons = {}, near = {}, near_at = -100, mode = 0, shown = nil, label = nil, label_text = nil }

    local function uid(n) return FName(string.format("AIMini_%s_%d_%d", n, math.floor(os.clock() * 1000), math.random(1, 1e6))) end
    local function cls(p) return StaticFindObject(p) end

    -- region table (once): name -> { x0, y0, x1, y1 (map units), M, S textures, base = {x0,y0,x1,y1} }
    local function load_regions(mm)
        local R, base = {}, {}
        pcall(function()
            mm.MinimapCollection.MinimapInfoMap:ForEach(function(k, v)
                local val = v:get()
                local b = val.BaseBound
                base[val.Name:ToString():lower()] = { x0 = b.Min.X * SCALE, x1 = b.Max.X * SCALE, y0 = -b.Max.Y * SCALE, y1 = -b.Min.Y * SCALE }
            end)
        end)
        pcall(function()
            mm.MinimapUIInfoCollection.MinimapInfoMap:ForEach(function(k, v)
                local name = k:get():ToString()
                local val = v:get()
                local b = val.Bound
                local tm, ts = val.Texture_M, val.Texture_S
                if valid(tm) or valid(ts) then
                    R[#R + 1] = { name = name, x0 = b.Min.X, y0 = b.Min.Y, x1 = b.Max.X, y1 = b.Max.Y,
                                  M = valid(tm) and tm or nil, S = valid(ts) and ts or nil, base = base[name:lower()] }
                end
            end)
        end)
        return R
    end

    local function new_image(tree, name, tex, tint)
        local img = StaticConstructObject(cls("/Script/UMG.Image"), tree, uid(name))
        if tex then img:SetBrushFromTexture(tex, false) end
        if tint then img:SetColorAndOpacity(tint) end
        return img
    end

    local function build(pc)
        local mm = pc.MinimapComp
        if not valid(mm) then return false end
        if not MM.regions then MM.regions = load_regions(mm) end
        if #MM.regions == 0 then log("minimap: no map regions found"); return false end
        local ok, err = pcall(function()
            local gi = FindFirstOf("GameInstance")
            local w = StaticConstructObject(cls("/Script/UMG.UserWidget"), gi, uid("W"))
            local tree = StaticConstructObject(cls("/Script/UMG.WidgetTree"), w, uid("Tree"))
            w.WidgetTree = tree
            local root = StaticConstructObject(cls("/Script/UMG.CanvasPanel"), tree, uid("Root"))
            tree.RootWidget = root
            local function corner(widget, x, y, sx, sy)   -- slot anchored to the bottom-right corner
                local s = root:AddChildToCanvas(widget)
                s:SetAnchors({ Minimum = { X = 1.0, Y = 1.0 }, Maximum = { X = 1.0, Y = 1.0 } })
                s:SetAlignment({ X = 1.0, Y = 1.0 })
                s:SetPosition({ X = x, Y = y })
                s:SetSize({ X = sx, Y = sy })
                return s
            end
            local fc = CFGM.frame_color or { R = 0.55, G = 0.42, B = 0.18, A = 0.95 }
            corner(new_image(tree, "Frame", nil, fc), -MX + 2.0, -MY + 2.0, W + 4.0, Hh + 4.0)
            local clip = StaticConstructObject(cls("/Script/UMG.CanvasPanel"), tree, uid("Clip"))
            clip:SetClipping(1)                         -- EWidgetClipping::ClipToBounds
            corner(clip, -MX, -MY, W, Hh)
            local bgc = CFGM.background_color or { R = 0.004, G = 0.006, B = 0.012, A = 0.88 }
            local bg = new_image(tree, "Bg", nil, bgc)
            local bs = clip:AddChildToCanvas(bg); bs:SetPosition({ X = 0.0, Y = 0.0 }); bs:SetSize({ X = W, Y = Hh })
            MM.layers = {}
            local mt = CFGM.room_tint or { R = 1.0, G = 0.80, B = 0.55, A = 1.0 }
            for _, r in ipairs(MM.regions) do
                local L = { r = r }
                if r.M then L.mi = new_image(tree, "M", r.M, mt); L.ms = clip:AddChildToCanvas(L.mi); L.mi:SetVisibility(1) end
                if r.S then L.si = new_image(tree, "S", r.S, nil); L.ss = clip:AddChildToCanvas(L.si); L.si:SetVisibility(1) end
                L.vis = false
                MM.layers[#MM.layers + 1] = L
            end
            -- item icons pool (only used while Map Item Markers is ON)
            MM.icons = {}
            for i = 1, MAXICONS do
                local img = new_image(tree, "Ic" .. i, nil, nil)
                local s = clip:AddChildToCanvas(img); s:SetSize({ X = 14.0, Y = 14.0 }); s:SetAlignment({ X = 0.5, Y = 0.5 })
                img:SetVisibility(1)
                MM.icons[i] = { img = img, slot = s, tex = nil, vis = false }
            end
            local ptex = valid(mm.PlayerTexture) and mm.PlayerTexture or nil
            local pi = new_image(tree, "Player", ptex, ptex and nil or { R = 1.0, G = 0.85, B = 0.2, A = 1.0 })
            local ps = clip:AddChildToCanvas(pi)
            local psz = CFGM.player_icon_size or 30.0
            ps:SetSize({ X = psz, Y = psz }); ps:SetAlignment({ X = 0.5, Y = 0.5 })
            MM.player_img, MM.player_slot = pi, ps
            local tb = StaticConstructObject(cls("/Script/UMG.TextBlock"), tree, uid("Label"))
            tb:SetText(FText(""))
            tb:SetColorAndOpacity({ SpecifiedColor = { R = 1.0, G = 0.92, B = 0.6, A = 1.0 }, ColorUseRule = 0 })
            local ls = root:AddChildToCanvas(tb)
            ls:SetAnchors({ Minimum = { X = 1.0, Y = 1.0 }, Maximum = { X = 1.0, Y = 1.0 } })
            ls:SetAlignment({ X = 1.0, Y = 1.0 })
            ls:SetPosition({ X = -MX, Y = -MY - Hh - 6.0 })
            ls:SetAutoSize(true)
            pcall(function() local f = tb.Font; f.Size = 14; tb:SetFont(f) end)
            MM.label = tb; MM.label_text = nil
            w:AddToViewport(9990)
            w:SetVisibility(3)                           -- HitTestInvisible
            MM.widget, MM.root, MM.clip, MM.shown = w, root, clip, true
        end)
        if not ok then log("minimap build failed: " .. tostring(err)); MM.widget = nil; return false end
        log("minimap: built with " .. #MM.regions .. " regions")
        return true
    end

    local function set_shown(b)
        if MM.shown == b or not valid(MM.widget) then return end
        MM.shown = b
        pcall(function() MM.widget:SetVisibility(b and 3 or 1) end)
    end

    -- current region of the player (by map units), cached
    local function region_at(px, py)
        for _, r in ipairs(MM.regions) do
            local b = r.base or r
            if px >= b.x0 and px <= b.x1 and py >= b.y0 and py <= b.y1 then return r end
        end
        for _, r in ipairs(MM.regions) do
            if px >= r.x0 and px <= r.x1 and py >= r.y0 and py <= r.y1 then return r end
        end
        return nil
    end

    -- per-frame placement. view centre (cx, cy) in map units, zoom z = screen px per map unit
    local function place(px, py, cx, cy, z)
        local hw, hh = W * 0.5, Hh * 0.5
        for _, L in ipairs(MM.layers) do
            local r = L.r
            local sx0, sy0 = hw + (r.x0 - cx) * z, hh + (r.y0 - cy) * z
            local sw, sh = (r.x1 - r.x0) * z, (r.y1 - r.y0) * z
            local vis = sx0 < W and sy0 < Hh and sx0 + sw > 0 and sy0 + sh > 0
            if vis ~= L.vis then
                L.vis = vis
                if L.mi then L.mi:SetVisibility(vis and 3 or 1) end
                if L.si then L.si:SetVisibility(vis and 3 or 1) end
            end
            if vis then
                local pos, size = { X = sx0, Y = sy0 }, { X = sw, Y = sh }
                if L.ms then L.ms:SetPosition(pos); if L.z ~= z then L.ms:SetSize(size) end end
                if L.ss then L.ss:SetPosition(pos); if L.z ~= z then L.ss:SetSize(size) end end
                L.z = z
            end
        end
        MM.player_slot:SetPosition({ X = hw + (px - cx) * z, Y = hh + (py - cy) * z })
        -- item icons
        local n = 0
        if ctx.items_on() then
            for _, it in ipairs(MM.near) do
                local ix, iy = hw + (it.x - cx) * z, hh + (it.y - cy) * z
                if ix > -8 and iy > -8 and ix < W + 8 and iy < Hh + 8 and n < MAXICONS then
                    n = n + 1
                    local slot = MM.icons[n]
                    if slot.tex ~= it.icon then slot.tex = it.icon; slot.img:SetBrushFromTexture(it.icon, false) end
                    slot.slot:SetPosition({ X = ix, Y = iy })
                    if not slot.vis then slot.vis = true; slot.img:SetVisibility(3) end
                end
            end
        end
        for i = n + 1, MAXICONS do local s = MM.icons[i]; if s.vis then s.vis = false; s.img:SetVisibility(1) end end
    end

    -- refresh the list of uncollected pickups near the player (about once a second)
    local function refresh_near(px, py, range)
        MM.near = {}
        local list = ctx.item_candidates()
        if not list then return end
        local lib = ctx.splib()
        for _, c in ipairs(list) do
            local x, y = c.x * SCALE, -c.z * SCALE
            if math.abs(x - px) < range and math.abs(y - py) < range then
                local collected = false
                if c.t ~= "NPC_Soul_Echo" and lib then
                    local ok, v = pcall(function() return lib:GetNumberValueBySaveID(c.sid, ctx.object_open_id) end)
                    collected = ok and type(v) == "number" and v ~= 0
                end
                local ic = ctx.icon_for(c.t)
                if not collected and ic then MM.near[#MM.near + 1] = { x = x, y = y, icon = ic } end
            end
        end
    end

    local api = {}
    api.MODES = { "OFF", "FOLLOW", "REGION" }
    function api.set_mode(m) MM.mode = m; if m == 0 then set_shown(false) end end
    function api.mode() return MM.mode end
    function api.state() return MM end
    -- visibility decisions (called from the main tick, a few times a second)
    function api.tick(pc, paused)
        if MM.mode == 0 or not pc then set_shown(false); return end
        if not valid(MM.widget) then MM.widget = nil; if not build(pc) then return end end
        pcall(function() if not MM.widget:IsInViewport() then MM.widget:AddToViewport(9990) end end)
        set_shown(not (paused and CFGM.hide_when_paused ~= false))
    end
    -- placement (called every frame when possible)
    function api.frame(pc)
        if MM.mode == 0 or not pc or not MM.shown or not valid(MM.widget) then return end
        local loc = pc:K2_GetActorLocation()
        local px, py = loc.X * SCALE, -loc.Z * SCALE
        local cx, cy, z = px, py, (ctx.items_on() and ZOOM_ITEMS or ZOOM)
        local reg = region_at(px, py)
        if MM.mode == 2 and reg then
            local b = reg.base or reg
            cx, cy = (b.x0 + b.x1) * 0.5, (b.y0 + b.y1) * 0.5
            z = math.min(W / math.max(1, b.x1 - b.x0), Hh / math.max(1, b.y1 - b.y0)) * 0.95
        end
        if ctx.items_on() and os.clock() - MM.near_at > 1.0 then
            MM.near_at = os.clock()
            local range = math.max(W, Hh) / z
            refresh_near(cx, cy, range)
        end
        place(px, py, cx, cy, z)
        local lt = (reg and reg.name or "?") .. "  [" .. (ctx.key_name or "F12") .. "] " .. (MM.mode == 2 and "region" or "follow")
        if lt ~= MM.label_text then MM.label_text = lt; pcall(function() MM.label:SetText(FText(lt)) end) end
    end
    function api.destroy()
        if valid(MM.widget) then pcall(function() MM.widget:RemoveFromParent() end) end
        MM.widget = nil
    end
    return api
end
