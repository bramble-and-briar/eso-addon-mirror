-- =========================================================
-- NecroCat: Group Frames Module (Фреймы группы и рейда)
-- =========================================================

if not NecroCat then NecroCat = {} end
NecroCat.GroupFrames = NecroCat.GroupFrames or {}
local GF = NecroCat.GroupFrames

-- Авторские выверенные стандарты геометрии
local HEADER_HEIGHT      = 27
local NAME_OFFSET_Y      = 7
local BASE_TEXT_OFFSET_Y = 4

-- НАСТРОЙКИ ПО УМОЛЧАНИЮ
local defaultGroupSV = {
    enabled            = false,
    locked             = false,
    hideDefaultGroupBars = true, -- Скрывать стандартные полосы группы ESO
    groupLeft          = 100,
    groupTop           = 250,
    numColumns         = 2,
    frameScale         = 100,   -- Масштаб в % (70-150)
    frameWidth         = 205,
    barHeight          = 29,
    classIconSize      = 20,
    spacingX           = 12,
    spacingY           = 0,
    sortMode           = 3,
    frameStyle         = 1,
    barTexture         = 1,
    nameMode           = 1,
    textMode           = 1,
    showShieldText     = true,
    testShield         = false,
    testTrauma         = false,
    testCount          = 12,
    textOffsetY        = 0,
    
    nameFontSize       = 15,
    healthFontSize     = 17,
    statusFontSize     = 13,
    
    outOfRangeAlpha    = 0.60,
    leaderCrownSize      = 24,    -- Размер короны в центре
    leaderCrownAlpha     = 45,    -- Прозрачность короны (в процентах, 45%)
    leaderCrownOffsetX   = 48,     -- Смещение по X (0 = строго по центру)
    
    colorTank          = { 0.18, 0.45, 0.88, 1.0 },
    colorHeal          = { 0.92, 0.76, 0.20, 1.0 },
    colorDamage        = { 0.76, 0.14, 0.14, 1.0 },

    colorResurrect     = { 0.95, 0.80, 0.15, 1.0 },
    colorResPending    = { 0.20, 0.85, 0.75, 1.0 },
    colorGhost         = { 0.40, 0.70, 0.95, 1.0 },

    shieldColor        = { 0.25, 0.75, 0.95, 0.65 },
    traumaColor        = { 0.65, 0.12, 0.55, 0.80 },
    textColor          = { 1.0, 1.0, 1.0, 1.0 },
    shieldTextColor    = { 0.35, 0.85, 1.0, 1.0 },
}

GF.LEADER_ICON = "EsoUI/Art/UnitFrames/groupIcon_leader.dds"

-- =========================================================
-- ТАБЛИЦА СТИЛЕЙ ОФОРМЛЕНИЯ ГРУППОВЫХ ФРЕЙМОВ
-- =========================================================
GF.STYLES = {
    -- 1. СТИЛЬ ПО УМОЛЧАНИЮ (МИНИМАЛИЗМ)
    [1] = {
        id           = 1,
        name         = "SI_NC_LAM_STYLE_DEFAULT",
        hasArt       = false,
        barW         = 205,
        barH         = 29, 
        insetX       = 1,
        insetY       = 1,
        labelPadX    = 5,
        labelOffsetY = 0,
        spacingX     = 12,
        spacingY     = 0,
    },

    -- 2. ВАМПИРСКАЯ ГОТИКА
    [2] = {
        id           = 2,
        name         = "SI_NC_LAM_STYLE_VAMPIRE",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/two_backplate.dds",
            },
        },
        artW         = 230,
        artH         = 92,
        artOffsetX   = 0,
        artOffsetY   = 5,
        barW         = 205,
        barH         = 29,
        insetX       = 2,
        insetY       = 2,
        labelPadX    = 6,
        labelOffsetY = 0,
        spacingX     = 28,
        spacingY     = 0,
    },

    -- 3. НЕКРОКОШКА
    [3] = {
        id           = 3,
        name         = "SI_NC_LAM_STYLE_CAT",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_GREEN",
                art  = "NecroCat/imgs/frames/two_backplate_cat_green.dds",
            },
            [2] = {
                name = "SI_NC_LAM_COLOR_BLUE",
                art  = "NecroCat/imgs/frames/two_backplate_cat_blue.dds",
            },
        },
        artW         = 245,
        artH         = 112,
        artOffsetX   = 1,
        artOffsetY   = -9,
        barW         = 205,
        barH         = 29,
        insetX       = 2,
        insetY       = 2,
        labelPadX    = 6,
        labelOffsetY = 0,
        spacingX     = 30,
        spacingY     = -2,
    },

    -- 4. ЛЕТУЧИЕ МЫШИ
    [4] = {
        id           = 4,
        name         = "SI_NC_LAM_STYLE_BAT",
        hasArt       = true,
        colorVariants = {
            [1] = {
                name = "SI_NC_LAM_COLOR_DEFAULT",
                art  = "NecroCat/imgs/frames/two_backplate_bat.dds",
            },
        },
        artW         = 230,
        artH         = 80,
        artOffsetX   = -1,
        artOffsetY   = 0,
        barW         = 205,
        barH         = 29,
        insetX       = 2,
        insetY       = 2,
        labelPadX    = 6,
        labelOffsetY = 0,
        spacingX     = 26,
        spacingY     = 1,
    },
}

-- Автоматический сборщик доступных стилей для меню
local function GetGroupStyleChoices()
    local names, ids = {}, {}
    for id, st in ipairs(GF.STYLES) do
        local str = GetString(_G[st.name] or st.name)
        table.insert(names, str)
        table.insert(ids, id)
    end
    return names, ids
end

-- Системные иконки 7 классов ESO
GF.CLASS_ICONS = {
    [1]   = "EsoUI/Art/Icons/class/class_dragonknight.dds",
    [2]   = "EsoUI/Art/Icons/class/class_sorcerer.dds",
    [3]   = "EsoUI/Art/Icons/class/class_nightblade.dds",
    [4]   = "EsoUI/Art/Icons/class/class_warden.dds",
    [5]   = "EsoUI/Art/Icons/class/class_necromancer.dds",
    [6]   = "EsoUI/Art/Icons/class/class_templar.dds",
    [117] = "EsoUI/Art/Icons/class/class_arcanist.dds",
}

-- =========================================================
-- БИБЛИОТЕКА ТЕКСТУР ЗАПОЛНЕНИЯ ПОЛОС ГРУППЫ
-- =========================================================
GF.BAR_TEXTURES = {
    [1] = {
        id   = 1,
        name = "SI_NC_LAM_TEX_DEFAULT",
        path = "EsoUI/Art/Miscellaneous/progressbar_genericfiller.dds",
    },
    [2] = {
        id   = 2,
        name = "SI_NC_LAM_TEX_NECRO",
        path = "NecroCat/imgs/frames/necrofactura.dds",
    },
    [3] = {
        id   = 3,
        name = "SI_NC_LAM_TEX_BAT",
        path = "NecroCat/imgs/frames/batfactura.dds",
    },
    [4] = {
        id   = 4,
        name = "SI_NC_LAM_TEX_GRASS",
        path = "NecroCat/imgs/frames/Grass.dds",
    },
    [5] = {
        id   = 5,
        name = "SI_NC_LAM_TEX_GREY",
        path = "NecroCat/imgs/frames/Grey.dds",
    },
    [6] = {
        id   = 6,
        name = "SI_NC_LAM_TEX_MARBLE",
        path = "NecroCat/imgs/frames/Marble.dds",
    },
    [7] = {
        id   = 7,
        name = "SI_NC_LAM_TEX_ORNAMENT",
        path = "NecroCat/imgs/frames/Ornament.dds",
    },
    [8] = {
        id   = 8,
        name = "SI_NC_LAM_TEX_FABRIC",
        path = "NecroCat/imgs/frames/Fabric.dds",
    },
    [9] = {
        id   = 9,
        name = "SI_NC_LAM_TEX_ROAD",
        path = "NecroCat/imgs/frames/Road.dds",
    },
    [10] = {
        id   = 10,
        name = "SI_NC_LAM_TEX_ROCK",
        path = "NecroCat/imgs/frames/Rock.dds",
    },
}

function GF.GetBarTextureChoices()
    local names, ids = {}, {}
    for id = 1, #GF.BAR_TEXTURES do
        local tex = GF.BAR_TEXTURES[id]
        if tex then
            local str = GetString(_G[tex.name] or tex.name)
            table.insert(names, str)
            table.insert(ids, id)
        end
    end
    return names, ids
end

GF.framePool    = {}
GF.unitToFrame  = {}
GF.deathCounts  = {} -- Таблица счётчика смертей [@UserID] = количество
GF.isDeadState  = {} -- Защита от ложных повторов [key] = true/false
GF.rootFrame    = nil

local function GetOrCreateChild(parent, name, controlType)
    local child = parent:GetNamedChild(name)
    if child then return child end
    return WINDOW_MANAGER:CreateControl("$(parent)" .. name, parent, controlType)
end

function GF.GetClassIcon(classId)
    if GetClassIcon then
        local tex = GetClassIcon(classId)
        if tex and tex ~= "" then return tex end
    end
    return GF.CLASS_ICONS[classId] or GF.CLASS_ICONS[1]
end

