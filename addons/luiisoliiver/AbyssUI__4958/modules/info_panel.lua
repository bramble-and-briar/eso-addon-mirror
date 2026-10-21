NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

-- =============================================================================
--  N A G A Info Painel  v1.1
--  Painel de informações personalizável (UI criada em Lua, sem XML)
-- =============================================================================

NAGAInfoPainel = NAGAInfoPainel or {}
local NAGA = NAGAInfoPainel

NAGA.name        = "NAGAInfoPainel"
NAGA.displayName = "N A G A Info Painel"
NAGA.version     = "1.5.2"
NAGA.author      = "NAGA"

local EM = GetEventManager()
local SM = SCENE_MANAGER

-- -----------------------------------------------------------------------------
-- Defaults / SavedVars
-- -----------------------------------------------------------------------------
NAGA.Defaults = {
    enabled            = true,
    panelScale         = 100,
    transparency       = 100,
    HideInCombat       = false,
    DisableInfoColours = false,
    TextBlackOutline   = true,
    ClockFormat        = "HH:MM:SS",
    FontFace           = "ZoFontGame",
    FontSize           = 16,
    IconSize           = 20,
    -- elementos (false = mostrar)
    HideLatency  = false,
    HideFPS      = false,
    HideMemory   = false,
    HideClock    = false,
    HideGems     = false,
    HideMount    = false,
    HideArmour   = false,
    HideWeapons  = false,
    HideBags     = false,
    HideGold     = false,
    -- Position is owned by ESO Edit HUD; no legacy coordinate is stored here.
}

-- Fontes disponíveis (dropdown)
NAGA.FontList = {
    "ZoFontGame",
    "ZoFontGameBold",
    "ZoFontGameOutline",
    "ZoFontGameShadow",
    "ZoFontGameSmall",
    "ZoFontChat",
    "ZoFontChatBold",
    "ZoFontWindowTitle",
    "ZoFontHeader",
    "ZoFontHeader2",
    "ZoFontHeader3",
    "ZoFontCallout3",
    "ZoFontBookPaper",
    "ZoFontTooltipTitle",
}

NAGA.SV = {}
NAGA.panelUnlocked = false

-- -----------------------------------------------------------------------------
-- Cores
-- -----------------------------------------------------------------------------
local C = {
    RED    = {1, 0, 0, 1},
    GREEN  = {0, 1, 0, 1},
    YELLOW = {1, 1, 0, 1},
    WHITE  = {1, 1, 1, 1},
    GOLD   = {0.85, 0.7, 0.1, 1},
}

local function SetLabelColor(label, colorTable)
    if label and colorTable then
        label:SetColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
    end
end

-- -----------------------------------------------------------------------------
-- UI refs
-- -----------------------------------------------------------------------------
local panel      -- TopLevelControl
local divider
local topRow
local botRow
local elements = {} -- [id] = { control, icon, label, row = "top"|"bot" }

local UPDATE_TAG = "NAGAInfoPainel_Update"
local panelHiddenByCombat = false
local panelHiddenByMenu = false

