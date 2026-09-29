-- DarkConvergenceTracker
-- Displays a countdown to when the Dark Convergence 5-piece set will next be
-- able to proc, visible only while 5 pieces are equipped and the internal
-- cooldown (ICD) is active. Shows "DC Ready!" in the box, and optionally
-- plays a sound, when the countdown reaches zero.

local ADDON_NAME = "DarkConvergenceTracker"
local ADDON_VERSION = 1
local ADDON_DISPLAY_VERSION = "1.0.2"

local DCTracker = {}
local addon = DCTracker

local DARK_CONVERGENCE_ICD_ABILITY_ID = 159388

-- Dark Convergence's set ID, used to count equipped pieces via
-- GetItemLinkSetInfo. (Sourced from itemLink data rather than the localized
-- set name, so this isn't affected by client language.)
local DARK_CONVERGENCE_SET_ID = 616

local ICD_DURATION_SECONDS = 25
local DEFAULT_READY_MESSAGE_DURATION_SECONDS = 2
local DEFAULT_READY_SOUND_KEY = "NONE"

-- Curated shortlist of built-in ESO sounds (verified against the game's own
-- SOUNDS table, esoui/libraries/globals/soundids.lua) offered as ready-alert
-- options. "NONE" is a sentinel handled specially -- it isn't a real SOUNDS key.
local READY_SOUND_CHOICES = {
    { display = "<No Sound>", key = "NONE" },
    { display = "Ultimate Ready", key = "ABILITY_ULTIMATE_READY" },
    { display = "Synergy Ready", key = "ABILITY_SYNERGY_READY" },
    { display = "New Notification", key = "NEW_NOTIFICATION" },
    { display = "Timed Notification", key = "NEW_TIMED_NOTIFICATION" },
    { display = "Achievement Awarded", key = "ACHIEVEMENT_AWARDED" },
    { display = "Duel Start", key = "DUEL_START" },
}

local defaults = {
    lockPosition = false,
    readyMessageDurationSeconds = DEFAULT_READY_MESSAGE_DURATION_SECONDS,
    readySoundKey = DEFAULT_READY_SOUND_KEY,
}

-- LAM2's dropdown wants two parallel arrays: display strings and the values
-- passed to setFunc. Derived here once from READY_SOUND_CHOICES so the
-- curated list only needs to be edited in one place.
local readySoundChoiceDisplayNames = {}
local readySoundChoiceKeys = {}
for _, choice in ipairs(READY_SOUND_CHOICES) do
    table.insert(readySoundChoiceDisplayNames, choice.display)
    table.insert(readySoundChoiceKeys, choice.key)
end

local positionDefaults = {
    point = CENTER,
    relativePoint = CENTER,
    offsetX = 0,
    offsetY = 220,
}

-- Box is square, sized to the original box's height. Resizing works directly
-- in raw pixel dimensions (not via SetScale -- see ApplySavedSize for why).
local BASE_WIDTH = 80
local BASE_HEIGHT = 80
local MIN_SIZE = 61
local MAX_SIZE = 120

-- Countdown number font: 36pt at/below the default box size (BASE_WIDTH),
-- scaling up proportionally only when the box is sized larger than default.
-- Same family/weight as ZoFontWinT1 (confirmed as $(BOLD_FONT)|18|soft-shadow-thin),
-- just at an explicit size so it can scale.
local BASE_NUMBER_FONT_SIZE = 36

-- "DC Ready!" gets its own fixed, smaller font (matching ZoFontWinT1's
-- original confirmed size) independent of the number font/box size, since it
-- needs to fit legibly in the fixed-size message box regardless of how large
-- the user has sized the countdown display.
local READY_MESSAGE_FONT = "$(BOLD_FONT)|18|soft-shadow-thin"

-- The "DC Ready!" text needs more room than the square box provides at most
-- sizes, so it's temporarily displayed at this fixed size regardless of the
-- user's chosen box size, then the box reverts to the user's saved size
-- afterward.
local READY_MESSAGE_WIDTH = 170
local READY_MESSAGE_HEIGHT = 80

local window, countdownText = nil, nil

-- Forward declaration: defined later in the "Window setup" section, but
-- referenced earlier by ShowReadyMessage(). Without this, that reference
-- would resolve to a nonexistent global instead of this local, and calling
-- it would fail with "function expected instead of nil".
local ApplySavedSize

--------------------------------------------------------------------------------
-- Gear check
--------------------------------------------------------------------------------

local EQUIP_SLOTS_TO_CHECK = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

-- Returns the number of equipped Dark Convergence pieces currently
-- contributing toward the set bonus, per the game's own accounting (so this
-- naturally respects whatever rules the engine applies re: active vs. backup
-- bar weapons).
local function GetDarkConvergencePieceCount()
    for _, slotId in ipairs(EQUIP_SLOTS_TO_CHECK) do
        local itemLink = GetItemLink(BAG_WORN, slotId, LINK_STYLE_DEFAULT)
        if itemLink and itemLink ~= "" then
            local hasSet, setName, numBonuses, numNormalEquipped, maxEquipped, setId, numPerfectedEquipped = GetItemLinkSetInfo(itemLink, true)
            if hasSet and setId == DARK_CONVERGENCE_SET_ID then
                return (numNormalEquipped or 0) + (numPerfectedEquipped or 0)
            end
        end
    end
    return 0
