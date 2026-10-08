--[[
    Addon: Immersive Rumors
    Author: Fadosch
    Description: Removes blue text highlights from Rumors clues and hints in the Quest Journal,
                 so you actually have to read the clues yourself to solve the mysteries!
]]

ImmersiveRumors = ImmersiveRumors or {}
local IR = ImmersiveRumors
-- Backward compatibility alias
RumorsNoBlueHints = ImmersiveRumors
local RNBH = ImmersiveRumors

IR.name = "ImmersiveRumors"
IR.version = "1.0.1"
IR.author = "Fadosch"

-- Default settings
local defaultSettings = {
    enabled = true,
    cleanJournal = true,
    debug = false,
}

IR.defaults = defaultSettings
IR.settings = defaultSettings

-- Table to track controls that have had their SetText hooked to prevent duplicate hooks
local hookedControls = {}

--------------------------------------------------------------------------------
-- Debug Logger
--------------------------------------------------------------------------------
local function DebugMsg(msg, ...)
    if IR.settings and IR.settings.debug then
        d(string.format("|c4E9BFF[Immersive Rumors Debug]|r " .. tostring(msg), ...))
    end
end
IR.DebugMsg = DebugMsg

--------------------------------------------------------------------------------
-- Color Detection & Text Sanitization
--------------------------------------------------------------------------------

-- Checks if a 6-character hex code represents a blue / cyan highlight
function IR.IsBlueColor(hex)
    if not hex or #hex ~= 6 then return false end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not (r and g and b) then return false end

    -- Characteristics of blue/cyan text highlights in ESO:
    -- 1. Blue channel is prominent: b >= 90
    -- 2. Blue channel is substantially higher than red: b - r >= 25
    -- 3. Green channel is greater or equal to red (excludes purples/magentas): g >= r
    -- 4. Blue channel is dominant or close to green: b >= (g * 0.7)
    return (b >= 90) and ((b - r) >= 30) and (g >= r) and (b >= (g * 0.7))
end

-- Fast test to check if a string contains any blue color tags
function IR.ContainsBlueHighlight(text)
    if not text or type(text) ~= "string" or text == "" then return false end
    for hex in text:gmatch("|[cC](%x%x%x%x%x%x)") do
        if IR.IsBlueColor(hex) then
            return true
        end
    end
    return false
end

-- Removes blue highlights from text so the highlighted words inherit the surrounding / base text color
function IR.RemoveBlueHighlights(text)
    if not text or type(text) ~= "string" or text == "" then return text end
    if not IR.settings.enabled then return text end
    if not IR.ContainsBlueHighlight(text) then return text end

    local originalText = text

    -- Pattern to match innermost color blocks: |cRRGGBB[non-pipe-chars]|r
    local leafPattern = "|[cC](%x%x%x%x%x%x)([^|]-)|[rR]"
    local iterations = 0
    while iterations < 10 do
        iterations = iterations + 1
        local changed = false
        text = text:gsub(leafPattern, function(hex, content)
            if IR.IsBlueColor(hex) then
                changed = true
                return content -- Strip the blue color tag and closing |r
            end
            return nil -- Leave non-blue color tags untouched
        end)
        if not changed then break end
    end

    -- Clean up any orphaned trailing blue tags (e.g. without matching |r)
    for hex in text:gmatch("|[cC](%x%x%x%x%x%x)") do
        if IR.IsBlueColor(hex) then
            text = text:gsub("|[cC]" .. hex, "")
        end
    end

    if text ~= originalText then
        DebugMsg("Neutralized blue highlight: original: %q -> cleaned: %q", originalText, text)
    end

    return text
end

--------------------------------------------------------------------------------
-- Control Hooking & Hierarchy Traversal
--------------------------------------------------------------------------------