-- -----------------------------------------------------------------------------
-- Helpers de criação de UI
-- -----------------------------------------------------------------------------
local function CreateIconLabel(parent, name, iconPath, iconSize, labelWidth, defaultText)
    local holder = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    holder:SetDimensions(iconSize + 4 + labelWidth, 22)

    local icon = WINDOW_MANAGER:CreateControl(name .. "_Icon", holder, CT_TEXTURE)
    icon:SetDimensions(iconSize, iconSize)
    icon:SetAnchor(LEFT, holder, LEFT, 0, 0)
    if iconPath and iconPath ~= "" then
        icon:SetTexture(iconPath)
    end
    icon:SetHidden(false)

    local label = WINDOW_MANAGER:CreateControl(name .. "_Label", holder, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(1, 1, 1, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetDimensions(labelWidth, 20)
    label:SetAnchor(LEFT, icon, RIGHT, 4, 0)
    label:SetText(defaultText or "")
    -- sem corte / sem "..."
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)

    return holder, icon, label
end

local function CreatePlainLabel(parent, name, width, defaultText)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(1, 1, 1, 1)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetDimensions(width, 20)
    label:SetText(defaultText or "")
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    return label
end

-- Ajusta largura do label (e do holder se tiver ícone) para o texto caber inteiro
local function FitText(el, text)
    if not el or not el.label then return end
    -- largura temporária grande para não truncar na medição
    el.label:SetWidth(400)
    el.label:SetText(text)
    local tw = el.label:GetTextWidth() or 40
    if tw < 24 then tw = 24 end
    tw = zo_ceil(tw) + 8
    el.label:SetWidth(tw)
    if el.hasIcon and el.icon and el.control then
        local iconW = el.icon:GetWidth() or (NAGA.SV.IconSize or 20)
        el.control:SetWidth(iconW + 4 + tw)
        el.control:SetHeight(math.max(iconW, 22))
    end
end

local function BuildUI()
    if panel then return end

    local wm = WINDOW_MANAGER

    panel = _G["NAGA_InfoPanel"] or wm:CreateTopLevelWindow("NAGA_InfoPanel")
    panel:SetDimensions(10, 48)
    panel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -24, 20)
    panel:SetClampedToScreen(true)
    panel:SetMouseEnabled(true)
    panel:SetMovable(true)
    panel:SetHidden(true)
    -- O painel precisa ficar acima do HUD para que textos/ícones não fiquem
    -- atrás de outras camadas do ESO.
    panel:SetDrawLayer(DL_OVERLAY)
    panel:SetDrawTier(DT_HIGH)

    divider = wm:CreateControl("NAGA_InfoPanel_Divider", panel, CT_TEXTURE)
    divider:SetTexture("/esoui/art/miscellaneous/horizontaldivider.dds")
    divider:SetHeight(4)
    divider:SetAnchor(LEFT, panel, LEFT, -40, 0)
    divider:SetAnchor(RIGHT, panel, RIGHT, 40, 0)

    topRow = wm:CreateControl("NAGA_InfoPanel_TopRow", panel, CT_CONTROL)
    topRow:SetDimensions(300, 24)
    topRow:SetAnchor(TOP, panel, TOP, 0, 2)

    botRow = wm:CreateControl("NAGA_InfoPanel_BotRow", panel, CT_CONTROL)
    botRow:SetDimensions(300, 24)
    botRow:SetAnchor(BOTTOM, panel, BOTTOM, 0, -2)

    -- Top elements
    local h, ic, lb

    h, ic, lb = CreateIconLabel(topRow, "NAGA_IP_Latency", "/esoui/art/campaign/campaignbrowser_hipop.dds", 20, 64, "0 MS")
    elements.latency = { control = h, icon = ic, label = lb, row = "top", labelWidth = 64, hasIcon = true }

    lb = CreatePlainLabel(topRow, "NAGA_IP_Fps", 64, "0 FPS")
    elements.fps = { control = lb, label = lb, row = "top" }

    lb = CreatePlainLabel(topRow, "NAGA_IP_Memory", 56, "0M")
    elements.memory = { control = lb, label = lb, row = "top" }

    lb = CreatePlainLabel(topRow, "NAGA_IP_Clock", 80, "00:00:00")
    elements.clock = { control = lb, label = lb, row = "top" }

    -- Soul gems: só contagem do inventário do personagem
    h, ic, lb = CreateIconLabel(topRow, "NAGA_IP_Gems", "/esoui/art/icons/soulgem_001_empty.dds", 20, 48, "0")
    elements.gems = { control = h, icon = ic, label = lb, row = "top", labelWidth = 64, hasIcon = true }

    -- Bottom elements
    h, ic, lb = CreateIconLabel(botRow, "NAGA_IP_Mount", "EsoUI/Art/Mounts/tabIcon_mounts_up.dds", 20, 64, "--")
    elements.mount = { control = h, icon = ic, label = lb, row = "bot", labelWidth = 64, hasIcon = true }

    h, ic, lb = CreateIconLabel(botRow, "NAGA_IP_Armour", "/esoui/art/progression/progression_indexicon_armor_up.dds", 20, 36, "100%")
    elements.armour = { control = h, icon = ic, label = lb, row = "bot", labelWidth = 36, hasIcon = true }

    -- Ícone de espada/armas (tab de inventário — uma arma clara)
    h, ic, lb = CreateIconLabel(botRow, "NAGA_IP_Weapons", "/esoui/art/inventory/inventory_tabicon_weapons_up.dds", 20, 36, "100%")
    elements.weapons = { control = h, icon = ic, label = lb, row = "bot", labelWidth = 36, hasIcon = true }

    h, ic, lb = CreateIconLabel(botRow, "NAGA_IP_Bags", "EsoUI/Art/Inventory/inventory_tabIcon_misc_up.dds", 20, 48, "0/0")
    elements.bags = { control = h, icon = ic, label = lb, row = "bot", labelWidth = 64, hasIcon = true }

    h, ic, lb = CreateIconLabel(botRow, "NAGA_IP_Gold", "", 20, 70, "0")
    elements.gold = { control = h, icon = ic, label = lb, row = "bot", labelWidth = 70, hasIcon = true }
    if ZO_Currency_GetKeyboardCurrencyIcon then
        local tex = ZO_Currency_GetKeyboardCurrencyIcon(CURT_MONEY)
        if tex then ic:SetTexture(tex) end
    else
        ic:SetTexture("/esoui/art/currency/currency_gold.dds")
    end
    SetLabelColor(lb, C.GOLD)
