-- ESO Adventurer Suite
-- Live equipment paper-doll overlay for the Gear & Sets workspace.

local EPC = ESOProgressionCoach
EPC.GearLoadoutOverlay = EPC.GearLoadoutOverlay or {}
local G = EPC.GearLoadoutOverlay
local wm = WINDOW_MANAGER
local WRAP_ELLIPSIS = TEXT_WRAP_MODE_ELLIPSIS or TEXT_WRAP_MODE_TRUNCATE
local WRAP_TRUNCATE = TEXT_WRAP_MODE_TRUNCATE or TEXT_WRAP_MODE_ELLIPSIS

local BASE_W, BASE_H = 700, 700
local MIN_W, MIN_H = 500, 500
local MAX_W, MAX_H = 980, 980

local SLOT_ROWS_LEFT = {
    {key="HEAD", label="HEAD", slot=EQUIP_SLOT_HEAD},
    {key="SHOULDERS", label="SHOULDERS", slot=EQUIP_SLOT_SHOULDERS},
    {key="CHEST", label="CHEST", slot=EQUIP_SLOT_CHEST},
    {key="HANDS", label="HANDS", slot=EQUIP_SLOT_HAND},
    {key="WAIST", label="WAIST", slot=EQUIP_SLOT_WAIST},
    {key="LEGS", label="LEGS", slot=EQUIP_SLOT_LEGS},
    {key="FEET", label="FEET", slot=EQUIP_SLOT_FEET},
}

local SLOT_ROWS_RIGHT = {
    {key="NECK", label="NECK", slot=EQUIP_SLOT_NECK},
    {key="RING1", label="RING 1", slot=EQUIP_SLOT_RING1},
    {key="RING2", label="RING 2", slot=EQUIP_SLOT_RING2},
    {key="FRONT_MAIN", label="FRONT MAIN", slot=EQUIP_SLOT_MAIN_HAND, bar="FRONT"},
    {key="FRONT_OFF", label="FRONT OFF", slot=EQUIP_SLOT_OFF_HAND, bar="FRONT"},
    {key="BACK_MAIN", label="BACK MAIN", slot=EQUIP_SLOT_BACKUP_MAIN, bar="BACK"},
    {key="BACK_OFF", label="BACK OFF", slot=EQUIP_SLOT_BACKUP_OFF, bar="BACK"},
}

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a,b,c,d,e,f,g,h,i = pcall(fn, ...)
    if not ok then return fallback end
    return a,b,c,d,e,f,g,h,i
end

local function makeBackdrop(name, parent)
    local b = wm:CreateControl(name, parent, CT_BACKDROP)
    b:SetEdgeTexture(nil, 1, 1, 1)
    return b
end

-- Keep visible strokes slightly inside their parent. Thin backdrop edges can be
-- partially clipped or land on sub-pixels when the Live Equipment canvas is
-- scaled down, so important panels get a second fully-contained border.
local function makeInsetBorder(name, parent, inset)
    local b = wm:CreateControl(name, parent, CT_BACKDROP)
    b:SetEdgeTexture(nil, 1, 1, 2)
    inset = tonumber(inset) or 2
    b:SetAnchor(TOPLEFT, parent, TOPLEFT, inset, inset)
    b:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -inset, -inset)
    b:SetCenterColor(0, 0, 0, 0)
    b:SetEdgeColor(0.20, 0.27, 0.36, 0.72)
    if b.SetMouseEnabled then b:SetMouseEnabled(false) end
    if b.SetDrawLevel then b:SetDrawLevel(2) end
    return b
end

local function makeLabel(name, parent, text, font)
    local l = wm:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font or "ZoFontGame")
    l:SetText(text or "")
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

local function keepInside(label, maxLines, wrapped)
    if not label then return end
    if label.SetMaxLineCount then label:SetMaxLineCount(maxLines or 1) end
    if label.SetWrapMode then
        local mode = wrapped and WRAP_TRUNCATE or WRAP_ELLIPSIS
        if mode then label:SetWrapMode(mode) end
    end
end

local function makeButton(name, parent, text, handler)
    local b = wm:CreateControl(name, parent, CT_BUTTON)
    b:SetFont("ZoFontGameBold")
    b:SetText(text)
    if b.SetHorizontalAlignment then b:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if b.SetVerticalAlignment then b:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
    local border = wm:CreateControl(name .. "Border", b, CT_BACKDROP)
    border:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    border:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
    border:SetCenterColor(0.035,0.050,0.072,0.55)
    border:SetEdgeColor(0.24,0.36,0.54,0.92)
    border:SetEdgeTexture(nil,1,1,1)
    if border.SetDrawLevel then border:SetDrawLevel(0) end
    b.easBorder = border
    if handler then b:SetHandler("OnClicked", handler) end
    return b
end

local function qualityColor(link)
    if not link or link == "" then return 0.30, 0.34, 0.42 end
    local q = safe(GetItemLinkDisplayQuality, nil, link)
    if q ~= nil and type(GetItemQualityColor) == "function" then
        local c = safe(GetItemQualityColor, nil, q)
        if c and type(c.UnpackRGB) == "function" then
            local ok, r,g,b = pcall(c.UnpackRGB, c)
            if ok and r and g and b then return r,g,b end
        end
    end
    return 0.30, 0.34, 0.42
end

local function cleanName(value)
    local text = tostring(value or "")
    if type(zo_strformat) == "function" and text ~= "" then
        local ok, formatted = pcall(zo_strformat, "<<1>>", text)
        if ok and formatted then text = formatted end
    end
    return text
end

-- ESO flattens line breaks in this compact equipment label on some clients.
-- Split the item name ourselves and render each line in a separate label so
-- long names are guaranteed to appear on two physical rows.
local function splitItemName(text, maxCharsPerLine)
    text = cleanName(text)
    maxCharsPerLine = tonumber(maxCharsPerLine) or 23
    if text == "" then return "", "" end

    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return text, "" end

    local first, second = "", ""
    local splitAt = nil
    for i = 1, #words do
        local candidate = first == "" and words[i] or (first .. " " .. words[i])
        if #candidate <= maxCharsPerLine or first == "" then
            first = candidate
        else
            splitAt = i
            break
        end
    end
    -- Only populate the second physical label when the first line actually
    -- overflowed. Short names that fit remain entirely on the first row.
    if splitAt then
        for i = splitAt, #words do
            second = second == "" and words[i] or (second .. " " .. words[i])
        end
    end
    return first, second
end

