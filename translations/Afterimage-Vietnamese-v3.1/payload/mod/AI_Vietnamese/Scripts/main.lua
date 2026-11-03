-- AI_Vietnamese v3.1.0 - Afterimage (UE 4.26, Steam) Vietnamese language pack, UE4SS Lua mod.
-- Offline / single-player. No game files are modified; all text is swapped live in memory.
--
-- Afterimage keeps its text in two places, and this mod covers both:
--   (1) Unreal string tables / .locres  (UI, dialogue, quests, talents, echoes, abilities, map names ...)
--       -> an English-keyed table + a sweep of the on-screen text widgets.
--   (2) The game's own Lua data tables  (item / weapon / armour / monster names and descriptions ...).
--       The engine fetches each of those through LuaLocalizationFunctionLibrary:GetTextWithNameSpace(), passing the
--       original Chinese text as a literal.  We post-hook that function and answer with Vietnamese, keyed by the
--       Chinese literal (a stable id that does not depend on the language the game is set to).
-- Fonts: see section (3). The game's UI font stack cannot draw most Vietnamese letters (U+01A0, U+01AF, U+1EA0..U+1EF9): they fall
-- back to a heavy CJK/Noto face. The pack therefore ships a Vietnamese-complete serif (Cormorant Garamond, SIL OFL) and moves the
-- translated widgets onto it at runtime.
local VERSION = "3.1.0"
local function script_dir()
    local s = debug.getinfo(1, "S").source:sub(2)
    return s:match("(.*[\\/])") or ""
end
local DIR = script_dir()
local function log(s) print("[AI_VI] " .. tostring(s) .. "\n") end
local function valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end

-- ---- config ---------------------------------------------------------------------------------------------
local okc, CFG = pcall(dofile, DIR .. "config.lua")
if not okc or type(CFG) ~= "table" then CFG = {} end
if CFG.enabled == nil then CFG.enabled = true end
if CFG.hook_data_tables == nil then CFG.hook_data_tables = true end
CFG.interval = CFG.interval or 200
CFG.startup_delay = CFG.startup_delay or 30.0

-- ---- dictionary -----------------------------------------------------------------------------------------
local EXACT, ZH, TMPL = {}, {}, {}
do
    local okd, d = pcall(dofile, DIR .. "vi_data.lua")
    if okd and type(d) == "table" then EXACT, ZH, TMPL = d.exact or {}, d.zh or {}, d.tmpl or {} end
end
local VISET, nexact, nzh, ntmpl = {}, 0, 0, #TMPL
for _, v in pairs(EXACT) do VISET[v] = true; nexact = nexact + 1 end
for _, v in pairs(ZH) do VISET[v] = true; nzh = nzh + 1 end
for i = 1, ntmpl do VISET[TMPL[i][2]] = true end
log(string.format("loaded %d english-keyed + %d chinese-keyed translations + %d templates", nexact, nzh, ntmpl))

-- ---- state ----------------------------------------------------------------------------------------------
local T0 = os.clock()
local function ready() return os.clock() - T0 >= CFG.startup_delay end
local S = { on = (CFG.enabled ~= false), hits = 0, hook_hits = 0, hook_miss = 0 }
local DONE = {}

-- ---- helpers --------------------------------------------------------------------------------------------
local function toStr(v)
    if v == nil then return nil end
    local ok, g = pcall(function() return v:get() end)
    if ok and g ~= nil then v = g end
    if type(v) == "string" then return v end
    local ok2, s = pcall(function() return v:ToString() end)
    if ok2 and type(s) == "string" then return s end
    return nil
end
local KTL
local function mkText(s)
    if not valid(KTL) then KTL = StaticFindObject("/Script/Engine.Default__KismetTextLibrary") end
    if not valid(KTL) then return nil end
    local ok, t = pcall(function() return KTL:Conv_StringToText(s) end)
    if ok then return t end
    return nil
end
local function norm(s) return (s:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("^%s+", ""):gsub("%s+$", "")) end

