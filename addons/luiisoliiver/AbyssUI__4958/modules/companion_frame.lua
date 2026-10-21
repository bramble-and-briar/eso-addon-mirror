local function T(s)
    if NAGA_UI and NAGA_UI.T then return NAGA_UI.T(s) end
    return s
end

local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_CompanionFrame"
local UNIT_TAG = "companion"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local BarVisuals = NAGA_UI.BarVisuals

local CompanionFrame = {}
NAGA_UI.CompanionFrame = CompanionFrame

local DEFAULTS =
{
    enabled = true,
    width = 220,
    height = 90,
    scale = 100,
    showLevel = true,
    showRapport = true,
    showXP = true,
    showButtons = true,
    opacityIn = 100,
    opacityOut = 70,
    nameFontKey = "esobold",
    valueFontKey = "standard",
    fontSize = 14,
    textOutline = "thick-outline",
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    healthColor = { r = 0.80, g = 0.15, b = 0.15, a = 1 },
    rapportColor = { r = 0.25, g = 0.55, b = 0.95, a = 1 },
    xpColor = { r = 0.25, g = 0.75, b = 0.30, a = 1 },
    trackColor = { r = 0.008, g = 0.009, b = 0.012, a = 0.78 },
    borderColor = { r = 0.20, g = 0.20, b = 0.20, a = 1 },
    roundedBarCorners = true,
    barInset = 2,
    textureKey = "genericTall",
}

local FONT_FACES =
{
    standard = "$(MEDIUM_FONT)",
    esobold = "$(BOLD_FONT)",
    antique = "EsoUI/Common/Fonts/ProseAntiquePSMT.slug",
    handwritten = "EsoUI/Common/Fonts/Handwritten_Bold.slug",
    trajan = "EsoUI/Common/Fonts/TrajanPro-Regular.slug",
    futura = "EsoUI/Common/Fonts/FuturaStd-CondensedLight.slug",
    futurabold = "EsoUI/Common/Fonts/FuturaStd-Condensed.slug",
    univers = "EsoUI/Common/Fonts/Univers57.slug",
    universbold = "EsoUI/Common/Fonts/Univers67.slug",
    gamepad_medium = "EsoUI/Common/Fonts/FTN57.slug",
    gamepad_bold = "EsoUI/Common/Fonts/FTN87.slug",
    chat = "$(CHAT_FONT)",
}

local FONT_CHOICES =
{
    "ESO Standard", "ESO Bold", "Prose Antique", "Handwritten", "Trajan Pro",
    "Futura Standard", "Futura Bold", "Univers 57", "Univers 67",
    "Gamepad Standard", "Gamepad Bold", "Chat",
}

local FONT_VALUES =
{
    "standard", "esobold", "antique", "handwritten", "trajan",
    "futura", "futurabold", "univers", "universbold", "gamepad_medium",
    "gamepad_bold", "chat",
}

local OUTLINE_CHOICES = { "None", "Soft Thin", "Soft Thick", "Thick Outline" }
local OUTLINE_VALUES = { "none", "soft-shadow-thin", "soft-shadow-thick", "thick-outline" }

local TEXTURE_CHOICES = { "Generic Tall", "Generic Arrow", "Gamepad Medium", "Gamepad Large" }
local TEXTURE_VALUES = { "genericTall", "genericArrow", "gamepadMedium", "gamepadLarge" }

local frame
local pickerControl
local pickerButtons = {}
local initialized = false
local hudRegistered = false
local registerRetryScheduled = false
local lastEditorState = false

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then value = fallback or minimum end
    return math.min(math.max(value, minimum), maximum)
end

local function CopyColor(color, fallback)
    color = color or fallback or {}
    fallback = fallback or {}
    return
    {
        r = tonumber(color.r or color[1]) or tonumber(fallback.r or fallback[1]) or 1,
        g = tonumber(color.g or color[2]) or tonumber(fallback.g or fallback[2]) or 1,
        b = tonumber(color.b or color[3]) or tonumber(fallback.b or fallback[3]) or 1,
        a = tonumber(color.a or color[4]) or tonumber(fallback.a or fallback[4]) or 1,
    }
end

local function GetSettings()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetCompanionFrame then
        local settings = NAGA_UI.Settings:GetCompanionFrame()
        if settings then return settings end
    end
    return DEFAULTS
end

local function GetSetting(key)
    local settings = GetSettings()
    return settings[key] ~= nil and settings[key] or DEFAULTS[key]
end

local function BuildFont(fontKey, size)
    local face = FONT_FACES[fontKey] or FONT_FACES.esobold
    size = Clamp(size, 8, 36, 14)
    local outline = GetSetting("textOutline") or "thick-outline"
    if outline == "none" then
        return string.format("%s|%d", face, size)
    end
    return string.format("%s|%d|%s", face, size, outline)
