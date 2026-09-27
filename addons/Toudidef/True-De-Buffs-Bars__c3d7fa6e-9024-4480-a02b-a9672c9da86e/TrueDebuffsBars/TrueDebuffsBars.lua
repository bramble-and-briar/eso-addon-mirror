local TrueDebuffsBars = {
    name = "TrueDebuffsBars",
    version = "2.4",
    updateInterval = 100, -- Rafraîchissement toutes les 100ms
    previewMode = false,
    controls = {
        buffs = {},
        debuffs = {}
    }
}

-- Styles d'ombrage et de contour pour la lisibilité
local AVAILABLE_STYLES = {
    { name = "Outline",           value = FONT_STYLE_OUTLINE or 1 },
    { name = "Thick Soft Shadow", value = FONT_STYLE_SOFT_SHADOW_THICK or 4 },
    { name = "Thin Soft Shadow",  value = FONT_STYLE_SOFT_SHADOW_THIN or 3 },
    { name = "Drop Shadow",       value = FONT_STYLE_SHADOW or 2 },
    { name = "None",              value = FONT_STYLE_NONE or 0 },
}

-- Correspondance des valeurs de styles avec la syntaxe de chaîne de l'API ESO
local styleToStringMapping = {
    [FONT_STYLE_OUTLINE or 1]           = "outline",
    [FONT_STYLE_SOFT_SHADOW_THICK or 4] = "soft-shadow-thick",
    [FONT_STYLE_SOFT_SHADOW_THIN or 3]  = "soft-shadow-thin",
    [FONT_STYLE_SHADOW or 2]            = "shadow",
    [FONT_STYLE_NONE or 0]              = ""
}

-- Récupération des choix pour LibAddonMenu
local availableStyleChoices = {}
for _, entry in ipairs(AVAILABLE_STYLES) do
    table.insert(availableStyleChoices, entry.name)
end

-- Positions pour le TEMPS (Autorise l'intérieur ou l'extérieur de l'icône)
local timerPositionMapping = {
    ["Top Left"]      = { point = TOPLEFT, relPoint = TOPLEFT, x = 0, y = 0 },
    ["Top Right"]     = { point = TOPRIGHT, relPoint = TOPRIGHT, x = 0, y = 0 },
    ["Bottom Left"]   = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 0, y = 0 },
    ["Bottom Right"]  = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = 0, y = 0 },
    ["Center"]        = { point = CENTER, relPoint = CENTER, x = 0, y = 0 },
    ["Low Center"]    = { point = BOTTOM, relPoint = BOTTOM, x = 0, y = -3 }, -- Centré en bas à l'intérieur
    ["Below Center"]  = { point = TOP, relPoint = BOTTOM, x = 0, y = 2 },
    ["Above Center"]  = { point = BOTTOM, relPoint = TOP, x = 0, y = -2 },
    ["Left Center"]   = { point = RIGHT, relPoint = LEFT, x = -4, y = 0 },
    ["Right Center"]  = { point = LEFT, relPoint = RIGHT, x = 4, y = 0 }
}

-- Positions pour les STACKS (Restreintes à l'intérieur de l'icône)
local stackPositionMapping = {
    ["Top Left"]     = { point = TOPLEFT, relPoint = TOPLEFT, x = 2, y = 2 },
    ["Top Right"]    = { point = TOPRIGHT, relPoint = TOPRIGHT, x = -2, y = 2 },
    ["Bottom Left"]  = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 2, y = -2 },
    ["Bottom Right"] = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = -2, y = -2 },
    ["Center"]       = { point = CENTER, relPoint = CENTER, x = 0, y = 0 }
}

-- Mapping des polices d'écriture (Gamepad compatible)
local fontMapping = {
    ["Gamepad Medium"]   = "$(GAMEPAD_MEDIUM_FONT)",
    ["Gamepad Bold"]     = "$(GAMEPAD_BOLD_FONT)",
    ["Medium (Default)"] = "$(MEDIUM_FONT)",
    ["Bold"]             = "$(BOLD_FONT)",
    ["Antique"]          = "$(ANTIQUE_FONT)",
    ["Stone Tablet"]     = "$(STONE_TABLET_FONT)",
    ["Chat Font"]        = "$(CHAT_FONT)"
}

