-- Skillbound_UI.lua : the main window, concept "K Nocturne alcove" on background "A
-- hearth ember" (both picked 2026-10-01):
--   ember background, gilded corners, a pointed title cartouche with the logo (sword
--   through a ring), text tabs with a gliding amber underline;
--   left: build cards (folders, layers indented, star = favorite, dot = needs you);
--   middle: the build's gear in a lit arch around a figure (back bar below);
--   right: name, sets, skill bars, champion stars as three small constellations, food
--   and mundus medallions, the build check, part toggles, the pointed Wear plate.
-- Every interaction animates with the shared motion language (Skillbound_Anim.lua):
-- the window rises and fades in (280 ms) and out (180 ms), rows and slots arrive one
-- after another, the selection and tab underline glide (220 ms), hovers ease (120 ms),
-- a slot flashes the moment its piece goes on, a sheen crosses the title when done.
-- Simple on purpose: a new player only needs "Save what I'm wearing" and "Wear".
-- Opened with the button, /sb or a keybind; Escape closes it (registered top level).

local B = Skillbound
local L = B.L
local C = B.COLOR
local W = B.W
local Anim = B.Anim
local Items, Capture = B.Items, B.Capture
local UI = {}
B.UI = UI

-- The window can be resized from every edge / corner (sv.window.w / h). Everything is
-- anchored so it follows the size: the list and the arch grow in height, the right
-- column and the "what will change" panel in width and height.
local WIN_W, WIN_H = 960, 780    -- standard size (0.6.0: taller for the Buffs row and the weapon rows; 1.0.2: bigger skills)
local MIN_W, MIN_H, MAX_W, MAX_H = 960, 760, 1400, 1000   -- (960: room for the Buffs row's Auto + Now at 40 px skills)
local HEADER_H = 110             -- cartouche + tabs
local CONTENT_Y = 116            -- content starts here (under the tabs). NOT "TOP": that is the game's anchor constant
local MINI_H = 84                -- minimized: only the title plate
local LIST_X, LIST_W = 24, 196
local CARD_H, CARD_GAP, FOLDER_H = 46, 6, 22
local ARCH_X, ARCH_W, ARCH_Y = 236, 236, 118
local RX = 494                   -- right column (its width follows the window)
local GEAR, SKILL = 38, 40       -- gear slot (arch) and skill slot sizes
local POISON = 30                -- the poison slots at the end of each weapon row
local ULT = 46                   -- the ultimate is a bit bigger, amber-framed (loadout sketch B, 2026-10-06)
local SKILL_STEP = SKILL + 8     -- distance between skill slots
local BAR_ROW = ULT + 6          -- distance between the loadout rows

local ui = { rows = {}, slots = {}, skills = {}, chips = {}, ruleRows = {}, stars = {} }
local listOffset = 0
local listData = {}
local CompareMenu   -- (defined with the compare panel, used by the build menu above it)

local PARTS_SHOWN = {
    { "gear", "PART_GEAR" }, { "skills", "PART_SKILLS" }, { "cp", "PART_CP" }, { "food", "PART_FOOD" },
    { "quick", "PART_QUICK" }, { "outfit", "PART_OUTFIT" }, { "title", "PART_TITLE" },
    { "collect", "PART_COLLECT" }, { "companion", "PART_COMPANION" },
}

-- the arch (sketch B "sections" + C "set colors", 2026-10-06): the build's crest on top, then
-- ARMOR (4 + 3), JEWELRY (3), WEAPONS (front bar / back bar, each: main, off hand, its poison)
local ARMOR_ROWS = {
    { EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND },
    { EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET },
}
local JEWELRY_ROW = { EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 }
local WEAPON_ROWS = {
    { "BAR_FRONT", EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_POISON },
    { "BAR_BACK", EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF, EQUIP_SLOT_BACKUP_POISON },
}
local GEAR_GAP = 8               -- between gear slots
local ARCH_SECTIONS_Y = 204     -- ARMOR starts here (above: the crest, its class and two lines of notes)
local TABS = { { key = "builds", text = "TAB_BUILDS" }, { key = "rules", text = "TAB_RULES" }, { key = "check", text = "TAB_CHECK" } }

-- (other = only on another character: red like missing, it can't be worn from here; 0.6.9)
local STATUS_COLOR = { missing = C.bad, other = C.bad, bank = C.warn, sub = C.gold, bad = C.bad, ok = C.good }

-- champion trees: slots, color, the four dots of the little constellation (x, y in its box)
local TREES = {
    { first = 1, color = C.craft, name = "CP_TREE_CRAFT" },
    { first = 5, color = C.warfare, name = "CP_TREE_WARFARE" },
    { first = 9, color = C.fitness, name = "CP_TREE_FITNESS" },
}
local STAR_POS = { { 6, 30 }, { 36, 12 }, { 66, 28 }, { 98, 10 } }

-- ---------------------------------------------------------------------------
-- Helpers

-- the picture of a build: its own pick, else the front bar's ultimate, else the main weapon
function UI.BuildIcon(b)
    if not b then return B.LOGO end
    if b.icon then return b.icon end
    for _, cat in ipairs(Capture.BARS) do
        local e = b.skills and b.skills[cat] and b.skills[cat][Capture.ULT_SLOT]
        if e then return GetAbilityIcon(e.id) end
    end
    local p = b.gear and (b.gear[EQUIP_SLOT_MAIN_HAND] or b.gear[EQUIP_SLOT_CHEST])
    if p and p.link then return GetItemLinkIcon(p.link) end
    return B.LOGO
end

-- Favorite star: 3D faceted star (star_on.dds gold / star_off.dds grey), no glow (user
-- removed it). star:SetFav(on, animate):
--   on  + animate: pops up 1.6x with a quick turn, a yellow ring bursts out
--   off + animate: dips small
local function MakeStar(parent, size)
    local s = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    s:SetDimensions(size, size)
    s.burst = W.Tex(s, B.TEX .. "ring.dds", size, size, C.star, 0)
    s.burst:SetAnchor(CENTER, s, CENTER, 0, 0)
    s.burst:SetDrawLevel(5)
    s.burst:SetHidden(true)
    s.tex = W.Tex(s, B.TEX .. "star_off.dds", size, size)
    s.tex:SetAnchor(CENTER, s, CENTER, 0, 0)
    s.tex:SetDrawLevel(6)
    local key = W.Name("Star")
    s.key = key
    local function Rest()
        s.tex:SetScale(1)
        s.tex:SetTextureRotation(0)
        s.burst:SetHidden(true)
    end
    function s:SetFav(on, animate)
        on = on and true or false
        -- a refresh during the click animation must not cut it short
        if not animate and self.on == on and Anim.IsRunning(key) then return end
        self.on = on
        self.tex:SetTexture(B.TEX .. (on and "star_on.dds" or "star_off.dds"))
        if not animate then
            Anim.Stop(key)
            Rest()
            return
        end
        if on then
            Anim.Run(key, 560, Anim.Linear, function(p)
                local pop = Anim.Pop(math.min(1, p * 1.7))
                s.tex:SetScale(1 + 0.6 * pop)
                s.tex:SetTextureRotation((1 - Anim.Out(p)) * math.pi * 0.4)
                s.burst:SetHidden(false)
                s.burst:SetScale(1 + 1.8 * Anim.Out(p))
                s.burst:SetAlpha(0.9 * (1 - p))
            end, Rest)
        else
            Anim.Run(key, 260, Anim.Linear, function(p)
                s.tex:SetScale(1 - 0.3 * Anim.Pop(p))
            end, Rest)
        end
    end
    return s
end

local function ClassName(classId)
    if not classId or classId == 0 then return "" end
    local ok, name = pcall(GetClassName, GENDER_MALE, classId)
    return ok and B.Name(name) or ""
end

-- the build's sets, complete ones first, then by pieces
local function SetList(b)
    local list = {}
    if not b.gear then return list end
    for id, t in pairs(B.Check.SetCounts(b.gear)) do
        list[#list + 1] = { id = id, name = B.Check.SetName(t.link), n = t.n, max = t.max, full = t.n >= t.max }
    end
    table.sort(list, function(x, y)
        if x.full ~= y.full then return x.full end
        if x.n ~= y.n then return x.n > y.n end
        return x.name < y.name
    end)
    return list
end

-- one set: complete = gold name + dim count, partial = soft name + orange count
-- (2026-10-06: colored set stripes in the arch + dots here were tried and removed: the user
-- found them unneeded, the sets line already names the sets. Don't bring them back.)
local function SetText(s)
    return B.Colorize(s.full and C.gold or C.soft, s.name) .. " " .. B.Colorize(s.full and C.dim or C.warn, s.n .. "/" .. s.max)
end

-- Sets line: as many sets as fit on one line, then "+2 more" (hover: all of them)
local function PaintSets(b)
    local list = SetList(b)
    ui.setsAll = list
    local avail = ui.sets:GetWidth()
    if avail < 50 then avail = ui.detail:GetWidth() end
    local sep = B.Colorize(C.faint, "  ·  ")
    local function Build(k)
        local parts = {}
        for i = 1, k do parts[i] = SetText(list[i]) end
        local text = table.concat(parts, sep)
        if k < #list then text = text .. "   " .. B.Colorize(C.dim, L("SETS_MORE", #list - k)) end
        return text
    end
    local text = Build(#list)
    for k = #list, 1, -1 do
        text = Build(k)
        ui.setsMeasure:SetText(text)
        local w = ui.setsMeasure:GetTextWidth()
        if w < 5 then w = #(text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")) * 7 end   -- (not measured yet: guess)
        if w <= avail then break end
    end
    ui.sets:SetText(text)
end

local function SetsTooltip()
    local list = ui.setsAll or {}
    if #list == 0 then return nil end
    local lines = { B.Colorize(C.text, L("SETS_TT_HEAD")) }
    for _, s in ipairs(list) do
        lines[#lines + 1] = SetText(s) .. (s.full and "" or ("  " .. B.Colorize(C.dim, L("SETS_TT_MISSING", s.max - s.n))))
    end
    return table.concat(lines, "\n")
end

local function CheckLine(line)
    return B.Dot(line.level == "bad" and C.bad or C.warn) .. " " .. line.text
end

local function IsWorn(b)
    local c = B.Char()
    return b and (c.worn == b.id or c.layer == b.id)
end

local function QualityColor(q)
    local c = GetItemQualityColor(q or ITEM_DISPLAY_QUALITY_NORMAL)
    return { r = c.r, g = c.g, b = c.b }
end

-- square slot: dark, quality glow at the bottom, frame, hover light, flash light
local function SquareSlot(parent, size)
    local c = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    c:SetDimensions(size, size)
    c:SetMouseEnabled(true)
    c.bg = W.Tex(c)
    c.bg:SetAnchorFill(c)
    c.bg:SetColor(B.RGBA(C.slot, 0.92))
    c.icon = W.Tex(c, nil, size - 6, size - 6)
    c.icon:SetAnchor(CENTER, c, CENTER, 0, 0)
    c.icon:SetHidden(true)   -- (a texture without a picture draws as a white square)
    c.quality = W.Tex(c, B.TEX .. "fade_up.dds", size - 2, math.floor(size * 0.32))
    c.quality:SetHidden(true)
    c.quality:SetAnchor(BOTTOM, c, BOTTOM, 0, -1)
    c.quality:SetDrawLevel(2)
    c.frame = W.Frame(c, C.edge, 1)
    c.hover = W.Glow(c, size * 1.9, size * 1.9, C.glow, 0)
    c.hover:SetAnchor(CENTER, c, CENTER, 0, 0)
    c.hover:SetDrawLevel(4)
    c.flash = W.Glow(c, size * 2.6, size * 2.6, C.theme, 0)
    c.flash:SetAnchor(CENTER, c, CENTER, 0, 0)
    c.flash:SetDrawLevel(5)
    c.flash:SetHidden(true)
    c.hoverKey = W.Name("SlotHover")
    function c:Light(on)
        local from = self.hover:GetAlpha()
        Anim.Run(self.hoverKey, Anim.MICRO, Anim.Out, function(p) self.hover:SetAlpha(Anim.Lerp(from, on and 0.35 or 0, p)) end)
    end
    return c
end

-- ---------------------------------------------------------------------------
-- Build list (left): cards + folder headers, a gliding selection

local function RebuildListData()
    listData = {}
    local byFolder, folders, children = {}, {}, {}
    for _, b in ipairs(B.SortedBuilds()) do
        if b.parent and B.Get(b.parent) then
            children[b.parent] = children[b.parent] or {}
            table.insert(children[b.parent], b)
        else
            local f = b.folder or ""
            if not byFolder[f] then
                byFolder[f] = {}
                folders[#folders + 1] = f
            end
            table.insert(byFolder[f], b)
        end
    end
    table.sort(folders, function(a, b)
        if a == "" then return false end
        if b == "" then return true end
        return zo_strlower(a) < zo_strlower(b)
    end)
    local collapsed = B.sv.window.collapsed or {}
    for _, f in ipairs(folders) do
        if f ~= "" or #folders > 1 then
            listData[#listData + 1] = { folder = f, name = f ~= "" and f or L("FOLDER_NONE") }
        end
        if not collapsed[f] then
            for _, b in ipairs(byFolder[f]) do
                listData[#listData + 1] = { build = b }
                for _, child in ipairs(children[b.id] or {}) do
                    listData[#listData + 1] = { build = child, layer = true }
                end
            end
        end
    end
end

-- name + notes, for the tooltips of build cards and the button's favorite slots
function UI.NoteTooltip(b, hint)
    local lines = { B.Colorize(C.text, b.name), B.Colorize(C.dim, zo_strupper(L("SAVE_NOTES"))), B.Colorize(C.soft, b.note) }
    if hint then lines[#lines + 1] = B.Colorize(C.dim, hint) end
    return table.concat(lines, "\n")
end

local function CardSub(b)
    if IsWorn(b) then return B.Colorize(C.theme, L("WORN_NOW")) end
    if b.parent and B.Get(b.parent) then return L("LAYER_OF", B.Get(b.parent).name) end
    if b.classId and b.classId ~= GetUnitClassId("player") then return B.Colorize(C.dim, ClassName(b.classId)) end
    return ClassName(b.classId)
end

local function PaintRow(row)
    local d = row.data
    if not d then
        row:SetHidden(true)
        return
    end
    row:SetHidden(false)
    local isFolder = d.folder ~= nil
    row:SetHeight(isFolder and FOLDER_H or CARD_H)
    row.bg:SetHidden(isFolder)
    row.frame:SetHidden(isFolder)
    row.icon:SetHidden(isFolder)
    row.iconFrame:SetHidden(isFolder)
    row.sub:SetHidden(isFolder)
    row.del:SetHidden(isFolder or not row.hover)
    if isFolder then
        row.fav:SetHidden(true)
        row.dot:SetHidden(true)
        local collapsed = (B.sv.window.collapsed or {})[d.folder]
        row.name:SetText((collapsed and "+  " or "-  ") .. zo_strupper(d.name))
        row.name:SetFont(B.Font("head", 12))
        row.name:SetColor(B.RGBA(row.hover and C.text or C.dim))
        row.name:ClearAnchors()
        row.name:SetAnchor(LEFT, row, LEFT, 4, 0)
        return
    end
    local b = d.build
    local selected = ui.sel == b.id
    row.bg:SetColor(B.RGBA(row.hover and C.hover or C.card, 0.82))
    row.frame:SetFrameColor(row.hover and C.goldDark or C.line, 1)
    local indent = d.layer and 14 or 0
    row.icon:SetTexture(UI.BuildIcon(b))
    row.iconFrame:SetFrameColor(IsWorn(b) and C.theme or C.goldDark, 1)
    Anim.Anchor(row.iconHolder, LEFT, row, LEFT, 8 + indent, 0)
    row.name:SetFont(B.Font("name", 12))
    row.name:SetText(b.name)
    row.name:SetColor(B.RGBA(selected and C.text or C.soft))
    row.name:ClearAnchors()
    row.name:SetAnchor(TOPLEFT, row.iconHolder, TOPRIGHT, 9, -1)
    row.name:SetAnchor(RIGHT, row, RIGHT, -26, 0)
    row.sub:SetText(CardSub(b))
    local fav = B.IsFavorite(b.id)
    if row.favId ~= b.id then row.fav.on = nil end   -- (rows are reused for other builds)
    row.favId = b.id
    row.fav:SetHidden(not (fav or row.hover or Anim.IsRunning(row.fav.key or "")))
    row.fav:SetFav(fav, false)
    local level = IsWorn(b) and B.Check.Level()
    row.dot:SetHidden(not level)
    if level then row.dot:SetColor(B.RGBA(level == "bad" and C.bad or C.warn)) end
end

-- the selection frame glides to the picked card
local function MoveSelector(instant)
    local target
    for _, row in ipairs(ui.rows) do
        if not row:IsHidden() and row.data and row.data.build and row.data.build.id == ui.sel then target = row end
    end
    ui.selector:SetHidden(target == nil)
    if not target then return end
    local y = target:GetTop() - ui.list:GetTop()
    local from = ui.selectorY or y
    ui.selectorY = y
    if instant or from == y then
        Anim.Stop("Skillbound_Selector")
        Anim.Offset(ui.selector, 0, y)
        return
    end
    Anim.Run("Skillbound_Selector", Anim.STD, Anim.InOut, function(p)
        Anim.Offset(ui.selector, 0, Anim.Lerp(from, y, p))
    end)
end

function UI.RefreshList(instantSelector)
    if not ui.win then return end
    RebuildListData()
    local maxH = ui.list:GetHeight()
    listOffset = zo_clamp(listOffset, 0, math.max(0, #listData - 1))
    local y = 0
    for i, row in ipairs(ui.rows) do
        local d = listData[i + listOffset]
        local h = d and (d.folder and FOLDER_H or CARD_H) or CARD_H
        if d and y + h <= maxH then
            row.data = d
            Anim.Anchor(row, TOPLEFT, ui.list, TOPLEFT, 0, y)
            y = y + h + CARD_GAP
        else
            row.data = nil
        end
        PaintRow(row)
    end
    ui.empty:SetHidden(#listData > 0)
    B.Later(function() MoveSelector(instantSelector) end, 1)   -- positions are known a frame later
end

local function BuildMenu(b, anchor)
    ClearMenu()
    -- (0.6.7, user: "a long list": only what has no button of its own. Wear, favorite, rename
    -- (click the name), overwrite, share and link in chat (the Share window) are on screen already)
    AddMenuItem(L("MENU_ICON"), function() B.Save.Open(b) end)
    AddMenuItem(L((b.note and b.note ~= "") and "MENU_NOTES_EDIT" or "MENU_NOTES_ADD"), function() B.Save.Open(b, true) end)
    -- (a menu opened from a menu click closes right away: open it a moment later)
    AddMenuItem(L("MENU_FOLDER"), function() B.Later(function() UI.FolderMenu(b) end, 50) end)
    AddMenuItem(L("MENU_COMPARE"), function() B.Later(function() CompareMenu(b) end, 50) end)
    AddMenuItem(L("MENU_LEARN"), function() B.Learn.Ask(b) end)
    if not b.parent then AddMenuItem(L("MENU_LAYER"), function() UI.NewLayer(b) end) end
    AddMenuItem(L("MENU_COPY"), function() UI.Duplicate(b) end)
    if B.Bank and IsBankOpen() then AddMenuItem(L("BANK_TAKE_OUT"), function() B.Bank.TakeOut(b) end) end
    AddMenuItem(L("MENU_DELETE"), function() UI.AskDelete(b) end)
    ShowMenu(anchor)
end

-- "Delete <build>? This can't be undone." (the card's X and the build menu)
function UI.AskDelete(b)
    W.Confirm(L("TITLE"), L("DELETE_ASK", b.name), function()
        B.DeleteBuild(b.id)
        if ui.sel == b.id then ui.sel = nil end
        UI.Refresh()
    end)
end

local function MakeRow(parent)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    row:SetDimensions(LIST_W, CARD_H)
    row:SetMouseEnabled(true)
    row.bg = W.Tex(row)
    row.bg:SetAnchorFill(row)
    row.frame = W.Frame(row, C.line, 1)
    row.iconHolder = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
    row.iconHolder:SetDimensions(30, 30)
    row.icon = W.Tex(row.iconHolder, nil, 28, 28)
    row.icon:SetAnchor(CENTER, row.iconHolder, CENTER, 0, 0)
    row.iconFrame = W.Frame(row.iconHolder, C.goldDark, 1)
    row.name = W.Label(row, B.Font("text", 14), C.soft, "")
    row.name:SetMaxLineCount(1)
    row.sub = W.Label(row, B.Font("text", 11), C.dim, "")
    row.sub:SetAnchor(TOPLEFT, row.name, BOTTOMLEFT, 0, 0)
    row.sub:SetMaxLineCount(1)
    row.fav = MakeStar(row, 18)   -- favorite star (grey on hover = click to add)
    row.fav:SetAnchor(RIGHT, row, RIGHT, -6, 0)
    row.dot = W.Tex(row, B.TEX .. "disc.dds", 8, 8, C.bad)
    row.dot:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -6, -5)   -- (top right is the X now)
    -- delete: a small amber X in the top-right corner, only while hovered (clicks found by
    -- position like the star: a mouse-enabled child would end the card's hover)
    row.del = W.Tex(row, B.TEX .. "x.dds", 11, 11, C.theme)
    row.del:SetAnchor(TOPRIGHT, row, TOPRIGHT, -4, 3)
    row.del:SetDrawLevel(6)
    row.del:SetHidden(true)
    row:SetHandler("OnMouseEnter", function()
        row.hover = true
        PaintRow(row)
        -- the build's notes (only when it has some), left of the card
        local b = row.data and row.data.build
        if b and b.note and b.note ~= "" then
            InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
            SetTooltipText(InformationTooltip, UI.NoteTooltip(b))
        end
    end)
    row:SetHandler("OnMouseExit", function()
        row.hover = false
        PaintRow(row)
        ClearTooltip(InformationTooltip)
    end)
    row:SetHandler("OnMouseWheel", function(_, delta) UI.Scroll(-delta) end)
    row:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or not row.data then return end
        local d = row.data
        if d.folder then
            B.sv.window.collapsed = B.sv.window.collapsed or {}
            B.sv.window.collapsed[d.folder] = not B.sv.window.collapsed[d.folder] or nil
            PlaySound(SOUNDS.DEFAULT_CLICK)
            UI.RefreshList(true)
            return
        end
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            BuildMenu(d.build, row)
        elseif not row.del:IsHidden() and B.IsOver(row.del, 4) then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(InformationTooltip)
            UI.AskDelete(d.build)
        elseif B.IsOver(row.fav, 5) then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            B.ToggleFavorite(d.build.id)
            row.fav:SetFav(B.IsFavorite(d.build.id), true)
            if d.build.id == ui.sel then ui.favBtn.star:SetFav(B.IsFavorite(d.build.id), true) end
        else
            PlaySound(SOUNDS.DEFAULT_CLICK)
            UI.Select(d.build.id)
        end
    end)
    row:SetHandler("OnMouseDoubleClick", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and row.data and row.data.build then
            -- two quick clicks on the star or the X are two clicks there, not "wear this build"
            if B.IsOver(row.fav, 5) or (not row.del:IsHidden() and B.IsOver(row.del, 4)) then return end
            UI.AskWear(row.data.build, { preview = true })
        end
    end)
    return row
end

function UI.Scroll(delta)
    listOffset = listOffset + delta
    UI.RefreshList(true)
end

-- ---------------------------------------------------------------------------
-- Build actions

-- "My Nightblade build", or "... 2", "... 3" when that name is taken already
function UI.DefaultName()
    local base = L("SAVE_DEFAULT", ClassName(GetUnitClassId("player")))
    local taken = {}
    for _, b in pairs(B.sv.builds) do taken[zo_strlower(b.name or "")] = true end
    if not taken[zo_strlower(base)] then return base end
    local n = 2
    while taken[zo_strlower(base .. " " .. n)] do n = n + 1 end
    return base .. " " .. n
end

-- saves what you wear as a new build: only the parts that are on (the save window's switches)
function UI.SaveBuild(name, parts, icon, note)
    local b = Capture.Build(name, parts, true)
    b.icon = icon
    b.note = note
    B.sv.builds[b.id] = b
    local c = B.Char()
    c.worn, c.layer = b.id, nil
    if #c.fav < (B.sv.launcher.slots or 4) then c.fav[#c.fav + 1] = b.id end
    B.callbacks:FireCallbacks("BuildsChanged")
    B.Print(L("SAVED", b.name))
    UI.Select(b.id)
    return b
end

-- name given (/sb save <name>): saves at once with the last switches; else the save window
function UI.SaveNew(name)
    if name then
        UI.SaveBuild(name, B.sv.saveParts or Capture.DEFAULT_PARTS)
    else
        B.Save.Open()
    end
end

function UI.Update(b)
    if B.Prebuff.IsActive() then
        B.Print(L("PRE_BUSY"))   -- (the buff skills are on your bar right now: they'd be saved as your skills)
        return
    end
    W.Confirm(L("TITLE"), L("UPDATE_ASK", b.name), function()
        Capture.Refresh(b, false)
        if b.parent and B.Get(b.parent) then Capture.KeepDifferences(b, B.Get(b.parent)) end
        B.callbacks:FireCallbacks("BuildsChanged")
        B.Print(L("UPDATED", b.name))
    end)
end

function UI.NewLayer(parent)
    W.AskText(L("LAYER_TITLE"), L("LAYER_ASK", parent.name), L("LAYER_DEFAULT", parent.name), function(name)
        local b = Capture.Build(name, parent.parts)
        b.parent = parent.id
        b.folder = parent.folder
        Capture.KeepDifferences(b, parent)
        B.sv.builds[b.id] = b
        B.callbacks:FireCallbacks("BuildsChanged")
        local gear, skills = Capture.Count(b)
        B.Print(L("LAYER_SAVED", b.name, gear, skills))
        UI.Select(b.id)
    end)
end

function UI.Duplicate(b)
    local copy = ZO_DeepTableCopy(b)
    copy.id = B.NewId()
    copy.name = L("COPY_NAME", b.name)
    B.sv.builds[copy.id] = copy
    B.callbacks:FireCallbacks("BuildsChanged")
    UI.Select(copy.id)
end

function UI.Rename(b)
    W.AskText(L("MENU_RENAME"), L("RENAME_ASK"), b.name, function(name)
        b.name = name
        B.callbacks:FireCallbacks("BuildsChanged")
    end)
end

function UI.FolderMenu(b)
    local folders, seen = {}, {}
    for _, x in pairs(B.sv.builds) do
        if x.folder and not seen[x.folder] then
            seen[x.folder] = true
            folders[#folders + 1] = x.folder
        end
    end
    table.sort(folders)
    ClearMenu()
    for _, f in ipairs(folders) do
        AddMenuItem(f, function()
            b.folder = f
            B.callbacks:FireCallbacks("BuildsChanged")
        end)
    end
    AddMenuItem(L("FOLDER_NEW"), function()
        W.AskText(L("MENU_FOLDER"), L("FOLDER_ASK"), "", function(name)
            b.folder = name
            B.callbacks:FireCallbacks("BuildsChanged")
        end)
    end)
    AddMenuItem(L("FOLDER_NONE"), function()
        b.folder = nil
        B.callbacks:FireCallbacks("BuildsChanged")
    end)
    ShowMenu()
end

-- pick the build's picture among its skills and gear
function UI.IconMenu(b)
    ClearMenu()
    AddMenuItem(L("ICON_AUTO"), function()
        b.icon = nil
        B.callbacks:FireCallbacks("BuildsChanged")
    end)
    local seen = {}
    local function Offer(icon, name)
        if icon and icon ~= "" and not seen[icon] then
            seen[icon] = true
            AddMenuItem(zo_iconTextFormat(icon, 22, 22, name), function()
                b.icon = icon
                B.callbacks:FireCallbacks("BuildsChanged")
            end)
        end
    end
    for _, cat in ipairs(Capture.BARS) do
        for slot = Capture.ULT_SLOT, Capture.FIRST_SLOT, -1 do
            local e = b.skills and b.skills[cat] and b.skills[cat][slot]
            if e then Offer(GetAbilityIcon(e.id), e.name) end
        end
    end
    for _, s in ipairs({ EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_HEAD, EQUIP_SLOT_CHEST }) do
        local p = b.gear and b.gear[s]
        if p and p.link then Offer(GetItemLinkIcon(p.link), B.Name(GetItemLinkName(p.link))) end
    end
    local roles = {
        { "EsoUI/Art/LFG/LFG_icon_dps.dds", "ROLE_DPS" }, { "EsoUI/Art/LFG/LFG_icon_tank.dds", "ROLE_TANK" },
        { "EsoUI/Art/LFG/LFG_icon_healer.dds", "ROLE_HEAL" }, { "/esoui/art/mainmenu/menubar_ava_up.dds", "ROLE_PVP" },
    }
    for _, r in ipairs(roles) do Offer(r[1], L(r[2])) end
    ShowMenu()
end

-- List panel (2026-10-03, sketch A "grouped list panel"; first made for the champion picker,
-- which went with One Click Champion Points (0.6.5), now the food picker): a small framed
-- panel beside what you clicked, like the gear / skill pickers. Group headers, then rows with
-- an item icon or a colored ring, the name, a small second line; what the build uses now has
-- the amber bar. Hover lights a row; a click flashes it and closes. "toggle" rows carry a switch
-- and keep the panel open. X / a click outside closes. UI.OpenListPanel(anchor, title, rows).
local CPP_W, CPP_ROW, CPP_HEAD = 320, 38, 24
local CPP_MAX_H = 5 * CPP_ROW + CPP_HEAD   -- (longer lists scroll)
local cpp = { rows = {} }

local function CloseCPPicker()
    if not cpp.win or cpp.win:IsHidden() then return end
    cpp.win:SetHidden(true)
    B.EM:UnregisterForEvent("Skillbound_CPPickClick", EVENT_GLOBAL_MOUSE_DOWN)
end

local function MakeCPRow(i)
    local r = WINDOW_MANAGER:CreateControl(nil, cpp.list, CT_CONTROL)
    r:SetMouseEnabled(true)
    r.bg = W.Tex(r, nil, nil, nil, C.hover)
    r.bg:SetAnchorFill(r)
    r.bg:SetAlpha(0)
    r.flash = W.Tex(r, nil, nil, nil, C.theme)
    r.flash:SetAnchorFill(r)
    r.flash:SetAlpha(0)
    r.mark = W.Tex(r, nil, 3, CPP_ROW - 8, C.theme)
    r.mark:SetAnchor(LEFT, r, LEFT, 0, 0)
    r.ring = W.Tex(r, B.TEX .. "ring.dds", 20, 20)
    r.ring:SetAnchor(LEFT, r, LEFT, 12, 0)
    r.core = W.Tex(r, B.TEX .. "disc.dds", 8, 8)
    r.core:SetAnchor(CENTER, r.ring, CENTER, 0, 0)
    r.iconBox = WINDOW_MANAGER:CreateControl(nil, r, CT_CONTROL)
    r.iconBox:SetDimensions(26, 26)
    r.iconBox:SetAnchor(LEFT, r, LEFT, 9, 0)
    W.Frame(r.iconBox, C.goldDark, 1)
    r.icon = W.Tex(r.iconBox, nil, 24, 24)
    r.icon:SetAnchor(CENTER, r.iconBox, CENTER, 0, 0)
    -- toggle rows: a switch on the right (the row takes the click, so the switch itself doesn't)
    r.sw = W.Switch(r, "", function() return r.data and r.data.get and r.data.get() or false end, function() end)
    r.sw:SetAnchor(RIGHT, r, RIGHT, -10, 0)
    r.sw:SetMouseEnabled(false)
    r.name = W.Label(r, B.Font("name", 12), C.text, "")
    r.name:SetAnchor(TOPLEFT, r, TOPLEFT, 42, 3)
    r.name:SetWidth(CPP_W - 70)
    r.name:SetMaxLineCount(1)
    r.sub = W.Label(r, B.Font("text", 10), C.dim, "")
    r.sub:SetAnchor(TOPLEFT, r.name, BOTTOMLEFT, 0, -2)
    r.sub:SetWidth(CPP_W - 70)
    r.sub:SetMaxLineCount(1)
    r.head = W.Label(r, B.Font("head", 11), C.dim, "")
    r.head:SetAnchor(LEFT, r, LEFT, 6, 2)
    r.line = W.Tex(r, nil, 10, 1, C.line)
    r.line:SetAnchor(LEFT, r.head, RIGHT, 8, 0)
    r.line:SetAnchor(RIGHT, r, RIGHT, -6, 2)
    r.key = W.Name("CPRow")
    r:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollListPanel(delta) end)
    r:SetHandler("OnMouseEnter", function(self)
        if not (self.data and not self.data.head) then return end
        local from = self.bg:GetAlpha()
        Anim.Run(self.key, Anim.MICRO, Anim.Out, function(p) self.bg:SetAlpha(Anim.Lerp(from, 0.9, p)) end)
        self.ring:SetScale(1.12)
    end)
    r:SetHandler("OnMouseExit", function(self)
        local from = self.bg:GetAlpha()
        Anim.Run(self.key, Anim.MICRO, Anim.Out, function(p) self.bg:SetAlpha(Anim.Lerp(from, 0, p)) end)
        self.ring:SetScale(1)
    end)
    r:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not self.data or self.data.head then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        local row = self.data
        if row.toggle then
            -- a switch row: flips, the panel stays open
            row.set(not row.get())
            self.sw:Refresh()
            return
        end
        Anim.Run(self.key .. "F", 220, Anim.Out, function(p) self.flash:SetAlpha(0.35 * (1 - p)) end,
            function()
                self.flash:SetAlpha(0)
                CloseCPPicker()
                if row.pick then row.pick() end
            end)
    end)
    cpp.rows[i] = r
    return r
end

local function CreateCPPicker()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_CPPicker")
    cpp.win = win
    win:SetWidth(CPP_W)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    local fill = W.Tex(win)
    fill:SetAnchorFill(win)
    fill:SetColor(B.RGBA(C.panel, 1))
    W.Frame(win, C.goldDark, 1)
    W.Brackets(win, 2, 6)
    local top = W.Tex(win, nil, 10, 2, C.theme, 0.9)
    top:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    cpp.title = W.Label(win, B.Font("head", 12), C.dim, "")
    cpp.title:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 11)
    local close = W.CloseButton(win, CloseCPPicker, 14, L("CLOSE"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 10)
    cpp.list = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    cpp.list:SetAnchor(TOPLEFT, win, TOPLEFT, 8, 36)
    cpp.list:SetAnchor(TOPRIGHT, win, TOPRIGHT, -8, 36)
    -- scrollbar (only for long lists): thin track + amber thumb
    cpp.track = W.Tex(cpp.list, nil, 2, 10, C.line)
    cpp.track:SetAnchor(TOPRIGHT, cpp.list, TOPRIGHT, -1, 0)
    cpp.track:SetAnchor(BOTTOMRIGHT, cpp.list, BOTTOMRIGHT, -1, 0)
    cpp.thumb = W.Tex(cpp.list, nil, 4, 20, C.theme, 0.8)
    cpp.track:SetHidden(true)
    cpp.thumb:SetHidden(true)
    win:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollListPanel(delta) end)
    -- the scrollbar's click / drag area: a direct child of the window (handlers on textures nested
    -- deeper never get the mouse), a bit wider than the thin bar so it's easy to hit
    local bar = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    bar:SetWidth(16)
    bar:SetAnchor(TOPRIGHT, cpp.list, TOPRIGHT, 6, 0)
    bar:SetAnchor(BOTTOMRIGHT, cpp.list, BOTTOMRIGHT, 6, 0)
    bar:SetDrawLevel(20)
    bar:SetMouseEnabled(true)
    bar:SetHidden(true)
    cpp.bar = bar
    bar:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollListPanel(delta) end)
    bar:SetHandler("OnMouseEnter", function() cpp.thumb:SetAlpha(1) cpp.thumb:SetWidth(6) end)
    bar:SetHandler("OnMouseExit", function()
        if not cpp.dragging then cpp.thumb:SetAlpha(0.8) cpp.thumb:SetWidth(4) end
    end)
    bar:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not cpp.scrolls then return end
        local _, my = GetUIMousePosition()
        local y = my - cpp.list:GetTop()
        local thumbY = cpp.thumbY or 0
        -- on the thumb: grab it where you clicked; on the track: the thumb jumps under the mouse
        if y >= thumbY and y <= thumbY + cpp.thumbH then
            cpp.grab = y - thumbY
        else
            cpp.grab = cpp.thumbH / 2
        end
        cpp.dragging = true
    end)
    bar:SetHandler("OnMouseUp", function()
        cpp.dragging = false
        if not B.IsOver(cpp.bar, 0) then cpp.thumb:SetAlpha(0.8) cpp.thumb:SetWidth(4) end
    end)
    -- smooth scrolling: the list glides toward cpp.target; dragging follows the mouse directly
    win:SetHandler("OnUpdate", B.Safe(function()
        if not cpp.scrolls then return end
        local now = GetFrameTimeSeconds()
        local dt = math.min(0.05, now - (cpp.lastT or now))
        cpp.lastT = now
        if cpp.dragging then
            local _, my = GetUIMousePosition()
            local room = CPP_MAX_H - cpp.thumbH
            local f = room > 0 and zo_clamp((my - cpp.list:GetTop() - cpp.grab) / room, 0, 1) or 0
            cpp.target = f * cpp.maxPos
            cpp.pos = cpp.target
            UI.PlaceListRows()
        elseif cpp.pos ~= cpp.target then
            if not Anim.Enabled() or math.abs(cpp.target - cpp.pos) < 0.5 then
                cpp.pos = cpp.target
            else
                cpp.pos = cpp.pos + (cpp.target - cpp.pos) * math.min(1, dt * 14)
            end
            UI.PlaceListRows()
        end
    end, "list panel"))
end

-- the panel with any rows: { head } | { text, sub, color (ring) or icon, nameColor, on, pick } |
-- { toggle = true, text, sub, get, set }
-- Longer lists scroll (2026-10-08): at most CPP_MAX_H of rows show. Smooth: cpp.pos (pixels)
-- glides toward cpp.target (wheel = one row per notch); the scrollbar can be dragged or clicked.
-- Controls can't clip their children, so rows at the top / bottom edge fade out as they leave
-- (gone when half outside) instead of being cut.
local function RowH(data) return data.head and CPP_HEAD or CPP_ROW end

-- where each row sits now: rows move with cpp.pos, edge rows fade
function UI.PlaceListRows()
    local h = cpp.scrolls and CPP_MAX_H or cpp.total
    for k, r in ipairs(cpp.rows) do
        local data = cpp.data[k]
        if data then
            local rh = RowH(data)
            local y = cpp.tops[k] - (cpp.pos or 0)
            local out = math.max(0, -y, y + rh - h)
            local a = 1 - out / (rh * 0.5)
            r:SetHidden(a <= 0)
            r:SetAlpha(zo_clamp(a, 0, 1))
            r:SetMouseEnabled(a > 0.6)
            r:ClearAnchors()
            r:SetAnchor(TOPLEFT, cpp.list, TOPLEFT, 0, y)
            r:SetAnchor(TOPRIGHT, cpp.list, TOPRIGHT, cpp.scrolls and -12 or 0, y)
        end
    end
    if cpp.scrolls then
        cpp.thumbH = math.max(20, h * h / cpp.total)
        cpp.thumbY = (h - cpp.thumbH) * (cpp.maxPos > 0 and cpp.pos / cpp.maxPos or 0)
        cpp.thumb:SetHeight(cpp.thumbH)
        cpp.thumb:ClearAnchors()
        cpp.thumb:SetAnchor(TOPRIGHT, cpp.list, TOPRIGHT, 0, cpp.thumbY)
    end
end

local function PaintListPanel()
    local rows = cpp.data
    cpp.tops, cpp.total = {}, 0
    for k, data in ipairs(rows) do
        cpp.tops[k] = cpp.total
        cpp.total = cpp.total + RowH(data)
    end
    cpp.scrolls = cpp.total > CPP_MAX_H
    cpp.maxPos = cpp.scrolls and cpp.total - CPP_MAX_H or 0
    cpp.target = zo_clamp(cpp.target or 0, 0, cpp.maxPos)
    cpp.pos = cpp.target
    for k, data in ipairs(rows) do
        local r = cpp.rows[k] or MakeCPRow(k)
        r.data = data
        r:SetHeight(RowH(data))
        local isHead = data.head ~= nil
        local hasIcon = not isHead and data.icon ~= nil
        local hasRing = not isHead and not hasIcon and data.color ~= nil
        r.head:SetHidden(not isHead)
        r.line:SetHidden(not isHead)
        r.name:SetHidden(isHead)
        r.sub:SetHidden(isHead)
        r.ring:SetHidden(not hasRing)
        r.core:SetHidden(not hasRing)
        r.iconBox:SetHidden(not hasIcon)
        r.sw:SetHidden(not data.toggle)
        r.mark:SetHidden(isHead or not data.on)
        r.bg:SetAlpha(0)
        r.flash:SetAlpha(0)
        if isHead then
            r.head:SetText(zo_strupper(data.head))
        else
            if hasRing then
                r.ring:SetColor(B.RGBA(data.color, 0.95))
                r.core:SetColor(B.RGBA(data.color, data.on and 1 or 0.45))
            end
            if hasIcon then r.icon:SetTexture(data.icon) end
            -- (rows without ring or icon start further left)
            r.name:ClearAnchors()
            r.name:SetAnchor(TOPLEFT, r, TOPLEFT, (hasRing or hasIcon) and 42 or 12, data.sub and 3 or 11)
            r.name:SetWidth(CPP_W - (data.toggle and 110 or 70))
            r.name:SetText(data.text)
            r.name:SetColor(B.RGBA(data.nameColor or (data.on and C.text or C.soft)))
            r.sub:SetText(data.on and B.Colorize(C.theme, data.inUse or L("CPP_IN_USE")) or (data.sub or ""))
            if data.toggle then r.sw:Refresh() end
        end
    end
    for k = #rows + 1, #cpp.rows do
        cpp.rows[k].data = nil
        cpp.rows[k]:SetHidden(true)
    end
    local h = cpp.scrolls and CPP_MAX_H or cpp.total
    cpp.list:SetHeight(h)
    cpp.win:SetHeight(36 + h + 10)
    cpp.track:SetHidden(not cpp.scrolls)
    cpp.thumb:SetHidden(not cpp.scrolls)
    cpp.bar:SetHidden(not cpp.scrolls)
    cpp.dragging = false
    UI.PlaceListRows()
end

-- mouse wheel: one row per notch, gliding
function UI.ScrollListPanel(delta)
    if not cpp.win or cpp.win:IsHidden() or not cpp.scrolls then return end
    cpp.target = zo_clamp((cpp.target or 0) - delta * CPP_ROW, 0, cpp.maxPos)
end

function UI.OpenListPanel(anchor, title, rows, below)
    if not cpp.win then CreateCPPicker() end
    if B.SkillList then B.SkillList.Close() end
    cpp.title:SetText(zo_strupper(title))
    cpp.data, cpp.target = rows, 0
    -- (opens scrolled to the row the build uses now, when that's further down)
    for k, data in ipairs(rows) do
        if data.on then cpp.target = math.max(0, (k - 3) * CPP_ROW) break end
    end
    PaintListPanel()
    cpp.win:ClearAnchors()
    if anchor then
        cpp.win:SetAnchor(TOPLEFT, anchor, TOPRIGHT, 10, -12)
    else
        cpp.win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    if below and anchor then
        -- (from the button: under the slot you clicked)
        cpp.win:ClearAnchors()
        cpp.win:SetAnchor(TOPLEFT, anchor, BOTTOMLEFT, -8, 10)
    end
    cpp.win:SetHidden(false)
    Anim.Alpha(cpp.win, 0, 1, Anim.STD, Anim.Out, "Skillbound_CPPickOpen")
    -- rows fade in one after another (only the ones fully in view: edge rows keep their edge fade)
    local n = 0
    for _, r in ipairs(cpp.rows) do
        if not r:IsHidden() and r:GetAlpha() >= 1 then
            n = n + 1
            Anim.Alpha(r, 0, 1, Anim.STD, Anim.Out, r.key .. "In", nil, n * 20, true)
        end
    end
    -- a click anywhere else closes it (checked a moment later: this very click doesn't count)
    B.Later(function()
        if not EVENT_GLOBAL_MOUSE_DOWN or cpp.win:IsHidden() then return end
        B.EM:RegisterForEvent("Skillbound_CPPickClick", EVENT_GLOBAL_MOUSE_DOWN, function()
            if not B.IsOver(cpp.win, 0) then CloseCPPicker() end
        end)
    end, 50)
end
UI.CloseCPPicker = CloseCPPicker

function UI.ListPanelOpen()
    return cpp.win ~= nil and not cpp.win:IsHidden()
end

-- The button's "+" / "Put another build here" (2026-10-08, sketch A + D's dimming): the list
-- panel under the slot. Each build with its picture and class; the worn one has the amber bar
-- ("worn now"); builds already on the button come last, dimmed, under their own header (picking
-- one moves it here). onPick(build).
function UI.PickFavorite(anchor, slotIndex, onPick)
    local fav = B.Char().fav
    local onButton = {}
    for j, id in ipairs(fav) do
        if j ~= slotIndex then onButton[id] = true end
    end
    local rows, later = {}, {}
    local function Row(b, dim)
        return {
            text = b.name,
            icon = UI.BuildIcon(b),
            sub = dim and L("FAV_ALREADY") or ClassName(b.classId),
            nameColor = dim and C.dim or nil,
            on = IsWorn(b) and not dim, inUse = L("WORN_NOW"),
            pick = function() onPick(b) end,
        }
    end
    for _, b in ipairs(B.SortedBuilds()) do
        if onButton[b.id] then later[#later + 1] = b else rows[#rows + 1] = Row(b) end
    end
    if #later > 0 then
        rows[#rows + 1] = { head = L("FAV_HEAD_ON_BUTTON") }
        for _, b in ipairs(later) do rows[#rows + 1] = Row(b, true) end
    end
    if #rows == 0 then
        rows[1] = { text = L("LIST_EMPTY_SHORT"), pick = function() UI.Show() end }
    end
    UI.OpenListPanel(anchor, L("FAV_PANEL_TITLE"), rows, true)
end

-- ---------------------------------------------------------------------------
-- The arch (gear) and the right column

local function Where(p, slot)
    local f = Items.Find(p)
    if not f then return "missing", L("WHERE_MISSING") end
    if f.other then return "other", L(f.copy and "WHERE_OTHER_COPY" or "WHERE_OTHER", f.other) end
    if f.e and f.e.bag == BAG_WORN and f.e.slot == slot then
        return f.exact and "worn" or "sub", L("WHERE_WORN")
    end
    if not f.exact then return "sub", L(f.otherTrait and "WHERE_COPY_TRAIT" or "WHERE_COPY") end
    return f.kind, Items.WhereText(f)
end

local function SlotMenu(slot)
    local b = B.Get(ui.sel)
    if not b then return end
    ClearMenu()
    AddMenuItem(L("SLOT_TAKE_WORN"), function()
        b.gear = b.gear or {}
        b.gear[slot] = Capture.Piece(BAG_WORN, slot)
        Capture.MarkPicked(b, "gear", slot, nil, false)
        B.callbacks:FireCallbacks("BuildsChanged")
    end)
    if b.gear and b.gear[slot] then
        AddMenuItem(L("SLOT_LEAVE_OUT"), function()
            b.gear[slot] = nil
            Capture.MarkPicked(b, "gear", slot, nil, false)
            B.callbacks:FireCallbacks("BuildsChanged")
        end)
    end
    ShowMenu()
end

-- Left click on a gear slot: pick another piece for this build (worn, bag or bank).
-- Changes the saved build only; Wear puts it on.
-- ---------------------------------------------------------------------------
-- Gear picker (2026-10-01, sketches A + C + search): a small panel beside the slot instead of
-- the game's long menu.
--   search box on top (filters by name as you type)
--   pieces of the sets this build already uses first, under their set name
--   "Other pieces (N)" folded; opened, they're grouped by place: Worn / In your bag / In the bank
--   each row: icon, name in its quality color, trait small and grey on the right; the piece the
--   build has now gets an amber mark. Wheel scrolls; click outside / Escape / X closes.
local PICK_W, PICK_ROW, PICK_ROWS = 360, 24, 13
local picker = {}

local function ClosePicker()
    if B.SkillList then B.SkillList.Close() end   -- (the skill and champion pickers close with it)
    CloseCPPicker()
    if not picker.win or picker.win:IsHidden() then return end
    picker.win:SetHidden(true)
    picker.edit:LoseFocus()
    B.EM:UnregisterForEvent("Skillbound_PickerClick", EVENT_GLOBAL_MOUSE_DOWN)
end

local function PickPiece(e)
    local b = B.Get(ui.sel)
    local slot = picker.slot
    if not b or not slot then return end
    b.gear = b.gear or {}
    local piece = Items.Info(e.link)
    if not Items.POISON[slot] then piece.uid = e.uid end
    b.gear[slot] = piece
    Capture.MarkPicked(b, "gear", slot, nil, true)   -- (Overwrite keeps it)
    b.parts.gear = true
    b.updated = GetTimeStamp()
    ClosePicker()
    B.callbacks:FireCallbacks("BuildsChanged")
    local c = ui.slots[slot]
    if c then Anim.Flash(c.flash, C.theme, Anim.FLASH, c.hoverKey .. "F") end
end

-- the rows to show: { head = text, toggle = true? } or { e = index entry }
local PLACE_ORDER = { { BAG_WORN, "PICK_WORN" }, { BAG_BACKPACK, "PICK_BAG" }, { "bank", "PICK_BANK" } }
local function PlaceOf(e) return (e.bag == BAG_WORN or e.bag == BAG_BACKPACK) and e.bag or "bank" end

local function PickerRows()
    local b = B.Get(ui.sel)
    local rows = {}
    local list = Items.Candidates(picker.slot)
    local q = zo_strlower(zo_strtrim(picker.query or ""))
    local function Name(e) return B.Name(GetItemLinkName(e.link)) end
    local function ByPlace(entries)
        for _, place in ipairs(PLACE_ORDER) do
            local first = true
            for _, e in ipairs(entries) do
                if PlaceOf(e) == place[1] then
                    if first then rows[#rows + 1] = { head = L(place[2]), sub = true } first = false end
                    rows[#rows + 1] = { e = e }
                end
            end
        end
    end
    if q ~= "" then
        -- searching: everything that matches, grouped by place
        local hits = {}
        for _, e in ipairs(list) do
            if zo_strlower(Name(e)):find(q, 1, true) then hits[#hits + 1] = e end
        end
        ByPlace(hits)
        if #hits == 0 then rows[1] = { head = L("PICK_NO_MATCH"), empty = true } end
        return rows
    end
    -- the build's sets first (most pieces first)
    local sets = {}
    for setId, t in pairs(b and b.gear and B.Check.SetCounts(b.gear) or {}) do
        sets[#sets + 1] = { id = setId, n = t.n, name = B.Check.SetName(t.link) }
    end
    table.sort(sets, function(x, y) if x.n ~= y.n then return x.n > y.n end return x.name < y.name end)
    local used = {}
    for _, s in ipairs(sets) do
        local first = true
        for _, e in ipairs(list) do
            if Items.EntryInfo(e).set == s.id then
                if first then rows[#rows + 1] = { head = s.name } first = false end
                rows[#rows + 1] = { e = e }
                used[e] = true
            end
        end
    end
    local rest = {}
    for _, e in ipairs(list) do if not used[e] then rest[#rest + 1] = e end end
    if #rest > 0 then
        -- (nothing from the build's sets: it starts open, see GearPicker; the click always toggles)
        if picker.otherOpen == nil then picker.otherOpen = #rows == 0 end
        local open = picker.otherOpen
        rows[#rows + 1] = { head = L("PICK_OTHER", #rest), toggle = true, open = open }
        if open then ByPlace(rest) end
    end
    if #list == 0 then rows[1] = { head = L("PICK_NONE"), empty = true } end
    return rows
end

local function MakePickRow(i)
    local r = WINDOW_MANAGER:CreateControl(nil, picker.list, CT_CONTROL)
    r:SetHeight(PICK_ROW)
    Anim.Anchor(r, TOPLEFT, picker.list, TOPLEFT, 0, (i - 1) * PICK_ROW)
    Anim.Anchor2(r, TOPRIGHT, picker.list, TOPRIGHT, 0, (i - 1) * PICK_ROW)
    r:SetMouseEnabled(true)
    r.bg = W.Tex(r, nil, nil, nil, C.hover)
    r.bg:SetAnchorFill(r)
    r.bg:SetAlpha(0)   -- (shown on hover)
    r.mark = W.Tex(r, nil, 3, PICK_ROW - 6, C.theme)
    r.mark:SetAnchor(LEFT, r, LEFT, 0, 0)
    r.icon = W.Tex(r, nil, 18, 18)
    r.icon:SetAnchor(LEFT, r, LEFT, 8, 0)
    r.name = W.Label(r, B.Font("name", 11), C.text, "")
    r.name:SetAnchor(LEFT, r.icon, RIGHT, 8, 0)
    r.name:SetMaxLineCount(1)
    r.trait = W.Label(r, B.Font("text", 10), C.dim, "", TEXT_ALIGN_RIGHT)
    r.trait:SetAnchor(RIGHT, r, RIGHT, -6, 0)
    r.head = W.Label(r, B.Font("head", 11), C.dim, "")
    r.head:SetAnchor(LEFT, r, LEFT, 4, 2)
    r.line = W.Tex(r, nil, 10, 1, C.line)
    r.line:SetAnchor(LEFT, r.head, RIGHT, 8, 2)
    r.line:SetAnchor(RIGHT, r, RIGHT, -4, 2)
    r.chev = W.Tex(r, B.TEX .. "chevron.dds", 10, 10, C.theme)
    r.chev:SetAnchor(RIGHT, r, RIGHT, -6, 2)
    r:SetHandler("OnMouseEnter", function(self)
        if self.data and (self.data.e or self.data.toggle) then self.bg:SetAlpha(0.9) end
        if self.data and self.data.e then
            InitializeTooltip(ItemTooltip, picker.win, RIGHT, -8, 0, LEFT)
            pcall(ItemTooltip.SetBagItem, ItemTooltip, self.data.e.bag, self.data.e.slot)
        end
    end)
    r:SetHandler("OnMouseExit", function(self)
        self.bg:SetAlpha(0)
        ClearTooltip(ItemTooltip)
    end)
    r:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollPicker(-delta) end)
    r:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not self.data then return end
        if self.data.e then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClearTooltip(ItemTooltip)
            PickPiece(self.data.e)
        elseif self.data.toggle then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            picker.otherOpen = not self.data.open
            UI.RefreshPicker()
        end
    end)
    picker.rows[i] = r
    return r
end

function UI.RefreshPicker()
    if not picker.win or picker.win:IsHidden() then return end
    local b = B.Get(ui.sel)
    local current = b and b.gear and b.gear[picker.slot]
    local rows = PickerRows()
    picker.offset = zo_clamp(picker.offset or 0, 0, math.max(0, #rows - PICK_ROWS))
    for i = 1, PICK_ROWS do
        local data = rows[picker.offset + i]
        local r = picker.rows[i] or MakePickRow(i)
        r.data = data
        r:SetHidden(data == nil)
        -- each row on its own: one that fails can't stop the rest (and says why, once)
        local ok, err = pcall(function()
        if data then
            local isHead = data.head ~= nil
            r.head:SetHidden(not isHead)
            r.line:SetHidden(not isHead or data.empty or data.toggle)
            r.chev:SetHidden(not data.toggle)
            r.icon:SetHidden(isHead)
            r.name:SetHidden(isHead)
            r.trait:SetHidden(isHead)
            r.mark:SetHidden(true)
            if isHead then
                r.head:SetText(data.empty and data.head or zo_strupper(data.head))
                r.head:SetFont(B.Font(data.empty and "text" or "head", data.sub and 10 or 11))
                -- set names in pewter, places (bag / bank) in soft gold, "Other pieces" in amber
                r.head:SetColor(B.RGBA(data.toggle and C.theme or (data.sub and C.dim or C.gold)))
                -- the "Other pieces" chevron points right (closed) or down (open)
                if data.toggle then r.chev:SetTextureRotation(data.open and -math.pi / 2 or 0, 0.5, 0.5) end
            else
                local info = Items.EntryInfo(data.e)
                r.icon:SetTexture(GetItemLinkIcon(data.e.link))
                r.name:SetText(B.Name(GetItemLinkName(data.e.link)))
                local qc = GetItemQualityColor(info.q or ITEM_DISPLAY_QUALITY_NORMAL)
                r.name:SetColor(qc:UnpackRGBA())
                r.trait:SetText(info.trait and info.trait ~= ITEM_TRAIT_TYPE_NONE and GetString("SI_ITEMTRAITTYPE", info.trait) or "")
                r.name:SetWidth(PICK_W - 130)
                r.mark:SetHidden(not (current and current.uid and current.uid == data.e.uid))
            end
        end
        end)
        if not ok and not picker.errorShown then
            picker.errorShown = true
            B.Print("Picker row error: " .. tostring(err))
        end
    end
    picker.more:SetHidden(picker.offset + PICK_ROWS >= #rows)
    picker.leave:SetHidden(current == nil)
end

function UI.ScrollPicker(delta)
    picker.offset = math.max(0, (picker.offset or 0) + delta * 2)
    UI.RefreshPicker()
end

local function CreatePicker()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Picker")
    picker.win = win
    picker.rows = {}
    win:SetDimensions(PICK_W, 74 + PICK_ROWS * PICK_ROW + 34)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    local fill = W.Tex(win)
    fill:SetAnchorFill(win)
    fill:SetColor(B.RGBA(C.panel, 1))
    W.Frame(win, C.goldDark, 1)
    W.Brackets(win, 2, 6)
    local top = W.Tex(win, nil, 10, 2, C.theme, 0.9)
    top:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    picker.title = W.Label(win, B.Font("head", 12), C.dim, "")
    picker.title:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 10)
    local close = W.CloseButton(win, ClosePicker, 14, L("CLOSE"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 10)
    local box, edit = W.Edit(win, PICK_W - 28, L("PICK_SEARCH"))
    box:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 32)
    edit:SetMaxInputChars(40)
    edit:SetHandler("OnTextChanged", function(self)
        picker.query = self:GetText()
        picker.offset = 0
        UI.RefreshPicker()
    end)
    edit:SetHandler("OnEscape", ClosePicker)
    picker.edit = edit
    picker.list = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    picker.list:SetAnchor(TOPLEFT, win, TOPLEFT, 10, 70)
    picker.list:SetAnchor(TOPRIGHT, win, TOPRIGHT, -10, 70)
    picker.list:SetHeight(PICK_ROWS * PICK_ROW)
    picker.list:SetMouseEnabled(true)
    picker.list:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollPicker(-delta) end)
    for i = 1, PICK_ROWS do MakePickRow(i) end   -- (all rows made up front, not while painting)
    picker.more = W.Label(win, B.Font("text", 10), C.faint, L("RULES_MORE"))
    picker.more:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -14, -10)
    picker.leave = W.Button(win, L("SLOT_LEAVE_OUT"), function()
        local b = B.Get(ui.sel)
        if b and b.gear then
            b.gear[picker.slot] = nil
            Capture.MarkPicked(b, "gear", picker.slot, nil, false)
        end
        ClosePicker()
        B.callbacks:FireCallbacks("BuildsChanged")
    end, "quiet", 260, 18)
    picker.leave:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 10, -8)
    picker.leave.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
end

local function GearPicker(slot, anchor)
    if not B.Get(ui.sel) then return end
    if not picker.win then CreatePicker() end
    picker.slot = slot
    picker.query = ""
    picker.offset = 0
    picker.otherOpen = nil   -- (decided by the first refresh: open when the build's sets have nothing here)
    picker.edit:SetText("")
    picker.title:SetText(zo_strupper(L("PICK_TITLE", Items.SlotName(slot))))
    picker.win:ClearAnchors()
    picker.win:SetAnchor(TOPLEFT, anchor, TOPRIGHT, 10, -20)
    picker.win:SetHidden(false)
    UI.RefreshPicker()
    Anim.Alpha(picker.win, 0, 1, Anim.STD, Anim.Out, "Skillbound_PickerOpen")
    picker.edit:TakeFocus()
    -- a click anywhere else closes it (checked a frame later: this very click doesn't count)
    B.Later(function()
        if not EVENT_GLOBAL_MOUSE_DOWN or picker.win:IsHidden() then return end
        B.EM:RegisterForEvent("Skillbound_PickerClick", EVENT_GLOBAL_MOUSE_DOWN, function()
            if not B.IsOver(picker.win, 0) then ClosePicker() end
        end)
    end, 50)
end
UI.ClosePicker = ClosePicker

local function MakeSlot(parent, slot, size)
    local c = SquareSlot(parent, size or GEAR)
    c.dot = W.Tex(c, B.TEX .. "disc.dds", 9, 9, C.bad)
    c.dot:SetAnchor(CENTER, c, TOPRIGHT, -2, 2)
    c.dot:SetDrawLevel(6)
    c.dot:SetHidden(true)
    c.slot = slot
    c:SetHandler("OnMouseEnter", function(self)
        local b = B.Get(ui.sel)
        local p = b and b.gear and b.gear[slot]
        if p and p.link then
            InitializeTooltip(ItemTooltip, self, RIGHT, -8, 0, LEFT)
            -- the real piece this build will use (worn / bag / bank) shows its real condition,
            -- charges, enchantment and level; the saved link can be a stand-in (share codes:
            -- condition 0 = shown as broken) or older than the item
            local f = Items.Find(p)
            local e = f and not f.other and f.e
            local shown = false
            if e and e.bag and e.slot and (e.bag == BAG_WORN or e.bag == BAG_BACKPACK or e.bag == BAG_BANK
                or e.bag == BAG_SUBSCRIBER_BANK) and GetItemId(e.bag, e.slot) ~= 0 then
                shown = pcall(ItemTooltip.SetBagItem, ItemTooltip, e.bag, e.slot)
            end
            if not shown then ItemTooltip:SetLink(p.link) end
            local status, text = Where(p, slot)
            local tc = (status == "missing" or status == "other") and C.bad or C.theme
            ItemTooltip:AddLine(text, "ZoFontGameBold", tc.r, tc.g, tc.b)
            -- a copy is used here, but the saved piece itself is on another character: say who
            local holder = status == "sub" and Items.Holder(p.uid)
            if holder then ItemTooltip:AddLine(L("WHERE_SAVED_ON", holder), "ZoFontGame", C.dim.r, C.dim.g, C.dim.b) end
            ItemTooltip:AddLine(L("SLOT_CLICK_TT"), "ZoFontGame", C.dim.r, C.dim.g, C.dim.b)
        else
            InitializeTooltip(InformationTooltip, self, RIGHT, -8, 0, LEFT)
            SetTooltipText(InformationTooltip, Items.SlotName(slot) .. "\n" .. L("SLOT_EMPTY_TT"))
        end
        self:Light(true)
    end)
    c:SetHandler("OnMouseExit", function(self)
        ClearTooltip(ItemTooltip)
        ClearTooltip(InformationTooltip)
        self:Light(false)
    end)
    c:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then return end
        ClearTooltip(ItemTooltip)
        ClearTooltip(InformationTooltip)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            SlotMenu(slot)
        elseif button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            GearPicker(slot, self)
        end
    end)
    ui.slots[slot] = c
    return c
end

local function PaintSlot(c, b)
    local p = b.gear and b.gear[c.slot]
    c.icon:SetHidden(false)
    if p and p.link then
        c.icon:SetTexture(GetItemLinkIcon(p.link))
        c.icon:SetColor(1, 1, 1, 1)
        local q = QualityColor(p.q or GetItemLinkDisplayQuality(p.link))
        c.frame:SetFrameColor(q, 0.8)
        c.quality:SetHidden(false)
        c.quality:SetColor(q.r, q.g, q.b, 0.45)
        local status = Where(p, c.slot)
        local color = STATUS_COLOR[status]
        c.dot:SetHidden(color == nil)
        if color then c.dot:SetColor(B.RGBA(color)) end
        -- not on this character (another character has it, or it's gone): the whole slot says so
        if status == "missing" or status == "other" then
            c.icon:SetColor(1, 1, 1, 0.4)
            c.frame:SetFrameColor(C.bad, 1)
            c.quality:SetColor(C.bad.r, C.bad.g, C.bad.b, 0.35)
        end
    else
        c.icon:SetTexture(Items.SLOT_ICON[c.slot])
        c.icon:SetColor(1, 1, 1, 0.2)
        c.frame:SetFrameColor(C.line, 1)
        c.quality:SetHidden(true)
        c.dot:SetHidden(true)
    end
end

local function SkillMenu(cat, slot)
    local b = B.Get(ui.sel)
    if not b then return end
    ClearMenu()
    AddMenuItem(L("SKILL_TAKE_SLOTTED"), function()
        b.skills = b.skills or {}
        b.skills[cat] = b.skills[cat] or {}
        b.skills[cat][slot] = Capture.SlotSkill(cat, slot)
        Capture.MarkPicked(b, "skills", slot, cat, false)
        B.callbacks:FireCallbacks("BuildsChanged")
    end)
    if b.skills and b.skills[cat] and b.skills[cat][slot] then
        AddMenuItem(L("SKILL_LEAVE_OUT"), function()
            b.skills[cat][slot] = nil
            Capture.MarkPicked(b, "skills", slot, cat, false)
            B.callbacks:FireCallbacks("BuildsChanged")
        end)
    end
    ShowMenu()
end

-- Left click on a skill: the skill picker (Skillbound_SkillList.lua): the skills on your bars
-- first, then every skill you've learned by skill line, with a search box. Ultimates only go
-- into the ultimate slot, normal skills only into normal slots. A pick stays when you Overwrite.
local function SkillPicker(cat, slot, anchor)
    local b = B.Get(ui.sel)
    if not b then return end
    ClosePicker()
    local current = b.skills and b.skills[cat] and b.skills[cat][slot]
    B.SkillList.Open(anchor, {
        title = L(cat == HOTBAR_CATEGORY_BACKUP and "SKL_TITLE_BACK" or "SKL_TITLE_FRONT"),
        ult = slot == Capture.ULT_SLOT,
        current = current,
        onPick = function(e)
            local cur = B.Get(ui.sel)
            if not cur then return end
            cur.skills = cur.skills or {}
            cur.skills[cat] = cur.skills[cat] or {}
            cur.skills[cat][slot] = e
            Capture.MarkPicked(cur, "skills", slot, cat, true)
            cur.parts.skills = true
            cur.updated = GetTimeStamp()
            B.callbacks:FireCallbacks("BuildsChanged")
            for _, s in ipairs(ui.skills) do
                if s.cat == cat and s.skillSlot == slot then Anim.Flash(s.flash, C.theme, Anim.FLASH, s.hoverKey .. "F") end
            end
        end,
        onClear = current and function()
            local cur = B.Get(ui.sel)
            if cur and cur.skills and cur.skills[cat] then
                cur.skills[cat][slot] = nil
                Capture.MarkPicked(cur, "skills", slot, cat, false)
                B.callbacks:FireCallbacks("BuildsChanged")
            end
        end or nil,
    })
end

local function MakeSkill(parent, cat, slot)
    local c = SquareSlot(parent, slot == Capture.ULT_SLOT and ULT or SKILL)
    c.quality:SetHidden(true)
    c:SetHandler("OnMouseEnter", function(self)
        local b = B.Get(ui.sel)
        local e = b and b.skills and b.skills[cat] and b.skills[cat][slot]
        if e then
            InitializeTooltip(AbilityTooltip, self, BOTTOM, 0, -6, TOP)
            AbilityTooltip:SetAbilityId(e.id)
            if self.problem then AbilityTooltip:AddLine(self.problem, "ZoFontGameBold", C.bad.r, C.bad.g, C.bad.b) end
            AbilityTooltip:AddLine(L("SKILL_CLICK_TT"), "ZoFontGame", C.dim.r, C.dim.g, C.dim.b)
        else
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, L("SKILL_EMPTY_TT"))
        end
        self:Light(true)
    end)
    c:SetHandler("OnMouseExit", function(self)
        ClearTooltip(AbilityTooltip)
        ClearTooltip(InformationTooltip)
        self:Light(false)
    end)
    c:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then return end
        ClearTooltip(AbilityTooltip)
        ClearTooltip(InformationTooltip)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            SkillMenu(cat, slot)
        elseif button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            SkillPicker(cat, slot, self)
        end
    end)
    c.cat, c.skillSlot = cat, slot
    ui.skills[#ui.skills + 1] = c
    return c
end

local function PaintSkill(c, b)
    local e = b.skills and b.skills[c.cat] and b.skills[c.cat][c.skillSlot]
    c.problem = nil
    local ult = c.skillSlot == Capture.ULT_SLOT
    if e then
        c.icon:SetTexture(GetAbilityIcon(e.id))
        c.icon:SetHidden(false)
        local _, _, problem = B.Apply.FindSkill(e)
        if problem == "missing" or problem == "notLearned" then
            c.problem = B.Apply.SkillProblemText(e, problem)
            c.icon:SetColor(1, 1, 1, 0.35)
            c.frame:SetFrameColor(C.bad, 1)
        else
            c.icon:SetColor(1, 1, 1, 1)
            c.frame:SetFrameColor(ult and C.theme or C.edge, 1)
        end
    else
        c.icon:SetHidden(true)
        c.frame:SetFrameColor(ult and C.goldDark or C.line, 1)
    end
end

-- Prebuff slots (the "Buffs" row): the build's buff skills, 5 at most. Click = the skill picker
-- (every skill you've learned), right-click = remove. Nothing here is slotted when you wear
-- the build: Prebuff (Auto, "Now" or the keybind) puts them on your bar for you to cast.
local function PreEntry(b, slot)
    return b and b.prebuff and b.prebuff.skills and b.prebuff.skills[slot]
end

local function SetPre(b, slot, e)
    b.prebuff = b.prebuff or { skills = {} }
    b.prebuff.skills = b.prebuff.skills or {}
    b.prebuff.skills[slot] = e
    b.updated = GetTimeStamp()
    B.callbacks:FireCallbacks("BuildsChanged")
end

local function MakePreSlot(parent, slot)
    local c = SquareSlot(parent, SKILL)
    c.quality:SetHidden(true)
    c.plus = W.Label(c, B.Font("bold", 15), C.faint, "+", TEXT_ALIGN_CENTER)
    c.plus:SetAnchor(CENTER, c, CENTER, 0, -1)
    c.preSlot = slot
    c:SetHandler("OnMouseEnter", function(self)
        local e = PreEntry(B.Get(ui.sel), slot)
        if e then
            InitializeTooltip(AbilityTooltip, self, BOTTOM, 0, -6, TOP)
            AbilityTooltip:SetAbilityId(e.id)
            AbilityTooltip:AddLine(L("PRE_SLOT_TT"), "ZoFontGame", C.dim.r, C.dim.g, C.dim.b)
        else
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, L("PRE_SLOT_EMPTY_TT"))
        end
        self:Light(true)
    end)
    c:SetHandler("OnMouseExit", function(self)
        ClearTooltip(AbilityTooltip)
        ClearTooltip(InformationTooltip)
        self:Light(false)
    end)
    c:SetHandler("OnMouseUp", function(self, button, upInside)
        local b = B.Get(ui.sel)
        if not upInside or not b then return end
        ClearTooltip(AbilityTooltip)
        ClearTooltip(InformationTooltip)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if PreEntry(b, slot) then
                ClearMenu()
                AddMenuItem(L("PRE_REMOVE"), function() SetPre(b, slot, nil) end)
                ShowMenu(self)
            end
        elseif button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            ClosePicker()
            B.SkillList.Open(self, {
                title = L("PRE_PICK_TITLE", slot - Capture.FIRST_SLOT + 1),
                ult = false,
                current = PreEntry(b, slot),
                onPick = function(e)
                    local cur = B.Get(ui.sel)
                    if not cur then return end
                    SetPre(cur, slot, e)
                    Anim.Flash(self.flash, C.theme, Anim.FLASH, self.hoverKey .. "F")
                end,
                onClear = PreEntry(b, slot) and function()
                    local cur = B.Get(ui.sel)
                    if cur then SetPre(cur, slot, nil) end
                end or nil,
                clearText = L("PRE_REMOVE"),
            })
        end
    end)
    ui.preSlots = ui.preSlots or {}
    ui.preSlots[#ui.preSlots + 1] = c
    return c
end

local function PaintPre(c, b)
    local e = PreEntry(b, c.preSlot)
    c.plus:SetHidden(e ~= nil)
    if e then
        c.icon:SetTexture(GetAbilityIcon(e.id))
        c.icon:SetHidden(false)
        local _, _, problem = B.Apply.FindSkill(e)
        local bad = problem == "missing" or problem == "notLearned"
        c.icon:SetColor(1, 1, 1, bad and 0.35 or 1)
        c.frame:SetFrameColor(bad and C.bad or C.edge, 1)
    else
        c.icon:SetHidden(true)
        c.frame:SetFrameColor(C.line, 1)
    end
end

-- Champion stars as three small constellations (green / blue / red), hover = the star
local function MakeConstellations(parent)
    for t, tree in ipairs(TREES) do
        local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
        box:SetDimensions(110, 44)
        box:SetAnchor(TOPLEFT, parent, TOPLEFT, (t - 1) * 126, 0)
        tree.lines = {}
        for i = 1, 3 do
            local a, b2 = STAR_POS[i], STAR_POS[i + 1]
            local dx, dy = b2[1] - a[1], b2[2] - a[2]
            local len = math.sqrt(dx * dx + dy * dy)
            local line = W.Tex(box, B.TEX .. "line.dds", len, len, tree.color, 0.45)
            line:SetAnchor(CENTER, box, TOPLEFT, (a[1] + b2[1]) / 2, (a[2] + b2[2]) / 2)
            line:SetTextureRotation(-math.atan2(dy, dx), 0.5, 0.5)
            tree.lines[i] = line
        end
        for i, pos in ipairs(STAR_POS) do
            local star = WINDOW_MANAGER:CreateControl(nil, box, CT_CONTROL)
            star:SetDimensions(16, 16)
            star:SetAnchor(CENTER, box, TOPLEFT, pos[1], pos[2])
            star:SetMouseEnabled(true)
            star.glow = W.Glow(star, 22, 22, tree.color, 0.35)
            star.glow:SetAnchor(CENTER, star, CENTER, 0, 0)
            star.dot = W.Tex(star, B.TEX .. "disc.dds", 7, 7, tree.color)
            star.dot:SetAnchor(CENTER, star, CENTER, 0, 0)
            star.ring = W.Tex(star, B.TEX .. "ring.dds", 9, 9, tree.color, 0.6)
            star.ring:SetAnchor(CENTER, star, CENTER, 0, 0)
            star.slotIndex = tree.first + i - 1
            star.tree = tree
            star:SetHandler("OnMouseEnter", function(self)
                InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
                local text = self.starId and B.Name(GetChampionSkillName(self.starId)) or L("CP_EMPTY_STAR")
                SetTooltipText(InformationTooltip, B.Colorize(self.tree.color, L(self.tree.name)) .. "\n" .. text)
                Anim.Pulse(self.dot, 1.6, 200)
            end)
            star:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
            ui.stars[#ui.stars + 1] = star
        end
    end
end

local function PaintConstellations(b)
    for _, star in ipairs(ui.stars) do
        local id = b.cp and b.cp.slots and b.cp.slots[star.slotIndex]
        star.starId = id
        star.dot:SetHidden(id == nil)
        star.glow:SetHidden(id == nil)
        star.ring:SetHidden(id ~= nil)
    end
end

-- food / mundus medallion: round icon in a gilded ring + two lines
local function MakeMedallion(parent)
    local m = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    m:SetDimensions(180, 34)
    m.bg = W.Tex(m, B.TEX .. "disc.dds", 32, 32, C.slot)
    m.bg:SetAnchor(LEFT, m, LEFT, 0, 0)
    m.icon = W.Tex(m, nil, 22, 22)
    m.icon:SetAnchor(CENTER, m.bg, CENTER, 0, 0)
    m.ring = W.Tex(m, B.TEX .. "ring.dds", 34, 34, C.gold, 0.8)
    m.ring:SetAnchor(CENTER, m.bg, CENTER, 0, 0)
    m.name = W.Label(m, B.Font("name", 13), C.text, "")
    m.name:SetAnchor(TOPLEFT, m.bg, TOPRIGHT, 8, -1)
    m.name:SetWidth(138)
    m.name:SetMaxLineCount(1)
    m.sub = W.Label(m, B.Font("text", 11), C.dim, "")
    m.sub:SetAnchor(TOPLEFT, m.name, BOTTOMLEFT, 0, 0)
    m.sub:SetMaxLineCount(1)
    -- text width = the room in its half of the card (see PaintMedallions)
    function m:SetTextWidth(w)
        self.name:SetWidth(w)
        self.sub:SetWidth(w)
    end
    -- "empty" (2026-10-04, sketch B): amber rim + an amber ring that spreads out and fades every
    -- 2 s, so a build without its food / drink is noticed. Stops once one is picked.
    m.ripple = W.Tex(m, B.TEX .. "ring.dds", 34, 34, C.theme, 1)
    m.ripple:SetAlpha(0)
    m.ripple:SetAnchor(CENTER, m.bg, CENTER, 0, 0)
    m.ripple:SetDrawLevel(2)
    local function Ripple()
        local t = (GetFrameTimeMilliseconds() % 2000) / 1200   -- 1.2 s out, then a pause
        if t > 1 then
            m.ripple:SetAlpha(0)
            return
        end
        local e = Anim.Out(t)
        m.ripple:SetScale(1 + 0.7 * e)
        m.ripple:SetAlpha(0.8 * (1 - e))
    end
    function m:SetEmpty(empty)
        self.ring:SetColor(B.RGBA(empty and C.theme or C.gold, empty and 1 or 0.8))
        local run = empty and Anim.Enabled()
        self.ripple:SetAlpha(0)
        self.ripple:SetScale(1)
        self:SetHandler("OnUpdate", run and B.Safe(Ripple, "food ripple") or nil)
    end
    return m
end

local function PaintMedallions(b)
    local p = b.parts or {}
    local food = b.food
    -- shown when the build has a food, or food is on but none picked yet ("Pick a food")
    local showFood = food ~= nil or p.food == true
    ui.food:SetHidden(not showFood)
    ui.food:SetEmpty(food == nil and showFood)
    if food then
        local icon = food.link and food.link ~= "" and GetItemLinkIcon(food.link) or "/esoui/art/icons/crafting_flower_bugloss_r1.dds"
        ui.food.icon:SetTexture(icon)
        ui.food.icon:SetAlpha(1)
        ui.food.name:SetText(B.Apply.FoodName(food))
        local left = IsWorn(b) and B.Apply.FoodLeft(food.id)
        local sub = L("PART_FOOD")
        if left then sub = L("FOOD_LEFT", math.floor(left / 60)) elseif not p.food then sub = B.Colorize(C.dim, L("FOOD_OFF")) end
        if b.foodAuto then sub = sub .. B.Colorize(C.dim, "  ·  ") .. B.Colorize(C.theme, L("FOOD_AUTO_TAG")) end
        ui.food.sub:SetText(sub)
    elseif showFood then
        ui.food.icon:SetTexture("/esoui/art/icons/crafting_flower_bugloss_r1.dds")
        ui.food.icon:SetAlpha(0.35)
        ui.food.name:SetText(B.Colorize(C.theme, L("FOOD_PICK")))
        ui.food.sub:SetText(L("PART_FOOD"))
    end
    local mundus = b.mundus and b.mundus[1]
    ui.mundus:SetHidden(mundus == nil)
    -- mundus right after the food, or at the left edge when there's no food
    ui.mundus:ClearAnchors()
    -- each in its own half of the card (a thin line between), texts kept inside their half
    -- (the food's "125 min left · auto-eats" ran into the mundus)
    local cardW = ui.consCard:GetWidth()
    if cardW < 200 then cardW = ui.detail:GetWidth() end
    local half = math.floor(cardW / 2)
    local textW = half - 10 - 32 - 8 - 10   -- (padding, icon, gap, room before the line)
    ui.mundus:SetAnchor(TOPLEFT, ui.consCard, TOPLEFT, showFood and (half + 10) or 10, 28)
    ui.food:SetTextWidth(textW)
    ui.mundus:SetTextWidth(showFood and textW or (cardW - 70))
    ui.consLine:SetHidden(not (showFood and mundus))
    ui.consNone:SetHidden(showFood or mundus ~= nil)
    if mundus then
        ui.mundus.icon:SetTexture(GetAbilityIcon(mundus))
        local names = {}
        for _, id in ipairs(b.mundus) do names[#names + 1] = B.Name(GetAbilityName(id)) end
        ui.mundus.name:SetText(table.concat(names, ", "))
        ui.mundus.sub:SetText(L("INFO_MUNDUS"))
    end
end

-- what a part holds, in one short line (the chip tooltips; was the "Also: ..." line)
local function PartDetail(b, part)
    if part == "outfit" and b.outfit then
        return (b.outfit.name and b.outfit.name ~= "") and b.outfit.name or L("OUTFIT_NONE")
    elseif part == "title" and b.title then
        return (b.title.name and b.title.name ~= "") and b.title.name or nil
    elseif part == "collect" and b.collect then
        local names = {}
        for _, c in ipairs(Capture.COLLECT) do
            local id = c.type and b.collect[c.type]
            if id and id ~= 0 then names[#names + 1] = B.Name(GetCollectibleName(id)) end
        end
        return #names > 0 and table.concat(names, ", ") or nil
    elseif part == "companion" and b.companion then
        local g, s = 0, 0
        for _ in pairs(b.companion.gear or {}) do g = g + 1 end
        for _ in pairs(b.companion.skills or {}) do s = s + 1 end
        return L("COMPANION_LINE", b.companion.name or L("PART_COMPANION"), g, s)
    elseif part == "food" and b.food then
        return B.Apply.FoodName(b.food)
    elseif part == "gear" or part == "skills" then
        local gear, skills = Capture.Count(b)
        return part == "gear" and L("DETAIL_PIECES", gear) or L("DETAIL_SKILLS", skills)
    end
end

-- Food of a build (0.6.1): click the food medallion = the food and drinks in your bag (one per
-- kind), "Eat in dungeons" on / off, "Don't eat with this build".
-- (0.6.4, sketch A + C's second line): the champion picker's panel with
--   FOOD / DRINKS   one row per kind in your bag: icon, name in its quality color, a grey line
--                   with what it raises (Health · Magicka · Stamina) and how many you have
--   OPTIONS         Eat in dungeons (switch, the panel stays open), Don't eat with this build

-- "Health · Stamina" from the food's own description (the game's localized attribute names)
local function FoodGives(link)
    local ok, has, _, desc = pcall(GetItemLinkOnUseAbilityInfo, link)
    if not ok or not has or not desc then return nil end
    desc = zo_strlower(desc)
    local out = {}
    for _, attr in ipairs({ ATTRIBUTE_HEALTH, ATTRIBUTE_MAGICKA, ATTRIBUTE_STAMINA }) do
        local name = attr and GetString("SI_ATTRIBUTES", attr) or ""
        if name ~= "" and desc:find(zo_strlower(name), 1, true) then out[#out + 1] = name end
    end
    return #out > 0 and table.concat(out, " · ") or nil
end

local function FoodMenu(b, anchor)
    local kinds, order = {}, {}
    for slot in ZO_IterateBagSlots(BAG_BACKPACK) do
        local t = GetItemType(BAG_BACKPACK, slot)
        if t == ITEMTYPE_FOOD or t == ITEMTYPE_DRINK then
            local id = GetItemId(BAG_BACKPACK, slot)
            local k = kinds[id]
            if not k then
                k = { id = id, link = GetItemLink(BAG_BACKPACK, slot), drink = t == ITEMTYPE_DRINK, n = 0 }
                kinds[id] = k
                order[#order + 1] = k
            end
            k.n = k.n + GetSlotStackSize(BAG_BACKPACK, slot)
        end
    end
    table.sort(order, function(x, y) return GetItemLinkName(x.link) < GetItemLinkName(y.link) end)
    local rows = {}
    local function Section(drink)
        local first = true
        for _, k in ipairs(order) do
            if k.drink == drink then
                if first then rows[#rows + 1] = { head = L(drink and "FOODP_DRINKS" or "FOODP_FOOD") } first = false end
                local q = GetItemQualityColor(GetItemLinkDisplayQuality(k.link))
                local gives = FoodGives(k.link)
                local count = L("FOODP_IN_BAG", k.n)
                rows[#rows + 1] = {
                    icon = GetItemLinkIcon(k.link), text = B.Name(GetItemLinkName(k.link)),
                    nameColor = { r = q.r, g = q.g, b = q.b },
                    sub = gives and (gives .. "  ·  " .. count) or count,
                    on = b.food and b.food.id == k.id, inUse = L("FOODP_IN_USE", k.n),
                    pick = function()
                        b.food = { id = k.id, link = k.link }
                        b.parts.food = true
                        b.updated = GetTimeStamp()
                        B.callbacks:FireCallbacks("BuildsChanged")
                    end,
                }
            end
        end
    end
    Section(false)
    Section(true)
    if #order == 0 then
        rows[#rows + 1] = { head = L("FOODP_FOOD") }
        rows[#rows + 1] = { text = L("FOOD_NONE_BAG"), sub = L("FOODP_NONE_SUB"), pick = function() end }
    end
    rows[#rows + 1] = { head = L("FOODP_OPTIONS") }
    rows[#rows + 1] = { toggle = true, text = L("SAVE_AUTO_EAT"), sub = L("FOODP_AUTO_SUB"),
        get = function() return b.foodAuto == true end,
        set = function(v)
            b.foodAuto = v or nil
            if v then b.parts.food = true end
            B.callbacks:FireCallbacks("BuildsChanged")
        end }
    if b.parts.food then
        rows[#rows + 1] = { text = L("FOOD_NOT_PART"), sub = L("FOODP_OFF_SUB"), pick = function()
            b.parts.food = false
            b.foodAuto = nil
            B.callbacks:FireCallbacks("BuildsChanged")
        end }
    end
    UI.OpenListPanel(anchor, L("FOODP_TITLE"), rows)
end

local function MakeFoodClickable(m)
    m:SetMouseEnabled(true)
    m:SetHandler("OnMouseEnter", function(self)
        local b = B.Get(ui.sel)
        local food = b and b.food
        if food and food.link and food.link ~= "" then
            InitializeTooltip(ItemTooltip, self, BOTTOM, 0, -6, TOP)
            ItemTooltip:SetLink(food.link)
            ItemTooltip:AddLine(L("FOOD_CLICK_TT"), "ZoFontGame", C.dim.r, C.dim.g, C.dim.b)
        else
            InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -6, TOP)
            SetTooltipText(InformationTooltip, L("FOOD_CLICK_TT"))
        end
        self.ring:SetColor(B.RGBA(C.theme, 1))
    end)
    m:SetHandler("OnMouseExit", function(self)
        ClearTooltip(ItemTooltip)
        ClearTooltip(InformationTooltip)
        self.ring:SetColor(B.RGBA(C.gold, 0.8))
    end)
    m:SetHandler("OnMouseUp", function(self, button, upInside)
        local b = B.Get(ui.sel)
        if not upInside or not b then return end
        ClearTooltip(ItemTooltip)
        ClearTooltip(InformationTooltip)
        PlaySound(SOUNDS.DEFAULT_CLICK)
        FoodMenu(b, self)
    end)
end

-- Middle of the arch (sketch B "build emblem", picked 2026-10-01; replaces the mannequin):
-- the build's picture, big, on a pennant crest (crest_fill / crest_edge.dds) with a soft
-- light behind it and the class under it.
--   hover: the crest lifts 3 px, its edge turns amber, the light comes up (120 ms)
--   click: the save window (name, picture, parts) for this build
--   another build selected: the crest dips to 92 % and fades in again (220 ms)
local CREST_W, CREST_H = 72, 90   -- (2026-10-06: smaller, on top of the arch; was 92 x 115 in the middle)
local CREST_BOX = 44              -- the build picture's frame inside the crest
local function MakeEmblem(parent)
    local e = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    e:SetDimensions(CREST_W, CREST_H + 22)
    e:SetMouseEnabled(true)
    Anim.Anchor(e, TOP, parent, TOP, 0, 46)   -- (in the arch's dome, above the gear sections; 26 touched the curve)
    e.light = W.Glow(e, CREST_W * 2, CREST_H * 1.7, C.theme, 0.08)
    e.light:SetAnchor(CENTER, e, TOP, 0, CREST_H / 2)
    e.inner = WINDOW_MANAGER:CreateControl(nil, e, CT_CONTROL)
    e.inner:SetDimensions(CREST_W, CREST_H)
    Anim.Anchor(e.inner, TOP, e, TOP, 0, 0)
    e.fill = W.Tex(e.inner, B.TEX .. "crest_fill.dds", CREST_W, CREST_H, C.card, 0.95)
    e.fill:SetAnchor(CENTER, e.inner, CENTER, 0, 0)
    local box = WINDOW_MANAGER:CreateControl(nil, e.inner, CT_CONTROL)
    box:SetDimensions(CREST_BOX, CREST_BOX)
    box:SetAnchor(CENTER, e.inner, TOP, 0, math.floor(CREST_H * 0.4))
    W.Frame(box, C.goldDark, 1)
    e.icon = W.Tex(box, nil, CREST_BOX - 2, CREST_BOX - 2)
    e.icon:SetAnchor(CENTER, box, CENTER, 0, 0)
    e.icon:SetDrawLevel(2)
    e.edge = W.Tex(e.inner, B.TEX .. "crest_edge.dds", CREST_W, CREST_H, C.gold)
    e.edge:SetAnchor(CENTER, e.inner, CENTER, 0, 0)
    e.edge:SetDrawLevel(3)
    e.caption = W.Label(e, B.Font("head", 11), C.dim, "", TEXT_ALIGN_CENTER)
    e.caption:SetAnchor(TOP, e.inner, BOTTOM, 0, 4)
    -- the build's notes (rotation, what it's for): two lines under the crest, all of it in the
    -- crest's tooltip (the gear sections start right below)
    e.note = W.Label(parent, B.Font("text", 11), C.soft, "", TEXT_ALIGN_CENTER)
    e.note:SetAnchor(TOP, e.caption, BOTTOM, 0, 4)
    e.note:SetWidth(ARCH_W - 44)
    e.note:SetMaxLineCount(2)
    e.hoverP = 0
    local function Paint()
        local p = e.hoverP
        Anim.Offset(e.inner, 0, -3 * p)
        e.light:SetAlpha(0.08 + 0.14 * p)
        e.edge:SetColor(Anim.Lerp(C.gold.r, C.theme.r, p), Anim.Lerp(C.gold.g, C.theme.g, p), Anim.Lerp(C.gold.b, C.theme.b, p), 1)
    end
    local function Hover(on)
        local from = e.hoverP
        Anim.Run("Skillbound_EmblemHover", Anim.MICRO, Anim.Out, function(p)
            e.hoverP = Anim.Lerp(from, on and 1 or 0, p)
            Paint()
        end)
    end
    e:SetHandler("OnMouseEnter", function()
        Hover(true)
        InitializeTooltip(InformationTooltip, e, BOTTOM, 0, -6, TOP)
        local b = B.Get(ui.sel)
        local note = b and b.note and b.note ~= "" and (B.Colorize(C.soft, b.note) .. "\n\n") or ""
        SetTooltipText(InformationTooltip, note .. L("EMBLEM_TT"))
    end)
    e:SetHandler("OnMouseExit", function()
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    e:SetHandler("OnMouseUp", function(_, button, upInside)
        local b = B.Get(ui.sel)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not b then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ClearTooltip(InformationTooltip)
        Anim.Pulse(e.inner, 0.94, Anim.PRESS * 2, "Skillbound_EmblemPress")
        B.Save.Open(b)
    end)
    Paint()
    ui.emblem = e
end

local function PaintEmblem(b)
    local e = ui.emblem
    e.icon:SetTexture(UI.BuildIcon(b))
    e.caption:SetText(zo_strupper(b.classId and ClassName(b.classId) or ""))
    e.note:SetText(b.note or "")
    if ui.emblemBuild ~= b.id then
        -- another build: dip and fade back in
        ui.emblemBuild = b.id
        Anim.Run("Skillbound_EmblemSwap", Anim.STD, Anim.Out, function(p)
            e.inner:SetAlpha(p)
            e.inner:SetScale(Anim.Lerp(0.92, 1, p))
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Compare two builds (2026-10-01): a panel over the arch and the right column. Rows:
-- sets, front bar, back bar, champion, food, the five stats (with the difference, green =
-- the second build has more), gear pieces that differ. Opens with a slide, X / Escape closes.
local CMP_ROWS = { "sets", "front", "back", "cp", "food", "hp", "res1", "dmg", "pen", "res", "gear" }

local function SkillIcons(b, cat)
    local out = {}
    for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
        local e = b.skills and b.skills[cat] and b.skills[cat][slot]
        out[#out + 1] = e and zo_iconFormat(GetAbilityIcon(e.id), 26, 26) or zo_iconFormat(B.TEX .. "disc.dds", 8, 8)
    end
    return table.concat(out, " ")
end

local function SetsShort(b)
    local parts = {}
    for _, s in ipairs(SetList(b)) do parts[#parts + 1] = SetText(s) end
    return #parts > 0 and table.concat(parts, "\n") or B.Colorize(C.dim, "-")
end

local function CPDiff(a, b)
    local sa = a.cp and a.cp.slots or {}
    local sb = b.cp and b.cp.slots or {}
    local n = 0
    for i = 1, 12 do if sa[i] ~= sb[i] then n = n + 1 end end
    return n
end

local function GearDiff(a, b)
    local n = 0
    for _, s in ipairs(Items.SLOTS) do
        local pa, pb = a.gear and a.gear[s], b.gear and b.gear[s]
        if (pa and pa.id) ~= (pb and pb.id) or (pa and pb and pa.trait ~= pb.trait) then n = n + 1 end
    end
    return n
end

local function MakeCompare(page)
    local p = W.Panel(page, 0.98)
    Anim.Anchor(p, TOPLEFT, page, TOPLEFT, ARCH_X, CONTENT_Y)
    Anim.Anchor2(p, BOTTOMRIGHT, page, BOTTOMRIGHT, -16, -14)
    p:SetHidden(true)
    -- (like "what will change": no raised level / mouse; the arch and the build hide under it)
    W.Brackets(p, 2, 7)
    p.title = W.Label(p, B.Font("title", 20), C.text, zo_strupper(L("CMP_TITLE")))
    p.title:SetAnchor(TOPLEFT, p, TOPLEFT, 20, 14)
    local close = W.CloseButton(p, function() UI.CloseCompare() end, 18, L("CLOSE"))
    close:SetAnchor(TOPRIGHT, p, TOPRIGHT, -16, 16)
    -- column heads: picture + name
    p.heads = {}
    for i = 1, 2 do
        local h = WINDOW_MANAGER:CreateControl(nil, p, CT_CONTROL)
        h:SetHeight(36)
        h.pic = W.Tex(h, nil, 32, 32)
        h.pic:SetAnchor(LEFT, h, LEFT, 0, 0)
        h.name = W.Label(h, B.Font("name", 14), i == 1 and C.text or C.theme, "")
        h.name:SetAnchor(LEFT, h.pic, RIGHT, 8, 0)
        h.name:SetMaxLineCount(1)
        p.heads[i] = h
    end
    p.rows = {}
    for i, key in ipairs(CMP_ROWS) do
        local r = {}
        r.label = W.Label(p, B.Font("head", 11), C.dim, zo_strupper(L("CMP_" .. string.upper(key))))
        r.a = W.Label(p, B.Font("text", 13), C.soft, "")
        r.b = W.Label(p, B.Font("text", 13), C.soft, "")
        r.d = W.Label(p, B.Font("bold", 12), C.dim, "", TEXT_ALIGN_RIGHT)
        r.line = W.Tex(p, nil, 10, 1, C.line)
        p.rows[i] = r
    end
    p.wear = W.Button(p, "", function()
        local b = p.second
        UI.CloseCompare()
        if b then B.Apply.Wear(b, { preview = true }) end
    end, "plate", 220, 40)
    p.wear:SetAnchor(BOTTOMRIGHT, p, BOTTOMRIGHT, -16, -12)
    ui.compare = p
end

-- lays the rows out for the panel's current width (the window can be resized)
local function LayoutCompare()
    local p = ui.compare
    local w = p:GetWidth()
    if w < 200 then w = 600 end
    local labelW, diffW = 110, 70
    local colW = (w - 40 - labelW - diffW) / 2
    local x1, x2 = 20 + labelW, 20 + labelW + colW
    p.heads[1]:ClearAnchors()
    p.heads[1]:SetAnchor(TOPLEFT, p, TOPLEFT, x1, 52)
    p.heads[1]:SetWidth(colW - 10)
    p.heads[2]:ClearAnchors()
    p.heads[2]:SetAnchor(TOPLEFT, p, TOPLEFT, x2, 52)
    p.heads[2]:SetWidth(colW - 10)
    for i = 1, 2 do p.heads[i].name:SetWidth(colW - 50) end
    local y = 100
    for i, r in ipairs(p.rows) do
        local h = (CMP_ROWS[i] == "sets") and 50 or ((CMP_ROWS[i] == "front" or CMP_ROWS[i] == "back") and 32 or 22)
        r.label:ClearAnchors()
        r.label:SetAnchor(TOPLEFT, p, TOPLEFT, 20, y + 4)
        r.a:ClearAnchors()
        r.a:SetAnchor(TOPLEFT, p, TOPLEFT, x1, y)
        r.a:SetWidth(colW - 10)
        r.b:ClearAnchors()
        r.b:SetAnchor(TOPLEFT, p, TOPLEFT, x2, y)
        r.b:SetWidth(colW - 10)
        r.d:ClearAnchors()
        r.d:SetAnchor(TOPRIGHT, p, TOPRIGHT, -20, y + 2)
        r.d:SetWidth(diffW)
        r.line:ClearAnchors()
        r.line:SetAnchor(TOPLEFT, p, TOPLEFT, 20, y + h + 3)
        r.line:SetAnchor(TOPRIGHT, p, TOPRIGHT, -20, y + h + 3)
        y = y + h + 8
    end
end

function UI.CloseCompare(instant)
    local p = ui.compare
    if not p or p:IsHidden() then return false end
    if instant then
        p:SetHidden(true)
        ui.arch:SetHidden(false)
        UI.RefreshDetail()   -- (shows the build again)
        return true
    end
    Anim.Run("Skillbound_Compare", Anim.CLOSE, Anim.In, function(t)
        p:SetAlpha(1 - t)
        Anim.Offset(p, 0, 10 * t)
    end, function()
        p:SetHidden(true)
        Anim.Offset(p, 0, 0)
        ui.arch:SetHidden(false)
        UI.RefreshDetail(true)
    end)
    return true
end

function UI.Compare(a, b)
    if not (a and b) then return end
    UI.Show()
    if ui.tab ~= "builds" then UI.SetTab("builds", false) end
    UI.CloseChanges(true)
    local p = ui.compare
    p.second = b
    LayoutCompare()
    for i, bb in ipairs({ a, b }) do
        p.heads[i].pic:SetTexture(UI.BuildIcon(bb))
        p.heads[i].name:SetText(bb.name)
    end
    local sa, sb = a.stats or {}, b.stats or {}
    local function Stat(v) return (v and v > 0) and ZO_CommaDelimitNumber(v) or B.Colorize(C.dim, "-") end
    local function Diff(x, y)
        if not (x and y and x > 0 and y > 0) or x == y then return "" end
        local d = y - x
        return B.Colorize(d > 0 and C.good or C.bad, (d > 0 and "+" or "-") .. ZO_CommaDelimitNumber(math.abs(d)))
    end
    local resA = math.max(sa.mag or 0, sa.stam or 0)
    local resB = math.max(sb.mag or 0, sb.stam or 0)
    local cpN, gearN = CPDiff(a, b), GearDiff(a, b)
    local values = {
        sets = { SetsShort(a), SetsShort(b), "" },
        front = { SkillIcons(a, Capture.BARS[1]), SkillIcons(b, Capture.BARS[1]), "" },
        back = { SkillIcons(a, Capture.BARS[2]), SkillIcons(b, Capture.BARS[2]), "" },
        cp = { "", "", cpN == 0 and B.Colorize(C.good, L("CMP_SAME")) or B.Colorize(C.warn, L("CMP_CP_DIFF", cpN)) },
        food = { a.food and B.Apply.FoodName(a.food) or B.Colorize(C.dim, "-"), b.food and B.Apply.FoodName(b.food) or B.Colorize(C.dim, "-"), "" },
        hp = { Stat(sa.hp), Stat(sb.hp), Diff(sa.hp, sb.hp) },
        res1 = { Stat(resA), Stat(resB), Diff(resA, resB) },
        dmg = { Stat(sa.dmg), Stat(sb.dmg), Diff(sa.dmg, sb.dmg) },
        pen = { Stat(sa.pen), Stat(sb.pen), Diff(sa.pen, sb.pen) },
        res = { Stat(sa.res), Stat(sb.res), Diff(sa.res, sb.res) },
        gear = { "", "", gearN == 0 and B.Colorize(C.good, L("CMP_SAME")) or B.Colorize(C.warn, L("CMP_GEAR_DIFF", gearN)) },
    }
    for i, key in ipairs(CMP_ROWS) do
        local r, v = p.rows[i], values[key]
        r.a:SetText(v[1])
        r.b:SetText(v[2])
        r.d:SetText(v[3])
        -- (champion / gear: one sentence across both columns)
        if (key == "cp" or key == "gear") then r.a:SetText(v[3]) r.d:SetText("") end
    end
    p.wear:SetText(L("CMP_WEAR", b.name))
    p:SetHidden(false)
    ui.arch:SetHidden(true)
    ui.detail:SetHidden(true)
    Anim.Run("Skillbound_Compare", Anim.OPEN, Anim.Out, function(t)
        p:SetAlpha(t)
        Anim.Offset(p, 0, 12 * (1 - t))
    end)
end

CompareMenu = function(a)
    ClearMenu()
    local n = 0
    for _, b in ipairs(B.SortedBuilds()) do
        if b.id ~= a.id then
            n = n + 1
            AddMenuItem(zo_iconTextFormat(UI.BuildIcon(b), 20, 20, b.name), function() UI.Compare(a, b) end)
        end
    end
    if n == 0 then AddMenuItem(B.Colorize(C.dim, L("CMP_NONE")), function() end) end
    ShowMenu()
end

-- Stats when last worn: five small blocks side by side (a colored tick, the number, a
-- small caption), like a character sheet. Hover: what they are.
local STAT_N = 5
local function MakeStats(parent)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box:SetHeight(30)
    ui.statBlocks = {}
    for i = 1, STAT_N do
        local s = WINDOW_MANAGER:CreateControl(nil, box, CT_CONTROL)
        s:SetHeight(30)
        s.tick = W.Tex(s, nil, 2, 24)
        s.tick:SetAnchor(LEFT, s, LEFT, 0, 0)
        s.value = W.Label(s, B.Font("name", 13), C.text, "")
        s.value:SetAnchor(TOPLEFT, s, TOPLEFT, 8, -1)
        s.caption = W.Label(s, B.Font("head", 10), C.dim, "")
        s.caption:SetAnchor(TOPLEFT, s.value, BOTTOMLEFT, 0, -2)
        ui.statBlocks[i] = s
    end
    W.Tip(box, function() return L("STATS_TT") end, TOP)
    return box
end

local function PaintStats(b)
    local s = b.stats
    local has = s and s.hp and s.hp > 0
    -- no stats yet (never worn): the strip goes, the chip line moves up under food · mundus
    ui.statsCard:SetHidden(not has)
    ui.PlaceChipLine(has and ui.statsCard or ui.consCard)
    if not has then return end
    local function N(v) return ZO_CommaDelimitNumber(v or 0) end
    local mag = (s.mag or 0) >= (s.stam or 0)
    local data = {
        { N(s.hp), "STAT_HEALTH", C.fitness },
        { N(math.max(s.mag or 0, s.stam or 0)), mag and "STAT_MAGICKA" or "STAT_STAMINA", mag and C.warfare or C.craft },
        { N(s.dmg), "STAT_DAMAGE", C.theme },
        { N(s.pen), "STAT_PEN", C.gold },
        { N(s.res), "STAT_RESIST", C.soft },
    }
    local w = ui.statsBox:GetWidth()
    if w < 100 then w = ui.detail:GetWidth() end
    local each = w / STAT_N
    for i, blk in ipairs(ui.statBlocks) do
        local d = data[i]
        blk:ClearAnchors()
        blk:SetAnchor(TOPLEFT, ui.statsBox, TOPLEFT, (i - 1) * each, 0)
        blk:SetWidth(each - 6)
        blk.value:SetText(d[1])
        blk.caption:SetText(zo_strupper(L(d[2])))
        blk.tick:SetColor(B.RGBA(d[3], 0.85))
    end
end

-- "PUTS ON" (sketch D, one line): a chip for every part the build puts on, in order; what
-- doesn't fit goes into a "+N" chip (hover: which ones). Parts that are off aren't shown
-- (the edit window, a click away, has all of them). A part that just came on fades in.
local function ChipWidth(label, text)
    local w = label:GetTextWidth()
    if w < 10 then w = #text * 7 end
    return w + 18
end

local function PaintChips(b, animate)
    local maxW = ui.chipArea:GetWidth()
    if maxW < 50 then maxW = 260 end
    local onList = {}
    for i, def in ipairs(PARTS_SHOWN) do
        if b.parts and b.parts[def[1]] then onList[#onList + 1] = i end
    end
    -- every part that's on gets its chip (user: no "+3"); what doesn't fit wraps to a second line
    local x, y = 0, 0
    for _, chip in ipairs(ui.chips) do chip:SetHidden(true) end
    for _, i in ipairs(onList) do
        local chip, def = ui.chips[i], PARTS_SHOWN[i]
        local w = ChipWidth(chip.label, L(def[2]))
        if x > 0 and x + w > maxW then
            x = 0
            y = y + 25
        end
        chip:SetHidden(false)
        chip:SetWidth(w)
        Anim.Anchor(chip, TOPLEFT, ui.chipArea, TOPLEFT, x, y)
        x = x + w + 5
        chip.frame:SetFrameColor(C.theme, 0.9)
        chip.label:SetColor(B.RGBA(C.text))
        chip.fill:SetWidth(w)
        chip.fill:SetHidden(false)
        if animate and not chip.on then Anim.Alpha(chip, 0, 1, Anim.STD, Anim.Out, chip.key) end
    end
    for i, chip in ipairs(ui.chips) do chip.on = b.parts and b.parts[PARTS_SHOWN[i][1]] or false end
    ui.chipArea:SetHeight(y + 20)
    ui.chipLine:SetHeight(y + 20)
    ui.chipNone:SetHidden(#onList > 0)
end

local function MakeChip(parent, i)
    local def = PARTS_SHOWN[i]
    local chip = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    chip:SetHeight(20)
    chip:SetMouseEnabled(true)
    chip.bg = W.Tex(chip)
    chip.bg:SetAnchorFill(chip)
    chip.bg:SetColor(B.RGBA(C.slot, 0.85))
    chip.fill = W.Tex(chip, nil, 1, 20, C.theme, 0.2)
    chip.fill:SetAnchor(TOPLEFT, chip, TOPLEFT, 0, 0)
    chip.frame = W.Frame(chip)
    chip.label = W.Label(chip, B.Font("head", 11), C.dim, L(def[2]), TEXT_ALIGN_CENTER)
    chip.label:SetAnchor(CENTER, chip, CENTER, 0, 0)
    chip.key = W.Name("Chip")
    W.Tip(chip, function()
        local b = B.Get(ui.sel)
        local on = b and b.parts and b.parts[def[1]]
        local text = L(on and "CHIP_ON_TT" or "CHIP_OFF_TT", L(def[2]))
        local detail = b and PartDetail(b, def[1])
        if detail then text = B.Colorize(C.text, detail) .. "\n" .. text end
        return text
    end, TOP)
    -- the chips only SHOW what the build changes; a click opens the edit window, where
    -- the switches change nothing until "Save changes" (user didn't want instant changes)
    chip:SetHandler("OnMouseUp", function(_, button, upInside)
        local b = B.Get(ui.sel)
        if not upInside or not b or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ClearTooltip(InformationTooltip)
        B.Save.Open(b)
    end)
    ui.chips[i] = chip
end


function UI.RefreshDetail(fade)
    if not ui.win or ui.tab ~= "builds" then return end
    if not ui.changes:IsHidden() then return end   -- "what will change" is shown over it
    if ui.compare and not ui.compare:IsHidden() then return end   -- (the compare panel too)
    local b = B.Get(ui.sel)
    ui.detail:SetHidden(b == nil)
    ui.intro:SetHidden(b ~= nil)
    ui.archContent:SetHidden(b == nil)   -- no build yet: the arch is just decoration
    if not b then return end
    local c = B.Char()
    ui.name:SetText(b.name)
    -- "Nightblade · worn now · ● all good · saved by Anna" (the check is a dot + two words
    -- here; hover lists what it found, the Gear check tab has the rest)
    local lines = B.Check.Run(b, IsWorn(b))
    ui.checkLines = lines
    local worst = "warn"
    for _, line in ipairs(lines) do if line.level == "bad" then worst = "bad" end end
    local status = #lines == 0 and (B.Dot(C.good) .. " " .. B.Colorize(C.good, L("CHECK_SHORT_GOOD")))
        or (B.Dot(worst == "bad" and C.bad or C.warn) .. " " .. B.Colorize(worst == "bad" and C.bad or C.warn, L("CHECK_SHORT_N", #lines)))
    local sub = {}
    if b.classId then sub[#sub + 1] = ClassName(b.classId) end
    if IsWorn(b) then sub[#sub + 1] = B.Colorize(C.theme, L("WORN_NOW")) end
    sub[#sub + 1] = status
    if b.parent and B.Get(b.parent) then sub[#sub + 1] = L("LAYER_OF", B.Get(b.parent).name) end
    if b.owner then sub[#sub + 1] = L("SAVED_BY", b.owner) end
    ui.sub:SetText(table.concat(sub, "  ·  "))
    PaintSets(b)
    local fav = B.IsFavorite(b.id)
    if ui.favBtn.starId ~= b.id then ui.favBtn.star.on = nil end
    ui.favBtn.starId = b.id
    ui.favBtn.star:SetFav(fav, false)
    ui.favBtn:SetText(L(fav and "FAV_BUTTON_ON" or "FAV_BUTTON"))
    for _, slot in pairs(ui.slots) do PaintSlot(slot, b) end
    for _, s in ipairs(ui.skills) do PaintSkill(s, b) end
    for _, s in ipairs(ui.preSlots or {}) do PaintPre(s, b) end
    ui.preAuto:Refresh()
    ui.preNow:SetText(L(B.Prebuff.IsActive() and "PRE_STOP" or "PRE_NOW"))
    PaintConstellations(b)
    PaintMedallions(b)
    -- same build as before (edited in the save window): changed chips wipe in / out
    PaintChips(b, ui.chipsBuild == b.id)
    ui.chipsBuild = b.id
    PaintStats(b)
    PaintEmblem(b)
    ui.undo:SetHidden(c.undo == nil)
    UI.PlaceUndo()
    if fade then
        Anim.Alpha(ui.detail, 0.25, 1, 160, Anim.Out, "Skillbound_DetailFade")
        Anim.Alpha(ui.archContent, 0.25, 1, 160, Anim.Out, "Skillbound_ArchFade")
    end
end

-- beside Overwrite when there's room (Wear 176 + 12 + Overwrite 148 + 20 + the text), else above it
function UI.PlaceUndo()
    local u, ow = ui.undo, ui.overwriteButton
    if not (u and ow) then return end
    local textW = u.label:GetTextWidth()
    if textW < 10 then textW = 110 end
    u:SetWidth(textW + 4)
    local room = ui.detail:GetWidth() - 176 - 12 - 148 - 20
    u:ClearAnchors()
    if room >= textW + 4 then
        u:SetAnchor(RIGHT, ow, LEFT, -20, 0)
    else
        u:SetAnchor(BOTTOMRIGHT, ow, TOPRIGHT, 0, -6)
    end
end

function UI.Select(id)
    local changed = ui.sel ~= id
    ui.sel = id
    B.sv.window.sel = id
    if ui.win then
        -- clicking a build always shows it, also when "what will change" was open
        if UI.CloseChanges(true) then changed = true end
        if UI.CloseCompare(true) then changed = true end
        -- previewing on the character: show this build there too
        if changed and B.Preview and B.Preview.IsActive() then B.Preview.ShowBuild(B.Get(id)) end
        if ui.tab ~= "builds" then UI.SetTab("builds") end
        UI.RefreshList()
        UI.RefreshDetail(changed)
    end
end

-- ---------------------------------------------------------------------------
-- "Switch to <build>?" (0.6.0): asked before wearing from the window and from the button's
-- favorites, so a misclick doesn't swap everything. A small card of its own (works with the
-- window closed), movable, remembered where you leave it. "Don't ask me again" turns it off
-- (Settings > Wearing a build turns it back on). Not asked when nothing would change, and not
-- for the window's Wear while "what will change" is on (that panel asks already).
local ask = {}

local function HideAsk()
    if ask.win then ask.win:SetHidden(true) end
end

local function CreateAsk()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_AskWear")
    ask.win = win
    win:SetDimensions(400, 196)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    if not W.RememberPlace(win, "askWear") then win:SetAnchor(CENTER, GuiRoot, CENTER, 0, -120) end
    B.callbacks:RegisterCallback("PositionsReset", function() Anim.Anchor(win, CENTER, GuiRoot, CENTER, 0, -120) end)
    local fill = W.Tex(win, B.BG)
    fill:SetAnchorFill(win)
    W.Frame(win, C.goldDark, 1)
    W.Brackets(win, 2, 6)
    local top = W.Tex(win, nil, 10, 2, C.theme, 0.9)
    top:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    local box = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    box:SetDimensions(46, 46)
    box:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 20)
    W.Frame(box, C.goldDark, 1)
    ask.pic = W.Tex(box, nil, 44, 44)
    ask.pic:SetAnchor(CENTER, box, CENTER, 0, 0)
    ask.title = W.Label(win, B.Font("title", 18), C.text, zo_strupper(L("ASK_WEAR_TITLE")))
    ask.title:SetAnchor(TOPLEFT, box, TOPRIGHT, 14, 0)
    ask.text = W.Label(win, B.Font("text", 13), C.soft, "")
    ask.text:SetAnchor(TOPLEFT, ask.title, BOTTOMLEFT, 0, 4)
    ask.text:SetWidth(300)
    ask.text:SetMaxLineCount(2)
    local close = W.CloseButton(win, HideAsk, 16, L("CANCEL"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 12)
    ask.check = W.Check(win, L("ASK_WEAR_DONT"), function() return ask.dont == true end,
        function(v) ask.dont = v end, L("ASK_WEAR_DONT_TT"))
    -- (its own line above the buttons: beside them the label ran into Cancel)
    ask.check:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 20, -66)
    local function Done(wear)
        if ask.dont then
            B.sv.askWear = false
            B.Print(L("ASK_WEAR_OFF"))
        end
        HideAsk()
        if wear and ask.build then B.Apply.Wear(ask.build, ask.opts) end
    end
    ask.yes = W.Button(win, L("ASK_WEAR_YES"), function() Done(true) end, "plate", 150, 38)
    ask.yes:AddLogo()
    ask.yes:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -14)
    local no = W.Button(win, L("CANCEL"), function() Done(false) end, "normal", 96, 30)
    no:SetAnchor(RIGHT, ask.yes, LEFT, -10, 0)
end

-- wear a build after "Switch to ...?" (or right away, see above)
function UI.AskWear(build, opts)
    if not build then return end
    opts = opts or {}
    if not B.sv.askWear or (opts.preview and B.sv.showChanges) then
        B.Apply.Wear(build, opts)
        return
    end
    local plan = B.Apply.Plan(build)
    if #plan.changes == 0 then
        B.Apply.Wear(build, opts)   -- ("you're wearing it already")
        return
    end
    if not ask.win then CreateAsk() end
    ask.build, ask.opts, ask.dont = build, { silent = opts.silent }, false
    ask.check:Refresh()
    ask.pic:SetTexture(UI.BuildIcon(build))
    local worn = B.WornBuild()
    ask.text:SetText(worn and worn.id ~= build.id and L("ASK_WEAR_FROM", build.name, worn.name) or L("ASK_WEAR_TEXT", build.name))
    ClearTooltip(InformationTooltip)
    ask.win:SetHidden(false)
    Anim.Alpha(ask.win, 0, 1, Anim.STD, Anim.Out, "Skillbound_AskWear")
end

-- ---------------------------------------------------------------------------
-- "What will change" (over the arch and the right column, before wearing)

local MAX_CHANGE_LINES = 16

function UI.ShowChanges(plan)
    if not ui.win then UI.Create() end
    if ui.win:IsHidden() then UI.Show() end
    if ui.tab ~= "builds" then UI.SetTab("builds") end
    ui.changesPlan = plan
    local b = plan.build
    ui.chTitle:SetText(L("CHANGES_TITLE", b.name))
    local lines = {}
    for i, ch in ipairs(plan.changes) do
        if i > MAX_CHANGE_LINES then
            lines[#lines + 1] = B.Colorize(C.dim, L("CHANGES_MORE", #plan.changes - MAX_CHANGE_LINES))
            break
        end
        local color = STATUS_COLOR[ch.status] or C.good
        local icon = ch.icon and zo_iconFormat(ch.icon, 20, 20) .. " " or ""
        local mark = (ch.status == "ok") and "+" or (ch.status == "sub" and "~" or "!")
        lines[#lines + 1] = B.Colorize(color, mark) .. "  " .. icon .. ch.text
    end
    if #lines == 0 then lines[1] = B.Colorize(C.good, L("CHANGES_NONE")) end
    ui.chList:SetText(table.concat(lines, "\n"))
    local waiting = IsUnitInCombat("player")
    ui.chNote:SetText(waiting and B.Colorize(C.warn, L("CHANGES_COMBAT"))
        or (plan.problems > 0 and B.Colorize(C.warn, L("CHANGES_PROBLEMS", plan.problems)) or ""))
    ui.chShowFirst:Refresh()
    -- the panel covers the arch and the build: hide those (draw order alone isn't enough)
    ui.arch:SetHidden(true)
    ui.detail:SetHidden(true)
    ui.changes:SetHidden(false)
    Anim.SlideIn(ui.changes, 0, 12, Anim.STD, "Skillbound_Changes")
    Anim.Alpha(ui.chList, 0, 1, 260, Anim.Out, "Skillbound_ChangesList", nil, 60, true)
end

local function HideChanges()
    Anim.Run("Skillbound_Changes", 140, Anim.In, function(p)
        ui.changes:SetAlpha(1 - p)
        Anim.Offset(ui.changes, 0, 8 * p)
    end, function()
        ui.changes:SetHidden(true)
        ui.changes:SetAlpha(1)
        Anim.Offset(ui.changes, 0, 0)
        ui.changesPlan = nil
        ui.arch:SetHidden(false)
        UI.RefreshDetail(true)
    end)
end

-- close "what will change" (instant = at once, no animation); true when it was open
function UI.CloseChanges(instant)
    if not ui.changes or ui.changes:IsHidden() then return false end
    if not instant then
        HideChanges()
        return true
    end
    Anim.Stop("Skillbound_Changes")
    ui.changes:SetHidden(true)
    ui.changes:SetAlpha(1)
    Anim.Offset(ui.changes, 0, 0)
    ui.changesPlan = nil
    ui.arch:SetHidden(false)
    return true
end

-- ---------------------------------------------------------------------------
-- Rules tab

-- New rules offer only what players really swap builds for (RULE_GROUPS below). house / craft /
-- fish / role were dropped (no crafting or fishing gear exists; house and role were barely
-- useful); rules of those kinds that already exist still work.

local function BuildChoices(withNone)
    local list = {}
    if withNone then list[1] = { text = L("RULE_PICK_BUILD"), value = nil } end
    for _, b in ipairs(B.SortedBuilds()) do list[#list + 1] = { text = b.name, value = b.id } end
    return list
end

local RULE_ICON = {
    trial = "crown", boss = "skull", dungeon = "shield", overland = "leaf", pvp = "swords", bg = "flame",
    zone = "moon", house = "book", craft = "hammer", fish = "potion", role = "heart",
}

-- ---------------------------------------------------------------------------
-- "New rule" card (2026-10-04, sketch C + B): the rule reads like a sentence
--   When [icon  I enter a trial  v]
--   wear [picture  build name    v]
--   (Boss [name field])          only for a boss rule
--   Ask first (o)          Cancel  [Add rule]
-- The "when" chip opens the grouped list panel (UI.OpenListPanel: group content / PvP / world).
-- Its own top-level card above "Add a rule" (DL_CONTROLS: the list panel, DL_OVERLAY, stays
-- above it). Nothing is added until "Add rule".
local RULE_GROUPS = {
    { "RULE_GROUP_GROUP", { "trial", "dungeon", "boss" } },
    { "RULE_GROUP_PVP", { "pvp", "bg" } },
    { "RULE_GROUP_WORLD", { "overland", "zone" } },
}
local NR_W, NR_H, NR_BOSS_H = 500, 196, 40
local nr = { kind = "trial", ask = false }

local function NewRuleProbe(kind)
    return { kind = kind, valueText = kind == "zone" and B.Name(GetZoneNameById(B.Rules.ZoneId())) or L("RULE_BOSS_SOME") }
end

local function CloseNewRule()
    if not nr.win or nr.win:IsHidden() then return end
    CloseCPPicker()
    nr.edit:LoseFocus()
    nr.win:SetHidden(true)
end
UI.CloseNewRule = CloseNewRule

-- a framed button like the build picker: icon, text, chevron down
local function RuleChip(parent, width, onClick)
    local p = W.Button(parent, "", onClick, "normal", width, 30)
    p.label:SetFont(B.Font("name", 13))
    p.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    p.icon = W.Tex(p, nil, 22, 22)
    p.icon:SetAnchor(LEFT, p, LEFT, 5, 0)
    p.icon:SetDrawLevel(3)
    Anim.Anchor(p.label, LEFT, p, LEFT, 34, 0)
    p.label:SetWidth(width - 56)
    p.label:SetMaxLineCount(1)
    p.chev = W.Tex(p, B.TEX .. "chevron.dds", 12, 12, C.theme)
    p.chev:SetAnchor(RIGHT, p, RIGHT, -8, 0)
    p.chev:SetTextureRotation(-math.pi / 2, 0.5, 0.5)   -- pointing down
    p.chev:SetDrawLevel(3)
    return p
end

local function NewRuleNote(text)
    nr.note:SetText(text or "")
    if text then Anim.Alpha(nr.note, 0, 1, Anim.STD, Anim.Out, "Skillbound_NewRuleNote") end
end

-- height grows upward (the card sits on "Add a rule"); the boss row fades in / out
local function NewRuleLayout(animate)
    local boss = nr.kind == "boss"
    nr.bossRow:SetHidden(not boss)
    local to = NR_H + (boss and NR_BOSS_H or 0)
    local from = nr.win:GetHeight()
    if not animate or from == to then
        Anim.Stop("Skillbound_NewRuleH")
        nr.win:SetHeight(to)
    else
        Anim.Run("Skillbound_NewRuleH", Anim.STD, Anim.InOut, function(p) nr.win:SetHeight(Anim.Lerp(from, to, p)) end)
    end
    if boss and animate then Anim.Alpha(nr.bossRow, 0, 1, Anim.STD, Anim.Out, "Skillbound_NewRuleBoss", nil, 60, true) end
end

local function NewRulePaint()
    nr.when.icon:SetTexture(B.TEX .. "icons/" .. RULE_ICON[nr.kind] .. ".dds")
    nr.when.label:SetText(B.Rules.Text(NewRuleProbe(nr.kind)))
    nr.when.label:SetColor(B.RGBA(C.text))
    nr.build:Refresh()
    nr.askSw:Refresh()
end

local function SetNewRuleKind(kind)
    local changed = kind ~= nr.kind
    nr.kind = kind
    NewRuleNote(nil)
    NewRulePaint()
    if changed then
        Anim.Alpha(nr.when.label, 0, 1, Anim.STD, Anim.Out, "Skillbound_NewRuleWhen")
        NewRuleLayout(true)
        if kind == "boss" then nr.edit:TakeFocus() end
    end
end

local function NewRuleKinds()
    local rows = {}
    for _, g in ipairs(RULE_GROUPS) do
        rows[#rows + 1] = { head = L(g[1]) }
        for _, kind in ipairs(g[2]) do
            rows[#rows + 1] = {
                icon = B.TEX .. "icons/" .. RULE_ICON[kind] .. ".dds",
                text = B.Rules.Text(NewRuleProbe(kind)),
                sub = L("RULE_HINT_" .. string.upper(kind)),
                on = kind == nr.kind, inUse = L("RULE_NEW_CHOSEN"),
                pick = function() SetNewRuleKind(kind) end,
            }
        end
    end
    UI.OpenListPanel(nr.when, L("RULE_NEW_PICK"), rows)
end

local function AddNewRule()
    local b = B.Get(nr.buildId)
    local name
    if nr.kind == "boss" then
        name = zo_strtrim(nr.edit:GetText() or "")
        if name == "" then
            NewRuleNote(L("RULE_NEW_NEED_BOSS"))
            nr.edit:TakeFocus()
            return
        end
    end
    if not b then
        NewRuleNote(L("RULE_NEW_NEED_BUILD"))
        return
    end
    local r
    if nr.kind == "zone" then
        local zoneId = B.Rules.ZoneId()
        r = B.Rules.Add("zone", zoneId, B.Name(GetZoneNameById(zoneId)))
    elseif nr.kind == "boss" then
        r = B.Rules.Add("boss", nil, name)
    else
        r = B.Rules.Add(nr.kind)
    end
    r.build, r.ask = b.id, nr.ask
    CloseNewRule()
    B.callbacks:FireCallbacks("RulesChanged")
end

local function CreateNewRule()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_NewRule")
    nr.win = win
    win:SetDimensions(NR_W, NR_H)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_CONTROLS)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    local fill = W.Tex(win, B.BG)
    fill:SetAnchorFill(win)
    W.Frame(win, C.goldDark, 1)
    W.Brackets(win, 2, 6)
    local top = W.Tex(win, nil, 10, 2, C.theme, 0.9)
    top:SetAnchor(TOPLEFT, win, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, win, TOPRIGHT, -1, 1)
    local title = W.Label(win, B.Font("head", 12), C.dim, zo_strupper(L("RULE_NEW")))
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 18, 12)
    local close = W.CloseButton(win, CloseNewRule, 14, L("CANCEL"))
    close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 10)
    local chipW = NR_W - 120
    -- When [...]
    local when = W.Label(win, B.Font("name", 15), C.soft, L("RULE_NEW_WHEN"))
    when:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 48)
    nr.when = RuleChip(win, chipW, function() NewRuleKinds() end)
    nr.when:SetAnchor(TOPLEFT, win, TOPLEFT, 96, 44)
    -- wear [...]
    local wear = W.Label(win, B.Font("name", 15), C.soft, L("RULE_NEW_WEAR"))
    wear:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 88)
    nr.build = W.BuildPicker(win, chipW, function() return nr.buildId end,
        function(id) nr.buildId = id NewRuleNote(nil) end, L("RULE_PICK_BUILD"))
    nr.build:SetHeight(30)
    nr.build:SetAnchor(TOPLEFT, win, TOPLEFT, 96, 84)
    -- Boss [name] (boss rules only)
    nr.bossRow = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    nr.bossRow:SetDimensions(NR_W - 40, 30)
    nr.bossRow:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 124)
    local bossLabel = W.Label(nr.bossRow, B.Font("name", 15), C.soft, L("RULE_NEW_BOSS"))
    bossLabel:SetAnchor(LEFT, nr.bossRow, LEFT, 0, 0)
    local box
    box, nr.edit = W.Edit(nr.bossRow, chipW, L("RULE_NEW_BOSS_HINT"))
    box:SetAnchor(LEFT, nr.bossRow, LEFT, 76, 0)
    nr.edit:SetMaxInputChars(60)
    nr.edit:SetHandler("OnEnter", function() AddNewRule() end)
    nr.edit:SetHandler("OnEscape", function(self) self:LoseFocus() end)
    nr.edit:SetHandler("OnTextChanged", function() NewRuleNote(nil) end)
    -- footer: Ask first | note | Cancel [Add rule]
    nr.add = W.Button(win, L("RULE_NEW_ADD"), AddNewRule, "plate", 150, 38)
    nr.add:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -16, -14)
    local cancel = W.Button(win, L("CANCEL"), CloseNewRule, "normal", 96, 30)
    cancel:SetAnchor(RIGHT, nr.add, LEFT, -10, 0)
    nr.askSw = W.Switch(win, L("RULE_ASK_FIRST"), function() return nr.ask end,
        function(v) nr.ask = v end, L("RULE_ASK_FIRST_TT"))
    nr.askSw:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 20, -20)
    nr.note = W.Label(win, B.Font("text", 12), C.warn, "")
    nr.note:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 20, -58)
end

-- "Add a rule" opens the card (again = closes it); the build you wear is picked to start with
local function OpenNewRule(anchor)
    if not nr.win then CreateNewRule() end
    if not nr.win:IsHidden() then
        CloseNewRule()
        return
    end
    local worn = B.WornBuild()
    if not B.Get(nr.buildId) then nr.buildId = worn and worn.id or nil end
    local guess = GetUnitName("boss1")
    if not guess or guess == "" then guess = GetUnitName("reticleover") or "" end
    nr.edit:SetText(guess)
    NewRuleNote(nil)
    NewRulePaint()
    NewRuleLayout(false)
    ClearTooltip(InformationTooltip)
    nr.win:ClearAnchors()
    Anim.Anchor(nr.win, BOTTOMLEFT, anchor, TOPLEFT, 0, -12)
    nr.win:SetHidden(false)
    Anim.Alpha(nr.win, 0, 1, Anim.STD, Anim.Out, "Skillbound_NewRule")
    Anim.SlideIn(nr.win, 0, 10, Anim.STD, "Skillbound_NewRuleIn")
end
--   [kind icon]  When I enter a trial          [picture + build v]  Ask first (o)  On (o)  X
-- plans (a trial / dungeon) are groups under a header: "Trash" + one row per boss met there.
-- The list scrolls with the mouse wheel. Cards slide in one after another when the page opens.
-- (RULE_ICON is above, with the "New rule" card)
local RULE_H, HEAD_H, RULE_GAP = 46, 30, 6

local function RuleText(r)
    if r.plan and r.kind == "zone" then return L("PLAN_TRASH") end
    if r.plan and r.kind == "boss" then return r.valueText or "?" end
    return L("RULE_WHEN", B.Rules.Text(r))
end

local function MakeRuleRow(i)
    local parent = ui.rulesArea
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    row:SetHeight(RULE_H)
    row:SetMouseEnabled(true)
    row.bg = W.Tex(row)
    row.bg:SetAnchorFill(row)
    row.frame = W.Frame(row, C.line, 1)
    row.icon = W.Tex(row, nil, 30, 30)
    row.icon:SetAnchor(LEFT, row, LEFT, 9, 0)
    row.text = W.Label(row, B.Font("name", 13), C.text, "")
    row.text:SetAnchor(TOPLEFT, row.icon, TOPRIGHT, 11, -1)
    row.text:SetWidth(270)
    row.text:SetMaxLineCount(1)
    row.sub = W.Label(row, B.Font("text", 11), C.dim, "")
    row.sub:SetAnchor(TOPLEFT, row.text, BOTTOMLEFT, 0, -2)
    row.del = W.CloseButton(row, function()
        if row.rule then B.Rules.Remove(row.rule.id) end
    end, 14, L("RULE_DELETE"))
    row.del:SetAnchor(RIGHT, row, RIGHT, -12, 0)
    row.on = W.Switch(row, L("RULE_ON"), function() return row.rule and row.rule.on end,
        function(v) if row.rule then row.rule.on = v end UI.RefreshRules() end, L("RULE_ON_TT"))
    row.on:SetAnchor(RIGHT, row.del, LEFT, -16, 0)
    row.ask = W.Switch(row, L("RULE_ASK_FIRST"), function() return row.rule and row.rule.ask end,
        function(v) if row.rule then row.rule.ask = v end end, L("RULE_ASK_FIRST_TT"))
    row.ask:SetAnchor(RIGHT, row.on, LEFT, -18, 0)
    row.back = W.Switch(row, L("RULE_BACK"), function() return row.rule and row.rule.back end,
        function(v) if row.rule then row.rule.back = v end end, L("RULE_BACK_TT"))
    row.back:SetAnchor(RIGHT, row.ask, LEFT, -18, 0)
    row.picker = W.BuildPicker(row, 200, function() return row.rule and row.rule.build end,
        function(id) if row.rule then row.rule.build = id end UI.RefreshRules() end, L("RULE_PICK_BUILD"))
    row.arrow = W.Label(row, B.Font("bold", 16), C.theme, "›")
    row.hoverP = 0
    local key = W.Name("Rule")
    local function Paint()
        local r = row.rule
        local off = r and (not r.on or B.Rules.IsPaused())
        row.bg:SetColor(B.RGBA(row.hoverP > 0.5 and C.hover or C.card, 0.85))
        row.frame:SetFrameColor(row.hoverP > 0.5 and C.goldDark or C.line, 1)
        row.icon:SetAlpha(off and 0.4 or 1)
        row.text:SetAlpha(off and 0.55 or 1)
    end
    row.Paint = Paint
    -- (hover is checked by position: the switches and buttons on the card take the mouse)
    row:SetHandler("OnMouseEnter", function()
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p) row.hoverP = p Paint() end)
    end)
    row:SetHandler("OnMouseExit", function()
        if B.IsOver(row, 0) then return end
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p) row.hoverP = 1 - p Paint() end)
    end)
    row:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollRules(-delta) end)
    ui.ruleRows[i] = row
    return row
end

local function MakePlanHead(i)
    local h = WINDOW_MANAGER:CreateControl(nil, ui.rulesArea, CT_CONTROL)
    h:SetHeight(HEAD_H)
    h:SetMouseEnabled(true)
    h.icon = W.Tex(h, B.TEX .. "icons/crown.dds", 20, 20)
    h.icon:SetAnchor(LEFT, h, LEFT, 2, 2)
    h.title = W.Label(h, B.Font("head", 14), C.theme, "")
    h.title:SetAnchor(LEFT, h.icon, RIGHT, 8, 0)
    h.del = W.Button(h, L("PLAN_REMOVE"), function()
        if h.zoneId then B.Rules.RemovePlan(h.zoneId) end
    end, "quiet", 110, 18)
    h.del:SetAnchor(RIGHT, h, RIGHT, -4, 2)
    h.del.tooltip = L("PLAN_REMOVE_TT")
    h.line = W.Tex(h, nil, 10, 1, C.goldDark)
    h.line:SetAnchor(LEFT, h.title, RIGHT, 12, 0)
    h.line:SetAnchor(RIGHT, h.del, LEFT, -12, 0)
    h:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollRules(-delta) end)
    ui.planHeads[i] = h
    return h
end

-- what the list shows, in order: loose rules, then each plan (header + trash + bosses)
local function RuleItems()
    local items, loose, byPlan = {}, {}, {}
    for _, r in ipairs(B.sv.rules) do
        if r.plan and B.sv.plans and B.sv.plans[r.plan] then
            byPlan[r.plan] = byPlan[r.plan] or {}
            table.insert(byPlan[r.plan], r)
        else
            loose[#loose + 1] = r
        end
    end
    for _, r in ipairs(loose) do items[#items + 1] = { rule = r } end
    local plans = {}
    for zoneId, p in pairs(B.sv.plans or {}) do plans[#plans + 1] = { zoneId = zoneId, name = p.name or "" } end
    table.sort(plans, function(a, b) return a.name < b.name end)
    for _, p in ipairs(plans) do
        items[#items + 1] = { head = p.zoneId, name = p.name }
        local list = byPlan[p.zoneId] or {}
        table.sort(list, function(a, b)
            if (a.kind == "zone") ~= (b.kind == "zone") then return a.kind == "zone" end
            return (a.valueText or "") < (b.valueText or "")
        end)
        for _, r in ipairs(list) do items[#items + 1] = { rule = r, inPlan = true } end
        if #list <= 1 then items[#items + 1] = { note = L("PLAN_EMPTY_BOSSES") } end
    end
    return items
end

function UI.ScrollRules(delta)
    ui.rulesOffset = math.max(0, (ui.rulesOffset or 0) + delta)
    UI.RefreshRules()
end

function UI.RefreshRules(animate)
    if not ui.win or ui.tab ~= "rules" then return end
    local items = RuleItems()
    local areaH = ui.rulesArea:GetHeight()
    if areaH < 50 then areaH = 400 end
    ui.rulesOffset = zo_clamp(ui.rulesOffset or 0, 0, math.max(0, #items - 1))
    local y, nRule, nHead, nNote = 0, 0, 0, 0
    local shown = 0
    for idx = ui.rulesOffset + 1, #items do
        local it = items[idx]
        local h = it.head and HEAD_H or (it.note and 22 or RULE_H)
        if y + h > areaH then break end
        local control
        if it.head then
            nHead = nHead + 1
            control = ui.planHeads[nHead] or MakePlanHead(nHead)
            control.zoneId = it.head
            control.title:SetText(zo_strupper(it.name))
        elseif it.note then
            nNote = nNote + 1
            ui.planNotes = ui.planNotes or {}
            control = ui.planNotes[nNote]
            if not control then
                control = W.Label(ui.rulesArea, B.Font("text", 12), C.dim, "")
                ui.planNotes[nNote] = control
            end
            control:SetText(it.note)
        else
            nRule = nRule + 1
            control = ui.ruleRows[nRule] or MakeRuleRow(nRule)
            local r = it.rule
            control.rule = r
            control.icon:SetTexture(B.TEX .. "icons/" .. (RULE_ICON[r.kind] or "sword") .. ".dds")
            control.text:SetText(RuleText(r))
            local sub = ""
            if not B.Get(r.build) then sub = B.Colorize(C.warn, L("RULE_NO_BUILD"))
            elseif B.Rules.IsPaused() then sub = L("RULE_SUB_PAUSED")
            elseif not r.on then sub = L("RULE_SUB_OFF") end
            control.sub:SetText(sub)
            control.text:ClearAnchors()
            control.text:SetAnchor(sub == "" and LEFT or TOPLEFT, control.icon, sub == "" and RIGHT or TOPRIGHT, 11, sub == "" and 0 or -1)
            control.picker:Refresh()
            control.ask:Refresh()
            control.on:Refresh()
            control.back:Refresh()
            control.back:SetHidden(not B.Rules.CAN_GO_BACK[r.kind])
            control.picker:ClearAnchors()
            control.picker:SetAnchor(RIGHT, B.Rules.CAN_GO_BACK[r.kind] and control.back or control.ask, LEFT, -22, 0)
            control.arrow:ClearAnchors()
            control.arrow:SetAnchor(RIGHT, control.picker, LEFT, -8, 0)
            control.Paint()
        end
        local indent = it.inPlan and 18 or (it.note and 26 or 0)
        control:ClearAnchors()
        Anim.Anchor(control, TOPLEFT, ui.rulesArea, TOPLEFT, indent, y)
        Anim.Anchor2(control, TOPRIGHT, ui.rulesArea, TOPRIGHT, 0, y)
        control:SetHidden(false)
        if animate then
            shown = shown + 1
            Anim.SlideIn(control, 0, 8, Anim.STD, W.Name("RuleIn"), shown * Anim.STAGGER, true)
        end
        y = y + h + (it.head and 2 or RULE_GAP)
    end
    for i = nRule + 1, #ui.ruleRows do ui.ruleRows[i]:SetHidden(true) end
    for i = nHead + 1, #(ui.planHeads) do ui.planHeads[i]:SetHidden(true) end
    for i = nNote + 1, #(ui.planNotes or {}) do ui.planNotes[i]:SetHidden(true) end
    ui.rulesEmpty:SetHidden(#items > 0)
    ui.rulesMore:SetHidden(ui.rulesOffset + nRule + nHead + nNote >= #items)
    ui.rulesSwitch:Refresh()
    ui.rulesPausedNote:SetHidden(not B.Rules.IsPaused())
end

-- "Plan a trial or dungeon": pick the zone (where you are, or one where you met bosses)
local function PlanMenu(anchor)
    ClearMenu()
    local zones = B.Rules.PlannableZones()
    if #zones == 0 then
        AddMenuItem(B.Colorize(C.dim, L("PLAN_NONE")), function() end)
    end
    for _, zoneId in ipairs(zones) do
        local n = #B.Rules.BossesSeen(zoneId)
        local planned = B.sv.plans and B.sv.plans[zoneId]
        AddMenuItem(B.Rules.ZoneName(zoneId) .. "  " .. B.Colorize(C.dim, planned and L("PLAN_HAS") or L("PLAN_BOSSES", n)),
            function() B.Rules.AddPlan(zoneId) end)
    end
    ShowMenu(anchor)
end

-- ---------------------------------------------------------------------------
-- Gear check tab

-- Gear check (redesigned 2026-10-01): the build you wear on a card with meters (lowest
-- condition, lowest weapon charge, repair kits, soul gems) and "Fix it" buttons; below, a
-- card per build with gear: ready, or what's in the bank / on another character / missing.
local GC_CARD_H, GC_GAP = 62, 8

-- a meter: number + a thin bar that grows to it; green / orange / red by the thresholds
-- (fine = nothing needs it right now: always green, e.g. 0 repair kits but nothing to repair)
local function Meter(m, value, max, good, warn, fine)
    m.value:SetText(value .. m.unit)
    local pct = max > 0 and zo_clamp(value / max, 0, 1) or 0
    local color = (fine or value >= good) and C.good or (value >= warn and C.warn or C.bad)
    m.value:SetColor(B.RGBA(color == C.good and C.text or color))
    m.fill:SetColor(B.RGBA(color, 0.9))
    local to = math.max(1, 90 * pct)
    local from = m.fillW or 1
    m.fillW = to
    Anim.Run(m.key, Anim.STD, Anim.Out, function(p) m.fill:SetWidth(Anim.Lerp(from, to, p)) end)
end

-- where a build's pieces are: counts per status
local function GearCounts(b)
    local n = { missing = 0, bank = 0, other = 0, sub = 0, total = 0 }
    for s, p in pairs(b.gear or {}) do
        if not Items.POISON[s] then
            n.total = n.total + 1
            local status = Where(p, s)
            if n[status] then n[status] = n[status] + 1 end
        end
    end
    return n
end

local function MakeGcCard(i)
    local c = WINDOW_MANAGER:CreateControl(nil, ui.gcArea, CT_CONTROL)
    c:SetHeight(GC_CARD_H)
    c:SetMouseEnabled(true)
    c.bg = W.Tex(c)
    c.bg:SetAnchorFill(c)
    c.frame = W.Frame(c, C.line, 1)
    local box = WINDOW_MANAGER:CreateControl(nil, c, CT_CONTROL)
    box:SetDimensions(38, 38)
    box:SetAnchor(LEFT, c, LEFT, 12, 0)
    W.Frame(box, C.goldDark, 1)
    c.pic = W.Tex(box, nil, 36, 36)
    c.pic:SetAnchor(CENTER, box, CENTER, 0, 0)
    c.name = W.Label(c, B.Font("name", 13), C.text, "")
    c.name:SetAnchor(TOPLEFT, box, TOPRIGHT, 10, 0)
    c.name:SetMaxLineCount(1)
    c.status = W.Label(c, B.Font("text", 12), C.soft, "")
    c.status:SetAnchor(TOPLEFT, c.name, BOTTOMLEFT, 0, 0)
    c.status:SetMaxLineCount(1)
    c.take = W.Button(c, L("BANK_TAKE_OUT_SHORT"), function()
        if c.build then B.Bank.TakeOut(c.build) end
    end, "normal", 92, 26)
    c.take:SetAnchor(RIGHT, c, RIGHT, -10, 0)
    c.take.tooltip = L("BANK_TAKE_OUT_TT")
    c.show = W.Button(c, L("GC_SHOW"), function()
        if c.build then
            UI.SetTab("builds", true)
            UI.Select(c.build.id)
        end
    end, "quiet", 50, 20)
    c.show:SetAnchor(RIGHT, c, RIGHT, -10, 0)
    c.hoverP = 0
    local key = W.Name("Gc")
    local function Paint()
        c.bg:SetColor(B.RGBA(c.hoverP > 0.5 and C.hover or C.card, 0.85))
        c.frame:SetFrameColor(c.hoverP > 0.5 and C.goldDark or C.line, 1)
    end
    c:SetHandler("OnMouseEnter", function() Anim.Run(key, Anim.MICRO, Anim.Out, function(p) c.hoverP = p Paint() end) end)
    c:SetHandler("OnMouseExit", function()
        if B.IsOver(c, 0) then return end
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p) c.hoverP = 1 - p Paint() end)
    end)
    c:SetHandler("OnMouseWheel", function(_, delta)
        ui.gcOffset = math.max(0, (ui.gcOffset or 0) - delta * 2)
        UI.RefreshGearCheck()
    end)
    Paint()
    ui.gcCards[i] = c
    return c
end

function UI.RefreshGearCheck(animate)
    if not ui.win or ui.tab ~= "check" then return end
    -- the card on top: the build you wear
    local worn = B.WornBuild()
    ui.gcPic:SetTexture(worn and UI.BuildIcon(worn) or B.LOGO)
    ui.gcName:SetText(worn and worn.name or L("CHECK_NONE"))
    ui.gcSub:SetHidden(worn == nil)
    local lines = {}
    if worn then
        local current = B.Check.Current(true)
        if #current == 0 then lines[1] = B.Dot(C.good) .. " " .. B.Colorize(C.good, L("CHECK_GOOD")) end
        for i, line in ipairs(current) do
            if i <= 3 then lines[#lines + 1] = CheckLine(line) end
        end
        if #current > 3 then lines[#lines + 1] = B.Colorize(C.dim, L("GC_MORE", #current - 3)) end
    else
        lines[1] = B.Colorize(C.dim, L("GC_NONE_HINT"))
    end
    ui.gcLines:SetText(table.concat(lines, "\n"))
    local s = B.Fix.Status()
    Meter(ui.gcMeters[1], s.minCond, 100, B.Fix.RepairAt(), math.min(15, B.Fix.RepairAt()))
    Meter(ui.gcMeters[2], s.minCharge, 100, B.Fix.ChargeAt(), math.min(10, B.Fix.ChargeAt()))
    for _, a in ipairs(ui.gcAuto or {}) do
        local icon, n = a.getIcon()
        a.icon:SetHidden(icon == nil)
        if icon then
            a.icon:SetTexture(icon)
            a.icon:SetColor(1, 1, 1, n > 0 and 1 or 0.3)   -- (none in your bag: greyed)
        end
        a.count:SetText(n > 0 and tostring(n) or "0")
        a.count:SetColor(B.RGBA(n > 0 and C.text or C.bad))
        a.switch:Refresh()
        if not a.slider.dragging then a.slider:Refresh() end
    end
    Meter(ui.gcMeters[3], s.kits, 10, math.max(1, #s.repair), 1, #s.repair == 0)
    Meter(ui.gcMeters[4], s.gems, 10, math.max(1, #s.charge), 1, #s.charge == 0)

    -- all builds with gear
    local list = {}
    for _, b in ipairs(B.SortedBuilds()) do
        if b.parts and b.parts.gear and b.gear and next(b.gear) then list[#list + 1] = b end
    end
    ui.gcEmpty:SetHidden(#list > 0)
    local areaW, areaH = ui.gcArea:GetWidth(), ui.gcArea:GetHeight()
    if areaW < 100 then areaW = 760 end
    if areaH < 60 then areaH = 300 end
    local colW = (areaW - GC_GAP) / 2
    local rows = math.max(1, math.floor((areaH + GC_GAP) / (GC_CARD_H + GC_GAP)))
    local maxOffset = math.max(0, math.ceil(#list / 2) - rows) * 2
    ui.gcOffset = zo_clamp(ui.gcOffset or 0, 0, maxOffset)
    local shown = 0
    for i = 1, rows * 2 do
        local b = list[ui.gcOffset + i]
        local c = ui.gcCards[i] or (b and MakeGcCard(i))
        if c then
            c:SetHidden(b == nil)
            if b then
                c.build = b
                local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
                Anim.Anchor(c, TOPLEFT, ui.gcArea, TOPLEFT, col * (colW + GC_GAP), row * (GC_CARD_H + GC_GAP))
                c:SetWidth(colW)
                c.pic:SetTexture(UI.BuildIcon(b))
                c.name:SetText(b.name)
                c.name:SetWidth(colW - 170)
                local n = GearCounts(b)
                local bits = {}
                if n.missing > 0 then bits[#bits + 1] = B.Colorize(C.bad, L("GC_MISSING", n.missing)) end
                if n.bank > 0 then bits[#bits + 1] = B.Colorize(C.warn, L("GC_BANK", n.bank)) end
                if n.other > 0 then bits[#bits + 1] = B.Colorize(C.warn, L("GC_OTHER", n.other)) end
                if n.sub > 0 then bits[#bits + 1] = B.Colorize(C.dim, L("GC_SUB", n.sub)) end
                if #bits == 0 then bits[1] = B.Dot(C.good) .. " " .. B.Colorize(C.good, L("GC_READY", n.total)) end
                c.status:SetText(table.concat(bits, "  ·  "))
                c.status:SetWidth(colW - 170)
                local canTake = n.bank > 0 and IsBankOpen()
                c.take:SetHidden(not canTake)
                c.show:SetHidden(canTake)
                if animate then
                    shown = shown + 1
                    Anim.SlideIn(c, 0, 8, Anim.STD, W.Name("GcIn"), shown * Anim.STAGGER, true)
                end
            end
        end
    end
    for i = rows * 2 + 1, #ui.gcCards do ui.gcCards[i]:SetHidden(true) end
    if animate then Anim.SlideIn(ui.gcTop, 0, 8, Anim.STD, "Skillbound_GcTop", 0, true) end
end


-- ---------------------------------------------------------------------------
-- Tabs: words in a row under the cartouche, an amber underline glides to the active one

local TAB_Y = 78

local function LayoutTabs()
    local widths, total = {}, 0
    for i, def in ipairs(TABS) do
        local w = ui.tabs[def.key].label:GetTextWidth()
        if w < 10 then w = #L(def.text) * 10 end
        widths[i] = w
        total = total + w
    end
    local gap = 46
    total = total + gap * (#TABS - 1)
    local x = (ui.win:GetWidth() - total) / 2
    for i, def in ipairs(TABS) do
        local t = ui.tabs[def.key]
        t:SetWidth(widths[i])
        Anim.Anchor(t, TOPLEFT, ui.win, TOPLEFT, x, TAB_Y)
        t.x = x
        if ui.tabGems[i] then
            ui.tabGems[i]:ClearAnchors()
            ui.tabGems[i]:SetAnchor(CENTER, ui.win, TOPLEFT, x + widths[i] + gap / 2, TAB_Y + 11)
        end
        x = x + widths[i] + gap
    end
end

local function MoveUnderline(instant)
    local t = ui.tabs[ui.tab]
    if not t or not t.x then return end
    local fromX, fromW = ui.ulX or t.x, ui.ulW or t:GetWidth()
    local toX, toW = t.x, t:GetWidth()
    ui.ulX, ui.ulW = toX, toW
    local function Set(x, w)
        ui.underline:ClearAnchors()
        ui.underline:SetAnchor(TOPLEFT, ui.win, TOPLEFT, x, TAB_Y + 24)
        ui.underline:SetWidth(w)
        ui.underGlow:ClearAnchors()
        ui.underGlow:SetAnchor(CENTER, ui.underline, CENTER, 0, 0)
        ui.underGlow:SetWidth(w + 30)
    end
    if instant then
        Anim.Stop("Skillbound_Underline")
        Set(toX, toW)
        return
    end
    Anim.Run("Skillbound_Underline", Anim.STD, Anim.InOut, function(p)
        Set(Anim.Lerp(fromX, toX, p), Anim.Lerp(fromW, toW, p))
    end)
end

local function PaintTabs()
    for _, def in ipairs(TABS) do
        local t = ui.tabs[def.key]
        local on = def.key == ui.tab
        t.label:SetColor(B.RGBA(on and C.text or (t.hover and C.soft or C.dim)))
        t:SetScale(t.hover and not on and 1.04 or 1)
    end
end

local PAGES = { builds = "buildsPage", rules = "rulesPage", check = "checkPage" }

function UI.SetTab(tab, animate)
    ClosePicker()
    CloseNewRule()
    local old = ui.tab
    ui.tab = tab
    B.sv.window.tab = tab
    PaintTabs()
    MoveUnderline(not animate)
    for key, field in pairs(PAGES) do
        local page = ui[field]
        if key == tab then
            page:SetHidden(ui.minimized == true)
            if animate and old ~= tab then Anim.SlideIn(page, 10, 0, Anim.STD, "Skillbound_PageIn") end
        elseif animate and key == old then
            Anim.Run("Skillbound_PageOut", 120, Anim.In, function(p)
                page:SetAlpha(1 - p)
                Anim.Offset(page, -8 * p, 0)
            end, function()
                if ui.tab ~= key then page:SetHidden(true) end
                page:SetAlpha(1)
                Anim.Offset(page, 0, 0)
            end)
        else
            page:SetHidden(true)
        end
    end
    if tab == "builds" then
        UI.RefreshList(true)
        UI.RefreshDetail()
    elseif tab == "rules" then
        UI.RefreshRules(true)
    else
        UI.RefreshGearCheck(true)
    end
end

local function MakeTab(def)
    local t = WINDOW_MANAGER:CreateControl(nil, ui.win, CT_CONTROL)
    t:SetHeight(22)
    t:SetMouseEnabled(true)
    t.label = W.Label(t, B.Font("title", 16), C.dim, zo_strupper(L(def.text)))
    t.label:SetAnchor(LEFT, t, LEFT, 0, 0)
    t:SetHandler("OnMouseEnter", function() t.hover = true PaintTabs() end)
    t:SetHandler("OnMouseExit", function() t.hover = false PaintTabs() end)
    t:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and ui.tab ~= def.key then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            UI.SetTab(def.key, true)
        end
    end)
    ui.tabs[def.key] = t
end

-- name plate: name / class / CP (the diamond and CP hide below champion level)
local function PaintHeaderInfo()
    local cp = GetPlayerChampionPointsEarned and GetPlayerChampionPointsEarned() or 0
    ui.charName:SetText(B.Char().name or "")
    ui.charClass:SetText(ClassName(GetUnitClassId("player")))
    ui.charGem:SetHidden(cp <= 0)
    ui.charCP:SetHidden(cp <= 0)
    ui.charCP:SetText(L("CP_COUNT", ZO_CommaDelimitNumber(cp)))
end

-- a label stretched across a parent (left + right edge), at a given top offset or under another control
local function Stretch(label, parent, top, under, gap)
    label:ClearAnchors()
    if under then
        label:SetAnchor(TOPLEFT, under, BOTTOMLEFT, 0, gap or 0)
        label:SetAnchor(TOPRIGHT, under, BOTTOMRIGHT, 0, gap or 0)
    else
        label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, top)
        label:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, top)
    end
end

-- ---------------------------------------------------------------------------
-- Pages

local function CreateBuildsPage(win)
    local page = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    Anim.Fill(page, win)
    ui.buildsPage = page

    -- left: build cards with the gliding selection (as tall as the window allows)
    local list = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    list:SetAnchor(TOPLEFT, page, TOPLEFT, LIST_X, CONTENT_Y + 4)
    list:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, LIST_X, -78)   -- (one import link under it now)
    list:SetWidth(LIST_W)
    list:SetMouseEnabled(true)
    list:SetHandler("OnMouseWheel", function(_, delta) UI.Scroll(-delta) end)
    ui.list = list
    for i = 1, 18 do ui.rows[i] = MakeRow(list) end
    local sel = WINDOW_MANAGER:CreateControl(nil, list, CT_CONTROL)
    sel:SetDimensions(LIST_W, CARD_H)
    sel:SetDrawLevel(10)
    sel.fill = W.Tex(sel, nil, nil, nil, C.theme, 0.1)
    sel.fill:SetAnchorFill(sel)
    sel.frame = W.Frame(sel, C.theme, 0.8)
    sel.bar = W.Tex(sel, nil, 3, CARD_H, C.theme)
    sel.bar:SetAnchor(LEFT, sel, LEFT, 0, 0)
    sel.glow = W.Glow(sel, 40, CARD_H * 1.6, C.theme, 0.25)
    sel.glow:SetAnchor(CENTER, sel, LEFT, 0, 0)
    sel:SetHidden(true)
    Anim.Anchor(sel, TOPLEFT, list, TOPLEFT, 0, 0)
    ui.selector = sel
    ui.empty = W.Label(list, B.Font("text", 13), C.dim, L("LIST_EMPTY"))
    ui.empty:SetAnchor(TOPLEFT, list, TOPLEFT, 6, 6)
    ui.empty:SetWidth(LIST_W - 12)

    -- same pointed amber plate as Wear (logo, sheen on hover, press), same height and baseline
    local save = W.Button(page, L("SAVE_MAIN"), function() UI.SaveNew() end, "plate", LIST_W, 42)
    ui.saveButton = save
    save:AddLogo()   -- (only Save build and Wear carry the logo)
    save:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, LIST_X, -22)
    save.tooltip = L("SAVE_WORN_TT")
    -- one "Import..." link (was two: share code + Armory): a small menu with both
    local import = W.Button(page, L("IMPORT_BUTTON"), function(self)
        ClearMenu()
        AddMenuItem(L("IMPORT_CODE"), function() B.Share.ShowImport() end)
        -- (a menu opened from a menu click closes right away: open it a moment later)
        AddMenuItem(L("IMPORT_ARMORY"), function() B.Later(function() B.Armory.Menu(self) end, 50) end)
        ShowMenu(self)
    end, "quiet", LIST_W, 22)
    import:SetAnchor(BOTTOMLEFT, save, TOPLEFT, 0, -8)
    import.tooltip = L("IMPORT_TT")

    -- middle: the lit arch with the gear (stretches down with the window)
    local arch = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    arch:SetAnchor(TOPLEFT, page, TOPLEFT, ARCH_X, ARCH_Y)
    arch:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, ARCH_X, -18)
    arch:SetWidth(ARCH_W)
    ui.arch = arch
    local archFill = W.Tex(arch, B.TEX .. "arch_fill.dds")
    archFill:SetAnchorFill(arch)
    archFill:SetColor(0.035, 0.035, 0.035, 0.88)
    ui.archLight = W.Glow(arch, ARCH_W * 1.05, 360, C.glow, 0.2)
    ui.archLight:SetAnchor(CENTER, arch, TOP, 0, 230)
    local floor = W.Glow(arch, ARCH_W * 0.95, 44, C.glow, 0.45)
    floor:SetAnchor(CENTER, arch, BOTTOM, 0, -14)
    local archEdge = W.Tex(arch, B.TEX .. "arch_edge.dds")
    archEdge:SetAnchorFill(arch)
    archEdge:SetColor(B.RGBA(C.gold, 0.5))
    archEdge:SetDrawLevel(2)
    local content = WINDOW_MANAGER:CreateControl(nil, arch, CT_CONTROL)
    content:SetAnchorFill(arch)
    ui.archContent = content
    MakeEmblem(content)
    -- a section header (small, like the cards' headers) and a centered row of gear slots
    local function Section(textKey, y)
        local h = W.Header(content, L(textKey))
        h.label:SetFont(B.Font("head", 11))
        h:SetAnchor(TOPLEFT, content, TOPLEFT, 18, y)
        h:SetAnchor(TOPRIGHT, content, TOPRIGHT, -18, y)
    end
    local function Row(slots, y)
        local w = #slots * GEAR + (#slots - 1) * GEAR_GAP
        for i, slot in ipairs(slots) do
            local s = MakeSlot(content, slot)
            Anim.Anchor(s, TOPLEFT, content, TOP, -w / 2 + (i - 1) * (GEAR + GEAR_GAP), y)
        end
    end
    -- (2026-10-06: a bit more air, user: header -> slots 22 (was 18), section -> section 28 (was 18))
    local HEAD_GAP, SECTION_GAP = 22, 28
    local y = ARCH_SECTIONS_Y
    Section("ARCH_ARMOR", y)
    Row(ARMOR_ROWS[1], y + HEAD_GAP)
    Row(ARMOR_ROWS[2], y + HEAD_GAP + GEAR + GEAR_GAP)
    y = y + HEAD_GAP + 2 * GEAR + GEAR_GAP + SECTION_GAP
    Section("ARCH_JEWELRY", y)
    Row(JEWELRY_ROW, y + HEAD_GAP)
    y = y + HEAD_GAP + GEAR + SECTION_GAP
    Section("ARCH_WEAPONS", y)
    -- FRONT BAR [main][off]  [poison]  /  BACK BAR [main][off]  [poison]
    for r, def in ipairs(WEAPON_ROWS) do
        local ry = y + HEAD_GAP + (r - 1) * (GEAR + GEAR_GAP + 2)
        local label = W.Label(content, B.Font("head", 11), C.dim, zo_strupper(L(def[1])))
        label:SetAnchor(LEFT, content, TOPLEFT, 18, ry + GEAR / 2)
        local poison = MakeSlot(content, def[4], POISON)
        Anim.Anchor(poison, TOPRIGHT, content, TOPRIGHT, -18, ry + (GEAR - POISON) / 2)
        local off = MakeSlot(content, def[3])
        Anim.Anchor(off, TOPRIGHT, content, TOPRIGHT, -18 - POISON - 12, ry)
        local main = MakeSlot(content, def[2])
        Anim.Anchor(main, TOPRIGHT, content, TOPRIGHT, -18 - POISON - 12 - GEAR - GEAR_GAP, ry)
    end
    -- bottom of the arch: [star Favorite] [Preview]
    ui.favBtn = W.Button(content, L("FAV_BUTTON"), function()
        if not ui.sel then return end
        B.ToggleFavorite(ui.sel)
        local fav = B.IsFavorite(ui.sel)
        ui.favBtn.star:SetFav(fav, true)
        -- the selected build's card star plays along
        for _, row in ipairs(ui.rows) do
            if row.favId == ui.sel and not row:IsHidden() then
                row.fav:SetHidden(false)
                row.fav:SetFav(fav, true)
            end
        end
    end, "normal", 112, 28)
    ui.favBtn:SetAnchor(BOTTOMLEFT, content, BOTTOMLEFT, 14, -14)
    ui.favBtn.label:SetFont(B.Font("head", 13))
    ui.favBtn.star = MakeStar(ui.favBtn, 18)
    ui.favBtn.star:SetAnchor(LEFT, ui.favBtn, LEFT, 8, 0)
    Anim.Anchor(ui.favBtn.label, CENTER, ui.favBtn, CENTER, 9, 0)
    ui.favBtn.tooltip = function() return L(ui.sel and B.IsFavorite(ui.sel) and "FAV_ON_TT" or "FAV_TT") end
    -- see the build on your real character (the game's own preview, Skillbound_Preview.lua)
    ui.previewBtn = W.Button(content, L("PREVIEW_START"), function()
        if B.Preview.IsActive() then
            B.Preview.Stop(true)
        else
            B.Preview.Start(B.Get(ui.sel))
        end
    end, "normal", ARCH_W - 28 - 112 - 8, 28)
    ui.previewBtn:SetAnchor(BOTTOMRIGHT, content, BOTTOMRIGHT, -14, -14)
    ui.previewBtn.label:SetFont(B.Font("head", 13))
    ui.previewBtn.tooltip = function() return L(B.Preview.IsActive() and "PREVIEW_STOP_TT" or "PREVIEW_START_TT") end
    local editHint = W.Label(content, B.Font("text", 11), C.dim, L("EDIT_HINT"), TEXT_ALIGN_CENTER)
    editHint:SetAnchor(BOTTOM, content, BOTTOM, 0, -50)
    editHint:SetWidth(ARCH_W - 40)

    -- right: the build (width and height follow the window)
    local d = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    d:SetAnchor(TOPLEFT, page, TOPLEFT, RX, CONTENT_Y + 2)
    d:SetAnchor(BOTTOMRIGHT, page, BOTTOMRIGHT, -26, -22)
    ui.detail = d
    ui.intro = W.Label(page, B.Font("text", 15), C.soft, L("INTRO"))
    ui.intro:SetAnchor(TOPLEFT, page, TOPLEFT, RX, CONTENT_Y + 30)
    ui.intro:SetAnchor(TOPRIGHT, page, TOPRIGHT, -26, CONTENT_Y + 30)

    ui.name = W.Label(d, B.Font("title", 26), C.text, "")
    ui.name:SetAnchor(TOPLEFT, d, TOPLEFT, 0, 0)
    ui.name:SetAnchor(TOPRIGHT, d, TOPRIGHT, -138, 0)   -- (room for Share + "...")
    ui.name:SetMaxLineCount(1)
    -- click the name to rename the build
    ui.name:SetMouseEnabled(true)
    ui.name:SetHandler("OnMouseEnter", function(self)
        self:SetColor(B.RGBA(C.theme))
        InitializeTooltip(InformationTooltip, self, BOTTOMLEFT, 0, -4, TOPLEFT)
        SetTooltipText(InformationTooltip, L("RENAME_TT"))
    end)
    ui.name:SetHandler("OnMouseExit", function(self)
        self:SetColor(B.RGBA(C.text))
        ClearTooltip(InformationTooltip)
    end)
    ui.name:SetHandler("OnMouseUp", function(_, button, upInside)
        local b = B.Get(ui.sel)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and b then
            ClearTooltip(InformationTooltip)
            PlaySound(SOUNDS.DEFAULT_CLICK)
            UI.Rename(b)
        end
    end)
    local more = W.Button(d, "...", function(self)
        local b = B.Get(ui.sel)
        if b then BuildMenu(b, self) end
    end, "quiet", 30, 26)
    more:SetAnchor(TOPRIGHT, d, TOPRIGHT, 0, 2)
    more.tooltip = L("MORE_TT")
    -- Share: the code to copy, and "Link in chat" in the same window
    local share = W.Button(d, L("SHARE_BUTTON"), function()
        local b = B.Get(ui.sel)
        if b then B.Share.ShowCode(b) end
    end, "plate", 92, 26)   -- the amber plate like Wear / Save build (smaller: user found 116 x 32 too big)
    share:SetAnchor(RIGHT, more, LEFT, -6, 0)
    share.label:SetFont(B.Font("head", 12))
    share.tooltip = L("SHARE_BUTTON_TT")
    ui.sub = W.Label(d, B.Font("text", 13), C.dim, "")
    Stretch(ui.sub, d, 34)
    ui.sub:SetMaxLineCount(1)
    W.Tip(ui.sub, function()
        local lines = ui.checkLines or {}
        if #lines == 0 then return B.Colorize(C.good, L("CHECK_GOOD")) end
        local out = {}
        for _, line in ipairs(lines) do out[#out + 1] = CheckLine(line) end
        out[#out + 1] = B.Colorize(C.dim, L("CHECK_TAB_HINT"))
        return table.concat(out, "\n")
    end, TOP)
    ui.sets = W.Label(d, B.Font("name", 12), C.gold, "")
    Stretch(ui.sets, d, 52)
    ui.sets:SetMaxLineCount(1)
    W.Tip(ui.sets, SetsTooltip, TOP)
    -- (same font, no width limit, invisible: measures how many sets fit)
    ui.setsMeasure = W.Label(d, B.Font("name", 12), C.gold, "")
    ui.setsMeasure:SetAnchor(TOPLEFT, d, TOPLEFT, 0, 52)
    ui.setsMeasure:SetAlpha(0)

    -- Below the name: framed cards (layout A, picked 2026-10-03, replaced the loose lines):
    --   LOADOUT        front bar, back bar, buffs (+ Auto / Now)
    --   CHAMPION       the three constellations ("change" in the card's header)
    --   FOOD · MUNDUS  the two medallions side by side
    --   stats strip    five numbers
    --   PUTS ON        one line of chips (only the parts that are on, "+N" when they don't fit)
    -- The check moved into the line under the name (a dot + "all good" / "2 to check", hover
    -- lists them); the "Also: outfit · title · mount" line moved into those chips' tooltips.
    local PAD_X = 10
    local function Card(top, height, title, under)
        local c = WINDOW_MANAGER:CreateControl(nil, d, CT_CONTROL)
        if under then
            c:SetAnchor(TOPLEFT, under, BOTTOMLEFT, 0, 8)
            c:SetAnchor(TOPRIGHT, under, BOTTOMRIGHT, 0, 8)
        else
            c:SetAnchor(TOPLEFT, d, TOPLEFT, 0, top)
            c:SetAnchor(TOPRIGHT, d, TOPRIGHT, 0, top)
        end
        c:SetHeight(height)
        c.fill = W.Tex(c)
        c.fill:SetAnchorFill(c)
        c.fill:SetColor(B.RGBA(C.card, 0.85))
        c.frame = W.Frame(c, C.line, 1)
        W.TopLight(c, 12, 0.25)
        if title then
            c.head = W.Header(c, title)
            c.head:SetAnchor(TOPLEFT, c, TOPLEFT, PAD_X, 8)
            c.head:SetAnchor(TOPRIGHT, c, TOPRIGHT, -PAD_X, 8)
        end
        return c
    end

    -- (sketch B, 2026-10-06: 40 px skills, the ultimate 46 px with an amber frame behind a thin
    -- divider; the five normal skills sit centered on the ultimate's height)
    local BAR_X = 64
    local ULT_X = BAR_X + 4 * SKILL_STEP + SKILL + 21   -- (divider halfway in the 21 px gap)
    local loadout = Card(78, 28 + 2 * BAR_ROW + SKILL + 12, L("CARD_LOADOUT"))
    ui.loadoutCard = loadout
    for bar, cat in ipairs(Capture.BARS) do
        local y = 28 + (bar - 1) * BAR_ROW
        local label = W.Label(loadout, B.Font("head", 12), C.dim, L(bar == 1 and "BAR_FRONT" or "BAR_BACK"))
        label:SetAnchor(LEFT, loadout, TOPLEFT, PAD_X, y + ULT / 2)
        for slot = Capture.FIRST_SLOT, Capture.ULT_SLOT do
            local s = MakeSkill(loadout, cat, slot)
            if slot == Capture.ULT_SLOT then
                Anim.Anchor(s, TOPLEFT, loadout, TOPLEFT, ULT_X, y)
            else
                Anim.Anchor(s, TOPLEFT, loadout, TOPLEFT, BAR_X + (slot - Capture.FIRST_SLOT) * SKILL_STEP, y + (ULT - SKILL) / 2)
            end
        end
        local divider = W.Tex(loadout, nil, 1, SKILL - 8, C.goldDark)
        divider:SetAnchor(CENTER, loadout, TOPLEFT, ULT_X - 11, y + ULT / 2)
    end
    -- third row: the build's prebuff skills (Skillbound_Prebuff.lua), an Auto switch, "Now"
    local preY = 28 + 2 * BAR_ROW
    local preLabel = W.Label(loadout, B.Font("head", 12), C.dim, L("BAR_PREBUFF"))
    preLabel:SetAnchor(LEFT, loadout, TOPLEFT, PAD_X, preY + SKILL / 2)
    W.Tip(preLabel, function() return L("PRE_INFO_TT") end, TOP)
    for slot = B.Prebuff.FIRST, B.Prebuff.LAST do
        local s = MakePreSlot(loadout, slot)
        Anim.Anchor(s, TOPLEFT, loadout, TOPLEFT, BAR_X + (slot - Capture.FIRST_SLOT) * SKILL_STEP, preY)
    end
    ui.preAuto = W.Switch(loadout, L("PRE_AUTO"), function()
        local b = B.Get(ui.sel)
        return b and b.prebuff and b.prebuff.auto or false
    end, function(v)
        local b = B.Get(ui.sel)
        if not b then return end
        b.prebuff = b.prebuff or { skills = {} }
        b.prebuff.auto = v or nil
    end, function() return L("PRE_AUTO_TT") end)
    ui.preAuto:SetAnchor(LEFT, loadout, TOPLEFT, BAR_X + 4 * SKILL_STEP + SKILL + 14, preY + SKILL / 2)
    ui.preNow = W.Button(loadout, L("PRE_NOW"), function()
        local b = B.Get(ui.sel)
        if b then B.Prebuff.Start(b) end
    end, "quiet", 42, 20)
    ui.preNow:SetAnchor(LEFT, ui.preAuto, RIGHT, 6, 0)
    ui.preNow.tooltip = function() return L(B.Prebuff.IsActive() and "PRE_STOP_TT" or "PRE_NOW_TT") end

    -- CHAMPION: the constellations (the stars slotted when the build was saved / overwritten)
    local cpCard = Card(nil, 80, L("PART_CP"), loadout)
    ui.cpBox = WINDOW_MANAGER:CreateControl(nil, cpCard, CT_CONTROL)
    ui.cpBox:SetAnchor(TOPLEFT, cpCard, TOPLEFT, PAD_X, 28)
    ui.cpBox:SetDimensions(370, 44)
    MakeConstellations(ui.cpBox)

    -- FOOD · MUNDUS: two medallions side by side (mundus moves left when there's no food)
    local consCard = Card(nil, 70, L("CARD_CONSUMABLES"), cpCard)
    ui.consCard = consCard
    ui.food = MakeMedallion(consCard)
    ui.food:SetAnchor(TOPLEFT, consCard, TOPLEFT, PAD_X, 28)
    MakeFoodClickable(ui.food)
    ui.mundus = MakeMedallion(consCard)
    ui.mundus:SetAnchor(TOPLEFT, consCard, TOPLEFT, 200, 28)
    ui.consLine = W.Tex(consCard, nil, 1, 32, C.line)
    ui.consLine:SetAnchor(TOP, consCard, TOP, 0, 28)
    ui.consNone = W.Label(consCard, B.Font("text", 12), C.dim, L("CONS_NONE"))
    ui.consNone:SetAnchor(TOPLEFT, consCard, TOPLEFT, PAD_X, 36)

    -- stats strip
    local statsCard = Card(nil, 42, nil, consCard)
    ui.statsCard = statsCard
    ui.statsBox = MakeStats(statsCard)
    ui.statsBox:SetAnchor(TOPLEFT, statsCard, TOPLEFT, PAD_X + 2, 6)
    ui.statsBox:SetAnchor(TOPRIGHT, statsCard, TOPRIGHT, -PAD_X, 6)

    -- PUTS ON: one line of chips (no card: the light ending under the cards)
    ui.chipLine = WINDOW_MANAGER:CreateControl(nil, d, CT_CONTROL)
    ui.chipLine:SetHeight(20)
    ui.chipHead = W.Label(ui.chipLine, B.Font("head", 12), C.dim, zo_strupper(L("PARTS_HEAD")))
    ui.chipHead:SetAnchor(TOPLEFT, ui.chipLine, TOPLEFT, 0, 3)   -- (stays on the first line when the chips wrap)
    ui.chipArea = WINDOW_MANAGER:CreateControl(nil, ui.chipLine, CT_CONTROL)
    ui.chipArea:SetAnchor(TOPLEFT, ui.chipHead, TOPRIGHT, 10, -1)
    ui.chipArea:SetAnchor(RIGHT, ui.chipLine, RIGHT, 0, 0)
    ui.chipArea:SetHeight(20)
    for i = 1, #PARTS_SHOWN do MakeChip(ui.chipArea, i) end
    ui.chipNone = W.Label(ui.chipArea, B.Font("text", 12), C.dim, L("CHIPS_NONE"))
    ui.chipNone:SetAnchor(TOPLEFT, ui.chipArea, TOPLEFT, 0, 3)
    -- (under the stats, or under food · mundus when there are no stats yet: see PaintStats)
    ui.PlaceChipLine = function(under)
        ui.chipLine:ClearAnchors()
        ui.chipLine:SetAnchor(TOPLEFT, under, BOTTOMLEFT, 0, 10)
        ui.chipLine:SetAnchor(TOPRIGHT, under, BOTTOMRIGHT, 0, 10)
    end
    ui.PlaceChipLine(statsCard)

    local wear = W.Button(d, L("WEAR"), function()
        local b = B.Get(ui.sel)
        if b then UI.AskWear(b, { preview = true }) end
    end, "plate", 176, 42)
    wear:AddLogo()
    wear:SetAnchor(BOTTOMRIGHT, d, BOTTOMRIGHT, 0, 0)
    ui.wearButton = wear
    -- Overwrite: an amber plate too (no logo), a little smaller than Wear
    local update = W.Button(d, L("UPDATE"), function()
        local b = B.Get(ui.sel)
        if b then UI.Update(b) end
    end, "plate", 148, 36)
    update:SetAnchor(RIGHT, wear, LEFT, -12, 0)
    update.tooltip = L("UPDATE_TT")
    -- Back to previous: as wide as its text, 20 px clear of Overwrite; when the window is too
    -- narrow for that it sits on its own line right above Overwrite (see UI.PlaceUndo)
    ui.undo = W.Button(d, L("UNDO"), function() B.Apply.Undo() end, "quiet", 130, 30)
    ui.undo.label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    Anim.Anchor(ui.undo.label, RIGHT, ui.undo, RIGHT, 0, 0)
    ui.overwriteButton = update
    ui.undo:SetAnchor(RIGHT, update, LEFT, -20, 0)
    ui.undo.tooltip = function()
        local u = B.Char().undo
        return u and L("UNDO_TT", u.name) or ""
    end

    -- what will change: over the arch and the right column
    local ch = W.Panel(page, 0.97)
    Anim.Anchor(ch, TOPLEFT, page, TOPLEFT, ARCH_X, CONTENT_Y)
    Anim.Anchor2(ch, BOTTOMRIGHT, page, BOTTOMRIGHT, -16, -14)
    ch:SetHidden(true)
    -- no draw level / mouse on the panel itself: the arch and the build are hidden while it's
    -- open, and a raised, mouse-enabled panel swallowed the clicks on its own buttons
    ui.changes = ch
    ui.chTitle = W.Label(ch, B.Font("title", 22), C.text, "")
    ui.chTitle:SetAnchor(TOPLEFT, ch, TOPLEFT, 20, 14)
    local legend = W.Label(ch, B.Font("text", 12), C.dim, L("CHANGES_LEGEND"))
    legend:SetAnchor(TOPLEFT, ch, TOPLEFT, 20, 48)
    ui.chList = W.Label(ch, B.Font("text", 14), C.soft, "")
    ui.chList:SetAnchor(TOPLEFT, ch, TOPLEFT, 20, 74)
    ui.chList:SetAnchor(TOPRIGHT, ch, TOPRIGHT, -20, 74)
    ui.chNote = W.Label(ch, B.Font("text", 13), C.warn, "")
    ui.chNote:SetAnchor(BOTTOMLEFT, ch, BOTTOMLEFT, 20, -58)
    ui.chShowFirst = W.Check(ch, L("CHANGES_ALWAYS"), function() return B.sv.showChanges end,
        function(v) B.sv.showChanges = v end, L("CHANGES_ALWAYS_TT"))
    ui.chShowFirst:SetAnchor(BOTTOMLEFT, ch, BOTTOMLEFT, 20, -24)
    local go = W.Button(ch, L("WEAR_NOW"), function()
        local plan = ui.changesPlan
        HideChanges()
        if plan then B.Apply.Run(B.Apply.Plan(plan.build)) end
    end, "plate", 176, 42)
    go:SetAnchor(BOTTOMRIGHT, ch, BOTTOMRIGHT, -16, -12)
    local cancel = W.Button(ch, L("CANCEL"), HideChanges, "normal", 110, 32)
    cancel:SetAnchor(RIGHT, go, LEFT, -12, 0)

    MakeCompare(page)
end

local function CreateRulesPage(win)
    local page = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    Anim.Fill(page, win)
    ui.rulesPage = page
    ui.planHeads = {}
    -- top: what rules do (left), the master switch (right)
    ui.rulesSwitch = W.Switch(page, L("RULES_ALL_ON"), function() return not B.Rules.IsPaused() end,
        function(v) B.Rules.SetPaused(not v) end, L("RULES_ALL_ON_TT"))
    ui.rulesSwitch:SetAnchor(TOPRIGHT, page, TOPRIGHT, -26, CONTENT_Y + 6)
    local info = W.Label(page, B.Font("text", 13), C.dim, L("RULES_INFO"))
    info:SetAnchor(TOPLEFT, page, TOPLEFT, 26, CONTENT_Y + 8)
    info:SetAnchor(TOPRIGHT, ui.rulesSwitch, TOPLEFT, -24, 2)
    ui.rulesPausedNote = W.Label(page, B.Font("text", 12), C.warn, L("RULES_PAUSED_NOTE"))
    ui.rulesPausedNote:SetAnchor(TOPRIGHT, ui.rulesSwitch, BOTTOMRIGHT, 0, 2)
    ui.rulesArea = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    ui.rulesArea:SetAnchor(TOPLEFT, page, TOPLEFT, 24, CONTENT_Y + 56)
    ui.rulesArea:SetAnchor(BOTTOMRIGHT, page, BOTTOMRIGHT, -24, -84)
    ui.rulesArea:SetMouseEnabled(true)
    ui.rulesArea:SetHandler("OnMouseWheel", function(_, delta) UI.ScrollRules(-delta) end)
    -- empty: a short how-to with an example
    ui.rulesEmpty = W.Label(ui.rulesArea, B.Font("text", 14), C.dim, L("RULES_EMPTY"))
    ui.rulesEmpty:SetAnchor(TOPLEFT, ui.rulesArea, TOPLEFT, 8, 8)
    ui.rulesEmpty:SetAnchor(TOPRIGHT, ui.rulesArea, TOPRIGHT, -8, 8)
    ui.rulesMore = W.Label(page, B.Font("text", 12), C.dim, L("RULES_MORE"))
    ui.rulesMore:SetAnchor(BOTTOMRIGHT, ui.rulesArea, BOTTOMRIGHT, 0, 18)
    ui.addRule = W.Button(page, L("RULE_ADD"), function(self) OpenNewRule(self) end, "plate", 190, 42)
    ui.addRule:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, 24, -20)
    local plan = W.Button(page, L("PLAN_ADD"), function(self) PlanMenu(self) end, "normal", 220, 34)
    plan:SetAnchor(LEFT, ui.addRule, RIGHT, 14, 0)
    plan.tooltip = L("PLAN_ADD_TT")
end

local function CreateCheckPage(win)
    local page = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    Anim.Fill(page, win)
    ui.checkPage = page
    ui.gcCards = {}

    -- "Wearing now": picture + name, what the check found, four meters, fix buttons
    local top = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    Anim.Anchor(top, TOPLEFT, page, TOPLEFT, 24, CONTENT_Y + 4)
    Anim.Anchor2(top, TOPRIGHT, page, TOPRIGHT, -24, CONTENT_Y + 4)
    top:SetHeight(156)
    ui.gcTop = top
    local bg = W.Tex(top)
    bg:SetAnchorFill(top)
    bg:SetColor(B.RGBA(C.card, 0.85))
    W.Frame(top, C.goldDark, 1)
    W.TopLight(top, 14, 0.35)
    local picBox = WINDOW_MANAGER:CreateControl(nil, top, CT_CONTROL)
    picBox:SetDimensions(50, 50)
    picBox:SetAnchor(TOPLEFT, top, TOPLEFT, 13, 13)
    W.Frame(picBox, C.goldDark, 1)
    ui.gcPic = W.Tex(picBox, nil, 48, 48)
    ui.gcPic:SetAnchor(CENTER, picBox, CENTER, 0, 0)
    ui.gcName = W.Label(top, B.Font("name", 15), C.text, "")
    ui.gcName:SetAnchor(TOPLEFT, ui.gcPic, TOPRIGHT, 12, 2)
    ui.gcName:SetWidth(300)
    ui.gcName:SetMaxLineCount(1)
    ui.gcSub = W.Label(top, B.Font("text", 12), C.theme, L("GC_WEARING_NOW"))
    ui.gcSub:SetAnchor(TOPLEFT, ui.gcName, BOTTOMLEFT, 0, 0)
    ui.gcLines = W.Label(top, B.Font("text", 13), C.soft, "")
    ui.gcLines:SetAnchor(TOPLEFT, ui.gcPic, BOTTOMLEFT, 0, 10)
    ui.gcLines:SetWidth(340)
    ui.gcLines:SetMaxLineCount(4)
    -- meters (right half)
    ui.gcMeters = {}
    local defs = { { "GC_M_COND", "%" }, { "GC_M_CHARGE", "%" }, { "GC_M_KITS", "" }, { "GC_M_GEMS", "" } }
    for i, d in ipairs(defs) do
        local m = WINDOW_MANAGER:CreateControl(nil, top, CT_CONTROL)
        m:SetDimensions(96, 44)
        m:SetAnchor(TOPRIGHT, top, TOPRIGHT, -14 - (4 - i) * 106, 14)
        m.caption = W.Label(m, B.Font("head", 10), C.dim, zo_strupper(L(d[1])))
        m.caption:SetAnchor(TOPLEFT, m, TOPLEFT, 0, 0)
        m.value = W.Label(m, B.Font("name", 15), C.text, "")
        m.value:SetAnchor(TOPLEFT, m.caption, BOTTOMLEFT, 0, -1)
        m.track = W.Tex(m, nil, 90, 3, C.line)
        m.track:SetAnchor(BOTTOMLEFT, m, BOTTOMLEFT, 0, 0)
        m.fill = W.Tex(m, nil, 1, 3, C.good)
        m.fill:SetAnchor(LEFT, m.track, LEFT, 0, 0)
        m.unit = d[2]
        m.key = W.Name("Meter")
        ui.gcMeters[i] = m
    end
    ui.gcFixAll = W.Button(top, L("FIX_ALL"), function() B.Fix.All() end, "plate", 150, 38)
    ui.gcFixAll:SetAnchor(BOTTOMRIGHT, top, BOTTOMRIGHT, -12, -12)
    ui.gcFixAll.tooltip = function() return L(IsBankOpen() and "FIX_ALL_TT_BANK" or "FIX_ALL_TT") end
    local recharge = W.Button(top, L("FIX_RECHARGE"), function() B.Fix.Recharge() end, "normal", 110, 30)
    recharge:SetAnchor(RIGHT, ui.gcFixAll, LEFT, -10, 0)
    recharge.tooltip = function() return L("FIX_RECHARGE_TT", B.Fix.ChargeAt()) end
    local repair = W.Button(top, L("FIX_REPAIR"), function() B.Fix.Repair() end, "normal", 100, 30)
    repair:SetAnchor(RIGHT, recharge, LEFT, -8, 0)
    repair.tooltip = function() return L("FIX_REPAIR_TT", B.Fix.RepairAt()) end

    -- automatic (0.6.0): a switch and a threshold slider each for repairing and recharging;
    -- on = done by itself after fights, with kits / filled soul gems from your bag, no question
    local auto = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    auto:SetAnchor(TOPLEFT, top, BOTTOMLEFT, 0, 10)
    auto:SetAnchor(TOPRIGHT, top, BOTTOMRIGHT, 0, 10)
    auto:SetHeight(80)
    local abg = W.Tex(auto)
    abg:SetAnchorFill(auto)
    abg:SetColor(B.RGBA(C.card, 0.85))
    W.Frame(auto, C.goldDark, 1)
    W.TopLight(auto, 14, 0.3)
    local divider = W.Tex(auto, nil, 1, 56, C.line)
    divider:SetAnchor(CENTER, auto, CENTER, 0, 0)
    ui.gcAuto = {}
    local AUTO = {
        { "FIX_AUTO_REPAIR", "FIX_AUTO_REPAIR_TT", B.Fix.AutoRepair, "autoRepair", B.Fix.RepairAt, B.Fix.SetRepairAt, "FIX_AT_REPAIR", "FIX_AT_REPAIR_TT", B.Fix.KitIcon, "FIX_KIT_TT" },
        { "FIX_AUTO_CHARGE", "FIX_AUTO_CHARGE_TT", B.Fix.AutoCharge, "autoCharge", B.Fix.ChargeAt, B.Fix.SetChargeAt, "FIX_AT_CHARGE", "FIX_AT_CHARGE_TT", B.Fix.GemIcon, "FIX_GEM_TT" },
    }
    for i, def in ipairs(AUTO) do
        local col = WINDOW_MANAGER:CreateControl(nil, auto, CT_CONTROL)
        col:SetDimensions(340, 60)
        if i == 1 then
            col:SetAnchor(TOPLEFT, auto, TOPLEFT, 16, 12)
        else
            col:SetAnchor(TOPLEFT, auto, TOP, 18, 12)
        end
        local a = {}
        -- the repair kit / filled soul gem from your bag (its own picture), how many, then the switch
        a.iconBox = WINDOW_MANAGER:CreateControl(nil, col, CT_CONTROL)
        a.iconBox:SetDimensions(24, 24)
        a.iconBox:SetAnchor(TOPLEFT, col, TOPLEFT, 0, 0)
        W.Frame(a.iconBox, C.goldDark, 1)
        a.icon = W.Tex(a.iconBox, nil, 22, 22)
        a.icon:SetAnchor(CENTER, a.iconBox, CENTER, 0, 0)
        a.count = W.Label(a.iconBox, B.Font("bold", 11), C.text, "", TEXT_ALIGN_RIGHT)
        a.count:SetAnchor(BOTTOMRIGHT, a.iconBox, BOTTOMRIGHT, 2, 3)
        a.count:SetDrawLevel(5)
        a.getIcon = def[9]
        W.Tip(a.iconBox, function()
            local _, n = a.getIcon()
            return L(def[10], n)
        end, TOP)
        a.switch = W.Switch(col, L(def[1]), def[3], function(v)
            B.sv.fix[def[4]] = v
            B.Fix.SettingsChanged()
        end, L(def[2]))
        a.switch:SetAnchor(LEFT, a.iconBox, RIGHT, 8, 0)
        a.caption = W.Label(col, B.Font("text", 12), C.dim, L(def[7]))
        a.caption:SetAnchor(TOPLEFT, col, TOPLEFT, 0, 34)
        a.slider = W.Slider(col, 200, B.Fix.MIN_AT, B.Fix.MAX_AT, 5, def[5], def[6],
            function(v) return v .. " %" end, L(def[8]))
        a.slider:SetAnchor(LEFT, a.caption, RIGHT, 8, 0)
        a.slider.onDone = function()
            B.Fix.SettingsChanged()
            UI.RefreshGearCheck()
        end
        ui.gcAuto[i] = a
    end

    -- every build with gear: cards in two columns (wheel scrolls)
    local head = W.Header(page, L("GC_ALL_HEAD"))
    head:SetAnchor(TOPLEFT, auto, BOTTOMLEFT, 0, 16)
    head:SetAnchor(TOPRIGHT, auto, BOTTOMRIGHT, 0, 16)
    ui.gcArea = WINDOW_MANAGER:CreateControl(nil, page, CT_CONTROL)
    ui.gcArea:SetAnchor(TOPLEFT, head, BOTTOMLEFT, 0, 10)
    ui.gcArea:SetAnchor(BOTTOMRIGHT, page, BOTTOMRIGHT, -24, -56)
    ui.gcArea:SetMouseEnabled(true)
    ui.gcArea:SetHandler("OnMouseWheel", function(_, delta)
        ui.gcOffset = math.max(0, (ui.gcOffset or 0) - delta * 2)
        UI.RefreshGearCheck()
    end)
    ui.gcEmpty = W.Label(ui.gcArea, B.Font("text", 13), C.dim, L("GC_NO_BUILDS"))
    ui.gcEmpty:SetAnchor(TOPLEFT, ui.gcArea, TOPLEFT, 4, 4)
    local hint = W.Label(page, B.Font("text", 12), C.dim, L("GC_HINT"))
    hint:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, 24, -20)
    hint:SetAnchor(BOTTOMRIGHT, page, BOTTOMRIGHT, -24, -20)
end

-- ---------------------------------------------------------------------------
-- Window: graphite background, frame with corner brackets, cartouche, tabs,
-- amber X to close, resize from every edge and corner

-- everything that depends on the window's size (called while resizing, too)
local function Relayout()
    if not ui.win then return end
    if ui.bg then W.FitBG(ui.bg) end   -- (in case the game has no OnRectChanged: see W.Tex)
    LayoutTabs()
    MoveUnderline(true)
    if ui.minimized then return end
    if ui.tab == "builds" then
        UI.RefreshList(true)
        if ui.changes:IsHidden() then UI.RefreshDetail() end
    elseif ui.tab == "rules" then
        UI.RefreshRules()
    end
end

-- ---------------------------------------------------------------------------
-- Wallpapers (2026-10-08): small glass arrows inside the window, in the narrow strips between the
-- frame line (6 px in) and the content (~17 px in) on the left and right (outside the window
-- they were hard to see; bigger ones touched the cards). Right = next, left = back; the new
-- picture fades in over the old (bg2) while sliding in from that side. The choice is kept in
-- sv.window.wall (0 = the Mundus night sky). The pictures are B.WALLS.

local WALL_MS = 550   -- the wallpaper switch (slide + crossfade)

local function WallIndex()
    local i = tonumber(B.sv.window.wall) or 0
    if not B.WALLS[i] then i = 0 end
    return i
end

function UI.WallTexture()
    return B.WALLS[WallIndex()]
end

local function WallTooltip(btn)
    local i = WallIndex()
    if btn.dir > 0 then
        InitializeTooltip(InformationTooltip, btn, LEFT, 6, 0, RIGHT)
    else
        InitializeTooltip(InformationTooltip, btn, RIGHT, -6, 0, LEFT)
    end
    SetTooltipText(InformationTooltip, L(btn.dir > 0 and "WALL_TT_NEXT" or "WALL_TT_PREV", L("WALL_" .. i), i + 1, #B.WALLS + 1))
end

function UI.StepWall(dir)
    local n = #B.WALLS + 1
    local i = (WallIndex() + dir) % n
    B.sv.window.wall = i
    local tex = B.WALLS[i]
    if not ui.bg then return end
    if not Anim.Enabled() then
        ui.bg:SetTexture(tex)
        return
    end
    -- sketch E "slide + crossfade": the new picture fades in over the old one while it glides
    -- in a little from the side of the arrow you clicked (next: from the right, back: from the
    -- left), then takes its place. (Controls can't clip, so the slide moves the part of the
    -- picture that's shown, not the texture control: no spill outside.)
    ui.bg2:SetTexture(tex)
    local w, h = ui.bg2:GetDimensions()
    local a = (w and h and h > 0) and w / h or 2
    local u0, u1, v0, v1 = 0, 1, 0, 1
    if a < 2 then
        u0, u1 = 0.5 - a / 4, 0.5 + a / 4
    else
        local f = 2 / a
        v0, v1 = 0.5 - f / 2, 0.5 + f / 2
    end
    -- (never past the picture's edge; the crop is centered, so both sides have the same room)
    local slide = math.min(0.12 * (u1 - u0), u0) * (dir > 0 and 1 or -1)
    Anim.Run("Skillbound_Wall", WALL_MS, Anim.Out, function(p)
        local d = slide * (1 - p)
        ui.bg2:SetTextureCoords(u0 - d, u1 - d, v0, v1)
        ui.bg2:SetAlpha(p)
    end, function()
        ui.bg:SetTexture(tex)
        W.FitBG(ui.bg)
        ui.bg2:SetAlpha(0)
        W.FitBG(ui.bg2)
    end)
end

-- sketch B "frosted glass blade" (wall_arrow.dds, white with its own alpha): dir 1 = right edge
-- (next), -1 = left edge, mirrored (back). Hover: amber, clearer, 15 % bigger. The click area is
-- the whole strip height around the arrow so it's easy to hit.
local function CreateWallButton(win, dir)
    local btn = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    btn.dir = dir
    btn:SetDimensions(11, 40)
    -- (centered in the strip: 6 .. 17 px from the window edge)
    if dir > 0 then
        btn:SetAnchor(RIGHT, win, RIGHT, -6, 0)
    else
        btn:SetAnchor(LEFT, win, LEFT, 6, 0)
    end
    btn:SetMouseEnabled(true)
    btn:SetDrawLevel(12)
    btn.arrow = W.Tex(btn, B.TEX .. "wall_arrow.dds", 9, 18)
    if dir < 0 then btn.arrow:SetTextureCoords(1, 0, 0, 1) end   -- (mirrored: points left)
    btn.arrow:SetColor(1, 1, 1, 1)
    btn.arrow:SetAlpha(0.85)
    Anim.Anchor(btn.arrow, CENTER, btn, CENTER, 0, 0)
    local key = "Skillbound_WallBtn" .. dir
    local function Hover(on)
        local from = btn.hoverP or 0
        local to = on and 1 or 0
        Anim.Run(key, Anim.MICRO, Anim.Out, function(p)
            local h = Anim.Lerp(from, to, p)
            btn.hoverP = h
            -- white -> amber, faint -> clear, a little bigger (no sideways nudge: the strip is narrow)
            local ar, ag, ab = B.RGBA(C.theme)
            btn.arrow:SetColor(1 + (ar - 1) * h, 1 + (ag - 1) * h, 1 + (ab - 1) * h, 1)
            btn.arrow:SetAlpha(0.85 + 0.15 * h)
            btn.arrow:SetScale(1 + 0.15 * h)
        end)
    end
    btn:SetHandler("OnMouseEnter", function(self)
        Hover(true)
        WallTooltip(self)
    end)
    btn:SetHandler("OnMouseExit", function()
        Hover(false)
        ClearTooltip(InformationTooltip)
    end)
    btn:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        UI.StepWall(dir)
        WallTooltip(self)
    end)
    return btn
end

local function SaveGeometry()
    local win = ui.win
    local x, y = win:GetLeft(), win:GetTop()
    Anim.Anchor(win, TOPLEFT, GuiRoot, TOPLEFT, x, y)
    local s = B.sv.window
    s.x, s.y = x, y
    if not ui.minimized then s.w, s.h = win:GetWidth(), win:GetHeight() end
end

-- Minimize: the window folds up to just its title plate (and back), height glides 220 ms
local HEADER_PARTS = {}
function UI.SetMinimized(on, instant)
    if not ui.win then return end
    ui.minimized = on
    B.sv.window.minimized = on or nil
    local win = ui.win
    local fullH = B.sv.window.h or WIN_H
    local from = win:GetHeight()
    local to = on and MINI_H or fullH
    if ui.minBtn then ui.minBtn:SetGlyph(on and "restore.dds" or "minus.dds") end
    win:SetResizeHandleSize(on and 0 or 8)
    -- the size limits would keep the window tall: allow the small height while minimized
    -- (restored to the normal limits once it's back up)
    if on then win:SetDimensionConstraints(MIN_W, MINI_H, MAX_W, MAX_H) end
    if on then
        for _, field in pairs(PAGES) do ui[field]:SetHidden(true) end
        for _, c in ipairs(HEADER_PARTS) do c:SetHidden(true) end
    end
    local function Done()
        win:SetHeight(to)
        if not on then
            win:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)
            for _, c in ipairs(HEADER_PARTS) do c:SetHidden(false) end
            UI.SetTab(ui.tab or "builds")
            local page = ui[PAGES[ui.tab or "builds"]]
            Anim.Alpha(page, 0, 1, Anim.STD, Anim.Out, "Skillbound_RestoreFade")
            Relayout()
        end
    end
    if instant then
        Done()
        return
    end
    Anim.Run("Skillbound_Minimize", Anim.STD, Anim.InOut, function(p)
        win:SetHeight(Anim.Lerp(from, to, p))
    end, Done)
end

function UI.Create()
    if ui.win then return end
    local s = B.sv.window
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Window")
    ui.win = win
    win:SetDimensions(zo_clamp(s.w or WIN_W, MIN_W, MAX_W), zo_clamp(s.h or WIN_H, MIN_H, MAX_H))
    win:SetHidden(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetDrawTier(DT_MEDIUM)
    if s.x and s.y then
        Anim.Anchor(win, TOPLEFT, GuiRoot, TOPLEFT, s.x, s.y)
    else
        Anim.Anchor(win, CENTER, GuiRoot, CENTER, 0, -10)
    end
    win:SetHandler("OnMoveStop", SaveGeometry)
    -- resize by dragging any edge or corner (the game shows its double-arrow cursor)
    win:SetResizeHandleSize(8)
    win:SetDimensionConstraints(MIN_W, MIN_H, MAX_W, MAX_H)
    win:SetHandler("OnResizeStart", function()
        ClearMenu()
        ui.resizing = true
    end)
    win:SetHandler("OnResizeStop", function()
        ui.resizing = false
        SaveGeometry()
        Relayout()
    end)

    -- background + frame (bg2 lies over it only while a new wallpaper fades in)
    local bg = W.Tex(win, B.BG)
    bg:SetAnchorFill(win)
    ui.bg = bg
    ui.bg2 = W.Tex(win, B.BG)
    ui.bg2:SetAnchorFill(win)
    ui.bg2:SetAlpha(0)
    bg:SetTexture(UI.WallTexture())
    ui.wallNext = CreateWallButton(win, 1)
    ui.wallPrev = CreateWallButton(win, -1)
    W.Frame(win, C.goldDark, 1)
    local inner = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    inner:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    inner:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -6, -6)
    W.Frame(inner, C.line, 1)
    W.TopLight(win, 40, 0.5)
    W.Brackets(win)
    -- credit, like a maker's mark: tiny faint text sitting on the bottom frame line, centered
    -- (a strip of the background behind it cuts the two frame lines), on every tab
    local credit = W.Label(win, B.Font("text", 10), C.faint, L("CREDIT", B.AUTHOR, B.VERSION))
    credit:SetAnchor(CENTER, win, BOTTOM, 0, -3)
    credit:SetDrawLevel(6)
    local creditBg = W.Tex(win, nil, 10, 12, C.panel, 1)
    creditBg:SetAnchor(LEFT, credit, LEFT, -8, 0)
    creditBg:SetAnchor(RIGHT, credit, RIGHT, 8, 0)
    creditBg:SetDrawLevel(5)

    -- title cartouche, inside the frame, centered, with the logo and a sheen
    local cart = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    cart:SetDimensions(340, 58)
    cart:SetAnchor(TOP, win, TOP, 0, 12)
    cart:SetDrawLevel(8)
    local cartFill = W.Tex(cart, B.TEX .. "cartouche_fill.dds")
    cartFill:SetAnchorFill(cart)
    cartFill:SetColor(0.06, 0.06, 0.06, 0.98)
    local cartEdge = W.Tex(cart, B.TEX .. "cartouche_edge.dds")
    cartEdge:SetAnchorFill(cart)
    cartEdge:SetColor(B.RGBA(C.gold))
    local logo = W.Tex(cart, B.LOGO, 34, 34)
    logo:SetAnchor(LEFT, cart, LEFT, 38, 0)
    ui.logo = logo
    local title = W.Label(cart, B.Font("title", 24), C.text, zo_strupper(L("TITLE")))
    title:SetAnchor(CENTER, cart, CENTER, 16, 1)
    ui.sheen = W.Tex(cart, B.TEX .. "sheen.dds", 90, 58)
    if ui.sheen.SetBlendMode then ui.sheen:SetBlendMode(TEX_BLEND_MODE_ADD) end
    ui.sheen:SetColor(1, 0.97, 0.92, 0.5)
    ui.sheen:SetHidden(true)
    ui.cart = cart
    -- the title plate opens the settings (Settings > Add-Ons > Skillbound). Hover: the edge and
    -- the letters turn amber, a warm light comes up behind it and a sheen crosses it (220 ms);
    -- click: it dips, the window closes and the settings page opens
    local cartGlow = W.Glow(win, 400, 110, C.theme, 0)
    cartGlow:SetAnchor(CENTER, cart, CENTER, 0, 0)
    cartGlow:SetDrawLevel(7)
    cart:SetMouseEnabled(true)
    local hoverP = 0
    local function PaintCart()
        local g, t, x = C.gold, C.theme, C.text
        cartEdge:SetColor(Anim.Lerp(g.r, t.r, hoverP), Anim.Lerp(g.g, t.g, hoverP), Anim.Lerp(g.b, t.b, hoverP), 1)
        title:SetColor(Anim.Lerp(x.r, t.r, hoverP), Anim.Lerp(x.g, t.g, hoverP), Anim.Lerp(x.b, t.b, hoverP), 1)
        cartGlow:SetAlpha(0.22 * hoverP)
    end
    local function CartHover(on)
        local from = hoverP
        Anim.Run("Skillbound_CartHover", Anim.STD, Anim.Out, function(p)
            hoverP = Anim.Lerp(from, on and 1 or 0, p)
            PaintCart()
        end)
    end
    cart:SetHandler("OnMouseEnter", function(self)
        CartHover(true)
        Anim.Sheen(ui.sheen, cart, "Skillbound_TitleSheen")
        InitializeTooltip(InformationTooltip, self, TOP, 0, 6, BOTTOM)
        SetTooltipText(InformationTooltip, L("TITLE_SETTINGS_TT"))
    end)
    cart:SetHandler("OnMouseExit", function()
        CartHover(false)
        ClearTooltip(InformationTooltip)
    end)
    cart:SetHandler("OnMouseUp", function(_, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        ClearTooltip(InformationTooltip)
        Anim.Pulse(cart, 0.96, 160, "Skillbound_CartPress")
        -- (the settings are a game menu: close the window first, else it stays on top of it)
        B.Later(function()
            UI.Hide()
            B.OpenSettings()
        end, 120)
    end)

    -- name plate, top left (sketch A, picked 2026-10-01): the character name in the title
    -- lettering, under it "Nightblade  <gold diamond>  1,092 CP"; stops before the title plate
    ui.charName = W.Label(win, B.Font("title", 19), C.text, "")
    ui.charName:SetAnchor(TOPLEFT, win, TOPLEFT, 28, 20)
    ui.charName:SetAnchor(RIGHT, cart, LEFT, -14, 0)
    ui.charName:SetMaxLineCount(1)
    ui.charClass = W.Label(win, B.Font("text", 13), C.dim, "")
    ui.charClass:SetAnchor(TOPLEFT, ui.charName, BOTTOMLEFT, 1, 1)
    ui.charGem = W.Tex(win, B.TEX .. "diamond_fill.dds", 7, 7, C.gold)
    ui.charGem:SetAnchor(LEFT, ui.charClass, RIGHT, 8, 1)
    ui.charCP = W.Label(win, B.Font("text", 13), C.theme, "")
    ui.charCP:SetAnchor(LEFT, ui.charGem, RIGHT, 8, -1)

    -- glass close button, top right (the minimize button was removed on request: X is enough)
    local close = W.CloseButton(win, function() UI.Hide() end, 22, L("CLOSE"))
    close:SetAnchor(RIGHT, win, TOPRIGHT, -22, 41)

    -- tabs + gliding underline
    ui.tabs, ui.tabGems = {}, {}
    for _, def in ipairs(TABS) do
        MakeTab(def)
        HEADER_PARTS[#HEADER_PARTS + 1] = ui.tabs[def.key]
    end
    for i = 1, #TABS - 1 do
        ui.tabGems[i] = W.Tex(win, B.TEX .. "diamond_fill.dds", 7, 7, C.goldDark)
        HEADER_PARTS[#HEADER_PARTS + 1] = ui.tabGems[i]
    end
    ui.underGlow = W.Glow(win, 80, 14, C.theme, 0.35)
    ui.underline = W.Tex(win, nil, 40, 2, C.theme)
    local rule = W.Tex(win, nil, 10, 1, C.line)
    rule:SetAnchor(TOPLEFT, win, TOPLEFT, 24, HEADER_H)
    rule:SetAnchor(TOPRIGHT, win, TOPRIGHT, -24, HEADER_H)
    for _, c in ipairs({ ui.underGlow, ui.underline, rule }) do HEADER_PARTS[#HEADER_PARTS + 1] = c end

    CreateBuildsPage(win)
    CreateRulesPage(win)
    CreateCheckPage(win)
    LayoutTabs()

    -- while resizing: lay out again (a few times a second); the arch light breathes
    local lastLayout = 0
    win:SetHandler("OnUpdate", B.Safe(function()
        local now = GetFrameTimeMilliseconds()
        if ui.resizing and now - lastLayout > 80 then
            lastLayout = now
            Relayout()
        end
        if B.Anim.Full() then
            ui.archLight:SetAlpha(0.19 + 0.04 * math.sin(now / 1000 * 1.4))
        end
    end, "window"))

    if SCENE_MANAGER and SCENE_MANAGER.RegisterTopLevel then
        SCENE_MANAGER:RegisterTopLevel(win, false)
    end
    s.minimized = nil   -- (saved by 0.3.1 / 0.3.2, when there was a minimize button)
end

-- opening: the window rises 10 px and grows from 96 % while it fades in; the cards and
-- slots arrive one after another; a sheen crosses the title
local function PlayOpen()
    local win = ui.win
    Anim.Run("Skillbound_Window", Anim.OPEN, Anim.Out, function(p)
        win:SetAlpha(p)
        win:SetScale(Anim.Lerp(0.96, 1, p))
        Anim.Offset(win, 0, 10 * (1 - p))
    end)
    if ui.tab == "builds" and not ui.minimized then
        local n = 0
        for _, row in ipairs(ui.rows) do
            if not row:IsHidden() then
                n = n + 1
                Anim.SlideIn(row, -10, 0, Anim.STD, nil, 60 + n * Anim.STAGGER, true)
            end
        end
        local i = 0
        for _, slot in pairs(ui.slots) do
            i = i + 1
            Anim.Alpha(slot, 0, 1, Anim.STD, Anim.Out, nil, nil, 90 + i * 18, true)
        end
    end
    Anim.Sheen(ui.sheen, ui.cart, "Skillbound_TitleSheen", 140)
end

function UI.Show()
    UI.Create()
    -- a launcher tooltip could stay behind under the window (it never got its mouse-exit)
    ClearTooltip(InformationTooltip)
    PaintHeaderInfo()
    Anim.Stop("Skillbound_Window")
    if SCENE_MANAGER and SCENE_MANAGER.ShowTopLevel then
        SCENE_MANAGER:ShowTopLevel(ui.win)
    else
        ui.win:SetHidden(false)
    end
    if not ui.sel or not B.Get(ui.sel) then
        ui.sel = B.Char().worn
        if not B.Get(ui.sel) then
            local first = B.SortedBuilds()[1]
            ui.sel = first and first.id or nil
        end
    end
    UI.CloseChanges(true)
    UI.CloseCompare(true)
    UI.SetTab(B.sv.window.tab or "builds")
    PlayOpen()
    -- text widths (tabs, part chips) are only right a frame after the first show
    B.Later(function()
        if UI.IsShown() then Relayout() end
    end, 50)
    -- first time ever: the welcome tour
    if not B.sv.tourDone then
        -- first time: start it; closed in the middle: carry on where it was
        local step = ui.tourStarted and ui.tourStep or 1
        ui.tourStarted = true
        if ui.tab ~= "builds" then UI.SetTab("builds", false) end
        B.Later(function() if UI.IsShown() then UI.TourStep(step) end end, 450)
    end
end

-- ---------------------------------------------------------------------------
-- Welcome tour (2026-10-01): the first time the window opens (sv.tourDone), three short
-- steps, each a small card beside what it explains, with an amber frame breathing around
-- it: 1 Save what I'm wearing, 2 Wear, 3 Favorite. Next / Skip; /sb tour shows it again.
-- each card sits ABOVE what it explains (dy = room for things right above it, like the
-- two import links over "Save what I'm wearing"); the card and the amber frame are their own
-- top-level windows, so nothing in the main window can draw over them (it did: unreadable)
local TOUR = {
    { target = "saveButton", title = "TOUR_1_T", text = "TOUR_1", dy = -38, align = LEFT },
    { target = "wearButton", title = "TOUR_2_T", text = "TOUR_2", dy = -14, align = RIGHT },
    { target = "favBtn", title = "TOUR_3_T", text = "TOUR_3", dy = -46, align = LEFT },
}
local TOUR_W, TOUR_H = 330, 178
-- the card can be dragged anywhere and resized from every edge / corner (user asked);
-- once moved, the next steps keep it where you put it (ui.tourMoved), and an X ends the tour
local TOUR_MIN_W, TOUR_MIN_H, TOUR_MAX_W, TOUR_MAX_H = 260, 150, 600, 380

local function MakeTour()
    local t = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Tour")
    t:SetDimensions(TOUR_W, TOUR_H)
    t:SetDrawTier(DT_HIGH)
    t:SetDrawLayer(DL_OVERLAY)
    t:SetMouseEnabled(true)
    t:SetMovable(true)
    t:SetClampedToScreen(true)
    t:SetResizeHandleSize(8)
    t:SetDimensionConstraints(TOUR_MIN_W, TOUR_MIN_H, TOUR_MAX_W, TOUR_MAX_H)
    t:SetHidden(true)
    -- moved / resized once: it stays there, also after a restart (sv.places.tour)
    local placed, savePlace = W.RememberPlace(t, "tour", true, true)
    ui.tourMoved = placed or nil
    -- (resizing from the bottom would push the top up while it hangs above a button: pin it first)
    t:SetHandler("OnResizeStart", function(self)
        ui.tourMoved = true
        Anim.Anchor(self, TOPLEFT, GuiRoot, TOPLEFT, self:GetLeft(), self:GetTop())
    end)
    t:SetHandler("OnResizeStop", function() savePlace() end)
    t:SetHandler("OnMoveStop", function()
        ui.tourMoved = true
        savePlace()   -- (anchored to the screen now, not to the button it explains)
    end)
    -- solid card: dark fill, pewter frame, brackets, a thin amber line on top
    local fill = W.Tex(t)
    fill:SetAnchorFill(t)
    fill:SetColor(B.RGBA(C.panel, 1))
    W.Frame(t, C.goldDark, 1)
    W.Brackets(t, 2, 6)
    local top = W.Tex(t, nil, 10, 2, C.theme, 0.9)
    top:SetAnchor(TOPLEFT, t, TOPLEFT, 1, 1)
    top:SetAnchor(TOPRIGHT, t, TOPRIGHT, -1, 1)
    -- the X (top right) ends the tour, like Skip
    t.close = W.CloseButton(t, function() UI.TourStep(#TOUR + 1) end, 16, L("TOUR_CLOSE_TT"))
    t.close:SetAnchor(TOPRIGHT, t, TOPRIGHT, -12, 12)
    -- everything is anchored on both sides, so it follows the card's size
    t.step = W.Label(t, B.Font("head", 11), C.dim, "")
    t.step:SetAnchor(TOPLEFT, t, TOPLEFT, 18, 14)
    t.title = W.Label(t, B.Font("title", 17), C.theme, "")
    t.title:SetAnchor(TOPLEFT, t, TOPLEFT, 18, 32)
    t.title:SetAnchor(TOPRIGHT, t, TOPRIGHT, -18, 32)
    t.title:SetMaxLineCount(1)
    t.next = W.Button(t, "", function() UI.TourStep((ui.tourStep or 1) + 1) end, "normal", 100, 28)
    t.next:SetAnchor(BOTTOMRIGHT, t, BOTTOMRIGHT, -14, -14)
    t.skip = W.Button(t, L("TOUR_SKIP"), function() UI.TourStep(#TOUR + 1) end, "quiet", 70, 20)
    t.skip:SetAnchor(RIGHT, t.next, LEFT, -12, 0)
    t.text = W.Label(t, B.Font("text", 13), C.soft, "")
    t.text:SetAnchor(TOPLEFT, t, TOPLEFT, 18, 62)
    t.text:SetAnchor(BOTTOMRIGHT, t.next, TOPRIGHT, 0, -8)   -- a bigger card shows more lines
    -- the amber frame around the thing being explained (breathes while shown)
    local hl = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_TourFrame")
    hl:SetDrawTier(DT_HIGH)
    hl:SetDrawLayer(DL_CONTROLS)
    hl:SetMouseEnabled(false)
    hl.frame = W.Frame(hl, C.theme, 1, 2)
    hl.glow = W.Glow(hl, 10, 10, C.theme, 0.25)
    hl.glow:SetAnchorFill(hl)
    hl:SetHidden(true)
    hl:SetHandler("OnUpdate", B.Safe(function()
        local a = 0.55 + 0.45 * math.sin(GetFrameTimeSeconds() * 4)
        hl:SetAlpha(Anim.Enabled() and a or 1)
    end, "welcome"))
    t.hl = hl
    ui.tour = t
end

function UI.TourStep(i)
    if not ui.tour then MakeTour() end
    local t = ui.tour
    ui.tourStep = i
    local def = TOUR[i]
    if not def then
        B.sv.tourDone = true
        Anim.Run("Skillbound_Tour", Anim.CLOSE, Anim.In, function(p) t:SetAlpha(1 - p) t.hl:SetAlpha(1 - p) end,
            function() t:SetHidden(true) t.hl:SetHidden(true) end)
        return
    end
    local target = ui[def.target]
    -- (no build yet: Wear / Favorite aren't shown, so their steps are skipped)
    local hidden = target and (target.IsControlHidden and target:IsControlHidden() or target:IsHidden())
    if not target or hidden then UI.TourStep(i + 1) return end
    t.step:SetText(zo_strupper(L("TOUR_STEP", i, #TOUR)))
    t.title:SetText(L(def.title))
    t.text:SetText(L(def.text))
    t.next:SetText(L(i == #TOUR and "TOUR_DONE" or "TOUR_NEXT"))
    -- above the target, lined up with its left (or right) edge; moved by you: stays put
    if not ui.tourMoved then
        local point = def.align == RIGHT and BOTTOMRIGHT or BOTTOMLEFT
        local rel = def.align == RIGHT and TOPRIGHT or TOPLEFT
        Anim.Anchor(t, point, target, rel, 0, def.dy)
    end
    t.hl:ClearAnchors()
    t.hl:SetAnchor(TOPLEFT, target, TOPLEFT, -4, -4)
    t.hl:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, 4, 4)
    t.hl:SetHidden(false)
    t:SetHidden(false)
    Anim.SlideIn(t, 0, 10, Anim.STD, "Skillbound_Tour")
end

-- the tour lives in its own windows: it hides with the main window and comes back with it
local function HideTour()
    if ui.tour then
        ui.tour:SetHidden(true)
        ui.tour.hl:SetHidden(true)
    end
end

function UI.StartTour()
    ui.tourMoved = nil   -- (/sb tour: back beside the buttons)
    if B.sv.places then B.sv.places.tour = nil end
    if ui.tour then ui.tour:SetDimensions(TOUR_W, TOUR_H) end
    UI.Show()
    if ui.tab ~= "builds" then UI.SetTab("builds", false) end
    B.Later(function() UI.TourStep(1) end, 400)
end

-- Preview on the character: the window becomes part of the preview screen (right side)
function UI.Window()
    UI.Create()
    return ui.win
end

function UI.BeforePreview()
    UI.CloseChanges(true)
    UI.CloseCompare(true)
    HideTour()
    if ui.minimized then UI.SetMinimized(false, true) end
    Anim.Stop("Skillbound_Window")
    if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel and not ui.win:IsHidden() then
        SCENE_MANAGER:HideTopLevel(ui.win)
    end
    ui.win:SetAlpha(1)
    ui.win:SetScale(1)
    -- on the right, the character stands on the left (not saved as your window position)
    ui.win:ClearAnchors()
    ui.win:SetAnchor(RIGHT, GuiRoot, RIGHT, -30, 0)
end

function UI.AfterPreview(reopen)
    if not ui.win then return end
    local s = B.sv.window
    if s.x and s.y then
        Anim.Anchor(ui.win, TOPLEFT, GuiRoot, TOPLEFT, s.x, s.y)
    else
        Anim.Anchor(ui.win, CENTER, GuiRoot, CENTER, 0, -10)
    end
    if reopen then B.Later(UI.Show, 60) end
end

-- closing: fades and shrinks to 97 %, then hides
function UI.Hide()
    ClosePicker()
    CloseNewRule()
    if B.Preview and B.Preview.IsActive() then
        B.Preview.Stop(false)
        return
    end
    if not ui.win or ui.win:IsHidden() then return end
    HideTour()
    local win = ui.win
    Anim.Run("Skillbound_Window", Anim.CLOSE, Anim.In, function(p)
        win:SetAlpha(1 - p)
        win:SetScale(Anim.Lerp(1, 0.97, p))
    end, function()
        if SCENE_MANAGER and SCENE_MANAGER.HideTopLevel then
            SCENE_MANAGER:HideTopLevel(win)
        else
            win:SetHidden(true)
        end
        win:SetAlpha(1)
        win:SetScale(1)
        Anim.Offset(win, 0, 0)
    end)
end

function UI.Toggle()
    if ui.win and not ui.win:IsHidden() and not Anim.IsRunning("Skillbound_Window") then UI.Hide() else UI.Show() end
end

function UI.IsShown()
    return ui.win ~= nil and not ui.win:IsHidden()
end

function UI.Refresh()
    if not UI.IsShown() or ui.minimized then return end
    if ui.tab == "builds" then
        UI.RefreshList()
        UI.RefreshDetail()
    elseif ui.tab == "rules" then
        UI.RefreshRules()
    else
        UI.RefreshGearCheck()
    end
end

-- a gear / skill slot flashes the moment its piece / skill goes on
local function FlashStep(step, color)
    if not UI.IsShown() or ui.tab ~= "builds" or ui.minimized then return end
    local target
    if step.slot then target = ui.slots[step.slot] end
    if step.cat then
        for _, s in ipairs(ui.skills) do
            if s.cat == step.cat and s.skillSlot == step.skillSlot then target = s end
        end
    end
    if target then Anim.Flash(target.flash, color or C.theme, Anim.FLASH, target.hoverKey .. "F") end
end

function UI.Init()
    ui.sel = B.sv.window.sel
    B.callbacks:RegisterCallback("BuildsChanged", UI.Refresh)
    B.callbacks:RegisterCallback("RulesChanged", function() if UI.IsShown() then UI.RefreshRules() end end)
    B.callbacks:RegisterCallback("PrebuffChanged", UI.Refresh)
    B.callbacks:RegisterCallback("FixDone", UI.Refresh)
    B.callbacks:RegisterCallback("SettingsChanged", UI.Refresh)
    B.callbacks:RegisterCallback("PreviewChanged", function(on)
        if ui.previewBtn then ui.previewBtn:SetText(L(on and "PREVIEW_STOP" or "PREVIEW_START")) end
    end)
    B.callbacks:RegisterCallback("StepDone", function(step) FlashStep(step, C.theme) end)
    B.callbacks:RegisterCallback("StepFailed", function(step) FlashStep(step, C.warn) end)
    B.callbacks:RegisterCallback("Worn", function(b)
        -- the build you just put on becomes the picked card (the selection used to stay on the old
        -- one when you wore it from the button, the wheel, a keybind or a rule)
        if b and not b.undo and b.id and B.Get(b.id) and ui.sel ~= b.id then
            ui.sel = b.id
            B.sv.window.sel = b.id
        end
        UI.Refresh()
        if UI.IsShown() then
            Anim.Sheen(ui.sheen, ui.cart, "Skillbound_TitleSheen")
            Anim.Pulse(ui.logo, 1.2, 400, "Skillbound_LogoPulse")
        end
    end)
    B.callbacks:RegisterCallback("PositionsReset", function()
        B.sv.window.w, B.sv.window.h = nil, nil
        if ui.win then
            ui.win:SetDimensions(WIN_W, WIN_H)
            Anim.Anchor(ui.win, CENTER, GuiRoot, CENTER, 0, -10)
            Relayout()
        end
    end)
    -- inventory changes come in bursts while wearing a build: refresh once afterwards
    B.callbacks:RegisterCallback("InventoryChanged", function()
        if not UI.IsShown() then return end
        B.EM:UnregisterForUpdate("Skillbound_UIRefresh")
        B.EM:RegisterForUpdate("Skillbound_UIRefresh", 600, function()
            B.EM:UnregisterForUpdate("Skillbound_UIRefresh")
            if ui.changes and not ui.changes:IsHidden() then return end
            UI.Refresh()
        end)
    end)
end
