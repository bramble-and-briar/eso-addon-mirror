local COMPASS_WIDTH = 415
local COMPASS_HEIGHT = 4
local POS_X = 0
local POS_Y = 134
local ICON_SCALE = 0.85

local HIDDEN_STAT_ENTRIES = { 4, 5, 7, 8, 13, 16, 22, 23, 24, 25, 29, 30, 33, 34, 35 }

local EMPTY_TEXTURE = "EldenRingUI/Textures/empty.dds"

local TEXTURE_REDIRECTS = {
    ["esoui/art/actionbar/abilityframe64_up.dds"] = "EldenRingUI/Textures/abilityframe64_up.dds",
    ["esoui/art/actionbar/abilityframe64_down.dds"] = "EldenRingUI/Textures/abilityframe64_up.dds",
    ["esoui/art/miscellaneous/interactkeyframe_center.dds"] = "EldenRingUI/Textures/interactkeyframe_center.dds",
    ["esoui/art/miscellaneous/interactkeyframe_edge.dds"] = "EldenRingUI/Textures/interactkeyframe_edge.dds",
    ["esoui/art/icons/consumable_potion_001_type_005.dds"] = "EldenRingUI/Textures/Icons/consumable_potion_001_type_005.dds",
    ["esoui/art/icons/consumable_potion_011_type_005.dds"] = "EldenRingUI/Textures/Icons/consumable_potion_011_type_005.dds",
    ["esoui/art/compass/area2frameanim_assisted_center.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/area2frameanim_assisted_endcap.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/area2frameanim_centers.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/areapin2frame_ends.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/area2frameanim_standard_center.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/area2frameanim_standard_endcap.dds"] = EMPTY_TEXTURE,
    ["esoui/art/mappins/hostile_pin.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/compass.dds"] = EMPTY_TEXTURE,
    ["esoui/art/compass/compass_frame.dds"] = EMPTY_TEXTURE,
}

ZO_PreHook("TryAutoTrackNextPromotionalEventCampaign", function() return true end)

if ZO_ChatWindowMinBar then ZO_ChatWindowMinBar:SetAlpha(0) end
if ZO_AlertTextNotification then ZO_AlertTextNotification:SetAlpha(0) end
if ZO_UnitFramesGroups then ZO_UnitFramesGroups:SetHidden(true) end
if ZO_HousingHUDFragmentTopLevelKeybindButton then ZO_HousingHUDFragmentTopLevelKeybindButton:SetHidden(true) end
if ZO_CompassAreaOverrideLabel then ZO_CompassAreaOverrideLabel:SetHidden(true) end
if ZO_PlayerAttributeMountStamina then ZO_PlayerAttributeMountStamina:SetHidden(true) end
if ZO_PlayerAttributeWerewolf then ZO_PlayerAttributeWerewolf:SetHidden(true) end
if ZO_PlayerAttributeSiegeHealth then ZO_PlayerAttributeSiegeHealth:SetHidden(true) end

if ZO_PlayerProgress then
    ZO_PlayerProgress:SetAlpha(0)
    ZO_PlayerProgress:SetHidden(true)
    ZO_PlayerProgress.SetHidden = function() end
end

if ZO_SharedWideLeftPanelBackgroundLeft then
    ZO_SharedWideLeftPanelBackgroundLeft:ClearAnchors()
    ZO_SharedWideLeftPanelBackgroundLeft:SetAnchor(LEFT, GuiRoot, LEFT, -20, -50)
    ZO_SharedWideLeftPanelBackgroundLeft:SetDimensions(240, 650)
end

for _, index in ipairs(HIDDEN_STAT_ENTRIES) do
    local entry = _G["ZO_CharacterWindowStatsScrollScrollChildStatEntry" .. index]
    if entry then entry:SetHidden(true) end
end
ZO_CharacterWindowStatsScrollScrollChildZO_MundusStonesStatsEntry:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildZO_MundusStonesStatsEntryMundusIcon1:SetHidden(true)