end

local function GetTextureInfo()
    -- Use the NAGA global bar texture selector so the same DDS is applied
    -- to Player Health/Magicka/Stamina, Target and all Companion bars.
    local key
    if NewWorldUI and NewWorldUI.GetSettingValue then
        key = NewWorldUI:GetSettingValue("barTextureKey")
    end
    if (not key or key == "") and NAGA_UI and NAGA_UI.Settings and NAGA_UI.Settings.GetResourceBars then
        local rb = NAGA_UI.Settings:GetResourceBars()
        if rb then
            key = rb.barTextureKey or rb.healthBarTexture
        end
    end
    key = key or GetSetting("textureKey") or "genericTall"

    if BarVisuals and BarVisuals.GetBarTextureInfo then
        return BarVisuals:GetBarTextureInfo(key)
    end
    if BarVisuals and BarVisuals.Textures and BarVisuals.Textures[key] then
        return BarVisuals.Textures[key]
    end
    return BarVisuals and BarVisuals.Textures and BarVisuals.Textures.genericTall or
        { texture = "EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds", coords = { 0, 1, 0, 0.8125 } }
end

local function IsHudEditorShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
    if not scene or not scene.GetName then return false end
    local name = scene:GetName() or ""
    return name == "hud_editor_keyboard" or name == "hud_editor_gamepad"
end

local function IsHudActuallyShowing()
    if IsHudEditorShowing() then return true end
    if not SCENE_MANAGER then return false end
    local hud = SCENE_MANAGER:GetScene("hud")
    local hudui = SCENE_MANAGER:GetScene("hudui")
    return (hud and hud.IsShowing and hud:IsShowing()) or (hudui and hudui.IsShowing and hudui:IsShowing()) or false
end

