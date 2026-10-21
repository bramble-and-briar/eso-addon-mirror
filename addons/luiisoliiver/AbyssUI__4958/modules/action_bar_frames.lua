local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_ActionBarFrames"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local ActionBarFrames = {}
NAGA_UI.ActionBarFrames = ActionBarFrames

local NORMAL_FRAME = "EsoUI/Art/ActionBar/actionslot_normal.dds"
local PRESSED_FRAME = "EsoUI/Art/ActionBar/actionslot_pressed.dds"
local TOGGLED_FRAME = "EsoUI/Art/ActionBar/actionslot_toggledon.dds"
local STOCK_NORMAL_FRAME = "EsoUI/Art/ActionBar/abilityFrame64_up.dds"
local STOCK_PRESSED_FRAME = "EsoUI/Art/ActionBar/abilityFrame64_down.dds"
local NO_TEXTURE = ""
local USE_SHRINK_SCALE = 0.86
local USE_SHRINK_DURATION_MS = 75
local USE_RESTORE_DURATION_MS = 90
local NO_LEADING_EDGE = false
local COOLDOWN_UPDATE_INTERVAL_MS = 100
local GLOBAL_COOLDOWN_IGNORE_MS = 1500

local function IsCooldownTextEnabled()
    return not NAGA_UI.Settings
        or not NAGA_UI.Settings.IsActionBarCooldownTextEnabled
        or NAGA_UI.Settings:IsActionBarCooldownTextEnabled()
end

local function IsModuleEnabled()
    return not NAGA_UI.Settings or NAGA_UI.Settings:IsActionBarFramesEnabled()
end

local function IsUseShrinkEnabled()
    return not NAGA_UI.Settings or NAGA_UI.Settings:IsActionBarSkillUseShrinkEnabled()
end

local function IsGlobalCooldownEnabled()
    return NAGA_UI.Settings and NAGA_UI.Settings:IsActionBarGlobalCooldownEnabled()
end

local function GetFrameStyle()
    local settings = NAGA_UI.Settings
    local style = settings and settings:GetActionBarFrames().frameStyle or "rpg"
    return (style == "original" or style == "none") and style or "rpg"
end

local function GetStyledFrame(pressed)
    local style = GetFrameStyle()
    if style == "none" then return NO_TEXTURE end
    if style == "rpg" then
        return NAGA_UI:GetAssetPath("ui/actionbar/naga_socket_v3_dxt5.dds")
    end
    return pressed and PRESSED_FRAME or NORMAL_FRAME
end

local function IsUltimateReady(button)
    if not button or not ZO_ActionBar_IsUltimateSlot(button:GetSlot(), button:GetHotbarCategory()) then
        return false
    end

    local cost = GetSlotAbilityCost(button:GetSlot(), COMBAT_MECHANIC_FLAGS_ULTIMATE, button:GetHotbarCategory())
    return cost and cost > 0 and button:GetUltimateCount() >= cost
end

local function IsQuickslotConsumableOnCooldown(button)
    if not button or button:GetHotbarCategory() ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        return false
    end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()
    local slotType = GetSlotType(slotNum, hotbarCategory)
    if slotType ~= ACTION_TYPE_ITEM and slotType ~= ACTION_TYPE_COLLECTIBLE and slotType ~= ACTION_TYPE_QUEST_ITEM then
        return false
    end

    local remain, duration = GetSlotCooldownInfo(slotNum, hotbarCategory)
    return duration and duration > 0 and remain and remain > 0
end

local function GetOverlayTexture(button)
    local style = GetFrameStyle()
    if style == "none" then return nil end
    if style == "rpg" then
        -- Ultimate readiness has its own full-size frame and halo.
        if ZO_ActionBar_IsUltimateSlot(button:GetSlot(), button:GetHotbarCategory()) then return nil end
        if IsQuickslotConsumableOnCooldown(button) or IsUltimateReady(button) then
            return NAGA_UI:GetAssetPath("ui/actionbar/socket_glow_dxt5.dds")
        end
        return nil
    end
    if IsQuickslotConsumableOnCooldown(button) then
        return TOGGLED_FRAME
    end

    if IsUltimateReady(button) then
        return PRESSED_FRAME
    end
end

local function GetStockNormalFrameTexture()
    return IsInGamepadPreferredMode() and NO_TEXTURE or STOCK_NORMAL_FRAME
