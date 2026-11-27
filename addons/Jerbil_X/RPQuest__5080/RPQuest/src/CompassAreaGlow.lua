-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.CompassAreaGlow = {}
local CompassAreaGlow = Addon.CompassAreaGlow

local CONTROL_NAME = "RPQuestCompassAreaGlow"
local UPDATE_NAME = "RPQuest_CompassAreaGlow_Update"
local LISTENER_ACTIVATED = "RPQuest_CompassAreaGlow_PlayerActivated"
local LISTENER_ZONE = "RPQuest_CompassAreaGlow_ZoneChanged"
local LISTENER_GAMEPAD = "RPQuest_CompassAreaGlow_GamepadMode"
local LISTENER_RESIZE = "RPQuest_CompassAreaGlow_ScreenResized"

local END_CAP_WIDTH = 18
local AREA_TEXTURE_RESTING_ALPHA_KEYBOARD = 0.85
local AREA_TEXTURE_RESTING_ALPHA_GAMEPAD = 1.0

local function IsTargetPending(target)
    return type(target) == "table" and (target.currentCount or 0) < (target.requiredCount or 1)
end

local function HasPendingEvaluatableTargets(quest)
    if type(quest) ~= "table" or quest.completed or quest.failed or type(quest.targets) ~= "table" then
        return false
    end
    for _, target in ipairs(quest.targets) do
        if IsTargetPending(target) then
            local hasLocation = (target.worldX ~= nil and target.worldZ ~= nil)
            local hasSearchArea = (target.areaCenterX ~= nil and target.areaCenterY ~= nil and target.areaRadius ~= nil and target.areaRadius > 0)
            if hasLocation or hasSearchArea then
                return true
            end
        end
    end
    return false
end

local function ApplyTintColor(areaTexture)
    local color = Addon.Constants.UI.COMPASS_AREA_GLOW_COLOR
    if not color then
        return
    end
    for _, part in ipairs({ areaTexture.left, areaTexture.right, areaTexture.center }) do
        if part and part.SetColor then
            part:SetColor(color.r, color.g, color.b, color.a or 1.0)
        end
    end
end

function CompassAreaGlow:EnsureControl()
    if self.areaTexture then
        return self.areaTexture
    end

    local areaTexture = WINDOW_MANAGER:CreateControlFromVirtual(CONTROL_NAME, ZO_Compass, "ZO_CompassAreaTexture")
    areaTexture.left = areaTexture.left or areaTexture:GetNamedChild("Left")
    areaTexture.right = areaTexture.right or areaTexture:GetNamedChild("Right")
    areaTexture.center = areaTexture.center or areaTexture:GetNamedChild("Center")
    areaTexture.pin = {
        GetScale = function()
            return 1
        end,
        GetCenter = function()
            return ZO_Compass:GetCenter()
        end,
    }

    local animationIn = ANIMATION_MANAGER:CreateTimelineFromVirtual("CompassAreaTextureAnimationIn")
    if animationIn.GetNumAnimations and animationIn.GetAnimation then
        local numAnims = animationIn:GetNumAnimations()
        local anim1 = numAnims >= 1 and animationIn:GetAnimation(1)
        if anim1 and anim1.SetAnimatedControl and areaTexture.left then
            anim1:SetAnimatedControl(areaTexture.left)
        end
        local anim2 = numAnims >= 2 and animationIn:GetAnimation(2)
        if anim2 and anim2.SetAnimatedControl and areaTexture.right then
            anim2:SetAnimatedControl(areaTexture.right)
        end
        local anim3 = numAnims >= 3 and animationIn:GetAnimation(3)
        if anim3 and anim3.SetAnimatedControl and areaTexture.center then
            anim3:SetAnimatedControl(areaTexture.center)
        end
        for i = 4, numAnims do
            local anim = animationIn:GetAnimation(i)
            if anim and anim.SetAnimatedControl then
                anim:SetAnimatedControl(areaTexture)
            end
        end
    end
    if animationIn.SetSkipAnimationsBehindPlayheadOnInitialPlay then
        animationIn:SetSkipAnimationsBehindPlayheadOnInitialPlay(false)
    end
    areaTexture.animationIn = animationIn
    areaTexture.resetAlphaAnimation = animationIn.GetLastAnimation and animationIn:GetLastAnimation() or nil

    local animationOut = ANIMATION_MANAGER:CreateTimelineFromVirtual("CompassAreaTextureAnimationOut", areaTexture)
    if animationOut.SetHandler then
        animationOut:SetHandler("OnStop", function()
            if not self._isInside then
                areaTexture:SetHidden(true)
                areaTexture:ClearAnchors()
            end
        end)
    end
    areaTexture.animationOut = animationOut

    areaTexture:SetHidden(true)
    self.areaTexture = areaTexture
    self:ApplyPlatformStyle()

    return areaTexture
