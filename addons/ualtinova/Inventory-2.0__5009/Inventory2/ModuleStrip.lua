InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- "(27)", or "(3) (27)" for a button that counts what it holds as well (SETUPS).
local function CountText(info)
    if info.firstCount then return string.format("(%d) (%d)", info.firstCount, info.count or 0) end
    return string.format("(%d)", info.count or 0)
end

-- Section display. Every section heading (ATTENTION, MODULES, SETS, ...) is drawn one of three
-- ways, picked by a right click on the heading and kept per list and per section
-- (sv.sectionDisplay[invKey][section]), the same way sv.sectionCollapsed is kept. "rows" is the
-- list as it always was: every category under the heading is a heading row of its own. "chips"
-- and "tiles" give those heading rows up to one row of buttons standing under the heading, one
-- button per category that holds something, and open only the one that was picked, directly
-- under the buttons. Every section is Rows until told otherwise, except MODULES, which is Chips.
--
-- The row is one of our own row types, put into the list by BuildGroupedList in place of the
-- category headings, so it scrolls with everything else. A scroll list lays a type out at one
-- fixed height (ZO_ScrollList_AddDataType), so there is one type per number of lines the buttons
-- wrap to, per look: chips 1713-1720, tiles 1721-1728.
--
-- What is open is kept per list and per section (sv.sectionStripOpen[invKey][section]) and
-- nowhere else: the open/closed answers the categories have as rows (sv.expanded) are left
-- exactly as they were, so switching back to Rows finds them unchanged. The old single
-- Modules Display setting (sv.modulesDisplay, sv.moduleStripOpen) is no longer read.
-- The open one's block is framed in its button's colour (AssignFrames, data.openChip).

local MAX_LINES = 8
local CHIP_BASE_TYPE = 1713
local TILE_BASE_TYPE = CHIP_BASE_TYPE + MAX_LINES

-- The open block's accent dress: its category frame in the button's colour, the thick left
-- rail from the strip's top and the line tying it to the open button. Off for now; true brings
-- all three back exactly as they were (AssignFrames reads data.railed, SetupStripRow below).
local STRIP_RAIL = false

-- In its place, a light heading under the buttons naming what is open: the look of a place
-- under RECENT LOOT (a centred name, a line to either side), shorter than a category header,
-- no plate. Not a category row to the sticky header (no key, no depth). Click shuts the open
-- button; right click is the category heading's own menu.
local STRIP_HEAD_TYPE = 1730
local STRIP_HEAD_HEIGHT = 30
local STRIP_HEAD_FONT = "$(BOLD_FONT)|19|soft-shadow-thin"
local STRIP_HEAD_ICON_SIZE = 22 -- the category's mark before its name, about the name's height
local STRIP_HEAD_ICON_GAP = 6
local STRIP_HEAD_LINE_ALPHA = 0.4
local STRIP_HEAD_COUNT_DARKEN = 0.75
local STRIP_HEAD_GAP = 8
local STRIP_HEAD_RIGHT = 16
IG.MODULE_STRIP_HEAD_TYPE = STRIP_HEAD_TYPE

local LOOKS = {
    chips = { base = CHIP_BASE_TYPE, perLine = 3, height = 30, gap = 4, pad = 5 },
    tiles = { base = TILE_BASE_TYPE, perLine = 4, height = 70, gap = 6, pad = 6 },
}
-- Read by Preview.lua, which draws its own (non-interactive) stand-in for this same look rather
-- than sharing these buttons: a chip here can toggle the real list open, and the preview's
-- categories have no real list to open.
IG.MODULE_STRIP_LOOKS = LOOKS

local CHIP_FONT = "$(BOLD_FONT)|17|soft-shadow-thin"
local TILE_COUNT_FONT = "$(BOLD_FONT)|22|soft-shadow-thin"
local TILE_NAME_FONT = "$(MEDIUM_FONT)|14|soft-shadow-thin"
local TILE_ICON_SIZE = 36
local CHIP_ICON_SIZE = 18
IG.MODULE_STRIP_STYLE = {
    chipFont = CHIP_FONT, tileCountFont = TILE_COUNT_FONT, tileNameFont = TILE_NAME_FONT,
    tileIconSize = TILE_ICON_SIZE, chipIconSize = CHIP_ICON_SIZE,
}