local function FormatValueNumber(value)
    if not value then return "0" end
    if value >= 1000000 then
        return string.format("%.1fm", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fk", value / 1000)
    else
        return ZO_LocalizeDecimalNumber(value)
    end
end

local function RgbToHex(c)
    if not c then return "ffffff" end
    local r = zo_clamp(math.floor((c[1] or 1) * 255), 0, 255)
    local g = zo_clamp(math.floor((c[2] or 1) * 255), 0, 255)
    local b = zo_clamp(math.floor((c[3] or 1) * 255), 0, 255)
    return string.format("%02x%02x%02x", r, g, b)
end

function GF.GetBarColor(role)
    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV

    if role == LFG_ROLE_TANK or role == 2 then
        local c = sv.colorTank or defaultGroupSV.colorTank
        return c[1], c[2], c[3], c[4]
    elseif role == LFG_ROLE_HEAL or role == 4 then
        local c = sv.colorHeal or defaultGroupSV.colorHeal
        return c[1], c[2], c[3], c[4]
    else
        local c = sv.colorDamage or defaultGroupSV.colorDamage
        return c[1], c[2], c[3], c[4]
    end
end

-- 3. СОЗДАНИЕ ПУЛА ИЗ 24 ПЛАШЕК
function GF.CreateFramePool()
    if GF.rootFrame then return end

    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    local styleId = sv.frameStyle or 1
    local style   = GF.STYLES[styleId] or GF.STYLES[1]

    local bHeight = (style.hasArt and style.barH) or sv.barHeight or 29
    local totalH  = HEADER_HEIGHT + bHeight
    local fWidth  = (style.hasArt and style.barW) or sv.frameWidth or 205

    local root = _G["NecroCat_GroupRoot"] or WINDOW_MANAGER:CreateTopLevelWindow("NecroCat_GroupRoot")
    root:SetDimensions(fWidth, totalH)
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.groupLeft or 100, sv.groupTop or 250)
    root:SetMovable(not sv.locked)
    root:SetMouseEnabled(not sv.locked)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_HIGH)

    root:SetHandler("OnMoveStop", function(self)
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
        if NecroCat.savedVars and NecroCat.savedVars.group then
            NecroCat.savedVars.group.groupLeft = self:GetLeft()
            NecroCat.savedVars.group.groupTop = self:GetTop()
        end
    end)

    GF.rootFrame = root

    local iconSize = sv.classIconSize or 20

    for i = 1, 24 do
        local frame = _G["NecroCat_GF_" .. i] or WINDOW_MANAGER:CreateControl("NecroCat_GF_" .. i, root, CT_CONTROL)
        frame:SetDimensions(fWidth, totalH)
        frame:SetHidden(true)
        frame:SetMouseEnabled(true)

        -- Зажатие кнопки мыши: ЛКМ тащит сетку, если снят замок
        frame:SetHandler("OnMouseDown", function(self, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                local sv = NecroCat and NecroCat.savedVars and NecroCat.savedVars.group
                if sv and not sv.locked and GF.rootFrame then
                    GF.rootFrame:StartMoving()
                end
            end
        end)

        -- Отпускание кнопки: ЛКМ фиксирует позицию, ПКМ открывает меню
        frame:SetHandler("OnMouseUp", function(self, button, upInside)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                local sv = NecroCat and NecroCat.savedVars and NecroCat.savedVars.group
                if sv and not sv.locked and GF.rootFrame then
                    GF.rootFrame:StopMovingOrResizing()
                    GF.rootFrame:ClearAnchors()
                    GF.rootFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GF.rootFrame:GetLeft(), GF.rootFrame:GetTop())
                    sv.groupLeft = GF.rootFrame:GetLeft()
                    sv.groupTop = GF.rootFrame:GetTop()
                end
            elseif button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
                GF.ShowUnitContextMenu(self)
            end
        end)
        
        -- Наведение мыши: показ тултипа со счётчиком смертей
        frame:SetHandler("OnMouseEnter", function(self)
            local tag = self.unitTag
            if not tag then return end

            local dispName = self.isTest and self.mockName or GetUnitDisplayName(tag)
            local charName = self.isTest and "" or GetUnitName(tag)
            local key = dispName or charName or "Player"
            local deaths = GF.deathCounts[key] or 0

            InitializeTooltip(InformationTooltip, self, TOP, 0, -5)
            InformationTooltip:AddLine(dispName or charName, "", ZO_HIGHLIGHT_TEXT:UnpackRGBA())
            if charName and charName ~= "" and charName ~= dispName then
                InformationTooltip:AddLine(charName, "", ZO_NORMAL_TEXT:UnpackRGBA())
            end
            InformationTooltip:AddLine(zo_strformat(GetString(SI_NC_TOOLTIP_DEATHS), deaths), "", 1, 0.3, 0.3)
        end)

        frame:SetHandler("OnMouseExit", function(self)
            ClearTooltip(InformationTooltip)
        end)

        -- ШАПКА
        local leaderIcon = GetOrCreateChild(frame, "LeaderIcon", CT_TEXTURE)
        leaderIcon:SetDimensions(22, 22)
        leaderIcon:ClearAnchors()
        leaderIcon:SetAnchor(TOPRIGHT, frame, TOPRIGHT, 4, 6)
        leaderIcon:SetTexture(GF.LEADER_ICON)
        leaderIcon:SetDrawLayer(DL_CONTROLS)
        leaderIcon:SetHidden(true)

        local levelLabel = GetOrCreateChild(frame, "LevelLabel", CT_LABEL)
        levelLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", math.max(10, (sv.nameFontSize or 15) - 2)))
        levelLabel:ClearAnchors()
        levelLabel:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -2, NAME_OFFSET_Y)
        levelLabel:SetColor(0.85, 0.85, 0.85, 1)
        levelLabel:SetDrawLayer(DL_CONTROLS)

        local nameLabel = GetOrCreateChild(frame, "NameLabel", CT_LABEL)
        nameLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.nameFontSize or 15))
        nameLabel:ClearAnchors()
        nameLabel:SetAnchor(TOPLEFT, frame, TOPLEFT, iconSize - 2, NAME_OFFSET_Y)
        nameLabel:SetAnchor(RIGHT, levelLabel, LEFT, -4, 0)
        nameLabel:SetMaxLineCount(1)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        nameLabel:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
        nameLabel:SetDrawLayer(DL_CONTROLS)

        local classIcon = GetOrCreateChild(frame, "ClassIcon", CT_TEXTURE)
        classIcon:SetDimensions(iconSize, iconSize)
        classIcon:ClearAnchors()
        classIcon:SetAnchor(CENTER, nameLabel, LEFT, -(iconSize / 2 + 2), -4)
        classIcon:SetDrawLayer(DL_CONTROLS)

        -- ПОЛОСА ЗДОРОВЬЯ
        local barContainer = GetOrCreateChild(frame, "BarContainer", CT_CONTROL)
        barContainer:ClearAnchors()
        barContainer:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, HEADER_HEIGHT)
        barContainer:SetDimensions(fWidth, bHeight)

        local artBG = GetOrCreateChild(barContainer, "ArtBG", CT_TEXTURE)
        artBG:SetDrawLayer(DL_BACKGROUND)
        artBG:SetDrawLevel(2)
        artBG:SetHidden(true)

        local bg = GetOrCreateChild(barContainer, "BG", CT_BACKDROP)
        bg:SetAnchorFill(barContainer)
        bg:SetCenterColor(0.04, 0.04, 0.04, 0.92)
        bg:SetEdgeColor(0.18, 0.18, 0.18, 1.0)
        bg:SetEdgeTexture("", 8, 1, 1)
        bg:SetDrawLayer(DL_BACKGROUND)
        bg:SetDrawLevel(1)

        local healthBar = GetOrCreateChild(barContainer, "HealthBar", CT_STATUSBAR)
        healthBar:ClearAnchors()
        healthBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 1, 1)
        healthBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -1, -1)
        healthBar:SetDrawLayer(DL_CONTROLS)
        healthBar:SetDrawLevel(1)

        local shieldBar = GetOrCreateChild(barContainer, "ShieldBar", CT_STATUSBAR)
        shieldBar:ClearAnchors()
        shieldBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 1, 1)
        shieldBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -1, -1)
        shieldBar:SetDrawLayer(DL_CONTROLS)
        shieldBar:SetDrawLevel(2)
        shieldBar:SetHidden(true)

        local traumaBar = GetOrCreateChild(barContainer, "TraumaBar", CT_STATUSBAR)
        traumaBar:ClearAnchors()
        traumaBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 1, 1)
        traumaBar:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -1, -1)
        traumaBar:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
        traumaBar:SetDrawLayer(DL_CONTROLS)
        traumaBar:SetDrawLevel(3)
        traumaBar:SetHidden(true)

        local hpLeftLabel = GetOrCreateChild(barContainer, "HPLeft", CT_LABEL)
        hpLeftLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.healthFontSize or 17))
        hpLeftLabel:SetDrawLayer(DL_OVERLAY)
        hpLeftLabel:SetDrawLevel(4)

        local hpRightLabel = GetOrCreateChild(barContainer, "HPRight", CT_LABEL)
        hpRightLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.healthFontSize or 17))
        hpRightLabel:SetDrawLayer(DL_OVERLAY)
        hpRightLabel:SetDrawLevel(4)

        local statusLabel = GetOrCreateChild(barContainer, "StatusLabel", CT_LABEL)
        statusLabel:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", sv.statusFontSize or 13))
        statusLabel:SetDrawLayer(DL_OVERLAY)
        statusLabel:SetDrawLevel(5)
        statusLabel:SetHidden(true)

        frame.classIcon    = classIcon
        frame.leaderIcon   = leaderIcon
        frame.levelLabel   = levelLabel
        frame.nameLabel    = nameLabel
        frame.barContainer = barContainer
        frame.artBG        = artBG
        frame.bg           = bg
        frame.healthBar    = healthBar
        frame.shieldBar    = shieldBar
        frame.traumaBar    = traumaBar
        frame.hpLeftLabel  = hpLeftLabel
        frame.hpRightLabel = hpRightLabel
        frame.statusLabel  = statusLabel

        GF.framePool[i] = frame
    end
    GF.rootFrame = root

    -- Создаем фрагмент сцены для автоматического скрытия в меню и на карте
    GF.GroupFragment = ZO_SimpleSceneFragment:New(root)
    GF.UpdateVisibility()
    