for source, target in pairs(TEXTURE_REDIRECTS) do
    RedirectTexture(source, target)
end

SecurePostHook(RETICLE, "UpdateInteractText", function()
    local interactContainer = ZO_ReticleContainerInteract
    local keybindButton = ZO_ReticleContainerInteractKeybindButton
    local contextLabel = ZO_ReticleContainerInteractContext
    local targetLabel = ZO_ReticleContainerInteractTargetName

    if interactContainer then
        interactContainer:ClearAnchors()
        interactContainer:SetAnchor(LEFT, GuiRoot, CENTER, 20, 30)
        interactContainer:SetAlpha(0.9)
    end

    if keybindButton and not keybindButton:IsHidden() then
        keybindButton:ClearAnchors()
        keybindButton:SetAnchor(LEFT, interactContainer, LEFT, 0, 0)
    end

    if contextLabel and not contextLabel:IsHidden() then
        contextLabel:ClearAnchors()
        contextLabel:SetAnchor(LEFT, keybindButton, RIGHT, 10, 0)
        contextLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end

    if targetLabel and not targetLabel:IsHidden() then
        targetLabel:ClearAnchors()
        targetLabel:SetAnchor(LEFT, contextLabel, RIGHT, 10, 0)
        targetLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
end)

SecurePostHook(SYNERGY, "OnSynergyAbilityChanged", function()
    if not ZO_SynergyTopLevel or ZO_SynergyTopLevel:IsHidden() then return end

    local container = ZO_SynergyTopLevel:GetNamedChild("Container")
    if not container then return end

    local key = container:GetNamedChild("Key")
    if key then key:SetHidden(true) end

    local action = container:GetNamedChild("Action")
    local background = container:GetNamedChild("CustomBackground")
    if action and background and not action:IsHidden() then
        background:SetDimensions((action:GetWidth() or 0) + 350, 64)
    end
end)

local function SetupSynergy()
    if not ZO_SynergyTopLevel then return end

    local container = ZO_SynergyTopLevel:GetNamedChild("Container")
    if not container then return end

    container:ClearAnchors()
    container:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -300)
    container:SetAlpha(0.85)

    local action = container:GetNamedChild("Action")
    local key = container:GetNamedChild("Key")
    local icon = container:GetNamedChild("Icon")

    if action and icon then
        action:ClearAnchors()
        action:SetAnchor(CENTER, container, CENTER, 27, 2)
    end

    if not icon then return end

    icon:SetDimensions(45, 45)
    icon:SetDrawLayer(DL_CONTROLS)
    icon:SetDrawLevel(1)
    icon:ClearAnchors()
    icon:SetAnchor(RIGHT, action, LEFT, -10, -2)

    if key then
        key:SetHidden(true)
    end

    if not container:GetNamedChild("CustomBackground") then
        local background = WINDOW_MANAGER:CreateControl("$(parent)CustomBackground", container, CT_TEXTURE)
        background:SetTexture("EldenRingUI/Textures/CustomBG.dds")
        background:SetAnchor(CENTER, container, CENTER, 0, 2)
        background:SetDrawLayer(DL_BACKGROUND)
        background:SetDrawLevel(0)
        background:SetAlpha(0.85)
    end

    if not icon:GetNamedChild("Edge") then
        local edge = WINDOW_MANAGER:CreateControl("$(parent)Edge", icon, CT_TEXTURE)
        edge:SetTexture("EldenRingUI/Textures/abilityframe64_up.dds")
        edge:SetDimensions(45, 45)
        edge:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
        edge:SetDrawLayer(DL_OVERLAY)
        edge:SetDrawLevel(2)
    end
end

local function CenterP2PPrompt()
    local prompt = WINDOW_MANAGER:GetControlByName("ZO_PlayerToPlayerAreaPromptContainer")
    if prompt and type(prompt.ClearAnchors) == "function" and type(prompt.SetAnchor) == "function" then
        prompt:ClearAnchors()
        prompt:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -350)
    end