local function GetUnlockedCompanionCollectibles()
    local list = {}
    local companionType = COLLECTIBLE_CATEGORY_TYPE_COMPANION
    if not companionType then return list end

    if GetTotalCollectiblesByCategoryType and GetCollectibleIdFromType then
        local total = GetTotalCollectiblesByCategoryType(companionType) or 0
        for i = 1, total do
            local id = GetCollectibleIdFromType(companionType, i)
            if id and id > 0 then
                local unlocked = IsCollectibleUnlocked and IsCollectibleUnlocked(id) or select(5, GetCollectibleInfo(id))
                if unlocked then list[#list + 1] = id end
            end
        end
        if #list > 0 then return list end
    end

    if GetNumCollectibleCategories and GetCollectibleId then
        local seen = {}
        local numCategories = GetNumCollectibleCategories() or 0
        for categoryIndex = 1, numCategories do
            local _, numCollectibles, numSubcategories = GetCollectibleCategoryInfo(categoryIndex)
            numCollectibles = numCollectibles or 0
            numSubcategories = numSubcategories or 0
            for collectibleIndex = 1, numCollectibles do
                local id = GetCollectibleId(categoryIndex, nil, collectibleIndex)
                if id and id > 0 and not seen[id] then
                    local unlocked = select(5, GetCollectibleInfo(id))
                    local catType = GetCollectibleCategoryType and GetCollectibleCategoryType(id)
                    if unlocked and catType == companionType then
                        seen[id] = true
                        list[#list + 1] = id
                    end
                end
            end
            for subIndex = 1, numSubcategories do
                local _, numSubCollectibles = GetCollectibleSubCategoryInfo(categoryIndex, subIndex)
                numSubCollectibles = numSubCollectibles or 0
                for collectibleIndex = 1, numSubCollectibles do
                    local id = GetCollectibleId(categoryIndex, subIndex, collectibleIndex)
                    if id and id > 0 and not seen[id] then
                        local unlocked = select(5, GetCollectibleInfo(id))
                        local catType = GetCollectibleCategoryType and GetCollectibleCategoryType(id)
                        if unlocked and catType == companionType then
                            seen[id] = true
                            list[#list + 1] = id
                        end
                    end
                end
            end
        end
    end

    return list
end

local function HideCompanionPicker()
    if pickerControl then pickerControl:SetHidden(true) end
end

local function ShowCompanionPicker()
    local list = GetUnlockedCompanionCollectibles()
    if #list == 0 then return end

    if not pickerControl then
        pickerControl = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_CompanionPicker")
        pickerControl:SetDrawLayer(DL_OVERLAY)
        pickerControl:SetDrawTier(DT_HIGH)
        pickerControl:SetMouseEnabled(true)
        pickerControl:SetClampedToScreen(true)
        pickerControl:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)

        local bg = WINDOW_MANAGER:CreateControl("NAGA_CompanionPicker_BG", pickerControl, CT_BACKDROP)
        bg:SetAnchorFill(pickerControl)
        bg:SetCenterColor(0, 0, 0, 0.85)
        bg:SetEdgeColor(0.2, 0.75, 0.45, 1)
        bg:SetEdgeTexture("", 1, 1, 2)
        bg:SetInsets(0, 0, 0, 0)

        local title = WINDOW_MANAGER:CreateControl("NAGA_CompanionPicker_Title", pickerControl, CT_LABEL)
        title:SetFont("$(BOLD_FONT)|18|thick-outline")
        title:SetColor(0.85, 1, 0.9, 1)
        title:SetText(T("Escolher Companheiro"))
        title:SetAnchor(TOP, pickerControl, TOP, 0, 8)
        title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

        local closeBtn = WINDOW_MANAGER:CreateControl("NAGA_CompanionPicker_Close", pickerControl, CT_BUTTON)
        closeBtn:SetDimensions(28, 28)
        closeBtn:SetAnchor(TOPRIGHT, pickerControl, TOPRIGHT, -6, 6)
        closeBtn:SetMouseEnabled(true)
        local closeLabel = WINDOW_MANAGER:CreateControl("NAGA_CompanionPicker_CloseLabel", closeBtn, CT_LABEL)
        closeLabel:SetFont("$(BOLD_FONT)|18|thick-outline")
        closeLabel:SetText("X")
        closeLabel:SetColor(1, 0.35, 0.35, 1)
        closeLabel:SetAnchor(CENTER, closeBtn, CENTER, 0, -1)
        closeBtn:SetHandler("OnClicked", HideCompanionPicker)
    end

    for _, button in ipairs(pickerButtons) do button:SetHidden(true) end

    local iconSize, spacing = 100, 12
    local totalWidth = (#list * (iconSize + spacing)) - spacing
    local startX = -totalWidth / 2

    local currentCol
    if HasActiveCompanion and HasActiveCompanion() and GetActiveCompanionDefId and GetCompanionCollectibleId then
        local defId = GetActiveCompanionDefId()
        if defId and defId > 0 then currentCol = GetCompanionCollectibleId(defId) end
    end

    for i, id in ipairs(list) do
        local btn = pickerButtons[i]
        if not btn then
            local btnName = "NAGA_CompanionPickerBtn" .. tostring(i)
            btn = WINDOW_MANAGER:CreateControl(btnName, pickerControl, CT_BUTTON)
            btn:SetDimensions(iconSize, iconSize)
            btn:SetMouseEnabled(true)
            local tex = WINDOW_MANAGER:CreateControl(btnName .. "Icon", btn, CT_TEXTURE)
            tex:SetAnchorFill(btn)
            btn.icon = tex
            local border = WINDOW_MANAGER:CreateControl(btnName .. "Border", btn, CT_BACKDROP)
            border:SetAnchorFill(btn)
            border:SetCenterColor(0, 0, 0, 0)
            border:SetEdgeColor(0.2, 0.95, 0.35, 1)
            border:SetEdgeTexture("", 1, 1, 3)
            border:SetInsets(0, 0, 0, 0)
            border:SetHidden(true)
            btn.border = border
            local nameLabel = WINDOW_MANAGER:CreateControl(btnName .. "Name", btn, CT_LABEL)
            nameLabel:SetFont("$(BOLD_FONT)|12|soft-shadow-thick")
            nameLabel:SetColor(0.9, 0.95, 0.9, 1)
            nameLabel:SetAnchor(TOP, btn, BOTTOM, 0, 2)
            nameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            nameLabel:SetMaxLineCount(1)
            nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            nameLabel:SetDimensions(iconSize + 8, 18)
            btn.nameLabel = nameLabel
            pickerButtons[i] = btn
        end

        btn:ClearAnchors()
        btn:SetAnchor(CENTER, pickerControl, CENTER, startX + (i - 1) * (iconSize + spacing) + iconSize / 2, 10)
        btn:SetHidden(false)
        local iconPath = GetCollectibleIcon and GetCollectibleIcon(id) or ""
        btn.icon:SetTexture((iconPath and iconPath ~= "") and iconPath or "/esoui/art/icons/icon_missing.dds")
        local name = GetCollectibleName and GetCollectibleName(id) or ("Companion " .. tostring(id))
        name = zo_strformat("<<1>>", name)
        btn.nameLabel:SetText(name)
        local isActive = currentCol == id
        btn.border:SetHidden(not isActive)
        btn:SetHandler("OnClicked", function()
            if UseCollectible then UseCollectible(id) end
            HideCompanionPicker()
        end)
        btn:SetHandler("OnMouseEnter", function()
            btn.border:SetHidden(false)
            btn.border:SetEdgeColor(0.6, 1.0, 0.7, 1)
            if InformationTooltip then
                InitializeTooltip(InformationTooltip, btn, TOP, 0, -10, BOTTOM)
                SetTooltipText(InformationTooltip, name)
            end
        end)
        btn:SetHandler("OnMouseExit", function()
            btn.border:SetHidden(currentCol ~= id)
            if currentCol == id then btn.border:SetEdgeColor(0.2, 0.95, 0.35, 1) end
            if InformationTooltip then ClearTooltip(InformationTooltip) end
        end)
    end

    local pad = 24
    pickerControl:SetDimensions(math.max(360, totalWidth + pad * 2), 180)
    pickerControl:SetHidden(false)
end

local function CreateBar(parent, baseName, height)
    local holder = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    holder.bg = WINDOW_MANAGER:CreateControl(nil, holder, CT_BACKDROP)
    holder.bar = WINDOW_MANAGER:CreateControl(nil, holder, CT_STATUSBAR)
    holder.label = WINDOW_MANAGER:CreateControl(nil, holder, CT_LABEL)
    holder:SetDimensions(220, height)
    holder.bg:SetAnchorFill(holder)
    holder.bg:SetCenterColor(0, 0, 0, 0)
    holder.bar:SetAnchorFill(holder.bg)
    holder.label:SetAnchorFill(holder)
    holder.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    holder.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    holder.label:SetMouseEnabled(false)

    return holder
end

local function ApplyBarStyle(container, width, height, color)
    if not container then return end
    local settings = GetSettings()
    local textureInfo = GetTextureInfo()
    local inset = GetSetting("roundedBarCorners") ~= false and Clamp(GetSetting("barInset"), 0, 10, 2) or 0
    local bg = container.bg
    local bar = container.bar
    local label = container.label
    container:SetDimensions(width, height)
    bg:SetAnchorFill(container)
    bg:SetEdgeTexture("", 8, 2, 2)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetCenterColor(0, 0, 0, 0)

    if inset > 0 then
        bg:SetCenterColor(0, 0, 0, 0)
        bar:ClearAnchors()
        bar:SetAnchor(TOPLEFT, bg, TOPLEFT, inset, inset)
        bar:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -inset, -inset)
    else
        bar:SetAnchorFill(bg)
    end
    bar:SetTexture(textureInfo.texture)
    if textureInfo.coords then bar:SetTextureCoords(unpack(textureInfo.coords)) end
    bar:SetColor(color.r, color.g, color.b, color.a or 1)
    if bar.SetPixelRoundingEnabled then bar:SetPixelRoundingEnabled(false) end
    if bar.EnableLeadingEdge then bar:EnableLeadingEdge(false) end

    bg:SetCenterColor(settings.trackColor.r, settings.trackColor.g, settings.trackColor.b, settings.trackColor.a)
    if inset > 0 then
        bg:SetEdgeColor(settings.borderColor.r, settings.borderColor.g, settings.borderColor.b, 0)
    end

    label:SetFont(BuildFont(settings.valueFontKey, math.max(8, settings.fontSize - 2)))
    label:SetColor(settings.textColor.r, settings.textColor.g, settings.textColor.b, settings.textColor.a)
end

local function FormatNumber(n)
    n = math.floor(n or 0)
    if ZO_AbbreviateNumber and n >= 100000 then
        return ZO_AbbreviateNumber(n, NUMBER_ABBREVIATION_PRECISION_TENTHS, true)
    end
    local s = tostring(n)
    local k
    while true do
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

local function GetCompanionRapport()
    -- Usa a escala oficial do jogo (GetMinimumRapport / GetMaximumRapport),
    -- igual ao overview nativo do companheiro. Exibe o valor absoluto de
    -- afinidade e a porcentagem na escala completa (-5000 .. 5500).
    local rapport = tonumber((GetActiveCompanionRapport and GetActiveCompanionRapport()) or 0) or 0
    local minR = tonumber((GetMinimumRapport and GetMinimumRapport()) or -5000) or -5000
    local maxR = tonumber((GetMaximumRapport and GetMaximumRapport()) or 5500) or 5500
    if maxR <= minR then
        maxR = minR + 1
    end
    local span = maxR - minR
    local progress = math.max(0, math.min(span, rapport - minR))
    local pct = progress / span
    return rapport, maxR, pct
end

local function GetCompanionXP()
    -- API oficial (ZO_Companion_Manager:GetLevelInfo):
    --   level, currentXpInLevel = GetActiveCompanionLevelInfo()
    --   totalXpInLevel = GetNumExperiencePointsInCompanionLevel(level + 1)
    -- totalXpInLevel == 0 significa nível máximo.
    local level, current = 1, 0
    if GetActiveCompanionLevelInfo then
        level, current = GetActiveCompanionLevelInfo()
        level = tonumber(level) or 1
        current = math.max(0, tonumber(current) or 0)
    elseif GetUnitLevel then
        level = tonumber(GetUnitLevel(UNIT_TAG)) or 1
    end
    local maxValue = 0
    if GetNumExperiencePointsInCompanionLevel then
        maxValue = tonumber(GetNumExperiencePointsInCompanionLevel(level + 1)) or 0
    end
    if maxValue <= 0 then
        -- Nível máximo: barra cheia
        return level, current, math.max(1, current), 1
    end
    local pct = current / maxValue
    return level, current, maxValue, math.max(0, math.min(1, pct))
end

local function CreateFrame()
    if frame then return frame end
    local root = NAGA_CompanionFrameRoot or GetControl("NAGA_CompanionFrameRoot")
    if not root then
        root = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_CompanionFrameRoot")
    end
    frame = root
    frame:SetDimensions(Clamp(GetSetting("width"), 120, 500, 220), Clamp(GetSetting("height"), 60, 180, 90))
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(true)
    frame:SetMovable(true)
    frame:SetDrawTier(DT_MEDIUM)
    frame:SetDrawLayer(DL_BACKGROUND)
    frame:SetHidden(true)

    frame.backdrop = WINDOW_MANAGER:CreateControl(nil, frame, CT_BACKDROP)
    frame.backdrop:SetAnchorFill(frame)
    frame.backdrop:SetCenterColor(0, 0, 0, 0.12)
    frame.backdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds", 128, 16, 2, 0)
    frame.backdrop:SetEdgeColor(0.15, 0.15, 0.15, 0.55)
    frame.backdrop:SetMouseEnabled(false)

    frame.top = WINDOW_MANAGER:CreateControl(nil, frame, CT_CONTROL)
    frame.top:SetAnchor(TOPLEFT, frame, TOPLEFT, 4, 2)
    frame.top:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -4, 2)
    frame.top:SetHeight(20)
    frame.top:SetMouseEnabled(false)

    frame.level = WINDOW_MANAGER:CreateControl(nil, frame.top, CT_LABEL)
    frame.level:SetAnchor(LEFT, frame.top, LEFT, 0, 0)
    frame.level:SetDimensions(52, 20)
    frame.level:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    frame.level:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    frame.level:SetMouseEnabled(false)

    frame.name = WINDOW_MANAGER:CreateControl(nil, frame.top, CT_LABEL)
    frame.name:SetAnchor(LEFT, frame.level, RIGHT, 4, 0)
    frame.name:SetAnchor(RIGHT, frame.top, RIGHT, 0, 0)
    frame.name:SetHeight(20)
    frame.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    frame.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    frame.name:SetMouseEnabled(false)

    frame.health = CreateBar(frame, "Health", 22)
    frame.rapport = CreateBar(frame, "Rapport", 16)
    frame.xp = CreateBar(frame, "XP", 16)

    frame.btnCycle = WINDOW_MANAGER:CreateControl(nil, frame, CT_BUTTON)
    frame.btnCycle:SetDimensions(20, 20)
    frame.btnCycle:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -28, 1)
    frame.btnCycle:SetMouseEnabled(true)
    frame.btnCycle:SetNormalTexture("EsoUI/Art/Buttons/plus_up.dds")
    frame.btnCycle:SetPressedTexture("EsoUI/Art/Buttons/plus_down.dds")
    frame.btnCycle:SetMouseOverTexture("EsoUI/Art/Buttons/plus_over.dds")
    frame.btnCycle:SetHandler("OnClicked", function() ShowCompanionPicker() end)

    frame.btnDismiss = WINDOW_MANAGER:CreateControl(nil, frame, CT_BUTTON)
    frame.btnDismiss:SetDimensions(20, 20)
    frame.btnDismiss:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -4, 1)
    frame.btnDismiss:SetMouseEnabled(true)
    frame.btnDismiss:SetNormalTexture("EsoUI/Art/Buttons/decline_up.dds")
    frame.btnDismiss:SetPressedTexture("EsoUI/Art/Buttons/decline_down.dds")
    frame.btnDismiss:SetMouseOverTexture("EsoUI/Art/Buttons/decline_over.dds")
    frame.btnDismiss:SetHandler("OnClicked", function()
        if not HasActiveCompanion or not HasActiveCompanion() then return end
        local defId = GetActiveCompanionDefId and GetActiveCompanionDefId()
        local collectibleId = defId and GetCompanionCollectibleId and GetCompanionCollectibleId(defId)
        if collectibleId and collectibleId > 0 and UseCollectible then UseCollectible(collectibleId) end
    end)

    return frame