end

function CompassAreaGlow:ApplyPlatformStyle()
    if not self.areaTexture then
        return
    end
    local areaTexture = self.areaTexture
    local isGamepad = IsInGamepadPreferredMode()
    local template = isGamepad and "ZO_CompassAreaTexture_Gamepad_Template" or "ZO_CompassAreaTexture_Keyboard_Template"
    local restingAlpha = isGamepad and AREA_TEXTURE_RESTING_ALPHA_GAMEPAD or AREA_TEXTURE_RESTING_ALPHA_KEYBOARD
    local platformModifier = isGamepad and "Gamepad/gp_" or ""

    ApplyTemplateToControl(areaTexture, template)

    if areaTexture.resetAlphaAnimation and areaTexture.resetAlphaAnimation.SetEndAlpha then
        areaTexture.resetAlphaAnimation:SetEndAlpha(restingAlpha)
    end
    if self._isInside and areaTexture:GetAlpha() ~= 0 then
        areaTexture:SetAlpha(restingAlpha)
    end

    if areaTexture.left and areaTexture.left.SetTexture then
        areaTexture.left:SetTexture("EsoUI/Art/Compass/" .. platformModifier .. "areapin2frame_ends.dds")
    end
    if areaTexture.right and areaTexture.right.SetTexture then
        areaTexture.right:SetTexture("EsoUI/Art/Compass/" .. platformModifier .. "areapin2frame_ends.dds")
    end
    if areaTexture.center and areaTexture.center.SetTexture then
        areaTexture.center:SetTexture("EsoUI/Art/Compass/" .. platformModifier .. "area2frameAnim_centers.dds")
    end

    ApplyTintColor(areaTexture)
end

function CompassAreaGlow:UpdateDimensions()
    if not self.areaTexture or not self._isInside then
        return
    end
    local areaTexture = self.areaTexture
    local parentWidth, parentHeight = ZO_Compass:GetDimensions()
    local targetWidth = parentWidth + (END_CAP_WIDTH * 2)

    if areaTexture.animationIn and areaTexture.animationIn.GetNumAnimations and areaTexture.animationIn:GetNumAnimations() >= 5 then
        local sizeAnimation = areaTexture.animationIn:GetAnimation(5)
        if sizeAnimation and sizeAnimation.IsPlaying and sizeAnimation:IsPlaying() and sizeAnimation.SetEndWidth then
            sizeAnimation:SetEndWidth(targetWidth)
            return
        end
    end
    areaTexture:SetWidth(targetWidth)
    areaTexture:SetHeight(parentHeight)
end

function CompassAreaGlow:SetInside(inside)
    local nextState = (inside == true)
    if nextState == (self._isInside == true) then
        return
    end
    self._isInside = nextState

    local areaTexture = self:EnsureControl()
    if nextState then
        if areaTexture.animationOut and areaTexture.animationOut:IsPlaying() then
            areaTexture.animationOut:Stop()
        end
        self:ApplyPlatformStyle()
        areaTexture:ClearAnchors()
        areaTexture:SetAnchor(CENTER, ZO_Compass, CENTER, 0, 0)
        local parentWidth, parentHeight = ZO_Compass:GetDimensions()
        areaTexture:SetDimensions(parentWidth + (END_CAP_WIDTH * 2), parentHeight)
        areaTexture:SetAlpha(0)
        areaTexture:SetHidden(false)
        if areaTexture.animationIn then
            areaTexture.animationIn:PlayFromStart()
        end
    else
        if areaTexture.animationIn and areaTexture.animationIn:IsPlaying() then
            areaTexture.animationIn:Stop()
        end
        if not areaTexture:IsHidden() and areaTexture.animationOut then
            areaTexture.animationOut:PlayFromStart()
        else
            areaTexture:SetHidden(true)
            areaTexture:ClearAnchors()
        end
    end