end

-- -----------------------------------------------------------------------------
-- Layout
-- -----------------------------------------------------------------------------
local hideKey = {
    latency = "HideLatency",
    fps     = "HideFPS",
    memory  = "HideMemory",
    clock   = "HideClock",
    gems    = "HideGems",
    mount   = "HideMount",
    armour  = "HideArmour",
    weapons = "HideWeapons",
    bags     = "HideBags",
    gold     = "HideGold",
}

local topOrder = { "latency", "fps", "memory", "clock", "gems" }
local botOrder = { "mount", "armour", "weapons", "bags", "gold" }

local function Rearrange()
    if not panel then return end
    local gap = 8

    local function layoutRow(rowCtrl, order)
        local x = 0
        for _, id in ipairs(order) do
            local el = elements[id]
            if not el or not el.control then
                -- skip
            elseif NAGA.SV[hideKey[id]] then
                el.control:SetHidden(true)
            else
                el.control:SetHidden(false)
                el.control:ClearAnchors()
                el.control:SetAnchor(LEFT, rowCtrl, LEFT, x, 0)
                x = x + el.control:GetWidth() + gap
            end
        end
        local w = math.max(x - gap, 10)
        rowCtrl:SetWidth(w)
        return w
    end

    local tw = layoutRow(topRow, topOrder)
    local bw = layoutRow(botRow, botOrder)
    local pw = math.max(tw, bw, 10)
    panel:SetWidth(pw)

    topRow:ClearAnchors()
    topRow:SetAnchor(TOP, panel, TOP, 0, 2)
    botRow:ClearAnchors()
    botRow:SetAnchor(BOTTOM, panel, BOTTOM, 0, -2)
end

function NAGA.RearrangePanel()
    Rearrange()
    NAGA.UpdateAll()
end

-- -----------------------------------------------------------------------------
-- Updates de cada elemento
-- -----------------------------------------------------------------------------
local function UpdateLatency()
    local el = elements.latency
    if not el or NAGA.SV.HideLatency or not el.label then return end
    local ms = GetLatency() or 0
    FitText(el, string.format("%d MS", ms))
    if NAGA.SV.DisableInfoColours then
        SetLabelColor(el.label, C.WHITE)
    elseif ms <= 100 then
        SetLabelColor(el.label, C.GREEN)
    elseif ms <= 200 then
        SetLabelColor(el.label, C.YELLOW)
    else
        SetLabelColor(el.label, C.RED)
    end
end

