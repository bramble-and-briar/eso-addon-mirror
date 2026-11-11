-- -----------------------------------------------------------------------------
-- PvPCooldownTracker - ProcCapture.lua
--
-- Records the procs that recently went off on the player and lets the player
-- turn any of them into a tracked cooldown from the settings menu - no ability
-- IDs or result codes to look up.
--
--   1. A lightweight EVENT_COMBAT_EVENT listener (filtered to the player and to
--      a handful of result codes) keeps a short list of recently seen procs,
--      including how often each fired and the shortest gap between two procs.
--   2. "Add a Proc" in the settings lists them. The player picks one, sets the
--      cooldown, and presses "Track This Proc".
--   3. The proc is stored as a custom catalog entry flagged `userProc`, which is
--      tracked all the time (it is not tied to equipped gear) and survives
--      reloads through savedVars.customSetData.
-- -----------------------------------------------------------------------------
PvPCooldownTracker = PvPCooldownTracker or {}
PvPCooldownTracker.ProcCapture = {}

local PCT = PvPCooldownTracker
local Capture = PvPCooldownTracker.ProcCapture
local EM = EVENT_MANAGER

local MAX_RECORDS = 40          -- how many distinct procs to remember
local BURST_WINDOW_MS = 1000    -- events closer together than this are one proc
local DEFAULT_COOLDOWN_SEC = 15
local MIN_COOLDOWN_SEC = 1
local MAX_COOLDOWN_SEC = 300

local RECENT_DROPDOWN = "PvPCooldownTracker_RecentProcDropdown"
local ADDED_DROPDOWN = "PvPCooldownTracker_AddedProcDropdown"

local NO_SELECTION = 0
local NO_ADDED = ""

local MODE_STANDARD = "standard"
local MODE_EXTENDED = "extended"

