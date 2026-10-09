-- Skillbound.lua : start-up, saved data, colors, slash command.
-- Skillbound = skill & gear presets ("builds"): save what you wear (gear on both bars,
-- skills on both bars, champion stars, food, poisons, quickslots, outfit, title,
-- mount / pet / costume, companion) and wear it again with one click.
-- The parts:
--   Skillbound_Items.lua    where an item is (bag, bank, other character), substitutes
--   Skillbound_Capture.lua  reads what you wear now into a build
--   Skillbound_Apply.lua    "what will change", the combat-safe queue that wears a build, undo
--   Skillbound_Check.lua    build check (set bonuses, mythics, poisons, repairs, food, mundus)
--   Skillbound_Rules.lua    automatic switching ("when I enter Cyrodiil, wear ...")
--   Skillbound_Bank.lua     take a build's gear out of the bank
--   Skillbound_Share.lua    share codes (copy / paste a build)
--   Skillbound_Marks.lua    small mark on build gear in the bag (+ optional game lock)
--   Skillbound_UI.lua       main window (build list + paperdoll), Rules and Gear check tabs
--   Skillbound_Launcher.lua the button: skills icon + favorite build slots
--   Skillbound_Wheel.lua    quick wheel (keybind) with your favorite builds
--   Skillbound_Settings.lua settings (LibAddonMenu-2.0, optional)
-- One global table: Skillbound.

local ADDON_NAME = "Skillbound"
Skillbound = Skillbound or {}
local B = Skillbound

-- Text for key in the game's language (lang/en.lua, then lang/$(language).lua replaces what
-- it has), formatted with the extra arguments (string.format).
function B.L(key, ...)
    local id = _G["SKILLBOUND_" .. key]
    if type(id) ~= "number" then return key end
    local text = GetString(id)
    if select("#", ...) > 0 then return string.format(text, ...) end
    return text
end
local L = B.L

