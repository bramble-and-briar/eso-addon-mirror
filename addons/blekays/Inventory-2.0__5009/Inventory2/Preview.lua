InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- A sample bag, drawn beside the settings page in a window of its own, so that a switch can be
-- seen rather than imagined. Every module is in it, in the order the real list would put them in
-- and whether or not it is switched on, because a module that was left out would leave its glow
-- and its animation with nothing to play on; one that is off is drawn dim in its place instead.
--
-- It works: clicking a header opens or closes it the way clicking one in the bag does, and what
-- opens holds a couple of made-up items. Nothing in it touches the real lists.
--
-- The rows are the real ones: the same templates the bag uses, dressed by the same code, framed
-- by the same frame pass, animated by the same clock. What it is made of comes from
-- IG.PreviewRows() (InventoryGrouping.lua); this file only puts it on screen.
--
-- It follows the settings page: shown when the page opens, hidden when it closes or when another
-- addon's page takes its place, and the switch in General can put it away for good.

local WINDOW_MANAGER = WINDOW_MANAGER
local CALLBACK_MANAGER = CALLBACK_MANAGER

-- The bag's own list is this wide (InventoryGrouping.xml), and the preview is only honest at the
-- width the rows were drawn for: narrower and every name would shrink to fit.
local ROW_WIDTH = 565
local PADDING = 14

local GAP_FROM_SETTINGS = 20

-- The window says what it is across the head of it, the plain way round: a name on a window is
-- read before anything under it, and a name turned on its side is not read at all. The room it
-- takes is the sample's, and worth it.
local TITLE_FONT = "$(BOLD_FONT)|33|soft-shadow-thick" -- ZoFontWinH2, a size and a half up
local TITLE_TEXT = "INVENTORY PREVIEW"
local TITLE_COLOR = "FFD84A"
local TITLE_HEIGHT = 38      -- the line the title stands on
local TITLE_GAP = 10         -- between that line and the first row

-- What a row in the bag carries besides its name. Every one of these is a path the game ships
-- with and another addon already draws, so none of them can turn out not to be there.
local LOCK_TEXTURE = "EsoUI/Art/Miscellaneous/status_locked.dds"
local KNOWN_TEXTURE = "EsoUI/Art/Miscellaneous/check_icon_64.dds"
local COIN_TEXTURE = "EsoUI/Art/currency/currency_gold.dds"
local LOCK_SIZE, LOCK_LEFT = 24, 38 -- the column the game keeps for a row's status icon
local KNOWN_SIZE, KNOWN_GAP = 20, 10
local COIN_SIZE, COIN_RIGHT = 18, 16
local PRICE_GAP = 5
local PRICE_FONT = "ZoFontGameShadow"
local PRICE_COLOR = "E8D5A9"

-- What the sample leaves out -- empty categories, and modules that are switched off -- is asked
-- for from the settings page (General > Preview), not from this window. They are settings like
-- any other and the page draws a switch better than a window's edge can.

-- A module whose switch is off: still there, still in its place, but plainly not running.
local DIM_ALPHA = 0.4

-- Shaped like one of the game's own menu panels rather than like a window: a thin line down
-- each side fading out toward its ends, over a half-transparent black doing the same at the
-- top and the bottom. Nothing is squared off, so the sample sits on the screen instead of
-- standing in a second window in front of it.
local PANEL_HEIGHT = 675    -- what it starts at, until there is a settings window to measure
local SCROLLBAR_ROOM = 20   -- kept clear on the right, where the bar runs
local CHROME_FADE = 90      -- how far the black and the lines take to come and go
local CHROME_BLACK = { 0, 0, 0, 0.85 }
-- The addon's own cream rather than the title's yellow: a line down the side of a panel is
-- furniture, and the game's own are never the loudest thing on screen.
local LINE_COLOR = { 0.773, 0.761, 0.62, 0.5 } -- IG.DEFAULT_ICON_COLOR
local LINE_WIDTH = 1        -- a hairline, the width the game rules its own panels off with

