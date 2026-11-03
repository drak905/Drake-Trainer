-- AI_Trainer HUD (v1.3.0): categorised, panel-based trainer window built from UMG widgets at runtime.
-- Loaded by main.lua:  local api = dofile(DIR .. "hud.lua")(ctx)
--
-- Layout (UI pixels, 1920x1080 reference):   header | 4 sections of rows | footer
--   row = [key badge] [label (+ optional sub-badge)] ........ [status pill]
-- Colours follow instruction/afterimage_trainer_ui_redesign_prompt_plan.md (slate panel, amber keys, emerald ON, slate OFF, sky info).
-- The UserWidget is HitTestInvisible, so it never swallows clicks. Mouse support is done by polling the cursor position
-- (WidgetLayoutLibrary.GetMousePositionOnViewport) + the left button, only while the cursor is visible.
-- UE4SS cannot read SlateBrush.OutlineSettings, so rounded corners are built from a few stacked rectangles.
return function(ctx)
    local valid, log = ctx.valid, ctx.log
    local CF = ctx.cfg or {}

    ---------------------------------------------------------------- colours (sRGB hex -> the linear values UMG tints expect)
    local function lin(c) c = c / 255; if c <= 0.04045 then return c / 12.92 end return ((c + 0.055) / 1.055) ^ 2.4 end
    local function hex(h, a)
        local r, g, b = h:match("#?(%x%x)(%x%x)(%x%x)")
        return { R = lin(tonumber(r, 16)), G = lin(tonumber(g, 16)), B = lin(tonumber(b, 16)), A = a or 1.0 }
    end
    local PAL = {
        panel      = hex("#0F172A", 0.88),
        border     = hex("#94A3B8", 0.30),
        divider    = hex("#94A3B8", 0.16),
        title      = hex("#38BDF8"),
        hint       = hex("#94A3B8"),
        section    = hex("#8393AA"),
        key_bg     = hex("#1E293B", 0.95),
        key_txt    = hex("#FBBF24"),
        lab_on     = hex("#F8FAFC"),
        lab_off    = hex("#CBD5E1"),
        row_on     = hex("#10B981", 0.11),
        row_hover  = hex("#94A3B8", 0.13),
        row_none   = { R = 0, G = 0, B = 0, A = 0 },
        on_bg      = hex("#10B981", 0.24),  on_txt   = hex("#34D399"),
        off_bg     = hex("#334155", 0.55),  off_txt  = hex("#64748B"),
        info_bg    = hex("#38BDF8", 0.18),  info_txt = hex("#38BDF8"),
        act_bg     = hex("#F59E0B", 0.18),  act_txt  = hex("#F59E0B"),
        sub_bg     = hex("#1E293B", 0.80),  sub_txt  = hex("#A5B4C8"),
        foot       = hex("#64748B"),
        mini_on    = hex("#34D399"),
        shadow     = { R = 0, G = 0, B = 0, A = 0.75 },
    }
    local TONE = {
        on     = { PAL.on_bg,   PAL.on_txt },
        off    = { PAL.off_bg,  PAL.off_txt },
        info   = { PAL.info_bg, PAL.info_txt },
        action = { PAL.act_bg,  PAL.act_txt },
    }

    ---------------------------------------------------------------- layout constants
    local W        = CF.width or 380.0
    local PAD      = 14.0
    local HDR_H    = 38.0
    local SEC_H    = 24.0
    local ROW_H    = 26.0       -- pitch
    local ROW_BOX  = 24.0       -- drawn height of a row
    local KEY_W    = 58.0
    local KEY_H    = 20.0
    local PILL_H   = 20.0
    local FOOT_H   = 28.0
    local MINI_H   = 30.0
    local FS_TITLE, FS_HINT, FS_SEC, FS_KEY, FS_LABEL, FS_PILL, FS_FOOT, FS_MINI = 15, 11, 11, 12, 15, 12, 12, 13

    ---------------------------------------------------------------- tiny widget helpers
    local function uid(n) return FName(string.format("AIHud_%s_%d_%d", n, math.floor(os.clock() * 1000), math.random(1, 1e6))) end
    local function cls(p) return StaticFindObject(p) end
    local UI = nil          -- built widget state
    local WL, GI = nil, nil
    local CAN_ROUND = true

    -- rounded rectangle from stacked rectangles: groups = { {inset, rows}, ... } from the top corner inward
    local CORNER = {
        [0] = {}, [2] = { { 1, 1 } }, [3] = { { 1, 1 } }, [4] = { { 2, 1 }, { 1, 1 } },
        [5] = { { 3, 1 }, { 1, 2 } }, [6] = { { 4, 1 }, { 2, 1 }, { 1, 2 } },
    }
    local function ckey(c) return string.format("%.4f,%.4f,%.4f,%.4f", c.R, c.G, c.B, c.A) end

    local function new_box(parent, tree, name, r, color)
        local B = { r = r, parts = {}, groups = CORNER[r] or {}, key = nil, vis = true, rect = nil }
        local function part(kind, inset, off, rows)
            local img = StaticConstructObject(cls("/Script/UMG.Image"), tree, uid(name))
            local slot = parent:AddChildToCanvas(img)
            img:SetVisibility(3)
            B.parts[#B.parts + 1] = { img = img, slot = slot, kind = kind, inset = inset, off = off, rows = rows }
        end
        local sum = 0
        for _, g in ipairs(B.groups) do sum = sum + g[2] end
        B.sum = sum
        part("body", 0, 0, 0)
        local off = 0
        for _, g in ipairs(B.groups) do part("top", g[1], off, g[2]); part("bot", g[1], off, g[2]); off = off + g[2] end
        function B.set_rect(x, y, w, h)
            local k = string.format("%.1f,%.1f,%.1f,%.1f", x, y, w, h)
            if B.rect == k then return end
            B.rect = k
            for _, p in ipairs(B.parts) do
                if p.kind == "body" then
                    p.slot:SetPosition({ X = x, Y = y + B.sum }); p.slot:SetSize({ X = w, Y = math.max(1.0, h - 2 * B.sum) })
                elseif p.kind == "top" then
                    p.slot:SetPosition({ X = x + p.inset, Y = y + p.off }); p.slot:SetSize({ X = math.max(1.0, w - 2 * p.inset), Y = p.rows })
                else
                    p.slot:SetPosition({ X = x + p.inset, Y = y + h - p.off - p.rows }); p.slot:SetSize({ X = math.max(1.0, w - 2 * p.inset), Y = p.rows })
                end
            end
        end
        function B.set_color(c)
            local k = ckey(c)
            if B.key == k then return end
            B.key = k
            for _, p in ipairs(B.parts) do p.img:SetColorAndOpacity(c) end
        end
        function B.show(b)
            if B.vis == b then return end
            B.vis = b
            for _, p in ipairs(B.parts) do p.img:SetVisibility(b and 3 or 1) end
        end
        if color then B.set_color(color) end
        return B
    end

    local function new_text(parent, tree, name, size, bold, color, ax, ay)
        local tb = StaticConstructObject(cls("/Script/UMG.TextBlock"), tree, uid(name))
        tb:SetText(FText(""))
        pcall(function() local f = tb.Font; f.Size = size; f.TypefaceFontName = FName(bold and "Bold" or "Regular"); tb:SetFont(f) end)
        pcall(function() tb:SetShadowOffset({ X = 1.0, Y = 1.0 }); tb:SetShadowColorAndOpacity(PAL.shadow) end)
        tb:SetVisibility(3)
        local slot = parent:AddChildToCanvas(tb)
        slot:SetAutoSize(true)
        slot:SetAlignment({ X = ax or 0.0, Y = ay or 0.5 })
        local T = { tb = tb, slot = slot, text = nil, ckey = nil, pos = nil, vis = true, size = size }
        function T.set(s) if T.text ~= s then T.text = s; tb:SetText(FText(T.zw and (s .. "\226\128\139") or s)) end end
        function T.color(c) local k = ckey(c); if T.ckey ~= k then T.ckey = k; tb:SetColorAndOpacity({ SpecifiedColor = c, ColorUseRule = 0 }) end end
        function T.move(x, y) local k = x .. "," .. y; if T.pos ~= k then T.pos = k; slot:SetPosition({ X = x, Y = y }) end end
        function T.show(b) if T.vis ~= b then T.vis = b; tb:SetVisibility(b and 3 or 1) end end
        T.color(color or PAL.lab_on)
        return T
    end

    -- text width: measured by Slate when available (cached per size+string), else a per-character estimate
    local WC = {}
    local function est_w(s, size, bold) return #s * size * (bold and 0.60 or 0.54) end
    local function text_w(T, s, size, bold)
        local k = size .. "|" .. s
        if WC[k] then return WC[k] end
        if T and T.text == s then
            local ok, v = pcall(function() return T.tb:GetDesiredSize() end)
            if ok and v and v.X and v.X > 2 then WC[k] = v.X; return v.X end
        end
        return est_w(s, size, bold)
    end

    ---------------------------------------------------------------- build
    local function build(model)
        local ok, err = pcall(function()
            local gi = FindFirstOf("GameInstance")
            local w = StaticConstructObject(cls("/Script/UMG.UserWidget"), gi, uid("W"))
            local tree = StaticConstructObject(cls("/Script/UMG.WidgetTree"), w, uid("Tree"))
            w.WidgetTree = tree
            local root = StaticConstructObject(cls("/Script/UMG.CanvasPanel"), tree, uid("Root"))
            tree.RootWidget = root
            local U = { widget = w, tree = tree, root = root, rows = {}, byid = {}, secs = {}, x = ctx.pos.x, y = ctx.pos.y, expanded = true }

            local function canvas(visible)
                local c = StaticConstructObject(cls("/Script/UMG.CanvasPanel"), tree, uid("Win"))
                local s = root:AddChildToCanvas(c)
                s:SetPosition({ X = U.x, Y = U.y })
                s:SetSize({ X = 10.0, Y = 10.0 })
                c:SetVisibility(visible and 3 or 1)
                return c, s
            end

            ---------------- expanded window
            local win, wslot = canvas(true)
            U.win, U.wslot = win, wslot
            -- count height first
            local H = HDR_H + 8
            for _, sec in ipairs(model.sections) do H = H + SEC_H + #sec.rows * ROW_H + 4 end
            H = H + FOOT_H
            U.H = H
            wslot:SetSize({ X = W, Y = H })
            U.border = new_box(win, tree, "Bd", 6, PAL.border); U.border.set_rect(0, 0, W, H)
            U.fill = new_box(win, tree, "Fl", 5, PAL.panel);    U.fill.set_rect(1, 1, W - 2, H - 2)

            U.title = new_text(win, tree, "Title", FS_TITLE, true, PAL.title, 0.0, 0.5)
            U.title.set(model.title); U.title.move(PAD, HDR_H * 0.5)
            U.hint = new_text(win, tree, "Hint", FS_HINT, false, PAL.hint, 1.0, 0.5)
            U.hint.set(model.hint); U.hint.move(W - PAD, HDR_H * 0.5)
            local line = new_box(win, tree, "Ln", 0, PAL.divider); line.set_rect(PAD, HDR_H, W - 2 * PAD, 1)

            local y = HDR_H + 8
            for si, sec in ipairs(model.sections) do
                if si > 1 then local d = new_box(win, tree, "Sd", 0, PAL.divider); d.set_rect(PAD, y - 2, W - 2 * PAD, 1) end
                local st = new_text(win, tree, "Sec", FS_SEC, true, PAL.section, 0.0, 0.5)
                st.set(sec.name); st.move(PAD, y + SEC_H * 0.5 + 1)
                y = y + SEC_H
                for _, r in ipairs(sec.rows) do
                    local R = { id = r.id, y = y, def = r }
                    local cy = y + ROW_H * 0.5 - 1
                    R.bg = new_box(win, tree, "Rb", 4, PAL.row_none); R.bg.set_rect(6, y, W - 12, ROW_BOX)
                    R.keybox = new_box(win, tree, "Kb", 4, PAL.key_bg); R.keybox.set_rect(PAD, cy - KEY_H * 0.5, KEY_W, KEY_H)
                    R.keytxt = new_text(win, tree, "Kt", FS_KEY, true, PAL.key_txt, 0.5, 0.5)
                    R.keytxt.set("[" .. r.key .. "]"); R.keytxt.move(PAD + KEY_W * 0.5, cy)
                    R.label = new_text(win, tree, "Lb", FS_LABEL, false, PAL.lab_off, 0.0, 0.5)
                    R.label.set(r.label); R.label.move(PAD + KEY_W + 12, cy)
                    R.pill = new_box(win, tree, "Pl", 4, PAL.off_bg)
                    R.ptxt = new_text(win, tree, "Pt", FS_PILL, true, PAL.off_txt, 0.5, 0.5); R.ptxt.zw = true
                    if r.sub then
                        R.sbox = new_box(win, tree, "Sb", 4, PAL.sub_bg)
                        R.stxt = new_text(win, tree, "St", 11, false, PAL.sub_txt, 0.5, 0.5); R.stxt.zw = true
                    end
                    R.cy = cy
                    U.rows[#U.rows + 1] = R; U.byid[r.id] = R
                    y = y + ROW_H
                end
                y = y + 4
            end
            U.ftxt = new_text(win, tree, "Ft", FS_FOOT, false, PAL.foot, 0.0, 0.5)
            U.ftxt.move(PAD, y + FOOT_H * 0.5 - 2)
            U.foot_y = y

            ---------------- collapsed mini pill
            local mini, mslot = canvas(false)
            U.mini, U.mslot = mini, mslot
            U.mborder = new_box(mini, tree, "Mb", 6, PAL.border)
            U.mfill = new_box(mini, tree, "Mf", 5, PAL.panel)
            U.mtitle = new_text(mini, tree, "Mt", FS_MINI, true, PAL.title, 0.0, 0.5)
            U.mhint = new_text(mini, tree, "Mh", FS_MINI, true, PAL.hint, 0.0, 0.5)
            U.mw = 300.0

            w:AddToViewport(9999)
            w:SetVisibility(3)                      -- HitTestInvisible: never blocks the game's own mouse input
            U.shown = true
            UI = U
        end)
        if not ok then log("HUD build failed: " .. tostring(err)); UI = nil; return false end
        log("HUD built")
        return true
    end

    ---------------------------------------------------------------- apply a model (cheap: everything is diffed)
    local function layout_row(R, row, hovered)
        local on = row.on == true
        R.label.set(row.label)
        R.label.color(on and PAL.lab_on or PAL.lab_off)
        R.bg.set_color(hovered and PAL.row_hover or (on and PAL.row_on or PAL.row_none))
        local tone = TONE[row.tone or "off"] or TONE.off
        local pw = math.max(46.0, text_w(R.ptxt, row.text, FS_PILL, true) + 18.0)
        local px = W - PAD - pw
        R.ptxt.set(row.text); R.ptxt.color(tone[2])
        R.pill.set_color(tone[1]); R.pill.set_rect(px, R.cy - PILL_H * 0.5, pw, PILL_H)
        R.ptxt.move(px + pw * 0.5, R.cy)
        if R.sbox then
            local sw = math.max(40.0, text_w(R.stxt, row.sub or "", 11, false) + 14.0)
            local sx = px - 6.0 - sw
            R.stxt.set(row.sub or "")
            R.sbox.set_rect(sx, R.cy - 9, sw, 18); R.stxt.move(sx + sw * 0.5, R.cy)
        end
    end

    local api = {}
    function api.built() return UI ~= nil and valid(UI.widget) end

    function api.refresh(model, expanded)
        if not api.built() then UI = nil; if not build(model) then return end end
        local U = UI
        pcall(function() if not U.widget:IsInViewport() then U.widget:AddToViewport(9999) end end)
        U.model, U.expanded = model, expanded
        if U.mouse_hover == nil then U.mouse_hover = false end
        if expanded then
            U.win:SetVisibility(3); U.mini:SetVisibility(1)
            U.title.set(model.title); U.hint.set(model.hint)
            for _, R in ipairs(U.rows) do
                local row = model.byid[R.id]
                if row then layout_row(R, row, U.hover == R.id) end
            end
            U.ftxt.set(model.footer or ""); U.ftxt.color(model.footer_on and PAL.info_txt or PAL.foot)
        else
            U.win:SetVisibility(1); U.mini:SetVisibility(3)
            local t = model.mini_title
            U.mtitle.set(t)
            local tw = text_w(U.mtitle, t, FS_MINI, true)
            local hint = model.mini_hint
            U.mhint.set(hint); U.mhint.color(model.active > 0 and PAL.mini_on or PAL.hint)
            local hw = text_w(U.mhint, hint, FS_MINI, true)
            local mw = PAD + tw + 12 + hw + PAD
            U.mw = mw
            U.mslot:SetSize({ X = mw, Y = MINI_H })
            U.mborder.set_rect(0, 0, mw, MINI_H); U.mfill.set_rect(1, 1, mw - 2, MINI_H - 2)
            U.mtitle.move(PAD, MINI_H * 0.5); U.mhint.move(PAD + tw + 12, MINI_H * 0.5)
        end
    end

    function api.set_pos(x, y)
        if not UI then ctx.pos.x, ctx.pos.y = x, y; return end
        UI.x, UI.y = x, y
        ctx.pos.x, ctx.pos.y = x, y
        pcall(function() UI.wslot:SetPosition({ X = x, Y = y }); UI.mslot:SetPosition({ X = x, Y = y }) end)
    end
    function api.pos() return UI and UI.x or ctx.pos.x, UI and UI.y or ctx.pos.y end

    function api.destroy()
        if UI and valid(UI.widget) then pcall(function() UI.widget:RemoveFromParent() end) end
        UI = nil
    end
    function api.state() return UI end

    ---------------------------------------------------------------- hit testing (window-relative)
    -- returns kind, id : "row", id | "hint" | "title" | "mini" | "panel" | nil
    function api.hit(mx, my)
        if not UI then return nil end
        local lx, ly = mx - UI.x, my - UI.y
        if UI.expanded then
            if lx < 0 or ly < 0 or lx > W or ly > UI.H then return nil end
            if ly <= HDR_H then
                if lx >= W - 110 then return "hint" end
                return "title"
            end
            for _, R in ipairs(UI.rows) do
                if ly >= R.y and ly < R.y + ROW_H then return "row", R.id end
            end
            return "panel"
        end
        if lx < 0 or ly < 0 or lx > UI.mw or ly > MINI_H then return nil end
        return "mini"
    end
    -- centre of a row in viewport coordinates (used by the self-test)
    function api.row_center(id)
        if not UI or not UI.byid[id] then return nil end
        return UI.x + W * 0.5, UI.y + UI.byid[id].y + ROW_H * 0.5
    end

    ---------------------------------------------------------------- mouse polling
    local MS = { down = false, drag = nil }
    local function mouse_pos()
        if not valid(WL) then WL = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary") end
        if not valid(GI) then GI = FindFirstOf("GameInstance") end
        if not (valid(WL) and valid(GI)) then return nil end
        local ok, v = pcall(function() return WL:GetMousePositionOnViewport(GI) end)
        if ok and v then return v.X, v.Y end
        return nil
    end
    local function clamp_pos(x, y)
        local vw, vh = 1920.0, 1080.0
        pcall(function()
            local s = WL:GetViewportSize(GI); local sc = WL:GetViewportScale(GI)
            if s and sc and sc > 0 then vw, vh = s.X / sc, s.Y / sc end
        end)
        return math.max(0.0, math.min(x, vw - 80.0)), math.max(0.0, math.min(y, vh - 40.0))
    end

    -- pc: player controller (for IsInputKeyDown); active: poll the mouse this call
    function api.mouse(pc, active)
        if not UI or not valid(UI.widget) then return end
        local function set_hover(id)
            if UI.hover ~= id then
                UI.hover = id
                if UI.model and UI.expanded then for _, R in ipairs(UI.rows) do local row = UI.model.byid[R.id]; if row then R.bg.set_color(id == R.id and PAL.row_hover or (row.on and PAL.row_on or PAL.row_none)) end end end
            end
        end
        if not active then set_hover(nil); MS.down = false; MS.drag = nil; return end
        local mx, my = mouse_pos()
        if not mx then return end
        local down = false
        pcall(function() down = pc:IsInputKeyDown({ KeyName = FName("LeftMouseButton") }) == true end)
        local kind, id = api.hit(mx, my)
        if not MS.drag then set_hover(kind == "row" and id or nil) end
        if down and not MS.down then
            if kind == "row" then ctx.on_click(id)
            elseif kind == "hint" then ctx.on_collapse()
            elseif kind == "title" or kind == "mini" then MS.drag = { ox = mx - UI.x, oy = my - UI.y, sx = mx, sy = my, moved = false, was_mini = (kind == "mini") }
            end
        elseif down and MS.drag then
            if not MS.drag.moved and (math.abs(mx - MS.drag.sx) > 4 or math.abs(my - MS.drag.sy) > 4) then MS.drag.moved = true end
            if MS.drag.moved then
                local nx, ny = clamp_pos(mx - MS.drag.ox, my - MS.drag.oy)
                api.set_pos(nx, ny)
            end
        elseif (not down) and MS.drag then
            local d = MS.drag
            MS.drag = nil
            if d.moved then ctx.on_moved(UI.x, UI.y)
            elseif d.was_mini then ctx.on_expand() end
        end
        MS.down = down
    end

    api.layout = { W = W, HDR_H = HDR_H, ROW_H = ROW_H }
    return api
end
