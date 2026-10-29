local COMPASS_WIDTH = 415    
local COMPASS_HEIGHT = 4    
local POS_X = 0            
local POS_Y = 134          
local TEXT_SCALE = 0       
local ICON_SCALE = 0.85        
local TEXT_OFFSET_Y = -15

ZO_PreHook("TryAutoTrackNextPromotionalEventCampaign", function() return true end)
if ZO_ChatWindowMinBar then ZO_ChatWindowMinBar:SetAlpha(0) end
if ZO_UnitFramesGroups then ZO_UnitFramesGroups:SetHidden(true) end
if ZO_AlertTextNotification then ZO_AlertTextNotification:SetAlpha(0) end
if ZO_HousingHUDFragmentTopLevelKeybindButton then ZO_HousingHUDFragmentTopLevelKeybindButton:SetHidden(true) end

if ZO_PlayerProgress then
    ZO_PlayerProgress:SetAlpha(0)
    ZO_PlayerProgress:SetHidden(true)
    ZO_PlayerProgress.SetHidden = function() end
end

if ZO_PlayerAttributeMountStamina then ZO_PlayerAttributeMountStamina:SetHidden(true) end
if ZO_PlayerAttributeWerewolf then ZO_PlayerAttributeWerewolf:SetHidden(true) end
if ZO_PlayerAttributeSiegeHealth then ZO_PlayerAttributeSiegeHealth:SetHidden(true) end

if ZO_CompassAreaOverrideLabel then ZO_CompassAreaOverrideLabel:SetHidden(true) end

local INVbackground = ZO_SharedWideLeftPanelBackgroundLeft
if INVbackground then
    INVbackground:ClearAnchors()
    INVbackground:SetAnchor(LEFT, GuiRoot, LEFT, -20, -50)
    INVbackground:SetDimensions(240, 650)
end

ZO_CharacterWindowStatsScrollScrollChildStatEntry4:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry5:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry7:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry8:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry29:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry30:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry25:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry23:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry34:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry35:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry16:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry33:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry13:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry22:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildStatEntry24:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildZO_MundusStonesStatsEntry:SetHidden(true)
ZO_CharacterWindowStatsScrollScrollChildZO_MundusStonesStatsEntryMundusIcon1:SetHidden(true)

RedirectTexture("esoui/art/actionbar/abilityframe64_up.dds", "EldenRingUI/Textures/abilityframe64_up.dds")
RedirectTexture("esoui/art/actionbar/abilityframe64_down.dds", "EldenRingUI/Textures/abilityframe64_up.dds")
RedirectTexture("esoui/art/miscellaneous/interactkeyframe_center.dds", "EldenRingUI/Textures/interactkeyframe_center.dds")
RedirectTexture("esoui/art/miscellaneous/interactkeyframe_edge.dds", "EldenRingUI/Textures/interactkeyframe_edge.dds")

RedirectTexture("esoui/art/compass/area2frameanim_assisted_center.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/compass/area2frameanim_assisted_endcap.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/compass/area2frameanim_centers.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/compass/areapin2frame_ends.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/compass/area2frameanim_standard_center.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/compass/area2frameanim_standard_endcap.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/mappins/hostile_pin.dds", "EldenRingUI/Textures/empty.dds")

RedirectTexture("esoui/art/compass/compass.dds", "EldenRingUI/Textures/empty.dds")
RedirectTexture("esoui/art/compass/compass_frame.dds", "EldenRingUI/Textures/empty.dds")

RedirectTexture("esoui/art/icons/consumable_potion_001_type_005.dds", "EldenRingUI/Textures/Icons/consumable_potion_001_type_005.dds")
RedirectTexture("esoui/art/icons/consumable_potion_011_type_005.dds", "EldenRingUI/Textures/Icons/consumable_potion_011_type_005.dds")

SecurePostHook(RETICLE, "UpdateInteractText", function()
    local interactContainer = ZO_ReticleContainerInteract
    local targetLabel = ZO_ReticleContainerInteractTargetName
    local contextLabel = ZO_ReticleContainerInteractContext
    local keybindButton = ZO_ReticleContainerInteractKeybindButton

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

local function CenterP2PPrompt()
    local ctrl = WINDOW_MANAGER:GetControlByName("ZO_PlayerToPlayerAreaPromptContainer")
    if ctrl and type(ctrl.ClearAnchors) == "function" and type(ctrl.SetAnchor) == "function" then
        ctrl:ClearAnchors()
        ctrl:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -350)
    end
