InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Equipped Sets on the HUD: the page's legend (piece icon, set name, bar badges, count) in a small frame that
-- stays on screen with the bag shut. Switched from a "Show on UI" line at the foot of the
-- Equipped Sets page; the X on the panel switches it off again.
--
-- The sets are read by the page's own reading (IG.ReadEquippedSets, EquippedDrawer.lua), so the
-- panel and the legend can never count differently. The frame is the one this author's other
-- addons draw (XPBar UI.lua: worldmap_frame_edge edge, black centre, four munge strips); the
-- lock, the X and the font are LootLog's (LootLog UI.lua).
--
-- Size is never measured to lay anything out: rows have a fixed height from the font size and
-- the number shown is worked out from the saved window size after a resize has stopped, one
-- deferred pass at a time (HANDOFF: a resize inside OnRectChanged froze the game).
--
-- Taking this panel out of the addon: drop this file and its line in the manifest.

local WIN_NAME = "InventoryGroupingEquippedHud"

local EDGE_FILE   = "EsoUI/Art/WorldMap/worldmap_frame_edge.dds"
local EDGE_WIDTH  = 128
local EDGE_HEIGHT = 16
local MUNGE_FILE  = "EsoUI/Art/Tooltips/munge_overlay.dds"

-- TomesTracker's lock textures (normal, pressed, over), as LootLog uses them.
local LOCK_TEX = {
    [true]  = { "EsoUI/art/miscellaneous/locked_up.dds",   "EsoUI/art/miscellaneous/locked_down.dds",   "EsoUI/art/miscellaneous/locked_over.dds"   },
    [false] = { "EsoUI/art/miscellaneous/unlocked_up.dds", "EsoUI/art/miscellaneous/unlocked_down.dds", "EsoUI/art/miscellaneous/unlocked_over.dds" },
}
local LOCK_ALPHA_OPEN, LOCK_ALPHA_LOCKED, LOCK_ALPHA_HOVER = 0.35, 0.70, 1.0
local LOCK_SIZE = 20

