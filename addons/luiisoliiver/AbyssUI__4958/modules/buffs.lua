--[[
    NAGAUI - Buffs / Debuffs (completo)
    Portado e expandido a partir do sistema de Buffs do NagaHUDCUSTOM/BUI_Buffs.lua.

    Paineis:
      * Buffs do jogador
      * Passivas (painel separado opcional)
      * Buffs/debuffs do alvo
      * Painel de buffs personalizados
      * Painel de cooldown de sinergia
      * Widgets (buffs importantes destacados)

    Todos os paineis podem ser desbloqueados e movidos; posicoes sao salvas
    no perfil de servidor (como no BUI original).
]]

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

local Buffs = {}
NAGA_UI.Buffs = Buffs

local ADDON_NAME = "AbyssUI"
-- Lui-style: no small hard display limit (was 12/24). Pool is large; layout
-- shows as many icons as fit by width/rows. Duplicates are collapsed by abilityId.
local PLAYER_MAX = 64
local TARGET_MAX = 64
local PASSIVE_MAX = 32
local CUSTOM_MAX = 24
local SYNERGY_MAX = 16
local WIDGET_MAX = 24
local DEFAULT_ICON_SIZE = 40
local GAP = 5
-- Soft max icons shown per group (buffs or debuffs). Lui has no fixed cap;
-- this only bounds memory if GetNumBuffs spikes.
local SOFT_DISPLAY_MAX = 64
local MOUNTED_PLAYER_BUFF_EXTRA_GAP = 12
local UPDATE_MS = 100

local PROC_EFFECTS = {
    [126924] = { cd = 10, icon = "/esoui/art/icons/ability_mage_010.dds" },
    [136098] = { cd = 10, icon = "/esoui/art/icons/ability_mage_010.dds" },
    [137995] = { cd = 10, icon = "/esoui/art/icons/ability_mage_010.dds" },
    [107141] = { cd = 10, icon = "/esoui/art/icons/ability_templar_rune_focus.dds" },
    [109084] = { cd = 10, icon = "/esoui/art/icons/ability_templar_rune_focus.dds" },
    [110067] = { cd = 3,  icon = "/esoui/art/icons/ability_mage_010.dds" },
    [110143] = { cd = 3,  icon = "/esoui/art/icons/ability_mage_010.dds" },
    [99204]  = { cd = 18, icon = "/esoui/art/icons/gear_clockwork_medium_head_a.dds" },
    [126941] = { cd = 7,  icon = "/esoui/art/icons/death_recap_disease_melee.dds" },
    [21676]  = { cd = 600, icon = "/esoui/art/icons/ability_mage_025.dds", negative = true },
    [81036]  = { cd = 15, icon = "/esoui/art/icons/pet_200_dwarven-ebonyyellow.dds" },
}

local SYNERGY_IDS = {
    [108799] = true, [108802] = true, [108821] = true, [108924] = true,
    [48052]  = true, [95926]  = true,
}

local IMPORTANT_BUFFS = {
    [40224] = true, [61771] = true, [61747] = true, [61665] = true,
    [61694] = true, [61745] = true, [93109] = true, [122389] = true, [62988] = true,
}

local COLOR_FRAME = { 0.00, 0.00, 0.00, 0.95 }

local panels = {
    player = nil, target = nil, passive = nil,
    custom = nil, synergy = nil, widgets = nil,
}

local initialized = false
local tickerId = ADDON_NAME .. "_NagaBuffsTicker"
local specialCooldowns = {}
local synergyCooldowns = {}

local function GetS()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetBuffs then
        return NAGA_UI.Settings:GetBuffs()
    end
    return nil
end


local function IconSize(which)
    local s = GetS()
    if not s then return DEFAULT_ICON_SIZE end
    if which == "player"  then return s.playerBuffSize  or DEFAULT_ICON_SIZE end
    if which == "target"  then return s.targetBuffSize  or DEFAULT_ICON_SIZE end
    if which == "passive" then return s.passiveBuffSize or 36 end
    if which == "custom"  then return s.customBuffSize  or DEFAULT_ICON_SIZE end
    if which == "synergy" then return s.synergyCdSize   or DEFAULT_ICON_SIZE end
    if which == "widgets" then return s.widgetsSize     or DEFAULT_ICON_SIZE end
    return DEFAULT_ICON_SIZE
end

local function MinDuration()
    local s = GetS()
    return (s and s.minimumDuration) or 3
end

local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

-- Sempre ocultar (mesmo com lista negra desligada)
local ALWAYS_HIDDEN = {
    [43752] = true, -- Soul Summons / Invocacao de Alma
}

local ALWAYS_HIDDEN_NAMES = {
    ["soul summons"] = true,
    ["invocacao de alma"] = true,
    ["invocação de alma"] = true,
}