-- One control per row per kind; a row only ever builds the kind it is asked for.
local KINDS = { "header", "frame", "item", "section", "setrule", "strip" }
local TEMPLATE = {
    header = "InventoryGrouping_HeaderRow",
    frame = "InventoryGrouping_Spacer",
    item = "InventoryGrouping_StoredItemRow",
    -- The heading over a run of categories: the bag draws it on a spacer too.
    section = "InventoryGrouping_Spacer",
    -- And a set drawn as a line rather than as a button.
    setrule = "InventoryGrouping_Spacer",
    -- A section in Chips or Tiles (LAYOUT): one row standing for every category in it. Its own
    -- buttons are built by hand (DressStrip) on a plain spacer, the way a chip never is here.
    strip = "InventoryGrouping_Spacer",
}

-- The same look ModuleStrip.lua's real buttons use, read off it rather than guessed at again.
-- Read when a row is actually dressed, not here: this file loads before ModuleStrip.lua
-- (Inventory2.txt), so IG.MODULE_STRIP_LOOKS is not written yet at this point.
local STRIP_ICON_GAP = 5
local STRIP_GROUND_SHADE = 0.3
local STRIP_GROUND_ALPHA = 0.85
local STRIP_EDGE_ALPHA = 0.6

local window, rowPool

---------------------------------------------------------------------------
-- Where it stands
---------------------------------------------------------------------------

-- Beside LAM's settings window, starting where it starts and ending where it ends. There is
-- nothing to remember and nothing to drag: it has one place, worked out from the window it
-- belongs to, so it is in it on every screen without anyone having to put it there.
--
-- That window is 1010 by 914 in the interface's own units and always will be, since the game
-- scales the whole interface to the screen rather than the sizes written inside it. It is
-- measured rather than copied all the same, so the two stay level to the pixel and a change in
-- the library carries this window with it.
local function PlaceWindow()
    if not window then return end
    local settings = LAMAddonSettingsWindow
    window:ClearAnchors()
    if not settings then
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        return
    end
    window:SetHeight(settings:GetHeight())
    window:SetAnchor(TOPLEFT, settings, TOPRIGHT, GAP_FROM_SETTINGS, 0)
end

---------------------------------------------------------------------------
-- Answering the mouse
---------------------------------------------------------------------------

-- The header template comes with the bag's own handlers on it. The two that only light the row
-- are worth keeping, but they also show set tooltips and collapse hints, which would have the
-- preview reaching for an item that does not exist; these light it and nothing else.
local function Lit(control)
    IG.SetHeaderSurface(control, control.igHoverColor)
end

local function Unlit(control)
    IG.SetHeaderSurface(control, control.igBgColor)
end

-- And the click is ours: the bag's would write to the real open/closed memory and rebuild the
-- real lists. A row with no key of its own -- a category switched off -- does nothing.
local function Clicked(control, _, upInside)
    if not upInside then return end
    local data = control.igData
    if not data or not data.igPreviewKey then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    IG.TogglePreviewNode(data.igPreviewKey)
    IG.RefreshPreview()
end

---------------------------------------------------------------------------
-- Building it once
---------------------------------------------------------------------------

-- A piece of the chrome, with a colour at its top and a colour at its bottom. Flat when the two
-- are the same, a fade when one of them is nothing.
local function Paint(piece, r, g, b, topAlpha, bottomAlpha)
    piece:SetVertexColors(VERTEX_POINTS_TOPLEFT, r, g, b, topAlpha)
    piece:SetVertexColors(VERTEX_POINTS_TOPRIGHT, r, g, b, topAlpha)
    piece:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, r, g, b, bottomAlpha)
    piece:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, r, g, b, bottomAlpha)
end

-- Three of them, one under the other: a fade in, a flat run and a fade out. Whatever is drawn
-- this way ends without an edge anywhere.
local function ThreePieces(tlw)
    local pieces = {}
    for index = 1, 3 do
        local piece = WINDOW_MANAGER:CreateControl(nil, tlw, CT_TEXTURE)
        piece:SetDrawLayer(DL_BACKGROUND)
        pieces[index] = piece
    end
    return pieces[1], pieces[2], pieces[3]
end