local function enumText(stringId, value)
    if value == nil or type(GetString) ~= "function" then return "" end
    local ok, text = pcall(GetString, stringId, value)
    if ok and text and text ~= "" then return cleanName(text) end
    return ""
end

local ARMOR_TYPE_NAMES = {
    [rawget(_G, "ARMORTYPE_LIGHT") or 1] = "LIGHT ARMOR",
    [rawget(_G, "ARMORTYPE_MEDIUM") or 2] = "MEDIUM ARMOR",
    [rawget(_G, "ARMORTYPE_HEAVY") or 3] = "HEAVY ARMOR",
}

local WEAPON_TYPE_NAMES = {
    [rawget(_G, "WEAPONTYPE_AXE") or -101] = "AXE",
    [rawget(_G, "WEAPONTYPE_HAMMER") or -102] = "MACE",
    [rawget(_G, "WEAPONTYPE_SWORD") or -103] = "SWORD",
    [rawget(_G, "WEAPONTYPE_TWO_HANDED_AXE") or -104] = "BATTLE AXE",
    [rawget(_G, "WEAPONTYPE_TWO_HANDED_HAMMER") or -105] = "MAUL",
    [rawget(_G, "WEAPONTYPE_TWO_HANDED_SWORD") or -106] = "GREATSWORD",
    [rawget(_G, "WEAPONTYPE_DAGGER") or -107] = "DAGGER",
    [rawget(_G, "WEAPONTYPE_BOW") or -108] = "BOW",
    [rawget(_G, "WEAPONTYPE_FIRE_STAFF") or -109] = "INFERNO STAFF",
    [rawget(_G, "WEAPONTYPE_FROST_STAFF") or -110] = "ICE STAFF",
    [rawget(_G, "WEAPONTYPE_LIGHTNING_STAFF") or -111] = "LIGHTNING STAFF",
    [rawget(_G, "WEAPONTYPE_HEALING_STAFF") or -112] = "RESTORATION STAFF",
    [rawget(_G, "WEAPONTYPE_SHIELD") or -113] = "SHIELD",
}

local function usableTypeText(text)
    text = tostring(text or "")
    local upper = zo_strupper(text)
    if upper == "" or upper == "UNKNOWN" or upper == "NONE" then return "" end
    return upper
end

local function equipmentTypeText(link, def)
    if not link or link == "" then return "" end

    -- Weapons (including shields where the API reports a weapon type).
    local weaponType = safe(GetItemLinkWeaponType, nil, link)
    local noneWeapon = rawget(_G, "WEAPONTYPE_NONE")
    if weaponType ~= nil and weaponType ~= noneWeapon then
        local mapped = WEAPON_TYPE_NAMES[weaponType]
        if mapped then return mapped end
        local text = usableTypeText(enumText(SI_WEAPONTYPE, weaponType))
        if text ~= "" then return text end
    end

    -- Worn armor pieces.
    local armorType = safe(GetItemLinkArmorType, nil, link)
    local noneArmor = rawget(_G, "ARMORTYPE_NONE")
    if armorType ~= nil and armorType ~= noneArmor then
        local mapped = ARMOR_TYPE_NAMES[armorType]
        if mapped then return mapped end
        local text = usableTypeText(enumText(SI_ARMORTYPE, armorType))
        if text ~= "" then
            if not text:find("ARMOR", 1, true) then text = text .. " ARMOR" end
            return text
        end
    end

    -- Jewelry is clearer by equipped slot than by generic item type.
    if def then
        if def.slot == EQUIP_SLOT_NECK then return "NECKLACE" end
        if def.slot == EQUIP_SLOT_RING1 or def.slot == EQUIP_SLOT_RING2 then return "RING" end
    end

    -- Last-resort ESO item type string.
    local itemType = safe(GetItemLinkItemType, nil, link)
    if itemType ~= nil then
        local text = usableTypeText(enumText(SI_ITEMTYPE, itemType))
        if text ~= "" then return text end
    end
    return "EQUIPMENT"
end

function G:GetTheme()
    local journal = EPC and EPC.Journal
    if journal and type(journal.GetTheme) == "function" then
        local theme = safe(journal.GetTheme, nil, journal)
        if type(theme) == "table" then return theme end
    end
    return {
        text={0.88,0.92,0.98,1},
        edge={0.24,0.36,0.54,1},
        accent={0.43,0.68,0.96,1},
    }
end

function G:GetCompanionDefId()
    return math.max(0, tonumber(safe(GetActiveCompanionDefId, 0)) or 0)
end

function G:EnsureSaved()
    EPC.saved = EPC.saved or {}
    EPC.saved.gearLoadoutOverlay = EPC.saved.gearLoadoutOverlay or {}
    local s = EPC.saved.gearLoadoutOverlay
    -- v0.24.91: the paper-doll is intentionally player-only.
    s.actor = "PLAYER"
    return s
end

function G:IsCompanionAvailable()
    if safe(HasActiveCompanion, false) == true then return true end
    if self:GetCompanionDefId() > 0 then return true end
    if type(DoesUnitExist) == "function" and safe(DoesUnitExist, false, "companion") == true then return true end
    return false
end

function G:IsCompanionGearSupported()
    return BAG_COMPANION_WORN ~= nil and (type(GetActiveCompanionDefId) == "function" or type(HasActiveCompanion) == "function")
end

function G:GetActorBag()
    return BAG_WORN, "player"
end

function G:SetButtonState(button, selected, enabled)
    if not button then return end
    local t = self:GetTheme()
    local a = t.accent or t.edge or {0.43,0.68,0.96,1}
    enabled = enabled ~= false
    if button.SetEnabled then button:SetEnabled(enabled) end
    if selected then
        button:SetNormalFontColor(a[1], a[2], a[3], 1)
        button:SetMouseOverFontColor(math.min(1,a[1]+0.18), math.min(1,a[2]+0.18), math.min(1,a[3]+0.18), 1)
    elseif enabled then
        button:SetNormalFontColor(0.84, 0.88, 0.94, 1)
        button:SetMouseOverFontColor(1,1,1,1)
    else
        button:SetNormalFontColor(0.38, 0.42, 0.50, 1)
        button:SetMouseOverFontColor(0.38, 0.42, 0.50, 1)
    end
    if button.bg then
        if selected then
            button.bg:SetCenterColor(a[1], a[2], a[3], 0.20)
            button.bg:SetEdgeColor(a[1], a[2], a[3], 0.72)
        elseif enabled then
            button.bg:SetCenterColor(0.055, 0.070, 0.095, 0.72)
            button.bg:SetEdgeColor(0.24, 0.31, 0.42, 0.55)
        else
            button.bg:SetCenterColor(0.03, 0.04, 0.05, 0.48)
            button.bg:SetEdgeColor(0.14, 0.16, 0.20, 0.35)
        end
    end