local FALLBACK_FACE = "EsoUI/Common/Fonts/FTN57.slug"
local FONT_SIZE = 18
local NAME_SIZE = 20     -- set names two points over the rest
-- The bar badges after the name: a green ring with the bar's number in it, "1" for the front bar,
-- "2" for the back bar, both of them for a set worn on both. The ring is two discs, so the green is
-- exact: a pure white disc (our own art/circle_64.dds, drawn by _dev/make-inventory2-circle-dds.js
-- in the AddOns folder so the badge depends on no other addon)
-- tinted green, and the crafting station's black circle (the Equipped Sets page uses it too) laid
-- inside it, which leaves a green rim round a dark middle; the digit is the same green on that dark.
-- (The game's own passive frame is coloured art and never tinted to a clear green.)
local BADGE_RIM_TEX = "Inventory2/art/circle_64.dds"
local BADGE_DISC_TEX = "EsoUI/Art/Crafting/blackcircle.dds"
local BADGE_SIZE = 20
local BADGE_RIM = 2      -- the green rim's thickness
local BADGE_FONT = 13
local BADGE_COLOR = "2CFF3C"
local BADGE_GAP = 3      -- between the two badges
local TAG_GAP = 5        -- between the name and its first badge
local PAD = 8
local ICON = 24          -- the set's own piece icon, where the colour square was
local ICON_GAP = 6       -- between the icon and the name
local COUNT_WIDTH = 44   -- the count column's least width; a longer count widens it
local COUNT_GAP = 6      -- between the name (or its last badge) and the count column
local MAX_ROWS = 10

-- Hairlines: under the title, and between two rows. Plain colour, no texture file
-- (horizontaldivider.dds sliced to 1px draws next to nothing).
local LINE_HEADER = { 0.85, 0.85, 0.85, 0.35 }
local LINE_ROW    = { 0.85, 0.85, 0.85, 0.18 }

-- Scrollbar, when there are more sets than rows that fit.
local SCROLL_W = 8
local SCROLL_TEX = "EsoUI/Art/Miscellaneous/scrollbox_elevator.dds"

-- Which worn piece stands for the set: chest first, then the rest of the armour; the neck
-- before the rings; the weapons last (a set worn only as weapons).
local ARMOR_PICK   = { "EQUIP_SLOT_CHEST", "EQUIP_SLOT_LEGS", "EQUIP_SLOT_HEAD", "EQUIP_SLOT_SHOULDERS",
                       "EQUIP_SLOT_HAND", "EQUIP_SLOT_FEET", "EQUIP_SLOT_WAIST" }
local JEWELRY_PICK = { "EQUIP_SLOT_NECK", "EQUIP_SLOT_RING1", "EQUIP_SLOT_RING2" }
-- The weapon slots of each bar: front first, back second.
local BAR_SLOTS = {
    { slots = { "EQUIP_SLOT_MAIN_HAND", "EQUIP_SLOT_OFF_HAND" } },
    { slots = { "EQUIP_SLOT_BACKUP_MAIN", "EQUIP_SLOT_BACKUP_OFF" } },
}

local MIN_W, MIN_H, MAX_W, MAX_H = 150, 60, 600, 500
local DEFAULT_W, DEFAULT_H = 240, 150

local SETTLE = "InventoryGroupingEquippedHud"
local SETTLE_DELAY = 150

local ui = nil
local userMoved, userResized = false, false
local layoutPending = false
local lockHover = false

-- The panel's own saved state, in the addon's saved variables.
local function Sv()
    if not IG.sv then return nil end
    IG.sv.equippedHud = IG.sv.equippedHud or {}
    return IG.sv.equippedHud
end

function IG.EquippedHudShown()
    local sv = Sv()
    return sv ~= nil and sv.shown == true
end

-- LootLog's ResolveFont: AUI's quest tracker face when AUI is there, the game's own otherwise.
local function Font(style, size)
    local face = FALLBACK_FACE
    local s = _G.AUI and AUI.Settings and AUI.Settings.Questtracker
    if s and type(s.font_art) == "string" and s.font_art ~= "" then face = s.font_art end
    return face .. "|" .. (size or FONT_SIZE) .. "|" .. (style or "outline")
end

local function HeaderH() return FONT_SIZE + 12 end
local function RowH() return NAME_SIZE + 10 end

local function Line(parent, color)
    local line = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    line:SetHeight(1)
    line:SetColor(unpack(color))
    line:SetMouseEnabled(false)
    return line
end

local function Munge(parent)
    local tex = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    tex:SetTexture(MUNGE_FILE)
    if tex.SetAddressMode and TEX_MODE_WRAP then tex:SetAddressMode(TEX_MODE_WRAP) end
    return tex
end

-- XPBar/UI.lua's frame, the same calls in the same order.
local function BuildFrame(parent)
    local bg = WINDOW_MANAGER:CreateControl(WIN_NAME .. "BG", parent, CT_BACKDROP)
    bg:SetAnchorFill(parent)
    bg:SetEdgeTexture(EDGE_FILE, EDGE_WIDTH, EDGE_HEIGHT, 0, 0)
    bg:SetCenterColor(0, 0, 0, 0.6)   -- same see-through as the LootLog panel

    local top = Munge(bg)
    top:SetHeight(2)
    top:SetAnchor(TOPLEFT, bg, TOPLEFT, 4, 0)
    top:SetAnchor(TOPRIGHT, bg, TOPRIGHT, -4, 0)
    local bottom = Munge(bg)
    bottom:SetHeight(2)
    bottom:SetAnchor(BOTTOMLEFT, bg, BOTTOMLEFT, 4, 0)
    bottom:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -4, 0)
    local left = Munge(bg)
    left:SetWidth(2)
    left:SetAnchor(TOPLEFT, bg, TOPLEFT, 0, 4)
    left:SetAnchor(BOTTOMLEFT, bg, BOTTOMLEFT, 0, -4)
    local right = Munge(bg)
    right:SetWidth(2)
    right:SetAnchor(TOPRIGHT, bg, TOPRIGHT, 0, 4)
    right:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, 0, -4)
    return bg
end

