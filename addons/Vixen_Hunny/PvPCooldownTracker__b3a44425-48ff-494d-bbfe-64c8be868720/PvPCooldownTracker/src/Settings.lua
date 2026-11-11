-- -----------------------------------------------------------------------------
-- PvPCooldownTracker
-- Author:  @VixenHunny
-- Edited: 4/15/2026
--
-- Settings.lua
-- -----------------------------------------------------------------------------
PvPCooldownTracker = PvPCooldownTracker or {}
PvPCooldownTracker.Settings = {}

local WM = WINDOW_MANAGER
local scaleBase = PvPCooldownTracker.UI.scaleBase

-- Direct references captured during Init() when everything is guaranteed
-- to exist.  Closures (LAM2 callbacks) use these upvalues so they keep
-- working even if the global table loses load-time members later.
local DataSets
local SetAppearanceFn
local TraceFn
local UIRef
local TrackingRef

local panelData = {
    type        = "panel",
    name        = "PvPCooldownTracker",
    displayName = "PvPCooldownTracker",
    author      = "@Vixen Hunny",
    version     = PvPCooldownTracker.version,
    registerForRefresh  = true,
}

local default

local function GetDefaultsTable()
    if PvPCooldownTracker.Defaults and type(PvPCooldownTracker.Defaults.Get) == "function" then
        return PvPCooldownTracker.Defaults.Get() or {}
    end

    return {}
end

local function SafeString(value, fallback)
    if value == nil then
        return fallback or ""
    end

    return tostring(value)
end

local function SafeNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback or 0
    end

    return n
end

local function SafeBoolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    if fallback == nil then
        return false
    end

    return fallback == true
end

local function IsStateContainer(value)
    if type(PvPCooldownTracker.IsStateContainer) == "function" then
        return PvPCooldownTracker.IsStateContainer(value)
    end

    local valueType = type(value)
    return value ~= nil and (valueType == "table" or valueType == "userdata")
end

local function SafeTrace(level, ...)
    local fn = TraceFn or PvPCooldownTracker.Trace
    if type(fn) == "function" then
        fn(PvPCooldownTracker, level, ...)
    end
end

local savedVarsMaterialized = false

local function EnsureSavedVarsState()
    local defaults = GetDefaultsTable()

    if PvPCooldownTracker.savedVars == nil then
        -- Only bootstrap savedVars if it hasn't been set up yet.
        -- Defaults:Generate() and EnsureSavedVariables() are called during
        -- FinishInitialize() before Settings.Init(), so this is a fallback.
        if type(PvPCooldownTracker.EnsureSavedVariables) == "function" then
            PvPCooldownTracker.EnsureSavedVariables()
        end
        if PvPCooldownTracker.savedVars == nil then
            PvPCooldownTracker.savedVars = ZO_DeepTableCopy(defaults)
        end
    end

    local savedVars = PvPCooldownTracker.savedVars

    -- ZO_SavedVars uses metatables: reading a sub-table key may return the
    -- defaults reference via __index.  Writes into those tables modify the
    -- defaults object in-memory but are never serialized to disk.
    -- Deep-copy every mutable sub-table once so the copies land in rawData.
    if not savedVarsMaterialized then
        savedVarsMaterialized = true
        savedVars.sets = type(savedVars.sets) == "table"
            and ZO_DeepTableCopy(savedVars.sets) or {}
        savedVars.sounds = type(savedVars.sounds) == "table"
            and ZO_DeepTableCopy(savedVars.sounds) or {}
        savedVars.LabelLocation = type(savedVars.LabelLocation) == "table"
            and ZO_DeepTableCopy(savedVars.LabelLocation) or { x = 600, y = 300 }
        savedVars.TextureLocation = type(savedVars.TextureLocation) == "table"
            and ZO_DeepTableCopy(savedVars.TextureLocation) or { x = 640, y = 300 }
        if type(savedVars.style) == "table" then
            savedVars.style = ZO_DeepTableCopy(savedVars.style)
        end
        -- Also materialize character.set so enable/disable persists
        if PvPCooldownTracker.character ~= nil then
            local char = PvPCooldownTracker.character
            char.set = type(char.set) == "table"
                and ZO_DeepTableCopy(char.set) or {}
        end
    end

    savedVars.cooldown_expired = SafeString(savedVars.cooldown_expired, defaults.cooldown_expired or "FFFF00")
    savedVars.set_active = SafeString(savedVars.set_active, defaults.set_active or "3CB043")
    savedVars.unlocked = SafeBoolean(savedVars.unlocked, defaults.unlocked)
    savedVars.snapToGrid = SafeBoolean(savedVars.snapToGrid, defaults.snapToGrid)
    savedVars.showOutsideCombat = SafeBoolean(savedVars.showOutsideCombat, defaults.showOutsideCombat)
    savedVars.lagCompensation = SafeBoolean(savedVars.lagCompensation, defaults.lagCompensation)
    savedVars.gridSize = SafeNumber(savedVars.gridSize, defaults.gridSize or 16)
    savedVars.labelSize = SafeNumber(savedVars.labelSize, defaults.labelSize or 1.5)
    savedVars.size = SafeNumber(savedVars.size, defaults.size or 64)
    savedVars.labelFont = SafeString(savedVars.labelFont, defaults.labelFont or "$(BOLD_FONT)|18|soft-shadow-thick")
    savedVars.timerFont = SafeString(savedVars.timerFont, defaults.timerFont or "$(BOLD_FONT)|22|soft-shadow-thick")

    if not IsStateContainer(savedVars.LabelLocation) then
        savedVars.LabelLocation = ZO_DeepTableCopy(defaults.LabelLocation or { x = 600, y = 300 })
    end
    savedVars.LabelLocation.x = SafeNumber(savedVars.LabelLocation.x, defaults.LabelLocation and defaults.LabelLocation.x or 600)
    savedVars.LabelLocation.y = SafeNumber(savedVars.LabelLocation.y, defaults.LabelLocation and defaults.LabelLocation.y or 300)

    if not IsStateContainer(savedVars.TextureLocation) then
        savedVars.TextureLocation = ZO_DeepTableCopy(defaults.TextureLocation or { x = 640, y = 300 })
    end
    savedVars.TextureLocation.x = SafeNumber(savedVars.TextureLocation.x, defaults.TextureLocation and defaults.TextureLocation.x or 640)
    savedVars.TextureLocation.y = SafeNumber(savedVars.TextureLocation.y, defaults.TextureLocation and defaults.TextureLocation.y or 300)

    if not IsStateContainer(savedVars.sounds) then
        savedVars.sounds = ZO_DeepTableCopy(defaults.sounds or {})
    end
    if not IsStateContainer(savedVars.sounds.onProc) then
        savedVars.sounds.onProc = ZO_DeepTableCopy(defaults.sounds and defaults.sounds.onProc or { enabled = true, sound = "STATS_PURCHASE" })
    end
    if not IsStateContainer(savedVars.sounds.onReady) then
        savedVars.sounds.onReady = ZO_DeepTableCopy(defaults.sounds and defaults.sounds.onReady or { enabled = true, sound = "SKILL_LINE_ADDED" })
    end
    savedVars.sounds.onProc.enabled = SafeBoolean(savedVars.sounds.onProc.enabled, true)
    savedVars.sounds.onReady.enabled = SafeBoolean(savedVars.sounds.onReady.enabled, true)
    savedVars.sounds.onProc.sound = SafeString(savedVars.sounds.onProc.sound, "STATS_PURCHASE")
    savedVars.sounds.onReady.sound = SafeString(savedVars.sounds.onReady.sound, "SKILL_LINE_ADDED")

    if not IsStateContainer(savedVars.sets) then
        savedVars.sets = {}
    end

    if PvPCooldownTracker.character == nil then
        PvPCooldownTracker.character = {}
    end
    if not IsStateContainer(PvPCooldownTracker.character.set) then
        PvPCooldownTracker.character.set = {}
    end

    return savedVars, defaults