end

function G:CreateActorButton(name, text, x, y, w, handler)
    local b = makeButton(name, self.canvas, text, handler)
    b:SetAnchor(TOPLEFT, self.canvas, TOPLEFT, x, y)
    b:SetDimensions(w, 30)
    local bg = makeBackdrop(name .. "_BG", b)
    bg:SetAnchor(TOPLEFT, b, TOPLEFT, 1, 1)
    bg:SetAnchor(BOTTOMRIGHT, b, BOTTOMRIGHT, -1, -1)
    bg:SetDrawLevel(0)
    b.bg = bg
    return b
end

function G:CreateSlotCard(def, x, y)
    if def.slot == nil then return nil end
    local name = "EAS_GearPreviewSlot_" .. def.key
    local card = makeBackdrop(name, self.canvas)
    card:SetAnchor(TOPLEFT, self.canvas, TOPLEFT, x, y)
    card:SetDimensions(262, 80)
    card:SetCenterColor(0.032, 0.043, 0.060, 0.80)
    card:SetEdgeColor(0.20, 0.27, 0.36, 0.40)
    local insetBorder = makeInsetBorder(name .. "_InsetBorder", card, 2)
    insetBorder:SetEdgeColor(0.20, 0.27, 0.36, 0.78)

    local iconBG = makeBackdrop(name .. "_IconBG", card)
    iconBG:SetAnchor(LEFT, card, LEFT, 8, 0)
    iconBG:SetDimensions(48, 48)
    iconBG:SetCenterColor(0.02, 0.025, 0.035, 0.88)
    iconBG:SetEdgeColor(0.30, 0.34, 0.42, 0.75)

    local icon = wm:CreateControl(name .. "_Icon", iconBG, CT_TEXTURE)
    icon:SetAnchor(CENTER, iconBG, CENTER, 0, 0)
    icon:SetDimensions(42, 42)
    icon:SetHidden(true)

    local slotLabel = makeLabel(name .. "_SlotLabel", card, def.label, "ZoFontGameSmall")
    slotLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 62, 5)
    slotLabel:SetDimensions(92, 14)
    slotLabel:SetColor(0.52, 0.62, 0.75, 1)
    slotLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    keepInside(slotLabel, 1, false)

    local itemLabel = makeLabel(name .. "_ItemLabel", card, "EMPTY", "ZoFontGame")
    itemLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 62, 19)
    itemLabel:SetDimensions(192, 18)
    itemLabel:SetColor(0.72, 0.76, 0.82, 1)
    itemLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    keepInside(itemLabel, 1, false)

    local itemLabel2 = makeLabel(name .. "_ItemLabel2", card, "", "ZoFontGame")
    itemLabel2:SetAnchor(TOPLEFT, card, TOPLEFT, 62, 36)
    itemLabel2:SetDimensions(192, 18)
    itemLabel2:SetColor(0.72, 0.76, 0.82, 1)
    itemLabel2:SetVerticalAlignment(TEXT_ALIGN_TOP)
    keepInside(itemLabel2, 1, false)

    -- Put equipment type on the same header row as the slot. This avoids
    -- stacking four text rows into a compact card and keeps type/set text
    -- from colliding at small overlay scales.
    local typeLabel = makeLabel(name .. "_TypeLabel", card, "", "ZoFontGameSmall")
    typeLabel:SetAnchor(TOPRIGHT, card, TOPRIGHT, -8, 5)
    typeLabel:SetDimensions(108, 14)
    typeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    typeLabel:SetColor(0.88, 0.72, 0.34, 1)
    typeLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    keepInside(typeLabel, 1, false)

    local setLabel = makeLabel(name .. "_SetLabel", card, "", "ZoFontGameSmall")
    setLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 62, 60)
    setLabel:SetDimensions(192, 14)
    setLabel:SetColor(0.48, 0.58, 0.68, 1)
    setLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    keepInside(setLabel, 1, false)

    card.insetBorder = insetBorder
    card.iconBG = iconBG
    card.icon = icon
    card.slotLabel = slotLabel
    card.itemLabel = itemLabel
    card.itemLabel2 = itemLabel2
    card.typeLabel = typeLabel
    card.setLabel = setLabel
    card.def = def
    card:SetMouseEnabled(true)
    card:SetHandler("OnMouseEnter", function(control)
        if not control.easItemLink or control.easItemLink == "" or not InformationTooltip then return end
        if type(InitializeTooltip) == "function" then InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, TOPRIGHT) end
        if type(InformationTooltip.SetLink) == "function" then
            InformationTooltip:SetLink(control.easItemLink)
        else
            InformationTooltip:AddLine(control.easFullItemName or (control.itemLabel and control.itemLabel:GetText()) or "Equipped Item")
            if control.typeLabel and control.typeLabel:GetText() ~= "" then InformationTooltip:AddLine(control.typeLabel:GetText()) end
            if control.setLabel and control.setLabel:GetText() ~= "" then InformationTooltip:AddLine(control.setLabel:GetText()) end
        end
    end)
    card:SetHandler("OnMouseExit", function() if type(ClearTooltip) == "function" and InformationTooltip then ClearTooltip(InformationTooltip) end end)
    return card
end

function G:UpdateScale()
    if not self.window or not self.canvas then return end
    local w,h = self.window:GetDimensions()
    w = tonumber(w) or BASE_W
    h = tonumber(h) or BASE_H

    -- The Live Equipment UI is authored as a fixed 700x700 canvas. Treat
    -- window resizing as a uniform zoom, never as a reflow/stretch. This keeps
    -- cards, fonts, icons, spacing and the character stage identical at every
    -- size.
    local side = math.min(w, h)
    side = math.max(MIN_W, math.min(MAX_W, side))
    local scale = side / BASE_W

    self.canvas:SetScale(scale)
    self.canvas:ClearAnchors()
    self.canvas:SetAnchor(CENTER, self.window, CENTER, 0, 0)
end

function G:NormalizeWindowSize(save)
    if not self.window then return end
    local w,h = self.window:GetDimensions()
    local side = math.min(tonumber(w) or BASE_W, tonumber(h) or BASE_H)
    side = math.floor(math.max(MIN_W, math.min(MAX_W, side)) + 0.5)
    self.window:SetDimensions(side, side)
    if save then
        local sv = self:EnsureSaved()
        sv.width, sv.height = side, side
    end
    self:UpdateScale()