end

local function GetStockPressedFrameTexture()
    return IsInGamepadPreferredMode() and NO_TEXTURE or STOCK_PRESSED_FRAME
end

local function IsStockActionFrame(texture)
    return texture == STOCK_NORMAL_FRAME
        or texture == STOCK_PRESSED_FRAME
        or texture == NO_TEXTURE
end

local function GetSetupNormalFrame(normalFrame)
    if IsModuleEnabled() and IsStockActionFrame(normalFrame) then
        return GetStyledFrame(false)
    end

    return normalFrame
end

local function GetSetupPressedFrame(pressedFrame)
    if IsModuleEnabled() then
        if pressedFrame == STOCK_PRESSED_FRAME then
            return GetStyledFrame(true)
        elseif pressedFrame == STOCK_NORMAL_FRAME then
            return GetStyledFrame(false)
        elseif pressedFrame == NO_TEXTURE then
            return GetStyledFrame(true)
        end
    end

    return pressedFrame
end

local function IsPlayableActionSlot(button)
    if not button then
        return false
    end

    local slotType = GetSlotType(button:GetSlot(), button:GetHotbarCategory())
    return slotType == ACTION_TYPE_ABILITY or slotType == ACTION_TYPE_CRAFTED_ABILITY
end

local function CreateUseShrinkTimeline(control)
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    local shrink = timeline:InsertAnimation(ANIMATION_SCALE, control, 0)
    shrink:SetDuration(USE_SHRINK_DURATION_MS)
    shrink:SetEasingFunction(ZO_EaseInQuadratic)

    local restore = timeline:InsertAnimation(ANIMATION_SCALE, control, USE_SHRINK_DURATION_MS)
    restore:SetDuration(USE_RESTORE_DURATION_MS)
    restore:SetEasingFunction(ZO_EaseOutQuadratic)

    return timeline
end

local function SetUseShrinkTimelineScale(timeline, control)
    local baseScale = control:GetScale()
    local shrinkScale = baseScale * USE_SHRINK_SCALE

    local shrink = timeline:GetAnimation(1)
    shrink:SetScaleValues(baseScale, shrinkScale)

    local restore = timeline:GetAnimation(2)
    restore:SetScaleValues(shrinkScale, baseScale)
end

function ActionBarFrames:PlayUseShrink(button)
    if not IsModuleEnabled() or not IsUseShrinkEnabled() or IsInGamepadPreferredMode() or not IsPlayableActionSlot(button) then
        return
    end

    if not button.NagaUseShrinkTimeline then
        button.NagaUseShrinkTimeline = CreateUseShrinkTimeline(button.slot)
    end

    local timeline = button.NagaUseShrinkTimeline
    if timeline:IsPlaying() then
        timeline:PlayInstantlyToEnd()
    end

    SetUseShrinkTimelineScale(timeline, button.slot)
    timeline:PlayFromStart()
end

function ActionBarFrames:ApplyGlobalCooldown(button)
    if not IsModuleEnabled() or not IsGlobalCooldownEnabled() or not IsPlayableActionSlot(button) or not button.cooldown then
        return
    end

    local remain, duration, global = GetSlotCooldownInfo(button:GetSlot(), button:GetHotbarCategory())
    if global and remain and remain > 0 and duration and duration > 0 then
        button.cooldown:StartCooldown(remain, duration, CD_TYPE_RADIAL, nil, NO_LEADING_EDGE)
        button.cooldown:SetHidden(false)
    end
end

local function GetCooldownText(button)
    if not button or not IsPlayableActionSlot(button) then
        return nil
    end

    local slotNum = button:GetSlot()
    local hotbarCategory = button:GetHotbarCategory()
    local remain, duration, global = GetSlotCooldownInfo(slotNum, hotbarCategory)
    remain = tonumber(remain) or 0
    duration = tonumber(duration) or 0

    if remain <= 0 or duration <= 0 then
        return nil
    end

    -- Do not print the normal 1-second global cooldown over every skill.
    if global and duration <= GLOBAL_COOLDOWN_IGNORE_MS then
        return nil
    end

    local seconds = math.ceil(remain / 1000)
    if seconds <= 0 then
        return nil
    end

    return tostring(seconds) .. "s"
end

