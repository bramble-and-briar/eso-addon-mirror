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
    version     = "0.2.3",
    toolUrl     = "https://github.com/AlbertHoffpauir/FurysAccountSync",
    SCENE       = "FurysAccountSync_Scene",
}
local AS = FurysAccountSync

local TAG = "|cA08CFF[Account Sync]|r "

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
        version      = 1,
        main         = nil,     -- "@Account" that snapshots come from
        snapshot     = nil,     -- the main's setup, see AS.TakeSnapshot
        accounts     = {},      -- ["@Account"] = { mode = "off" | "ask" | "auto", applied = time, seen = time,
                                --                  chars = { [characterId] = snapshot time copied }, last = {...},
                                --                  addonsAt = snapshot time addon settings were copied for }
        undo         = {},      -- ["@Account"] = the addon settings the account had before copying, see AddonCopy.lua
        builds       = {},      -- ["Build name"] = build, see Builds.lua
        what         = {        -- what an alt takes from the snapshot
            keybinds = true,
            chat     = true,
            addons   = false,   -- settings of the addons listed in Rules.lua (ends with a UI reload)
            layout   = false,   -- base game chat window, meters and quest tracker (ends with a UI reload)
            panels   = { gameplay = true, camera = true, interface = true, nameplates = true,
                         social = true, combat = true, accessibility = true },
        },
        autoSnapshot = false,   -- main takes a fresh snapshot at every logout, reload and zone change
        builds_on    = false,   -- Character builds section
        buildParts   = { skills = true, cp = true, quick = true },   -- what Load build puts on the character
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
    CHAT_ROUTER:AddSystemMessage(TAG .. text)
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
                        fn(s, i, TextOf(data.text))
                    end
                end
            end
        end
    end
end