end

--------------------------------------------------------------------------------
-- Countdown state machine
--------------------------------------------------------------------------------

local TIMER_UPDATE_NAME = ADDON_NAME .. "Timer"
local TIMER_UPDATE_INTERVAL_MS = 250

-- nil = not currently on cooldown. Otherwise the GetFrameTimeSeconds() value
-- at which the ICD will expire.
addon.icdEndTime = nil

-- True while the "DC Ready!" flash is being displayed, so other refresh
-- triggers (gear changes, EVENT_PLAYER_ACTIVATED) can't cut it short.
addon.showingReadyMessage = false

local function StopTimerLoop()
    EVENT_MANAGER:UnregisterForUpdate(TIMER_UPDATE_NAME)
end

-- Plays the user's chosen ready sound, if any. "NONE" (the default) plays
-- nothing. This runs independently of the message duration setting -- a
-- sound can be selected even if the message itself is turned off.
local function PlayReadySound()
    local soundKey = addon.savedVariables.readySoundKey
    if soundKey and soundKey ~= "NONE" and SOUNDS[soundKey] then
        PlaySound(SOUNDS[soundKey])
    end
end

-- Shows the box (with a placeholder "0") when preview mode is on, or hides
-- it otherwise. Used anywhere the real countdown isn't active/eligible to
-- display, so the box stays available for dragging/resizing on demand even
-- when Dark Convergence genuinely isn't on cooldown.
local function RefreshHiddenState()
    if addon.previewEnabled then
        window:SetHidden(false)
        countdownText:SetText("0")
    else
        window:SetHidden(true)
        countdownText:SetText("")
    end
end

-- Temporarily grows the box to fit "DC Ready!" regardless of the user's
-- chosen size, shows the message for the user-configured duration, then
-- reverts to the user's saved size and falls back to whatever
-- RefreshHiddenState() would normally show.
local function ShowReadyMessage()
    addon.showingReadyMessage = true

    window:SetHidden(false)
    window:SetDimensions(READY_MESSAGE_WIDTH, READY_MESSAGE_HEIGHT)
    countdownText:SetFont(READY_MESSAGE_FONT)
    countdownText:SetText("DC Ready!")

    local durationMs = addon.savedVariables.readyMessageDurationSeconds * 1000

    zo_callLater(function()
        addon.showingReadyMessage = false
        ApplySavedSize()
        RefreshHiddenState()
    end, durationMs)
end

local function RefreshDisplay()
    if addon.showingReadyMessage then
        -- Let the flash finish undisturbed; it reverts itself on its own timer.
        return
    end

    if addon.icdEndTime == nil then
        RefreshHiddenState()
        return
    end

    local remaining = addon.icdEndTime - GetFrameTimeSeconds()

    if remaining <= 0 then
        -- ICD has genuinely expired. Clear state unconditionally so a later
        -- gear change can't cause a stale ready flash/sound long after the
        -- real expiration moment. Only actually announce it if the player is
        -- wearing 5 pieces right now -- otherwise the set isn't really ready
        -- to use.
        addon.icdEndTime = nil
        StopTimerLoop()
        local pieceCountAtExpiry = GetDarkConvergencePieceCount()
        if pieceCountAtExpiry >= 5 then
            PlayReadySound()
            if addon.savedVariables.readyMessageDurationSeconds > 0 then
                ShowReadyMessage()
            else
                RefreshHiddenState()
            end
        else
            RefreshHiddenState()
        end
        return
    end

    if GetDarkConvergencePieceCount() < 5 then
        RefreshHiddenState()
        return
    end

    window:SetHidden(false)
    countdownText:SetText(tostring(math.ceil(remaining)))
end

local function OnTimerUpdate()
    RefreshDisplay()
end