-- Hooks a label's SetText method so future updates are intercepted and sanitized
function IR.HookControlSetText(control)
    if not control or hookedControls[control] then return end
    if not control.SetText or not control.GetText then return end

    hookedControls[control] = true

    local origSetText = control.SetText
    control.SetText = function(self, text, ...)
        if IR.settings.enabled and type(text) == "string" and IR.ContainsBlueHighlight(text) then
            text = IR.RemoveBlueHighlights(text)
        end
        return origSetText(self, text, ...)
    end
end

-- Recursively scans a control and its children, sanitizing current text and hooking SetText on labels
function IR.SanitizeControlTree(control, depth)
    if not control then return end
    depth = depth or 0
    if depth > 15 then return end -- Safety depth limit

    if control.GetText and control.SetText then
        IR.HookControlSetText(control)
        local text = control:GetText()
        if text and text ~= "" and IR.ContainsBlueHighlight(text) then
            local clean = IR.RemoveBlueHighlights(text)
            if clean ~= text then
                control:SetText(clean)
            end
        end
    end

    if control.GetNumChildren then
        local num = control:GetNumChildren()
        for i = 1, num do
            local child = control:GetChild(i)
            if child then
                IR.SanitizeControlTree(child, depth + 1)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Bullet List Hooking
--------------------------------------------------------------------------------

-- Hooks AddLine on a ZO_BulletList instance or class
function IR.HookBulletList(bulletList)
    if not bulletList or bulletList.__rnbhHooked then return end
    if type(bulletList.AddLine) ~= "function" then return end

    bulletList.__rnbhHooked = true
    local origAddLine = bulletList.AddLine
    bulletList.AddLine = function(self, text, ...)
        if IR.settings.enabled and type(text) == "string" and IR.ContainsBlueHighlight(text) then
            text = IR.RemoveBlueHighlights(text)
        end
        return origAddLine(self, text, ...)
    end
    DebugMsg("Hooked BulletList instance")
end

--------------------------------------------------------------------------------
-- Journal & Rumor Managers Hooking
--------------------------------------------------------------------------------

-- Discovers all active journal and rumor manager objects
function IR.FindJournalManagers()
    local managers = {}

    -- Known and expected global manager names
    local candidates = {
        "ZO_QUEST_JOURNAL_RUMORS_KEYBOARD",
        "ZO_QUEST_JOURNAL_RUMOR_KEYBOARD",
        "ZO_RUMORS_JOURNAL_KEYBOARD",
        "ZO_RUMOR_JOURNAL_KEYBOARD",
        "ZO_RUMORS_KEYBOARD",
        "ZO_RUMOR_KEYBOARD",
        "RUMORS_JOURNAL_KEYBOARD",
        "RUMOR_JOURNAL_KEYBOARD",
        "ZO_QUEST_JOURNAL_RUMORS_GAMEPAD",
        "ZO_QUEST_JOURNAL_RUMOR_GAMEPAD",
        "ZO_RUMORS_JOURNAL_GAMEPAD",
        "ZO_RUMOR_JOURNAL_GAMEPAD",
        "ZO_RUMORS_GAMEPAD",
        "ZO_RUMOR_GAMEPAD",
        "ZO_QUEST_JOURNAL_QUESTS_KEYBOARD",
        "ZO_QUEST_JOURNAL_QUESTS_GAMEPAD",
        "QUEST_JOURNAL_KEYBOARD",
        "QUEST_JOURNAL_GAMEPAD",
    }

    for _, name in ipairs(candidates) do
        local obj = _G[name]
        if type(obj) == "table" then
            managers[name] = obj
        end
    end

    -- Dynamically search _G for any globals matching RUMOR
    pcall(function()
        for name, obj in pairs(_G) do
            if type(name) == "string" and type(obj) == "table" then
                local upper = name:upper()
                if upper:find("RUMOR") and (upper:find("JOURNAL") or upper:find("KEYBOARD") or upper:find("GAMEPAD") or upper:find("MANAGER")) then
                    managers[name] = obj
                end
            end
        end
    end)

    -- Also check sub-tables on QUEST_JOURNAL_KEYBOARD
    if QUEST_JOURNAL_KEYBOARD and type(QUEST_JOURNAL_KEYBOARD) == "table" then
        pcall(function()
            for k, v in pairs(QUEST_JOURNAL_KEYBOARD) do
                if type(k) == "string" and type(v) == "table" then
                    local upper = k:upper()
                    if upper:find("RUMOR") then
                        managers["QUEST_JOURNAL_KEYBOARD." .. k] = v
                    end
                end
            end
        end)
    end

    return managers
