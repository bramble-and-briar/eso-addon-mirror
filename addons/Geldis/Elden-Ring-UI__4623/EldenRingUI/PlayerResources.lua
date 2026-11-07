local SHIELD_BAR_TEXTURE = "EldenRingUI/Textures/ERShieldBar.dds"

local PLAYER_RESOURCES = {
    [POWERTYPE_HEALTH]  = { name = "Health",  texture = "EldenRingUI/Textures/ERHealthBar.dds",  width = 300, scaleFactor = 45, yOffset = 0 },
    [POWERTYPE_MAGICKA] = { name = "Magicka", texture = "EldenRingUI/Textures/ERMagickaBar.dds", width = 300, scaleFactor = 75, yOffset = 18 },
    [POWERTYPE_STAMINA] = { name = "Stamina", texture = "EldenRingUI/Textures/ERStaminaBar.dds", width = 300, scaleFactor = 75, yOffset = 36 },
}

local function FormatResource(value)
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.0fk", value / 1000)
    end
    return tostring(value)
end

local function UpdatePlayerShieldVisuals()
    local healthBar = PlayerResourceContainer:GetNamedChild("Health")
    if not healthBar then return end

    local shieldBar = healthBar:GetNamedChild("ShieldOverlay")
    if not shieldBar then return end

    local shieldValue, shieldMax = GetUnitAttributeVisualizerEffectInfo(
        "player",
        ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION,
        ATTRIBUTE_HEALTH,
        COMBAT_MECHANIC_FLAGS_HEALTH
    )

    if not shieldMax or shieldMax <= 0 or shieldValue <= 0 then
        shieldBar:SetHidden(true)
        return
    end

    local shieldWidth = math.min(shieldValue / PLAYER_RESOURCES[POWERTYPE_HEALTH].scaleFactor, healthBar:GetWidth())
    shieldBar:SetWidth(shieldWidth)
    shieldBar:SetTextureCoords(0, shieldWidth / 2048, 0, 1)
    shieldBar:SetHidden(false)
end

local function StartDelayedBar(bar, delayedBar, resourceData, powerType, powerMax)
    local barWidth = bar:GetWidth()
    local delayWidth = (resourceData.lastValue / powerMax) * barWidth

    delayedBar:SetWidth(delayWidth)
    delayedBar:SetTextureCoords(0, delayWidth / 2048, 0, 1)
    delayedBar:SetHidden(false)
    delayedBar:SetHandler("OnUpdate", nil)
    delayedBar.lastTime = nil

    local timerName = "ERUI_Delay_" .. powerType
    EVENT_MANAGER:UnregisterForUpdate(timerName)
    EVENT_MANAGER:RegisterForUpdate(timerName, 1000, function()
        EVENT_MANAGER:UnregisterForUpdate(timerName)

        delayedBar:SetHandler("OnUpdate", function(self, time)
            local dt = self.lastTime and (time - self.lastTime) or 0
            self.lastTime = time
            if dt == 0 then return end

            local targetW = (GetUnitPower("player", powerType) / resourceData.lastMax) * barWidth
            local nextW = self:GetWidth() - (300 * dt)

            if nextW <= targetW then
                self:SetHidden(true)
                self:SetHandler("OnUpdate", nil)
                self.lastTime = nil
            else
                self:SetWidth(nextW)
                self:SetTextureCoords(0, nextW / 2048, 0, 1)
            end
        end)
    end)
end

local function UpdatePlayerPower(_, unitTag, _, powerType, powerValue, powerMax)
    local resourceData = PLAYER_RESOURCES[powerType]
    if unitTag ~= "player" or not resourceData then return end

    local bar = PlayerResourceContainer:GetNamedChild(resourceData.name)
    if not bar or powerMax <= 0 then return end

    if resourceData.lastMax ~= powerMax then
        local newWidth = powerMax / resourceData.scaleFactor
        local texRight = newWidth / 2048
        bar:SetWidth(newWidth)

        local yellowLine = bar:GetNamedChild("YellowLine")
        if yellowLine then yellowLine:SetTextureCoords(0, texRight, 0, 1) end

        local backdrop = bar:GetNamedChild("Backdrop")
        if backdrop then backdrop:SetTextureCoords(0, texRight, 0, 1) end

        resourceData.lastMax = powerMax
    end

    resourceData.lastValue = resourceData.lastValue or powerValue

    local delayedBar = bar:GetNamedChild("DelayedBar")
    if delayedBar and powerValue < resourceData.lastValue then
        local dropPercent = (resourceData.lastValue - powerValue) / powerMax
        if dropPercent >= 0.05 then
            StartDelayedBar(bar, delayedBar, resourceData, powerType, powerMax)
        end
    end

    resourceData.lastValue = powerValue

    ZO_StatusBar_SmoothTransition(bar, powerValue, powerMax)
    bar:GetNamedChild("PercentLabel"):SetText(math.floor(powerValue * 100 / powerMax) .. "%")
    bar:GetNamedChild("ValueLabel"):SetText(FormatResource(powerValue))

    if powerType == POWERTYPE_HEALTH then
        UpdatePlayerShieldVisuals()
    end
end