-- Player ultimate only (never companion).
-- Returns percentText ("0%".."100%"), progressText ("189/175"), and ready flag.
local function GetUltimateProgressInfo(button)
    if not button or not button.GetSlot or not button.GetHotbarCategory then
        return nil, nil, false
    end

    local hotbarCategory = button:GetHotbarCategory()
    -- Explicitly exclude companion ultimate.
    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        return nil, nil, false
    end

    if not ZO_ActionBar_IsUltimateSlot(button:GetSlot(), hotbarCategory) then
        return nil, nil, false
    end

    local cost = GetSlotAbilityCost(button:GetSlot(), COMBAT_MECHANIC_FLAGS_ULTIMATE, hotbarCategory)
    if not cost or cost <= 0 then
        return nil, nil, false
    end

    local power = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    if power < 0 then
        power = 0
    end

    local progress = power / cost
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end

    local percentage = math.floor((progress * 100) + 0.5)
    local percentText = tostring(percentage) .. "%"
    local progressText = tostring(math.floor(power + 0.5)) .. "/" .. tostring(math.floor(cost + 0.5))
    return percentText, progressText, progress >= 1
end


function ActionBarFrames:UpdateCooldownText(button)
    if not button or not button.slot then
        return
    end

    local label = button.NagaCooldownText
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, button.slot, CT_LABEL)
        label:SetAnchor(CENTER, button.slot, CENTER, 0, 11)
        label:SetDimensions(button.slot:GetWidth() + 12, 22)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
        label:SetColor(1, 1, 1, 1)
        label:SetDrawTier(DT_HIGH)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(30)
        label:SetMouseEnabled(false)
        button.NagaCooldownText = label
    end

    if not IsCooldownTextEnabled() then
        label:SetText("")
        label:SetHidden(true)
        return
    end

    local text = GetCooldownText(button)
    label:SetText(text or "")
    label:SetHidden(text == nil)
end

function ActionBarFrames:UpdateUltimatePercentText(button)
    if not button or not button.slot then
        return
    end

    local slot = button.slot
    local slotW = slot:GetWidth() or 50

    -- Percentage label (centered on the icon). Player ultimate only.
    local label = button.NagaUltimatePercentText
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, slot, CT_LABEL)
        label:SetAnchor(CENTER, slot, CENTER, 0, 0)
        label:SetDimensions(slotW + 16, 22)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
        label:SetColor(1, 0.95, 0.75, 1)
        label:SetDrawTier(DT_HIGH)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(31)
        label:SetMouseEnabled(false)
        button.NagaUltimatePercentText = label
    end

    -- Progress label ABOVE the ultimate (e.g. 189/175). Player ultimate only.
    local progressLabel = button.NagaUltimateProgressText
    if not progressLabel then
        progressLabel = WINDOW_MANAGER:CreateControl(nil, slot, CT_LABEL)
        -- Raised above the iron ultimate DDS frame so it does not overlap the border art.
        progressLabel:SetAnchor(BOTTOM, slot, TOP, 0, -10)
        progressLabel:SetDimensions(slotW + 40, 20)
        progressLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        progressLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
        -- White fill with thin black edge (soft-shadow-thin).
        progressLabel:SetFont("$(BOLD_FONT)|15|soft-shadow-thin")
        progressLabel:SetColor(1, 1, 1, 1)
        progressLabel:SetDrawTier(DT_HIGH)
        progressLabel:SetDrawLayer(DL_OVERLAY)
        progressLabel:SetDrawLevel(32)
        progressLabel:SetMouseEnabled(false)
        button.NagaUltimateProgressText = progressLabel
    else
        -- Keep style/position correct if the label already existed from a previous load.
        progressLabel:ClearAnchors()
        progressLabel:SetAnchor(BOTTOM, slot, TOP, 0, -10)
        progressLabel:SetFont("$(BOLD_FONT)|15|soft-shadow-thin")
        progressLabel:SetColor(1, 1, 1, 1)
    end

    -- Never show on companion ultimate.
    local hotbarCategory = button.GetHotbarCategory and button:GetHotbarCategory()
    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        label:SetText("")
        label:SetHidden(true)
        progressLabel:SetText("")
        progressLabel:SetHidden(true)
        return
    end

    local percentText, progressText, ready = GetUltimateProgressInfo(button)
    if percentText then
        label:SetText(percentText)
        label:SetHidden(false)
        if ready then
            label:SetColor(1, 0.92, 0.45, 1)
        else
            label:SetColor(1, 0.95, 0.75, 1)
        end
    else
        label:SetText("")
        label:SetHidden(true)
    end

    if progressText then
        progressLabel:SetText(progressText)
        progressLabel:SetHidden(false)
        progressLabel:SetColor(1, 1, 1, 1)
    else
        progressLabel:SetText("")
        progressLabel:SetHidden(true)
    end
