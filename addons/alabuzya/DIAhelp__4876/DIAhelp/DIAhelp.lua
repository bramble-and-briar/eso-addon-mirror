-- DIAhelp fork by alabuzya, modified 2026-09-22. GPL-3.0-or-later.
-- Original code: BulDeZir; artwork: Forsion. See CREDITS.txt.
local NAME = "DIAhelp"

local powerSettings = {
    [POWERTYPE_HEALTH] = {0, 1, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorehealth.dds'},
    [POWERTYPE_MAGICKA] = {0, 0.5, 0, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restoremagicka.dds'},
    [POWERTYPE_STAMINA] = {0.5, 0, 75, 'esoui/art/icons/alchemy/crafting_alchemy_trait_restorestamina.dds'},
    [POWERTYPE_MOUNT_STAMINA] = {0.5, 0, 75, nil},
    [POWERTYPE_WEREWOLF] = {0.0, 0.5, 0, nil},
    [ATTRIBUTE_VISUAL_POWER_SHIELDING] = {1, 0, 0, nil},

}
local DIFFICULTY_BRACKET_LEFT_TEXTURE =
{
    [MONSTER_DIFFICULTY_NONE] = "DIAhelp/Textures/TargetBorderLeft.dds",
    [MONSTER_DIFFICULTY_EASY] = "DIAhelp/Textures/TargetBorderLeft.dds",
    [MONSTER_DIFFICULTY_NORMAL] = "DIAhelp/Textures/NormalLeft.dds",
    [MONSTER_DIFFICULTY_HARD] = "DIAhelp/Textures/EliteLeft.dds",
    [MONSTER_DIFFICULTY_DEADLY] = "DIAhelp/Textures/BossLeft.dds",
}

local DIFFICULTY_BRACKET_RIGHT_TEXTURE =
{
    [MONSTER_DIFFICULTY_NONE] = "DIAhelp/Textures/TargetBorderRight.dds",
    [MONSTER_DIFFICULTY_EASY] = "DIAhelp/Textures/TargetBorderRight.dds",
    [MONSTER_DIFFICULTY_NORMAL] = "DIAhelp/Textures/NormalRight.dds",
    [MONSTER_DIFFICULTY_HARD] = "DIAhelp/Textures/EliteRight.dds",
    [MONSTER_DIFFICULTY_DEADLY] = "DIAhelp/Textures/BossRight.dds",
}
local DIFFICULTY_BRACKET_CENTER_TEXTURE =
{

    [MONSTER_DIFFICULTY_NONE] = "DIAhelp/Textures/TargetBorderCenter.dds",
    [MONSTER_DIFFICULTY_EASY] = "DIAhelp/Textures/TargetBorderCenter.dds",
    [MONSTER_DIFFICULTY_NORMAL] = "DIAhelp/Textures/NormalCenter.dds",
    [MONSTER_DIFFICULTY_HARD] = "DIAhelp/Textures/EliteCenter.dds",
    [MONSTER_DIFFICULTY_DEADLY] = "DIAhelp/Textures/BossCenter.dds",
}
local GAMEPAD_CONSTANTS =
{
    abilitySlotWidth = 64,
    abilitySlotOffsetX = 10,
    dualBarOffsetX = 44,
}
local KEYBOARD_CONSTANTS =
{
    abilitySlotWidth = 50,
    abilitySlotOffsetX = 2,
    dualBarOffsetX = 12,
}

-------------------------------------------------------------------------------------------------
-- Modify default styles --
-------------------------------------------------------------------------------------------------
local function ReTexture()
    local redirData = {
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowUnderlay_level4_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowUnderlay_level4_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/Tooltips/munge_overlay.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/Gamepad/gp_targetUnitFrame_bracket_level4.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/Gamepad/gp_targetUnitFrame_bracket_level3.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/Gamepad/gp_targetUnitFrame_bracket_level2.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowOverlay_level4_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowOverlay_level3_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowOverlay_level2_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowOverlay_level4_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowOverlay_level3_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_glowOverlay_level2_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level4_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level3_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level4_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level2_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level3_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level4_right.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitFrames/targetUnitFrame_bracket_level2_left.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitAttributeVisualizer/targetBar_dynamic_frame.dds", "DIAhelp/Textures/blank.dds" },

        { "esoui/art/unitattributevisualizer/attributebar_dynamic_increasedarmor_frame.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/attributebar_dynamic_increasedarmor_bg.dds", "DIAhelp/Textures/blank.dds" },

        { "esoui/art/unitattributevisualizer/attributebar_dynamic_fill_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/attributebar_dynamic_leadingedge_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/attributebar_small_fill_center_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/attributebar_small_fill_leadingedge_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/targetbar_dynamic_fill_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/targetbar_dynamic_leadingedge_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitAttributeVisualizer/targetBar_dynamic_frame.dds", "DIAhelp/Textures/blank.dds" },
        { "EsoUI/Art/UnitAttributeVisualizer/targetBar_dynamic_leadingEdge.dds", "DIAhelp/Textures/blank.dds" },

        { "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_dynamic_fill_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_dynamic_leadingedge_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_small_fill_center_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/gamepad/gp_attributebar_small_fill_leadingedge_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/gamepad/gp_targetbar_dynamic_fill_gloss.dds", "DIAhelp/Textures/blank.dds" },
        { "esoui/art/unitattributevisualizer/gamepad/gp_targetbar_dynamic_leadingedge_gloss.dds", "DIAhelp/Textures/blank.dds" },

    }
    for _, fromTo in ipairs(redirData) do
        RedirectTexture(unpack(fromTo))
    end
end

local function RestyleCurrentTarget()
    local difficulty = GetUnitDifficulty("reticleover")
    local target = UNIT_FRAMES:GetFrame("reticleover").frame
    local targetTextureRight = GetControl(target,'FrameRight')
    local targetTextureLeft = GetControl(target,'FrameLeft')
    local targetTextureCenter = GetControl(target,'FrameCenter')
    targetTextureRight:SetTexture(DIFFICULTY_BRACKET_RIGHT_TEXTURE[difficulty])
    targetTextureLeft:SetTexture(DIFFICULTY_BRACKET_LEFT_TEXTURE[difficulty])
    targetTextureCenter:SetTexture(DIFFICULTY_BRACKET_CENTER_TEXTURE[difficulty])
end

local function RestyleTargetFrames()
    local target = UNIT_FRAMES:GetFrame("reticleover").frame
    local targetTextureRight = GetControl(target,'FrameRight')
    local targetTextureLeft = GetControl(target,'FrameLeft')
    local targetTextureCenter = GetControl(target,'FrameCenter')
    local targetName = GetControl(target, 'TextArea')
    targetTextureRight:SetTextureCoords(1, 0, 1, 0, 1)
    targetTextureLeft:SetTextureCoords(1, 0, 1, 0, 1)
    targetTextureCenter:SetTextureCoords(1, 0, 1, 0, 1)
    targetTextureRight:SetAnchor(RIGHT, target, RIGHT, 34, -1)
    targetTextureLeft:SetAnchor(LEFT, target, LEFT, -34, -1)
    -- вот тут хз как быть, все что меньше MONSTER_DIFFICULTY_HARD выглядит и так ок.
    -- а выше - отступ не спасает, надо чето другое думать
    --targetName:SetAnchor(TOP, target, BOTTOM, 0, 30)
    targetTextureRight:SetDimensions(64,166)
    targetTextureLeft:SetDimensions(64,166)
end

local function GetCompanionUltimateButton()
    return ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
end

local function RestyleDoubleActionBar(topLevelCtrl, style, actionBarContainer)

    local anchorControl = ZO_ActionBar1:GetNamedChild('WeaponSwap')
    local barParent = GetControl(topLevelCtrl, 'ActionBarContainer')

    zo_callLater(function()
        GetControl(actionBarContainer, 'Arrow'):SetHidden(true)
    end, 150)

    local quickSlotButton = ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    quickSlotButton.slot:ClearAnchors()
    quickSlotButton.slot:SetAnchor(LEFT, barParent, LEFT)

    anchorControl:ClearAnchors()
    anchorControl:SetAnchor(LEFT, barParent, LEFT, style.dualBarOffsetX, 0)
end

local function RestyleActionBar(topLevelCtrl, style, actionBarContainer)
    local isGamePad = IsInGamepadPreferredMode()
    local template = 'DIAhelpFrame'

    ZO_ActionBar1WeaponSwap:SetHidden(true)
    ZO_ActionBar1KeybindBG:SetHidden(true)
    ZO_WeaponSwap_SetPermanentlyHidden(ZO_ActionBar1WeaponSwap, true)

    if not isGamePad then
        zo_callLater(function()
            for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + ACTION_BAR_SLOTS_PER_PAGE - 1 do
                ZO_ActionBar_GetButton(i).buttonText:SetHidden(true)
            end
            ZO_ActionBar_GetButton(1, HOTBAR_CATEGORY_QUICKSLOT_WHEEL).buttonText:SetHidden(true)
        end, 150)
    end

    DIAhelp_ApplyCompanionPolicy()

    ZO_HUDEquipmentStatus:ClearAnchors()
    ZO_HUDEquipmentStatus:SetAnchor(RIGHT, GuiRoot, RIGHT, -(style.abilitySlotOffsetX + 13), 0)

    local barParent = GetControl(topLevelCtrl, 'ActionBarContainer')
    local offsetX = ((style.abilitySlotWidth + style.abilitySlotOffsetX) * 5) / 2

    if actionBarContainer ~= nil then
        template = 'DIAhelpFrameDouble'
        RestyleDoubleActionBar(topLevelCtrl, style, actionBarContainer)
    else
        template = 'DIAhelpFrameDouble'
    end

    ApplyTemplateToControl(topLevelCtrl, ZO_GetPlatformTemplate(template))
    if actionBarContainer == nil then
        DIAhelp_LayoutDualBar(topLevelCtrl, style)
    end
end

-------------------------------------------------------------------------------------------------
-- - --
-------------------------------------------------------------------------------------------------

local DIAhelpStatusBar = ZO_Object:Subclass()
function DIAhelpStatusBar:New(...)
    local bar = ZO_Object.New(self)
    bar:Initialize(...)
    return bar
end

function DIAhelpStatusBar:Initialize(control, powerType)
    self.control = control
    self.glow = GetControl(control, 'Glow')
    self.smoke = GetControl(control, 'Smoke')
    self.smokeBg = GetControl(control, 'SmokeBg')
    self.label = GetControl(control, 'Label')
    self.value = 0
    self.min = 0
    self.max = 0
    local baseCoordLeft, baseCoordRight, baseAnchorX, ttIcon = unpack(powerSettings[powerType])
    self.baseCoordLeft = baseCoordLeft
    self.baseCoordRight = baseCoordRight
    self.baseAnchorX = baseAnchorX

    if self.glow ~= nil then
        self.glowAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("DIAhelpFrameGlowTemplate", self.glow)

        self.glow:SetHandler("OnMouseEnter", function(trigger)
            local hp = zo_round(self.value).." / "..zo_round(self.max)
            local text = zo_iconTextFormat(ttIcon, "70%", "70%", hp)
            InitializeTooltip(InformationTooltip, trigger, CENTER, 0, 25, TOP)
            SetTooltipText(InformationTooltip, text)
        end)
        self.glow:SetHandler("OnMouseExit", function()
            ClearTooltip(InformationTooltip)
        end)
    end
end

function DIAhelpStatusBar:SetValue(value)
    self.value = value
    self:ApplyTexture()
    self:ApplyAttributeLabel()
end

function DIAhelpStatusBar:GetValue()
    return self.value
end

function DIAhelpStatusBar:GetMax()
    return self.max
end

function DIAhelpStatusBar:SetMinMax(min, max)
    self.min = min
    self.max = max
end

function DIAhelpStatusBar:ApplyAttributeLabel()
    if self.label ~= nil then
        self.label:SetText(zo_round((self.value / 1000)) .. 'k')
    end
end

function DIAhelpStatusBar:ApplyTexture()

    local percent = 0
    if self.value >= self.max then
        percent = 100
    elseif self.max ~= 0 then
        percent = zo_roundToNearest((self.value / self.max) * 100, 0.1)
    end

    percent = zo_min(100, zo_max(0, percent - 3)) -- visual fix

    local height = (150 / 100) * percent
    local coordTop = 1 - (percent / 100)
    local anchorY = 150 - height

    if self.glow ~= nil then
        if percent < 30 then
            if not self.glowAnimation:IsPlaying() then
                self.glowAnimation:PlayFromStart()
            end
        else
            self.glowAnimation:Stop()
            self.glow:SetAlpha(0)
        end
    end

    self.smoke:SetHeight(height)
    self.smoke:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, coordTop, 1)
    self.smoke:SetAnchor(TOPLEFT, self.control, nil, self.baseAnchorX, anchorY)

    if self.smokeBg ~= nil then
        self.smokeBg:SetHeight(zo_max(0, height - 5))
        self.smokeBg:SetTextureCoords(self.baseCoordLeft, self.baseCoordRight, coordTop - 0.00000005, 1)
        self.smokeBg:SetAnchor(TOPLEFT, self.control, nil, self.baseAnchorX, anchorY - 5)
    end
end
-------------------------------------------------------------------------------------------------
--  Register Events --
-------------------------------------------------------------------------------------------------
local LongBuffsBlackList = {
    [43752] = true,
    [21263] = true,
    [92232] = true,
    [64210] = true,
    [66776] = true,
    [77123] = true,
    [85501] = true,
    [85502] = true,
    [85503] = true,
    [86755] = true,
    [88445] = true,
    [89683] = true,
    [91369] = true,
}

local function AbilityIsFood(abilityId)
    if LongBuffsBlackList[abilityId] ~= nil then
        return false
    end
    if not DoesAbilityExist(abilityId) or IsAbilityPermanent(abilityId) or GetAbilityDuration(abilityId) < 600000 then
        return false
    end

    return true
end

local function getFoodBuff()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer = GetUnitBuffInfo("player", i)
        if canClickOff and AbilityIsFood(abilityId) then
            local timeLeft = timeEnding - GetFrameTimeSeconds()
            return {
                abilityId = abilityId,
                name = buffName,
                timeLeft = timeLeft,
                timeLeftFormatted = ZO_FormatTime(timeLeft, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR),
                duration = (timeEnding - timeStarted),
            }
        end
    end
end

local function updateFood(topLevelCtrl)
    local food = getFoodBuff()
    local control = GetControl(topLevelCtrl, 'Line')
    if food == nil then
        control:SetValue(0)
        control.ttt = nil
    else
        ZO_StatusBar_SmoothTransition(control, food.timeLeft, food.duration)
        control.ttt = food.name .. ' (' .. food.timeLeftFormatted .. ')'
    end
end

function DIAhelpFrame_Initialize(topLevelCtrl)

    local function OnAddOnLoaded(_, addonName)
        if addonName == NAME then

            -----------------
            -- POWER POOLS --
            -----------------
            local pools = {
                [POWERTYPE_HEALTH] = DIAhelpStatusBar:New(GetControl(topLevelCtrl, 'Health'), POWERTYPE_HEALTH),
                [POWERTYPE_MAGICKA] = DIAhelpStatusBar:New(GetControl(topLevelCtrl, 'Magicka'), POWERTYPE_MAGICKA),
                [POWERTYPE_STAMINA] = DIAhelpStatusBar:New(GetControl(topLevelCtrl, 'Stamina'), POWERTYPE_STAMINA),
                [POWERTYPE_MOUNT_STAMINA] = DIAhelpStatusBar:New(GetControl(topLevelCtrl, 'MountStamina'), POWERTYPE_MOUNT_STAMINA),
                [POWERTYPE_WEREWOLF] = DIAhelpStatusBar:New(GetControl(topLevelCtrl, 'WerewolfTimer'), POWERTYPE_WEREWOLF),
            }
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_POWER_UPDATE, function(_, _, _, powerType, powerValue, powerMax)
                local pool = pools[powerType]
                if pool ~= nil then
                    ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
                end
            end)
            EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

            -----------------
            -- SHIELD --
            -----------------
            local shield = DIAhelpStatusBar:New(GetControl(topLevelCtrl, 'Shield'), ATTRIBUTE_VISUAL_POWER_SHIELDING)

            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, _, unitAttributeVisual, _, _, _, value)
                if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                    shield.label:GetParent():SetHidden(false)
                    ZO_StatusBar_SmoothTransition(shield, value, pools[POWERTYPE_HEALTH]:GetMax())
                end
            end)
            EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")

            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, _, unitAttributeVisual, _, _, _, _, newValue)
                if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                    ZO_StatusBar_SmoothTransition(shield, newValue, pools[POWERTYPE_HEALTH]:GetMax())
                end
            end)
            EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")

            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, _, unitAttributeVisual)
                if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
                    ZO_StatusBar_SmoothTransition(shield, 0, pools[POWERTYPE_HEALTH]:GetMax())
                    shield.label:GetParent():SetHidden(true)
                end
            end)
            EVENT_MANAGER:AddFilterForEvent(NAME, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")

            -----------------
            -- MOUNT STATE --
            -----------------
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MOUNTED_STATE_CHANGED, function(_, state)
                pools[POWERTYPE_MOUNT_STAMINA].control:SetHidden(not state)
            end)

            -----------------
            -- WW STATE --
            -----------------
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_WEREWOLF_STATE_CHANGED, function(_, state)
                pools[POWERTYPE_WEREWOLF].control:SetHidden(not state)
            end)
 
 
            -----------------
            -- FOOD --
            -----------------
            EVENT_MANAGER:RegisterForUpdate(NAME .. "Food", 3000, function() updateFood(topLevelCtrl) end)

            -----------------
            -- FRAGMENT --
            -----------------
            local fragment = ZO_HUDFadeSceneFragment:New(topLevelCtrl)
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
            local function UpdateDeathFragment()
                fragment:SetHiddenForReason("Dead", IsUnitDead("player"))
            end
            PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('DIAhelp', true)
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEAD, UpdateDeathFragment)
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ALIVE, UpdateDeathFragment)
            -----------------
            -- Target (ReticleOver) --
            -----------------
            -- отключил, пока сыро
            --ReTexture()
            --RestyleTargetFrames()
            --EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, RestyleCurrentTarget)
            -----------------
            -- PLAYER_ACTIVATED --
            -----------------
            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
                UpdateDeathFragment()
                DIAhelp_ApplyCompanionPolicy()

                for powerType in pairs(pools) do
                    local powerValue, powerMax = GetUnitPower("player", powerType)
                    ZO_StatusBar_SmoothTransition(pools[powerType], powerValue, powerMax)
                end

                shield:SetMinMax(0, pools[POWERTYPE_HEALTH]:GetMax())
                shield:SetValue(0)

                updateFood(topLevelCtrl)

                pools[POWERTYPE_MOUNT_STAMINA].control:SetHidden(not IsMounted())
            end)

            -----------------
            -- APPLY STYLE --
            -----------------
            local styleManager = ZO_PlatformStyle:New(function(style)
                if AltAB_ActionBar ~= nil then
                    RestyleActionBar(topLevelCtrl, style, AltAB_ActionBar)
                elseif FAB_ActionBar ~= nil then
                    RestyleActionBar(topLevelCtrl, style, FAB_ActionBar)
                else
                    RestyleActionBar(topLevelCtrl, style)
                end
            end, KEYBOARD_CONSTANTS, GAMEPAD_CONSTANTS)

            EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ACTIVE_COMPANION_STATE_CHANGED, function() styleManager:Apply() end)

            EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
        end
    end

    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
end