local function NormalizeName(name)
    if not name then return "" end
    name = string.lower(tostring(name))
    -- remove acentos comuns
    name = name:gsub("ã", "a"):gsub("á", "a"):gsub("à", "a"):gsub("â", "a")
    name = name:gsub("é", "e"):gsub("ê", "e")
    name = name:gsub("í", "i")
    name = name:gsub("ó", "o"):gsub("ô", "o"):gsub("õ", "o")
    name = name:gsub("ú", "u"):gsub("ç", "c")
    return name
end

local function IsBlacklisted(abilityId, name)
    abilityId = tonumber(abilityId)
    if abilityId and ALWAYS_HIDDEN[abilityId] then return true end
    local n = NormalizeName(name)
    if n ~= "" and ALWAYS_HIDDEN_NAMES[n] then return true end

    local s = GetS()
    if not s or not s.enableBlackList then return false end
    local list = s.blackList or {}
    if abilityId and list[abilityId] then return true end
    if name and list[name] then return true end
    if abilityId and list[tostring(abilityId)] then return true end
    if n ~= "" then
        for k, v in pairs(list) do
            if v and type(k) == "string" and NormalizeName(k) == n then
                return true
            end
        end
    end
    return false
end

local function IsCustomBuff(abilityId, name)
    local s = GetS()
    if not s or not s.enableCustomBuffs then return false end
    local list = s.customBuffs or {}
    if abilityId and list[abilityId] then return true end
    if name and list[name] then return true end
    if abilityId and list[tostring(abilityId)] then return true end
    return false
end

local function IsWidgetBuff(abilityId, name)
    local s = GetS()
    if not s or not s.enableWidgets then return false end
    local list = s.widgets or {}
    if abilityId and list[abilityId] then return true end
    if name and list[name] then return true end
    if abilityId and list[tostring(abilityId)] then return true end
    return false
end

local function CreateBuffIcon(parent, namePrefix, index, size)
    size = size or DEFAULT_ICON_SIZE
    local control = WINDOW_MANAGER:CreateControl(namePrefix .. index, parent, CT_CONTROL)
    control:SetDimensions(size, size)
    control:SetHidden(true)
    control:SetMouseEnabled(false)

    control.bg = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    control.bg:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    control.bg:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
    control.bg:SetCenterColor(0, 0, 0, 0.55)
    control.bg:SetEdgeColor(unpack(COLOR_FRAME))
    control.bg:SetEdgeTexture("", 1, 1, 1)
    control.bg:SetDrawLayer(DL_BACKGROUND)

    control.icon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    control.icon:SetAnchor(CENTER, control, CENTER, 0, 0)
    control.icon:SetDimensions(size - 4, size - 4)
    control.icon:SetTexture("/esoui/art/icons/icon_missing.dds")
    control.icon:SetDrawLayer(DL_BACKGROUND)

    control.cooldown = WINDOW_MANAGER:CreateControl(nil, control, CT_COOLDOWN)
    control.cooldown:SetAnchor(TOPLEFT, control.icon, TOPLEFT, 0, 0)
    control.cooldown:SetAnchor(BOTTOMRIGHT, control.icon, BOTTOMRIGHT, 0, 0)
    control.cooldown:SetFillColor(0, 0, 0, 0.70)
    control.cooldown:SetDrawLayer(DL_CONTROLS)
    control.cooldown:SetHidden(true)

    control.timer = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.timer:SetAnchor(CENTER, control, CENTER, 0, 0)
    control.timer:SetDimensions(size + 10, 22)
    control.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    control.timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.timer:SetFont("ZoFontGameBold")
    control.timer:SetColor(1, 1, 1, 1)
    control.timer:SetDrawLayer(DL_OVERLAY)

    control.count = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    control.count:SetAnchor(TOPRIGHT, control, TOPRIGHT, -1, 1)
    control.count:SetDimensions(22, 18)
    control.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    control.count:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.count:SetFont("ZoFontGameSmallBold")
    control.count:SetColor(1, 1, 1, 1)
    control.count:SetDrawLayer(DL_CONTROLS)

    control.progress = WINDOW_MANAGER:CreateControl(nil, control, CT_STATUSBAR)
    control.progress:SetAnchor(LEFT, control, RIGHT, 2, 0)
    control.progress:SetDimensions(100, 8)
    control.progress:SetMinMax(0, 1)
    control.progress:SetValue(0)
    control.progress:SetColor(0.25, 0.70, 0.90, 0.90)
    control.progress:SetHidden(true)

    return control
end

-- Controles XML (AbyssUI_Root.xml) registrados no Edit HUD nativo.
local PANEL_XML_NAMES = {
    player  = "NAGA_BuffsPlayerRoot",
    target  = "NAGA_BuffsTargetRoot",
    passive = "NAGA_BuffsPassiveRoot",
    custom  = "NAGA_BuffsCustomRoot",
    synergy = "NAGA_BuffsSynergyRoot",
    widgets = "NAGA_BuffsWidgetsRoot",
}

