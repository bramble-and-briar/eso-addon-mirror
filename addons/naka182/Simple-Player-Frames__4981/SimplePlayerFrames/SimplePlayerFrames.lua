local SimplePlayerFrames = {}
SimplePlayerFrames.name = "SimplePlayerFrames"

local defaults = {
    accountWide = true, 
    lockUI = false,
    layout = "Vertical", 
    frameWidth = 250, 
    borderTop = 1,
    borderBottom = 1,
    borderLateral = 1,
    healthHeight = 24,
    magickaHeight = 20,
    staminaHeight = 20,
    nameFontSize = 19,
    barFontSize = 18,
    fontChoice = "FCUI",
    fontStyle = "outline",
    showName = true,
    showCP = true,
    
    healthColor = {0.75, 0.15, 0.15, 1},
    useHealthGradient = false,
    healthGradientColor = {0.40, 0.05, 0.05, 1},
    shieldColor = {0.80, 0.80, 1.00, 0.5},
    useShieldGradient = false,
    shieldGradientColor = {0.40, 0.40, 0.80, 0.5},
    magickaColor = {0.15, 0.30, 0.85, 1},
    useMagickaGradient = false,
    magickaGradientColor = {0.05, 0.15, 0.50, 1},
    staminaColor = {0.20, 0.70, 0.20, 1},
    useStaminaGradient = false,
    staminaGradientColor = {0.05, 0.40, 0.05, 1},

    posX = 300, 
    posY = 300, 
}

local function FormatPercent(current, max)
    if not max or max <= 0 then return "0%" end
    return math.floor((current / max) * 100) .. "%"
end

local function GetWidthPercent(current, max)
    if not max or max <= 0 then return 0 end
    local p = current / max
    if p > 1 then return 1 end
    if p < 0 then return 0 end
    return p
end

local function FormatAbbrev(val)
    if val >= 1000 then
        local formatted = string.format("%.1fk", val / 1000)
        return formatted:gsub("%.0k", "k")
    end
    return tostring(val)
end

function SimplePlayerFrames:Initialize()
    self.accountVars = ZO_SavedVars:NewAccountWide("SimplePlayerFramesVars", 1, nil, defaults, GetWorldName())
    self.charVars = ZO_SavedVars:NewCharacterIdSettings("SimplePlayerFramesVars", 1, nil, defaults)

    if self.accountVars.accountWide then
        self.savedVars = self.accountVars
    else
        self.savedVars = self.charVars
    end

    self:CreateUI()
    self:BuildMenu()
    self:ApplySettings()

    -- Otimização Avançada: Filtra pelo PowerType para atualizar apenas a barra necessária
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_POWER_UPDATE, function(_, _, _, powerType, powerValue, powerMax, powerEffectiveMax)
        if powerType == POWERTYPE_HEALTH then
            self:UpdateHealth(powerValue, powerEffectiveMax)
        elseif powerType == POWERTYPE_MAGICKA then
            self:UpdateMagicka(powerValue, powerEffectiveMax)
        elseif powerType == POWERTYPE_STAMINA then
            self:UpdateStamina(powerValue, powerEffectiveMax)
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

    local function OnVisualUpdated(_, _, visualType)
        if visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            self:UpdateShield()
        end
    end

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnVisualUpdated)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualUpdated)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualUpdated)
    EVENT_MANAGER:AddFilterForEvent(self.name, EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, function()
        self:UpdateAllPowers()
        self:UpdateNameAndIcons()
    end)
end