-- English lookup for ONE untagged piece of text: exact, template, "<LABEL> +N", line-by-line
local function lookup1(src)
    local k = norm(src)
    if k == "" then return nil end
    local vi = EXACT[k]
    if vi then return vi end
    for i = 1, ntmpl do
        local t = TMPL[i]
        local caps = { k:match(t[1]) }
        if #caps > 0 then
            local out = t[2]
            for j, name in ipairs(t[3]) do out = out:gsub("{" .. name .. "}", function() return caps[j] or "" end) end
            return out
        end
    end
    local open, body, close = k:match("^(<[%w_]+>)(.-)(</>)$")
    if open and EXACT[body] then return open .. EXACT[body] .. close end
    -- "<LABEL> +10" / "<LABEL> 12%" / "<LABEL>: 3" : a known label followed by a runtime number
    do
        local label, sign, num = k:match("^(.-)%s*([%+%-]?)%s*(%d[%d%.,]*%%?)$")
        if label and label ~= "" and EXACT[label] then return EXACT[label] .. " " .. sign .. num end
        local lab2, num2 = k:match("^(.-)%s*[:：]%s*(%d[%d%.,]*%%?)$")
        if lab2 and lab2 ~= "" and EXACT[lab2] then return EXACT[lab2] .. ": " .. num2 end
    end
    if k:find("\n", 1, true) then
        local parts, all = {}, true
        for line in (k .. "\n"):gmatch("(.-)\n") do
            if line == "" then parts[#parts + 1] = ""
            elseif EXACT[line] then parts[#parts + 1] = EXACT[line]
            else all = false; break end
        end
        if all then return table.concat(parts, "\n") end
    end
    return nil
end

-- Rich text: "<Pink>MAIN WEAPON ATTACK+2</>", "<WhiteG>MAX HP</> <White>+1.4</>", "<img id=.../>HP<Green>+1</>".
-- Split on tags, translate each text segment on its own, and put the tags back untouched.
local function lookup(src)
    local vi = lookup1(src)
    if vi then return vi end
    if not src:find("<", 1, true) then return nil end
    local out, changed, pos = {}, false, 1
    while pos <= #src do
        local s, e = src:find("<[^<>]*>", pos)
        local text = src:sub(pos, (s or (#src + 1)) - 1)
        if text ~= "" then
            local lead, core, trail = text:match("^(%s*)(.-)(%s*)$")
            local t = core ~= "" and lookup1(core) or nil
            if t then out[#out + 1] = lead .. t .. trail; changed = true else out[#out + 1] = text end
        end
        if not s then break end
        out[#out + 1] = src:sub(s, e)
        pos = e + 1
    end
    if changed then return table.concat(out) end
    return nil
end

-- Chinese lookup (data-table hook)
local function lookup_zh(zh)
    local k = norm(zh)
    local vi = ZH[k]
    if vi then return vi end
    if k:find("\\n", 1, true) then            -- literal backslash-n sequences in the data
        vi = ZH[(k:gsub("\\n", "\n"))]
        if vi then return vi end
    end
    return nil
end

-- harvest (dev only): record anything the game asked for that we could not answer
local HF, HSEEN = nil, {}
local function harvest(kind, key, en, zh)
    if not CFG.harvest then return end
    if HSEEN[key] then return end
    HSEEN[key] = true
    if not HF then HF = io.open(DIR .. "vi_harvest.txt", "a") end
    if HF then HF:write(table.concat({ kind, key, (zh or ""):gsub("[\r\n\t]", " "), (en or ""):gsub("[\r\n\t]", " ") }, "\t") .. "\n"); HF:flush() end
end

-- ---- (2) data-table hook --------------------------------------------------------------------------------
local hooked = false
local function install_hooks()
    if hooked or not CFG.hook_data_tables then return end
    hooked = true
    local function reg(path)
        local ok, e = pcall(function()
            RegisterHook(path, function() end, function(self, Ret, Ns, Row, Col, Lit)
                if not S.on then return end
                local ok2 = pcall(function()
                    local zh = toStr(Lit)
                    if not zh or zh == "" then return end
                    local vi = lookup_zh(zh)
                    if not vi then
                        local en = toStr(Ret)
                        if en then vi = lookup(en) end            -- fall back to the English the game produced
                        if not vi then
                            S.hook_miss = S.hook_miss + 1
                            harvest("DT", (toStr(Ns) or "?") .. ":" .. (toStr(Row) or "?") .. ":" .. (toStr(Col) or "?"), toStr(Ret), zh)
                            return
                        end
                    end
                    Ret:set(vi)
                    S.hook_hits = S.hook_hits + 1
                end)
                if not ok2 then S.hook_miss = S.hook_miss + 1 end
            end)
        end)
        if not ok then log("hook failed: " .. path .. " " .. tostring(e)) end
        return ok
    end
    local a = reg("/Script/Afterimage.LuaLocalizationFunctionLibrary:GetTextWithNameSpace")
    local b = reg("/Script/Afterimage.TalentSkillFunctionLibrary:GetDescEffectWithNameSpace")
    local c = reg("/Script/Afterimage.TalentSkillFunctionLibrary:GetTextWithNameSpace")
    -- talent / equipment stat lines: "<Pink>PYRO DAMAGE+0.5%</>\n<Pink>GEO DAMAGE+0.5%</>" (rich text: label + runtime number)
    local statok = pcall(function()
        RegisterHook("/Script/Afterimage.TalentSkillFunctionLibrary:GetSPropEffectsWithTalentLevel", function() end,
            function(self, Ret, Cfg, Level)
                if not S.on then return end
                pcall(function()
                    local en = toStr(Ret)
                    if not en or en == "" then return end
                    local parts, any = {}, false
                    for line in (en .. "\n"):gmatch("(.-)\n") do
                        local v = (line ~= "") and lookup(line) or nil
                        if v then any = true; parts[#parts + 1] = v else parts[#parts + 1] = line end
                    end
                    if any then Ret:set(table.concat(parts, "\n")); S.hook_hits = S.hook_hits + 1 end
                end)
            end)
    end)
    log("stat-line hook installed: " .. tostring(statok))
    log(string.format("data-table hooks installed: GetTextWithNameSpace=%s GetDescEffectWithNameSpace=%s Talent.GetTextWithNameSpace=%s",
        tostring(a), tostring(b), tostring(c)))
end

-- ---- (3) font fix ---------------------------------------------------------------------------------------
-- Afterimage draws all UI text with the composite font AuroMinTWM_Font. Its English sub-typeface (Bellefair) only covers
-- U+0000..U+017F, so every Vietnamese letter outside that range (ơ ư and all the toned vowels U+1EA0..U+1EF9) falls through to
-- the CJK default face / Noto Serif: heavy, mismatched strokes inside a thin word.  Fix: a font object nobody uses
-- (DMatchHUDFont) is pointed at a Vietnamese-complete serif TTF shipped with the pack, and the widgets are moved onto it.
-- Text that still contains Chinese stays on the original font (the shipped face has no CJK glyphs).
local FF = { ready = false, failed = false, font = nil, rows = {}, orig = {}, richdone = {} }
local function fullname(o)
    local ok, s = pcall(function() return o:GetFullName() end)
    return ok and tostring(s) or ""
end
local function font_path()
    local root = DIR:gsub("[\\/]+Scripts[\\/]*$", "")
    local rel = CFG.font_file or "font/CormorantGaramond-SemiBold.ttf"
    local p = (root .. "/" .. rel):gsub("\\", "/")
    if not p:match("^%a:/") then                                  -- relative dir: anchor it at the process directory
        local okp, cwd = pcall(function() local h = io.popen("cd"); local s = h:read("a"); h:close(); return s end)
        if okp and cwd then p = (cwd:gsub("%s+$", ""):gsub("\\", "/") .. "/" .. p):gsub("//+", "/") end
    end
    return p
end
local function fontfix_setup()
    if FF.ready or FF.failed or CFG.font_fix == false then return end
    local ok, err = pcall(function()
        local path = font_path()
        local fh = io.open(path, "rb")
        if not fh then error("font file not found: " .. path) end
        fh:close()
        local carrier = StaticFindObject("/Game/UMG/DMatchHUDFont.DMatchHUDFont")
        if not valid(carrier) then error("carrier font object not found") end
        local fd
        carrier.CompositeFont.DefaultTypeface.Fonts:ForEach(function(i, e) if i == 1 then fd = e:get() end end)
        if not fd then error("carrier has no default face") end
        fd.Font.FontFaceAsset = nil
        fd.Font.FontFilename = path
        FF.font = carrier
        FF.path = path
        -- rich-text style rows that use the composite font -> carrier
        local dts = FindAllOf("DataTable")
        if dts then
            for i = 1, #dts do
                local nm = fullname(dts[i])
                if nm:find("RichTextStyle", 1, true) and not nm:find("ImageStyle", 1, true) then
                    dts[i]:ForEachRow(function(rn, row)
                        pcall(function()
                            local fo = fullname(row.TextStyle.Font.FontObject)
                            if fo:find("AuroMinTWM_Font", 1, true) then
                                FF.rows[#FF.rows + 1] = { row = row, font = row.TextStyle.Font.FontObject, tf = row.TextStyle.Font.TypefaceFontName }
                                row.TextStyle.Font.FontObject = carrier
                                row.TextStyle.Font.TypefaceFontName = FName("")
                            end
                        end)
                    end)
                end
            end
        end
    end)
    if ok then FF.ready = true; log(string.format("font fix ready: %s (%d rich-text style rows redirected)", FF.path, #FF.rows))
    else FF.failed = true; log("font fix unavailable: " .. tostring(err)) end
end
local function has_cjk(s) return s:find("[\227-\233][\128-\191][\128-\191]") ~= nil end
local function addr_of(w)
    local ok, a = pcall(function() return w:GetAddress() end)
    if ok and a then return a end
    return nil
end
local function fontfix_widget(w, isrich, s, ak)
    if not FF.ready or not S.on then return end
    if has_cjk(s) then return end
    ak = ak or addr_of(w)
    if not ak then return end
    pcall(function()
        if isrich then
            if FF.richdone[ak] then return end
            FF.richdone[ak] = w
            local ts = w.TextStyleSet
            if ts then w:SetTextStyleSet(nil); w:SetTextStyleSet(ts) end
        else
            local f = w.Font
            local fon = fullname(f.FontObject)
            if fon:find("DMatchHUDFont", 1, true) then return end                     -- already on the Vietnamese face
            if not fon:find("AuroMinTWM_Font", 1, true) and not fon:find("Fonts/Bellefair.Bellefair", 1, true) then return end
            if not FF.orig[ak] then FF.orig[ak] = { w = w, fo = f.FontObject, tf = f.TypefaceFontName } end
            f.FontObject = FF.font
            f.TypefaceFontName = FName("")
            w:SetFont(f)
        end
    end)
end
local function fontfix_restore()
    if not FF.ready then return end
    for _, o in pairs(FF.orig) do
        pcall(function() if valid(o.w) then local f = o.w.Font; f.FontObject = o.fo; f.TypefaceFontName = o.tf; o.w:SetFont(f) end end)
    end
    FF.orig = {}
    for _, r in ipairs(FF.rows) do
        pcall(function() r.row.TextStyle.Font.FontObject = r.font; r.row.TextStyle.Font.TypefaceFontName = r.tf end)
    end
    for _, w in pairs(FF.richdone) do
        pcall(function() if valid(w) then local ts = w.TextStyleSet; if ts then w:SetTextStyleSet(nil); w:SetTextStyleSet(ts) end end end)
    end
    FF.richdone = {}
    FF.rowsRestored = true
end
local function fontfix_reapply_rows()
    if not FF.ready or not FF.rowsRestored then return end
    FF.rowsRestored = false
    for _, r in ipairs(FF.rows) do
        pcall(function() r.row.TextStyle.Font.FontObject = FF.font; r.row.TextStyle.Font.TypefaceFontName = FName("") end)
    end
end

-- ---- (1) widget sweep -----------------------------------------------------------------------------------
-- NOTE: FindAllOf() returns a NEW Lua wrapper for the same widget on every call, so a widget can never be used as a table key.
-- Its address (GetAddress, cheap and stable) is the identity used for all per-widget caches.
local DONE_N = 0
local function do_widget(w, isrich)
    if not valid(w) then return end
    local ak = addr_of(w)
    if not ak then return end
    local ok, txt = pcall(function() return w:GetText() end)
    if not ok then return end
    local s = toStr(txt)
    if not s or s == "" then return end
    if DONE[ak] == s then return end
    if DONE[ak] == nil then
        DONE_N = DONE_N + 1
        if DONE_N > 6000 then DONE = {}; DONE_N = 0 end            -- widgets come and go; keep the cache small
    end
    if VISET[norm(s)] then DONE[ak] = s; fontfix_widget(w, isrich, s, ak); return end
    local vi = lookup(s)
    if not vi and s:find("[\227-\233][\128-\191][\128-\191]") then       -- text still in Chinese (widget design-time default)
        vi = lookup_zh(s)
    end
    if vi then
        local t = mkText(vi)
        if t and pcall(function() w:SetText(t) end) then DONE[ak] = vi; S.hits = S.hits + 1; fontfix_widget(w, isrich, vi, ak); return end
    end
    DONE[ak] = s
    fontfix_widget(w, isrich, s, ak)
    if CFG.harvest then
        local vis = false
        pcall(function() vis = w:IsVisible() end)
        harvest(vis and "WV" or "W", norm(s), s, nil)
    end
end

-- ---- (4) instant rich-text translation ------------------------------------------------------------------
-- Some labels (the map / minimap area names are RichTextAnimation widgets) are re-set to English by the game several times a second,
-- so a sweep that runs every 200 ms leaves them in English most of the time.  A post-hook on RichTextBlock:SetText answers in the
-- same frame: when the game has just written an English string we know, we write the Vietnamese one straight away.
-- (A TextBlock:SetText hook was tested too but those widgets do not flicker, so it is not installed.)
local rich_hooked = false
local RCACHE, RCACHE_N = {}, 0
local in_rich_hook = false
local function install_rich_hook()
    if rich_hooked or CFG.hook_rich_text == false then return end
    rich_hooked = true
    local ok, e = pcall(function()
        RegisterHook("/Script/UMG.RichTextBlock:SetText", function(self, a1) end, function(self, a1)
            if in_rich_hook or not S.on then return end
            pcall(function()
                local en = toStr(a1)
                if not en or en == "" then return end
                local vi = RCACHE[en]
                if vi == nil then
                    vi = lookup(en) or false
                    RCACHE_N = RCACHE_N + 1
                    if RCACHE_N > 4000 then RCACHE = {}; RCACHE_N = 0 end    -- counters / timers produce endless distinct strings
                    RCACHE[en] = vi
                end
                if not vi or vi == en then return end
                local t = mkText(vi)
                if not t then return end
                in_rich_hook = true
                local okset = pcall(function() self:get():SetText(t) end)
                in_rich_hook = false
                if okset then S.rich_hits = (S.rich_hits or 0) + 1 end
            end)
            in_rich_hook = false
        end)
    end)
    log("rich-text instant hook installed: " .. tostring(ok) .. (ok and "" or (" " .. tostring(e))))
end

local CLASSES = { "TextBlock", "RichTextBlock" }
local started = false
local function sweep()
    if not S.on or not ready() then return end
    if not started then started = true; install_hooks(); install_rich_hook(); fontfix_setup() end
    fontfix_reapply_rows()
    for _, cn in ipairs(CLASSES) do
        local a = FindAllOf(cn)
        local isrich = (cn == "RichTextBlock")
        if a then for i = 1, #a do do_widget(a[i], isrich) end end
    end
end

-- ---- keybind toggle -------------------------------------------------------------------------------------
local KEYMAP = { HOME = Key.HOME, END = Key.END, INSERT = Key.INS, F7 = Key.F7, SCROLL_LOCK = Key.SCROLL_LOCK }
if CFG.toggle_key and KEYMAP[CFG.toggle_key] then
    pcall(function()
        RegisterKeyBind(KEYMAP[CFG.toggle_key], function()
            S.on = not S.on
            if not S.on then DONE = {}; pcall(fontfix_restore) end
            log(string.format("Vietnamese %s (widgets %d, rich-text hook %d, data-table hits %d, misses %d, sweep avg %.2f ms over %d runs)", S.on and "ON" or "OFF", S.hits, S.rich_hits or 0, S.hook_hits, S.hook_miss, (S.sweep_n or 0) > 0 and S.sweep_t / S.sweep_n * 1000 or 0, S.sweep_n or 0))
        end)
    end)
end

-- ---- run ------------------------------------------------------------------------------------------------
if type(LoopInGameThreadWithDelay) == "function" then
    LoopInGameThreadWithDelay(CFG.interval, function()
        local c0 = os.clock()
        pcall(sweep)
        S.sweep_n = (S.sweep_n or 0) + 1; S.sweep_t = (S.sweep_t or 0) + (os.clock() - c0)
    end)
else
    LoopAsync(CFG.interval, function() ExecuteInGameThread(function() pcall(sweep) end); return false end)
end
log("AI_Vietnamese " .. VERSION .. " loaded (enabled=" .. tostring(S.on) .. ")")