end

-- 4. МАТЕМАТИКА УМНОЙ СЕТКИ
function GF.LayoutGrid(activeCount)
    if not GF.rootFrame then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    local styleId = sv.frameStyle or 1
    local style   = GF.STYLES[styleId] or GF.STYLES[1]

    local count = activeCount or 0
    if count == 0 then
        for i = 1, 24 do GF.framePool[i]:SetHidden(true) end
        return
    end

    local numCols = math.max(1, math.min(sv.numColumns or 2, 6))
    -- В данже на 4 человека всегда строго 1 вертикальный столбик!
    if count <= 4 then
        numCols = 1
    end
    local fWidth  = (style.hasArt and style.barW) or sv.frameWidth or 205
    local bHeight = (style.hasArt and style.barH) or sv.barHeight or 26
    local totalH  = HEADER_HEIGHT + bHeight
    local baseSpX = (style and style.spacingX) or 12
    local baseSpY = (style and style.spacingY) or 0
    local spX     = baseSpX + (sv.spacingOffsetX or (sv.spacingX and (sv.spacingX - 12)) or 0)
    local spY     = baseSpY + (sv.spacingOffsetY or (sv.spacingY and sv.spacingY) or 0)

    local rowsPerCol = math.ceil(count / numCols)
    if rowsPerCol < 1 then rowsPerCol = 1 end

    local colOffsetsY = {}
    for c = 0, numCols - 1 do colOffsetsY[c] = 0 end

    for i = 1, 24 do
        local frame = GF.framePool[i]
        if i <= count then
            frame:SetDimensions(fWidth, totalH)
            frame:ClearAnchors()

            local col = math.floor((i - 1) / rowsPerCol)
            if col >= numCols then col = numCols - 1 end

            local offsetX = col * (fWidth + spX)
            local offsetY = colOffsetsY[col] or 0

            frame:SetAnchor(TOPLEFT, GF.rootFrame, TOPLEFT, offsetX, offsetY)
            frame:SetHidden(false)

            -- Считаем отступ для следующего игрока
            local nextY = offsetY + totalH + spY

            -- Если у этого игрока прикреплен спутник (СТРОГО в режиме «В группе») — сдвигаем
            local compSV = NecroCat.savedVars and NecroCat.savedVars.companion
            local isCompDocked = compSV and (compSV.enabled ~= false) and (compSV.attachMode == 2)
            local tag = frame.unitTag

            if isCompDocked and tag and NecroCat.Companion and NecroCat.Companion.HasCompanionForUnit and NecroCat.Companion.HasCompanionForUnit(tag) then
                local compH = NecroCat.Companion.GetTotalHeight()
                local compSpY = (compSV and compSV.spacingY) or 2
                nextY = nextY + compH + compSpY
            end

            colOffsetsY[col] = nextY
        else
            frame:SetHidden(true)
        end
    end
end

-- 5. АЛГОРИТМ СОРТИРОВКИ РОСТЕРА
local function GetRoleWeight(role)
    if role == LFG_ROLE_TANK or role == 2 then return 1 end
    if role == LFG_ROLE_HEAL or role == 4 then return 2 end
    if role == LFG_ROLE_DPS  or role == 1 then return 3 end
    return 4
end

local function SortRoster(list, sortMode, numCols)
    if not list or #list <= 1 then return list end

    if sortMode == 1 then return list end

    if sortMode == 2 then
        table.sort(list, function(a, b)
            local wA = GetRoleWeight(a.role)
            local wB = GetRoleWeight(b.role)
            if wA ~= wB then return wA < wB end
            return (a.name or "") < (b.name or "")
        end)
        return list
    end

    if sortMode == 3 then
        local tanks, heals, dds, others = {}, {}, {}, {}
        for _, u in ipairs(list) do
            local w = GetRoleWeight(u.role)
            if w == 1 then table.insert(tanks, u)
            elseif w == 2 then table.insert(heals, u)
            elseif w == 3 then table.insert(dds, u)
            else table.insert(others, u) end
        end

        local cols = math.max(1, math.min(numCols or 2, 6))
        local subGroups = {}
        for c = 1, cols do subGroups[c] = {} end

        for idx, u in ipairs(tanks) do
            local targetCol = ((idx - 1) % cols) + 1
            table.insert(subGroups[targetCol], u)
        end
        for idx, u in ipairs(heals) do
            local targetCol = ((idx - 1) % cols) + 1
            table.insert(subGroups[targetCol], u)
        end
        for idx, u in ipairs(dds) do
            local targetCol = ((idx - 1) % cols) + 1
            table.insert(subGroups[targetCol], u)
        end
        for idx, u in ipairs(others) do
            local targetCol = ((idx - 1) % cols) + 1
            table.insert(subGroups[targetCol], u)
        end

        local balanced = {}
        for c = 1, cols do
            for _, u in ipairs(subGroups[c]) do
                table.insert(balanced, u)
            end
        end
        return balanced
    end

    return list
end

