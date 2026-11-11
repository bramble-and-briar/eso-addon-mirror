-- -----------------------------------------------------------------------------
-- HUDitorTools - register ZOS HUD controls that stock Edit HUD does not.
-- HUD_MANAGER:RegisterKeyboardElement / RegisterGamepadElement
-- (EsoUI/Ingame/HUD/HUDManager.lua).
-- ZO_HUDManager_Element:Initialize (HUDManager.lua 25-37) requires one primary
-- anchor, no secondary anchor, and control.hudElementRef.
-- The ref matches ZO_HUDManager_Element in HUDManager.xml 9-13: excluded from
-- resize-to-fit, and overridden when the control rect is not the drawn element.
-- SetAnchorFill() fills a parent that already has a size (ZO_TimerBar.lua 296).
-- Keyboard and gamepad each get their own ZO_Anchor. CompassFrame.lua 125-126
-- does the same. primaryAnchorPoint is taken from that anchor at init
-- (HUDManager.lua 44-49).
-- PreLoadSettings fires before ZO_HUDManager saved vars load (HUDManager.lua
-- 300-315). Controls created later are registered on EVENT_PLAYER_ACTIVATED.
-- ZO_ActivityTracker is already registered by ZO_HUDTracker_Base:Initialize
-- (HUDTracker_Base.lua 33-77, ActivityTracker.lua 41-47 and 102). Do not add it.
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local windowManager = GetWindowManager()
local eventManager = GetEventManager()

local preloadCallbackInstalled = false
local playerActivatedCallbackInstalled = false
local playerProgressAnchorRestoreInstalled = false

-- PlayerProgressBar.xml 81 and 108. Both keyboard templates use this anchor.
local PLAYER_PROGRESS_KEYBOARD_OFFSET_X = 15
local PLAYER_PROGRESS_KEYBOARD_OFFSET_Y = 10
-- ZO_PlayerProgressBar_Gamepad.xml 74.
local PLAYER_PROGRESS_GAMEPAD_OFFSET_X = -98
local PLAYER_PROGRESS_GAMEPAD_OFFSET_Y = -53
-- ZO_PlayerProgressBar_Gamepad.xml 101.
local PLAYER_PROGRESS_GAMEPAD_CHAMPION_OFFSET_X = -135
local PLAYER_PROGRESS_GAMEPAD_CHAMPION_OFFSET_Y = -53
-- ObjectiveCaptureMeter.xml 35-39. Keyboard offset is
-- ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y (CommonConstants.lua 4).
local OBJECTIVE_CAPTURE_METER_GAMEPAD_OFFSET_Y = -270
-- ObjectiveCaptureMeter.xml 51-53. Background, bar, and frame are this size.
local OBJECTIVE_CAPTURE_METER_SIZE = 128
-- Reticle.xml 48-50.
local STEALTH_ICON_SIZE = 64

local function GetOrCreateHudElementRef(control)
    if control.hudElementRef then
        return control.hudElementRef
    end

    local existingRef = control:GetNamedChild("HUDElementRef")
    if existingRef then
        control.hudElementRef = existingRef
        return existingRef
    end

    local ref = windowManager:CreateControl(control:GetName() .. "HUDElementRef", control, CT_CONTROL)
    ref:SetExcludeFromResizeToFitExtents(true)
    ref:ClearAnchors()
    local controlName = control:GetName()
    if controlName == "ZO_ObjectiveCaptureMeter" then
        -- ObjectiveCaptureMeter.xml 48-53. The meter has no dimensions. The
        -- drawn piece is the 128 background, anchored BOTTOM. ZO_ObjectiveCapture
        -- stays hidden (line 42) until a capture. GetDimensions on a ref that is
        -- only sized by anchors stays 0 then, and the editor box is a cross.
        -- GetConvertedRefControlAnchorInfo reads GetDimensions (HUDManager.lua 110).
        ref:SetAnchor(BOTTOM, control, BOTTOM)
        ref:SetDimensions(OBJECTIVE_CAPTURE_METER_SIZE, OBJECTIVE_CAPTURE_METER_SIZE)
    elseif controlName == "ZO_ReticleContainerStealthIcon" then
        -- Reticle.xml 46-50 and 57. The container has no dimensions. The eye is
        -- 64, anchored CENTER. The reticle stays hidden, so an anchor-sized ref
        -- reports 0 from GetDimensions and the editor box is a cross.
        ref:SetAnchor(CENTER, control, CENTER)
        ref:SetDimensions(STEALTH_ICON_SIZE, STEALTH_ICON_SIZE)
    elseif controlName == "ZO_PlayerToPlayerAreaPromptContainer" then
        -- PlayerToPlayer.xml 52-62. Width is 870 and there is no height. Target
        -- spans that width. ActionArea hangs below the target.
        local targetLabel = control:GetNamedChild("Target")
        local actionArea = control:GetNamedChild("ActionArea")
        local rightOffset = targetLabel:GetRight() - actionArea:GetRight()
        ref:SetAnchor(TOPLEFT, targetLabel, TOPLEFT)
        ref:SetAnchor(BOTTOMRIGHT, actionArea, BOTTOMRIGHT, rightOffset, 0)
    else
        ref:SetAnchorFill()
    end
    control.hudElementRef = ref
    return ref
