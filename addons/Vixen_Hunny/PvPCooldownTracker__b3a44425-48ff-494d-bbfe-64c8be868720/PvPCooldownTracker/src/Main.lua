-- -----------------------------------------------------------------------------
-- PvPCooldownTracker - Main.lua
-- Startup, SavedVariables bootstrap, and initialization.
-- -----------------------------------------------------------------------------
PvPCooldownTracker            = PvPCooldownTracker or {}
PvPCooldownTracker.name       = "PvPCooldownTracker"
PvPCooldownTracker.version    = "1.2.1"
PvPCooldownTracker.dbVersion  = 1
PvPCooldownTracker.slash      = "/pvpcooldowntracker"
PvPCooldownTracker.prefix     = "[PvPCooldownTracker] "
PvPCooldownTracker.HUDHidden  = false
PvPCooldownTracker.ForceShow  = false
PvPCooldownTracker.isInCombat = false
PvPCooldownTracker.isDead     = false
PvPCooldownTracker.debugMode  = 0

local EM = EVENT_MANAGER
local STARTUP_RETRY_MS  = 50
local STARTUP_MAX_TRIES = 40

-- -----------------------------------------------------------------------------
-- Debug trace - output when level <= current debug mode
-- 1: Low    - Basic debug info, show core functionality
-- 2: Medium - More information about skills and addon details
-- 3: High   - Everything
-- -----------------------------------------------------------------------------
function PvPCooldownTracker:Trace(debugLevel, ...)
    if (tonumber(debugLevel) or 0) <= (tonumber(self.debugMode) or 0) then
        d(self.prefix .. zo_strformat(...))
    end
end

-- -----------------------------------------------------------------------------
-- ZO_SavedVars containers may be userdata rather than plain tables.
-- This helper accepts both.
-- -----------------------------------------------------------------------------
function PvPCooldownTracker.IsStateContainer(value)
    local t = type(value)
    return value ~= nil and (t == "table" or t == "userdata")
end

-- -----------------------------------------------------------------------------
-- SavedVariables bootstrap
-- Creates or recovers the account-wide and character state tables.
-- -----------------------------------------------------------------------------
function PvPCooldownTracker.EnsureSavedVariables()
    if PvPCooldownTracker.Defaults and type(PvPCooldownTracker.Defaults.Generate) == "function" then
        PvPCooldownTracker.Defaults:Generate()
    end

    local defaults     = PvPCooldownTracker.Defaults
                         and PvPCooldownTracker.Defaults.Get
                         and PvPCooldownTracker.Defaults.Get()
    local charDefaults = PvPCooldownTracker.Defaults
                         and PvPCooldownTracker.Defaults.GetCharacter
                         and PvPCooldownTracker.Defaults.GetCharacter()

    if PvPCooldownTracker.savedVars == nil then
        if type(ZO_SavedVars) == "table" and type(ZO_SavedVars.NewAccountWide) == "function" and defaults then
            PvPCooldownTracker.savedVars = ZO_SavedVars:NewAccountWide(
                "CooldownsVariables1", PvPCooldownTracker.dbVersion, nil, defaults)
        elseif defaults then
            PvPCooldownTracker.savedVars = ZO_DeepTableCopy(defaults)
        else
            PvPCooldownTracker.savedVars = { sets = {} }
        end
    end

    if PvPCooldownTracker.character == nil then
        if type(ZO_SavedVars) == "table" and type(ZO_SavedVars.NewAccountWide) == "function" and charDefaults then
            PvPCooldownTracker.character = ZO_SavedVars:NewAccountWide(
                "CooldownsVariables2AccountWide", PvPCooldownTracker.dbVersion, nil, charDefaults)
        elseif charDefaults then
            PvPCooldownTracker.character = ZO_DeepTableCopy(charDefaults)
        else
            PvPCooldownTracker.character = { set = {} }
        end
    end

    return PvPCooldownTracker.savedVars, PvPCooldownTracker.character
end