-- Valeurs par défaut sauvegardées
local defaults = {
    buffX = 300,
    buffY = 500,
    debuffX = 400,
    debuffY = 500,

    buffDir = "Horizontal (Centered)",
    debuffDir = "Horizontal (Centered)",

    buffEnableGrid = false,
    buffMaxPerRow = 8,
    buffRowDirection = "Below",

    debuffEnableGrid = false,
    debuffMaxPerRow = 8,
    debuffRowDirection = "Below",

    iconSize = 40,
    spacing = 5,
    fontStyle = "Gamepad Medium",
    fontOutlineStyle = "Outline",

    timerBuffPos = "Low Center",
    timerDebuffPos = "Low Center",
    timerSize = 18,
    timerColor = {r = 1, g = 1, b = 1, a = 1},

    stackBuffPos = "Top Right",
    stackDebuffPos = "Top Right",
    stackSize = 16,
    stackColor = {r = 1, g = 0.8, b = 0, a = 1},

    hidePermanent = false,
    hideLongBuffs = false,
    longBuffThreshold = 60
}

-- Échantillon d'icônes factices pour l'aperçu
local dummyBuffData = {
    { icon = "/esoui/art/icons/ability_warrior_010.dds", time = 25 },
    { icon = "/esoui/art/icons/ability_rogue_038.dds", time = 120 },
    { icon = "/esoui/art/icons/icon_experience_scroll.dds", time = 3600 },
    { icon = "/esoui/art/icons/ability_mage_065.dds", time = 8 },
    { icon = "/esoui/art/icons/ability_healer_018.dds", time = 45 },
    { icon = "/esoui/art/icons/ability_warden_001.dds", time = 90 },
    { icon = "/esoui/art/icons/ability_sorcerer_thunderous_strike.dds", time = 15 },
    { icon = "/esoui/art/icons/ability_restorationstaff_001.dds", time = 5 },
    { icon = "/esoui/art/icons/ability_templar_sun_shield.dds", time = 60 },
    { icon = "/esoui/art/icons/ability_dragonknight_004.dds", time = 180 }
}

local dummyDebuffData = {
    { icon = "/esoui/art/icons/ability_debuff_snare.dds", time = 6 },
    { icon = "/esoui/art/icons/ability_debuff_disease.dds", time = 20 },
    { icon = "/esoui/art/icons/ability_debuff_minor_vulnerability.dds", time = 12 },
    { icon = "/esoui/art/icons/ability_debuff_minor_breach.dds", time = 30 },
    { icon = "/esoui/art/icons/ability_debuff_major_breach.dds", time = 4 }
}

-- Formatage du temps en texte lisible
local function FormatTime(seconds)
    if seconds <= 0 then return "" end
    if seconds > 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds > 60 then
        return string.format("%dm", math.floor(seconds / 60))
    else
        return string.format("%ds", math.floor(seconds))
    end
end

-- Convertit le nom du style en mot-clé de style pour le moteur de police d'ESO
local function GetStyleDescriptor(selectedStyleName)
    for _, styleEntry in ipairs(AVAILABLE_STYLES) do
        if styleEntry.name == selectedStyleName then
            return styleToStringMapping[styleEntry.value] or "outline"
        end
    end
    return "outline"
end