-- Result codes listened to per capture mode.
local function BuildResultList(...)
    local list = {}
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil then
            list[#list + 1] = value
        end
    end
    return list
end

local CAPTURE_RESULTS = {
    [MODE_STANDARD] = BuildResultList(
        ACTION_RESULT_EFFECT_GAINED,
        ACTION_RESULT_EFFECT_GAINED_DURATION),
    [MODE_EXTENDED] = BuildResultList(
        ACTION_RESULT_EFFECT_GAINED,
        ACTION_RESULT_EFFECT_GAINED_DURATION,
        ACTION_RESULT_DAMAGE,
        ACTION_RESULT_CRITICAL_DAMAGE,
        ACTION_RESULT_HEAL,
        ACTION_RESULT_CRITICAL_HEAL,
        ACTION_RESULT_POWER_ENERGIZE),
}

-- When one ability reports several results, track the most reliable one.
local RESULT_PRIORITY = {}
do
    local ordered = BuildResultList(
        ACTION_RESULT_EFFECT_GAINED,
        ACTION_RESULT_EFFECT_GAINED_DURATION,
        ACTION_RESULT_POWER_ENERGIZE,
        ACTION_RESULT_HEAL,
        ACTION_RESULT_DAMAGE)
    for rank, result in ipairs(ordered) do
        RESULT_PRIORITY[result] = rank
    end
end

local RESULT_NAMES = {}
if ACTION_RESULT_EFFECT_GAINED ~= nil then RESULT_NAMES[ACTION_RESULT_EFFECT_GAINED] = "buff / effect" end
if ACTION_RESULT_EFFECT_GAINED_DURATION ~= nil then RESULT_NAMES[ACTION_RESULT_EFFECT_GAINED_DURATION] = "timed effect" end
if ACTION_RESULT_POWER_ENERGIZE ~= nil then RESULT_NAMES[ACTION_RESULT_POWER_ENERGIZE] = "resource restore" end
if ACTION_RESULT_HEAL ~= nil then RESULT_NAMES[ACTION_RESULT_HEAL] = "heal" end
if ACTION_RESULT_DAMAGE ~= nil then RESULT_NAMES[ACTION_RESULT_DAMAGE] = "damage" end

-- [abilityId] = { id, name, icon, result, count, firstMs, lastMs, minGapMs }
local records = {}
local recordCount = 0
local registeredResults = {}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
local function GetSavedVars()
    if PCT.Settings and type(PCT.Settings.EnsureState) == "function" then
        return PCT.Settings.EnsureState()
    end
    return PCT.savedVars or {}
end

local function IsStateContainer(value)
    if type(PCT.IsStateContainer) == "function" then
        return PCT.IsStateContainer(value)
    end
    local t = type(value)
    return value ~= nil and (t == "table" or t == "userdata")
end

local function Trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function CleanName(name)
    if type(name) ~= "string" or name == "" then return "" end
    return Trim(zo_strformat("<<1>>", name))
end

local function GetCatalog()
    return (PCT.Data and PCT.Data.Sets) or {}
end

local function EventName(result)
    return (PCT.name or "PvPCooldownTracker") .. "_Capture_" .. tostring(result)
end

local function NormalizeResult(result)
    local equivalent = PCT.Tracking and PCT.Tracking.RESULT_EQUIVALENT
    return (equivalent and equivalent[result]) or result
end

local function IsIgnored(abilityId)
    local ignored = PCT.Tracking and PCT.Tracking.IGNORE_ABILITY_IDS
    return ignored ~= nil and ignored[abilityId] == true
end

local function RoundToHalf(seconds)
    return math.floor(seconds * 2 + 0.5) / 2
end

local function ClampCooldown(seconds)
    seconds = tonumber(seconds) or DEFAULT_COOLDOWN_SEC
    return math.max(MIN_COOLDOWN_SEC, math.min(MAX_COOLDOWN_SEC, seconds))
end

-- Returns the catalog key that already tracks this ability ID, if any.
function Capture.FindTrackedKey(abilityId)
    abilityId = tonumber(abilityId)
    if abilityId == nil then return nil end

    for key, set in pairs(GetCatalog()) do
        if type(set) == "table" then
            if type(set.id) == "table" then
                for i = 1, #set.id do
                    if tonumber(set.id[i]) == abilityId then return key end
                end
            elseif tonumber(set.id) == abilityId then
                return key
            end
        end
    end

    return nil
end

-- -----------------------------------------------------------------------------
-- Recorder
-- -----------------------------------------------------------------------------
local function EvictOldest()
    local oldestId, oldestMs = nil, nil
    for id, rec in pairs(records) do
        if oldestMs == nil or rec.lastMs < oldestMs then
            oldestId, oldestMs = id, rec.lastMs
        end
    end
    if oldestId ~= nil then
        records[oldestId] = nil
        recordCount = recordCount - 1
    end
end

local function Record(abilityId, abilityName, result)
    abilityId = tonumber(abilityId)
    if abilityId == nil or abilityId <= 0 or IsIgnored(abilityId) then return end

    local now = GetGameTimeMilliseconds()
    result = NormalizeResult(result)

    local rec = records[abilityId]
    if rec == nil then
        local name = CleanName(abilityName)
        if name == "" then
            name = CleanName(GetAbilityName(abilityId))
        end
        -- Nameless abilities are internal helper effects; nothing a player could pick.
        if name == "" then return end

        if recordCount >= MAX_RECORDS then
            EvictOldest()
        end

        records[abilityId] = {
            id      = abilityId,
            name    = name,
            icon    = GetAbilityIcon(abilityId),
            result  = result,
            count   = 1,
            firstMs = now,
            lastMs  = now,
        }
        recordCount = recordCount + 1
        if type(Capture.onNewRecord) == "function" then
            Capture.onNewRecord(records[abilityId])
        end
        return
    end

    local gap = now - rec.lastMs
    if gap >= BURST_WINDOW_MS then
        rec.count = rec.count + 1
        if rec.minGapMs == nil or gap < rec.minGapMs then
            rec.minGapMs = gap
        end
    end
    rec.lastMs = now

    local newRank = RESULT_PRIORITY[result] or 99
    local oldRank = RESULT_PRIORITY[rec.result] or 99
    if newRank < oldRank then
        rec.result = result
    end
end

local function OnCaptureEvent(_, result, isError, abilityName, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    if isError then return end
    Record(abilityId, abilityName, result)
end

-- Exposed so the recorder can be fed directly (tests, other modules).
Capture.Record = Record

local function GetMode()
    local mode = GetSavedVars().procCaptureMode
    if mode == MODE_EXTENDED then return MODE_EXTENDED end
    return MODE_STANDARD
end

function Capture.Stop()
    for result in pairs(registeredResults) do
        EM:UnregisterForEvent(EventName(result), EVENT_COMBAT_EVENT)
        registeredResults[result] = nil
    end
end

function Capture.Start()
    Capture.Stop()
    for _, result in ipairs(CAPTURE_RESULTS[GetMode()]) do
        local name = EventName(result)
        EM:RegisterForEvent(name, EVENT_COMBAT_EVENT, OnCaptureEvent)
        EM:AddFilterForEvent(name, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_COMBAT_RESULT, result)
        registeredResults[result] = true
    end
end

function Capture.IsEnabled()
    return GetSavedVars().procCapture ~= false
end

function Capture.SetEnabled(enabled)
    GetSavedVars().procCapture = enabled == true
    if enabled then
        Capture.Start()
    else
        Capture.Stop()
    end
end

function Capture.GetMode()
    return GetMode()
end

function Capture.SetMode(mode)
    GetSavedVars().procCaptureMode = (mode == MODE_EXTENDED) and MODE_EXTENDED or MODE_STANDARD
    if Capture.IsEnabled() then
        Capture.Start()
    end
end

function Capture.Init()
    if Capture.IsEnabled() then
        Capture.Start()
    end
end

function Capture.Clear()
    records = {}
    recordCount = 0
end

function Capture.GetRecord(abilityId)
    return records[tonumber(abilityId) or -1]
end

-- Most recent first.
function Capture.GetRecent()
    local list = {}
    for _, rec in pairs(records) do
        list[#list + 1] = rec
    end
    table.sort(list, function(a, b)
        if a.lastMs ~= b.lastMs then return a.lastMs > b.lastMs end
        return a.id < b.id
    end)
    return list
end

-- Best guess for the cooldown: the shortest gap seen between two procs. The
-- real cooldown can only be equal or shorter, so it is a safe starting point.
function Capture.SuggestCooldownSeconds(rec)
    if type(rec) == "table" and tonumber(rec.minGapMs) then
        return ClampCooldown(RoundToHalf(rec.minGapMs / 1000)), true
    end
    return DEFAULT_COOLDOWN_SEC, false
end

function Capture.DescribeRecord(rec)
    if type(rec) ~= "table" then return "" end
    local parts = { string.format("%s (%d)", rec.name, rec.id), string.format("seen %dx", rec.count) }
    if rec.minGapMs then
        parts[#parts + 1] = string.format("shortest gap %.1fs", rec.minGapMs / 1000)
    end
    local trackedKey = Capture.FindTrackedKey(rec.id)
    if trackedKey then
        parts[#parts + 1] = string.format("already tracked as '%s'", trackedKey)
    end
    return table.concat(parts, " - ")
end

-- -----------------------------------------------------------------------------
-- Player-added procs
-- -----------------------------------------------------------------------------
function Capture.GetUserProcKeys()
    local keys = {}
    for key, set in pairs(GetCatalog()) do
        if type(set) == "table" and set.userProc == true then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return string.lower(a) < string.lower(b) end)
    return keys
end

-- Called once at startup: user procs are tracked no matter what is equipped.
function Capture.EnableUserProcs()
    local tracking = PCT.Tracking
    if not (tracking and type(tracking.EnableTrackingForSet) == "function") then return 0 end

    local count = 0
    for _, key in ipairs(Capture.GetUserProcKeys()) do
        local disabled = PCT.character
            and IsStateContainer(PCT.character.set)
            and PCT.character.set[key] == false
        if not disabled then
            tracking.EnableTrackingForSet(key, true)
            count = count + 1
        end
    end
    return count
end

-- Adds a tracked cooldown for an ability.
--   abilityId   (number)  ability that fires when the proc goes off
--   displayName (string?) name shown on the tracker; defaults to the ability name
--   cooldownSec (number)  cooldown in seconds
-- Returns ok (bool), message (string), setKey (string?)
function Capture.AddProc(abilityId, displayName, cooldownSec)
    abilityId = tonumber(abilityId)
    if abilityId == nil or abilityId <= 0 then
        return false, "Pick a proc from the list first."
    end
    abilityId = math.floor(abilityId)

    local editor = PCT.EquippedSets
    if not (editor and type(editor.SaveSetData) == "function") then
        return false, "Set editor is not available."
    end

    local trackedKey = Capture.FindTrackedKey(abilityId)
    if trackedKey then
        return false, string.format("That proc is already tracked as '%s'. Adjust it under Tracked Cooldowns.", trackedKey)
    end

    local seconds = tonumber(cooldownSec)
    if seconds == nil or seconds <= 0 then
        return false, "Cooldown must be greater than 0 seconds."
    end
    local cooldownMs = math.floor(seconds * 1000 + 0.5)

    local rec = records[abilityId]
    local name = Trim(displayName)
    if name == "" then
        name = (rec and rec.name) or CleanName(GetAbilityName(abilityId))
    end
    if name == "" then
        name = "Proc " .. tostring(abilityId)
    end

    -- Tracker names are catalog keys, so they have to be unique.
    local catalog = GetCatalog()
    if catalog[name] ~= nil then
        name = string.format("%s (%d)", name, abilityId)
        if catalog[name] ~= nil then
            return false, string.format("A tracker named '%s' already exists. Choose another name.", name)
        end
    end

    local result = (rec and rec.result) or ACTION_RESULT_EFFECT_GAINED
    local icon = (rec and rec.icon) or GetAbilityIcon(abilityId) or ""

    local ok, message = editor.SaveSetData({
        originalSetName = name,
        setName         = name,
        abilityIds      = tostring(abilityId),
        cooldownMs      = tostring(cooldownMs),
        timeOfProcMs    = "0",
        resultCode      = tostring(result),
        eventCode       = tostring(EVENT_COMBAT_EVENT),
        texture         = icon,
        description     = string.format("Added by you from recent procs (ability %d).", abilityId),
        settingsColor   = "3A97CF",
        showFrame       = true,
        userProc        = true,
    })
    if not ok then
        return false, message
    end

    -- Give the new tracker its own spot instead of stacking it on the others.
    local saved = PCT.Settings and PCT.Settings.EnsureSetSavedVars and PCT.Settings.EnsureSetSavedVars(name)
    if saved and PCT.UI and type(PCT.UI.GetNextFreePosition) == "function" then
        saved.x, saved.y = PCT.UI.GetNextFreePosition(name)
    end

    if PCT.character == nil then PCT.character = {} end
    if not IsStateContainer(PCT.character.set) then PCT.character.set = {} end
    PCT.character.set[name] = true

    if PCT.Tracking and type(PCT.Tracking.EnableTrackingForSet) == "function" then
        PCT.Tracking.EnableTrackingForSet(name, true)
    end
    if PCT.UI then
        PCT.UI.Draw(name)
        PCT.UI:SetCombatStateDisplay()
    end

    return true, string.format("Now tracking '%s' with a %.1fs cooldown.", name, cooldownMs / 1000), name
end

-- Removes a player-added proc completely. Built-in catalog sets are left alone.
function Capture.RemoveProc(setKey)
    local catalog = GetCatalog()
    local set = catalog[setKey]
    if type(set) ~= "table" then
        return false, "Pick one of your added procs first."
    end
    if set.userProc ~= true then
        return false, string.format("'%s' is a built-in set and cannot be removed. Disable it under Tracked Cooldowns instead.", setKey)
    end

    -- Flag as manually disabled first so the tracking code really lets go of it.
    if PCT.character and IsStateContainer(PCT.character.set) then
        PCT.character.set[setKey] = false
    end
    if PCT.Tracking and type(PCT.Tracking.EnableTrackingForSet) == "function" then
        PCT.Tracking.EnableTrackingForSet(setKey, false)
    end
    set.enabled = false
    set.onCooldown = false
    EM:UnregisterForUpdate((PCT.name or "PvPCooldownTracker") .. setKey .. "Count")

    catalog[setKey] = nil
    if PCT.UI then
        PCT.UI.Draw(setKey) -- hides the tracker now that the entry is gone
    end

    local savedVars = GetSavedVars()
    if IsStateContainer(savedVars.customSetData) then savedVars.customSetData[setKey] = nil end
    if IsStateContainer(savedVars.sets) then savedVars.sets[setKey] = nil end
    if savedVars.lastSelectedSet == setKey then savedVars.lastSelectedSet = nil end
    if PCT.character and IsStateContainer(PCT.character.set) then
        PCT.character.set[setKey] = nil
    end

    local defaults = PCT.Defaults and PCT.Defaults.Get and PCT.Defaults.Get()
    if type(defaults) == "table" and type(defaults.sets) == "table" then
        defaults.sets[setKey] = nil
    end

    return true, string.format("Removed '%s'.", setKey)
end

-- -----------------------------------------------------------------------------
-- Settings menu (LibAddonMenu controls)
-- -----------------------------------------------------------------------------
local function PushChoices(reference, choices, values, tooltips, quiet)
    if PCT.Settings and type(PCT.Settings.PushDropdownChoices) == "function" then
        PCT.Settings.PushDropdownChoices(reference, choices, values, tooltips, quiet)
    end
end

local function ReplaceList(target, source)
    for i = #target, 1, -1 do target[i] = nil end
    for i = 1, #source do target[i] = source[i] end
end

function Capture.BuildLAMControls()
    local recentChoices, recentValues, recentTooltips = {}, {}, {}
    local addedChoices = {}
    local selectedId = NO_SELECTION
    local selectedAdded = NO_ADDED
    local draft = {
        name = "",
        cooldownSec = DEFAULT_COOLDOWN_SEC,
        status = "Fight until the proc you want goes off, then pick it from the list.",
    }

    local function SelectRecord(abilityId)
        selectedId = tonumber(abilityId) or NO_SELECTION
        local rec = records[selectedId]
        if rec == nil then
            selectedId = NO_SELECTION
            draft.name = ""
            return
        end
        draft.name = rec.name
        draft.cooldownSec = Capture.SuggestCooldownSeconds(rec)
    end

    local function RefreshRecent(quiet)
        local recent = Capture.GetRecent()
        local choices, values, tooltips = {}, {}, {}

        if #recent == 0 then
            choices[1] = "-- No procs recorded yet --"
            values[1] = NO_SELECTION
            tooltips[1] = "Procs show up here a moment after they go off in combat."
        else
            choices[1] = "-- Pick a proc --"
            values[1] = NO_SELECTION
            tooltips[1] = "Most recent procs are listed first."
            local nameCount = {}
            for _, rec in ipairs(recent) do
                nameCount[rec.name] = (nameCount[rec.name] or 0) + 1
            end
            for _, rec in ipairs(recent) do
                local tracked = Capture.FindTrackedKey(rec.id)
                -- Different abilities can share a name; show the ID to tell them apart.
                local label = nameCount[rec.name] > 1 and string.format("%s (%d)", rec.name, rec.id) or rec.name
                choices[#choices + 1] = label .. (tracked and "  [tracked]" or "")
                values[#values + 1] = rec.id
                tooltips[#tooltips + 1] = Capture.DescribeRecord(rec)
            end
        end

        ReplaceList(recentChoices, choices)
        ReplaceList(recentValues, values)
        ReplaceList(recentTooltips, tooltips)

        if records[selectedId] == nil then
            selectedId = NO_SELECTION
        end

        PushChoices(RECENT_DROPDOWN, recentChoices, recentValues, recentTooltips, quiet)
    end

    -- Keep the list current as new procs are seen, so it is already filled in
    -- when the menu is opened (the console menu has no "panel opened" signal).
    Capture.onNewRecord = function() RefreshRecent(true) end

    local function RefreshAdded(preferred)
        local keys = Capture.GetUserProcKeys()
        if #keys == 0 then
            keys = { NO_ADDED }
        end
        ReplaceList(addedChoices, keys)

        if preferred ~= nil and GetCatalog()[preferred] ~= nil then
            selectedAdded = preferred
        elseif GetCatalog()[selectedAdded] == nil then
            selectedAdded = addedChoices[1] or NO_ADDED
        end

        PushChoices(ADDED_DROPDOWN, addedChoices)
    end

    local function RefreshTrackedMenu(preferred)
        if PCT.Settings and type(PCT.Settings.RefreshSetChoices) == "function" then
            PCT.Settings.RefreshSetChoices(preferred)
        end
    end

    local function GetDetailsText()
        local rec = records[selectedId]
        if rec == nil then
            return "|c9A9A9ANo proc selected.|r"
        end

        local lines = {}
        local icon = (type(rec.icon) == "string" and rec.icon ~= "") and string.format("|t36:36:%s|t  ", rec.icon) or ""
        lines[#lines + 1] = string.format("%s|cFFD27F%s|r", icon, rec.name)
        lines[#lines + 1] = string.format("Ability ID %d  -  %s  -  seen %d time%s",
            rec.id, RESULT_NAMES[rec.result] or ("result " .. tostring(rec.result)),
            rec.count, rec.count == 1 and "" or "s")

        local _, measured = Capture.SuggestCooldownSeconds(rec)
        if measured then
            lines[#lines + 1] = string.format(
                "|c7EC87EShortest time between two procs: %.1fs.|r The cooldown below was filled in from that - lower it if the tooltip says it is shorter.",
                rec.minGapMs / 1000)
        else
            lines[#lines + 1] = "|cC8B27ESeen only once so far, so the cooldown is a guess.|r Set it to the cooldown from the set or skill tooltip."
        end

        local tracked = Capture.FindTrackedKey(rec.id)
        if tracked then
            lines[#lines + 1] = string.format("|cFF8060Already tracked as '%s'.|r", tracked)
        end

        return table.concat(lines, "\n")
    end

    local function TrackSelected()
        local ok, message, key = Capture.AddProc(selectedId, draft.name, draft.cooldownSec)
        draft.status = (ok and "|c7EC87E" or "|cFF8060") .. tostring(message) .. "|r"
        d((PCT.prefix or "[PvPCooldownTracker] ") .. tostring(message))
        if ok then
            RefreshAdded(key)
            RefreshTrackedMenu(key)
            RefreshRecent()
        end
    end

    local function RemoveSelected()
        local ok, message = Capture.RemoveProc(selectedAdded)
        draft.status = (ok and "|c7EC87E" or "|cFF8060") .. tostring(message) .. "|r"
        d((PCT.prefix or "[PvPCooldownTracker] ") .. tostring(message))
        if ok then
            RefreshAdded()
            RefreshTrackedMenu()
            RefreshRecent()
        end
    end

    RefreshRecent()
    RefreshAdded()

    -- Keep the list fresh every time the settings panel is opened.
    if CALLBACK_MANAGER ~= nil then
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
            if PCT.Settings and panel ~= nil and panel == PCT.Settings.panel then
                RefreshRecent()
                RefreshAdded()
            end
        end)
    end

    local function NothingSelected()
        return records[selectedId] == nil
    end

    return {
        {
            type  = "description",
            text  = "Saw something proc that is not being tracked? The addon keeps a list of what recently went off on you.\n\n"
                .. "|cFFD27F1.|r Let the proc go off in combat.\n"
                .. "|cFFD27F2.|r Pick it from |cFFFFFFRecent Procs|r below.\n"
                .. "|cFFD27F3.|r Set its cooldown and press |cFFFFFFTrack This Proc|r.",
            width = "full",
        },
        {
            type    = "checkbox",
            name    = "Record Recent Procs",
            tooltip = "Keeps a short list of the procs that recently went off on you. Turn OFF if you never add your own procs.",
            getFunc = function() return Capture.IsEnabled() end,
            setFunc = function(value) Capture.SetEnabled(value) end,
            width   = "full",
        },
        {
            type          = "dropdown",
            name          = "What To Record",
            tooltip       = "Buffs & effects catches most set and skill procs. Switch to Everything if the proc you want only deals damage, heals, or restores resources - that list is much noisier.",
            choices       = { "Buffs & effects (recommended)", "Everything (damage, heals, resources)" },
            choicesValues = { MODE_STANDARD, MODE_EXTENDED },
            getFunc       = function() return Capture.GetMode() end,
            setFunc       = function(value) Capture.SetMode(value) end,
            width         = "full",
            disabled      = function() return not Capture.IsEnabled() end,
        },
        {
            type            = "dropdown",
            name            = "Recent Procs",
            tooltip         = "Procs that recently went off, newest first. Press Refresh List if the one you want is missing.",
            choices         = recentChoices,
            choicesValues   = recentValues,
            choicesTooltips = recentTooltips,
            getFunc         = function() return selectedId end,
            setFunc         = function(value) SelectRecord(value) end,
            scrollable      = true,
            width           = "full",
            reference       = RECENT_DROPDOWN,
        },
        {
            type    = "button",
            name    = "Refresh List",
            tooltip = "Reload the list with everything recorded so far.",
            func    = function() RefreshRecent() end,
            width   = "half",
        },
        {
            type    = "button",
            name    = "Clear List",
            tooltip = "Forget every recorded proc and start over. Does not touch the procs you already track.",
            func    = function()
                Capture.Clear()
                SelectRecord(NO_SELECTION)
                RefreshRecent()
                draft.status = "List cleared."
            end,
            width   = "half",
        },
        {
            type  = "description",
            text  = GetDetailsText,
            width = "full",
        },
        {
            type     = "editbox",
            name     = "Tracker Name",
            tooltip  = "Name shown on the tracker. Defaults to the name of the proc.",
            getFunc  = function() return draft.name end,
            setFunc  = function(value) draft.name = value or "" end,
            width    = "full",
            disabled = NothingSelected,
        },
        {
            type       = "slider",
            name       = "Cooldown (seconds)",
            tooltip    = "How long until the proc can go off again. Check the set or skill tooltip.",
            getFunc    = function() return draft.cooldownSec end,
            setFunc    = function(value) draft.cooldownSec = ClampCooldown(value) end,
            min        = MIN_COOLDOWN_SEC,
            max        = MAX_COOLDOWN_SEC,
            step       = 0.5,
            decimals   = 1,
            clampInput = true,
            width      = "full",
            disabled   = NothingSelected,
        },
        {
            type     = "button",
            name     = "Track This Proc",
            tooltip  = "Add a tracker for the selected proc. It is tracked all the time, whatever gear you wear.",
            func     = TrackSelected,
            width    = "full",
            disabled = NothingSelected,
        },
        {
            type  = "description",
            text  = function() return draft.status end,
            width = "full",
        },
        {
            type   = "divider",
            width  = "full",
            height = 12,
            alpha  = 0.25,
        },
        {
            type  = "description",
            text  = "|cFFD27FProcs You Added|r\nMove, resize, or change the sounds of an added proc under |cFFFFFFTracked Cooldowns|r.",
            width = "full",
        },
        {
            type       = "dropdown",
            name       = "Your Procs",
            choices    = addedChoices,
            getFunc    = function() return selectedAdded end,
            setFunc    = function(value) selectedAdded = value or NO_ADDED end,
            scrollable = true,
            width      = "full",
            reference  = ADDED_DROPDOWN,
            disabled   = function() return #Capture.GetUserProcKeys() == 0 end,
        },
        {
            type        = "button",
            name        = "Remove Proc",
            tooltip     = "Stop tracking the selected proc and delete its tracker.",
            func        = RemoveSelected,
            width       = "full",
            isDangerous = true,
            warning     = "This deletes the tracker and its position, size, and sound settings.",
            disabled    = function() return GetCatalog()[selectedAdded] == nil end,
        },
    }
end