-- 6. ОБНОВЛЕНИЕ БОЕВОЙ ПЛАШКИ
function GF.UpdateUnitFrame(frame, unitTag)
    if not frame or not unitTag then return end

    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    local textMode = sv.textMode or 1

    local inRange = IsUnitInGroupSupportRange(unitTag)
    frame:SetAlpha(inRange and 1.0 or (sv.outOfRangeAlpha or defaultGroupSV.outOfRangeAlpha))

    if not IsUnitOnline(unitTag) then
        frame.healthBar:SetHidden(true); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
        frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
        frame.statusLabel:SetText(GetString(SI_NC_STATUS_OFFLINE)); frame.statusLabel:SetColor(0.5, 0.5, 0.5, 0.9)
        frame.statusLabel:SetHidden(false)
        return
    end

    if IsUnitReincarnating(unitTag) then
        local gc = sv.colorGhost or defaultGroupSV.colorGhost
        frame.healthBar:SetColor(gc[1], gc[2], gc[3], gc[4])
        frame.healthBar:SetMinMax(0, 1); frame.healthBar:SetValue(1)
        frame.healthBar:SetHidden(false); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
        frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
        frame.statusLabel:SetText(GetString(SI_NC_STATUS_GHOST)); frame.statusLabel:SetColor(1, 1, 1, 1)
        frame.statusLabel:SetHidden(false)

        -- Пульсирующий опрос выхода из режима призрака (каждую секунду)
        if not frame.ghostTimerActive then
            frame.ghostTimerActive = true
            local function CheckGhostState()
                if frame and unitTag and DoesUnitExist(unitTag) then
                    if IsUnitReincarnating(unitTag) then
                        zo_callLater(CheckGhostState, 1000)
                    else
                        frame.ghostTimerActive = nil
                        GF.UpdateUnitFrame(frame, unitTag)
                    end
                else
                    frame.ghostTimerActive = nil
                end
            end
            zo_callLater(CheckGhostState, 1000)
        end
        return
    elseif DoesUnitHaveResurrectPending(unitTag) then
        local rpc = sv.colorResPending or defaultGroupSV.colorResPending
        frame.healthBar:SetColor(rpc[1], rpc[2], rpc[3], rpc[4])
        frame.healthBar:SetMinMax(0, 1); frame.healthBar:SetValue(1)
        frame.healthBar:SetHidden(false); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
        frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
        frame.statusLabel:SetText(GetString(SI_NC_STATUS_RES_PENDING)); frame.statusLabel:SetColor(1, 1, 1, 1)
        frame.statusLabel:SetHidden(false)
        return
    elseif IsUnitBeingResurrected(unitTag) then
        local rc = sv.colorResurrect or defaultGroupSV.colorResurrect
        frame.healthBar:SetColor(rc[1], rc[2], rc[3], rc[4])
        frame.healthBar:SetMinMax(0, 1); frame.healthBar:SetValue(1)
        frame.healthBar:SetHidden(false); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
        frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
        frame.statusLabel:SetText(GetString(SI_NC_STATUS_RESURRECTING)); frame.statusLabel:SetColor(1, 1, 1, 1)
        frame.statusLabel:SetHidden(false)

        -- Опрос пока идет каст: если сопартийца собьют — моментально вернем статус «Мертв»
        if not frame.resPollActive then
            frame.resPollActive = true
            local function CheckResState()
                if frame and unitTag and DoesUnitExist(unitTag) and IsUnitDead(unitTag) then
                    if IsUnitBeingResurrected(unitTag) then
                        zo_callLater(CheckResState, 500)
                    else
                        frame.resPollActive = nil
                        GF.UpdateUnitFrame(frame, unitTag)
                    end
                else
                    frame.resPollActive = nil
                end
            end
            zo_callLater(CheckResState, 500)
        end
        return
    elseif IsUnitDead(unitTag) then
        frame.healthBar:SetHidden(true); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
        frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
        frame.statusLabel:SetText(GetString(SI_NC_STATUS_DEAD)); frame.statusLabel:SetColor(0.9, 0.2, 0.2, 1.0)
        frame.statusLabel:SetHidden(false)

        -- Опрос мертвого: ждем момента, когда кто-то зажмет камень воскрешения
        if not frame.deadPollActive then
            frame.deadPollActive = true
            local function CheckDeadState()
                if frame and unitTag and DoesUnitExist(unitTag) and IsUnitDead(unitTag) then
                    if not DoesUnitHaveResurrectPending(unitTag) and not IsUnitBeingResurrected(unitTag) then
                        zo_callLater(CheckDeadState, 500)
                    else
                        frame.deadPollActive = nil
                        GF.UpdateUnitFrame(frame, unitTag)
                    end
                else
                    frame.deadPollActive = nil
                end
            end
            zo_callLater(CheckDeadState, 500)
        end
        return
    end

    frame.statusLabel:SetHidden(true)
    frame.healthBar:SetHidden(false)

    local curHealth, maxHealth = GetUnitPower(unitTag, POWERTYPE_HEALTH)
    if maxHealth <= 0 then maxHealth = 1 end

    local role = GetGroupMemberSelectedRole(unitTag)
    local r, g, b, a = GF.GetBarColor(role)
    frame.healthBar:SetColor(r, g, b, a)
    frame.healthBar:SetMinMax(0, maxHealth)
    frame.healthBar:SetValue(curHealth)

    local shieldVal = 0
    local traumaVal = 0
    if GetUnitAttributeVisualizerEffectInfo then
        shieldVal = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
        traumaVal = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_TRAUMA, STAT_MITIGATION, ATTRIBUTE_HEALTH, POWERTYPE_HEALTH) or 0
    end

    if shieldVal > 0 then
        local sc = sv.shieldColor or defaultGroupSV.shieldColor
        frame.shieldBar:SetColor(sc[1], sc[2], sc[3], sc[4])
        frame.shieldBar:SetMinMax(0, maxHealth); frame.shieldBar:SetValue(shieldVal)
        frame.shieldBar:SetHidden(false)
    else
        frame.shieldBar:SetHidden(true)
    end

    if traumaVal > 0 then
        local tc = sv.traumaColor or defaultGroupSV.traumaColor
        frame.traumaBar:SetColor(tc[1], tc[2], tc[3], tc[4])
        frame.traumaBar:SetMinMax(0, maxHealth); frame.traumaBar:SetValue(traumaVal)
        frame.traumaBar:SetHidden(false)
    else
        frame.traumaBar:SetHidden(true)
    end

    if textMode == 5 then
        frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
        return
    end

    local pct = math.floor((curHealth / maxHealth) * 100)
    local shieldHex = RgbToHex(sv.shieldTextColor or defaultGroupSV.shieldTextColor)
    local extra = ""
    if shieldVal > 0 and sv.showShieldText ~= false then
        extra = extra .. string.format(" |c%s[+%s]|r", shieldHex, FormatValueNumber(shieldVal))
    end

    if textMode == 1 then
        frame.hpLeftLabel:SetHidden(false)
        frame.hpRightLabel:SetHidden(false)
        frame.hpLeftLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extra))
        frame.hpRightLabel:SetText(string.format("%d%%", pct))
    elseif textMode == 2 then
        frame.hpLeftLabel:SetHidden(true)
        frame.hpRightLabel:SetHidden(false)
        frame.hpRightLabel:SetText(string.format("%s%s (%d%%)", FormatValueNumber(curHealth), extra, pct))
    elseif textMode == 3 then
        frame.hpLeftLabel:SetHidden(true)
        frame.hpRightLabel:SetHidden(false)
        frame.hpRightLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extra))
    elseif textMode == 4 then
        frame.hpLeftLabel:SetHidden(true)
        frame.hpRightLabel:SetHidden(false)
        frame.hpRightLabel:SetText(string.format("%d%%%s", pct, extra))
    end
end

-- 7. ЖИВОЕ ПРИМЕНЕНИЕ НАСТРОЕК
function GF.ApplySettings()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    local styleId = sv.frameStyle or 1
    local style   = GF.STYLES[styleId] or GF.STYLES[1]

    -- Находим картинку из выбранного комплекта расцветки:
    local colorId = sv.styleColor or 1
    local variant = (style.colorVariants and style.colorVariants[colorId]) or (style.colorVariants and style.colorVariants[1])
    local artTex  = (variant and variant.art) or style.artTexture

    if GF.rootFrame then
        local isUnlocked = not sv.locked
        GF.rootFrame:SetMovable(isUnlocked)
        GF.rootFrame:SetMouseEnabled(isUnlocked)

        -- Общий масштаб фреймов группы (70-150%)
        local scale = (sv.frameScale or 100) / 100
        GF.rootFrame:SetScale(scale)
    end

    local textOffY   = BASE_TEXT_OFFSET_Y + (sv.textOffsetY or 0) + ((style and style.labelOffsetY) or 0)
    local labelPadX  = (style and style.labelPadX) or 5
    local textMode   = sv.textMode or 1
    local iconSize   = sv.classIconSize or 20
    local bHeight    = (style.hasArt and style.barH) or sv.barHeight or 26
    local fWidth     = (style.hasArt and style.barW) or sv.frameWidth or 205
    local totalH     = HEADER_HEIGHT + bHeight
    local texCfg     = GF.BAR_TEXTURES[sv.barTexture or 1] or GF.BAR_TEXTURES[1]
    local barTexPath = texCfg and texCfg.path

    local nameFont = string.format("$(BOLD_FONT)|%d|thick-outline", sv.nameFontSize or 15)
    local hpFont   = string.format("$(BOLD_FONT)|%d|thick-outline", sv.healthFontSize or 17)
    local stFont   = string.format("$(BOLD_FONT)|%d|thick-outline", sv.statusFontSize or 13)
    local cpFont   = string.format("$(BOLD_FONT)|%d|thick-outline", math.max(10, (sv.nameFontSize or 15) - 2))

    for i = 1, 24 do
        local f = GF.framePool[i]
        if f then
            f:SetDimensions(fWidth, totalH)

            f.barContainer:ClearAnchors()
            f.barContainer:SetAnchor(TOPLEFT, f, TOPLEFT, 0, HEADER_HEIGHT)
            f.barContainer:SetDimensions(fWidth, bHeight)

            -- Рамка стиля и отступы жидкости
            if style.hasArt and artTex and artTex ~= "" then
                f.artBG:SetHidden(false)
                f.artBG:SetTexture(artTex)
                f.artBG:SetDimensions(style.artW or fWidth, style.artH or bHeight)
                f.artBG:ClearAnchors()
                f.artBG:SetAnchor(CENTER, f.barContainer, CENTER, style.artOffsetX or 0, style.artOffsetY or 0)
                f.bg:SetHidden(true)
            else
                f.artBG:SetHidden(true)
                f.bg:SetHidden(false)
            end

            -- Отступы полоски внутри желоба
            local inX = style.insetX or 1
            local inY = style.insetY or 1

            f.healthBar:ClearAnchors()
            f.healthBar:SetAnchor(TOPLEFT, f.barContainer, TOPLEFT, inX, inY)
            f.healthBar:SetAnchor(BOTTOMRIGHT, f.barContainer, BOTTOMRIGHT, -inX, -inY)

            f.shieldBar:ClearAnchors()
            f.shieldBar:SetAnchor(TOPLEFT, f.barContainer, TOPLEFT, inX, inY)
            f.shieldBar:SetAnchor(BOTTOMRIGHT, f.barContainer, BOTTOMRIGHT, -inX, -inY)

            f.traumaBar:ClearAnchors()
            f.traumaBar:SetAnchor(TOPLEFT, f.barContainer, TOPLEFT, inX, inY)
            f.traumaBar:SetAnchor(BOTTOMRIGHT, f.barContainer, BOTTOMRIGHT, -inX, -inY)

            -- Шапка (Ник, Класс, Корона)
            f.classIcon:SetDimensions(iconSize, iconSize)
            f.classIcon:ClearAnchors()
            f.classIcon:SetAnchor(CENTER, f.nameLabel, LEFT, -(iconSize / 2 + 2), -4)

            f.nameLabel:ClearAnchors()
            f.nameLabel:SetAnchor(TOPLEFT, f, TOPLEFT, iconSize - 2, NAME_OFFSET_Y)
            f.nameLabel:SetAnchor(RIGHT, f.levelLabel, LEFT, -4, 0)
            f.nameLabel:SetFont(nameFont)

            local crownSize = sv.leaderCrownSize or 24
            local crownAlpha = (sv.leaderCrownAlpha or 45) / 100
            local crownOffX = sv.leaderCrownOffsetX or 0
            f.leaderIcon:SetDimensions(crownSize, crownSize)
            f.leaderIcon:SetAlpha(crownAlpha)
            f.leaderIcon:SetDrawLayer(DL_CONTROLS)
            f.leaderIcon:SetDrawLevel(3)
            f.leaderIcon:ClearAnchors()
            f.leaderIcon:SetAnchor(CENTER, f.barContainer, CENTER, crownOffX, 0)

            f.levelLabel:SetFont(cpFont)

            -- Текстура полосы
            if sv.barTexture and sv.barTexture > 1 then
                f.healthBar:SetTexture(barTexPath)
            else
                f.healthBar:SetTexture(nil)
            end

            -- Шрифты внутри полосы
            f.hpLeftLabel:SetFont(hpFont)
            f.hpRightLabel:SetFont(hpFont)
            f.statusLabel:SetFont(stFont)

            f.hpLeftLabel:ClearAnchors()
            f.hpRightLabel:ClearAnchors()
            f.statusLabel:ClearAnchors()

            f.statusLabel:SetAnchor(CENTER, f.barContainer, CENTER, 0, textOffY)

            if textMode == 1 then
                f.hpLeftLabel:SetAnchor(LEFT, f.barContainer, LEFT, labelPadX, textOffY)
                f.hpLeftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                f.hpLeftLabel:SetHidden(false)

                f.hpRightLabel:SetAnchor(RIGHT, f.barContainer, RIGHT, -labelPadX, textOffY)
                f.hpRightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
                f.hpRightLabel:SetHidden(false)
            elseif textMode == 2 or textMode == 3 or textMode == 4 then
                f.hpLeftLabel:SetHidden(true)

                f.hpRightLabel:SetAnchor(CENTER, f.barContainer, CENTER, 0, textOffY)
                f.hpRightLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                f.hpRightLabel:SetHidden(false)
            elseif textMode == 5 then
                f.hpLeftLabel:SetHidden(true)
                f.hpRightLabel:SetHidden(true)
            end
        end
    end

    GF.UpdateRoster()
