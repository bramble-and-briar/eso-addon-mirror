-- Fury's Account Sync
-- Makes your other accounts on this PC match your main one: game settings, keybinds, chat look,
-- addon settings and window layout, plus character builds you can load onto any character.
-- The separate Windows tool does the same for addon settings with the game closed, including
-- addons that aren't turned on for an account.
--
-- Saved data lives in one file that every account on this PC shares (SavedVariables are per PC,
-- not per account), so an alt can read the snapshot the main account took.

FurysAccountSync = {
    name        = "FurysAccountSync",
    title       = "Fury's Account Sync",
    version     = "0.6.9",
    toolUrl     = "https://github.com/AlbertHoffpauir/FurysAccountSync",
    SCENE       = "FurysAccountSync_Scene",
}
local AS = FurysAccountSync


-- The game Settings pages this addon copies. Video and Audio are left out on purpose: they are kept
-- in UserSettings.txt, which every account on the same PC already shares.
AS.PANELS = {
    { key = "gameplay",      panel = SETTING_PANEL_GAMEPLAY,      name = "Gameplay" },
    { key = "camera",        panel = SETTING_PANEL_CAMERA,        name = "Camera" },
    { key = "interface",     panel = SETTING_PANEL_INTERFACE,     name = "Interface" },
    { key = "nameplates",    panel = SETTING_PANEL_NAMEPLATES,    name = "Nameplates" },
    { key = "social",        panel = SETTING_PANEL_SOCIAL,        name = "Social" },
    { key = "combat",        panel = SETTING_PANEL_COMBAT,        name = "Combat" },
    { key = "accessibility", panel = SETTING_PANEL_ACCESSIBILITY, name = "Accessibility" },
}

-- Setting groups never touched: graphics and sound (shared per PC already), account and voice
-- details, debug options and menu buttons that run an action instead of holding a value.
local SKIP_SYSTEM = {
    [SETTING_TYPE_GRAPHICS]        = true,
    [SETTING_TYPE_AUDIO]           = true,
    [SETTING_TYPE_ACCOUNT]         = true,
    [SETTING_TYPE_VOICE]           = true,
    [SETTING_TYPE_DEVELOPER_DEBUG] = true,
    [SETTING_TYPE_CUSTOM]          = true,
}

------------------------------------------------------------------------------
-- Saved data
------------------------------------------------------------------------------
local SV

local function Defaults()
    return {
        main         = nil,     -- "@Account" that snapshots come from
        snapshot     = nil,     -- the main's setup, see AS.TakeSnapshot
        accounts     = {},      -- ["@Account"] = { mode = "off" | "ask" | "auto", applied = time, seen = time,
                                --                  chars = { [characterId] = snapshot time copied }, last = {...},
                                --                  addonsAt = snapshot time addon settings were copied for }
        undo         = {},      -- ["@Account"] = the addon settings the account had before copying, see AddonCopy.lua
        builds       = {},      -- ["Build name"] = build, see Builds.lua
        extra        = {},      -- ["SavedVariableName"] = true: addons the player added to the copy list
        pick         = {},      -- ["SavedVariableName"] = true / false: the player's tick for that addon, see Rules.lua
        what         = {        -- what an alt takes from the snapshot
            keybinds = true,
            chat     = true,
            addons   = false,   -- settings of the addons listed in Rules.lua (ends with a UI reload)
            layout   = false,   -- base game chat window, meters, quest tracker and HUD positions (ends with a UI reload)
            panels   = { gameplay = true, camera = true, interface = true, nameplates = true,
                         social = true, combat = true, accessibility = true },
        },
        autoSnapshot = false,   -- main takes a fresh snapshot at every logout, reload and zone change
        mainChar     = nil,     -- characterId of the main character: automatic snapshots only come from it
        mainCharName = nil,
        mainKeys     = false,   -- the main account's other characters take the main character's keybinds at login
        builds_on    = false,   -- Character builds section
        buildParts   = { skills = true, cp = true, quick = true, gear = false },   -- what Load build puts on the character
    }
end

-- Fills in anything missing from older saved data without touching what is there.
local function Merge(into, from)
    for k, v in pairs(from) do
        if into[k] == nil then
            into[k] = v
        elseif type(v) == "table" and type(into[k]) == "table" then
            Merge(into[k], v)
        end
    end
end

function AS.SV() return SV end

function AS.Account() return GetDisplayName() end

function AS.IsMain() return SV.main ~= nil and SV.main == GetDisplayName() end

-- 0.5.7: the main character is the one on the main account whose keybinds the others copy, and the
-- only one an automatic snapshot comes from. Before 0.5.7 every character of the main snapshotted
-- at logout, so a character without your addon keys could wipe them from the snapshot.
-- Snapshots older than 0.5.7 only kept the character's name.
function AS.IsMainChar()
    if SV.mainChar then return SV.mainChar == GetCurrentCharacterId() end
    if SV.snapshot and SV.snapshot.char then return SV.snapshot.char == GetUnitName("player") end
    return true
end

function AS.MainCharName()
    return SV.mainCharName or (SV.snapshot and SV.snapshot.char) or nil
end

local function SetMainChar()
    SV.mainChar = GetCurrentCharacterId()
    SV.mainCharName = GetUnitName("player")
end

function AS.AccountRecord(acct)
    acct = acct or GetDisplayName()
    local rec = SV.accounts[acct]
    if not rec then
        rec = { mode = "off", applied = 0, seen = 0 }
        SV.accounts[acct] = rec
    end
    if not rec.chars then rec.chars = {} end
    return rec
end

-- The game keeps settings, keybinds and chat colors per character, so each character copies the
-- snapshot once. This is the time of the snapshot this character last copied (0 = never).
function AS.CopiedHere()
    return AS.AccountRecord().chars[GetCurrentCharacterId()] or 0
end

-- Synced Account Settings (another addon) puts its own saved settings and every keybind back a few
-- seconds after each login, which undoes whatever is copied here. True while it is doing that on
-- this account.
function AS.OtherSyncActive()
    local other = AccountSettings
    return type(other) == "table" and type(other.sv) == "table" and other.sv.sync == true and other.sv.tracked == true
end

local OTHER_SYNC_MAIN_TEXT = "Synced Account Settings is syncing this account. It puts its own saved keybinds and settings " ..
    "back after every login, so a change you make here can be erased before the snapshot is taken. Turn it off " ..
    "here, or press its Save button after every change."

local OTHER_SYNC_TEXT = "Synced Account Settings is turned on for this account. It puts its own saved settings and keybinds " ..
    "back after every login, which undoes this copy, so nothing is copied while it is on. Turn it off in the " ..
    "AddOns list (or untick its Sync option) and reload."

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------
function AS.Msg(text)
    AS.Theme.Chat(text)   -- 0.5.4: the shared chat line (Theme.lua)
end

function AS.When(ts)
    if not ts or ts == 0 then return "never" end
    return os.date("%Y-%m-%d %H:%M", ts)
end

-- Some action-bar and quickslot calls are protected in some game versions and not in others.
function AS.Call(fnName, ...)
    if IsProtectedFunction(fnName) then
        return CallSecureProtected(fnName, ...)
    end
    return _G[fnName](...)
end

