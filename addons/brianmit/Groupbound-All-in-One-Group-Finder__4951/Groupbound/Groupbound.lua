-- Groupbound.lua : start-up, saved data, colors, slash command.
-- Groupbound = one board for every group you could join: the game's Group Finder, zone chat
-- and your guild chats, read and sorted for you, with Apply / Whisper in one click.
-- The parts:
--   Groupbound_Anim.lua      one small tween engine (hover, fades, glides)
--   Groupbound_Widgets.lua   building blocks (labels, frames, buttons, chips, close X, edit box)
--   Groupbound_Content.lua   trials / dungeons / arenas and their nicknames (vSS, vDSR, fg1...)
--   Groupbound_Parse.lua     reads a chat post: content, roles needed, tags, CP, start time
--   Groupbound_Chat.lua      listens to zone and guild chat, keeps the posts (15 min)
--   Groupbound_Finder.lua    the game's Group Finder: searches in turns, apply, your own listing
--   Groupbound_Achieve.lua   achievements a group asks for (links or names) and whether you have them
--   Groupbound_Board.lua     everything merged into one list, "for you" sorting, player notes
--   Groupbound_Watch.lua     leading: a member switches role after joining ("fake roles")
--   Groupbound_UI.lua        main window: list left, details / "Post a group" right (layout C)
--   Groupbound_HUD.lua       small board on screen + "new group" alert
--   Groupbound_Launcher.lua  the button
--   Groupbound_Settings.lua  settings (LibAddonMenu-2.0, optional)
-- One global table: Groupbound.

local ADDON_NAME = "Groupbound"
Groupbound = Groupbound or {}
local G = Groupbound

-- Text for key in the game's language (lang/en.lua, then lang/$(language).lua replaces what
-- it has), formatted with the extra arguments (string.format).
function G.L(key, ...)
    local id = _G["GROUPBOUND_" .. key]
    if type(id) ~= "number" then return key end
    local text = GetString(id)
    if select("#", ...) > 0 then return string.format(text, ...) end
    return text
end
local L = G.L

G.VERSION = "1.0.0"   -- keep the same as "## Version" in Groupbound.txt
G.AUTHOR = "brianmit"
-- the game's own Group Finder icon (from esoui groupfinder_keyboard.lua) stands in as the logo
G.LOGO = "EsoUI/Art/LFG/LFG_indexIcon_groupFinder_up.dds"

-- role icons (from esoui groupfinder_shared.lua)
G.ROLE_ICON = {
    tank = "EsoUI/Art/LFG/LFG_tank_down_no_glow_64.dds",
    heal = "EsoUI/Art/LFG/LFG_healer_down_no_glow_64.dds",
    dps = "EsoUI/Art/LFG/LFG_dps_down_no_glow_64.dds",
    any = "EsoUI/Art/LFG/LFG_any_down_no_glow_64.dds",
}
G.ROLES = { "tank", "heal", "dps" }

local function Hex(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end
G.Hex = Hex

-- Layout A (2026-10-12): the game's own text colors (ZO_NORMAL_TEXT etc., read from the game when
-- it has them), muted source colors, black see-through panels.
local function FromGame(def, hex)
    if def and def.UnpackRGB then
        local ok, r, g, b = pcall(def.UnpackRGB, def)
        if ok and r then return { r = r, g = g, b = b } end
    end
    return Hex(hex)
end
G.COLOR = {
    normal = FromGame(ZO_NORMAL_TEXT, "C5C29E"),       -- the game's normal text
    selected = FromGame(ZO_SELECTED_TEXT, "FFFFFF"),   -- picked / headers
    highlight = FromGame(ZO_HIGHLIGHT_TEXT, "E8DFAF"), -- hovered
    disabled = FromGame(ZO_DISABLED_TEXT, "5C5B56"),
    dim = Hex("8F8A76"),                               -- secondary text (sources, ages)
    good = FromGame(ZO_SUCCEEDED_TEXT, "5DC060"),
    bad = FromGame(ZO_ERROR_COLOR, "D63C3C"),
    panel = Hex("000000"),
    finder = Hex("6EA8DC"),    -- source dots: Group Finder
    zone = Hex("D2C27A"),      -- zone chat
    guild = Hex("B48AD0"),     -- guild chat
    -- difficulty (picked 2026-10-13, B): green normal, gold veteran (the game's veteran gold),
    -- red-orange hard mode; red stays for problems ("can't join", missing achievement)
    diffNormal = Hex("9CC98A"),
    diffVet = Hex("E3B866"),
    diffHM = Hex("E07A5A"),
}
G.COLOR.theme = G.COLOR.normal

function G.RGBA(c, a)
    return c.r, c.g, c.b, a or 1
end

function G.Colorize(c, text)
    return string.format("|c%02X%02X%02X%s|r", zo_round(c.r * 255), zo_round(c.g * 255), zo_round(c.b * 255), text)
end

-- the game's UI letters (the windows mostly use the game's font objects: ZoFontGame...)
function G.Font(kind, size)
    local face = (kind == "bold" or kind == "head" or kind == "title") and "$(BOLD_FONT)" or "$(MEDIUM_FONT)"
    if size < 12 then size = 12 end
    return face .. "|" .. size .. "|soft-shadow-thin"
end

local defaults = {
    window = { x = nil, y = nil },
    launcher = { hidden = false, combatHide = true, x = nil, y = nil },
    hud = { shown = false, x = nil, y = nil },
    -- which Group Finder categories are searched (settings); the tree picks what the list shows
    cats = { trial = true, dungeon = true, arena = true, other = true },
    view = "trial",           -- the tree: "all", "trial", "dungeon", "arena", "other", "alerts", "post"
    sortKey = "best",         -- column the list is sorted by
    sortUp = true,
    sources = { finder = true, zone = true, guild = true },
    forMe = true,             -- only groups with room for your role (and your CP)
    teach = false,            -- only teaching / learning runs
    players = false,          -- also show players looking for a group (for leaders)
    hideSales = true,         -- hide "WTS carry" and other selling posts
    chatMinutes = 15,         -- how long a chat post stays on the board
    background = true,        -- keep checking the Group Finder while the window is closed (alerts)
    toast = true,             -- "New group" message on screen
    sound = true,
    alertAll = false,         -- also alert for any new group that fits you (not only watched content)
    watches = {},             -- [contentKey] = true: alert me for these
    notes = {},               -- [@account lowercase] = { note = "", hidden = true, good = true }
    -- the Post a group page; the game's own listing options too (cat / primaryIdx / secondaryIdx /
    -- size / playstyle stay nil = automatic or the game's default)
    post = { text = "", tank = 0, heal = 0, dps = 0, cp = 0, time = "", note = "",
        title = "", desc = "", voip = false, auto = true, enforce = true, codeOn = false, code = "" },
    postOpen = {},            -- Post page drawers you opened (more / listing = true), kept open
    postByRun = {},           -- [content key] = what you last posted for it (roles, CP, note, ach, auto)
    anim = "full",            -- "full", "subtle" or "off"
    blockWords = "",          -- "opulent, wtt, recipe": groups with these words are hidden
    askApplyMsg = true,       -- groups that check each player: write a message before applying
    quietInside = true,       -- in dungeons / trials / arenas: no button, small board, alerts, background search
    lastListing = nil,        -- your last Group Finder listing ("List again"): the post spec + t + total roles
    langFilter = false,       -- "only languages I read" (the tree's checkbox)
    langs = nil,              -- { en = true, de = true... }: languages you read (first load: English + the game's)
    roleWatch = true,         -- leading: tell me when a member switches role after joining
    allListings = true,       -- search the Group Finder without the game's extra filters (yours come back after)
    catsVersion = 0,          -- 1: "Other" (custom / zone / adventure zone groups) searched (2026-10-13)
}

-- the game's language as Groupbound names it ("en", "de", "fr", "es"...)
function G.ClientLang()
    local ok, lang = pcall(GetCVar, "language.2")
    lang = ok and lang and zo_strlower(lang) or "en"
    return lang:sub(1, 2)
end

function G.Print(text)
    d(G.Colorize(G.COLOR.theme, L("PREFIX")) .. " " .. text)
end

G.callbacks = ZO_CallbackObject:New()
do
    local rawRegister = G.callbacks.RegisterCallback
    function G.callbacks:RegisterCallback(name, fn, ...)
        return rawRegister(self, name, G.Safe and G.Safe(fn, name) or fn, ...)
    end
end

-- ---------------------------------------------------------------------------
-- Safety net (like Skillbound / Rumorbound): everything that runs by itself (events, timers,
-- callbacks, per-frame updates) goes through G.Safe. An error prints ONE short chat line per
-- place and Groupbound keeps going; /gb errors lists the last ones.

G.errors = {}
local errorShown = {}

function G.ReportError(where, err, quiet)
    where = tostring(where or "?"):gsub("^Groupbound_", "")
    local text = tostring(err or "?"):match("^[^\n]*") or "?"
    table.insert(G.errors, 1, where .. ": " .. text)
    while #G.errors > 10 do table.remove(G.errors) end
    if quiet or errorShown[where] then return end
    errorShown[where] = true
    pcall(G.Print, L("ERROR_LINE", where))
end

local function Pass(where, ok, ...)
    if not ok then
        G.ReportError(where, ...)
        return
    end
    return ...
end

function G.Safe(fn, where)
    if type(fn) ~= "function" then return fn end
    return function(...) return Pass(where, pcall(fn, ...)) end
end

G.EM = {
    RegisterForEvent = function(_, name, event, fn) return EVENT_MANAGER:RegisterForEvent(name, event, G.Safe(fn, name)) end,
    RegisterForUpdate = function(_, name, ms, fn) return EVENT_MANAGER:RegisterForUpdate(name, ms, G.Safe(fn, name)) end,
    UnregisterForEvent = function(_, ...) return EVENT_MANAGER:UnregisterForEvent(...) end,
    UnregisterForUpdate = function(_, ...) return EVENT_MANAGER:UnregisterForUpdate(...) end,
}

function G.Later(fn, ms, where)
    return zo_callLater(G.Safe(fn, where or "delayed"), ms)
end

-- Fragment that shows a control only on the normal HUD (hidden in menus, map, dialogs).
function G.HudFragment(control)
    local fragment = ZO_HUDFadeSceneFragment:New(control)
    fragment.gbControl = control
    G.ShowOnHud(fragment, true)
    return fragment
end

function G.ShowOnHud(fragment, show)
    if fragment.gbShown ~= show then
        fragment.gbShown = show
        if show then
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
        else
            HUD_SCENE:RemoveFragment(fragment)
            HUD_UI_SCENE:RemoveFragment(fragment)
        end
    end
    fragment.gbControl:SetHidden(not show or not (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()))
end

function G.IsOver(control, pad)
    if not control or control:IsHidden() then return false end
    pad = pad or 0
    local x, y = GetUIMousePosition()
    return x >= control:GetLeft() - pad and x <= control:GetRight() + pad
        and y >= control:GetTop() - pad and y <= control:GetBottom() + pad
end

-- seconds since 1970 (UTC), the clock every post uses
function G.Now()
    return GetTimeStamp()
end

-- "3 min" / "1 h" style age
function G.Ago(t)
    if not t then return "" end
    local s = math.max(0, G.Now() - t)
    if s < 60 then return L("AGO_NOW") end
    if s < 3600 then return L("AGO_MIN", math.floor(s / 60)) end
    return L("AGO_HOUR", math.floor(s / 3600))
end

-- your local time offset from UTC in seconds (from the game's local clock "HH:MM:SS")
function G.LocalOffset()
    local h, m, s = (GetTimeString() or ""):match("^(%d+):(%d+):(%d+)")
    if not h then return 0 end
    local localSecs = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    local diff = localSecs - G.Now() % 86400
    -- round to 15 minutes and keep it within one day either way
    diff = zo_round(diff / 900) * 900
    if diff > 14 * 3600 then diff = diff - 86400 elseif diff < -12 * 3600 then diff = diff + 86400 end
    return diff
end

-- "20:30" in your local time for a UTC timestamp
function G.ClockText(t)
    local localT = (t + G.LocalOffset()) % 86400
    return string.format("%02d:%02d", math.floor(localT / 3600), math.floor((localT % 3600) / 60))
end

-- the role you play: the one picked in the game's group menu (Groupbound's role buttons set it too)
local ROLE_BY_LFG
function G.MyRole()
    if not ROLE_BY_LFG then
        ROLE_BY_LFG = {}
        if LFG_ROLE_TANK then ROLE_BY_LFG[LFG_ROLE_TANK] = "tank" end
        if LFG_ROLE_HEAL then ROLE_BY_LFG[LFG_ROLE_HEAL] = "heal" end
        if LFG_ROLE_DPS then ROLE_BY_LFG[LFG_ROLE_DPS] = "dps" end
    end
    local ok, lfg = pcall(GetSelectedLFGRole)
    return ok and ROLE_BY_LFG[lfg] or "dps"
end

function G.LfgRole(role)
    if role == "tank" then return LFG_ROLE_TANK end
    if role == "heal" then return LFG_ROLE_HEAL end
    return LFG_ROLE_DPS
end

function G.RoleName(role)
    if role == "any" then return L("ROLE_ANY") end
    return L("ROLE_" .. zo_strupper(role))
end

function G.MyCP()
    local ok, cp = pcall(GetPlayerChampionPointsEarned)
    return ok and cp or 0
end

-- "@Name" lowercase: the key for player notes
function G.AccountKey(account)
    if not account or account == "" then return nil end
    return zo_strlower(account)
end

function G.Note(account)
    local key = G.AccountKey(account)
    return key and G.sv.notes[key] or nil
end

function G.EnsureNote(account)
    local key = G.AccountKey(account)
    if not key then return nil end
    local n = G.sv.notes[key]
    if not n then
        n = {}
        G.sv.notes[key] = n
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Blocked words (setting): "opulent, wtt, OO". Short words (3 letters or less) only count as a
-- whole word ("oo" doesn't hide "room"; "vOO" / "nOO" count, like trial nicknames), longer ones
-- anywhere in the text.

local blockSource, blockList
local function BlockList()
    local source = G.sv.blockWords or ""
    if source ~= blockSource then
        blockSource = source
        blockList = {}
        for word in source:gmatch("[^,;]+") do
            word = zo_strlower(zo_strtrim(word))
            if word ~= "" then blockList[#blockList + 1] = word end
        end
    end
    return blockList
end

-- the blocked word found in text (or nil)
function G.BlockedWord(text)
    if not text or text == "" then return nil end
    local list = BlockList()
    if #list == 0 then return nil end
    local lower = " " .. zo_strlower(text) .. " "
    for _, word in ipairs(list) do
        if #word <= 3 then
            -- whole word: not between letters or digits (a "v" / "n" in front is fine: vOO)
            local plain = word:gsub("(%W)", "%%%1")
            if lower:find("[^%w][vn]?" .. plain .. "[^%w]") then return word end
        elseif lower:find(word, 1, true) then
            return word
        end
    end
end

-- ---------------------------------------------------------------------------
-- Staying out of the way (setting quietInside): inside a dungeon, trial or arena

-- a group dungeon, arena or trial (not a delve / public dungeon: IsUnitInDungeon is true there too,
-- the button would hide in every delve). Trials = IsPlayerInRaid; dungeons / arenas have a
-- difficulty (normal / veteran).
function G.InInstance()
    if IsPlayerInRaid then
        local okRaid, inRaid = pcall(IsPlayerInRaid)
        if okRaid and inRaid then return true end
    end
    if GetCurrentZoneDungeonDifficulty and DUNGEON_DIFFICULTY_NONE ~= nil then
        local ok, diff = pcall(GetCurrentZoneDungeonDifficulty)
        return ok and diff ~= nil and diff ~= DUNGEON_DIFFICULTY_NONE or false
    end
    local ok, inDungeon = pcall(IsUnitInDungeon, "player")
    return ok and inDungeon or false
end

-- in a battleground (the Group Finder isn't available there: searching gave errors in other addons)
function G.InBattleground()
    if not IsActiveWorldBattleground then return false end
    local ok, yes = pcall(IsActiveWorldBattleground)
    return ok and yes or false
end

function G.Quiet()
    return G.sv.quietInside and G.InInstance() or false
end

-- removes empty note records (no text, not hidden, not marked)
function G.TidyNote(account)
    local key = G.AccountKey(account)
    local n = key and G.sv.notes[key]
    if n and (not n.note or n.note == "") and not n.hidden and not n.good then
        G.sv.notes[key] = nil
    end
end

-- ---------------------------------------------------------------------------
-- Slash command

local function Slash(args)
    args = zo_strtrim(args or "")
    local cmd = zo_strlower(args:match("^(%S*)") or "")
    if cmd == "" then
        if G.sv.launcher.hidden then
            G.sv.launcher.hidden = false
            G.callbacks:FireCallbacks("SettingsChanged")
            G.Print(L("SHOWN_LAUNCHER"))
        end
        G.UI.Toggle()
    elseif cmd == "settings" then
        G.OpenSettings()
    elseif cmd == "post" then
        G.UI.Show()
        G.UI.ShowPost()
    elseif cmd == "relist" then
        G.Finder.Relist()
    elseif cmd == "test" then
        -- try pages that normally need other players (nothing is sent to the game)
        local what = zo_strlower(args:match("^%S+%s+(%S+)") or "")
        if what == "applicants" then
            G.Finder.StartTest()
            G.Print(L("TEST_ON"))
            G.UI.ShowApplicants()
        elseif what == "roleswitch" then
            G.Watch.Announce({ char = "Test Player", account = "@TestPlayer" }, LFG_ROLE_TANK, LFG_ROLE_DPS)
        elseif what == "alert" then
            local e = G.Board.ForMeList(1)[1] or G.Board.Visible()[1]
            if e then G.HUD.Alert(e) else G.Print(L("TEST_NO_GROUP")) end
        elseif what == "off" then
            G.Finder.StopTest()
            G.Print(L("TEST_OFF"))
        else
            G.Print(L("TEST_HELP"))
        end
    elseif cmd == "hud" then
        G.ToggleHud()
    elseif cmd == "errors" then
        if #G.errors == 0 then
            G.Print(L("ERRORS_NONE"))
        else
            G.Print(L("ERRORS_HEAD", G.VERSION))
            for _, e in ipairs(G.errors) do d("  " .. e) end
        end
    elseif cmd == "reset" then
        G.sv.launcher.x, G.sv.launcher.y = nil, nil
        G.sv.window.x, G.sv.window.y = nil, nil
        G.sv.hud.x, G.sv.hud.y = nil, nil
        G.callbacks:FireCallbacks("PositionsReset")
        G.Print(L("RESET_DONE"))
    elseif cmd == "debug" then
        G.Finder.PrintDebug()
    else
        G.Print(L("HELP"))
    end
end

ZO_CreateStringId("SI_BINDING_NAME_GROUPBOUND_WINDOW", L("BIND_WINDOW"))
ZO_CreateStringId("SI_BINDING_NAME_GROUPBOUND_HUD", L("BIND_HUD"))
ZO_CreateStringId("SI_BINDING_NAME_GROUPBOUND_ALERT", L("BIND_ALERT"))
ZO_CreateStringId("SI_BINDING_NAME_GROUPBOUND_POST", L("BIND_POST"))
ZO_CreateStringId("SI_BINDING_NAME_GROUPBOUND_RELIST", L("BIND_RELIST"))

function G.ToggleHud()
    G.sv.hud.shown = not G.sv.hud.shown
    G.callbacks:FireCallbacks("SettingsChanged")
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- saved per server (NA / EU / PTS): players and notes belong to that server
    G.sv = ZO_SavedVars:NewAccountWide("Groupbound_SV", 1, nil, defaults, GetWorldName())
    -- (once: custom / zone groups are searched too; many players list in "Custom")
    if (G.sv.catsVersion or 0) < 1 then
        G.sv.cats.other = true
        G.sv.catsVersion = 1
    end
    -- (once: Auto-accept is ticked by default when you post a group, 2026-10-14)
    if (G.sv.postVersion or 0) < 1 then
        G.sv.post.auto = true
        G.sv.postVersion = 1
    end
    if not G.sv.langs then
        G.sv.langs = { en = true }
        G.sv.langs[G.ClientLang()] = true
    end

    G.W.InitRowLight()
    G.Content.Init()
    G.Chat.Init()
    G.Finder.Init()
    G.Board.Init()
    G.Watch.Init()
    G.UI.Init()
    G.HUD.Init()
    G.Launcher.Init()
    G.InitSettings()

    SLASH_COMMANDS["/groupbound"] = Slash
    if not SLASH_COMMANDS["/gb"] then SLASH_COMMANDS["/gb"] = Slash end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