end

-- 8. ПОЛНАЯ ПЕРЕСБОРКА РОСТЕРА
local MOCK_MEMBERS = {
    [1]  = { char = "Iron Wall",     id = "@IronWall",     role = 2, class = 1,   cp = 2450 }, -- DK Танк
    [2]  = { char = "Shield Lord",   id = "@ShieldLord",   role = 2, class = 4,   cp = 1920 }, -- Warden Танк
    [3]  = { char = "Holy Light",    id = "@HolyLight",    role = 4, class = 6,   cp = 1600 }, -- Templar Хил
    [4]  = { char = "Dawn Healer",   id = "@DawnHealer",   role = 4, class = 3,   cp = 1100 }, -- NB Хил
    [5]  = { char = "Blood Mage",    id = "@BloodMage",    role = 1, class = 5,   cp = 2100 }, -- Necro ДД
    [6]  = { char = "Shadow Blade",  id = "@ShadowBlade",  role = 1, class = 117, cp = 1850 }, -- Arcanist ДД
    [7]  = { char = "Storm Caller",  id = "@StormCaller",  role = 1, class = 2,   cp = 1400 }, -- Sorc ДД
    [8]  = { char = "Dead Guy",      id = "@DeadGuy",      role = 1, class = 1,   cp = 2200 }, -- МЁРТВ
    [9]  = { char = "Sleepy Cat",    id = "@SleepyCat",    role = 1, class = 4,   cp = 950 },  -- ОФФЛАЙН
    [10] = { char = "Rising Phoenix",id = "@RisingPhoenix",role = 1, class = 6,   cp = 1750 }, -- ВОСКРЕШАЮТ
    [11] = { char = "Lazy Bones",    id = "@LazyBones",    role = 1, class = 117, cp = 1300 }, -- ОТДЫХАЕТ
    [12] = { char = "Far Away",      id = "@FarAway",      role = 1, class = 5,   cp = 850 },  -- ПРИЗРАК
    [13] = { char = "Frost Bite",    id = "@FrostBite",    role = 1, class = 4,   cp = 1650 }, -- ДД
    [14] = { char = "Venom Strike",  id = "@VenomStrike",  role = 1, class = 3,   cp = 1900 }, -- ДД
    [15] = { char = "Sun Fire",      id = "@SunFire",      role = 4, class = 6,   cp = 2300 }, -- Хил
    [16] = { char = "Rune Master",   id = "@RuneMaster",   role = 1, class = 117, cp = 2050 }, -- ДД
    [17] = { char = "Dragon Breath", id = "@DragonBreath", role = 2, class = 1,   cp = 2150 }, -- Танк
    [18] = { char = "Night Stalker", id = "@NightStalker", role = 1, class = 3,   cp = 1450 }, -- ДД
    [19] = { char = "Arcane Pulse",  id = "@ArcanePulse",  role = 1, class = 117, cp = 1780 }, -- ДД
    [20] = { char = "Stone Wall",    id = "@StoneWall",    role = 2, class = 4,   cp = 2500 }, -- Танк
    [21] = { char = "Healing Wave",  id = "@HealingWave",  role = 4, class = 4,   cp = 1820 }, -- Хил
    [22] = { char = "Thunder Clap",  id = "@ThunderClap",  role = 1, class = 2,   cp = 1350 }, -- ДД
    [23] = { char = "Soul Reaper",   id = "@SoulReaper",   role = 1, class = 5,   cp = 1980 }, -- ДД
    [24] = { char = "Flame Strike",  id = "@FlameStrike",  role = 1, class = 1,   cp = 1620 }, -- ДД
}

local function FormatMemberName(charName, displayName, mode)
    if mode == 2 then return charName or displayName or "" end
    if mode == 3 then return string.format("%s (%s)", charName or "", displayName or "") end
    if mode == 4 then return string.format("%s (%s)", displayName or "", charName or "") end
    return displayName or charName or ""
end

