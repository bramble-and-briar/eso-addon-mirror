-- ============================================================================
-- TrueDebuffsBars (Optimisé mémoire Lua / Console)
-- ============================================================================

local TrueDebuffsBars = {
    name = "TrueDebuffsBars",
    version = "2.4",
    updateInterval = 100, -- Rafraîchissement toutes les 100ms
    previewMode = false,
    styleVersion = 1,
    controls = {
        buffs = {},
        debuffs = {}
    }
}

-- Raccourcis locaux pour limiter les recherches globales dans la boucle
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local string_format = string.format
local table_sort = table.sort

-- État interne et caches pré-alloués (zéro allocation en régime permanent)
local effectsDirty = true
local wasPreviewMode = false
local rescanTickCounter = 0
local activeBuffCount = 0
local activeDebuffCount = 0

local reusableBuffs = {}
local reusableDebuffs = {}
local auraEntryPool = {}
local timeStrCache = { [0] = "" }
local stackStrCache = {}

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

-- Lookup direct par nom de style (évite ipairs à chaque tick)
local styleNameToDescriptor = {}
local availableStyleChoices = {}
for _, entry in ipairs(AVAILABLE_STYLES) do
    table.insert(availableStyleChoices, entry.name)
    styleNameToDescriptor[entry.name] = styleToStringMapping[entry.value] or "outline"
end

