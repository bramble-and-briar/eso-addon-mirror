-- BGF_Core.lua
-- Namespace, saved variables, printing and small helpers shared by the PC and
-- console front ends. The PC and console add-ons each carry their own copy of
-- the Core folder (with their own namespace), so they never clash.

BetterGroupFinderConsole = BetterGroupFinderConsole or {}
local BGF = BetterGroupFinderConsole

BGF.name = "BetterGroupFinderConsole"
BGF.displayName = "Better Group Finder"
BGF.version = "1.0.0"
BGF.svName = "BetterGroupFinderConsoleSV"
BGF.color = "4FC3F7"

BGF.defaults = {
    -- Browse
    lastCategory = nil,          -- GROUP_FINDER_CATEGORY_* (set on first load)
    searchText = "",
    filterNeedsMyRole = false,
    filterMeetsCP = true,
    filterHideFull = true,
    filterAutoAcceptOnly = false,
    filterNoInviteCode = false,
    sortMode = 1,                -- index into BGF.SORT_MODES
    applyMessage = "",

    -- Create
    lastIntent = "vet_dungeon",
    autoTitle = true,
    autoDescription = true,
    autoRoles = true,
    extraNotes = "",

    -- Auto generation
    trialTanks = 2,              -- default 12-player makeup (DPS = the rest)
    trialHealers = 2,
    titleIncludeRoles = true,    -- "LF 1T 2D" in auto titles
    titleIncludeCP = true,       -- "CP1500+" in auto titles
    descIncludeActivity = true,  -- first line "Sunspire (Veteran)"
    descIncludeAd = true,        -- "Created using Better Group Finder" at the end

    -- Live listing
    autoAdjustRoles = true,      -- re-fit roles / texts when a member changes role, joins or leaves

    -- General
    alertOnApplicant = true,
    printResults = true,         -- chat messages for posted / applied / errors
    showNativeButton = true,     -- PC: button on the game's Group Finder window
}

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
function BGF:Print(text, force)
    if not force and self.sv and self.sv.printResults == false then return end
    local prefix = string.format("|c%s[BGF]|r ", self.color)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(prefix .. tostring(text))
    elseif d then
        d(prefix .. tostring(text))
    end
end

function BGF:Alert(text, isError)
    if ZO_Alert then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, isError and SOUNDS.GENERAL_ALERT_ERROR or SOUNDS.DEFAULT_CLICK, text)
    else
        self:Print(text)
    end
end

function BGF:ActionResultText(result)
    if result == nil then return "" end
    local text = GetString("SI_GROUPFINDERACTIONRESULT", result)
    if text == nil or text == "" then
        text = "Result " .. tostring(result)
    end
    return text
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
BGF.util = {}
local U = BGF.util

function U.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lower case, no punctuation or doubled spaces, "the " dropped: used to match
-- the game's activity names against the descriptive database.
function U.Normalize(s)
    s = zo_strlower(tostring(s or ""))
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("[%p]", " "):gsub("%s+", " ")
    s = U.Trim(s)
    s = s:gsub("^the ", "")
    return s
end

function U.Contains(haystack, needle)
    if needle == nil or needle == "" then return true end
    return zo_plainstrfind(zo_strlower(tostring(haystack or "")), zo_strlower(needle)) ~= nil
end

function U.Colorize(hex, text)
    return string.format("|c%s%s|r", hex, tostring(text or ""))
end

function U.Muted(text)
    return U.Colorize("9A9A9A", text)
end

function U.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d2 = pcall(fn, ...)
    if ok then return a, b, c, d2 end
    return nil
end

-- Iterates the bit flags between two flag values (as the game's flag
-- dropdowns do). Falls back to a plain loop if ZO_FlagHelpers is missing.
function U.FlagValues(first, last)
    local values = {}
    if first == nil or last == nil then return values end
    if ZO_FlagHelpers and ZO_FlagHelpers.FlagIterator then
        for flag in ZO_FlagHelpers.FlagIterator(first, last) do
            values[#values + 1] = flag
        end
    else
        local flag = first
        while flag <= last do
            values[#values + 1] = flag
            flag = flag * 2
        end
    end
    return values
end

function U.EnumValues(first, last)
    local values = {}
    if first == nil or last == nil then return values end
    for v = first, last do values[#values + 1] = v end
    return values
end

function U.FormatSeconds(s)
    s = math.max(0, math.floor(tonumber(s) or 0))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

---------------------------------------------------------------------------
-- Player info
---------------------------------------------------------------------------
function BGF:GetPlayerRole()
    local role = U.Safe(GetSelectedLFGRole)
    if role == nil or role == LFG_ROLE_INVALID then
        role = LFG_ROLE_DPS
    end
    return role
end

function BGF:GetPlayerCP()
    return U.Safe(GetPlayerChampionPointsEarned) or 0
end

function BGF:IsGamepad()
    return IsInGamepadPreferredMode and IsInGamepadPreferredMode() or false
end

---------------------------------------------------------------------------
-- Lightweight callbacks between the core and the UI
---------------------------------------------------------------------------
BGF.listeners = {}

function BGF:On(eventName, fn)
    self.listeners[eventName] = self.listeners[eventName] or {}
    table.insert(self.listeners[eventName], fn)
end

function BGF:Fire(eventName, ...)
    local list = self.listeners[eventName]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then
            self:Print("Error in " .. eventName .. ": " .. tostring(err))
        end
    end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
BGF.initFunctions = {}

-- Front ends and modules queue their setup here; runs after saved vars load.
function BGF:OnInitialize(fn)
    table.insert(self.initFunctions, fn)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= BGF.name then return end
    EVENT_MANAGER:UnregisterForEvent(BGF.name, EVENT_ADD_ON_LOADED)

    BGF.sv = ZO_SavedVars:NewAccountWide(BGF.svName, 1, nil, BGF.defaults)
    if BGF.sv.lastCategory == nil and GROUP_FINDER_CATEGORY_DUNGEON then
        BGF.sv.lastCategory = GROUP_FINDER_CATEGORY_DUNGEON
    end

    for i = 1, #BGF.initFunctions do
        local ok, err = pcall(BGF.initFunctions[i])
        if not ok then
            BGF:Print("Init error: " .. tostring(err))
        end
    end
end

EVENT_MANAGER:RegisterForEvent(BGF.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