local function UpdateFPS()
    local el = elements.fps
    if not el or NAGA.SV.HideFPS or not el.label then return end
    local fps = GetFramerate() or 0
    FitText(el, string.format("%d FPS", zo_floor(fps + 0.5)))
    if NAGA.SV.DisableInfoColours then
        SetLabelColor(el.label, C.WHITE)
    elseif fps <= 25 then
        SetLabelColor(el.label, C.RED)
    elseif fps <= 40 then
        SetLabelColor(el.label, C.YELLOW)
    else
        SetLabelColor(el.label, C.GREEN)
    end
end

local function UpdateMemory()
    local el = elements.memory
    if not el or NAGA.SV.HideMemory or not el.label then return end
    local mb = collectgarbage("count") / 1024
    local text = (mb >= 100) and string.format("%.0fM", mb) or string.format("%.1fM", mb)
    FitText(el, text)
    if NAGA.SV.DisableInfoColours then
        SetLabelColor(el.label, C.WHITE)
    elseif mb >= 90 then
        SetLabelColor(el.label, C.RED)
    elseif mb >= 70 then
        SetLabelColor(el.label, C.YELLOW)
    else
        SetLabelColor(el.label, C.GREEN)
    end
end

local function UpdateClock()
    local el = elements.clock
    if not el or NAGA.SV.HideClock or not el.label then return end
    local t = GetTimeString() or "00:00:00"
    local fmt = NAGA.SV.ClockFormat or "HH:MM:SS"
    if fmt == "HH:MM" or fmt == "H:m" then
        t = string.sub(t, 1, 5)
    end
    FitText(el, t)
end

local function UpdateGems()
    local el = elements.gems
    if not el or NAGA.SV.HideGems or not el.label then return end
    -- Apenas soul gems CHEIAS no inventário do personagem atual (backpack)
    local level = GetUnitEffectiveLevel("player") or GetUnitLevel("player") or 1
    local _, iconFull, fullCount = GetSoulGemInfo(SOUL_GEM_TYPE_FILLED, level, true)
    fullCount = fullCount or 0
    -- só o número do inventário atual (sem vazias / sem total)
    local text = tostring(fullCount)
    if fullCount > 0 then
        FitText(el, "|c00FF00" .. text .. "|r")
    else
        FitText(el, "|cFF0000" .. text .. "|r")
    end
    local icon = iconFull
    if not icon or icon == "" or icon == "/esoui/art/icons/icon_missing.dds" then
        icon = "/esoui/art/icons/soulgem_001_empty.dds"
    end
    if el.icon then
        el.icon:SetTexture(icon)
    end
end

local function UpdateMount()
    local el = elements.mount
    if not el or NAGA.SV.HideMount or not el.label then return end
    local inventoryBonus, maxInventoryBonus, staminaBonus, maxStaminaBonus, speedBonus, maxSpeedBonus = GetRidingStats()
    local maxed = (inventoryBonus >= maxInventoryBonus)
        and (staminaBonus >= maxStaminaBonus)
        and (speedBonus >= maxSpeedBonus)
    if maxed then
        FitText(el, "MAXED")
        SetLabelColor(el.label, C.GREEN)
        return
    end
    local remain = GetTimeUntilCanBeTrained()
    if not remain or remain <= 0 then
        FitText(el, "TRAIN NOW")
        SetLabelColor(el.label, C.YELLOW)
    else
        local sec = zo_floor(remain / 1000)
        local h = zo_floor(sec / 3600)
        local m = zo_floor((sec % 3600) / 60)
        FitText(el, string.format("%dH %dM", h, m))
        SetLabelColor(el.label, C.WHITE)
    end
end

-- Cores por %: Vermelho <=10 | Amarelo 11-50 | Verde 51+
local function ColorByPercent(label, pct)
    if pct <= 10 then
        SetLabelColor(label, C.RED)
    elseif pct <= 50 then
        SetLabelColor(label, C.YELLOW)
    else
        SetLabelColor(label, C.GREEN)
    end
end