end

function G:Create()
    if self.window then return end
    local s = self:EnsureSaved()

    local window = wm:CreateTopLevelWindow("EAS_GearLoadoutOverlay")
    local savedW = tonumber(s.width) or BASE_W
    local savedH = tonumber(s.height) or BASE_H
    local initialSide = math.floor(math.max(MIN_W, math.min(MAX_W, math.min(savedW, savedH))) + 0.5)
    window:SetDimensions(initialSide, initialSide)
    if window.SetDimensionConstraints then window:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H) end
    if window.SetResizeHandleSize then window:SetResizeHandleSize(24) end
    -- Allow the overlay to be positioned flush against any screen edge/corner.
    window:SetClampedToScreen(false)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetHidden(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)
    self.window = window

    if tonumber(s.left) and tonumber(s.top) then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.left, s.top)
    else
        window:SetAnchor(RIGHT, GuiRoot, RIGHT, -24, 0)
    end

    local canvas = wm:CreateControl("EAS_GearLoadoutCanvas", window, CT_CONTROL)
    canvas:SetDimensions(BASE_W, BASE_H)
    canvas:SetAnchor(CENTER, window, CENTER, 0, 0)
    self.canvas = canvas

    local bg = makeBackdrop("EAS_GearLoadoutBG", canvas)
    bg:SetAnchorFill(canvas)
    bg:SetCenterColor(0.012, 0.018, 0.028, 0.91)
    bg:SetEdgeColor(0.30, 0.56, 0.82, 0.78)
    self.bg = bg
    local frameBorder = makeInsetBorder("EAS_GearLoadoutFrameInsetBorder", bg, 3)
    frameBorder:SetEdgeColor(0.30, 0.56, 0.82, 0.86)
    self.frameBorder = frameBorder

    local top = makeBackdrop("EAS_GearLoadoutTop", canvas)
    top:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, 0)
    top:SetAnchor(TOPRIGHT, canvas, TOPRIGHT, 0, 0)
    top:SetHeight(92)
    top:SetCenterColor(0.024, 0.034, 0.050, 0.92)
    top:SetEdgeColor(0.18, 0.28, 0.40, 0.54)
    self.top = top

    local accent = makeBackdrop("EAS_GearLoadoutAccent", canvas)
    accent:SetAnchor(TOPLEFT, canvas, TOPLEFT, 0, 0)
    accent:SetDimensions(4, BASE_H)
    accent:SetCenterColor(0.34, 0.68, 1.00, 0.96)
    accent:SetEdgeColor(0,0,0,0)
    self.accent = accent

    local title = makeLabel("EAS_GearLoadoutTitle", canvas, "LIVE EQUIPMENT", "ZoFontWinH2")
    title:SetAnchor(TOPLEFT, canvas, TOPLEFT, 18, 12)
    title:SetDimensions(230, 26)
    title:SetColor(0.94, 0.97, 1.00, 1)
    keepInside(title, 1, false)
    self.title = title

    local subtitle = makeLabel("EAS_GearLoadoutSubtitle", canvas, "Gear & Sets  /  updates as equipment changes", "ZoFontGameSmall")
    subtitle:SetAnchor(TOPLEFT, canvas, TOPLEFT, 19, 40)
    subtitle:SetDimensions(310, 18)
    subtitle:SetColor(0.55, 0.64, 0.75, 1)
    keepInside(subtitle, 1, false)
    self.subtitle = subtitle

    -- Live Equipment is display-only. Loadout workspace controls live in
    -- Gear & Sets (OPEN BUILDS) and on the Saved Builds overlay itself
    -- (CLOSE LOADOUTS), so this panel stays focused on equipped gear.
    self.playerButton = nil
    self.companionButton = nil
    self.closeButton = self:CreateActorButton("EAS_GearPreviewClose", "X", 654, 18, 30, function()
        self.manualClosed = true
        self:UpdateVisibility()
    end)

    -- Useful at-a-glance gear summary replaces the old filler status.
    local liveText = makeLabel("EAS_GearLoadoutLiveText", canvas, "", "ZoFontGameBold")
    liveText:SetAnchor(TOPRIGHT, canvas, TOPRIGHT, -66, 57)
    liveText:SetDimensions(350, 18)
    liveText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    liveText:SetColor(0.62, 0.78, 0.92, 1)
    keepInside(liveText, 1, false)
    self.live = nil
    self.liveText = liveText

    self.slotCards = {}
    for i,def in ipairs(SLOT_ROWS_LEFT) do
        local card = self:CreateSlotCard(def, 8, 104 + (i-1)*80)
        if card then self.slotCards[#self.slotCards+1] = card end
    end
    for i,def in ipairs(SLOT_ROWS_RIGHT) do
        local card = self:CreateSlotCard(def, 430, 104 + (i-1)*80)
        if card then self.slotCards[#self.slotCards+1] = card end
    end

    -- Center character stage. ESO does not expose a true custom 3D paper-doll
    -- to addons, so this uses the game-provided player silhouette with a
    -- layered accent treatment and the live character identity underneath.
    local portraitBG = makeBackdrop("EAS_GearPreviewPortraitBG", canvas)
    portraitBG:SetAnchor(TOPLEFT, canvas, TOPLEFT, 278, 104)
    portraitBG:SetDimensions(144, 370)
    portraitBG:SetCenterColor(0.022, 0.030, 0.044, 0.84)
    portraitBG:SetEdgeColor(0.22, 0.34, 0.48, 0.38)
    local portraitBorder = makeInsetBorder("EAS_GearPreviewPortraitInsetBorder", portraitBG, 2)
    portraitBorder:SetEdgeColor(0.22, 0.34, 0.48, 0.78)
    self.portraitBG = portraitBG
    self.portraitBorder = portraitBorder

    local modelHeader = makeLabel("EAS_GearPreviewModelHeader", portraitBG, "CURRENT CHARACTER", "ZoFontGameBold")
    modelHeader:SetAnchor(TOPLEFT, portraitBG, TOPLEFT, 8, 8)
    modelHeader:SetDimensions(128, 18)
    modelHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    modelHeader:SetColor(0.62, 0.72, 0.84, 1)
    self.modelHeader = modelHeader

    local portraitGlow = wm:CreateControl("EAS_GearPreviewPortraitGlow", portraitBG, CT_TEXTURE)
    portraitGlow:SetAnchor(CENTER, portraitBG, CENTER, 4, 9)
    portraitGlow:SetDimensions(132, 250)
    portraitGlow:SetColor(0.28, 0.62, 0.92, 0.12)
    portraitGlow:SetHidden(true)
    self.portraitGlow = portraitGlow

    local portrait = wm:CreateControl("EAS_GearPreviewPortrait", portraitBG, CT_TEXTURE)
    portrait:SetAnchor(CENTER, portraitBG, CENTER, 0, 5)
    portrait:SetDimensions(152, 264)
    portrait:SetColor(0.92, 0.86, 0.72, 0.96)
    portrait:SetHidden(true)
    self.portrait = portrait

    local portraitFallback = makeLabel("EAS_GearPreviewPortraitFallback", portraitBG, "CHARACTER PREVIEW\nUNAVAILABLE", "ZoFontGameBold")
    portraitFallback:SetAnchor(CENTER, portraitBG, CENTER, 0, 8)
    portraitFallback:SetDimensions(156, 44)
    portraitFallback:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    portraitFallback:SetColor(0.58, 0.65, 0.74, 1)
    portraitFallback:SetHidden(true)
    self.portraitFallback = portraitFallback

    local stageLine = makeBackdrop("EAS_GearPreviewStageLine", portraitBG)
    stageLine:SetAnchor(BOTTOMLEFT, portraitBG, BOTTOMLEFT, 18, -14)
    stageLine:SetDimensions(136, 1)
    stageLine:SetCenterColor(0.34, 0.68, 1.00, 0.42)
    stageLine:SetEdgeColor(0,0,0,0)
    self.stageLine = stageLine

    local actorName = makeLabel("EAS_GearPreviewActorName", canvas, "", "ZoFontWinH3")
    actorName:SetAnchor(TOPLEFT, canvas, TOPLEFT, 260, 484)
    actorName:SetDimensions(180, 28)
    actorName:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    actorName:SetColor(0.94, 0.97, 1.00, 1)
    keepInside(actorName, 1, false)
    self.actorName = actorName

    local actorMeta = makeLabel("EAS_GearPreviewActorMeta", canvas, "", "ZoFontGameSmall")
    actorMeta:SetAnchor(TOPLEFT, canvas, TOPLEFT, 260, 515)
    actorMeta:SetDimensions(180, 38)
    actorMeta:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    actorMeta:SetVerticalAlignment(TEXT_ALIGN_TOP)
    actorMeta:SetColor(0.56, 0.66, 0.78, 1)
    keepInside(actorMeta, 2, true)
    self.actorMeta = actorMeta

    local barPanel = makeBackdrop("EAS_GearPreviewBarPanel", canvas)
    barPanel:SetAnchor(TOPLEFT, canvas, TOPLEFT, 278, 562)
    barPanel:SetDimensions(144, 80)
    barPanel:SetCenterColor(0.030, 0.040, 0.056, 0.80)
    barPanel:SetEdgeColor(0.20, 0.28, 0.39, 0.34)
    local barBorder = makeInsetBorder("EAS_GearPreviewBarInsetBorder", barPanel, 2)
    barBorder:SetEdgeColor(0.20, 0.28, 0.39, 0.74)
    self.barPanel = barPanel
    self.barBorder = barBorder

    local barTitle = makeLabel("EAS_GearPreviewBarTitle", barPanel, "ACTIVE WEAPON BAR", "ZoFontGameSmall")
    barTitle:SetAnchor(TOPLEFT, barPanel, TOPLEFT, 8, 8)
    barTitle:SetDimensions(128, 16)
    barTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    barTitle:SetColor(0.52, 0.62, 0.74, 1)
    keepInside(barTitle, 1, false)
    self.barTitle = barTitle

    local barValue = makeLabel("EAS_GearPreviewBarValue", barPanel, "FRONT", "ZoFontGameBold")
    barValue:SetAnchor(TOPLEFT, barPanel, TOPLEFT, 8, 29)
    barValue:SetDimensions(128, 20)
    barValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    barValue:SetColor(0.44, 0.78, 1.00, 1)
    keepInside(barValue, 1, false)
    self.barValue = barValue

    local countLabel = makeLabel("EAS_GearPreviewCount", barPanel, "", "ZoFontGameSmall")
    countLabel:SetAnchor(TOPLEFT, barPanel, TOPLEFT, 8, 54)
    countLabel:SetDimensions(128, 16)
    countLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    countLabel:SetColor(0.50, 0.58, 0.68, 1)
    keepInside(countLabel, 1, false)
    self.countLabel = countLabel

    local footer = makeLabel("EAS_GearPreviewFooter", canvas, "Hover your Gear & Sets workspace while this panel tracks the equipped build.", "ZoFontGameSmall")
    footer:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 22, -12)
    footer:SetDimensions(BASE_W-44, 16)
    footer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    footer:SetColor(0.44, 0.52, 0.62, 1)
    keepInside(footer, 1, false)
    self.footer = footer

    window:SetHandler("OnMoveStop", function(control)
        local sv = self:EnsureSaved()
        sv.left, sv.top = control:GetLeft(), control:GetTop()
    end)
    window:SetHandler("OnResizeStart", function(control)
        control:SetHandler("OnUpdate", function(_, timeMs)
            local now = tonumber(timeMs) or 0
            if not self.lastScaleUpdate or now - self.lastScaleUpdate > 40 then
                self.lastScaleUpdate = now
                self:UpdateScale()
            end
        end)
    end)
    window:SetHandler("OnResizeStop", function(control)
        control:SetHandler("OnUpdate", nil)
        self:NormalizeWindowSize(true)
    end)

    self.actor = "PLAYER"
    self:UpdateScale()
    self:ApplyTheme()
end

function G:SetActor(actor)
    self.actor = "PLAYER"
    self:EnsureSaved().actor = "PLAYER"
    self:Refresh()
end

function G:RefreshSlot(card, bagId, activePair)
    if not card or not card.def or bagId == nil then return false end
    local slot = card.def.slot
    local link = safe(GetItemLink, "", bagId, slot, LINK_STYLE_DEFAULT or 0) or ""
    local hasItem = link ~= ""
    card.easItemLink = link

    if hasItem then
        local icon = safe(GetItemLinkIcon, "", link) or ""
        if icon == "" then icon = safe(GetItemInfo, "", bagId, slot) or "" end
        if icon ~= "" then
            card.icon:SetTexture(icon)
            card.icon:SetHidden(false)
        else
            card.icon:SetHidden(true)
        end

        local itemName = safe(GetItemLinkName, "", link) or ""
        if itemName == "" then itemName = "Equipped Item" end
        local itemLine1, itemLine2 = splitItemName(itemName, 23)
        card.easFullItemName = itemName
        card.itemLabel:SetText(itemLine1)
        if card.itemLabel2 then card.itemLabel2:SetText(itemLine2) end
        card.itemLabel:SetColor(0.92, 0.95, 0.99, 1)
        if card.itemLabel2 then card.itemLabel2:SetColor(0.92, 0.95, 0.99, 1) end
        if card.typeLabel then
            card.typeLabel:SetText(equipmentTypeText(link, card.def))
            card.typeLabel:SetColor(0.88, 0.72, 0.34, 1)
        end

        local hasSet, setName = safe(GetItemLinkSetInfo, false, link, true)
        if hasSet and setName and setName ~= "" then card.setLabel:SetText(setName) else card.setLabel:SetText("") end

        local r,g,b = qualityColor(link)
        card.iconBG:SetEdgeColor(r,g,b,0.92)
    else
        card.icon:SetHidden(true)
        card.easItemLink = ""
        card.easFullItemName = "EMPTY"
        card.itemLabel:SetText("EMPTY")
        if card.itemLabel2 then card.itemLabel2:SetText("") end
        card.itemLabel:SetColor(0.48, 0.53, 0.61, 1)
        if card.itemLabel2 then card.itemLabel2:SetColor(0.48, 0.53, 0.61, 1) end
        if card.typeLabel then card.typeLabel:SetText("") end
        card.setLabel:SetText("")
        card.iconBG:SetEdgeColor(0.23, 0.28, 0.35, 0.55)
    end

    if self.actor == "PLAYER" and card.def.bar then
        local active = (card.def.bar == "FRONT" and activePair == (ACTIVE_WEAPON_PAIR_MAIN or 1)) or
                       (card.def.bar == "BACK" and activePair == (ACTIVE_WEAPON_PAIR_BACKUP or 2))
        if active then
            card:SetEdgeColor(0.38, 0.76, 1.00, 0.42)
            if card.insetBorder then card.insetBorder:SetEdgeColor(0.38, 0.76, 1.00, 0.96) end
            card.slotLabel:SetColor(0.45, 0.82, 1.00, 1)
        else
            card:SetEdgeColor(0.20, 0.27, 0.36, 0.36)
            if card.insetBorder then card.insetBorder:SetEdgeColor(0.20, 0.27, 0.36, 0.78) end
            card.slotLabel:SetColor(0.52, 0.62, 0.75, 1)
        end
    else
        card:SetEdgeColor(0.20, 0.27, 0.36, 0.36)
        if card.insetBorder then card.insetBorder:SetEdgeColor(0.20, 0.27, 0.36, 0.78) end
        card.slotLabel:SetColor(0.52, 0.62, 0.75, 1)
    end

    return hasItem
end

function G:ClearSlots(message)
    for _,card in ipairs(self.slotCards or {}) do
        if card.icon then card.icon:SetHidden(true) end
        card.easItemLink = ""
        if card.itemLabel then
            card.easFullItemName = message or "EMPTY"
            card.itemLabel:SetText(message or "EMPTY")
            if card.itemLabel2 then card.itemLabel2:SetText("") end
            card.itemLabel:SetColor(0.48, 0.53, 0.61, 1)
            if card.itemLabel2 then card.itemLabel2:SetColor(0.48, 0.53, 0.61, 1) end
        end
        if card.typeLabel then card.typeLabel:SetText("") end
        if card.setLabel then card.setLabel:SetText("") end
        if card.iconBG then card.iconBG:SetEdgeColor(0.23, 0.28, 0.35, 0.55) end
        card:SetEdgeColor(0.20, 0.27, 0.36, 0.36)
        if card.insetBorder then card.insetBorder:SetEdgeColor(0.20, 0.27, 0.36, 0.78) end
    end
end

function G:ApplyTheme()
    if not self.window then return end
    local t = self:GetTheme()
    local a = t.accent or t.edge or {0.43,0.68,0.96,1}

    if self.bg then self.bg:SetCenterColor(0.014,0.018,0.028,0.88) self.bg:SetEdgeColor(a[1],a[2],a[3],0.30) end
    if self.frameBorder then self.frameBorder:SetEdgeColor(a[1],a[2],a[3],0.86) end
    if self.top then self.top:SetCenterColor(0.024,0.028,0.040,0.92) self.top:SetEdgeColor(0.16,0.20,0.28,0.48) end
    if self.accent then self.accent:SetCenterColor(a[1],a[2],a[3],0.98) self.accent:SetEdgeColor(0,0,0,0) end
    if self.title then self.title:SetColor(0.94,0.97,1.00,1) end
    if self.subtitle then self.subtitle:SetColor(0.62,0.70,0.80,1) end
    if self.live then self.live:SetColor(a[1],a[2],a[3],1) end
    if self.liveText then self.liveText:SetColor(0.62,0.70,0.80,1) end
    if self.portraitBG then self.portraitBG:SetCenterColor(0.042,0.052,0.070,0.86) self.portraitBG:SetEdgeColor(a[1],a[2],a[3],0.28) end
    if self.portraitBorder then self.portraitBorder:SetEdgeColor(a[1],a[2],a[3],0.82) end
    if self.modelHeader then self.modelHeader:SetColor(a[1],a[2],a[3],0.95) end
    if self.portraitGlow then self.portraitGlow:SetColor(a[1],a[2],a[3],0.16) end
    if self.stageLine then self.stageLine:SetCenterColor(a[1],a[2],a[3],0.48) end
    if self.portraitFallback then self.portraitFallback:SetColor(0.58,0.65,0.74,1) end
    if self.barPanel then self.barPanel:SetCenterColor(0.042,0.052,0.070,0.82) self.barPanel:SetEdgeColor(a[1],a[2],a[3],0.18) end
    if self.barBorder then self.barBorder:SetEdgeColor(a[1],a[2],a[3],0.72) end
    if self.barTitle then self.barTitle:SetColor(0.62,0.70,0.80,1) end
    if self.barValue then self.barValue:SetColor(a[1],a[2],a[3],1) end
    if self.actorName then self.actorName:SetColor(0.94,0.97,1.00,1) end
    if self.actorMeta then self.actorMeta:SetColor(0.62,0.70,0.80,1) end
    if self.footer then self.footer:SetColor(0.52,0.60,0.70,1) end

    for _,card in ipairs(self.slotCards or {}) do
        card:SetCenterColor(0.042,0.052,0.070,0.80)
        if card.insetBorder then card.insetBorder:SetEdgeColor(0.24,0.32,0.43,0.80) end
        if card.slotLabel then card.slotLabel:SetColor(0.62,0.70,0.80,1) end
    end

    self:SetButtonState(self.playerButton, self.actor == "PLAYER", true)
    self:SetButtonState(self.companionButton, self.actor == "COMPANION", self:IsCompanionGearSupported())
    self:SetButtonState(self.closeButton, false, true)
end

local BODY_ARMOR_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST,
    EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
}