-- Positions pour le TEMPS (Autorise l'intérieur ou l'extérieur de l'icône)
local timerPositionMapping = {
    ["Top Left"]      = { point = TOPLEFT, relPoint = TOPLEFT, x = 0, y = 0 },
    ["Top Right"]     = { point = TOPRIGHT, relPoint = TOPRIGHT, x = 0, y = 0 },
    ["Bottom Left"]   = { point = BOTTOMLEFT, relPoint = BOTTOMLEFT, x = 0, y = 0 },
    ["Bottom Right"]  = { point = BOTTOMRIGHT, relPoint = BOTTOMRIGHT, x = 0, y = 0 },
    ["Center"]        = { point = CENTER, relPoint = CENTER, x = 0, y = 0 },
    ["Low Center"]    = { point = BOTTOM, relPoint = BOTTOM, x = 0, y = -3 },
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
    timerColor = { r = 1, g = 1, b = 1, a = 1 },

    stackBuffPos = "Top Right",
    stackDebuffPos = "Top Right",
    stackSize = 16,
    stackColor = { r = 1, g = 0.8, b = 0, a = 1 },

    hidePermanent = false,
    hideLongBuffs = false,
    longBuffThreshold = 60
}

-- Échantillon d'icônes factices pour l'aperçu (noms pré-alloués)
local dummyBuffData = {
    { icon = "/esoui/art/icons/ability_warrior_010.dds", time = 25, name = "PreviewBuff1" },
    { icon = "/esoui/art/icons/ability_rogue_038.dds", time = 120, name = "PreviewBuff2" },
    { icon = "/esoui/art/icons/icon_experience_scroll.dds", time = 3600, name = "PreviewBuff3" },
    { icon = "/esoui/art/icons/ability_mage_065.dds", time = 8, name = "PreviewBuff4" },
    { icon = "/esoui/art/icons/ability_healer_018.dds", time = 45, name = "PreviewBuff5" },
    { icon = "/esoui/art/icons/ability_warden_001.dds", time = 90, name = "PreviewBuff6" },
    { icon = "/esoui/art/icons/ability_sorcerer_thunderous_strike.dds", time = 15, name = "PreviewBuff7" },
    { icon = "/esoui/art/icons/ability_restorationstaff_001.dds", time = 5, name = "PreviewBuff8" },
    { icon = "/esoui/art/icons/ability_templar_sun_shield.dds", time = 60, name = "PreviewBuff9" },
    { icon = "/esoui/art/icons/ability_dragonknight_004.dds", time = 180, name = "PreviewBuff10" }
}

local dummyDebuffData = {
    { icon = "/esoui/art/icons/ability_debuff_snare.dds", time = 6, name = "PreviewDebuff1" },
    { icon = "/esoui/art/icons/ability_debuff_disease.dds", time = 20, name = "PreviewDebuff2" },
    { icon = "/esoui/art/icons/ability_debuff_minor_vulnerability.dds", time = 12, name = "PreviewDebuff3" },
    { icon = "/esoui/art/icons/ability_debuff_minor_breach.dds", time = 30, name = "PreviewDebuff4" },
    { icon = "/esoui/art/icons/ability_debuff_major_breach.dds", time = 4, name = "PreviewDebuff5" }
}

-- ============================================================================
-- Fonctions utilitaires avec mise en cache
-- ============================================================================

local function SetHiddenIfChanged(ctrl, hidden)
    if ctrl and ctrl:IsControlHidden() ~= hidden then
        ctrl:SetHidden(hidden)
    end
end

local function InvalidateStyle()
    TrueDebuffsBars.styleVersion = TrueDebuffsBars.styleVersion + 1
end

local function MarkEffectsDirty()
    effectsDirty = true
end

-- Formatage du temps avec cache borné (zéro string temporaire en combat)
local function GetFormattedTimeAndKey(seconds)
    if seconds <= 0 then
        return -1, ""
    end

    local key
    if seconds > 3600 then
        local h = math_floor(seconds / 3600)
        key = 200000 + h
        if key > 200100 then
            return key, string_format("%dh", h)
        end
        if not timeStrCache[key] then
            timeStrCache[key] = string_format("%dh", h)
        end
    elseif seconds > 60 then
        local m = math_floor(seconds / 60)
        key = 100000 + m
        if not timeStrCache[key] then
            timeStrCache[key] = string_format("%dm", m)
        end
    else
        key = math_floor(seconds)
        if not timeStrCache[key] then
            timeStrCache[key] = string_format("%ds", key)
        end
    end

    return key, timeStrCache[key]
end

local function GetFormattedStack(stackVal)
    if stackVal <= 1 then
        return ""
    end
    if stackVal <= 100 then
        local str = stackStrCache[stackVal]
        if not str then
            str = tostring(stackVal)
            stackStrCache[stackVal] = str
        end
        return str
    end
    return tostring(stackVal)
end

-- Détecte si l'interface doit être complètement masquée (menus, scoreboard, réticule)
local function ShouldHideAllUI()
    if TrueDebuffsBars.previewMode then
        return false
    end

    if IsReticleHidden() then
        return true
    end

    if SCENE_MANAGER then
        if SCENE_MANAGER:IsShowing("battleground_scoreboard") or SCENE_MANAGER:IsShowing("gamepad_battleground_scoreboard") then
            return true
        end

        local isHudShowing = SCENE_MANAGER:IsShowing("gamepad_hud_scene")
                        or SCENE_MANAGER:IsShowing("gamepad_hud")
                        or SCENE_MANAGER:IsShowing("hud")

        if not isHudShowing then
            return true
        end
    end

    return false
end

-- Création ou réutilisation d'un contrôle d'icône (style appliqué uniquement si modifié)
local function GetOrCreateIconControl(poolType, index)
    local pool = TrueDebuffsBars.controls[poolType]
    local ctrl = pool[index]

    if not ctrl then
        local parentFrame = (poolType == "buffs") and TrueDebuffsBars.buffFrame or TrueDebuffsBars.debuffFrame
        ctrl = WINDOW_MANAGER:CreateControl(TrueDebuffsBars.name .. poolType .. index, parentFrame, CT_TEXTURE)

        local timerLabel = WINDOW_MANAGER:CreateControl(TrueDebuffsBars.name .. poolType .. "Timer" .. index, ctrl, CT_LABEL)
        timerLabel:SetDrawLayer(DL_OVERLAY)
        timerLabel:SetDrawTier(DT_HIGH)
        ctrl.timerLabel = timerLabel

        local stackLabel = WINDOW_MANAGER:CreateControl(TrueDebuffsBars.name .. poolType .. "Stack" .. index, ctrl, CT_LABEL)
        stackLabel:SetDrawLayer(DL_OVERLAY)
        stackLabel:SetDrawTier(DT_HIGH)
        ctrl.stackLabel = stackLabel

        ctrl.appliedStyleVersion = 0
        pool[index] = ctrl
    end

    if ctrl.appliedStyleVersion ~= TrueDebuffsBars.styleVersion then
        local settings = TrueDebuffsBars.savedVars
        local selectedFont = fontMapping[settings.fontStyle] or "$(GAMEPAD_MEDIUM_FONT)"
        local styleDesc = styleNameToDescriptor[settings.fontOutlineStyle] or "outline"

        ctrl:SetDimensions(settings.iconSize, settings.iconSize)

        -- Configuration de la police du temps
        local tFont = (styleDesc ~= "") and string_format("%s|%d|%s", selectedFont, settings.timerSize, styleDesc)
                                         or string_format("%s|%d", selectedFont, settings.timerSize)
        ctrl.timerLabel:SetFont(tFont)
        ctrl.timerLabel:SetColor(settings.timerColor.r, settings.timerColor.g, settings.timerColor.b, settings.timerColor.a)
        ctrl.timerLabel:ClearAnchors()

        local tPosSetting = (poolType == "buffs") and settings.timerBuffPos or settings.timerDebuffPos
        local tPos = timerPositionMapping[tPosSetting]
        if tPos then
            ctrl.timerLabel:SetAnchor(tPos.point, ctrl, tPos.relPoint, tPos.x, tPos.y)
        end

        -- Configuration de la police des charges
        local sFont = (styleDesc ~= "") and string_format("%s|%d|%s", selectedFont, settings.stackSize, styleDesc)
                                         or string_format("%s|%d", selectedFont, settings.stackSize)
        ctrl.stackLabel:SetFont(sFont)
        ctrl.stackLabel:SetColor(settings.stackColor.r, settings.stackColor.g, settings.stackColor.b, settings.stackColor.a)
        ctrl.stackLabel:ClearAnchors()

        local sPosSetting = (poolType == "buffs") and settings.stackBuffPos or settings.stackDebuffPos
        local sPos = stackPositionMapping[sPosSetting]
        if sPos then
            ctrl.stackLabel:SetAnchor(sPos.point, ctrl, sPos.relPoint, sPos.x, sPos.y)
        end

        ctrl.appliedStyleVersion = TrueDebuffsBars.styleVersion
    end

    SetHiddenIfChanged(ctrl, false)
    return ctrl
end

-- Calcul des ancrages avec diffing (ne ré-ancre que si une coordonnée ou ancre change)
local function ApplyAnchors(poolType, count, spacing, iconSize, direction, enableGrid, maxPerRow, vDir)
    if count == 0 then return end

    local pool = TrueDebuffsBars.controls[poolType]
    local parent = (poolType == "buffs") and TrueDebuffsBars.buffFrame or TrueDebuffsBars.debuffFrame

    if direction == "Horizontal" then direction = "Horizontal (Left to Right)" end

    local limit = enableGrid and math_max(1, maxPerRow or 1) or count
    local step = iconSize + spacing

    for i = 1, count do
        local ctrl = pool[i]
        local point, relPoint, xOffset, yOffset

        if direction == "Horizontal (Left to Right)" then
            local col = (i - 1) % limit
            local row = math_floor((i - 1) / limit)
            xOffset = col * step
            yOffset = (vDir == "Above") and -(row * step) or (row * step)
            point, relPoint = TOPLEFT, TOPLEFT

        elseif direction == "Horizontal (Right to Left)" then
            local col = (i - 1) % limit
            local row = math_floor((i - 1) / limit)
            xOffset = -(col * step)
            yOffset = (vDir == "Above") and -(row * step) or (row * step)
            point, relPoint = TOPRIGHT, TOPLEFT

        elseif direction == "Horizontal (Centered)" then
            local row = math_floor((i - 1) / limit)
            local rowStart = row * limit + 1
            local rowEnd = math_min(count, (row + 1) * limit)
            local countInRow = rowEnd - rowStart + 1
            local rowSpan = (countInRow * iconSize) + ((countInRow - 1) * spacing)

            local col = (i - 1) % limit
            xOffset = -(rowSpan * 0.5) + (col * step)
            yOffset = (vDir == "Above") and -(row * step) or (row * step)
            point, relPoint = TOPLEFT, TOPLEFT

        elseif direction == "Vertical (Top to Bottom)" then
            local row = (i - 1) % limit
            local col = math_floor((i - 1) / limit)
            yOffset = row * step
            xOffset = col * step
            point, relPoint = TOPLEFT, TOPLEFT

        elseif direction == "Vertical (Bottom to Top)" then
            local row = (i - 1) % limit
            local col = math_floor((i - 1) / limit)
            yOffset = -(row * step)
            xOffset = col * step
            point, relPoint = BOTTOMLEFT, TOPLEFT

        elseif direction == "Vertical (Centered)" then
            local col = math_floor((i - 1) / limit)
            local colStart = col * limit + 1
            local colEnd = math_min(count, (col + 1) * limit)
            local countInCol = colEnd - colStart + 1
            local colSpan = (countInCol * iconSize) + ((countInCol - 1) * spacing)

            local row = (i - 1) % limit
            yOffset = -(colSpan * 0.5) + (row * step)
            xOffset = col * step
            point, relPoint = TOPLEFT, TOPLEFT
        end

        if ctrl.lastAnchorPoint ~= point
            or ctrl.lastAnchorRelPoint ~= relPoint
            or ctrl.lastAnchorX ~= xOffset
            or ctrl.lastAnchorY ~= yOffset
        then
            ctrl:ClearAnchors()
            ctrl:SetAnchor(point, parent, relPoint, xOffset, yOffset)
            ctrl.lastAnchorPoint = point
            ctrl.lastAnchorRelPoint = relPoint
            ctrl.lastAnchorX = xOffset
            ctrl.lastAnchorY = yOffset
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

-- Rendu factorisé d'un pool (Buffs ou Debuffs) avec diffing
local function RenderIconPool(poolType, list, count)
    for i = 1, count do
        local data = list[i]
        local ctrl = GetOrCreateIconControl(poolType, i)

        if ctrl.lastIcon ~= data.icon then
            ctrl:SetTexture(data.icon)
            ctrl.lastIcon = data.icon
        end

        if data.isPermanent then
            if ctrl.lastTimerKey ~= -2 then
                ctrl.lastTimerKey = -2
                ctrl.timerLabel:SetText("")
            end
        else
            local timeKey, timeText = GetFormattedTimeAndKey(data.timeLeft)
            if ctrl.lastTimerKey ~= timeKey then
                ctrl.lastTimerKey = timeKey
                ctrl.timerLabel:SetText(timeText)
            end
        end

        local stackVal = (data.stackCount > 1) and data.stackCount or 0
        if ctrl.lastStackVal ~= stackVal then
            ctrl.lastStackVal = stackVal
            ctrl.stackLabel:SetText(GetFormattedStack(stackVal))
        end
    end

    local pool = TrueDebuffsBars.controls[poolType]
    for i = count + 1, #pool do
        SetHiddenIfChanged(pool[i], true)
    end
end

-- Boucle principale (zéro allocation)
function TrueDebuffsBars.UpdateBuffs()
    local shouldHide = ShouldHideAllUI()

    SetHiddenIfChanged(TrueDebuffsBars.buffFrame, shouldHide)
    SetHiddenIfChanged(TrueDebuffsBars.debuffFrame, shouldHide)

    if shouldHide then return end

    local currentTime = GetFrameTimeSeconds()
    local settings = TrueDebuffsBars.savedVars
    local isPreview = TrueDebuffsBars.previewMode

    if isPreview ~= wasPreviewMode then
        wasPreviewMode = isPreview
        effectsDirty = true
    end

    if isPreview then
        if effectsDirty then
            effectsDirty = false
            local poolIdx = 0
            activeBuffCount = 0
            activeDebuffCount = 0

            for i, item in ipairs(dummyBuffData) do
                poolIdx = poolIdx + 1
                local entry = auraEntryPool[poolIdx]
                if not entry then entry = {}; auraEntryPool[poolIdx] = entry end
                entry.icon = item.icon
                entry.timeLeft = item.time
                entry.timeEnding = 0
                entry.isPermanent = false
                entry.stackCount = (i % 2 == 0) and 3 or 0
                entry.name = item.name
                activeBuffCount = activeBuffCount + 1
                reusableBuffs[activeBuffCount] = entry
            end

            for i, item in ipairs(dummyDebuffData) do
                poolIdx = poolIdx + 1
                local entry = auraEntryPool[poolIdx]
                if not entry then entry = {}; auraEntryPool[poolIdx] = entry end
                entry.icon = item.icon
                entry.timeLeft = item.time
                entry.timeEnding = 0
                entry.isPermanent = false
                entry.stackCount = 0
                entry.name = item.name
                activeDebuffCount = activeDebuffCount + 1
                reusableDebuffs[activeDebuffCount] = entry
            end

            for i = activeBuffCount + 1, #reusableBuffs do reusableBuffs[i] = nil end
            for i = activeDebuffCount + 1, #reusableDebuffs do reusableDebuffs[i] = nil end

            if activeBuffCount > 1 then table_sort(reusableBuffs, CompareEffectsDescending) end
            if activeDebuffCount > 1 then table_sort(reusableDebuffs, CompareEffectsDescending) end
        end
    else
        rescanTickCounter = rescanTickCounter + 1

        -- Entre deux rescans complets, met uniquement à jour les durées restantes
        if not effectsDirty and rescanTickCounter < 10 then
            for i = 1, activeBuffCount do
                local entry = reusableBuffs[i]
                if not entry.isPermanent then
                    entry.timeLeft = entry.timeEnding - currentTime
                    if entry.timeLeft <= 0 then
                        effectsDirty = true
                        break
                    end
                end
            end

            if not effectsDirty then
                for i = 1, activeDebuffCount do
                    local entry = reusableDebuffs[i]
                    if not entry.isPermanent then
                        entry.timeLeft = entry.timeEnding - currentTime
                        if entry.timeLeft <= 0 then
                            effectsDirty = true
                            break
                        end
                    end
                end
            end
        end

        -- Rescan complet uniquement sur événement EFFECT_CHANGED, expiration ou toutes les 1s
        if effectsDirty or rescanTickCounter >= 10 then
            effectsDirty = false
            rescanTickCounter = 0

            local poolIdx = 0
            activeBuffCount = 0
            activeDebuffCount = 0
            local longLimit = (settings.longBuffThreshold or 60) * 60
            local numBuffs = GetNumBuffs("player")

            for i = 1, numBuffs do
                local buffName, timeStarted, timeEnding, _, stackCount, iconFilename, _, effectType = GetUnitBuffInfo("player", i)

                if buffName and buffName ~= "" then
                    local isPermanent = (timeStarted == timeEnding) or (timeEnding == 0)
                    local timeLeft = isPermanent and 0 or (timeEnding - currentTime)

                    local skipEffect = (settings.hidePermanent and isPermanent)
                                    or (settings.hideLongBuffs and not isPermanent and timeLeft > longLimit)

                    if not skipEffect then
                        poolIdx = poolIdx + 1
                        local entry = auraEntryPool[poolIdx]
                        if not entry then
                            entry = {}
                            auraEntryPool[poolIdx] = entry
                        end

                        entry.name = buffName
                        entry.icon = iconFilename
                        entry.stackCount = stackCount or 0
                        entry.isPermanent = isPermanent
                        entry.timeLeft = timeLeft
                        entry.timeEnding = timeEnding

                        if effectType == BUFF_EFFECT_TYPE_DEBUFF then
                            activeDebuffCount = activeDebuffCount + 1
                            reusableDebuffs[activeDebuffCount] = entry
                        else
                            activeBuffCount = activeBuffCount + 1
                            reusableBuffs[activeBuffCount] = entry
                        end
                    end
                end
            end

            for i = activeBuffCount + 1, #reusableBuffs do reusableBuffs[i] = nil end
            for i = activeDebuffCount + 1, #reusableDebuffs do reusableDebuffs[i] = nil end

            if activeBuffCount > 1 then table_sort(reusableBuffs, CompareEffectsDescending) end
            if activeDebuffCount > 1 then table_sort(reusableDebuffs, CompareEffectsDescending) end
        end
    end

    RenderIconPool("buffs", reusableBuffs, activeBuffCount)
    RenderIconPool("debuffs", reusableDebuffs, activeDebuffCount)

    ApplyAnchors("buffs", activeBuffCount, settings.spacing, settings.iconSize, settings.buffDir, settings.buffEnableGrid, settings.buffMaxPerRow, settings.buffRowDirection)
    ApplyAnchors("debuffs", activeDebuffCount, settings.spacing, settings.iconSize, settings.debuffDir, settings.debuffEnableGrid, settings.debuffMaxPerRow, settings.debuffRowDirection)
end

-- Mise à jour des positions des conteneurs
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
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
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
            setFunc = function(value) TrueDebuffsBars.previewMode = value; MarkEffectsDirty() end,
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
                    setFunc = function(value) TrueDebuffsBars.savedVars.hidePermanent = value; MarkEffectsDirty() end,
                },
                {
                    type = "checkbox",
                    name = "Hide Long Duration Effects",
                    tooltip = "Hides buffs that have a long timer (e.g. food).",
                    getFunc = function() return TrueDebuffsBars.savedVars.hideLongBuffs end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.hideLongBuffs = value; MarkEffectsDirty() end,
                },
                {
                    type = "slider",
                    name = "Long Duration Threshold (Minutes)",
                    tooltip = "Any effect longer than this will be hidden.",
                    min = 1, max = 120, step = 1,
                    disabled = function() return not TrueDebuffsBars.savedVars.hideLongBuffs end,
                    getFunc = function() return TrueDebuffsBars.savedVars.longBuffThreshold end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.longBuffThreshold = value; MarkEffectsDirty() end,
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
                    choices = { "Below", "Above" },
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
                    choices = { "Below", "Above" },
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
                    setFunc = function(value) TrueDebuffsBars.savedVars.iconSize = value; InvalidateStyle() end,
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
                    choices = { "Gamepad Medium", "Gamepad Bold", "Medium (Default)", "Bold", "Antique", "Stone Tablet", "Chat Font" },
                    getFunc = function() return TrueDebuffsBars.savedVars.fontStyle end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.fontStyle = value; InvalidateStyle() end,
                },
                {
                    type = "dropdown",
                    name = "Font Outline / Shadow Style",
                    tooltip = "Choose an outline or shadow style to maximize text readability over any background.",
                    choices = availableStyleChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.fontOutlineStyle end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.fontOutlineStyle = value; InvalidateStyle() end,
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
                    setFunc = function(value) TrueDebuffsBars.savedVars.timerBuffPos = value; InvalidateStyle() end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Timer Position",
                    choices = timerPositionChoices,
                    getFunc = function() return TrueDebuffsBars.savedVars.timerDebuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.timerDebuffPos = value; InvalidateStyle() end,
                },
                {
                    type = "slider",
                    name = "Timer Text Size",
                    min = 10, max = 40, step = 1,
                    getFunc = function() return TrueDebuffsBars.savedVars.timerSize end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.timerSize = value; InvalidateStyle() end,
                },
                {
                    type = "colorpicker",
                    name = "Timer Color",
                    getFunc = function()
                        local c = TrueDebuffsBars.savedVars.timerColor
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        TrueDebuffsBars.savedVars.timerColor = { r = r, g = g, b = b, a = a }
                        InvalidateStyle()
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
                    choices = { "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center" },
                    getFunc = function() return TrueDebuffsBars.savedVars.stackBuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.stackBuffPos = value; InvalidateStyle() end,
                },
                {
                    type = "dropdown",
                    name = "Debuffs Stack Position",
                    choices = { "Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center" },
                    getFunc = function() return TrueDebuffsBars.savedVars.stackDebuffPos end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.stackDebuffPos = value; InvalidateStyle() end,
                },
                {
                    type = "slider",
                    name = "Stack Text Size",
                    min = 10, max = 40, step = 1,
                    getFunc = function() return TrueDebuffsBars.savedVars.stackSize end,
                    setFunc = function(value) TrueDebuffsBars.savedVars.stackSize = value; InvalidateStyle() end,
                },
                {
                    type = "colorpicker",
                    name = "Stack Color",
                    getFunc = function()
                        local c = TrueDebuffsBars.savedVars.stackColor
                        return c.r, c.g, c.b, c.a
                    end,
                    setFunc = function(r, g, b, a)
                        TrueDebuffsBars.savedVars.stackColor = { r = r, g = g, b = b, a = a }
                        InvalidateStyle()
                    end,
                },
            }
        }
    }
    LAM:RegisterOptionControls("TrueDebuffsBarsPanel", optionsData)
end

-- Événements pour déclencher un rescan uniquement quand les effets ou la zone changent
local function OnEffectChanged(_, _, _, _, unitTag)
    if unitTag == "player" then
        effectsDirty = true
    end
end

local function OnPlayerActivated()
    effectsDirty = true
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

    EVENT_MANAGER:RegisterForEvent(TrueDebuffsBars.name, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(TrueDebuffsBars.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(TrueDebuffsBars.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForUpdate(TrueDebuffsBars.name .. "UpdateLoop", TrueDebuffsBars.updateInterval, TrueDebuffsBars.UpdateBuffs)
end

EVENT_MANAGER:RegisterForEvent(TrueDebuffsBars.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)