end

local function RunOneTimeSetup()
    SafeAddString(SI_COMPASS_PIN_DISTANCE_FORMATTER, "", 1)       
    SafeAddString(SI_COMPASS_PIN_LONG_DISTANCE_FORMATTER, "", 1)  

    if ZO_SynergyTopLevel then
        local c = ZO_SynergyTopLevel:GetNamedChild('Container')
        if c then
            c:ClearAnchors()
            c:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -300)
            c:SetAlpha(0.85)

            local a = c:GetNamedChild('Action')
            local x = c:GetNamedChild('Key')
            local i = c:GetNamedChild('Icon')

            if a and i then
                a:ClearAnchors()
                a:SetAnchor(CENTER, c, CENTER, 27, 2)
            end

            if i then
                i:SetDimensions(45, 45)
                i:SetDrawLayer(DL_CONTROLS)
                i:SetDrawLevel(1)
                i:ClearAnchors()
                i:SetAnchor(RIGHT, a, LEFT, -10, -2)
                
                if x then
                    x:ClearAnchors()
                    x:SetAnchor(RIGHT, i, LEFT, 5, 0)
                end
                
                local bg = c:GetNamedChild('CustomBackground')
                if not bg then
                    bg = WINDOW_MANAGER:CreateControl('$(parent)CustomBackground', c, CT_TEXTURE)
                    bg:ClearAnchors()
                    bg:SetAnchor(CENTER, c, CENTER, 0, 2)
                    bg:SetTexture('EldenRingUI/Textures/CustomBG.dds')
                    bg:SetDrawLayer(DL_BACKGROUND)
                    bg:SetDrawLevel(0) 
                end

                local e = i:GetNamedChild('Edge')
                if not e then
                    e = WINDOW_MANAGER:CreateControl('$(parent)Edge', i, CT_TEXTURE)
                    e:SetDimensions(45, 45)
                    e:ClearAnchors()
                    e:SetAnchor(TOPLEFT, i, TOPLEFT, 0, 0)
                    e:SetTexture('EldenRingUI/Textures/abilityframe64_up.dds')
                    e:SetDrawLayer(DL_OVERLAY)
                    e:SetDrawLevel(2)
                end
            end
        end
    end

    if COMPASS_FRAME then
        COMPASS_FRAME.SetTargetTopOffsetY = function() end
        COMPASS_FRAME.ApplyStyle = function() end
    end

    zo_callLater(function()
        local ctrl = WINDOW_MANAGER:GetControlByName("ZO_PlayerToPlayerAreaPromptContainer")
        if ctrl and type(ctrl.GetHandler) == "function" and type(ctrl.SetHandler) == "function" then
            local origOnShow = ctrl:GetHandler("OnShow")
            if not ctrl.ERUI_P2PHooked then
                ctrl:SetHandler("OnShow", function(control, ...)
                    if origOnShow then origOnShow(control, ...) end
                    CenterP2PPrompt()
                end)
                ctrl.ERUI_P2PHooked = true
            end
        end
        CenterP2PPrompt()
    end, 500)
end

SecurePostHook(SYNERGY, "OnSynergyAbilityChanged", function()
    if ZO_SynergyTopLevel and not ZO_SynergyTopLevel:IsHidden() then
        local c = ZO_SynergyTopLevel:GetNamedChild("Container")
        if c then
            local a = c:GetNamedChild("Action")
            local bg = c:GetNamedChild("CustomBackground")
            if a and bg and not a:IsHidden() then
                local actionWidth = a:GetWidth() or 0
                bg:SetDimensions(actionWidth + 500, 64)
            end
        end
    end
end)

local frameFixer = WINDOW_MANAGER:GetControlByName("ERUI_CustomCompassFixer") or WINDOW_MANAGER:CreateControl("ERUI_CustomCompassFixer", GuiRoot, CT_CONTROL)
frameFixer:SetHandler("OnUpdate", function()
    if ZO_CompassFrame then
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
end)

local function HideQuickslotNumbers()
    if QuickslotButtonCountText then QuickslotButtonCountText:SetAlpha(0) end
    if QuickslotButtonStackCountText then QuickslotButtonStackCountText:SetAlpha(0) end
end

EVENT_MANAGER:RegisterForEvent("HideQuickslot_Event", EVENT_PLAYER_ACTIVATED, HideQuickslotNumbers)
EVENT_MANAGER:RegisterForEvent("EldenRingUI_Compass", EVENT_PLAYER_ACTIVATED, RunOneTimeSetup)