end

function ActionBarFrames:RefreshCooldownText()
    if not ZO_ActionBar_GetButton then
        return
    end

    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 do
        self:UpdateCooldownText(ZO_ActionBar_GetButton(i))
    end

    self:UpdateCooldownText(ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    self:UpdateCooldownText(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
end

function ActionBarFrames:RefreshUltimatePercentText()
    if not ZO_ActionBar_GetButton then
        return
    end

    -- Player active + weapon-swap backbar ultimate only.
    self:UpdateUltimatePercentText(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1))
    -- Explicitly clear companion if label was ever created.
    local companionButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    if companionButton then
        self:UpdateUltimatePercentText(companionButton)
    end
end

function ActionBarFrames:StartCooldownTextTicker()
    if self.cooldownTextTicker then
        return
    end

    local ticker = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_CONTROL)
    ticker:SetHidden(false)
    ticker:SetHandler("OnUpdate", function(_, currentTime)
        if self.cooldownTextLastUpdate and currentTime - self.cooldownTextLastUpdate < COOLDOWN_UPDATE_INTERVAL_MS then
            return
        end
        self.cooldownTextLastUpdate = currentTime
        self:RefreshCooldownText()
        self:RefreshUltimatePercentText()
    end)
    self.cooldownTextTicker = ticker
end

function ActionBarFrames:UpdateSkillFrame(button, enabled)
    local frame = button.NagaSkillFrame
    if not enabled then
        if frame then frame:SetHidden(true) end
        return
    end
    if not frame then
        frame = WINDOW_MANAGER:CreateControl(nil, button.slot, CT_TEXTURE)
        frame:SetAnchor(CENTER, button.slot, CENTER, 0, 0)
        frame:SetTexture(NAGA_UI:GetAssetPath("ui/actionbar/naga_socket_v3_dxt5.dds"))
        frame:SetMouseEnabled(false)
        frame:SetDrawTier(DT_HIGH)
        frame:SetDrawLayer(DL_OVERLAY)
        frame:SetDrawLevel(4)
        button.NagaSkillFrame = frame
    end
    -- Draw the metal outside the 47px icon, instead of squeezing it into
    -- the native 50px button texture. Slot positions and hit targets stay native.
    local size = button.slot:GetWidth() + 4
    frame:SetDimensions(size, size)
    frame:SetHidden(false)
end

function ActionBarFrames:UpdateUltimateFrame(button, enabled)
    local decoration = button.slot:GetNamedChild("Decoration")
    if decoration then
        if enabled then
            if button.NagaDecorationAlpha == nil then
                button.NagaDecorationAlpha = decoration:GetAlpha()
            end
            decoration:SetAlpha(0)
        elseif button.NagaDecorationAlpha ~= nil then
            decoration:SetAlpha(button.NagaDecorationAlpha)
            button.NagaDecorationAlpha = nil
        end
    end
    local art = button.NagaUltimateArt
    if not enabled then
        if art then
            art.frame:SetHidden(true)
            art.halo:SetHidden(true)
            art.halo:SetHandler("OnUpdate", nil)
            art.ready = false
        end
        return
    end
    if not art then
        art = {}
        for _, key in ipairs({ "halo", "frame" }) do
            local texture = WINDOW_MANAGER:CreateControl(nil, button.slot, CT_TEXTURE)
            texture:SetAnchor(CENTER, button.slot, CENTER, 0, 0)
            texture:SetMouseEnabled(false)
            texture:SetDrawTier(DT_HIGH)
            texture:SetDrawLayer(DL_OVERLAY)
            texture:SetDrawLevel(key == "halo" and 3 or 4)
            art[key] = texture
        end
        art.halo:SetTexture(NAGA_UI:GetAssetPath("ui/actionbar/ultimate_halo_v3_dxt5.dds"))
        button.NagaUltimateArt = art
    end
    local size = button.slot:GetWidth() + 14
    art.frame:SetDimensions(size, size)
    art.halo:SetDimensions(size + 14, size + 14)
    local ready = IsUltimateReady(button)
    art.frame:SetTexture(NAGA_UI:GetAssetPath(ready
        and "ui/actionbar/ultimate_ready_v3_dxt5.dds" or "ui/actionbar/ultimate_iron_v3_dxt5.dds"))
    art.frame:SetHidden(false)
    art.halo:SetHidden(not ready)
    if ready ~= art.ready then
        art.halo:SetHandler("OnUpdate", nil)
        if ready then
            local start = GetFrameTimeMilliseconds()
            art.halo:SetAlpha(0.65)
            art.halo:SetHandler("OnUpdate", function(control)
                local phase = (GetFrameTimeMilliseconds() - start) / 1800 * math.pi * 2
                control:SetAlpha(0.65 + 0.20 * math.sin(phase))
            end)
        end
        art.ready = ready
    end