end

PvPCooldownTracker.Settings.EnsureSavedVars = EnsureSavedVarsState
PvPCooldownTracker.Settings.EnsureState = EnsureSavedVarsState

local function EnsureSelectedSetSavedVars(setKey)
    local savedVars, defaults = EnsureSavedVarsState()
    if type(setKey) ~= "string" or setKey == "" then
        return nil, savedVars
    end

    if not IsStateContainer(savedVars.sets[setKey]) then
        local defaultSet = defaults and defaults.sets and defaults.sets[setKey]
        if type(defaultSet) == "table" then
            savedVars.sets[setKey] = ZO_DeepTableCopy(defaultSet)
        else
            savedVars.sets[setKey] = {
                x = savedVars.TextureLocation.x,
                y = savedVars.TextureLocation.y,
                labelx = savedVars.LabelLocation.x,
                labely = savedVars.LabelLocation.y,
                size = savedVars.size,
                sounds = ZO_DeepTableCopy(savedVars.sounds),
            }
        end
    end

    local saved = savedVars.sets[setKey]
    saved.x = SafeNumber(saved.x, savedVars.TextureLocation.x)
    saved.y = SafeNumber(saved.y, savedVars.TextureLocation.y)
    saved.size = SafeNumber(saved.size, savedVars.size)
    if not IsStateContainer(saved.sounds) then
        saved.sounds = ZO_DeepTableCopy(savedVars.sounds)
    end
    if not IsStateContainer(saved.sounds.onProc) then
        saved.sounds.onProc = ZO_DeepTableCopy(savedVars.sounds.onProc)
    end
    if not IsStateContainer(saved.sounds.onReady) then
        saved.sounds.onReady = ZO_DeepTableCopy(savedVars.sounds.onReady)
    end
    saved.sounds.onProc.enabled = SafeBoolean(saved.sounds.onProc.enabled, savedVars.sounds.onProc.enabled)
    saved.sounds.onReady.enabled = SafeBoolean(saved.sounds.onReady.enabled, savedVars.sounds.onReady.enabled)
    saved.sounds.onProc.sound = SafeString(saved.sounds.onProc.sound, savedVars.sounds.onProc.sound)
    saved.sounds.onReady.sound = SafeString(saved.sounds.onReady.sound, savedVars.sounds.onReady.sound)

    return saved, savedVars
end

PvPCooldownTracker.Settings.EnsureSetSavedVars = EnsureSelectedSetSavedVars


-- ============================================================================
-- Live dropdown lists
-- ============================================================================
-- Dropdown lists that change while playing (recent procs, added procs, tracked
-- cooldowns) have to be pushed to the menu library by hand:
--   * PC: LibAddonMenu only reads `choices` when the control is built, so the
--     live control (found through its `reference`) gets UpdateChoices().
--   * Console: LibAddonMenu converts the whole menu to LibHarvensAddonSettings
--     once at load and copies every dropdown's choices into an `items` list.
--     That copy is rewritten in place here, otherwise the list would stay
--     frozen at whatever it held when the addon loaded.
local consolePanel = nil       -- LibHarvensAddonSettings panel object (console only)
local consoleDropdowns = {}    -- [reference] = { setting = <LHAS setting>, option = <LAM option> }

local function RebuildConsoleItems(entry, choices, values)
    local setting = entry.setting
    if type(setting.items) ~= "table" then
        setting.items = {}
    end

    choices = type(choices) == "table" and choices or entry.option.choices or {}
    values = type(values) == "table" and values or entry.option.choicesValues or choices

    local items = setting.items
    for i = #items, 1, -1 do items[i] = nil end
    for i = 1, #choices do
        local value = values[i]
        if value == nil then value = choices[i] end
        items[i] = { name = choices[i], data = value }
    end
end

local function RefreshConsolePanel()
    -- Only redraw while this addon's settings are the ones on screen.
    if type(consolePanel) == "table"
        and consolePanel.selected == true
        and type(consolePanel.UpdateControls) == "function"
    then
        pcall(consolePanel.UpdateControls, consolePanel)
    end
end

-- quiet = true only updates the stored list (no redraw); used for background
-- updates while the menu is most likely closed.
function PvPCooldownTracker.Settings.PushDropdownChoices(reference, choices, values, tooltips, quiet)
    local control = _G[reference]
    if control ~= nil and type(control.UpdateChoices) == "function" then
        control:UpdateChoices(choices, values, tooltips)
        if type(control.UpdateValue) == "function" then
            control:UpdateValue()
        end
    end

    local entry = consoleDropdowns[reference]
    if entry ~= nil then
        RebuildConsoleItems(entry, choices, values)
        if not quiet then
            RefreshConsolePanel()
        end
    end