end

local function RegisterNativeEditHUD()
    if hudRegistered or not frame or not HUD_MANAGER or not ZO_Anchor then
        return hudRegistered
    end
    local ok = pcall(function()
        local opts = { defaultAnchor = ZO_Anchor:New(TOPLEFT, nil, TOPLEFT, 250, 280) }
        HUD_MANAGER:RegisterKeyboardElement(frame, "NAGA Companion Frame", opts, COMPASS_OPTIONS)
        HUD_MANAGER:RegisterGamepadElement(frame, "NAGA Companion Frame", opts, COMPASS_OPTIONS)
    end)
    if ok then
        hudRegistered = true
        frame.nagaNativeEditHUD = true
        frame.nagaNativeEditHUDName = "NAGA Companion Frame"
        return true
    end
    return false
end

local function EnsureNativeEditHUD()
    if RegisterNativeEditHUD() then return end
    if registerRetryScheduled then return end
    registerRetryScheduled = true
    zo_callLater(function()
        registerRetryScheduled = false
        if RegisterNativeEditHUD() then return end
        zo_callLater(RegisterNativeEditHUD, 1000)
    end, 250)
end

local function IsInEditorPreview()
    return IsHudEditorShowing()
end

local function HideDefaultCompanionFrame()
    pcall(function()
        if UNIT_FRAMES and type(UNIT_FRAMES.DisableLocalCompanionFrame) == "function" then
            UNIT_FRAMES:DisableLocalCompanionFrame()
        end
    end)

    local candidates =
    {
        "ZO_UnitFramesCompanion", "ZO_CompanionUnitFrame", "ZO_UnitFramecompanion",
        "ZO_UnitFrames_Companion", "ZO_PlayerAttributeCompanion",
    }
    for _, name in ipairs(candidates) do
        local control = _G[name]
        if control and control.SetHidden then pcall(function() control:SetHidden(true) end) end
    end

    pcall(function()
        if UNIT_FRAMES and type(UNIT_FRAMES.GetFrame) == "function" then
            local unitFrame = UNIT_FRAMES:GetFrame(UNIT_TAG)
            if unitFrame then
                if unitFrame.SetHidden then unitFrame:SetHidden(true) end
                if unitFrame.control and unitFrame.control.SetHidden then unitFrame.control:SetHidden(true) end
                if unitFrame.frame and unitFrame.frame.SetHidden then unitFrame.frame:SetHidden(true) end
            end
        end
    end)