local function Captureable(value)
    return value ~= nil and value ~= ""
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
-- Snapshot (main account only)
------------------------------------------------------------------------------
function AS.TakeSnapshot(quiet)
    if not AS.IsMain() then
        if not quiet then AS.Msg("Only the main account takes snapshots. Make this account the main in the settings first.") end
        return false
    end
    local actions, binds = ReadKeybinds()
    local snap = {
        by       = GetDisplayName(),
        char     = GetUnitName("player"),
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
        AS.Msg(string.format("Snapshot taken: %d game settings, %d keybinds, chat look.", count, #binds))
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
function AS.Plan(gameOnly, skipAddons)
    local snap = SV.snapshot
    local plan = { settings = {}, unbind = {}, bind = {}, steal = {}, keysMissing = 0, chat = false, addons = {}, layout = {} }
    if not snap then return plan end
    local what = SV.what
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
            add("  " .. C_TEXT .. name .. "|r  " .. C_MUTED .. tostring(e.old) .. " > |r" .. C_TEXT .. tostring(e.v) .. "|r")
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

-- Reloads the UI so the addons and the base game read what was just copied into their saved data.
local RELOAD_SECONDS = 3

local function ReloadSoon(rec, auto)
    if IsUnitInCombat("player") then
        AS.Msg("The addon settings are copied. Type /reloadui after the fight so they load.")
        return
    end
    rec.reloaded = auto and "auto" or "manual"
    AS.Msg("Reloading the UI in " .. RELOAD_SECONDS .. " seconds so the copied addon settings load.")
    zo_callLater(function() ReloadUI("ingame") end, RELOAD_SECONDS * 1000)
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
    AS.UndoAddons()
    local rec = AS.AccountRecord()
    rec.report = nil
    rec.reloaded = "undo"
    AS.Msg("Putting back the addon settings and window layout this account had before " .. since ..
        ". Reloading the UI in " .. RELOAD_SECONDS .. " seconds.")
    zo_callLater(function() ReloadUI("ingame") end, RELOAD_SECONDS * 1000)
    return true
end

------------------------------------------------------------------------------
-- Preview text for the window
------------------------------------------------------------------------------
function AS.PreviewText()
    local snap = SV.snapshot
    if not SV.main then
        return C_WARN .. "No main account yet.|r\n\n" .. C_SUB ..
            "Log in on the account the others should copy, open the settings (gear button) and press " ..
            "\"Make this account the main\". Then take a snapshot.|r"
    end
    if not snap then
        return C_WARN .. "No snapshot yet.|r\n\n" .. C_SUB .. "Log in on " .. SV.main .. " and press Take snapshot.|r"
    end
    if AS.IsMain() then
        local n = 0
        for _, p in ipairs(AS.PANELS) do n = n + #(snap.settings[p.key] or {}) end
        local warning = ""
        if AS.OtherSyncActive() then warning = C_WARN .. OTHER_SYNC_MAIN_TEXT .. "|r\n\n" end
        return warning .. C_HEAD .. "This is the main account.|r\n\n" .. C_TEXT ..
            string.format("The snapshot holds %d game settings, %d keybinds and the chat look, taken %s on %s.",
                n, SnapshotKeyCounts(snap), AS.When(snap.time), snap.char or "?") .. "|r\n\n" .. C_SUB ..
            "Take a new snapshot after you change anything. Your other accounts pick it up the next time they log in, " ..
            "if \"Copy the main's setup\" is turned on in their settings.|r\n\n" .. C_MUTED ..
            "Addon settings and window layout aren't part of the snapshot. The other accounts read them from this " ..
            "account's saved data, which the game writes when you log out or reload the UI here.|r"
    end

    local plan = AS.Plan()
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    if AS.OtherSyncActive() then
        add(C_WARN .. OTHER_SYNC_TEXT .. "|r")
        add("")
    end
    if AS.PlanCount(plan) == 0 then
        add(C_GOOD .. "This character already matches " .. snap.by .. ".|r")
    else
        add(C_HEAD .. string.format("Pressing Apply changes %d things on this character:|r", AS.PlanCount(plan)))
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
    if ReloadCount(plan) > 0 then
        add(C_WARN .. "Copying addon settings or window layout ends with a UI reload.|r " .. C_MUTED ..
            "What this account had before can be put back for a month with \"Undo addon copies\" in the settings.|r")
    end
    if not SV.what.addons then
        add(C_MUTED .. "Addon settings aren't copied yet. Tick \"Addon settings\" in the settings (gear button) to include them.|r")
    else
        add(C_MUTED .. "Addon settings are copied for addons that are turned on for this account and on this addon's list. " ..
            "The Windows tool covers the rest with the game closed.|r")
    end
    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Login: offer or apply a newer snapshot
------------------------------------------------------------------------------
local function OnFirstActivation()
    local rec = AS.AccountRecord()
    rec.seen = GetTimeStamp()
    local snap = SV.snapshot
    if AS.IsMain() and AS.OtherSyncActive() then AS.Msg(OTHER_SYNC_MAIN_TEXT) end

    -- This login is the UI reload that followed a copy or an undo: say how it went.
    local reloaded = rec.reloaded
    rec.reloaded = nil
    if reloaded == "undo" then
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
    arg = zo_strlower(zo_strtrim(arg or ""))
    if arg == "snapshot" then
        AS.TakeSnapshot()
    elseif arg == "apply" then
        AS.Apply()
    elseif arg == "undo" then
        AS.Undo()
    elseif arg == "settings" then
        AS.OpenSettings()
    else
        AS.ToggleWindow()
    end
end

------------------------------------------------------------------------------
-- Load
------------------------------------------------------------------------------
local function OnLoaded(_, addonName)
    if addonName ~= AS.name then return end
    EVENT_MANAGER:UnregisterForEvent(AS.name, EVENT_ADD_ON_LOADED)

    FurysAccountSync_SV = FurysAccountSync_SV or {}
    SV = FurysAccountSync_SV
    Merge(SV, Defaults())
    -- 0.1.4 to 0.2.0 had the front and back bar as two choices; they are one again
    if SV.buildParts.front ~= nil or SV.buildParts.back ~= nil then
        SV.buildParts.skills = (SV.buildParts.front == true or SV.buildParts.back == true)
        SV.buildParts.front = nil
        SV.buildParts.back = nil
    end
    AS.PruneUndo()

    AS.InitWindow()
    AS.InitSettings()

    EVENT_MANAGER:RegisterForEvent(AS.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(AS.name, EVENT_PLAYER_ACTIVATED)
        zo_callLater(OnFirstActivation, 3000)
    end)
    EVENT_MANAGER:RegisterForEvent(AS.name, EVENT_PLAYER_DEACTIVATED, function()
        if SV.autoSnapshot and AS.IsMain() then AS.TakeSnapshot(true) end
    end)

    SLASH_COMMANDS["/fas"] = Slash
    SLASH_COMMANDS["/furysync"] = Slash
end

EVENT_MANAGER:RegisterForEvent(AS.name, EVENT_ADD_ON_LOADED, OnLoaded)