-- One line: the set's own piece icon, its name, the bar badges, its count. A hairline under every
-- row but the last one shown. No ground.
local function Row(parent, index)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    row:SetHeight(RowH())
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, PAD, HeaderH() + (index - 1) * RowH())
    row:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -PAD, HeaderH() + (index - 1) * RowH())
    row:SetMouseEnabled(false)

    row.icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.icon:SetDimensions(ICON, ICON)
    row.icon:SetAnchor(TOPLEFT, row, TOPLEFT, 0, (RowH() - ICON) / 2)

    -- Pinned to the row's right edge; its width is set in the refresh to its text's own width.
    row.count = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.count:SetFont(Font())
    row.count:SetDimensions(COUNT_WIDTH, RowH())
    row.count:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    row.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    row.count:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Held between two anchors in the refresh (the icon on its left, the first badge or the count
    -- on its right), so its width is the row's real room and a long name ends in "...". Only its
    -- height is ever set: an explicit width would override the anchors.
    row.name = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.name:SetFont(Font("outline", NAME_SIZE))
    row.name:SetHeight(RowH())
    row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name:SetMaxLineCount(1)

    -- The bar badges between the name and the count, created once per row: [1] front bar, [2] back bar.
    row.badges = {}
    for bar = 1, 2 do
        local badge = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
        badge:SetDimensions(BADGE_SIZE, BADGE_SIZE)
        badge:SetMouseEnabled(false)
        badge:SetHidden(true)
        local cr, cg, cb = IG.HexToRGB(BADGE_COLOR)
        -- Drawn in creation order: the green rim, the dark middle over it, the digit over both.
        local rim = WINDOW_MANAGER:CreateControl(nil, badge, CT_TEXTURE)
        rim:SetTexture(BADGE_RIM_TEX)
        rim:SetAnchorFill(badge)
        rim:SetColor(cr, cg, cb, 1)
        local middle = WINDOW_MANAGER:CreateControl(nil, badge, CT_TEXTURE)
        middle:SetTexture(BADGE_DISC_TEX)
        middle:SetDimensions(BADGE_SIZE - 2 * BADGE_RIM, BADGE_SIZE - 2 * BADGE_RIM)
        middle:SetAnchor(CENTER, badge, CENTER, 0, 0)
        local digit = WINDOW_MANAGER:CreateControl(nil, badge, CT_LABEL)
        digit:SetFont(Font("outline", BADGE_FONT))
        digit:SetColor(cr, cg, cb, 1)
        digit:SetText(tostring(bar))
        digit:SetAnchor(CENTER, badge, CENTER, 0, 1)
        row.badges[bar] = badge
    end

    row.line = Line(row, LINE_ROW)
    row.line:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
    row.line:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
    return row
end

-- The height the rows have to share -- from the saved height, never from a measured child.
local function AvailH()
    local sv = Sv() or {}
    local h = sv.height or DEFAULT_H
    return zo_max(0, h - HeaderH() - PAD / 2)
end

-- The icon that stands for a set: the piece of it that is worn, armour (chest first) when it
-- is mostly armour, jewellery when mostly jewellery, a weapon when it is only weapons.
local function SetIcon(worn, set)
    local armor, jewelry = 0, 0
    for _, slot in ipairs(ARMOR_PICK) do
        local p = worn[slot]
        if p and p.setId == set.setId then armor = armor + 1 end
    end
    for _, slot in ipairs(JEWELRY_PICK) do
        local p = worn[slot]
        if p and p.setId == set.setId then jewelry = jewelry + 1 end
    end
    local order = (armor >= jewelry) and { ARMOR_PICK, JEWELRY_PICK } or { JEWELRY_PICK, ARMOR_PICK }
    order[3] = { BAR_SLOTS[1].slots[1], BAR_SLOTS[1].slots[2], BAR_SLOTS[2].slots[1], BAR_SLOTS[2].slots[2] }
    for _, list in ipairs(order) do
        for _, slot in ipairs(list) do
            local p = worn[slot]
            if p and p.setId == set.setId then return GetItemLinkIcon(p.link) end
        end
    end
    return set.link and GetItemLinkIcon(set.link) or nil
end

-- Which bars a set's weapons are on: front (true/nil), back (true/nil); neither when no weapon of it
-- is worn (armour and jewellery count on both bars, so those sets carry no badge).
local function SetBars(worn, set)
    local on = {}
    for i, bar in ipairs(BAR_SLOTS) do
        for _, slot in ipairs(bar.slots) do
            local p = worn[slot]
            if p and p.setId == set.setId then
                on[i] = true
                break
            end
        end
    end
    return on[1], on[2]
end

-- Scrolling over variable row heights. Returns the last first-index that may be scrolled to
-- (1 when everything fits) and whether the bar is needed.
local function ScrollMax(heights, avail)
    local total, n = 0, #heights
    for i = 1, n do total = total + heights[i] end
    if total <= avail then return 1, false end
    local f, sum = n + 1, 0
    while f > 1 and sum + heights[f - 1] <= avail do
        f = f - 1
        sum = sum + heights[f]
    end
    return zo_clamp(f, 2, zo_max(2, n)), true