end

--- One anchor only. HUDManager.lua 35-37 asserts there is no secondary anchor.
--- Does not rewrite the control.
--- @param control Control
--- @return ZO_Anchor|nil
local function ReadSingleControlAnchor(control)
    local primaryValid, primaryPoint, relativeTo, relativePoint, offsetX, offsetY, constraints = control:GetAnchor(0)
    if not primaryValid then
        return nil
    end
    local secondaryValid = control:GetAnchor(1)
    if secondaryValid then
        return nil
    end
    return ZO_Anchor:New(primaryPoint, relativeTo, relativePoint, offsetX, offsetY, constraints)
end

--- ZO_Anchor:New(otherAnchor) copies .data (ZO_Anchor.lua 59-62).
--- @param anchor ZO_Anchor
--- @return ZO_Anchor
local function DuplicateAnchor(anchor)
    return ZO_Anchor:New(anchor)
end

--- @param gamepad boolean
--- @return ZO_Anchor
local function CreatePlayerProgressTemplateAnchor(gamepad)
    if gamepad then
        local offsetX = PLAYER_PROGRESS_GAMEPAD_OFFSET_X
        local offsetY = PLAYER_PROGRESS_GAMEPAD_OFFSET_Y
        -- Same call PlayerProgressBar:RefreshTemplate uses (PlayerProgressBar.lua 718).
        if CanUnitGainChampionPoints("player") then
            offsetX = PLAYER_PROGRESS_GAMEPAD_CHAMPION_OFFSET_X
            offsetY = PLAYER_PROGRESS_GAMEPAD_CHAMPION_OFFSET_Y
        end
        return ZO_Anchor:New(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, offsetX, offsetY)
    end
    return ZO_Anchor:New(TOPLEFT, GuiRoot, TOPLEFT, PLAYER_PROGRESS_KEYBOARD_OFFSET_X, PLAYER_PROGRESS_KEYBOARD_OFFSET_Y)
end

--- Meter anchor from ObjectiveCaptureMeter.xml 28-39. relativeTo omitted in XML,
--- so the target is the meter parent.
--- @param control Control
--- @param gamepad boolean
--- @return ZO_Anchor
local function CreateObjectiveCaptureMeterTemplateAnchor(control, gamepad)
    local parentControl = control:GetParent()
    local offsetY = ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y
    if gamepad then
        offsetY = OBJECTIVE_CAPTURE_METER_GAMEPAD_OFFSET_Y
    end
    return ZO_Anchor:New(BOTTOM, parentControl, BOTTOM, 0, offsetY)
end