-- The black the sample sits on, gone by the time it reaches the top and the bottom.
local function CreateGround(tlw)
    local r, g, b, alpha = unpack(CHROME_BLACK)
    local top, middle, bottom = ThreePieces(tlw)

    top:SetHeight(CHROME_FADE)
    top:SetAnchor(TOPLEFT, tlw, TOPLEFT)
    top:SetAnchor(TOPRIGHT, tlw, TOPRIGHT)
    Paint(top, r, g, b, 0, alpha)

    bottom:SetHeight(CHROME_FADE)
    bottom:SetAnchor(BOTTOMLEFT, tlw, BOTTOMLEFT)
    bottom:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT)
    Paint(bottom, r, g, b, alpha, 0)

    middle:SetAnchor(TOPLEFT, top, BOTTOMLEFT)
    middle:SetAnchor(BOTTOMRIGHT, bottom, TOPRIGHT)
    Paint(middle, r, g, b, alpha, alpha)
end

-- One thin line down one side, gone by the time it reaches either end.
local function CreateSideLine(tlw, topPoint, bottomPoint, offsetX)
    local r, g, b, alpha = unpack(LINE_COLOR)
    local top, middle, bottom = ThreePieces(tlw)

    top:SetDimensions(LINE_WIDTH, CHROME_FADE)
    top:SetAnchor(TOPLEFT, tlw, topPoint, offsetX, 0)
    Paint(top, r, g, b, 0, alpha)

    bottom:SetDimensions(LINE_WIDTH, CHROME_FADE)
    bottom:SetAnchor(BOTTOMLEFT, tlw, bottomPoint, offsetX, 0)
    Paint(bottom, r, g, b, alpha, 0)

    middle:SetAnchor(TOPLEFT, top, BOTTOMLEFT)
    middle:SetAnchor(BOTTOMRIGHT, bottom, TOPRIGHT)
    Paint(middle, r, g, b, alpha, alpha)
end

local function CreateWindow()
    local tlw = WINDOW_MANAGER:CreateTopLevelWindow("InventoryGroupingPreview")
    tlw:SetHidden(true)
    tlw:SetMouseEnabled(true)
    -- It keeps this size: as tall as the window it stands beside, whatever is in it. More than
    -- fits is scrolled to rather than grown into.
    tlw:SetDimensions(ROW_WIDTH + PADDING * 2 + SCROLLBAR_ROOM, PANEL_HEIGHT)

    CreateGround(tlw)
    CreateSideLine(tlw, TOPLEFT, BOTTOMLEFT, 0)
    CreateSideLine(tlw, TOPRIGHT, BOTTOMRIGHT, -LINE_WIDTH)

    -- Across the head of the window, on a line of its own that the sample starts under.
    local title = WINDOW_MANAGER:CreateControl("$(parent)Title", tlw, CT_LABEL)
    title:SetFont(TITLE_FONT)
    title:SetText(string.format("|c%s%s|r", TITLE_COLOR, TITLE_TEXT))
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetHeight(TITLE_HEIGHT)
    title:SetAnchor(TOPLEFT, tlw, TOPLEFT, PADDING, PADDING)
    title:SetAnchor(TOPRIGHT, tlw, TOPRIGHT, -PADDING, PADDING)

    local listTop = PADDING + TITLE_HEIGHT + TITLE_GAP
    local container = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Container", tlw,
        "ZO_ScrollContainer")
    container:SetAnchor(TOPLEFT, tlw, TOPLEFT, PADDING, listTop)
    container:SetAnchor(BOTTOMRIGHT, tlw, BOTTOMRIGHT, -PADDING, -PADDING)

    -- The template hangs the bar off the container's right edge, which puts it hard against the
    -- rows with all the spare width on the other side. Everything right of the rows is the bar's
    -- run -- the strip kept clear for it and the padding beyond -- so it is hung off the window
    -- at the middle of that instead, by its own middle, whatever width the game gives it.
    local bar = container:GetNamedChild("ScrollBar")
    if bar then
        local middle = -(SCROLLBAR_ROOM + PADDING) / 2
        bar:ClearAnchors()
        bar:SetAnchor(TOP, tlw, TOPRIGHT, middle, listTop)
        bar:SetAnchor(BOTTOM, tlw, BOTTOMRIGHT, middle, -PADDING)
    end
    local scroll = container:GetNamedChild("ScrollChild")

    -- Rows hang from here, so the title line is out of their way and they can be re-anchored
    -- among themselves without touching it.
    local list = WINDOW_MANAGER:CreateControl("$(parent)List", scroll, CT_CONTROL)
    list:SetWidth(ROW_WIDTH)
    list:SetAnchor(TOPLEFT, scroll, TOPLEFT)
    scroll:SetResizeToFitDescendents(true)
    tlw.list = list
    tlw.title = title

    return tlw