function G:BuildGearSummary(bagId, activePair)
    if bagId == nil then return "" end
    local light, medium, heavy = 0, 0, 0
    for _, slot in ipairs(BODY_ARMOR_SLOTS) do
        local link = safe(GetItemLink, "", bagId, slot, LINK_STYLE_DEFAULT or 0) or ""
        if link ~= "" then
            local armorType = safe(GetItemLinkArmorType, nil, link)
            if armorType == rawget(_G, "ARMORTYPE_LIGHT") then light = light + 1
            elseif armorType == rawget(_G, "ARMORTYPE_MEDIUM") then medium = medium + 1
            elseif armorType == rawget(_G, "ARMORTYPE_HEAVY") then heavy = heavy + 1 end
        end
    end

    local armorText
    if light > 0 and medium == 0 and heavy == 0 then armorText = tostring(light) .. " LIGHT"
    elseif medium > 0 and light == 0 and heavy == 0 then armorText = tostring(medium) .. " MEDIUM"
    elseif heavy > 0 and light == 0 and medium == 0 then armorText = tostring(heavy) .. " HEAVY"
    else armorText = string.format("%dL/%dM/%dH", light, medium, heavy) end

    local seen, setCount = {}, 0
    for _, card in ipairs(self.slotCards or {}) do
        local slot = card.def and card.def.slot
        if slot ~= nil then
            local link = safe(GetItemLink, "", bagId, slot, LINK_STYLE_DEFAULT or 0) or ""
            if link ~= "" then
                local hasSet, setName = safe(GetItemLinkSetInfo, false, link, true)
                setName = cleanName(setName)
                if hasSet and setName ~= "" and not seen[setName] then
                    seen[setName] = true
                    setCount = setCount + 1
                end
            end
        end
    end

    local bar = activePair == (ACTIVE_WEAPON_PAIR_BACKUP or 2) and "BACK" or "FRONT"
    return string.format("ARMOR %s  •  SETS %d  •  %s BAR", armorText, setCount, bar)