-- Todos os slots de armadura (corpo) — média precisa de tudo que está equipado
local ARMOR_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_HANDS,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
}

local function UpdateArmour()
    local el = elements.armour
    if not el or NAGA.SV.HideArmour or not el.label then return end
    local total, count = 0, 0
    for i = 1, #ARMOR_SLOTS do
        local slot = ARMOR_SLOTS[i]
        -- só conta se há item equipado nesse slot
        local hasItem = GetItemLink and GetItemLink(BAG_WORN, slot)
        if hasItem and hasItem ~= "" then
            local cond = GetItemCondition(BAG_WORN, slot)
            if cond ~= nil then
                total = total + cond
                count = count + 1
            end
        elseif DoesItemExist and DoesItemExist(BAG_WORN, slot) then
            local cond = GetItemCondition(BAG_WORN, slot)
            if cond ~= nil then
                total = total + cond
                count = count + 1
            end
        else
            -- fallback: se condition > 0 considera equipado
            local cond = GetItemCondition(BAG_WORN, slot)
            if cond and cond > 0 then
                total = total + cond
                count = count + 1
            end
        end
    end
    local pct = (count > 0) and zo_floor((total / count) + 0.5) or 100
    FitText(el, string.format("%d%%", pct))
    ColorByPercent(el.label, pct)
end

-- Ícones de arma
local ICON_WEAPON_SINGLE = "/esoui/art/inventory/inventory_tabicon_weapons_up.dds"
local ICON_WEAPON_DUAL   = "/esoui/art/progression/icon_dualwield.dds"

-- Só conta se o slot tem uma ARMA de verdade (não escudo / vazio)
local function SlotIsWeapon(slot)
    local itemType = GetItemType(BAG_WORN, slot)
    if itemType == ITEMTYPE_WEAPON then
        return true
    end
    if GetItemWeaponType then
        local wt = GetItemWeaponType(BAG_WORN, slot)
        if wt and wt ~= WEAPONTYPE_NONE and wt ~= WEAPONTYPE_SHIELD then
            return true
        end
    end
    return false
end

-- charges, max, isWeapon
local function GetSlotCharges(slot)
    if not SlotIsWeapon(slot) then
        return 0, 0, false
    end
    local ch, mx = GetChargeInfoForItem(BAG_WORN, slot)
    ch = ch or 0
    mx = mx or 0
    if mx > 0 then
        return ch, mx, true
    end
    -- arma sem encantamento → 100%
    return 1, 1, true
end

local function UpdateWeapons()
    local el = elements.weapons
    if not el or NAGA.SV.HideWeapons or not el.label then return end

    -- Barra ativa: MAIN/OFF mudam ao trocar primária <-> secundária
    local ch1, mx1, hasMain = GetSlotCharges(EQUIP_SLOT_MAIN_HAND)
    local ch2, mx2, hasOff  = GetSlotCharges(EQUIP_SLOT_OFF_HAND)

    local totalCh, totalMx, weaponCount = 0, 0, 0
    if hasMain then
        totalCh = totalCh + ch1
        totalMx = totalMx + mx1
        weaponCount = weaponCount + 1
    end
    if hasOff then
        totalCh = totalCh + ch2
        totalMx = totalMx + mx2
        weaponCount = weaponCount + 1
    end

    -- Uma % só: unifica as 2 armas (soma das cargas / soma do máximo)
    local pct = 100
    if totalMx > 0 then
        pct = zo_floor((totalCh / totalMx) * 100 + 0.5)
    end

    if el.icon then
        if weaponCount >= 2 then
            el.icon:SetTexture(ICON_WEAPON_DUAL)
        else
            el.icon:SetTexture(ICON_WEAPON_SINGLE)
        end
    end

    FitText(el, string.format("%d%%", pct))
    ColorByPercent(el.label, pct)
end