local function CreatePanel(name, maxIcons, size)
    size = size or DEFAULT_ICON_SIZE
    local xmlName = PANEL_XML_NAMES[name]
    local panel = xmlName and _G[xmlName] or nil

    if not panel then
        -- Fallback (sem ZO_HUDManager_Element — so se XML falhar)
        panel = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "_BuffPanel_" .. name)
        panel:SetClampedToScreen(true)
        panel:SetDrawLayer(DL_CONTROLS)
        panel:SetDrawTier(DT_HIGH)
    end

    panel:SetMouseEnabled(true)
    panel:SetClampedToScreen(true)
    panel.panelName = name
    panel.iconSize = size
    panel.hudElementRef = panel

    -- Nunca handlers de movimento do addon.
    pcall(function() panel:SetHandler("OnMoveStop", nil) end)
    pcall(function() panel:SetHandler("OnMouseUp", nil) end)
    pcall(function() panel:SetHandler("OnMoveStart", nil) end)

    if not panel.icons then
        panel.icons = {}
        for i = 1, maxIcons do
            local icon = CreateBuffIcon(panel, panel:GetName() .. "_Icon", i, size)
            icon:SetAnchor(CENTER, panel, CENTER, 0, 0)
            panel.icons[i] = icon
        end
    end

    return panel
end

local function ResizePanelIcons(panel, size)
    if not panel then return end
    panel.iconSize = size
    -- Nao alterar dimensoes do root (HUD_MANAGER).
    if not panel.icons then return end
    for _, control in ipairs(panel.icons) do
        control:SetDimensions(size, size)
        control.icon:SetDimensions(size - 4, size - 4)
        control.timer:SetDimensions(size + 10, 22)
    end
end

local function IsEditHUDShowing()
    if not SCENE_MANAGER or not SCENE_MANAGER.IsShowing then return false end
    return SCENE_MANAGER:IsShowing("hud_editor_keyboard")
        or SCENE_MANAGER:IsShowing("hud_editor_gamepad")
end

local function IsRealHUDShowing()
    -- No Edit HUD nativo os paineis devem permanecer visiveis para mover.
    if IsEditHUDShowing() then return true end
    if not SCENE_MANAGER or not SCENE_MANAGER.IsShowing then return true end
    return SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
end

-- Faz os buffs principais acompanharem os elementos aos quais pertencem.
-- Player buffs ficam abaixo das barras do personagem; target debuffs ficam acima do alvo.
-- Esses dois painéis não são elementos independentes do Edit HUD: a posição é relativa ao HUD do personagem/alvo.
local function ApplyFollowAnchors()
    local playerPanel = panels.player
    local targetPanel = panels.target

    -- O painel segue o centro da barra/frame. As fileiras de buffs/debuffs
    -- sao posicionadas acima/abaixo desse ponto, portanto continuam juntas
    -- quando o elemento do HUD 2 e movido.
    if playerPanel then
        local resourceRoot = NAGA_UI.ResourceBars and NAGA_UI.ResourceBars.GetRoot
            and NAGA_UI.ResourceBars:GetRoot()
        if resourceRoot then
            playerPanel:ClearAnchors()
            playerPanel:SetAnchor(CENTER, resourceRoot, CENTER, 0, 0)
        end
    end

    if targetPanel then
        local targetRoot = NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.GetRoot
            and NAGA_UI.TargetFrame:GetRoot()
        if targetRoot then
            targetPanel:ClearAnchors()
            targetPanel:SetAnchor(CENTER, targetRoot, CENTER, 0, 0)
        end
    end
end

local function IsDebuff(data)
    if not data then return false end
    -- ESO normalmente usa EFFECT_TYPE_DEBUFF; os procs negativos deste addon
    -- usam -1. O valor 2 cobre versoes/API onde o enum nao esta exposto.
    return data.negative == true
        or data.effectType == -1
        or (EFFECT_TYPE_DEBUFF ~= nil and data.effectType == EFFECT_TYPE_DEBUFF)
        or data.effectType == 2
end

local function SplitBuffDebuff(list)
    local buffs, debuffs = {}, {}
    for _, data in ipairs(list or {}) do
        if IsDebuff(data) then
            table.insert(debuffs, data)
        else
            table.insert(buffs, data)
        end
    end
    return buffs, debuffs
end