local function StartCountdown()
    -- Debounce: a genuinely new proc can't happen while the ICD is already
    -- active, so a trigger arriving mid-countdown is either a duplicate event
    -- from the same proc hitting multiple enemies, or otherwise not something
    -- we should act on. This also means we don't need any separate
    -- multi-target handling.
    if addon.icdEndTime ~= nil then return end

    if GetDarkConvergencePieceCount() < 5 then
        -- Shouldn't normally happen (the set can't proc without 5 pieces),
        -- but skip defensively rather than start a countdown that shouldn't exist.
        return
    end

    addon.icdEndTime = GetFrameTimeSeconds() + ICD_DURATION_SECONDS
    RefreshDisplay()
    EVENT_MANAGER:RegisterForUpdate(TIMER_UPDATE_NAME, TIMER_UPDATE_INTERVAL_MS, OnTimerUpdate)
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

local function OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    -- No self-check needed here: REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE with
    -- COMBAT_UNIT_TYPE_PLAYER (set up below) already restricts this callback
    -- to events sourced specifically by the local player. COMBAT_UNIT_TYPE_PLAYER,
    -- COMBAT_UNIT_TYPE_GROUP, and COMBAT_UNIT_TYPE_PLAYER_PET are distinct
    -- categories, so a group member's proc would never reach this callback
    -- in the first place -- an earlier version of this code redundantly
    -- re-checked the source name here, which was both unnecessary and wasteful.
    StartCountdown()
end

local function OnGearChanged(eventCode, bagId, slotIndex)
    -- No bagId check needed here: REGISTER_FILTER_BAG_ID with BAG_WORN (set
    -- up below) already restricts this callback to worn-equipment changes.
    -- A gear swap can't start or stop the underlying ICD, but it can change
    -- whether we're allowed to *display* an in-progress countdown, so just
    -- re-evaluate rather than touching icdEndTime here.
    RefreshDisplay()
end

local function OnPlayerActivated(eventCode)
    RefreshDisplay()
end

--------------------------------------------------------------------------------
-- Window setup (position, lock/unlock, resize) -- mirrors Blood Hunger Tracker
--------------------------------------------------------------------------------

local function ApplySavedPosition()
    local pv = addon.positionVariables

    if type(pv.point) ~= "number" or type(pv.relativePoint) ~= "number" then
        pv.point = positionDefaults.point
        pv.relativePoint = positionDefaults.relativePoint
        pv.offsetX = positionDefaults.offsetX
        pv.offsetY = positionDefaults.offsetY
    end

    window:ClearAnchors()
    window:SetAnchor(pv.point, GuiRoot, pv.relativePoint, pv.offsetX, pv.offsetY)
end

-- Countdown number font scales proportionally once the box is sized above
-- BASE_WIDTH (default), and stays at the base size at or below default --
-- per the request to only grow it "when and if the box size is increased
-- beyond the default."
local function ApplyNumberFont(boxSize)
    local fontSize = BASE_NUMBER_FONT_SIZE
    if boxSize > BASE_WIDTH then
        fontSize = math.floor(BASE_NUMBER_FONT_SIZE * (boxSize / BASE_WIDTH))
    end
    countdownText:SetFont("$(BOLD_FONT)|" .. fontSize .. "|soft-shadow-thin")
end

function ApplySavedSize()
    local pv = addon.positionVariables

    if type(pv.size) ~= "number" then
        pv.size = BASE_WIDTH
    end

    window:SetDimensions(pv.size, pv.size)
    -- Restores the correctly-scaled number font too -- this matters not just
    -- on load, but also when ShowReadyMessage() reverts after its flash,
    -- since that revert calls this same function.
    ApplyNumberFont(pv.size)
end

local function OnResizeStop(control)
    local width, height = control:GetDimensions()

    -- Force square by taking the larger of the two dragged dimensions, then
    -- clamp to the allowed range. Working directly in raw pixel dimensions
    -- (rather than deriving a SetScale factor and resetting raw dimensions
    -- back to BASE_WIDTH/HEIGHT every time) keeps what's on screen and what
    -- the next drag starts from always in sync -- the previous scale-based
    -- approach caused the box to visually lag behind the raw size during a
    -- drag, requiring several separate drags to reach the far end of the
    -- range.
    local size = zo_max(width, height)
    size = zo_clamp(size, MIN_SIZE, MAX_SIZE)

    control:SetDimensions(size, size)
    ApplyNumberFont(size)

    addon.positionVariables.size = size
end

local function ApplyLockState()
    local locked = addon.savedVariables.lockPosition
    window:SetMovable(not locked)
    window:SetMouseEnabled(not locked)
end

local function OnMoveStop()
    local isValid, point, _, relativePoint, offsetX, offsetY = window:GetAnchor(0)
    if not isValid then return end
    local pv = addon.positionVariables
    pv.point = point
    pv.relativePoint = relativePoint
    pv.offsetX = offsetX
    pv.offsetY = offsetY
end

--------------------------------------------------------------------------------
-- Settings panel (LibAddonMenu-2.0, required)
--------------------------------------------------------------------------------