local function UpdateBags()
    local el = elements.bags
    if not el or NAGA.SV.HideBags or not el.label then return end
    local used = GetNumBagUsedSlots(BAG_BACKPACK) or 0
    local size = GetBagSize(BAG_BACKPACK) or 0
    FitText(el, string.format("%d/%d", used, size))
    local fill = (size > 0) and ((used / size) * 100) or 0
    if fill >= 90 then
        SetLabelColor(el.label, C.RED)
    elseif fill >= 70 then
        SetLabelColor(el.label, C.YELLOW)
    else
        SetLabelColor(el.label, C.WHITE)
    end
end

local function UpdateGold()
    local el = elements.gold
    if not el or NAGA.SV.HideGold or not el.label then return end
    local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
    local text = ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(gold) or tostring(gold)
    FitText(el, text)
    SetLabelColor(el.label, C.GOLD)
end

function NAGA.UpdateAll()
    if not NAGA.SV.enabled or not panel then return end
    -- pcall evita que um elemento quebre o painel inteiro
    pcall(UpdateLatency)
    pcall(UpdateFPS)
    pcall(UpdateMemory)
    pcall(UpdateClock)
    pcall(UpdateGems)
    pcall(UpdateMount)
    pcall(UpdateArmour)
    pcall(UpdateWeapons)
    pcall(UpdateBags)
    pcall(UpdateGold)
    -- reorganiza após ajustar larguras dos textos
    pcall(Rearrange)
end

-- -----------------------------------------------------------------------------
-- Visual helpers
-- -----------------------------------------------------------------------------
local function ApplyScale()
    if panel then
        panel:SetScale((NAGA.SV.panelScale or 100) / 100)
    end
end

local function ApplyAlpha()
    if panel then
        panel:SetAlpha((NAGA.SV.transparency or 100) / 100)
    end
end

-- Aplica a fonte escolhida em todos os labels.
-- Os nomes ZoFont* são aliases de fontes prontas; para permitir que o
-- tamanho do slider realmente seja aplicado, convertemos o alias para o
-- arquivo de fonte base e montamos a string de fonte explicitamente.
local FONT_FACES = {
    ZoFontGame       = "EsoUI/Common/Fonts/Univers57.slug",
    ZoFontGameBold   = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontGameOutline= "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontGameShadow = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontGameSmall  = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontChat       = "EsoUI/Common/Fonts/Univers57.slug",
    ZoFontChatBold   = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontWindowTitle= "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontHeader     = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontHeader2    = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontHeader3    = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontCallout3   = "EsoUI/Common/Fonts/Univers67.slug",
    ZoFontBookPaper  = "EsoUI/Common/Fonts/ProseAntiquePSMT.slug",
    ZoFontTooltipTitle = "EsoUI/Common/Fonts/Univers67.slug",
}

local function ApplyFont()
    local face = NAGA.SV.FontFace or "ZoFontGame"
    local size = tonumber(NAGA.SV.FontSize) or 16
    local fontFace = FONT_FACES[face] or FONT_FACES.ZoFontGame
    local outline = NAGA.SV.TextBlackOutline ~= false and "thick-outline" or "soft-shadow-thin"
    local fontString = string.format("%s|%d|%s", fontFace, size, outline)
    for _, el in pairs(elements) do
        if el and el.label then
            el.label:SetFont(fontString)
        end
    end
end

function NAGA.ApplyFont()
    ApplyFont()
    Rearrange()
end

local function ApplyIconSize()
    local size = NAGA.SV.IconSize or 20
    for _, el in pairs(elements) do
        if el and el.hasIcon and el.icon then
            el.icon:SetDimensions(size, size)
            local lw = el.labelWidth or (el.label and el.label:GetWidth()) or 40
            if el.label then
                -- mantém label; control = icon + gap + label
                local labelW = el.label:GetWidth()
                if labelW < 1 then labelW = lw end
                el.control:SetWidth(size + 4 + labelW)
                el.control:SetHeight(math.max(size, 22))
            end
        end
    end
end

function NAGA.ApplyIconSize()
    ApplyIconSize()
    Rearrange()
    NAGA.UpdateAll()
end

local function RestorePosition()
    -- ESO Update 51+ Edit HUD owns the position.
    return
end