end

-- Sanitizes all known fields and controls on a journal/rumor manager
function IR.SanitizeManager(manager)
    if not manager or type(manager) ~= "table" then return end
    if not IR.settings.cleanJournal then return end

    -- Check common label fields
    local labelFields = {
        "stepText",
        "bgText",
        "descriptionText",
        "title",
        "hintText",
        "clueText",
        "taskText",
        "summaryText",
    }

    for _, field in ipairs(labelFields) do
        local label = manager[field]
        if label and label.GetText and label.SetText then
            IR.HookControlSetText(label)
            local text = label:GetText()
            if text and text ~= "" and IR.ContainsBlueHighlight(text) then
                local clean = IR.RemoveBlueHighlights(text)
                if clean ~= text then
                    label:SetText(clean)
                end
            end
        end
    end

    -- Check bullet lists
    local bulletFields = {
        "conditionTextBulletList",
        "clueBulletList",
        "cluesBulletList",
        "clueList",
    }

    for _, field in ipairs(bulletFields) do
        local bList = manager[field]
        if bList and type(bList.AddLine) == "function" then
            IR.HookBulletList(bList)
        end
    end

    -- If manager has a main control, sanitize its tree
    if manager.control then
        IR.SanitizeControlTree(manager.control)
    end
end

-- Hooks details refresh functions on a manager
function IR.HookManager(name, manager)
    if not manager or manager.__rnbhHooked then return end
    manager.__rnbhHooked = true

    local hookFunctions = {
        "RefreshDetails",
        "UpdateDetails",
        "Refresh",
        "RefreshView",
        "PopulateDetails",
    }

    for _, fnName in ipairs(hookFunctions) do
        if type(manager[fnName]) == "function" then
            SecurePostHook(manager, fnName, function(self)
                IR.SanitizeManager(self)
            end)
            DebugMsg("Hooked %s:%s()", name, fnName)
        end
    end

    -- If manager already has bullet lists, hook them directly
    if manager.conditionTextBulletList then
        IR.HookBulletList(manager.conditionTextBulletList)
    end
    if manager.clueBulletList then
        IR.HookBulletList(manager.clueBulletList)
    end
end

-- Comprehensive scan and sanitize of the Quest Journal UI
function IR.ScanAndSanitizeAll()
    if not IR.settings.cleanJournal then return end

    -- Sanitize top-level UI windows
    if ZO_QuestJournal then
        IR.SanitizeControlTree(ZO_QuestJournal)
    end
    if ZO_GamepadQuestJournal then
        IR.SanitizeControlTree(ZO_GamepadQuestJournal)
    end

    -- Find and hook all managers
    local managers = IR.FindJournalManagers()
    for name, mgr in pairs(managers) do
        IR.HookManager(name, mgr)
        IR.SanitizeManager(mgr)
    end
end

--------------------------------------------------------------------------------
-- Global Class & Scene Hooks Setup
--------------------------------------------------------------------------------