function addon:InitializeSettings()
    -- No existence check needed here: LibAddonMenu-2.0 is a required
    -- dependency (## DependsOn in the manifest), so this addon cannot load
    -- at all unless LAM2 is already present -- checking for it here was
    -- dead code.
    local LAM = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = "Dark Convergence Tracker",
        author = "Irreverend",
        version = ADDON_DISPLAY_VERSION,
        registerForRefresh = true,
    }

    local optionsData = {
        {
            type = "dropdown",
            name = "'DC Ready!' Sound",
            tooltip = "Plays when the cooldown finishes, independently of the message duration above. Selecting an option here previews it immediately.",
            choices = readySoundChoiceDisplayNames,
            choicesValues = readySoundChoiceKeys,
            getFunc = function() return addon.savedVariables.readySoundKey end,
            setFunc = function(value)
                addon.savedVariables.readySoundKey = value
                if value ~= "NONE" and SOUNDS[value] then
                    PlaySound(SOUNDS[value])
                end
            end,
            default = DEFAULT_READY_SOUND_KEY,
        },
        {
            type = "slider",
            name = "'DC Ready!' Message Duration (Seconds, 0 = Off)",
            tooltip = "How long the box shows \"DC Ready!\" when the cooldown finishes. 1-60 seconds, or 0 to skip the ready message entirely.",
            min = 0,
            max = 60,
            step = 1,
            getFunc = function() return addon.savedVariables.readyMessageDurationSeconds end,
            setFunc = function(value)
                addon.savedVariables.readyMessageDurationSeconds = value
            end,
            default = DEFAULT_READY_MESSAGE_DURATION_SECONDS,
        },
        {
            type = "checkbox",
            name = "Preview Position/Size",
            tooltip = "Temporarily shows the box with a placeholder value so you can drag or resize it even when Dark Convergence isn't on cooldown. Not saved between sessions.",
            getFunc = function() return addon.previewEnabled end,
            setFunc = function(value)
                addon.previewEnabled = value
                RefreshDisplay()
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = "Lock Position",
            tooltip = "Lock the display so it can no longer be dragged.",
            getFunc = function() return addon.savedVariables.lockPosition end,
            setFunc = function(value)
                addon.savedVariables.lockPosition = value
                ApplyLockState()
            end,
            default = defaults.lockPosition,
        },
        {
            type = "button",
            name = "Reset Position",
            tooltip = "Move the display back to the default screen position for this character.",
            func = function()
                local pv = addon.positionVariables
                pv.point = positionDefaults.point
                pv.relativePoint = positionDefaults.relativePoint
                pv.offsetX = positionDefaults.offsetX
                pv.offsetY = positionDefaults.offsetY
                ApplySavedPosition()
            end,
        },
        {
            type = "button",
            name = "Reset Size",
            tooltip = "Reset the display back to its default size for this character.",
            func = function()
                addon.positionVariables.size = BASE_WIDTH
                ApplySavedSize()
            end,
        },
    }

    local panel = LAM:RegisterAddonPanel(ADDON_NAME .. "Options", panelData)
    LAM:RegisterOptionControls(ADDON_NAME .. "Options", optionsData)

    -- When the settings panel is closed (menu left, or a different addon's
    -- panel selected), turn Preview off automatically so the box doesn't
    -- linger visible once the user is done configuring it.
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(closedPanel)
        if closedPanel ~= panel then return end
        addon.previewEnabled = false
        RefreshDisplay()
    end)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function OnAddonLoaded(eventCode, loadedAddonName)
    if loadedAddonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    addon.savedVariables = ZO_SavedVars:NewAccountWide(ADDON_NAME .. "SavedVariables", ADDON_VERSION, nil, defaults, GetWorldName())
    addon.positionVariables = ZO_SavedVars:NewCharacterIdSettings(ADDON_NAME .. "Position", ADDON_VERSION, nil, positionDefaults)
    addon.icdEndTime = nil
    addon.showingReadyMessage = false
    addon.previewEnabled = false

    window = DarkConvergenceTracker_Window
    countdownText = DarkConvergenceTracker_WindowCountdownText

    ApplySavedPosition()
    ApplySavedSize()
    ApplyLockState()

    window:SetHandler("OnMoveStop", OnMoveStop)
    window:SetHandler("OnResizeStop", OnResizeStop)

    addon:InitializeSettings()

    local combatEventNamespace = ADDON_NAME .. "_CombatEvent"
    EVENT_MANAGER:RegisterForEvent(combatEventNamespace, EVENT_COMBAT_EVENT, OnCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(combatEventNamespace, EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID, DARK_CONVERGENCE_ICD_ABILITY_ID,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnGearChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_WORN)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

    RefreshDisplay()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