end

local function ApplyLayout()
    if not frame then return end
    local settings = GetSettings()
    local width = Clamp(settings.width, 120, 500, 220)
    local height = Clamp(settings.height, 60, 180, 90)
    frame:SetScale(Clamp(settings.scale, 70, 160, 100) / 100)
    frame:SetDimensions(width, height)
    frame.backdrop:SetAnchorFill(frame)
    frame.top:SetAnchor(TOPLEFT, frame, TOPLEFT, 4, 2)
    frame.top:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -4, 2)
    frame.top:SetHeight(20)

    local barTop = 24
    local healthHeight = Clamp(math.floor((height - 34) * 0.43), 16, 28)
    local smallHeight = Clamp(math.floor((height - 34) * 0.285), 10, 20)

    frame.health:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, barTop)
    frame.health:SetWidth(width - 4)
    frame.health:SetHeight(healthHeight)
    frame.rapport:SetAnchor(TOPLEFT, frame.health, BOTTOMLEFT, 0, 2)
    frame.rapport:SetWidth(width - 4)
    frame.rapport:SetHeight(smallHeight)
    frame.xp:SetAnchor(TOPLEFT, frame.rapport, BOTTOMLEFT, 0, 2)
    frame.xp:SetWidth(width - 4)
    frame.xp:SetHeight(smallHeight)

    local healthColor = CopyColor(settings.healthColor, DEFAULTS.healthColor)
    local rapportColor = CopyColor(settings.rapportColor, DEFAULTS.rapportColor)
    local xpColor = CopyColor(settings.xpColor, DEFAULTS.xpColor)
    ApplyBarStyle(frame.health, width - 4, healthHeight, healthColor)
    ApplyBarStyle(frame.rapport, width - 4, smallHeight, rapportColor)
    ApplyBarStyle(frame.xp, width - 4, smallHeight, xpColor)
    -- O texto das barras menores acompanha suas respectivas funções: Rapport azul,
    -- XP verde. A cor continua configurável no menu.
    frame.rapport.label:SetColor(rapportColor.r, rapportColor.g, rapportColor.b, rapportColor.a or 1)
    frame.xp.label:SetColor(xpColor.r, xpColor.g, xpColor.b, xpColor.a or 1)

    local nameSize = Clamp(settings.fontSize, 8, 36, 14)
    frame.level:SetFont(BuildFont(settings.nameFontKey, math.max(8, nameSize - 2)))
    frame.name:SetFont(BuildFont(settings.nameFontKey, math.max(8, nameSize - 1)))
    frame.level:SetColor(settings.textColor.r, settings.textColor.g, settings.textColor.b, settings.textColor.a)
    frame.name:SetColor(settings.textColor.r, settings.textColor.g, settings.textColor.b, settings.textColor.a)
    frame.btnCycle:SetHidden(settings.showButtons == false)
    frame.btnDismiss:SetHidden(settings.showButtons == false)
    frame.rapport:SetHidden(settings.showRapport == false)
    frame.xp:SetHidden(settings.showXP == false)
    frame.level:SetHidden(settings.showLevel == false)