end

local function ApplyScroll(total, maxFirst, needed, avail, shown)
    local bar = ui.scroll
    if needed and avail > 0 then
        ui.first = zo_clamp(ui.first or 1, 1, maxFirst)
        bar.igSetting = true
        bar:SetMinMax(1, maxFirst)
        bar:SetValue(ui.first)
        bar.igSetting = false
        bar:ClearAnchors()
        bar:SetAnchor(TOPRIGHT, ui.window, TOPRIGHT, -3, HeaderH() + 2)
        bar:SetHeight(avail - 4)
        bar:SetThumbTexture(SCROLL_TEX, SCROLL_TEX, SCROLL_TEX, SCROLL_W,
            zo_max(16, (avail - 4) * zo_max(1, shown) / total), 0, 0, 1, 1)
        bar:SetHidden(false)
        return true
    end
    ui.first = 1
    bar:SetHidden(true)
    return false
end

function IG.RefreshEquippedHud()
    if not ui or ui.window:IsHidden() and not IG.EquippedHudShown() then return end
    if not IG.ReadEquippedSets then return end
    local ok, worn, sets = pcall(IG.ReadEquippedSets)
    if not ok then
        if IG.sv and IG.sv.debug then d("[I2] equipped hud: " .. tostring(worn)) end
        return
    end
    local avail = AvailH()
    local heights = {}
    for i = 1, #sets do heights[i] = RowH() end
    local maxFirst, needed = ScrollMax(heights, avail)
    ui.first = zo_clamp(ui.first or 1, 1, maxFirst)
    -- How many rows from the first one fit the height.
    local fit, used = 0, 0
    for i = ui.first, #sets do
        if fit >= MAX_ROWS or used + heights[i] > avail then break end
        used = used + heights[i]
        fit = fit + 1
    end
    local scrolling = ApplyScroll(#sets, maxFirst, needed, avail, fit)
    local rightInset = scrolling and (PAD + SCROLL_W + 2) or PAD
    local shown, y = 0, HeaderH()
    for index = 1, fit do
        local setIndex = index + ui.first - 1
        local set = sets[setIndex]
        if not set then break end
        shown = index
        local row = ui.rows[index]
        if not row then
            row = Row(ui.window, index)
            ui.rows[index] = row
        end
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, ui.window, TOPLEFT, PAD, y)
        row:SetAnchor(TOPRIGHT, ui.window, TOPRIGHT, -rightInset, y)
        row:SetHeight(heights[setIndex])
        y = y + heights[setIndex]

        local r, g, b = IG.HexToRGB(set.color)
        row.name:SetColor(r, g, b, 1)
        row.count:SetColor(r, g, b, 1)
        local icon = SetIcon(worn, set)
        row.icon:SetTexture(icon or "")
        row.icon:SetHidden(icon == nil)
        row.name:SetText(set.label)
        local countText = set.needed > 0
            and string.format("%d/%d", set.count, set.needed)
            or tostring(set.count)
        row.count:SetText(countText)
        -- The count column is as wide as its text needs (never under COUNT_WIDTH), so a long count
        -- cannot reach back over the badges.
        ui.countProbe:SetText(countText)
        local countW = zo_max(COUNT_WIDTH, zo_ceil(ui.countProbe:GetTextWidth()) + 2)
        row.count:SetWidth(countW)
        -- Laid out by anchors only, from the right: the count on the row's right edge, the badges
        -- right to left off the count's left edge, and the name stretched from the icon to the
        -- first badge (or to the count). Nothing here depends on a width worked out in Lua, so a
        -- saved size that is not the panel's real size can no longer push a badge over the count.
        -- A shown badge hangs off the control to its right, a single anchor each; [1] stays left of [2].
        local front, back = SetBars(worn, set)
        local on = { front, back }
        local right, gap = row.count, COUNT_GAP
        for bar = 2, 1, -1 do
            local badge = row.badges[bar]
            badge:SetHidden(not on[bar])
            if on[bar] then
                badge:ClearAnchors()
                badge:SetAnchor(RIGHT, right, LEFT, -gap, 0)
                right, gap = badge, BADGE_GAP
            end
        end
        if right ~= row.count then gap = TAG_GAP end
        row.name:ClearAnchors()
        row.name:SetAnchor(LEFT, row.icon, RIGHT, ICON_GAP, 0)
        row.name:SetAnchor(RIGHT, right, LEFT, -gap, 0)
        row:SetHidden(false)
    end
    for index = 1, shown do
        local nextSet = sets[index + ui.first]
        ui.rows[index].line:SetHidden(index == shown and true or nextSet == nil)
    end
    for index = shown + 1, #ui.rows do ui.rows[index]:SetHidden(true) end
    ui.empty:SetHidden(shown > 0)
    if shown == 0 then
        ui.empty:SetText(#sets == 0 and "No sets equipped" or "")
    end
end

local function ApplyLockState()
    if not ui then return end
    local sv = Sv() or {}
    local locked = sv.locked == true
    ui.window:SetMovable(not locked)
    ui.window:SetResizeHandleSize(locked and 0 or 6)
    local tex = LOCK_TEX[locked]
    ui.lock:SetNormalTexture(tex[1]); ui.lock:SetPressedTexture(tex[2]); ui.lock:SetMouseOverTexture(tex[3])
    ui.lock:SetAlpha(lockHover and LOCK_ALPHA_HOVER or (locked and LOCK_ALPHA_LOCKED or LOCK_ALPHA_OPEN))
end

-- Saved in the window's own units: it is a top level window at scale 1, so what GetWidth and
-- GetLeft give back is what SetDimensions and SetAnchor take.
local function Place()
    local sv = Sv() or {}
    local w = zo_clamp(sv.width or DEFAULT_W, MIN_W, MAX_W)
    local h = zo_clamp(sv.height or DEFAULT_H, MIN_H, MAX_H)
    ui.window:SetDimensions(w, h)
    ui.window:ClearAnchors()
    if sv.left and sv.top then
        ui.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.left, sv.top)
    else
        ui.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 40, 300)
    end