-- One art family for every module button, chips and tiles alike: the keyboard tab and menu-bar
-- buttons (the *_up.dds set SELL [GUILD STORE] and DECONSTRUCT already wear). Paths are the
-- game's own, each used by the base UI. Any other category keeps the icon its heading has.
local MODULE_ICONS = {
    -- The bag's own Armor filter tab (the icon its heading already wears).
    EQUIPPED  = "EsoUI/Art/Inventory/inventory_tabIcon_armor_up.dds",
    LASTRUN   = "EsoUI/Art/Guild/tabIcon_history_up.dds",
    ARMORY    = "EsoUI/Art/MainMenu/menuBar_character_up.dds",
    -- ARMORY's heading art (Colors.lua), the one the Setups module wears (Setups.lua).
    SETUPS    = "EsoUI/Art/Armory/buildItem_icon.dds",
    HOME      = "EsoUI/Art/Collections/collections_tabIcon_housing_up.dds",
    -- The guild store's Sell tab (Colors.lua: the DISPOSAL heading wears the same).
    DISPOSAL  = "EsoUI/Art/TradingHouse/tradinghouse_sell_tabIcon_up.dds",
    STOLEN    = "EsoUI/Art/Vendor/vendor_tabIcon_fence_up.dds",
    SELL      = "EsoUI/Art/Vendor/vendor_tabIcon_sell_up.dds",
    GUILDSELL = "EsoUI/Art/MainMenu/menuBar_guilds_up.dds",
    DECON     = "EsoUI/Art/Crafting/enchantment_tabIcon_deconstruction_up.dds",
    -- The smithing bench's own Research tab (HarvestMap Tour/BaseInterface.lua uses it too).
    RESEARCH  = "EsoUI/Art/Crafting/smithing_tabIcon_research_up.dds",
    CUSTOM    = "EsoUI/Art/MainMenu/menuBar_inventory_up.dds",
    -- The bank's own Deposit tab (Colors.lua: its heading wears the same).
    TOBANK    = "EsoUI/Art/Bank/bank_tabIcon_deposit_up.dds",
    GARBAGE   = "EsoUI/Art/Inventory/inventory_tabIcon_trash_up.dds",
    JUNK      = "EsoUI/Art/Inventory/inventory_tabIcon_junk_up.dds",
    -- The smithing bench's own Creation tab (consolidatedsmithingsetdata_manager.lua).
    JUSTCRAFTED = "EsoUI/Art/Crafting/smithing_tabIcon_creation_up.dds",
    -- The journal's own Quests tab (keyboardingamescenes.lua).
    DAILYWRIT = "EsoUI/Art/Journal/journal_tabIcon_quest_up.dds",
}
-- The MODULES drawer draws the same marks beside its switches (Drawer.lua).
IG.MODULE_ICONS = MODULE_ICONS

-- How dark each state leaves the category's own colour on the button's ground.
local GROUND = { rest = 0.22, hover = 0.36, open = 0.55, pressed = 0.7 }
local GROUND_ALPHA = 0.92
local EDGE = { rest = 0.45, hover = 0.8, open = 1 }
-- Black Surfaces: the ink the heading rows stand on (Frame.lua INK), lifted a little more for a
-- hovered, open or pressed button. Header Surfaces off: no ground at rest, a faint tint otherwise.
local INK = { 0.017, 0.017, 0.024 }
local INK_LIFT = 0.12
local BARE_TINT = 0.35