end

function CompassAreaGlow:IsPlayerInsideActiveTargetArea(quest, playerZoneId, playerWorldX, playerWorldZ, playerMapId, playerX, playerY)
    if type(quest) ~= "table" or quest.completed or quest.failed or type(quest.targets) ~= "table" then
        return false
    end

    for _, target in ipairs(quest.targets) do
        if IsTargetPending(target) then
            if target.worldX ~= nil and target.worldZ ~= nil then
                if Addon.WorldMapArea:IsPlayerInsideTargetLocation(target, playerZoneId, playerWorldX, playerWorldZ) then
                    return true
                end
            end

            if quest.mapId and quest.mapId > 0 and playerMapId == quest.mapId and playerX and playerY then
                if target.areaCenterX and target.areaCenterY and target.areaRadius and target.areaRadius > 0 then
                    local effectiveRadius = Addon.WorldMapArea:GetEffectiveAreaRadius(target.areaRadius)
                    local dx = playerX - target.areaCenterX
                    local dy = playerY - target.areaCenterY
                    if ((dx * dx) + (dy * dy)) <= (effectiveRadius * effectiveRadius) then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function CompassAreaGlow:EvaluateCurrentPosition(preloadedQuest)
    local activeQuest = preloadedQuest or Addon.QuestRepository:GetActiveQuest()
    if not HasPendingEvaluatableTargets(activeQuest) then
        self:SetInside(false)
        return false
    end

    local zoneId, worldX, _, worldZ = GetUnitWorldPosition("player")
    local playerMapId, playerX, playerY
    if DoesCurrentMapMatchMapForPlayerLocation() then
        playerMapId = GetCurrentMapId()
        playerX, playerY = GetMapPlayerPosition("player")
    end

    local inside = self:IsPlayerInsideActiveTargetArea(activeQuest, zoneId, worldX, worldZ, playerMapId, playerX, playerY)
    self:SetInside(inside)
    return inside
end

function CompassAreaGlow:UpdatePollingState()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    local shouldPoll = HasPendingEvaluatableTargets(activeQuest)
    self._isPolling = self._isPolling or false

    if shouldPoll and not self._isPolling then
        local interval = Addon.Constants.COMPASS_AREA_GLOW_POLL_INTERVAL_MS or 500
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, interval, function()
            self:OnUpdateTick()
        end)
        self._isPolling = true
    elseif not shouldPoll and self._isPolling then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        self._isPolling = false
    end

    if shouldPoll then
        self:EvaluateCurrentPosition(activeQuest)
    else
        self:SetInside(false)
    end
end

function CompassAreaGlow:OnUpdateTick()
    if not self._isPolling then
        return
    end
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if not HasPendingEvaluatableTargets(activeQuest) then
        self:UpdatePollingState()
        return
    end
    self:EvaluateCurrentPosition(activeQuest)
end

function CompassAreaGlow:IsGlowVisible()
    if not self.areaTexture then
        return false
    end
    return (not self.areaTexture:IsHidden()) and (not ZO_Compass:IsHidden())
end

function CompassAreaGlow:Initialize()
    if self.isInitialized then
        return
    end

    self._isInside = false
    self._isPolling = false
    local areaTexture = self:EnsureControl()
    areaTexture:SetHidden(true)

    Addon.QuestRepository:RegisterListener(function()
        self:UpdatePollingState()
    end)

    EVENT_MANAGER:RegisterForEvent(LISTENER_ACTIVATED, EVENT_PLAYER_ACTIVATED, function()
        self:UpdatePollingState()
    end)
    EVENT_MANAGER:RegisterForEvent(LISTENER_ZONE, EVENT_ZONE_CHANGED, function()
        self:UpdatePollingState()
    end)
    EVENT_MANAGER:RegisterForEvent(LISTENER_GAMEPAD, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:ApplyPlatformStyle()
    end)
    EVENT_MANAGER:RegisterForEvent(LISTENER_RESIZE, EVENT_SCREEN_RESIZED, function()
        self:UpdateDimensions()
    end)

    self.isInitialized = true
    self:UpdatePollingState()
end