-- Collapse duplicate abilityIds (same buff twice from API / procs). Keep higher
-- stacks, then shorter remaining time (more urgent).
local function DeduplicateBuffs(list)
    local best, order = {}, {}
    for _, data in ipairs(list or {}) do
        local key = data.abilityId or data.name
        if key ~= nil and key ~= "" then
            local prev = best[key]
            if not prev then
                best[key] = data
                order[#order + 1] = key
            else
                local ds, ps = tonumber(data.stacks) or 0, tonumber(prev.stacks) or 0
                local dr, pr = tonumber(data.remaining) or 0, tonumber(prev.remaining) or 0
                if ds > ps or (ds == ps and dr > 0 and (pr <= 0 or dr < pr)) then
                    best[key] = data
                end
            end
        else
            order[#order + 1] = data
            best[data] = data
        end
    end
    local out = {}
    for _, key in ipairs(order) do
        local entry = best[key]
        if entry then
            out[#out + 1] = entry
        end
    end
    return out
end

local function EnsureIconCount(panel, needed, size)
    if not panel then return end
    panel.icons = panel.icons or {}
    size = size or panel.iconSize or DEFAULT_ICON_SIZE
    needed = math.min(math.max(tonumber(needed) or 0, 0), SOFT_DISPLAY_MAX * 2)
    while #panel.icons < needed do
        local i = #panel.icons + 1
        local icon = CreateBuffIcon(panel, panel:GetName() .. "_Icon", i, size)
        icon:SetAnchor(CENTER, panel, CENTER, 0, 0)
        icon:SetHidden(true)
        panel.icons[i] = icon
    end
end


local function RowXOffset(index, count, step)
    -- 6 por linha, sempre centralizados.
    return (index - (count + 1) / 2) * step
end

local function LayoutBuffDebuffRows(panel, buffs, debuffs, anchorRoot, extraBuffDown)
    if not panel then return end
    buffs = DeduplicateBuffs(buffs)
    debuffs = DeduplicateBuffs(debuffs)
    local size = panel.iconSize or DEFAULT_ICON_SIZE
    local step = size + GAP
    -- 7 per row. Extra rows: buffs down, debuffs up; each row centered.
    local maxPerRow = 7
    local visible = 0


    -- Os buffs ficam ABAIXO do elemento: primeira fileira logo abaixo,
    -- segunda fileira mais para baixo.
    -- Os debuffs ficam ACIMA: primeira fileira logo acima, segunda mais para cima.
    local playerHeight = anchorRoot and anchorRoot.GetHeight and anchorRoot:GetHeight() or 120
    local base = (playerHeight / 2) + (size / 2) + 8 + (tonumber(extraBuffDown) or 0)

    local buffCount = math.min(#buffs, SOFT_DISPLAY_MAX)
    local debuffCount = math.min(#debuffs, SOFT_DISPLAY_MAX)
    EnsureIconCount(panel, buffCount + debuffCount, size)
    local totalSlots = #panel.icons

    local next = 1
    for i = 1, buffCount do
        local control = panel.icons[next]
        local row = math.floor((i - 1) / maxPerRow)
        local rowCount = math.min(maxPerRow, buffCount - row * maxPerRow)
        local col = i - row * maxPerRow
        local x = RowXOffset(col, rowCount, step)
        local y = base + row * step
        control:ClearAnchors()
        control:SetAnchor(CENTER, panel, CENTER, x, y)
        next = next + 1
    end

    for i = 1, math.min(debuffCount, math.max(totalSlots - next + 1, 0)) do
        local control = panel.icons[next]
        local row = math.floor((i - 1) / maxPerRow)
        local rowCount = math.min(maxPerRow, debuffCount - row * maxPerRow)
        local col = i - row * maxPerRow
        local x = RowXOffset(col, rowCount, step)
        local y = -base - row * step
        control:ClearAnchors()
        control:SetAnchor(CENTER, panel, CENTER, x, y)
        next = next + 1
    end

    -- Esconde os slots nao usados e preenche cada controle atraves da mesma
    -- rotina de desenho, sem alterar o root do Edit HUD.
    local function Draw(control, data)
        if not control or not data then return end
        control:SetHidden(false)
        if data.icon and data.icon ~= "" then control.icon:SetTexture(data.icon) else control.icon:SetTexture("/esoui/art/icons/icon_missing.dds") end
        control.bg:SetEdgeColor(unpack(COLOR_FRAME))
        control:SetScale(data.important and 1.25 or 1)
        if data.remaining and data.remaining > 0 then
            control.timer:SetText(FormatTime(data.remaining / 1000))
            if control.cooldown and data.duration and data.duration > 0 then
                control.cooldown:StartCooldown(data.remaining, data.duration, CD_TYPE_RADIAL, nil, NO_LEADING_EDGE)
                control.cooldown:SetHidden(false)
            else control.cooldown:SetHidden(true) end
        else
            control.timer:SetText("")
            control.cooldown:SetHidden(true)
        end
        control.count:SetText((data.stacks and data.stacks > 0) and tostring(data.stacks) or "")
        if data.showProgress and data.duration and data.duration > 0 and data.remaining then
            control.progress:SetHidden(false)
            control.progress:SetValue(math.max(0, math.min(1, data.remaining / data.duration)))
        else control.progress:SetHidden(true) end
    end

    next = 1
    for i = 1, buffCount do Draw(panel.icons[next], buffs[i]); next = next + 1 end
    for i = 1, math.min(debuffCount, math.max(totalSlots - next + 1, 0)) do Draw(panel.icons[next], debuffs[i]); next = next + 1 end
    for i = next, #panel.icons do
        local control = panel.icons[i]
        control:SetHidden(true)
        if control.cooldown then control.cooldown:SetHidden(true) end
        if control.progress then control.progress:SetHidden(true) end
    end

    local visible = (buffCount + debuffCount) > 0
    if IsEditHUDShowing() then return end
    if not IsRealHUDShowing() then panel:SetHidden(true) else panel:SetHidden(not visible) end
end

local function LayoutIcons(panel, buffs, horizontal, bottomUp)
    if not panel then return end
    buffs = DeduplicateBuffs(buffs)
    local size = panel.iconSize or DEFAULT_ICON_SIZE
    local step = size + GAP
    local needed = math.min(#buffs, SOFT_DISPLAY_MAX)
    EnsureIconCount(panel, needed, size)
    local visible = math.min(needed, #panel.icons)

    for i = 1, #panel.icons do
        local control = panel.icons[i]
        local data = buffs[i]

        if i <= visible and data then
            if horizontal ~= false then
                local offsetIndex
                if visible % 2 == 1 then
                    if i == 1 then
                        offsetIndex = 0
                    elseif i % 2 == 0 then
                        offsetIndex = i / 2
                    else
                        offsetIndex = -math.floor(i / 2)
                    end
                else
                    local level = math.floor((i - 1) / 2) + 0.5
                    offsetIndex = (i % 2 == 1) and -level or level
                end
                control:ClearAnchors()
                control:SetAnchor(CENTER, panel, CENTER, offsetIndex * step, 0)
            else
                control:ClearAnchors()
                if bottomUp then
                    -- Passive Buffs: primeiro buff fica embaixo e os seguintes sobem.
                    control:SetAnchor(BOTTOM, panel, BOTTOM, 0, -(i - 1) * step)
                else
                    control:SetAnchor(TOP, panel, TOP, 0, (i - 1) * step)
                end
            end
            control:SetHidden(false)

            if data.icon and data.icon ~= "" then
                control.icon:SetTexture(data.icon)
            else
                control.icon:SetTexture("/esoui/art/icons/icon_missing.dds")
            end

            control.bg:SetEdgeColor(unpack(COLOR_FRAME))
            control:SetScale(data.important and 1.25 or 1)

            if data.remaining and data.remaining > 0 then
                control.timer:SetText(FormatTime(data.remaining / 1000))
                if control.cooldown and data.duration and data.duration > 0 then
                    control.cooldown:StartCooldown(data.remaining, data.duration, CD_TYPE_RADIAL, nil, NO_LEADING_EDGE)
                    control.cooldown:SetHidden(false)
                else
                    control.cooldown:SetHidden(true)
                end
            else
                control.timer:SetText("")
                control.cooldown:SetHidden(true)
            end

            control.count:SetText((data.stacks and data.stacks > 0) and tostring(data.stacks) or "")

            if data.showProgress and data.duration and data.duration > 0 and data.remaining then
                control.progress:SetHidden(false)
                control.progress:SetValue(math.max(0, math.min(1, data.remaining / data.duration)))
            else
                control.progress:SetHidden(true)
            end
        else
            control:SetHidden(true)
            if control.cooldown then control.cooldown:SetHidden(true) end
            if control.progress then control.progress:SetHidden(true) end
        end
    end

    -- NAO chamar panel:SetDimensions/SetHeight no root registrado no Edit HUD.
    -- Mudar tamanho do TLC pode invalidar o offset do HUD_MANAGER.

    local canShow = IsRealHUDShowing()
    local inEdit = IsEditHUDShowing()
    if inEdit then
        -- No editor: deixa o HUD_MANAGER controlar visibilidade. Nao tocar.
        return
    end
    if not canShow then
        panel:SetHidden(true)
    else
        panel:SetHidden(visible == 0)
    end
end

local function CollectUnitBuffs(unitTag, opts)
    opts = opts or {}
    local result = {}
    local now = GetGameTimeMilliseconds()
    local minDur = (MinDuration() or 0) * 1000
    local hideOther = opts.hideOther
    local onlyPassives = opts.onlyPassives
    local excludePassives = opts.excludePassives
    local importantOnly = opts.importantOnly
    local customOnly = opts.customOnly
    local s = GetS()
    local showImportantSize = s and s.buffsImportant

    local num = GetNumBuffs(unitTag)
    for i = 1, num do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconTexture,
              buffType, effectType, abilityType, statusEffectType, abilityId,
              canClickOff, castByPlayer = GetUnitBuffInfo(unitTag, i)

        abilityId = tonumber(abilityId)
        if abilityId and not IsBlacklisted(abilityId, buffName) then
            local remaining = (timeEnding or 0) * 1000 - now
            local duration  = ((timeEnding or 0) - (timeStarted or 0)) * 1000
            if remaining < 0 then remaining = 0 end

            local isPermanent = (timeEnding == 0) or (duration <= 0 and remaining <= 0)
            local isPassive = isPermanent or (abilityType == ABILITY_TYPE_PASSIVE)

            local skip = false
            -- Regra do LuiExtended: no alvo, debuffs so aparecem se foram aplicados por voce.
            if unitTag ~= "player" and effectType == BUFF_EFFECT_TYPE_DEBUFF and not castByPlayer
                and (not s or s.luieStyleFilter ~= false) then
                skip = true
            end
            if onlyPassives and not isPassive then skip = true end
            if excludePassives and isPassive then skip = true end
            if customOnly and not IsCustomBuff(abilityId, buffName) then skip = true end
            if not isPassive and not customOnly and remaining > 0 and remaining < minDur and duration < minDur then
                skip = true
            end
            if hideOther and not castByPlayer and unitTag == "player" then
                if not (showImportantSize and IMPORTANT_BUFFS[abilityId]) then
                    skip = true
                end
            end

            local important = showImportantSize and IMPORTANT_BUFFS[abilityId]
            if importantOnly and not (important or IsWidgetBuff(abilityId, buffName)) then
                skip = true
            end

            if not skip then
                table.insert(result, {
                    name = buffName,
                    abilityId = abilityId,
                    icon = iconTexture or GetAbilityIcon(abilityId),
                    remaining = remaining,
                    duration = duration > 0 and duration or remaining,
                    stacks = stackCount or 0,
                    effectType = effectType,
                    castByPlayer = castByPlayer,
                    important = important,
                    passive = isPassive,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        if a.passive ~= b.passive then return not a.passive end
        return (a.remaining or 0) < (b.remaining or 0)
    end)

    return DeduplicateBuffs(result)
end

local function CollectProcBuffs()
    local result = {}
    local now = GetGameTimeMilliseconds()
    for abilityId, state in pairs(specialCooldowns) do
        if state.endsAt and state.endsAt > now then
            local proc = PROC_EFFECTS[abilityId]
            table.insert(result, {
                name = GetAbilityName(abilityId),
                abilityId = abilityId,
                icon = proc and proc.icon or GetAbilityIcon(abilityId),
                remaining = state.endsAt - now,
                duration = (proc and proc.cd or 10) * 1000,
                stacks = 0,
                effectType = state.negative and -1 or 1,
                castByPlayer = true,
                important = false,
                passive = false,
            })
        end
    end
    return result
end

local function CollectSynergyBuffs()
    local result = {}
    local now = GetGameTimeMilliseconds()
    for abilityId, state in pairs(synergyCooldowns) do
        if state.endsAt and state.endsAt > now then
            table.insert(result, {
                name = GetAbilityName(abilityId),
                abilityId = abilityId,
                icon = GetAbilityIcon(abilityId),
                remaining = state.endsAt - now,
                duration = state.duration or (state.endsAt - state.started),
                stacks = 0,
                effectType = 1,
                castByPlayer = true,
                important = false,
                passive = false,
                showProgress = true,
            })
        end
    end
    return result
end

-- Defaults iguais ao NagaHUDCUSTOM / BUI_Buffs.lua
-- Formato: point, relativePoint, offsetX, offsetY (relativo ao GuiRoot)
local ANCHOR_DEFAULTS = {
    player  = { point = CENTER, rel = CENTER, x = 0,   y = 345 },
    target  = { point = CENTER, rel = CENTER, x = 0,   y = -350 },
    passive = { point = BOTTOMRIGHT, rel = BOTTOMRIGHT, x = 0, y = 0 },
    custom  = { point = CENTER, rel = CENTER, x = 0,   y = 300 },
    synergy = { point = CENTER, rel = CENTER, x = -300, y = 200 },
    widgets = { point = CENTER, rel = CENTER, x = 400,  y = 350 },
}


function Buffs:ApplyFixedPositions()
    -- NO-OP. Posicao e 100% do Edit HUD nativo.
    -- Chamar RevertOffsetModifications aqui causa snap-back ao arrastar.
end

function Buffs:SetUnlocked(unlocked)
    -- Movimentacao apenas pelo Edit HUD nativo. Mantido por compatibilidade.
    local s = GetS()
    if s then s.unlocked = false end
    self:UpdateVisibility()
end

function Buffs:IsUnlocked()
    local s = GetS()
    return s and s.unlocked == true
end


function Buffs:UpdateVisibility()
    -- Durante o Edit HUD, nao interferir (senão a caixa volta ao lugar).
    if IsEditHUDShowing() then
        return
    end

    local s = GetS()
    local enabled = s and s.enabled ~= false
    local inHud = IsRealHUDShowing()

    if (not enabled) or (not inHud) then
        for _, panel in pairs(panels) do
            if panel then panel:SetHidden(true) end
        end
        return
    end
    self:Refresh()
end

function Buffs:Refresh()
    -- Nao atualizar durante o Edit HUD (evita snap-back e SetHidden).
    if IsEditHUDShowing() then
        return
    end

    local s = GetS()
    if not s or s.enabled == false or not IsRealHUDShowing() then
        for _, panel in pairs(panels) do
            if panel then panel:SetHidden(true) end
        end
        return
    end

    local unlocked = false

    if s.showPlayer ~= false and panels.player then
        local passivesMode = s.buffsPassives or "On additional panel"
        local list
        if passivesMode == "On one panel" then
            list = CollectUnitBuffs("player", { hideOther = s.buffsOtherHide, excludePassives = false })
        else
            list = CollectUnitBuffs("player", {
                hideOther = s.buffsOtherHide,
                excludePassives = (passivesMode == "On additional panel"),
            })
        end
        local procs = CollectProcBuffs()
        for _, p in ipairs(procs) do table.insert(list, p) end
        list = DeduplicateBuffs(list)
        if s.enableCustomBuffs then
            local filtered = {}
            for _, b in ipairs(list) do
                if not IsCustomBuff(b.abilityId, b.name) then table.insert(filtered, b) end
            end
            list = filtered
        end
        if s.enableWidgets then
            local filtered = {}
            for _, b in ipairs(list) do
                if not IsWidgetBuff(b.abilityId, b.name) then table.insert(filtered, b) end
            end
            list = filtered
        end
        local buffsList, debuffsList = SplitBuffDebuff(list)
        -- Com a barra alternativa (XP/montaria) ligada, ela ja faz parte da altura do HUD:
        -- os buffs ficam abaixo dela, sem folga extra para a barra nativa de montaria.
        local resourceBars = NAGA_UI.ResourceBars
        local altBarOn = resourceBars and resourceBars.IsAltBarEnabled and resourceBars:IsAltBarEnabled()
        local mountedExtra = (not altBarOn and IsMounted and IsMounted()) and MOUNTED_PLAYER_BUFF_EXTRA_GAP or 0
        LayoutBuffDebuffRows(panels.player, buffsList, debuffsList, NAGA_UI.ResourceBars and NAGA_UI.ResourceBars.GetRoot and NAGA_UI.ResourceBars:GetRoot(), mountedExtra)
        if unlocked then panels.player:SetHidden(false) end
    elseif panels.player then
        panels.player:SetHidden(true)
    end

    if s.showPlayer ~= false and s.buffsPassives == "On additional panel" and panels.passive then
        local list = CollectUnitBuffs("player", { onlyPassives = true })
        if s.passiveOakFilter then
            local filtered = {}
            for _, b in ipairs(list) do
                local n = string.lower(b.name or "")
                if not string.find(n, "oakensoul") then table.insert(filtered, b) end
            end
            list = filtered
        end
        LayoutIcons(panels.passive, list, false, true)
        if unlocked then panels.passive:SetHidden(false) end
    elseif panels.passive then
        panels.passive:SetHidden(true)
    end

    if s.showTarget ~= false and panels.target then
        if DoesUnitExist("reticleover") then
            local list = CollectUnitBuffs("reticleover", {})
            local buffsList, debuffsList = SplitBuffDebuff(list)
            LayoutBuffDebuffRows(panels.target, buffsList, debuffsList, NAGA_UI.TargetFrame and NAGA_UI.TargetFrame.GetRoot and NAGA_UI.TargetFrame:GetRoot())
            if unlocked then panels.target:SetHidden(false) end
        else
            panels.target:SetHidden(true)
        end
    elseif panels.target then
        panels.target:SetHidden(true)
    end

    if s.enableCustomBuffs and panels.custom then
        local list = CollectUnitBuffs("player", { customOnly = true })
        local dir = s.customBuffsDirection or "vertical"
        LayoutIcons(panels.custom, list, dir ~= "vertical")
        if unlocked then panels.custom:SetHidden(false) end
    elseif panels.custom then
        panels.custom:SetHidden(true)
    end

    if s.enableSynergyCd and panels.synergy then
        local list = CollectSynergyBuffs()
        local dir = s.synergyCdDirection or "vertical"
        LayoutIcons(panels.synergy, list, dir ~= "vertical")
        if unlocked then panels.synergy:SetHidden(false) end
    elseif panels.synergy then
        panels.synergy:SetHidden(true)
    end

    if s.enableWidgets and panels.widgets then
        local list = CollectUnitBuffs("player", { importantOnly = true })
        local all = CollectUnitBuffs("player", {})
        local seen = {}
        for _, b in ipairs(list) do seen[b.abilityId] = true end
        for _, b in ipairs(all) do
            if IsWidgetBuff(b.abilityId, b.name) and not seen[b.abilityId] then
                table.insert(list, b)
                seen[b.abilityId] = true
            end
        end
        LayoutIcons(panels.widgets, list, false)
        if unlocked then panels.widgets:SetHidden(false) end
    elseif panels.widgets then
        panels.widgets:SetHidden(true)
    end
end

function Buffs:RebuildPanels()
    local s = GetS() or {}
    if not panels.player then
        panels.player = CreatePanel("player", PLAYER_MAX, IconSize("player"))
    else
        ResizePanelIcons(panels.player, IconSize("player"))
    end
    if not panels.target then
        panels.target = CreatePanel("target", TARGET_MAX, IconSize("target"))
    else
        ResizePanelIcons(panels.target, IconSize("target"))
    end
    if not panels.passive then
        panels.passive = CreatePanel("passive", PASSIVE_MAX, IconSize("passive"))
    else
        ResizePanelIcons(panels.passive, IconSize("passive"))
    end
    if not panels.custom then
        panels.custom = CreatePanel("custom", CUSTOM_MAX, IconSize("custom"))
    else
        ResizePanelIcons(panels.custom, IconSize("custom"))
    end
    if not panels.synergy then
        panels.synergy = CreatePanel("synergy", SYNERGY_MAX, IconSize("synergy"))
    else
        ResizePanelIcons(panels.synergy, IconSize("synergy"))
    end
    if not panels.widgets then
        panels.widgets = CreatePanel("widgets", WIDGET_MAX, IconSize("widgets"))
    else
        ResizePanelIcons(panels.widgets, IconSize("widgets"))
    end
    ApplyFollowAnchors()
    self:SetUnlocked(false)
    self:Refresh()

    -- Apenas registra no Edit HUD (sem restaurar posicao em loop).
    if NAGA_UI.MasterMover and NAGA_UI.MasterMover.RegisterAll then
        zo_callLater(function()
            NAGA_UI.MasterMover:RegisterAll()
        end, 300)
    end
end

function Buffs:SetEnabled(enabled)
    local s = GetS()
    if s then s.enabled = enabled == true end
    self:UpdateVisibility()
end


function Buffs:Initialize()
    if initialized then
        self:RebuildPanels()
        return
    end
    initialized = true
    self:RebuildPanels()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_NagaBuffsPositionActivated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function()
            if NAGA_UI.MasterMover and NAGA_UI.MasterMover.RegisterAll then
                NAGA_UI.MasterMover:RegisterAll()
            end
            Buffs:Refresh()
        end, 500)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_NagaBuffsCombat", EVENT_COMBAT_EVENT, function(_, result, isError, _, _, _, sourceName, _, _, _, _, _, _, _, _, _, _, abilityId)
        if isError then return end
        abilityId = tonumber(abilityId)
        if not abilityId then return end
        -- result is already filtered to ACTION_RESULT_EFFECT_GAINED via AddFilterForEvent
        local proc = PROC_EFFECTS[abilityId]
        if proc then
            local now = GetGameTimeMilliseconds()
            specialCooldowns[abilityId] = {
                started = now,
                endsAt = now + (proc.cd * 1000),
                negative = proc.negative,
            }
            Buffs:Refresh()
        end
        if SYNERGY_IDS[abilityId] then
            local now = GetGameTimeMilliseconds()
            synergyCooldowns[abilityId] = {
                started = now,
                endsAt = now + 20000,
                duration = 20000,
            }
            Buffs:Refresh()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_NagaBuffsCombat", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_NagaBuffsActivated", EVENT_PLAYER_ACTIVATED, function()
        Buffs:UpdateVisibility()
    end)

    if SCENE_MANAGER then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            zo_callLater(function() Buffs:UpdateVisibility() end, 0)
        end)
        -- Alguns menus do ESO usam fragments; revalida com frequencia baixa.
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_NagaBuffsHudCheck", 150, function()
            Buffs:UpdateVisibility()
        end)
    end
    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", function() Buffs:UpdateVisibility() end)
    end
    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", function() Buffs:UpdateVisibility() end)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_NagaBuffsEffectChanged", EVENT_EFFECT_CHANGED, function()
        Buffs:UpdateVisibility()
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_NagaBuffsTargetChanged", EVENT_RETICLE_TARGET_CHANGED, function()
        Buffs:Refresh()
    end)

    zo_callLater(function() Buffs:UpdateVisibility() end, 500)
    EVENT_MANAGER:RegisterForUpdate(tickerId, UPDATE_MS, function() Buffs:Refresh() end)
end

function Buffs:SetHidden(hidden)
    for _, panel in pairs(panels) do
        if panel then panel:SetHidden(hidden) end
    end
end


-- Auto-init (não depende mais do AbyssUI.lua)
NAGA_UI.OnAddonLoaded(function()
    zo_callLater(function()
        if NAGA_UI and NAGA_UI.Buffs and NAGA_UI.Buffs.Initialize then
            NAGA_UI.Buffs:Initialize()
        end
    end, 0)
end)