IG.MODULE_STRIP_TYPES = {}
for i = 0, MAX_LINES * 2 - 1 do IG.MODULE_STRIP_TYPES[#IG.MODULE_STRIP_TYPES + 1] = CHIP_BASE_TYPE + i end

local DISPLAY_ORDER = { "rows", "chips", "tiles" }
local DISPLAY_MENU = { rows = "Show as Rows", chips = "Show as Chips", tiles = "Show as Tiles" }
-- Every section starts as plain rows; nothing is picked out with a default of its own any more.
local DISPLAY_DEFAULT = {}

function IG.SectionDisplay(invKey, section)
    local all = IG.sv and IG.sv.sectionDisplay
    local mine = all and invKey and all[invKey]
    local mode = mine and section and mine[section]
    if mode == "rows" or LOOKS[mode] then return mode end
    return section and DISPLAY_DEFAULT[section] or "rows"
end

function IG.SetSectionDisplay(invKey, inventoryType, section, mode)
    if not (IG.sv and invKey and section and DISPLAY_MENU[mode]) then return end
    IG.sv.sectionDisplay = IG.sv.sectionDisplay or {}
    local mine = IG.sv.sectionDisplay[invKey] or {}
    IG.sv.sectionDisplay[invKey] = mine
    mine[section] = mode
    PlaySound(SOUNDS.DEFAULT_CLICK)
    -- Through the list's own rebuild, never a commit of ours (HANDOFF §5).
    if IG.RefreshKeepingPlace then IG.RefreshKeepingPlace(inventoryType) end
end

-- Every section, in every list, to the one look: the bag, the bank, the guild bank, a house
-- chest, the flat layout a merchant or guild store opens, Minimal's own layout, and any crafting
-- bench already in the save (a bench not yet visited has no entry here to overwrite and keeps
-- answering from DISPLAY_DEFAULT until it does). Called from the settings page (LAYOUT), never
-- from a right click, so there is no one list's own refresh to ask for -- the caller rebuilds.
local ALL_LIST_KEYS = { "backpack", "bank", "guildbank", "housebank", "trading", "minimal" }
function IG.SetAllSectionDisplays(mode)
    if not (IG.sv and DISPLAY_MENU[mode]) then return end
    IG.sv.sectionDisplay = IG.sv.sectionDisplay or {}
    local all = IG.sv.sectionDisplay
    -- The lists already in the save first, crafting benches among them, then the fixed ones
    -- every player has, whether or not they have been opened yet.
    for listKey in pairs(all) do
        local mine = all[listKey]
        for _, section in ipairs(IG.SECTION_ORDER) do mine[section] = mode end
    end
    for _, listKey in ipairs(ALL_LIST_KEYS) do
        local mine = all[listKey] or {}
        all[listKey] = mine
        for _, section in ipairs(IG.SECTION_ORDER) do mine[section] = mode end
    end
end

-- The right click on a section heading: the two looks it is not wearing now.
function IG.ShowSectionDisplayMenu(control, data)
    if not (data and data.isSection and data.invKey and data.label) then return end
    local current = IG.SectionDisplay(data.invKey, data.label)
    ClearMenu()
    -- The LOCKED divider stands for the one category under it: opening or shutting every set
    -- in it (InventoryGrouping.lua).
    if data.label == "LOCKED" and IG.AddLockedSetItems then
        IG.AddLockedSetItems(data.invKey, data.inventoryType)
    end
    for _, mode in ipairs(DISPLAY_ORDER) do
        if mode ~= current then
            AddMenuItem(DISPLAY_MENU[mode], function()
                IG.SetSectionDisplay(data.invKey, data.inventoryType, data.label, mode)
            end)
        end
    end
    -- Painting every category under it at once (InventoryGrouping.lua). LOCKED needs to know
    -- which list it is, since what is really under it (as opposed to its own section) is read
    -- off that list's own build.
    if IG.AddSectionColorItems then IG.AddSectionColorItems(data.label, data.invKey) end
    ShowMenu(control)
end

local function OpenKey(invKey, section)
    local open = IG.sv and IG.sv.sectionStripOpen
    local mine = open and invKey and open[invKey]
    return mine and section and mine[section] or nil
end

local function RowHeight(look, lines)
    return look.pad * 2 + lines * look.height + (lines - 1) * look.gap
end

-- Asked by BuildGroupedList once its items are classified and sorted. Nil when every section is
-- Rows, which leaves the build as it always was. Otherwise the categories that hold something
-- in each Chips or Tiles section, in the order the list puts them, and the row that stands for
-- each such section. Each button's heading data (for its right click) is written onto it later,
-- by the build, as it passes that category.
-- sectionOnly: [section] = the one category under it, or false (BuildGroupedList). A section that
-- is one category of its own name (LOCKED) is named by its divider already, so its buttons are
-- the categories inside that one: one button holding the whole section would say LOCKED twice
-- and leave everything under it as plain rows. nodeKey is the build's own key for a path level.
function IG.ModuleStripPlan(items, invKey, inventoryType, children, totals, sectionOnly, nodeKey)
    local byKey, sections, any = {}, {}, false
    for _, entry in ipairs(items) do
        local path = entry.igPath
        local top = path and path[1]
        local section = top and IG.GetGroupSection(top.id)
        local depth = 1
        if top and section == top.id and sectionOnly and sectionOnly[section] == top.id and path[2] and nodeKey then
            depth = 2
        end
        local node = path and path[depth]
        local key = node and (depth == 1 and node.id or nodeKey(path, depth))
        if node and not entry.igEmpty and not byKey[key] then
            local mode = section and IG.SectionDisplay(invKey, section)
            if mode and LOOKS[mode] then
                local strip = sections[section]
                if not strip then
                    strip = {
                        data = {
                            isModuleStrip = true,
                            mode = mode,
                            section = section,
                            chips = {},
                            invKey = invKey,
                            inventoryType = inventoryType,
                            openKey = OpenKey(invKey, section),
                            railed = STRIP_RAIL,
                        },
                    }
                    sections[section] = strip
                    any = true
                end
                local chip = {
                    key = key,
                    -- The path level the button stands for: 2 inside a one-category section.
                    depth = depth,
                    section = section,
                    label = node.label or tostring(node.id),
                    color = node.color or IG.DEFAULT_ICON_COLOR,
                    icon = MODULE_ICONS[node.id]
                        or (IG.sv.icons and node.iconKey and IG.sv.icons[node.iconKey]) or node.icon,
                    -- The items under it, whatever its heading counts first (RECENT LOOT
                    -- runs, sets): a button says how much is inside.
                    count = (totals and totals[key]) or node.fixedCount or children[key] or 0,
                    -- SETUPS says how many setups too, before the items: "(3) (27)".
                    firstCount = node.chipBothCounts and (children[key] or 0) or nil,
                }
                local chips = strip.data.chips
                chips[#chips + 1] = chip
                byKey[key] = chip
                if strip.data.openKey == key then strip.data.openChip = chip end
            end
        end
    end
    if not any then return nil end
    for _, strip in pairs(sections) do
        local look = LOOKS[strip.data.mode]
        local lines = zo_min(zo_ceil(#strip.data.chips / look.perLine), MAX_LINES)
        strip.data.rowHeight = RowHeight(look, lines)
        strip.openKey = strip.data.openKey
        strip.entry = ZO_ScrollList_CreateDataEntry(look.base + lines - 1, strip.data)
    end
    return { byKey = byKey, sections = sections }
end

---------------------------------------------------------------------------
-- Opening one
---------------------------------------------------------------------------

function IG.ToggleModuleStrip(invKey, inventoryType, key, section)
    if not (IG.sv and invKey and key and section) then return end
    IG.sv.sectionStripOpen = IG.sv.sectionStripOpen or {}
    local mine = IG.sv.sectionStripOpen[invKey] or {}
    IG.sv.sectionStripOpen[invKey] = mine
    if mine[section] == key then
        mine[section] = nil
    else
        mine[section] = key
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    -- Through the list's own rebuild, never a commit of ours (HANDOFF §5).
    if IG.RefreshKeepingPlace then IG.RefreshKeepingPlace(inventoryType) end
    -- A button just opened slides its heading and rows into view, as a category heading does.
    if mine[section] == key and IG.PullOpenedIntoView and IG.ListFor then
        IG.PullOpenedIntoView(IG.ListFor(inventoryType), function(row)
            return row ~= nil and row.isStripHeading and row.chip ~= nil and row.chip.key == key
        end)
    end
end

-- E over a button does what a click does, offered on the keybind strip the way the header rows
-- offer theirs (InventoryGrouping.lua, OfferHeaderAction). Their offer is taken down first: the
-- two share one key.
local CHIP_ACTION = {
    keybind = "UI_SHORTCUT_PRIMARY",
    alignment = KEYBIND_STRIP_ALIGN_RIGHT,
}

local function DropChipAction()
    if KEYBIND_STRIP then KEYBIND_STRIP:RemoveKeybindButton(CHIP_ACTION) end
end

local function OfferChipAction(chip)
    DropChipAction()
    if IG.DropHeaderAction then IG.DropHeaderAction() end
    if not (KEYBIND_STRIP and chip.igChip) then return end
    local strip, info = chip.igStrip, chip.igChip
    CHIP_ACTION.name = strip.openKey == info.key and "Close" or "Open"
    CHIP_ACTION.callback = function()
        DropChipAction()
        IG.ToggleModuleStrip(strip.invKey, strip.inventoryType, info.key, strip.section)
    end
    KEYBIND_STRIP:AddKeybindButton(CHIP_ACTION)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function PaintChip(chip)
    local info, strip = chip.igChip, chip.igStrip
    if not (info and strip) then return end
    local open = strip.openKey == info.key
    local state = (chip.igPressed and "pressed") or (open and "open") or (chip.igHovered and "hover") or "rest"
    local r, g, b = IG.HexToRGB(info.color)
    local k = GROUND[state]
    -- The theme's switches, the same ones the heading rows answer to (Frame.lua): Black Surfaces
    -- puts the buttons on ink, Header Surfaces off leaves them on the game's own background with
    -- only a faint tint while hovered or open, and Frames off takes the outline away.
    local sv = IG.sv
    local surfaces = not sv or sv.headerSurfaces ~= false
    local ink = sv ~= nil and sv.blackSurfaces == true
    local frames = not sv or sv.frames ~= false
    -- Alpha on the control, not in SetColor (a texture without art ignores the colour's alpha,
    -- HANDOFF §5).
    if ink then
        local lift = k * INK_LIFT
        chip.ground:SetColor(INK[1] + lift, INK[2] + lift, INK[3] + lift, 1)
        chip.ground:SetAlpha(GROUND_ALPHA)
    elseif surfaces then
        -- A dark ground carrying some of the module's colour.
        chip.ground:SetColor(r * k, g * k, b * k, 1)
        chip.ground:SetAlpha(GROUND_ALPHA)
    else
        chip.ground:SetColor(r, g, b, 1)
        chip.ground:SetAlpha(state == "rest" and 0 or k * BARE_TINT)
    end
    local edge = EDGE[open and "open" or (chip.igHovered and "hover" or "rest")]
    for _, line in ipairs(chip.edges) do
        line:SetColor(r, g, b, 1)
        line:SetAlpha(edge)
        line:SetHidden(not frames)
    end
    local tr, tg, tb = IG.HexToRGB(IG.LightenColor(info.color, open and 0.75 or 0.45))
    chip.label:SetColor(tr, tg, tb, 1)
    if chip.name then chip.name:SetColor(tr, tg, tb, 1) end
end

local function OnChipEnter(chip)
    chip.igHovered = true
    PaintChip(chip)
    OfferChipAction(chip)
    local info = chip.igChip
    if info and chip.igStrip and chip.igStrip.mode == "tiles" then
        InitializeTooltip(InformationTooltip, chip, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, string.format("%s %s", info.label, CountText(info)))
        if IG.SHIFT_CLICK_ACTIONS[info.key] then SetTooltipText(InformationTooltip, "Shift+Click: Distribute") end
    end
end

local function OnChipExit(chip)
    chip.igHovered, chip.igPressed = false, false
    PaintChip(chip)
    DropChipAction()
    ClearTooltip(InformationTooltip)
end

local function OnChipDown(chip, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    chip.igPressed = true
    PaintChip(chip)
end


local function OnChipUp(chip, button, upInside)
    chip.igPressed = false
    PaintChip(chip)
    local info, strip = chip.igChip, chip.igStrip
    if not (upInside and info and strip) then return end
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        -- The very menu the category's own heading row has. The heading was built for this list
        -- but not drawn; the button stands in for it.
        if info.header then
            chip.igData = info.header
            IG.OnHeaderMouseUp(chip, MOUSE_BUTTON_INDEX_RIGHT, true)
        end
        return
    end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    DropChipAction()
    local invKey, inventoryType, key, section = strip.invKey, strip.inventoryType, info.key, strip.section
    if IsShiftKeyDown() and IG.SHIFT_CLICK_ACTIONS[key] then
        -- NEW or RECENT LOOT: Shift+Click is its menu's Distribute items; nothing toggles.
        IG.DistributeDelayed(chip, key)
        return
    end
    IG.ToggleModuleStrip(invKey, inventoryType, key, section)
end

-- One button, made once per row control and kept: rows come out of the list's pool and are
-- dressed again for whatever they are next. Unnamed, so no name can ever be taken twice.
local function CreateChip(control)
    local chip = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)
    chip:SetMouseEnabled(true)
    -- The outline: four one-pixel lines (IG.AddEdges, Toolbar.lua) rather than a filled box
    -- behind the ground, so a theme with no ground still shows an outline and not a solid block.
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
    chip.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    chip.name = WINDOW_MANAGER:CreateControl(nil, chip, CT_LABEL)
    chip.name:SetDrawLevel(3)
    chip.name:SetFont(TILE_NAME_FONT)
    chip.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    chip.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    chip:SetHandler("OnMouseEnter", OnChipEnter)
    chip:SetHandler("OnMouseExit", OnChipExit)
    chip:SetHandler("OnMouseDown", OnChipDown)
    chip:SetHandler("OnMouseUp", OnChipUp)
    return chip
end

-- Lays the icon, count and name out for the look in force. Every anchor, size and text is set
-- again each time: a chip can be a pill one build and a tile the next (pooled rows).
-- width: the width it was placed at.
local function DressChip(chip, info, mode, width)
    local label = info.label
    chip.icon:ClearAnchors()
    chip.label:ClearAnchors()
    chip.name:ClearAnchors()
    local hasIcon = info.icon ~= nil and info.icon ~= ""
    chip.icon:SetTexture(hasIcon and info.icon or "")
    chip.icon:SetHidden(not hasIcon)
    if mode == "tiles" then
        -- Icon and count side by side on one line, the pair centred; the name under them.
        chip.label:SetFont(TILE_COUNT_FONT)
        chip.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        chip.label:SetText(info.firstCount and CountText(info) or tostring(info.count))
        local iconSize = hasIcon and TILE_ICON_SIZE or 0
        local gap = hasIcon and 4 or 0
        local pairWidth = iconSize + gap + chip.label:GetTextWidth()
        -- The width it was placed at, not GetWidth(): a pooled chip may still read its old size.
        local left = zo_max(6, ((width or chip:GetWidth()) - pairWidth) / 2)
        chip.icon:SetDimensions(TILE_ICON_SIZE, TILE_ICON_SIZE)
        chip.icon:SetAnchor(TOPLEFT, chip, TOPLEFT, left, 4)
        chip.label:SetAnchor(LEFT, chip, TOPLEFT, left + iconSize + gap, 4 + TILE_ICON_SIZE / 2)
        chip.name:SetHidden(false)
        chip.name:SetText(label)
        chip.name:SetAnchor(TOPLEFT, chip, TOPLEFT, 3, 6 + TILE_ICON_SIZE)
        chip.name:SetAnchor(BOTTOMRIGHT, chip, BOTTOMRIGHT, -3, -2)
    else
        chip.name:SetHidden(true)
        chip.name:SetText("")
        chip.icon:SetDimensions(CHIP_ICON_SIZE, CHIP_ICON_SIZE)
        chip.icon:SetAnchor(LEFT, chip, LEFT, 5, 0)
        chip.label:SetFont(CHIP_FONT)
        chip.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        chip.label:SetText(string.format("%s %s", label, CountText(info)))
        chip.label:SetAnchor(TOPLEFT, chip, TOPLEFT, hasIcon and (7 + CHIP_ICON_SIZE) or 6, 0)
        chip.label:SetAnchor(BOTTOMRIGHT, chip, BOTTOMRIGHT, -6, 0)
    end
end

local SetupStripRow

-- The row's width is not final when the scroll list first sets it up (a fresh row still has the
-- template's 565, and the list narrows when its scrollbar shows), so the buttons are laid out
-- again once the row has its real width. Deferred and guarded: never resize from inside the event.
local STRIP_WIDTH_TOLERANCE = 0.5
local function OnStripRowRectChanged(control)
    if control.igStripRelayoutPending or not control.igStripData then return end
    local width = control:GetWidth()
    if control.igStripWidth and zo_abs(width - control.igStripWidth) < STRIP_WIDTH_TOLERANCE then return end
    control.igStripRelayoutPending = true
    zo_callLater(function()
        control.igStripRelayoutPending = false
        local data = control.igStripData
        if data and not control:IsHidden() then SetupStripRow(control, data) end
    end, 0)
end

SetupStripRow = function(control, data)
    control:SetHeight(data.rowHeight)
    control.igStripData = data
    if not control.igStripRectHooked then
        control.igStripRectHooked = true
        control:SetHandler("OnRectChanged", OnStripRowRectChanged)
    end
    local look = LOOKS[data.mode] or LOOKS.chips
    control.igChips = control.igChips or {}
    -- The buttons span exactly a top-level header's surface: from IG.HeaderIndent(1) to
    -- IG.TOP_PLATE_RIGHT_INSET in from the right, both read off the row's own width as the header does.
    local width = control:GetWidth()
    if not width or width <= 0 then
        local parent = control:GetParent()
        width = parent and parent:GetWidth() or 0
    end
    if width <= 0 then width = 565 end -- the row template's width
    control.igStripWidth = width
    local sideLeft = IG.HeaderIndent(1)
    local usable = width - sideLeft - IG.TOP_PLATE_RIGHT_INSET
    local chipWidth = (usable - (look.perLine - 1) * look.gap) / look.perLine
    local slots = data.chips
    local shownSlots = zo_min(#slots, look.perLine * MAX_LINES)
    local shown = 0
    -- The open block's left strip starts at the strip's first line, whichever line the open
    -- button sits on; the link to it runs at the open button's top (IG.ApplyStripRail).
    local linkTop, railLeft
    local function Place(info, left, top, width)
        shown = shown + 1
        local chip = control.igChips[shown] or CreateChip(control)
        control.igChips[shown] = chip
        chip.igChip, chip.igStrip = info, data
        chip.igPressed = false
        chip.igHovered = false
        chip:ClearAnchors()
        chip:SetAnchor(TOPLEFT, control, TOPLEFT, left, top)
        if width then
            chip:SetDimensions(width, look.height)
        else
            -- The last column ends on the header surface's own anchor, not on a measured width.
            chip:SetAnchor(TOPRIGHT, control, TOPRIGHT, -IG.TOP_PLATE_RIGHT_INSET, top)
            chip:SetHeight(look.height)
        end
        DressChip(chip, info, data.mode,
            width or (control.igStripWidth - IG.TOP_PLATE_RIGHT_INSET - left))
        chip:SetHidden(false)
        PaintChip(chip)
        if info == data.openChip then linkTop, railLeft = top, left end
    end
    for i = 1, shownSlots do
        local slot = slots[i]
        local column = (i - 1) % look.perLine
        local line = zo_floor((i - 1) / look.perLine)
        local top = look.pad + line * (look.height + look.gap)
        local left = sideLeft + column * (chipWidth + look.gap)
        local last = column == look.perLine - 1
        Place(slot, left, top, not last and chipWidth or nil)
    end
    IG.ApplyStripRail(control, STRIP_RAIL and linkTop and data.openChip.color, look.pad, railLeft, linkTop)
    -- Whatever this control carried last time and does not carry now.
    for i = shown + 1, #control.igChips do
        local chip = control.igChips[i]
        chip.igChip, chip.igStrip, chip.igData = nil, nil, nil
        chip:SetHidden(true)
    end
end

---------------------------------------------------------------------------
-- The open button's heading
---------------------------------------------------------------------------

-- Asked by BuildGroupedList as it passes the open category: the row to put straight under the
-- buttons, above that category's rows. header is the heading data kept on the button.
function IG.ModuleStripHeading(strip, chip, header)
    if not (strip and chip) then return nil end
    return ZO_ScrollList_CreateDataEntry(STRIP_HEAD_TYPE, {
        isStripHeading = true, strip = strip, chip = chip, header = header,
    })
end

local function StripHeadLine(control)
    local line = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    line:SetHeight(1)
    return line
end

local function OnStripHeadUp(control, button, upInside)
    local data = control.igHeadData
    if not (upInside and data) then return end
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        -- The category heading's own menu, the same way the button offers it.
        if data.header then
            control.igData = data.header
            IG.OnHeaderMouseUp(control, MOUSE_BUTTON_INDEX_RIGHT, true)
        end
        return
    end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local strip, chip = data.strip, data.chip
    IG.ToggleModuleStrip(strip.invKey, strip.inventoryType, chip.key, strip.section)
end

local function SetupStripHeadRow(control, data)
    control:SetHeight(STRIP_HEAD_HEIGHT)
    control.igHeadData = data
    if not control.igHeadLabel then
        control:SetMouseEnabled(true)
        control:SetHandler("OnMouseUp", OnStripHeadUp)
        control.igHeadLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        control.igHeadLabel:SetFont(STRIP_HEAD_FONT)
        control.igHeadLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control.igHeadIcon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        control.igHeadIcon:SetDimensions(STRIP_HEAD_ICON_SIZE, STRIP_HEAD_ICON_SIZE)
        control.igHeadLeft = StripHeadLine(control)
        control.igHeadRight = StripHeadLine(control)
    end
    local chip = data.chip
    local color = chip.color or IG.DEFAULT_ICON_COLOR
    local r, g, b = IG.HexToRGB(color)
    local label = control.igHeadLabel
    label:SetColor(r, g, b, 1)
    label:SetText(string.format("%s  |c%s%s|r", zo_strupper(chip.label or ""),
        IG.DimColor(color, STRIP_HEAD_COUNT_DARKEN), CountText(chip)))
    -- Re-anchored every time: pooled rows (HANDOFF §5). Mark and name centred as one.
    local icon = type(chip.icon) == "string" and chip.icon or nil
    local mark = control.igHeadIcon
    mark:SetHidden(icon == nil)
    mark:SetTexture(icon or "")
    mark:SetColor(r, g, b, 1)
    local lead = icon and (STRIP_HEAD_ICON_SIZE + STRIP_HEAD_ICON_GAP) or 0
    label:ClearAnchors()
    label:SetAnchor(CENTER, control, CENTER, lead / 2, 0)
    mark:ClearAnchors()
    mark:SetAnchor(RIGHT, label, LEFT, -STRIP_HEAD_ICON_GAP, 0)
    control.igHeadLeft:ClearAnchors()
    control.igHeadLeft:SetAnchor(LEFT, control, LEFT, IG.HeaderIndent(1), 0)
    control.igHeadLeft:SetAnchor(RIGHT, icon and mark or label, LEFT, -STRIP_HEAD_GAP, 0)
    control.igHeadRight:ClearAnchors()
    control.igHeadRight:SetAnchor(LEFT, label, RIGHT, STRIP_HEAD_GAP, 0)
    control.igHeadRight:SetAnchor(RIGHT, control, RIGHT, -STRIP_HEAD_RIGHT, 0)
    control.igHeadLeft:SetColor(r, g, b, 1)
    control.igHeadLeft:SetAlpha(STRIP_HEAD_LINE_ALPHA)
    control.igHeadRight:SetColor(r, g, b, 1)
    control.igHeadRight:SetAlpha(STRIP_HEAD_LINE_ALPHA)
end

function IG.RegisterModuleStripTypes(listView)
    ZO_ScrollList_AddDataType(listView, STRIP_HEAD_TYPE, "InventoryGrouping_Spacer",
        STRIP_HEAD_HEIGHT, SetupStripHeadRow)
    for mode, look in pairs(LOOKS) do
        for lines = 1, MAX_LINES do
            ZO_ScrollList_AddDataType(listView, look.base + lines - 1, "InventoryGrouping_Spacer",
                RowHeight(look, lines), SetupStripRow)
        end
    end
end