function SimplePlayerFrames:CreateUI()
    self.control = WINDOW_MANAGER:CreateTopLevelWindow("SimplePlayerFrames_Window")
    self.control:SetMouseEnabled(not self.savedVars.lockUI)
    self.control:SetMovable(not self.savedVars.lockUI)
    self.control:SetClampedToScreen(true)
    
    local fragment = ZO_HUDFadeSceneFragment:New(self.control)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    SIEGE_BAR_SCENE:AddFragment(fragment)
    
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.savedVars.posX, self.savedVars.posY)

    self.control:SetHandler("OnMoveStop", function(control)
        self.savedVars.posX = control:GetLeft()
        self.savedVars.posY = control:GetTop()
    end)

    self.bg = WINDOW_MANAGER:CreateControl(nil, self.control, CT_BACKDROP)
    self.bg:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, 30)
    self.bg:SetCenterColor(0, 0, 0, 0) 
    self.bg:SetEdgeColor(0, 0, 0, 0)
    self.bg:SetDrawLayer(DL_BACKGROUND)

    self.nameLabel = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
    self.nameLabel:SetColor(1, 1, 1, 1)

    self.cpLabel = WINDOW_MANAGER:CreateControl(nil, self.control, CT_LABEL)
    self.cpLabel:SetColor(1, 1, 1, 1)

    local function CreateCustomBar(parent)
        local container = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
        container:SetCenterColor(0, 0, 0, 0.85)
        container:SetEdgeColor(0, 0, 0, 0)
        container:SetDrawLayer(DL_BACKGROUND)

        local fill = WINDOW_MANAGER:CreateControl(nil, container, CT_STATUSBAR)
        fill:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
        fill:SetMinMax(0, 1)
        fill:SetValue(1)
        fill:SetDrawLayer(DL_CONTROLS)
        fill:SetDrawLevel(1)

        local valueLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
        valueLabel:SetAnchor(LEFT, container, LEFT, 5, 0)
        valueLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        valueLabel:SetText("-")
        valueLabel:SetColor(1, 1, 1, 1)
        valueLabel:SetDrawLayer(DL_CONTROLS)
        valueLabel:SetDrawLevel(3)

        local pctLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
        pctLabel:SetAnchor(RIGHT, container, RIGHT, -5, 0)
        pctLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        pctLabel:SetText("-%")
        pctLabel:SetColor(1, 1, 1, 1)
        pctLabel:SetDrawLayer(DL_CONTROLS)
        pctLabel:SetDrawLevel(3)

        return container, fill, valueLabel, pctLabel
    end

    self.healthContainer, self.healthFill, self.healthValue, self.healthPct = CreateCustomBar(self.bg)
    self.magickaContainer, self.magickaFill, self.magickaValue, self.magickaPct = CreateCustomBar(self.bg)
    self.staminaContainer, self.staminaFill, self.staminaValue, self.staminaPct = CreateCustomBar(self.bg)

    self.shieldFill = WINDOW_MANAGER:CreateControl(nil, self.healthContainer, CT_STATUSBAR)
    self.shieldFill:SetAnchor(TOPLEFT, self.healthContainer, TOPLEFT, 0, 0)
    self.shieldFill:SetMinMax(0, 1)
    self.shieldFill:SetValue(1)
    self.shieldFill:SetDrawLayer(DL_CONTROLS)
    self.shieldFill:SetDrawLevel(2) 
    self.shieldFill:SetHidden(true)
    
    self.shieldAnimTimeline = ANIMATION_MANAGER:CreateTimeline()
    local alphaAnim = self.shieldAnimTimeline:InsertAnimation(ANIMATION_ALPHA, self.shieldFill)
    alphaAnim:SetAlphaValues(0, 1)
    alphaAnim:SetDuration(350)
end