-- Création ou réutilisation d'un contrôle d'icône
local function GetOrCreateIconControl(poolType, index)
    local pool = TrueDebuffsBars.controls[poolType]
    local parentFrame = (poolType == "buffs") and TrueDebuffsBars.buffFrame or TrueDebuffsBars.debuffFrame

    if not pool[index] then
        local ctrl = WINDOW_MANAGER:CreateControl(TrueDebuffsBars.name .. poolType .. index, parentFrame, CT_TEXTURE)

        local timerLabel = WINDOW_MANAGER:CreateControl(TrueDebuffsBars.name .. poolType .. "Timer" .. index, ctrl, CT_LABEL)
        timerLabel:SetDrawLayer(DL_OVERLAY)
        timerLabel:SetDrawTier(DT_HIGH)
        ctrl.timerLabel = timerLabel

        local stackLabel = WINDOW_MANAGER:CreateControl(TrueDebuffsBars.name .. poolType .. "Stack" .. index, ctrl, CT_LABEL)
        stackLabel:SetDrawLayer(DL_OVERLAY)
        stackLabel:SetDrawTier(DT_HIGH)
        ctrl.stackLabel = stackLabel

        pool[index] = ctrl
    end

    local ctrl = pool[index]
    local settings = TrueDebuffsBars.savedVars
    local selectedFont = fontMapping[settings.fontStyle] or "$(GAMEPAD_MEDIUM_FONT)"
    local styleDesc = GetStyleDescriptor(settings.fontOutlineStyle)

    ctrl:SetDimensions(settings.iconSize, settings.iconSize)

    -- Configuration de la police du temps
    local tFont
    if styleDesc and styleDesc ~= "" then
        tFont = string.format("%s|%d|%s", selectedFont, settings.timerSize, styleDesc)
    else
        tFont = string.format("%s|%d", selectedFont, settings.timerSize)
    end
    ctrl.timerLabel:SetFont(tFont)
    ctrl.timerLabel:SetColor(settings.timerColor.r, settings.timerColor.g, settings.timerColor.b, settings.timerColor.a)
    ctrl.timerLabel:ClearAnchors()

    local tPosSetting = (poolType == "buffs") and settings.timerBuffPos or settings.timerDebuffPos
    local tPos = timerPositionMapping[tPosSetting]
    if tPos then
        ctrl.timerLabel:SetAnchor(tPos.point, ctrl, tPos.relPoint, tPos.x, tPos.y)
    end

    -- Configuration de la police des stacks
    local sFont
    if styleDesc and styleDesc ~= "" then
        sFont = string.format("%s|%d|%s", selectedFont, settings.stackSize, styleDesc)
    else
        sFont = string.format("%s|%d", selectedFont, settings.stackSize)
    end
    ctrl.stackLabel:SetFont(sFont)
    ctrl.stackLabel:SetColor(settings.stackColor.r, settings.stackColor.g, settings.stackColor.b, settings.stackColor.a)
    ctrl.stackLabel:ClearAnchors()

    local sPosSetting = (poolType == "buffs") and settings.stackBuffPos or settings.stackDebuffPos
    local sPos = stackPositionMapping[sPosSetting]
    if sPos then
        ctrl.stackLabel:SetAnchor(sPos.point, ctrl, sPos.relPoint, sPos.x, sPos.y)
    end

    ctrl:SetHidden(false)
    return ctrl
end

-- Calcul des ancrages
local function ApplyAnchors(poolType, count, spacing, iconSize, direction, enableGrid, maxPerRow, vDir)
    if count == 0 then return end

    local pool = TrueDebuffsBars.controls[poolType]
    local parent = (poolType == "buffs") and TrueDebuffsBars.buffFrame or TrueDebuffsBars.debuffFrame

    if direction == "Horizontal" then direction = "Horizontal (Left to Right)" end

    local limit = enableGrid and math.max(1, maxPerRow or 1) or count

    for i = 1, count do
        local ctrl = pool[i]
        ctrl:ClearAnchors()

        if direction == "Horizontal (Left to Right)" then
            local col = (i - 1) % limit
            local row = math.floor((i - 1) / limit)
            local xOffset = col * (iconSize + spacing)
            local yOffset = (vDir == "Above") and -(row * (iconSize + spacing)) or (row * (iconSize + spacing))
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Horizontal (Right to Left)" then
            local col = (i - 1) % limit
            local row = math.floor((i - 1) / limit)
            local xOffset = -(col * (iconSize + spacing))
            local yOffset = (vDir == "Above") and -(row * (iconSize + spacing)) or (row * (iconSize + spacing))
            ctrl:SetAnchor(TOPRIGHT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Horizontal (Centered)" then
            local row = math.floor((i - 1) / limit)
            local rowStart = row * limit + 1
            local rowEnd = math.min(count, (row + 1) * limit)
            local countInRow = rowEnd - rowStart + 1
            local rowSpan = (countInRow * iconSize) + ((countInRow - 1) * spacing)

            local col = (i - 1) % limit
            local xOffset = -(rowSpan / 2) + col * (iconSize + spacing)
            local yOffset = (vDir == "Above") and -(row * (iconSize + spacing)) or (row * (iconSize + spacing))
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Vertical (Top to Bottom)" then
            local row = (i - 1) % limit
            local col = math.floor((i - 1) / limit)
            local yOffset = row * (iconSize + spacing)
            local xOffset = col * (iconSize + spacing)
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Vertical (Bottom to Top)" then
            local row = (i - 1) % limit
            local col = math.floor((i - 1) / limit)
            local yOffset = -(row * (iconSize + spacing))
            local xOffset = col * (iconSize + spacing)
            ctrl:SetAnchor(BOTTOMLEFT, parent, TOPLEFT, xOffset, yOffset)

        elseif direction == "Vertical (Centered)" then
            local col = math.floor((i - 1) / limit)
            local colStart = col * limit + 1
            local colEnd = math.min(count, (col + 1) * limit)
            local countInCol = colEnd - colStart + 1
            local colSpan = (countInCol * iconSize) + ((countInCol - 1) * spacing)

            local row = (i - 1) % limit
            local yOffset = -(colSpan / 2) + row * (iconSize + spacing)
            local xOffset = col * (iconSize + spacing)
            ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, xOffset, yOffset)
        end
    end