end

local function SetBarProgress(container, pct)
    if not container or not container.bg or not container.bar then return end
    pct = math.max(0, math.min(1, tonumber(pct) or 0))
    local bg = container.bg
    local bar = container.bar
    local inset = GetSetting("roundedBarCorners") ~= false and Clamp(GetSetting("barInset"), 0, 10, 2) or 0
    local bgWidth = math.max(1, bg:GetWidth())
    local bgHeight = math.max(1, bg:GetHeight())
    -- Se a largura ainda não foi resolvida pelo layout, usa a dimensão do holder
    if bgWidth <= 1 and container.GetWidth then
        bgWidth = math.max(1, container:GetWidth())
    end
    if bgHeight <= 1 and container.GetHeight then
        bgHeight = math.max(1, container:GetHeight())
    end
    local availableWidth = math.max(1, bgWidth - inset * 2)
    local availableHeight = math.max(1, bgHeight - inset * 2)

    -- Não deixe o BOTTOMRIGHT/TOPRIGHT anterior determinar a largura.
    -- A largura da barra agora é exclusivamente a porcentagem real.
    bar:ClearAnchors()
    bar:SetAnchor(TOPLEFT, bg, TOPLEFT, inset, inset)
    bar:SetDimensions(math.max(1, availableWidth * pct), availableHeight)

    -- Reforça o preenchimento via API de statusbar quando disponível
    if bar.SetMinMax and bar.SetValue then
        bar:SetMinMax(0, 1)
        bar:SetValue(pct)
    end