function SimplePlayerFrames:ApplySettings()
    local sv = self.savedVars
    
    local fontPath = sv.fontChoice
    if fontPath ~= "FCUI" then
        if LibMediaProvider:Fetch("font", sv.fontChoice) then
            fontPath = LibMediaProvider:Fetch("font", sv.fontChoice)
        end
    end

    local styleStr = sv.fontStyle
    if styleStr == "none" then styleStr = "" end

    local nameFontString = string.format("%s|%d|%s", fontPath, sv.nameFontSize, styleStr)
    local barFontString = string.format("%s|%d|%s", fontPath, sv.barFontSize, styleStr)
    
    self.nameLabel:SetFont(nameFontString)
    self.cpLabel:SetFont(nameFontString)
    
    self.healthValue:SetFont(barFontString)
    self.healthPct:SetFont(barFontString)
    self.magickaValue:SetFont(barFontString)
    self.magickaPct:SetFont(barFontString)
    self.staminaValue:SetFont(barFontString)
    self.staminaPct:SetFont(barFontString)

    local function ApplyColor(control, color, useGrad, gradColor)
        if useGrad then
            control:SetGradientColors(color[1], color[2], color[3], color[4], gradColor[1], gradColor[2], gradColor[3], gradColor[4])
        else
            control:SetGradientColors(color[1], color[2], color[3], color[4], color[1], color[2], color[3], color[4])
        end
    end

    ApplyColor(self.healthFill, sv.healthColor, sv.useHealthGradient, sv.healthGradientColor)
    ApplyColor(self.shieldFill, sv.shieldColor, sv.useShieldGradient, sv.shieldGradientColor)
    ApplyColor(self.magickaFill, sv.magickaColor, sv.useMagickaGradient, sv.magickaGradientColor)
    ApplyColor(self.staminaFill, sv.staminaColor, sv.useStaminaGradient, sv.staminaGradientColor)

    self.healthContainer:ClearAnchors()
    self.magickaContainer:ClearAnchors()
    self.staminaContainer:ClearAnchors()

    local barInnerWidth = sv.frameWidth - (sv.borderLateral * 2)
    self.control:SetDimensions(sv.frameWidth, 100) -- Initial size; recalculated after layout below.
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.savedVars.posX, self.savedVars.posY)

    if sv.layout == "Compact" then
        local maxBottomHeight = math.max(sv.magickaHeight, sv.staminaHeight)
        local totalBgHeight = sv.borderTop + sv.healthHeight + maxBottomHeight + sv.borderBottom
        self.bg:SetDimensions(sv.frameWidth, totalBgHeight)

        local magickaInnerWidth = math.floor(barInnerWidth / 2)
        local staminaInnerWidth = barInnerWidth - magickaInnerWidth

        local yHealth = sv.borderTop
        local yMagStam = yHealth + sv.healthHeight

        self.healthWidth = barInnerWidth
        self.healthContainer:SetDimensions(self.healthWidth, sv.healthHeight)
        self.healthContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yHealth)

        self.magickaWidth = magickaInnerWidth
        self.magickaContainer:SetDimensions(self.magickaWidth, sv.magickaHeight)
        self.magickaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yMagStam)

        self.staminaWidth = staminaInnerWidth
        self.staminaContainer:SetDimensions(self.staminaWidth, sv.staminaHeight)
        self.staminaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral + magickaInnerWidth, yMagStam)

    elseif sv.layout == "Horizontal" then
        local maxBarHeight = math.max(sv.healthHeight, sv.magickaHeight, sv.staminaHeight)
        local totalBgHeight = sv.borderTop + maxBarHeight + sv.borderBottom
        self.bg:SetDimensions(sv.frameWidth, totalBgHeight)

        local gap = 5
        local w = math.floor((barInnerWidth - (gap * 2)) / 3)
        local healthW = barInnerWidth - (w * 2) - (gap * 2)

        local yBar = sv.borderTop

        self.magickaWidth = w
        self.magickaContainer:SetDimensions(self.magickaWidth, sv.magickaHeight)
        self.magickaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yBar)

        self.healthWidth = healthW
        self.healthContainer:SetDimensions(self.healthWidth, sv.healthHeight)
        self.healthContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral + w + gap, yBar)

        self.staminaWidth = w
        self.staminaContainer:SetDimensions(self.staminaWidth, sv.staminaHeight)
        self.staminaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral + w + gap + healthW + gap, yBar)

    elseif sv.layout == "Pyramid" then
        local maxBottomHeight = math.max(sv.magickaHeight, sv.staminaHeight)
        local gapY = 0 
        local totalBgHeight = sv.borderTop + sv.healthHeight + gapY + maxBottomHeight + sv.borderBottom
        self.bg:SetDimensions(sv.frameWidth, totalBgHeight)

        local bottomW = math.floor(barInnerWidth / 2)
        local stamW = barInnerWidth - bottomW

        self.healthWidth = math.floor(barInnerWidth * 0.6)
        local healthOffsetX = sv.borderLateral + math.floor((barInnerWidth - self.healthWidth) / 2)
        
        local yHealth = sv.borderTop
        self.healthContainer:SetDimensions(self.healthWidth, sv.healthHeight)
        self.healthContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, healthOffsetX, yHealth)

        local yMagStam = yHealth + sv.healthHeight + gapY

        self.magickaWidth = bottomW
        self.magickaContainer:SetDimensions(self.magickaWidth, sv.magickaHeight)
        self.magickaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yMagStam)

        self.staminaWidth = stamW
        self.staminaContainer:SetDimensions(self.staminaWidth, sv.staminaHeight)
        self.staminaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral + bottomW, yMagStam)

    else
        local totalBgHeight = sv.borderTop + sv.healthHeight + sv.magickaHeight + sv.staminaHeight + sv.borderBottom
        self.bg:SetDimensions(sv.frameWidth, totalBgHeight)

        local yHealth = sv.borderTop
        local yMagicka = yHealth + sv.healthHeight
        local yStamina = yMagicka + sv.magickaHeight

        self.healthWidth = barInnerWidth
        self.magickaWidth = barInnerWidth
        self.staminaWidth = barInnerWidth

        self.healthContainer:SetDimensions(self.healthWidth, sv.healthHeight)
        self.healthContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yHealth)

        self.magickaContainer:SetDimensions(self.magickaWidth, sv.magickaHeight)
        self.magickaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yMagicka)

        self.staminaContainer:SetDimensions(self.staminaWidth, sv.staminaHeight)
        self.staminaContainer:SetAnchor(TOPLEFT, self.bg, TOPLEFT, sv.borderLateral, yStamina)
    end

    -- The background begins 30 units below the top-level control.
    -- Keep the movable/clamped control large enough to contain the full layout.
    local totalControlHeight = 30 + self.bg:GetHeight()
    self.control:SetDimensions(sv.frameWidth, totalControlHeight)

    self.nameLabel:ClearAnchors()
    self.cpLabel:ClearAnchors()

    if sv.layout == "Horizontal" then
        self.nameLabel:SetAnchor(BOTTOMLEFT, self.magickaContainer, TOPLEFT, 0, -2)
        self.cpLabel:SetAnchor(BOTTOMRIGHT, self.staminaContainer, TOPRIGHT, 0, -2)
    else
        self.nameLabel:SetAnchor(BOTTOMLEFT, self.healthContainer, TOPLEFT, 0, -2)
        self.cpLabel:SetAnchor(BOTTOMRIGHT, self.healthContainer, TOPRIGHT, 0, -2)
    end

    self.healthFill:SetDimensions(self.healthWidth, sv.healthHeight)
    self.magickaFill:SetDimensions(self.magickaWidth, sv.magickaHeight)
    self.staminaFill:SetDimensions(self.staminaWidth, sv.staminaHeight)

    self:UpdateAllPowers()