end
-- Controls are made as they are first asked for and kept afterwards.
--
-- Every one is named, and named after its place in the list. A header's template names its own
-- children "$(parent)Marker" and the like, so a nameless row would hand every one of them the
-- same name and the second row would be refused -- and SetupHeaderRow looks them up by name.
local function ControlFor(index, kind)
    local row = rowPool[index]
    if not row then
        row = {}
        rowPool[index] = row
    end
    local control = row[kind]
    if not control then
        control = WINDOW_MANAGER:CreateControlFromVirtual(
            string.format("$(parent)%s%d", kind, index), window.list, TEMPLATE[kind])
        if kind == "header" then
            control:SetHandler("OnMouseEnter", Lit)
            control:SetHandler("OnMouseExit", Unlit)
            control:SetHandler("OnMouseUp", Clicked)
        else
            -- Item rows carry a tooltip handler that would look up an item link we made up.
            control:SetMouseEnabled(false)
            control:SetHandler("OnMouseEnter", nil)
            control:SetHandler("OnMouseExit", nil)
        end
        row[kind] = control
    end
    return control
end

---------------------------------------------------------------------------
-- Drawing it again
---------------------------------------------------------------------------

local function HideOthers(index, keep)
    local row = rowPool[index]
    for _, kind in ipairs(KINDS) do
        if kind ~= keep and row[kind] then row[kind]:SetHidden(true) end
    end
end

local function HideFrom(index)
    for i = index, #rowPool do
        for _, kind in ipairs(KINDS) do
            if rowPool[i][kind] then rowPool[i][kind]:SetHidden(true) end
        end
    end
end

-- The bag's own item row reads its icon, its stack and its quality colour off an item link. The
-- preview has no link, so its items are dressed straight from what the sample says they are.
-- The lock, the tick and the price. Made as the row first needs them and kept afterwards, like
-- everything else here, and hidden rather than thrown away when a row goes without.
local function DressExtras(control, data, name)
    if not control.igLock then
        local lock = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        lock:SetTexture(LOCK_TEXTURE)
        lock:SetDimensions(LOCK_SIZE, LOCK_SIZE)
        lock:SetAnchor(CENTER, control, LEFT, LOCK_LEFT, 0)
        control.igLock = lock

        local known = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        known:SetTexture(KNOWN_TEXTURE)
        known:SetDimensions(KNOWN_SIZE, KNOWN_SIZE)
        control.igKnown = known

        local coin = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        coin:SetTexture(COIN_TEXTURE)
        coin:SetDimensions(COIN_SIZE, COIN_SIZE)
        coin:SetAnchor(RIGHT, control, RIGHT, -COIN_RIGHT, 0)
        control.igCoin = coin

        local price = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        price:SetFont(PRICE_FONT)
        price:SetColor(IG.HexToRGB(PRICE_COLOR))
        price:SetAnchor(RIGHT, coin, LEFT, -PRICE_GAP, 0)
        control.igPrice = price
    end

    control.igLock:SetHidden(not data.locked)
    control.igPrice:SetText(data.price or "")
    control.igCoin:SetHidden(data.price == nil)

    -- The tick stands where the name ends, which is not where its label ends: the label is a
    -- fixed width and the name inside it is however long it is.
    control.igKnown:ClearAnchors()
    control.igKnown:SetAnchor(LEFT, name, LEFT, name:GetTextWidth() + KNOWN_GAP, 0)
    control.igKnown:SetHidden(not data.known)
end