end

function G:Refresh()
    if not self.window then return end
    self:ApplyTheme()

    local companionAvailable = self:IsCompanionAvailable()
    local companionSupported = self:IsCompanionGearSupported()
    local bagId, unitTag = self:GetActorBag()

    self:SetButtonState(self.playerButton, self.actor == "PLAYER", true)
    self:SetButtonState(self.companionButton, self.actor == "COMPANION", companionSupported)
    self:SetButtonState(self.closeButton, false, true)

    if self.actor == "COMPANION" then
        local companionId = self:GetCompanionDefId()
        local name = ""
        if companionId > 0 and type(GetCompanionName) == "function" then
            name = cleanName(safe(GetCompanionName, "", companionId))
        end
        if name == "" and type(GetUnitName) == "function" then
            name = cleanName(safe(GetUnitName, "", "companion"))
        end

        if not companionAvailable then
            self.actorName:SetText("NO ACTIVE COMPANION")
            self.actorMeta:SetText("Summon a companion to view\nits currently equipped gear.")
            self.portrait:SetHidden(true)
            if self.portraitGlow then self.portraitGlow:SetHidden(true) end
            if self.portraitFallback then self.portraitFallback:SetHidden(false) end
            self:ClearSlots("--")
            if self.countLabel then self.countLabel:SetText("No active companion") end
            if self.barValue then self.barValue:SetText("COMPANION") end
            return
        end

        if name == "" then name = "Companion" end
        self.actorName:SetText(name)

        local level = 0
        if type(GetActiveCompanionLevelInfo) == "function" then
            level = tonumber(safe(GetActiveCompanionLevelInfo, 0)) or 0
        end
        local raceName = ""
        local raceId = companionId > 0 and (tonumber(safe(GetCompanionRace, 0, companionId)) or 0) or 0
        local gender = companionId > 0 and safe(GetCompanionGender, GENDER_NEUTER or 0, companionId) or (GENDER_NEUTER or 0)
        if raceId > 0 and type(GetRaceName) == "function" then
            raceName = cleanName(safe(GetRaceName, "", gender, raceId))
        end
        local identityLine = raceName
        if level > 0 then
            identityLine = identityLine ~= "" and (identityLine .. "  /  Level " .. tostring(level)) or ("Level " .. tostring(level))
        end
        self.actorMeta:SetText((identityLine ~= "" and (identityLine .. "\n") or "") .. "Companion equipment")

        local silhouette = ""
        -- Prefer ESO's race/gender character silhouette so the center stage
        -- looks like an actual character instead of the broad generic unit mask.
        if raceId > 0 and type(GetRaceAndGenderSilhouetteTexture) == "function" then
            silhouette = safe(GetRaceAndGenderSilhouetteTexture, "", raceId, gender) or ""
        end
        if silhouette == "" and type(DoesUnitExist) == "function" and safe(DoesUnitExist, false, "companion") == true then
            silhouette = safe(GetUnitSilhouetteTexture, "", "companion") or ""
        end
        if silhouette ~= "" then
            self.portrait:SetTexture(silhouette)
            self.portrait:SetHidden(false)
            if self.portraitGlow then
                self.portraitGlow:SetTexture(silhouette)
                self.portraitGlow:SetHidden(false)
            end
            if self.portraitFallback then self.portraitFallback:SetHidden(true) end
        else
            self.portrait:SetHidden(true)
            if self.portraitGlow then self.portraitGlow:SetHidden(true) end
            if self.portraitFallback then self.portraitFallback:SetHidden(false) end
        end
    else
        local name = cleanName(safe(GetUnitName, "", "player"))
        if name == "" then name = "Player" end
        self.actorName:SetText(name)

        local level = tonumber(safe(GetUnitLevel, 0, "player")) or 0
        local cp = tonumber(safe(GetUnitChampionPoints, 0, "player")) or 0
        local race = cleanName(safe(GetUnitRace, "", "player"))
        local className = cleanName(safe(GetUnitClass, "", "player"))
        local identityLine = ""
        if race ~= "" and className ~= "" then identityLine = race .. " " .. className
        elseif race ~= "" then identityLine = race
        elseif className ~= "" then identityLine = className end
        local progressLine = ""
        if cp > 0 then progressLine = "Champion " .. tostring(cp)
        elseif level > 0 then progressLine = "Level " .. tostring(level) end
        if identityLine ~= "" and progressLine ~= "" then
            self.actorMeta:SetText(identityLine .. "\n" .. progressLine)
        elseif identityLine ~= "" then
            self.actorMeta:SetText(identityLine)
        else
            self.actorMeta:SetText(progressLine ~= "" and progressLine or "Player equipment")
        end

        local silhouette = ""
        local raceId = tonumber(safe(GetUnitRaceId, 0, "player")) or 0
        local gender = safe(GetUnitGender, GENDER_NEUTER or 0, "player")
        -- Prefer ESO's native race/gender silhouette. The generic unit
        -- silhouette remains only as a fallback for unusual cases.
        if raceId > 0 and type(GetRaceAndGenderSilhouetteTexture) == "function" then
            silhouette = safe(GetRaceAndGenderSilhouetteTexture, "", raceId, gender) or ""
        end
        if silhouette == "" then
            silhouette = safe(GetUnitSilhouetteTexture, "", "player") or ""
        end
        if silhouette ~= "" then
            self.portrait:SetTexture(silhouette)
            self.portrait:SetHidden(false)
            if self.portraitGlow then
                self.portraitGlow:SetTexture(silhouette)
                self.portraitGlow:SetHidden(false)
            end
            if self.portraitFallback then self.portraitFallback:SetHidden(true) end
        else
            self.portrait:SetHidden(true)
            if self.portraitGlow then self.portraitGlow:SetHidden(true) end
            if self.portraitFallback then self.portraitFallback:SetHidden(false) end
        end
    end

    local activePair = ACTIVE_WEAPON_PAIR_MAIN or 1
    if self.actor == "PLAYER" and type(GetActiveWeaponPairInfo) == "function" then
        activePair = safe(GetActiveWeaponPairInfo, ACTIVE_WEAPON_PAIR_MAIN or 1)
    end

    local equipped = 0
    if bagId ~= nil then
        for _,card in ipairs(self.slotCards or {}) do
            if self:RefreshSlot(card, bagId, activePair) then equipped = equipped + 1 end
        end
    else
        self:ClearSlots("--")
    end
    if self.countLabel then self.countLabel:SetText(string.format("%d equipped slots", equipped)) end
    if self.liveText then
        if self.actor == "PLAYER" then
            self.liveText:SetText(self:BuildGearSummary(bagId, activePair))
        else
            self.liveText:SetText("COMPANION EQUIPMENT")
        end
    end

    if self.barValue then
        if self.actor == "COMPANION" then
            self.barValue:SetText("COMPANION")
        elseif activePair == (ACTIVE_WEAPON_PAIR_BACKUP or 2) then
            self.barValue:SetText("BACK BAR")
        else
            self.barValue:SetText("FRONT BAR")
        end
    end