local function SetupHooks()
    -- Hook ZO_BulletList class if globally available
    if ZO_BulletList and type(ZO_BulletList.AddLine) == "function" then
        IR.HookBulletList(ZO_BulletList)
    end

    -- Hook Quest Journal scenes when shown
    if SCENE_MANAGER then
        local journalScene = SCENE_MANAGER:GetScene("questJournal")
        if journalScene then
            journalScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWN then
                    zo_callLater(IR.ScanAndSanitizeAll, 50)
                end
            end)
        end

        local gamepadJournalScene = SCENE_MANAGER:GetScene("gamepad_quest_journal")
        if gamepadJournalScene then
            gamepadJournalScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWN then
                    zo_callLater(IR.ScanAndSanitizeAll, 50)
                end
            end)
        end
    end

    -- Hook Lore Reader (books, scrolls, notes found in the world)
    if LORE_READER and type(LORE_READER.Show) == "function" then
        local origShow = LORE_READER.Show
        LORE_READER.Show = function(self, title, body, medium, showTitle, ...)
            if IR.settings.enabled then
                if type(body) == "string" and IR.ContainsBlueHighlight(body) then
                    body = IR.RemoveBlueHighlights(body)
                    DebugMsg("Neutralized blue highlights in Lore Reader body")
                end
                if type(title) == "string" and IR.ContainsBlueHighlight(title) then
                    title = IR.RemoveBlueHighlights(title)
                    DebugMsg("Neutralized blue highlights in Lore Reader title")
                end
            end
            return origShow(self, title, body, medium, showTitle, ...)
        end
        DebugMsg("Hooked LORE_READER:Show()")
    end

    -- Register for EVENT_SHOW_BOOK to also scan the book UI controls after display
    if EVENT_SHOW_BOOK then
        EVENT_MANAGER:RegisterForEvent(IR.name .. "_Book", EVENT_SHOW_BOOK,
            function(eventCode, title, body, medium, showTitle, bookId)
                if IR.settings.enabled then
                    DebugMsg("EVENT_SHOW_BOOK fired: title=%s, bookId=%s", tostring(title), tostring(bookId))
                    zo_callLater(function()
                        if ZO_LoreReader then
                            IR.SanitizeControlTree(ZO_LoreReader)
                        end
                    end, 100)
                end
            end)
        DebugMsg("Registered for EVENT_SHOW_BOOK")
    end

    -- Hook Lore Reader scenes (keyboard and gamepad)
    if SCENE_MANAGER then
        local lrSceneNames = { "loreReaderKeyboard", "loreReaderGamepad", "loreReader" }
        for _, sceneName in ipairs(lrSceneNames) do
            local lrScene = SCENE_MANAGER:GetScene(sceneName)
            if lrScene then
                lrScene:RegisterCallback("StateChange", function(oldState, newState)
                    if newState == SCENE_SHOWN then
                        zo_callLater(function()
                            if ZO_LoreReader then
                                IR.SanitizeControlTree(ZO_LoreReader)
                            end
                        end, 50)
                    end
                end)
                DebugMsg("Hooked Lore Reader scene: %s", sceneName)
            end
        end
    end

    -- Hook all discovered journal and rumor managers
    local managers = IR.FindJournalManagers()
    for name, mgr in pairs(managers) do
        IR.HookManager(name, mgr)
    end
end

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