--- Active platform keeps the live anchor. Progress and the capture meter use
--- the other platform's template anchor, because those templates differ.
--- Battleground score keeps its live TOPRIGHT to ZO_ActivityTracker
--- (BattlegroundHud.xml 48) on both platforms.
--- @param spec table
--- @param control Control
--- @return ZO_Anchor|nil keyboardDefaultAnchor
--- @return ZO_Anchor|nil gamepadDefaultAnchor
local function BuildPlatformDefaultAnchors(spec, control)
    local liveAnchor = ReadSingleControlAnchor(control)
    if not liveAnchor then
        return nil, nil
    end

    local keyboardDefaultAnchor = liveAnchor
    local gamepadDefaultAnchor = DuplicateAnchor(liveAnchor)
    local gamepadMode = IsInGamepadPreferredMode()

    if spec.controlName == "ZO_PlayerProgress" then
        if gamepadMode then
            gamepadDefaultAnchor = liveAnchor
            keyboardDefaultAnchor = CreatePlayerProgressTemplateAnchor(false)
        else
            keyboardDefaultAnchor = liveAnchor
            gamepadDefaultAnchor = CreatePlayerProgressTemplateAnchor(true)
        end
    elseif spec.controlName == "ZO_ObjectiveCaptureMeter" then
        if gamepadMode then
            gamepadDefaultAnchor = liveAnchor
            keyboardDefaultAnchor = CreateObjectiveCaptureMeterTemplateAnchor(control, false)
        else
            keyboardDefaultAnchor = liveAnchor
            gamepadDefaultAnchor = CreateObjectiveCaptureMeterTemplateAnchor(control, true)
        end
    end

    return keyboardDefaultAnchor, gamepadDefaultAnchor
end

local function HasRegisteredAncestor(control)
    local parentControl = control:GetParent()
    while parentControl and parentControl ~= GuiRoot do
        if HUD_MANAGER:GetKeyboardElementForControl(parentControl) or HUD_MANAGER:GetGamepadElementForControl(parentControl) then
            return true
        end
        parentControl = parentControl:GetParent()
    end
    return false
end

local function GetExtraHudElementSpecs()
    return
    {
        {
            -- Not a tracker. Default anchor stays TOPRIGHT on ZO_ActivityTracker
            -- (BattlegroundHud.xml 48) so it follows the tracker ZOS already moves.
            controlName = "ZO_BattlegroundHUDFragmentTopLevel",
            displayName = SI_HUDITORTOOLS_FRAME_BATTLEGROUND,
            registerKeyboard = true,
            registerGamepad = true,
            isValid = function ()
                return IsActiveWorldBattleground()
            end,
        },
        {
            -- Child of ZO_ObjectiveCapture. The parent is AnchorFill
            -- (ObjectiveCaptureMeter.xml 43), so it cannot be registered
            -- (HUDManager.lua 35-37).
            controlName = "ZO_ObjectiveCaptureMeter",
            displayName = SI_HUDITORTOOLS_FRAME_OBJECTIVE_METER,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            -- PlayerToPlayer.xml 52-54. ApplyPlatformStyle only sets fonts
            -- (PlayerToPlayer.lua 96-102).
            controlName = "ZO_PlayerToPlayerAreaPromptContainer",
            displayName = SI_HUDITORTOOLS_FRAME_PLAYER_INTERACTION,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            controlName = "ZO_PlayerProgress",
            displayName = SI_HUDITORTOOLS_FRAME_PLAYER_PROGRESS,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            -- Reticle.xml 70-72. Parent ZO_ReticleContainer is AnchorFill (line 58).
            controlName = "ZO_ReticleContainerInteract",
            displayName = SI_HUDITORTOOLS_FRAME_RETICLE_INTERACT,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            -- Reticle.xml 63-65.
            controlName = "ZO_ReticleContainerReticle",
            displayName = SI_HUDITORTOOLS_FRAME_RETICLE,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            -- Reticle.xml 67-68.
            controlName = "ZO_ReticleContainerStealthIcon",
            displayName = SI_HUDITORTOOLS_FRAME_STEALTH_ICON,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            -- Ram.xml 8.
            controlName = "ZO_RamTopLevel",
            displayName = SI_SIEGETYPE3,
            registerKeyboard = true,
            registerGamepad = true,
            isValid = function ()
                return IsPlayerEscortingRam()
            end,
        },
        {
            -- HudInfoTutorial.xml 12. Created in HudInfoTutorial.lua 8-11.
            controlName = "ZO_TutorialHudInfoTipKeyboard",
            displayName = SI_HUDITORTOOLS_FRAME_TUTORIALS,
            registerKeyboard = true,
            registerGamepad = false,
            isValid = function ()
                return not IsInGamepadPreferredMode()
            end,
        },
        {
            -- HudInfoTutorial.xml 61.
            controlName = "ZO_TutorialHudInfoTipGamepad",
            displayName = SI_HUDITORTOOLS_FRAME_TUTORIALS,
            registerKeyboard = false,
            registerGamepad = true,
            isValid = function ()
                return IsInGamepadPreferredMode()
            end,
        },
    }