end

function SimplePlayerFrames:UpdateNameAndIcons()
    local sv = self.savedVars

    if sv.showName then
        local name = GetUnitName("player") or "Player"
        local classId = GetUnitClassId("player")
        local classIconStr = ""
        if classId > 0 then
            classIconStr = zo_iconFormat(GetClassIcon(classId), 22, 22)
        end
        self.nameLabel:SetText(name .. " " .. classIconStr)
        self.nameLabel:SetHidden(false)
    else
        self.nameLabel:SetHidden(true)
    end

    if sv.showCP then
        local levelStr = ""
        if IsUnitChampion("player") then
            local cpIcon = zo_iconFormat("EsoUI/Art/Champion/champion_icon_32.dds", 22, 22)
            levelStr = cpIcon .. GetUnitChampionPoints("player")
        else
            levelStr = tostring(GetUnitLevel("player"))
        end
        self.cpLabel:SetText(levelStr)
        self.cpLabel:SetHidden(false)
    else
        self.cpLabel:SetHidden(true)
    end
end

function SimplePlayerFrames:UpdateShield()
    local currentHealth, maxHealth, effectiveMaxHealth =
        GetUnitPower("player", POWERTYPE_HEALTH)

    -- Clear stale shield visuals if health data is unavailable.
    if not currentHealth or not maxHealth or maxHealth <= 0 then
        self.shieldFill:SetHidden(true)
        self.shieldFill:SetDimensions(0, self.savedVars.healthHeight)
        self.healthValue:SetText("0")
        return
    end

    -- A dead player should not retain a previously displayed shield overlay.
    if currentHealth <= 0 then
        self.shieldFill:SetHidden(true)
        self.shieldFill:SetDimensions(0, self.savedVars.healthHeight)
        self.healthValue:SetText(tostring(currentHealth))
        return
    end

    local shieldVal = GetUnitAttributeVisualizerEffectInfo(
        "player",
        ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION,
        ATTRIBUTE_HEALTH,
        POWERTYPE_HEALTH
    ) or 0

    -- Prefer effective maximum health when available, falling back to max health.
    local shieldReference = effectiveMaxHealth
    if not shieldReference or shieldReference <= 0 then
        shieldReference = maxHealth
    end

    if shieldVal > 0 then
        if self.shieldFill:IsHidden() then
            self.shieldFill:SetHidden(false)
            self.shieldAnimTimeline:PlayFromStart()
        end

        self.shieldFill:SetDimensions(
            self.healthWidth * GetWidthPercent(shieldVal, shieldReference),
            self.savedVars.healthHeight
        )

        local shieldText = FormatAbbrev(shieldVal)
        self.healthValue:SetText(tostring(currentHealth) .. " [" .. shieldText .. "]")
    else
        self.shieldFill:SetHidden(true)
        self.shieldFill:SetDimensions(0, self.savedVars.healthHeight)
        self.healthValue:SetText(tostring(currentHealth))
    end
