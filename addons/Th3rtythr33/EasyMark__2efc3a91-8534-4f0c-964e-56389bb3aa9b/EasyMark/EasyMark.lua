-- EasyMark
-- Places a group target marker on the unit under your reticle when a trigger fires.
-- A trigger is only watched while it has a marker assigned in the settings menu.

EasyMark = EasyMark or {}
local EM = EasyMark

EM.name = "EasyMark"
EM.version = "1.0.0"
EM.savedVarsName = "EasyMarkSavedVars"
EM.savedVarsVersion = 1

-------------------------------------------------------------------------------
-- Tunables
-------------------------------------------------------------------------------

-- Two weapon swaps within this many milliseconds count as "Swap Weapons Twice".
local DOUBLE_SWAP_WINDOW_MS = 2000

-- How long after a heavy attack begins we treat hit events as part of that
-- same attack. Covers the longest charge plus channeled staff ticks.
local HEAVY_ATTACK_LIFETIME_MS = 3500

-- Hotbar slot that always holds the heavy attack ability.
local HEAVY_ATTACK_SLOT_INDEX = 2

-------------------------------------------------------------------------------
-- Marker choices
-------------------------------------------------------------------------------

-- Names follow the in-game icon art (EsoUI/Art/TargetMarkers).
local MARK_ITEMS =
{
    { name = "None",                data = TARGET_MARKER_TYPE_NONE },
    { name = "1 - Blue Square",     data = TARGET_MARKER_TYPE_ONE },
    { name = "2 - Gold Star",       data = TARGET_MARKER_TYPE_TWO },
    { name = "3 - Green Circle",    data = TARGET_MARKER_TYPE_THREE },
    { name = "4 - Orange Triangle", data = TARGET_MARKER_TYPE_FOUR },
    { name = "5 - Pink Moons",      data = TARGET_MARKER_TYPE_FIVE },
    { name = "6 - Purple Oblivion", data = TARGET_MARKER_TYPE_SIX },
    { name = "7 - Red Weapons",     data = TARGET_MARKER_TYPE_SEVEN },
    { name = "8 - White Skull",     data = TARGET_MARKER_TYPE_EIGHT },
}

local MARK_NAME_BY_TYPE = {}
local MARK_TYPE_BY_NAME = {}
for _, item in ipairs(MARK_ITEMS) do
    MARK_NAME_BY_TYPE[item.data] = item.name
    MARK_TYPE_BY_NAME[item.name] = item.data
end

-------------------------------------------------------------------------------
-- Marking
-------------------------------------------------------------------------------

-- Marks the reticle target. Returns true when the target now carries the
-- marker (either newly assigned or already present), false when there was
-- nothing under the reticle to mark.
local function ApplyMark(markType)
    if markType == nil or markType == TARGET_MARKER_TYPE_NONE then
        return false
    end
    -- The API can only mark whatever is under the reticle right now.
    if not DoesUnitExist("reticleover") then
        return false
    end
    -- Assigning the marker a unit already has removes it, so never toggle it off here.
    if GetUnitTargetMarkerType("reticleover") == markType then
        return true
    end
    AssignTargetMarkerToReticleTarget(markType)
    return true
end

local function FormatUnitName(name)
    if name == nil or name == "" then
        return ""
    end
    return zo_strformat(SI_UNIT_NAME, name)
end

-------------------------------------------------------------------------------
-- Trigger: Heavy Attack
-------------------------------------------------------------------------------
--
-- The marker API only ever targets what is under the reticle at call time, and
-- a heavy attack can finish after the target has drifted out of the reticle.
-- So the marker is placed the moment the heavy attack BEGINS, while the target
-- is still in the reticle. The hit events that arrive later are only used as a
-- fallback for the case where nothing was under the reticle at the start.

-- Fallback list of direct heavy-attack ability IDs, used when the combat event
-- does not carry ACTION_SLOT_TYPE_HEAVY_ATTACK in abilityActionSlotType.
local HEAVY_ATTACK_ABILITY_IDS =
{
    [16041] = true, -- Two Handed
    [15279] = true, -- One Hand and Shield
    [16420] = true, -- Dual Wield
    [16691] = true, -- Bow
    [15383] = true, -- Inferno Staff
    [16261] = true, -- Frost Staff
    [32477] = true, -- Werewolf
}

-- Combat results that mean the heavy attack has started charging or channeling.
local HEAVY_ATTACK_BEGIN_RESULTS =
{
    [ACTION_RESULT_BEGIN] = true,
    [ACTION_RESULT_BEGIN_CHANNEL] = true,
}