end

local function RegisterSpec(spec)
    local control = _G[spec.controlName]
    if not control then
        return false
    end
    if HasRegisteredAncestor(control) then
        return true
    end

    local registerKeyboard = spec.registerKeyboard ~= false
    local registerGamepad = spec.registerGamepad ~= false
    local needsKeyboard = registerKeyboard and not HUD_MANAGER:GetKeyboardElementForControl(control)
    local needsGamepad = registerGamepad and not HUD_MANAGER:GetGamepadElementForControl(control)
    if not needsKeyboard and not needsGamepad then
        return true
    end

    GetOrCreateHudElementRef(control)

    local keyboardDefaultAnchor, gamepadDefaultAnchor = BuildPlatformDefaultAnchors(spec, control)
    if not keyboardDefaultAnchor or not gamepadDefaultAnchor then
        return false
    end

    local displayName = spec.displayName
    if type(displayName) == "number" then
        displayName = GetString(displayName)
    end

    if needsKeyboard then
        local keyboardConfig =
        {
            defaultAnchor = keyboardDefaultAnchor,
            isValid = spec.isValid,
        }
        local element = HUD_MANAGER:RegisterKeyboardElement(control, displayName, keyboardConfig)
        if HUD_MANAGER.savedVars then
            element:RevertOffsetModifications()
        end
    end
    if needsGamepad then
        local gamepadConfig =
        {
            defaultAnchor = gamepadDefaultAnchor,
            isValid = spec.isValid,
        }
        local element = HUD_MANAGER:RegisterGamepadElement(control, displayName, gamepadConfig)
        if HUD_MANAGER.savedVars then
            element:RevertOffsetModifications()
        end
    end
    return true
end

function HT.RegisterExtraHudElements()
    local specs = GetExtraHudElementSpecs()
    for _, spec in ipairs(specs) do
        RegisterSpec(spec)
    end
    HT.ApplyAllElementAppearances()
end

local function OnPlayerActivated()
    HT.RegisterExtraHudElements()
    zo_callLater(function ()
        HT.RegisterExtraHudElements()
    end, 0)
end

--- PlayerProgressBar:RefreshTemplate (PlayerProgressBar.lua 714-734, called from
--- OnBarLevelChange at 886) ApplyTemplateToControl's the template anchor onto
--- ZO_PlayerProgress. CompassFrame:ApplyStyle does the same, then calls
--- RevertOffsetModifications (CompassFrame.lua 132-149). No HUD_MANAGER callback
--- runs after OnBarLevelChange, so the saved offsets stay in the profile and the
--- control shows the template anchor until this runs.
local function RestorePlayerProgressSavedAnchor()
    local element = HT.GetHudElementForControl(ZO_PlayerProgress)
    if not element or element:IsUsingDefaultAnchor() then
        return
    end
    element:RevertOffsetModifications()
end

local function InstallPlayerProgressAnchorRestore()
    if playerProgressAnchorRestoreInstalled then
        return
    end
    playerProgressAnchorRestoreInstalled = true
    SecurePostHook(PLAYER_PROGRESS_BAR, "RefreshTemplate", function ()
        RestorePlayerProgressSavedAnchor()
    end)
end

function HT.InitializeExtraHudElements()
    InstallPlayerProgressAnchorRestore()
    if not preloadCallbackInstalled then
        preloadCallbackInstalled = true
        if HUD_MANAGER.savedVars then
            HT.RegisterExtraHudElements()
        else
            -- HUDManager.lua 300-315. Last chance before the saved profile loads.
            HUD_MANAGER:RegisterCallback("PreLoadSettings", function ()
                HT.RegisterExtraHudElements()
            end)
        end
    end
    if not playerActivatedCallbackInstalled then
        playerActivatedCallbackInstalled = true
        eventManager:RegisterForEvent(HT.eventName .. "_ExtraHudElements", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    end
end