end

function SimplePlayerFrames:UpdateHealth(powerValue, powerMax)
    if not powerMax or powerMax <= 0 then return end
    self.healthPct:SetText(FormatPercent(powerValue, powerMax))
    self.healthFill:SetDimensions(self.healthWidth * GetWidthPercent(powerValue, powerMax), self.savedVars.healthHeight)
    self:UpdateShield()
end

function SimplePlayerFrames:UpdateMagicka(powerValue, powerMax)
    if not powerMax or powerMax <= 0 then return end
    self.magickaValue:SetText(powerValue)
    self.magickaPct:SetText(FormatPercent(powerValue, powerMax))
    self.magickaFill:SetDimensions(self.magickaWidth * GetWidthPercent(powerValue, powerMax), self.savedVars.magickaHeight)
end

function SimplePlayerFrames:UpdateStamina(powerValue, powerMax)
    if not powerMax or powerMax <= 0 then return end
    self.staminaValue:SetText(powerValue)
    self.staminaPct:SetText(FormatPercent(powerValue, powerMax))
    self.staminaFill:SetDimensions(self.staminaWidth * GetWidthPercent(powerValue, powerMax), self.savedVars.staminaHeight)
end

function SimplePlayerFrames:UpdateAllPowers()
    local cHealth, mHealth, eHealth = GetUnitPower("player", POWERTYPE_HEALTH)
    local healthMax = (eHealth and eHealth > 0) and eHealth or mHealth
    if healthMax and healthMax > 0 then self:UpdateHealth(cHealth, healthMax) end

    local cMag, mMag, eMag = GetUnitPower("player", POWERTYPE_MAGICKA)
    local magickaMax = (eMag and eMag > 0) and eMag or mMag
    if magickaMax and magickaMax > 0 then self:UpdateMagicka(cMag, magickaMax) end

    local cStam, mStam, eStam = GetUnitPower("player", POWERTYPE_STAMINA)
    local staminaMax = (eStam and eStam > 0) and eStam or mStam
    if staminaMax and staminaMax > 0 then self:UpdateStamina(cStam, staminaMax) end
end