end

function G:ScheduleRefresh(delay)
    delay = tonumber(delay) or 35
    if self.refreshPending then return end
    self.refreshPending = true
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            self.refreshPending = false
            self:Refresh()
        end, delay)
    else
        self.refreshPending = false
        self:Refresh()
    end
end

function G:UpdateVisibility()
    if not self.window then return end
    local shouldShow = ((self.gearTabActive == true and self.journalVisible == true) or self.loadoutMode == true)
        and self.manualClosed ~= true
    self.window:SetHidden(not shouldShow)
    if shouldShow then self:Refresh() end
end

-- Saved Builds can detach from the Tamriel Codex.  While this mode is active,
-- Live Equipment remains visible even though the Codex itself has been closed.
function G:SetLoadoutMode(active)
    self.loadoutMode = active == true
    if self.loadoutMode then self.manualClosed = false end
    self:UpdateVisibility()
end

function G:OnGearTabChanged(isGear)
    isGear = isGear == true
    if isGear and self.gearTabActive ~= true then self.manualClosed = false end
    self.gearTabActive = isGear
    self:UpdateVisibility()
end

function G:SetJournalVisible(visible)
    self.journalVisible = visible == true
    if not self.journalVisible then self.manualClosed = false end
    self:UpdateVisibility()
end