end

-- Called once after the menu is registered. Does nothing on PC.
local function HookConsoleDropdowns(lam, addonId, optionsTable)
    local conversion = type(lam) == "table" and lam.LHASConversion or nil
    local panel = type(conversion) == "table"
        and type(conversion.settingTables) == "table"
        and conversion.settingTables[addonId]
        or nil
    if type(panel) ~= "table" or type(panel.settings) ~= "table" then
        return
    end

    consolePanel = panel

    local function FindSetting(label)
        for i = 1, #panel.settings do
            local setting = panel.settings[i]
            if type(setting) == "table" and setting.labelText == label and type(setting.items) == "table" then
                return setting
            end
        end
        return nil
    end

    local function Walk(controls)
        for _, option in ipairs(controls) do
            if option.type == "dropdown" and type(option.reference) == "string" then
                local setting = FindSetting(option.name)
                if setting ~= nil then
                    local entry = { setting = setting, option = option }
                    consoleDropdowns[option.reference] = entry

                    -- The converted getter looks names up in a map built at
                    -- load; replace it with one that reads the live list.
                    setting.getFunction = function()
                        local value = option.getFunc()
                        local items = setting.items
                        for i = 1, #items do
                            if items[i].data == value then
                                return items[i].name
                            end
                        end
                        return items[1] and items[1].name or ""
                    end

                    RebuildConsoleItems(entry)
                end
            end
            if type(option.controls) == "table" then
                Walk(option.controls)
            end
        end
    end

    Walk(optionsTable)
end

-- ============================================================================
-- Global Options
-- ============================================================================

-- Grid Options
local function GetSnapToGrid()
    local savedVars = EnsureSavedVarsState()
    return savedVars.snapToGrid
end

local function SetSnapToGrid(snap)
    local savedVars = EnsureSavedVarsState()
    savedVars.snapToGrid = snap == true
end

local function GetGridSize()
    local savedVars = EnsureSavedVarsState()
    return savedVars.gridSize
end

local function SetGridSize(gridSize)
    local savedVars = EnsureSavedVarsState()
    savedVars.gridSize = SafeNumber(gridSize, savedVars.gridSize)
end

-- Locked State
local function SetUnlocked(unlocked)
    local savedVars = EnsureSavedVarsState()
    savedVars.unlocked = unlocked == true

    local ui = UIRef or PvPCooldownTracker.UI
    if ui and type(ui.SetUnlocked) == "function" then
        ui.SetUnlocked(savedVars.unlocked)
    end
end