function GF.UpdateRoster()
    -- Щит от вылета при загрузке: если пула плашек еще нет в памяти — ждем!
    if not GF.rootFrame or not GF.framePool or #GF.framePool == 0 then return end

    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    if not sv.enabled then
        if GF.rootFrame then GF.rootFrame:SetHidden(true) end
        return
    end

    local isTest = (sv.testCount and sv.testCount > 0)
    local groupSize = isTest and sv.testCount or GetGroupSize()

    if groupSize == 0 then
        if GF.rootFrame then GF.rootFrame:SetHidden(true) end
        for i = 1, 24 do GF.framePool[i]:SetHidden(true) end
        return
    else
        -- Если мы в живой игре (не в Esc) — моментально показываем окно при входе в пати!
        if not SCENE_MANAGER:IsShowing("gameMenuInGame") and GF.rootFrame then
            GF.rootFrame:SetHidden(false)
        end
    end
    -- Убрали насильный SetHidden(false), теперь показом управляют только сцены!

    GF.unitToFrame = {}
    local rawList = {}
    local nameMode = sv.nameMode or 1

    if isTest then
        for i = 1, groupSize do
            local mock = MOCK_MEMBERS[i] or { char = "Member " .. i, id = "@Player" .. i, role = 1, class = 1, cp = 1600 }
            table.insert(rawList, {
                unitTag  = "test" .. i,
                name     = FormatMemberName(mock.char, mock.id, nameMode),
                role     = mock.role,
                classId  = mock.class,
                cp       = mock.cp,
                isLeader = (i == 1),
                isTest   = true,
                index    = i,
            })
        end
    else
        -- Сканируем все 24 возможных слота ESO 
        for i = 1, 24 do
            local tag = "group" .. i
            if DoesUnitExist(tag) then
                local charName = GetUnitName(tag)
                local dispName = GetUnitDisplayName(tag)
                table.insert(rawList, {
                    unitTag  = tag,
                    name     = FormatMemberName(charName, dispName, nameMode),
                    role     = GetGroupMemberSelectedRole(tag),
                    classId  = GetUnitClassId(tag),
                    cp       = GetUnitChampionPoints(tag),
                    level    = GetUnitLevel(tag),
                    isLeader = IsUnitGroupLeader(tag),
                    isTest   = false,
                })
            end
        end

        -- САМОИСЦЕЛЕНИЕ: если игра еще не успела выдать все теги при масс-кике — добираем через 250 мс!
        if groupSize > 1 and #rawList < groupSize then
            zo_callLater(GF.UpdateRoster, 250)
        end
    end

    local sortedList = SortRoster(rawList, sv.sortMode or 3, sv.numColumns or 2)
    local activeCount = #sortedList

    -- Заранее раздаем теги, чтобы сетка знала, у кого есть спутники
    for i = 1, activeCount do
        GF.framePool[i].unitTag = sortedList[i].unitTag
    end

    GF.LayoutGrid(activeCount)

    for i = 1, 24 do
        local frame = GF.framePool[i]
        if i <= activeCount then
            local data = sortedList[i]
            frame.unitTag  = data.unitTag
            frame.isTest   = data.isTest
            frame.mockName = data.name

            frame.nameLabel:SetText(data.name)
            frame.classIcon:SetTexture(GF.GetClassIcon(data.classId))

            -- Фиксированный ЧП и корона-герб по центру
        frame.levelLabel:ClearAnchors()
        frame.levelLabel:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -2, NAME_OFFSET_Y)
        frame.leaderIcon:SetHidden(not data.isLeader)

            -- Чистые цифры ЧП
            local cpVal = data.cp or (data.unitTag and GetUnitChampionPoints(data.unitTag)) or 0
            if cpVal > 0 then
                frame.levelLabel:SetText(tostring(cpVal))
            else
                frame.levelLabel:SetText(tostring(data.level or 50))
            end

            if data.isTest then
                local idx = data.index or i
                local maxHealth = 32000
                local curHealth = 32000
                local shieldVal = sv.testShield and 10000 or 0
                local traumaVal = sv.testTrauma and 8000 or 0

                frame:SetAlpha(1.0)
                frame.statusLabel:SetHidden(true)
                frame.healthBar:SetHidden(false)

                if data.role == 2 then
                    maxHealth = 45000; curHealth = 42000
                    if idx == 1 then shieldVal = 18000 end
                elseif data.role == 4 then
                    maxHealth = 30000; curHealth = 28000
                    if idx == 4 then shieldVal = 8000 end
                end

                if idx == 6 then
                    frame:SetAlpha(sv.outOfRangeAlpha or defaultGroupSV.outOfRangeAlpha)
                elseif idx == 7 then
                    curHealth = 9000
                elseif idx == 8 then
                    frame.healthBar:SetHidden(true); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
                    frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
                    frame.statusLabel:SetText(GetString(SI_NC_STATUS_DEAD)); frame.statusLabel:SetColor(0.9, 0.2, 0.2, 1.0)
                    frame.statusLabel:SetHidden(false)
                elseif idx == 9 then
                    frame.healthBar:SetHidden(true); frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
                    frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
                    frame.statusLabel:SetText(GetString(SI_NC_STATUS_OFFLINE)); frame.statusLabel:SetColor(0.5, 0.5, 0.5, 0.9)
                    frame.statusLabel:SetHidden(false)
                elseif idx == 10 then
                    local rc = sv.colorResurrect or defaultGroupSV.colorResurrect
                    frame.healthBar:SetColor(rc[1], rc[2], rc[3], rc[4])
                    frame.healthBar:SetMinMax(0, 1); frame.healthBar:SetValue(1)
                    frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
                    frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
                    frame.statusLabel:SetText(GetString(SI_NC_STATUS_RESURRECTING)); frame.statusLabel:SetColor(1, 1, 1, 1)
                    frame.statusLabel:SetHidden(false)
                elseif idx == 11 then
                    local rpc = sv.colorResPending or defaultGroupSV.colorResPending
                    frame.healthBar:SetColor(rpc[1], rpc[2], rpc[3], rpc[4])
                    frame.healthBar:SetMinMax(0, 1); frame.healthBar:SetValue(1)
                    frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
                    frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
                    frame.statusLabel:SetText(GetString(SI_NC_STATUS_RES_PENDING)); frame.statusLabel:SetColor(1, 1, 1, 1)
                    frame.statusLabel:SetHidden(false)
                elseif idx == 12 then
                    local gc = sv.colorGhost or defaultGroupSV.colorGhost
                    frame.healthBar:SetColor(gc[1], gc[2], gc[3], gc[4])
                    frame.healthBar:SetMinMax(0, 1); frame.healthBar:SetValue(1)
                    frame.shieldBar:SetHidden(true); frame.traumaBar:SetHidden(true)
                    frame.hpLeftLabel:SetHidden(true); frame.hpRightLabel:SetHidden(true)
                    frame.statusLabel:SetText(GetString(SI_NC_STATUS_GHOST)); frame.statusLabel:SetColor(1, 1, 1, 1)
                    frame.statusLabel:SetHidden(false)
                end

                -- Живые игроки (все слоты, кроме демонстрационных статусов 8-12)
                if idx < 8 or idx > 12 then
                    local r, g, b, a = GF.GetBarColor(data.role)
                    frame.healthBar:SetColor(r, g, b, a)
                    frame.healthBar:SetMinMax(0, maxHealth)
                    frame.healthBar:SetValue(curHealth)

                    if shieldVal > 0 then
                        local sc = sv.shieldColor or defaultGroupSV.shieldColor
                        frame.shieldBar:SetColor(sc[1], sc[2], sc[3], sc[4])
                        frame.shieldBar:SetMinMax(0, maxHealth); frame.shieldBar:SetValue(shieldVal)
                        frame.shieldBar:SetHidden(false)
                    else
                        frame.shieldBar:SetHidden(true)
                    end

                    if traumaVal > 0 then
                        local tc = sv.traumaColor or defaultGroupSV.traumaColor
                        frame.traumaBar:SetColor(tc[1], tc[2], tc[3], tc[4])
                        frame.traumaBar:SetMinMax(0, maxHealth); frame.traumaBar:SetValue(traumaVal)
                        frame.traumaBar:SetHidden(false)
                    else
                        frame.traumaBar:SetHidden(true)
                    end

                    local textMode = sv.textMode or 1
                    if textMode ~= 5 then
                        local pct = math.floor((curHealth / maxHealth) * 100)
                        local shieldHex = RgbToHex(sv.shieldTextColor or defaultGroupSV.shieldTextColor)
                        local extra = ""
                        if shieldVal > 0 and sv.showShieldText ~= false then
                            extra = extra .. string.format(" |c%s[+%s]|r", shieldHex, FormatValueNumber(shieldVal))
                        end

                        if textMode == 1 then
                            frame.hpLeftLabel:SetHidden(false)
                            frame.hpRightLabel:SetHidden(false)
                            frame.hpLeftLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extra))
                            frame.hpRightLabel:SetText(string.format("%d%%", pct))
                        elseif textMode == 2 then
                            frame.hpLeftLabel:SetHidden(true)
                            frame.hpRightLabel:SetHidden(false)
                            frame.hpRightLabel:SetText(string.format("%s%s (%d%%)", FormatValueNumber(curHealth), extra, pct))
                        elseif textMode == 3 then
                            frame.hpLeftLabel:SetHidden(true)
                            frame.hpRightLabel:SetHidden(false)
                            frame.hpRightLabel:SetText(string.format("%s%s", FormatValueNumber(curHealth), extra))
                        elseif textMode == 4 then
                            frame.hpLeftLabel:SetHidden(true)
                            frame.hpRightLabel:SetHidden(false)
                            frame.hpRightLabel:SetText(string.format("%d%%%s", pct, extra))
                        end
                    end
                end
            else
                GF.unitToFrame[data.unitTag] = frame
                if AreUnitsEqual(data.unitTag, "player") then
                    GF.unitToFrame["player"] = frame
                end
                GF.UpdateUnitFrame(frame, data.unitTag)
            end
        else
            frame.unitTag = nil
            frame:SetHidden(true)
        end
    end

    -- Обновляем позиции прикрепленных спутников следом за группой
    if NecroCat.Companion and NecroCat.Companion.Update then
        NecroCat.Companion.Update()
    end
end

-- 9. СОБЫТИЯ
local function OnPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
    if powerType ~= POWERTYPE_HEALTH then return end
    local frame = GF.unitToFrame[unitTag]
    if frame then GF.UpdateUnitFrame(frame, unitTag) end
end

local function OnVisualChanged(eventCode, unitTag, unitAttributeVisual, statType, attributeType, powerType, value, maxValue, sequenceId)
    if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING or unitAttributeVisual == ATTRIBUTE_VISUAL_TRAUMA then
        local frame = GF.unitToFrame[unitTag]
        if frame then GF.UpdateUnitFrame(frame, unitTag) end
    end
end

local function OnDeathStateChanged(eventCode, unitTag, isDead)
    -- Фильтр: реагируем ТОЛЬКО на сопартийцев или себя (игнорируем мобов и прицел reticleover!)
    local isGroupUnit = (unitTag == "player") or (unitTag and string.match(unitTag, "^group%d+$"))

    if isGroupUnit and DoesUnitExist(unitTag) then
        local key = GetUnitDisplayName(unitTag) or GetUnitName(unitTag)
        if key and key ~= "" then
            if isDead then
                -- Прибавляем +1 СТРОГО один раз! Если игрок уже помечен мертвым — игнорируем спам игры
                if not GF.isDeadState[key] then
                    GF.isDeadState[key] = true
                    GF.deathCounts[key] = (GF.deathCounts[key] or 0) + 1
                end
            else
                -- Игрок ожил — сбрасываем флаг смерти для следующего раза
                GF.isDeadState[key] = false
            end
        end
    end

    local frame = GF.unitToFrame[unitTag]
    if frame then GF.UpdateUnitFrame(frame, unitTag) end
end

local function OnConnectedStatusChanged(eventCode, unitTag, isOnline)
    local frame = GF.unitToFrame[unitTag]
    if frame then GF.UpdateUnitFrame(frame, unitTag) end
end

local function OnSupportRangeChanged(eventCode, unitTag, status)
    local frame = GF.unitToFrame[unitTag]
    if frame then
        local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
        frame:SetAlpha(status and 1.0 or (sv.outOfRangeAlpha or defaultGroupSV.outOfRangeAlpha))
    end
end

-- Управление видимостью стандартных фреймов группы ESO
function GF.UpdateDefaultGroupBarsVisibility()
    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    local shouldHide = (sv.enabled ~= false) and (sv.hideDefaultGroupBars ~= false)

    if ZO_UnitFramesGroups then
        ZO_UnitFramesGroups:SetHidden(shouldHide)
    end
    if ZO_SmallGroupAnchorFrame then
        ZO_SmallGroupAnchorFrame:SetHidden(shouldHide)
    end