B.LOGO = "Skillbound/Textures/logo.dds"   -- sword through a ring (logo 2, picked 2026-10-01)
B.TEX = "Skillbound/Textures/"
B.VERSION = "1.0.3"   -- keep the same as "## Version" in Skillbound.txt (shown in the window's credit)
B.AUTHOR = "brianmit"
B.BG = B.TEX .. "bg_graphite.dds"   -- window / panel / button background (palette 2)
-- the main window's wallpapers (2026-10-08): 0 = the Mundus night sky above, 1-10 drawn by
-- _SkillboundDev/make_wallpapers.ps1 (2048 x 1024 DXT1); names in WALL_0 .. WALL_10
B.WALLS = { [0] = B.BG }
for i = 1, 10 do B.WALLS[i] = B.TEX .. "walls/wall_" .. i .. ".dds" end
B.MAX_FAV = 10   -- favorites: button slots, keybinds, quick wheel (all up to 10)
B.SKILLS_ICON = "/esoui/art/mainmenu/menubar_skills_up.dds"   -- the game's own Skills menu icon

-- Colors are plain { r, g, b } tables (0..1), like in Questbound.
local function Hex(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end
B.Hex = Hex

-- Look "K" + background "A hearth ember" (picked 2026-10-01): near-black warm panels,
-- a low fire glow, gilded ornaments, cream text, ember amber for what's selected / worn.
B.COLOR = {
    -- palette 2 "graphite + ember" (picked 2026-10-01): grey / black everywhere, the amber
    -- accent is the only color. (Names kept from look K: "gold" is now pewter, "glow" a soft
    -- neutral light.)
    theme = Hex("E3A857"),     -- ember amber accent (sv.theme can change it)
    text = Hex("F1EADB"),      -- off-white: titles, selected
    soft = Hex("E2D6BC"),      -- normal text: warm parchment (grey was hard to read on graphite)
    dim = Hex("C9AE72"),       -- labels, hints: soft gold (readable, quieter than the amber accent)
    faint = Hex("7A6A4C"),     -- dark gold: separators, empty "+" slots, switched-off things
    line = Hex("2E2E2E"),      -- divider lines, card edges
    good = Hex("9CC46A"),
    warn = Hex("E07A3A"),      -- orange: something needs you
    bad = Hex("D9584A"),
    gold = Hex("A9A59D"),      -- pewter: ornaments, ultimate slot edge, complete set names
    goldDark = Hex("474747"),  -- outer frame
    panel = Hex("161616"),
    card = Hex("101010"),
    slot = Hex("0A0A0A"),
    hover = Hex("262626"),
    edge = Hex("4A4A4A"),      -- slot frames
    glow = Hex("CFC9BF"),      -- soft light (hover glows, the arch light)
    warfare = Hex("5BA3D9"),   -- blue champion tree
    fitness = Hex("E0644F"),   -- red
    craft = Hex("7DBE5B"),     -- green
    star = Hex("FFD54A"),      -- favorite star: yellow
    grey = Hex("6F6F6F"),      -- favorite star when not a favorite
}

function B.RGBA(c, a)
    return c.r, c.g, c.b, a or 1
end

function B.Colorize(c, text)
    return string.format("|c%02X%02X%02X%s|r", zo_round(c.r * 255), zo_round(c.g * 255), zo_round(c.b * 255), text)
end

-- ESO lettering. kind:
--   "title" / "head" : Trajan, the game's own title letters (window title, headers, tabs, buttons)
--   "name"           : Prose Antique, the game's book / quest-name letters (build, item, food names); runs small: +2
--   "text"           : Prose Antique too (2026-10-01: the plain UI letters looked too plain); +1
--   "bold"           : the game's bold UI letters (small numbers, the "quiet" text buttons)
local FACES = {
    title = "$(STONE_TABLET_FONT)", head = "$(STONE_TABLET_FONT)", name = "$(ANTIQUE_FONT)",
    bold = "$(BOLD_FONT)", text = "$(ANTIQUE_FONT)",
}
function B.Font(kind, size)
    local face = FACES[kind] or FACES.text
    if kind == "name" then size = size + 2 elseif kind == "text" then size = size + 1 end
    return face .. "|" .. size .. "|soft-shadow-thick"
end

local defaults = {
    builds = {},              -- [id] = build, see Skillbound_Capture.lua for the layout
    nextId = 1,
    chars = {},               -- [characterId] = { name, classId, fav = { build ids }, worn = id, undo = build, items = { [uid] = true } }
    bank = {},                -- [uid] = true: equipment in the account bank (seen at the last bank visit)
    foodBuffs = {},           -- [food item id] = buff ability id (learned when you eat it)
    rules = {},               -- see Skillbound_Rules.lua
    launcher = {
        hidden = false,
        combatHide = true,
        slots = 10,           -- favorite build slots on the button (0 - B.MAX_FAV)
        x = nil, y = nil,     -- top left once you move it
    },
    window = { x = nil, y = nil },
    places = {},              -- [window name] = { x, y, w, h }: the other windows (save, share, tour, ...) where you left them
    showChanges = true,       -- "Wear" in the window shows what will change first
    askWear = true,           -- "Switch to <build>?" before wearing from the window / the button's favorites
    foodRenewMin = 0,         -- "Eat in dungeons" renews the food once fewer minutes than this are left (0 = only when it ran out)
    readyCard = true,         -- the ready check card when you enter a dungeon or trial (Skillbound_Ready.lua)
    quietSwap = true,         -- mute the game's item sounds (drinking / eating / equip) while a build goes on
    fix = { repairAt = 60, chargeAt = 30, autoRepair = false, autoCharge = false },   -- Gear check, Skillbound_Fix.lua
    prebuff = { restoreAfter = 12 },   -- seconds the buff skills stay on the bar at most (Skillbound_Prebuff.lua)
    eatFood = true,           -- wearing a build eats its food when the buff isn't running
    refillPoison = true,      -- an empty poison slot gets the next stack of the same poison
    marks = true,             -- small mark on build gear in the bag
    lockGear = false,         -- also turn on the game's own lock for build gear when saving
    announce = true,          -- "Wearing Trial DPS" message on screen
    theme = { r = 0.89, g = 0.66, b = 0.34 },   -- ember amber
    anim = "full",            -- animations: "full", "subtle" or "off" (see Skillbound_Anim.lua)
    -- uiVersion: not a default on purpose (nil = fresh install or saved by 0.1.0)
}

-- a small colored dot inside text (the game font has no ● character)
function B.Dot(c, size)
    size = size or 8
    return B.Colorize(c, string.format("|t%d:%d:%sdisc.dds:inheritcolor|t", size, size, B.TEX))
end

B.callbacks = ZO_CallbackObject:New()
-- (Skillbound's own callbacks: each listener wrapped, see the safety net below)
do
    local rawRegister = B.callbacks.RegisterCallback
    function B.callbacks:RegisterCallback(name, fn, ...)
        return rawRegister(self, name, B.Safe and B.Safe(fn, name) or fn, ...)
    end
end

function B.Print(text)
    d(B.Colorize(B.COLOR.theme, L("PREFIX")) .. " " .. text)
end

-- ---------------------------------------------------------------------------
-- Safety net (1.0.0): everything that runs by itself (game events, timers, delayed calls,
-- Skillbound's own callbacks, per-frame updates) goes through B.Safe. An error there no
-- longer opens the game's big error window (every frame, for per-frame code): Skillbound
-- prints ONE short chat line per place and keeps going. /sb errors lists the last ones (for
-- bug reports). Files use B.EM instead of EVENT_MANAGER and B.Later instead of zo_callLater.

B.errors = {}
local errorShown = {}

-- quiet = only remember it (/sb errors), no chat line
function B.ReportError(where, err, quiet)
    where = tostring(where or "?"):gsub("^Skillbound_", "")
    local text = tostring(err or "?"):match("^[^\n]*") or "?"   -- (first line: no stack traces in chat)
    table.insert(B.errors, 1, where .. ": " .. text)
    while #B.errors > 10 do table.remove(B.errors) end
    if quiet or errorShown[where] then return end
    errorShown[where] = true
    if B.Print and B.L then pcall(B.Print, B.L("ERROR_LINE", where)) end
end

local function Pass(where, ok, ...)
    if not ok then
        B.ReportError(where, ...)
        return
    end
    return ...
end

function B.Safe(fn, where)
    if type(fn) ~= "function" then return fn end
    return function(...) return Pass(where, pcall(fn, ...)) end
end

-- EVENT_MANAGER with every handler wrapped (same method names)
B.EM = {
    RegisterForEvent = function(_, name, event, fn) return EVENT_MANAGER:RegisterForEvent(name, event, B.Safe(fn, name)) end,
    RegisterForUpdate = function(_, name, ms, fn) return EVENT_MANAGER:RegisterForUpdate(name, ms, B.Safe(fn, name)) end,
    UnregisterForEvent = function(_, ...) return EVENT_MANAGER:UnregisterForEvent(...) end,
    UnregisterForUpdate = function(_, ...) return EVENT_MANAGER:UnregisterForUpdate(...) end,
    AddFilterForEvent = function(_, ...) return EVENT_MANAGER:AddFilterForEvent(...) end,
}

-- zo_callLater, wrapped
function B.Later(fn, ms, where)
    return zo_callLater(B.Safe(fn, where or "delayed"), ms)
end

-- short message in the middle of the screen (falls back to chat)
function B.Announce(text, isError)
    if not B.sv.announce then
        B.Print(text)
        return
    end
    local ok = pcall(function()
        local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT,
            isError and SOUNDS.GENERAL_ALERT_ERROR or SOUNDS.NONE)
        params:SetText(B.Colorize(isError and B.COLOR.bad or B.COLOR.theme, text))
        params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_AVENGE_KILL)   -- (same type Wizard's Wardrobe uses)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
    end)
    if not ok then B.Print(text) end
end

function B.ApplyTheme()
    local c, t = B.sv.theme, B.COLOR.theme
    t.r, t.g, t.b = c.r, c.g, c.b
end

-- Fragment that shows a control only on the normal HUD (hidden in menus, map, dialogs).
function B.HudFragment(control)
    local fragment = ZO_HUDFadeSceneFragment:New(control)
    fragment.sbControl = control
    B.ShowOnHud(fragment, true)
    return fragment
end

function B.ShowOnHud(fragment, show)
    if fragment.sbShown ~= show then
        fragment.sbShown = show
        if show then
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
        else
            HUD_SCENE:RemoveFragment(fragment)
            HUD_UI_SCENE:RemoveFragment(fragment)
        end
    end
    fragment.sbControl:SetHidden(not show or not (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()))
end

function B.IsOver(control, pad)
    if not control or control:IsHidden() then return false end
    pad = pad or 0
    local x, y = GetUIMousePosition()
    return x >= control:GetLeft() - pad and x <= control:GetRight() + pad
        and y >= control:GetTop() - pad and y <= control:GetBottom() + pad
end

-- ---------------------------------------------------------------------------
-- Characters and builds

function B.CharId()
    return GetCurrentCharacterId()
end

-- this character's record (created on first use)
function B.Char(charId)
    charId = charId or B.CharId()
    local c = B.sv.chars[charId]
    if not c then
        c = { fav = {}, items = {} }
        B.sv.chars[charId] = c
    end
    if charId == B.CharId() then
        c.name = zo_strformat("<<1>>", GetUnitName("player"))
        c.classId = GetUnitClassId("player")
    end
    c.fav = c.fav or {}
    c.items = c.items or {}
    return c
end

function B.Get(id)
    return id and B.sv.builds[id]
end

function B.NewId()
    local id = "b" .. B.sv.nextId
    B.sv.nextId = B.sv.nextId + 1
    return id
end

-- every build, sorted by folder then name
function B.SortedBuilds()
    local list = {}
    for _, b in pairs(B.sv.builds) do list[#list + 1] = b end
    table.sort(list, function(a, b)
        local fa, fb = a.folder or "", b.folder or ""
        if fa ~= fb then return fa < fb end
        return zo_strlower(a.name or "") < zo_strlower(b.name or "")
    end)
    return list
end

function B.FindByName(name)
    name = zo_strlower(zo_strtrim(name or ""))
    for _, b in pairs(B.sv.builds) do
        if zo_strlower(b.name or "") == name then return b end
    end
end

function B.IsFavorite(id)
    for _, f in ipairs(B.Char().fav) do
        if f == id then return true end
    end
    return false
end

function B.ToggleFavorite(id)
    local fav = B.Char().fav
    for i, f in ipairs(fav) do
        if f == id then
            table.remove(fav, i)
            B.callbacks:FireCallbacks("BuildsChanged")
            return
        end
    end
    if #fav >= B.MAX_FAV then
        B.Print(L("FAV_FULL"))
        return
    end
    fav[#fav + 1] = id
    B.callbacks:FireCallbacks("BuildsChanged")
end

function B.DeleteBuild(id)
    B.sv.builds[id] = nil
    for _, c in pairs(B.sv.chars) do
        for i = #(c.fav or {}), 1, -1 do
            if c.fav[i] == id then table.remove(c.fav, i) end
        end
        if c.worn == id then c.worn = nil end
    end
    for _, b in pairs(B.sv.builds) do
        if b.parent == id then b.parent = nil end
    end
    for _, r in ipairs(B.sv.rules) do
        if r.build == id then r.build = nil end
    end
    B.callbacks:FireCallbacks("BuildsChanged")
end

-- the build you wore last on this character (nil after you changed things by hand a lot)
function B.WornBuild()
    return B.Get(B.Char().worn)
end

-- skill / champion / item names as the game shows them
function B.Name(text)
    return zo_strformat("<<1>>", text or "")
end

-- ---------------------------------------------------------------------------
-- Slash command

local function Slash(args)
    args = zo_strtrim(args or "")
    local cmd, rest = args:match("^(%S*)%s*(.-)$")
    cmd = zo_strlower(cmd or "")
    if cmd == "" then
        if B.sv.launcher.hidden then
            B.sv.launcher.hidden = false
            B.callbacks:FireCallbacks("SettingsChanged")
            B.Print(L("SHOWN_LAUNCHER"))
        end
        B.UI.Toggle()
    elseif cmd == "wear" and rest ~= "" then
        local b = B.FindByName(rest)
        if b then B.Apply.Wear(b) else B.Print(L("NO_SUCH_BUILD", rest)) end
    elseif cmd == "save" and rest ~= "" then
        B.UI.SaveNew(rest)
    elseif cmd == "undo" then
        B.Apply.Undo()
    elseif cmd == "check" then
        B.Check.PrintCurrent()
    elseif cmd == "settings" then
        B.OpenSettings()
    elseif cmd == "tour" then
        B.UI.StartTour()
    elseif cmd == "mouse" then
        -- diagnostic: in 3 seconds, prints what's under the mouse (and its parents)
        B.Print("Point at the spot now...")
        zo_callLater(function()
            local c = WINDOW_MANAGER:GetMouseOverControl()
            local chain = {}
            while c and #chain < 8 do
                local name = c.GetName and c:GetName() or "?"
                chain[#chain + 1] = (name ~= "" and name or "(no name)") .. " [level " .. tostring(c.GetDrawLevel and c:GetDrawLevel() or "?") .. "]"
                c = c.GetParent and c:GetParent() or nil
            end
            B.Print("Under the mouse: " .. (#chain > 0 and table.concat(chain, " < ") or "nothing"))
        end, 3000)
    elseif cmd == "prebuff" then
        B.Prebuff.Start()
    elseif cmd == "ready" then
        B.Ready.Show(true)
    elseif cmd == "food" then
        -- diagnostic: what Skillbound knows about the worn build's food and the long buffs on you
        local b = B.Apply.FoodBuild()
        local food = b and b.food
        if food and food.id then
            local ids = {}
            if B.sv.foodBuffs[food.id] then ids[#ids + 1] = tostring(B.sv.foodBuffs[food.id]) end
            for id in pairs((B.sv.foodBuffSet or {})[food.id] or {}) do ids[#ids + 1] = tostring(id) end
            local left = B.Apply.FoodLeft(food.id)
            B.Print(string.format("%s (item %d): learned buffs [%s], running: %s", B.Apply.FoodName(food), food.id,
                table.concat(ids, ", "), left and (math.floor(left / 60) .. " min left") or "no"))
        else
            B.Print("The build you wear has no food.")
        end
        local now = GetFrameTimeSeconds()
        for i = 1, GetNumBuffs("player") do
            local name, started, ending, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
            if ending - started >= 1200 then
                d(string.format("  %s (%d): %d min long, %d min left", B.Name(name), id, math.floor((ending - started) / 60), math.floor((ending - now) / 60)))
            end
        end
    elseif cmd == "steps" then
        -- diagnostic (English only, dev tool): how long each step of the last switch took
        local log = B.Apply.lastLog
        if not log then
            d("Skillbound: no build switch since the last reload.")
        else
            d(string.format("Skillbound: last switch \"%s\" took %d ms:", log.name, log.total))
            for _, e in ipairs(log) do d(string.format("  %5d ms  %s%s", e.ms, e.label, e.how)) end
        end
    elseif cmd == "errors" then
        -- the last errors the safety net caught (for bug reports)
        if #B.errors == 0 then
            B.Print(L("ERRORS_NONE"))
        else
            B.Print(L("ERRORS_HEAD", B.VERSION))
            for _, e in ipairs(B.errors) do d("  " .. e) end
        end
    elseif cmd == "reset" then
        B.sv.launcher.x, B.sv.launcher.y = nil, nil
        B.sv.window.x, B.sv.window.y = nil, nil
        B.sv.places = {}
        B.callbacks:FireCallbacks("PositionsReset")
        B.Print(L("RESET_DONE"))
    else
        B.Print(L("HELP"))
    end
end

-- keybind texts (Controls > Keybindings > Skillbound)
ZO_CreateStringId("SI_BINDING_NAME_SKILLBOUND_WINDOW", L("BIND_WINDOW"))
ZO_CreateStringId("SI_BINDING_NAME_SKILLBOUND_WHEEL", L("BIND_WHEEL"))
ZO_CreateStringId("SI_BINDING_NAME_SKILLBOUND_UNDO", L("BIND_UNDO"))
ZO_CreateStringId("SI_BINDING_NAME_SKILLBOUND_RULES", L("BIND_RULES"))
ZO_CreateStringId("SI_BINDING_NAME_SKILLBOUND_PREBUFF", L("BIND_PREBUFF"))
for i = 1, B.MAX_FAV do
    ZO_CreateStringId("SI_BINDING_NAME_SKILLBOUND_FAV" .. i, L("BIND_FAV", i))
end

-- keybind: wear favorite slot n
function B.WearFavorite(n)
    local b = B.Get(B.Char().fav[n])
    if b then
        B.Apply.Wear(b)
    else
        B.Print(L("FAV_EMPTY", n))
    end
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- saved per server (NA / EU / PTS): builds point at items and characters of one server.
    -- Data from before 1.0.1 lived under "Default": hand it to the first server we log into.
    local world = GetWorldName()
    if Skillbound_SV and Skillbound_SV.Default and not Skillbound_SV[world] then
        Skillbound_SV[world] = Skillbound_SV.Default
        Skillbound_SV.Default = nil
    end
    B.sv = ZO_SavedVars:NewAccountWide("Skillbound_SV", 1, nil, defaults, world)
    -- an accent still on an older default (0.1.0 amethyst, 0.2.0 Skyshard blue) becomes
    -- 0.3.0's ember amber (fresh installs have it already)
    local UI_VERSION = 6
    if (B.sv.uiVersion or 0) < UI_VERSION then
        local t = B.sv.theme
        local function Is(r, g, b) return math.abs(t.r - r) < 0.01 and math.abs(t.g - g) < 0.01 and math.abs(t.b - b) < 0.01 end
        if (B.sv.uiVersion or 0) < 3 and (Is(0.66, 0.55, 0.88) or Is(0.35, 0.71, 0.94)) then
            B.sv.theme = { r = 0.89, g = 0.66, b = 0.34 }
        end
        -- 4: the button's favorite slots went from 4 (max 6) to 10: the old default moves up
        if (B.sv.uiVersion or 0) < 4 and B.sv.launcher.slots == 4 then B.sv.launcher.slots = B.MAX_FAV end
        -- 5 (0.6.5): One Click Champion Points setups are no longer part of builds (kept separate):
        -- such a build leaves your champion stars alone now (no slotted stars were saved for it)
        -- 6 (1.0.0): food renewing early is off by default (user: eat only when it has run out)
        if (B.sv.uiVersion or 0) < 6 and B.sv.foodRenewMin == 10 then B.sv.foodRenewMin = 0 end
        if (B.sv.uiVersion or 0) < 5 then
            for _, b in pairs(B.sv.builds) do
                if b.cp and b.cp.occp then
                    b.cp = nil
                    if b.parts then b.parts.cp = false end
                end
            end
        end
        B.sv.uiVersion = UI_VERSION
    end
    B.ApplyTheme()
    B.Char()   -- name and class of this character

    B.Items.Init()
    B.Apply.Init()
    B.Fix.Init()
    B.Ready.Init()
    B.Prebuff.Init()
    B.Check.Init()
    B.Rules.Init()
    B.Marks.Init()
    B.Share.Init()
    B.UI.Init()
    B.Launcher.Init()
    B.Wheel.Init()
    B.InitSettings()

    SLASH_COMMANDS["/skillbound"] = Slash
    if not SLASH_COMMANDS["/sb"] then SLASH_COMMANDS["/sb"] = Slash end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