-- Force Showing (keeps trackers visible while a menu is open)
local function SetForceShow(value)
    local ui = UIRef or PvPCooldownTracker.UI
    PvPCooldownTracker.ForceShow = value == true

    if PvPCooldownTracker.ForceShow then
        if ui and type(ui.ShowIcon) == "function" then ui.ShowIcon(true) end
    else
        -- Fall back to the normal rules: hidden in menus, combat rules on the HUD.
        local onHud = SCENE_MANAGER ~= nil
            and (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
        PvPCooldownTracker.HUDHidden = not onHud
        if ui and type(ui.SetCombatStateDisplay) == "function" then
            ui.SetCombatStateDisplay(ui)
        end
    end
end

-- Style
local CUSTOM_THEME = "Custom"

local function GetStyle()
    local savedVars = EnsureSavedVarsState()
    if type(savedVars.style) ~= "table" then
        local defaults = GetDefaultsTable()
        savedVars.style = type(defaults.style) == "table" and ZO_DeepTableCopy(defaults.style) or {}
    end
    return savedVars.style
end

local function HexToRGB(hex, fallbackHex)
    local text = tostring(hex or ""):gsub("#", "")
    if not text:match("^%x%x%x%x%x%x") then
        text = fallbackHex
    end
    return tonumber(text:sub(1, 2), 16) / 255, tonumber(text:sub(3, 4), 16) / 255, tonumber(text:sub(5, 6), 16) / 255, 1
end

local function RGBToHex(r, g, b)
    local function Channel(value)
        return math.floor(math.max(0, math.min(1, tonumber(value) or 0)) * 255 + 0.5)
    end
    return string.format("%02X%02X%02X", Channel(r), Channel(g), Channel(b))
end

-- Combat State Display
local function GetShowOutOfCombat()
    local savedVars = EnsureSavedVarsState()
    return savedVars.showOutsideCombat
end

local function SetShowOutOfCombat(value)
    local savedVars = EnsureSavedVarsState()
    savedVars.showOutsideCombat = value == true

    local ui = UIRef or PvPCooldownTracker.UI
    if ui and type(ui.SetCombatStateDisplay) == "function" then
        pcall(function()
            ui.SetCombatStateDisplay(ui)
        end)
    end

    local tracking = TrackingRef or PvPCooldownTracker.Tracking
    if tracking then
        if value and type(tracking.UnregisterCombatEvent) == "function" then
            pcall(function()
                tracking.UnregisterCombatEvent()
            end)
        elseif not value and type(tracking.RegisterCombatEvent) == "function" then
            pcall(function()
                tracking.RegisterCombatEvent()
            end)
        end
    end
end

-- Lag Compensation
local function GetLagCompensation()
    local savedVars = EnsureSavedVarsState()
    return savedVars.lagCompensation
end

local function SetLagCompensation(value)
    local savedVars = EnsureSavedVarsState()
    savedVars.lagCompensation = value == true
end

-- Sizing
local function SetSize(setKey, size)
    local saved = EnsureSelectedSetSavedVars(setKey)
    local context = WM:GetControlByName(setKey .. "_Container")

    if not saved then
        return
    end

    saved.size = SafeNumber(size, saved.size)

    if context ~= nil then
        context:SetScale(saved.size / scaleBase)
    end
end


-- ============================================================================
-- Sets
-- ============================================================================

-- Selection
default = {
    set = "-- Select a Set --",
}

local setAliases = {
    ["Two-Fanged Snake"] = "Twice-Fanged Serpent",
}

local function ResolveSetAlias(procType, key)
    if procType == "set" and type(key) == "string" and setAliases[key] ~= nil then
        return setAliases[key]
    end

    return key
end

local function IsAliasSetKey(key)
    return setAliases[key] ~= nil
end

local function BuildSortedSetEntries()
    local entries = {}
    local sets = DataSets
    if type(sets) ~= "table" then
        return entries
    end

    for key, setData in pairs(sets) do
        if type(key) == "string" and type(setData) == "table" and setData.procType == "set" and not IsAliasSetKey(key) then
            entries[#entries + 1] = {
                key = key,
                description = setData.description,
            }
        end
    end

    table.sort(entries, function(a, b)
        return string.lower(a.key) < string.lower(b.key)
    end)

    return entries
end

local function GetFirstSelectableSetKey()
    local entries = BuildSortedSetEntries()
    return entries[1] and entries[1].key or nil
end

local function GetPersistedSelectedSet()
    local savedVars = EnsureSavedVarsState()
    local rawKey = savedVars.lastSelectedSet
    local key = ResolveSetAlias("set", rawKey)

    if type(key) == "string"
        and key ~= ""
        and key ~= default.set
        and type(DataSets) == "table"
        and type(DataSets[key]) == "table"
        and DataSets[key].procType == "set"
    then
        return key
    end

    return nil
end

local function IsSelectableSetKey(key)
    return type(key) == "string"
        and key ~= ""
        and key ~= default.set
        and type(DataSets) == "table"
        and type(DataSets[key]) == "table"
        and DataSets[key].procType == "set"
end


local function SetSelected(procType, selection)
    if procType == "set" then
        local key = ResolveSetAlias(procType, selection)
        if IsSelectableSetKey(key) then
            EnsureSavedVarsState().lastSelectedSet = key
        end
    end
end

local function HasSelected(procType)
    if type(default) ~= "table" then
        return false
    end

    local key = GetPersistedSelectedSet()
    if key then
        key = ResolveSetAlias(procType, key)
    end

    if key == nil or key == default[procType] then
        return false
    end

    if procType == "set" then
        local savedVars = PvPCooldownTracker.savedVars
        if savedVars ~= nil and IsStateContainer(savedVars.sets) and savedVars.sets[key] ~= nil then
            return true
        end

        return type(DataSets) == "table" and DataSets[key] ~= nil
    end

    return true
end

local function UpdateSelectedAppearance(procType)
    if not HasSelected(procType) then
        return
    end

    local setKey = GetPersistedSelectedSet()
    local saved = EnsureSelectedSetSavedVars(setKey)
    if not saved then
        return
    end

    local fn = SetAppearanceFn or PvPCooldownTracker.SetAppearance
    if type(fn) == "function" then
        fn(PvPCooldownTracker, saved.x, saved.y, setKey)
    end
end

local function EnsureCharacterProcType(procType)
    if PvPCooldownTracker.character == nil then
        PvPCooldownTracker.character = {}
    end

    if not IsStateContainer(PvPCooldownTracker.character[procType]) then
        PvPCooldownTracker.character[procType] = {}
    end

    if procType == "set" then
        for key, setData in pairs(DataSets) do
            if setData.procType == "set" and PvPCooldownTracker.character.set[key] == nil then
                PvPCooldownTracker.character.set[key] = true
            end
        end
    end

    return PvPCooldownTracker.character[procType]
end

local function GetValidSelectedKey(procType)
    if procType ~= "set" then
        return nil
    end

    local key = GetPersistedSelectedSet()
    if type(key) ~= "string" then
        return nil
    end

    return EnsureSelectedSetSavedVars(key) and key or nil
end

local function GetSelectedXPos(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if key then
        local saved = EnsureSelectedSetSavedVars(key)
        return saved and saved.x or savedVars.TextureLocation.x
    else
        return savedVars.TextureLocation.x
    end
end
local function SetSelectedXPos(procType, x)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.x = SafeNumber(x, saved.x)
    end
end
local function GetSelectedYPos(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if key then
        local saved = EnsureSelectedSetSavedVars(key)
        return saved and saved.y or savedVars.TextureLocation.y
    else
        return savedVars.TextureLocation.y
    end
end
local function SetSelectedYPos(procType, y)
    local key = GetValidSelectedKey(procType)
    if not key then return end
    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.y = SafeNumber(y, saved.y)
    end
end
-- Enabled
local function GetSelectedEnabled(procType)
    local key = GetValidSelectedKey(procType)
    if not key then
        return false
    end

    local procTable = EnsureCharacterProcType(procType)
    if not IsStateContainer(procTable) then
        return false
    end
    if procTable[key] == nil then
        procTable[key] = true
    end

    return procTable[key]
end

local function SetSelectedEnabled(procType, state)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    if procType == "set" then
        SetSelected(procType, key)
    end

    local procTable = EnsureCharacterProcType(procType)
    SafeTrace(0, 'SetSelectedEnabled key=<<1>> state=<<2>>', key, tostring(state))

    if procType == "set" then
        if procTable[key] == false and state == true then
            SafeTrace(0, 'Re-enabling <<1>>.', key)
        elseif state == false then
            SafeTrace(0, 'Forcing tracking off for <<1>>. It will not be tracked until you enable it again.', key)
        else
            SafeTrace(1, 'Setting <<1>> to <<2>>', key, tostring(state))
        end
    end

    procTable[key] = state
    local tracking = TrackingRef or PvPCooldownTracker.Tracking
    if tracking and type(tracking.EnableTrackingForSet) == "function" then
        pcall(function()
            tracking.EnableTrackingForSet(key, state)
        end)
    end

    local setData = type(DataSets) == "table" and DataSets[key] or nil
    if setData then
        setData.enabled = state
        if not state then
            setData.onCooldown = false
        end
    end

    local ui = UIRef or PvPCooldownTracker.UI
    if ui and type(ui.Draw) == "function" then
        pcall(function()
            ui.Draw(key)
        end)
        local context = WM:GetControlByName(key .. "_Container")
        if context ~= nil and state then
            context:SetHidden(false)
        end
        if state and type(ui.ShowIcon) == "function" then
            pcall(function()
                ui.ShowIcon(true)
            end)
        end
        if type(ui.SetCombatStateDisplay) == "function" then
            pcall(function()
                ui.SetCombatStateDisplay(ui)
            end)
        end
    end

    if state and not EnsureSavedVarsState().showOutsideCombat and not PvPCooldownTracker.isInCombat then
        SafeTrace(0, '<<1>> enabled. Visibility is currently combat-only.', key)
    end
end

-- Size
local function GetSelectedSize(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if key then
        local saved = EnsureSelectedSetSavedVars(key)
        return saved and saved.size or savedVars.size
    else
        return savedVars.size
    end
end

local function SetSelectedSize(procType, size)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.size = SafeNumber(size, saved.size)
    end
    SetSize(key, size)
end

-- Sounds
local function GetSelectedSoundOnProcEnabled(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if not key then
        return savedVars.sounds.onProc.enabled
    end

    local saved = EnsureSelectedSetSavedVars(key)
    return saved and saved.sounds.onProc.enabled or savedVars.sounds.onProc.enabled
end

local function SetSelectedSoundOnProcEnabled(procType, enabled)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.sounds.onProc.enabled = enabled == true
    end
end

local function GetSelectedSoundOnReadyEnabled(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if not key then
        return savedVars.sounds.onReady.enabled
    end

    local saved = EnsureSelectedSetSavedVars(key)
    return saved and saved.sounds.onReady.enabled or savedVars.sounds.onReady.enabled
end

local function SetSelectedSoundOnReadyEnabled(procType, enabled)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.sounds.onReady.enabled = enabled == true
    end
end

local function GetSelectedSoundOnProc(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if not key then
        return savedVars.sounds.onProc.sound
    end

    local saved = EnsureSelectedSetSavedVars(key)
    return saved and saved.sounds.onProc.sound or savedVars.sounds.onProc.sound
end

local function SetSelectedSoundOnProc(procType, sound)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.sounds.onProc.sound = SafeString(sound, saved.sounds.onProc.sound)
    end
end

local function GetSelectedSoundOnReady(procType)
    local key = GetValidSelectedKey(procType)
    local savedVars = EnsureSavedVarsState()
    if not key then
        return savedVars.sounds.onReady.sound
    end

    local saved = EnsureSelectedSetSavedVars(key)
    return saved and saved.sounds.onReady.sound or savedVars.sounds.onReady.sound
end

local function SetSelectedSoundOnReady(procType, sound)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if saved then
        saved.sounds.onReady.sound = SafeString(sound, saved.sounds.onReady.sound)
    end
end

-- Test Sound
local function PlaySelectedTestSound(procType, condition)
    local key = GetValidSelectedKey(procType)
    if not key then return end

    local saved = EnsureSelectedSetSavedVars(key)
    if not saved or not IsStateContainer(saved.sounds) then
        return
    end

    local sound = saved.sounds[condition]
    if type(sound) ~= "table" then
        return
    end

    SafeTrace(2, "Testing sound <<1>>", sound)

    local ui = UIRef or PvPCooldownTracker.UI
    if ui and type(ui.PlaySound) == "function" then
        ui.PlaySound(sound)
    end
end

-- Disabled Controls
local function ShouldOptionBeDisabled(procType, consider)
    if not GetValidSelectedKey(procType) then
        return true
    end

    if consider ~= nil and not consider then
        return true
    end

    return false
end

-- ============================================================================
-- Create Menu
-- ============================================================================
-- Initialize
function PvPCooldownTracker.Settings.Init()
    -- Capture Data.Sets NOW while it definitely exists.
    -- All closures below (getFunc/setFunc/disabled) use DataSets via upvalue.
    DataSets        = PvPCooldownTracker.Data and PvPCooldownTracker.Data.Sets
    SetAppearanceFn = PvPCooldownTracker.SetAppearance
    TraceFn         = PvPCooldownTracker.Trace
    UIRef           = PvPCooldownTracker.UI
    TrackingRef     = PvPCooldownTracker.Tracking

    local savedVars = EnsureSavedVarsState()
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()
    local sounds = PvPCooldownTracker.Sounds or {}
    local soundNames = type(sounds.names) == "table" and sounds.names or {}
    local soundOptions = type(sounds.options) == "table" and sounds.options or soundNames

    -- Copy key/value table to index/value table
    local settingsBreakout = {
        set = {
            name = "|cCD5031Tracked Cooldowns|r",
            data = {},
            values = {},
            description = {},
        }
    }

    for key, set in pairs(DataSets) do
        if set.procType ~= "set" then
            SafeTrace(1, "Invalid procType: <<1>>", set.procType)
        end
    end

    local SET_DROPDOWN = "PvPCooldownTracker_SetDropdown"

    -- Rebuilds the "Tracked Cooldown" dropdown, e.g. after a proc was added or
    -- removed, and optionally selects an entry.
    local function RefreshSetChoices(preferredKey)
        local data, values, description = {}, {}, {}
        data[1], values[1] = default.set, default.set
        description[1] = "Choose a tracked cooldown to edit its position, size, and sounds."

        local entries = BuildSortedSetEntries()
        for i = 1, #entries do
            local entry = entries[i]
            local setData = DataSets[entry.key]
            data[#data + 1] = (setData and setData.userProc) and (entry.key .. "  |cFFD27F[added by you]|r") or entry.key
            values[#values + 1] = entry.key
            description[#description + 1] = entry.description or entry.key
        end

        if #entries == 0 then
            description[1] = "No tracked cooldowns are currently available."
        end

        local target = settingsBreakout.set
        for _, pair in ipairs({ { target.data, data }, { target.values, values }, { target.description, description } }) do
            for i = #pair[1], 1, -1 do pair[1][i] = nil end
            for i = 1, #pair[2] do pair[1][i] = pair[2][i] end
        end

        if IsSelectableSetKey(preferredKey) then
            EnsureSavedVarsState().lastSelectedSet = preferredKey
        end

        PvPCooldownTracker.Settings.PushDropdownChoices(SET_DROPDOWN, target.data, target.values, target.description)
    end

    PvPCooldownTracker.Settings.RefreshSetChoices = RefreshSetChoices
    RefreshSetChoices()

    local function RefreshAllTrackers()
        local ui = UIRef or PvPCooldownTracker.UI
        if ui and type(ui.RefreshAll) == "function" then
            ui.RefreshAll()
        end
    end

    -- Colour picker bound to one entry of savedVars.style.
    local function StyleColorPicker(name, tooltip, styleKey, fallback)
        return {
            type    = "colorpicker",
            name    = name,
            tooltip = tooltip,
            getFunc = function()
                local color = GetStyle()[styleKey]
                if type(color) ~= "table" then color = fallback end
                return color[1], color[2], color[3], color[4] or 1
            end,
            setFunc = function(r, g, b, a)
                local style = GetStyle()
                style[styleKey] = { r, g, b, a or 1 }
                style.theme = CUSTOM_THEME
                RefreshAllTrackers()
            end,
            width   = "half",
        }
    end

    -- Colour picker bound to one of the hex-string text colours.
    local function HexColorPicker(name, tooltip, savedKey, fallbackHex)
        return {
            type    = "colorpicker",
            name    = name,
            tooltip = tooltip,
            getFunc = function()
                return HexToRGB(EnsureSavedVarsState()[savedKey], fallbackHex)
            end,
            setFunc = function(r, g, b)
                EnsureSavedVarsState()[savedKey] = RGBToHex(r, g, b)
            end,
            width   = "half",
        }
    end

    local themeChoices = {}
    do
        local ui = UIRef or PvPCooldownTracker.UI
        if ui and type(ui.GetThemeNames) == "function" then
            themeChoices = ui.GetThemeNames()
        end
        themeChoices[#themeChoices + 1] = CUSTOM_THEME
    end

    local optionsTable = {
        {
            type = "description",
            text = "|cFFD27FPvPCooldownTracker|r shows a countdown for every set proc you wear. "
                .. "Saw a proc that is missing? Open |cFFFFFFAdd a Proc|r below and track it yourself.",
            width = "full",
        },
        {
            type = "header",
            name = "|cFFD27FGeneral|r",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Unlock Trackers",
            tooltip = "Set to ON to drag trackers around the screen. Set to OFF to lock them in place and let clicks pass through.",
            getFunc = function() return EnsureSavedVarsState().unlocked end,
            setFunc = function(value) SetUnlocked(value) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Trackers While In Menus",
            tooltip = "Keeps every enabled tracker on screen, even in this menu, so you can see your changes. Turns itself off on reload.",
            getFunc = function() return PvPCooldownTracker.ForceShow == true end,
            setFunc = function(value) SetForceShow(value) end,
            width = "full",
        },
        {
            type = "button",
            name = "Arrange In A Column",
            tooltip = "Stacks every enabled tracker into a tidy column so none of them overlap.",
            func = function()
                local ui = UIRef or PvPCooldownTracker.UI
                if ui and type(ui.ArrangeColumn) == "function" then
                    ui.ArrangeColumn()
                end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Outside of Combat",
            tooltip = "Set to ON to show while out of combat and OFF to only show while in combat.",
            getFunc = function() return GetShowOutOfCombat() end,
            setFunc = function(value) SetShowOutOfCombat(value) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Lag Compensation",
            tooltip = "Attempt to adjust proc timing based on lag conditions. Set to ON if you are falsely seeing back-to-back procs and set to OFF if procs in close proximity to being ready are being missed.",
            getFunc = function() return GetLagCompensation() end,
            setFunc = function(value) SetLagCompensation(value) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Snap to Grid",
            tooltip = "Set to ON to snap position to the specified grid.",
            getFunc = function() return GetSnapToGrid() end,
            setFunc = function(value) SetSnapToGrid(value) end,
            width = "half",
        },
        {
            type = "slider",
            name = "Grid Size",
            tooltip = "Grid dimensions to snap positioning of display elements to.",
            getFunc = function() return GetGridSize() end,
            setFunc = function(size) SetGridSize(size) end,
            min = 1,
            max = 100,
            step = 1,
            clampInput = true,
            decimals = 0,
            width = "half",
            disabled = function() return not GetSnapToGrid() end,
        },
        {
            type = "submenu",
            name = "|c7EC8E3Appearance|r",
            controls = {
                {
                    type = "dropdown",
                    name = "Color Theme",
                    tooltip = "Pick a ready-made palette. You can still change every color below afterwards.",
                    choices = themeChoices,
                    getFunc = function() return GetStyle().theme or CUSTOM_THEME end,
                    setFunc = function(value)
                        local ui = UIRef or PvPCooldownTracker.UI
                        if value ~= CUSTOM_THEME and ui and type(ui.ApplyTheme) == "function" then
                            ui.ApplyTheme(value)
                        else
                            GetStyle().theme = CUSTOM_THEME
                        end
                    end,
                    width = "full",
                },
                {
                    type = "dropdown",
                    name = "Layout",
                    tooltip = "Bar shows the icon, name, countdown, and a progress bar. Icon Only shows just the icon with the countdown on top.",
                    choices = { "Bar", "Icon Only" },
                    choicesValues = { "bar", "icon" },
                    getFunc = function() return GetStyle().layout == "icon" and "icon" or "bar" end,
                    setFunc = function(value)
                        GetStyle().layout = value == "icon" and "icon" or "bar"
                        RefreshAllTrackers()
                    end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Show Background Card",
                    tooltip = "Draws a dark card behind each tracker so it stays readable in a busy fight.",
                    getFunc = function() return GetStyle().showCard ~= false end,
                    setFunc = function(value) GetStyle().showCard = value == true RefreshAllTrackers() end,
                    width = "half",
                    disabled = function() return GetStyle().layout == "icon" end,
                },
                {
                    type = "checkbox",
                    name = "Show Name",
                    tooltip = "Shows the name of the set or proc on the tracker.",
                    getFunc = function() return GetStyle().showName ~= false end,
                    setFunc = function(value) GetStyle().showName = value == true RefreshAllTrackers() end,
                    width = "half",
                    disabled = function() return GetStyle().layout == "icon" end,
                },
                StyleColorPicker("Cooldown Color", "Bar and accent color while the proc is on cooldown.", "barFillColor", { 0.95, 0.45, 0.15, 1 }),
                StyleColorPicker("Ready Color", "Bar, accent, and glow color when the proc is ready.", "barReadyColor", { 0.36, 0.80, 0.36, 1 }),
                StyleColorPicker("Name Color", "Color of the set or proc name.", "labelColor", { 0.96, 0.93, 0.88, 1 }),
                StyleColorPicker("Timer Color", "Color of the countdown number.", "timerColor", { 1, 0.97, 0.91, 1 }),
                StyleColorPicker("Card Color", "Color and opacity of the background card.", "cardColor", { 0.05, 0.05, 0.07, 0.78 }),
                StyleColorPicker("Icon Tint On Cooldown", "The icon is dimmed with this color while on cooldown.", "cooldownTint", { 0.62, 0.60, 0.58, 1 }),
                {
                    type = "header",
                    name = "Proc / Ready Announcements",
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Show Announcements",
                    tooltip = "Shows floating text when a proc starts cooling down and when it is ready again.",
                    getFunc = function() return GetStyle().showAnnouncements ~= false end,
                    setFunc = function(value) GetStyle().showAnnouncements = value == true end,
                    width = "full",
                },
                HexColorPicker("Cooling Down Text Color", "Color of the text shown when a proc goes on cooldown.", "set_active", "3CB043"),
                HexColorPicker("Ready Text Color", "Color of the text shown when a proc is ready again.", "cooldown_expired", "FFFF00"),
                {
                    type = "slider",
                    name = "Announcement Size",
                    tooltip = "Scale of the announcement text.",
                    getFunc = function() return math.max(0.5, math.min(4, EnsureSavedVarsState().labelSize)) end,
                    setFunc = function(size)
                        EnsureSavedVarsState().labelSize = SafeNumber(size, EnsureSavedVarsState().labelSize)
                    end,
                    min = 0.5,
                    max = 4,
                    step = 0.1,
                    clampInput = true,
                    decimals = 1,
                    width = "full",
                    disabled = function() return GetStyle().showAnnouncements == false end,
                },
                {
                    type = "slider",
                    name = "Announcement X Position",
                    tooltip = "Horizontal position of the announcement text.",
                    min = 0,
                    max = screenWidth,
                    step = 10,
                    getFunc = function() return EnsureSavedVarsState().LabelLocation.x end,
                    setFunc = function(value)
                        EnsureSavedVarsState().LabelLocation.x = SafeNumber(value, EnsureSavedVarsState().LabelLocation.x)
                    end,
                    width = "half",
                    disabled = function() return GetStyle().showAnnouncements == false end,
                },
                {
                    type = "slider",
                    name = "Announcement Y Position",
                    tooltip = "Vertical position of the announcement text.",
                    min = 0,
                    max = screenHeight,
                    step = 10,
                    getFunc = function() return EnsureSavedVarsState().LabelLocation.y end,
                    setFunc = function(value)
                        EnsureSavedVarsState().LabelLocation.y = SafeNumber(value, EnsureSavedVarsState().LabelLocation.y)
                    end,
                    width = "half",
                    disabled = function() return GetStyle().showAnnouncements == false end,
                },
            },
        },
    }
    for procType, options in pairs(settingsBreakout) do
        table.insert(optionsTable, {
                type = "submenu",
                name = options.name,
                controls = {
                    {
                        type = "description",
                        text = "Pick a tracked cooldown to move it, resize it, or change its sounds. Everything here is saved account-wide.",
                        width = "full",
                    },
                    {
                        type = "dropdown",
                        name = "Tracked Cooldown",
                        choices = options.data,
                        choicesValues = options.values,
                        getFunc = function()
                            return GetPersistedSelectedSet() or default.set
                        end,
                        setFunc = function(set)
                            SetSelected(procType, set)
                        end,
                        choicesTooltips = options.description,
                        width = "full",
                        scrollable = true,
                        reference = SET_DROPDOWN,
                    },
                    {
                        type = "checkbox",
                        name = "Enable Tracking",
                        tooltip = "Set to ON to enable tracking. Note: Sets will still disable automatically when not worn.",
                        getFunc = function() return GetSelectedEnabled(procType) end,
                        setFunc = function(value) SetSelectedEnabled(procType, value) end,
                        width = "half",
                        disabled = function() return ShouldOptionBeDisabled(procType) end,
                    },
                    {
                        type = "button",
                        name = "Preview Cooldown",
                        tooltip = "Fakes a proc so you can see and hear this tracker counting down. Turn on Show Trackers While In Menus to watch it from here.",
                        func = function()
                            local key = GetValidSelectedKey(procType)
                            local tracking = TrackingRef or PvPCooldownTracker.Tracking
                            if key and tracking and type(tracking.TestProc) == "function" then
                                tracking.TestProc(key)
                            end
                        end,
                        width = "half",
                        disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedEnabled(procType)) end,
                    },
                    {
                        type = "slider",
                        name = "X Position",
                        getFunc = function() return GetSelectedXPos(procType) end,
                        setFunc = function(x) SetSelectedXPos(procType, x) UpdateSelectedAppearance(procType) end,
                        min = 0,
                        max = screenWidth,
                        step = 10,
                        default = 640,
                        clampInput = true,
                        decimals = 0,
                        tooltip = "X Position on screen",
                        width = "half",
                        disabled = function() return ShouldOptionBeDisabled(procType) end,
                    },
                    {
                        type = "slider",
                        name = "Y Position",
                        getFunc = function() return GetSelectedYPos(procType) end,
                        setFunc = function(y) SetSelectedYPos(procType, y) UpdateSelectedAppearance(procType) end,
                        min = 0,
                        max = screenHeight,
                        step = 10,
                        default = 300,
                        clampInput = true,
                        decimals = 0,
                        tooltip = "Y Position on screen",
                        width = "half",
                        disabled = function() return ShouldOptionBeDisabled(procType) end,
                    },
                    {
                        type = "slider",
                        name = "Size",
                        tooltip = "Scale of this tracker.",
                        getFunc = function() return GetSelectedSize(procType) end,
                        setFunc = function(size) SetSelectedSize(procType, size) UpdateSelectedAppearance(procType) end,
                        min = 20,
                        max = 260,
                        step = 2,
                        clampInput = true,
                        decimals = 0,
                        default = 64,
                        width = "full",
                        disabled = function() return ShouldOptionBeDisabled(procType) end,
                    },
                    {
                        type = "checkbox",
                        name = "Play Sound On Proc",
                        tooltip = "Set to ON to play a sound when the set procs.",
                        getFunc = function() return GetSelectedSoundOnProcEnabled(procType) end,
                        setFunc = function(value) SetSelectedSoundOnProcEnabled(procType, value) end,
                        width = "full",
                        disabled = function() return ShouldOptionBeDisabled(procType) end,
                    },
                    {
                        type = "dropdown",
                        name = "Sound On Proc",
                        choices = soundNames,
                        choicesValues = soundOptions,
                        getFunc = function() return GetSelectedSoundOnProc(procType) end,
                        setFunc = function(value) SetSelectedSoundOnProc(procType, value) end,
                        tooltip = "Sound volume based on Interface volume setting.",
                        sort = "name-up",
                        width = "half",
                        scrollable = true,
                        disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnProcEnabled(procType)) end,
                    },
                    {
                        type = "button",
                        name = "Test Sound",
                        func = function() PlaySelectedTestSound(procType, "onProc") end,
                        width = "half",
                        disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnProcEnabled(procType)) end,
                    },
                    {
                        type = "checkbox",
                        name = "Play Sound On Ready",
                        tooltip = "Set to ON to play a sound when the set is off cooldown and ready to proc again.",
                        getFunc = function() return GetSelectedSoundOnReadyEnabled(procType) end,
                        setFunc = function(value) SetSelectedSoundOnReadyEnabled(procType, value) end,
                        width = "full",
                        disabled = function() return ShouldOptionBeDisabled(procType) end,
                    },
                    {
                        type = "dropdown",
                        name = "Sound On Ready",
                        choices = soundNames,
                        choicesValues = soundOptions,
                        getFunc = function() return GetSelectedSoundOnReady(procType) end,
                        setFunc = function(value) SetSelectedSoundOnReady(procType, value) end,
                        tooltip = "Sound volume based on game interface volume setting.",
                        sort = "name-up",
                        width = "half",
                        scrollable = true,
                        disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnReadyEnabled(procType)) end,
                    },
                    {
                        type = "button",
                        name = "Test Sound",
                        func = function() PlaySelectedTestSound(procType, "onReady") end,
                        width = "half",
                        disabled = function() return ShouldOptionBeDisabled(procType, GetSelectedSoundOnReadyEnabled(procType)) end,
                    },
                },
        })
    end

    -- Add a Proc submenu (provided by ProcCapture.lua)
    if PvPCooldownTracker.ProcCapture and type(PvPCooldownTracker.ProcCapture.BuildLAMControls) == "function" then
        table.insert(optionsTable, {
            type     = "submenu",
            name     = "|cFFD27FAdd a Proc|r",
            tooltip  = "Track a proc that just went off, even if the addon does not know it.",
            controls = PvPCooldownTracker.ProcCapture.BuildLAMControls(),
        })
    end

    -- Equipped Set Scanner submenu (provided by EquippedSets.lua)
    if PvPCooldownTracker.EquippedSets and type(PvPCooldownTracker.EquippedSets.BuildLAMControls) == "function" then
        table.insert(optionsTable, {
            type     = "submenu",
            name     = "|c92C843Equipped Set Scanner|r",
            controls = PvPCooldownTracker.EquippedSets.BuildLAMControls(),
        })
    end

    local addonId = PvPCooldownTracker.name or panelData.name or "PvPCooldownTracker"
    if type(addonId) ~= "string" or addonId == "" then
        addonId = "PvPCooldownTracker"
    end

    local lam = LibAddonMenu2
    if type(lam) ~= "table" then
        d((PvPCooldownTracker.prefix or "[PvPCooldownTracker] ") .. "LibAddonMenu-2.0 is not available. Settings panel was not registered.")
        return
    end

    local registerAddonPanel = lam.RegisterAddonPanel
    local registerOptionControls = lam.RegisterOptionControls
    if type(registerAddonPanel) ~= "function" or type(registerOptionControls) ~= "function" then
        d((PvPCooldownTracker.prefix or "[PvPCooldownTracker] ") .. "LibAddonMenu-2.0 API mismatch. Settings panel was not registered.")
        return
    end

    -- Kept so other modules can tell when this panel is the one being opened.
    PvPCooldownTracker.Settings.panel = registerAddonPanel(lam, addonId, panelData)

    registerOptionControls(lam, addonId, optionsTable)

    -- Console builds the menu differently; keep its dropdown lists live too.
    HookConsoleDropdowns(lam, addonId, optionsTable)

    if type(PvPCooldownTracker.Trace) == "function" then
        PvPCooldownTracker:Trace(2, "Finished InitSettings()")
    else
        SafeTrace(2, "Finished InitSettings()")
    end
end

function PvPCooldownTracker.Settings.Upgrade()
    -- v1.1.0 changes setKey names, restore previous user settings
    if PvPCooldownTracker.savedVars.upgradedv110 == nil or not PvPCooldownTracker.savedVars.upgradedv110 then
        local previousSetKeys = {
            ["Lich"] = "Shroud of the Lich",
            ["Olorime"] = "Vestment of Olorime",
            ["Trappings"] = "Trappings of Invigoration",
            ["Warlock"] = "Vestments of the Warlock",
            ["Wyrd"] = "Wyrd Tree's Blessing",
        }

        for previous, new in pairs(previousSetKeys) do
            if PvPCooldownTracker.savedVars.sets[previous] ~= nil then
                PvPCooldownTracker.savedVars.sets[new] = PvPCooldownTracker.savedVars.sets[previous]
                PvPCooldownTracker.savedVars.sets[previous] = nil
            end
        end

        d("[PvPCooldownTracker] Upgraded settings to v1.1.0")
        PvPCooldownTracker.savedVars.upgradedv110 = true
    end

    -- v1.6.0 changes character settings, migrate
    if PvPCooldownTracker.character.upgradedv154 == nil or not PvPCooldownTracker.character.upgradedv154 then

        for key, set in pairs(DataSets or PvPCooldownTracker.Data.Sets) do
            if PvPCooldownTracker.character[key] ~= nil then
                if set.procType == "set" then
                    PvPCooldownTracker.character.set[key] = true
                else
                    -- Unsupported procType
                end

                PvPCooldownTracker.character[key] = nil
            end
        end

        SafeTrace(0, "Upgraded character settings to v1.6.0")
        PvPCooldownTracker.character.upgradedv154 = true
    end
end