end

-- Железный перехватчик: блокирует попытки игры включить свои фреймы
local function HookDefaultGroupBars()
    if ZO_UnitFramesGroups then
        ZO_PreHook(ZO_UnitFramesGroups, "SetHidden", function(self, hidden)
            local sv = NecroCat and NecroCat.savedVars and NecroCat.savedVars.group
            if sv and sv.enabled and (sv.hideDefaultGroupBars ~= false) and not hidden then
                return true -- Блокируем появление стандартных полос!
            end
        end)
    end
    if ZO_SmallGroupAnchorFrame then
        ZO_PreHook(ZO_SmallGroupAnchorFrame, "SetHidden", function(self, hidden)
            local sv = NecroCat and NecroCat.savedVars and NecroCat.savedVars.group
            if sv and sv.enabled and (sv.hideDefaultGroupBars ~= false) and not hidden then
                return true
            end
        end)
    end
end

-- Управление видимостью фреймов группы в сценах игры (Инвентарь, Карта, Меню)
function GF.UpdateVisibility()
    if not GF.GroupFragment then return end
    local sv = (NecroCat.savedVars and NecroCat.savedVars.group) or defaultGroupSV
    local isEnabled = (sv.enabled ~= false)
    local isUnlocked = not sv.locked
    local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")

    if isEnabled then
        if not HUD_SCENE:HasFragment(GF.GroupFragment) then
            HUD_SCENE:AddFragment(GF.GroupFragment)
            HUD_UI_SCENE:AddFragment(GF.GroupFragment)
        end

        -- В меню Esc принудительно управляем видимостью
        if gameMenuScene then
            if isUnlocked then
                if not gameMenuScene:HasFragment(GF.GroupFragment) then
                    gameMenuScene:AddFragment(GF.GroupFragment)
                end
                if GF.rootFrame then GF.rootFrame:SetHidden(false) end
            else
                gameMenuScene:RemoveFragment(GF.GroupFragment)
                if GF.rootFrame and SCENE_MANAGER:IsShowing("gameMenuInGame") then
                    GF.rootFrame:SetHidden(true)
                end
            end
        end
    else
        HUD_SCENE:RemoveFragment(GF.GroupFragment)
        HUD_UI_SCENE:RemoveFragment(GF.GroupFragment)
        if gameMenuScene then
            gameMenuScene:RemoveFragment(GF.GroupFragment)
        end
        if GF.rootFrame then GF.rootFrame:SetHidden(true) end
    end
end

-- Автоматический контроль при каждом открытии меню Esc
local function HookEscMenuScene()
    local gameMenuScene = SCENE_MANAGER:GetScene("gameMenuInGame")
    if gameMenuScene and not GF.isEscHooked then
        GF.isEscHooked = true
        gameMenuScene:RegisterCallback("StateChange", function(oldState, newState)
            local sv = NecroCat and NecroCat.savedVars and NecroCat.savedVars.group
            local isUnlocked = sv and (not sv.locked)
            if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                if not isUnlocked and GF.rootFrame then
                    GF.rootFrame:SetHidden(true) -- Железно скрываем при входе в Esc!
                end
            elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                if GF.rootFrame and sv and sv.enabled and (sv.testCount > 0 or GetGroupSize() > 0) then
                    GF.rootFrame:SetHidden(false) -- Возвращаем в живой игре
                end
            end
        end)
    end
end

-- =========================================================
-- СИСТЕМНОЕ КОНТЕКСТНОЕ МЕНЮ (ПКМ ПО ПЛАШКЕ)
-- =========================================================
function GF.ShowUnitContextMenu(frame)
    if not frame then return end

    -- Если включен тестовый режим — показываем красивую демонстрацию
    if frame.isTest then
        ClearMenu()
        AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_WHISPER), function()
            zo_callLater(function()
                StartChatInput(string.format("/w %s ", frame.mockName or "@Player"))
            end, 50)
        end)
        AddMenuItem(GetString(SI_NC_MENU_JUMP), function()
            d("|c9933ff[NecroCat]|r " .. GetString(SI_NC_MENU_JUMP))
        end)
        AddMenuItem(GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER), function()
            d("|c9933ff[NecroCat]|r " .. GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER))
        end)
        AddMenuItem(GetString(SI_NC_MENU_KICK), function()
            d("|c9933ff[NecroCat]|r " .. GetString(SI_NC_MENU_KICK))
        end)
        ShowMenu(frame)
        return
    end

    -- Реальная группа ESO
    local unitTag = frame.unitTag
    if not unitTag or not DoesUnitExist(unitTag) then return end

    local isLocalPlayer = AreUnitsEqual(unitTag, "player")
    local rawCharName   = GetUnitName(unitTag)
    local rawDispName   = GetUnitDisplayName(unitTag)

    ClearMenu()

    -- 1. Шепнуть (/w @UserID)
    if not isLocalPlayer and rawDispName and rawDispName ~= "" then
        AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_WHISPER), function()
            zo_callLater(function()
                StartChatInput(string.format("/w %s ", rawDispName))
            end, 50)
        end)
    end

    -- 2. Переместиться к игроку (быстрый порт по имени, если онлайн)
    if not isLocalPlayer and IsUnitOnline(unitTag) then
        AddMenuItem(GetString(SI_NC_MENU_JUMP), function()
            local cleanName = (rawCharName and rawCharName ~= "") and zo_strformat("<<t:1>>", rawCharName)
            local target = (rawDispName and rawDispName ~= "") and rawDispName or cleanName
            if target then
                JumpToGroupMember(target)
            end
        end)
    end

    -- 3. Сделать лидером (только если сам лидер и кликнул не по себе)
    if IsUnitGroupLeader("player") and not isLocalPlayer then
        AddMenuItem(GetString(SI_GROUP_LIST_MENU_PROMOTE_TO_LEADER), function()
            GroupPromote(unitTag)
        end)
    end

    -- 4. Кикнуть (умное переключение: мгновенный кик или запуск голосования)
    if not isLocalPlayer then
        AddMenuItem(GetString(SI_NC_MENU_KICK), function()
            local mustVote = DoesGroupModificationRequireVote and DoesGroupModificationRequireVote()
            if IsUnitGroupLeader("player") and not mustVote then
                GroupKick(unitTag)
            elseif BeginGroupElection and GROUP_ELECTION_TYPE_KICK_MEMBER then
                BeginGroupElection(GROUP_ELECTION_TYPE_KICK_MEMBER, ZO_GROUP_ELECTION_DESCRIPTORS_NONE, unitTag)
            else
                GroupKick(unitTag)
            end
        end)
    end

    ShowMenu(frame)
end