local function TextOf(id)
    if type(id) == "number" then return GetString(id) end
    if type(id) == "string" then return id end
    return ""
end

------------------------------------------------------------------------------
-- Reading the game's Settings pages
------------------------------------------------------------------------------
-- The game keeps every option shown in its Settings menu in ZO_SharedOptions_SettingsData,
-- by page, then setting group, then setting. We read the list from there instead of keeping our own,
-- so new options the game adds are picked up without an update.
local function ForEachSetting(panel, fn)
    local page = ZO_SharedOptions_SettingsData[panel]
    if type(page) ~= "table" then return end
    for system, settings in pairs(page) do
        if type(settings) == "table" then
            for settingId, data in pairs(settings) do
                if type(data) == "table" then
                    local s = data.system or system
                    local i = data.settingId or settingId
                    local language = (s == SETTING_TYPE_UI and i == UI_SETTING_TEXT_LANGUAGE)
                                  or s == SETTING_TYPE_LANGUAGE
                    if type(s) == "number" and type(i) == "number" and not SKIP_SYSTEM[s] and not language then
                        fn(s, i, TextOf(data.text), data)
                    end
                end
            end
        end
    end
end

local function Captureable(value)
    return value ~= nil and value ~= ""
end

-- A setting's value the way the game's Settings menu words it: Off and On for a tickbox, the
-- game's own text for a choice where the game has one. Anything else is shown as it is stored.
local optionData
local function ValueText(system, settingId, value)
    local text = tostring(value)
    if not optionData then
        optionData = {}
        for _, p in ipairs(AS.PANELS) do
            ForEachSetting(p.panel, function(s, i, _, data) optionData[s .. ":" .. i] = data end)
        end
    end
    local data = optionData[system .. ":" .. settingId]
    if not data then return text end
    if data.controlType == OPTIONS_CHECKBOX then
        if text == "1" or text == "true" then return "On" end
        if text == "0" or text == "false" then return "Off" end
    elseif type(data.valueStringPrefix) == "string" then
        local stringId = _G[data.valueStringPrefix .. text]
        if type(stringId) == "number" and GetString(stringId) ~= "" then return GetString(stringId) end
    end
    return text
end

------------------------------------------------------------------------------
-- Keybinds
------------------------------------------------------------------------------
local function Combo(key, m1, m2, m3, m4)
    return key .. ":" .. (m1 or 0) .. ":" .. (m2 or 0) .. ":" .. (m3 or 0) .. ":" .. (m4 or 0)
end

-- Calls fn(layer, category, action, actionName) for every action the player can rebind.
local function ForEachAction(fn)
    for layer = 1, GetNumActionLayers() do
        local _, numCategories = GetActionLayerInfo(layer)
        for category = 1, numCategories do
            local _, numActions = GetActionLayerCategoryInfo(layer, category)
            for action = 1, numActions do
                local actionName, isRebindable, isHidden = GetActionInfo(layer, category, action)
                if isRebindable and not isHidden then
                    fn(layer, category, action, actionName)
                end
            end
        end
    end
end