end

local function ApplyHealth()
    if not frame or not DoesUnitExist(UNIT_TAG) then return end
    local current, maximum = GetUnitPower(UNIT_TAG, POWERTYPE_HEALTH)
    maximum = math.max(1, tonumber(maximum) or 1)
    current = tonumber(current) or 0
    local pct = math.max(0, math.min(1, current / maximum))
    SetBarProgress(frame.health, pct)
    frame.health.label:SetText(string.format("%s (%d%%)", FormatNumber(current), math.floor(pct * 100 + 0.5)))
end

local function ApplyRapport()
    if not frame then return end
    if GetSetting("showRapport") == false then
        frame.rapport:SetHidden(true)
        return
    end
    frame.rapport:SetHidden(false)
    local current, maximum, pct = GetCompanionRapport()
    SetBarProgress(frame.rapport, pct)
    -- Valor absoluto de afinidade (ex: 750/5,500) + % na escala oficial
    frame.rapport.label:SetText(string.format("%s/%s (%d%%)",
        FormatNumber(current), FormatNumber(maximum), math.floor((pct or 0) * 100 + 0.5)))
    local rc = CopyColor(GetSetting("rapportColor"), DEFAULTS.rapportColor)
    frame.rapport.label:SetColor(rc.r, rc.g, rc.b, rc.a or 1)
    if frame.rapport.bar then
        frame.rapport.bar:SetColor(rc.r, rc.g, rc.b, rc.a or 1)
    end
end

local function ApplyXPAndName(usePreview)
    if not frame then return end
    if usePreview then
        frame.name:SetText(T("Companion"))
        frame.level:SetText("LV 20")
        frame.health.label:SetText("12,345 (100%)")
        frame.rapport.label:SetText("2,750/5,500 (70%)")
        frame.xp.label:SetText("1,250/2,000 (63%)")
        return
    end
    if not DoesUnitExist(UNIT_TAG) then return end
    local name = zo_strformat("<<1>>", GetUnitName(UNIT_TAG) or "Companion")
    local level, currentXP, maxXP, pct = GetCompanionXP()
    frame.name:SetText(name)
    frame.level:SetText(string.format("LV %d", level or 1))
    if GetSetting("showXP") == false then
        frame.xp:SetHidden(true)
    else
        frame.xp:SetHidden(false)
        SetBarProgress(frame.xp, pct)
        -- current/max (pct%) — igual ao tooltip nativo do companheiro
        if maxXP and maxXP > 0 and pct < 1 then
            frame.xp.label:SetText(string.format("%s/%s (%d%%)",
                FormatNumber(currentXP), FormatNumber(maxXP), math.floor((pct or 0) * 100 + 0.5)))
        else
            frame.xp.label:SetText(string.format("%s (100%%)", FormatNumber(currentXP or 0)))
        end
        local xc = CopyColor(GetSetting("xpColor"), DEFAULTS.xpColor)
        frame.xp.label:SetColor(xc.r, xc.g, xc.b, xc.a or 1)
        if frame.xp.bar then
            frame.xp.bar:SetColor(xc.r, xc.g, xc.b, xc.a or 1)
        end
    end
