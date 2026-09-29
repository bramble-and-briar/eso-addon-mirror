-- -----------------------------------------------------------------------------
-- HUDitorTools - register ZOS HUD controls that stock Edit HUD does not.
-- Only ZOS controls: addon frames own their anchors. Same contract as
-- LuiExtended pc/Unlock.lua:
-- HUD_MANAGER:RegisterKeyboardElement / RegisterGamepadElement
-- (hudmanager.lua). ZO_HUDManager_Element:Initialize requires one anchor
-- and control.hudElementRef.
-- PreLoadSettings fires before ZO_HUDManager saved vars load. Controls
-- created later are registered on EVENT_PLAYER_ACTIVATED.
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local windowManager = GetWindowManager()
local eventManager = GetEventManager()

local preloadCallbackInstalled = false
local playerActivatedCallbackInstalled = false

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
    if not ref then
        return nil
    end
    ref:SetExcludeFromResizeToFitExtents(true)
    ref:ClearAnchors()
    ref:SetAnchor(CENTER)
    local width, height = control:GetDimensions()
    if width <= 0 then
        width = 100
    end
    if height <= 0 then
        height = 100
    end
    ref:SetDimensions(width, height)
    control.hudElementRef = ref
    return ref
end

local function PrepareControlForHudRegistration(control)
    if not control then
        return false, nil
    end

    local primaryValid, primaryPoint, relativeTo, relativePoint, offsetX, offsetY = control:GetAnchor(0)
    if not primaryValid then
        return false, nil
    end

    local secondaryValid = control:GetAnchor(1)
    local defaultAnchor
    if secondaryValid then
        local left = control:GetLeft()
        local top = control:GetTop()
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top, ANCHOR_CONSTRAINS_XY)
        defaultAnchor = ZO_Anchor:New(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        defaultAnchor = ZO_Anchor:New(primaryPoint, relativeTo, relativePoint, offsetX, offsetY)
    end

    if not GetOrCreateHudElementRef(control) then
        return false, nil
    end

    return true, defaultAnchor
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
            controlName = "ZO_BattlegroundHUDFragmentTopLevel",
            displayName = SI_HUDITORTOOLS_FRAME_BATTLEGROUND,
            registerKeyboard = true,
            registerGamepad = true,
            isValid = function ()
                return IsActiveWorldBattleground()
            end,
        },
        {
            controlName = "ZO_ObjectiveCaptureMeter",
            displayName = SI_HUDITORTOOLS_FRAME_OBJECTIVE_METER,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
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
            controlName = "ZO_ReticleContainerInteract",
            displayName = SI_HUDITORTOOLS_FRAME_RETICLE_INTERACT,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            controlName = "ZO_ReticleContainerReticle",
            displayName = SI_HUDITORTOOLS_FRAME_RETICLE,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            controlName = "ZO_ReticleContainerStealthIcon",
            displayName = SI_HUDITORTOOLS_FRAME_STEALTH_ICON,
            registerKeyboard = true,
            registerGamepad = true,
        },
        {
            controlName = "ZO_RamTopLevel",
            displayName = SI_SIEGETYPE3,
            registerKeyboard = true,
            registerGamepad = true,
            isValid = function ()
                return IsPlayerEscortingRam()
            end,
        },
        {
            controlName = "ZO_TutorialHudInfoTipKeyboard",
            displayName = SI_HUDITORTOOLS_FRAME_TUTORIALS,
            registerKeyboard = true,
            registerGamepad = false,
            isValid = function ()
                return not IsInGamepadPreferredMode()
            end,
        },
        {
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

    local ready, defaultAnchor = PrepareControlForHudRegistration(control)
    if not ready or not defaultAnchor then
        return false
    end

    local config =
    {
        defaultAnchor = defaultAnchor,
        isValid = spec.isValid,
    }
    local displayName = spec.displayName
    if type(displayName) == "number" then
        displayName = GetString(displayName)
    end

    if needsKeyboard then
        local element = HUD_MANAGER:RegisterKeyboardElement(control, displayName, config)
        if HUD_MANAGER.savedVars and element then
            element:RevertOffsetModifications()
        end
    end
    if needsGamepad then
        local element = HUD_MANAGER:RegisterGamepadElement(control, displayName, config)
        if HUD_MANAGER.savedVars and element then
            element:RevertOffsetModifications()
        end
    end
    return true
end

function HT.RegisterExtraHudElements()
    if not HUD_MANAGER or not HUD_MANAGER.RegisterKeyboardElement then
        return
    end
    local specs = GetExtraHudElementSpecs()
    for _, spec in ipairs(specs) do
        RegisterSpec(spec)
    end
    if HT.ApplyAllElementAppearances then
        HT.ApplyAllElementAppearances()
    end
end

local function OnPlayerActivated()
    HT.RegisterExtraHudElements()
    zo_callLater(function ()
        HT.RegisterExtraHudElements()
    end, 0)
end

function HT.InitializeExtraHudElements()
    if not HUD_MANAGER or not HUD_MANAGER.RegisterCallback then
        return
    end
    if not preloadCallbackInstalled then
        preloadCallbackInstalled = true
        if HUD_MANAGER.savedVars then
            HT.RegisterExtraHudElements()
        else
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
