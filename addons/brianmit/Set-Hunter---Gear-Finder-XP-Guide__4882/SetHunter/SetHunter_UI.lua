-- SetHunter_UI.lua : floating window in ESO's menu style (same look as Command
-- Codex), plus a small movable "Set Hunter" button that opens / minimizes it.
-- Category tree on the left, sets or guide rows on the right with an info panel
-- above them, action buttons at the bottom.

local S = SetHunter
local L = S.L
local D = S.DATA
local ui = { reachGen = 1 }

local WIN_W, WIN_H = 960, 680           -- starting size
local MIN_W, MIN_H = 860, 540           -- the window can be resized between these
local MAX_W, MAX_H = 1600, 1200
local PAD = 28
local TREE_W = 262   -- room for "Collection overview" / "Recently collected" without "..."

local TREE_CATEGORY, TREE_SUB, TREE_HEADER = 1, 2, 3
local DropIn   -- the short drop-in animation for pop-up panels (defined with the tab animation)
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

local TEX_ROUNDED = "SetHunter/Textures/rounded_fill.dds"
local TEX_CIRCLE = "SetHunter/Textures/circle.dds"
local TEX_RING = "SetHunter/Textures/circle_ring.dds"
local TEX_ICON = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds"
local TEX_QUEUE = "EsoUI/Art/LFG/LFG_indexIcon_dungeon_up.dds"
local TEX_NORMAL = "EsoUI/Art/LFG/LFG_normalDungeon_up.dds"
local TEX_VETERAN = "EsoUI/Art/LFG/LFG_veteranDungeon_up.dds"

local ARROW_CLOSED = "EsoUI/Art/Buttons/tree_closed_up.dds"

local TEX_BAG = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds"
local TEX_BANK = "EsoUI/Art/Icons/ServiceMapPins/servicepin_bank.dds"   -- the bank icon on the map
-- the same symbol in the map's hover tooltip, larger (path guessed; checked before use)
-- the glass button under "How drops work" (Start a new session, Open Antiquities, ...)
local SOURCE_BTN_H, SOURCE_TEXT = 26, "C08A4E"   -- the UI's bronze (text and icon)
local CREDIT_ALPHA = 0.24   -- the "by brianmit · v..." line: faint (0.14 too dark; brighter ones too noticeable)
local BADGE_ROW_Y = 47   -- middle of the badge row in the page header (title 34 + 2, badges 22 high)
local TEX_BANK_HD ="EsoUI/Art/Icons/ServiceTooltipIcons/servicetooltipicon_bank.dds"
local TEX_STAR = "EsoUI/Art/Collections/Favorite_StarOnly.dds"

-- icon: ESO's own textures (main menu, map and group finder icons).
-- header = which tab the entries below belong to; group = a small group title in the
-- tree (YOUR GOALS, BROWSE, ...)
local CATEGORIES = {
    { header = "TREE_SETS" },
    { group = "GRP_GOALS" },
    { view = "wishlist",  key = "CAT_WISHLIST",  icon = TEX_STAR, expand = "wish" },
    { view = "traithunt", key = "CAT_HUNT",      icon = "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds" },
    { view = "almost",    key = "CAT_ALMOST",    icon = "EsoUI/Art/MainMenu/menuBar_skills_up.dds" },
    { group = "GRP_BROWSE" },
    -- The compass marker of your tracked quest.
    { view = "here",      key = "CAT_HERE",      icon = "EsoUI/Art/Compass/quest_icon_assisted.dds" },
    { view = "dungeon",   key = "CAT_DUNGEON",   icon = TEX_QUEUE, kind = "dungeon" },
    { view = "trial",     key = "CAT_TRIAL",     icon = "EsoUI/Art/Icons/poi/poi_raiddungeon_complete.dds", kind = "trial" },
    { view = "arena",     key = "CAT_ARENA",     icon = "EsoUI/Art/Icons/poi/poi_solotrial_complete.dds", kind = "arena" },
    { view = "overland",  key = "CAT_OVERLAND",  icon = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds", kind = "overland" },
    { view = "pvp",       key = "CAT_PVP",       icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds", kind = "pvp" },
    { view = "other",     key = "CAT_OTHER",     icon = "EsoUI/Art/MainMenu/menuBar_journal_up.dds", kind = "other" },
    { view = "crafted",   key = "CAT_CRAFTED",   icon = "EsoUI/Art/Icons/ServiceMapPins/servicepin_smithy.dds" },
    { view = "monster",   key = "CAT_MONSTER",   icon = TEX_VETERAN },
    { group = "GRP_PROGRESS" },
    { view = "overview",  key = "CAT_OVERVIEW",  icon = "EsoUI/Art/MainMenu/menuBar_collections_up.dds" },
    { view = "recent",    key = "CAT_RECENT",    icon = TEX_BAG },
    { header = "TREE_ITEMS" },
    { group = "GRP_PIECES" },
    { view = "items",     key = "CAT_ITEMS",     icon = TEX_BAG },
    { view = "items_new", key = "CAT_ITEMS_NEW", icon = "EsoUI/Art/MainMenu/menuBar_collections_up.dds" },
    { view = "items_trade", key = "CAT_ITEMS_TRADE", icon = "EsoUI/Art/MainMenu/menuBar_market_up.dds" },
    -- groupings: one sub-entry per trait / slot / quality / ... (see ITEM_MODES groupOf)
    { group = "GRP_SORTED" },
    { view = "items_trait", key = "CAT_ITEMS_TRAIT", icon = "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds", expand = "groups" },
    { view = "items_slot",  key = "CAT_ITEMS_SLOT",  icon = TEX_ICON, expand = "groups" },
    { view = "items_quality", key = "CAT_ITEMS_QUALITY", icon = TEX_STAR, expand = "groups" },
    { view = "items_weight", key = "CAT_ITEMS_WEIGHT", icon = "EsoUI/Art/MainMenu/menuBar_character_up.dds", expand = "groups" },
    { view = "items_settype", key = "CAT_ITEMS_SETTYPE", icon = "EsoUI/Art/MainMenu/menuBar_journal_up.dds", expand = "groups" },
    { group = "GRP_CLEANUP" },
    { view = "items_decon", key = "CAT_ITEMS_DECON", icon = "EsoUI/Art/Crafting/enchantment_tabIcon_deconstruction_up.dds" },
    { view = "items_dupes", key = "CAT_ITEMS_DUPES", icon = "EsoUI/Art/Crafting/smithing_tabIcon_refine_up.dds" },
    { view = "items_low",   key = "CAT_ITEMS_LOW",   icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds" },
    { header = "TREE_XP" },
    { group = "GRP_XP_FARM" },
    { view = "xp_spots",  key = "CAT_XP_SPOTS",  icon = "EsoUI/Art/MainMenu/menuBar_skills_up.dds" },
    { view = "xp_daily",  key = "CAT_XP_DAILY",  icon = TEX_QUEUE },
    { group = "GRP_XP_GEAR" },
    { view = "xp_boosts", key = "CAT_XP_BOOSTS", icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds" },
    { view = "xp_setup",  key = "CAT_XP_SETUP",  icon = "EsoUI/Art/MainMenu/menuBar_character_up.dds" },
    { group = "GRP_XP_TRACK" },
    { view = "xp_session", key = "CAT_XP_SESSION", icon = "SetHunter/Textures/tab_xp.dds" },
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

-- The window frame: a glass bevel, as if light falls from above. The top and left edges
-- catch the light (bright hairline + a fainter one inside); the right side and the bottom
-- have the left's softer light line. Small bronze L-shaped corner pieces sit on top.
local CORNER_LEN, CORNER_W = 18, 2
local GLASS_EDGES = {
    -- side, inset, alpha, white (true) or black
    { "TOP", 0, 0.28, true }, { "TOP", 1, 0.07, true },
    { "LEFT", 0, 0.14, true }, { "LEFT", 1, 0.04, true },
    -- the right side and the bottom get the left side's light line too (a dark one
    -- vanished on the dark game world, so those edges had no visible outline)
    { "RIGHT", 0, 0.14, true }, { "RIGHT", 1, 0.04, true },
    { "BOTTOM", 0, 0.14, true }, { "BOTTOM", 1, 0.04, true },
}
local function MakeFrame(win, prefix)
    local br, bg, bb = HexToRGB(COLOR.theme)
    for i, e in ipairs(GLASS_EDGES) do
        local side, inset, alpha, light = e[1], e[2], e[3], e[4]
        local t = WINDOW_MANAGER:CreateControl(prefix .. "Glass" .. i, win, CT_TEXTURE)
        if light then t:SetColor(1, 1, 1, alpha) else t:SetColor(0, 0, 0, alpha) end
        t:SetMouseEnabled(false)
        if side == "TOP" then
            t:SetAnchor(TOPLEFT, win, TOPLEFT, inset, inset)
            t:SetAnchor(TOPRIGHT, win, TOPRIGHT, -inset, inset)
            t:SetHeight(1)
        elseif side == "BOTTOM" then
            t:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, inset, -inset)
            t:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -inset, -inset)
            t:SetHeight(1)
        elseif side == "LEFT" then
            t:SetAnchor(TOPLEFT, win, TOPLEFT, inset, inset + 1)
            t:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, inset, -inset - 1)
            t:SetWidth(1)
        else
            t:SetAnchor(TOPRIGHT, win, TOPRIGHT, -inset, inset + 1)
            t:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -inset, -inset)
            t:SetWidth(1)
        end
    end
    local n = 0
    local function Bar(point, x, y, w, h)
        n = n + 1
        local t = WINDOW_MANAGER:CreateControl(prefix .. "Corner" .. n, win, CT_TEXTURE)
        t:SetDimensions(w, h)
        t:SetAnchor(point, win, point, x, y)
        t:SetColor(br, bg, bb, 1)
        t:SetMouseEnabled(false)
    end
    local len, thick, at = CORNER_LEN, CORNER_W, 2
    Bar(TOPLEFT, at, at, len, thick)          Bar(TOPLEFT, at, at, thick, len)
    Bar(TOPRIGHT, -at, at, len, thick)        Bar(TOPRIGHT, -at, at, thick, len)
    Bar(BOTTOMLEFT, at, -at, len, thick)      Bar(BOTTOMLEFT, at, -at, thick, len)
    Bar(BOTTOMRIGHT, -at, -at, len, thick)    Bar(BOTTOMRIGHT, -at, -at, thick, len)
end