local function ApplyResourceStyle(bar)
    bar:SetDrawTier(DT_MEDIUM)
    bar:SetDrawLayer(DL_CONTROLS)

    local backdrop = bar:GetNamedChild("Backdrop")
    if backdrop then
        backdrop:SetDrawTier(DT_LOW)
        backdrop:SetDrawLayer(DL_BACKGROUND)
        backdrop:SetDrawLevel(0)
    end

    local delayedBar = WINDOW_MANAGER:CreateControl(bar:GetName() .. "DelayedBar", bar, CT_TEXTURE)
    delayedBar:SetTexture("EldenRingUI/Textures/DelayedBar.dds")
    delayedBar:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, 0)
    delayedBar:SetAnchor(BOTTOMLEFT, bar, BOTTOMLEFT, 0, 0)
    delayedBar:SetDrawTier(DT_LOW)
    delayedBar:SetDrawLayer(DL_BACKGROUND)
    delayedBar:SetDrawLevel(1)
    delayedBar:SetHidden(true)

    local yellowLine = WINDOW_MANAGER:CreateControl(bar:GetName() .. "YellowLine", bar, CT_TEXTURE)
    yellowLine:SetTexture("EldenRingUI/Textures/lowline.dds")
    yellowLine:SetAnchor(BOTTOMLEFT, bar, BOTTOMLEFT, 0, 0)
    yellowLine:SetAnchor(BOTTOMRIGHT, bar, BOTTOMRIGHT, 0, 0)
    yellowLine:SetHeight(12)
    yellowLine:SetDrawTier(DT_MEDIUM)
    yellowLine:SetDrawLayer(DL_CONTROLS)
    yellowLine:SetDrawLevel(3)

    local icon = bar:GetNamedChild("Icon")
    if icon then
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetDrawLevel(4)
    end
end

local function SetupCurrentValueIcon(bar)
    local currentValueIcon = bar:GetNamedChild("CurrentValueIcon")
    if not currentValueIcon then return end

    currentValueIcon:SetDrawLayer(DL_CONTROLS)
    currentValueIcon:SetDrawLevel(2)

    local lastPercent = -1
    local lastWidth = -1

    bar:SetHandler("OnUpdate", function(self)
        local _, max = self:GetMinMax()
        if not max or max <= 0 then return end

        local percent = self:GetValue() / max
        local barWidth = self:GetWidth()

        if percent ~= lastPercent or barWidth ~= lastWidth then
            currentValueIcon:ClearAnchors()
            currentValueIcon:SetAnchor(CENTER, self, LEFT, barWidth * percent - 13, -1)
            lastPercent = percent
            lastWidth = barWidth
        end
    end)
end

local function CreateShieldOverlay(bar)
    local shieldBar = WINDOW_MANAGER:CreateControl("$(parent)ShieldOverlay", bar, CT_TEXTURE)
    shieldBar:SetTexture(SHIELD_BAR_TEXTURE)
    shieldBar:SetAnchor(TOPLEFT, bar, TOPLEFT, 0, 0)
    shieldBar:SetAnchor(BOTTOMLEFT, bar, BOTTOMLEFT, 0, 0)
    shieldBar:SetDrawLayer(DL_CONTROLS)
    shieldBar:SetDrawLevel(2)
    shieldBar:SetHidden(true)
end

local function OnPlayerVisualChanged(_, unitTag, unitAttributeVisual)
    if unitTag == "player" and unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
        UpdatePlayerShieldVisuals()
    end
end

local function InitializePlayerModule()
    ZO_PlayerAttributeHealth:SetHidden(true)
    ZO_PlayerAttributeMagicka:SetHidden(true)
    ZO_PlayerAttributeStamina:SetHidden(true)

    local playerFragment = ZO_SimpleSceneFragment:New(PlayerResourceContainer)
    HUD_SCENE:AddFragment(playerFragment)
    HUD_UI_SCENE:AddFragment(playerFragment)

    for powerType, data in pairs(PLAYER_RESOURCES) do
        local bar = CreateControlFromVirtual("$(parent)" .. data.name, PlayerResourceContainer, "ERUI_PlayerBarTemplate")
        bar:SetAnchor(TOPLEFT, PlayerResourceContainer, TOPLEFT, 0, data.yOffset)
        bar:SetTexture(data.texture)
        bar:GetNamedChild("NameLabel"):SetText(data.name)

        ApplyResourceStyle(bar)
        SetupCurrentValueIcon(bar)

        if powerType == POWERTYPE_HEALTH then
            CreateShieldOverlay(bar)
        end

        local cur, max = GetUnitPower("player", powerType)
        UpdatePlayerPower(nil, "player", nil, powerType, cur, max)
    end

    EVENT_MANAGER:RegisterForEvent("ERUI_PlayerResources", EVENT_POWER_UPDATE, UpdatePlayerPower)
    EVENT_MANAGER:AddFilterForEvent("ERUI_PlayerResources", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

    local shieldEvents = {
        ERUI_ShieldAdded = EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,
        ERUI_ShieldRemoved = EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED,
        ERUI_ShieldUpdated = EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED,
    }
    for name, event in pairs(shieldEvents) do
        EVENT_MANAGER:RegisterForEvent(name, event, OnPlayerVisualChanged)
        EVENT_MANAGER:AddFilterForEvent(name, event, REGISTER_FILTER_UNIT_TAG, "player")
    end

    UpdatePlayerShieldVisuals()
end

EVENT_MANAGER:RegisterForEvent("ERUI_PlayerInit", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= "EldenRingUI" then return end
    EVENT_MANAGER:UnregisterForEvent("ERUI_PlayerInit", EVENT_ADD_ON_LOADED)
    InitializePlayerModule()
end)