-- Combat results that mean the heavy attack actually connected with a target.
local HEAVY_ATTACK_HIT_RESULTS =
{
    [ACTION_RESULT_DAMAGE] = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
    [ACTION_RESULT_DAMAGE_SHIELDED] = true,
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_KILLING_BLOW] = true,
    [ACTION_RESULT_DODGED] = true,
    [ACTION_RESULT_IMMUNE] = true,
    [ACTION_RESULT_MISS] = true,
    [ACTION_RESULT_PARRIED] = true,
    [ACTION_RESULT_REFLECTED] = true,
    [ACTION_RESULT_RESIST] = true,
    [ACTION_RESULT_PARTIAL_RESIST] = true,
    [ACTION_RESULT_ABSORBED] = true,
}

-- State of the heavy attack currently in progress, if any.
local heavyAttack =
{
    startedMs = 0,      -- when the begin event arrived (0 = none in progress)
    marked = false,     -- whether this attack has already placed its marker
}

local function IsHeavyAttackAbility(abilityActionSlotType, abilityId)
    if abilityActionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
        return true
    end
    if HEAVY_ATTACK_ABILITY_IDS[abilityId] then
        return true
    end
    return abilityId ~= 0 and abilityId == GetSlotBoundId(HEAVY_ATTACK_SLOT_INDEX)
end