local function SlashCommandHandler(arg)
    arg = arg and arg:lower():match("^%s*(.-)%s*$") or ""
    local isGerman = (GetCVar("language.2") == "de")

    if arg == "on" then
        IR.settings.enabled = true
        d(isGerman and "|c00FF00[Immersive Rumors]|r Aktiviert! Blaue Hinweistexte werden jetzt neutralisiert."
                   or "|c00FF00[Immersive Rumors]|r Enabled! Blue clue text highlights are now neutralized.")
        IR.ScanAndSanitizeAll()
    elseif arg == "off" then
        IR.settings.enabled = false
        d(isGerman and "|cFF6600[Immersive Rumors]|r Deaktiviert."
                   or "|cFF6600[Immersive Rumors]|r Disabled.")
    elseif arg == "toggle" then
        IR.settings.enabled = not IR.settings.enabled
        local state
        if isGerman then
            state = IR.settings.enabled and "|c00FF00Aktiviert|r" or "|cFF6600Deaktiviert|r"
        else
            state = IR.settings.enabled and "|c00FF00Enabled|r" or "|cFF6600Disabled|r"
        end
        d("|c4E9BFF[Immersive Rumors]|r Status: " .. state)
        if IR.settings.enabled then IR.ScanAndSanitizeAll() end
    elseif arg == "scan" then
        d(isGerman and "|c4E9BFF[Immersive Rumors]|r Scanne und bereinige Tagebuch-Elemente..."
                   or "|c4E9BFF[Immersive Rumors]|r Scanning and sanitizing journal elements...")
        IR.ScanAndSanitizeAll()
        d(isGerman and "|c00FF00[Immersive Rumors]|r Scan abgeschlossen."
                   or "|c00FF00[Immersive Rumors]|r Scan complete.")
    elseif arg == "debug" then
        IR.settings.debug = not IR.settings.debug
        local state
        if isGerman then
            state = IR.settings.debug and "|c00FF00AN|r" or "|cFF6600AUS|r"
        else
            state = IR.settings.debug and "|c00FF00ON|r" or "|cFF6600OFF|r"
        end
        d(isGerman and "|c4E9BFF[Immersive Rumors]|r Debug-Modus: " .. state
                   or "|c4E9BFF[Immersive Rumors]|r Debug Mode: " .. state)
    else
        if isGerman then
            local state = IR.settings.enabled and "|c00FF00Aktiviert|r" or "|cFF6600Deaktiviert|r"
            d("|c4E9BFF=== Immersive Rumors (v" .. IR.version .. ") ===|r")
            d("Status: " .. state)
            d("Befehle:")
            d("  /ir on         - Aktiviert das Addon")
            d("  /ir off        - Deaktiviert das Addon")
            d("  /ir toggle     - Schaltet das Addon um")
            d("  /ir debug      - Schaltet Debug-Ausgaben an/aus")
        else
            local state = IR.settings.enabled and "|c00FF00Enabled|r" or "|cFF6600Disabled|r"
            d("|c4E9BFF=== Immersive Rumors (v" .. IR.version .. ") ===|r")
            d("Status: " .. state)
            d("Commands:")
            d("  /ir on         - Enable the addon")
            d("  /ir off        - Disable the addon")
            d("  /ir toggle     - Toggle the addon")
            d("  /ir debug      - Toggle debug output on/off")
        end
    end
end

SLASH_COMMANDS["/ir"] = SlashCommandHandler
SLASH_COMMANDS["/immersiverumors"] = SlashCommandHandler
SLASH_COMMANDS["/rnbh"] = SlashCommandHandler
SLASH_COMMANDS["/noblue"] = SlashCommandHandler
SLASH_COMMANDS["/rumors"] = SlashCommandHandler

--------------------------------------------------------------------------------
-- Addon Initialization
--------------------------------------------------------------------------------

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= IR.name and addonName ~= "RumorsNoBlueHints" then return end
    EVENT_MANAGER:UnregisterForEvent(IR.name, EVENT_ADD_ON_LOADED)

    -- Initialize SavedVariables (with fallback from previous name)
    ImmersiveRumorsSavedVars = ImmersiveRumorsSavedVars or RumorsNoBlueHintsSavedVars or {}
    IR.savedVars = ZO_SavedVars:NewAccountWide("ImmersiveRumorsSavedVars", 1, nil, defaultSettings)
    IR.settings = IR.savedVars

    -- Initialize Settings Menu (LibAddonMenu-2.0)
    if IR.InitSettings then
        IR.InitSettings()
    end

    DebugMsg("AddOn Loaded successfully")
end

local function OnPlayerActivated(eventCode)
    EVENT_MANAGER:UnregisterForEvent(IR.name, EVENT_PLAYER_ACTIVATED)

    -- Setup all hooks once the player and UI are fully active
    SetupHooks()
    zo_callLater(IR.ScanAndSanitizeAll, 200)
end

EVENT_MANAGER:RegisterForEvent(IR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(IR.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