end

local function HookP2PPrompt()
    local prompt = WINDOW_MANAGER:GetControlByName("ZO_PlayerToPlayerAreaPromptContainer")
    if prompt and type(prompt.GetHandler) == "function" and type(prompt.SetHandler) == "function" and not prompt.ERUI_P2PHooked then
        local origOnShow = prompt:GetHandler("OnShow")
        prompt:SetHandler("OnShow", function(control, ...)
            if origOnShow then origOnShow(control, ...) end
            CenterP2PPrompt()
        end)
        prompt.ERUI_P2PHooked = true
    end
    CenterP2PPrompt()
end

local function RunOneTimeSetup()
    SafeAddString(SI_COMPASS_PIN_DISTANCE_FORMATTER, "", 1)
    SafeAddString(SI_COMPASS_PIN_LONG_DISTANCE_FORMATTER, "", 1)

    if COMPASS_FRAME then
        COMPASS_FRAME.SetTargetTopOffsetY = function() end
        COMPASS_FRAME.ApplyStyle = function() end
    end

    SetupSynergy()
    zo_callLater(HookP2PPrompt, 500)
end

local function HideQuickslotNumbers()
    if QuickslotButtonCountText then QuickslotButtonCountText:SetAlpha(0) end
    if QuickslotButtonStackCountText then QuickslotButtonStackCountText:SetAlpha(0) end
end

local function FixCompass()
    if not ZO_CompassFrame then return end

    local valid, _, _, _, _, y = ZO_CompassFrame:GetAnchor(0)
    if not valid or y ~= POS_Y then
        ZO_CompassFrame:ClearAnchors()
        ZO_CompassFrame:SetAnchor(TOP, GuiRoot, TOP, POS_X, POS_Y)
    end

    if ZO_CompassFrame:GetWidth() ~= COMPASS_WIDTH then
        ZO_CompassFrame:SetDimensions(COMPASS_WIDTH, COMPASS_HEIGHT)
        if ZO_CompassFrameLeft then ZO_CompassFrameLeft:SetDimensions(COMPASS_HEIGHT, COMPASS_HEIGHT) end
        if ZO_CompassFrameRight then ZO_CompassFrameRight:SetDimensions(COMPASS_HEIGHT, COMPASS_HEIGHT) end
        if ZO_CompassFrameCenter then ZO_CompassFrameCenter:SetHeight(COMPASS_HEIGHT) end
    end

    if ZO_Compass and ZO_Compass:GetScale() ~= ICON_SCALE then
        ZO_Compass:SetScale(ICON_SCALE)
        ZO_Compass:SetDimensions(COMPASS_WIDTH / ICON_SCALE, COMPASS_HEIGHT / ICON_SCALE)
        ZO_Compass:ClearAnchors()
        ZO_Compass:SetAnchor(CENTER, ZO_CompassFrame, CENTER, 0, 0)
        ZO_Compass:SetAlpha(0.95)
    end

    if ZO_CompassCenterOverPinLabel and not ZO_CompassCenterOverPinLabel:IsHidden() then
        ZO_CompassCenterOverPinLabel:SetHidden(true)
    end
end

local compassFixer = WINDOW_MANAGER:GetControlByName("ERUI_CompassFixer") or WINDOW_MANAGER:CreateControl("ERUI_CompassFixer", GuiRoot, CT_CONTROL)
compassFixer:SetHandler("OnUpdate", FixCompass)

EVENT_MANAGER:RegisterForEvent("ERUI_Compass", EVENT_PLAYER_ACTIVATED, RunOneTimeSetup)
EVENT_MANAGER:RegisterForEvent("ERUI_CompassQuickslot", EVENT_PLAYER_ACTIVATED, HideQuickslotNumbers)