function G:RegisterEvents()
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        local wornName = EPC.name .. "_GearPreviewPlayerWorn"
        EPC.Runtime:RegisterEvent("GearLoadoutOverlay", "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if self.actor == "PLAYER" then self:ScheduleRefresh(30) end
        end)
        if REGISTER_FILTER_BAG_ID and BAG_WORN ~= nil then
            EVENT_MANAGER:AddFilterForEvent(wornName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
        end

        if BAG_COMPANION_WORN ~= nil then
            local companionName = EPC.name .. "_GearPreviewCompanionWorn"
            EPC.Runtime:RegisterEvent("GearLoadoutOverlay", "Companion", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
                if self.actor == "COMPANION" then self:ScheduleRefresh(30) end
            end)
            if REGISTER_FILTER_BAG_ID then
                EVENT_MANAGER:AddFilterForEvent(companionName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_COMPANION_WORN)
            end
        end
    end

    if EVENT_INVENTORY_FULL_UPDATE then
        EPC.Runtime:RegisterEvent("GearLoadoutOverlay", "FullInventory", EVENT_INVENTORY_FULL_UPDATE, function() self:ScheduleRefresh(50) end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EPC.Runtime:RegisterEvent("GearLoadoutOverlay", "WeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() self:ScheduleRefresh(20) end)
    end
    if EVENT_ACTIVE_COMPANION_STATE_CHANGED then
        EPC.Runtime:RegisterEvent("GearLoadoutOverlay", "CompanionState", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
            self:ScheduleRefresh(40)
        end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("GearLoadoutOverlay", "Activated", EVENT_PLAYER_ACTIVATED, function() self:ScheduleRefresh(80) end)
    end
end

function G:Initialize()
    self:EnsureSaved()
    self:Create()
    self:RegisterEvents()
    self.gearTabActive = false
    self.journalVisible = false
    self:Refresh()
end