-- The snapshot keeps the name of every action plus the slots that hold a key. A slot of a listed
-- action that isn't in "binds" is unbound on the main. (Most slots are empty, so listing every one
-- made the saved file ten times bigger.)
local function ReadKeybinds()
    local actions, binds = {}, {}
    ForEachAction(function(layer, category, action, actionName)
        actions[#actions + 1] = actionName
        for binding = 1, GetMaxBindingsPerAction() do
            local key, m1, m2, m3, m4 = GetActionBindingInfo(layer, category, action, binding)
            if key ~= 0 then
                binds[#binds + 1] = { actionName, binding, key, m1, m2, m3, m4 }
            end
        end
    end)
    return actions, binds
end

-- Every slot the snapshot knows about as { actionName, slot, key, m1, m2, m3, m4 }, key 0 = unbound.
-- Snapshots from 0.1.0 and 0.1.1 already stored that list as "keybinds".
local function SnapshotSlots(snap)
    if snap.keybinds then return snap.keybinds end
    local held = {}
    for _, k in ipairs(snap.binds or {}) do held[k[1] .. "#" .. k[2]] = k end
    local list = {}
    for _, actionName in ipairs(snap.actions or {}) do
        for binding = 1, GetMaxBindingsPerAction() do
            list[#list + 1] = held[actionName .. "#" .. binding] or { actionName, binding, 0, 0, 0, 0, 0 }
        end
    end
    return list
end

local function SnapshotKeyCounts(snap)
    if snap.keybinds then
        local bound = 0
        for _, k in ipairs(snap.keybinds) do if k[3] ~= 0 then bound = bound + 1 end end
        return bound
    end
    return #(snap.binds or {})
end

------------------------------------------------------------------------------
-- Chat look (colors, text size, fade). Chat tabs and the window's place are saved per character by
-- the game and are copied by the Windows tool.
------------------------------------------------------------------------------
local function ReadChat()
    local colors = {}
    for category = CHAT_CATEGORY_MIN_VALUE, CHAT_CATEGORY_MAX_VALUE do
        local r, g, b = GetChatCategoryColor(category)
        if r then colors[category] = { r, g, b } end
    end
    return {
        colors   = colors,
        fontSize = KEYBOARD_CHAT_SYSTEM:GetFontSizeFromSetting(),
        minAlpha = KEYBOARD_CHAT_SYSTEM:GetMinAlpha(),
    }
end

------------------------------------------------------------------------------
-- Choosing the main account
------------------------------------------------------------------------------
local AskReload   -- the confirm pop-up, defined further down

-- Makes the account you're on the main, after a pop-up. When another account was the main,
-- that account's snapshot is dropped: it describes the old main, not this one.
function AS.MakeMain()
    local me = GetDisplayName()
    if SV.main == me then return end
    local old = SV.main
    local function go()
        SV.main = me
        SetMainChar()
        local dropped = false
        if SV.snapshot and SV.snapshot.by ~= me then
            SV.snapshot = nil
            dropped = true
        end
        if dropped then
            AS.Msg(me .. " is now the main account. The snapshot from " .. tostring(old) .. " is gone. Press Take snapshot in /fas to save this account's setup.")
        else
            AS.Msg(me .. " is now the main account. Press Take snapshot in /fas to save its setup.")
        end
        AS.RefreshWindow()
    end
    if not old then
        -- 0.5.5: the first pick asks too (Albert: nothing that sticks happens on one click).
        AskReload("Make this account the main",
            "Make " .. me .. " the main account?\n\nYour other accounts on this PC will copy " .. me .. " from now on. You can change it later.",
            "Make it the main", go)
        return
    end
    AskReload("Change the main account",
        "The main account is " .. old .. ". Make " .. me .. " the main?\n\nYour other accounts will copy " .. me ..
        " from now on. The snapshot taken on " .. old .. " is removed, so take a new one here afterwards.",
        "Change the main", go)
end

------------------------------------------------------------------------------
-- Snapshot (main account only)
------------------------------------------------------------------------------
-- auto: the automatic snapshot at logout, reload or zone change. It only runs on the main character.
-- A snapshot you take with the button makes the character you're on the main character.
function AS.TakeSnapshot(quiet, auto)
    if not AS.IsMain() then
        if not quiet then AS.Msg("Only the main account takes snapshots. Make this account the main in the settings first.") end
        return false
    end
    if auto and not AS.IsMainChar() then return false end
    if not auto then SetMainChar() end
    local actions, binds = ReadKeybinds()
    local snap = {
        by       = GetDisplayName(),
        char     = GetUnitName("player"),
        charId   = GetCurrentCharacterId(),
        time     = GetTimeStamp(),
        settings = {},
        actions  = actions,
        binds    = binds,
        chat     = ReadChat(),
    }
    local count = 0
    for _, p in ipairs(AS.PANELS) do
        local list = {}
        ForEachSetting(p.panel, function(system, settingId, text)
            local value = GetSetting(system, settingId)
            if Captureable(value) then
                list[#list + 1] = { s = system, i = settingId, v = value, t = text }
                count = count + 1
            end
        end)
        snap.settings[p.key] = list
    end
    SV.snapshot = snap
    if not quiet then
        AS.Msg(string.format("Snapshot taken: %d game settings, %d %s, chat look.", count, #binds,
            #binds == 1 and "keybind" or "keybinds"))
        if AS.OtherSyncActive() then AS.Msg(OTHER_SYNC_MAIN_TEXT) end
    end
    AS.RefreshWindow()
    return true
end

------------------------------------------------------------------------------
-- What would change on this account
------------------------------------------------------------------------------
-- Returns a plan: { settings = { {s, i, v, t, old, page} }, unbind = {...}, bind = {...}, steal = {...},
--                   keysMissing = n, chat = bool, chatData = {...}, addons = {...}, layout = {...} }
-- unbind: slots the main has empty. bind: slots that get the main's key. steal: slots outside the
-- snapshot that hold a key the main uses for something else, cleared so the key can move.
-- addons and layout: see AddonCopy.lua. gameOnly leaves those two out.
-- keysOnly: just the keybinds (the main account's other characters, 0.5.7).
function AS.Plan(gameOnly, skipAddons, keysOnly)
    local snap = SV.snapshot
    local plan = { settings = {}, unbind = {}, bind = {}, steal = {}, keysMissing = 0, chat = false, addons = {}, layout = {} }
    if not snap then return plan end
    local what = SV.what
    if keysOnly then
        gameOnly = true
        what = { keybinds = true, chat = false, panels = {} }
    end
    if not gameOnly then
        if what.addons and not skipAddons then plan.addons = AS.AddonPlan() end
        if what.layout then plan.layout = AS.LayoutPlan() end
    end

    for _, p in ipairs(AS.PANELS) do
        if what.panels[p.key] then
            for _, e in ipairs(snap.settings[p.key] or {}) do
                local cur = GetSetting(e.s, e.i)
                if Captureable(cur) and tostring(cur) ~= tostring(e.v) then
                    plan.settings[#plan.settings + 1] = { s = e.s, i = e.i, v = e.v, t = e.t, old = cur, page = p.name }
                end
            end
        end
    end

    if what.keybinds then
        local slots = SnapshotSlots(snap)
        local wanted = {}        -- what the main has in each slot
        for _, k in ipairs(slots) do wanted[k[1] .. "#" .. k[2]] = Combo(k[3], k[4], k[5], k[6], k[7]) end
        local changing = {}      -- slots this plan already clears or rebinds
        for _, k in ipairs(slots) do
            local layer, category, action = GetActionIndicesFromName(k[1])
            if layer and category and action then
                local key, m1, m2, m3, m4 = GetActionBindingInfo(layer, category, action, k[2])
                if key ~= k[3] or m1 ~= (k[4] or 0) or m2 ~= (k[5] or 0) or m3 ~= (k[6] or 0) or m4 ~= (k[7] or 0) then
                    local entry = { layer, category, action, k[2], k[3], k[4] or 0, k[5] or 0, k[6] or 0, k[7] or 0, k[1], had = key }
                    changing[layer .. ":" .. category .. ":" .. action .. ":" .. k[2]] = true
                    if k[3] == 0 or k[3] == nil then
                        plan.unbind[#plan.unbind + 1] = entry
                    else
                        plan.bind[#plan.bind + 1] = entry
                    end
                end
            else
                plan.keysMissing = plan.keysMissing + 1
            end
        end
        -- A key the main uses can be held here by something the snapshot doesn't cover, for example
        -- an addon the main doesn't run. That slot has to be cleared first or the key can't move.
        if #plan.bind > 0 then
            local held = {}
            ForEachAction(function(layer, category, action, actionName)
                for binding = 1, GetMaxBindingsPerAction() do
                    local key, m1, m2, m3, m4 = GetActionBindingInfo(layer, category, action, binding)
                    if key ~= 0 then
                        held[layer .. "|" .. Combo(key, m1, m2, m3, m4)] = { layer, category, action, binding, 0, 0, 0, 0, 0, actionName, had = key }
                    end
                end
            end)
            for _, e in ipairs(plan.bind) do
                local combo = Combo(e[5], e[6], e[7], e[8], e[9])
                local other = held[e[1] .. "|" .. combo]
                if other then
                    local slotKey = other[1] .. ":" .. other[2] .. ":" .. other[3] .. ":" .. other[4]
                    local sameSlot = (other[2] == e[2] and other[3] == e[3] and other[4] == e[4])
                    -- left alone when the main really has this key on both actions
                    if not sameSlot and not changing[slotKey] and wanted[other[10] .. "#" .. other[4]] ~= combo then
                        changing[slotKey] = true
                        other.takenBy = e[10]
                        plan.steal[#plan.steal + 1] = other
                    end
                end
            end
        end
    end

    if what.chat and snap.chat then
        local c = snap.chat
        local differs = (c.fontSize ~= KEYBOARD_CHAT_SYSTEM:GetFontSizeFromSetting())
                     or (c.minAlpha ~= KEYBOARD_CHAT_SYSTEM:GetMinAlpha())
        for category, rgb in pairs(c.colors or {}) do
            local r, g, b = GetChatCategoryColor(category)
            if r and (math.abs(r - rgb[1]) > 0.002 or math.abs(g - rgb[2]) > 0.002 or math.abs(b - rgb[3]) > 0.002) then
                differs = true
            end
        end
        plan.chat = differs
        plan.chatData = c
    end
    return plan
end

local function KeyCount(plan)
    return #plan.unbind + #plan.bind + #plan.steal
end

-- Addon settings and window layout: the parts that need a UI reload to show.
local function ReloadCount(plan)
    return #plan.addons + #plan.layout
end

function AS.PlanCount(plan)
    return #plan.settings + #plan.unbind + #plan.bind + #plan.steal + (plan.chat and 1 or 0) + ReloadCount(plan)
end

------------------------------------------------------------------------------
-- Describing a plan (used by the preview and by the report after copying)
------------------------------------------------------------------------------
local C_HEAD, C_TEXT, C_SUB, C_MUTED, C_GOOD, C_WARN = "|c5CC2FF", "|cECEAF8", "|cB4B0D8", "|c8A86B0", "|c5EE6A0", "|cFFC857"

local function ActionLabel(actionName)
    local stringId = _G["SI_BINDING_NAME_" .. actionName]
    if type(stringId) == "number" and GetString(stringId) ~= "" then return GetString(stringId) end
    return actionName
end

local function KeyLabel(e)
    local label = ActionLabel(e[10])
    if e[4] > 1 then label = label .. " (key " .. e[4] .. ")" end
    return label
end

local function PlanLines(plan, add)
    local byPage, order = {}, {}
    for _, e in ipairs(plan.settings) do
        if not byPage[e.page] then byPage[e.page] = {}; order[#order + 1] = e.page end
        table.insert(byPage[e.page], e)
    end
    for _, page in ipairs(order) do
        add(C_HEAD .. page .. "|r " .. C_MUTED .. "(" .. #byPage[page] .. ")|r")
        for _, e in ipairs(byPage[page]) do
            local name = (e.t ~= "" and e.t) or ("Setting " .. e.s .. "/" .. e.i)
            add("  " .. C_TEXT .. name .. "|r  " .. C_MUTED .. ValueText(e.s, e.i, e.old) .. " > |r" ..
                C_TEXT .. ValueText(e.s, e.i, e.v) .. "|r")
        end
    end
    if KeyCount(plan) > 0 then
        add(C_HEAD .. "Keybinds|r " .. C_MUTED .. "(" .. KeyCount(plan) .. ")|r")
        local shown = 0
        for _, list in ipairs({ plan.bind, plan.steal, plan.unbind }) do
            for _, e in ipairs(list) do
                if shown < 60 then
                    local keyText = (e[5] and e[5] ~= 0) and ZO_Keybindings_GetBindingStringFromKeys(e[5], e[6], e[7], e[8], e[9]) or "not bound"
                    local why = ""
                    if e.takenBy then why = "  " .. C_MUTED .. "(the main uses its key for " .. ActionLabel(e.takenBy) .. ")|r" end
                    add("  " .. C_TEXT .. KeyLabel(e) .. "|r  " .. C_MUTED .. "> |r" .. C_TEXT .. keyText .. "|r" .. why)
                end
                shown = shown + 1
            end
        end
        if shown > 60 then add("  " .. C_MUTED .. "and " .. (shown - 60) .. " more|r") end
    end
    if plan.chat then
        add(C_HEAD .. "Chat|r  " .. C_TEXT .. "colors, text size and fade|r")
    end
    if #plan.addons > 0 then
        add(C_HEAD .. "Addon settings|r " .. C_MUTED .. "(" .. #plan.addons .. ")|r")
        for _, e in ipairs(plan.addons) do
            local detail = e.added and "none here yet" or (e.parts == 1 and "1 part differs" or (e.parts .. " parts differ"))
            local name = e.name
            if e.profile ~= "Default" then name = name .. " (" .. tostring(e.profile) .. ")" end
            add("  " .. C_TEXT .. name .. "|r  " .. C_MUTED .. detail .. "|r")
        end
    end
    if #plan.layout > 0 then
        local names = {}
        for _, part in ipairs(plan.layout) do names[#names + 1] = part.name end
        add(C_HEAD .. "Window layout|r  " .. C_TEXT .. table.concat(names, ", ") .. "|r")
    end
end

------------------------------------------------------------------------------
-- Apply the snapshot to this character
------------------------------------------------------------------------------
-- Keybind changes go to the server one message each. They are sent a few at a time with a short
-- pause, not all at once, so a big first copy can't flood the connection.
local KEY_BATCH    = 4
local KEY_PAUSE_MS = 150

local function SendKeybinds(calls, done)
    local index = 1
    local function step()
        if IsUnitInCombat("player") then
            done(false)
            return
        end
        for _ = 1, KEY_BATCH do
            local c = calls[index]
            if not c then break end
            if c.unbind then
                CallSecureProtected("UnbindKeyFromAction", c[1], c[2], c[3], c[4])
            else
                CallSecureProtected("BindKeyToAction", c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
            end
            index = index + 1
        end
        if index > #calls then
            -- give the last ones a moment to land before checking the result
            zo_callLater(function() done(true) end, 500)
        else
            zo_callLater(step, KEY_PAUSE_MS)
        end
    end
    step()
end

-- Clear first, then bind, so a key moving from one action to another lands where it belongs:
-- slots the main has empty, slots in the way, and the old key of every slot that gets a new one.
local function KeyCalls(plan)
    local calls = {}
    for _, e in ipairs(plan.unbind) do calls[#calls + 1] = { e[1], e[2], e[3], e[4], unbind = true } end
    for _, e in ipairs(plan.steal) do calls[#calls + 1] = { e[1], e[2], e[3], e[4], unbind = true } end
    for _, e in ipairs(plan.bind) do
        if e.had and e.had ~= 0 then calls[#calls + 1] = { e[1], e[2], e[3], e[4], unbind = true } end
    end
    for _, e in ipairs(plan.bind) do calls[#calls + 1] = { e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9] } end
    return calls
end

-- Nothing reloads the UI without asking (0.2.4, Albert): a pop-up says why, with a button
-- to reload and Cancel. yes picks the dialog with that button text. Changing the main asks the same way.
-- 0.5.4: the pop-up is the shared one (Theme.lua), the same in every Fury addon.
AskReload = function(title, text, yes, onYes, onNo)
    AS.Theme.Confirm(title, text, yes, onYes, onNo)
end

-- Asks to reload the UI so the addons and the base game read what was just copied into their saved data.
local function ReloadSoon(rec, auto)
    if IsUnitInCombat("player") then
        AS.Msg("The addon settings are copied. Type /reloadui after the fight so they load.")
        return
    end
    -- Set before asking, so the report also shows after a /reloadui you type later.
    rec.reloaded = auto and "auto" or "manual"
    AskReload("Fury's Account Sync",
        "The main account's addon settings are copied. They load after a UI reload (a few seconds). Check your addons afterwards: a copy can break one, and \"Undo addon copies\" in the settings puts back what this account had.\n\nReload now? With Cancel they load at your next /reloadui or login. Until then the addons keep their old settings, and changes you make to those addon settings now are not kept.",
        "Reload now",
        function() ReloadUI("ingame") end,
        function() AS.Msg("The copied addon settings load at your next /reloadui or login.") end)
end

local function FinishApply(snap, plan, finished, secondTry, auto)
    local after = AS.Plan(true)
    -- Anything that didn't land gets one more go before it is reported.
    if finished and not secondTry and KeyCount(after) > 0 then
        SendKeybinds(KeyCalls(after), function(done) FinishApply(snap, plan, done, true, auto) end)
        return
    end
    AS.busy = false
    local rec = AS.AccountRecord()
    local left = AS.PlanCount(after)
    local keys = KeyCount(plan)
    local addons, layout = 0, 0
    if finished then
        rec.chars[GetCurrentCharacterId()] = snap.time
        rec.applied = snap.time
        -- Addon settings and window layout go last: they are table copies that a UI reload loads.
        local undo = AS.UndoRecord()
        addons = AS.CopyAddons(plan.addons, undo)
        layout = AS.CopyLayout(plan.layout, undo)
        AS.KeepUndo(undo)
        if SV.what.addons then rec.addonsAt = snap.time end
    end
    rec.last = { time = GetTimeStamp(), char = GetUnitName("player"), settings = #plan.settings, keybinds = keys,
                 chat = plan.chat, addons = addons, layout = layout, left = left, finished = finished }

    local summary = string.format("%d game settings, %d keybinds%s", #plan.settings, keys, plan.chat and ", chat look" or "")
    if addons == 1 then
        summary = summary .. ", settings of 1 addon"
    elseif addons > 1 then
        summary = summary .. ", settings of " .. addons .. " addons"
    end
    if layout > 0 then summary = summary .. ", window layout" end
    rec.last.summary = summary
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    if finished then
        AS.Msg("Copied from " .. snap.by .. ": " .. summary .. ".")
        if left == 1 then
            AS.Msg("1 thing didn't take. Open /fas to see which.")
        elseif left > 1 then
            AS.Msg(left .. " things didn't take. Open /fas to see which.")
        end
        add(C_GOOD .. "Copied from " .. snap.by .. " to " .. GetUnitName("player") .. ": " .. summary .. ".|r")
    else
        AS.Msg("Combat started, so the keybinds stopped part way. Press Apply again after the fight.")
        add(C_WARN .. "Combat started, so the keybinds stopped part way. Press Apply again after the fight.|r")
    end
    if plan.keysMissing > 0 then
        AS.Msg(string.format("%d keybinds belong to addons that aren't turned on here, so they were left out.", plan.keysMissing))
    end
    add("")
    PlanLines(plan, add)
    if left > 0 then
        add("")
        if finished then
            add(C_WARN .. "Still different after copying (" .. left .. "). The game didn't accept these:|r")
        else
            add(C_WARN .. "Still to copy (" .. left .. "):|r")
        end
        PlanLines(after, add)
    end
    add("")
    add(C_MUTED .. "The game keeps settings, keybinds and chat colors per character, so each of this account's " ..
        "characters copies once. With \"Automatically when I log in\" that happens by itself.|r")
    local report = table.concat(lines, "\n")
    if addons + layout > 0 then
        -- the reload clears the window, so the report is kept and shown again afterwards
        rec.report = report
        ReloadSoon(rec, auto)
    end
    AS.RefreshWindow(report)
end

-- auto: called at login, not from the Apply button. Addon settings are then copied once per account
-- for each snapshot, not again for every character.
function AS.Apply(auto)
    local snap = SV.snapshot
    if not snap then
        AS.Msg("There is no snapshot yet. Log in on the main account and take one.")
        return false
    end
    if AS.IsMain() then
        AS.Msg("This is the main account. Apply the snapshot from one of your other accounts.")
        return false
    end
    if AS.OtherSyncActive() then
        AS.Msg(OTHER_SYNC_TEXT)
        return false
    end
    if AS.busy then
        AS.Msg("Still copying. Give it a moment.")
        return false
    end
    local rec = AS.AccountRecord()
    local addonsDone = (rec.addonsAt or 0) >= snap.time
    local plan = AS.Plan(false, auto and addonsDone)
    local keys = KeyCount(plan)
    if keys > 0 and IsUnitInCombat("player") then
        AS.Msg("Keybinds can't be changed in combat. Try again once combat ends.")
        return false
    end
    if AS.PlanCount(plan) == 0 then
        rec.chars[GetCurrentCharacterId()] = snap.time
        rec.applied = snap.time
        if SV.what.addons then rec.addonsAt = snap.time end
        AS.Msg("This character already matches " .. snap.by .. ". Nothing to copy.")
        AS.RefreshWindow()
        return true
    end

    AS.busy = true
    for _, e in ipairs(plan.settings) do
        SetSetting(e.s, e.i, e.v)
    end
    -- The game holds many settings (Auto Loot among them) until its Settings menu closes, and only
    -- then sends them to the server. Without this they looked set but were gone at the next login.
    if #plan.settings > 0 then SendAllCachedSettingMessages() end
    if plan.chat then
        local c = plan.chatData
        for category, rgb in pairs(c.colors or {}) do
            SetChatCategoryColor(category, rgb[1], rgb[2], rgb[3])
        end
        if c.fontSize then KEYBOARD_CHAT_SYSTEM:SetFontSize(c.fontSize) end
        if c.minAlpha then KEYBOARD_CHAT_SYSTEM:SetMinAlpha(c.minAlpha) end
    end

    if keys == 0 then
        FinishApply(snap, plan, true, false, auto)
        return true
    end
    local calls = KeyCalls(plan)
    if #calls > 20 then
        AS.Msg(string.format("Copying %d keybinds a few at a time. This takes about %d seconds.", keys,
            zo_ceil(#calls / KEY_BATCH * KEY_PAUSE_MS / 1000)))
    end
    SendKeybinds(calls, function(finished) FinishApply(snap, plan, finished, false, auto) end)
    return true
end

-- The main account's other characters (0.5.7). The game keeps keybinds per character, so a key set on
-- the main character is missing on the others. This gives the character you're on the main
-- character's keybinds, game and addon keys alike. Only keybinds: nothing else is touched.
-- auto: called at login. Quiet when nothing differs.
function AS.CopyKeysHere(auto)
    local snap = SV.snapshot
    if not AS.IsMain() then
        if not auto then AS.Msg("This works on the main account's characters. Other accounts copy with Apply.") end
        return false
    end
    if not snap then
        if not auto then AS.Msg("There is no snapshot yet. Log in on your main character and press Take snapshot.") end
        return false
    end
    if AS.IsMainChar() then
        if not auto then AS.Msg("This is the main character. The others copy its keybinds.") end
        return false
    end
    if AS.busy then
        if not auto then AS.Msg("Still copying. Give it a moment.") end
        return false
    end
    local rec = AS.AccountRecord()
    local plan = AS.Plan(true, true, true)
    local keys = KeyCount(plan)
    local from = AS.MainCharName() or "the main character"
    if keys == 0 then
        rec.chars[GetCurrentCharacterId()] = snap.time
        if not auto then AS.Msg("This character already has the same keybinds as " .. from .. ".") end
        return true
    end
    if IsUnitInCombat("player") then
        AS.Msg("Keybinds can't be changed in combat. Type /fas keys once combat ends.")
        return false
    end
    AS.busy = true
    local function finish(finished, secondTry)
        local after = AS.Plan(true, true, true)
        if finished and not secondTry and KeyCount(after) > 0 then
            SendKeybinds(KeyCalls(after), function(done) finish(done, true) end)
            return
        end
        AS.busy = false
        if not finished then
            AS.Msg("Combat started, so the keybinds stopped part way. Type /fas keys after the fight.")
            return
        end
        rec.chars[GetCurrentCharacterId()] = snap.time
        AS.Msg(string.format("Copied %d %s from %s.", keys, keys == 1 and "keybind" or "keybinds", from))
        local left = KeyCount(after)
        if left > 0 then
            AS.Msg(string.format("%d %s didn't take. Type /fas keys to try again.", left, left == 1 and "keybind" or "keybinds"))
        end
        if plan.keysMissing > 0 then
            AS.Msg(string.format("%d keybinds belong to addons that aren't turned on here, so they were left out.", plan.keysMissing))
        end
        AS.RefreshWindow()
    end
    SendKeybinds(KeyCalls(plan), function(finished) finish(finished, false) end)
    return true
end

-- Puts back the addon settings and window layout this account had before it copied the main's.
function AS.Undo()
    if AS.busy then
        AS.Msg("Still copying. Give it a moment.")
        return false
    end
    local undo = AS.UndoInfo()
    if not undo then
        AS.Msg("There is nothing to undo on this account. Undo covers copied addon settings and window layout, for a month.")
        return false
    end
    if IsUnitInCombat("player") then
        AS.Msg("Undo reloads the UI, so it waits until you're out of combat.")
        return false
    end
    local since = AS.When(undo.time)
    AskReload("Undo addon copies",
        "Put back the addon settings and window layout this account had before " .. since .. "?\n\nThis reloads the UI (a few seconds).",
        "Undo and reload",
        function()
            AS.UndoAddons()
            local rec = AS.AccountRecord()
            rec.report = nil
            rec.reloaded = "undo"
            ReloadUI("ingame")
        end)
    return true
end

-- Puts back one addon's settings from before the copy, unticks it and reloads, after a pop-up.
function AS.UndoOne(typed)
    if AS.busy then
        AS.Msg("Still copying. Give it a moment.")
        return false
    end
    local name = AS.FindUndoName(typed)
    if not name then
        local names = AS.UndoNames()
        if #names == 0 then
            AS.Msg("There is nothing to undo on this account.")
        else
            AS.Msg("\"" .. zo_strtrim(typed or "") .. "\" isn't one of the addons this account can undo. Those are: " .. table.concat(names, ", ") .. ".")
        end
        return false
    end
    if IsUnitInCombat("player") then
        AS.Msg("Undo reloads the UI, so it waits until you're out of combat.")
        return false
    end
    AskReload("Undo one addon",
        "Put back the settings " .. name .. " had on this account before it copied the main's?\n\nIt is also unticked, so the next Apply leaves it alone. Every other addon stays copied. This reloads the UI (a few seconds).",
        "Undo this addon",
        function()
            AS.UndoOneAddon(name)
            local rec = AS.AccountRecord()
            rec.report = nil
            rec.reloaded = "undoone"
            ReloadUI("ingame")
        end)
    return true
end

-- One line that says what this copy of the addon is set to and how the last copy went, to paste
-- into a comment when something goes wrong. It holds no account or character names.
function AS.ReportLine()
    local rec = AS.AccountRecord()
    local what = SV.what
    local copies = {}
    for _, p in ipairs(AS.PANELS) do
        if what.panels[p.key] then copies[#copies + 1] = p.key end
    end
    if what.keybinds then copies[#copies + 1] = "keybinds" end
    if what.chat then copies[#copies + 1] = "chat" end
    if what.addons then copies[#copies + 1] = "addons" end
    if what.layout then copies[#copies + 1] = "layout" end
    local ticked = {}
    for _, name in ipairs(AS.SortedCopiedNames()) do
        if AS.IsPicked(name) and type(_G[name]) == "table" then ticked[#ticked + 1] = name end
    end
    local last = "none"
    if rec.last then
        last = AS.When(rec.last.time) .. ": " .. tostring(rec.last.summary) .. ", " .. tostring(rec.last.left or 0) .. " left, " ..
            (rec.last.finished and "finished" or "stopped")
    end
    local role = (not SV.main and "no main yet") or (AS.IsMain() and "main") or ("other account, at login " .. tostring(rec.mode))
    return table.concat({
        "Fury's Account Sync " .. AS.version,
        "game " .. tostring(GetAPIVersion()),
        "this account: " .. role,
        "snapshot: " .. (SV.snapshot and AS.When(SV.snapshot.time) or "none"),
        "copies: " .. table.concat(copies, ","),
        "addons ticked and running: " .. (#ticked > 0 and table.concat(ticked, ",") or "none"),
        "can undo: " .. (#AS.UndoNames() > 0 and table.concat(AS.UndoNames(), ",") or "none"),
        "not on the list: " .. (#AS.UnlistedAddons() > 0 and table.concat(AS.UnlistedAddons(), ",") or "none"),
        "other sync addon active: " .. tostring(AS.OtherSyncActive()),
        "last copy: " .. last,
    }, " | ")
end

------------------------------------------------------------------------------
-- Preview text for the window
------------------------------------------------------------------------------
-- How many accounts other than the main have copied a snapshot at least once.
local function AccountsThatCopied()
    local n = 0
    for account, rec in pairs(SV.accounts) do
        if account ~= SV.main and type(rec) == "table" and (rec.applied or 0) > 0 then n = n + 1 end
    end
    return n
end

-- The setup as numbered steps, each marked Done, Next or Later, for as long as it isn't finished.
-- Returns nil once this account has nothing left to set up.
local function StepsText()
    local snap = SV.snapshot
    local isMain = AS.IsMain()
    local copiedHere = (AS.AccountRecord().applied or 0) > 0
    local done1 = SV.main ~= nil
    local done2 = done1 and snap ~= nil
    local done3
    if isMain then done3 = AccountsThatCopied() > 0 else done3 = copiedHere end
    if done1 and done2 and done3 then return nil end

    local nextShown = false
    local function mark(done)
        if done then return C_GOOD .. "Done|r   " end
        if not nextShown then
            nextShown = true
            return C_WARN .. "Next|r   "
        end
        return C_MUTED .. "Later|r  "
    end
    local lines = { C_HEAD .. "Getting started|r", "" }
    local function add(text) lines[#lines + 1] = text end

    add(mark(done1) .. C_TEXT .. "1. Choose your main account|r")
    if done1 then
        add("            " .. C_SUB .. "The main is " .. SV.main .. ". Your other accounts will look like it.|r")
    else
        add("            " .. C_SUB .. "That is the account the others should look like. If you're on it now, press " ..
            "\"Make this account the main\" above. If not, log in on it first and type /fas there.|r")
    end
    add("")
    add(mark(done2) .. C_TEXT .. "2. Take a snapshot on the main|r")
    if done2 then
        add("            " .. C_SUB .. "Taken " .. AS.When(snap.time) .. " on " .. (snap.char or "?") .. ".|r")
    elseif isMain then
        add("            " .. C_SUB .. "Press \"Take snapshot\" above. It saves this account's game settings, keybinds and chat look.|r")
    elseif done1 then
        add("            " .. C_SUB .. "Log in on " .. SV.main .. ", type /fas and press \"Take snapshot\".|r")
    else
        add("            " .. C_SUB .. "It saves the main's game settings, keybinds and chat look.|r")
    end
    add("")
    add(mark(done3) .. C_TEXT .. "3. Copy it on your other accounts|r")
    if isMain then
        add("            " .. C_SUB .. "Log in on another account and type /fas. It lists what would change before anything is copied.|r")
    elseif done2 then
        add("            " .. C_SUB .. "The list below is what would change on this character. Press \"Apply to this character\" to copy it.|r")
    else
        add("            " .. C_SUB .. "On each other account, /fas lists what would change. \"Apply to this character\" copies it.|r")
    end
    add("")
    add(C_MUTED .. "Later on: \"At login\" on each other account can be set to Ask me or Automatic, so changes on the main " ..
        "follow by themselves. Each character copies once, because the game keeps settings per character.|r")
    return table.concat(lines, "\n")
end
AS.StepsText = StepsText

-- On the main: every other account that has logged in with the addon, and where it stands.
function AS.AccountLines(add)
    local snap = SV.snapshot
    local names = {}
    for account in pairs(SV.accounts) do
        if account ~= SV.main then names[#names + 1] = account end
    end
    if #names == 0 then return end
    table.sort(names)
    add(C_HEAD .. "Your other accounts|r " .. C_MUTED .. "(" .. #names .. ")|r")
    for _, account in ipairs(names) do
        local rec = SV.accounts[account]
        local mode = (rec.mode == "auto" and "Automatic") or (rec.mode == "ask" and "Ask me") or "Off"
        local current = 0
        for _, copiedAt in pairs(rec.chars or {}) do
            if copiedAt >= snap.time then current = current + 1 end
        end
        local state
        if (rec.applied or 0) == 0 then
            state = C_MUTED .. "has never copied|r"
        elseif current > 0 then
            state = C_GOOD .. string.format("%d %s this snapshot|r", current, current == 1 and "character has" or "characters have")
        else
            state = C_WARN .. "behind: last copied the snapshot of " .. AS.When(rec.applied) .. "|r"
        end
        add("  " .. C_TEXT .. account .. "|r  " .. state .. C_MUTED .. "  -  at login: " .. mode .. "|r")
    end
    add(C_MUTED .. "A character catches up the next time it logs in, if At login is Ask me or Automatic on its account.|r")
    add("")
end

-- On the main: what differs between this character and the snapshot, so it is plain when the
-- snapshot is out of date.
local function MainChangeLines(add)
    local plan = AS.Plan(true)
    local keys = #plan.bind + #plan.unbind
    local count = #plan.settings + keys + (plan.chat and 1 or 0)
    if count == 0 then
        add(C_GOOD .. "The snapshot is up to date with this character.|r")
        return
    end
    add(C_WARN .. string.format("%d %s changed since the snapshot. Press Take snapshot so your other accounts get %s.|r",
        count, count == 1 and "thing has" or "things have", count == 1 and "it" or "them"))
    local shown = 0
    for _, e in ipairs(plan.settings) do
        if shown < 30 then
            local name = (e.t ~= "" and e.t) or ("Setting " .. e.s .. "/" .. e.i)
            add("  " .. C_TEXT .. e.page .. ": " .. name .. "|r  " .. C_MUTED .. ValueText(e.s, e.i, e.v) .. " > |r" ..
                C_TEXT .. ValueText(e.s, e.i, e.old) .. "|r")
        end
        shown = shown + 1
    end
    for _, list in ipairs({ plan.bind, plan.unbind }) do
        for _, e in ipairs(list) do
            if shown < 30 then add("  " .. C_TEXT .. "Keybind: " .. KeyLabel(e) .. "|r") end
            shown = shown + 1
        end
    end
    if plan.chat then
        if shown < 30 then add("  " .. C_TEXT .. "Chat colors, text size or fade|r") end
        shown = shown + 1
    end
    if shown > 30 then add("  " .. C_MUTED .. "and " .. (shown - 30) .. " more|r") end
    add(C_MUTED .. "The game keeps these per character, so another character of this account can differ from the " ..
        "snapshot without anything having changed.|r")
end

function AS.PreviewText()
    local snap = SV.snapshot
    local steps = StepsText()
    if not SV.main or not snap then
        return steps
    end
    if AS.IsMain() then
        local n = 0
        for _, p in ipairs(AS.PANELS) do n = n + #(snap.settings[p.key] or {}) end
        local lines = {}
        local function add(text) lines[#lines + 1] = text end
        if AS.OtherSyncActive() then
            add(C_WARN .. OTHER_SYNC_MAIN_TEXT .. "|r")
            add("")
        end
        add(C_HEAD .. "This is the main account.|r")
        add("")
        add(C_TEXT .. string.format("The snapshot holds %d game settings, %d keybinds and the chat look, taken %s on %s.",
            n, SnapshotKeyCounts(snap), AS.When(snap.time), snap.char or "?") .. "|r")
        add("")
        MainChangeLines(add)
        add("")
        AS.AccountLines(add)
        add(C_SUB .. "Your other accounts pick up a new snapshot the next time they log in, if \"At login\" is set to " ..
            "Ask me or Automatic there.|r")
        add("")
        add(C_MUTED .. "Addon settings and window layout aren't part of the snapshot. The other accounts read them from this " ..
            "account's saved data, which the game writes when you log out or reload the UI here.|r")
        if steps then
            add("")
            add(C_WARN .. "Next:|r " .. C_TEXT .. "log in on another account and type /fas. It lists what would change there " ..
                "before anything is copied.|r")
        end
        return table.concat(lines, "\n")
    end

    local plan = AS.Plan()
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    if steps then
        add(steps)
        add("")
    end
    if AS.OtherSyncActive() then
        add(C_WARN .. OTHER_SYNC_TEXT .. "|r")
        add("")
    end
    if AS.PlanCount(plan) == 0 then
        add(C_GOOD .. "This character already matches " .. snap.by .. ".|r")
    else
        local count = AS.PlanCount(plan)
        add(C_HEAD .. string.format("Pressing Apply changes %d %s on this character:|r", count, count == 1 and "thing" or "things"))
    end
    add("")
    PlanLines(plan, add)
    if plan.keysMissing > 0 then
        add(C_MUTED .. plan.keysMissing .. " keybinds belong to addons not turned on here and will be left out.|r")
    end
    add("")
    add(C_MUTED .. "Snapshot from " .. snap.by .. " (" .. (snap.char or "?") .. "), taken " .. AS.When(snap.time) ..
        ". This character last copied: " .. AS.When(AS.CopiedHere()) .. ".|r")
    add(C_MUTED .. "The game keeps settings, keybinds and chat colors per character, so each character copies once.|r")
    if #plan.addons > 0 then
        add("|cFF6B86Warning: copying addon settings can break an addon.|r " .. C_WARN .. "Some addons keep things that belong " ..
            "to one account or one character in with their settings. Check your addons after the reload. If one misbehaves, " ..
            "\"Undo addon copies\" in the settings puts back what this account had.|r")
    end
    if ReloadCount(plan) > 0 then
        add(C_WARN .. "Copying addon settings or window layout ends with a UI reload.|r " .. C_MUTED ..
            "What this account had before can be put back for a month with \"Undo addon copies\" in the settings.|r")
    end
    if not SV.what.addons then
        add(C_MUTED .. "Addon settings aren't copied yet. Tick \"Addon settings\" in the settings (gear button) to include them.|r")
    else
        add(C_MUTED .. "Addon settings are copied for addons that are turned on for this account and on this addon's list. " ..
            "The Windows tool covers the rest with the game closed.|r")
        local unticked = 0
        for _, name in ipairs(AS.SortedCopiedNames()) do
            if not AS.IsPicked(name) and type(_G[name]) == "table" then unticked = unticked + 1 end
        end
        if unticked > 0 then
            add(C_MUTED .. string.format("%d more %s on the list and running here, but not ticked. Only a small, well-known set is ticked " ..
                "to begin with. Tick more, one at a time, under \"Which addons\" in the settings.|r", unticked,
                unticked == 1 and "addon is" or "addons are"))
        end
        local skipped = {}
        for _, name in ipairs(AS.UnlistedAddons()) do
            if not SV.extra[name] then skipped[#skipped + 1] = name end
        end
        if #skipped > 0 then
            add("")
            add(C_WARN .. string.format("Not copied: %d running %s on the list.|r", #skipped,
                #skipped == 1 and "addon isn't" or "addons aren't"))
            add("  " .. C_TEXT .. table.concat(skipped, ", ") .. "|r")
            add(C_MUTED .. "These are saved-data names. This addon doesn't know which parts of them are settings and which are " ..
                "data, so it leaves them alone. To copy one anyway, add its name under \"Addons that aren't on the list\" " ..
                "in the settings, or use the Windows tool.|r")
        end
    end
    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Login: offer or apply a newer snapshot
------------------------------------------------------------------------------
local function OnFirstActivation()
    local rec = AS.AccountRecord()
    local firstTime = (rec.seen or 0) == 0
    rec.seen = GetTimeStamp()
    local snap = SV.snapshot
    if AS.IsMain() and AS.OtherSyncActive() then AS.Msg(OTHER_SYNC_MAIN_TEXT) end

    -- One line, the first time an account logs in with this addon: how to open it.
    if firstTime then
        if not SV.main then
            AS.Msg("Welcome! Type /fas to set it up in three steps; its Start here button explains it in one page. Everything starts turned off.")
        elseif not AS.IsMain() and snap then
            AS.Msg(SV.main .. " has a setup this account can copy. Type /fas to see what would change. Nothing is copied until you say so.")
        elseif not AS.IsMain() then
            AS.Msg("Type /fas to see the setup steps. Nothing is copied until you say so.")
        end
    end

    -- This login is the UI reload that followed a copy or an undo: say how it went.
    local reloaded = rec.reloaded
    rec.reloaded = nil
    if reloaded == "undoone" then
        AS.Msg("That addon has its own settings back and is unticked. Tick it again under \"Which addons\" in the settings if you want to try once more.")
        return
    elseif reloaded == "undo" then
        AS.Msg("This account's own addon settings and window layout are back. Untick \"Addon settings\" in " ..
            "the settings if they should stay that way.")
        return
    elseif reloaded then
        local last = rec.last
        if last and last.summary then AS.Msg("Copied from " .. tostring(SV.main) .. ": " .. last.summary .. ".") end
        if reloaded == "manual" and rec.report then
            AS.OpenWindow()
        end
        return
    end

    -- Older installs knew the main character only by name: remember its id once it logs in.
    if AS.IsMain() and not SV.mainChar and snap and snap.char == GetUnitName("player") then SetMainChar() end
    -- The main account's other characters take the main character's keybinds (0.5.7, off by default).
    if AS.IsMain() and SV.mainKeys and snap and not AS.IsMainChar() then
        if AS.OtherSyncActive() then return end
        AS.CopyKeysHere(true)
        return
    end

    if not snap or AS.IsMain() or not SV.main then return end
    if rec.mode == "off" then return end
    -- Game settings are per character; addon settings are per account.
    local charDone = AS.CopiedHere() >= snap.time
    local addonsDone = not SV.what.addons or (rec.addonsAt or 0) >= snap.time
    if charDone and addonsDone then return end
    if AS.OtherSyncActive() then
        AS.Msg(OTHER_SYNC_TEXT)
        return
    end
    local plan = AS.Plan(false, addonsDone)
    if AS.PlanCount(plan) == 0 then
        rec.chars[GetCurrentCharacterId()] = snap.time
        rec.applied = snap.time
        if SV.what.addons then rec.addonsAt = snap.time end
    elseif rec.mode == "auto" then
        AS.Apply(true)
    elseif rec.mode == "ask" then
        AS.OpenWindow("The main account's setup is newer than this character's. Here is what Apply would change.")
    end
end

------------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------------
local function Slash(arg)
    local typed = zo_strtrim(arg or "")
    arg = zo_strlower(typed)
    if arg:sub(1, 5) == "undo " then
        AS.UndoOne(typed:sub(6))
    elseif arg == "report" then
        AS.ShowReportBox()
    elseif arg == "snapshot" then
        AS.TakeSnapshot()
    elseif arg == "apply" then
        AS.Apply()
    elseif arg == "keys" then
        AS.CopyKeysHere()
    elseif arg == "undo" then
        AS.Undo()
    elseif arg == "settings" then
        AS.OpenSettings()
    elseif arg == "start" then
        AS.ShowStart()
    elseif arg == "" then
        AS.ToggleWindow()
    else
        if arg ~= "help" then AS.Msg("\"/fas " .. arg .. "\" isn't a command.") end
        AS.Msg(AS.title .. " v" .. AS.version .. " commands:")
        AS.Msg("/fas  open the window (also on a key: Controls > Keybindings > Fury's Account Sync)")
        AS.Msg("/fas start  the Start here page: how it works, in one page")
        AS.Msg("/fas snapshot  take a snapshot on the main account")
        AS.Msg("/fas apply  copy the main's snapshot to this character")
        AS.Msg("/fas keys  on the main account: give this character the main character's keybinds")
        AS.Msg("/fas undo  put back this account's own addon settings; /fas undo NAME just one addon's")
        AS.Msg("/fas report  make a line to paste into a bug report")
        AS.Msg("/fas settings  open the settings")
    end
end

------------------------------------------------------------------------------
-- Load
------------------------------------------------------------------------------
local function OnLoaded(_, addonName)
    if addonName ~= AS.name then return end
    EVENT_MANAGER:UnregisterForEvent(AS.name, EVENT_ADD_ON_LOADED)

    SV = AS.Theme.SavedVars("FurysAccountSync_SV")
    Merge(SV, Defaults())
    -- 0.1.4 to 0.2.0 had the front and back bar as two choices; they are one again
    if SV.buildParts.front ~= nil or SV.buildParts.back ~= nil then
        SV.buildParts.skills = (SV.buildParts.front == true or SV.buildParts.back == true)
        SV.buildParts.front = nil
        SV.buildParts.back = nil
    end
    -- Before 0.5.0 every listed addon was copied. An install that already copies addon settings
    -- keeps that: every listed addon starts ticked there. New installs start with the starter set.
    if not SV.pickSet then
        SV.pickSet = true
        if SV.what.addons then
            for name in pairs(AS.RULES) do
                if AS.CopyRule(name) then SV.pick[name] = true end
            end
        end
    end
    -- HarvestMap joined the list in 0.5.1. An install that already copies addon settings gets it ticked.
    if not SV.pickHarvest then
        SV.pickHarvest = true
        if SV.what.addons and SV.pick.Harvest_SavedVars == nil then SV.pick.Harvest_SavedVars = true end
    end
    AS.PruneUndo()

    AS.InitWindow()
    AS.InitSettings()

    EVENT_MANAGER:RegisterForEvent(AS.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(AS.name, EVENT_PLAYER_ACTIVATED)
        zo_callLater(OnFirstActivation, 3000)
    end)
    EVENT_MANAGER:RegisterForEvent(AS.name, EVENT_PLAYER_DEACTIVATED, function()
        if SV.autoSnapshot and AS.IsMain() then AS.TakeSnapshot(true, true) end
    end)

    SLASH_COMMANDS["/fas"] = Slash
    SLASH_COMMANDS["/furysync"] = Slash
end

EVENT_MANAGER:RegisterForEvent(AS.name, EVENT_ADD_ON_LOADED, OnLoaded)