-- Turns a label into a small glass button (like the window's edge): faint fill, light
-- top / left edge, dark right / bottom edge; bronze tint under the mouse. The frame is on
-- the background layer, under the label's own text. Adds:
--   link:PaintGlass(hovered[, textHex, alpha])  -- colors (textHex defaults to the one given here)
--   link:FitGlass()                             -- width hugs the text (+24)
local function AddGlass(link, textHex)
    local name = link:GetName()
    local function Part(suffix, r, g, b, a)
        local t = WINDOW_MANAGER:CreateControl(name .. suffix, link, CT_TEXTURE)
        t:SetColor(r, g, b, a)
        t:SetDrawLayer(DL_BACKGROUND)
        t:SetMouseEnabled(false)
        return t
    end
    local fill = Part("GlassFill", 1, 1, 1, 0.035)
    fill:SetAnchorFill(link)
    local function Edge(suffix, a1, a2, horizontal, r, g, b, a)
        local t = Part(suffix, r, g, b, a)
        t:SetAnchor(a1, link, a1, 0, 0)
        t:SetAnchor(a2, link, a2, 0, 0)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    end
    Edge("GlassTop", TOPLEFT, TOPRIGHT, true, 1, 1, 1, 0.3)
    Edge("GlassLeft", TOPLEFT, BOTTOMLEFT, false, 1, 1, 1, 0.14)
    Edge("GlassRight", TOPRIGHT, BOTTOMRIGHT, false, 0, 0, 0, 0.9)
    Edge("GlassBottom", BOTTOMLEFT, BOTTOMRIGHT, true, 0, 0, 0, 0.9)
    function link:PaintGlass(hovered, hex, alpha)
        if hovered then
            local r, g, b = HexToRGB(COLOR.theme)
            fill:SetColor(r, g, b, 0.18)
            SetHexColor(self, COLOR.selected)
        else
            fill:SetColor(1, 1, 1, 0.035)
            SetHexColor(self, hex or textHex, alpha)
        end
    end
    -- same text as last time: the size is already right (re-guessing it on every
    -- refresh made the button jump for a frame)
    function link:FitGlass()
        local text = self:GetText() or ""
        if text == self.fittedText then return end
        self.fittedText = text
        self:SetWidth(#text * 6 + 24)
        zo_callLater(function() self:SetWidth(self:GetTextWidth() + 24) end, 1)
    end
end

local function MakeFadePanel(win, prefix, fadeW, fadeH)
    -- 0.95: a hint of the world shows through, text stays easy to read
    local FADE_W, FADE_H, ALPHA = fadeW or 0, fadeH or 0, 0.95
    if FADE_W == 0 and FADE_H == 0 then
        -- solid black, inside the bronze frame
        local solid = WINDOW_MANAGER:CreateControl(prefix .. "BG", win, CT_TEXTURE)
        solid:SetColor(0, 0, 0, ALPHA)
        solid:SetAnchorFill(win)
        solid:SetDrawLayer(DL_BACKGROUND)
        solid:SetMouseEnabled(false)
        MakeFrame(win, prefix)
        return
    end
    -- thin see-through theme line around the whole panel
    local border = WINDOW_MANAGER:CreateControl(prefix .. "Border", win, CT_BACKDROP)
    border:SetAnchorFill(win)
    border:SetCenterColor(0, 0, 0, 0)
    border:SetEdgeTexture("", 1, 1, 1)
    local br, bg, bb = HexToRGB(COLOR.theme)
    border:SetEdgeColor(br, bg, bb, BORDER_ALPHA)
    border:SetMouseEnabled(false)
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
-- engraved: the main window's lines. A thin, faint line with an even fainter twin
-- 3 px under it (like an engraving), so the active tab's bright underline is the one
-- accent on top. Plain (default): one 2 px line at full strength.
local ENGRAVED_LINES = { { y = 0, h = 1, a = 0.55 }, { y = 3, h = 1, a = 0.22 } }
local PLAIN_LINES = { { y = 0, h = 2, a = 1 } }
local function MakeDivider(name, parent, width, engraved)
    local lines = engraved and ENGRAVED_LINES or PLAIN_LINES
    local divider = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    divider:SetDimensions(width, engraved and 4 or 2)
    local r, g, b = HexToRGB(COLOR.theme)
    local function Seg(suffix, alpha, h)
        local t = WINDOW_MANAGER:CreateControl(name .. suffix, divider, CT_TEXTURE)
        t:SetColor(r, g, b, alpha)
        t:SetHeight(h)
        t:SetMouseEnabled(false)
        return t
    end
    local parts = {}
    for n, line in ipairs(lines) do
        local p = { y = line.y, lefts = {}, rights = {} }
        for i = 1, FADE_STEPS do
            local a = (i / FADE_STEPS) ^ 1.6   -- eased so the tips really vanish
            p.lefts[i] = Seg(n .. "L" .. i, a * line.a, line.h)
            p.rights[i] = Seg(n .. "R" .. i, a * line.a, line.h)
        end
        p.mid = Seg(n .. "M", line.a, line.h)
        parts[n] = p
    end

    function divider:SetDividerWidth(w)
        self:SetWidth(w)
        local fadeW = w * FADE_PART
        local step = fadeW / FADE_STEPS
        for _, p in ipairs(parts) do
            for i = 1, FADE_STEPS do
                local off = (i - 1) * step
                p.lefts[i]:ClearAnchors()
                p.lefts[i]:SetAnchor(TOPLEFT, self, TOPLEFT, off, p.y)
                p.lefts[i]:SetWidth(step)
                p.rights[i]:ClearAnchors()
                p.rights[i]:SetAnchor(TOPRIGHT, self, TOPRIGHT, -off, p.y)
                p.rights[i]:SetWidth(step)
            end
            p.mid:ClearAnchors()
            p.mid:SetAnchor(TOPLEFT, self, TOPLEFT, fadeW, p.y)
            p.mid:SetAnchor(TOPRIGHT, self, TOPRIGHT, -fadeW, p.y)
        end
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
    -- a soft bronze pill with bold bronze text, like the column titles, so the facts
    -- at the top of a page stand out from the grey text (colored badges keep their color)
    local BADGE_ALPHA, BADGE_ALPHA_HOVER = 0.16, 0.26
    local bg = MakeRoundedBackground(name .. "BG", badge, 22)
    bg:SetColor(HexToRGB(COLOR.theme))
    bg:SetAlpha(BADGE_ALPHA)
    local label = MakeLabel(name .. "Text", badge, "$(BOLD_FONT)|13|soft-shadow-thin", 200, 22, COLOR.header)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetAnchor(CENTER, badge, CENTER, 0, 0)
    local function Fit()
        local width = label:GetTextWidth() + 12
        label:SetWidth(width)
        badge:SetWidth(width + 14)
    end
    -- Optional tooltip: a function that fills InformationTooltip (nil = none), or a
    -- panel { show = function(badge), hide = function() } of our own (lined-up columns)
    badge:SetHandler("OnMouseEnter", function(self)
        if not self.tooltipFn and not self.panel then return end
        bg:SetAlpha(BADGE_ALPHA_HOVER)
        if self.panel then
            self.panel.show(self)
            return
        end
        InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -6, TOPLEFT)
        self.tooltipFn(InformationTooltip)
    end)
    badge:SetHandler("OnMouseExit", function(self)
        bg:SetAlpha(BADGE_ALPHA)
        if self.panel then self.panel.hide() end
        ClearTooltip(InformationTooltip)
    end)
    function badge:SetBadgeTooltip(fn, panel)
        self.tooltipFn, self.panel = fn, panel
        self:SetMouseEnabled(fn ~= nil or panel ~= nil)
    end
    function badge:SetBadgeText(text)
        -- unchanged text keeps its size (re-estimating it on every refresh made the
        -- badges and everything after them jump for a frame)
        if text == self.badgeText then return end
        self.badgeText = text
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
    -- animate: grow from empty to the value (0.6 s, soft ease-out), for a page you arrive on
    function bar:SetProgress(fraction, complete, animate)
        fraction = zo_max(0, zo_min(1, fraction))
        SetHexColor(fill, complete and COLOR.good or COLOR.theme)
        if not animate then
            self:SetHandler("OnUpdate", nil)
            fill:SetWidth(fraction * self:GetWidth())
            return
        end
        local start = GetFrameTimeSeconds()
        fill:SetWidth(0)
        self:SetHandler("OnUpdate", function(me)
            local t = zo_min((GetFrameTimeSeconds() - start) / 0.6, 1)
            fill:SetWidth(fraction * (1 - (1 - t) ^ 5) * me:GetWidth())
            if t >= 1 then me:SetHandler("OnUpdate", nil) end
        end)
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
        facts = not special,   -- monster helm lines / notes stay on the page; explanations go to the (i)
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
        place = spot.name,   -- travel goes to the wayshrine closest to the spot, not just the zone
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
-- one daily reward as a row
local function DailyRow(reward)
    local info = reward.open and Colorize(COLOR.good, L("DAILY_OPEN")) or Colorize(COLOR.dim, L("DAILY_DONE"))
    if reward.open and reward.xp > 0 then
        info = info .. Colorize(COLOR.dim, "  ·  ") .. Colorize(COLOR.selected, L("DAILY_XP", ZO_CommaDelimitNumber(reward.xp)))
    end
    return {
        kind = "info", name = reward.name, info = info,
        nameColor = reward.open and COLOR.selected or nil,
        sourceAction = reward.action,   -- row icon: queue random dungeon / open Battlegrounds
        tooltip = { L(reward.open and "DAILY_TT_OPEN" or "DAILY_TT_DONE") },
    }
end

local function DailyView(scrollData)
    local open = 0
    for _, reward in ipairs(S.DailyRewards()) do
        if reward.open then open = open + 1 end
        AddRow(scrollData, ROW_INFO, DailyRow(reward))
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

-- bound, already collected (so it can be reconstructed), not worn, not a wanted trait,
-- and not used by a Skillbound build (same item + trait; Skillbound is optional)
local function SafeToDecon(entry, piece)
    return piece.collected == true and entry.bound and entry.whereKind ~= "worn"
        and not S.IsWantedTrait(entry.setId, piece.traitType)
        and not (Skillbound and Skillbound.UsesItemLink and Skillbound.UsesItemLink(entry.link))
        and not S.FCO.IsLocked(entry)   -- locked in FCO ItemSaver
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
        return q, GetItemQualityColor(q):Colorize(S.QualityName(q)), string.format("%02d", 99 - q)
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
local SCOPE_ICON_ALL = "EsoUI/Art/MainMenu/menuBar_group_up.dds"
local SCOPE_ICON_HOUSE = "EsoUI/Art/TreeIcons/collection_indexicon_furnishings_up.dds"   -- as Inventory Insight uses
local function ClassIcon(classId)
    local icon = classId and GetClassIcon and GetClassIcon(classId)
    return (icon and icon ~= "") and icon or "EsoUI/Art/MainMenu/menuBar_character_up.dds"
end

-- kind: "all" / "char" / "store"; icon for the picker rows and its button
local function ScopeChoices()
    local list = { { text = L("SCOPE_ALL"), kind = "all", icon = SCOPE_ICON_ALL } }   -- value nil = all
    for _, char in ipairs(S.GetCharacterScanList()) do
        list[#list + 1] = {
            value = char.id, name = char.name, scanned = char.scanned, kind = "char", me = char.me,
            text = char.scanned and char.name or L("SCOPE_NOT_SCANNED", char.name),
            icon = ClassIcon(char.classId),
        }
    end
    list[#list + 1] = { value = "bank", text = L("SCOPE_BANK"), kind = "store", icon = TEX_BANK }
    list[#list + 1] = { value = "house", text = L("SCOPE_HOUSE"), kind = "store", icon = SCOPE_ICON_HOUSE }
    return list
end

-- set pieces per choice: [character id] / bank / house / all
local function ScopeCounts()
    local counts = { all = 0, bank = 0, house = 0 }
    for _, entries in pairs(S.GetOwnedIndex()) do
        for _, entry in ipairs(entries) do
            local n = entry.count or 1
            counts.all = counts.all + n
            local key = (entry.whereKind == "bank" or entry.whereKind == "house") and entry.whereKind or entry.ownerId
            if key then counts[key] = (counts[key] or 0) + n end
        end
    end
    return counts
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
-- Hover panel for "Bags of 9 of 9 characters": the answer on top ("All 9 characters
-- are in the list", oldest one under it), then one line per character (class icon,
-- name, when its bags were read, lined up on the right), a short note at the bottom.
local CP_W, CP_PAD, CP_ROW_H = 300, 10, 24
local charsPanel = { rows = {} }

local function CreateCharsPanel()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_CharsPanel")
    win:SetDrawTier(DT_HIGH)
    win:SetHidden(true)
    win:SetWidth(CP_W)
    local bg = WINDOW_MANAGER:CreateControl("SetHunter_CharsPanelBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0, 0, 0, 0.95)
    bg:SetEdgeColor(HexToRGB(COLOR.theme))
    bg:SetEdgeTexture("", 1, 1, 1)
    local w = CP_W - CP_PAD * 2
    local sum = MakeLabel("SetHunter_CharsSum", win, "ZoFontGameBold", w, 24)
    sum:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    sum:SetAnchor(TOPLEFT, win, TOPLEFT, CP_PAD, CP_PAD - 2)
    local oldest = MakeLabel("SetHunter_CharsOldest", win, "ZoFontGameSmall", w, 18, COLOR.dim)
    oldest:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    oldest:SetAnchor(TOPLEFT, sum, BOTTOMLEFT, 0, 0)
    local tr, tg, tb = HexToRGB(COLOR.theme)
    local function Rule(name)
        local r = WINDOW_MANAGER:CreateControl(name, win, CT_TEXTURE)
        r:SetDimensions(w, 1)
        r:SetColor(tr, tg, tb, 0.35)
        return r
    end
    local rule1, rule2 = Rule("SetHunter_CharsRule1"), Rule("SetHunter_CharsRule2")
    local note = WINDOW_MANAGER:CreateControl("SetHunter_CharsNote", win, CT_LABEL)
    note:SetFont("ZoFontGameSmall")
    note:SetWidth(w)
    SetHexColor(note, COLOR.dim)
    note:SetText(L("CHARS_PANEL_NOTE"))
    charsPanel.win, charsPanel.sum, charsPanel.oldest = win, sum, oldest
    charsPanel.rule1, charsPanel.rule2, charsPanel.note = rule1, rule2, note
end

local function CharsRow(i)
    local r = charsPanel.rows[i]
    if r then return r end
    local win = charsPanel.win
    r = WINDOW_MANAGER:CreateControl("SetHunter_CharsRow" .. i, win, CT_CONTROL)
    r:SetDimensions(CP_W - CP_PAD * 2, CP_ROW_H)
    r.icon = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.icon:SetDimensions(20, 20)
    r.icon:SetAnchor(LEFT, r, LEFT, 0, 0)
    r.time = MakeLabel(nil, r, "ZoFontGameSmall", 100, CP_ROW_H, COLOR.dim)
    r.time:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    r.time:SetAnchor(RIGHT, r, RIGHT, 0, 0)
    r.name = MakeLabel(nil, r, "ZoFontGame", CP_W - CP_PAD * 2 - 20 - 8 - 104, CP_ROW_H)
    r.name:SetMaxLineCount(1)
    r.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    r.name:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
    charsPanel.rows[i] = r
    return r
end

local function CharsPanel(list, scanned, total)
    local function Show(anchor)
        if not charsPanel.win then CreateCharsPanel() end
        local win = charsPanel.win
        local all = total > 0 and scanned == total
        charsPanel.sum:SetText(all and L("CHARS_SUM_ALL", total) or L("CHARS_SUM_SOME", scanned, total))
        SetHexColor(charsPanel.sum, all and COLOR.good or COLOR.warn)
        local oldest
        for _, char in ipairs(list) do
            if char.scanned and char.t and (not oldest or char.t < oldest.t) then oldest = char end
        end
        charsPanel.oldest:SetText(oldest and L("CHARS_OLDEST", oldest.name, S.FormatAgo(oldest.t)) or "")
        local y = CP_PAD - 2 + 24 + 18 + 6
        charsPanel.rule1:ClearAnchors()
        charsPanel.rule1:SetAnchor(TOPLEFT, win, TOPLEFT, CP_PAD, y)
        y = y + 6
        for i, char in ipairs(list) do
            local r = CharsRow(i)
            r.icon:SetTexture(ClassIcon(char.classId))
            r.icon:SetAlpha(char.scanned and 1 or 0.45)
            r.name:SetText(char.name)
            SetHexColor(r.name, char.scanned and COLOR.normal or COLOR.dim)
            r.time:SetText(char.scanned and S.FormatAgo(char.t) or L("CHARS_LOG_IN"))
            r:ClearAnchors()
            r:SetAnchor(TOPLEFT, win, TOPLEFT, CP_PAD, y)
            r:SetHidden(false)
            y = y + CP_ROW_H
        end
        for i = #list + 1, #charsPanel.rows do charsPanel.rows[i]:SetHidden(true) end
        y = y + 6
        charsPanel.rule2:ClearAnchors()
        charsPanel.rule2:SetAnchor(TOPLEFT, win, TOPLEFT, CP_PAD, y)
        y = y + 6
        charsPanel.note:ClearAnchors()
        charsPanel.note:SetAnchor(TOPLEFT, win, TOPLEFT, CP_PAD, y)
        win:SetHeight(y + charsPanel.note:GetTextHeight() + CP_PAD)
        DropIn(win, TOPLEFT, anchor, BOTTOMLEFT, 0, 6)
    end
    local function Hide()
        if charsPanel.win then charsPanel.win:SetHidden(true) end
    end
    return { show = Show, hide = Hide }
end

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
    return { text = text, panel = CharsPanel(list, scanned, total) }
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

-- A wish is done when you have it all: every piece of a whole set, or every piece you
-- picked. Sets without a Set Collection can't be tracked, so they never count as done.
local function IsWishDone(data)
    if S.HasWishPieces(data.setId) then
        local any = false
        for _, piece in ipairs(S.SetPieces(data.setId)) do
            if S.IsWantedPiece(data.setId, piece.key) then
                if not piece.unlocked then return false end
                any = true
            end
        end
        return any
    end
    return (data.total or 0) > 0 and data.complete == true
end

-- wishlist sets split in two: with picked pieces (true) or the whole set (false);
-- done ones are left out (they're under Completed)
local function PieceWishSets(withPieces)
    local list = {}
    for _, data in ipairs(S.GetWishlistSets()) do
        if S.HasWishPieces(data.setId) == withPieces and not IsWishDone(data) then list[#list + 1] = data end
    end
    return list
end

local function DoneWishSets()
    local list = {}
    for _, data in ipairs(S.GetWishlistSets()) do
        if IsWishDone(data) then list[#list + 1] = data end
    end
    return list
end

-- Wishlist > By place: every place your open wishes drop in, the place with the most
-- first. A place row (icon, name, how many) has the travel / queue shortcut; its
-- sets follow. A set that drops in several places is under each of them.
local KIND_ICON = {}
for _, cat in ipairs(CATEGORIES) do
    if cat.kind then KIND_ICON[cat.kind] = cat.icon end
end
local function WishPlacesView(scrollData)
    local places, order = {}, {}
    local open = 0
    for _, data in ipairs(S.GetWishlistSets()) do
        if not IsWishDone(data) then
            open = open + 1
            for _, id in ipairs(data.sourceIds or {}) do
                local loc = S.GetLocation(id)
                if loc then
                    if not places[id] then
                        places[id] = { loc = loc, sets = {} }
                        order[#order + 1] = id
                    end
                    table.insert(places[id].sets, data)
                end
            end
        end
    end
    table.sort(order, function(a, b)
        local na, nb = #places[a].sets, #places[b].sets
        if na ~= nb then return na > nb end
        return places[a].loc.name < places[b].loc.name
    end)
    for _, id in ipairs(order) do
        local place = places[id]
        local icon = KIND_ICON[place.loc.kind]
        AddRow(scrollData, ROW_INFO, {
            kind = "info",
            name = (icon and (zo_iconFormat(icon, 22, 22) .. " ") or "") .. place.loc.name,
            nameColor = COLOR.header,
            info = L(#place.sets == 1 and "WISH_PLACE_ONE" or "WISH_PLACE_MANY", #place.sets),
            zoneId = id > 0 and id or nil,
            tooltip = { place.loc.name, L("WISH_PLACE_TT") },
        })
        for _, data in ipairs(place.sets) do
            data.showWhere = false
            AddRow(scrollData, ROW_SET, data)
        end
    end
    return {
        crumb = Crumb(Sec("TREE_SETS"), CatPart("CAT_WISHLIST")),
        title = L("CAT_WISH_PLACES"),
        badges = { Count("BADGE_PLACE", "BADGE_PLACES", #order), Count("BADGE_SET", "BADGE_SETS", open) },
        info = Colorize(COLOR.dim, L("WISH_PLACES_INFO")),
        columns = "sets",
        count = #order,
        empty = S.LIS() and L("EMPTY_WISH_PLACES") or L("NO_LIB"),
    }
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
    local here
    for _, cat in ipairs(CATEGORIES) do
        if cat.view == S.sv.view then return cat end
        if cat.view == "here" then here = cat end
    end
    return here
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
            facts = true,
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
    elseif view == "wishlist" and S.sv.loc == "places" then
        return WishPlacesView(scrollData)
    elseif view == "wishlist" and S.sv.loc == "done" then
        -- Wishlist > Completed: everything you wanted from these sets is collected
        local sets = DoneWishSets()
        return {
            crumb = Crumb(Sec("TREE_SETS"), CatPart("CAT_WISHLIST")),
            title = L("CAT_WISH_DONE"),
            badges = { Count("BADGE_SET", "BADGE_SETS", #sets) },
            info = Colorize(COLOR.dim, L("WISH_DONE_INFO", zo_iconFormat(TEX_STAR, 16, 16))),
            columns = "where",
            count = AddWishlist(scrollData, sets),
            empty = L("EMPTY_WISH_DONE"),
        }
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
        -- everything still open: whole sets first, then the sets with picked pieces
        -- (done ones are under Completed)
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
            and (S.CanQueue(zoneId) or S.FindTravelNode(zoneId, nil, true) ~= nil)
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
-- add(icon, text, fn): puts the entry into the right-click menu
local function AddTravelOrQueue(zoneId, data, add)
    if not zoneId then return end
    if S.CanQueue(zoneId) then
        add(TEX_QUEUE, L("MENU_QUEUE"), function() S.OpenQueueDialog(zoneId, SetDataFor(data)) end)
    else
        add("EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds", L("BTN_TRAVEL"),
            function() S.TravelTo(zoneId, data and data.place) end)
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
    -- the game's soft map ping when added, its reverse when taken off (picked by ear;
    -- the "positive" click was too much)
    local sound = S.sv.wishlist[data.setId] and SOUNDS.MAP_PING or SOUNDS.MAP_PING_REMOVE
    PlaySound(sound or SOUNDS.DEFAULT_CLICK)
    -- the star on that set's row pops on the refresh below (SetupSetRow)
    ui.starPop = { setId = data.setId, start = GetFrameTimeSeconds() }
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
        local place = ui.selected and ui.selected.zoneId == zoneId and ui.selected.place or nil
        S.TravelTo(zoneId, place)
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

-- "all collected here" mark in the tree's count spot (white texture, takes the count's green)
local TREE_CHECK = "|t16:16:SetHunter/Textures/check.dds:inheritcolor|t"
local TREE_DIM = "7A766A"   -- places you have nothing from yet

local function PaintCategory(control, hovered)
    local data = control.data
    local selected = data and IsCategorySelected(data)
    -- while the highlight glides over from the old entry, the new one waits for it
    local lit = selected and not ui.treeGliding
    control:GetNamedChild("SelBG"):SetHidden(not lit)
    control:GetNamedChild("SelBar"):SetHidden(not lit)
    SetHexColor(control:GetNamedChild("Text"), (selected or hovered) and COLOR.selected
        or (data and data.dim and TREE_DIM) or COLOR.normal)
    local icon = control:GetNamedChild("Icon")
    if icon then icon:SetAlpha((selected or hovered) and 1 or 0.75) end
end

-- tree animation: the arrow's quarter turn (texture rotation is counter-clockwise, so
-- a negative angle turns ">" down) and the fade-in of the entries under it
local TREE_ARROW_OPEN, TREE_ARROW_T, TREE_SUB_T, TREE_SUB_GAP = -math.pi / 2, 0.2, 0.18, 0.04

local function SetupCategory(control, data)
    control.data = data
    control:GetNamedChild("Text"):SetText(data.text or L(data.key))
    local count = control:GetNamedChild("Count")
    count:SetText(data.count or "")
    SetHexColor(count, data.countColor or COLOR.dim)

    -- Opening / closing a category: its arrow turns (one arrow, rotated a quarter turn
    -- when open) and the entries under it fade in one after another. ui.treeAnim is
    -- set by the click (Category_OnMouseUp) and only animates the refresh it caused.
    local anim = ui.treeAnim
    local arrow = control:GetNamedChild("Arrow")
    if arrow then
        arrow:SetHidden(not (data.kind or data.expand))
        arrow:SetTexture(ARROW_CLOSED)
        local target = S.sv.open[data.view] and TREE_ARROW_OPEN or 0
        if anim and not anim.committed and anim.view == data.view and not data.loc then
            local from = S.sv.open[data.view] and 0 or TREE_ARROW_OPEN
            arrow:SetHandler("OnUpdate", function(self)
                local t = zo_min((GetFrameTimeSeconds() - anim.start) / TREE_ARROW_T, 1)
                local e = 1 - (1 - t) ^ 3
                self:SetTextureRotation(from + (target - from) * e)
                if t >= 1 then self:SetHandler("OnUpdate", nil) end
            end)
        else
            arrow:SetHandler("OnUpdate", nil)
            arrow:SetTextureRotation(target)
        end
    end
    -- rows get reused: no leftover fade
    control:SetHandler("OnUpdate", nil)
    control:SetAlpha(1)
    if data.loc and anim and anim.opened and not anim.committed and anim.view == data.view then
        anim.n = (anim.n or 0) + 1
        local delay = (anim.n - 1) * TREE_SUB_GAP
        control:SetAlpha(0)
        control:SetHandler("OnUpdate", function(self)
            local t = zo_clamp((GetFrameTimeSeconds() - anim.start - delay) / TREE_SUB_T, 0, 1)
            self:SetAlpha(1 - (1 - t) ^ 3)
            if t >= 1 then self:SetHandler("OnUpdate", nil) end
        end)
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

-- tab icons (white, tinted in PaintTabs): helmet, backpack, rising arrow
local TAB_ICONS = {
    -- Sets: the same helmet as the Set Hunter emblem (the game's own icon: it has
    -- mipmaps, so it stays crisp at 20 px; our drawn shield looked grainy)
    TREE_SETS = TEX_ICON,
    TREE_ITEMS = "SetHunter/Textures/tab_items.dds",
    TREE_XP = "SetHunter/Textures/tab_xp.dds",
}
local TAB_ICON_SIZE, TAB_ICON_GAP = 20, 6
-- the game's sturdy bold header font (tried Trajan: too thin; a same-color outline to
-- make it bolder: far too thick; a colored shadow: looked like doubled letters)
local TAB_FONT = "ZoFontWinH4"
local TAB_GAP = 30   -- between one tab's name and the next tab's icon (a diamond sits in the middle)
-- the game's helmet has empty space round it, so it's drawn bigger to look the same size
local TAB_ICON_SIZES = { TREE_SETS = 27 }
local function TabIconSize(key) return TAB_ICON_SIZES[key] or TAB_ICON_SIZE end

-- Tab switch: one bronze underline that glides to the new tab, and the page on the
-- right slides in from the side of the tab you went to (and fades in).
local GLIDE_T, SLIDE_T, SLIDE_PX = 0.22, 0.22, 24
local function EaseOut(t) return 1 - (1 - t) ^ 3 end

-- Dropdowns and pop-up panels unfold: the panel grows down from its top edge (0.26 s,
-- ease-out) and each row fades in as the edge passes it, so they appear one after
-- another. (The game can't clip a panel's children, so rows are hidden by their alpha
-- until the edge reaches them.) Panels placed by their center just soft-drop in.
-- Anchors the panel itself (same arguments as SetAnchor).
local UNFOLD_T, DROP_T, DROP_PX = 0.26, 0.2, 10
local UNFOLDS = { [TOPLEFT] = true, [TOP] = true, [TOPRIGHT] = true }
local function SetChildrenAlpha(win, alphaOf)
    for i = 1, win:GetNumChildren() do
        local c = win:GetChild(i)
        if c then c:SetAlpha(alphaOf(c)) end
    end
end
DropIn = function(win, point, rel, relPoint, x, y)
    local start = GetFrameTimeSeconds()
    win:ClearAnchors()
    win:SetAnchor(point, rel, relPoint, x, y)
    win:SetAlpha(1)
    win:SetHidden(false)
    win.fading = false
    if not UNFOLDS[point] or win.noUnfold then
        win:SetHandler("OnUpdate", function(self)
            local e = EaseOut(zo_min((GetFrameTimeSeconds() - start) / DROP_T, 1))
            self:ClearAnchors()
            self:SetAnchor(point, rel, relPoint, x, y - DROP_PX * (1 - e))
            self:SetAlpha(e)
            if e >= 1 then self:SetHandler("OnUpdate", nil) end
        end)
        return
    end
    -- the full height is whatever the panel's own layout set (it may lay out again a
    -- frame later: then that height is the new goal)
    local target, lastSet = (win.unfolding and win.fullHeight) or win:GetHeight(), nil
    -- each row's own alpha (some are dimmed on purpose): the fade-in goes up to that
    -- (read fresh each opening, unless one is still running: then its alphas are mid-fade)
    if not win.unfolding or not win.baseAlpha then
        win.baseAlpha = {}
        for i = 1, win:GetNumChildren() do
            local c = win:GetChild(i)
            if c then win.baseAlpha[c] = c:GetAlpha() end
        end
    end
    win.unfolding = true
    local base = win.baseAlpha
    local function Base(c) return base[c] or 1 end
    win:SetHandler("OnUpdate", function(self)
        local h = self:GetHeight()
        if lastSet ~= nil and math.abs(h - lastSet) > 0.5 then target = h end
        self.fullHeight = target
        local t = zo_min((GetFrameTimeSeconds() - start) / UNFOLD_T, 1)
        local cur = zo_max(target * EaseOut(t), 1)
        self:SetHeight(cur)
        lastSet = cur
        local top = self:GetTop()
        SetChildrenAlpha(self, function(c)
            local ch = c:GetHeight()
            if ch >= cur * 0.9 then return Base(c) end   -- the background (fills the panel)
            return Base(c) * zo_clamp((top + cur - c:GetTop()) / zo_max(ch, 8), 0, 1)
        end)
        if t >= 1 then
            self:SetHeight(target)
            SetChildrenAlpha(self, Base)
            self.unfolding = false
            self:SetHandler("OnUpdate", nil)
        end
    end)
end

-- A dropdown's arrow: points down, turns half round to point up while its list is open.
-- (">" turned -90 degrees points down, +90 up.)
local ARROW_TURN_T = 0.25
local function TurnArrow(arrow, up)
    if not arrow then return end
    local from = arrow.angle or (-math.pi / 2)
    local to = up and (math.pi / 2) or (-math.pi / 2)
    local start = GetFrameTimeSeconds()
    arrow:SetHandler("OnUpdate", function(self)
        local t = zo_min((GetFrameTimeSeconds() - start) / ARROW_TURN_T, 1)
        self.angle = from + (to - from) * EaseOut(t)
        self:SetTextureRotation(self.angle)
        if t >= 1 then self:SetHandler("OnUpdate", nil) end
    end)
end

-- Closing: a quick fade (0.12 s), then hidden. Opening again meanwhile simply wins.
local FOLD_T = 0.12
local function FadeAway(win)
    if not win or win:IsHidden() then return end
    local start = GetFrameTimeSeconds()
    -- closed mid-unfold: finish the rows and the height first, then fade
    if win.unfolding then
        local base = win.baseAlpha or {}
        SetChildrenAlpha(win, function(c) return base[c] or c:GetAlpha() end)
        if win.fullHeight then win:SetHeight(win.fullHeight) end
        win.unfolding = false
    end
    win.fading = true
    win:SetHandler("OnUpdate", function(self)
        local t = zo_min((GetFrameTimeSeconds() - start) / FOLD_T, 1)
        self:SetAlpha(1 - t)
        if t >= 1 then
            self:SetHandler("OnUpdate", nil)
            self:SetHidden(true)
            self:SetAlpha(1)
            self.fading = false
        end
    end)
end

-- where the underline goes for a tab: x from the window's right edge (the tabs are
-- right-aligned, so this stays right while resizing) and its width (icon + name)
local function TabLineTarget(tab)
    return tab.icon:GetLeft() - ui.win:GetRight(), tab:GetTextWidth() + tab.icon:GetWidth() + tab.iconGap
end

local function SetTabLine(x, w)
    local line = ui.tabLine
    line.x, line.w = x, w
    line:ClearAnchors()
    line:SetAnchor(TOPLEFT, ui.win, TOPRIGHT, x, 51)   -- 3 px, resting right on the divider (y 54)
    line:SetWidth(w)
end

local function PaintTabs()
    if not ui.tabs then return end
    local current = CurrentTab()
    for key, tab in pairs(ui.tabs) do
        local on = key == current
        -- active: warm cream letters (over the bronze underline); under the mouse: white;
        -- otherwise grey
        SetHexColor(tab, on and COLOR.header or (tab.hovered and COLOR.selected or COLOR.dim))
        -- icon: bronze on the active tab, white under the mouse, grey otherwise
        SetHexColor(tab.icon, on and COLOR.theme or (tab.hovered and COLOR.selected or COLOR.dim))
        tab.line:SetHidden(true)   -- the shared ui.tabLine is drawn instead
    end
    local line, tab = ui.tabLine, ui.tabs[current]
    if not line or not tab or ui.win:GetRight() == 0 then return end
    local x, w = TabLineTarget(tab)
    if line.animating then
        line.toX, line.toW = x, w
    elseif line.key ~= nil and line.key ~= current and not ui.win:IsHidden() then
        -- glide from where it is now
        line.fromX, line.fromW, line.toX, line.toW = line.x, line.w, x, w
        line.start, line.animating = GetFrameTimeSeconds(), true
        line:SetHandler("OnUpdate", function(self)
            local t = zo_min((GetFrameTimeSeconds() - self.start) / GLIDE_T, 1)
            local e = EaseOut(t)
            SetTabLine(self.fromX + (self.toX - self.fromX) * e, self.fromW + (self.toW - self.fromW) * e)
            if t >= 1 then
                self.animating = false
                self:SetHandler("OnUpdate", nil)
            end
        end)
    else
        SetTabLine(x, w)
    end
    line.key = current
end

-- dir: 1 = came from a tab on the left (slides in from the right), -1 = the other way,
-- 0 = no sideways move; rise: px it comes up from (a new category in the tree: 8)
local function SlideContent(dir, rise)
    local driver = ui.slideDriver
    if not driver then return end
    local parts = { ui.header, ui.infoIcon, ui.progressRow, ui.columns, ui.list, ui.empty }
    local start = GetFrameTimeSeconds()
    local function Place(e)
        ui.header:ClearAnchors()
        ui.header:SetAnchor(TOPLEFT, ui.searchBox, TOPRIGHT, 20 + dir * SLIDE_PX * (1 - e), 24 + (rise or 0) * (1 - e))
        for _, part in ipairs(parts) do part:SetAlpha(e) end
    end
    Place(0)
    driver:SetHandler("OnUpdate", function(self)
        local t = zo_min((GetFrameTimeSeconds() - start) / SLIDE_T, 1)
        Place(EaseOut(t))
        if t >= 1 then self:SetHandler("OnUpdate", nil) end
    end)
end

local function TabIndex(key)
    for i, k in ipairs(TABS) do if k == key then return i end end
    return 0
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
    SlideContent(TabIndex(key) > TabIndex(current) and 1 or -1)
end

-- My items dropdown: All characters / one character / Bank / House storage
local function SetScope(value)
    if S.sv.itemsScope == value then return end
    S.sv.itemsScope = value
    ui.selected = nil
    ZO_ScrollList_ResetToTop(ui.list)
    S.RefreshAll()
end

-- ---------------------------------------------------------------------------
-- Whose items: a bronze button (icon, name, piece count, arrow) that opens our own
-- picker panel: All characters, then CHARACTERS (class icon, name, pieces; not read
-- yet = grey), then STORAGE (bank, house). A search box shows with many characters.
-- ---------------------------------------------------------------------------
local SP_W, SP_ROW_H, SP_CAP_H, SP_PAD, SP_SEARCH_FROM = 290, 26, 22, 8, 9
local scopePicker = { rows = {}, caps = {} }

local function PaintScopeButton(hovered)
    local b = ui.scopeBox
    if not b then return end
    local r, g, bl = HexToRGB(COLOR.theme)
    b.bg:SetEdgeColor(r, g, bl, (hovered or b.open) and 1 or 0.55)
    SetHexColor(b.label, hovered and COLOR.selected or COLOR.header)
end

-- the button shows the current choice (the picked character was deleted: back to All)
local function FillScope()
    local b = ui.scopeBox
    if not b then return end
    local choices = ScopeChoices()
    local current = choices[1]
    for _, choice in ipairs(choices) do
        if choice.value ~= nil and choice.value == S.sv.itemsScope then current = choice end
    end
    if current == choices[1] then S.sv.itemsScope = nil end
    local counts = ScopeCounts()
    b.icon:SetTexture(current.icon)
    b.label:SetText(current.name or current.text)
    b.count:SetText(tostring(counts[current.value or "all"] or 0))
    PaintScopeButton(false)
end

local function CloseScopePicker()
    local win = scopePicker.win
    if not win or win:IsHidden() then return end
    FadeAway(win)
    scopePicker.edit:LoseFocus()
    EVENT_MANAGER:UnregisterForEvent("SetHunter_ScopePicker", EVENT_GLOBAL_MOUSE_DOWN)
    if ui.scopeBox then
        ui.scopeBox.open = false
        PaintScopeButton(false)
        TurnArrow(ui.scopeBox.arrow, false)
    end
end
S.CloseScopePicker = CloseScopePicker

local function PaintScopeRow(r)
    local lit = r.hovered or r.on
    r.hl:SetHidden(not lit)
    -- a soft bronze wash (SetAlpha replaces the color's own alpha on textures)
    r.hl:SetAlpha(r.on and 0.2 or 0.1)
    r.bar:SetHidden(not r.on)
    SetHexColor(r.label, lit and COLOR.selected or (r.dim and COLOR.dim or COLOR.normal))
    r.icon:SetAlpha(r.dim and 0.45 or 1)
end

local function ScopeRow(i)
    local r = scopePicker.rows[i]
    if r then return r end
    local win = scopePicker.win
    r = WINDOW_MANAGER:CreateControl("SetHunter_ScopeRow" .. i, win, CT_CONTROL)
    r:SetDimensions(SP_W - 2, SP_ROW_H)
    r:SetMouseEnabled(true)
    local tr, tg, tb = HexToRGB(COLOR.theme)
    r.hl = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.hl:SetAnchorFill(r)
    r.hl:SetColor(tr, tg, tb, 0.2)
    r.bar = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.bar:SetDimensions(2, SP_ROW_H)
    r.bar:SetAnchor(LEFT, r, LEFT, 0, 0)
    r.bar:SetColor(tr, tg, tb, 1)
    r.icon = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.icon:SetDimensions(22, 22)
    r.icon:SetAnchor(LEFT, r, LEFT, SP_PAD + 4, 0)
    r.count = MakeLabel(nil, r, "ZoFontGameSmall", 70, SP_ROW_H, COLOR.dim)
    r.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    r.count:SetAnchor(RIGHT, r, RIGHT, -SP_PAD - 4, 0)
    r.label = MakeLabel(nil, r, "ZoFontGame", SP_W - 22 - 70 - SP_PAD * 2 - 22, SP_ROW_H)
    r.label:SetMaxLineCount(1)
    r.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    r.label:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
    r:SetHandler("OnMouseEnter", function(self) self.hovered = true; PaintScopeRow(self) end)
    r:SetHandler("OnMouseExit", function(self) self.hovered = false; PaintScopeRow(self) end)
    r:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local value = self.value
        PlaySound(SOUNDS.DEFAULT_CLICK)
        CloseScopePicker()
        SetScope(value)
        FillScope()
    end)
    scopePicker.rows[i] = r
    return r
end

local function ScopeCap(i)
    local c = scopePicker.caps[i]
    if not c then
        c = MakeLabel("SetHunter_ScopeCap" .. i, scopePicker.win, "$(BOLD_FONT)|12|soft-shadow-thin", SP_W - SP_PAD * 2, SP_CAP_H, COLOR.dim)
        scopePicker.caps[i] = c
    end
    return c
end

-- (re)draws the rows; the search box filters the characters by name
local function LayoutScopePicker()
    local win = scopePicker.win
    local choices = ScopeChoices()
    local counts = ScopeCounts()
    local nChars = 0
    for _, choice in ipairs(choices) do if choice.kind == "char" then nChars = nChars + 1 end end
    local withSearch = nChars >= SP_SEARCH_FROM
    scopePicker.searchBox:SetHidden(not withSearch)
    local filter = withSearch and zo_strlower(scopePicker.edit:GetText() or "") or ""

    local y = SP_PAD
    if withSearch then y = y + 30 + 6 end
    local nRow, nCap, lastKind = 0, 0, nil
    for _, choice in ipairs(choices) do
        local show = choice.kind ~= "char" or filter == "" or zo_strlower(choice.name or ""):find(filter, 1, true) ~= nil
        if show then
            -- a caption whenever a new group starts (not above "All characters")
            if choice.kind ~= lastKind and choice.kind ~= "all" then
                nCap = nCap + 1
                local c = ScopeCap(nCap)
                c:SetText(zo_strupper(L(choice.kind == "char" and "SCOPE_HDR_CHARS" or "SCOPE_HDR_STORAGE")))
                c:ClearAnchors()
                c:SetAnchor(TOPLEFT, win, TOPLEFT, SP_PAD + 4, y + 4)
                c:SetHidden(false)
                y = y + SP_CAP_H + 4
            end
            lastKind = choice.kind
            nRow = nRow + 1
            local r = ScopeRow(nRow)
            r.value = choice.value
            r.on = choice.value == S.sv.itemsScope
            r.dim = choice.kind == "char" and not choice.scanned
            r.hovered = false
            r.icon:SetTexture(choice.icon)
            r.label:SetText(choice.name or choice.text)
            r.count:SetText(r.dim and L("SCOPE_NOT_READ") or tostring(counts[choice.value or "all"] or 0))
            r:ClearAnchors()
            r:SetAnchor(TOPLEFT, win, TOPLEFT, 1, y)
            r:SetHidden(false)
            PaintScopeRow(r)
            y = y + SP_ROW_H
        end
    end
    for i = nCap + 1, #scopePicker.caps do scopePicker.caps[i]:SetHidden(true) end
    for i = nRow + 1, #scopePicker.rows do scopePicker.rows[i]:SetHidden(true) end
    win:SetHeight(y + SP_PAD)
end

local function CreateScopePicker()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_ScopePicker")
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetWidth(SP_W)
    local bg = WINDOW_MANAGER:CreateControl("SetHunter_ScopePickerBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.04, 0.035, 0.03, 0.97)
    bg:SetEdgeColor(HexToRGB(COLOR.theme))
    bg:SetEdgeTexture("", 1, 1, 1)
    scopePicker.win = win
    local box, edit = MakeEdit("SetHunter_ScopeSearch", win, SP_W - SP_PAD * 2, L("SCOPE_SEARCH"))
    box:SetAnchor(TOPLEFT, win, TOPLEFT, SP_PAD, SP_PAD)
    edit:SetHandler("OnTextChanged", LayoutScopePicker)
    edit:SetHandler("OnEscape", function(self) self:LoseFocus(); CloseScopePicker() end)
    scopePicker.searchBox, scopePicker.edit = box, edit
end

local function OpenScopePicker()
    if not scopePicker.win then CreateScopePicker() end
    local win, b = scopePicker.win, ui.scopeBox
    if not win:IsHidden() and not win.fading then
        CloseScopePicker()
        return
    end
    ClearTooltip(InformationTooltip)
    scopePicker.edit:SetText("")
    LayoutScopePicker()
    DropIn(win, TOPLEFT, b, BOTTOMLEFT, 0, 3)
    b.open = true
    PaintScopeButton(true)
    TurnArrow(b.arrow, true)   -- points up while the list is open
    if not scopePicker.searchBox:IsHidden() then scopePicker.edit:TakeFocus() end
    -- a click anywhere else closes it (the button itself toggles it)
    EVENT_MANAGER:RegisterForEvent("SetHunter_ScopePicker", EVENT_GLOBAL_MOUSE_DOWN, function()
        if not IsMouseOver(win, 0) and not IsMouseOver(b, 0) then CloseScopePicker() end
    end)
end

-- the button in the header (placed after the badges in LayoutRight)
local function CreateScopeButton(win)
    local b = WINDOW_MANAGER:CreateControl("SetHunter_Scope", win, CT_CONTROL)
    b:SetDimensions(230, 28)
    b:SetMouseEnabled(true)
    b:SetHidden(true)
    b.bg = WINDOW_MANAGER:CreateControl("SetHunter_ScopeBG", b, CT_BACKDROP)
    b.bg:SetAnchorFill(b)
    b.bg:SetCenterColor(0.07, 0.06, 0.045, 0.95)
    b.bg:SetEdgeTexture("", 1, 1, 1)
    b.icon = WINDOW_MANAGER:CreateControl("SetHunter_ScopeIcon", b, CT_TEXTURE)
    b.icon:SetDimensions(20, 20)
    b.icon:SetAnchor(LEFT, b, LEFT, 6, 0)
    b.arrow = WINDOW_MANAGER:CreateControl("SetHunter_ScopeArrow", b, CT_TEXTURE)
    b.arrow:SetDimensions(16, 16)
    -- pointing down (it's a dropdown): the ">" arrow turned a quarter, like the open
    -- categories in the tree (the game's "open" arrow points diagonally)
    b.arrow:SetTexture(ARROW_CLOSED)
    b.arrow:SetTextureRotation(TREE_ARROW_OPEN)
    b.arrow:SetAnchor(RIGHT, b, RIGHT, -6, 0)
    b.count = MakeLabel("SetHunter_ScopeCount", b, "ZoFontGameSmall", 36, 28, COLOR.dim)
    b.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    b.count:SetAnchor(RIGHT, b.arrow, LEFT, -4, 0)
    b.label = MakeLabel("SetHunter_ScopeLabel", b, "ZoFontGame", 230 - 20 - 16 - 36 - 28, 28, COLOR.header)
    b.label:SetMaxLineCount(1)
    b.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    b.label:SetAnchor(LEFT, b.icon, RIGHT, 6, 0)
    b:SetHandler("OnMouseEnter", function(self)
        PaintScopeButton(true)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
        SetTooltipText(InformationTooltip, L("SCOPE_TT"))
    end)
    b:SetHandler("OnMouseExit", function()
        PaintScopeButton(false)
        ClearTooltip(InformationTooltip)
    end)
    b:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            OpenScopePicker()
        end
    end)
    ui.scopeBox = b
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
        elseif cat.group then
            if section == tab then
                scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_HEADER, { text = zo_strupper(L(cat.group)) })
            end
        elseif section == tab then
            local locations = cat.kind and S.GetLocations(cat.kind)
            if not locations or #locations > 0 then
                cat.count, cat.countColor = CategoryCount(cat)
                scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_CATEGORY, cat)
                if locations and S.sv.open[cat.view] then
                    for _, loc in ipairs(locations) do
                        -- "2/4" (sets complete here / sets with a collection here) once you
                        -- have a piece from here; all done = a green check; nothing yet = no
                        -- number and a dimmer name
                        local sets = S.GetSetsForLocation(loc.id, true)
                        local done, total = Progress(sets)
                        local started = false
                        for _, data in ipairs(sets) do
                            if (data.have or 0) > 0 then started = true break end
                        end
                        local count, countColor
                        if total > 0 and done == total then
                            count, countColor = TREE_CHECK, COLOR.good
                        elseif started and total > 0 then
                            count = string.format("%d/%d", done, total)
                        end
                        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_SUB, {
                            text = loc.name, view = cat.view, loc = loc.id,
                            count = count, countColor = countColor,
                            dim = total > 0 and not started,
                        })
                    end
                end
                -- Wishlist: By place, Whole sets (sets), Wanted pieces (pieces), Completed
                -- (only once something is done); empty counts stay blank
                if cat.expand == "wish" and S.sv.open[cat.view] then
                    local whole, pieces = PieceWishSets(false), 0
                    for _, data in ipairs(PieceWishSets(true)) do
                        for _ in pairs(S.sv.wishPieces[data.setId] or {}) do pieces = pieces + 1 end
                    end
                    local done = #DoneWishSets()
                    local function Sub(key, loc, n, color)
                        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(TREE_SUB, {
                            text = L(key), view = cat.view, loc = loc,
                            count = n > 0 and tostring(n) or nil, countColor = color,
                        })
                    end
                    Sub("CAT_WISH_PLACES", "places", 0)
                    Sub("CAT_WISH_WHOLE", "whole", #whole)
                    Sub("CAT_WISH_PIECES", "pieces", pieces)
                    if done > 0 then Sub("CAT_WISH_DONE", "done", done, COLOR.good) end
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

-- The tree entry that is selected now (if it's on screen)
local function SelectedTreeRow()
    local contents = ui.tree and ui.tree:GetNamedChild("Contents")
    if not contents then return nil end
    for i = 1, contents:GetNumChildren() do
        local c = contents:GetChild(i)
        if c and not c:IsHidden() and c.data and c.data.view and IsCategorySelected(c.data) then return c end
    end
    return nil
end

-- Changing category: the bronze highlight glides from the old entry to the new one
-- (0.22 s, like the tab underline). A stand-in highlight flies between the two spots; the
-- new entry's own highlight shows once it arrives. from = { top, left, width, height }.
local GLIDE_SEL_T, CATEGORY_RISE_PX = 0.22, 8
local function GlideTreeHighlight(from)
    local to = SelectedTreeRow()
    if not from or not to or math.abs(from.top - to:GetTop()) < 1 then return end
    local g = ui.treeGlide
    if not g then
        g = WINDOW_MANAGER:CreateControl("SetHunter_TreeGlide", ui.win, CT_CONTROL)
        g:SetDrawLevel(5)
        g:SetMouseEnabled(false)
        local bg = WINDOW_MANAGER:CreateControl("SetHunter_TreeGlideBG", g, CT_TEXTURE)
        bg:SetAnchorFill(g)
        SetHexColor(bg, COLOR.theme, 0.14)
        local bar = WINDOW_MANAGER:CreateControl("SetHunter_TreeGlideBar", g, CT_TEXTURE)
        bar:SetAnchor(TOPLEFT, g, TOPLEFT, 0, 0)
        bar:SetAnchor(BOTTOMLEFT, g, BOTTOMLEFT, 0, 0)
        bar:SetWidth(2)
        SetHexColor(bar, COLOR.theme)
        ui.treeGlide = g
    end
    local toTop, toH, left, width = to:GetTop(), to:GetHeight(), to:GetLeft(), to:GetWidth()
    -- the tree clips nothing, so keep it inside the tree's own area
    local minTop, maxTop = ui.tree:GetTop(), ui.tree:GetBottom()
    local start = GetFrameTimeSeconds()
    ui.treeGliding = true
    ZO_ScrollList_RefreshVisible(ui.tree)   -- the new entry waits without its highlight
    g:SetHidden(false)
    g:SetHandler("OnUpdate", function(self)
        local t = zo_min((GetFrameTimeSeconds() - start) / GLIDE_SEL_T, 1)
        local e = EaseOut(t)
        local top = zo_clamp(from.top + (toTop - from.top) * e, minTop, maxTop)
        local h = from.height + (toH - from.height) * e
        self:ClearAnchors()
        self:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
        self:SetDimensions(width, h)
        if t >= 1 then
            self:SetHandler("OnUpdate", nil)
            self:SetHidden(true)
            ui.treeGliding = false
            ZO_ScrollList_RefreshVisible(ui.tree)
        end
    end)
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
    -- where the highlight is now: it glides from there to the new entry
    local old = SelectedTreeRow()
    local from = old and { top = old:GetTop(), height = old:GetHeight() } or nil
    ui.itemsSetId = nil
    ui.boostKey = nil
    local wasOpen = sv.open[data.view] == true
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
    -- the game's own tree sounds (its menus use them for categories / sub-entries; the
    -- soft typing tick didn't fit here)
    local treeSound = data.loc and SOUNDS.TREE_SUBCATEGORY_CLICK or SOUNDS.TREE_HEADER_CLICK
    PlaySound(treeSound or SOUNDS.DEFAULT_CLICK)
    ZO_ScrollList_ResetToTop(ui.list)
    -- opened or closed by this click: the next tree refresh animates it (SetupCategory)
    local isOpen = sv.open[data.view] == true
    if not data.loc and (data.kind or data.expand) and isOpen ~= wasOpen then
        ui.treeAnim = { view = data.view, start = GetFrameTimeSeconds(), opened = isOpen }
    end
    ui.search:SetText("")
    ui.search:LoseFocus()
    S.RefreshAll()
    if ui.treeAnim then ui.treeAnim.committed = true end   -- later refreshes don't replay it
    -- a new page: the highlight glides over and the page fades in, rising 8 px
    if not samePage then
        GlideTreeHighlight(from)
        SlideContent(0, CATEGORY_RISE_PX)
    end
end

-- ---------------------------------------------------------------------------
-- List (right)
-- ---------------------------------------------------------------------------
-- Shortcut icon at the end of a row: queue for its dungeon, or travel to its place.
-- Worked out once per row (finding a dungeon's queue entry takes a moment).
local TEX_TRAVEL = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds"
local ACTION_ALPHA, ACTION_ALPHA_HOVER = 0.55, 1
local OWNED_ALPHA = 0.6

-- Wishlist star on set rows: a polished-metal star (gold fading to bronze, dark rim) when
-- the set is on your wishlist, a grey metal outline otherwise (bronze under the mouse);
-- both grow a little under the mouse. A click pops it.
local TEX_STAR_FILL = "SetHunter/Textures/star_fill.dds"
local TEX_STAR_LINE = "SetHunter/Textures/star_line.dds"
local STAR_LINE_HEX = "8A7F6C"
local STAR_POP_T = 0.3

-- What kind of set it is, as a small glass chip at the end of a set row: the kind's icon
-- + word ("Dungeon", "Trial"...) in the kind's color. It's also the row's shortcut, like
-- the end icon it replaced: queue, travel, or open the reward system it comes from.
-- Hover: lifts 1 px, bronze glass, white text. Click: a quick dip and a light flash.
local PILL_KIND = {
    dungeon  = { key = "PILL_DUNGEON",  text = "E3B98A", icon = TEX_QUEUE },
    trial    = { key = "PILL_TRIAL",    text = "C8B8EA", icon = "EsoUI/Art/Icons/poi/poi_raiddungeon_complete.dds" },
    arena    = { key = "PILL_ARENA",    text = "EBA08F", icon = "EsoUI/Art/Icons/poi/poi_solotrial_complete.dds" },
    overland = { key = "PILL_OVERLAND", text = "B0D6A4", icon = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds" },
    pvp      = { key = "PILL_PVP",      text = "C5CCD6", icon = "EsoUI/Art/MainMenu/menuBar_champion_up.dds" },
    mythic   = { key = "PILL_MYTHIC",   text = "F2D27C", iconFn = AntiquityIcon },
    monster  = { key = "PILL_MONSTER",  text = "E0A6C9", icon = TEX_VETERAN },
    crafted  = { key = "PILL_CRAFTED",  text = "A9C8E8", icon = "EsoUI/Art/Icons/ServiceMapPins/servicepin_smithy.dds" },
    other    = { key = "PILL_OTHER",    text = "C9BFA8", icon = "EsoUI/Art/MainMenu/menuBar_journal_up.dds" },
}
local PILL_H, PILL_LIFT, PILL_PRESS_T, PILL_FLASH_T = 20, 1, 0.15, 0.42

local function PillKind(data)
    if not data or data.kind ~= "set" or not data.setId then return nil end
    return PILL_KIND[S.SetKind(data.setId)]
end

-- Set row columns, measured from the right: pill, collected count + bar, owned. Name
-- and type share what's left (wider windows give both more room). The column titles
-- use the same numbers (PlaceColumns).
local SR_NAME_X = 32
local SR_PILL_W, SR_INFO_W, SR_OWNED_W = 70, 62, 52
local SR_PILL_R = 6                                  -- pill's right edge, from the row's
local SR_INFO_R = SR_PILL_R + SR_PILL_W + 10         -- collected count / bar
local SR_OWNED_R = SR_INFO_R + SR_INFO_W + 10        -- owned (bag icon + count)
local function SetRowWidths(rowW)
    local avail = zo_max(rowW - SR_NAME_X - SR_OWNED_R - SR_OWNED_W - 8, 160)
    local nameW = zo_floor(avail * 0.56)
    return nameW, avail - nameW - 6   -- name width, type width
end

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
        S.TravelTo(zoneId, data.zoneId == zoneId and data.place or nil)
    end
end

-- "Icon: queue for Arx Corinium" line for the row tooltips.
local function ActionHint(data)
    local zoneId, queue, source = RowAction(data)
    -- set rows: the shortcut is the pill, so the hint names it ("Click Dungeon to ...")
    local pill = PillKind(data)
    local pillMark = pill and Colorize(pill.text, L(pill.key))
    if source then
        local action = SOURCE_ACTIONS[source]
        return L(action.hint, pillMark or zo_iconFormat(action.icon(), 18, 18))
    end
    if not zoneId then return nil end
    local icon = pillMark or zo_iconFormat(ActionIcon(zoneId, queue), 18, 18)
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
    -- set rows: the pill is the shortcut (when the set has somewhere to go)
    if row.pill and not row.pill:IsHidden() then
        return row.pillAction == true and IsMouseOver(row.pill, 2)
    end
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
    if owned then SetHexColor(owned, hovered and COLOR.selected or COLOR.header) end
end

local function PaintPill(row, hovered)
    local pill, kind = row.pill, row.pillKind
    if not pill or not kind then return end
    local hot = hovered and row.pillAction or false
    if hot == pill.hot then return end   -- (called every frame while the mouse is on the row)
    pill.hot = hot
    pill:PaintGlass(hot, kind.text)
    pill:ClearAnchors()
    pill:SetAnchor(RIGHT, row, RIGHT, -SR_PILL_R, hot and -PILL_LIFT or 0)
end

-- clicked: dips to 92 % and springs back while a light flash fades over it
local function PressPill(row)
    local pill = row.pill
    if not pill or pill:IsHidden() then return end
    local start = GetFrameTimeSeconds()
    pill.flash:SetHidden(false)
    pill.flash:SetHandler("OnUpdate", function(self)
        local now = GetFrameTimeSeconds() - start
        local p = zo_min(now / PILL_PRESS_T, 1)
        pill:SetScale(1 - 0.08 * math.sin(p * math.pi))
        local f = zo_min(now / PILL_FLASH_T, 1)
        self:SetAlpha(0.45 * (1 - f) ^ 2)
        if f >= 1 then
            pill:SetScale(1)
            self:SetHidden(true)
            self:SetHandler("OnUpdate", nil)
        end
    end)
end

-- the chip is made the first time a row needs it (rows are reused by the list)
local function SetupPill(row, data)
    local pill = row.pill
    if not pill then
        local name = row:GetName() .. "Pill"
        pill = MakeLabel(name, row, "$(BOLD_FONT)|11|soft-shadow-thin", SR_PILL_W, PILL_H, COLOR.normal)
        pill:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        AddGlass(pill, COLOR.normal)
        pill.flash = WINDOW_MANAGER:CreateControl(name .. "Flash", pill, CT_TEXTURE)
        pill.flash:SetAnchorFill(pill)
        pill.flash:SetColor(1, 0.86, 0.67, 1)
        pill.flash:SetHidden(true)
        pill.flash:SetMouseEnabled(false)
        row.pill = pill
    end
    local kind = PillKind(data)
    row.pillKind = kind
    pill:SetHidden(kind == nil)
    if not kind then
        row.pillAction = false
        return
    end
    local zoneId, _, source = RowAction(data)
    row.pillAction = zoneId ~= nil or source ~= nil
    local icon = kind.icon or (kind.iconFn and kind.iconFn())
    pill:SetText((icon and (zo_iconFormatInheritColor(icon, 14, 14) .. " ") or "") .. L(kind.key))
    pill.hot = nil
    pill:SetScale(1)
    PaintPill(row, false)
end

local function PaintStar(star, data, hovered)
    if data.wish then
        -- polished metal: the picture has its own gold-to-bronze colors (not tinted)
        star:SetTexture(TEX_STAR_FILL)
        star:SetColor(1, 1, 1, 1)
    else
        star:SetTexture(TEX_STAR_LINE)
        SetHexColor(star, hovered and COLOR.theme or STAR_LINE_HEX)
    end
    if not star.popping then star:SetScale(hovered and 1.2 or 1) end
end

-- Rows are as wide as the list (which follows the window size), minus the scrollbar.
local function FitRow(row)
    if ui.list then row:SetWidth(zo_max(ui.list:GetWidth() - 16, 300)) end
end

local function SetupSetRow(row, data)
    FitRow(row)
    local rowW = row:GetWidth()
    local nameW, typeW = SetRowWidths(rowW)
    -- overview rows (kind "summary") are categories, not sets: no wishlist star, no owned,
    -- and they keep the end icon; set rows have the pill instead
    local summary = data.kind == "summary"
    SetupAction(row, data)
    SetupPill(row, data)
    if row.pillKind then row:GetNamedChild("Action"):SetHidden(true) end

    local star = row:GetNamedChild("Star")
    star:SetHidden(summary)
    star:SetDesaturation(0)
    star:SetHandler("OnUpdate", nil)
    star.popping = false
    PaintStar(star, data, false)
    -- just clicked: a quick pop (grows to 1.5x and settles back)
    local pop = ui.starPop
    if not summary and pop and pop.setId == data.setId and GetFrameTimeSeconds() - pop.start < STAR_POP_T then
        star.popping = true
        star:SetHandler("OnUpdate", function(self)
            local t = zo_min((GetFrameTimeSeconds() - pop.start) / STAR_POP_T, 1)
            self:SetScale(1 + 0.5 * math.sin(t * math.pi))
            if t >= 1 then
                self.popping = false
                self:SetScale(1)
                self:SetHandler("OnUpdate", nil)
            end
        end)
    end

    local name = row:GetNamedChild("Name")
    name:ClearAnchors()
    name:SetAnchor(LEFT, row, LEFT, SR_NAME_X, 0)
    name:SetWidth(nameW)
    local typeLabel = row:GetNamedChild("Type")
    typeLabel:ClearAnchors()
    typeLabel:SetAnchor(LEFT, row, LEFT, SR_NAME_X + nameW + 6, 0)
    typeLabel:SetWidth(typeW)
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
    if summary then SetHexColor(typeLabel, COLOR.dim) end
    typeLabel:SetText(typeText)

    local hasOwned = data.owned > 0
    local ownedX = rowW - SR_OWNED_R - SR_OWNED_W
    local ownedIcon, owned = row:GetNamedChild("OwnedIcon"), row:GetNamedChild("Owned")
    ownedIcon:SetHidden(not hasOwned)
    ownedIcon:SetTexture(TEX_BAG)
    ownedIcon:SetAlpha(OWNED_ALPHA)
    ownedIcon:ClearAnchors()
    ownedIcon:SetAnchor(LEFT, row, LEFT, ownedX, 0)
    owned:ClearAnchors()
    owned:SetAnchor(LEFT, row, LEFT, hasOwned and ownedX + 22 or ownedX + 2, 0)
    owned:SetText(hasOwned and tostring(data.owned) or Colorize(COLOR.dim, "–"))
    if summary then owned:SetText("") end
    SetHexColor(owned, COLOR.header)

    local info = row:GetNamedChild("Info")
    local barBG, barFill = row:GetNamedChild("BarBG"), row:GetNamedChild("BarFill")
    info:ClearAnchors()
    info:SetAnchor(TOPRIGHT, row, TOPRIGHT, -SR_INFO_R, 2)
    info:SetWidth(SR_INFO_W)
    barBG:ClearAnchors()
    barBG:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -SR_INFO_R, -5)
    barBG:SetWidth(SR_INFO_W)
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
    local marks = S.FCO.MarkNames(entry)
    if marks then
        ItemTooltip:AddLine(L("TT_FCO_MARKS", marks), "ZoFontGameSmall", HexToRGB(COLOR.normal))
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

-- The found piece in the bag / bank list: a bronze bar on the row's left edge with a soft
-- bronze tint fading out to the right, blinking 3 times (0.7 s each), then gone.
-- The tint is one gradient picture (flash_fade.dds), so it fades smoothly; thin strips
-- side by side showed lines where they met.
local FLASH_BLINK, FLASH_COUNT = 0.7, 3
local flash
local function FlashRow(row)
    local r, g, b = HexToRGB(COLOR.theme)
    if not flash then
        local top = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_BagFlash")
        top:SetDrawTier(DT_HIGH)
        top:SetMouseEnabled(false)
        local fade = WINDOW_MANAGER:CreateControl("SetHunter_BagFlashFade", top, CT_TEXTURE)
        fade:SetTexture("SetHunter/Textures/flash_fade.dds")
        fade:SetAnchorFill(top)
        fade:SetColor(r, g, b, 0.42)
        local bar = WINDOW_MANAGER:CreateControl("SetHunter_BagFlashBar", top, CT_TEXTURE)
        bar:SetAnchor(TOPLEFT, top, TOPLEFT, 0, 0)
        bar:SetAnchor(BOTTOMLEFT, top, BOTTOMLEFT, 0, 0)
        bar:SetWidth(4)
        bar:SetColor(r, g, b, 1)
        flash = { top = top, fade = fade }
    end
    local top = flash.top
    top:ClearAnchors()
    top:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    top:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
    -- a new picture needs a full game restart: until then only the bar blinks (a missing
    -- file would draw as a solid sheet)
    flash.fade:SetHidden(not flash.fade:IsTextureLoaded())
    top:SetAlpha(0)
    top:SetHidden(false)
    local start = GetFrameTimeSeconds()
    -- (rows get recycled when scrolling, so it never lingers past the blinks)
    top:SetHandler("OnUpdate", function(self)
        local t = (GetFrameTimeSeconds() - start) / FLASH_BLINK
        if t >= FLASH_COUNT then
            self:SetHandler("OnUpdate", nil)
            self:SetHidden(true)
            return
        end
        flash.fade:SetHidden(not flash.fade:IsTextureLoaded())
        self:SetAlpha((1 - math.cos(t * 2 * math.pi)) / 2)   -- 0 -> 1 -> 0 per blink
    end)
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
    if picker.win then FadeAway(picker.win) end
    if S.CloseRowMenu then S.CloseRowMenu() end   -- the right-click menu goes with it
    if S.CloseScopePicker then S.CloseScopePicker() end   -- and the character picker
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
    local wasHidden = win:IsHidden() or win.fading   -- (fading out = closed)
    win.noUnfold = true   -- it has a minimum height, so it can't grow from 0: soft drop instead
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
    -- the short drop only when it opens (not when it's already open and gets new content)
    if wasHidden then
        if S.sv.pickX and S.sv.pickY then
            DropIn(win, TOPLEFT, GuiRoot, TOPLEFT, S.sv.pickX, S.sv.pickY)
        else
            DropIn(win, CENTER, ui.win, CENTER, 0, 0)
        end
    end
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

-- ---------------------------------------------------------------------------
-- Right-click menu on list rows: our own panel instead of the game's plain menu.
-- Header with the piece (icon, name in its quality color, trait · where), then
-- FCO ItemSaver marks as chips (with FCOIS), then labelled sections with icons.
-- Chips toggle and keep the menu open; a row closes it and runs its action.
-- ---------------------------------------------------------------------------
local RM_W, RM_PAD, RM_HEAD_H, RM_CAP_H, RM_ROW_H, RM_CHIP_H, RM_ICON = 300, 8, 52, 22, 26, 24, 20
local RM_ORDER = { "wish", "find", "piece" }
local RM_TITLES = { wish = "RM_WISHLIST", find = "RM_FIND", piece = "RM_PIECE" }
local TEX_RESEARCH = "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds"
local TEX_MAP = "EsoUI/Art/MainMenu/menuBar_map_up.dds"
local TEX_CHAT = "EsoUI/Art/ChatWindow/chat_notification_up.dds"
local CHIP_EDGE_OFF = { 0.29, 0.24, 0.16 }
local rowMenu = { rows = {}, caps = {}, chips = {} }

local function CloseRowMenu()
    if not rowMenu.win or rowMenu.win:IsHidden() then return end
    FadeAway(rowMenu.win)
    ClearTooltip(InformationTooltip)
    EVENT_MANAGER:UnregisterForEvent("SetHunter_RowMenu", EVENT_GLOBAL_MOUSE_DOWN)
end
S.CloseRowMenu = CloseRowMenu

local function PaintRowMenuRow(r)
    local hover = r.hovered
    r.hl:SetHidden(not hover)
    r.bar:SetHidden(not hover)
    SetHexColor(r.label, hover and COLOR.selected or (r.dim and COLOR.dim or COLOR.normal))
    r.icon:SetAlpha(hover and 1 or 0.8)
end

local function PaintChip(c)
    local on = c.isOn()
    if on then
        c.bg:SetEdgeColor(HexToRGB(COLOR.theme))
        local r, g, b = HexToRGB(COLOR.theme)
        c.bg:SetCenterColor(r * 0.3, g * 0.3, b * 0.3, 0.9)
    else
        c.bg:SetEdgeColor(CHIP_EDGE_OFF[1], CHIP_EDGE_OFF[2], CHIP_EDGE_OFF[3], 1)
        c.bg:SetCenterColor(0, 0, 0, 0)
    end
    SetHexColor(c.label, c.hovered and COLOR.selected or (on and COLOR.header or COLOR.dim))
end

local function PaintChips()
    for i = 1, rowMenu.usedChips or 0 do PaintChip(rowMenu.chips[i]) end
end

local function CreateRowMenu()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("SetHunter_RowMenu")
    win:SetDrawTier(DT_HIGH)
    win:SetMouseEnabled(true)   -- clicks on the panel don't fall through to the list
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetWidth(RM_W)
    local bg = WINDOW_MANAGER:CreateControl("SetHunter_RowMenuBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.04, 0.035, 0.03, 0.97)
    bg:SetEdgeColor(HexToRGB(COLOR.theme))
    bg:SetEdgeTexture("", 1, 1, 1)

    -- header: the piece's icon in a small frame, its name, trait · where
    local frame = WINDOW_MANAGER:CreateControl("SetHunter_RowMenuIconFrame", win, CT_BACKDROP)
    frame:SetDimensions(38, 38)
    frame:SetAnchor(TOPLEFT, win, TOPLEFT, RM_PAD + 2, RM_PAD)
    frame:SetCenterColor(0.08, 0.07, 0.05, 1)
    local tr, tg, tb = HexToRGB(COLOR.theme)
    frame:SetEdgeColor(tr, tg, tb, 0.6)
    frame:SetEdgeTexture("", 1, 1, 1)
    local icon = WINDOW_MANAGER:CreateControl("SetHunter_RowMenuIcon", frame, CT_TEXTURE)
    icon:SetDimensions(32, 32)
    icon:SetAnchor(CENTER, frame, CENTER, 0, 0)
    local name = MakeLabel("SetHunter_RowMenuName", win, "ZoFontGameBold", RM_W - 38 - RM_PAD * 3 - 4, 22)
    name:SetMaxLineCount(1)
    name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    name:SetAnchor(TOPLEFT, frame, TOPRIGHT, 10, -1)
    local sub = MakeLabel("SetHunter_RowMenuSub", win, "ZoFontGameSmall", RM_W - 38 - RM_PAD * 3 - 4, 18, COLOR.dim)
    sub:SetMaxLineCount(1)
    sub:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    sub:SetAnchor(TOPLEFT, name, BOTTOMLEFT, 0, 0)
    local rule = WINDOW_MANAGER:CreateControl("SetHunter_RowMenuRule", win, CT_TEXTURE)
    rule:SetDimensions(RM_W - RM_PAD * 2, 1)
    rule:SetColor(tr, tg, tb, 0.35)
    rule:SetAnchor(TOPLEFT, win, TOPLEFT, RM_PAD, RM_HEAD_H)
    rowMenu.headParts = { frame, name, sub, rule }
    rowMenu.icon, rowMenu.name, rowMenu.sub = icon, name, sub
    rowMenu.win = win
end

local function RowMenuCap(i)
    local c = rowMenu.caps[i]
    if not c then
        c = MakeLabel("SetHunter_RowMenuCap" .. i, rowMenu.win, "$(BOLD_FONT)|12|soft-shadow-thin", RM_W - RM_PAD * 2, RM_CAP_H, COLOR.dim)
        rowMenu.caps[i] = c
    end
    return c
end

local function RowMenuRow(i)
    local r = rowMenu.rows[i]
    if r then return r end
    r = WINDOW_MANAGER:CreateControl("SetHunter_RowMenuRow" .. i, rowMenu.win, CT_CONTROL)
    r:SetDimensions(RM_W - 2, RM_ROW_H)
    r:SetMouseEnabled(true)
    local tr, tg, tb = HexToRGB(COLOR.theme)
    r.hl = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.hl:SetAnchorFill(r)
    r.hl:SetColor(tr, tg, tb, 0.16)
    r.bar = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.bar:SetDimensions(2, RM_ROW_H)
    r.bar:SetAnchor(LEFT, r, LEFT, 0, 0)
    r.bar:SetColor(tr, tg, tb, 1)
    r.icon = WINDOW_MANAGER:CreateControl(nil, r, CT_TEXTURE)
    r.icon:SetDimensions(RM_ICON, RM_ICON)
    r.icon:SetAnchor(LEFT, r, LEFT, RM_PAD + 4, 0)
    r.label = MakeLabel(nil, r, "ZoFontGame", RM_W - RM_ICON - RM_PAD * 3 - 8, RM_ROW_H)
    r.label:SetMaxLineCount(1)
    r.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    r.label:SetAnchor(LEFT, r.icon, RIGHT, 10, 0)
    r:SetHandler("OnMouseEnter", function(self) self.hovered = true; PaintRowMenuRow(self) end)
    r:SetHandler("OnMouseExit", function(self) self.hovered = false; PaintRowMenuRow(self) end)
    r:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local fn = self.fn
        CloseRowMenu()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if fn then fn() end
    end)
    rowMenu.rows[i] = r
    return r
end

local function RowMenuChip(i)
    local c = rowMenu.chips[i]
    if c then return c end
    c = WINDOW_MANAGER:CreateControl("SetHunter_RowMenuChip" .. i, rowMenu.win, CT_CONTROL)
    c:SetMouseEnabled(true)
    c:SetHeight(RM_CHIP_H)
    c.bg = WINDOW_MANAGER:CreateControl(nil, c, CT_BACKDROP)
    c.bg:SetAnchorFill(c)
    c.bg:SetEdgeTexture("", 1, 1, 1)
    c.label = WINDOW_MANAGER:CreateControl(nil, c, CT_LABEL)
    c.label:SetFont("ZoFontGameSmall")
    c.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c.label:SetAnchor(LEFT, c, LEFT, 7, 0)
    c:SetHandler("OnMouseEnter", function(self)
        self.hovered = true
        PaintChip(self)
        if self.tooltip then
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, self.tooltip)
        end
    end)
    c:SetHandler("OnMouseExit", function(self)
        self.hovered = false
        PaintChip(self)
        ClearTooltip(InformationTooltip)
    end)
    c:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        self.toggle()
        PaintChips()   -- FCOIS can change other marks too (its own auto rules)
        S.RefreshAll()
    end)
    rowMenu.chips[i] = c
    return c
end

-- Duplicates page: "keep the best, mark the rest". The group = every copy of this
-- piece (same set, slot and trait) among the items shown (follows the character
-- picker). Best = worn first, then quality, CP level, level. The kept one loses a
-- deconstruction mark; the others get one in FCO ItemSaver, except worn / FCOIS-locked
-- copies, copies not read with FCOIS yet, and identical copies sharing the kept one's
-- FCOIS id (FCOIS's default item instance ids: one mark for all of them).
local TEX_DECON = "EsoUI/Art/Crafting/enchantment_tabIcon_deconstruction_up.dds"

local function DupeGroup(data)
    local key = DupeKey(data, S.PieceInfo(data))
    local list = {}
    for _, entry in ipairs(S.GetOwned(data.setId)) do
        if InScope(entry) and DupeKey(entry, S.PieceInfo(entry)) == key then list[#list + 1] = entry end
    end
    return list
end

local function BetterCopy(a, b)
    local wa, wb = a.whereKind == "worn", b.whereKind == "worn"
    if wa ~= wb then return wa end
    local pa, pb = S.PieceInfo(a), S.PieceInfo(b)
    if pa.qualityValue ~= pb.qualityValue then return pa.qualityValue > pb.qualityValue end
    if (pa.cp or 0) ~= (pb.cp or 0) then return (pa.cp or 0) > (pb.cp or 0) end
    return GetItemLinkRequiredLevel(a.link) > GetItemLinkRequiredLevel(b.link)
end

local function KeepBestMarkRest(data)
    local DECON = FCOIS_CON_ICON_DECONSTRUCTION
    local group = DupeGroup(data)
    if not DECON or #group < 2 then return end
    table.sort(group, BetterCopy)
    local keep = group[1]
    if keep.fco and S.FCO.IsMarked(keep, DECON) then S.FCO.Set(keep, DECON, false) end
    local marked, unread, shared, protected = 0, 0, 0, 0
    for i = 2, #group do
        local entry = group[i]
        if not entry.fco then
            unread = unread + 1
        elseif keep.fco and entry.fco == keep.fco then
            shared = shared + 1
        elseif entry.whereKind == "worn" or S.FCO.IsLocked(entry) then
            protected = protected + 1
        else
            if not S.FCO.IsMarked(entry, DECON) then S.FCO.Set(entry, DECON, true) end
            marked = marked + 1
        end
    end
    local piece = S.PieceInfo(keep)
    S.Print(L("KEEP_DONE", piece.coloredName, keep.where or "", marked))
    if protected > 0 then S.Print(L("KEEP_SKIP_PROTECTED", protected)) end
    if unread > 0 then S.Print(L("KEEP_SKIP_UNREAD", unread)) end
    if shared > 0 then S.Print(L("KEEP_SKIP_SHARED", shared)) end
    S.RefreshAll()
end

-- m = { sections = { wish = { item, ... }, ... }, chips = { { text, isOn, toggle, tooltip }, ... } }
-- item = { icon, text, fn, dim }; header = { icon, name, sub } or nil
local function NewRowMenu() return { sections = {} } end
local function MenuAdd(m, section, icon, text, fn, dim)
    m.sections[section] = m.sections[section] or {}
    table.insert(m.sections[section], { icon = icon, text = text, fn = fn, dim = dim })
end

local function OpenRowMenu(m, header)
    local any = m.chips ~= nil
    for _, items in pairs(m.sections) do if #items > 0 then any = true end end
    if not any then return end
    if not rowMenu.win then CreateRowMenu() end
    local win = rowMenu.win
    ClearTooltip(ItemTooltip)
    ClearTooltip(InformationTooltip)

    for _, part in ipairs(rowMenu.headParts) do part:SetHidden(header == nil) end
    local y = RM_PAD
    if header then
        rowMenu.icon:SetTexture(header.icon or TEX_ICON)
        rowMenu.name:SetText(header.name or "")
        rowMenu.sub:SetText(header.sub or "")
        y = RM_HEAD_H + 6
    end

    local nCap, nRow, nChip = 0, 0, 0
    local function Cap(text)
        nCap = nCap + 1
        local c = RowMenuCap(nCap)
        c:SetText(zo_strupper(text))
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT, win, TOPLEFT, RM_PAD + 4, y)
        c:SetHidden(false)
        y = y + RM_CAP_H
    end

    -- FCO ItemSaver marks: chips that wrap onto more lines
    if m.chips then
        Cap(L("RM_FCO"))
        local x, maxX = RM_PAD + 4, RM_W - RM_PAD - 4
        for _, chip in ipairs(m.chips) do
            nChip = nChip + 1
            local c = RowMenuChip(nChip)
            c.isOn, c.toggle, c.tooltip, c.hovered = chip.isOn, chip.toggle, chip.tooltip, false
            c.label:SetText(chip.text)
            local w = zo_min(c.label:GetTextWidth() + 14, maxX - RM_PAD - 4)
            if x + w > maxX and x > RM_PAD + 4 then
                x = RM_PAD + 4
                y = y + RM_CHIP_H + 5
            end
            c:SetWidth(w)
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
            c:SetHidden(false)
            x = x + w + 5
        end
        y = y + RM_CHIP_H + 8
    end

    for _, key in ipairs(RM_ORDER) do
        local items = m.sections[key]
        if items and #items > 0 then
            Cap(L(RM_TITLES[key]))
            for _, item in ipairs(items) do
                nRow = nRow + 1
                local r = RowMenuRow(nRow)
                r.fn, r.dim, r.hovered = item.fn, item.dim, false
                r.icon:SetTexture(item.icon or TEX_ICON)
                r.label:SetText(item.text)
                r:ClearAnchors()
                r:SetAnchor(TOPLEFT, win, TOPLEFT, 1, y)
                r:SetHidden(false)
                PaintRowMenuRow(r)
                y = y + RM_ROW_H
            end
            y = y + 6
        end
    end
    for i = nCap + 1, #rowMenu.caps do rowMenu.caps[i]:SetHidden(true) end
    for i = nRow + 1, #rowMenu.rows do rowMenu.rows[i]:SetHidden(true) end
    for i = nChip + 1, #rowMenu.chips do rowMenu.chips[i]:SetHidden(true) end
    rowMenu.usedChips = nChip
    PaintChips()

    win:SetHeight(y + RM_PAD - 6)
    local mx, my = GetUIMousePosition()
    DropIn(win, TOPLEFT, GuiRoot, TOPLEFT, mx + 4, my + 2)
    -- a click anywhere else closes it
    EVENT_MANAGER:RegisterForEvent("SetHunter_RowMenu", EVENT_GLOBAL_MOUSE_DOWN, function()
        if not IsMouseOver(win, 0) then CloseRowMenu() end
    end)
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
    local hasPill = row.pill ~= nil and not row.pill:IsHidden() and row.pillAction
    local star = data.kind == "set" and row:GetNamedChild("Star") or nil
    local hasOwned = HasOwnedShortcut(data)
    local summary = data.kind == "summary"
    if hasAction or hasPill or star or hasOwned or summary then
        row.starOver = nil
        row:SetHandler("OnUpdate", function(self)
            if hasAction then action:SetAlpha(IsOverAction(self) and ACTION_ALPHA_HOVER or ACTION_ALPHA) end
            if hasPill then PaintPill(self, IsOverAction(self)) end
            if star then
                local over = IsMouseOver(star, 3)
                if over ~= self.starOver then
                    self.starOver = over
                    PaintStar(star, data, over)
                end
            end
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
    PaintPill(row, false)
    row.starOver = nil
    if row:GetNamedChild("OwnedIcon") then PaintOwned(row, false) end
    if row:GetNamedChild("Where") then
        local name = row:GetNamedChild("Name")
        name:SetFont("ZoFontGame")
        name:SetStyleColor(0, 0, 0, 1)
    end
    local data = ZO_ScrollList_GetData(row)
    if data then SetHexColor(row:GetNamedChild("Name"), NameColor(data)) end
    if data and data.kind == "set" then PaintStar(row:GetNamedChild("Star"), data, false) end
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
            PressPill(row)   -- set rows: the chip dips and flashes
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
        CloseRowMenu()
        local m = NewRowMenu()
        local function Wish(icon, text, fn) MenuAdd(m, "wish", icon, text, fn) end
        local function Find(icon, text, fn) MenuAdd(m, "find", icon, text, fn) end
        local function Piece(icon, text, fn, dim) MenuAdd(m, "piece", icon, text, fn, dim) end

        if IsSetLike(data) then
            local wished = S.sv.wishlist[data.setId]
            if data.kind ~= "item" then
                Wish(TEX_STAR, wished and L("BTN_UNWISH") or L("BTN_WISH"), function() ToggleWish(data) end)
            elseif wished then
                -- a piece has its own "add this piece" below; only offer removing the whole set
                Wish(TEX_STAR, L("MENU_UNWISH_SET"), function() ToggleWish(data) end)
            end
            -- an owned piece: wishlist just that piece
            local key = data.kind == "item" and S.PieceInfo(data).slotKey
            if key then
                local on = S.IsWantedPiece(data.setId, key)
                Wish(TEX_STAR, L(on and "MENU_UNWISH_PIECE" or "MENU_WISH_PIECE"), function()
                    S.ToggleWishPiece(data.setId, key)
                    S.RefreshAll()
                end)
            end
            -- for any set: picking a trait or piece puts the set on the wishlist
            Wish(TEX_RESEARCH, L("MENU_TRAITS"), function() ShowTraitMenu(row, data) end)
            Wish(TEX_ICON, L("MENU_PIECES"), function() ShowPieceMenu(row, data) end)
            -- drops in several places: one entry per place (not the one on screen)
            local locIds = SetLocationIds(data)
            if #locIds > 1 then
                for _, id in ipairs(locIds) do
                    if id ~= ui.viewLocId then
                        Find(TEX_MAP, L("MENU_GOTO_AT", S.GetLocation(id).name), function() GoToSet(data, id) end)
                    end
                end
            elseif NextLocationFor(data) then
                Find(TEX_MAP, L("MENU_GOTO"), function() GoToSet(data) end)
            end
            -- reward systems it comes from: Open Antiquities / Queue random dungeon / Open Battlegrounds
            for _, key in ipairs(SourceActionsFor(data)) do
                local action = SOURCE_ACTIONS[key]
                Find(action.icon(), L(action.text), action.run)
            end
            local owned = S.OwnedCount(data.setId)
            if data.kind == "set" and owned > 0 then
                Piece(TEX_BAG, L("MENU_MY_PIECES", owned), function() ShowMyPieces(data.setId) end)
            end
        end
        -- wanted-piece line under a set in the Wishlist
        if data.pieceKey then
            Wish(TEX_STAR, L("MENU_UNWISH_PIECE"), function()
                S.ToggleWishPiece(data.pieceOf, data.pieceKey)
                S.RefreshAll()
            end)
        end
        -- hunted-trait line under a set in Trait hunt
        if data.huntSet then
            Wish(TEX_RESEARCH, L("MENU_TRAITS"), function() ShowTraitMenu(row, { setId = data.huntSet }) end)
        end
        local here = ui.viewZoneId and Reachable(ui.viewZoneId) and ui.viewZoneId or nil
        AddTravelOrQueue(TargetFor(data) or here, data, Find)
        if CanLocate(data) then
            Piece(ui.atBank and TEX_BANK or TEX_BAG, L(ui.atBank and "MENU_SHOW_IN_BANK" or "MENU_SHOW_IN_BAG"),
                function() S.LocateItem(data) end)
        end
        if data.boostKey and (data.owned or 0) > 0 then
            Piece(TEX_BAG, L("MENU_MY_BOOSTS", data.owned), function() OpenOwned(data) end)
        end
        -- FCO ItemSaver marks on an owned piece: chips right in the menu
        -- (read before FCOIS was installed: the entry says to log in there once)
        if data.kind == "item" and S.FCO.Ready() then
            if data.fco then
                m.chips = {}
                for _, icon in ipairs(S.FCO.Icons()) do
                    m.chips[#m.chips + 1] = {
                        text = icon.name,
                        isOn = function() return S.FCO.IsMarked(data, icon.iconId) end,
                        toggle = function() S.FCO.Set(data, icon.iconId, not S.FCO.IsMarked(data, icon.iconId)) end,
                    }
                end
                if #m.chips == 0 then m.chips = nil end
            else
                local where = data.whereKind == "bank" and "BANK" or data.whereKind == "house" and "HOUSE" or nil
                Piece(TEX_ICON, L(where and ("MENU_FCO_LATER_" .. where) or "MENU_FCO_LATER", data.owner or ""), function()
                    local text = L(where and ("FCO_NEED_SCAN_" .. where) or "FCO_NEED_SCAN", data.owner or "")
                    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NEGATIVE_CLICK, text)
                    S.Print(text)
                end, true)
            end
        end
        -- Duplicates page: keep the best copy, mark the others for deconstruction (FCOIS)
        if data.kind == "item" and S.sv.view == "items_dupes" and S.FCO.Ready() and FCOIS_CON_ICON_DECONSTRUCTION then
            local others = #DupeGroup(data) - 1
            if others > 0 then
                Piece(TEX_DECON, L(others == 1 and "MENU_KEEP_BEST_ONE" or "MENU_KEEP_BEST", others),
                    function() KeepBestMarkRest(data) end)
            end
        end
        if data.link then
            Piece(TEX_CHAT, L("BTN_LINK"), function() LinkInChat(data) end)
        end

        -- header: the piece (or set) the menu is about
        local header
        if data.kind == "item" then
            local piece = S.PieceInfo(data)
            header = { icon = piece.icon, name = piece.coloredName, sub = piece.trait .. "  ·  " .. (data.where or "") }
        elseif data.kind == "set" and data.link then
            header = {
                icon = GetItemLinkIcon(data.link), name = Colorize(COLOR.header, data.name or ""),
                sub = (data.total or 0) > 0 and L("RM_SET_SUB", data.have or 0, data.total) or nil,
            }
        end
        OpenRowMenu(m, header)
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
        S.TravelTo(data.zoneId, data.place)
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
    PlaySound(SOUNDS.EDIT_CLICK or SOUNDS.DEFAULT_CLICK)   -- the same soft tick as back / forward
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
            if text ~= label:GetText() then
                label:SetText(text)
                label:SetWidth(#text * 8 + 4)   -- rough; fitted next frame (unchanged text keeps its fit)
            end
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
        -- on the badge row (level with the character dropdown), at the right edge
        ui.bankLink:SetHidden(not showBank)
        ui.bankLink:ClearAnchors()
        ui.bankLink:SetAnchor(RIGHT, ui.header, TOPRIGHT, 0, BADGE_ROW_Y)
    end
    ui.sourceKey = result.sourceKey
    if ui.sourceLink then
        local action = SOURCE_ACTIONS[result.sourceKey or ""]
        ui.sourceLink:SetHidden(action == nil)
        if action then
            -- the icon takes the text's color (bronze, white under the mouse)
            ui.sourceLink:SetText(zo_iconFormatInheritColor(action.icon(), 18, 18) .. " " .. L(action.text))
            ui.sourceLink:PaintGlass(false)
            ui.sourceLink:FitGlass()
        end
    end
    local reserve = art and (ART_W + 14) or ((result.rules or showBank) and 170) or 0
    local textW = ui.listW - reserve

    -- The page's explanation goes behind the (i) after the title; only facts (a
    -- dungeon's monster helm lines, a missing library) stay on the page (result.facts).
    local info = result.info or ""
    ui.infoText = (info ~= "" and not result.facts) and info or nil
    if ui.infoText then info = "" end
    -- My items pages: the text is mostly about the character dropdown, so the (i) sits
    -- right of the dropdown instead (placed with it, below)
    local infoByTitle = ui.infoText ~= nil and not result.scope
    ui.viewTitle:SetWidth(textW - (infoByTitle and 30 or 0))
    ui.viewTitle:SetText(zo_strupper(result.title or ""))
    ui.infoIcon:SetHidden(ui.infoText == nil)
    if ui.infoText then ui.paintInfoIcon(false) end   -- the sharp picture once it has loaded
    if infoByTitle then
        -- right after the title's text: rough now, exact a frame later (new text is
        -- only measured on the next frame)
        -- Same title and width as last time: it's already in the right spot (placing it
        -- again by the rough guess made it jump for a frame on every refresh / click).
        local title = ui.viewTitle
        local key = (title:GetText() or "") .. "|" .. title:GetWidth()
        if key ~= ui.infoPlacedFor then
            ui.infoPlacedFor = key
            local function Place(w)
                ui.infoIcon:ClearAnchors()
                ui.infoIcon:SetAnchor(LEFT, title, LEFT, zo_min(w, title:GetWidth()) + 8, 0)
            end
            Place(#(title:GetText() or "") * 14)
            zo_callLater(function()
                if ui.infoPlacedFor == key then Place(title:GetTextWidth()) end   -- still this page
            end, 1)
        end
    end

    local previous
    local badges = result.badges or {}
    for i, badge in ipairs(ui.badges) do
        -- A badge is its text, or { text = ..., tooltip = function(tooltip) ... end }.
        local entry = badges[i]
        local text = type(entry) == "table" and entry.text or entry
        badge:SetHidden(text == nil)
        badge:SetBadgeTooltip(type(entry) == "table" and entry.tooltip or nil, type(entry) == "table" and entry.panel or nil)
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
            -- the (i) right after the dropdown (it follows the dropdown by itself)
            if ui.infoText and ui.infoPlacedFor ~= "scope" then
                ui.infoPlacedFor = "scope"
                ui.infoIcon:ClearAnchors()
                ui.infoIcon:SetAnchor(LEFT, ui.scopeBox, RIGHT, 8, 0)
            end
        end
    end

    local height = 36 + (previous and 26 or 0)
    ui.info:SetWidth(textW)
    ui.info:ClearAnchors()
    ui.info:SetAnchor(TOPLEFT, ui.header, TOPLEFT, 0, height + 6)
    ui.info:SetText(info)
    ui.info:SetHidden(info == "")
    if info ~= "" then height = height + 6 + ui.info:GetTextHeight() end
    -- the links on the right ("How drops work", the source link under it, the bank link)
    -- need room too, or they run into the progress line below (since the page text went
    -- behind the (i), the left side alone is often shorter than they are)
    local right = 0
    if result.rules then right = 30 end                                   -- How drops work: y 10, 20 high
    if SOURCE_ACTIONS[result.sourceKey or ""] then right = 34 + SOURCE_BTN_H end   -- + 4 + the button under it
    if showBank then right = zo_max(right, BADGE_ROW_Y + SOURCE_BTN_H / 2) end   -- on the badge row
    if right > 0 then right = right + 4 end
    ui.header:SetHeight(zo_max(height, right, art and (ART_H + 24) or 0))

    local above = ui.header
    local progress = result.progress
    ui.progressRow:SetHidden(progress == nil)
    if progress then
        ui.progressLabel:SetText(progress.label or L("COLLECTION_HERE"))
        ui.progressValue:SetText(progress.valueText or L(progress.valueKey or "PROGRESS_VALUE", progress.done, progress.total))
        SetHexColor(ui.progressValue, progress.done == progress.total and COLOR.good or COLOR.selected)
        -- fills up when you arrive on a page; plain refreshes (a piece looted) don't replay it
        local pageKey = tostring(S.sv.view) .. "|" .. tostring(S.sv.loc) .. "|" .. tostring(ui.itemsSetId)
        local arrived = pageKey ~= ui.progressPage
        ui.progressPage = pageKey
        ui.progressBar:SetProgress(progress.done / progress.total, progress.done == progress.total, arrived)
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
        -- set rows: titles over the stretching columns (SetRowWidths); item / boost rows
        -- keep their fixed spots
        local labels = ui.columnLabels
        local setRows = result.columns ~= "items" and result.columns ~= "boosts"
        local rowW = zo_max(ui.listW - 16, 300)
        local xs, lastRight
        if setRows then
            local nameW = SetRowWidths(rowW)
            xs = { SR_NAME_X, SR_NAME_X + nameW + 6, rowW - SR_OWNED_R - SR_OWNED_W }
            lastRight = -(16 + SR_INFO_R)
        else
            xs, lastRight = { 32, 224, 352 }, -50
        end
        for i = 1, 3 do
            labels[i]:ClearAnchors()
            labels[i]:SetAnchor(LEFT, ui.columns, LEFT, xs[i], 0)
        end
        labels[4]:ClearAnchors()
        labels[4]:SetAnchor(RIGHT, ui.columns, RIGHT, lastRight, 0)
        labels[5]:SetHidden(not setRows or result.columns == "overview")
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
    if ui.paintSearch then ui.paintSearch() end   -- the result count next to the search text
    local isEmpty = #scrollData == 0
    ui.empty:SetHidden(not isEmpty)
    ui.empty:SetText(result.empty or L("EMPTY"))
    -- empty page: the page's own icon, large and faint, breathing slowly above the hint
    if ui.emptyIcon then
        ui.emptyIcon:SetHidden(not isEmpty)
        if isEmpty then
            local icon = TEX_ICON
            for _, cat in ipairs(CATEGORIES) do
                if cat.view == S.sv.view and cat.icon then icon = cat.icon break end
            end
            ui.emptyIcon:SetTexture(icon)
            local start = GetFrameTimeSeconds()
            ui.emptyIcon:SetHandler("OnUpdate", function(self)
                local wave = (1 - math.cos((GetFrameTimeSeconds() - start) / 2.4 * 2 * math.pi)) / 2   -- 0..1..0
                self:SetAlpha(0.22 + 0.2 * wave)
                self:SetScale(1 + 0.06 * wave)
            end)
        else
            ui.emptyIcon:SetHandler("OnUpdate", nil)
        end
    end
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
    ui.baseX, ui.baseY = x, y   -- where the open / close animation starts from
end

-- ---------------------------------------------------------------------------
-- Open: the window rises 16 px while fading in (0.26 s, soft ease-out), then its
-- parts settle in one after another (title + tabs, left side, right side; 50 ms
-- apart). Close: it sinks 10 px and fades out quicker (0.18 s).
-- ---------------------------------------------------------------------------
local OPEN_T, CLOSE_T, RISE_PX, SINK_PX = 0.26, 0.18, 16, 10
local PART_T, PART_DELAY, PART_GAP = 0.22, 0.08, 0.05

local function WindowParts()
    local top = { ui.titleBlock, ui.closeButton, ui.divider, ui.tabLine }
    for _, tab in pairs(ui.tabs or {}) do
        top[#top + 1] = tab
        top[#top + 1] = tab.icon
    end
    for _, diamond in ipairs(ui.tabDiamonds or {}) do top[#top + 1] = diamond end
    local left = { ui.searchBox, ui.missingToggle, ui.announceToggle, ui.tree }
    local right = { ui.back, ui.forward, ui.crumb, ui.header, ui.infoIcon, ui.progressRow, ui.columns, ui.list, ui.empty,
        ui.scopeBox, ui.divider2, ui.selectedLabel, ui.actions.wish, ui.actions.link, ui.actions.travel }
    return { top, left, right }
end

local function SetPartsAlpha(groups, alphaOf)
    for i, group in ipairs(groups) do
        local a = alphaOf(i)
        for _, part in ipairs(group) do
            if part then part:SetAlpha(a) end
        end
    end
end

local function AnimateWindow(opening)
    local win, driver = ui.win, ui.openDriver
    -- opening: where PlaceWindow put it; closing: where it is now (you may have moved it)
    local x, y
    if opening and ui.baseX then
        x, y = ui.baseX, ui.baseY
    else
        x, y = win:GetLeft(), win:GetTop()
    end
    local groups = WindowParts()
    local start = GetFrameTimeSeconds()
    local function At(dy, alpha)
        win:ClearAnchors()
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y + dy)
        win:SetAlpha(alpha)
    end
    if opening then
        At(RISE_PX, 0)
        SetPartsAlpha(groups, function() return 0 end)
        win:SetHidden(false)
        local total = PART_DELAY + PART_GAP * (#groups - 1) + PART_T
        driver:SetHandler("OnUpdate", function(self)
            local now = GetFrameTimeSeconds() - start
            local e = 1 - (1 - zo_min(now / OPEN_T, 1)) ^ 5
            At(RISE_PX * (1 - e), e)
            SetPartsAlpha(groups, function(i)
                local t = zo_clamp((now - PART_DELAY - (i - 1) * PART_GAP) / PART_T, 0, 1)
                return 1 - (1 - t) ^ 3
            end)
            if now >= total then
                At(0, 1)
                SetPartsAlpha(groups, function() return 1 end)
                self:SetHandler("OnUpdate", nil)
            end
        end)
    else
        SetPartsAlpha(groups, function() return 1 end)
        driver:SetHandler("OnUpdate", function(self)
            local t = zo_min((GetFrameTimeSeconds() - start) / CLOSE_T, 1)
            local e = t * t * t
            At(SINK_PX * e, 1 - e)
            if t >= 1 then
                self:SetHandler("OnUpdate", nil)
                if not ui.isOpen then win:SetHidden(true) end
                At(0, 1)   -- back in place for next time (hidden by then)
            end
        end)
    end
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

    -- Hover: only the emblem's ring lights up (no outline round the whole button). Press:
    -- the button dips to 95 % and springs back. Eased on a small driver control.
    local ring = icon:GetNamedChild("Ring")
    local feel = { hovered = false, pressed = false, scale = 1 }
    local driver = WINDOW_MANAGER:CreateControl("SetHunter_LauncherFeel", launcher, CT_CONTROL)
    local function FeelTick(self)
        local wantS = feel.pressed and 0.95 or 1
        feel.scale = feel.scale + (wantS - feel.scale) * 0.35
        if math.abs(wantS - feel.scale) < 0.004 then
            feel.scale = wantS
            self:SetHandler("OnUpdate", nil)
        end
        launcher:SetScale(feel.scale)
    end
    local function Feel() driver:SetHandler("OnUpdate", FeelTick) end

    launcher:SetHandler("OnMouseEnter", function(self)
        bg:SetAlpha(LAUNCHER_BG_ALPHA_HOVER)
        SetLauncherTextColor(true)
        if ring then SetHexColor(ring, COLOR.header) end
        feel.hovered = true
        Feel()
        InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 4, BOTTOMLEFT)
        SetTooltipText(InformationTooltip, L("LAUNCHER_TT"))
    end)
    launcher:SetHandler("OnMouseExit", function()
        bg:SetAlpha(LAUNCHER_BG_ALPHA)
        SetLauncherTextColor(false)
        if ring then SetHexColor(ring, COLOR.theme) end
        feel.hovered, feel.pressed = false, false
        Feel()
        ClearTooltip(InformationTooltip)
    end)
    -- Drag to move; a short click (no movement) opens / minimizes.
    launcher:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            ui.pressX, ui.pressY = self:GetLeft(), self:GetTop()
            feel.pressed = true
            Feel()
        end
    end)
    launcher:SetHandler("OnMoveStart", function()
        ClearTooltip(InformationTooltip)
        feel.pressed = false   -- dragging it: no dip
        Feel()
    end)
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
        feel.pressed = false
        Feel()
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
    -- (opening / closing plays its own click in S.Toggle)
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
        PlaySound(SOUNDS.DEFAULT_CLICK)
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

    -- credit, like a maker's mark (as in Skillbound): tiny faint "by brianmit · v1.1.0",
    -- bottom left just inside the edge, under the "Selected" line; no hover, no tooltip
    local credit = MakeLabel("SetHunter_Credit", win, "$(MEDIUM_FONT)|11|soft-shadow-thin", 300, 12, COLOR.dim)
    credit:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    credit:SetText(L("CREDIT", S.AUTHOR or "brianmit", S.VERSION or ""))
    credit:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, PAD, -2)
    -- faint by the label's own alpha (a faint text color still showed fairly bright);
    -- it's left out of the open animation's parts, so nothing sets it back to 1
    credit:SetAlpha(CREDIT_ALPHA)
    credit:SetMouseEnabled(false)
    ui.credit = credit

    -- Title and minimize "-"
    -- Title block: bronze crest with the collections icon, the name in ESO's stone-tablet
    -- font (Trajan) and a small subtitle. 42 high, like the old title, so the divider stays put.
    local title = WINDOW_MANAGER:CreateControl("SetHunter_TitleBlock", win, CT_CONTROL)
    title:SetDimensions(inner - 80, 42)
    title:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 10)
    ui.titleBlock = title
    -- runs the open / close animation (AnimateWindow)
    ui.openDriver = WINDOW_MANAGER:CreateControl("SetHunter_OpenDriver", win, CT_CONTROL)

    -- the Set Hunter emblem (shield + helmet)
    local crestBG = MakeEmblem("SetHunter_Crest", title)
    crestBG:SetAnchor(LEFT, title, LEFT, 0, -2)   -- 48 high on a 42 row: stay clear of the divider
    -- the emblem opens Set Hunter's settings (Settings > Addons > Set Hunter): under the
    -- mouse the ring lights up, the helmet turns bronze and it grows a little
    do
        local ring, helmet = crestBG:GetNamedChild("Ring"), crestBG:GetNamedChild("Helmet")
        local crest = { hovered = false, scale = 1 }
        local function Paint(hovered)
            if ring then SetHexColor(ring, hovered and COLOR.header or COLOR.theme) end
            if helmet then
                if hovered then SetHexColor(helmet, COLOR.theme) else helmet:SetColor(1, 1, 1, 1) end
            end
        end
        local function Tick(self)
            local want = crest.hovered and 1.08 or 1
            crest.scale = crest.scale + (want - crest.scale) * 0.3
            if math.abs(want - crest.scale) < 0.003 then
                crest.scale = want
                self:SetHandler("OnUpdate", nil)
            end
            self:SetScale(crest.scale)
        end
        -- the mouse is caught by an invisible area that is a direct child of the window
        -- (like the tabs, which get the mouse fine), laid over the emblem; the emblem
        -- inside the title block got no mouse events
        local hit = WINDOW_MANAGER:CreateControl("SetHunter_CrestHit", win, CT_CONTROL)
        hit:SetDimensions(EMBLEM_W + 4, EMBLEM_H + 4)
        hit:SetAnchor(CENTER, crestBG, CENTER, 0, 0)
        hit:SetMouseEnabled(true)
        hit:SetDrawLevel(10)
        hit:SetHandler("OnMouseEnter", function(self)
            crest.hovered = true
            Paint(true)
            crestBG:SetHandler("OnUpdate", Tick)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, L("MENU_SETTINGS"))
        end)
        hit:SetHandler("OnMouseExit", function()
            crest.hovered = false
            Paint(false)
            crestBG:SetHandler("OnUpdate", Tick)
            ClearTooltip(InformationTooltip)
        end)
        hit:SetHandler("OnMouseUp", function(_, button, upInside)
            if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            ClearTooltip(InformationTooltip)
            -- close first, or the window would stay over the game's settings menu
            S.Toggle(false)
            zo_callLater(S.OpenSettings, 50)
        end)
    end

    local name = MakeLabel("SetHunter_Title", title, "$(STONE_TABLET_FONT)|28|soft-shadow-thick", 400, 30, COLOR.selected)
    name:SetText(zo_strupper(L("TITLE")))
    name:SetAnchor(TOPLEFT, title, TOPLEFT, EMBLEM_W + 12, -3)
    local sub = MakeLabel("SetHunter_Subtitle", title, "$(BOLD_FONT)|12|soft-shadow-thin", 400, 14, COLOR.theme)
    sub:SetText(L("SUBTITLE"))
    sub:SetAnchor(TOPLEFT, name, BOTTOMLEFT, 2, 0)

    -- Close: an x on a tile that fades in on hover (dark bronze, bronze edge); it
    -- shrinks while pressed and springs back. Tooltip "Close".
    local minimize = WINDOW_MANAGER:CreateControl("SetHunter_Close", win, CT_CONTROL)
    minimize:SetDimensions(30, 30)
    minimize:SetMouseEnabled(true)
    minimize:SetDrawLevel(6)
    minimize:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD + 8, 13)
    ui.closeButton = minimize
    local tile = WINDOW_MANAGER:CreateControl("SetHunter_CloseTile", minimize, CT_BACKDROP)
    tile:SetAnchorFill(minimize)
    local tr, tg, tb = HexToRGB(COLOR.theme)
    tile:SetCenterColor(tr * 0.22, tg * 0.22, tb * 0.22, 1)
    tile:SetEdgeColor(tr, tg, tb, 0.7)
    tile:SetEdgeTexture("", 1, 1, 1)
    tile:SetAlpha(0)
    local cross = WINDOW_MANAGER:CreateControl("SetHunter_CloseX", minimize, CT_TEXTURE)
    cross:SetTexture("SetHunter/Textures/close.dds")
    cross:SetDimensions(16, 16)
    cross:SetAnchor(CENTER, minimize, CENTER, 0, 0)
    SetHexColor(cross, COLOR.dim)
    -- eases the tile's alpha and the button's size toward where they should be
    local closeState = { hovered = false, pressed = false, alpha = 0, scale = 1 }
    local function CloseTick(self)
        local wantA = closeState.hovered and 1 or 0
        local wantS = closeState.pressed and 0.85 or 1
        closeState.alpha = closeState.alpha + (wantA - closeState.alpha) * 0.3
        closeState.scale = closeState.scale + (wantS - closeState.scale) * 0.35
        if math.abs(wantA - closeState.alpha) < 0.01 and math.abs(wantS - closeState.scale) < 0.005 then
            closeState.alpha, closeState.scale = wantA, wantS
            self:SetHandler("OnUpdate", nil)
        end
        tile:SetAlpha(closeState.alpha)
        self:SetScale(closeState.scale)
    end
    local function Animate() minimize:SetHandler("OnUpdate", CloseTick) end
    minimize:SetHandler("OnMouseEnter", function(self)
        closeState.hovered = true
        SetHexColor(cross, COLOR.theme)
        Animate()
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
        SetTooltipText(InformationTooltip, L("CLOSE"))
    end)
    minimize:SetHandler("OnMouseExit", function()
        closeState.hovered, closeState.pressed = false, false
        SetHexColor(cross, COLOR.dim)
        Animate()
        ClearTooltip(InformationTooltip)
    end)
    minimize:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        closeState.pressed = true
        Animate()
    end)
    minimize:SetHandler("OnMouseUp", function(_, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        closeState.pressed = false
        Animate()
        if upInside then
            ClearTooltip(InformationTooltip)
            S.Toggle(false)   -- plays the click itself
        end
    end)

    -- tabs sit on the title line, right-aligned before the "-" (like ESO's menu bars)
    ui.tabs = {}
    local nextTab = minimize
    for i = #TABS, 1, -1 do
        local key = TABS[i]
        local text = zo_strupper(L(key))
        -- Trajan, like the title (the active tab glows bronze: PaintTabs)
        local tab = MakeLabel("SetHunter_Tab" .. i, win, TAB_FONT, #text * 15, 30, COLOR.dim)
        tab:SetText(text)
        tab:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        if nextTab == minimize then
            -- underline sits just on the divider under the title
            tab:SetAnchor(BOTTOMRIGHT, win, TOPRIGHT, -PAD - 34, 50)
        else
            -- right of this tab's name = left of the next tab's icon, with a small
            -- bronze diamond in the middle of the gap
            tab:SetAnchor(RIGHT, nextTab.icon, LEFT, -TAB_GAP, 0)
            local diamond = WINDOW_MANAGER:CreateControl("SetHunter_Tab" .. i .. "Diamond", win, CT_TEXTURE)
            diamond:SetTexture("SetHunter/Textures/diamond.dds")
            diamond:SetDimensions(7, 7)
            diamond:SetAnchor(CENTER, nextTab.icon, LEFT, -TAB_GAP / 2, 1)
            SetHexColor(diamond, COLOR.theme, 0.7)
            ui.tabDiamonds = ui.tabDiamonds or {}
            table.insert(ui.tabDiamonds, diamond)
        end
        tab:SetMouseEnabled(true)
        -- outline icon in front of the name (colored in PaintTabs)
        tab.icon = WINDOW_MANAGER:CreateControl("SetHunter_Tab" .. i .. "Icon", win, CT_TEXTURE)
        local size = TabIconSize(key)
        -- a bigger icon sits a little closer, so its picture keeps the same gap to the name
        tab.iconGap = TAB_ICON_GAP - (size - TAB_ICON_SIZE) / 2
        tab.icon:SetDimensions(size, size)
        tab.icon:SetAnchor(RIGHT, tab, LEFT, -tab.iconGap, 0)
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
    -- one shared underline that glides between the tabs (PaintTabs places it)
    ui.tabLine = WINDOW_MANAGER:CreateControl("SetHunter_TabLine", win, CT_TEXTURE)
    ui.tabLine:SetHeight(3)   -- the one bright accent on the faint engraved line
    SetHexColor(ui.tabLine, COLOR.theme)
    -- drives the page slide after a tab switch (SlideContent)
    ui.slideDriver = WINDOW_MANAGER:CreateControl("SetHunter_SlideDriver", win, CT_CONTROL)
    -- text widths are only known a frame later
    zo_callLater(function()
        for _, tab in pairs(ui.tabs) do tab:SetWidth(tab:GetTextWidth() + 2) end
        PaintTabs()
    end, 1)

    local divider = MakeDivider("SetHunter_Divider", win, inner, true)
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

    local divider2 = MakeDivider("SetHunter_Divider2", win, inner, true)
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
        if ui.paintSearch then ui.paintSearch() end
    end)
    ui.search = search

    -- Search field look: a dark, sunken field with the magnifier on the left; while you
    -- type in it a soft bronze glow fades in around it. With text: how many results
    -- ("12 sets") and an x that pops in to clear it.
    do
        local tr, tg, tb = HexToRGB(COLOR.theme)
        searchBox:SetCenterColor(0.055, 0.047, 0.035, 1)
        searchBox:SetEdgeColor(0.23, 0.19, 0.13, 1)
        local glow = WINDOW_MANAGER:CreateControl("SetHunter_SearchGlow", searchBox, CT_BACKDROP)
        glow:SetAnchor(TOPLEFT, searchBox, TOPLEFT, -2, -2)
        glow:SetAnchor(BOTTOMRIGHT, searchBox, BOTTOMRIGHT, 2, 2)
        glow:SetCenterColor(0, 0, 0, 0)
        glow:SetEdgeColor(tr, tg, tb, 1)
        glow:SetEdgeTexture("", 2, 2, 2)
        glow:SetAlpha(0)
        local lens = WINDOW_MANAGER:CreateControl("SetHunter_SearchLens", searchBox, CT_TEXTURE)
        lens:SetTexture("EsoUI/Art/Miscellaneous/search_icon.dds")   -- the game's own (LibShifterBox uses it too)
        lens:SetDimensions(18, 18)
        lens:SetAnchor(LEFT, searchBox, LEFT, 6, 0)
        local clear = WINDOW_MANAGER:CreateControl("SetHunter_SearchClear", searchBox, CT_TEXTURE)
        clear:SetTexture("SetHunter/Textures/close.dds")
        clear:SetDimensions(12, 12)
        clear:SetAnchor(RIGHT, searchBox, RIGHT, -8, 0)
        clear:SetHidden(true)
        -- the x gets the mouse through an invisible area that is a direct child of the
        -- window (a texture nested in the search box got no clicks, like the emblem)
        local clearHit = WINDOW_MANAGER:CreateControl("SetHunter_SearchClearHit", win, CT_CONTROL)
        clearHit:SetDimensions(22, 24)
        clearHit:SetAnchor(CENTER, clear, CENTER, 0, 0)
        clearHit:SetMouseEnabled(true)
        clearHit:SetDrawLevel(10)
        clearHit:SetHidden(true)
        local count = MakeLabel("SetHunter_SearchCount", searchBox, "ZoFontGameSmall", 70, 28, COLOR.dim)
        count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        count:SetAnchor(RIGHT, clear, LEFT, -6, 0)
        count:SetHidden(true)
        search:ClearAnchors()
        search:SetAnchor(TOPLEFT, searchBox, TOPLEFT, 30, 4)
        search:SetAnchor(BOTTOMRIGHT, searchBox, BOTTOMRIGHT, -8, -4)

        local st = { focused = false, glow = 0, pop = 0, has = false }
        local driver = WINDOW_MANAGER:CreateControl("SetHunter_SearchFeel", searchBox, CT_CONTROL)
        local function Tick(self)
            local wantG = st.focused and 1 or 0
            local wantP = st.has and 1 or 0
            st.glow = st.glow + (wantG - st.glow) * 0.22
            st.pop = st.pop + (wantP - st.pop) * 0.3
            if math.abs(wantG - st.glow) < 0.01 and math.abs(wantP - st.pop) < 0.01 then
                st.glow, st.pop = wantG, wantP
                self:SetHandler("OnUpdate", nil)
            end
            glow:SetAlpha(0.45 * st.glow)
            searchBox:SetEdgeColor(0.23 + (tr - 0.23) * st.glow, 0.19 + (tg - 0.19) * st.glow, 0.13 + (tb - 0.13) * st.glow, 1)
            -- the x pops in (a little overshoot) and the count fades in
            local p = st.pop
            clear:SetScale(0.6 + 0.4 * p + 0.15 * math.sin(p * math.pi))
            clear:SetAlpha(p)
            count:SetAlpha(p)
            clear:SetHidden(p < 0.02)
            count:SetHidden(p < 0.02)
            clearHit:SetHidden(not st.has)
        end
        local function Feel() driver:SetHandler("OnUpdate", Tick) end
        local function PaintLens()
            SetHexColor(lens, st.focused and COLOR.theme or COLOR.dim)
        end
        PaintLens()
        search:SetHandler("OnFocusGained", function() st.focused = true; PaintLens(); Feel() end)
        search:SetHandler("OnFocusLost", function() st.focused = false; PaintLens(); Feel() end)
        clearHit:SetHandler("OnMouseEnter", function(self)
            SetHexColor(clear, COLOR.theme)
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, L("SEARCH_CLEAR"))
        end)
        clearHit:SetHandler("OnMouseExit", function()
            SetHexColor(clear, COLOR.selected)
            ClearTooltip(InformationTooltip)
        end)
        clearHit:SetHandler("OnMouseUp", function(_, button, upInside)
            if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            ClearTooltip(InformationTooltip)
            PlaySound(SOUNDS.DEFAULT_CLICK)
            search:SetText("")
            search:TakeFocus()
        end)
        -- with text: room on the right for the count and the x
        function ui.paintSearch()
            local text = search:GetText() or ""
            local has = text ~= ""
            if has ~= st.has then
                st.has = has
                search:ClearAnchors()
                search:SetAnchor(TOPLEFT, searchBox, TOPLEFT, 30, 4)
                search:SetAnchor(BOTTOMRIGHT, searchBox, BOTTOMRIGHT, has and -96 or -8, -4)
                Feel()
            end
            local n = has and ui.lastResult and ui.lastResult.count
            if n then
                count:SetText(L(n == 1 and "SEARCH_COUNT_ONE" or "SEARCH_COUNT", n))
            else
                count:SetText("")
            end
        end
    end

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

    -- My items: whose items to show (our own button + picker); placed after the badges
    -- in LayoutRight
    CreateScopeButton(win)

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
            -- the game's soft "typing" tick: back / forward get clicked a lot (the normal
            -- click was too much)
            PlaySound(SOUNDS.EDIT_CLICK or SOUNDS.DEFAULT_CLICK)
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

    -- (i) after the page title: the page's explanation in a tooltip (it used to be a
    -- paragraph above the list: read once, then it only took room). A direct child of the
    -- window, so it gets the mouse (nested controls in the header didn't, like the emblem).
    do
        -- 16 px from 32 px pictures (info.dds = ring + "i", info_fill.dds = hover disc): a
        -- clean half, so it stays sharp. Until those load (new files need a full game
        -- restart) the older ring + text "i" stand in.
        local icon = WINDOW_MANAGER:CreateControl("SetHunter_InfoIcon", win, CT_CONTROL)
        icon:SetDimensions(16, 16)   -- small: it's a hint, not a button (20 looked far too big)
        icon:SetMouseEnabled(true)
        icon:SetDrawLevel(10)
        icon:SetHidden(true)
        local fill = WINDOW_MANAGER:CreateControl("SetHunter_InfoIconFill", icon, CT_TEXTURE)
        fill:SetTexture(TEX_CIRCLE)
        fill:SetAnchorFill(icon)
        SetHexColor(fill, COLOR.theme, 0)
        local ring = WINDOW_MANAGER:CreateControl("SetHunter_InfoIconRing", icon, CT_TEXTURE)
        ring:SetTexture(TEX_RING)
        ring:SetAnchorFill(icon)
        SetHexColor(ring, COLOR.theme)
        local letter = MakeLabel("SetHunter_InfoIconText", icon, "$(BOLD_FONT)|11|soft-shadow-thin", 16, 16, COLOR.theme)
        letter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        letter:SetAnchor(CENTER, icon, CENTER, 0, 0)
        letter:SetText("i")
        local hd = WINDOW_MANAGER:CreateControl("SetHunter_InfoIconHD", icon, CT_TEXTURE)
        hd:SetTexture("SetHunter/Textures/info.dds")
        hd:SetAnchorFill(icon)
        SetHexColor(hd, COLOR.theme)
        local hdFill = WINDOW_MANAGER:CreateControl("SetHunter_InfoIconHDFill", icon, CT_TEXTURE)
        hdFill:SetTexture("SetHunter/Textures/info_fill.dds")
        hdFill:SetAnchorFill(icon)
        hdFill:SetDrawLevel(0)
        hd:SetDrawLevel(1)
        local function Paint(hovered)
            local sharp = hd:IsTextureLoaded() and hdFill:IsTextureLoaded()
            hd:SetHidden(not sharp)
            hdFill:SetHidden(not sharp)
            ring:SetHidden(sharp)
            letter:SetHidden(sharp)
            fill:SetHidden(sharp)
            SetHexColor(hdFill, COLOR.theme, hovered and 0.3 or 0)
            SetHexColor(fill, COLOR.theme, hovered and 0.3 or 0)
            SetHexColor(hd, hovered and COLOR.selected or COLOR.theme)
            SetHexColor(letter, hovered and COLOR.selected or COLOR.theme)
        end
        ui.paintInfoIcon = Paint
        Paint(false)
        icon:SetHandler("OnMouseEnter", function(self)
            Paint(true)
            if not ui.infoText then return end
            InitializeTooltip(InformationTooltip, self, TOPLEFT, 0, 6, BOTTOMLEFT)
            SetTooltipText(InformationTooltip, ui.viewTitle:GetText() or "")
            -- the page text is colored dim for the old paragraph: plain in the tooltip
            local text = ui.infoText:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
            InformationTooltip:AddLine(text, "ZoFontGame", HexToRGB(COLOR.normal))
        end)
        icon:SetHandler("OnMouseExit", function()
            Paint(false)
            ClearTooltip(InformationTooltip)
        end)
        ui.infoIcon = icon
    end

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
    -- a small glass button (like the window's edge): faint fill, light top / left edge,
    -- dark right / bottom edge, cream text; bronze tint under the mouse. The frame is on
    -- the background layer, under the label's own text.
    ui.sourceLink = MakeLabel("SetHunter_SourceLink", header, "ZoFontGameSmall", 170, SOURCE_BTN_H, SOURCE_TEXT)
    ui.sourceLink:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ui.sourceLink:SetAnchor(TOPRIGHT, ui.how, BOTTOMRIGHT, 0, 4)
    ui.sourceLink:SetMouseEnabled(true)
    ui.sourceLink:SetHidden(true)
    AddGlass(ui.sourceLink, SOURCE_TEXT)
    ui.sourceLink:SetHandler("OnMouseEnter", function(self)
        self:PaintGlass(true)
        local action = SOURCE_ACTIONS[ui.sourceKey]
        if action then
            InitializeTooltip(InformationTooltip, self, BOTTOMRIGHT, 0, -6, TOPRIGHT)
            SetTooltipText(InformationTooltip, L(action.linkTip))
        end
    end)
    ui.sourceLink:SetHandler("OnMouseExit", function(self)
        self:PaintGlass(false)
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
    -- bronze, bold small caps with a faint bronze line under them, so they read as
    -- headings and not as one more line of grey text
    local COL_FONT = "$(BOLD_FONT)|13|soft-shadow-thin"
    for i, x in ipairs({ 32, 224, 352 }) do
        local label = MakeLabel("SetHunter_Col" .. i, columns, COL_FONT, 120, 20, COLOR.theme)
        label:SetAnchor(LEFT, columns, LEFT, x, 0)
        ui.columnLabels[i] = label
    end
    local last = MakeLabel("SetHunter_Col4", columns, COL_FONT, 120, 20, COLOR.theme)
    last:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    last:SetAnchor(RIGHT, columns, RIGHT, -50, 0)
    ui.columnLabels[4] = last
    -- over the set rows' kind pills
    local source = MakeLabel("SetHunter_Col5", columns, COL_FONT, SR_PILL_W + 20, 20, COLOR.theme)
    source:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    source:SetAnchor(RIGHT, columns, RIGHT, -(16 + SR_PILL_R - 10), 0)
    source:SetText(L("COL_SOURCE"))
    ui.columnLabels[5] = source
    local colRule = WINDOW_MANAGER:CreateControl("SetHunter_ColRule", columns, CT_TEXTURE)
    colRule:SetHeight(1)
    colRule:SetAnchor(BOTTOMLEFT, columns, BOTTOMLEFT, 0, 1)
    colRule:SetAnchor(BOTTOMRIGHT, columns, BOTTOMRIGHT, -16, 1)
    SetHexColor(colRule, COLOR.theme, 0.35)
    ui.columns = columns

    -- Bank button: a small glass button (like "Start a new session") with the game's bank
    -- icon + "Bank", on the badge row at the right (placed in LayoutRight). With a bank
    -- assistant: bronze, hover opens the assistant picker (one assistant: click summons
    -- it). Without one: dimmed, and its tooltip points to the nearest bank.
    local bank = MakeLabel("SetHunter_BankLink", ui.header, "ZoFontGameSmall", 80, SOURCE_BTN_H, COLOR.dim)
    bank:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    bank:SetMouseEnabled(true)
    AddGlass(bank, SOURCE_TEXT)
    ui.bankLink = bank

    local function PaintBank(hovered)
        if ui.hasBanker then
            bank:PaintGlass(hovered)
        else
            bank:PaintGlass(false, COLOR.dim, hovered and 0.85 or 0.6)
        end
    end
    function S.UpdateBankButton()
        ui.bankers = S.GetBankerAssistants()
        ui.hasBanker = #ui.bankers > 0
        -- the game's icon in its own colors
        bank:SetText(zo_iconFormat(ui.bankIcon or TEX_BANK, 20, 20) .. " " .. L("BANK_BTN"))
        bank:FitGlass()
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
    -- The game's bank symbol, but its larger map-tooltip version: the small map pin looked
    -- grainy at this size. Checked once the window is open; if that file isn't there
    -- (guessed path), the map pin stays.
    do
        local probe = WINDOW_MANAGER:CreateControl("SetHunter_BankIconProbe", win, CT_TEXTURE)
        probe:SetDimensions(1, 1)
        probe:SetAlpha(0)
        probe:SetTexture(TEX_BANK_HD)
        local started
        probe:SetHandler("OnUpdate", function(self)
            started = started or GetFrameTimeMilliseconds()
            local loaded = self:IsTextureLoaded()
            if loaded or GetFrameTimeMilliseconds() - started > 3000 then
                self:SetHandler("OnUpdate", nil)
                local w = loaded and self:GetTextureFileDimensions() or 0
                if w >= 48 then
                    ui.bankIcon = TEX_BANK_HD
                    S.UpdateBankButton()
                end
                self:SetHidden(true)
            end
        end)
    end
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
    ui.empty:SetAnchor(TOP, list, TOP, 0, 96)
    ui.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ui.empty:SetHidden(true)
    ui.emptyIcon = WINDOW_MANAGER:CreateControl("SetHunter_EmptyIcon", win, CT_TEXTURE)
    ui.emptyIcon:SetDimensions(48, 48)
    ui.emptyIcon:SetAnchor(BOTTOM, ui.empty, TOP, 0, -6)
    SetHexColor(ui.emptyIcon, COLOR.theme)
    ui.emptyIcon:SetHidden(true)

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

-- Opening / closing like the main window (user's pick A; growing out of the clicked icon
-- was tried and disliked): it rises 16 px into its place while fading in (0.26 s,
-- ease-out); closing, it sinks 10 px while fading out (0.18 s). Its place is where it
-- was last (you can move it), read on the first frame once it's laid out.
local RISE_IN_T, RISE_IN_PX, SINK_OUT_T, SINK_OUT_PX = 0.26, 16, 0.18, 10
local function RiseIn(win)
    if not win:IsHidden() and not win.fading then return end   -- already open: it just updates
    local start, fx, fy
    if win.fading and win.homeX then fx, fy = win.homeX, win.homeY end   -- reopened mid-close
    win.fading = false
    win:SetAlpha(0)
    win:SetHidden(false)
    win:SetHandler("OnUpdate", function(self)
        if not fx then fx, fy = self:GetCenter() end
        if not start then
            self.homeX, self.homeY = fx, fy
            start = GetFrameTimeSeconds()
        end
        local t = zo_min((GetFrameTimeSeconds() - start) / RISE_IN_T, 1)
        local e = 1 - (1 - t) ^ 5
        self:ClearAnchors()
        self:SetAnchor(CENTER, GuiRoot, TOPLEFT, fx, fy + RISE_IN_PX * (1 - e))
        self:SetAlpha(e)
        if t >= 1 then self:SetHandler("OnUpdate", nil) end
    end)
end

local function SinkAway(win)
    if not win or win:IsHidden() then return end
    local fx, fy = win:GetCenter()
    win.homeX, win.homeY = fx, fy
    local start = GetFrameTimeSeconds()
    win.fading = true
    win:SetHandler("OnUpdate", function(self)
        local t = zo_min((GetFrameTimeSeconds() - start) / SINK_OUT_T, 1)
        local e = t * t * t
        self:ClearAnchors()
        self:SetAnchor(CENTER, GuiRoot, TOPLEFT, fx, fy + SINK_OUT_PX * e)
        self:SetAlpha(1 - e)
        if t >= 1 then
            self:SetHandler("OnUpdate", nil)
            self:SetHidden(true)
            self:SetAlpha(1)
            -- back in its place for next time (hidden by then)
            self:ClearAnchors()
            self:SetAnchor(CENTER, GuiRoot, TOPLEFT, fx, fy)
            self.fading = false
        end
    end)
end

local function CloseQueueDialog()
    if qd.win then SinkAway(qd.win) end
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

    -- the x clicks like closing the main window (Cancel is a game button with its own click)
    local close = MakeTextButton("SetHunter_QDClose", dlg, "x", "$(BOLD_FONT)|20|soft-shadow-thin", 24,
        L("CANCEL"), function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            CloseQueueDialog()
        end)
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

    RiseIn(qd.win)
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
    if scene == SCENE_MANAGER:GetScene("bank") then
        if S.sv.bankOpen then
            OnBankScene(newState)
            return
        end
        -- not opening beside the bank: bank pieces can still be found when you open
        -- the window yourself while the bank is up
        if newState == SCENE_SHOWING then
            ui.atBank = true
        elseif newState == SCENE_HIDDEN and ui.atBank then
            ui.atBank = false
            if ui.isOpen and not ui.hiddenByMenu then S.RefreshAll() end
        end
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
        PlaySound(SOUNDS.DEFAULT_CLICK)   -- the same soft click as closing it
        ui.progressPage = nil   -- the page's progress bar fills up again on opening
        -- Home was removed again: a saved "home" page falls back to Current location
        if S.sv.view == "home" then S.sv.view, S.sv.loc = "here", nil end
        PlaceWindow()
        ui.win:SetHidden(false)
        ZO_ClearTable(reachCache)   -- new wayshrines may have been found since
        ui.reachGen = (ui.reachGen or 0) + 1   -- rows work out their shortcut again
        S.RefreshAll()
        if S.UpdateBankButton then S.UpdateBankButton() end
        SetGameCameraUIMode(true)   -- mouse cursor, but stay in the game world
        AnimateWindow(true)
    else
        PlaySound(SOUNDS.DEFAULT_CLICK)   -- however it's closed (X, button, keybind)
        CloseQueueDialog()
        if ui.hideBankPicker then ui.hideBankPicker() end
        ClosePicker()
        ClearMenu()
        ClearTooltip(InformationTooltip)
        ClearTooltip(ItemTooltip)
        ui.search:LoseFocus()
        AnimateWindow(false)
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