end

function ActionBarFrames:ApplyToButton(button)
    if not button or not button.button then
        return
    end

    local moduleEnabled = IsModuleEnabled()
    local iron = moduleEnabled and GetFrameStyle() == "rpg"
    local ironUltimate = iron and ZO_ActionBar_IsUltimateSlot(button:GetSlot(), button:GetHotbarCategory())
    button.button:SetNormalTexture(iron and NO_TEXTURE or moduleEnabled and GetStyledFrame(false) or GetStockNormalFrameTexture())
    button.button:SetPressedTexture(iron and NO_TEXTURE or moduleEnabled and GetStyledFrame(true) or GetStockPressedFrameTexture())
    self:UpdateSkillFrame(button, iron and not ironUltimate)
    self:UpdateUltimateFrame(button, ironUltimate)

    if button.status then
        local iron = moduleEnabled and GetFrameStyle() == "rpg"
        button.status:SetColor(1, iron and 0.78 or 1, iron and 0.42 or 1, 1)
        local overlayTexture = moduleEnabled and GetOverlayTexture(button)
        if overlayTexture then
            button.status:SetTexture(overlayTexture)
            button.status:SetHidden(false)
        elseif moduleEnabled then
            button.status:SetHidden(true)
        else
            local slotNum = button:GetSlot()
            local hotbarCategory = button:GetHotbarCategory()
            local slotIsEmpty = GetSlotType(slotNum, hotbarCategory) == ACTION_TYPE_NOTHING
            button.status:SetTexture(TOGGLED_FRAME)
            button.status:SetHidden(slotIsEmpty or IsSlotToggled(slotNum, hotbarCategory) == false)
        end
    end

    self:ApplyGlobalCooldown(button)
    self:UpdateCooldownText(button)
    self:UpdateUltimatePercentText(button)
end

function ActionBarFrames:ApplyQuickslot()
    if ZO_ActionBar_GetButton then
        self:ApplyToButton(ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL))
    end
end

function ActionBarFrames:ApplyActiveUltimate()
    if ZO_ActionBar_GetButton then
        self:ApplyToButton(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1))
    end
end

function ActionBarFrames:ApplyCompanionUltimate()
    if ZO_ActionBar_GetButton then
        self:ApplyToButton(ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION))
    end
end

function ActionBarFrames:ApplyAll()
    if not ZO_ActionBar_GetButton then
        return
    end

    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 do
        self:ApplyToButton(ZO_ActionBar_GetButton(i))
    end

    self:ApplyQuickslot()
    self:ApplyCompanionUltimate()
end