-- One box per category in the strip, kept on the row the way the bag's own pooled rows keep
-- theirs (ControlFor above): made the first time a row needs that many, hidden rather than
-- thrown away once a shorter strip asks for fewer of them.
local function ChipBox(control, index)
    control.igChips = control.igChips or {}
    local chip = control.igChips[index]
    if chip then return chip end
    chip = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    IG.AddEdges(chip)
    chip.ground = WINDOW_MANAGER:CreateControl(nil, chip, CT_TEXTURE)
    chip.ground:SetAnchor(TOPLEFT, chip, TOPLEFT, 1, 1)
    chip.ground:SetAnchor(BOTTOMRIGHT, chip, BOTTOMRIGHT, -1, -1)
    chip.ground:SetDrawLevel(2)
    chip.icon = WINDOW_MANAGER:CreateControl(nil, chip, CT_TEXTURE)
    chip.icon:SetDrawLevel(3)
    chip.label = WINDOW_MANAGER:CreateControl(nil, chip, CT_LABEL)
    chip.label:SetDrawLevel(3)
    chip.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    chip.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    chip.name = WINDOW_MANAGER:CreateControl(nil, chip, CT_LABEL)
    chip.name:SetDrawLevel(3)
    chip.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    chip.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    control.igChips[index] = chip
    return chip
end