function NAGA.ResetPosition()
    -- Never write a legacy coordinate that could fight the native Edit HUD.
    NAGA.SV.position = nil
end



local function RemovePanelFragmentFromScenes()
    if not NAGA.panelFragment or not SM then return end
    local scenes = { "hud", "hudui", "siegeBar", "siegeBarUI" }
    for _, name in ipairs(scenes) do
        local scene = SM:GetScene(name)
        if scene and scene.RemoveFragment then
            scene:RemoveFragment(NAGA.panelFragment)
        end
    end
end

-- Forward declaration: SetEnabled() can be called by Settings.lua before the
-- menu-visibility helper is reached later in this file.
local UpdateMenuVisibility

function NAGA.SetEnabled(enabled)
    NAGA.SV.enabled = enabled and true or false
    if not panel then return end
    if NAGA.SV.enabled then
        panel:SetHidden(false)
        panel:SetDrawLayer(DL_OVERLAY)
        panel:SetDrawTier(DT_HIGH)
        Rearrange()
        NAGA.UpdateAll()
        panel:SetHidden(false)
        UpdateMenuVisibility()
        EM:RegisterForUpdate(UPDATE_TAG, 1000, NAGA.UpdateAll)
    else
        -- Força esconder: remove do HUD e para updates
        RemovePanelFragmentFromScenes()
        panel:SetHidden(true)
        EM:UnregisterForUpdate(UPDATE_TAG)
    end
end

function NAGA.ApplyScale()
    ApplyScale()
end

function NAGA.ApplyAlpha()
    ApplyAlpha()
end

-- -----------------------------------------------------------------------------
-- Combat hide
-- -----------------------------------------------------------------------------
local function OnCombatState(_, inCombat)
    if not NAGA.SV.HideInCombat or not panel then return end
    if inCombat then
        panelHiddenByCombat = true
        panel:SetHidden(true)
    else
        if panelHiddenByCombat then
            panelHiddenByCombat = false
            if NAGA.SV.enabled and not panelHiddenByMenu then
                panel:SetHidden(false)
            end
        end
    end
end


-- -----------------------------------------------------------------------------
-- Esconde o Info Panel sempre que o HUD sai de cena para abrir qualquer menu.
-- O Scene Manager avisa quando HUD/HUDUI mudam de estado; enquanto nenhum dos
-- dois estiver visível, estamos fora da tela de jogo e o painel deve sumir.
-- -----------------------------------------------------------------------------
UpdateMenuVisibility = function()
    if not panel or not NAGA.SV then return end

    local hud = SM and SM:GetScene("hud")
    local hudui = SM and SM:GetScene("hudui")
    local hudVisible = (hud and hud:IsShowing()) or (hudui and hudui:IsShowing())

    if hudVisible then
        panelHiddenByMenu = false
        if NAGA.SV.enabled and not panelHiddenByCombat then
            panel:SetHidden(false)
        end
    else
        panelHiddenByMenu = true
        panel:SetHidden(true)
    end
end

local function RegisterMenuVisibilityCallbacks()
    if not SM or NAGA.menuVisibilityCallbacksRegistered then return end

    local hud = SM:GetScene("hud")
    local hudui = SM:GetScene("hudui")

    local function OnHudSceneStateChanged()
        UpdateMenuVisibility()
    end

    if hud then
        hud:RegisterCallback("StateChange", OnHudSceneStateChanged)
    end
    if hudui then
        hudui:RegisterCallback("StateChange", OnHudSceneStateChanged)
    end

    NAGA.menuVisibilityCallbacksRegistered = true
end





-- -----------------------------------------------------------------------------
-- Native Edit HUD
-- -----------------------------------------------------------------------------
local function RegisterNativeEditHUD()
    if not panel or NAGA.hudManaged then return NAGA.hudManaged end
    if not HUD_MANAGER or not ZO_Anchor then return false end

    local ok = pcall(function()
        local opts = { defaultAnchor = ZO_Anchor:New(TOPRIGHT, nil, TOPRIGHT, -24, 20) }
        HUD_MANAGER:RegisterKeyboardElement(panel, "NAGA Info Panel", opts, COMPASS_OPTIONS)
        HUD_MANAGER:RegisterGamepadElement(panel, "NAGA Info Panel", opts, COMPASS_OPTIONS)
    end)

    if ok then
        NAGA.hudManaged = true
            panel.nagaNativeEditHUDName = "NAGA Info Panel"
        return true
    end
    return false