function ActionBarFrames:RefreshCooldowns()
    if not ZO_ActionBar_GetButton then
        return
    end

    for i = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 do
        local button = ZO_ActionBar_GetButton(i)
        if button and button.UpdateCooldown then
            button:UpdateCooldown()
        end
    end

    local quickslotButton = ZO_ActionBar_GetButton(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    if quickslotButton and quickslotButton.UpdateCooldown then
        quickslotButton:UpdateCooldown()
    end

    local companionUltimateButton = ZO_ActionBar_GetButton(ACTION_BAR_ULTIMATE_SLOT_INDEX + 1, HOTBAR_CATEGORY_COMPANION)
    if companionUltimateButton and companionUltimateButton.UpdateCooldown then
        companionUltimateButton:UpdateCooldown()
    end
end

function ActionBarFrames:RefreshAssignableActionBars()
    if SKILLS_WINDOW and SKILLS_WINDOW.assignableActionBar then
        SKILLS_WINDOW.assignableActionBar:RefreshAllButtons()
    end

    if GAMEPAD_SKILLS and GAMEPAD_SKILLS.assignableActionBar then
        GAMEPAD_SKILLS.assignableActionBar:RefreshAllButtons()
    end
end

local function WrapActionButtonMethod(methodName)
    if not ActionButton or ActionButton["NagaHooked" .. methodName] then
        return
    end

    if not ZO_PostHook or not ZO_PostHook(ActionButton, methodName, function(button, ...)
        ActionBarFrames:ApplyToButton(button)
    end) then
        return
    end

    ActionButton["NagaHooked" .. methodName] = true
end

function ActionBarFrames:InstallActionSlotHooks()
    if self.actionSlotHooksInstalled or not ZO_PreHook or not ZO_ActionSlot_SetupSlot or not ZO_ActionSlot_ClearSlot then
        return
    end

    local originalSetupSlot = ZO_ActionSlot_SetupSlot
    local setupHooked = ZO_PreHook("ZO_ActionSlot_SetupSlot", function(iconControl, buttonControl, icon, normalFrame, downFrame, cooldownIconControl, mouseOverTexture)
        originalSetupSlot(
            iconControl,
            buttonControl,
            icon,
            GetSetupNormalFrame(normalFrame),
            GetSetupPressedFrame(downFrame),
            cooldownIconControl,
            mouseOverTexture
        )
        return true
    end)

    local originalClearSlot = ZO_ActionSlot_ClearSlot
    local clearHooked = ZO_PreHook("ZO_ActionSlot_ClearSlot", function(iconControl, buttonControl, normalFrame, downFrame, cooldownIconControl, mouseOverTexture)
        originalClearSlot(
            iconControl,
            buttonControl,
            GetSetupNormalFrame(normalFrame),
            GetSetupPressedFrame(downFrame),
            cooldownIconControl,
            mouseOverTexture
        )
        return true
    end)

    self.actionSlotHooksInstalled = setupHooked ~= false and clearHooked ~= false
end

function ActionBarFrames:InstallHooks()
    if self.hooksInstalled then
        return
    end

    self:InstallActionSlotHooks()
    WrapActionButtonMethod("HandleSlotChanged")
    WrapActionButtonMethod("UpdateState")
    WrapActionButtonMethod("UpdateCooldown")
    WrapActionButtonMethod("RefreshCooldown")
    WrapActionButtonMethod("SetUltimateMeter")
    WrapActionButtonMethod("Clear")
    WrapActionButtonMethod("ApplyStyle")

    self.hooksInstalled = true
end

function ActionBarFrames:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTION_UPDATE_COOLDOWNS, function()
        self:ApplyQuickslot()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOTBAR_SLOT_UPDATED, function()
        self:ApplyAll()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_HOTBAR_SLOT_STATE_UPDATED, function()
        self:ApplyAll()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        zo_callLater(function() self:ApplyAll() end, 250)
        zo_callLater(function() self:ApplyAll() end, 550)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
        zo_callLater(function() self:ApplyAll() end, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTIVE_QUICKSLOT_CHANGED, function()
        self:ApplyQuickslot()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTION_SLOT_ABILITY_USED, function(_, actionSlotIndex)
        if ZO_ActionBar_GetButton then
            self:PlayUseShrink(ZO_ActionBar_GetButton(actionSlotIndex))
        end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function() self:ApplyAll() end, 1000)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_POWER_UPDATE, function()
        self:ApplyActiveUltimate()
        self:RefreshUltimatePercentText()
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE, EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ULTIMATE_ABILITY_COST_CHANGED, function()
        self:RefreshUltimatePercentText()
    end)

    self.eventsRegistered = true
end

function ActionBarFrames:RefreshSettings()
    self:StartCooldownTextTicker()
    self:RegisterEvents()
    self:ApplyAll()
    self:RefreshCooldowns()
    self:RefreshCooldownText()
    self:RefreshUltimatePercentText()
    self:RefreshAssignableActionBars()
end

NAGA_UI.OnAddonLoaded(function()
    ActionBarFrames:InstallHooks()
    ActionBarFrames:RefreshSettings()
    zo_callLater(function() ActionBarFrames:ApplyAll() end, 1000)
end)