-- A whole section's worth of categories, drawn the way ModuleStrip.lua's real Chips and Tiles
-- buttons look -- plate, outline and all -- but never answering the mouse: there is no real
-- list behind the sample for a click to open.
local function DressStrip(control, data)
    control.igData = nil
    control:SetHeight(data.rowHeight)
    IG.ApplyFrames(control, data.igFrames, true)

    local looks = IG.MODULE_STRIP_LOOKS or {}
    local style = IG.MODULE_STRIP_STYLE or {}
    local look = looks[data.mode]
    local items = data.items
    local perLine = (look and look.perLine) or zo_max(1, #items)
    local pad, gap = (look and look.pad) or 4, (look and look.gap) or 4
    local chipHeight = (look and look.height) or 30
    local chipWidth = (ROW_WIDTH - pad * 2 - gap * (perLine - 1)) / perLine
    local tileIconSize = style.tileIconSize or 36

    for index, info in ipairs(items) do
        local chip = ChipBox(control, index)
        chip:SetHidden(false)
        chip:SetDimensions(chipWidth, chipHeight)
        local line = zo_floor((index - 1) / perLine)
        local col = (index - 1) % perLine
        chip:ClearAnchors()
        chip:SetAnchor(TOPLEFT, control, TOPLEFT,
            pad + col * (chipWidth + gap), pad + line * (chipHeight + gap))

        local r, g, b = IG.HexToRGB(info.color)
        chip.ground:SetColor(r * STRIP_GROUND_SHADE, g * STRIP_GROUND_SHADE, b * STRIP_GROUND_SHADE, 1)
        chip.ground:SetAlpha(STRIP_GROUND_ALPHA)
        for _, edge in ipairs(chip.edges) do
            edge:SetColor(r, g, b, 1)
            edge:SetAlpha(STRIP_EDGE_ALPHA)
        end
        local tr, tg, tb = IG.HexToRGB(IG.LightenColor(info.color, 0.45))
        chip.label:SetColor(tr, tg, tb, 1)
        chip.name:SetColor(tr, tg, tb, 1)

        local hasIcon = info.icon ~= nil and info.icon ~= ""
        chip.icon:SetTexture(hasIcon and info.icon or "")
        chip.icon:SetHidden(not hasIcon)
        chip.label:ClearAnchors()
        chip.name:ClearAnchors()
        if data.mode == "tiles" then
            chip.label:SetFont(style.tileCountFont or "ZoFontGameShadow")
            chip.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            chip.label:SetText(tostring(info.count))
            local iconSize = hasIcon and tileIconSize or 0
            local iconGap = hasIcon and 4 or 0
            local pairWidth = iconSize + iconGap + chip.label:GetTextWidth()
            local left = zo_max(6, (chipWidth - pairWidth) / 2)
            chip.icon:SetDimensions(tileIconSize, tileIconSize)
            chip.icon:SetAnchor(TOPLEFT, chip, TOPLEFT, left, 4)
            chip.label:SetAnchor(LEFT, chip, TOPLEFT, left + iconSize + iconGap, 4 + iconSize / 2)
            chip.name:SetHidden(false)
            chip.name:SetFont(style.tileNameFont or "ZoFontGameSmall")
            chip.name:SetText(info.label)
            chip.name:SetAnchor(TOPLEFT, chip, TOPLEFT, 3, 6 + iconSize)
            chip.name:SetAnchor(BOTTOMRIGHT, chip, BOTTOMRIGHT, -3, -2)
        else
            local chipIconSize = style.chipIconSize or 18
            chip.name:SetHidden(true)
            chip.name:SetText("")
            chip.icon:SetDimensions(chipIconSize, chipIconSize)
            chip.icon:SetAnchor(LEFT, chip, LEFT, 5, 0)
            chip.label:SetFont(style.chipFont or "ZoFontGameShadow")
            chip.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            chip.label:SetText(string.format("%s (%d)", info.label, info.count))
            chip.label:SetAnchor(TOPLEFT, chip, TOPLEFT, hasIcon and (STRIP_ICON_GAP * 2 + chipIconSize) or 6, 0)
            chip.label:SetAnchor(BOTTOMRIGHT, chip, BOTTOMRIGHT, -6, 0)
        end
    end
    -- Whatever this same pooled row left over from a longer strip last time: gone, not thrown
    -- away, in case the next one needs that many again.
    for index = #items + 1, #(control.igChips or {}) do
        control.igChips[index]:SetHidden(true)
    end
end

local function DressItem(control, data)
    control.igData = nil
    control:SetHeight(data.rowHeight)
    IG.ApplyFrames(control, data.igFrames, true)
    control:GetNamedChild("Icon"):SetTexture(data.icon)
    control:GetNamedChild("Count"):SetText(data.count > 1 and data.count or "")
    local name = control:GetNamedChild("Name")
    name:SetText(data.label)
    name:SetColor(IG.HexToRGB(data.color))
    DressExtras(control, data, name)
end

function IG.RefreshPreview()
    if not window or window:IsHidden() then return end

    local rows = IG.PreviewRows()
    local previous, total = nil, 0
    for index, row in ipairs(rows) do
        local control = ControlFor(index, row.kind)
        HideOthers(index, row.kind)

        control:SetWidth(ROW_WIDTH)
        control:SetAlpha(row.dim and DIM_ALPHA or 1)
        control:SetHidden(false)
        control:ClearAnchors()
        if previous then
            control:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
        else
            control:SetAnchor(TOPLEFT, window.list, TOPLEFT, 0, 0)
        end

        if row.kind == "header" then
            IG.DressHeaderRow(control, row.data)
        elseif row.kind == "section" then
            IG.DressSectionRow(control, row.data)
        elseif row.kind == "setrule" then
            IG.DressSetRuleRow(control, row.data)
        elseif row.kind == "item" then
            DressItem(control, row.data)
        elseif row.kind == "strip" then
            DressStrip(control, row.data)
        else
            control:SetHeight(row.data.rowHeight)
            IG.ApplyFrames(control, row.data.igFrames, true)
        end

        previous = control
        total = total + row.data.rowHeight
    end
    HideFrom(#rows + 1)

    window.list:SetHeight(total)
end

---------------------------------------------------------------------------
-- Coming and going
---------------------------------------------------------------------------

local function Wanted()
    return IG.sv == nil or IG.sv.previewEnabled ~= false
end

function IG.ShowPreview()
    if not Wanted() then return end
    if not window then
        window = CreateWindow()
        rowPool = {}
    end
    window:SetHidden(false)
    IG.RefreshPreview()
    PlaceWindow()
end

function IG.HidePreview()
    if window then window:SetHidden(true) end
end

-- The switch in General, which can reach us with the page already open.
function IG.SetPreviewShown(shown)
    if shown and IG.settingsPanel and not IG.settingsPanel:IsHidden() then
        IG.ShowPreview()
    else
        IG.HidePreview()
    end
end

-- LAM builds a panel's controls the first time it is opened, and that build runs over more than
-- one frame (the settings page's own first-open stutter). If the settings window is closed
-- before it finishes, this callback still fires once it does -- late, and after the window is
-- already gone. Answering it then would open the sample over an empty screen with nothing left
-- to close it again, so the window's own state is asked rather than trusted blindly.
CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
    if panel ~= IG.settingsPanel then return end
    if LAMAddonSettingsWindow and LAMAddonSettingsWindow:IsHidden() then return end
    IG.ShowPreview()
end)

-- Fired both when the settings window closes and when another addon's page takes ours over.
CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
    if panel == IG.settingsPanel then IG.HidePreview() end
end)