end

local function RefreshAll()
    if not frame then CreateFrame() end
    local enabled = GetSetting("enabled") ~= false
    local editor = IsInEditorPreview()
    local hudVisible = IsHudActuallyShowing()
    lastEditorState = editor

    -- Sempre suprimir o frame nativo antes de testar a cena. O ESO pode
    -- recriá-lo/mostrá-lo ao entrar em menus; fazer isso primeiro evita
    -- o antigo frame de companheiro piscando por um instante.
    HideDefaultCompanionFrame()

    if not enabled then
        frame:SetHidden(true)
        HideCompanionPicker()
        return
    end

    -- Nunca mantenha o Companion Frame sobre Inventário, Mapa, Skills,
    -- Configurações ou outros menus. Exceção: o próprio Edit HUD do ESO,
    -- onde o elemento precisa permanecer visível para ser movimentado.
    if not hudVisible and not editor then
        frame:SetHidden(true)
        HideCompanionPicker()
        return
    end
    ApplyLayout()

    if editor then
        frame:SetHidden(false)
        frame:SetAlpha(1)
        ApplyXPAndName(true)
        return
    end

    if not DoesUnitExist(UNIT_TAG) or not HasActiveCompanion or not HasActiveCompanion() then
        frame:SetHidden(true)
        HideCompanionPicker()
        return
    end

    frame:SetHidden(false)
    ApplyXPAndName(false)
    ApplyHealth()
    ApplyRapport()
    local inCombat = IsUnitInCombat and IsUnitInCombat("player") or false
    local opacity = inCombat and Clamp(GetSetting("opacityIn"), 0, 100, 100) or Clamp(GetSetting("opacityOut"), 0, 100, 70)
    frame:SetAlpha(opacity / 100)
end

local function OnPowerUpdate(_, unitTag, _, powerType)
    if unitTag ~= UNIT_TAG then return end
    if powerType == POWERTYPE_HEALTH then ApplyHealth() end
end

local function RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Power", EVENT_POWER_UPDATE, OnPowerUpdate)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "Power", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, UNIT_TAG)

    if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "State", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
            zo_callLater(RefreshAll, 150)
        end)
    end
    if EVENT_COMPANION_RAPPORT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Rapport", EVENT_COMPANION_RAPPORT_UPDATE, ApplyRapport)
    end
    if EVENT_COMPANION_EXPERIENCE_GAIN then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "XP", EVENT_COMPANION_EXPERIENCE_GAIN, function() ApplyXPAndName(false) end)
    end
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "PlayerAct", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(RefreshAll, 500)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "Combat", EVENT_PLAYER_COMBAT_STATE, function()
        if GetSetting("enabled") ~= false then RefreshAll() end
    end)

    if SCENE_MANAGER then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            -- Suprime imediatamente o frame nativo e o nosso frame ao abrir
            -- qualquer menu. O callback atrasado anterior permitia um frame
            -- do ESO aparecer/piscar antes do RefreshAll.
            HideDefaultCompanionFrame()
            RefreshAll()
        end)
    end
end

function CompanionFrame:Initialize()
    if initialized then
        RefreshAll()
        return true
    end
    local settings = NAGA_UI.Settings
    if not settings or not settings.GetCompanionFrame then return false end
    CreateFrame()
    EnsureNativeEditHUD()
    RegisterEvents()
    HideDefaultCompanionFrame()
    RefreshAll()
    initialized = true
    return true
end

function CompanionFrame:RefreshSettings()
    if not initialized then
        return self:Initialize()
    end
    CreateFrame()
    EnsureNativeEditHUD()
    ApplyLayout()
    RefreshAll()
end


function CompanionFrame:GetFrame()
    return frame
end



-- Auto-init (não depende mais do AbyssUI.lua)
local function TryInitializeCompanion()
    if initialized then
        return
    end
    if CompanionFrame:Initialize() then
        return
    end
    zo_callLater(TryInitializeCompanion, 250)
end

NAGA_UI.OnAddonLoaded(function()
    zo_callLater(TryInitializeCompanion, 0)
end)

return CompanionFrame