end

local function CreateUI()
    if ui then return ui end
    local window = WINDOW_MANAGER:CreateTopLevelWindow(WIN_NAME)
    if not window then return nil end
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetScale(1)
    window:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)
    window:SetHidden(true)
    ui = { window = window, rows = {} }

    BuildFrame(window)

    local title = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    title:SetFont(Font("thick-outline"))
    -- Same box and offset as the BUILDS title so both sit the same distance above the hairline.
    title:SetAnchor(TOPLEFT, window, TOPLEFT, PAD, 6)
    title:SetHeight(FONT_SIZE + 6)
    title:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    title:SetText("|c8A8A8ASETS|r")

    -- Hairline under the title row.
    local headLine = Line(window, LINE_HEADER)
    headLine:SetAnchor(TOPLEFT, window, TOPLEFT, PAD, HeaderH() - 3)
    headLine:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PAD, HeaderH() - 3)

    -- Scrollbar: one step is one set. Shown only when the sets do not all fit.
    local scroll = WINDOW_MANAGER:CreateControl(WIN_NAME .. "Scroll", window, CT_SLIDER)
    scroll:SetOrientation(ORIENTATION_VERTICAL)
    scroll:SetWidth(SCROLL_W)
    scroll:SetMouseEnabled(true)
    scroll:SetValueStep(1)
    scroll:SetHidden(true)
    scroll:SetHandler("OnValueChanged", function(self, value)
        if self.igSetting then return end
        local v = zo_round(value)
        if v ~= ui.first then ui.first = v; IG.RefreshEquippedHud() end
    end)
    ui.scroll = scroll
    ui.first = 1
    window:SetHandler("OnMouseWheel", function(_, delta)
        if scroll:IsHidden() then return end
        local lo, hi = scroll:GetMinMax()
        local v = zo_clamp((ui.first or 1) - delta, lo, hi)
        if v ~= ui.first then ui.first = v; IG.RefreshEquippedHud() end
    end)

    -- X: neutral light grey, white under the mouse (LootLog).
    local close = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    close:SetFont(Font())
    close:SetText("|cC8C8C8X|r")
    close:SetMouseEnabled(true)
    close:SetAnchor(TOPRIGHT, window, TOPRIGHT, -PAD, 4)
    close:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then IG.SetEquippedHudShown(false) end
    end)
    close:SetHandler("OnMouseEnter", function(self) self:SetText("|cFFFFFFX|r") end)
    close:SetHandler("OnMouseExit", function(self) self:SetText("|cC8C8C8X|r") end)

    local lock = WINDOW_MANAGER:CreateControl(nil, window, CT_BUTTON)
    lock:SetDimensions(LOCK_SIZE, LOCK_SIZE)
    lock:SetAnchor(TOPRIGHT, close, TOPLEFT, -8, 1)
    lock:SetMouseEnabled(true)
    lock:SetHandler("OnMouseEnter", function() lockHover = true; ApplyLockState() end)
    lock:SetHandler("OnMouseExit", function() lockHover = false; ApplyLockState() end)
    lock:SetHandler("OnClicked", function()
        local sv = Sv()
        if sv then sv.locked = not (sv.locked == true); ApplyLockState() end
    end)
    ui.lock = lock

    -- Invisible label that only measures how wide a count is, in the count's font.
    local countProbe = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    countProbe:SetFont(Font())
    countProbe:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    countProbe:SetAlpha(0)
    countProbe:SetMouseEnabled(false)
    ui.countProbe = countProbe

    local empty = WINDOW_MANAGER:CreateControl(nil, window, CT_LABEL)
    empty:SetFont(Font())
    empty:SetColor(0.6, 0.6, 0.64, 1)
    empty:SetAnchor(TOPLEFT, window, TOPLEFT, PAD, HeaderH())
    empty:SetHidden(true)
    ui.empty = empty

    -- Position and size are saved only when the player dragged (HANDOFF: a size event at load
    -- must never write the default over the saved one). A move and a resize keep separate flags:
    -- with one shared flag, a move stop seen around a resize could clear it and the new size was
    -- then never saved (the saved width was found 40 units off the panel's real width).
    window:SetHandler("OnMoveStart", function() userMoved = true end)
    window:SetHandler("OnResizeStart", function() userResized = true end)
    window:SetHandler("OnMoveStop", function()
        if not userMoved then return end
        userMoved = false
        local sv = Sv(); if not sv then return end
        sv.left, sv.top = window:GetLeft(), window:GetTop()
    end)
    window:SetHandler("OnResizeStop", function()
        local wasUser = userResized
        userResized = false
        local sv = Sv()
        if wasUser and sv then
            sv.left, sv.top = window:GetLeft(), window:GetTop()
            sv.width, sv.height = window:GetWidth(), window:GetHeight()
        end
        -- The rows are laid again after the resize is over, one deferred pass at a time.
        if layoutPending then return end
        layoutPending = true
        zo_callLater(function()
            layoutPending = false
            IG.RefreshEquippedHud()
        end, 0)
    end)

    Place()
    ApplyLockState()

    -- On the HUD scenes only, as Speedometer/SMBuilder.lua and LootLog do.
    if ZO_HUDFadeSceneFragment then
        ui.fragment = ZO_HUDFadeSceneFragment:New(window)
        if HUD_SCENE then HUD_SCENE:AddFragment(ui.fragment) end
        if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(ui.fragment) end
    end
    return ui
end

-- Shown means: in the HUD scenes' fragments. Hidden means: out of them, so no scene can show it.
local function ApplyShown()
    local on = IG.EquippedHudShown()
    if on then CreateUI() end
    if not ui then return end
    if ui.fragment then
        if on then
            if HUD_SCENE and not HUD_SCENE:HasFragment(ui.fragment) then HUD_SCENE:AddFragment(ui.fragment) end
            if HUD_UI_SCENE and not HUD_UI_SCENE:HasFragment(ui.fragment) then HUD_UI_SCENE:AddFragment(ui.fragment) end
        else
            if HUD_SCENE then HUD_SCENE:RemoveFragment(ui.fragment) end
            if HUD_UI_SCENE then HUD_UI_SCENE:RemoveFragment(ui.fragment) end
            ui.window:SetHidden(true)
        end
    else
        ui.window:SetHidden(not on)
    end
    if on then IG.RefreshEquippedHud() end
end

function IG.SetEquippedHudShown(on)
    local sv = Sv()
    if not sv then return end
    sv.shown = on and true or false
    ApplyShown()
    local body = IG.equippedBody
    if body and body.igHudToggle then body.igHudToggle.igPaint() end
end

---------------------------------------------------------------------------
-- The switch on the Equipped Sets page
---------------------------------------------------------------------------

local TOGGLE_FONT = "$(MEDIUM_FONT)|16|soft-shadow-thin"
local TOGGLE_ON = "2CFF3C"
local DIM = "9A9AA2"
local TOGGLE_GAP = 6

local function BuildToggle(body)
    if body.igHudToggle then return end
    local toggle = WINDOW_MANAGER:CreateControl(nil, body, CT_LABEL)
    toggle:SetFont(TOGGLE_FONT)
    toggle:SetMouseEnabled(true)
    toggle:SetHandler("OnMouseEnter", function(self) self.igHover = true; self.igPaint() end)
    toggle:SetHandler("OnMouseExit", function(self) self.igHover = false; self.igPaint() end)
    toggle:SetHandler("OnMouseUp", function(_, _, upInside)
        if not upInside or not IG.sv then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        IG.SetEquippedHudShown(not IG.EquippedHudShown())
    end)
    toggle.igPaint = function()
        local on = IG.EquippedHudShown()
        toggle:SetColor(IG.HexToRGB(toggle.igHover and "FFFFFF" or DIM))
        toggle:SetText(string.format("Show on UI: |c%s%s|r", on and TOGGLE_ON or DIM, on and "ON" or "OFF"))
    end
    body.igHudToggle = toggle
end

-- Under the page's own switch, which is always the last thing the page draws.
local function PlaceToggle(body)
    local toggle, under = body.igHudToggle, body.igToggle
    if not (toggle and under) then return end
    toggle:ClearAnchors()
    toggle:SetAnchor(TOPLEFT, under, BOTTOMLEFT, 0, TOGGLE_GAP)
    toggle.igPaint()
end

local build = IG.BuildEquippedDrawer
if build then
    IG.BuildEquippedDrawer = function(body)
        build(body)
        local ok, err = pcall(function() BuildToggle(body); PlaceToggle(body) end)
        if not ok and IG.sv and IG.sv.debug then d("[I2] equipped hud: " .. tostring(err)) end
    end
end

local refresh = IG.RefreshEquippedDrawer
if refresh then
    IG.RefreshEquippedDrawer = function(body)
        refresh(body)
        pcall(PlaceToggle, body)
    end
end

---------------------------------------------------------------------------
-- Keeping up with the character, bag open or not
---------------------------------------------------------------------------

local function Redraw()
    EVENT_MANAGER:UnregisterForUpdate(SETTLE)
    IG.RefreshEquippedHud()
end

-- A gear change is a run of events, settled into one redraw: every event below pushes the one
-- pending redraw back, so it reads the gear once, after the last of them. It runs with the HUD
-- hidden too (the Armory and the bag are menu scenes), so the list is right when the HUD returns.
local function ScheduleRedraw()
    if not IG.EquippedHudShown() then return end
    EVENT_MANAGER:UnregisterForUpdate(SETTLE)
    EVENT_MANAGER:RegisterForUpdate(SETTLE, SETTLE_DELAY, Redraw)
end

-- Equipping, unequipping or swapping one piece (by hand, or an addon such as LarvalTear).
EVENT_MANAGER:RegisterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, ScheduleRedraw)
EVENT_MANAGER:AddFilterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    REGISTER_FILTER_BAG_ID, BAG_WORN)

-- An Armory build being restored changes the gear as one bulk operation, which the worn slot
-- updates above did not catch (the panel kept the old sets). The game's own character window and
-- HUD equipment status also listen for the full inventory update; that, and the restore's own
-- answer, both redraw.
EVENT_MANAGER:RegisterForEvent(SETTLE, EVENT_INVENTORY_FULL_UPDATE, ScheduleRedraw)
if EVENT_ARMORY_BUILD_RESTORE_RESPONSE then
    EVENT_MANAGER:RegisterForEvent(SETTLE, EVENT_ARMORY_BUILD_RESTORE_RESPONSE, function(_, result)
        if ARMORY_BUILD_RESTORE_RESULT_SUCCESS == nil or result == ARMORY_BUILD_RESTORE_RESULT_SUCCESS then
            ScheduleRedraw()
        end
    end)
end

-- Built at the first activation, once the saved variables are in; later activations (zoning)
-- read the gear again.
EVENT_MANAGER:RegisterForEvent(SETTLE, EVENT_PLAYER_ACTIVATED, function()
    if IG.IsEnabled and not IG.IsEnabled() then return end
    ApplyShown()
end)