end

-- Tri décroissant par durée restante
local function CompareEffectsDescending(a, b)
    local timeA = a.isPermanent and -1 or a.timeLeft
    local timeB = b.isPermanent and -1 or b.timeLeft

    if timeA ~= timeB then
        return timeA > timeB
    end
    return a.name < b.name
end

-- Boucle principale
function TrueDebuffsBars.UpdateBuffs()
    local shouldHide = false
    if IsReticleHidden() and not TrueDebuffsBars.previewMode then
        shouldHide = true
    end

    TrueDebuffsBars.buffFrame:SetHidden(shouldHide)
    TrueDebuffsBars.debuffFrame:SetHidden(shouldHide)

    if shouldHide then return end

    local currentTime = GetFrameTimeSeconds()
    local settings = TrueDebuffsBars.savedVars
    local buffsList = {}
    local debuffsList = {}

    if TrueDebuffsBars.previewMode then
        for i, item in ipairs(dummyBuffData) do
            table.insert(buffsList, {
                icon = item.icon,
                timeLeft = item.time,
                isPermanent = false,
                stackCount = (i % 2 == 0) and 3 or 0,
                name = "PreviewBuff" .. i
            })
        end
        for i, item in ipairs(dummyDebuffData) do
            table.insert(debuffsList, {
                icon = item.icon,
                timeLeft = item.time,
                isPermanent = false,
                stackCount = 0,
                name = "PreviewDebuff" .. i
            })
        end
    else
        for i = 1, GetNumBuffs("player") do
            local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType = GetUnitBuffInfo("player", i)

            if buffName and buffName ~= "" then
                local isPermanent = (timeStarted == timeEnding) or (timeEnding == 0)
                local timeLeft = isPermanent and 0 or (timeEnding - currentTime)

                local skipEffect = false
                if settings.hidePermanent and isPermanent then skipEffect = true end
                if settings.hideLongBuffs and not isPermanent and (timeLeft > (settings.longBuffThreshold * 60)) then skipEffect = true end

                if not skipEffect then
                    local effectEntry = {
                        name = buffName,
                        icon = iconFilename,
                        stackCount = stackCount,
                        isPermanent = isPermanent,
                        timeLeft = timeLeft
                    }

                    if effectType == BUFF_EFFECT_TYPE_DEBUFF then
                        table.insert(debuffsList, effectEntry)
                    else
                        table.insert(buffsList, effectEntry)
                    end
                end
            end
        end
    end

    table.sort(buffsList, CompareEffectsDescending)
    table.sort(debuffsList, CompareEffectsDescending)

    local buffCount = #buffsList
    for i, data in ipairs(buffsList) do
        local ctrl = GetOrCreateIconControl("buffs", i)
        ctrl:SetTexture(data.icon)

        local timeText = ""
        if not data.isPermanent then
            timeText = FormatTime(data.timeLeft)
        end
        ctrl.timerLabel:SetText(timeText)

        if data.stackCount > 1 then
            ctrl.stackLabel:SetText(tostring(data.stackCount))
        else
            ctrl.stackLabel:SetText("")
        end
    end

    local debuffCount = #debuffsList
    for i, data in ipairs(debuffsList) do
        local ctrl = GetOrCreateIconControl("debuffs", i)
        ctrl:SetTexture(data.icon)

        local timeText = ""
        if not data.isPermanent then
            timeText = FormatTime(data.timeLeft)
        end
        ctrl.timerLabel:SetText(timeText)

        if data.stackCount > 1 then
            ctrl.stackLabel:SetText(tostring(data.stackCount))
        else
            ctrl.stackLabel:SetText("")
        end
    end

    ApplyAnchors("buffs", buffCount, settings.spacing, settings.iconSize, settings.buffDir, settings.buffEnableGrid, settings.buffMaxPerRow, settings.buffRowDirection)
    ApplyAnchors("debuffs", debuffCount, settings.spacing, settings.iconSize, settings.debuffDir, settings.debuffEnableGrid, settings.debuffMaxPerRow, settings.debuffRowDirection)

    for i = buffCount + 1, #TrueDebuffsBars.controls.buffs do
        TrueDebuffsBars.controls.buffs[i]:SetHidden(true)
    end
    for i = debuffCount + 1, #TrueDebuffsBars.controls.debuffs do
        TrueDebuffsBars.controls.debuffs[i]:SetHidden(true)
    end
