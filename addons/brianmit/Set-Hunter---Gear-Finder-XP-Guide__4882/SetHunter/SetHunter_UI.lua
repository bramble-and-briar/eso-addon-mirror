-- SetHunter_UI.lua : floating window in ESO's menu style (same look as Command
-- Codex), plus a small movable "Set Hunter" button that opens / minimizes it.
-- Category tree on the left, sets or guide rows on the right with an info panel
-- above them, action buttons at the bottom.

local S = SetHunter
local L = S.L
local D = S.DATA
local ui = { reachGen = 1 }

local WIN_W, WIN_H = 860, 660           -- starting size
local MIN_W, MIN_H = 780, 540           -- the window can be resized between these
local MAX_W, MAX_H = 1600, 1200
local PAD = 28
local TREE_W = 250

local TREE_CATEGORY, TREE_SUB, TREE_HEADER = 1, 2, 3
local ROW_SET, ROW_HEADER, ROW_INFO, ROW_ITEM = 1, 2, 3, 4

-- ESO's own text colors (same as Command Codex).
local COLOR = {
    normal   = "C5C29E",
    selected = "FFFFFF",
    header   = "E8DFAF",
    theme    = "C08A4E",   -- our own accent (command codex keeps the gold)
    dim      = "8F8B7A",
    good     = "8FD17F",
    bad      = "FF6B5A",
    warn     = "E8A33D",   -- orange: something incomplete (not all characters seen yet)
    accent   = "7FB2E5",
}
local STAR_ON = { 1, 1, 1, 1 }
local STAR_OFF = { 0.7, 0.7, 0.7, 0.25 }

local TEX_ROUNDED = "SetHunter/Textures/rounded_fill.dds"
local TEX_CIRCLE = "SetHunter/Textures/circle.dds"
local TEX_RING = "SetHunter/Textures/circle_ring.dds"
local TEX_ICON = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds"
local TEX_QUEUE = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds"
local TEX_NORMAL = "EsoUI/Art/LFG/LFG_normalDungeon_up.dds"
local TEX_VETERAN = "EsoUI/Art/LFG/LFG_veteranDungeon_up.dds"

local ARROW_OPEN = "EsoUI/Art/Buttons/tree_open_up.dds"
local ARROW_CLOSED = "EsoUI/Art/Buttons/tree_closed_up.dds"

local TEX_BAG = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds"
local TEX_BANK = "EsoUI/Art/Icons/ServiceMapPins/servicepin_bank.dds"   -- the bank icon on the map
local TEX_STAR = "EsoUI/Art/Collections/Favorite_StarOnly.dds"

-- icon: ESO's own textures (main menu, map and group finder icons).
local CATEGORIES = {
    { header = "TREE_SETS" },
    -- The compass marker of your tracked quest.
    { view = "here",      key = "CAT_HERE",      icon = "EsoUI/Art/Compass/quest_icon_assisted.dds" },
    { view = "overview",  key = "CAT_OVERVIEW",  icon = "EsoUI/Art/MainMenu/menuBar_collections_up.dds" },
    { view = "wishlist",  key = "CAT_WISHLIST",  icon = TEX_STAR, expand = "wish" },
    { view = "traithunt", key = "CAT_HUNT",      icon = "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds" },
    { view = "almost",    key = "CAT_ALMOST",    icon = "EsoUI/Art/MainMenu/menuBar_skills_up.dds" },
    { view = "recent",    key = "CAT_RECENT",    icon = TEX_BAG },
    { view = "dungeon",   key = "CAT_DUNGEON",   icon = TEX_QUEUE, kind = "dungeon" },
    { view = "trial",     key = "CAT_TRIAL",     icon = "EsoUI/Art/Icons/poi/poi_raiddungeon_complete.dds", kind = "trial" },
    { view = "arena",     key = "CAT_ARENA",     icon = "EsoUI/Art/Icons/poi/poi_solotrial_complete.dds", kind = "arena" },
    { view = "overland",  key = "CAT_OVERLAND",  icon = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds", kind = "overland" },
    { view = "pvp",       key = "CAT_PVP",       icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds", kind = "pvp" },
    { view = "other",     key = "CAT_OTHER",     icon = "EsoUI/Art/MainMenu/menuBar_journal_up.dds", kind = "other" },
    { view = "crafted",   key = "CAT_CRAFTED",   icon = "EsoUI/Art/Icons/ServiceMapPins/servicepin_smithy.dds" },
    { view = "monster",   key = "CAT_MONSTER",   icon = TEX_VETERAN },
    { header = "TREE_ITEMS" },
    { view = "items",     key = "CAT_ITEMS",     icon = TEX_BAG },
    { view = "items_new", key = "CAT_ITEMS_NEW", icon = "EsoUI/Art/MainMenu/menuBar_collections_up.dds" },
    { view = "items_decon", key = "CAT_ITEMS_DECON", icon = "EsoUI/Art/Crafting/enchantment_tabIcon_deconstruction_up.dds" },
    { view = "items_dupes", key = "CAT_ITEMS_DUPES", icon = "EsoUI/Art/Crafting/smithing_tabIcon_refine_up.dds" },
    { view = "items_trade", key = "CAT_ITEMS_TRADE", icon = "EsoUI/Art/MainMenu/menuBar_market_up.dds" },
    { view = "items_low",   key = "CAT_ITEMS_LOW",   icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds" },
    -- groupings: one sub-entry per trait / slot / quality / ... (see ITEM_MODES groupOf)
    { view = "items_trait", key = "CAT_ITEMS_TRAIT", icon = "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds", expand = "groups" },
    { view = "items_slot",  key = "CAT_ITEMS_SLOT",  icon = TEX_ICON, expand = "groups" },
    { view = "items_quality", key = "CAT_ITEMS_QUALITY", icon = TEX_STAR, expand = "groups" },
    { view = "items_weight", key = "CAT_ITEMS_WEIGHT", icon = "EsoUI/Art/MainMenu/menuBar_character_up.dds", expand = "groups" },
    { view = "items_settype", key = "CAT_ITEMS_SETTYPE", icon = "EsoUI/Art/MainMenu/menuBar_journal_up.dds", expand = "groups" },
    { header = "TREE_XP" },
    { view = "xp_spots",  key = "CAT_XP_SPOTS",  icon = "EsoUI/Art/MainMenu/menuBar_skills_up.dds" },
    { view = "xp_boosts", key = "CAT_XP_BOOSTS", icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds" },
    { view = "xp_setup",  key = "CAT_XP_SETUP",  icon = "EsoUI/Art/MainMenu/menuBar_character_up.dds" },
    { view = "xp_session", key = "CAT_XP_SESSION", icon = "SetHunter/Textures/tab_xp.dds" },
    { view = "xp_daily",  key = "CAT_XP_DAILY",  icon = TEX_QUEUE },
}

-- Breadcrumb above the title: which section a view belongs to.
local SECTION_OF = {
    here = "TREE_SETS", wishlist = "TREE_SETS", traithunt = "TREE_SETS", overview = "TREE_SETS",
    almost = "TREE_SETS", recent = "TREE_SETS", crafted = "TREE_SETS", dungeon = "TREE_SETS", trial = "TREE_SETS",
    arena = "TREE_SETS", overland = "TREE_SETS", pvp = "TREE_SETS", other = "TREE_SETS",
    monster = "TREE_SETS", items = "TREE_ITEMS", items_new = "TREE_ITEMS", items_decon = "TREE_ITEMS", items_trait = "TREE_ITEMS",
    items_dupes = "TREE_ITEMS", items_trade = "TREE_ITEMS", items_low = "TREE_ITEMS", items_slot = "TREE_ITEMS",
    items_quality = "TREE_ITEMS", items_weight = "TREE_ITEMS", items_settype = "TREE_ITEMS",
    xp_spots = "TREE_XP", xp_boosts = "TREE_XP", xp_setup = "TREE_XP", xp_session = "TREE_XP", xp_daily = "TREE_XP",
}

local RULE_BY_KIND = {
    dungeon = "RULE_DUNGEON", trial = "RULE_TRIAL", arena = "RULE_ARENA",
    overland = "RULE_OVERLAND", pvp = "RULE_PVP", other = "RULE_OTHER",
}

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function SetHexColor(control, hex, alpha)
    local r, g, b = HexToRGB(hex)
    control:SetColor(r, g, b, alpha or 1)
end

local function Colorize(hex, text)
    return "|c" .. hex .. text .. "|r"
end

local function MakeLabel(name, parent, font, width, height, hex)
    local l = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font)
    l:SetDimensions(width, height)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    SetHexColor(l, hex or COLOR.normal)
    return l
end

-- Small clickable text (x, -) that lights up on hover, with a tooltip.
local function MakeTextButton(name, parent, text, font, size, tooltip, onClick)
    local b = MakeLabel(name, parent, font, size, size, COLOR.dim)
    b:SetText(text)
    b:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    b:SetMouseEnabled(true)
    b:SetDrawLevel(6)
    b:SetHandler("OnMouseEnter", function(self)
        SetHexColor(self, COLOR.selected)
        if tooltip then
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, tooltip)
        end
    end)
    b:SetHandler("OnMouseExit", function(self)
        SetHexColor(self, COLOR.dim)
        ClearTooltip(InformationTooltip)
    end)
    b:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            ClearTooltip(InformationTooltip)
            onClick()
        end
    end)
    return b
end

-- Dark text field with a thin bronze edge; the edit box inside is ESO's own template.
local function MakeEdit(name, parent, width, hint)
    local box = WINDOW_MANAGER:CreateControl(name .. "BG", parent, CT_BACKDROP)
    box:SetDimensions(width, 28)
    box:SetCenterColor(0, 0, 0, 0.55)
    box:SetEdgeColor(0.36, 0.35, 0.27, 1)
    box:SetEdgeTexture("", 1, 1, 1)
    box:SetMouseEnabled(true)

    local edit = WINDOW_MANAGER:CreateControlFromVirtual(name, box, "ZO_DefaultEditForBackdrop")
    if hint and edit.SetDefaultText then edit:SetDefaultText(hint) end
    box:SetHandler("OnMouseUp", function() edit:TakeFocus() end)
    return box, edit
end

-- ESO buttons react to every mouse button by default; ours only to the left one.
local function LeftClickOnly(button)
    if button.EnableMouseButton then
        button:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, false)
        button:EnableMouseButton(MOUSE_BUTTON_INDEX_MIDDLE, false)
    end
end

local function MakeCheck(name, parent, text, getter, setter, tooltip)
    local cb = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_CheckButton")
    ZO_CheckButton_SetLabelText(cb, text)
    LeftClickOnly(cb)
    local label = cb.label or GetControl(cb, "Label")
    local labelClick = label and label:GetHandler("OnMouseUp")
    if labelClick then
        label:SetHandler("OnMouseUp", function(self, button, ...)
            if button == MOUSE_BUTTON_INDEX_LEFT then labelClick(self, button, ...) end
        end)
    end
    ZO_CheckButton_SetCheckState(cb, getter())
    ZO_CheckButton_SetToggleFunction(cb, function(_, checked) setter(checked) end)
    if tooltip then
        cb:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -6, TOPLEFT)
            SetTooltipText(InformationTooltip, tooltip)
        end)
        cb:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    end
    return cb
end

local function MakeButton(name, parent, text, width, onClick)
    local b = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    b:SetDimensions(width, 28)
    b:SetText(text)
    LeftClickOnly(b)
    b:SetHandler("OnClicked", onClick)
    return b
end

-- Panel background with a thin border. Solid by default; pass fadeW/fadeH to fade
-- the edges out instead (alpha steps like the dividers, corners use x-alpha * y-alpha).
-- everything is anchored to the window edges, so it follows resizing by itself
local STEPS_X, STEPS_Y = 14, 8
local BORDER_ALPHA = 0.45
local function MakeFadePanel(win, prefix, fadeW, fadeH)
    -- 0.95: a hint of the world shows through, text stays easy to read
    local FADE_W, FADE_H, ALPHA = fadeW or 0, fadeH or 0, 0.95
    -- thin see-through theme line around the whole panel
    local border = WINDOW_MANAGER:CreateControl(prefix .. "Border", win, CT_BACKDROP)
    border:SetAnchorFill(win)
    border:SetCenterColor(0, 0, 0, 0)
    border:SetEdgeTexture("", 1, 1, 1)
    local br, bg, bb = HexToRGB(COLOR.theme)
    border:SetEdgeColor(br, bg, bb, BORDER_ALPHA)
    border:SetMouseEnabled(false)
    if FADE_W == 0 and FADE_H == 0 then
        local solid = WINDOW_MANAGER:CreateControl(prefix .. "BG", win, CT_TEXTURE)
        solid:SetColor(0, 0, 0, ALPHA)
        solid:SetAnchorFill(win)
        solid:SetDrawLayer(DL_BACKGROUND)
        solid:SetMouseEnabled(false)
        return
    end
    local sx, sy = FADE_W / STEPS_X, FADE_H / STEPS_Y
    local n = 0
    local function Part(alpha)
        n = n + 1
        local t = WINDOW_MANAGER:CreateControl(prefix .. "BG" .. n, win, CT_TEXTURE)
        t:SetColor(0, 0, 0, ALPHA * alpha)
        t:SetDrawLayer(DL_BACKGROUND)
        t:SetMouseEnabled(false)
        return t
    end
    local function Ease(i, steps) return (i / steps) ^ 1.4 end

    local center = Part(1)
    center:SetAnchor(TOPLEFT, win, TOPLEFT, FADE_W, FADE_H)
    center:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -FADE_W, -FADE_H)

    for i = 1, STEPS_X do
        local a, x = Ease(i, STEPS_X), (i - 1) * sx
        local left = Part(a)
        left:SetAnchor(TOPLEFT, win, TOPLEFT, x, FADE_H)
        left:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, x, -FADE_H)
        left:SetWidth(sx)
        local right = Part(a)
        right:SetAnchor(TOPRIGHT, win, TOPRIGHT, -x, FADE_H)
        right:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -x, -FADE_H)
        right:SetWidth(sx)
    end
    for j = 1, STEPS_Y do
        local a, y = Ease(j, STEPS_Y), (j - 1) * sy
        local top = Part(a)
        top:SetAnchor(TOPLEFT, win, TOPLEFT, FADE_W, y)
        top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -FADE_W, y)
        top:SetHeight(sy)
        local bottom = Part(a)
        bottom:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, FADE_W, -y)
        bottom:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -FADE_W, -y)
        bottom:SetHeight(sy)
    end
    for i = 1, STEPS_X do
        for j = 1, STEPS_Y do
            local a = Ease(i, STEPS_X) * Ease(j, STEPS_Y)
            local x, y = (i - 1) * sx, (j - 1) * sy
            for _, c in ipairs({ { TOPLEFT, x, y }, { TOPRIGHT, -x, y }, { BOTTOMLEFT, x, -y }, { BOTTOMRIGHT, -x, -y } }) do
                local t = Part(a)
                t:SetDimensions(sx, sy)
                t:SetAnchor(c[1], win, c[1], c[2], c[3])
            end
        end
    end
end