function SimplePlayerFrames:BuildMenu()
    local fontChoices = {"FCUI", "ZoFontGameBold", "ZoFontGame"}
    for _, font in ipairs(LibMediaProvider:List("font")) do
        if font ~= "FCUI" then table.insert(fontChoices, font) end
    end

    local panelData = {
        type = "panel",
        name = "Simple Player Frames",
        displayName = "Simple Player Frames",
        author = "nakamura182",
        version = "1.0.3",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "checkbox",
            name = "Account Wide Settings",
            tooltip = "If enabled, the same settings will be used for all characters. (Close and reopen this menu after changing to update visuals)",
            getFunc = function() return self.accountVars.accountWide end,
            setFunc = function(value) 
                self.accountVars.accountWide = value
                if value then
                    self.savedVars = self.accountVars
                else
                    self.savedVars = self.charVars
                end
                self:ApplySettings()
            end,
            requiresReload = true,
        },
        {
            type = "checkbox",
            name = "Lock UI",
            tooltip = "Lock the frames in place so they cannot be moved accidentally.",
            getFunc = function() return self.savedVars.lockUI end,
            setFunc = function(value) 
                self.savedVars.lockUI = value
                self.control:SetMouseEnabled(not value)
                self.control:SetMovable(not value)
            end,
        },
        {
            type = "dropdown",
            name = "Layout Style",
            choices = {"Vertical", "Compact", "Horizontal", "Pyramid"},
            getFunc = function() return self.savedVars.layout end,
            setFunc = function(value) 
                self.savedVars.layout = value 
                if value == "Horizontal" then
                    self.savedVars.frameWidth = 600
                elseif value == "Pyramid" then
                    self.savedVars.frameWidth = 400
                elseif value == "Vertical" or value == "Compact" then
                    self.savedVars.frameWidth = 250
                end
                self:ApplySettings() 
            end,
        },
        {
            type = "dropdown",
            name = "Text Font",
            choices = fontChoices,
            getFunc = function() return self.savedVars.fontChoice end,
            setFunc = function(value) 
                self.savedVars.fontChoice = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "dropdown",
            name = "Font Outline / Style",
            choices = {"none", "outline", "shadow", "soft-shadow-thick", "soft-shadow-thin"},
            getFunc = function() return self.savedVars.fontStyle end,
            setFunc = function(value) 
                self.savedVars.fontStyle = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "checkbox",
            name = "Show Character Name & Class",
            getFunc = function() return self.savedVars.showName end,
            setFunc = function(value) 
                self.savedVars.showName = value 
                self:UpdateNameAndIcons() 
            end,
        },
        {
            type = "checkbox",
            name = "Show Level / CP",
            getFunc = function() return self.savedVars.showCP end,
            setFunc = function(value) 
                self.savedVars.showCP = value 
                self:UpdateNameAndIcons() 
            end,
        },
        {
            type = "header",
            name = "Health Bar",
        },
        {
            type = "colorpicker",
            name = "Primary Color (Health)",
            getFunc = function() return unpack(self.savedVars.healthColor) end,
            setFunc = function(r, g, b, a) self.savedVars.healthColor = {r, g, b, a}; self:ApplySettings() end,
        },
        {
            type = "checkbox",
            name = "Use Gradient (Health)",
            getFunc = function() return self.savedVars.useHealthGradient end,
            setFunc = function(value) self.savedVars.useHealthGradient = value; self:ApplySettings() end,
        },
        {
            type = "colorpicker",
            name = "Secondary Color (Health Gradient)",
            getFunc = function() return unpack(self.savedVars.healthGradientColor) end,
            setFunc = function(r, g, b, a) self.savedVars.healthGradientColor = {r, g, b, a}; self:ApplySettings() end,
            disabled = function() return not self.savedVars.useHealthGradient end,
        },
        {
            type = "header",
            name = "Shield Bar",
        },
        {
            type = "colorpicker",
            name = "Primary Color (Shield)",
            getFunc = function() return unpack(self.savedVars.shieldColor) end,
            setFunc = function(r, g, b, a) self.savedVars.shieldColor = {r, g, b, a}; self:ApplySettings() end,
        },
        {
            type = "checkbox",
            name = "Use Gradient (Shield)",
            getFunc = function() return self.savedVars.useShieldGradient end,
            setFunc = function(value) self.savedVars.useShieldGradient = value; self:ApplySettings() end,
        },
        {
            type = "colorpicker",
            name = "Secondary Color (Shield Gradient)",
            getFunc = function() return unpack(self.savedVars.shieldGradientColor) end,
            setFunc = function(r, g, b, a) self.savedVars.shieldGradientColor = {r, g, b, a}; self:ApplySettings() end,
            disabled = function() return not self.savedVars.useShieldGradient end,
        },
        {
            type = "header",
            name = "Magicka Bar",
        },
        {
            type = "colorpicker",
            name = "Primary Color (Magicka)",
            getFunc = function() return unpack(self.savedVars.magickaColor) end,
            setFunc = function(r, g, b, a) self.savedVars.magickaColor = {r, g, b, a}; self:ApplySettings() end,
        },
        {
            type = "checkbox",
            name = "Use Gradient (Magicka)",
            getFunc = function() return self.savedVars.useMagickaGradient end,
            setFunc = function(value) self.savedVars.useMagickaGradient = value; self:ApplySettings() end,
        },
        {
            type = "colorpicker",
            name = "Secondary Color (Magicka Gradient)",
            getFunc = function() return unpack(self.savedVars.magickaGradientColor) end,
            setFunc = function(r, g, b, a) self.savedVars.magickaGradientColor = {r, g, b, a}; self:ApplySettings() end,
            disabled = function() return not self.savedVars.useMagickaGradient end,
        },
        {
            type = "header",
            name = "Stamina Bar",
        },
        {
            type = "colorpicker",
            name = "Primary Color (Stamina)",
            getFunc = function() return unpack(self.savedVars.staminaColor) end,
            setFunc = function(r, g, b, a) self.savedVars.staminaColor = {r, g, b, a}; self:ApplySettings() end,
        },
        {
            type = "checkbox",
            name = "Use Gradient (Stamina)",
            getFunc = function() return self.savedVars.useStaminaGradient end,
            setFunc = function(value) self.savedVars.useStaminaGradient = value; self:ApplySettings() end,
        },
        {
            type = "colorpicker",
            name = "Secondary Color (Stamina Gradient)",
            getFunc = function() return unpack(self.savedVars.staminaGradientColor) end,
            setFunc = function(r, g, b, a) self.savedVars.staminaGradientColor = {r, g, b, a}; self:ApplySettings() end,
            disabled = function() return not self.savedVars.useStaminaGradient end,
        },
        {
            type = "header",
            name = "Sizes and Margins",
        },
        {
            type = "slider",
            name = "Font Size (Name/CP)",
            min = 10, max = 30, step = 1,
            getFunc = function() return self.savedVars.nameFontSize end,
            setFunc = function(value) 
                self.savedVars.nameFontSize = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Font Size (Bars)",
            min = 10, max = 30, step = 1,
            getFunc = function() return self.savedVars.barFontSize end,
            setFunc = function(value) 
                self.savedVars.barFontSize = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Total Frame Width",
            min = 150, max = 1000, step = 10, 
            getFunc = function() return self.savedVars.frameWidth end,
            setFunc = function(value) 
                self.savedVars.frameWidth = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Top Spacing (Margin)",
            min = 0, max = 30, step = 1,
            getFunc = function() return self.savedVars.borderTop end,
            setFunc = function(value) 
                self.savedVars.borderTop = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Bottom Spacing (Margin)",
            min = 0, max = 30, step = 1,
            getFunc = function() return self.savedVars.borderBottom end,
            setFunc = function(value) 
                self.savedVars.borderBottom = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Lateral Spacing (Margin)",
            min = 0, max = 15, step = 1,
            getFunc = function() return self.savedVars.borderLateral end,
            setFunc = function(value) 
                self.savedVars.borderLateral = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Health Bar Height",
            min = 10, max = 40, step = 1,
            getFunc = function() return self.savedVars.healthHeight end,
            setFunc = function(value) 
                self.savedVars.healthHeight = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Magicka Bar Height",
            min = 10, max = 40, step = 1,
            getFunc = function() return self.savedVars.magickaHeight end,
            setFunc = function(value) 
                self.savedVars.magickaHeight = value 
                self:ApplySettings() 
            end,
        },
        {
            type = "slider",
            name = "Stamina Bar Height",
            min = 10, max = 40, step = 1,
            getFunc = function() return self.savedVars.staminaHeight end,
            setFunc = function(value) 
                self.savedVars.staminaHeight = value 
                self:ApplySettings() 
            end,
        },
    }

    LibAddonMenu2:RegisterAddonPanel("SimplePlayerFramesOptions", panelData)
    LibAddonMenu2:RegisterOptionControls("SimplePlayerFramesOptions", optionsData)
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName == SimplePlayerFrames.name then
        EVENT_MANAGER:UnregisterForEvent(SimplePlayerFrames.name, EVENT_ADD_ON_LOADED)
        SimplePlayerFrames:Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(SimplePlayerFrames.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)