-- -----------------------------------------------------------------------------
-- SavedVars version upgrade
-- -----------------------------------------------------------------------------
function PvPCooldownTracker:UpgradeSavedVars()
    local sv = self.savedVars
    local TARGET_VERSION = 2
    local baseDefaults = self.Defaults.Get()

    if not sv.version then sv.version = 1 end

    if sv.version == 1 then
        d(self.prefix .. "Upgrading SavedVariables from v1 to v2...")
        for setKey, saved in pairs(sv.sets or {}) do
            local defs = baseDefaults.sets[setKey] or {}
            if saved.texture == nil then saved.texture = defs.texture or "EsoUI/Art/Icons/icon_missing.dds" end
            if saved.label    == nil then saved.label   = defs.label   or setKey end
            if saved.cooldown == nil then saved.cooldown = defs.cooldown or true end
        end
        sv.version = 2
    end

    if sv.version < TARGET_VERSION then
        sv.version = TARGET_VERSION
    end
end

-- -----------------------------------------------------------------------------
-- Merge missing defaults into SavedVars
-- -----------------------------------------------------------------------------
function PvPCooldownTracker:SanitizeSavedVars()
    local defaults = self.Defaults.Get()
    local sv  = self.savedVars
    local ISC = self.IsStateContainer

    local function MergeMissing(target, source)
        if type(target) ~= "table" or type(source) ~= "table" then return target end
        for k, v in pairs(source) do
            if target[k] == nil then
                target[k] = type(v) == "table" and ZO_DeepTableCopy(v) or v
            elseif type(v) == "table" then
                if type(target[k]) ~= "table" then
                    target[k] = ZO_DeepTableCopy(v)
                else
                    MergeMissing(target[k], v)
                end
            end
        end
        return target
    end

    MergeMissing(sv, {
        cooldown_expired  = defaults.cooldown_expired,
        set_active        = defaults.set_active,
        unlocked          = defaults.unlocked,
        snapToGrid        = defaults.snapToGrid,
        gridSize          = defaults.gridSize,
        showOutsideCombat = defaults.showOutsideCombat,
        lagCompensation   = defaults.lagCompensation,
        procCapture       = defaults.procCapture,
        procCaptureMode   = defaults.procCaptureMode,
        size              = defaults.size,
        labelSize         = defaults.labelSize,
        labelFont         = defaults.labelFont,
        timerFont         = defaults.timerFont,
        LabelLocation     = defaults.LabelLocation,
        TextureLocation   = defaults.TextureLocation,
        sounds            = defaults.sounds,
        style             = defaults.style,
        customSetData     = defaults.customSetData,
    })

    if not ISC(sv.sets) then sv.sets = {} end

    -- ZO_SavedVars may return the defaults reference via __index for
    -- sub-tables.  Force a deep-copy into rawData so writes persist to disk.
    sv.sets            = ZO_DeepTableCopy(sv.sets)
    sv.sounds          = type(sv.sounds) == "table" and ZO_DeepTableCopy(sv.sounds) or ZO_DeepTableCopy(defaults.sounds)
    sv.LabelLocation   = type(sv.LabelLocation) == "table" and ZO_DeepTableCopy(sv.LabelLocation) or ZO_DeepTableCopy(defaults.LabelLocation)
    sv.TextureLocation = type(sv.TextureLocation) == "table" and ZO_DeepTableCopy(sv.TextureLocation) or ZO_DeepTableCopy(defaults.TextureLocation)

    local screenW, screenH = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    for key, defaultSet in pairs(defaults.sets) do
        local saved = sv.sets[key]
        if not ISC(saved) then
            sv.sets[key] = ZO_ShallowTableCopy(defaultSet)
            saved = sv.sets[key]
        end
        if not saved.x or saved.x < 0 or saved.x > screenW then saved.x = defaultSet.x end
        if not saved.y or saved.y < 0 or saved.y > screenH then saved.y = defaultSet.y end
        if not saved.size or saved.size < 16                then saved.size = defaultSet.size end
        saved.sounds = MergeMissing(saved.sounds or {}, defaultSet.sounds)
    end

    if not sv.labelFont then sv.labelFont = defaults.labelFont end
    if not sv.timerFont then sv.timerFont = defaults.timerFont end

    if not ISC(sv.style) then
        sv.style = ZO_DeepTableCopy(defaults.style)
    else
        for k, v in pairs(defaults.style) do
            if sv.style[k] == nil then
                sv.style[k] = type(v) == "table" and ZO_DeepTableCopy(v) or v
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- Startup scan: enable tracking for equipped sets that aren't manually disabled
-- -----------------------------------------------------------------------------
local function RefreshTrackedEquippedSets()
    local ES = PvPCooldownTracker.EquippedSets
    local TK = PvPCooldownTracker.Tracking
    if not (ES and type(ES.Scan) == "function") then return end
    if not (TK and type(TK.EnableTrackingForSet) == "function") then return end

    local results = ES.Scan()
    if type(results) ~= "table" or type(results.found) ~= "table" then return end

    local ISC   = PvPCooldownTracker.IsStateContainer
    local count = 0
    for _, entry in ipairs(results.found) do
        local name = entry and entry.setName
        local disabled = PvPCooldownTracker.character
            and ISC(PvPCooldownTracker.character.set)
            and PvPCooldownTracker.character.set[name] == false
        if type(name) == "string" and name ~= "" and not disabled then
            TK.EnableTrackingForSet(name, true)
            count = count + 1
        end
    end

    if count > 0 then
        d(PvPCooldownTracker.prefix .. string.format("Enabled %d equipped tracked set(s).", count))
    end