-- Theme line that fades out at both ends (ESO's menu divider).
-- vertex colors didn't show on plain 2px textures, so the fade is built from small
-- steps of rising alpha instead
local FADE_STEPS, FADE_PART = 24, 0.22
local function MakeDivider(name, parent, width)
    local divider = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    divider:SetDimensions(width, 2)
    local r, g, b = HexToRGB(COLOR.theme)
    local function Seg(suffix, alpha)
        local t = WINDOW_MANAGER:CreateControl(name .. suffix, divider, CT_TEXTURE)
        t:SetColor(r, g, b, alpha)
        t:SetHeight(2)
        t:SetMouseEnabled(false)
        return t
    end
    local lefts, rights = {}, {}
    for i = 1, FADE_STEPS do
        local a = (i / FADE_STEPS) ^ 1.6   -- eased so the tips really vanish
        lefts[i] = Seg("L" .. i, a)
        rights[i] = Seg("R" .. i, a)
    end
    local mid = Seg("M", 1)

    function divider:SetDividerWidth(w)
        self:SetWidth(w)
        local fadeW = w * FADE_PART
        local step = fadeW / FADE_STEPS
        for i = 1, FADE_STEPS do
            local off = (i - 1) * step
            lefts[i]:ClearAnchors()
            lefts[i]:SetAnchor(TOPLEFT, self, TOPLEFT, off, 0)
            lefts[i]:SetWidth(step)
            rights[i]:ClearAnchors()
            rights[i]:SetAnchor(TOPRIGHT, self, TOPRIGHT, -off, 0)
            rights[i]:SetWidth(step)
        end
        mid:ClearAnchors()
        mid:SetAnchor(TOPLEFT, self, TOPLEFT, fadeW, 0)
        mid:SetAnchor(TOPRIGHT, self, TOPRIGHT, -fadeW, 0)
    end
    divider:SetDividerWidth(width)
    return divider
end

-- Rounded dark background: two rounded caps and a plain middle.
local function MakeRoundedBackground(name, parent, height)
    local capW = height / 2
    local left = WINDOW_MANAGER:CreateControl(name .. "L", parent, CT_TEXTURE)
    left:SetTexture(TEX_ROUNDED)
    left:SetTextureCoords(0, 0.5, 0, 1)
    left:SetDimensions(capW, height)
    left:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    local right = WINDOW_MANAGER:CreateControl(name .. "R", parent, CT_TEXTURE)
    right:SetTexture(TEX_ROUNDED)
    right:SetTextureCoords(0.5, 1, 0, 1)
    right:SetDimensions(capW, height)
    right:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
    local middle = WINDOW_MANAGER:CreateControl(name .. "M", parent, CT_TEXTURE)
    middle:SetAnchor(TOPLEFT, left, TOPRIGHT, 0, 0)
    middle:SetAnchor(BOTTOMRIGHT, right, BOTTOMLEFT, 0, 0)
    local parts = { left, middle, right }
    for _, t in ipairs(parts) do
        t:SetColor(0, 0, 0, 1)
        t:SetMouseEnabled(false)
        t:SetDrawLayer(DL_BACKGROUND)
    end
    return {
        SetAlpha = function(_, alpha)
            for _, t in ipairs(parts) do t:SetAlpha(alpha) end
        end,
        SetColor = function(_, r, g, b)
            for _, t in ipairs(parts) do t:SetColor(r, g, b, 1) end
        end,
    }
end


-- The Set Hunter emblem: bronze-edged shield with the helmet (our own shield textures,
-- tinted here). Title size 44 x 48; the launcher and the bag button use smaller ones.
-- Returns the shield (anchor it).
local EMBLEM_W, EMBLEM_H, EMBLEM_ICON = 44, 48, 30
local function MakeEmblem(name, parent, w, h, iconSize)
    local fill = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    fill:SetTexture("SetHunter/Textures/emblem_fill.dds")
    fill:SetColor(0.10, 0.08, 0.06, 1)   -- #1a1510
    fill:SetDimensions(w or EMBLEM_W, h or EMBLEM_H)
    fill:SetMouseEnabled(false)
    local ring = WINDOW_MANAGER:CreateControl(name .. "Ring", fill, CT_TEXTURE)
    ring:SetTexture("SetHunter/Textures/emblem_ring.dds")
    SetHexColor(ring, COLOR.theme)
    ring:SetAnchorFill(fill)
    ring:SetDrawLevel(2)
    local helmet = WINDOW_MANAGER:CreateControl(name .. "Helmet", fill, CT_TEXTURE)
    helmet:SetTexture(TEX_ICON)   -- the game's helmet icon, like the old round crest
    helmet:SetDimensions(iconSize or EMBLEM_ICON, iconSize or EMBLEM_ICON)
    helmet:SetAnchor(CENTER, fill, CENTER, 0, 0)
    helmet:SetDrawLevel(3)
    return fill
end

-- Small rounded label ("4 players", "Base game").
local function MakeBadge(name, parent)
    local badge = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    badge:SetHeight(22)
    local bg = MakeRoundedBackground(name .. "BG", badge, 22)
    bg:SetColor(1, 1, 1)
    bg:SetAlpha(0.09)
    local label = MakeLabel(name .. "Text", badge, "ZoFontGameSmall", 200, 22, COLOR.normal)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(CENTER, badge, CENTER, 0, 0)
    local function Fit()
        local width = label:GetTextWidth() + 12
        label:SetWidth(width)
        badge:SetWidth(width + 14)
    end
    -- Optional tooltip: a function that fills InformationTooltip (nil = none).
    badge:SetHandler("OnMouseEnter", function(self)
        if not self.tooltipFn then return end
        bg:SetAlpha(0.16)
        InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -6, TOPLEFT)
        self.tooltipFn(InformationTooltip)
    end)
    badge:SetHandler("OnMouseExit", function()
        bg:SetAlpha(0.09)
        ClearTooltip(InformationTooltip)
    end)
    function badge:SetBadgeTooltip(fn)
        self.tooltipFn = fn
        self:SetMouseEnabled(fn ~= nil)
    end
    function badge:SetBadgeText(text)
        -- The game only measures new text on the next frame (right away it still reports
        -- the old text's width), so start with an estimate and fit exactly a frame later.
        label:SetWidth(300)
        label:SetText(text)
        label:SetWidth(#text * 8 + 12)
        self:SetWidth(#text * 8 + 26)
        zo_callLater(Fit, 1)
    end
    return badge
end

-- Rounded on/off pill for a setting (Missing only, Alerts): gold when on.
local function MakeToggle(name, parent, text, getter, setter, tooltip)
    local pill = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    pill:SetHeight(24)
    pill:SetMouseEnabled(true)
    local bg = MakeRoundedBackground(name .. "BG", pill, 24)
    local label = MakeLabel(name .. "Text", pill, "ZoFontGameSmall", 300, 24, COLOR.dim)
    label:SetText(text)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(CENTER, pill, CENTER, 0, 0)
    -- Measured a frame later, like the badges (see MakeBadge).
    local function Fit()
        local width = label:GetTextWidth() + 12
        label:SetWidth(width)
        pill:SetWidth(width + 14)
    end
    label:SetWidth(#text * 8 + 12)
    pill:SetWidth(#text * 8 + 26)
    zo_callLater(Fit, 1)

    local function Paint(hovered)
        local on = getter()
        if on then
            bg:SetColor(HexToRGB(COLOR.theme))
            bg:SetAlpha(hovered and 0.45 or 0.32)
        else
            bg:SetColor(1, 1, 1)
            bg:SetAlpha(hovered and 0.14 or 0.07)
        end
        SetHexColor(label, (on or hovered) and COLOR.selected or COLOR.dim)
    end
    pill.Refresh = function() Paint(false) end
    pill:SetHandler("OnMouseEnter", function(self)
        Paint(true)
        if tooltip then
            InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -6, TOPLEFT)
            SetTooltipText(InformationTooltip, tooltip)
        end
    end)
    pill:SetHandler("OnMouseExit", function()
        Paint(false)
        ClearTooltip(InformationTooltip)
    end)
    pill:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            setter(not getter())
            Paint(true)
        end
    end)
    Paint(false)
    return pill
end

-- Thin progress bar: background + gold fill; SetProgress(0..1).
local function MakeBar(name, parent, width, height)
    local bar = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    bar:SetDimensions(width, height)
    bar:SetColor(1, 1, 1, 0.12)
    local fill = WINDOW_MANAGER:CreateControl(name .. "Fill", bar, CT_TEXTURE)
    fill:SetAnchor(LEFT, bar, LEFT, 0, 0)
    fill:SetHeight(height)
    function bar:SetProgress(fraction, complete)
        fill:SetWidth(zo_max(0, zo_min(1, fraction)) * self:GetWidth())
        SetHexColor(fill, complete and COLOR.good or COLOR.theme)
    end
    bar:SetProgress(0)
    return bar
end

-- Is the mouse over control (with a few pixels of slack for small targets)?
local function IsMouseOver(control, pad)
    pad = pad or 0
    local x, y = GetUIMousePosition()
    return x >= control:GetLeft() - pad and x <= control:GetRight() + pad
        and y >= control:GetTop() - pad and y <= control:GetBottom() + pad
end

-- ---------------------------------------------------------------------------
-- What each view shows
-- ---------------------------------------------------------------------------
local function GroupText(group)
    if group == "solo" then return L("GROUP_SOLO") end
    if group == "duo" then return L("GROUP_DUO") end
    return L("GROUP_ANY")
end

-- "1 set" / "4 sets"
local function Count(oneKey, manyKey, n)
    return n == 1 and L(oneKey) or L(manyKey, n)
end

-- Short facts about a location, shown as badges under its name.
local function LocationBadges(loc)
    local badges = {}
    if loc.kind == "dungeon" then
        badges[#badges + 1] = L("BADGE_PLAYERS", 4)
        if S.FindDungeonActivity(loc.id, true) then badges[#badges + 1] = L("BADGE_NORMAL_VET") end
        local _, ownsDLC = S.GetActivityDLC(S.FindDungeonActivity(loc.id, false) or S.FindDungeonActivity(loc.id, true))
        if not ownsDLC then badges[#badges + 1] = Colorize(COLOR.bad, L("BADGE_DLC_MISSING")) end
    elseif loc.kind == "trial" then
        badges[#badges + 1] = L("BADGE_PLAYERS", 12)
    elseif loc.kind == "arena" then
        badges[#badges + 1] = loc.arena == "solo" and L("INFO_ARENA_SOLO")
            or loc.arena == "group" and L("BADGE_PLAYERS", 4)
            or loc.arena == "soloduo" and L("INFO_ARENA_SOLODUO")
            or L("INFO_ARENA")
    elseif loc.kind == "pvp" then
        badges[#badges + 1] = L("INFO_PVP")
    elseif loc.kind == "other" then
        badges[#badges + 1] = L("INFO_OTHER")
    else
        badges[#badges + 1] = L("INFO_OVERLAND")
    end
    if loc.monster then badges[#badges + 1] = loc.monster.dlc and L("BADGE_DLC") or L("BASE_GAME") end
    return badges
end

-- Undaunted key icon for the shoulders line (the game's own currency icon).
local function KeyIcon()
    if ZO_Currency_GetKeyboardCurrencyIcon and CURT_UNDAUNTED_KEYS then
        local ok, icon = pcall(ZO_Currency_GetKeyboardCurrencyIcon, CURT_UNDAUNTED_KEYS)
        if ok and icon and icon ~= "" then return icon end
    end
    return TEX_QUEUE
end

-- Head / shoulders lines with icons, and a special note.
local function LocationLines(loc)
    local lines = {}
    if loc.monster then
        lines[#lines + 1] = zo_iconFormat(TEX_VETERAN, 20, 20) .. " " .. L("LINE_HEAD",
            Colorize(COLOR.selected, loc.monster.set), Colorize(COLOR.dim, L("LINE_HEAD_FROM", loc.monster.boss)))
        lines[#lines + 1] = zo_iconFormat(KeyIcon(), 20, 20) .. " " .. L("LINE_SHOULDERS", Colorize(COLOR.dim, L("UNDAUNTED_KEYS")))
    end
    if loc.note then lines[#lines + 1] = Colorize(COLOR.accent, loc.note) end
    return table.concat(lines, "\n")
end

local function DungeonArt(loc)
    if loc.kind ~= "dungeon" then return nil end
    return S.GetActivityBanner(S.FindDungeonActivity(loc.id, true) or S.FindDungeonActivity(loc.id, false))
end

-- breadcrumb parts: plain text, or clickable { text, view } / { text, tab }
local function Crumb(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local part = select(i, ...)
        if type(part) == "string" and part ~= "" then part = { text = part } end
        if type(part) == "table" then parts[#parts + 1] = part end
    end
    return parts
end

local function Sec(key)
    return { text = L(key), tab = key }
end

local function CatPart(key)
    for _, cat in ipairs(CATEGORIES) do
        if cat.key == key then return { text = L(key), view = cat.view } end
    end
    return L(key)
end

-- Rows alternate a faint stripe; the count restarts under every heading.
local stripe = false
local function AddRow(scrollData, rowType, data)
    if rowType == ROW_HEADER then
        stripe = false
    else
        stripe = not stripe
        data.stripe = stripe
    end
    scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(rowType, data)
end

local function AddSets(scrollData, sets, showWhere)
    for _, data in ipairs(sets) do
        data.showWhere = showWhere
        AddRow(scrollData, ROW_SET, data)
    end
    return #sets
end

-- Sets complete / collectible among a list of sets.
local function Progress(sets)
    local collectible, complete = 0, 0
    for _, data in ipairs(sets) do
        if data.total > 0 then
            collectible = collectible + 1
            if data.complete then complete = complete + 1 end
        end
    end
    return complete, collectible
end

-- The game's Antiquities journal (nil when this game version doesn't have that scene).
local function AntiquityScene()
    return SCENE_MANAGER and SCENE_MANAGER:GetScene("antiquityJournalKeyboard") or nil
end

local function OpenAntiquities()
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    SCENE_MANAGER:Show("antiquityJournalKeyboard")
end

-- the game's own lead icon (a scroll), else the journal icon
local function AntiquityIcon()
    if GetAntiquityLeadIcon then
        local ok, icon = pcall(GetAntiquityLeadIcon)
        if ok and icon and icon ~= "" then return icon end
    end
    return "EsoUI/Art/MainMenu/menuBar_journal_up.dds"
end

-- Other sources (reward systems): which one a location is, for its own info texts
-- (SRC_INFO_<key> under the title, SRC_RULE_<key> in "How drops work")
local function SpecialSourceKey(loc)
    local LIS = S.LIS()
    if not LIS or loc.id >= 0 then return nil end
    if loc.id == LIS.SPECIAL_SOURCE_ANTIQUITIES then return "ANTIQUITIES" end
    if loc.id == LIS.SPECIAL_SOURCE_BATTLEGROUNDS then return "BATTLEGROUNDS" end
    if loc.id == LIS.SPECIAL_SOURCE_RANDOM_DUNGEON_REWARD then return "RANDOM" end
    if loc.id == LIS.SPECIAL_SOURCE_REWARDS_FOR_THE_WORTHY then return "WORTHY" end
    return nil
end

-- The game's Group Finder on its Battlegrounds tab (pcall'd: the game's own objects)
local function OpenBattlegrounds()
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    local ok = pcall(function()
        GROUP_MENU_KEYBOARD:ShowCategory(BATTLEGROUND_FINDER_KEYBOARD.categoryData.categoryFragment)
    end)
    if not ok then pcall(function() MAIN_MENU_KEYBOARD:ShowScene("groupMenuKeyboard") end) end
end

-- What you can start for a reward system right from the window: a row icon, a link
-- on its page, right-click and double-click. Rewards for the Worthy has nothing to start.
local SOURCE_ACTIONS = {
    ANTIQUITIES = {
        text = "MENU_ANTIQ", hint = "TT_ACTION_ANTIQ", linkTip = "ANTIQ_LINK_TT", icon = AntiquityIcon,
        run = OpenAntiquities,
        ready = function() return AntiquityScene() ~= nil end,
    },
    RANDOM = {
        text = "MENU_RANDOM", hint = "TT_ACTION_RANDOM", linkTip = "RANDOM_LINK_TT",
        icon = function() return TEX_QUEUE end,
        run = function()
            ClearTooltip(ItemTooltip)
            ClearTooltip(InformationTooltip)
            PlaySound(SOUNDS.DEFAULT_CLICK)
            S.OpenQueueDialog("random")
        end,
        ready = function() return S.FindRandomDungeonSet(false) ~= nil end,
    },
    BATTLEGROUNDS = {
        text = "MENU_BG", hint = "TT_ACTION_BG", linkTip = "BG_LINK_TT",
        icon = function() return "EsoUI/Art/LFG/LFG_indexIcon_battlegrounds_up.dds" end,
        run = OpenBattlegrounds,
        ready = function() return GROUP_MENU_KEYBOARD ~= nil and BATTLEGROUND_FINDER_KEYBOARD ~= nil end,
    },
    -- XP farming > This session: the link under "How drops work"
    XPRESET = {
        text = "MENU_XP_RESET", linkTip = "XP_RESET_TT",
        icon = function() return "SetHunter/Textures/tab_xp.dds" end,
        run = function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            S.ResetXPSession()
            S.RefreshAll()
        end,
        ready = function() return true end,
    },
}

-- a reward system's action if it can be used right now (nil otherwise)
local function ReadySourceAction(key)
    local action = key and SOURCE_ACTIONS[key]
    return action and action.ready() and action or nil
end

-- One location: name, badges, head / shoulders, art, progress, then its sets.
local function LocationView(loc, scrollData, catKey)
    local allSets = S.GetSetsForLocation(loc.id, true)
    local shown = {}
    for _, data in ipairs(allSets) do
        if not (S.sv.missingOnly and data.complete) then shown[#shown + 1] = data end
    end
    local done, total = Progress(allSets)
    local special = SpecialSourceKey(loc)
    return {
        crumb = Crumb(Sec("TREE_SETS"), catKey and CatPart(catKey), loc.name),
        title = loc.name,
        badges = LocationBadges(loc),
        info = special and Colorize(COLOR.dim, L("SRC_INFO_" .. special)) or LocationLines(loc),
        art = DungeonArt(loc),
        rules = special and L("SRC_RULE_" .. special) or L(RULE_BY_KIND[loc.kind] or "RULE_OVERLAND"),
        sourceKey = ReadySourceAction(special) and special or nil,   -- link under "How drops work"
        progress = total > 0 and { done = done, total = total } or nil,
        columns = "sets",
        locId = loc.id,
        zoneId = loc.id > 0 and loc.id or nil,
        count = AddSets(scrollData, shown, false),
        empty = S.LIS() and L("EMPTY") or L("NO_LIB"),
    }
end

-- All locations of one kind, a heading per location.
local function KindView(cat, scrollData)
    local count = 0
    for _, loc in ipairs(S.GetLocations(cat.kind)) do
        local sets = S.GetSetsForLocation(loc.id)
        if #sets > 0 then
            AddRow(scrollData, ROW_HEADER, { title = loc.name })
            count = count + AddSets(scrollData, sets, false)
        end
    end
    return {
        crumb = Crumb(Sec("TREE_SETS")),
        title = L(cat.key),
        badges = { Count("BADGE_PLACE", "BADGE_PLACES", #S.GetLocations(cat.kind)) },
        rules = L(RULE_BY_KIND[cat.kind]),
        columns = "sets",
        count = count,
        empty = S.LIS() and L("EMPTY") or L("NO_LIB"),
    }
end

local function MonsterView(scrollData)
    local list = {}
    for _, m in ipairs(D.MONSTER_SETS) do
        local setId = S.SetIdByName(m.set)
        local data = setId and S.GetSetData(setId)
        if data then
            data.monster = m
            data.typeText = m.zoneId and S.ZoneName(m.zoneId) or m.loc
            if not (S.sv.missingOnly and data.complete) then list[#list + 1] = data end
        else
            list[#list + 1] = {
                kind = "info", name = m.set, info = m.loc, zoneId = m.zoneId, monster = m,
                tooltip = { L("TT_HEAD", m.boss), L("TT_SHOULDERS") },
            }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    for _, data in ipairs(list) do
        AddRow(scrollData, data.kind == "set" and ROW_SET or ROW_INFO, data)
    end
    return {
        crumb = Crumb(Sec("TREE_SETS")), title = L("CAT_MONSTER"),
        badges = { Count("BADGE_SET", "BADGE_SETS", #list) },
        info = zo_iconFormat(TEX_VETERAN, 20, 20) .. " " .. L("MONSTER_INFO_HEAD") .. "\n"
            .. zo_iconFormat(KeyIcon(), 20, 20) .. " " .. L("LINE_SHOULDERS", Colorize(COLOR.dim, L("UNDAUNTED_KEYS"))),
        rules = L("RULE_MONSTER"), columns = "sets", count = #list,
    }
end

local function SpotRow(spot)
    local zoneId = S.ZoneIdByName(spot.zone)
    local zone = zoneId and S.ZoneName(zoneId) or spot.zone
    local name = spot.rank and string.format("%d.  %s", spot.rank, spot.name) or spot.name
    return {
        kind = "info",
        name = name,
        info = string.format("%s  ·  %s", zone, GroupText(spot.group)),
        zoneId = zoneId,
        tooltip = {
            zone .. "  ·  " .. GroupText(spot.group) .. "  ·  " .. (spot.dlc and (spot.dlc .. " DLC") or L("BASE_GAME")),
            spot.enemies,
            spot.how,
        },
    }
end

-- The bar on every XP page: "Level 45 ... 62% to level 46" or "CP 1,076 ... 38% to next CP"
local function XPProgress()
    local st = S.XPState()
    if not st.size or st.size <= 0 then return nil end
    local pct = zo_floor(st.xp / st.size * 100)
    return {
        done = st.xp, total = st.size,
        label = st.champion and L("XP_LABEL_CP", ZO_CommaDelimitNumber(st.rank)) or L("XP_LABEL_LEVEL", st.rank),
        valueText = st.champion and L("XP_TO_NEXT_CP", pct) or L("XP_TO_NEXT_LEVEL", pct, st.rank + 1),
    }
end

local function SpotsView(scrollData)
    local top, backup = {}, {}
    for _, spot in ipairs(D.GRIND_SPOTS) do
        table.insert(spot.backup and backup or top, spot)
    end
    table.sort(top, function(a, b) return (a.rank or 99) < (b.rank or 99) end)
    AddRow(scrollData, ROW_HEADER, { title = L("XP_HDR_TOP") })
    for _, spot in ipairs(top) do AddRow(scrollData, ROW_INFO, SpotRow(spot)) end
    AddRow(scrollData, ROW_HEADER, { title = L("XP_HDR_BACKUP") })
    for _, spot in ipairs(backup) do AddRow(scrollData, ROW_INFO, SpotRow(spot)) end

    local tips = {}
    for _, tip in ipairs(D.GRIND_TIPS) do tips[#tips + 1] = "•  " .. tip end
    return {
        crumb = Crumb(Sec("TREE_XP")),
        title = L("CAT_XP_SPOTS"),
        badges = { L("BADGE_SPOTS", #top + #backup) },
        info = Colorize(COLOR.dim, table.concat(tips, "\n")),
        progress = XPProgress(),
        count = #top + #backup,
    }
end

-- Live state for boosts that aren't items (ESO Plus, group, Enlightenment).
local function BoostStatus(boost)
    if boost.status == "esoplus" then
        local on = IsESOPlusSubscriber and IsESOPlusSubscriber()
        return on and Colorize(COLOR.good, L("STATUS_ACTIVE")) or Colorize(COLOR.dim, L("STATUS_OFF"))
    elseif boost.status == "group" then
        return IsUnitGrouped("player") and Colorize(COLOR.good, L("STATUS_GROUPED")) or Colorize(COLOR.dim, L("STATUS_OFF"))
    elseif boost.status == "enlightenment" then
        local pool = GetEnlightenedPool and GetEnlightenedPool() or 0
        if pool > 0 then return Colorize(COLOR.good, L("STATUS_ENLIGHTENED", ZO_CommaDelimitNumber(pool))) end
        return Colorize(COLOR.dim, L("STATUS_OFF"))
    end
    -- scrolls and Ambrosia share one buff: show it (with time left) while it's on
    if boost.key == "scroll" or boost.key == "ambrosia" then
        local name, left = S.ActiveXPBuff()
        if name then
            return Colorize(COLOR.good, left and L("STATUS_BUFF_LEFT", S.FormatDuration(left)) or L("STATUS_ACTIVE"))
        end
    end
    return nil
end

-- How many you own of a boost (nil when it isn't something you can own).
local function BoostOwned(boost)
    if boost.set then
        local setId = S.SetIdByName(boost.set)
        return setId and S.OwnedCount(setId) or 0, setId
    end
    if boost.items or boost.trait then return S.BoostCount(boost.key) end
    return nil
end

-- Icon for a boost row: the item you own, else the set's item, else an ESO menu icon.
local BOOST_ICONS = {
    scroll = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds",
    ambrosia = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds",
    esoplus = "EsoUI/Art/MainMenu/menuBar_market_up.dds",
    group = "EsoUI/Art/MainMenu/menuBar_group_up.dds",
    mara = "EsoUI/Art/MainMenu/menuBar_social_up.dds",
    training = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
    keeps = "EsoUI/Art/MainMenu/menuBar_champion_up.dds",
    cyrodiil = "EsoUI/Art/MainMenu/menuBar_map_up.dds",
    enlightenment = "EsoUI/Art/MainMenu/menuBar_champion_up.dds",
    challenge = "EsoUI/Art/MainMenu/menuBar_map_up.dds",
    apprentice = "EsoUI/Art/MainMenu/menuBar_skills_up.dds",
    events = "EsoUI/Art/MainMenu/menuBar_journal_up.dds",
}

local function BoostIcon(boost, setId)
    local owned = S.GetBoostItems(boost.key)[1]
    if owned then return GetItemLinkIcon(owned.link) end
    if setId then
        local data = S.GetSetData(setId)
        if data and data.icon then return data.icon end
    end
    return BOOST_ICONS[boost.key]
end

local function BoostByKey(key)
    for _, boost in ipairs(D.XP_BOOSTS) do
        if boost.key == key then return boost end
    end
    return nil
end

local function BoostsView(scrollData)
    local consumables = 0
    for _, boost in ipairs(D.XP_BOOSTS) do
        local tooltip = { boost.how }
        if boost.note then tooltip[#tooltip + 1] = boost.note end
        if boost.kill then tooltip[#tooltip + 1] = L("TT_KILL_ONLY") end
        local owned, setId = BoostOwned(boost)
        if boost.items and owned then consumables = consumables + owned end
        local info = Colorize(COLOR.good, boost.value)
        local status = BoostStatus(boost)
        if status then info = info .. Colorize(COLOR.dim, "  ·  ") .. status end
        AddRow(scrollData, ROW_INFO, {
            kind = "info", name = boost.name, info = info, tooltip = tooltip,
            boostKey = boost.key, boostSetId = setId, owned = owned, icon = BoostIcon(boost, setId),
        })
    end
    return {
        crumb = Crumb(Sec("TREE_XP")), title = L("CAT_XP_BOOSTS"),
        badges = { L("BADGE_MAX_XP"), L("BADGE_BOOSTS_OWNED", consumables) },
        info = Colorize(COLOR.dim, D.XP_MAX_NOTE .. "\n" .. L("BOOSTS_INFO")),
        progress = XPProgress(),
        count = #D.XP_BOOSTS,
    }
end

-- Every item you own for one boost, grouped by where it is (Bank, each character...).
local function BoostItemsView(scrollData, key, search)
    local boost = BoostByKey(key)
    local groups, places, total = {}, {}, 0
    for _, entry in ipairs(S.GetBoostItems(key)) do
        local piece = S.PieceInfo(entry)
        if search == "" or zo_strlower(piece.name):find(search, 1, true) then
            if not groups[entry.where] then
                groups[entry.where] = {}
                places[#places + 1] = entry.where
            end
            table.insert(groups[entry.where], entry)
            total = total + entry.count
        end
    end
    table.sort(places)
    local rows = 0
    for _, where in ipairs(places) do
        local list = groups[where]
        table.sort(list, function(a, b)
            local pa, pb = S.PieceInfo(a), S.PieceInfo(b)
            if pa.qualityValue ~= pb.qualityValue then return pa.qualityValue > pb.qualityValue end
            return pa.name < pb.name
        end)
        local n = 0
        for _, entry in ipairs(list) do n = n + entry.count end
        AddRow(scrollData, ROW_HEADER, { title = string.format("%s  (%d)", where, n) })
        for _, entry in ipairs(list) do
            entry.kind, entry.isBoost = "item", true
            AddRow(scrollData, ROW_ITEM, entry)
            rows = rows + 1
        end
    end
    return {
        crumb = Crumb(Sec("TREE_XP"), CatPart("CAT_XP_BOOSTS")),
        title = boost and boost.name or "",
        badges = { Count("BADGE_ITEM", "BADGE_ITEMS", total), Count("BADGE_STORED_ONE", "BADGE_STORED", #places) },
        info = boost and Colorize(COLOR.dim, boost.how) or nil,
        columns = "boosts",
        count = rows,
        empty = L("EMPTY_BOOSTS"),
    }
end

-- Leveling setup: a 4-step guide (what to wear, which skills, what to bring, which
-- mundus). Rows that are XP boosts show and link to what you own of them.
local function SetupView(scrollData)
    local function Section(title, items)
        AddRow(scrollData, ROW_HEADER, { title = title })
        for _, item in ipairs(items) do
            local row = { kind = "info", name = item.name, info = item.short, tooltip = { item.long } }
            local boost = item.boost and BoostByKey(item.boost)
            if boost then
                row.boostKey = boost.key
                row.owned, row.boostSetId = BoostOwned(boost)
                row.icon = BoostIcon(boost, row.boostSetId)
            end
            AddRow(scrollData, ROW_INFO, row)
        end
    end

    Section(L("SETUP_HDR_GEAR"), D.SETUP_GEAR)

    -- Skills: your own class first, the others below it.
    local myClass = GetUnitClassId("player")
    local mine, others = nil, {}
    for _, entry in ipairs(D.SETUP_SKILLS) do
        if entry.classId == myClass then mine = entry else others[#others + 1] = entry end
    end
    local function SkillRow(entry, isMine)
        return {
            kind = "info", name = entry.class, info = entry.skills,
            nameColor = isMine and COLOR.good or nil,
            infoColor = isMine and COLOR.selected or nil,
            tooltip = { L("SETUP_SKILLS_TT", entry.class, entry.skills) },
        }
    end
    AddRow(scrollData, ROW_HEADER, { title = mine and L("SETUP_HDR_SKILLS_MINE", mine.class) or L("SETUP_HDR_SKILLS") })
    if mine then AddRow(scrollData, ROW_INFO, SkillRow(mine, true)) end
    AddRow(scrollData, ROW_HEADER, { title = L("SETUP_HDR_SKILLS_OTHER") })
    for _, entry in ipairs(others) do AddRow(scrollData, ROW_INFO, SkillRow(entry, false)) end

    Section(L("SETUP_HDR_CONS"), D.SETUP_CONSUMABLES)
    Section(L("SETUP_HDR_MUNDUS"), D.SETUP_MUNDUS)
    return {
        crumb = Crumb(Sec("TREE_XP")),
        title = L("CAT_XP_SETUP"),
        badges = { L("BADGE_STEPS") },
        info = Colorize(COLOR.dim, L("SETUP_INFO")),
        progress = XPProgress(),
    }
end

-- This session: time, XP, XP per hour, ranks gained, time to the next rank, XP buff
local function SessionView(scrollData)
    local stats = S.XPSessionStats()
    local N = ZO_CommaDelimitNumber
    local function Row(nameKey, info, color, tip)
        AddRow(scrollData, ROW_INFO, {
            kind = "info", name = L(nameKey), info = info, infoColor = color,
            tooltip = tip and { tip } or nil,
        })
    end
    if stats then
        Row("SESSION_TIME", S.FormatDuration(stats.seconds))
        Row("SESSION_XP", N(stats.gained), COLOR.selected)
        Row("SESSION_RATE", L("SESSION_RATE_VALUE", N(zo_floor(stats.perHour))), COLOR.good, L("SESSION_RULES"))
        Row(stats.champion and "SESSION_CP" or "SESSION_LEVELS", tostring(stats.ranks))
        Row(stats.champion and "SESSION_NEXT_CP" or "SESSION_NEXT_LEVEL",
            stats.toNext and L("SESSION_ABOUT", S.FormatDuration(stats.toNext)) or L("SESSION_NO_XP_YET"))
    end
    local buff, left = S.ActiveXPBuff()
    Row("SESSION_BUFF", buff and (left and L("SESSION_BUFF_LEFT", buff, S.FormatDuration(left)) or buff) or L("SESSION_NO_BUFF"),
        buff and COLOR.good or nil, L("SESSION_BUFF_TT"))
    return {
        crumb = Crumb(Sec("TREE_XP")),
        title = L("CAT_XP_SESSION"),
        info = Colorize(COLOR.dim, L("SESSION_INFO")),
        rules = L("SESSION_RULES"),
        progress = XPProgress(),
        sourceKey = "XPRESET",   -- "Start a new session" link under "How drops work"
    }
end

-- Daily bonuses: the Group Finder's once-a-day rewards, open or done today
local function DailyView(scrollData)
    local open = 0
    for _, reward in ipairs(S.DailyRewards()) do
        if reward.open then open = open + 1 end
        local info = reward.open and Colorize(COLOR.good, L("DAILY_OPEN")) or Colorize(COLOR.dim, L("DAILY_DONE"))
        if reward.open and reward.xp > 0 then
            info = info .. Colorize(COLOR.dim, "  ·  ") .. Colorize(COLOR.selected, L("DAILY_XP", ZO_CommaDelimitNumber(reward.xp)))
        end
        AddRow(scrollData, ROW_INFO, {
            kind = "info", name = reward.name, info = info,
            nameColor = reward.open and COLOR.selected or nil,
            sourceAction = reward.action,   -- row icon: queue random dungeon / open Battlegrounds
            tooltip = { L(reward.open and "DAILY_TT_OPEN" or "DAILY_TT_DONE") },
        })
    end
    return {
        crumb = Crumb(Sec("TREE_XP")),
        title = L("CAT_XP_DAILY"),
        badges = { open > 0 and Colorize(COLOR.good, L("DAILY_BADGE", open)) or L("DAILY_BADGE", open) },
        info = Colorize(COLOR.dim, L("DAILY_INFO")),
        rules = L("DAILY_RULES"),
        progress = XPProgress(),
        empty = L("DAILY_NONE"),
    }
end

-- bound, already collected (so it can be reconstructed), not worn, not a wanted trait
local function SafeToDecon(entry, piece)
    return piece.collected == true and entry.bound and entry.whereKind ~= "worn"
        and not S.IsWantedTrait(entry.setId, piece.traitType)
end

-- My items dropdown: whose items show. sv.itemsScope = nil (all), a character id,
-- "bank" (incl. ESO Plus bank) or "house" (house storage chests)
local function InScope(entry)
    local scope = S.sv.itemsScope
    if scope == nil then return true end
    if scope == "bank" or scope == "house" then return entry.whereKind == scope end
    return entry.ownerId == scope
end

-- Duplicates: the same piece (set + slot) in the same trait, more than once among the
-- items shown (so it follows the character dropdown). Counted once per refresh.
-- set + slot + trait (the collection slot alone means "Head", "Chest"... for every set)
local function DupeKey(entry, piece)
    return tostring(entry.setId) .. "|" .. (piece.slotKey or piece.name) .. "|" .. tostring(piece.traitType)
end

local dupeCache = {}
local function DupeCounts()
    local index, scope = S.GetOwnedIndex(), S.sv.itemsScope or "all"
    if dupeCache.index ~= index or dupeCache.scope ~= scope then
        local counts = {}
        for _, entries in pairs(index) do
            for _, entry in ipairs(entries) do
                if InScope(entry) then
                    local key = DupeKey(entry, S.PieceInfo(entry))
                    counts[key] = (counts[key] or 0) + entry.count
                end
            end
        end
        dupeCache = { index = index, scope = scope, counts = counts }
    end
    return dupeCache.counts
end

local MAX_CP = 160   -- gear stops getting better at CP 160

-- Groupings (By trait, By slot, ...): groupOf(entry, piece) returns the group's key (kept
-- in sv.loc when one is picked in the tree), its name, and a value to sort the groups by.
local SET_KIND_ORDER = {
    { "mythic", "TYPE_MYTHIC" }, { "monster", "TYPE_MONSTER" }, { "trial", "CAT_TRIAL" },
    { "dungeon", "CAT_DUNGEON" }, { "arena", "CAT_ARENA" }, { "overland", "CAT_OVERLAND" },
    { "pvp", "CAT_PVP" }, { "crafted", "KIND_CRAFTED" }, { "other", "CAT_OTHER" },
}

local function IsJewelry(piece)
    return piece.equipType == EQUIP_TYPE_NECK or piece.equipType == EQUIP_TYPE_RING
end
local function IsWeapon(piece)
    return piece.weaponType ~= nil and piece.weaponType ~= WEAPONTYPE_NONE
end

local GROUP_OF = {
    trait = function(_, piece)
        local t = piece.traitType
        if not t or t == ITEM_TRAIT_TYPE_NONE then return nil end
        local name = S.TraitLabel(t)
        return t, name, name
    end,
    -- armor slots A-Z, then jewelry, then weapons
    slot = function(_, piece)
        if IsWeapon(piece) then
            local name = GetString("SI_WEAPONTYPE", piece.weaponType)
            return "w" .. piece.weaponType, name, "3" .. name
        end
        local name = GetString("SI_EQUIPTYPE", piece.equipType)
        return "e" .. piece.equipType, name, (IsJewelry(piece) and "2" or "1") .. name
    end,
    -- best first, each in its own color
    quality = function(_, piece)
        local q = piece.qualityValue
        return q, GetItemQualityColor(q):Colorize(GetString("SI_ITEMQUALITY", q)), string.format("%02d", 99 - q)
    end,
    weight = function(_, piece)
        if IsWeapon(piece) then return "weapon", L("TRAITS_WEAPON"), "5" end
        if IsJewelry(piece) then return "jewelry", L("TRAITS_JEWELRY"), "4" end
        local at = piece.armorType
        if at and at ~= ARMORTYPE_NONE then return "a" .. at, GetString("SI_ARMORTYPE", at), tostring(at) end
        return nil
    end,
    settype = function(entry)
        local kind = S.SetKind(entry.setId)
        for i, k in ipairs(SET_KIND_ORDER) do
            if k[1] == kind then return kind, L(k[2]), string.format("%02d", i) end
        end
        return nil
    end,
}

-- the My items pages; filter picks which of your pieces show, groupOf makes the page
-- expandable in the tree (the picked group sits in sv.loc; nil = all)
local ITEM_MODES = {
    items = { title = "CAT_ITEMS", info = "ITEMS_INFO", empty = "EMPTY_ITEMS" },
    items_new = { title = "CAT_ITEMS_NEW", info = "ITEMS_NEW_INFO", empty = "EMPTY_ITEMS_NEW", countColor = COLOR.good,
        filter = function(_, piece) return piece.collected == false end },
    items_decon = { title = "CAT_ITEMS_DECON", info = "ITEMS_DECON_INFO", empty = "EMPTY_ITEMS_DECON",
        filter = SafeToDecon },
    items_dupes = { title = "CAT_ITEMS_DUPES", info = "ITEMS_DUPES_INFO", empty = "EMPTY_ITEMS_DUPES",
        filter = function(entry, piece) return (DupeCounts()[DupeKey(entry, piece)] or 0) > 1 end },
    items_trade = { title = "CAT_ITEMS_TRADE", info = "ITEMS_TRADE_INFO", empty = "EMPTY_ITEMS_TRADE",
        filter = function(entry) return not entry.bound end },
    items_low = { title = "CAT_ITEMS_LOW", info = "ITEMS_LOW_INFO", empty = "EMPTY_ITEMS_LOW",
        filter = function(_, piece) return (piece.cp or 0) < MAX_CP end },
    items_trait = { title = "CAT_ITEMS_TRAIT", info = "ITEMS_TRAIT_INFO", empty = "EMPTY_ITEMS", groupOf = GROUP_OF.trait },
    items_slot = { title = "CAT_ITEMS_SLOT", info = "ITEMS_SLOT_INFO", empty = "EMPTY_ITEMS", groupOf = GROUP_OF.slot },
    items_quality = { title = "CAT_ITEMS_QUALITY", info = "ITEMS_QUALITY_INFO", empty = "EMPTY_ITEMS", groupOf = GROUP_OF.quality },
    items_weight = { title = "CAT_ITEMS_WEIGHT", info = "ITEMS_WEIGHT_INFO", empty = "EMPTY_ITEMS", groupOf = GROUP_OF.weight },
    items_settype = { title = "CAT_ITEMS_SETTYPE", info = "ITEMS_SETTYPE_INFO", empty = "EMPTY_ITEMS", groupOf = GROUP_OF.settype },
}
-- grouped pages: show the picked group (or everything while none is picked)
for _, mode in pairs(ITEM_MODES) do
    if mode.groupOf then
        local groupOf = mode.groupOf
        mode.filter = function(entry, piece)
            return S.sv.loc == nil or groupOf(entry, piece) == S.sv.loc
        end
    end
end

-- the dropdown's choices: All, every character (this one first), Bank, House storage
local function ScopeChoices()
    local list = { { text = L("SCOPE_ALL") } }   -- value nil = all
    for _, char in ipairs(S.GetCharacterScanList()) do
        list[#list + 1] = {
            value = char.id, name = char.name, scanned = char.scanned,
            text = char.scanned and char.name or L("SCOPE_NOT_SCANNED", char.name),
        }
    end
    list[#list + 1] = { value = "bank", text = L("SCOPE_BANK") }
    list[#list + 1] = { value = "house", text = L("SCOPE_HOUSE") }
    return list
end

-- name of what the dropdown shows ("Asaki Mozu", "Bank"); nil for All characters
local function ScopeName()
    local scope = S.sv.itemsScope
    if scope == nil then return nil end
    for _, choice in ipairs(ScopeChoices()) do
        if choice.value == scope then return choice.name or choice.text end
    end
    return nil
end

-- a character picked whose bags were never read: say how to fix that (nil otherwise)
local function ScopeEmptyText()
    local scope = S.sv.itemsScope
    if scope == nil or scope == "bank" or scope == "house" then return nil end
    for _, choice in ipairs(ScopeChoices()) do
        if choice.value == scope and not choice.scanned then return L("EMPTY_CHAR_NOT_SCANNED", choice.name) end
    end
    return nil
end

-- the groups of a grouped page among the items shown, with how many pieces each:
-- { { key, name, count }, ... } in the page's order
local function ItemGroups(mode)
    local byKey, list = {}, {}
    for _, entries in pairs(S.GetOwnedIndex()) do
        for _, entry in ipairs(entries) do
            if InScope(entry) then
                local key, name, sort = mode.groupOf(entry, S.PieceInfo(entry))
                if key ~= nil then
                    local group = byKey[key]
                    if not group then
                        group = { key = key, name = name, sort = sort or name, count = 0 }
                        byKey[key] = group
                        list[#list + 1] = group
                    end
                    group.count = group.count + 1
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.sort < b.sort end)
    return list
end

-- name of the group picked in the tree (for the page title)
local function GroupName(mode, key)
    for _, group in ipairs(ItemGroups(mode)) do
        if group.key == key then return group.name end
    end
    return nil
end

-- "Wanted traits: [stone] Divines  [stone] Infused (Armor)" line under a set, if it has any
local function AddWishTraitsRow(scrollData, setId, setName)
    if not S.HasWishTraits(setId) then return end
    local parts = {}
    for _, group in ipairs(S.TraitGroups()) do
        for _, t in ipairs(group.list) do
            if S.IsWantedTrait(setId, t.trait) then
                local label = S.TraitLabel(t.trait)
                parts[#parts + 1] = t.icon and (zo_iconFormat(t.icon, 18, 18) .. " " .. label) or label
            end
        end
    end
    AddRow(scrollData, ROW_INFO, {
        kind = "info",
        name = "      " .. L("WISH_TRAITS_ROW"),
        info = Colorize(COLOR.theme, table.concat(parts, "   ")),
        tooltip = { L("WISH_TRAITS_TT", setName) },
    })
end

-- Owned pieces grouped by set: { { name, setId, rows = { entry, ... } }, ... } A-Z.
local function OwnedGroups(filter, setFilter, search)
    local groups = {}
    for setId, entries in pairs(S.GetOwnedIndex()) do
        if not setFilter or setFilter == setId then
            local rows = {}
            for _, entry in ipairs(entries) do
                local piece = S.PieceInfo(entry)
                local matches = search == ""
                    or zo_strlower(piece.setName):find(search, 1, true)
                    or zo_strlower(piece.name):find(search, 1, true)
                if matches and (not filter or filter(entry, piece)) then rows[#rows + 1] = entry end
            end
            if #rows > 0 then
                table.sort(rows, function(a, b)
                    local pa, pb = S.PieceInfo(a), S.PieceInfo(b)
                    if pa.name ~= pb.name then return pa.name < pb.name end
                    if pa.trait ~= pb.trait then return pa.trait < pb.trait end
                    return a.where < b.where
                end)
                groups[#groups + 1] = { name = S.PieceInfo(rows[1]).setName, setId = setId, rows = rows }
            end
        end
    end
    table.sort(groups, function(a, b) return a.name < b.name end)
    return groups
end

-- "Bags of 1 of 5 characters" (green once all are in), with a tooltip listing which
-- characters are included and which still need a login.
local function CharactersBadge()
    local list = S.GetCharacterScanList()
    local scanned = 0
    for _, char in ipairs(list) do
        if char.scanned then scanned = scanned + 1 end
    end
    local total = #list
    local text = L("BADGE_CHARS_OF", scanned, total)
    -- green once every character is in; orange until then, so an incomplete list stands out
    if total > 0 and scanned == total then
        text = Colorize(COLOR.good, text)
    elseif total > 0 then
        text = Colorize(COLOR.warn, zo_iconFormat("EsoUI/Art/Miscellaneous/help_icon.dds", 14, 14) .. " " .. text)
    end
    return {
        text = text,
        tooltip = function(tooltip)
            SetTooltipText(tooltip, L("CHARS_TT_TITLE"))
            tooltip:AddLine(L("CHARS_TT_INFO"), "ZoFontGameSmall", HexToRGB(COLOR.dim))
            for _, char in ipairs(list) do
                if char.scanned then
                    tooltip:AddLine(L("CHARS_TT_DONE", char.name, S.FormatAgo(char.t)), "ZoFontGame", HexToRGB(COLOR.good))
                else
                    tooltip:AddLine(L("CHARS_TT_MISSING", char.name), "ZoFontGame", HexToRGB(COLOR.dim))
                end
            end
            if scanned < total then
                tooltip:AddLine(L("CHARS_TT_HINT"), "ZoFontGameSmall", HexToRGB(COLOR.accent))
            end
        end,
    }
end

local function ItemsView(scrollData, view, search)
    local mode = ITEM_MODES[view]
    local count = 0
    local groups = OwnedGroups(function(entry, piece)
        return InScope(entry) and (not mode.filter or mode.filter(entry, piece))
    end, ui.itemsSetId, search)
    for _, group in ipairs(groups) do
        AddRow(scrollData, ROW_HEADER, { title = string.format("%s  (%d)", group.name, #group.rows) })
        for _, entry in ipairs(group.rows) do
            entry.kind = "item"
            AddRow(scrollData, ROW_ITEM, entry)
            count = count + 1
        end
    end
    local title = L(mode.title)
    if ui.itemsSetId and groups[1] then title = L("ITEMS_FOR", groups[1].name) end
    local info = L(mode.info)
    -- filtered to one set: the crumb leads back to the full list
    local crumb = Crumb(Sec("TREE_ITEMS"), ui.itemsSetId and CatPart(mode.title))
    if mode.groupOf and S.sv.loc ~= nil then
        title = GroupName(mode, S.sv.loc) or title
        crumb = Crumb(Sec("TREE_ITEMS"), CatPart(mode.title), title)
    end
    -- one character (or Bank / House storage) picked in the dropdown: say so in the title
    local scopeName = ScopeName()
    if scopeName then title = title .. "  ·  " .. scopeName end
    return {
        crumb = crumb,
        title = title,
        scope = true,   -- show the character dropdown on the badge row
        badges = {
            count == 1 and L("BADGE_PIECE") or L("BADGE_PIECES", count),
            CharactersBadge(),
        },
        info = Colorize(COLOR.dim, info),
        rules = L("ITEMS_RULES"),
        columns = "items",
        count = count,
        empty = ScopeEmptyText() or L(mode.empty),
    }
end

-- Wishlist (the only one; My items has none of its own): each set, then
-- - picked pieces: every picked piece, with the copies you own of it right under it
-- - whole sets: every piece of the set you own
local function AddWishlist(scrollData, sets)
    for _, data in ipairs(sets) do
        data.showWhere = true
        AddRow(scrollData, ROW_SET, data)
        AddWishTraitsRow(scrollData, data.setId, data.name)
        local owned = OwnedGroups(nil, data.setId, "")[1]
        owned = owned and owned.rows or {}
        if S.HasWishPieces(data.setId) then
            local byKey = {}
            for _, entry in ipairs(owned) do
                local key = S.PieceInfo(entry).slotKey
                if key then
                    byKey[key] = byKey[key] or {}
                    table.insert(byKey[key], entry)
                end
            end
            for _, piece in ipairs(S.SetPieces(data.setId)) do
                if S.IsWantedPiece(data.setId, piece.key) then
                    local mine = byKey[piece.key] or {}
                    local n = 0
                    for _, entry in ipairs(mine) do n = n + entry.count end
                    local status = piece.unlocked and Colorize(COLOR.good, L("PIECE_COLLECTED")) or L("PIECE_MISSING")
                    if n > 0 then
                        status = status .. Colorize(COLOR.dim, "  ·  ") .. Colorize(COLOR.accent, L("OWNED", n))
                    end
                    AddRow(scrollData, ROW_INFO, {
                        kind = "info",
                        name = "      " .. zo_iconFormat(TEX_STAR, 16, 16) .. " "
                            .. (piece.icon and (zo_iconFormat(piece.icon, 22, 22) .. " ") or "") .. piece.name,
                        info = status,
                        pieceOf = data.setId, pieceKey = piece.key, pieceLink = piece.link,
                        tooltip = { L("PIECE_TT", piece.name, data.name) },
                    })
                    for _, entry in ipairs(mine) do
                        entry.kind = "item"
                        AddRow(scrollData, ROW_ITEM, entry)
                    end
                end
            end
        else
            for _, entry in ipairs(owned) do
                entry.kind = "item"
                AddRow(scrollData, ROW_ITEM, entry)
            end
        end
    end
    return #sets
end

-- wishlist sets split in two: with picked pieces (true) or the whole set (false)
local function PieceWishSets(withPieces)
    local list = {}
    for _, data in ipairs(S.GetWishlistSets()) do
        if S.HasWishPieces(data.setId) == withPieces then list[#list + 1] = data end
    end
    return list
end

-- sets you picked traits for (right-click a set > Hunt traits...)
local function HuntSets()
    local ids = {}
    for setId in pairs(S.sv.wishTraits) do ids[#ids + 1] = setId end
    return S.GetSets(ids, true)
end

-- Trait hunt: each set, then every trait you hunt for it with the pieces you
-- already have in that trait (any character, bank, house) listed underneath
local function TraitHuntView(scrollData)
    local sets = HuntSets()
    local found, hunted = 0, 0
    for _, data in ipairs(sets) do
        data.showWhere = true
        AddRow(scrollData, ROW_SET, data)
        local byTrait = {}
        local owned = OwnedGroups(nil, data.setId, "")[1]   -- sorted A-Z
        for _, entry in ipairs(owned and owned.rows or {}) do
            local t = S.PieceInfo(entry).traitType
            if S.IsWantedTrait(data.setId, t) then
                byTrait[t] = byTrait[t] or {}
                table.insert(byTrait[t], entry)
            end
        end
        for _, group in ipairs(S.TraitGroups()) do
            for _, t in ipairs(group.list) do
                if S.IsWantedTrait(data.setId, t.trait) then
                    hunted = hunted + 1
                    local list = byTrait[t.trait]
                    local n = 0
                    for _, entry in ipairs(list or {}) do n = n + entry.count end
                    if n > 0 then found = found + 1 end
                    local label = S.TraitLabel(t.trait)
                    AddRow(scrollData, ROW_INFO, {
                        kind = "info",
                        name = "      " .. (t.icon and (zo_iconFormat(t.icon, 18, 18) .. " ") or "") .. label,
                        nameColor = COLOR.theme,
                        info = n > 0 and Colorize(COLOR.good, L("HUNT_HAVE", n)) or Colorize(COLOR.dim, L("HUNT_NONE")),
                        huntSet = data.setId,
                        tooltip = { L("HUNT_TRAIT_TT", label, data.name) },
                    })
                    for _, entry in ipairs(list or {}) do
                        entry.kind = "item"
                        AddRow(scrollData, ROW_ITEM, entry)
                    end
                end
            end
        end
    end
    return {
        crumb = Crumb(Sec("TREE_SETS")),
        title = L("CAT_HUNT"),
        badges = { Count("BADGE_SET", "BADGE_SETS", #sets), L("BADGE_HUNT_FOUND", found, hunted), CharactersBadge() },
        info = Colorize(COLOR.dim, L("HUNT_INFO")),
        columns = "where",
        count = #sets,
        empty = S.LIS() and L("EMPTY_HUNT") or L("NO_LIB"),
    }
end

-- Worked out once per collection change (S.collectionGen): these look at every set.
local cacheGen, cache = -1, {}
local function Cached(name, build)
    if cacheGen ~= S.collectionGen then cache, cacheGen = {}, S.collectionGen end
    if cache[name] == nil then cache[name] = build() end
    return cache[name]
end

local function AllSetIds()
    local LIS = S.LIS()
    return LIS and LIS.GetAllItemSetIds() or {}
end

-- Almost complete: { { setId, missing }, ... } for sets 1-3 pieces from done
local ALMOST_MAX = 3
local function AlmostIds()
    return Cached("almost", function()
        local list = {}
        for _, setId in ipairs(AllSetIds()) do
            local have, total = S.SetProgress(setId)
            local missing = total - have
            if total > 0 and missing >= 1 and missing <= ALMOST_MAX then
                list[#list + 1] = { setId = setId, missing = missing }
            end
        end
        return list
    end)
end

local function AlmostView(scrollData)
    local byMissing = {}
    for _, entry in ipairs(AlmostIds()) do
        byMissing[entry.missing] = byMissing[entry.missing] or {}
        table.insert(byMissing[entry.missing], entry.setId)
    end
    local count = 0
    for missing = 1, ALMOST_MAX do
        local sets = byMissing[missing] and S.GetSets(byMissing[missing], true) or {}
        if #sets > 0 then
            AddRow(scrollData, ROW_HEADER, {
                title = string.format("%s  (%d)", missing == 1 and L("ALMOST_HDR_ONE") or L("ALMOST_HDR", missing), #sets),
            })
            count = count + AddSets(scrollData, sets, true)
        end
    end
    return {
        crumb = Crumb(Sec("TREE_SETS")),
        title = L("CAT_ALMOST"),
        badges = { Count("BADGE_SET", "BADGE_SETS", count) },
        info = Colorize(COLOR.dim, L("ALMOST_INFO")),
        columns = "where",
        count = count,
        empty = S.LIS() and L("EMPTY_ALMOST") or L("NO_LIB"),
    }
end

-- Crafted sets: { [traitsNeeded] = { setId, ... } }
local function CraftedIds()
    return Cached("crafted", function()
        local byTraits = {}
        for _, setId in ipairs(AllSetIds()) do
            local n = S.CraftTraitsNeeded(setId)
            if n then
                byTraits[n] = byTraits[n] or {}
                table.insert(byTraits[n], setId)
            end
        end
        return byTraits
    end)
end

-- how many item lines this character can craft a set with n traits on: ok, total
local function CraftableLines(lines, n)
    local ok = 0
    for _, line in ipairs(lines) do
        if line.known >= n then ok = ok + 1 end
    end
    return ok, #lines
end

local function CraftedView(scrollData)
    local lines = S.ResearchLines()
    local byTraits = CraftedIds()
    local needs = {}
    for n in pairs(byTraits) do needs[#needs + 1] = n end
    table.sort(needs)
    local count, craftable = 0, 0
    for _, n in ipairs(needs) do
        local sets = S.GetSets(byTraits[n])   -- follows "Missing only"
        if #sets > 0 then
            local ok, total = CraftableLines(lines, n)
            local status = ok == total and Colorize(COLOR.good, L("CRAFT_ALL"))
                or Colorize(ok > 0 and COLOR.accent or COLOR.dim, L("CRAFT_SOME", ok, total))
            AddRow(scrollData, ROW_HEADER, { title = L("CRAFT_HDR", n) .. "  ·  " .. status })
            count = count + AddSets(scrollData, sets, true)
            if ok == total then craftable = craftable + #sets end
        end
    end
    return {
        crumb = Crumb(Sec("TREE_SETS")),
        title = L("CAT_CRAFTED"),
        badges = { Count("BADGE_SET", "BADGE_SETS", count), Colorize(COLOR.good, L("BADGE_CRAFTABLE", craftable)) },
        info = Colorize(COLOR.dim, L("CRAFTED_INFO")),
        rules = L("RULE_CRAFTED"),
        columns = "crafted",
        count = count,
        empty = S.LIS() and L("EMPTY") or L("NO_LIB"),
    }
end

-- Collection overview: complete sets and collected pieces, overall and per category.
-- Each category is a row (kind "summary") shaped like a set row, with its own bar.
local OVERVIEW_ROWS = {
    { view = "dungeon", kind = "dungeon" }, { view = "trial", kind = "trial" },
    { view = "arena", kind = "arena" }, { view = "overland", kind = "overland" },
    { view = "pvp", kind = "pvp" }, { view = "other", kind = "other" },
    { view = "monster", monster = true },
}   -- crafted sets aren't in the Set Collection, so they have no progress to show

local function OverviewStats()
    return Cached("overview", function()
        local function Tally(ids)
            local seen, t = {}, { sets = 0, done = 0, have = 0, pieces = 0 }
            for _, setId in ipairs(ids) do
                if not seen[setId] then
                    seen[setId] = true
                    local have, total = S.SetProgress(setId)
                    if total > 0 then
                        t.sets, t.pieces, t.have = t.sets + 1, t.pieces + total, t.have + have
                        if have == total then t.done = t.done + 1 end
                    end
                end
            end
            return t
        end
        local LIS = S.LIS()
        local stats = { all = Tally(AllSetIds()), rows = {} }
        for i, row in ipairs(OVERVIEW_ROWS) do
            local ids = {}
            if row.kind and LIS then
                for _, loc in ipairs(S.GetLocations(row.kind)) do
                    for _, setId in ipairs(LIS.GetAllItemSetIdsForSource(loc.id)) do ids[#ids + 1] = setId end
                end
            elseif row.monster then
                for _, m in ipairs(D.MONSTER_SETS) do ids[#ids + 1] = S.SetIdByName(m.set) end
            end
            stats.rows[i] = Tally(ids)
        end
        return stats
    end)
end

local function CategoryFor(view)
    for _, cat in ipairs(CATEGORIES) do
        if cat.view == view then return cat end
    end
    return nil
end

local function OverviewView(scrollData)
    local stats = OverviewStats()
    local N = ZO_CommaDelimitNumber
    for i, row in ipairs(OVERVIEW_ROWS) do
        local t, cat = stats.rows[i], CategoryFor(row.view)
        if cat and t.sets > 0 then
            AddRow(scrollData, ROW_SET, {
                kind = "summary", view = row.view, name = L(cat.key), icon = cat.icon,
                typeText = L("OVERVIEW_PIECES", N(t.have), N(t.pieces)),
                have = t.done, total = t.sets, complete = t.done == t.sets, owned = 0,
                tooltip = { L("OVERVIEW_TT", t.done, t.sets, N(t.have), N(t.pieces)) },
            })
        end
    end
    local all = stats.all
    return {
        crumb = Crumb(Sec("TREE_SETS")),
        title = L("CAT_OVERVIEW"),
        badges = { L("BADGE_PIECES_OF", N(all.have), N(all.pieces)) },
        info = Colorize(COLOR.dim, L("OVERVIEW_INFO")),
        progress = all.sets > 0 and { done = all.done, total = all.sets, label = L("OVERVIEW_PROGRESS") } or nil,
        columns = "overview",
        count = #OVERVIEW_ROWS,
        empty = S.LIS() and L("EMPTY") or L("NO_LIB"),
    }
end

-- Recently collected: newest first, a heading per day
local function RecentView(scrollData)
    local lastDay
    for _, r in ipairs(S.sv.recent) do
        local day = GetDateStringFromTimestamp and GetDateStringFromTimestamp(r.t) or ""
        if day ~= lastDay then
            AddRow(scrollData, ROW_HEADER, { title = day })
            lastDay = day
        end
        local data = S.GetSetData(r.s)
        local setName = data and data.name or ""
        local itemName = r.link and zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(r.link)) or setName
        local zone = (r.z and r.z ~= 0) and S.ZoneName(r.z) or ""
        AddRow(scrollData, ROW_INFO, {
            kind = "info",
            name = (r.link and (zo_iconFormat(GetItemLinkIcon(r.link), 22, 22) .. " ") or "") .. itemName,
            info = Colorize(COLOR.dim, zone .. "  ·  " .. S.FormatAgo(r.t)),
            pieceLink = r.link,
            tooltip = { L("RECENT_TT", setName, zone) },
        })
    end
    return {
        crumb = Crumb(Sec("TREE_SETS")),
        title = L("CAT_RECENT"),
        badges = { Count("BADGE_PIECE", "BADGE_PIECES", #S.sv.recent) },
        info = Colorize(COLOR.dim, L("RECENT_INFO")),
        count = #S.sv.recent,
        empty = L("EMPTY_RECENT"),
    }
end

local function CurrentCategory()
    for _, cat in ipairs(CATEGORIES) do
        if cat.view == S.sv.view then return cat end
    end
    return CATEGORIES[2]
end

-- Fills the list for the current view; returns { title, info, zoneId, count, empty }.
local function BuildView(scrollData)
    local search = zo_strtrim(ui.search:GetText() or "")
    -- Wanted pieces used to be its own category; it's under Wishlist now
    if S.sv.view == "wishpieces" then S.sv.view, S.sv.loc = "wishlist", "pieces" end
    -- My items had its own Wishlist; there's one Wishlist now (Sets)
    if S.sv.view == "items_wish" then S.sv.view, S.sv.loc = "wishlist", nil end
    -- One XP boost's items (a page without a spot in the tree; after a reload it
    -- falls back to the XP boosts list).
    if S.sv.view == "boost_items" then
        if ui.boostKey then return BoostItemsView(scrollData, ui.boostKey, zo_strlower(search)) end
        S.sv.view = "xp_boosts"
    end
    -- In My items the search box filters your items instead of searching all sets.
    if ITEM_MODES[S.sv.view] then
        return ItemsView(scrollData, S.sv.view, zo_strlower(search))
    end
    if search ~= "" then
        local sets = S.SearchSets(search)
        return {
            crumb = Crumb(Sec("TREE_SETS"), L("SEARCH_RESULTS")),
            title = string.format("\"%s\"", search),
            badges = { Count("BADGE_SET", "BADGE_SETS", #sets) },
            info = not S.LIS() and Colorize(COLOR.dim, L("NO_LIB")) or nil,
            columns = "sets",
            count = AddSets(scrollData, sets, true),
            empty = L("EMPTY_SEARCH"),
        }
    end

    local view = S.sv.view
    if view == "here" then
        local loc = S.GetHereLocation()
        local result = LocationView(loc, scrollData)
        result.crumb = Crumb(Sec("TREE_SETS"), L("CAT_HERE"))
        if loc.unknown then
            result.badges, result.info, result.rules, result.empty = nil, nil, nil, L("HERE_NONE")
        end
        return result
    elseif view == "wishlist" and S.sv.loc == "pieces" then
        -- Wishlist > Wanted pieces: sets where you picked single pieces
        local sets = PieceWishSets(true)
        local done, total = 0, 0
        for _, data in ipairs(sets) do
            for _, piece in ipairs(S.SetPieces(data.setId)) do
                if S.IsWantedPiece(data.setId, piece.key) then
                    total = total + 1
                    if piece.unlocked then done = done + 1 end
                end
            end
        end
        return {
            crumb = Crumb(Sec("TREE_SETS"), CatPart("CAT_WISHLIST")),
            title = L("CAT_WISH_PIECES"),
            badges = { total == 1 and L("BADGE_PIECE") or L("BADGE_PIECES", total), Count("BADGE_SET", "BADGE_SETS", #sets) },
            info = Colorize(COLOR.dim, L("WISH_PIECES_INFO")),
            progress = total > 0 and { done = done, total = total, label = L("WISH_PIECES_PROGRESS"), valueKey = "PROGRESS_PIECES" } or nil,
            columns = "where",
            count = AddWishlist(scrollData, sets),
            empty = S.LIS() and L("EMPTY_WISH_PIECES") or L("NO_LIB"),
        }
    elseif view == "wishlist" and S.sv.loc == "whole" then
        -- Wishlist > Whole sets
        local sets = PieceWishSets(false)
        local done, total = Progress(sets)
        return {
            crumb = Crumb(Sec("TREE_SETS"), CatPart("CAT_WISHLIST")),
            title = L("CAT_WISH_WHOLE"),
            badges = { Count("BADGE_SET", "BADGE_SETS", #sets) },
            info = Colorize(COLOR.dim, L("WISH_WHOLE_INFO")),
            progress = total > 0 and { done = done, total = total, label = L("WISHLIST_PROGRESS") } or nil,
            columns = "where",
            count = AddWishlist(scrollData, sets),
            empty = S.LIS() and L("EMPTY_WISH_WHOLE") or L("NO_LIB"),
        }
    elseif view == "wishlist" then
        -- everything: whole sets first, then the sets with picked pieces
        local whole, pieces = PieceWishSets(false), PieceWishSets(true)
        local done, total = Progress(whole)
        local count = 0
        if #whole > 0 and #pieces > 0 then
            AddRow(scrollData, ROW_HEADER, { title = string.format("%s  (%d)", L("CAT_WISH_WHOLE"), #whole) })
        end
        count = count + AddWishlist(scrollData, whole)
        if #pieces > 0 then
            if #whole > 0 then
                AddRow(scrollData, ROW_HEADER, { title = string.format("%s  (%d)", L("CAT_WISH_PIECES"), #pieces) })
            end
            count = count + AddWishlist(scrollData, pieces)
        end
        return {
            crumb = Crumb(Sec("TREE_SETS")),
            title = L("CAT_WISHLIST"),
            badges = { Count("BADGE_SET", "BADGE_SETS", #whole + #pieces) },
            info = Colorize(COLOR.dim, L("WISHLIST_INFO")),
            progress = total > 0 and { done = done, total = total, label = L("WISHLIST_PROGRESS") } or nil,
            columns = "where",
            count = count,
            empty = S.LIS() and L("EMPTY_WISHLIST") or L("NO_LIB"),
        }
    elseif view == "traithunt" then
        return TraitHuntView(scrollData)
    elseif view == "almost" then
        return AlmostView(scrollData)
    elseif view == "crafted" then
        return CraftedView(scrollData)
    elseif view == "overview" then
        return OverviewView(scrollData)
    elseif view == "recent" then
        return RecentView(scrollData)
    elseif view == "monster" then
        return MonsterView(scrollData)
    elseif view == "xp_spots" then
        return SpotsView(scrollData)
    elseif view == "xp_boosts" then
        return BoostsView(scrollData)
    elseif view == "xp_setup" then
        return SetupView(scrollData)
    elseif view == "xp_session" then
        return SessionView(scrollData)
    elseif view == "xp_daily" then
        return DailyView(scrollData)
    end

    local cat = CurrentCategory()
    local loc = S.sv.loc and S.GetLocation(S.sv.loc)
    if cat.kind and loc then return LocationView(loc, scrollData, cat.key) end
    if cat.kind then return KindView(cat, scrollData) end
    return { title = "" }
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------
-- An owned item row stands for its set: where it drops, monster boss, ...
local function SetDataFor(data)
    if data and data.kind == "item" then return S.GetSetData(data.setId) or data end
    return data
end

-- A set, or an owned piece of a set (not XP boost items, which aren't in a set).
local function IsSetLike(data)
    return data ~= nil and (data.kind == "set" or data.kind == "item") and data.setId ~= nil
end

-- Can you get there from the window? Dungeons: queue; else a known wayshrine or
-- entrance. PvP zones (Cyrodiil, Imperial City) go through the campaign queue, so no.
-- Cached; cleared whenever the window opens (you may have found new wayshrines).
local reachCache = {}
local function Reachable(zoneId)
    if reachCache[zoneId] == nil then
        local loc = S.GetLocation(zoneId)
        reachCache[zoneId] = not (loc and loc.kind == "pvp")
            and (S.CanQueue(zoneId) or S.FindTravelNode(zoneId) ~= nil)
    end
    return reachCache[zoneId]
end

-- Where a row leads: its zone, its monster dungeon, or the first place its set drops
-- in that you can actually get to.
local function TargetFor(data)
    data = SetDataFor(data)
    if not data then return nil end
    if data.zoneId then return data.zoneId end
    if data.monster and data.monster.zoneId and Reachable(data.monster.zoneId) then return data.monster.zoneId end
    for _, id in ipairs(data.sourceIds or {}) do
        if id > 0 and Reachable(id) then return id end
    end
    return nil
end

-- The selected row's place, else the location shown.
local function TravelTarget()
    local target = TargetFor(ui.selected)
    if target then return target end
    if ui.viewZoneId and Reachable(ui.viewZoneId) then return ui.viewZoneId end
    return nil
end

-- Dungeons are queued for (queue window) instead of traveled to.
local function AddTravelOrQueue(zoneId, data)
    if not zoneId then return end
    if S.CanQueue(zoneId) then
        AddMenuItem(zo_iconFormat(TEX_QUEUE, 20, 20) .. " " .. L("MENU_QUEUE"),
            function() S.OpenQueueDialog(zoneId, SetDataFor(data)) end)
    else
        AddMenuItem(L("BTN_TRAVEL"), function() S.TravelTo(zoneId) end)
    end
end

local function UpdateActionButtons()
    if not ui.actions then return end
    local data = ui.selected
    local setLike = IsSetLike(data)
    ui.actions.wish:SetEnabled(setLike)
    ui.actions.wish:SetText(zo_iconFormat(TEX_STAR, 18, 18) .. " "
        .. ((setLike and S.sv.wishlist[data.setId]) and L("BTN_UNWISH") or L("BTN_WISH")))
    ui.actions.link:SetEnabled(data ~= nil and data.link ~= nil)

    local name = data and (data.kind == "item" and S.PieceInfo(data).name or data.name)
    ui.selectedLabel:SetText(name and (Colorize(COLOR.dim, L("SELECTED")) .. "  " .. Colorize(COLOR.selected, name)) or "")
    local target = TravelTarget()
    ui.actions.travel:SetEnabled(target ~= nil)
    ui.actions.travel:SetText((target and S.CanQueue(target))
        and (zo_iconFormat(TEX_QUEUE, 22, 22) .. " " .. L("BTN_QUEUE")) or L("BTN_TRAVEL"))
end

local function ToggleWish(data)
    S.ToggleWish(data.setId)
    S.RefreshAll()
end

local function LinkInChat(data)
    if data.link then ZO_LinkHandler_InsertLink(data.link) end
end

-- Bottom button: travel, or for a dungeon the queue window.
local function TravelOrQueue()
    local zoneId = TravelTarget()
    if not zoneId then return end
    if S.CanQueue(zoneId) then
        S.OpenQueueDialog(zoneId, SetDataFor(ui.selected))
    else
        S.TravelTo(zoneId)
    end
end

-- Every location a set drops in (monster dungeon first).
local function SetLocationIds(data)
    data = SetDataFor(data)
    local ids, seen = {}, {}
    local function add(id)
        if id and not seen[id] and S.GetLocation(id) then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    if data.monster then add(data.monster.zoneId) end
    for _, sourceId in ipairs(data.sourceIds or {}) do add(sourceId) end
    return ids
end

-- Where "Show where it drops" goes: the first place that isn't the one already
-- on screen, or the next one when a set drops in several places. nil = nowhere else.
local function NextLocationFor(data)
    local ids = SetLocationIds(data)
    for i, id in ipairs(ids) do
        if id == ui.viewLocId then
            local nextId = ids[i % #ids + 1]
            return nextId ~= id and nextId or nil
        end
    end
    return ids[1]
end

-- ---------------------------------------------------------------------------
-- Back / forward: every page change remembers where you were, like a web browser.
-- ---------------------------------------------------------------------------
local MAX_HISTORY = 50
local history, future = {}, {}

local function CurrentPage()
    return {
        view = S.sv.view,
        loc = S.sv.loc,
        itemsSetId = ui.itemsSetId,
        boostKey = ui.boostKey,
        search = ui.search and ui.search:GetText() or "",
    }
end

local function SamePage(a, b)
    return a and b and a.view == b.view and a.loc == b.loc
        and a.itemsSetId == b.itemsSetId and a.boostKey == b.boostKey and a.search == b.search
end

local function UpdateNavButtons()
    if not ui.back then return end
    ui.back:SetNavEnabled(#history > 0)
    ui.forward:SetNavEnabled(#future > 0)
end

-- Call right before changing the page.
local function RememberPage()
    local page = CurrentPage()
    if SamePage(page, history[#history]) then return end
    history[#history + 1] = page
    if #history > MAX_HISTORY then table.remove(history, 1) end
    ZO_ClearNumericallyIndexedTable(future)
    UpdateNavButtons()
end

local function ShowPage(page)
    S.sv.view, S.sv.loc = page.view, page.loc
    ui.itemsSetId = page.itemsSetId
    ui.boostKey = page.boostKey
    if page.loc then S.sv.open[page.view] = true end
    ui.selected = nil
    ui.restoring = true    -- setting the search text below isn't a new page
    ui.search:SetText(page.search or "")
    ui.restoring = false
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
    UpdateNavButtons()
end

function S.GoBack()
    if #history == 0 then return end
    future[#future + 1] = CurrentPage()
    ShowPage(table.remove(history))
end

function S.GoForward()
    if #future == 0 then return end
    history[#history + 1] = CurrentPage()
    ShowPage(table.remove(future))
end

-- Reward systems a set comes from that you can start from here: { "RANDOM", ... }
local function SourceActionsFor(data)
    local keys = {}
    if not IsSetLike(data) then return keys end
    local set = SetDataFor(data)
    for _, id in ipairs(set and set.sourceIds or {}) do
        local key = id < 0 and SpecialSourceKey({ id = id }) or nil
        if ReadySourceAction(key) then keys[#keys + 1] = key end
    end
    return keys
end

-- What a double-click on a row does: "goto" (where it drops, if that's somewhere
-- else than the page you're on), a reward system key (open / queue it), or nil.
local function DoubleClickAction(data)
    if not data then return nil end
    if data.kind == "summary" then return "open" end   -- overview row: open that category
    if (IsSetLike(data) or data.monster) and NextLocationFor(data) then return "goto" end
    return SourceActionsFor(data)[1]
end

-- Open the location a set drops in, with that set selected and scrolled into view.
local function GoToSet(data, locId)
    local loc = S.GetLocation(locId or NextLocationFor(data))
    if not loc then return end
    RememberPage()
    S.sv.view, S.sv.loc = loc.kind, loc.id
    S.sv.open[loc.kind] = true
    ui.selected = nil
    ui.itemsSetId = nil
    ui.boostKey = nil
    ui.search:SetText("")   -- OnTextChanged refreshes
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
    if not data.setId then return end

    for index, entry in ipairs(ZO_ScrollList_GetDataList(ui.list)) do
        if entry.data and entry.data.kind == "set" and entry.data.setId == data.setId then
            ZO_ScrollList_ScrollDataIntoView(ui.list, index)
            ZO_ScrollList_SelectData(ui.list, entry.data)
            ui.selected = entry.data
            UpdateActionButtons()
            break
        end
    end
end

-- The items you own for one XP boost (scrolls, Ambrosia, Training gear...).
local function ShowBoostItems(key)
    RememberPage()
    S.sv.view, S.sv.loc = "boost_items", nil
    ui.itemsSetId = nil
    ui.boostKey = key
    ui.selected = nil
    ui.search:SetText("")
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

-- "My items" for one set.
local function ShowMyPieces(setId)
    RememberPage()
    S.sv.view, S.sv.loc = "items", nil
    S.sv.itemsScope = nil   -- all your pieces of the set, whoever has them
    ui.itemsSetId = setId
    ui.boostKey = nil
    ui.selected = nil
    ui.search:SetText("")
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

-- Click on a bag count: a set's pieces, or a boost's items.
local function OpenOwned(data)
    if data.kind == "set" then
        ShowMyPieces(data.setId)
    elseif data.boostSetId then
        ShowMyPieces(data.boostSetId)
    elseif data.boostKey then
        ShowBoostItems(data.boostKey)
    end
end

-- ---------------------------------------------------------------------------
-- Category tree (left)
-- ---------------------------------------------------------------------------
local function IsCategorySelected(data)
    if data.loc then return S.sv.view == data.view and S.sv.loc == data.loc end
    local view = S.sv.view == "boost_items" and "xp_boosts" or S.sv.view
    return view == data.view and S.sv.loc == nil
end

local function SetupTreeHeader(control, data)
    control:GetNamedChild("Text"):SetText(data.text)
end

local function PaintCategory(control, hovered)
    local data = control.data
    local selected = data and IsCategorySelected(data)
    control:GetNamedChild("SelBG"):SetHidden(not selected)
    control:GetNamedChild("SelBar"):SetHidden(not selected)
    SetHexColor(control:GetNamedChild("Text"), (selected or hovered) and COLOR.selected or COLOR.normal)
    local icon = control:GetNamedChild("Icon")
    if icon then icon:SetAlpha((selected or hovered) and 1 or 0.75) end
end

local function SetupCategory(control, data)
    control.data = data
    control:GetNamedChild("Text"):SetText(data.text or L(data.key))
    local count = control:GetNamedChild("Count")
    count:SetText(data.count or "")
    SetHexColor(count, data.countColor or COLOR.dim)

    local arrow = control:GetNamedChild("Arrow")
    if arrow then
        arrow:SetHidden(not (data.kind or data.expand))
        arrow:SetTexture(S.sv.open[data.view] and ARROW_OPEN or ARROW_CLOSED)
    end
    local icon = control:GetNamedChild("Icon")
    if icon then icon:SetTexture(data.icon) end
    PaintCategory(control, false)
end

-- Counts shown on the right of the tree.
local function CategoryCount(cat)
    if cat.view == "wishlist" then
        local n = 0
        for _ in pairs(S.sv.wishlist) do n = n + 1 end
        return n > 0 and tostring(n) or nil
    elseif cat.view == "traithunt" then
        local n = 0
        for _ in pairs(S.sv.wishTraits) do n = n + 1 end
        return n > 0 and tostring(n) or nil
    elseif cat.view == "xp_daily" then
        local n = 0
        for _, reward in ipairs(S.DailyRewards()) do
            if reward.open then n = n + 1 end
        end
        return n > 0 and tostring(n) or nil, COLOR.good
    elseif cat.view == "almost" then
        local n = #AlmostIds()
        return n > 0 and tostring(n) or nil, COLOR.good
    elseif cat.view == "recent" then
        local n = #S.sv.recent
        return n > 0 and tostring(n) or nil
    elseif cat.view == "crafted" then
        local n = 0
        for _, list in pairs(CraftedIds()) do n = n + #list end
        return n > 0 and tostring(n) or nil
    elseif cat.view == "overview" then
        local all = OverviewStats().all
        return all.sets > 0 and string.format("%d%%", zo_floor(all.done / all.sets * 100)) or nil
    elseif cat.expand == "groups" then
        local n = #ItemGroups(ITEM_MODES[cat.view])
        return n > 0 and tostring(n) or nil
    elseif ITEM_MODES[cat.view] then
        local mode, n = ITEM_MODES[cat.view], 0
        for _, entries in pairs(S.GetOwnedIndex()) do
            for _, entry in ipairs(entries) do
                if InScope(entry) and (not mode.filter or mode.filter(entry, S.PieceInfo(entry))) then n = n + 1 end
            end
        end
        return n > 0 and tostring(n) or nil, mode.countColor
    elseif cat.kind then
        return tostring(#S.GetLocations(cat.kind))
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Tabs (Sets / My items / XP farming) next to the title
-- ---------------------------------------------------------------------------
local TABS = { "TREE_SETS", "TREE_ITEMS", "TREE_XP" }
local TAB_START = { TREE_SETS = "here", TREE_ITEMS = "items", TREE_XP = "xp_spots" }

local function CurrentTab()
    local view = S.sv.view == "boost_items" and "xp_boosts" or S.sv.view
    local tab = SECTION_OF[view] or "TREE_SETS"
    -- set search results live under Sets, whatever tab you typed in
    if tab ~= "TREE_ITEMS" and ui.search and (ui.search:GetText() or "") ~= "" then tab = "TREE_SETS" end
    return tab
end

-- our own outline icons (white, tinted in PaintTabs): shield, backpack, rising arrow
local TAB_ICONS = {
    TREE_SETS = "SetHunter/Textures/tab_sets.dds",
    TREE_ITEMS = "SetHunter/Textures/tab_items.dds",
    TREE_XP = "SetHunter/Textures/tab_xp.dds",
}
local TAB_ICON_SIZE, TAB_ICON_GAP = 20, 6

local function PaintTabs()
    if not ui.tabs then return end
    local current = CurrentTab()
    for key, tab in pairs(ui.tabs) do
        local on = key == current
        SetHexColor(tab, (on or tab.hovered) and COLOR.selected or COLOR.dim)
        -- icon: bronze on the active tab, white under the mouse, grey otherwise
        SetHexColor(tab.icon, on and COLOR.theme or (tab.hovered and COLOR.selected or COLOR.dim))
        tab.line:SetHidden(not on)
        -- underline under icon and name together
        tab.line:SetWidth(tab:GetTextWidth() + TAB_ICON_SIZE + TAB_ICON_GAP)
    end
end

local function SelectTab(key)
    local current = CurrentTab()
    if key == current then return end
    RememberPage()
    ui.tabView = ui.tabView or {}
    if SECTION_OF[S.sv.view] == current then
        ui.tabView[current] = { view = S.sv.view, loc = S.sv.loc }
    end
    local last = ui.tabView[key]
    S.sv.view = last and last.view or TAB_START[key]
    S.sv.loc = last and last.loc
    ui.itemsSetId, ui.boostKey, ui.selected = nil, nil, nil
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ui.restoring = true
    ui.search:SetText("")
    ui.restoring = false
    ui.search:LoseFocus()
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

-- My items dropdown: All characters / one character / Bank / House storage
local function SetScope(value)
    if S.sv.itemsScope == value then return end
    S.sv.itemsScope = value
    ui.selected = nil
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

local function FillScope()
    local box = ui.scope
    if not box or (box.IsDropdownVisible and box:IsDropdownVisible()) then return end
    local choices = ScopeChoices()
    -- the picked character was deleted: back to All
    local found = S.sv.itemsScope == nil
    for _, choice in ipairs(choices) do
        if choice.value ~= nil and choice.value == S.sv.itemsScope then found = true end
    end
    if not found then S.sv.itemsScope = nil end
    box:ClearItems()
    local selectedText = choices[1].text
    for _, choice in ipairs(choices) do
        local value = choice.value
        -- refresh a frame later, not while the dropdown is still handling the click
        box:AddItem(box:CreateItemEntry(choice.text, function()
            zo_callLater(function() SetScope(value) end, 1)
        end), ZO_COMBOBOX_SUPPRESS_UPDATE)
        if value ~= nil and value == S.sv.itemsScope then selectedText = choice.text end
    end
    box:SetSelectedItemText(selectedText)
end

local function RefreshTree()
    ZO_ScrollList_Clear(ui.tree)
    local scrollData = ZO_ScrollList_GetDataList(ui.tree)
    local tab = CurrentTab()
    -- missing only / alerts are about sets; elsewhere the tree moves up under the search
    local onSets = tab == "TREE_SETS"
    ui.missingToggle:SetHidden(not onSets)
    ui.announceToggle:SetHidden(not onSets)
    -- the character dropdown (shown on My items' badge row, see LayoutRight)
    if tab == "TREE_ITEMS" then FillScope() end
    ui.tree:ClearAnchors()
    ui.tree:SetAnchor(TOPLEFT, onSets and ui.missingToggle or ui.searchBox, BOTTOMLEFT, 0, 6)
    ui.tree:SetAnchor(BOTTOMLEFT, ui.divider2, TOPLEFT, 0, -8)
    PaintTabs()

    local section
    for _, cat in ipairs(CATEGORIES) do
        if cat.header then
            section = cat.header
        elseif section == tab then
            local locations = cat.kind and S.GetLocations(cat.kind)
            if not locations or #locations > 0 then
                cat.count, cat.countColor = CategoryCount(cat)
                scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_CATEGORY, cat)
                if locations and S.sv.open[cat.view] then
                    for _, loc in ipairs(locations) do
                        -- "2/4": sets complete here / sets with a collection here.
                        local done, total = Progress(S.GetSetsForLocation(loc.id, true))
                        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_SUB, {
                            text = loc.name, view = cat.view, loc = loc.id,
                            count = total > 0 and string.format("%d/%d", done, total) or nil,
                            countColor = (total > 0 and done == total) and COLOR.good or nil,
                        })
                    end
                end
                -- Wishlist: Whole sets (count of sets) and Wanted pieces (count of pieces)
                if cat.expand == "wish" and S.sv.open[cat.view] then
                    local whole, pieces = 0, 0
                    for setId in pairs(S.sv.wishlist) do
                        if S.HasWishPieces(setId) then
                            for _ in pairs(S.sv.wishPieces[setId]) do pieces = pieces + 1 end
                        else
                            whole = whole + 1
                        end
                    end
                    scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_SUB, {
                        text = L("CAT_WISH_WHOLE"), view = cat.view, loc = "whole", count = tostring(whole),
                    })
                    scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_SUB, {
                        text = L("CAT_WISH_PIECES"), view = cat.view, loc = "pieces", count = tostring(pieces),
                    })
                end
                -- By trait / slot / quality / ...: one entry per group, with how many pieces
                if cat.expand == "groups" and S.sv.open[cat.view] then
                    for _, group in ipairs(ItemGroups(ITEM_MODES[cat.view])) do
                        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_SUB, {
                            text = group.name, view = cat.view, loc = group.key, count = tostring(group.count),
                        })
                    end
                end
            end
        end
    end
    ZO_ScrollList_Commit(ui.tree)
end

function S.Category_OnMouseEnter(control)
    PaintCategory(control, true)
end

function S.Category_OnMouseExit(control)
    PaintCategory(control, false)
end

function S.Category_OnMouseUp(control, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not control.data then return end
    local data, sv = control.data, S.sv
    local samePage = IsCategorySelected(data) and ui.itemsSetId == nil and (ui.search:GetText() or "") == ""
    if not samePage then RememberPage() end
    ui.itemsSetId = nil
    ui.boostKey = nil
    if data.loc then
        sv.view, sv.loc = data.view, data.loc
    elseif data.kind or data.expand then
        -- First click opens it and shows everything; clicking it again while shown closes it.
        if sv.view == data.view and sv.loc == nil then
            sv.open[data.view] = not sv.open[data.view]
        else
            sv.open[data.view] = true
        end
        sv.view, sv.loc = data.view, nil
    else
        sv.view, sv.loc = data.view, nil
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ZO_ScrollList_ResetToTop(ui.list)
    ui.search:SetText("")
    ui.search:LoseFocus()
    S.RefreshAll()
end

-- ---------------------------------------------------------------------------
-- List (right)
-- ---------------------------------------------------------------------------
-- Shortcut icon at the end of a row: queue for its dungeon, or travel to its place.
-- Worked out once per row (finding a dungeon's queue entry takes a moment).
local TEX_TRAVEL = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds"
local ACTION_ALPHA, ACTION_ALPHA_HOVER = 0.55, 1
local OWNED_ALPHA = 0.6

-- returns zoneId, queue (dungeon), source (nowhere to travel, but a reward system to
-- start: "ANTIQUITIES" / "RANDOM" / "BATTLEGROUNDS")
local function RowAction(data)
    if data.actionChecked ~= ui.reachGen then
        data.actionChecked = ui.reachGen
        data.actionZone = TargetFor(data)
        data.actionQueue = data.actionZone ~= nil and S.CanQueue(data.actionZone)
        -- a row can name its own (Daily bonuses), else the set's reward systems
        local own = data.sourceAction and ReadySourceAction(data.sourceAction) and data.sourceAction
        data.actionSource = data.actionZone == nil and (own or SourceActionsFor(data)[1]) or nil
    end
    return data.actionZone, data.actionQueue, data.actionSource
end

-- trials and arenas get their own map icon, so they don't look like a plain wayshrine
local function ActionIcon(zoneId, queue)
    if queue then return TEX_QUEUE end
    local loc = S.GetLocation(zoneId)
    if loc and loc.kind == "trial" then return "EsoUI/Art/Icons/poi/poi_raiddungeon_complete.dds" end
    if loc and loc.kind == "arena" then return "EsoUI/Art/Icons/poi/poi_solotrial_complete.dds" end
    return TEX_TRAVEL
end

local function SetupAction(row, data)
    local action = row:GetNamedChild("Action")
    if not action then return end
    local zoneId, queue, source = RowAction(data)
    action:SetHidden(zoneId == nil and not source)
    if zoneId or source then
        action:SetTexture(source and SOURCE_ACTIONS[source].icon() or ActionIcon(zoneId, queue))
        action:SetAlpha(ACTION_ALPHA)
    end
end

local function DoRowAction(data)
    local zoneId, queue, source = RowAction(data)
    if source then
        SOURCE_ACTIONS[source].run()
        return
    end
    if not zoneId then return end
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    if queue then
        S.OpenQueueDialog(zoneId, SetDataFor(data))
    else
        S.TravelTo(zoneId)
    end
end

-- "Icon: queue for Arx Corinium" line for the row tooltips.
local function ActionHint(data)
    local zoneId, queue, source = RowAction(data)
    if source then
        local action = SOURCE_ACTIONS[source]
        return L(action.hint, zo_iconFormat(action.icon(), 18, 18))
    end
    if not zoneId then return nil end
    local icon = zo_iconFormat(ActionIcon(zoneId, queue), 18, 18)
    if queue then return L("TT_ACTION_QUEUE", icon, S.ZoneName(zoneId)) end
    -- group content: say so, so nobody ports there alone by accident
    local note = S.GroupNote(zoneId)
    if note then return note .. "\n" .. L("TT_ACTION_TRAVEL", icon, S.ZoneName(zoneId)) end
    return L("TT_ACTION_TRAVEL", icon, S.ZoneName(zoneId))
end

-- Overview rows: the category icon at the start of the PIECES column opens it (one click)
local function IsOverSummaryIcon(row, data)
    if not data or data.kind ~= "summary" then return false end
    local label = row:GetNamedChild("Type")
    if not label then return false end
    local x, y = GetUIMousePosition()
    return x >= label:GetLeft() - 3 and x <= label:GetLeft() + 24
        and y >= label:GetTop() and y <= label:GetBottom()
end

local function OpenSummary(data)
    RememberPage()
    S.sv.view, S.sv.loc = data.view, nil
    ui.selected = nil
    ClearTooltip(InformationTooltip)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

local function IsOverAction(row)
    local action = row:GetNamedChild("Action")
    return action ~= nil and not action:IsHidden() and IsMouseOver(action, 4)
end

-- The "bag 2" owned count is a shortcut too: on set rows it opens My items for that
-- set, on XP boost rows the list of those boost items.
local function HasOwnedShortcut(data)
    return data ~= nil and (data.kind == "set" or data.boostKey ~= nil) and (data.owned or 0) > 0
end

local function IsOverOwned(row, data)
    if not HasOwnedShortcut(data) then return false end
    local icon, owned = row:GetNamedChild("OwnedIcon"), row:GetNamedChild("Owned")
    return (icon ~= nil and IsMouseOver(icon, 3)) or (owned ~= nil and IsMouseOver(owned, 2))
end

-- Bag icon + count: dim normally; under the mouse the icon switches to ESO's bright
-- hover version of it and the count turns white.
local TEX_BAG_OVER = "EsoUI/Art/MainMenu/menuBar_inventory_over.dds"
local function PaintOwned(row, hovered)
    local icon, owned = row:GetNamedChild("OwnedIcon"), row:GetNamedChild("Owned")
    if icon then
        icon:SetTexture(hovered and TEX_BAG_OVER or TEX_BAG)
        icon:SetAlpha(hovered and 1 or OWNED_ALPHA)
    end
    if owned then SetHexColor(owned, hovered and COLOR.selected or COLOR.accent) end
end

-- Rows are as wide as the list (which follows the window size), minus the scrollbar.
local function FitRow(row)
    if ui.list then row:SetWidth(zo_max(ui.list:GetWidth() - 16, 300)) end
end

local function SetupSetRow(row, data)
    FitRow(row)
    SetupAction(row, data)
    -- overview rows (kind "summary") are categories, not sets: no wishlist star, no owned
    local summary = data.kind == "summary"
    local star = row:GetNamedChild("Star")
    star:SetHidden(summary)
    star:SetDesaturation(data.wish and 0 or 1)
    star:SetColor(unpack(data.wish and STAR_ON or STAR_OFF))

    local name = row:GetNamedChild("Name")
    name:SetText(data.name)
    SetHexColor(name, data.complete and COLOR.good or COLOR.normal)
    row:GetNamedChild("Stripe"):SetHidden(not data.stripe)

    -- Type: the set's own item icon + weight (or where it drops, in lists across places).
    local typeText = data.showWhere and data.sources or data.typeText
    -- mythic not made yet: how many of its fragments you've dug up ("Mythic  2/5")
    if not data.showWhere and not data.complete and data.typeText == L("TYPE_MYTHIC") then
        local frags = S.MythicFragments(data.setId)
        if frags and #frags > 0 then
            local found = 0
            for _, f in ipairs(frags) do if f.found then found = found + 1 end end
            typeText = typeText .. "  " .. Colorize(found > 0 and COLOR.accent or COLOR.dim, string.format("%d/%d", found, #frags))
        end
    end
    if data.icon and not data.showWhere then
        -- overview rows: the icon takes the text color, so it lights up on hover (it's clickable)
        local icon = summary and zo_iconFormatInheritColor(data.icon, 20, 20) or zo_iconFormat(data.icon, 20, 20)
        typeText = icon .. " " .. typeText
    end
    if summary then SetHexColor(row:GetNamedChild("Type"), COLOR.dim) end
    row:GetNamedChild("Type"):SetText(typeText)

    local hasOwned = data.owned > 0
    local ownedIcon, owned = row:GetNamedChild("OwnedIcon"), row:GetNamedChild("Owned")
    ownedIcon:SetHidden(not hasOwned)
    ownedIcon:SetTexture(TEX_BAG)
    ownedIcon:SetAlpha(OWNED_ALPHA)
    owned:ClearAnchors()
    owned:SetAnchor(LEFT, row, LEFT, hasOwned and 372 or 352, 0)
    owned:SetText(hasOwned and tostring(data.owned) or Colorize(COLOR.dim, "–"))
    if summary then owned:SetText("") end
    SetHexColor(owned, COLOR.accent)

    local info = row:GetNamedChild("Info")
    local barBG, barFill = row:GetNamedChild("BarBG"), row:GetNamedChild("BarFill")
    barBG:SetHidden(data.total == 0)
    barFill:SetHidden(data.total == 0)
    if data.total == 0 then
        info:SetText("")
        return
    end
    if data.complete then
        info:SetText(L("COMPLETE"))
        SetHexColor(info, COLOR.good)
    else
        info:SetText(L("COLLECTED", data.have, data.total))
        SetHexColor(info, COLOR.dim)
    end
    barFill:SetWidth(barBG:GetWidth() * data.have / data.total)
    SetHexColor(barFill, data.complete and COLOR.good or COLOR.theme)
end

local function SetupInfoRow(row, data)
    FitRow(row)
    row:GetNamedChild("Stripe"):SetHidden(not data.stripe)
    SetupAction(row, data)

    -- Icon in front of the name (XP boosts); the name moves right to make room.
    local icon, name = row:GetNamedChild("Icon"), row:GetNamedChild("Name")
    icon:SetHidden(data.icon == nil)
    if data.icon then icon:SetTexture(data.icon) end
    name:ClearAnchors()
    name:SetAnchor(LEFT, row, LEFT, data.icon and 36 or 10, 0)
    name:SetWidth(data.icon and 224 or 250)
    name:SetText(data.name)
    SetHexColor(name, data.nameColor or COLOR.normal)

    -- Owned (XP boost rows): bag icon + count, like on set rows.
    local ownedIcon, owned = row:GetNamedChild("OwnedIcon"), row:GetNamedChild("Owned")
    local info = row:GetNamedChild("Info")
    info:ClearAnchors()
    if data.owned ~= nil then
        local has = data.owned > 0
        ownedIcon:SetHidden(not has)
        ownedIcon:SetTexture(TEX_BAG)
        ownedIcon:SetAlpha(OWNED_ALPHA)
        owned:ClearAnchors()
        owned:SetAnchor(LEFT, row, LEFT, has and 288 or 268, 0)
        owned:SetText(has and tostring(data.owned) or Colorize(COLOR.dim, "–"))
        SetHexColor(owned, COLOR.accent)
        info:SetAnchor(LEFT, row, LEFT, 330, 0)
    else
        ownedIcon:SetHidden(true)
        owned:SetText("")
        info:SetAnchor(LEFT, row, LEFT, 268, 0)
    end
    info:SetAnchor(RIGHT, row, RIGHT, -34, 0)
    info:SetText(data.info or "")
    SetHexColor(info, data.infoColor or COLOR.dim)
end

local function SetupItemRow(row, entry)
    local piece = S.PieceInfo(entry)
    FitRow(row)
    row:GetNamedChild("Stripe"):SetHidden(not entry.stripe)
    SetupAction(row, entry)
    row:GetNamedChild("Icon"):SetTexture(piece.icon)
    if entry.isBoost then
        -- XP boost item: amount and quality instead of a trait.
        row:GetNamedChild("Name"):SetText(piece.coloredName)
        row:GetNamedChild("Trait"):SetText(Colorize(COLOR.selected, L("AMOUNT", entry.count)) .. "  " .. piece.quality)
    else
        local count = entry.count > 1 and ("  x" .. entry.count) or ""
        local star = S.IsWantedPiece(entry.setId, piece.slotKey) and (zo_iconFormat(TEX_STAR, 16, 16) .. " ") or ""
        row:GetNamedChild("Name"):SetText(star .. piece.coloredName .. count)
        local wanted = S.IsWantedTrait(entry.setId, piece.traitType)
        row:GetNamedChild("Trait"):SetText(wanted and Colorize(COLOR.good, piece.trait) or piece.trait)
    end
    local where = entry.where
    if piece.collected == false then
        where = Colorize(COLOR.accent, L("NOT_COLLECTED")) .. "  " .. where
    end
    row:GetNamedChild("Where"):SetText(where)
    -- rows get reused; drop any hover glow (the style color also tints the normal shadow)
    local name = row:GetNamedChild("Name")
    name:SetFont("ZoFontGame")
    name:SetStyleColor(0, 0, 0, 1)
end

local function SetupHeader(control, data)
    FitRow(control)
    control:GetNamedChild("Text"):SetText(zo_strupper(data.title))
end

-- "Head · Divines · Legendary · CP 160 — Bank" lines for the pieces you own.
local MAX_OWNED_LINES = 8
local function AddOwnedLines(tooltip, setId)
    local owned = S.GetOwned(setId)
    if #owned == 0 then return end
    local total = 0
    for _, entry in ipairs(owned) do total = total + entry.count end
    tooltip:AddLine(L("TT_OWNED", total), "ZoFontGame", HexToRGB(COLOR.accent))
    for i = 1, zo_min(#owned, MAX_OWNED_LINES) do
        local piece = S.PieceInfo(owned[i])
        tooltip:AddLine(string.format("%s  ·  %s  ·  %s  ·  %s  —  %s",
            piece.name, piece.trait, piece.quality, piece.level, owned[i].where), "ZoFontGameSmall", HexToRGB(COLOR.normal))
    end
    if #owned > MAX_OWNED_LINES then
        tooltip:AddLine(L("TT_MORE", #owned - MAX_OWNED_LINES), "ZoFontGameSmall", HexToRGB(COLOR.dim))
    end
end

-- Mythic (Antiquities): "Fragments: 2 / 5 found", then each fragment with the zone
-- its lead is dug up in and whether you have the lead / found it.
local function AddMythicLines(tooltip, setId)
    local frags = S.MythicFragments(setId)
    if not frags or #frags == 0 then return end
    local found = 0
    for _, f in ipairs(frags) do if f.found then found = found + 1 end end
    tooltip:AddLine(L("TT_FRAGMENTS", found, #frags), "ZoFontGame", HexToRGB(COLOR.header))
    for _, f in ipairs(frags) do
        local state = f.found and Colorize(COLOR.good, L("FRAG_FOUND"))
            or f.lead and Colorize(COLOR.accent, L("FRAG_LEAD"))
            or Colorize(COLOR.dim, L("FRAG_NO_LEAD"))
        local zone = (f.zoneId and f.zoneId ~= 0) and S.ZoneName(f.zoneId) or L("FRAG_ANY_ZONE")
        tooltip:AddLine(string.format("%s  —  %s  ·  %s", f.name, zone, state), "ZoFontGameSmall", HexToRGB(COLOR.normal))
    end
    tooltip:AddLine(L("TT_FRAGMENTS_HOW"), "ZoFontGameSmall", HexToRGB(COLOR.dim))
end

-- Crafted sets: traits needed, and which item types this character can't make yet
-- ("Helmet 2/3, Bow 1/3")
local MAX_CRAFT_MISSING = 10
local function AddCraftLines(tooltip, setId)
    local n = S.CraftTraitsNeeded(setId)
    if not n then return end
    tooltip:AddLine(L("TT_CRAFT_NEED", n), "ZoFontGame", HexToRGB(COLOR.header))
    local missing, total = {}, 0
    for _, line in ipairs(S.ResearchLines()) do
        if line.known < n then
            total = total + 1
            if #missing < MAX_CRAFT_MISSING then
                missing[#missing + 1] = string.format("%s %d/%d", line.name, line.known, n)
            end
        end
    end
    if total == 0 then
        tooltip:AddLine(L("TT_CRAFT_ALL"), "ZoFontGameSmall", HexToRGB(COLOR.good))
    else
        if total > #missing then missing[#missing + 1] = L("TT_MORE_SHORT", total - #missing) end
        tooltip:AddLine(L("TT_CRAFT_MISSING", table.concat(missing, ", ")), "ZoFontGameSmall", HexToRGB(COLOR.normal))
    end
end

-- XP boost rows: what you own of it and who has it
-- ("Crown Experience Scroll  ·  x5  ·  Legendary  —  Bank").
local function AddBoostLines(tooltip, data)
    if (data.owned or 0) == 0 then return end
    if data.boostSetId then
        AddOwnedLines(tooltip, data.boostSetId)
    else
        local items = S.GetBoostItems(data.boostKey)
        tooltip:AddLine(L("TT_OWNED", data.owned), "ZoFontGame", HexToRGB(COLOR.accent))
        for i = 1, zo_min(#items, MAX_OWNED_LINES) do
            local piece = S.PieceInfo(items[i])
            tooltip:AddLine(string.format("%s  ·  x%d  ·  %s  —  %s",
                piece.name, items[i].count, piece.quality, items[i].where), "ZoFontGameSmall", HexToRGB(COLOR.normal))
        end
        if #items > MAX_OWNED_LINES then
            tooltip:AddLine(L("TT_MORE_SHORT", #items - MAX_OWNED_LINES), "ZoFontGameSmall", HexToRGB(COLOR.dim))
        end
    end
    tooltip:AddLine(L("TT_OWNED_CLICK", zo_iconFormat(TEX_BAG, 18, 18)), "ZoFontGameSmall", HexToRGB(COLOR.accent))
end

local function ItemTooltipLines(entry)
    local piece = S.PieceInfo(entry)
    local line = L("TT_WHERE", entry.where)
    if entry.count > 1 then line = line .. "  (x" .. entry.count .. ")" end
    ItemTooltip:AddLine(line, "ZoFontGame", HexToRGB(COLOR.accent))
    if entry.how then
        ItemTooltip:AddLine(entry.how, "ZoFontGameSmall", HexToRGB(COLOR.normal))
    end
    if entry.t then
        ItemTooltip:AddLine(L("TT_UPDATED", S.FormatAgo(entry.t)), "ZoFontGameSmall", HexToRGB(COLOR.dim))
    end
    ItemTooltip:AddLine(entry.bound and L("TT_BOUND") or L("TT_UNBOUND"), "ZoFontGameSmall", HexToRGB(COLOR.normal))
    if S.IsWantedPiece(entry.setId, piece.slotKey) then
        ItemTooltip:AddLine(L("TT_WANTED_PIECE"), "ZoFontGameSmall", HexToRGB(COLOR.good))
    end
    if S.IsWantedTrait(entry.setId, piece.traitType) then
        ItemTooltip:AddLine(L("TT_WANTED_TRAIT"), "ZoFontGameSmall", HexToRGB(COLOR.good))
    end
    if piece.collected == false then
        ItemTooltip:AddLine(entry.bound and L("TT_NOT_COLLECTED") or L("TT_BIND_TO_COLLECT"),
            "ZoFontGameSmall", HexToRGB(COLOR.accent))
    elseif piece.collected then
        ItemTooltip:AddLine(L("TT_COLLECTED"), "ZoFontGameSmall", HexToRGB(COLOR.good))
    end
end

local function NameColor(data)
    if data.kind == "set" then return data.complete and COLOR.good or COLOR.normal end
    return data.nameColor or COLOR.normal
end

-- ---------------------------------------------------------------------------
-- Locate an item: open the bag on a piece from this character's backpack
-- ---------------------------------------------------------------------------
local BACKPACK_BAGS = { BAG_BACKPACK }

local function FindIn(bags, link)
    for _, bagId in ipairs(bags) do
        local slot = ZO_GetNextBagSlotIndex(bagId)
        while slot do
            if GetItemLink(bagId, slot) == link then return bagId, slot end
            slot = ZO_GetNextBagSlotIndex(bagId, slot)
        end
    end
    return nil
end

local flash
local function FlashRow(row)
    if not flash then
        local top = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_BagFlash")
        top:SetDrawTier(DT_HIGH)
        top:SetMouseEnabled(false)
        local tex = WINDOW_MANAGER:CreateControl("SetHunter_BagFlashTex", top, CT_TEXTURE)
        tex:SetAnchorFill(top)
        SetHexColor(tex, COLOR.theme)
        local anim = ANIMATION_MANAGER:CreateTimeline()
        local pulse = anim:InsertAnimation(ANIMATION_ALPHA, top)
        pulse:SetAlphaValues(0, 0.45)
        pulse:SetDuration(350)
        anim:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, 5)
        flash = { top = top, anim = anim }
    end
    flash.top:ClearAnchors()
    flash.top:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    flash.top:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
    flash.top:SetHidden(false)
    flash.anim:PlayFromStart()
    -- rows get recycled when scrolling, so don't let it linger
    zo_callLater(function() flash.top:SetHidden(true) end, 2200)
end

-- pcall'd: this pokes at ESO's own inventory internals, which can change with patches
local function HighlightIn(invType, bagId, slot)
    pcall(function()
        local inv = PLAYER_INVENTORY.inventories[invType]
        if inv.filterBar and ITEMFILTERTYPE_ALL then ZO_MenuBar_SelectDescriptor(inv.filterBar, ITEMFILTERTYPE_ALL) end
        zo_callLater(function()
            pcall(function()
                local list = inv.listView
                for i, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
                    local d = entry.data
                    if d.bagId == bagId and d.slotIndex == slot then
                        ZO_ScrollList_ScrollDataIntoView(list, i, nil, true)
                        zo_callLater(function()
                            for c = 1, list.contents:GetNumChildren() do
                                local row = list.contents:GetChild(c)
                                if not row:IsHidden() and row.dataEntry and row.dataEntry.data == d then
                                    FlashRow(row)
                                    return
                                end
                            end
                        end, 60)
                        return
                    end
                end
            end)
        end, 60)
    end)
end

-- same size as ZoFontGame, with a thin outline we can color
local FONT_GLOW = "$(MEDIUM_FONT)|$(KB_18)|outline"

-- this character's backpack; bank pieces only while the bank is open
-- (the bag can't be opened on top of the bank)
local function CanLocate(data)
    if data == nil or data.kind ~= "item" then return false end
    if ui.atBank then return data.whereKind == "bank" end
    return data.inMyBag == true
end

local BANK_BAGS = { BAG_BANK, BAG_SUBSCRIBER_BANK }   -- no esoplus bag on old clients: ipairs stops

-- the bank opens on Withdraw, but you may have switched to Deposit
local function ShowWithdrawTab()
    if ZO_PlayerBankMenuBar and SI_BANK_WITHDRAW then
        pcall(ZO_MenuBar_SelectDescriptor, ZO_PlayerBankMenuBar, SI_BANK_WITHDRAW)
    end
end

function S.LocateItem(data)
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
    PlaySound(SOUNDS.DEFAULT_CLICK)

    if ui.atBank then
        local bagId, slot = FindIn(BANK_BAGS, data.link)
        if not slot then
            S.Print(L("BANK_GONE"))
            return
        end
        ShowWithdrawTab()
        HighlightIn(INVENTORY_BANK, bagId, slot)
        return
    end

    local _, slot = FindIn(BACKPACK_BAGS, data.link)
    if not slot then
        S.Print(L("BAG_GONE"))
        return
    end
    local scene = SCENE_MANAGER:GetScene("inventory")
    if scene:IsShowing() then
        HighlightIn(INVENTORY_BACKPACK, BAG_BACKPACK, slot)
        return
    end
    local function OnState(_, newState)
        if newState == SCENE_SHOWN then
            scene:UnregisterCallback("StateChange", OnState)
            HighlightIn(INVENTORY_BACKPACK, BAG_BACKPACK, slot)
        end
    end
    scene:RegisterCallback("StateChange", OnState)
    SCENE_MANAGER:Show("inventory")
end


-- ---------------------------------------------------------------------------
-- Wanted traits menu (right-click a wishlist set > Wanted traits...)
-- ---------------------------------------------------------------------------
local function TraitGroupsFor(setId)
    -- only the trait columns for gear the set really has (from its Set Collection pieces)
    local has = {}
    for _, piece in ipairs(S.SetPieces(setId)) do has[piece.group] = true end
    local noPieces = next(has) == nil   -- no collection data: offer everything
    local groupOf = { TRAITS_ARMOR = "armor", TRAITS_WEAPON = "weapon", TRAITS_JEWELRY = "jewelry" }
    local list = {}
    for _, group in ipairs(S.TraitGroups()) do
        if #group.list > 0 and (noPieces or has[groupOf[group.key]]) then list[#list + 1] = group end
    end
    return list
end

-- Small popup with columns of toggles (wanted traits, wanted pieces). Stays open while
-- you click, closes with its x, or when the window closes / a game menu opens.
local PICK_COL_W, PICK_ROW_H, PICK_PAD, PICK_TOP, PICK_NOTE_H = 200, 24, 18, 72, 60
local picker = {}

local function ClosePicker()
    if picker.win then picker.win:SetHidden(true) end
end
S.ClosePicker = ClosePicker

local function PaintPick(label)
    local item = label.item
    local on = picker.isOn(item)
    local text = item.name
    if item.icon then text = zo_iconFormat(item.icon, 20, 20) .. " " .. text end
    if on then text = text .. " " .. zo_iconFormat(TEX_STAR, 14, 14) end
    if item.note then text = text .. "  " .. Colorize(COLOR.dim, item.note) end
    label:SetText(text)
    SetHexColor(label, label.hovered and COLOR.selected or (on and COLOR.theme or COLOR.normal))
end

-- only the labels in use right now (IsHidden can't be trusted while the popup itself
-- is still hidden, which left rows blank until hovered)
local function PaintPicker()
    for i = 1, picker.used or 0 do PaintPick(picker.labels[i]) end
end

-- columns share the popup's width, so dragging it wider spreads them out
local function LayoutPicker()
    local win = picker.win
    local w = win:GetWidth()
    local colW = (w - PICK_PAD * 2) / zo_max(picker.cols or 1, 1)
    local top = picker.top or PICK_TOP
    picker.title:SetWidth(w - PICK_PAD * 2 - 30)
    picker.divider:SetDividerWidth(w - PICK_PAD * 2)
    picker.note:SetWidth(w - PICK_PAD * 2)
    for c = 1, picker.cols or 0 do
        local head = picker.heads[c]
        head:ClearAnchors()
        head:SetAnchor(TOPLEFT, win, TOPLEFT, PICK_PAD + (c - 1) * colW, top - 24)
        head:SetWidth(colW - 10)
    end
    for i = 1, picker.used or 0 do
        local label = picker.labels[i]
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, win, TOPLEFT, PICK_PAD + (label.col - 1) * colW, top + (label.row - 1) * PICK_ROW_H)
        label:SetWidth(colW - 10)
    end
end

local function CreatePicker()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_Picker")
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)   -- clicks on the panel don't fall through to the list
    win:SetHidden(true)
    win:SetClampedToScreen(true)
    -- drag anywhere on the panel to move it; edges and corners resize it (the game
    -- shows its double-arrow cursor there). Both are remembered.
    win:SetMovable(true)
    win:SetResizeHandleSize(8)
    win:SetHandler("OnMoveStop", function(self)
        S.sv.pickX, S.sv.pickY = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, S.sv.pickX, S.sv.pickY)
    end)
    win:SetHandler("OnResizeStart", function(self)
        self:SetHandler("OnUpdate", LayoutPicker)
    end)
    win:SetHandler("OnResizeStop", function(self)
        self:SetHandler("OnUpdate", nil)
        S.sv.pickW, S.sv.pickH = self:GetWidth(), self:GetHeight()
        S.sv.pickX, S.sv.pickY = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, S.sv.pickX, S.sv.pickY)
        LayoutPicker()
    end)
    local bg = WINDOW_MANAGER:CreateControl("SetHunter_PickerBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, 0.95)
    bg:SetEdgeColor(HexToRGB(COLOR.theme))
    bg:SetEdgeTexture("", 1, 1, 1)

    picker.title = MakeLabel("SetHunter_PickerTitle", win, "ZoFontWinH4", 400, 30, COLOR.selected)
    picker.title:SetAnchor(TOPLEFT, win, TOPLEFT, PICK_PAD, 10)
    picker.divider = MakeDivider("SetHunter_PickerDivider", win, 400)
    picker.divider:SetAnchor(TOPLEFT, picker.title, BOTTOMLEFT, 0, 2)
    -- what picking does (up to 3 lines under the title)
    picker.note = MakeLabel("SetHunter_PickerNote", win, "ZoFontGameSmall", 400, PICK_NOTE_H, COLOR.dim)
    picker.note:SetVerticalAlignment(TEXT_ALIGN_TOP)
    picker.note:SetAnchor(TOPLEFT, picker.divider, BOTTOMLEFT, 0, 6)

    local close = MakeTextButton("SetHunter_PickerClose", win, "x", "$(BOLD_FONT)|20|soft-shadow-thin", 24, L("CLOSE"), ClosePicker)
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 8)

    -- bottom: ESO buttons. Left: "Any trait" / "Whole set" (clears the picks, keeps the
    -- set on the wishlist and closes); right: Done
    picker.clear = MakeButton("SetHunter_PickerClear", win, "", 200, function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        picker.onClear()
        ClosePicker()
    end)
    picker.clear:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PICK_PAD, -12)
    local done = MakeButton("SetHunter_PickerDone", win, L("DONE"), 120, ClosePicker)
    done:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PICK_PAD, -12)

    picker.heads, picker.labels = {}, {}
    picker.win = win
end

-- groups: { { title, list = { { name, note? }, ... } }, ... } one column each
local function OpenPicker(title, clearText, groups, isOn, onToggle, onClear, anyOn, note)
    if not picker.win then CreatePicker() end
    picker.isOn, picker.onToggle, picker.onClear, picker.anyOn = isOn, onToggle, onClear, anyOn
    local win = picker.win
    picker.note:SetText(note or "")
    picker.note:SetHidden(note == nil)
    picker.top = note and (PICK_TOP + PICK_NOTE_H) or PICK_TOP

    local rows = 0
    for _, group in ipairs(groups) do rows = zo_max(rows, #group.list) end
    picker.cols = #groups
    -- can't be made smaller than its content; your own size / spot is reused
    local minW = PICK_PAD * 2 + zo_max(#groups, 2) * 150
    if note then minW = zo_max(minW, 560) end
    local minH = picker.top + rows * PICK_ROW_H + 50
    local width = zo_max(S.sv.pickW or (PICK_PAD * 2 + zo_max(#groups, 2) * PICK_COL_W), minW)
    local height = zo_max(S.sv.pickH or minH, minH)
    win:SetDimensionConstraints(minW, minH, 1400, 1000)
    win:SetDimensions(width, height)
    win:ClearAnchors()
    if S.sv.pickX and S.sv.pickY then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, S.sv.pickX, S.sv.pickY)
    else
        win:SetAnchor(CENTER, ui.win, CENTER, 0, 0)
    end
    picker.title:SetText(zo_strupper(title))
    picker.clear:SetText(clearText)

    for _, head in ipairs(picker.heads) do head:SetHidden(true) end
    for _, label in ipairs(picker.labels) do label:SetHidden(true) end
    local n = 0
    for c, group in ipairs(groups) do
        local head = picker.heads[c]
        if not head then
            head = MakeLabel("SetHunter_PickerHead" .. c, win, "ZoFontGameSmall", PICK_COL_W - 10, 20, COLOR.dim)
            picker.heads[c] = head
        end
        head:SetText(zo_strupper(group.title))
        head:SetHidden(false)
        for r, item in ipairs(group.list) do
            n = n + 1
            local label = picker.labels[n]
            if not label then
                label = MakeLabel("SetHunter_PickerItem" .. n, win, "ZoFontGame", PICK_COL_W - 10, PICK_ROW_H, COLOR.normal)
                label:SetMaxLineCount(1)
                label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                label:SetMouseEnabled(true)
                label:SetHandler("OnMouseEnter", function(self) self.hovered = true; PaintPick(self) end)
                label:SetHandler("OnMouseExit", function(self) self.hovered = false; PaintPick(self) end)
                label:SetHandler("OnMouseUp", function(self, button, upInside)
                    if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                    picker.onToggle(self.item)
                    PaintPicker()
                end)
                picker.labels[n] = label
            end
            label.item, label.hovered = item, false
            label.col, label.row = c, r
            label:SetHidden(false)
        end
    end
    picker.used = n
    LayoutPicker()
    win:SetHidden(false)
    PaintPicker()
    -- and once more a frame later: text set on a just-shown popup can come out blank
    zo_callLater(PaintPicker, 1)
end

-- right-click a wishlist set > Wanted traits...
local function ShowTraitMenu(_, data)
    local setId = data.setId
    local groups = {}
    for _, group in ipairs(TraitGroupsFor(setId)) do
        groups[#groups + 1] = { title = L(group.key), list = group.list }
    end
    OpenPicker(L("PICK_TRAITS", (S.GetSetData(setId) or data).name or ""), L("TRAIT_ANY"), groups,
        function(item) return S.IsWantedTrait(setId, item.trait) end,
        function(item) S.ToggleWishTrait(setId, item.trait); S.RefreshAll() end,
        function() S.ClearWishTraits(setId); S.WishSet(setId); S.RefreshAll() end,
        function() return S.HasWishTraits(setId) end,
        L("PICK_TRAITS_NOTE", zo_iconFormat(TEX_STAR, 14, 14)))
end

-- right-click a wishlist set > Wanted pieces...
local function ShowPieceMenu(_, data)
    local setId = data.setId
    local byGroup = { armor = {}, weapon = {}, jewelry = {} }
    for _, piece in ipairs(S.SetPieces(setId)) do
        piece.note = piece.unlocked and L("PIECE_HAVE") or nil
        table.insert(byGroup[piece.group], piece)
    end
    local groups = {}
    for _, g in ipairs({ { "armor", "TRAITS_ARMOR" }, { "jewelry", "TRAITS_JEWELRY" }, { "weapon", "TRAITS_WEAPON" } }) do
        if #byGroup[g[1]] > 0 then groups[#groups + 1] = { title = L(g[2]), list = byGroup[g[1]] } end
    end
    OpenPicker(L("PICK_PIECES", (S.GetSetData(setId) or data).name or ""), L("PIECE_ANY"), groups,
        function(item) return S.IsWantedPiece(setId, item.key) end,
        function(item) S.ToggleWishPiece(setId, item.key); S.RefreshAll() end,
        function() S.ClearWishPieces(setId); S.WishSet(setId); S.RefreshAll() end,
        function() return S.HasWishPieces(setId) end,
        L("PICK_PIECES_NOTE", zo_iconFormat(TEX_STAR, 14, 14)))
end

local ShowRowTooltip   -- defined below

function S.Row_OnMouseEnter(row)
    ZO_ScrollList_MouseEnter(ui.list, row)
    SetHexColor(row:GetNamedChild("Name"), COLOR.selected)
    local data = ZO_ScrollList_GetData(row)
    if not data then return end

    -- The shortcuts (end icon, owned count) only light up while the mouse is on them.
    local action = row:GetNamedChild("Action")
    local hasAction = action ~= nil and not action:IsHidden()
    local hasOwned = HasOwnedShortcut(data)
    local summary = data.kind == "summary"
    if hasAction or hasOwned or summary then
        row:SetHandler("OnUpdate", function(self)
            if hasAction then action:SetAlpha(IsOverAction(self) and ACTION_ALPHA_HOVER or ACTION_ALPHA) end
            if hasOwned then PaintOwned(self, IsOverOwned(self, data)) end
            -- overview row: the category icon (and its text) light up when it can be clicked
            if summary then
                SetHexColor(self:GetNamedChild("Type"), IsOverSummaryIcon(self, data) and COLOR.selected or COLOR.dim)
            end
        end)
    end
    -- pieces you can go and look at (your bag, your bank): name gets a glowing outline
    if CanLocate(data) then
        local name = row:GetNamedChild("Name")
        name:SetFont(FONT_GLOW)
        name:SetStyleColor(HexToRGB(COLOR.theme))
    end
    ShowRowTooltip(row, data)
end
ShowRowTooltip = function(row, data)
    local hint = ActionHint(data)

    if data.kind == "set" and data.link then
        InitializeTooltip(ItemTooltip, row, RIGHT, -12, 0, LEFT)
        ItemTooltip:SetLink(data.link)
        ZO_Tooltip_AddDivider(ItemTooltip)
        if data.sources ~= "" then
            ItemTooltip:AddLine(L("TT_DROPS", data.sources), "ZoFontGame", HexToRGB(COLOR.normal))
        end
        if data.monster then
            ItemTooltip:AddLine(L("TT_HEAD", data.monster.boss), "ZoFontGame", HexToRGB(COLOR.header))
            ItemTooltip:AddLine(L("TT_SHOULDERS"), "ZoFontGame", HexToRGB(COLOR.header))
        end
        AddMythicLines(ItemTooltip, data.setId)
        AddCraftLines(ItemTooltip, data.setId)
        if S.HasWishPieces(data.setId) then
            ItemTooltip:AddLine(L("TT_WANTED_PIECES", S.WishPieceNames(data.setId)), "ZoFontGame", HexToRGB(COLOR.good))
        end
        if S.HasWishTraits(data.setId) then
            ItemTooltip:AddLine(L("TT_WANTED_TRAITS", S.WishTraitNames(data.setId)), "ZoFontGame", HexToRGB(COLOR.good))
        end
        if data.total > 0 and not data.complete then
            local left = data.have == 0 and L("TT_MISSING_ALL", data.total)
                or L("TT_MISSING", data.total - data.have, table.concat(S.MissingPieces(data.setId), ", "))
            ItemTooltip:AddLine(left, "ZoFontGame", HexToRGB(COLOR.normal))
        end
        AddOwnedLines(ItemTooltip, data.setId)
        if (data.owned or 0) > 0 then
            ItemTooltip:AddLine(L("TT_OWNED_CLICK", zo_iconFormat(TEX_BAG, 18, 18)), "ZoFontGameSmall", HexToRGB(COLOR.accent))
        end
        if hint then ItemTooltip:AddLine(hint, "ZoFontGameSmall", HexToRGB(COLOR.accent)) end
        -- only mention what a double-click really does on this row
        local hints = { L("HINT_STAR") }
        local double = DoubleClickAction(data)
        if double == "goto" then hints[#hints + 1] = L("HINT_DOUBLE_GOTO") end
        if double and double ~= "goto" then
            hints[#hints + 1] = L("HINT_DOUBLE_ACTION", L(SOURCE_ACTIONS[double].text))
        end
        hints[#hints + 1] = L("HINT_RIGHT")
        ItemTooltip:AddLine(table.concat(hints, "  ·  "), "ZoFontGameSmall", HexToRGB(COLOR.dim))
    elseif data.kind == "item" then
        InitializeTooltip(ItemTooltip, row, RIGHT, -12, 0, LEFT)
        ItemTooltip:SetLink(data.link)
        ZO_Tooltip_AddDivider(ItemTooltip)
        ItemTooltipLines(data)
        if CanLocate(data) then
            ItemTooltip:AddLine(L(ui.atBank and "TT_SHOW_IN_BANK" or "TT_SHOW_IN_BAG"), "ZoFontGameSmall", HexToRGB(COLOR.accent))
        end
        if hint then ItemTooltip:AddLine(hint, "ZoFontGameSmall", HexToRGB(COLOR.accent)) end
    elseif data.pieceLink then
        -- wanted piece under a set in the Wishlist: the real item
        InitializeTooltip(ItemTooltip, row, RIGHT, -12, 0, LEFT)
        ItemTooltip:SetLink(data.pieceLink)
        ZO_Tooltip_AddDivider(ItemTooltip)
        for _, line in ipairs(data.tooltip or {}) do
            ItemTooltip:AddLine(line, "ZoFontGameSmall", HexToRGB(COLOR.dim))
        end
    elseif data.tooltip then
        InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
        SetTooltipText(InformationTooltip, data.name)
        for i, line in ipairs(data.tooltip) do
            InformationTooltip:AddLine(line, i == 1 and "ZoFontGame" or "ZoFontGameSmall",
                HexToRGB(i == 1 and COLOR.normal or COLOR.dim))
        end
        if data.boostKey then AddBoostLines(InformationTooltip, data) end
        if hint then InformationTooltip:AddLine(hint, "ZoFontGameSmall", HexToRGB(COLOR.accent)) end
    end
end

function S.Row_OnMouseExit(row)
    ZO_ScrollList_MouseExit(ui.list, row)
    row:SetHandler("OnUpdate", nil)
    local typeLabel = row:GetNamedChild("Type")
    if typeLabel then SetHexColor(typeLabel, COLOR.dim) end
    local action = row:GetNamedChild("Action")
    if action then action:SetAlpha(ACTION_ALPHA) end
    if row:GetNamedChild("OwnedIcon") then PaintOwned(row, false) end
    if row:GetNamedChild("Where") then
        local name = row:GetNamedChild("Name")
        name:SetFont("ZoFontGame")
        name:SetStyleColor(0, 0, 0, 1)
    end
    local data = ZO_ScrollList_GetData(row)
    if data then SetHexColor(row:GetNamedChild("Name"), NameColor(data)) end
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)
end

function S.Row_OnMouseUp(row, button, upInside)
    if not upInside then return end
    local data = ZO_ScrollList_GetData(row)
    if not data then return end

    if button == MOUSE_BUTTON_INDEX_LEFT then
        local star = row:GetNamedChild("Star")
        if data.kind == "set" and star and IsMouseOver(star, 5) then
            ToggleWish(data)
        elseif IsOverSummaryIcon(row, data) then
            OpenSummary(data)
        elseif IsOverAction(row) then
            DoRowAction(data)
        elseif IsOverOwned(row, data) then
            ClearTooltip(ItemTooltip)
            ClearTooltip(InformationTooltip)
            PlaySound(SOUNDS.DEFAULT_CLICK)
            OpenOwned(data)
        elseif CanLocate(data) then
            S.LocateItem(data)
        else
            ZO_ScrollList_MouseClick(ui.list, row)
        end
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        ZO_ScrollList_MouseClick(ui.list, row)
        ClearMenu()
        if IsSetLike(data) then
            local wished = S.sv.wishlist[data.setId]
            if data.kind ~= "item" then
                AddMenuItem(wished and L("BTN_UNWISH") or L("BTN_WISH"), function() ToggleWish(data) end)
            elseif wished then
                -- a piece has its own "add this piece" below; only offer removing the whole set
                AddMenuItem(L("MENU_UNWISH_SET"), function() ToggleWish(data) end)
            end
            -- for any set: picking a trait or piece puts the set on the wishlist
            -- (the game clears the menu right after a click, so open ours a frame later)
            AddMenuItem(L("MENU_TRAITS"), function()
                zo_callLater(function() ShowTraitMenu(row, data) end, 1)
            end)
            AddMenuItem(L("MENU_PIECES"), function()
                zo_callLater(function() ShowPieceMenu(row, data) end, 1)
            end)
            -- an owned piece: wishlist just that piece
            local key = data.kind == "item" and S.PieceInfo(data).slotKey
            if key then
                local on = S.IsWantedPiece(data.setId, key)
                AddMenuItem(L(on and "MENU_UNWISH_PIECE" or "MENU_WISH_PIECE"), function()
                    S.ToggleWishPiece(data.setId, key)
                    S.RefreshAll()
                end)
            end
            AddMenuItem(L("BTN_LINK"), function() LinkInChat(data) end)
            -- drops in several places: one entry per place (not the one on screen)
            local locIds = SetLocationIds(data)
            if #locIds > 1 then
                for _, id in ipairs(locIds) do
                    if id ~= ui.viewLocId then
                        AddMenuItem(L("MENU_GOTO_AT", S.GetLocation(id).name), function() GoToSet(data, id) end)
                    end
                end
            elseif NextLocationFor(data) then
                AddMenuItem(L("MENU_GOTO"), function() GoToSet(data) end)
            end
            -- reward systems it comes from: Open Antiquities / Queue random dungeon / Open Battlegrounds
            for _, key in ipairs(SourceActionsFor(data)) do
                local action = SOURCE_ACTIONS[key]
                AddMenuItem(zo_iconFormat(action.icon(), 20, 20) .. " " .. L(action.text), action.run)
            end
            local owned = S.OwnedCount(data.setId)
            if data.kind == "set" and owned > 0 then
                AddMenuItem(L("MENU_MY_PIECES", owned), function() ShowMyPieces(data.setId) end)
            end
        elseif data.link then
            AddMenuItem(L("BTN_LINK"), function() LinkInChat(data) end)
        end
        -- wanted-piece line under a set in the Wishlist
        if data.pieceKey then
            AddMenuItem(L("MENU_UNWISH_PIECE"), function()
                S.ToggleWishPiece(data.pieceOf, data.pieceKey)
                S.RefreshAll()
            end)
        end
        -- hunted-trait line under a set in Trait hunt
        if data.huntSet then
            AddMenuItem(L("MENU_TRAITS"), function()
                zo_callLater(function() ShowTraitMenu(row, { setId = data.huntSet }) end, 1)
            end)
        end
        if CanLocate(data) then
            AddMenuItem(L(ui.atBank and "MENU_SHOW_IN_BANK" or "MENU_SHOW_IN_BAG"), function() S.LocateItem(data) end)
        end
        if data.boostKey and (data.owned or 0) > 0 then
            AddMenuItem(L("MENU_MY_BOOSTS", data.owned), function() OpenOwned(data) end)
        end
        local here = ui.viewZoneId and Reachable(ui.viewZoneId) and ui.viewZoneId or nil
        AddTravelOrQueue(TargetFor(data) or here, data)
        ShowMenu(row)
    end
end

function S.Row_OnMouseDoubleClick(row, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local data = ZO_ScrollList_GetData(row)
    if not data then return end
    local star = row:GetNamedChild("Star")
    if star and IsMouseOver(star, 5) then return end
    -- a click on a bag / bank piece already opened it
    if IsOverAction(row) or IsOverOwned(row, data) or CanLocate(data) then return end
    local action = DoubleClickAction(data)
    if action == "open" then
        OpenSummary(data)
    elseif action == "goto" then
        GoToSet(data)
    elseif action then
        SOURCE_ACTIONS[action].run()
    elseif not IsSetLike(data) and data.zoneId then
        S.TravelTo(data.zoneId)
    end
end

local function OnSelectionChanged(_, selectedData)
    ui.selected = selectedData
    UpdateActionButtons()
end

-- Column titles above the list, lined up with the row templates.
local COLUMNS = {
    sets  = { "COL_SET", "COL_TYPE", "COL_OWNED", "COL_COLLECTED" },
    where = { "COL_SET", "COL_DROPS", "COL_OWNED", "COL_COLLECTED" },
    crafted = { "COL_SET", "COL_STATION", "COL_OWNED", nil },   -- not in the Set Collection
    overview = { "COL_CATEGORY", "COL_PIECES", nil, "COL_SETS_DONE" },
    items = { "COL_ITEM", "COL_TRAIT", nil, "COL_WHERE" },
    boosts = { "COL_ITEM", "COL_AMOUNT", nil, "COL_WHERE" },
}

-- The game's dungeon art sits in the top-left part of its texture file (the rest is
-- empty), so only that part is shown, at its own shape (1.6 : 1).
local ART_W, ART_H = 128, 80
local ART_COORDS = { 0, 0.625, 0, 0.78125 }

-- Right side, top to bottom: breadcrumb, header (title, badges, info lines, art),
-- collection bar, column titles, list. Everything below moves up when a part is empty.
local function GoCrumb(part)
    RememberPage()
    S.sv.view, S.sv.loc = part.view or TAB_START[part.tab], nil
    ui.itemsSetId, ui.boostKey, ui.selected = nil, nil, nil
    ui.restoring = true
    ui.search:SetText("")
    ui.restoring = false
    ui.search:LoseFocus()
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

-- a part only links somewhere if it isn't the last one and doesn't lead to the page
-- you're already on (SETS on Current location would just reload it)
local function CrumbLinks(part, isLast)
    if isLast then return false end
    local view = part.view or TAB_START[part.tab]
    if not view then return false end
    local onIt = view == S.sv.view and S.sv.loc == nil and not ui.itemsSetId and not ui.boostKey
        and (ui.search:GetText() or "") == ""
    return not onIt
end

local function SetCrumb(parts)
    parts = parts or {}
    for i, label in ipairs(ui.crumbLabels) do
        local part = parts[i]
        label:SetHidden(part == nil)
        if part then
            local text = zo_strupper(part.text)
            if i > 1 then text = "›  " .. text end
            label:SetText(text)
            label:SetWidth(#text * 8 + 4)   -- rough; fitted next frame
            local links = CrumbLinks(part, i == #parts)
            label.part = links and part or nil
            label:SetMouseEnabled(links)
            SetHexColor(label, links and COLOR.normal or COLOR.dim)
        end
    end
    zo_callLater(function()
        for _, label in ipairs(ui.crumbLabels) do
            if not label:IsHidden() then label:SetWidth(label:GetTextWidth() + 2) end
        end
    end, 1)
end

-- Dungeon art the game points to isn't always in the game files (new dungeons): then
-- it would show ESO's red "?" placeholder. Textures load in the background, so the art
-- stays invisible until it has loaded as a real banner; if it never does, it's dropped.
local artChecked = {}   -- [path] = true (fine) / false (missing)
local function CheckArt(control, path, onDone)
    local started = GetFrameTimeMilliseconds()
    control:SetAlpha(0)   -- not hidden: hidden controls get no OnUpdate
    control:SetHandler("OnUpdate", function(self)
        local loaded = self:IsTextureLoaded()
        if loaded or GetFrameTimeMilliseconds() - started > 2000 then
            self:SetHandler("OnUpdate", nil)
            local width = loaded and self:GetTextureFileDimensions() or 0
            artChecked[path] = loaded and width >= 128
            onDone(artChecked[path])
        end
    end)
end

-- the art to show: nil when it's known to be missing
local function UsableArt(path)
    if path and artChecked[path] == false then return nil end
    return path
end

local function LayoutRight(result)
    SetCrumb(result.crumb)

    local art = UsableArt(result.art)
    ui.art:SetHidden(art == nil)
    ui.art:SetHandler("OnUpdate", nil)
    if art then
        ui.art:SetTexture(art)
        if artChecked[art] == nil then
            CheckArt(ui.art, art, function(ok)
                if ok then
                    ui.art:SetAlpha(1)
                elseif ui.lastResult then
                    LayoutRight(ui.lastResult)   -- again, without the art
                end
            end)
        else
            ui.art:SetAlpha(1)
        end
    end
    ui.rules = result.rules
    ui.how:SetHidden(result.rules == nil)
    ui.how:ClearAnchors()
    if art then
        ui.how:SetAnchor(TOPRIGHT, ui.art, BOTTOMRIGHT, 0, 2)
    else
        ui.how:SetAnchor(TOPRIGHT, ui.header, TOPRIGHT, 0, 10)
    end
    -- Bank link under "How drops work" (or at the top when there's no such link),
    -- on the pages that list where your items are.
    local showBank = result.columns == "items" or result.columns == "boosts"
    if ui.bankLink then
        ui.bankLink:SetHidden(not showBank)
        ui.bankLink:ClearAnchors()
        if result.rules then
            ui.bankLink:SetAnchor(TOPRIGHT, ui.how, BOTTOMRIGHT, 0, 4)
        else
            ui.bankLink:SetAnchor(TOPRIGHT, ui.header, TOPRIGHT, 0, 10)
        end
    end
    ui.sourceKey = result.sourceKey
    if ui.sourceLink then
        local action = SOURCE_ACTIONS[result.sourceKey or ""]
        ui.sourceLink:SetHidden(action == nil)
        if action then ui.sourceLink:SetText(zo_iconFormat(action.icon(), 20, 20) .. " " .. L(action.text)) end
    end
    local reserve = art and (ART_W + 14) or ((result.rules or showBank) and 170) or 0
    local textW = ui.listW - reserve

    ui.viewTitle:SetWidth(textW)
    ui.viewTitle:SetText(zo_strupper(result.title or ""))

    local previous
    local badges = result.badges or {}
    for i, badge in ipairs(ui.badges) do
        -- A badge is its text, or { text = ..., tooltip = function(tooltip) ... end }.
        local entry = badges[i]
        local text = type(entry) == "table" and entry.text or entry
        badge:SetHidden(text == nil)
        badge:SetBadgeTooltip(type(entry) == "table" and entry.tooltip or nil)
        if text then
            badge:SetBadgeText(text)
            badge:ClearAnchors()
            if previous then
                badge:SetAnchor(LEFT, previous, RIGHT, 6, 0)
            else
                badge:SetAnchor(TOPLEFT, ui.viewTitle, BOTTOMLEFT, 0, 2)
            end
            previous = badge
        end
    end
    -- My items: the character dropdown right after the badges
    if ui.scopeBox then
        ui.scopeBox:SetHidden(not result.scope)
        if result.scope then
            ui.scopeBox:ClearAnchors()
            if previous then
                ui.scopeBox:SetAnchor(LEFT, previous, RIGHT, 12, 0)
            else
                ui.scopeBox:SetAnchor(TOPLEFT, ui.viewTitle, BOTTOMLEFT, 0, 2)
            end
        end
    end

    local height = 36 + (previous and 26 or 0)
    local info = result.info or ""
    ui.info:SetWidth(textW)
    ui.info:ClearAnchors()
    ui.info:SetAnchor(TOPLEFT, ui.header, TOPLEFT, 0, height + 6)
    ui.info:SetText(info)
    ui.info:SetHidden(info == "")
    if info ~= "" then height = height + 6 + ui.info:GetTextHeight() end
    ui.header:SetHeight(zo_max(height, art and (ART_H + 24) or 0))

    local above = ui.header
    local progress = result.progress
    ui.progressRow:SetHidden(progress == nil)
    if progress then
        ui.progressLabel:SetText(progress.label or L("COLLECTION_HERE"))
        ui.progressValue:SetText(progress.valueText or L(progress.valueKey or "PROGRESS_VALUE", progress.done, progress.total))
        SetHexColor(ui.progressValue, progress.done == progress.total and COLOR.good or COLOR.selected)
        ui.progressBar:SetProgress(progress.done / progress.total, progress.done == progress.total)
        ui.progressRow:ClearAnchors()
        ui.progressRow:SetAnchor(TOPLEFT, above, BOTTOMLEFT, 0, 8)
        above = ui.progressRow
    end

    local columns = result.columns and COLUMNS[result.columns]
    ui.columns:SetHidden(columns == nil)
    if columns then
        for i = 1, 4 do
            ui.columnLabels[i]:SetText(columns[i] and L(columns[i]) or "")
        end
        ui.columns:ClearAnchors()
        ui.columns:SetAnchor(TOPLEFT, above, BOTTOMLEFT, 0, 8)
        above = ui.columns
    end

    ui.list:ClearAnchors()
    ui.list:SetAnchor(TOPLEFT, above, BOTTOMLEFT, 0, columns and 2 or 10)
    ui.list:SetAnchor(BOTTOMRIGHT, ui.divider2, TOPRIGHT, 0, -8)
end

local function RefreshList()
    ZO_ScrollList_Clear(ui.list)
    local scrollData = ZO_ScrollList_GetDataList(ui.list)
    local result = BuildView(scrollData)
    ZO_ScrollList_Commit(ui.list)

    -- Keep the same row selected after a refresh.
    local selected = ui.selected
    ui.selected = nil
    if selected then
        for _, entry in ipairs(scrollData) do
            local data = entry.data
            local same = false
            if data and data.kind == selected.kind then
                if data.kind == "item" then
                    same = data.link == selected.link and data.where == selected.where
                else
                    same = data.name == selected.name
                end
            end
            if same then
                ZO_ScrollList_SelectData(ui.list, data)
                ui.selected = data
                break
            end
        end
    end

    ui.viewZoneId = result.zoneId
    ui.viewLocId = result.locId
    ui.lastResult = result
    LayoutRight(result)
    local isEmpty = #scrollData == 0
    ui.empty:SetHidden(not isEmpty)
    ui.empty:SetText(result.empty or L("EMPTY"))
    UpdateActionButtons()
end

function S.RefreshAll()
    if not ui.win or ui.win:IsHidden() then return end
    RefreshTree()
    RefreshList()
end

-- XP changed: redraw the XP farming page on screen (progress bar, session numbers)
function S.RefreshXPPages()
    if not ui.win or ui.win:IsHidden() then return end
    if SECTION_OF[S.sv.view] == "TREE_XP" then RefreshList() end
end

-- ---------------------------------------------------------------------------
-- Launcher button + open/close animation (same behavior as Command Codex)
-- ---------------------------------------------------------------------------
local LAUNCHER_H = 32
local LAUNCHER_EMBLEM_W, LAUNCHER_EMBLEM_H = 26, 28   -- the title's 44 x 48 shield, in small
local LAUNCHER_BG_ALPHA, LAUNCHER_BG_ALPHA_HOVER = 0.65, 0.85

local function SetLauncherTextColor(hovered)
    if not ui.launcherText then return end
    local bright = hovered or ui.isOpen
    SetHexColor(ui.launcherText, bright and COLOR.selected or COLOR.normal)
    ui.launcherIcon:SetAlpha(bright and 1 or 0.7)
end

-- Window sits right under the launcher unless the player dragged it somewhere else.
-- Always a plain screen position (top left corner): anchored to the launcher or the
-- screen centre, a drag made the game jump the window into a screen corner.
local function PlaceWindow()
    local win, sv = ui.win, S.sv
    if not win then return end
    local x, y
    if ui.atBank or ui.besideBag then
        -- left of the screen by default, clear of the bank / bag list on the right
        x, y = sv.bankX or 40, sv.bankY or 110
    elseif sv.docked ~= false and ui.launcher and not sv.launcherHidden then   -- (also while it's hidden in combat)
        x, y = ui.launcher:GetLeft(), ui.launcher:GetBottom() + 6
    elseif sv.x and sv.y then
        x, y = sv.x, sv.y
    else
        x = (GuiRoot:GetWidth() - win:GetWidth()) / 2
        y = (GuiRoot:GetHeight() - win:GetHeight()) / 2 - 40
    end
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

local function ShowLauncherMenu(launcher)
    ClearTooltip(InformationTooltip)
    ClearMenu()
    AddMenuItem(S.sv.announce and L("MENU_ANNOUNCE_ON") or L("MENU_ANNOUNCE_OFF"), function()
        S.SetAnnounce(not S.sv.announce)
    end)
    AddMenuItem(S.sv.runSummary and L("MENU_SUMMARY_ON") or L("MENU_SUMMARY_OFF"), function()
        S.sv.runSummary = not S.sv.runSummary
    end)
    AddMenuItem(L("MENU_RESET_SIZE"), S.ResetSize)
    AddMenuItem(S.sv.launcherCompact and L("MENU_COMPACT_ON") or L("MENU_COMPACT_OFF"), function()
        S.SetLauncherCompact(not S.sv.launcherCompact, true)
    end)
    AddMenuItem(L("MENU_HIDE_BUTTON"), function()
        S.SetLauncherShown(false)
        S.Print(L("LAUNCHER_HIDDEN"))
    end)
    AddMenuItem(L("MENU_SETTINGS"), S.OpenSettings)
    ShowMenu(launcher)
end

function S.ResetSize()
    S.sv.w, S.sv.h = nil, nil
    ui.win:SetDimensions(WIN_W, WIN_H)
    S.Relayout(false)
end

function S.ResetPosition()
    local sv = S.sv
    sv.launcherX, sv.launcherY = 16, 88
    sv.x, sv.y, sv.docked = nil, nil, true
    ui.launcher:ClearAnchors()
    ui.launcher:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.launcherX, sv.launcherY)
    PlaceWindow()
end

local function AttachToHud(control, fragment, attached, show)
    if fragment and attached ~= show then
        if show then
            HUD_SCENE:AddFragment(fragment)
            HUD_UI_SCENE:AddFragment(fragment)
        else
            HUD_SCENE:RemoveFragment(fragment)
            HUD_UI_SCENE:RemoveFragment(fragment)
        end
    end
    control:SetHidden(not show or (fragment ~= nil and not (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing())))
    return show
end

-- shown unless you hid it, or (with "hide in combat" on) while you're fighting
local function UpdateLauncher()
    if not ui.launcher then return end
    local show = not S.sv.launcherHidden and not (S.sv.launcherCombatHide and ui.inCombat)
    ui.launcherAttached = AttachToHud(ui.launcher, ui.launcherFragment, ui.launcherAttached, show)
end

function S.SetLauncherShown(show)
    S.sv.launcherHidden = not show
    UpdateLauncher()
end

function S.SetLauncherCombatHide(on)
    S.sv.launcherCombatHide = on
    UpdateLauncher()
end

-- Compact: only the shield and the arrow to open it up again (no name, no "x");
-- the small arrow on the button switches between the two
local LAUNCHER_ARROW = 16   -- « collapse / » expand

local function PaintLauncherArrow(hovered)
    ui.launcherArrow:SetText(S.sv.launcherCompact and "»" or "«")
    SetHexColor(ui.launcherArrow, hovered and COLOR.selected or COLOR.dim)
end

local LAUNCHER_ARROW_RIGHT = 10   -- the arrow sits this far from the right edge (clear of the "x")
local LAUNCHER_ANIM = 0.2         -- seconds to hide / show the name

-- width with / without the name (the arrow is pinned to the right edge)
local function LauncherWidth(compact)
    local base = 3 + LAUNCHER_EMBLEM_W + LAUNCHER_ARROW + LAUNCHER_ARROW_RIGHT
    if compact then return base + 4 end
    return base + 7 + zo_max(ui.launcherText:GetTextWidth(), 90) + 4
end

-- animate: slide the width and fade the name (and "x") instead of snapping
function S.SetLauncherCompact(on, animate)
    S.sv.launcherCompact = on
    local launcher = ui.launcher
    if not launcher then return end
    PaintLauncherArrow(false)
    local text, close = ui.launcherText, ui.launcherClose
    local from, to = launcher:GetWidth(), LauncherWidth(on)
    if not animate then
        launcher:SetHandler("OnUpdate", nil)
        text:SetHidden(on); text:SetAlpha(1)
        close:SetHidden(on); close:SetAlpha(1)
        launcher:SetWidth(to)
        return
    end
    text:SetHidden(false)
    close:SetHidden(false)
    local start = GetFrameTimeSeconds()
    launcher:SetHandler("OnUpdate", function(self)
        local t = zo_min(1, (GetFrameTimeSeconds() - start) / LAUNCHER_ANIM)
        local eased = 1 - (1 - t) ^ 3   -- ease out: quick start, gentle stop
        self:SetWidth(from + (to - from) * eased)
        -- hiding: the name fades a bit faster than the button shrinks, so it never sticks out
        local alpha = on and zo_max(0, 1 - eased * 1.6) or eased
        text:SetAlpha(alpha)
        close:SetAlpha(alpha)
        if t >= 1 then
            self:SetHandler("OnUpdate", nil)
            text:SetHidden(on)
            close:SetHidden(on)
        end
    end)
end

local function CreateLauncher()
    local sv = S.sv
    local launcher = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_Launcher")
    launcher:SetHeight(LAUNCHER_H)
    launcher:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.launcherX, sv.launcherY)
    launcher:SetClampedToScreen(true)
    launcher:SetMouseEnabled(true)
    launcher:SetMovable(true)

    local bg = MakeRoundedBackground("SetHunter_LauncherBG", launcher, LAUNCHER_H)
    bg:SetAlpha(LAUNCHER_BG_ALPHA)

    ui.launcherBG = bg

    -- the same shield emblem and Trajan lettering as the window title, in small
    local icon = MakeEmblem("SetHunter_LauncherCrest", launcher, LAUNCHER_EMBLEM_W, LAUNCHER_EMBLEM_H, 20)
    icon:SetAnchor(LEFT, launcher, LEFT, 3, 0)
    ui.launcherIcon = icon

    local text = WINDOW_MANAGER:CreateControl("SetHunter_LauncherText", launcher, CT_LABEL)
    text:SetFont("$(STONE_TABLET_FONT)|16|soft-shadow-thick")
    text:SetText(zo_strupper(L("LAUNCHER")))
    text:SetAnchor(LEFT, icon, RIGHT, 7, 1)
    text:SetDrawLevel(5)
    text:SetMouseEnabled(false)
    ui.launcherText = text
    -- small « / » arrow: collapse to just the shield / show the name again
    local arrow = MakeLabel("SetHunter_LauncherArrow", launcher, "$(BOLD_FONT)|20|soft-shadow-thin",
        LAUNCHER_ARROW, LAUNCHER_H, COLOR.dim)
    arrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    arrow:SetMouseEnabled(true)
    arrow:SetDrawLevel(9)
    arrow:SetAnchor(RIGHT, launcher, RIGHT, -LAUNCHER_ARROW_RIGHT, -1)   -- moves with the edge
    arrow:SetHandler("OnMouseEnter", function(self)
        PaintLauncherArrow(true)
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 4, BOTTOMLEFT)
        SetTooltipText(InformationTooltip, L(S.sv.launcherCompact and "LAUNCHER_EXPAND" or "LAUNCHER_COLLAPSE"))
    end)
    arrow:SetHandler("OnMouseExit", function()
        PaintLauncherArrow(false)
        ClearTooltip(InformationTooltip)
    end)
    arrow:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            S.SetLauncherCompact(not S.sv.launcherCompact, true)
        end
    end)
    ui.launcherArrow = arrow

    ui.fitLauncher = function()
        launcher:SetWidth(LauncherWidth(S.sv.launcherCompact))
    end
    ui.fitLauncher()
    zo_callLater(ui.fitLauncher, 1)   -- the new font's width is only known a frame later

    launcher:SetHandler("OnMouseEnter", function(self)
        bg:SetAlpha(LAUNCHER_BG_ALPHA_HOVER)
        SetLauncherTextColor(true)
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 4, BOTTOMLEFT)
        SetTooltipText(InformationTooltip, L("LAUNCHER_TT"))
    end)
    launcher:SetHandler("OnMouseExit", function()
        bg:SetAlpha(LAUNCHER_BG_ALPHA)
        SetLauncherTextColor(false)
        ClearTooltip(InformationTooltip)
    end)
    -- Drag to move; a short click (no movement) opens / minimizes.
    launcher:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then ui.pressX, ui.pressY = self:GetLeft(), self:GetTop() end
    end)
    launcher:SetHandler("OnMoveStart", function() ClearTooltip(InformationTooltip) end)
    launcher:SetHandler("OnMoveStop", function(self)
        sv.launcherX, sv.launcherY = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.launcherX, sv.launcherY)
        sv.docked = true
        PlaceWindow()
    end)
    launcher:SetHandler("OnMouseUp", function(self, button, upInside)
        if button == MOUSE_BUTTON_INDEX_RIGHT and upInside then
            ShowLauncherMenu(self)
            return
        end
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local moved = ui.pressX and (math.abs(self:GetLeft() - ui.pressX) > 3 or math.abs(self:GetTop() - ui.pressY) > 3)
        ui.pressX, ui.pressY = nil, nil
        if not upInside or moved then return end
        -- a click on the « / » arrow collapses / expands the button instead of opening
        if ui.launcherArrow and IsMouseOver(ui.launcherArrow, 3) then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            S.SetLauncherCompact(not S.sv.launcherCompact, true)
            return
        end
        S.Toggle()
    end)

    -- Small round "x" on the top-right corner: hides the button.
    local closeBg = WINDOW_MANAGER:CreateControl("SetHunter_LauncherCloseBG", launcher, CT_TEXTURE)
    closeBg:SetTexture(TEX_CIRCLE)
    closeBg:SetColor(0, 0, 0, 0.85)
    closeBg:SetDimensions(16, 16)
    closeBg:SetAnchor(CENTER, launcher, TOPRIGHT, -2, 2)
    closeBg:SetDrawLevel(7)
    local closeRing = WINDOW_MANAGER:CreateControl("SetHunter_LauncherCloseRing", closeBg, CT_TEXTURE)
    closeRing:SetTexture(TEX_RING)
    SetHexColor(closeRing, "4A4A44")
    closeRing:SetAnchorFill(closeBg)
    closeRing:SetDrawLevel(8)
    local close = MakeTextButton("SetHunter_LauncherClose", closeBg, "x", "$(BOLD_FONT)|12|soft-shadow-thin", 16,
        L("LAUNCHER_HIDE_TT"),
        function()
            S.SetLauncherShown(false)
            S.Print(L("LAUNCHER_HIDDEN"))
        end)
    close:SetAnchor(CENTER, closeBg, CENTER, 0, -1)
    close:SetDrawLevel(9)
    ui.launcherClose = closeBg

    -- Like ESO's own HUD: visible on the HUD (with or without cursor), hidden in menus.
    if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        ui.launcherFragment = ZO_HUDFadeSceneFragment:New(launcher)
        ui.launcherAttached = false
    end
    ui.launcher = launcher
    SetLauncherTextColor(false)
    S.SetLauncherCompact(sv.launcherCompact == true)
    -- out of the way while you fight (setting "Hide the button in combat")
    ui.inCombat = IsUnitInCombat("player")
    EVENT_MANAGER:RegisterForEvent("SetHunter_LauncherCombat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        ui.inCombat = inCombat
        UpdateLauncher()
    end)
    UpdateLauncher()
end

-- ---------------------------------------------------------------------------
-- Inventory / bank button: the shield on the left of the filter-tab row; opens Set
-- Hunter on My items, next to the bag (click a piece there to find it in the bag)
-- ---------------------------------------------------------------------------
local BAG_WINDOWS = { "ZO_PlayerInventory", "ZO_PlayerBank", "ZO_HouseBank" }
local bagButtons = {}

local function OpenFromBag()
    ClearTooltip(InformationTooltip)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    -- already on screen: the button closes it again (a toggle, like the launcher)
    if ui.isOpen and not ui.hiddenByMenu and not ui.win:IsHidden() then
        ui.besideBag, ui.openedForBag = false, nil
        S.Toggle(false)
        return
    end
    local inventory = SCENE_MANAGER:GetScene("inventory")
    if inventory and inventory:IsShowing() and not ui.atBank then
        ui.besideBag = true
        ui.openedForBag = not ui.isOpen
    end
    -- already open but tucked away because a menu (the bag) opened: bring it back
    if ui.isOpen and ui.hiddenByMenu then
        ui.hiddenByMenu = false
        ui.win:SetHidden(false)
    end
    S.OpenView("items")
    PlaceWindow()
end

function S.SetBagButtonShown(on)
    S.sv.bagButton = on
    for _, button in ipairs(bagButtons) do button:SetHidden(not on) end
end

local function CreateBagButtons()
    for i, winName in ipairs(BAG_WINDOWS) do
        local bagWin, divider = _G[winName], _G[winName .. "FilterDivider"]
        if bagWin and divider then
            local name = "SetHunter_BagButton" .. i
            local button = WINDOW_MANAGER:CreateControl(name, bagWin, CT_CONTROL)
            button:SetDimensions(LAUNCHER_EMBLEM_W, LAUNCHER_EMBLEM_H)
            button:SetAnchor(BOTTOMLEFT, divider, TOPLEFT, 4, -8)
            button:SetMouseEnabled(true)
            local emblem = MakeEmblem(name .. "Emblem", button, LAUNCHER_EMBLEM_W, LAUNCHER_EMBLEM_H, 20)
            emblem:SetAnchor(CENTER, button, CENTER, 0, 0)
            emblem:SetAlpha(0.8)
            button:SetHandler("OnMouseEnter", function(self)
                emblem:SetAlpha(1)
                InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
                SetTooltipText(InformationTooltip, L("BAG_BUTTON_TT"))
                InformationTooltip:AddLine(L("BAG_BUTTON_TT_INFO"), "ZoFontGameSmall", HexToRGB(COLOR.dim))
            end)
            button:SetHandler("OnMouseExit", function()
                emblem:SetAlpha(0.8)
                ClearTooltip(InformationTooltip)
            end)
            button:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
                if upInside and mouseButton == MOUSE_BUTTON_INDEX_LEFT then OpenFromBag() end
            end)
            bagButtons[#bagButtons + 1] = button
        end
    end
    S.SetBagButtonShown(S.sv.bagButton ~= false)
end

local function CreateOpenAnimation(win)
    if not ANIMATION_MANAGER then return end
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, win)
    fade:SetAlphaValues(0, 1)
    fade:SetDuration(180)
    local grow = timeline:InsertAnimation(ANIMATION_SCALE, win)
    grow:SetScaleValues(0.94, 1)
    grow:SetDuration(220)
    if ZO_EaseOutCubic then
        fade:SetEasingFunction(ZO_EaseOutCubic)
        grow:SetEasingFunction(ZO_EaseOutCubic)
    end
    timeline:SetHandler("OnStop", function()
        if not ui.isOpen then ui.win:SetHidden(true) end
    end)
    ui.openAnim = timeline
end

-- After a resize: everything with a fixed width follows the window's new size.
-- live = while dragging (quick redraw), false = once let go (full refresh).
function S.Relayout(live)
    if not ui.win then return end
    local inner = ui.win:GetWidth() - PAD * 2
    local listW = inner - TREE_W - 20
    ui.listW = listW
    ui.divider:SetDividerWidth(inner)
    ui.divider2:SetDividerWidth(inner)
    ui.crumb:SetWidth(listW - 56)
    ui.header:SetWidth(listW)
    ui.progressRow:SetWidth(listW)
    ui.progressBar:SetWidth(listW - 130 - 110 - 30)
    ui.columns:SetWidth(listW)
    ui.selectedLabel:SetWidth(inner - 560)
    ui.empty:SetWidth(listW - 20)
    if live then
        if ui.lastResult then LayoutRight(ui.lastResult) end
        ZO_ScrollList_RefreshVisible(ui.list)
        ZO_ScrollList_RefreshVisible(ui.tree)
    else
        S.RefreshAll()
    end
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------
local function CreateWindow()
    local sv = S.sv
    local width = zo_clamp(sv.w or WIN_W, MIN_W, MAX_W)
    local height = zo_clamp(sv.h or WIN_H, MIN_H, MAX_H)
    local inner = width - PAD * 2
    local listW = inner - TREE_W - 20

    local win = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_Window")
    win:SetDimensions(width, height)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_MEDIUM)
    win:SetHandler("OnMoveStop", function(self)
        -- stays exactly where you let go
        local x, y = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        -- the bank (and the bag) has its own spot, so moving it there doesn't undo your usual one
        if ui.atBank or ui.besideBag then
            sv.bankX, sv.bankY = x, y
            return
        end
        sv.x, sv.y = x, y
        sv.docked = false
    end)

    -- Resize by dragging any edge or corner (the game shows its double-arrow cursor).
    -- The tree keeps its width; the list side grows and shrinks, live while dragging.
    win:SetResizeHandleSize(8)
    win:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)
    win:SetHandler("OnResizeStart", function(self)
        ClearMenu()
        self:SetHandler("OnUpdate", function() S.Relayout(true) end)
    end)
    win:SetHandler("OnResizeStop", function(self)
        self:SetHandler("OnUpdate", nil)
        sv.w, sv.h = self:GetWidth(), self:GetHeight()
        -- dragging the left or top edge moves the corner too: keep it where it ended up
        local x, y = self:GetLeft(), self:GetTop()
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        if ui.atBank or ui.besideBag then
            sv.bankX, sv.bankY = x, y
        else
            sv.x, sv.y, sv.docked = x, y, false
        end
        S.Relayout(false)
    end)
    ui.win = win

    MakeFadePanel(win, "SetHunter_")

    -- Title and minimize "-"
    -- Title block: bronze crest with the collections icon, the name in ESO's stone-tablet
    -- font (Trajan) and a small subtitle. 42 high, like the old title, so the divider stays put.
    local title = WINDOW_MANAGER:CreateControl("SetHunter_TitleBlock", win, CT_CONTROL)
    title:SetDimensions(inner - 80, 42)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 10)

    -- the Set Hunter emblem (shield + helmet)
    local crestBG = MakeEmblem("SetHunter_Crest", title)
    crestBG:SetAnchor(LEFT, title, LEFT, 0, -2)   -- 48 high on a 42 row: stay clear of the divider

    local name = MakeLabel("SetHunter_Title", title, "$(STONE_TABLET_FONT)|28|soft-shadow-thick", 400, 30, COLOR.selected)
    name:SetText(zo_strupper(L("TITLE")))
    name:SetAnchor(TOPLEFT, title, TOPLEFT, EMBLEM_W + 12, -3)
    local sub = MakeLabel("SetHunter_Subtitle", title, "$(BOLD_FONT)|12|soft-shadow-thin", 400, 14, COLOR.theme)
    sub:SetText(L("SUBTITLE"))
    sub:SetAnchor(TOPLEFT, name, BOTTOMLEFT, 2, 0)

    local minimize = MakeTextButton("SetHunter_Minimize", win, "-", "$(BOLD_FONT)|28|soft-shadow-thin", 28,
        L("MINIMIZE"), function() S.Toggle(false) end)
    minimize:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD + 6, 14)

    -- tabs sit on the title line, right-aligned before the "-" (like ESO's menu bars)
    ui.tabs = {}
    local nextTab = minimize
    for i = #TABS, 1, -1 do
        local key = TABS[i]
        local text = zo_strupper(L(key))
        local tab = MakeLabel("SetHunter_Tab" .. i, win, "ZoFontWinH4", #text * 14, 30, COLOR.dim)
        tab:SetText(text)
        tab:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        if nextTab == minimize then
            -- underline sits just on the divider under the title
            tab:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -PAD - 34, 50)
        else
            -- right of this tab's name = left of the next tab's icon
            tab:SetAnchor(RIGHT, nextTab.icon, LEFT, -24, 0)
        end
        tab:SetMouseEnabled(true)
        -- outline icon in front of the name (colored in PaintTabs)
        tab.icon = WINDOW_MANAGER:CreateControl("SetHunter_Tab" .. i .. "Icon", win, CT_TEXTURE)
        tab.icon:SetDimensions(TAB_ICON_SIZE, TAB_ICON_SIZE)
        tab.icon:SetAnchor(RIGHT, tab, LEFT, -TAB_ICON_GAP, 0)
        tab.icon:SetTexture(TAB_ICONS[key])
        tab.icon:SetMouseEnabled(true)   -- the icon is part of the tab
        tab.line = WINDOW_MANAGER:CreateControl("SetHunter_Tab" .. i .. "Line", tab, CT_TEXTURE)
        tab.line:SetHeight(2)
        tab.line:SetAnchor(BOTTOMRIGHT, tab, BOTTOMRIGHT, 0, 2)
        SetHexColor(tab.line, COLOR.theme)
        local function Enter() tab.hovered = true; PaintTabs() end
        local function Exit() tab.hovered = false; PaintTabs() end
        local function Up(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then SelectTab(key) end
        end
        for _, control in ipairs({ tab, tab.icon }) do
            control:SetHandler("OnMouseEnter", Enter)
            control:SetHandler("OnMouseExit", Exit)
            control:SetHandler("OnMouseUp", Up)
        end
        ui.tabs[key] = tab
        nextTab = tab
    end
    -- text widths are only known a frame later
    zo_callLater(function()
        for _, tab in pairs(ui.tabs) do tab:SetWidth(tab:GetTextWidth() + 2) end
        PaintTabs()
    end, 1)

    local divider = MakeDivider("SetHunter_Divider", win, inner)
    divider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
    ui.divider = divider

    -- Bottom: "Selected: ..." on the left, action buttons on the right
    ui.actions = {}
    ui.actions.travel = MakeButton("SetHunter_ActTravel", win, L("BTN_TRAVEL"), 180, TravelOrQueue)
    ui.actions.travel:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -PAD, -16)
    ui.actions.link = MakeButton("SetHunter_ActLink", win, L("BTN_LINK"), 130,
        function() if ui.selected and ui.selected.link then LinkInChat(ui.selected) end end)
    ui.actions.link:SetAnchor(RIGHT, ui.actions.travel, LEFT, -10, 0)
    ui.actions.wish = MakeButton("SetHunter_ActWish", win, L("BTN_WISH"), 210,
        function() if IsSetLike(ui.selected) then ToggleWish(ui.selected) end end)
    ui.actions.wish:SetAnchor(RIGHT, ui.actions.link, LEFT, -10, 0)

    ui.selectedLabel = MakeLabel("SetHunter_Selected", win, "ZoFontGame", inner - 560, 28, COLOR.normal)
    ui.selectedLabel:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PAD, -16)
    ui.selectedLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    ui.selectedLabel:SetMaxLineCount(1)

    local divider2 = MakeDivider("SetHunter_Divider2", win, inner)
    divider2:SetAnchor(BOTTOMLEFT, ui.selectedLabel, TOPLEFT, 0, -10)
    ui.divider2 = divider2

    -- Left: search, toggles, category tree
    local searchBox, search = MakeEdit("SetHunter_Search", win, TREE_W, L("SEARCH"))
    searchBox:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 12)
    ui.searchBox = searchBox
    -- Starting a search counts as a new page (Back returns to where you searched from).
    ui.lastSearch = ""
    search:SetHandler("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if not ui.restoring and ui.lastSearch == "" and text ~= "" then
            local page = CurrentPage()
            page.search = ""
            if not SamePage(page, history[#history]) then
                history[#history + 1] = page
                ZO_ClearNumericallyIndexedTable(future)
                UpdateNavButtons()
            end
        end
        ui.lastSearch = text
        S.RefreshAll()
    end)
    ui.search = search

    local missing = MakeToggle("SetHunter_Missing", win, L("MISSING_ONLY"),
        function() return S.sv.missingOnly end,
        function(on)
            S.sv.missingOnly = on
            S.RefreshAll()
        end,
        L("MISSING_ONLY_TT"))
    missing:SetAnchor(TOPLEFT, searchBox, BOTTOMLEFT, 0, 8)
    ui.missingToggle = missing
    ui.announceToggle = MakeToggle("SetHunter_Announce", win, L("ANNOUNCE"),
        function() return S.sv.announce end,
        function(on) S.sv.announce = on end,
        L("ANNOUNCE_TT"))
    ui.announceToggle:SetAnchor(LEFT, missing, RIGHT, 6, 0)

    -- My items: whose items to show (ESO's own dropdown); placed after the badges
    -- in LayoutRight
    local scopeBox = WINDOW_MANAGER:CreateControlFromVirtual("SetHunter_Scope", win, "ZO_ComboBox")
    scopeBox:SetDimensions(180, 26)   -- fits next to the badges even at the smallest window size
    scopeBox:SetHidden(true)
    ui.scopeBox = scopeBox
    ui.scope = ZO_ComboBox_ObjectFromContainer(scopeBox)
    ui.scope:SetSortsItems(false)

    local tree = WINDOW_MANAGER:CreateControlFromVirtual("SetHunter_Tree", win, "ZO_ScrollList")
    tree:SetAnchor(TOPLEFT, missing, BOTTOMLEFT, 0, 6)
    tree:SetAnchor(BOTTOMLEFT, divider2, TOPLEFT, 0, -8)
    tree:SetWidth(TREE_W)
    ZO_ScrollList_AddDataType(tree, TREE_CATEGORY, "SetHunter_Category", 30, SetupCategory)
    ZO_ScrollList_AddDataType(tree, TREE_SUB, "SetHunter_SubCategory", 26, SetupCategory)
    ZO_ScrollList_AddDataType(tree, TREE_HEADER, "SetHunter_TreeHeader", 30, SetupTreeHeader)
    ui.tree = tree

    -- Right: breadcrumb and count
    ui.listW = listW
    -- Back / forward: ESO's own arrow buttons. The game swaps the art by itself:
    -- normal, bright under the mouse, pressed, and greyed out when there's nowhere to go.
    local function MakeNavButton(name, direction, tooltip, onClick)
        local button = WINDOW_MANAGER:CreateControl(name, win, CT_BUTTON)
        button:SetDimensions(26, 26)
        local art = "EsoUI/Art/Buttons/large_" .. direction .. "Arrow_"
        button:SetNormalTexture(art .. "up.dds")
        button:SetMouseOverTexture(art .. "over.dds")
        button:SetPressedTexture(art .. "down.dds")
        button:SetDisabledTexture(art .. "disabled.dds")
        LeftClickOnly(button)
        button:SetHandler("OnClicked", function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            onClick()
        end)
        button:SetHandler("OnMouseEnter", function(self)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, tooltip)
        end)
        button:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        function button:SetNavEnabled(enabled)
            self:SetEnabled(enabled)
        end
        button:SetNavEnabled(false)
        return button
    end
    ui.back = MakeNavButton("SetHunter_Back", "left", L("NAV_BACK"), function() S.GoBack() end)
    ui.back:SetAnchor(TOPLEFT, searchBox, TOPRIGHT, 14, -3)
    ui.forward = MakeNavButton("SetHunter_Forward", "right", L("NAV_FORWARD"), function() S.GoForward() end)
    ui.forward:SetAnchor(LEFT, ui.back, RIGHT, 0, 0)

    -- breadcrumb: one label per part so each can be clicked
    ui.crumb = WINDOW_MANAGER:CreateControl("SetHunter_Crumb", win, CT_CONTROL)
    ui.crumb:SetDimensions(listW - 56, 20)
    ui.crumb:SetAnchor(LEFT, ui.forward, RIGHT, 8, 1)
    ui.crumbLabels = {}
    local prev
    for i = 1, 5 do
        local label = MakeLabel("SetHunter_Crumb" .. i, ui.crumb, "ZoFontGameSmall", 60, 20, COLOR.dim)
        label:SetMaxLineCount(1)
        if prev then
            label:SetAnchor(LEFT, prev, RIGHT, 6, 0)
        else
            label:SetAnchor(LEFT, ui.crumb, LEFT, 0, 0)
        end
        label:SetHandler("OnMouseEnter", function(self) SetHexColor(self, COLOR.selected) end)
        label:SetHandler("OnMouseExit", function(self) SetHexColor(self, self.part and COLOR.normal or COLOR.dim) end)
        label:SetHandler("OnMouseUp", function(self, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT and self.part then GoCrumb(self.part) end
        end)
        label:SetHidden(true)
        ui.crumbLabels[i] = label
        prev = label
    end

    -- Header: title, badges, info lines; dungeon art and "how drops work" on the right
    local header = WINDOW_MANAGER:CreateControl("SetHunter_ViewHeader", win, CT_CONTROL)
    header:SetDimensions(listW, 60)
    header:SetAnchor(TOPLEFT, searchBox, TOPRIGHT, 20, 24)
    ui.header = header

    ui.viewTitle = MakeLabel("SetHunter_ViewTitle", header, "ZoFontWinH2", listW, 34, COLOR.selected)
    ui.viewTitle:SetAnchor(TOPLEFT, header, TOPLEFT, 0, 0)
    ui.viewTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    ui.viewTitle:SetMaxLineCount(1)

    ui.badges = {}
    for i = 1, 4 do ui.badges[i] = MakeBadge("SetHunter_Badge" .. i, header) end

    local info = WINDOW_MANAGER:CreateControl("SetHunter_Info", header, CT_LABEL)
    info:SetFont("ZoFontGame")
    SetHexColor(info, COLOR.normal)
    ui.info = info

    ui.art = WINDOW_MANAGER:CreateControl("SetHunter_Art", header, CT_TEXTURE)
    ui.art:SetDimensions(ART_W, ART_H)
    ui.art:SetTextureCoords(unpack(ART_COORDS))
    ui.art:SetAnchor(TOPRIGHT, header, TOPRIGHT, 0, 0)

    ui.how = MakeLabel("SetHunter_How", header, "ZoFontGameSmall", 140, 20, COLOR.dim)
    ui.how:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.how:SetText(zo_iconFormat("EsoUI/Art/Miscellaneous/help_icon.dds", 16, 16) .. " " .. L("HOW_DROPS"))
    ui.how:SetMouseEnabled(true)
    ui.how:SetHandler("OnMouseEnter", function(self)
        SetHexColor(self, COLOR.selected)
        if ui.rules then
            InitializeTooltip(InformationTooltip, self, BOTTOMRIGHT, 0, -6, TOPRIGHT)
            SetTooltipText(InformationTooltip, L("HOW_DROPS"))
            InformationTooltip:AddLine(ui.rules, "ZoFontGame", HexToRGB(COLOR.normal))
        end
    end)
    ui.how:SetHandler("OnMouseExit", function(self)
        SetHexColor(self, COLOR.dim)
        ClearTooltip(InformationTooltip)
    end)

    -- Other sources pages: "Open Antiquities" / "Queue random dungeon" / "Open Battlegrounds"
    -- link under "How drops work" (ui.sourceKey = which one, set in LayoutRight)
    ui.sourceLink = MakeLabel("SetHunter_SourceLink", header, "ZoFontGameSmall", 170, 22, COLOR.theme)
    ui.sourceLink:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.sourceLink:SetAnchor(TOPRIGHT, ui.how, BOTTOMRIGHT, 0, 4)
    ui.sourceLink:SetMouseEnabled(true)
    ui.sourceLink:SetHidden(true)
    ui.sourceLink:SetHandler("OnMouseEnter", function(self)
        SetHexColor(self, COLOR.selected)
        local action = SOURCE_ACTIONS[ui.sourceKey]
        if action then
            InitializeTooltip(InformationTooltip, self, BOTTOMRIGHT, 0, -6, TOPRIGHT)
            SetTooltipText(InformationTooltip, L(action.linkTip))
        end
    end)
    ui.sourceLink:SetHandler("OnMouseExit", function(self)
        SetHexColor(self, COLOR.theme)
        ClearTooltip(InformationTooltip)
    end)
    ui.sourceLink:SetHandler("OnMouseUp", function(_, button, upInside)
        local action = SOURCE_ACTIONS[ui.sourceKey]
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and action then action.run() end
    end)

    -- Collection progress bar
    local progressRow = WINDOW_MANAGER:CreateControl("SetHunter_ProgressRow", win, CT_CONTROL)
    progressRow:SetDimensions(listW, 22)
    ui.progressLabel = MakeLabel("SetHunter_ProgressLabel", progressRow, "ZoFontGameSmall", 130, 22, COLOR.dim)
    ui.progressLabel:SetAnchor(LEFT, progressRow, LEFT, 0, 0)
    ui.progressValue = MakeLabel("SetHunter_ProgressValue", progressRow, "ZoFontGameSmall", 110, 22, COLOR.selected)
    ui.progressValue:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.progressValue:SetAnchor(RIGHT, progressRow, RIGHT, -10, 0)
    ui.progressBar = MakeBar("SetHunter_ProgressBar", progressRow, listW - 130 - 110 - 30, 4)
    ui.progressBar:SetAnchor(LEFT, ui.progressLabel, RIGHT, 6, 0)
    ui.progressRow = progressRow

    -- Column titles (offsets match the row templates in SetHunter.xml)
    local columns = WINDOW_MANAGER:CreateControl("SetHunter_Columns", win, CT_CONTROL)
    columns:SetDimensions(listW, 20)
    ui.columnLabels = {}
    for i, x in ipairs({ 32, 224, 352 }) do
        local label = MakeLabel("SetHunter_Col" .. i, columns, "ZoFontGameSmall", 120, 20, COLOR.dim)
        label:SetAnchor(LEFT, columns, LEFT, x, 0)
        ui.columnLabels[i] = label
    end
    local last = MakeLabel("SetHunter_Col4", columns, "ZoFontGameSmall", 120, 20, COLOR.dim)
    last:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    last:SetAnchor(RIGHT, columns, RIGHT, -50, 0)
    ui.columnLabels[4] = last
    ui.columns = columns

    -- Bank link, top right under "How drops work", in the same style: the game's bank
    -- map icon + text. "Summon <your assistant>" when you own a bank assistant (click to
    -- summon); otherwise a grey "Nearest bank" that can't be clicked, with the direction
    -- to the nearest bank in its tooltip.
    local bank = MakeLabel("SetHunter_BankLink", ui.header, "ZoFontGameSmall", 30, 28, COLOR.dim)
    bank:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    bank:SetAnchor(TOPRIGHT, ui.how, BOTTOMRIGHT, 0, 4)
    bank:SetMouseEnabled(true)
    ui.bankLink = bank

    local function PaintBank(hovered)
        if ui.hasBanker then
            SetHexColor(bank, hovered and COLOR.selected or COLOR.normal)
        else
            SetHexColor(bank, COLOR.dim, hovered and 0.8 or 0.55)
        end
    end
    function S.UpdateBankButton()
        ui.bankers = S.GetBankerAssistants()
        ui.hasBanker = #ui.bankers > 0
        bank:SetText(zo_iconFormat(TEX_BANK, 26, 26))
        PaintBank(false)
    end

    -- Bank assistant picker: hovering the link opens a small panel with a square
    -- portrait slot per bank assistant you own (ESO inventory-slot style); click one
    -- to summon it. It stays open while the mouse is on the link or the panel.
    local SLOT, SLOT_GAP, PICKER_PAD = 56, 8, 12
    local picker = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_BankPicker")
    picker:SetDrawTier(DT_HIGH)
    picker:SetMouseEnabled(false)
    picker:SetHidden(true)
    local pickerBG = WINDOW_MANAGER:CreateControl("SetHunter_BankPickerBG", picker, CT_BACKDROP)
    pickerBG:SetAnchorFill(picker)
    pickerBG:SetCenterColor(0, 0, 0, 0.92)
    pickerBG:SetEdgeColor(HexToRGB(COLOR.theme))
    pickerBG:SetEdgeTexture("", 1, 1, 1)
    local pickerTitle = MakeLabel("SetHunter_BankPickerTitle", picker, "ZoFontGameSmall", 300, 18, COLOR.dim)
    pickerTitle:SetAnchor(TOPLEFT, picker, TOPLEFT, PICKER_PAD, 8)
    ui.bankPicker = picker
    local slots = {}

    -- Slot look: dark square with a thin edge; under the mouse it lights up like an
    -- ESO action bar slot (glow, gold edge, brighter portrait, white name).
    local function PaintSlot(slot, hovered)
        slot.frame:SetEdgeColor(HexToRGB(hovered and COLOR.theme or "4A4A44"))
        local edge = hovered and 2 or 1
        slot.frame:SetEdgeTexture("", edge, edge, edge)
        slot.frame:SetCenterColor(hovered and 0.16 or 0.08, hovered and 0.15 or 0.08, hovered and 0.11 or 0.07, 1)
        slot.glow:SetHidden(not hovered)
        slot.icon:SetAlpha(hovered and 1 or 0.8)
        SetHexColor(slot.name, hovered and COLOR.selected or COLOR.normal)
    end

    local function HidePicker()
        picker:SetHidden(true)
        picker:SetHandler("OnUpdate", nil)
        ClearTooltip(InformationTooltip)
    end
    ui.hideBankPicker = HidePicker

    -- Each slot is a real button (on top of the panel, so it gets the mouse); the
    -- square, the glow and the portrait are drawn inside it.
    local function MakeSlot(i)
        local slot = {}
        local button = WINDOW_MANAGER:CreateControl("SetHunter_BankSlot" .. i, picker, CT_BUTTON)
        button:SetDimensions(SLOT, SLOT)
        button:SetDrawLevel(5)
        LeftClickOnly(button)

        local frame = WINDOW_MANAGER:CreateControl("SetHunter_BankSlot" .. i .. "BG", button, CT_BACKDROP)
        frame:SetAnchorFill(button)
        frame:SetMouseEnabled(false)
        frame:SetDrawLevel(5)

        local icon = WINDOW_MANAGER:CreateControl("SetHunter_BankSlot" .. i .. "Icon", button, CT_TEXTURE)
        icon:SetDimensions(SLOT - 8, SLOT - 8)
        icon:SetAnchor(CENTER, button, CENTER, 0, 0)
        icon:SetMouseEnabled(false)
        icon:SetDrawLevel(6)

        local glow = WINDOW_MANAGER:CreateControl("SetHunter_BankSlot" .. i .. "Glow", button, CT_TEXTURE)
        glow:SetTexture("EsoUI/Art/ActionBar/actionBar_mouseOver.dds")
        glow:SetAnchorFill(button)
        glow:SetMouseEnabled(false)
        glow:SetDrawLevel(7)
        glow:SetHidden(true)

        local name = MakeLabel("SetHunter_BankSlot" .. i .. "Name", picker, "ZoFontGameSmall", SLOT + SLOT_GAP, 18, COLOR.normal)
        name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        name:SetMaxLineCount(1)
        name:SetAnchor(TOP, button, BOTTOM, 0, 3)
        slot.button, slot.frame, slot.icon, slot.glow, slot.name = button, frame, icon, glow, name

        button:SetHandler("OnMouseEnter", function(self)
            PaintSlot(slot, true)
            InitializeTooltip(InformationTooltip, self, TOP, 0, 6, BOTTOM)
            SetTooltipText(InformationTooltip, slot.banker.fullName)
            InformationTooltip:AddLine(L("BANKER_CLICK_ONE"), "ZoFontGameSmall", HexToRGB(COLOR.dim))
        end)
        button:SetHandler("OnMouseExit", function()
            PaintSlot(slot, false)
            ClearTooltip(InformationTooltip)
        end)
        button:SetHandler("OnClicked", function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            HidePicker()
            S.SummonBanker(slot.banker)
        end)
        return slot
    end
    local function ShowPicker()
        local bankers = ui.bankers or {}
        local n = #bankers
        pickerTitle:SetText(zo_strupper(n == 1 and L("BANK_PICK_ONE") or L("BANK_PICK_MANY")))
        for i = 1, zo_max(n, #slots) do
            local slot = slots[i]
            if i <= n then
                slot = slot or MakeSlot(i)
                slots[i] = slot
                slot.banker = bankers[i]
                slot.icon:SetTexture(bankers[i].icon)
                slot.name:SetText(bankers[i].name)
                slot.button:ClearAnchors()
                slot.button:SetAnchor(TOPLEFT, picker, TOPLEFT, PICKER_PAD + (i - 1) * (SLOT + SLOT_GAP) + SLOT_GAP / 2, 32)
                PaintSlot(slot, false)
            end
            if slot then
                slot.button:SetHidden(i > n)
                slot.name:SetHidden(i > n)
            end
        end
        local width, height
        if n == 1 then
            local slot = slots[1]
            slot.name:ClearAnchors()
            slot.name:SetAnchor(LEFT, slot.button, RIGHT, 10, 0)
            slot.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            slot.name:SetWidth(#bankers[1].name * 8 + 10)
            width = zo_max(PICKER_PAD * 2 + SLOT_GAP / 2 + SLOT + 10 + #bankers[1].name * 8 + 10, #pickerTitle:GetText() * 8 + PICKER_PAD * 2)
            height = 32 + SLOT + PICKER_PAD
        else
            for i = 1, n do
                local slot = slots[i]
                slot.name:ClearAnchors()
                slot.name:SetAnchor(TOP, slot.button, BOTTOM, 0, 3)
                slot.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
                slot.name:SetWidth(SLOT + SLOT_GAP)
            end
            width = zo_max(PICKER_PAD * 2 + n * (SLOT + SLOT_GAP), #pickerTitle:GetText() * 8 + PICKER_PAD * 2)
            height = 32 + SLOT + 3 + 18 + PICKER_PAD
        end
        picker:SetDimensions(width, height)
        picker:ClearAnchors()
        picker:SetAnchor(TOPRIGHT, bank, BOTTOMRIGHT, 0, 4)
        picker:SetHidden(false)
        -- Close once the mouse has left both the link and the panel for a moment.
        local away = 0
        picker:SetHandler("OnUpdate", function(_, now)
            if IsMouseOver(picker, 4) or IsMouseOver(bank, 4) then
                away = 0
            else
                away = away == 0 and now or away
                if now - away > 0.3 then HidePicker() end
            end
        end)
    end

    bank:SetHandler("OnMouseEnter", function(self)
        PaintBank(true)
        if ui.hasBanker then
            ShowPicker()
            return
        end
        -- No bank assistant: point to the nearest bank instead.
        InitializeTooltip(InformationTooltip, self, BOTTOMRIGHT, 0, -6, TOPRIGHT)
        SetTooltipText(InformationTooltip, L("BANK_NONE_TITLE"))
        local direction = S.NearestBankDirection()
        local text
        if direction == "HERE" then
            text = L("BANK_NONE_HERE")
        elseif direction then
            text = L("BANK_NONE_DIR", L("DIR_" .. direction))
        else
            text = L("BANK_NONE_NODIR")
        end
        InformationTooltip:AddLine(text, "ZoFontGame", HexToRGB(COLOR.normal))
        InformationTooltip:AddLine(L("BANK_NONE_MAP", zo_iconFormat(TEX_BANK, 22, 22)), "ZoFontGameSmall", HexToRGB(COLOR.dim))
    end)
    bank:SetHandler("OnMouseExit", function()
        PaintBank(false)
        if not ui.hasBanker then ClearTooltip(InformationTooltip) end
    end)
    -- Clicking the link itself with one assistant summons it straight away.
    bank:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and ui.bankers and #ui.bankers == 1 then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            HidePicker()
            S.SummonBanker(ui.bankers[1])
        end
    end)
    S.UpdateBankButton()
    local list = WINDOW_MANAGER:CreateControlFromVirtual("SetHunter_List", win, "ZO_ScrollList")
    list:SetWidth(listW)
    ZO_ScrollList_AddDataType(list, ROW_SET, "SetHunter_SetRow", 30, SetupSetRow)
    ZO_ScrollList_AddDataType(list, ROW_HEADER, "SetHunter_Header", 34, SetupHeader)
    ZO_ScrollList_AddDataType(list, ROW_INFO, "SetHunter_InfoRow", 30, SetupInfoRow)
    ZO_ScrollList_AddDataType(list, ROW_ITEM, "SetHunter_ItemRow", 30, SetupItemRow)
    ZO_ScrollList_EnableHighlight(list, "ZO_ThinListHighlight")
    ZO_ScrollList_EnableSelection(list, "ZO_ThinListHighlight", OnSelectionChanged)
    ui.list = list
    LayoutRight({})

    ui.empty = MakeLabel("SetHunter_Empty", win, "ZoFontGame", listW - 20, 60, COLOR.dim)
    ui.empty:SetAnchor(TOP, list, TOP, 0, 40)
    ui.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ui.empty:SetHidden(true)

    CreateOpenAnimation(win)
    S.Relayout(true)
end

-- ---------------------------------------------------------------------------
-- Queue window: dungeon art, Normal / Veteran, Damage / Healer / Tank, then Queue.
-- ---------------------------------------------------------------------------
local qd = {}
local QD_W = 480
local QD_INNER = QD_W - 60
local OPTION_H = 38

-- A big selectable choice (icon + text) with a gold line under it when picked.
local function MakeOption(name, parent, width, icon, text, onClick)
    local option = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    option:SetDimensions(width, OPTION_H)
    option:SetMouseEnabled(true)

    local bg = MakeRoundedBackground(name .. "BG", option, OPTION_H)
    local r, g, b = HexToRGB(COLOR.theme)
    local line = WINDOW_MANAGER:CreateControl(name .. "Line", option, CT_TEXTURE)
    line:SetColor(r, g, b, 1)
    line:SetDimensions(width - OPTION_H, 2)
    line:SetAnchor(BOTTOM, option, BOTTOM, 0, 0)

    local tex = WINDOW_MANAGER:CreateControl(name .. "Icon", option, CT_TEXTURE)
    tex:SetTexture(icon)
    tex:SetDimensions(30, 30)
    tex:SetAnchor(LEFT, option, LEFT, 12, 0)
    tex:SetMouseEnabled(false)

    local label = MakeLabel(name .. "Text", option, "$(BOLD_FONT)|17|soft-shadow-thick", width - 56, OPTION_H, COLOR.dim)
    label:SetText(text)
    label:SetAnchor(LEFT, tex, RIGHT, 6, 0)
    label:SetMouseEnabled(false)

    local function Paint(hovered)
        local on = option.selected
        bg:SetAlpha(on and 0.95 or (hovered and 0.7 or 0.45))
        line:SetHidden(not on)
        SetHexColor(label, (on or hovered) and COLOR.selected or COLOR.dim)
        tex:SetDesaturation(on and 0 or 0.7)
        tex:SetAlpha((on or hovered) and 1 or 0.55)
    end
    function option:SetSelected(selected)
        self.selected = selected
        Paint(false)
    end
    function option:SetOptionEnabled(enabled)
        self.enabled = enabled
        self:SetAlpha(enabled and 1 or 0.3)
    end
    option.enabled = true
    option:SetHandler("OnMouseEnter", function(self) if self.enabled then Paint(true) end end)
    option:SetHandler("OnMouseExit", function() Paint(false) end)
    option:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and self.enabled then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            onClick()
        end
    end)
    return option
end

local function SmallCaps(name, parent, text)
    local l = MakeLabel(name, parent, "ZoFontGameSmall", QD_INNER, 20, COLOR.dim)
    l:SetText(zo_strupper(text))
    return l
end

local function CloseQueueDialog()
    if qd.win then qd.win:SetHidden(true) end
end

local function UpdateQueueDialog()
    if not qd.win or qd.win:IsHidden() then return end
    qd.normal:SetSelected(not qd.veteran)
    qd.vet:SetSelected(qd.veteran)
    qd.normal:SetOptionEnabled(qd.normalId ~= nil)
    qd.vet:SetOptionEnabled(qd.vetId ~= nil)
    for _, option in ipairs(qd.roles) do option:SetSelected(option.role == qd.role) end

    -- Requirement for the chosen difficulty.
    local activityId = qd.veteran and qd.vetId or qd.normalId
    -- the whole line goes green / red; not meeting it is only a warning, you can still queue
    local available = activityId ~= nil
    -- DLC dungeon you don't own: can't be queued at all (random: the game only picks
    -- dungeons you have)
    local ownsDLC, dlcName = true, nil
    if not qd.random then _, ownsDLC, dlcName = S.GetActivityDLC(activityId) end
    if not ownsDLC then available = false end
    if qd.random then
        qd.req:SetText(activityId and L("QUEUE_RANDOM_REWARD") or L("QUEUE_NO_VET"))
        SetHexColor(qd.req, activityId and COLOR.normal or COLOR.bad)
    elseif activityId then
        -- each requirement on its own line: this one is only level / CP (the DLC has
        -- its own red line below), so a met level stays green
        local levelMin, cpMin, ok = S.GetActivityRequirement(activityId)
        local text = cpMin > 0 and L("QUEUE_REQ_CP", cpMin) or L("QUEUE_REQ_LEVEL", levelMin)
        qd.req:SetText(text .. "  " .. L(ok and "QUEUE_REQ_OK" or "QUEUE_REQ_NO"))
        SetHexColor(qd.req, ok and COLOR.good or COLOR.bad)
    else
        qd.req:SetText(L("QUEUE_NO_VET"))
        SetHexColor(qd.req, COLOR.bad)
    end

    -- Warnings, most important first.
    local queued, canStart = S.IsQueued(), S.CanStartQueue()
    local status, color = "", COLOR.accent
    if queued then
        status = L("QUEUE_IN_QUEUE")
    elseif not ownsDLC then
        status, color = L("QUEUE_NO_DLC", dlcName or ""), COLOR.bad
    elseif not canStart then
        status, color = L("QUEUE_NOT_LEADER"), COLOR.bad
    elseif qd.set and qd.set.monster and not qd.veteran then
        status = L("QUEUE_MONSTER_VET")
    end
    qd.status:SetText(status)
    SetHexColor(qd.status, color)

    qd.go:SetText(queued and L("BTN_LEAVE_QUEUE") or (zo_iconFormat(TEX_QUEUE, 22, 22) .. " " .. L("BTN_START_QUEUE")))
    qd.go:SetEnabled(queued or (canStart and available))
end

local function OnQueueClicked()
    if S.IsQueued() then
        S.LeaveQueue()
        zo_callLater(UpdateQueueDialog, 300)
        return
    end
    S.sv.queueVeteran = qd.veteran
    local queued
    if qd.random then
        queued = S.QueueRandomDungeon(qd.veteran, qd.role)
    else
        queued = S.QueueDungeon(qd.zoneId, qd.veteran, qd.role)
    end
    if queued then
        PlaySound(SOUNDS.DEFAULT_CLICK)
        CloseQueueDialog()
        if ui.hideBankPicker then ui.hideBankPicker() end
        ClosePicker()
    end
end

local function CreateQueueDialog()
    local dlg = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_QueueDialog")
    dlg:SetWidth(QD_W)
    dlg:SetAnchor(CENTER, GuiRoot, CENTER, 0, -40)
    dlg:SetDrawTier(DT_HIGH)
    dlg:SetClampedToScreen(true)
    dlg:SetMouseEnabled(true)
    dlg:SetMovable(true)
    dlg:SetHidden(true)
    MakeFadePanel(dlg, "SetHunter_QD")
    qd.win = dlg

    local close = MakeTextButton("SetHunter_QDClose", dlg, "x", "$(BOLD_FONT)|20|soft-shadow-thin", 24,
        L("CANCEL"), CloseQueueDialog)
    close:SetAnchor(TOPRIGHT, dlg, TOPRIGHT, -18, 10)

    -- Dungeon art (when the game has it)
    local banner = WINDOW_MANAGER:CreateControl("SetHunter_QDBanner", dlg, CT_TEXTURE)
    banner:SetDimensions(QD_INNER, 130)
    banner:SetAnchor(TOP, dlg, TOP, 0, 40)
    qd.banner = banner

    -- Dungeon icon + name, what you're farming
    qd.icon = WINDOW_MANAGER:CreateControl("SetHunter_QDIcon", dlg, CT_TEXTURE)
    qd.icon:SetTexture(TEX_QUEUE)
    qd.icon:SetDimensions(40, 40)
    qd.title = MakeLabel("SetHunter_QDTitle", dlg, "ZoFontWinH2", QD_INNER - 50, 40, COLOR.selected)
    qd.title:SetAnchor(LEFT, qd.icon, RIGHT, 10, 0)

    qd.sub = MakeLabel("SetHunter_QDSub", dlg, "ZoFontGameSmall", QD_INNER, 44, COLOR.normal)
    qd.sub:SetVerticalAlignment(TEXT_ALIGN_TOP)
    qd.sub:SetAnchor(TOPLEFT, qd.icon, BOTTOMLEFT, 0, 8)

    local divider = MakeDivider("SetHunter_QDDivider", dlg, QD_INNER)
    divider:SetAnchor(TOPLEFT, qd.sub, BOTTOMLEFT, 0, 6)

    -- Difficulty
    local diffLabel = SmallCaps("SetHunter_QDDiffLabel", dlg, L("QUEUE_DIFFICULTY"))
    diffLabel:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 12)
    local halfW = (QD_INNER - 10) / 2
    qd.normal = MakeOption("SetHunter_QDNormal", dlg, halfW, TEX_NORMAL, L("NORMAL"), function()
        qd.veteran = false
        UpdateQueueDialog()
    end)
    qd.normal:SetAnchor(TOPLEFT, diffLabel, BOTTOMLEFT, 0, 6)
    qd.vet = MakeOption("SetHunter_QDVet", dlg, halfW, TEX_VETERAN, L("VETERAN"), function()
        qd.veteran = true
        UpdateQueueDialog()
    end)
    qd.vet:SetAnchor(LEFT, qd.normal, RIGHT, 10, 0)

    -- Role
    local roleLabel = SmallCaps("SetHunter_QDRoleLabel", dlg, L("QUEUE_ROLE"))
    roleLabel:SetAnchor(TOPLEFT, qd.normal, BOTTOMLEFT, 0, 14)
    local thirdW = (QD_INNER - 20) / 3
    qd.roles = {}
    local previous
    for i, entry in ipairs(S.ROLES) do
        local option = MakeOption("SetHunter_QDRole" .. i, dlg, thirdW, S.RoleIcon(entry), L(entry.key), function()
            qd.role = entry.role
            UpdateQueueDialog()
        end)
        option.role = entry.role
        if previous then
            option:SetAnchor(LEFT, previous, RIGHT, 10, 0)
        else
            option:SetAnchor(TOPLEFT, roleLabel, BOTTOMLEFT, 0, 6)
        end
        qd.roles[i] = option
        previous = option
    end

    -- Requirement and warnings
    qd.req = MakeLabel("SetHunter_QDReq", dlg, "ZoFontGame", QD_INNER, 24, COLOR.normal)
    qd.req:SetAnchor(TOPLEFT, qd.roles[1], BOTTOMLEFT, 0, 14)
    -- up to two lines, so longer warnings wrap inside the window instead of running off it
    qd.status = MakeLabel("SetHunter_QDStatus", dlg, "ZoFontGameSmall", QD_INNER, 40, COLOR.accent)
    qd.status:SetVerticalAlignment(TEXT_ALIGN_TOP)
    qd.status:SetMaxLineCount(2)
    qd.status:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    qd.status:SetAnchor(TOPLEFT, qd.req, BOTTOMLEFT, 0, 2)

    -- Buttons
    local cancel = MakeButton("SetHunter_QDCancel", dlg, L("CANCEL"), 130, CloseQueueDialog)
    cancel:SetAnchor(BOTTOMRIGHT, dlg, BOTTOMRIGHT, -30, -18)
    qd.go = MakeButton("SetHunter_QDGo", dlg, L("BTN_START_QUEUE"), 190, OnQueueClicked)
    qd.go:SetAnchor(RIGHT, cancel, LEFT, -10, 0)

    -- Keep the buttons honest while the dialog is open (queue joined / left, group changes).
    local function Refresh() UpdateQueueDialog() end
    for _, event in ipairs({ EVENT_ACTIVITY_FINDER_STATUS_UPDATE, EVENT_GROUP_MEMBER_JOINED,
        EVENT_GROUP_MEMBER_LEFT, EVENT_LEADER_UPDATE }) do
        if event then EVENT_MANAGER:RegisterForEvent("SetHunter_QD", event, Refresh) end
    end
end

-- Content height without / with the dungeon art.
local QD_H, QD_BANNER_H = 440, 140

-- Opens the queue window for a dungeon; setData (optional) is what you're farming,
-- veteran (optional) picks the difficulty (Queue again from the run summary).
-- zoneId "random": Random Normal / Random Veteran Dungeon instead of one dungeon.
function S.OpenQueueDialog(zoneId, setData, veteran)
    if not qd.win then CreateQueueDialog() end
    qd.random = zoneId == "random"
    qd.zoneId = zoneId
    qd.set = setData and setData.kind == "set" and setData or nil
    if qd.random then
        qd.normalId = S.FindRandomDungeonSet(false)
        qd.vetId = S.FindRandomDungeonSet(true)
    else
        qd.normalId = S.FindDungeonActivity(zoneId, false)
        qd.vetId = S.FindDungeonActivity(zoneId, true)
    end
    -- Monster helms only drop on Veteran, so start there for them; otherwise the last choice.
    qd.veteran = (qd.set and qd.set.monster ~= nil or S.sv.queueVeteran == true) and qd.vetId ~= nil
    if veteran ~= nil then qd.veteran = veteran and qd.vetId ~= nil end
    if not qd.normalId then qd.veteran = qd.vetId ~= nil end
    qd.role = S.GetRole()

    -- Art on top when available, then icon + name.
    local art
    if qd.random then
        art = S.GetActivitySetBanner(qd.normalId or qd.vetId)
    else
        art = S.GetActivityBanner(qd.vetId or qd.normalId)
    end
    -- banner on top (only if it really exists, see CheckArt), then icon + name
    local function LayoutBanner(path)
        qd.banner:SetHidden(path == nil)
        qd.banner:SetHandler("OnUpdate", nil)
        qd.icon:ClearAnchors()
        if path then
            qd.banner:SetTexture(path)
            qd.banner:SetAlpha(1)
            qd.icon:SetAnchor(TOPLEFT, qd.banner, BOTTOMLEFT, 0, 10)
        else
            qd.icon:SetAnchor(TOPLEFT, qd.win, TOPLEFT, 30, 24)
        end
        qd.win:SetHeight(QD_H + (path and QD_BANNER_H or 0))
    end
    art = UsableArt(art)
    LayoutBanner(art)
    if art and artChecked[art] == nil then
        CheckArt(qd.banner, art, function(ok)
            if ok then qd.banner:SetAlpha(1) else LayoutBanner(nil) end
        end)
    end

    qd.title:SetText(qd.random and L("RANDOM_DUNGEON") or S.ZoneName(zoneId))
    local lines = {}
    if qd.random then
        lines[#lines + 1] = L("QUEUE_RANDOM_SUB")
    elseif qd.set then
        lines[#lines + 1] = L("QUEUE_FOR", qd.set.name, qd.set.typeText)
        if qd.set.monster then lines[#lines + 1] = Colorize(COLOR.header, L("TT_HEAD", qd.set.monster.boss)) end
    else
        local loc = S.GetLocation(zoneId)
        if loc and loc.monster then
            lines[#lines + 1] = Colorize(COLOR.header, L("MONSTER_LINE", loc.monster.set, loc.monster.boss))
        end
    end
    qd.sub:SetText(table.concat(lines, "\n"))

    qd.win:SetHidden(false)
    SetGameCameraUIMode(true)
    UpdateQueueDialog()
end

-- Game menus: hide the open window while one is up, show it again after.
local function IsHudScene(scene)
    return scene == HUD_SCENE or scene == HUD_UI_SCENE
end

-- Bank (a banker or your assistant): open next to it on My items, so bank pieces can
-- be clicked to find them; closes again with the bank if it wasn't open before.
local function OnBankScene(newState)
    if newState == SCENE_SHOWING then
        ui.atBank = true
        ui.openedForBank = not ui.isOpen
        ui.hiddenByMenu = false
        if ui.isOpen then
            PlaceWindow()
            ui.win:SetHidden(false)
        else
            S.Toggle(true)
        end
        if CurrentTab() ~= "TREE_ITEMS" then SelectTab("TREE_ITEMS") end
        S.RefreshAll()
    elseif newState == SCENE_HIDDEN and ui.atBank then
        ui.atBank = false
        ClearTooltip(InformationTooltip)
        ClearTooltip(ItemTooltip)
        if ui.openedForBank then S.Toggle(false) else PlaceWindow() end
        ui.openedForBank = nil
        S.RefreshAll()
    end
end

local function OnSceneStateChanged(scene, _, newState)
    if not ui.win then return end
    if S.sv.bankOpen and scene == SCENE_MANAGER:GetScene("bank") then
        OnBankScene(newState)
        return
    end
    -- opened with the bag button: close again with the bag (or go back to its usual spot)
    if ui.besideBag and scene == SCENE_MANAGER:GetScene("inventory") and newState == SCENE_HIDDEN then
        ui.besideBag = false
        ClearTooltip(ItemTooltip)
        if ui.openedForBag then S.Toggle(false) else PlaceWindow() end
        ui.openedForBag = nil
        return
    end
    if not ui.isOpen then return end
    if newState == SCENE_SHOWING and not IsHudScene(scene) and not ui.hiddenByMenu then
        ui.hiddenByMenu = true
        CloseQueueDialog()
        if ui.hideBankPicker then ui.hideBankPicker() end
        ClosePicker()
        ClearMenu()
        ClearTooltip(InformationTooltip)
        ClearTooltip(ItemTooltip)
        ui.win:SetHidden(true)
    elseif newState == SCENE_SHOWN and IsHudScene(scene) and ui.hiddenByMenu then
        ui.hiddenByMenu = false
        ui.win:SetHidden(false)
        S.RefreshAll()
    end
end

-- Open (true), minimize (false) or flip (nil).
function S.Toggle(show)
    if not ui.win then return end
    if show == nil then show = not ui.isOpen end
    if show == (ui.isOpen == true) then return end
    ui.isOpen = show
    ui.hiddenByMenu = false
    SetLauncherTextColor(false)

    if show then
        PlaceWindow()
        ui.win:SetHidden(false)
        ZO_ClearTable(reachCache)   -- new wayshrines may have been found since
        ui.reachGen = (ui.reachGen or 0) + 1   -- rows work out their shortcut again
        S.RefreshAll()
        if S.UpdateBankButton then S.UpdateBankButton() end
        SetGameCameraUIMode(true)   -- mouse cursor, but stay in the game world
        if ui.openAnim then
            if ui.openAnim:IsPlaying() then ui.openAnim:PlayForward() else ui.openAnim:PlayFromStart() end
        else
            ui.win:SetAlpha(1)
        end
    else
        CloseQueueDialog()
        if ui.hideBankPicker then ui.hideBankPicker() end
        ClosePicker()
        ClearMenu()
        ClearTooltip(InformationTooltip)
        ClearTooltip(ItemTooltip)
        ui.search:LoseFocus()
        if ui.openAnim then
            if ui.openAnim:IsPlaying() then ui.openAnim:PlayBackward() else ui.openAnim:PlayFromEnd() end
        else
            ui.win:SetHidden(true)
        end
    end
end

-- /sethunter and the keybind: bring the button back if hidden, and open / minimize.
function S.ToggleWindow()
    if S.sv.launcherHidden then S.SetLauncherShown(true) end
    S.Toggle()
end

-- /sethunter <text>: open searching for a set.
function S.OpenWithSearch(text)
    if S.sv.launcherHidden then S.SetLauncherShown(true) end
    S.Toggle(true)
    ui.search:SetText(text)   -- OnTextChanged refreshes the list
end

-- /sethunter here | wishlist | xp
function S.OpenView(view)
    if S.sv.launcherHidden then S.SetLauncherShown(true) end
    if ui.win and ui.isOpen then RememberPage() end
    S.sv.view, S.sv.loc = view, nil
    ui.itemsSetId = nil
    ui.boostKey = nil
    if ui.search then ui.search:SetText("") end
    if ui.isOpen then S.RefreshAll() else S.Toggle(true) end
end

function S.SetAnnounce(on)
    S.sv.announce = on
    if ui.announceToggle then ui.announceToggle.Refresh() end
end

function S.SetMissingOnly(on)
    S.sv.missingOnly = on
    if ui.missingToggle then ui.missingToggle.Refresh() end
    S.RefreshAll()
end

-- Shared look for the other windows (run summary).
S.UIKit = {
    COLOR = COLOR,
    HexToRGB = HexToRGB,
    SetHexColor = SetHexColor,
    Colorize = Colorize,
    MakeLabel = MakeLabel,
    MakeButton = MakeButton,
    MakeTextButton = MakeTextButton,
    MakeFadePanel = MakeFadePanel,
    MakeDivider = MakeDivider,
    MakeBar = MakeBar,
    TEX_QUEUE = TEX_QUEUE,
    TEX_VETERAN = TEX_VETERAN,
    TEX_NORMAL = TEX_NORMAL,
}

function S.InitUI()
    CreateWindow()
    CreateLauncher()
    CreateBagButtons()
    PlaceWindow()
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
end