end

local function EnsureNativeEditHUD()
    if RegisterNativeEditHUD() then return end
    if not NAGA.nativeRetryScheduled then
        NAGA.nativeRetryScheduled = true
        zo_callLater(function()
            NAGA.nativeRetryScheduled = false
            RegisterNativeEditHUD()
            if not NAGA.hudManaged then
                zo_callLater(RegisterNativeEditHUD, 1000)
            end
        end, 250)
    end
end

-- -----------------------------------------------------------------------------
-- Init (embedded in NAGA Modules)
-- -----------------------------------------------------------------------------
function NAGA.Initialize()
    if NAGA.initialized then return true end

    local settings = NAGA_UI and NAGA_UI.Settings
    if not settings or not settings.GetInfoPanel then
        return false
    end

    NAGA.SV = settings:GetInfoPanel()
    NAGA.initialized = true

    BuildUI()
    RegisterMenuVisibilityCallbacks()
    EnsureNativeEditHUD()
    ApplyScale()
    ApplyAlpha()
    ApplyFont()
    ApplyIconSize()
    Rearrange()

    if NAGA.SV.enabled then
        panel:SetDrawLayer(DL_OVERLAY)
        panel:SetDrawTier(DT_HIGH)
        panel:SetHidden(false)
        Rearrange()
        NAGA.UpdateAll()
        UpdateMenuVisibility()
        EM:RegisterForUpdate(UPDATE_TAG, 1000, NAGA.UpdateAll)
    else
        panel:SetHidden(true)
    end

    EM:RegisterForEvent(NAGA.name .. "_Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EM:RegisterForEvent(NAGA.name .. "Inv", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        UpdateBags()
        UpdateArmour()
        UpdateWeapons()
        UpdateGems()
    end)
    EM:RegisterForEvent(NAGA.name .. "Weap", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, UpdateWeapons)
    EM:RegisterForEvent(NAGA.name .. "Gold", EVENT_MONEY_UPDATE, UpdateGold)
    EM:RegisterForEvent(NAGA.name .. "Carry", EVENT_CARRIED_CURRENCY_UPDATE, function(_, currency)
        if currency == CURT_MONEY then UpdateGold() end
    end)
    EM:RegisterForEvent(NAGA.name .. "Mount", EVENT_RIDING_SKILL_IMPROVEMENT, UpdateMount)
    EM:RegisterForEvent(NAGA.name .. "BagCap", EVENT_INVENTORY_BAG_CAPACITY_CHANGED, UpdateBags)

    return true
end

-- Slash commands
-- -----------------------------------------------------------------------------
SLASH_COMMANDS["/nagaip"] = function(args)
    args = zo_strlower(args or "")
    if args == "show" then
        NAGA.SetEnabled(true)
        d("|cB0B0FF[N A G A Info Painel]|r Painel ativado.")
    elseif args == "hide" then
        NAGA.SetEnabled(false)
        d("|cB0B0FF[N A G A Info Painel]|r Painel desativado.")
    elseif args == "reset" then
        NAGA.ResetPosition()
        d("|cB0B0FF[N A G A Info Painel]|r A posição é controlada pelo Edit HUD do ESO.")
    else
        d("|cB0B0FF[N A G A Info Painel]|r /nagaip show | hide | reset")
    end
end


-- Auto-init (não depende mais do AbyssUI.lua)
NAGA_UI.OnAddonLoaded(function()
    zo_callLater(function()
        if NAGAInfoPainel and NAGAInfoPainel.Initialize then
            NAGAInfoPainel.Initialize()
        elseif NAGA and NAGA.Initialize then
            NAGA.Initialize()
        end
    end, 200)
end)