local function OnCombatEvent(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType,
                             sourceName, sourceType, targetName, targetType, hitValue, powerType,
                             damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError then
        return
    end
    if not IsHeavyAttackAbility(abilityActionSlotType, abilityId) then
        return
    end

    local now = GetGameTimeMilliseconds()
    local markType = EM.sv.marks.heavyAttack

    if HEAVY_ATTACK_BEGIN_RESULTS[result] then
        -- Heavy attack just started: mark whatever is in the reticle right now,
        -- before the player has a chance to turn away.
        heavyAttack.startedMs = now
        heavyAttack.marked = ApplyMark(markType)
        return
    end

    if not HEAVY_ATTACK_HIT_RESULTS[result] then
        return
    end

    -- Hit events for an attack that already marked its target are ignored.
    local inProgress = heavyAttack.startedMs > 0 and (now - heavyAttack.startedMs) <= HEAVY_ATTACK_LIFETIME_MS
    if inProgress and heavyAttack.marked then
        return
    end

    -- Fallback: no begin event was seen, or nothing was in the reticle when the
    -- attack started. Mark on hit if the thing we hit is what we are looking at.
    local hitName = FormatUnitName(targetName)
    if hitName ~= "" and hitName ~= FormatUnitName(GetUnitName("reticleover")) then
        return
    end

    if ApplyMark(markType) then
        heavyAttack.startedMs = now
        heavyAttack.marked = true
    end
end

local HEAVY_ATTACK_EVENT_NAME = EM.name .. "_HeavyAttack"

local function StartHeavyAttackWatcher()
    heavyAttack.startedMs = 0
    heavyAttack.marked = false
    EVENT_MANAGER:RegisterForEvent(HEAVY_ATTACK_EVENT_NAME, EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(HEAVY_ATTACK_EVENT_NAME, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    EVENT_MANAGER:AddFilterForEvent(HEAVY_ATTACK_EVENT_NAME, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_IS_ERROR, false)
end

local function StopHeavyAttackWatcher()
    EVENT_MANAGER:UnregisterForEvent(HEAVY_ATTACK_EVENT_NAME, EVENT_COMBAT_EVENT)
    heavyAttack.startedMs = 0
    heavyAttack.marked = false
end

-------------------------------------------------------------------------------
-- Trigger: Swap Weapons Twice
-------------------------------------------------------------------------------

local lastSwapMs = nil
local lastSwapPair = nil

local function OnWeaponPairChanged(_, activeWeaponPair, locked)
    local now = GetGameTimeMilliseconds()

    if lastSwapMs ~= nil
        and activeWeaponPair ~= lastSwapPair
        and (now - lastSwapMs) <= DOUBLE_SWAP_WINDOW_MS then
        -- Second swap inside the window: fire and reset so a third swap starts fresh.
        lastSwapMs = nil
        lastSwapPair = nil
        ApplyMark(EM.sv.marks.doubleSwap)
        return
    end

    lastSwapMs = now
    lastSwapPair = activeWeaponPair
end

local DOUBLE_SWAP_EVENT_NAME = EM.name .. "_DoubleSwap"

local function StartDoubleSwapWatcher()
    lastSwapMs = nil
    lastSwapPair = nil
    EVENT_MANAGER:RegisterForEvent(DOUBLE_SWAP_EVENT_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPairChanged)
end

local function StopDoubleSwapWatcher()
    EVENT_MANAGER:UnregisterForEvent(DOUBLE_SWAP_EVENT_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
    lastSwapMs = nil
    lastSwapPair = nil
end

-------------------------------------------------------------------------------
-- Trigger: Ability Slot Used (one trigger per slot, one shared watcher)
-------------------------------------------------------------------------------
--
-- EVENT_ACTION_SLOT_ABILITY_USED reports the Lua slot index (3..7 = abilities
-- 1..5, 8 = ultimate) on whichever bar is active. All six slot triggers share a
-- single event registration that stays alive while any of them has a marker.

-- Lua slot indices are one higher than the 0-based engine constants.
local FIRST_ABILITY_SLOT = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local ULTIMATE_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1

local function AbilitySlotKey(slotIndex)
    return "abilitySlot" .. tostring(slotIndex)
end

local function OnActionSlotAbilityUsed(_, actionSlotIndex)
    local markType = EM.sv.marks[AbilitySlotKey(actionSlotIndex)]
    if markType ~= nil then
        ApplyMark(markType)
    end
end

local ABILITY_SLOT_EVENT_NAME = EM.name .. "_AbilitySlot"
local abilitySlotWatcherUsers = 0

local function StartAbilitySlotWatcher()
    abilitySlotWatcherUsers = abilitySlotWatcherUsers + 1
    if abilitySlotWatcherUsers == 1 then
        EVENT_MANAGER:RegisterForEvent(ABILITY_SLOT_EVENT_NAME, EVENT_ACTION_SLOT_ABILITY_USED, OnActionSlotAbilityUsed)
    end
end

local function StopAbilitySlotWatcher()
    abilitySlotWatcherUsers = abilitySlotWatcherUsers - 1
    if abilitySlotWatcherUsers <= 0 then
        abilitySlotWatcherUsers = 0
        EVENT_MANAGER:UnregisterForEvent(ABILITY_SLOT_EVENT_NAME, EVENT_ACTION_SLOT_ABILITY_USED)
    end
end

-- Returns the player's current binding for a slot as text with embedded button
-- icons. The icon markup is resolved by the game for the connected controller,
-- so it shows Xbox glyphs on Xbox and PlayStation glyphs on PS5. In keyboard
-- mode on PC it shows the key name instead.
local KEYBIND_ICON_SCALE_PERCENT = 100

local function GetAbilitySlotKeybindText(slotIndex)
    local actionName
    if ZO_Keybindings_ShouldUseGamepadAction() then
        actionName = "GAMEPAD_ACTION_BUTTON_" .. tostring(slotIndex)
    else
        actionName = "ACTION_BUTTON_" .. tostring(slotIndex)
    end
    local NO_HOLD = false
    local bindingText = ZO_Keybindings_GetHighestPriorityBindingStringFromAction(actionName,
        KEYBIND_TEXT_OPTIONS_FULL_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP, nil, NO_HOLD, KEYBIND_ICON_SCALE_PERCENT)
    if bindingText == nil or bindingText == "" then
        return GetString(SI_ACTION_IS_NOT_BOUND)
    end
    return bindingText
end

local function AbilitySlotDisplayName(slotIndex)
    if slotIndex == ULTIMATE_SLOT then
        return "Ultimate"
    end
    return "Ability " .. tostring(slotIndex - FIRST_ABILITY_SLOT + 1)
end

-------------------------------------------------------------------------------
-- Trigger registry
-------------------------------------------------------------------------------

EM.triggers =
{
    {
        key = "heavyAttack",
        section = "Triggers",
        label = "Heavy Attack",
        tooltip = "Marks the target you are looking at the moment you begin a heavy attack.",
        start = StartHeavyAttackWatcher,
        stop = StopHeavyAttackWatcher,
        active = false,
    },
    {
        key = "doubleSwap",
        section = "Triggers",
        label = "Swap Weapons Twice",
        tooltip = "Marks the target you are looking at when you swap weapon bars twice within two seconds.",
        start = StartDoubleSwapWatcher,
        stop = StopDoubleSwapWatcher,
        active = false,
    },
}

for slotIndex = FIRST_ABILITY_SLOT, ULTIMATE_SLOT do
    local displayName = AbilitySlotDisplayName(slotIndex)
    table.insert(EM.triggers,
    {
        key = AbilitySlotKey(slotIndex),
        section = "Triggers",
        -- Evaluated each time the settings panel draws, so a rebind shows up.
        label = function()
            return string.format("%s  %s", displayName, GetAbilitySlotKeybindText(slotIndex))
        end,
        tooltip = string.format("Marks the target you are looking at when you use %s on either bar.", displayName),
        start = StartAbilitySlotWatcher,
        stop = StopAbilitySlotWatcher,
        active = false,
    })
end

-- Start watchers for triggers that have a marker assigned and stop the rest.
function EM.RefreshWatchers()
    for _, trigger in ipairs(EM.triggers) do
        local markType = EM.sv.marks[trigger.key]
        local wanted = markType ~= nil and markType ~= TARGET_MARKER_TYPE_NONE
        if wanted and not trigger.active then
            trigger.start()
            trigger.active = true
        elseif not wanted and trigger.active then
            trigger.stop()
            trigger.active = false
        end
    end
end

-------------------------------------------------------------------------------
-- Saved variables (account-wide by default, per-character on request)
-------------------------------------------------------------------------------
--
-- Two stores live in the same saved-variable table:
--   EM.svAccount   shared by every character on the account (the default)
--   EM.svCharacter this character's own marks plus the "use mine" flag
-- EM.sv always points at whichever store is active, so the trigger handlers
-- just read EM.sv.marks and never care which one it is.

local function BuildMarkDefaults()
    local marks = {}
    for _, trigger in ipairs(EM.triggers) do
        marks[trigger.key] = TARGET_MARKER_TYPE_NONE
    end
    return marks
end

local function BuildAccountDefaults()
    return { marks = BuildMarkDefaults() }
end

local function BuildCharacterDefaults()
    return { useCharacterSettings = false, marks = BuildMarkDefaults() }
end

-- Guard against saved data from a build with a different trigger list.
local function SanitizeMarks(marks)
    for _, trigger in ipairs(EM.triggers) do
        if MARK_NAME_BY_TYPE[marks[trigger.key]] == nil then
            marks[trigger.key] = TARGET_MARKER_TYPE_NONE
        end
    end
end

local function CopyMarks(from, to)
    for _, trigger in ipairs(EM.triggers) do
        to[trigger.key] = from[trigger.key]
    end
end

local function SelectActiveStore()
    if EM.svCharacter.useCharacterSettings then
        EM.sv = EM.svCharacter
    else
        EM.sv = EM.svAccount
    end
end

local function RefreshSettingsPanel()
    if EM.settingsPanel and EM.settingsPanel.UpdateControls then
        EM.settingsPanel:UpdateControls()
    end
end

-- "Reset to Defaults" clears the marks in whichever store is active. It does
-- not change the account-wide / this-character choice.
local function ResetToDefaults()
    for _, trigger in ipairs(EM.triggers) do
        EM.sv.marks[trigger.key] = TARGET_MARKER_TYPE_NONE
    end
    EM.RefreshWatchers()
end

-------------------------------------------------------------------------------
-- Switching between account-wide and this-character settings
-------------------------------------------------------------------------------

local SWITCH_DIALOG_NAME = "EASYMARK_SWITCH_TO_ACCOUNT_WIDE"

local function FinishSwitchToAccountWide(applyCharacterSettings)
    if applyCharacterSettings then
        CopyMarks(EM.svCharacter.marks, EM.svAccount.marks)
    end
    EM.svCharacter.useCharacterSettings = false
    SelectActiveStore()
    EM.RefreshWatchers()
    RefreshSettingsPanel()
end

local function RegisterSwitchDialog()
    ZO_Dialogs_RegisterCustomDialog(SWITCH_DIALOG_NAME,
    {
        canQueue = true,
        gamepadInfo =
        {
            dialogType = GAMEPAD_DIALOGS.BASIC,
        },
        title =
        {
            text = "EasyMark: Account-Wide Settings",
        },
        mainText =
        {
            text = "This character has its own EasyMark settings.\n\nApply them to the whole account, or discard them and use the existing account-wide settings?",
        },
        buttons =
        {
            {
                keybind = "DIALOG_PRIMARY",
                text = "Apply to Account",
                callback = function()
                    FinishSwitchToAccountWide(true)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = "Discard",
                callback = function()
                    FinishSwitchToAccountWide(false)
                end,
            },
        },
        -- Dismissed without choosing: stay on this-character settings and
        -- redraw so the checkbox reflects that.
        noChoiceCallback = function()
            RefreshSettingsPanel()
        end,
    })
end

local function SetUseCharacterSettings(enabled)
    if enabled == nil or enabled == EM.svCharacter.useCharacterSettings then
        return
    end
    if enabled then
        -- This character starts with a copy of the account-wide settings.
        CopyMarks(EM.svAccount.marks, EM.svCharacter.marks)
        EM.svCharacter.useCharacterSettings = true
        SelectActiveStore()
        EM.RefreshWatchers()
        RefreshSettingsPanel()
    else
        -- Let the player decide what happens to this character's settings.
        ZO_Dialogs_ShowPlatformDialog(SWITCH_DIALOG_NAME)
    end
end

-------------------------------------------------------------------------------
-- Settings menu (LibHarvensAddonSettings)
-------------------------------------------------------------------------------

local function ResolveMarkType(itemName, itemData)
    -- Newer library versions pass the item's data; older ones pass the item table.
    if type(itemData) == "table" then
        itemData = itemData.data
    end
    if itemData ~= nil and MARK_NAME_BY_TYPE[itemData] then
        return itemData
    end
    return MARK_TYPE_BY_NAME[itemName] or TARGET_MARKER_TYPE_NONE
end

local function CreateSettingsMenu()
    if not LibHarvensAddonSettings then
        d("[EasyMark] LibHarvensAddonSettings is missing; the settings menu is unavailable.")
        return
    end

    -- allowRefresh is deliberately NOT set. It is not a refresh-on-show flag
    -- (LHAS re-reads every getter on panel show for free); it means "re-run
    -- every getter whenever any control changes", which nothing here needs.
    -- The scope switch calls UpdateControls() explicitly instead.
    local options =
    {
        allowDefaults = true,
        defaultsFunction = ResetToDefaults,
    }
    local panel = LibHarvensAddonSettings:AddAddon("EasyMark", options)
    if not panel then
        return
    end
    EM.settingsPanel = panel

    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_LABEL,
        label = "Pick a marker for each trigger. A trigger set to None is not watched at all.",
    })

    -- No `default` on purpose: Reset to Defaults must not flip the scope.
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "This character only",
        tooltip = "Off: every character on this account shares the same settings. On: this character keeps its own settings, starting from a copy of the account-wide ones. Turning it off again asks whether to apply this character's settings to the account or discard them.",
        getFunction = function()
            return EM.svCharacter.useCharacterSettings
        end,
        setFunction = SetUseCharacterSettings,
    })

    -- Triggers are listed in registry order; a new section header is emitted
    -- whenever the section name changes.
    local currentSection = nil
    for _, trigger in ipairs(EM.triggers) do
        local key = trigger.key
        if trigger.section ~= currentSection then
            currentSection = trigger.section
            panel:AddSetting({
                type = LibHarvensAddonSettings.ST_SECTION,
                label = currentSection,
            })
        end
        panel:AddSetting({
            type = LibHarvensAddonSettings.ST_DROPDOWN,
            label = trigger.label,
            tooltip = trigger.tooltip,
            items = MARK_ITEMS,
            default = MARK_NAME_BY_TYPE[TARGET_MARKER_TYPE_NONE],
            getFunction = function()
                return MARK_NAME_BY_TYPE[EM.sv.marks[key]] or MARK_NAME_BY_TYPE[TARGET_MARKER_TYPE_NONE]
            end,
            setFunction = function(control, itemName, itemData)
                EM.sv.marks[key] = ResolveMarkType(itemName, itemData)
                EM.RefreshWatchers()
            end,
        })
    end
end

-------------------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= EM.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(EM.name, EVENT_ADD_ON_LOADED)

    EM.svAccount = ZO_SavedVars:NewAccountWide(EM.savedVarsName, EM.savedVarsVersion, nil, BuildAccountDefaults())
    EM.svCharacter = ZO_SavedVars:NewCharacterIdSettings(EM.savedVarsName, EM.savedVarsVersion, nil, BuildCharacterDefaults())
    SanitizeMarks(EM.svAccount.marks)
    SanitizeMarks(EM.svCharacter.marks)
    SelectActiveStore()

    RegisterSwitchDialog()
    CreateSettingsMenu()
    EM.RefreshWatchers()
end

EVENT_MANAGER:RegisterForEvent(EM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