end

-- -----------------------------------------------------------------------------
-- Module readiness check
-- -----------------------------------------------------------------------------
local function HasRequiredModules()
    local PCT = PvPCooldownTracker
    return type(PCT.Data) == "table"
        and type(PCT.Data.Sets) == "table"
        and type(PCT.Defaults) == "table"
        and type(PCT.Settings) == "table"
        and type(PCT.Settings.Init) == "function"
        and type(PCT.UI) == "table"
end

-- -----------------------------------------------------------------------------
-- Core initialization (called once all modules are ready)
-- -----------------------------------------------------------------------------
local function FinishInitialize(addonId)
    if PvPCooldownTracker.initialized then return end
    PvPCooldownTracker.initialized = true
    PvPCooldownTracker.name = addonId

    local PCT = PvPCooldownTracker
    PCT:Trace(1, "PvPCooldownTracker Loaded")

    -- Reset runtime state on all sets
    for _, set in pairs(PCT.Data.Sets) do
        set.enabled     = false
        set.onCooldown  = false
        set.timeOfProc  = 0
        set.justProcced = false
    end

    -- Bootstrap SavedVariables
    PCT.Defaults:Generate()
    PCT.savedVars, PCT.character = PCT.EnsureSavedVariables()

    -- Migrate legacy per-character SavedVars to account-wide
    local legacyChar = ZO_SavedVars:New(
        "CooldownsVariables2", PCT.dbVersion, nil, PCT.Defaults.GetCharacter())
    if not PCT.character.migratedFromCharacterWide then
        if not PCT.IsStateContainer(PCT.character.set) then
            PCT.character.set = {}
        end
        if type(legacyChar) == "table" and type(legacyChar.set) == "table" then
            for setKey, enabled in pairs(legacyChar.set) do
                if PCT.character.set[setKey] == nil then
                    PCT.character.set[setKey] = enabled
                end
            end
        end
        PCT.character.upgradedv154 = PCT.character.upgradedv154
            or (type(legacyChar) == "table" and legacyChar.upgradedv154)
            or false
        PCT.character.migratedFromCharacterWide = true
    end

    -- Materialize character sub-tables so writes land in rawData
    if PCT.character ~= nil then
        PCT.character.set = type(PCT.character.set) == "table"
            and ZO_DeepTableCopy(PCT.character.set) or {}
    end

    PCT:UpgradeSavedVars()

    if PCT.Settings and type(PCT.Settings.Upgrade) == "function" then
        PCT.Settings.Upgrade()
    end

    -- Restore custom sets from SavedVars
    if PCT.EquippedSets and type(PCT.EquippedSets.RestoreCustomSets) == "function" then
        local count = PCT.EquippedSets.RestoreCustomSets()
        if count > 0 then
            d(PCT.prefix .. string.format("Restored %d custom set(s) from SavedVariables.", count))
        end
    end

    PCT:SanitizeSavedVars()

    -- One-time move to the 1.2 look. Colours were not editable before 1.2, so
    -- anything saved earlier is just the old default palette.
    if PCT.savedVars.styleVersion ~= 2 then
        PCT.UI.ApplyTheme("Ember")
        PCT.savedVars.styleVersion = 2
    end

    PCT.debugMode = PCT.savedVars.debugMode or 0

    SLASH_COMMANDS[PCT.slash] = PCT.UI.SlashCommand
    PCT.isInCombat = IsUnitInCombat("player")
    PCT.isDead     = IsUnitDead("player")

    -- Settings panel
    PCT.Settings.Init()

    -- Tracking events
    if PCT.Tracking and type(PCT.Tracking.RegisterEvents) == "function" then
        PCT.Tracking.RegisterEvents()
    end

    -- Combat event filter
    EM:AddFilterForEvent(addonId .. "_1234", EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    -- Equipment bonus library
    local LEB = LibEquipmentBonus
    if LEB and type(LEB.Init) == "function"
        and PCT.Tracking and type(PCT.Tracking.EnableTrackingForSet) == "function" then
        local Equip = LEB:Init(addonId)
        if Equip and type(Equip.Register) == "function" then
            Equip:Register(PCT.Tracking.EnableTrackingForSet)
        end
    end

    RefreshTrackedEquippedSets()

    -- Player-added procs are not tied to gear, so they are always tracked.
    -- Then start recording recent procs for the "Add a Proc" menu.
    if PCT.ProcCapture then
        PCT.ProcCapture.EnableUserProcs()
        PCT.ProcCapture.Init()
    end

    -- Initial HUD state
    if PCT.UI and type(PCT.UI.ToggleHUD) == "function" then
        PCT.UI.ToggleHUD()
    end
    if PCT.UI and type(PCT.UI.SetCombatStateDisplay) == "function" then
        PCT.UI:SetCombatStateDisplay()
    end

    PCT:Trace(2, "Finished Initialize()")
end

-- -----------------------------------------------------------------------------
-- EVENT_ADD_ON_LOADED handler
-- -----------------------------------------------------------------------------
function PvPCooldownTracker.Initialize(_, addonName)
    local addonId = PvPCooldownTracker.name
    if addonName ~= addonId then return end

    EM:UnregisterForEvent(addonId, EVENT_ADD_ON_LOADED)

    if HasRequiredModules() then
        FinishInitialize(addonId)
        return
    end

    -- Deferred startup: wait for modules to become available
    d(PvPCooldownTracker.prefix .. "Deferring startup until required modules are ready.")
    local attempts = 0
    EM:RegisterForUpdate(addonId .. "_StartupRetry", STARTUP_RETRY_MS, function()
        attempts = attempts + 1
        if HasRequiredModules() then
            EM:UnregisterForUpdate(addonId .. "_StartupRetry")
            FinishInitialize(addonId)
        elseif attempts >= STARTUP_MAX_TRIES then
            EM:UnregisterForUpdate(addonId .. "_StartupRetry")
            d(PvPCooldownTracker.prefix .. "Startup failed: required modules never became available.")
        end
    end)
end

-- -----------------------------------------------------------------------------
-- Event hook
-- -----------------------------------------------------------------------------
EM:RegisterForEvent(PvPCooldownTracker.name, EVENT_ADD_ON_LOADED, PvPCooldownTracker.Initialize)