end

-- Mise à jour des positions
local function UpdateFramePositions()
    TrueDebuffsBars.buffFrame:ClearAnchors()
    TrueDebuffsBars.buffFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TrueDebuffsBars.savedVars.buffX, TrueDebuffsBars.savedVars.buffY)

    TrueDebuffsBars.debuffFrame:ClearAnchors()
    TrueDebuffsBars.debuffFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TrueDebuffsBars.savedVars.debuffX, TrueDebuffsBars.savedVars.debuffY)
end

-- Menu LAM-2.0
local function BuildMenu()
    if not LibAddonMenu2 then return end

    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = "True (De)Buffs Bars",
        displayName = "|cff5900True (De)Buffs Bars|r",
        author = "|cff5900Toudidef|r",
        version = TrueDebuffsBars.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    LAM:RegisterAddonPanel("TrueDebuffsBarsPanel", panelData)

    local optionsChoices = {
        "Horizontal (Left to Right)",
        "Horizontal (Right to Left)",
        "Horizontal (Centered)",
        "Vertical (Top to Bottom)",
        "Vertical (Bottom to Top)",
        "Vertical (Centered)"
    }

    local timerPositionChoices = {
        "Top Left",
        "Top Right",
        "Bottom Left",
        "Bottom Right",
        "Center",
        "Low Center",
        "Below Center",
        "Above Center",
        "Left Center",
        "Right Center"
    }

    local optionsData = {
        {
            type = "checkbox",
            name = "|c00FF00Preview Mode (Show fake buffs)|r",
            tooltip = "Turn this ON to test appearance, sorting, and styling with dummy icons. Turn it OFF when finished.",
            getFunc = function() return TrueDebuffsBars.previewMode end,
            setFunc = function(value) TrueDebuffsBars.previewMode = value end,
            warning = "Don't forget to turn this OFF when you finish your setup!",
        },
        -- Sous-menu : Filtres
        {
            type = "submenu",
            name = "Filters",
            tooltip = "Filter out permanent effects or long duration buffs.",
            controls = {
                {
                    type = "checkbox",
                    name = "Hide Permanent Effects",
                    tooltip = "Hides passives, mundus stones, and infinite buffs.",
                    getFunc = function() return TrueDebuffsBars.savedVars.hidePermanent end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.hidePermanent = value end,
                },
                {
                    type = "checkbox",
                    name = "Hide Long Duration Effects",
                    tooltip = "Hides buffs that have a long timer (e.g. food).",
                    getFunc = function() return TrueDebuffsBars.savedVars.hideLongBuffs end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.hideLongBuffs = value end,
                },
                {
                    type = "slider",
                    name = "Long Duration Threshold (Minutes)",
                    tooltip = "Any effect longer than this will be hidden.",
                    min = 1, max = 120, step = 1,
                    disabled = function() return not TrueDebuffsBars.savedVars.hideLongBuffs end,
                    getFunc = function() return TrueDebuffsBars.savedVars.longBuffThreshold end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.longBuffThreshold = value end,
                },
            }
        },
        -- Sous-menu : Buffs Configuration
        {
            type = "submenu",
            name = "Buffs Bar Configuration",
            tooltip = "Positions, orientation, and multiple row/column settings for buffs.",
            controls = {
                {
                    type = "slider",
                    name = "Buffs Position (X)",
                    min = 0, max = 3500, step = 10,
                    getFunc = function() return TrueDebuffsBars.savedVars.buffX end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.buffX = value; UpdateFramePositions() end,
                },
                {
                    type = "slider",
                    name = "Buffs Position (Y)",
                    min = 0, max = 2000, step = 10,
                    getFunc = function() return TrueDebuffsBars.savedVars.buffY end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.buffY = value; UpdateFramePositions() end,
                },
                {
                    type = "dropdown",
                    name = "Buffs Orientation",
                    choices = optionsChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.buffDir end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.buffDir = value end,
                },
                {
                    type = "checkbox",
                    name = "Enable Multiple Rows / Columns",
                    tooltip = "Enable this to allow buffs to wrap onto new rows/columns once the limit per line is reached.",
                    getFunc = function() return TrueDebuffsBars.savedVars.buffEnableGrid end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.buffEnableGrid = value end,
                },
                {
                    type = "slider",
                    name = "Max Buffs Per Line",
                    tooltip = "Maximum number of buffs displayed per line before creating a new row/column.",
                    min = 1, max = 30, step = 1,
                    disabled = function() return not TrueDebuffsBars.savedVars.buffEnableGrid end,
                    getFunc = function() return TrueDebuffsBars.savedVars.buffMaxPerRow end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.buffMaxPerRow = value end,
                },
                {
                    type = "dropdown",
                    name = "New Row Direction",
                    tooltip = "Controls if new rows appear above or below the initial line.",
                    choices = {"Below", "Above"},
                    disabled = function() return not TrueDebuffsBars.savedVars.buffEnableGrid end,
                    getFunc = function() return TrueDebuffsBars.savedVars.buffRowDirection end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.buffRowDirection = value end,
                },
            }
        },
        -- Sous-menu : Débuffs Configuration
        {
            type = "submenu",
            name = "Debuffs Bar Configuration",
            tooltip = "Positions, orientation, and multiple row/column settings for debuffs.",
            controls = {
                {
                    type = "slider",
                    name = "Debuffs Position (X)",
                    min = 0, max = 3500, step = 10,
                    getFunc = function() return TrueDebuffsBars.savedVars.debuffX end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.debuffX = value; UpdateFramePositions() end,
                },
                {
                    type = "slider",
                    name = "Debuffs Position (Y)",
                    min = 0, max = 2000, step = 10,
                    getFunc = function() return TrueDebuffsBars.savedVars.debuffY end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.debuffY = value; UpdateFramePositions() end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Orientation",
                    choices = optionsChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.debuffDir end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.debuffDir = value end,
                },
                {
                    type = "checkbox",
                    name = "Enable Multiple Rows / Columns",
                    tooltip = "Enable this to allow debuffs to wrap onto new rows/columns once the limit per line is reached.",
                    getFunc = function() return TrueDebuffsBars.savedVars.debuffEnableGrid end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.debuffEnableGrid = value end,
                },
                {
                    type = "slider",
                    name = "Max Debuffs Per Line",
                    tooltip = "Maximum number of debuffs displayed per line before creating a new row/column.",
                    min = 1, max = 30, step = 1,
                    disabled = function() return not TrueDebuffsBars.savedVars.debuffEnableGrid end,
                    getFunc = function() return TrueDebuffsBars.savedVars.debuffMaxPerRow end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.debuffMaxPerRow = value end,
                },
                {
                    type = "dropdown",
                    name = "New Row Direction",
                    tooltip = "Controls if new rows appear above or below the initial line.",
                    choices = {"Below", "Above"},
                    disabled = function() return not TrueDebuffsBars.savedVars.debuffEnableGrid end,
                    getFunc = function() return TrueDebuffsBars.savedVars.debuffRowDirection end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.debuffRowDirection = value end,
                },
            }
        },
        -- Sous-menu : Apparence & Lisibilité
        {
            type = "submenu",
            name = "Appearance & Sizing",
            tooltip = "Adjust sizes, spacing, and typography readability.",
            controls = {
                {
                    type = "slider",
                    name = "Icons Size",
                    min = 20, max = 100, step = 2,
                    getFunc = function() return TrueDebuffsBars.savedVars.iconSize end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.iconSize = value end,
                },
                {
                    type = "slider",
                    name = "Spacing",
                    min = 0, max = 50, step = 1,
                    getFunc = function() return TrueDebuffsBars.savedVars.spacing end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.spacing = value end,
                },
                {
                    type = "dropdown",
                    name = "Font Family",
                    choices = {"Gamepad Medium", "Gamepad Bold", "Medium (Default)", "Bold", "Antique", "Stone Tablet", "Chat Font"},
                    getFunc = function() return TrueDebuffsBars.savedVars.fontStyle end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.fontStyle = value end,
                },
                {
                    type = "dropdown",
                    name = "Font Outline / Shadow Style",
                    tooltip = "Choose an outline or shadow style to maximize text readability over any background.",
                    choices = availableStyleChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.fontOutlineStyle end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.fontOutlineStyle = value end,
                },
            }
        },
        -- Sous-menu : Minuteurs (Timers)
        {
            type = "submenu",
            name = "Timers Display (Duration)",
            tooltip = "Position, size, and color of duration labels.",
            controls = {
                {
                    type = "dropdown",
                    name = "Buffs Timer Position",
                    choices = timerPositionChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.timerBuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.timerBuffPos = value end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Timer Position",
                    choices = timerPositionChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.timerDebuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.timerDebuffPos = value end,
                },
                {
                    type = "slider",
                    name = "Timer Text Size",
                    min = 10, max = 40, step = 1,
                    getFunc = function() return TrueDebuffsBars.savedVars.timerSize end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.timerSize = value end,
                },
                {
                    type = "colorpicker",
                    name = "Timer Color",
                    getFunc = function()
                        local c = TrueDebuffsBars.savedVars.timerColor
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        TrueDebuffsBars.savedVars.timerColor = {r = r, g = g, b = b, a = a}
                    end,
                },
            }
        },
        -- Sous-menu : Compteurs de charges (Stacks)
        {
            type = "submenu",
            name = "Stacks Display (Charges)",
            tooltip = "Position, size, and color of stack counters.",
            controls = {
                {
                    type = "dropdown",
                    name = "Buffs Stack Position",
                    choices = {"Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center"},
                    getFunc = function() return TrueDebuffsBars.savedVars.stackBuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.stackBuffPos = value end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Stack Position",
                    choices = {"Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center"},
                    getFunc = function() return TrueDebuffsBars.savedVars.stackDebuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.stackDebuffPos = value end,
                },
                {
                    type = "slider",
                    name = "Stack Text Size",
                    min = 10, max = 40, step = 1,
                    getFunc = function() return TrueDebuffsBars.savedVars.stackSize end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.stackSize = value end,
                },
                {
                    type = "colorpicker",
                    name = "Stack Color",
                    getFunc = function()
                        local c = TrueDebuffsBars.savedVars.stackColor
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        TrueDebuffsBars.savedVars.stackColor = {r = r, g = g, b = b, a = a}
                    end,
                },
            }
        }
    }
    LAM:RegisterOptionControls("TrueDebuffsBarsPanel", optionsData)
end

-- Initialisation de l'Addon
local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= TrueDebuffsBars.name then return end
    EVENT_MANAGER:UnregisterForEvent(TrueDebuffsBars.name, EVENT_ADD_ON_LOADED)

    TrueDebuffsBars.savedVars = ZO_SavedVars:NewAccountWide("TrueDebuffsBarsSavedVars", 1, nil, defaults)

    TrueDebuffsBars.buffFrame = WINDOW_MANAGER:CreateTopLevelWindow(TrueDebuffsBars.name .. "BuffFrame")
    TrueDebuffsBars.debuffFrame = WINDOW_MANAGER:CreateTopLevelWindow(TrueDebuffsBars.name .. "DebuffFrame")

    TrueDebuffsBars.buffFrame:SetDrawTier(DT_HIGH)
    TrueDebuffsBars.debuffFrame:SetDrawTier(DT_HIGH)

    UpdateFramePositions()
    BuildMenu()
    EVENT_MANAGER:RegisterForUpdate(TrueDebuffsBars.name .. "UpdateLoop", TrueDebuffsBars.updateInterval, TrueDebuffsBars.UpdateBuffs)
end

EVENT_MANAGER:RegisterForEvent(TrueDebuffsBars.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)