-- 10. МЕНЮ НАСТРОЕК LAM
function GF.GetMenuOptions()
    local styleNames, styleIds = GetGroupStyleChoices()

    return {
        type = "submenu",
        name = "|c66f2ff" .. GetString(SI_NC_LAM_GROUP_SUB) .. "|r",
        tooltip = GetString(SI_NC_LAM_GROUP_SUB_TT),
        controls = {
            { type = "header", name = GetString(SI_NC_LAM_GROUP_ENABLE) },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_GROUP_ENABLE),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.enabled ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.enabled = v
                        GF.UpdateVisibility()
                        GF.UpdateRoster()
                        GF.UpdateDefaultGroupBarsVisibility()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_HIDE_DEFAULT_GROUP),
                disabled = function() return not (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.enabled ~= false) end,
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.hideDefaultGroupBars ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.hideDefaultGroupBars = v
                        GF.UpdateDefaultGroupBarsVisibility()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_GROUP_UNLOCK),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.locked == false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.locked = not v
                        GF.ApplySettings()
                        GF.UpdateVisibility()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_TEST),
                choices = { "Выкл (Реальная группа)", "4 игрока", "12 игроков (Триал)", "24 игрока (Рейд)" },
                choicesValues = { 0, 4, 12, 24 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.testCount) or 0 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.testCount = v
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_COLUMNS),
                tooltip = GetString(SI_NC_LAM_GROUP_COLUMNS_TT),
                min = 1, max = 6, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.numColumns) or 2 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.numColumns = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_SORT),
                choices = { GetString(SI_NC_LAM_GROUP_SORT_BALANCE), GetString(SI_NC_LAM_GROUP_SORT_ROLES), GetString(SI_NC_LAM_GROUP_SORT_NONE) },
                choicesValues = { 3, 2, 1 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.sortMode) or 3 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.sortMode = v
                        GF.UpdateRoster()
                    end
                end,
            },

            { type = "header", name = "Стиль и фактура" },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_STYLE),
                choices = styleNames,
                choicesValues = styleIds,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.frameStyle) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.frameStyle = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_TEXTURE),
                choices = { "Стандартная (Гладкая)", "Кровь", "Руны" },
                choicesValues = { 1, 2, 3 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.barTexture) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.barTexture = v
                        GF.ApplySettings()
                    end
                end,
            },

            { type = "header", name = "Отображение имени и текста" },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_NAME_MODE),
                choices = { GetString(SI_NC_LAM_NAME_USERID), GetString(SI_NC_LAM_NAME_CHAR), GetString(SI_NC_LAM_NAME_BOTH), GetString(SI_NC_LAM_NAME_ID_CHAR) },
                choicesValues = { 1, 2, 3, 4 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.nameMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.nameMode = v
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "dropdown",
                name = GetString(SI_NC_LAM_GROUP_TEXT_MODE),
                choices = { GetString(SI_NC_LAM_TEXT_SPLIT), GetString(SI_NC_LAM_TEXT_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_CENTER_VAL), GetString(SI_NC_LAM_TEXT_CENTER_PCT), GetString(SI_NC_LAM_TEXT_NONE) },
                choicesValues = { 1, 2, 3, 4, 5 },
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.textMode) or 1 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.textMode = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_GROUP_SHOW_SHIELD),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.showShieldText ~= false end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.showShieldText = v
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_LEADER_CROWN_SIZE),
                min = 14, max = 44, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.leaderCrownSize) or 24 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.leaderCrownSize = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_LEADER_CROWN_ALPHA),
                min = 10, max = 100, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.leaderCrownAlpha) or 45 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.leaderCrownAlpha = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_LEADER_CROWN_OFFSET_X),
                min = -140, max = 140, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.leaderCrownOffsetX) or 0 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.leaderCrownOffsetX = v
                        GF.ApplySettings()
                    end
                end,
            },
            { type = "header", name = "Размеры и зазоры" },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_SCALE),
                tooltip = GetString(SI_NC_LAM_GROUP_SCALE_TT),
                min = 70, max = 150, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.frameScale) or 100 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.frameScale = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_WIDTH),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.group
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = GF.STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.group
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = GF.STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 140, max = 320, step = 5,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.frameWidth) or 205 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.frameWidth = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_BAR_HEIGHT),
                tooltip = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.group
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = GF.STYLES[styleId]
                    if style and style.hasArt then return GetString(SI_NC_LAM_DIMENSIONS_LOCKED_TT) end
                    return nil
                end,
                disabled = function()
                    local sv = NecroCat.savedVars and NecroCat.savedVars.group
                    local styleId = (sv and sv.frameStyle) or 1
                    local style = GF.STYLES[styleId]
                    return style and style.hasArt
                end,
                min = 14, max = 60, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.barHeight) or 29 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.barHeight = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_CLASS_ICON),
                min = 12, max = 40, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.classIconSize) or 20 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.classIconSize = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_SPACING_X),
                min = 0, max = 40, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.spacingX) or 12 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.spacingX = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_SPACING_Y),
                min = 0, max = 30, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.spacingY) or 0 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.spacingY = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_TEXT_OFFSET_Y),
                min = -10, max = 10, step = 1,
                default = 0,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.textOffsetY) or 0 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.textOffsetY = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_NAME_FONT),
                min = 10, max = 28, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.nameFontSize) or 15 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.nameFontSize = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_HP_FONT),
                min = 10, max = 28, step = 1,
                getFunc = function() return (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.healthFontSize) or 17 end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.healthFontSize = v
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "slider",
                name = GetString(SI_NC_LAM_GROUP_ALPHA_FAR),
                tooltip = "Прозрачность для сопартийцев вне зоны хила (в %)",
                min = 20, max = 90, step = 5,
                getFunc = function()
                    local a = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.outOfRangeAlpha) or 0.60
                    return math.floor(a * 100 + 0.5)
                end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.outOfRangeAlpha = v / 100
                        GF.ApplySettings()
                    end
                end,
            },
            {
                type = "button",
                name = GetString(SI_NC_LAM_GROUP_RESET_POS),
                func = function()
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.groupLeft = 100
                        NecroCat.savedVars.group.groupTop = 250
                        if GF.rootFrame then
                            GF.rootFrame:ClearAnchors()
                            GF.rootFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100, 250)
                        end
                        GF.ApplySettings()
                    end
                end,
            },

            { type = "header", name = "Тестовые симуляции" },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_GROUP_TEST_SHIELD),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.testShield end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.testShield = v
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "checkbox",
                name = GetString(SI_NC_LAM_GROUP_TEST_TRAUMA),
                getFunc = function() return NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.testTrauma end,
                setFunc = function(v)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.testTrauma = v
                        GF.UpdateRoster()
                    end
                end,
            },

            { type = "header", name = "Цвета и оформление" },
            {
                type = "colorpicker",
                name = "Цвет танка",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.colorTank) or defaultGroupSV.colorTank
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.colorTank = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет целителя",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.colorHeal) or defaultGroupSV.colorHeal
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.colorHeal = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет бойца (ДД)",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.colorDamage) or defaultGroupSV.colorDamage
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.colorDamage = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет полосы щита",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.shieldColor) or defaultGroupSV.shieldColor
                    return c[1], c[2], c[3], c[4] or 0.65
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.shieldColor = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет полосы травмы",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.traumaColor) or defaultGroupSV.traumaColor
                    return c[1], c[2], c[3], c[4] or 0.8
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.traumaColor = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет статуса «Воскрешают»",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.colorResurrect) or defaultGroupSV.colorResurrect
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.colorResurrect = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет статуса «Отдыхает»",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.colorResPending) or defaultGroupSV.colorResPending
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.colorResPending = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет статуса «Призрак»",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.colorGhost) or defaultGroupSV.colorGhost
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.colorGhost = { r, g, b, a }
                        GF.UpdateRoster()
                    end
                end,
            },
            {
                type = "colorpicker",
                name = "Цвет текста",
                getFunc = function()
                    local c = (NecroCat.savedVars and NecroCat.savedVars.group and NecroCat.savedVars.group.textColor) or defaultGroupSV.textColor
                    return c[1], c[2], c[3], c[4] or 1
                end,
                setFunc = function(r, g, b, a)
                    if NecroCat.savedVars and NecroCat.savedVars.group then
                        NecroCat.savedVars.group.textColor = { r, g, b, a }
                        GF.ApplySettings()
                    end
                end,
            },
        },
    }
end

-- 11. ИНИЦИАЛИЗАЦИЯ
local function OnPlayerActivated()
    if not (NecroCat.savedVars and NecroCat.savedVars.group) then
        if NecroCat.savedVars then
            NecroCat.savedVars.group = ZO_ShallowTableCopy(defaultGroupSV)
        end
    end

    GF.CreateFramePool()
    GF.ApplySettings()
    GF.UpdateVisibility()
    HookEscMenuScene()
    HookDefaultGroupBars()
    GF.UpdateDefaultGroupBarsVisibility()

    -- Контрольная перепроверка через 1.5 сек (когда сервер догрузит спутников группы)
    zo_callLater(GF.UpdateRoster, 1500)
end

EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

local isRosterUpdatePending = false
local function OnGroupRosterChanged()
    if isRosterUpdatePending then return end
    isRosterUpdatePending = true
    zo_callLater(function()
        isRosterUpdatePending = false
        GF.UpdateRoster()
    end, 200)
end

-- Реагируем на появление и исчезновение только членов группы и спутников
local function OnUnitSpawnOrDespawn(eventCode, unitTag)
    if unitTag and (string.match(unitTag, "group") or string.match(unitTag, "companion")) then
        OnGroupRosterChanged()
    end
end

EVENT_MANAGER:RegisterForEvent("NecroCat_GF_GroupJoin",   EVENT_GROUP_MEMBER_JOINED, OnGroupRosterChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_GroupLeft",   EVENT_GROUP_MEMBER_LEFT,   OnGroupRosterChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_GroupUpd",    EVENT_GROUP_UPDATE,        OnGroupRosterChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_UnitCreated",  EVENT_UNIT_CREATED,        OnUnitSpawnOrDespawn)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_UnitDestr",    EVENT_UNIT_DESTROYED,      OnUnitSpawnOrDespawn)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_RoleChg",     EVENT_GROUP_MEMBER_ROLE_CHANGED, OnGroupRosterChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_LeaderChg",   EVENT_LEADER_UPDATE,       OnGroupRosterChanged)

EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Power",      EVENT_POWER_UPDATE,        OnPowerUpdate)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Death",      EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathStateChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Range",      EVENT_GROUP_SUPPORT_RANGE_UPDATE, OnSupportRangeChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Connected",  EVENT_GROUP_MEMBER_CONNECTED_STATUS, OnConnectedStatusChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Alive",      EVENT_PLAYER_ALIVE, function()
    local frame = GF.unitToFrame["player"]
    if frame then GF.UpdateUnitFrame(frame, "player") end
end)

-- Слушаем начало и отмену процесса воскрешения сопартийца или себя:
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_Reviving", EVENT_CORPSE_BEING_REVIVED_STATE_CHANGED, function(eventCode, unitTag, isBeingRevived)
    local frame = GF.unitToFrame[unitTag] or (AreUnitsEqual(unitTag, "player") and GF.unitToFrame["player"])
    if frame then
        GF.UpdateUnitFrame(frame, frame.unitTag or unitTag)
    end
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_GF_ResReq",     EVENT_RESURRECT_REQUEST, function()
    zo_callLater(GF.UpdateRoster, 150)
end)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_ResRes",     EVENT_RESURRECT_RESULT, function()
    zo_callLater(GF.UpdateRoster, 150)
end)

EVENT_MANAGER:RegisterForEvent("NecroCat_GF_VisAdd",     EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED,   OnVisualChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_VisUpd",     EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualChanged)
EVENT_MANAGER:RegisterForEvent("NecroCat_GF_VisRem",     EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualChanged)