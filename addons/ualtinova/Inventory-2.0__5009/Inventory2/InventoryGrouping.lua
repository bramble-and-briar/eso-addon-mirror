InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- PUBLIC API (for other addons)
--
-- InventoryGrouping.RevealItem(bagId, slotIndex) -> boolean
--   bagId: BAG_BACKPACK or BAG_VIRTUAL (craft bag); slotIndex: the slot (craft bag: slot id).
--   Returns true when the slot holds an item and a reveal was scheduled; false otherwise
--   (empty slot, other bag, bad args). Never raises. The reveal itself runs deferred: opens the
--   inventory scene and the Items / Craft Bag tab, opens the item's section, Chips/Tiles button,
--   category and sub-categories (written into the saved open state: it only opens; the one
--   thing it may close is the other Chips/Tiles button of that section, and with "one group
--   open at a time" the sibling categories, as a click would), clears the search box only if
--   the item is not in the list, scrolls so the category header and the row show together
--   (row centred if they cannot), then flashes the row once. One reveal at a time; a newer call
--   replaces a pending one; gives up quietly after ~3 s.
--
-- InventoryGrouping.RevealItemLink(itemLink) -> boolean
--   Looks in the backpack, then the craft bag, for the exact link, then for the same item id,
--   and calls RevealItem on the first match. False when nothing matches. Never raises.

-- Must match the folder this addon lives in: the game hands that name to
-- EVENT_ADD_ON_LOADED and OnAddOnLoaded waits for it. Rename one without the other and the
-- files still load, nothing initialises, and nothing is printed. The folder is Inventory2 (one
-- word, so the name never has to be quoted anywhere); the name players see is the manifest
-- Title and IG.DISPLAY_NAME, both "Inventory 2.0". See RENAME.md.
IG.name = "Inventory2"

-- The Global Switch, top of the General settings. Off means none of our hooks go in, so the game
-- keeps its own inventory exactly as it ships it; the saved settings are left alone either way.
-- Called before the settings exist too (during load), where it answers "on".
function IG.IsEnabled()
    return IG.sv == nil or IG.sv.addonEnabled ~= false
end

-- Scroll list data types for header rows, one per depth (heights differ per depth).
local HEADER_TYPES = { 1701, 1702, 1703 }

-- How tall our own rows are, from General > STYLE. Only rows we draw ourselves are in here; the
-- game's item rows keep their own height.
--   headers  : one per depth       setName : the name line of a set
--   pieces   : what the badge row adds below the name, piecesTop where it starts
-- A set's badges are 23 pixels tall wherever they are drawn, so setName + pieces never falls
-- below piecesTop + 23: that is what keeps the bottom row of icons inside its own row.
-- The sub-levels stand among item rows rather than over a list of their own, so they are built
-- to something near an item row's height (44 at normal, which is what our own stored rows are
-- drawn at to sit among the game's). The top level keeps its own: it is read as the start of
-- something, not as one of the things.
local DENSITY = {
    compact = { headers = { 34, 36, 36 }, setName = 28, pieces = 16, piecesTop = 21,
                section = 30, setRule = 24, spacer = 6, subSpacer = 4, foot = 14 },
    normal  = { headers = { 43, 44, 44 }, setName = 35, pieces = 22, piecesTop = 26,
                section = 36, setRule = 28, spacer = 8, subSpacer = 6, foot = 18 },
    roomy   = { headers = { 49, 50, 50 }, setName = 40, pieces = 24, piecesTop = 31,
                section = 42, setRule = 32, spacer = 12, subSpacer = 8, foot = 23 },
}
local metrics = DENSITY.normal

-- How tall a set's header is. The badge row is the tallest thing a set carries, and the row is
-- built to hold it whether or not the badges are switched on: turning them off is meant to take
-- a row of icons away, not to shrink every set in the list. Without them the name has the whole
-- height to itself and is written larger in it.
local function SetRowHeight()
    return metrics.setName + metrics.pieces
end

-- { face, size, shadow }. Set names (deepest level) use a thinner face so they don't read as groups.
-- The deeper two grew by more than their rows did: a sub-heading stands among item rows and was
-- written smaller than the names under it.
local HEADER_FONTS = {
    { "$(BOLD_FONT)", 19, "soft-shadow-thin" },
    { "$(BOLD_FONT)", 19, "soft-shadow-thin" },
    { "$(MEDIUM_FONT)", 17, "soft-shadow-thin" },
}
local MIN_FONT_SIZE = 11
-- Set headers: thin face, a bit larger, with a larger icon after the name.
local SET_FONT = { "$(MEDIUM_FONT)", 17, "thick-outline" }
-- What that name starts at with no badge row under it.
local SET_FONT_TALL_SIZE = 21
local SET_LOCATION_FONT = "$(MEDIUM_FONT)|14|thick-outline"
-- The most of a set's row its location may take. The label only has its right edge anchored and
-- the name is anchored to its left edge, so an unbounded one (LibSets' per-boss drop text for the
-- older trials) grew over the whole row and pushed the set's name out of sight.
local SET_LOCATION_MAX_SHARE = 0.4
-- How far a set's text is pushed toward white against its own colored surface.
local SET_TEXT_LIGHTEN = 0.5
local COLLECT_FONT = "$(BOLD_FONT)|14|soft-shadow-thin"
-- "Collectable !" beside an item's name while selling. It carried the colour of the spare-pieces
-- counter, which is gone; it is the green of the missing-piece counter now, which is what it is
-- actually saying.
local COLLECTABLE_COLOR = { 0.22, 1, 0.08 }
-- The collection counter sits on its own line under the drop location, at the same right edge.
local COLLECTED_DROP = 19
-- The "Total items" bracket, against its row's own text color.
local TOTAL_DARKEN = 0.55
local HINT_FONT = "$(MEDIUM_FONT)|13|soft-shadow-thin"
-- Horizontal spacing on a header line: [marker] gap [icon] gap [name].
local MARKER_ICON_GAP = 3
local ICON_NAME_GAP = 4
-- Where the game starts an item's name, from the left edge of its row: the column our own
-- stored rows were built to stand in (InventoryGrouping_StoredItemRow). A heading that is read
-- as one of the rows around it starts there too, whatever depth it is at.
local ITEM_NAME_LEFT = 110
-- And where it centres their icons, from the same template. A mark on such a line stands in
-- that column, so it lines up with the icons above and below it rather than with a heading's.
local ITEM_ICON_CENTER = 70
-- And is lettered the way the game letters those names: ZoFontGameShadow's own face and style,
-- which is what our stored rows are written in, a tenth larger than the game writes it.
local ITEM_LINE_FONT = { "$(MEDIUM_FONT)", 20, "shadow" }
-- What the row template anchors the name with, so a row whose name was moved can be put back:
-- the rows are drawn from a pool and the next thing this one is asked to be may be a heading.
local NAME_ICON_GAP = 5
local NAME_LOCATION_GAP = 12
-- The +/- in front of every header: the same round mark at every level, only the size changes.
local MARKER_SIZES = { 22, 19, 19 }
-- A set's +/- stands on its name line like the first letter of the name, as tall as the text.
local SET_MARKER_SIZE = 25
local MARKER_PLUS = "EsoUI/Art/Progression/addPoints_up.dds"
local MARKER_MINUS = "EsoUI/Art/Progression/removePoints_up.dds"
-- Drop location on the right of set headers: same font family, ~15% smaller and thinner.
local LOCATION_FONTS = {
    "$(MEDIUM_FONT)|17|soft-shadow-thin",
    "$(MEDIUM_FONT)|14|soft-shadow-thin",
    "$(MEDIUM_FONT)|13|soft-shadow-thin",
}
local LOCATION_DARKEN = 0.75
-- Top-level icons are as big as the row allows (40px row, a few pixels of air above and below).
local HEADER_ICON_SIZES = { 34, 20, 18 }
-- Header surface: dark glass with a touch of the group color. Open groups get more color.
local SURFACE_TINT_COLLAPSED = 0.1
local SURFACE_TINT_EXPANDED = 0.36
local SURFACE_TINT_SUB = 0.22
local SURFACE_TINT_SUB_EXPANDED = 0.44
-- Sets carry enough color to tell their roles apart, but stay under the groups they live in:
-- the deepest level shouting louder than its parents turns the list upside down.
local SURFACE_TINT_SET = 0.42 -- raised from 0.26: set bands read as a clear role color, not a dim wash
local SURFACE_TINT_SET_EXPANDED = 0.56
local HEADER_BG_ALPHA = { 0.88, 0.85, 0.85 }
local HEADER_HOVER_TINT = 0.12
-- Groups with their own glowing surface, each in its own color. How much is the player's to
-- set: these are the three steps, Medium the level every glowing group used to have and Strong
-- the one NEW had, so the list starts out looking exactly as it always did.
IG.GLOW_LEVELS = { low = 0.15, medium = 0.225, strong = 0.34 }
IG.DEFAULT_GLOW = { NEW = "strong", REWARDS = "medium", ARMORY = "medium", HOME = "medium",
    LASTRUN = "medium", BINDONEQUIP = "medium" }
-- REWARDS glows on a warm dark base (on the default blue-grey base its yellow turns olive);
-- ARMORY's white glows on a neutral one.
-- RECENT LOOT's amber needs the same warm base as REWARDS' yellow, or it reads as olive.
-- NEW's cyan and UNCOLLECTED's teal are at home on the default base and are not listed.
local SPECIAL_SURFACE_BASE = { REWARDS = { 0.1, 0.075, 0.03 }, ARMORY = { 0.07, 0.07, 0.075 },
    HOME = { 0.08, 0.07, 0.07 }, LASTRUN = { 0.1, 0.07, 0.03 } }
-- How dark a base derived from a group's own color is: the brightest of its channels, brought
-- down to about what the hand-picked bases above sit at.
local SPECIAL_BASE_LUMA = 0.09

-- A group the player put on the glow list has no base of its own, so it gets a very dark version
-- of its own color. The four above keep the ones they were given; the two that are not listed
-- there keep none, which is the default base.
local function SpecialBase(key, color)
    if IG.DEFAULT_GLOW[key] then return SPECIAL_SURFACE_BASE[key] end
    local r, g, b = IG.HexToRGB(color)
    local peak = zo_max(r, zo_max(g, b))
    if peak <= 0 then return nil end
    local scale = SPECIAL_BASE_LUMA / peak
    return { r * scale, g * scale, b * scale }
end
local SPECIAL_EXPANDED_EXTRA_TINT = 0.1
-- Per-group header looks (outline, surface, text). None in use right now.
local HEADER_STYLES = {}
-- Read-only rows for items saved from your house chests (HOME CONTAINERS).
local STORED_ITEM_TYPE = 1708
local STORED_ITEM_HEIGHT = 44
-- "[right mouse] Menu" on the headers that have one.
-- The red a piece wears when it is standing where it belongs and has been sent somewhere else.
-- One red for the whole idea: the line over a stood-down row and the words over a category
-- every piece of which has gone are saying the same thing, and a second red would be read as a
-- second meaning. Kept up here because the heading needs it long before the item rows do.
local ASIDE_TEXT_COLOR = { 1, 0.29, 0.29, 1 }

-- A category whose every piece was sent away by hand says so on the right of its heading, which
-- is the one part of a top-level heading with nothing of its own to put there. All of them in
-- one place says it once instead of once per row, and it is the difference worth seeing from
-- the top of the list: the category is still there, and there is nothing in it that you have
-- not already spoken for.
local ALL_MOVED_TEXT = 'ALL MOVED TO "%s"'
-- Where they went to is only worth naming while it is one place. Once it is two, naming both
-- would be longer than the heading and still not tell you which piece went where -- the rows
-- inside say that, each for itself.
local ALL_MOVED_MIXED = "ALL MOVED"
local ALL_MOVED_WRAP_FIRST = "ALL MOVED"
local ALL_MOVED_WRAP_SECOND = 'TO "%s"'
local ALL_MOVED_FONT = "$(BOLD_FONT)|%d|soft-shadow-thin"
-- As large as it will go on one line, and a long category name is what stops it: then it is
-- broken over two, and both lines together stand no taller than the heading's own letters
-- (HEADER_FONTS: 19), which is what keeps it a note on the heading rather than a second one.
local ALL_MOVED_ONE_MAX, ALL_MOVED_ONE_MIN = 15, 12
local ALL_MOVED_TWO_MAX, ALL_MOVED_TWO_MIN = 9, 7
local ALL_MOVED_LINE_GAP = 1
-- Written from the right edge inwards, with only a hair of air behind it: the right of a
-- top-level heading is empty, and starting further in was cutting names off while that space
-- stood unused. Each line is then given exactly the width its letters measure, so nothing is
-- ever trimmed to fit a box.
local ALL_MOVED_RIGHT = 8
-- How much of the row is kept for the heading's own name and brackets. What is left of that is
-- all the words may take before they are made smaller: the name shrinks to fit what remains
-- (down to MIN_FONT_SIZE), and past this it would be shrinking to make room for a note.
local ALL_MOVED_KEEP = 300

-- And the heading is struck through, the way a line of a page is struck through: one slant
-- repeated at a steady spacing across the button. Thick enough to be seen without reading and
-- faint enough to be read through -- the name underneath is still the thing you came for. All
-- of them lean the same way on purpose; slants crossing would draw an X, which says the button
-- was deleted rather than that what stood under it has gone.
--
-- No file of our own is added for this (a DDS of ours comes out a white square) and none of the
-- game's art is borrowed either: a plain coloured control turned about its own centre is the
-- whole of a stripe, and turning is something a control does exactly (the wordmark on the sort
-- bar is turned the same way).
local STRIPE_COLOR = { 1, 0.29, 0.29 }
-- The strength goes on the control, never in the colour: a CT_TEXTURE with no texture on it
-- ignores the fourth number SetColor is given and answers SetAlpha instead.
local STRIPE_ALPHA = 0.22
local STRIPE_WIDTH = 7
local STRIPE_GAP = 26
local STRIPE_SLANT = math.rad(32)
-- Only sideways: the top and bottom are met exactly, but the plate's right edge stands a
-- little in from the row's and the last stripe stops with it.
local STRIPE_INSET = 2
local STRIPE_MAX = 60

local MENU_HINT_FONT = "$(MEDIUM_FONT)|14|soft-shadow-thin"
local MENU_GROUPS = { NEW = true, LASTRUN = true }
local SUBTITLE_COLOR = "9A9AA2"
-- Empty gap between top-level groups.
local SPACER_TYPE = 1704
-- Smaller gap inside a group, after a sub-group or set that was open.
local SUB_SPACER_TYPE = 1707
-- Set headers have their own row types: one line, or two with the piece badges underneath.
local SET_TYPE = 1705
local SET_TYPE_WITH_PIECES = 1706
-- From the left edge of a set's +/- to the first letter of its name. The second badge starts on
-- the same line (first badge offset + badge size + spacing, see SetDetails.lua).
local SET_NAME_OFFSET = 26
local SET_BADGE_OFFSET = 1
-- A set name is all capitals, so nothing hangs below the baseline and the letters sit in the
-- upper part of their label. The mark is lifted by the same amount to meet their middle.
local SET_MARKER_RISE = 3
-- And the same amount the other way for the name itself, once it has the whole row: centred on
-- the middle of its label, capitals with nothing under them ride above the middle of the row.
-- The mark takes itself back down, since it is placed against this line rather than the row.
local SET_CAP_DROP = SET_MARKER_RISE
-- Headers of the flat trading layout: top-level groups, but in the size of a sub-group header.
local TRADE_HEADER_TYPE = 1710
local TRADE_HEADER_LOOK = 2 -- which depth's height, font, icon and marker sizes they borrow
-- REWARDS' heading, a quarter taller than every other category heading. A type of its own: a
-- scroll list lays a type out at one fixed height, so a pooled row is never stretched by hand.
-- After the section strip types (ModuleStrip.lua, 1713-1728).
local TALL_HEADER_TYPE = 1729
local TALL_HEADER_KEYS = { REWARDS = true }
local TALL_HEADER_SCALE = 1.25
local IS_HEADER_TYPE = { [SET_TYPE] = true, [SET_TYPE_WITH_PIECES] = true, [TRADE_HEADER_TYPE] = true,
    [TALL_HEADER_TYPE] = true }
for _, typeId in ipairs(HEADER_TYPES) do IS_HEADER_TYPE[typeId] = true end
-- Rows we add ourselves (headers and spacers), as opposed to the game's item rows.
-- The last row of an open sub-group: only there to hold the foot of its strip (Frame.lua).
local SUB_FOOT_TYPE = 1709
-- The white heading a run of categories is read under.
local SECTION_TYPE = 1711
-- A set drawn as a rule rather than as a button: its name between two fading lines, its pieces
-- standing under it and no way to shut it. Settings: Groups > Categorization > Don't Group Sets.
local SET_RULE_TYPE = 1712
local IS_OWN_ROW_TYPE = { [SPACER_TYPE] = true, [SUB_SPACER_TYPE] = true, [STORED_ITEM_TYPE] = true,
    [SUB_FOOT_TYPE] = true, [SECTION_TYPE] = true, [SET_RULE_TYPE] = true }
-- The module buttons row (ModuleStrip.lua, loaded before this file): one type per line count.
for _, typeId in ipairs(IG.MODULE_STRIP_TYPES or {}) do IS_OWN_ROW_TYPE[typeId] = true end
if IG.MODULE_STRIP_HEAD_TYPE then IS_OWN_ROW_TYPE[IG.MODULE_STRIP_HEAD_TYPE] = true end
for typeId in pairs(IS_HEADER_TYPE) do IS_OWN_ROW_TYPE[typeId] = true end
local MAX_DEPTH = #HEADER_TYPES + 1

-- Groups that start expanded even though everything else starts collapsed.
-- LOCKED among them: it is switched on to be looked at, so it is open when it arrives.
local DEFAULT_EXPANDED = { NEW = true, LOCKED = true }
-- Nothing should have to be opened before it can be sold.
for _, category in ipairs(IG.TRADE_CATEGORIES) do DEFAULT_EXPANDED[category.key] = true end

local INVENTORY_KEYS -- filled on load: [inventoryType] = saved-variable key
local GROUPED_INVENTORIES = { INVENTORY_BACKPACK, INVENTORY_BANK, INVENTORY_GUILD_BANK,
    INVENTORY_HOUSE_BANK }

local sv  -- account-wide: expanded state
local csv -- per character: known item ids for NEW tracking

-- The bench lists: [inventoryType] = the key every skill's bench once shared ("craft",
-- "improve"). Filled on load, next to INVENTORY_KEYS.
local BENCH_KEYS

-- Every per-list memory a bench has. A skill's bench seen for the first time starts from what
-- the shared bench remembered, so nothing kept before the split is lost.
local BENCH_LIST_TABLES = { "expanded", "sectionCollapsed", "sectionDisplay", "sectionStripOpen",
    "lockedLists", "movedLists", "setViewLists" }

local function CopyValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = CopyValue(inner) end
    return copy
end

local function SeedBenchKey(base, key)
    sv.benchKeysSeeded = sv.benchKeysSeeded or {}
    if sv.benchKeysSeeded[key] then return end
    sv.benchKeysSeeded[key] = true
    for _, name in ipairs(BENCH_LIST_TABLES) do
        local lists = sv[name]
        if type(lists) == "table" and lists[key] == nil and lists[base] ~= nil then
            lists[key] = CopyValue(lists[base])
        end
    end
end

-- A bench's key: its own per crafting skill (GetCraftingInteractionType, the skill of the station
-- being used), the shared one when no skill answers (e.g. not at a station).
local function BenchKey(base)
    local skill = GetCraftingInteractionType and GetCraftingInteractionType()
    if not skill or skill == CRAFTING_TYPE_INVALID or not sv then return base end
    local key = base .. ":" .. skill
    SeedBenchKey(base, key)
    return key
end

-- The ones that carry an animation unless the player says otherwise, at normal speed. All four
-- share the one sweep: NEW, UNCOLLECTED, REWARDS and RECENT LOOT are all piles you are meant to
-- notice and work through.
IG.DEFAULT_ANIMATED = { NEW = "shift", BINDONEQUIP = "shift", REWARDS = "shift", LASTRUN = "shift" }

-- What a group is set to, whether or not the animations are switched on right now.
function IG.AnimationSetting(key)
    local entry = IG.sv.animations and IG.sv.animations[key]
    if entry then return entry.style or "none", entry.speed or "normal" end
    local style = IG.DEFAULT_ANIMATED[key]
    if style then return style, "normal" end
    return "none", "normal"
end

-- And what it actually plays. Animations have a switch of their own: the glows are a look, and
-- a theme sets those, while what moves on the screen stays the player's own choice.
local function AnimationFor(key)
    if sv.animationsEnabled == false then return nil end
    local style, speed = IG.AnimationSetting(key)
    if style == "none" then return nil end
    return style, speed
end

-- How much a group is set to glow, whether or not the glows are switched on right now.
function IG.GlowSetting(key)
    local entry = IG.sv.glows and IG.sv.glows[key]
    if entry then return entry.level or "none" end
    return IG.DEFAULT_GLOW[key] or "none"
end

-- And how much it actually glows: nothing at all with the switch off.
local function GlowTint(key)
    if sv.specialSurfaces == false then return nil end
    return IG.GLOW_LEVELS[IG.GlowSetting(key)]
end

---------------------------------------------------------------------------
-- NEW tracking
---------------------------------------------------------------------------

-- Loot that lands on a stack you already carried: only the added pieces are new, so the amount
-- is kept here. NEW then shows a row with just that count while the stack stays in its own group.
local partialNew = {}    -- [item unique id] = how many of the stack arrived just now
local partialFromRun = {} -- [item unique id] = those pieces were picked up during a run

local function SnapshotKnownItems()
    local known = {}
    -- Worn gear too: taking something off (e.g. switching Armory loadouts) must not make it NEW.
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_WORN }) do
        for slotIndex = 0, GetBagSize(bagId) - 1 do
            if HasItemInSlot(bagId, slotIndex) then
                known[Id64ToString(GetItemUniqueId(bagId, slotIndex))] = true
            end
        end
    end
    csv.known = known
    ZO_ClearTable(partialNew)
    ZO_ClearTable(partialFromRun)
end

-- Items that land in the bag without being newly acquired (taken off, withdrawn from a bank or a
-- house chest...) count as seen right away; only loot, rewards and purchases show up as NEW.
local function OnBackpackSlotUpdate(_, bagId, slotIndex, isNewItem, _, _, stackCountChange)
    if not csv.known or not HasItemInSlot(bagId, slotIndex) then return end
    local id = Id64ToString(GetItemUniqueId(bagId, slotIndex))
    local stackSize = GetSlotStackSize(bagId, slotIndex)
    if not isNewItem then
        csv.known[id] = true
        -- The stack changed without anything being acquired (used, split, moved): never claim
        -- more new pieces than it still holds, but don't forget them either.
        local pieces = partialNew[id]
        if pieces then
            pieces = zo_min(pieces, stackSize)
            partialNew[id] = pieces > 0 and pieces or nil
            if not partialNew[id] then partialFromRun[id] = nil end
        end
        return
    end
    -- A stack you already had that just grew: the slot itself is no news, only the pieces it
    -- gained. A slot you have never seen at all stays news as a whole, so it is left alone here.
    local added = stackCountChange or 0
    if added > 0 and added < stackSize and csv.known[id] then
        partialNew[id] = (partialNew[id] or 0) + added
        if IG.IsRunActive() then partialFromRun[id] = true end
    end
end

-- Empties NEW without having to close and reopen the inventory: everything you own now counts
-- as seen, and the items go back to the groups they belong to. With a filter (asked of each
-- backpack slot's data), only the new pieces it answers true for are seen; the rest stay NEW.
-- Returns how many pieces the filter let through (nil without one).
function IG.DistributeNew(filter)
    if type(filter) ~= "function" then
        SnapshotKnownItems()
        IG.RefreshLists()
        return nil
    end
    local count = 0
    local bag = csv.known and SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    for _, slotData in pairs(bag or {}) do
        local id = slotData.uniqueId and Id64ToString(slotData.uniqueId)
        if id and (not csv.known[id] or partialNew[id]) and filter(slotData) then
            csv.known[id] = true
            partialNew[id] = nil
            partialFromRun[id] = nil
            count = count + 1
        end
    end
    if count > 0 then IG.RefreshLists() end
    return count
end

-- What a Shift+Click on a category's heading, chip or tile does, by group key: the same as
-- that category's menu entry Distribute items. RECENT LOOT's keeps the run you are in, emptied
-- (IG.DistributeLastRun). Looked up when it runs, since Modules.lua loads after this file.
IG.SHIFT_CLICK_ACTIONS = {
    NEW = function() IG.DistributeNew() end,
    LASTRUN = function() IG.DistributeLastRun() end,
}

-- The Shift+Click's Distribute waits a moment and blinks what was clicked, so NEW does not
-- vanish before the eye has followed. One pending at a time; a second Shift+Click is ignored.
-- If the clicked control (or any parent) is hidden when the time is up, nothing happens.
local DISTRIBUTE_DELAY_MS = 200
local distributePending = nil
local function ShownOnScreen(control)
    while control do
        if control:IsHidden() then return false end
        control = control:GetParent()
    end
    return true
end
function IG.DistributeDelayed(control, key, action)
    action = action or IG.SHIFT_CLICK_ACTIONS[key]
    if distributePending or not action then return end
    local startAt = GetFrameTimeMilliseconds()
    local baseAlpha = control and control:GetAlpha() or 1
    distributePending = control or true
    local name = "Inventory2DistributeDelay"
    EVENT_MANAGER:RegisterForUpdate(name, 0, function()
        local t = GetFrameTimeMilliseconds() - startAt
        if control then
            -- Two quick blinks, fading down to a third.
            local phase = (t % 250) / 250
            control:SetAlpha(baseAlpha * (0.3 + 0.7 * math.abs(1 - 2 * phase)))
        end
        if t < DISTRIBUTE_DELAY_MS then return end
        EVENT_MANAGER:UnregisterForUpdate(name)
        distributePending = nil
        if control then control:SetAlpha(baseAlpha) end
        if control and not ShownOnScreen(control) then return end
        action()
    end)
end

-- Shift+Click on one item row under a category that distributes: just that piece goes, the
-- way its heading's Shift+Click sends them all (and with the same wait and blink). NEW sees the
-- piece through the same routine with a filter that lets only it through; RECENT LOOT lets it go
-- the way its menu line Distribute This Item does. By the group the row is drawn under, so the
-- same piece under its own category is left to the game.
IG.SHIFT_CLICK_ITEM_ACTIONS = {
    NEW = function(bagId, slotIndex)
        IG.DistributeNew(function(slotData)
            return slotData.bagId == bagId and slotData.slotIndex == slotIndex
        end)
    end,
    LASTRUN = function(bagId, slotIndex) IG.DistributeOneFromLastRun(bagId, slotIndex) end,
}

-- The row a click landed on (it usually lands on a part of one), with its entry.
local function ClickedItemRow(control)
    for _ = 1, 4 do
        if not control then return nil end
        local entry = control.dataEntry
        if entry and entry.igPath and entry.data and entry.data.bagId and entry.data.slotIndex then
            return control, entry
        end
        control = control.GetParent and control:GetParent()
    end
end

-- Typing in chat keeps the click the game's (a link may be wanted there).
local function ChatTyping()
    local entry = CHAT_SYSTEM and CHAT_SYSTEM.textEntry
    local edit = entry and entry.GetEditControl and entry:GetEditControl()
    return edit ~= nil and edit:HasFocus()
end

local function ShiftClickItem(control, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not IsShiftKeyDown() then return false end
    if IsControlKeyDown() or IsAltKeyDown() then return false end
    if IG.SelectionCount and IG.SelectionCount() > 0 then return false end
    if GetCursorContentType and GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then return false end
    if ChatTyping() then return false end
    local row, entry = ClickedItemRow(control)
    if not row then return false end
    local action
    for _, node in ipairs(entry.igPath) do
        action = IG.SHIFT_CLICK_ITEM_ACTIONS[node.id]
        if action then break end
    end
    if not action then return false end
    local bagId, slotIndex = entry.data.bagId, entry.data.slotIndex
    IG.DistributeDelayed(row, nil, function() action(bagId, slotIndex) end)
    return true
end

-- Hooked after the selection's hooks, so this one is asked first and steps aside while marking.
function IG.StartItemShiftDistribute()
    if ZO_InventorySlot_OnMouseUp then
        ZO_PreHook("ZO_InventorySlot_OnMouseUp", function(control, button, upInside)
            return upInside and ShiftClickItem(control, button) or false
        end)
    end
    if ZO_InventorySlot_OnSlotClicked then ZO_PreHook("ZO_InventorySlot_OnSlotClicked", ShiftClickItem) end
end

-- The same blink for feedback alone: Expand All does not open Chips/Tiles buttons (one can be
-- open per section), so the closed ones blink once the list is built to say they were left shut.
local BLINK_MS = 500
local blinkRun = 0
function IG.BlinkControls(controls)
    if not controls or #controls == 0 then return end
    blinkRun = blinkRun + 1
    local run, startAt, bases = blinkRun, GetFrameTimeMilliseconds(), {}
    for i, control in ipairs(controls) do bases[i] = control:GetAlpha() end
    local name = "Inventory2BlinkControls"
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, 0, function()
        local t = GetFrameTimeMilliseconds() - startAt
        local done = run ~= blinkRun or t >= BLINK_MS
        local phase = (t % 250) / 250
        for i, control in ipairs(controls) do
            if done then
                control:SetAlpha(bases[i])
            else
                control:SetAlpha(bases[i] * (0.3 + 0.7 * math.abs(1 - 2 * phase)))
            end
        end
        if done then EVENT_MANAGER:UnregisterForUpdate(name) end
    end)
end

-- RECENT LOOT already tells the story of everything picked up during a run, so with the setting on,
-- none of it is repeated under NEW: neither whole stacks nor pieces added to older ones.
local function LastRunTakesOver(slotData, uniqueId)
    if not sv.lastRunOverNew then return false end
    -- A piece RECENT LOOT leaves out (AUTOMATE) is not told, or it would be shown nowhere.
    if slotData and IG.HiddenFromRecentLoot(slotData) then return false end
    if uniqueId and partialFromRun[uniqueId] then return true end
    return IG.IsInLastRun(slotData)
end

local function IsNewSlot(slotData)
    -- The module is answered here rather than where the path is made: a piece told it is new
    -- asks for a NEW heading and would be sent to the fallback category if there were none, so
    -- with the group switched off nothing is ever called new and every piece keeps its own place.
    -- What has been seen goes on being written down either way (csv.known below), so switching
    -- the group back on answers with what has really arrived rather than with the whole bag.
    if not sv.newEnabled then return false end
    if not csv.known or slotData.bagId ~= BAG_BACKPACK or not slotData.uniqueId then return false end
    return not csv.known[Id64ToString(slotData.uniqueId)]
end

-- The categories whose NEW pieces are nothing to keep: Distribute Only Unnecessary sees these
-- and leaves the rest of NEW standing.
local UNNECESSARY_KEYS = { SELL = true, DECON = true, GARBAGE = true, JUNK = true, STOLEN = true }

-- A treasure (not a quest's) or a plain trophy that is only worth its gold.
local function IsSellOnlyTreasure(itemLink)
    local itemType, specializedType = GetItemLinkItemType(itemLink)
    if itemType == ITEMTYPE_TREASURE then return not IsItemLinkBound(itemLink) end
    return itemType == ITEMTYPE_TROPHY and specializedType == SPECIALIZED_ITEMTYPE_NONE
        and not IsItemLinkBound(itemLink) and (GetItemLinkValue(itemLink) or 0) > 0
end

-- Whether a new piece is one you would only sell or throw away: it stands (rules and moves by
-- hand included) in SELL, DECONSTRUCT, GARBAGE, JUNK or STOLEN, is marked junk or stolen, or is
-- a treasure (not a quest's) or a plain sell-only trophy wherever it stands.
local function IsUnnecessaryNew(slotData)
    if not (slotData and slotData.bagId and slotData.slotIndex) then return false end
    if slotData.stolen or IsItemJunk(slotData.bagId, slotData.slotIndex) then return true end
    -- A piece a crafting writ wants goes to DAILY WRIT.
    if IG.IsDailyWritItem and IG.IsDailyWritItem(slotData) then return true end
    local path = IG.ClassifySlot(slotData, false, false)
    if path and path[1] and UNNECESSARY_KEYS[path[1].id] then return true end
    return IsSellOnlyTreasure(GetItemLink(slotData.bagId, slotData.slotIndex))
end

-- Crafting materials of every kind (the craft bag's own), by item type.
local MATERIAL_TYPES = {}
for _, name in ipairs({ "ITEMTYPE_ADDITIVE", "ITEMTYPE_ARMOR_BOOSTER", "ITEMTYPE_ARMOR_TRAIT",
    "ITEMTYPE_BLACKSMITHING_BOOSTER", "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",
    "ITEMTYPE_CLOTHIER_BOOSTER", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
    "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
    "ITEMTYPE_ENCHANTMENT_BOOSTER", "ITEMTYPE_FISH", "ITEMTYPE_FLAVORING", "ITEMTYPE_FURNISHING_MATERIAL",
    "ITEMTYPE_INGREDIENT", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
    "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",
    "ITEMTYPE_JEWELRY_RAW_TRAIT", "ITEMTYPE_JEWELRY_TRAIT", "ITEMTYPE_POISON_BASE", "ITEMTYPE_POTION_BASE",
    "ITEMTYPE_RAW_MATERIAL", "ITEMTYPE_REAGENT", "ITEMTYPE_SPICE", "ITEMTYPE_STYLE_MATERIAL",
    "ITEMTYPE_WEAPON_BOOSTER", "ITEMTYPE_WEAPON_TRAIT", "ITEMTYPE_WOODWORKING_BOOSTER",
    "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_RAW_MATERIAL" }) do
    if _G[name] then MATERIAL_TYPES[_G[name]] = true end
end
-- Repair kits of every kind.
local REPAIR_TYPES = { [ITEMTYPE_TOOL] = true, [ITEMTYPE_CROWN_REPAIR] = true, [ITEMTYPE_GROUP_REPAIR] = true }

-- Keep Out of NEW: whether a piece is never shown under NEW, by the kinds switched on in the
-- NEW settings. Asked while drawing, so a piece moved to another category later follows it.
local function KeptOutOfNew(slotData)
    if not (slotData and slotData.bagId and slotData.slotIndex) then return false end
    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    if sv.newOutStolen and slotData.stolen then return true end
    if sv.newOutJunk and IsItemJunk(bagId, slotIndex) then return true end
    if sv.newOutDailyWrit and IG.IsDailyWritItem and IG.IsDailyWritItem(slotData) then return true end
    local itemLink = GetItemLink(bagId, slotIndex)
    local itemType = GetItemLinkItemType(itemLink)
    if sv.newOutTrash and itemType == ITEMTYPE_TRASH then return true end
    if sv.newOutTreasure and IsSellOnlyTreasure(itemLink) then return true end
    if sv.newOutMaterials and MATERIAL_TYPES[itemType] then return true end
    if sv.newOutStock and (REPAIR_TYPES[itemType] or itemType == ITEMTYPE_SOUL_GEM) then
        return true
    end
    if sv.newOutGarbage or sv.newOutJunk or sv.newOutSell or sv.newOutDecon or sv.newOutStolen then
        local path = IG.ClassifySlot(slotData, false, false)
        local key = path and path[1] and path[1].id
        if (key == "GARBAGE" and sv.newOutGarbage) or (key == "JUNK" and sv.newOutJunk)
            or (key == "SELL" and sv.newOutSell) or (key == "DECON" and sv.newOutDecon)
            or (key == "STOLEN" and sv.newOutStolen) then
            return true
        end
    end
    return false
end
IG.KeptOutOfNew = KeptOutOfNew

-- How many pieces NEW is showing that Distribute Only Unnecessary would take out.
local function CountUnnecessaryNew()
    local count = 0
    local bag = sv.newEnabled and csv.known and SHARED_INVENTORY and SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    for _, slotData in pairs(bag or {}) do
        local id = slotData.uniqueId and Id64ToString(slotData.uniqueId)
        local shown = id and (partialNew[id] or (not csv.known[id] and not LastRunTakesOver(slotData)))
        if shown and not KeptOutOfNew(slotData) and IsUnnecessaryNew(slotData) then count = count + 1 end
    end
    return count
end

-- NEW keeps what you might want; SELL, DECONSTRUCT, GARBAGE, JUNK, STOLEN and treasures go.
function IG.DistributeUnnecessaryNew()
    return IG.DistributeNew(IsUnnecessaryNew)
end

---------------------------------------------------------------------------
-- Collapse state
---------------------------------------------------------------------------

-- While a list is being searched, its clicks go to a table of their own that is never saved:
-- everything starts open so the matches show, the player can still open and close, and what
-- he had before the search is left as it was. Forgotten whenever the search text changes.
local searchStates = {} -- [invKey] = { text = ..., expanded = {}, sections = {}, scroll = ... }

-- Where a list is scrolled to, and putting it back there. A rebuild snaps a list to the top, and
-- the list it leaves can be shorter than the one it replaced, so the way back stays inside what
-- the new one can scroll. Scrolling never rebuilds, so putting the place back starts nothing.
local function ReadScroll(list)
    return list and list.scrollbar and list.scrollbar:GetValue() or nil
end

local function RestoreScroll(list, value)
    if not (value and list and list.scrollbar) then return end
    local lowest, highest = list.scrollbar:GetMinMax()
    ZO_ScrollList_ScrollAbsolute(list, zo_clamp(value, lowest, highest))
end

-- The same, run once on the next frame: for a place read inside a build, which the game only
-- commits after the build has returned.
local function RestoreScrollLater(name, list, value)
    if not (value and list) then return end
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(name)
        if list:IsHidden() then return end
        RestoreScroll(list, value)
    end)
end

-- Rebuilds a list with rebuild() and puts it back where the player was.
local function KeepingScroll(list, rebuild)
    local value = ReadScroll(list)
    rebuild()
    if list and not list:IsHidden() then RestoreScroll(list, value) end
end

-- Called by the build with the list's search text ("" or nil when there is none). Where the list
-- was when the search started is kept with it, and the list goes back there when it is cleared.
local function NoteSearch(invKey, text, list)
    if not invKey then return end
    local current = searchStates[invKey]
    if not text or text == "" then
        if current then
            searchStates[invKey] = nil
            RestoreScrollLater("InventoryGroupingSearchScroll" .. invKey, list, current.scroll)
        end
        return
    end
    if not current or current.text ~= text then
        -- A search typed further is the same search: it keeps the place the first letter found.
        local scroll = current and current.scroll or ReadScroll(list)
        searchStates[invKey] = { text = text, expanded = {}, sections = {}, scroll = scroll }
    end
end

-- A list that has never been seen has no table yet; "Reset everything" can take one away too.
local function States(invKey)
    local search = searchStates[invKey]
    if search then return search.expanded end
    local states = sv.expanded[invKey]
    if not states then
        states = {}
        sv.expanded[invKey] = states
    end
    return states
end

local function IsExpanded(invKey, nodeKey)
    local state = States(invKey)[nodeKey]
    if state == nil then
        if searchStates[invKey] then return true end
        return sv.startExpanded == true or DEFAULT_EXPANDED[nodeKey] == true
    end
    return state
end

local function ToggleExpanded(invKey, nodeKey)
    States(invKey)[nodeKey] = not IsExpanded(invKey, nodeKey)
end

-- Opened by something other than a click on it: following a piece to wherever it went.
local function SetExpanded(invKey, nodeKey, open)
    States(invKey)[nodeKey] = open
end

-- A section heading (ATTENTION, MODULES, ...) shut away with everything under it. Kept per list
-- under its own table, made the first time it is needed, and only ever holds the shut ones.
local function SectionStates(invKey)
    local search = searchStates[invKey]
    if search then return search.sections end
    sv.sectionCollapsed = sv.sectionCollapsed or {}
    local states = sv.sectionCollapsed[invKey]
    if not states then
        states = {}
        sv.sectionCollapsed[invKey] = states
    end
    return states
end

local function IsSectionShut(invKey, label)
    return invKey ~= nil and label ~= nil and SectionStates(invKey)[label] == true
end

-- Closed is written down as false rather than forgotten: with "start with every group open" an
-- entry that isn't there means open, so clearing one would open it again.
local CLOSED = false

-- Accordion: closes the other groups that sit next to this one, so only one stays open.
--
-- The table only holds what has been clicked at least once, and a group that has never been
-- clicked can still be open -- NEW starts that way, and with "start with every group open" all
-- of them do. So the rows on screen are walked as well: whatever is beside this one and drawn
-- right now is written down as closed, whether or not it was ever written down before.
local function CollapseSiblings(invKey, nodeKey, list)
    local parent = nodeKey:match("^(.*)/[^/]*$")
    local prefix = parent and (parent .. "/") or ""
    local states = States(invKey)
    -- A category inside DISPOSAL has a key with no slash, the same as a top-level one (NodeKey
    -- leaves DISPOSAL out of it), so the two levels are told apart by asking DISPOSAL: its own
    -- categories are siblings of each other, and of nothing at the top level.
    local inside = not parent and IG.InDisposal(nodeKey)
    local function Close(key)
        if key == nodeKey or zo_strsub(key, 1, #prefix) ~= prefix then return end
        if key:sub(#prefix + 1):find("/") then return end
        if not parent and IG.InDisposal(key) ~= inside then return end
        states[key] = CLOSED
    end
    -- Only keys already in the table are written here, so the walk over it stays sound.
    for key in pairs(states) do Close(key) end
    if not list then return end
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local key = IS_HEADER_TYPE[entry.typeId] and entry.data and entry.data.key
        if key then Close(key) end
    end
end

-- Collapses every group below a node while keeping the node itself open.
local function CollapseChildren(invKey, nodeKey)
    local prefix = nodeKey .. "/"
    local expanded = States(invKey)
    -- DISPOSAL's children are its categories, whose keys do not start with its own.
    local disposal = nodeKey == IG.DISPOSAL_KEY
    for key in pairs(expanded) do
        if zo_strsub(key, 1, #prefix) == prefix
            or (disposal and IG.InDisposal(key:match("^[^/]*"))) then
            expanded[key] = CLOSED
        end
    end
    expanded[nodeKey] = true
end

-- DISPOSAL shut (its heading, its Chips/Tiles button, Close All -- whichever way): everything
-- inside it is written down as closed, so opening it again shows its categories shut. Asked by
-- the build, once per shutting (disposalShut remembers it until DISPOSAL is seen open again).
local disposalShut = {}
local function NoteDisposalOpen(invKey, open)
    if not invKey or searchStates[invKey] then return end
    if open then disposalShut[invKey] = nil return end
    if disposalShut[invKey] then return end
    disposalShut[invKey] = true
    local states = States(invKey)
    for key in pairs(states) do
        if key ~= IG.DISPOSAL_KEY and IG.InDisposal(key:match("^[^/]*")) then states[key] = CLOSED end
    end
    for member in pairs(IG.DISPOSAL_MEMBERS) do
        if IG.InDisposal(member) then states[member] = CLOSED end
    end
end

-- Every header a list is showing right now, written down as closed.
local function CollapseBuiltList(invKey, list)
    if not invKey or not list then return end
    local states = States(invKey)
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local key = IS_HEADER_TYPE[entry.typeId] and entry.data and entry.data.key
        if key then states[key] = CLOSED end
    end
end

-- The other way round, and not a mirror of it: a list only holds the headers it is currently
-- drawing, so what is inside a closed group is not there to be opened yet. One pass opens what
-- is on screen; the caller builds the list again and comes back for what that brought into view.
-- Answers whether it opened anything, which is how the caller knows to stop.
local function ExpandBuiltList(invKey, list)
    if not invKey or not list then return false end
    local states = States(invKey)
    local opened = false
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local key = IS_HEADER_TYPE[entry.typeId] and entry.data and entry.data.key
        if key and states[key] ~= true then
            states[key] = true
            opened = true
        end
    end
    return opened
end

-- Our own trees are three deep, and a pass that opens nothing ends it early anyway; the count is
-- only here so that a list we have not thought of cannot spin forever.
local EXPAND_PASSES = 6

---------------------------------------------------------------------------
-- Building the grouped list
---------------------------------------------------------------------------

local function ResolveInventory(manager, inventoryType)
    if inventoryType == INVENTORY_BANK then
        return manager.inventories[INVENTORY_BANK], INVENTORY_BANK
    elseif inventoryType == INVENTORY_GUILD_BANK then
        return manager.inventories[INVENTORY_GUILD_BANK], INVENTORY_GUILD_BANK
    elseif inventoryType == INVENTORY_HOUSE_BANK then
        return manager.inventories[INVENTORY_HOUSE_BANK], INVENTORY_HOUSE_BANK
    elseif inventoryType == INVENTORY_CRAFT_BAG or inventoryType == INVENTORY_QUEST_ITEM then
        return nil
    end
    -- Mirrors ZO_InventoryManager:ApplySort, which falls back to the selected tab.
    if manager.selectedTabType == INVENTORY_BACKPACK then
        return manager.inventories[INVENTORY_BACKPACK], INVENTORY_BACKPACK
    end
end

-- A category inside DISPOSAL keeps the key it has at the top level ("SELL", "SELL/..."):
-- DISPOSAL is left out of every key below it, so what is open, painted or remembered about the
-- category is the same answer inside DISPOSAL and out of it.
local function NodeKey(path, depth)
    local parts = {}
    local from = (depth > 1 and path[1].id == IG.DISPOSAL_KEY) and 2 or 1
    for i = from, depth do parts[#parts + 1] = path[i].id end
    return table.concat(parts, "/")
end

-- The category a path is filed under: its top node, or the category inside DISPOSAL.
local function CategoryKey(path)
    local top = path and path[1]
    if not top then return nil end
    local second = path[2]
    if top.id == IG.DISPOSAL_KEY and second and IG.DISPOSAL_MEMBERS[second.id] then
        return second.id
    end
    return top.id
end

-- Where the Group Sets / Don't Group Sets answer for a path is kept. Inside LOCKED every category
-- answers for itself under "LOCKED/<category>" (its own heading is the one with the right click),
-- and one never asked falls back to what LOCKED as a whole was told, then to the setting.
local function SetViewKey(path)
    local top, second = path and path[1], path and path[2]
    if top and top.id == "LOCKED" and second and not second.isSet then
        return "LOCKED/" .. second.id
    end
    return CategoryKey(path)
end

local function SetsAsDividersFor(windowKey, path)
    local key = SetViewKey(path)
    if key ~= CategoryKey(path) and not IG.SetViewChoice(windowKey, key) then
        key = CategoryKey(path)
    end
    return IG.SetsAsDividers(windowKey, key)
end

-- Puts every row of a category that is inside DISPOSAL one level down, under DISPOSAL. A new
-- path every time: the classifier caches and shares its paths, and writing into one would
-- nest it again on the next build.
local function NestDisposal(items)
    local root
    for _, entry in ipairs(items) do
        local path = entry.igPath
        local top = path and path[1]
        if top and IG.InDisposal(top.id) then
            if not root then
                root = IG.MakeGroupNode(IG.DISPOSAL_KEY)
                -- The heading says how many items are in it, and nothing else.
                root.totalOnly = true
            end
            local nested = { root }
            for field, value in pairs(path) do
                if type(field) ~= "number" then nested[field] = value end
            end
            for depth = 1, #path do nested[depth + 1] = path[depth] end
            entry.igPath = nested
        end
    end
end

-- The game's own column sort (NAME, VALUE, ...), for the lists where its header is the sort
-- control rather than our Sort button: the selling layout once a header was clicked, and the
-- crafting stations. { key, order, keys } -- the game's current key and direction, and its own
-- tie-break table (ZO_Inventory_GetDefaultHeaderSortKeys, inventory.lua; the stations keep a
-- local copy, Craft.lua). nil everywhere else.
IG.headerSort = nil

-- Two items by the game's header sort, the way the game compares them itself
-- (ZO_TableOrderingFunction). nil when it has nothing to say: no header sort in force, or a row
-- that is not a real slot (empty-group and set-aside rows carry no value to compare).
function IG.CompareByHeader(a, b)
    local sort = IG.headerSort
    if not sort or not sort.keys[sort.key] then return nil end
    local dataA, dataB = a.data, b.data
    if not dataA or not dataB or dataA.slotIndex == nil or dataB.slotIndex == nil then return nil end
    if dataA[sort.key] == nil or dataB[sort.key] == nil then return nil end
    if ZO_TableOrderingFunction(dataA, dataB, sort.key, sort.keys, sort.order) then return true end
    if ZO_TableOrderingFunction(dataB, dataA, sort.key, sort.keys, sort.order) then return false end
    return nil
end

-- Two items in the same category, wherever that category came from.
local function CompareItems(a, b)
    if a.igSlotRank and b.igSlotRank and a.igSlotRank ~= b.igSlotRank then
        return a.igSlotRank < b.igSlotRank
    end
    local byHeader = IG.CompareByHeader(a, b)
    if byHeader ~= nil then return byHeader end
    local sortBy = IG.sv.sortBy
    if sortBy == "value" then
        local valueA, valueB = a.data.stackSellPrice or 0, b.data.stackSellPrice or 0
        if valueA ~= valueB then return valueA > valueB end
    elseif sortBy == "quality" then
        local qualityA, qualityB = a.data.displayQuality or 0, b.data.displayQuality or 0
        if qualityA ~= qualityB then return qualityA > qualityB end
    elseif sortBy == "count" then
        local countA, countB = a.data.stackCount or 0, b.data.stackCount or 0
        if countA ~= countB then return countA > countB end
    elseif sortBy == "age" then
        -- The game stamps a slot the moment something new lands in it and leaves the rest at
        -- nothing, so what this really says is: what arrived, newest first, and then the rest
        -- of it by name. A piece already in the bag at login has no arrival to be sorted by.
        local ageA, ageB = a.data.age or 0, b.data.age or 0
        if ageA ~= ageB then return ageA > ageB end
    end
    if a.igSortName ~= b.igSortName then return a.igSortName < b.igSortName end
    -- Saved house items have no bag slot; fall back to 0 so they still sort consistently.
    local bagA, bagB = a.data.bagId or 0, b.data.bagId or 0
    if bagA ~= bagB then return bagA < bagB end
    return (a.data.slotIndex or 0) < (b.data.slotIndex or 0)
end
IG.CompareItems = CompareItems

local function CompareEntries(a, b)
    local pa, pb = a.igPath, b.igPath
    if pa[1].id ~= pb[1].id then
        -- The heading a category is read under comes before the place it holds inside that
        -- heading, the same way IG.GetOrderedGroups reads them. Order alone used to be enough
        -- only because every category still stood in the run its heading names; one that had
        -- been sent elsewhere -- by the Heading picker, or by the switch under JUNK -- sorted to
        -- its old place and had its heading drawn a second time around it.
        if IG.SectionsOn() then
            local sectionA = IG.SECTION_INDEX[IG.GetGroupSection(pa[1].id)] or 0
            local sectionB = IG.SECTION_INDEX[IG.GetGroupSection(pb[1].id)] or 0
            if sectionA ~= sectionB then return sectionA < sectionB end
        end
        return IG.GetGroupOrder(pa[1].id) < IG.GetGroupOrder(pb[1].id)
    end
    -- Sub-levels: named sub-groups by their fixed order, others (sets) alphabetically.
    -- Items sitting directly under a node come before its sub-groups.
    for i = 2, zo_max(#pa, #pb) do
        local na, nb = pa[i], pb[i]
        if not na or not nb then return na == nil end
        if na.id ~= nb.id then
            local oa, ob = na.order or math.huge, nb.order or math.huge
            if oa ~= ob then return oa < ob end
            return na.label < nb.label
        end
    end
    return CompareItems(a, b)
end

-- A bench can put the category it is there for at the head of its list: DECONSTRUCT at
-- deconstruction (Craft.lua hands it over as the list's lead). The heading it is read under
-- comes before every other heading and the category first under it -- DISPOSAL first when the
-- category stands inside it, and the category first inside DISPOSAL. Each row is ranked once
-- (LeadFirst, below); rows of the same rank keep the order they always had.
local function CompareLeadFirst(a, b)
    if a.igLeadRank ~= b.igLeadRank then return a.igLeadRank < b.igLeadRank end
    return CompareEntries(a, b)
end

-- The order a bench's list is sorted by when it has a lead and the lead holds something; nil
-- otherwise, which leaves the usual order. An empty lead is drawn exactly as it was before.
--
-- The first build of each visit (lead.fresh, set again as the bench is left) also opens it:
-- its heading unshut, its Chips/Tiles button the open one, its own heading and DISPOSAL's open.
-- Written into the list's own answers, so a click during the visit still shuts it, and the next
-- visit opens it again. A search the visit before left behind goes with it: the place NoteSearch
-- would put the list back to belongs to that visit, and this one starts at the top.
local function LeadFirst(items, lead, invKey, searchText)
    local key = lead and lead.key
    if not key then return nil end
    local fresh = lead.fresh and searchText == ""
    -- The search memory goes on the visit's first build; the opening waits for the first build
    -- the lead holds something in (a filter tab kept from last visit may show none of it).
    if fresh and lead.fresh ~= "searchCleared" then
        lead.fresh = "searchCleared"
        if invKey then searchStates[invKey] = nil end
    end
    local held = false
    for _, entry in ipairs(items) do
        if not entry.igEmpty and CategoryKey(entry.igPath) == key then
            held = true
            break
        end
    end
    if not held then return nil end
    local top = IG.InDisposal(key) and IG.DISPOSAL_KEY or key
    local section = IG.SectionsOn() and IG.GetGroupSection(top) or nil
    if fresh then lead.fresh = nil end
    if fresh and invKey then
        if section then
            SectionStates(invKey)[section] = nil
            if IG.SectionDisplay and IG.SectionDisplay(invKey, section) ~= "rows" then
                sv.sectionStripOpen = sv.sectionStripOpen or {}
                sv.sectionStripOpen[invKey] = sv.sectionStripOpen[invKey] or {}
                sv.sectionStripOpen[invKey][section] = top
            end
        end
        SetExpanded(invKey, top, true)
        if top ~= key then SetExpanded(invKey, key, true) end
    end
    for _, entry in ipairs(items) do
        local path = entry.igPath
        local rank = 0
        if section and IG.GetGroupSection(path[1].id) ~= section then rank = rank + 4 end
        if path[1].id ~= top then rank = rank + 2 end
        if CategoryKey(path) ~= key then rank = rank + 1 end
        entry.igLeadRank = rank
    end
    return CompareLeadFirst
end

-- Groups that only exist while their module is switched on.
--
-- LOCKED is one of them in every way that matters -- a menu on its header, not drawn empty
-- while it is off -- but its switch is not a switch: it is an answer per list, kept in the
-- table named here and asked for with a list's key. Every place that reads this table asks
-- LOCKED its own way before it gets as far as the value.
local MODULE_GROUPS = { EQUIPPED = "equippedEnabled", NEW = "newEnabled", ARMORY = "armoryEnabled", HOME = "homeEnabled", LASTRUN = "lastRunEnabled",
    BINDONEQUIP = "bindOnEquipEnabled", JUNK = "junkEnabled", LOCKED = "lockedLists",
    CUSTOM = "customEnabled", GUILDSELL = "guildSellEnabled", JUSTCRAFTED = "justCraftedEnabled",
    DAILYWRIT = "dailyWritEnabled", SETUPS = "setupsEnabled", RESEARCH = "researchableEnabled",
    -- Its switch hides the button only: marking and depositing go on regardless (ToBank.lua).
    TOBANK = "toBankShown" }
-- Read by the MODULES drawer (Drawer.lua), so a module added here is a line there as well.
IG.MODULE_GROUPS = MODULE_GROUPS

-- Categories whose heading offers something done to everything standing under it, rather than
-- to the one row that was clicked. Only one of them so far, and the table is here so the second
-- one is a key rather than a rewrite.
--
-- What is under a heading is only known while the list is being built: the tree is worked out
-- there and thrown away, and a row inside a closed group is not in the finished list to be
-- asked afterwards. So the build writes down what went into these categories, per list, and the
-- menu reads that.
-- Headings that offer something done to the whole of what stands under them, and therefore
-- have to know what that is: the build writes their pieces down as it goes (NoteActionGroups).
-- The selling layout's own Sell heading is one of them -- at a merchant it is the only place
-- the SELL category is on screen at all, since the tree is put away there (Trading.lua).
-- SELL is one as well: at a merchant or a fence the bag keeps its own layout, and there the
-- real SELL heading carries the same Sell All line.
local ACTION_GROUPS = { GARBAGE = true, TRADE_SELL = true, SELL = true }

-- The category that is nothing but a mark, and the only one whose headings can hand that mark
-- back. It is named rather than listed: there is one of it, and everything below asks about it
-- by this name.
local JUNK_ACTION_KEY = "JUNK"
local groupMembers = {}

-- [list key] = the keys of the sets standing under LOCKED in that list, written down by every
-- build (BuildGroupedList) because a set inside a shut category is not in the finished list to be
-- asked afterwards. Read by the LOCKED heading's "Expand all sets" / "Collapse all sets".
local lockedSetKeys = {}

-- [list key] = the keys of the real categories (DUNGEON, ARENA, ...) a locked piece is standing
-- under in that list -- what the LOCKED heading is actually showing, as opposed to IG.GROUP_BY_KEY
-- entries whose own section happens to read "LOCKED" (there is exactly one of those: LOCKED
-- itself). Read by the LOCKED heading's "Color All Categories...": those are the headings on
-- screen under it, and they are the ones a colour painted there is meant to reach.
local lockedCategoryKeys = {}

-- And what is standing under each heading inside JUNK, that heading included: one list per
-- heading rather than one for the category, because JUNK is broken into sub-categories by a
-- setting that can change under it and each of those headings answers for its own pieces.
local junkMembers = {}

-- Categories that can be called something else from their own header. They are the ones no rule
-- fills: what is in one is there because you put it there, so what it is called is the only
-- thing on screen saying what you are using it for.
local RENAME_GROUPS = { CUSTOM = true, GUILDSELL = true }

-- Headers with a right click menu: the ones that can hand their items back, the ones that can
-- be renamed, and every module (which can be switched off from there).
local function HasMenu(key)
    return MENU_GROUPS[key] or RENAME_GROUPS[key] or MODULE_GROUPS[key] ~= nil
end

-- Whether a heading answers a right click at all. Every one of them does now: handing its items
-- back or switching its module off is something only a few can offer, but a colour of its own is
-- something any heading can be given, so the menu is built for all of them and each one gets the
-- lines that mean something for it. What is not a heading never arrives here -- the headings the
-- list is read under, our spacers and the feet are drawn as other row types, with no handler of
-- their own -- and a set drawn as a rule cannot be right clicked either, as it is drawn by one
-- of those types as well.
--
-- The Minimal layout is the exception: it is one flat level of cream with no colours in it, and
-- an offer to repaint a heading there would be an offer to change nothing. "Is this Minimal" is
-- asked the way the rest of the file asks it, through the flat layout switch that theme sets.
-- A category's own heading: a top-level one, or one of DISPOSAL's categories drawn under it.
local function IsCategoryHead(data)
    return data ~= nil and data.key ~= nil
        and (data.depth == 1 or data.disposalSub == true or data.lockedSub == true)
end

local function HeaderHasMenu(data)
    if not data or data.isRule then return false end
    if sv.flatGrouping then return false end
    return data.menu ~= nil or data.isSet or data.key ~= nil
end

-- While selling, trading or mailing the bag switches to the flat trading layout (Trading.lua).
-- Each scene has a key of its own in sv.npcCategoryTypes (Settings.lua: NPC_CATEGORY_TYPES), so
-- the player can turn the flat layout off at one of these and keep it everywhere else.
local TRADING_SCENES = { "store", "fence_keyboard", "tradinghouse", "trade", "mailSend" }
local TRADING_SCENE_TYPE = { store = "merchant", fence_keyboard = "fence",
    tradinghouse = "guildstore", trade = "playertrade", mailSend = "mail" }
local function IsTrading()
    -- The global switch is above the per-type ones: off, none of the five ever switch the bag.
    if sv.npcCategoryEnabled == false then return false end
    for _, name in ipairs(TRADING_SCENES) do
        if SCENE_MANAGER:IsShowing(name) and sv.npcCategoryTypes[TRADING_SCENE_TYPE[name]] ~= false then
            return true
        end
    end
    return false
end

-- Asked by the toolbar, which puts its box away on the selling layout.
IG.IsTrading = IsTrading

-- A merchant's and a fence's sell window are the exception: there the bag keeps its own
-- grouping, sections and categories exactly as in the bag, and what the flat layout offered on
-- its Sell heading (Sell All, the column header sort) is offered on the real SELL heading.
-- The guild store, a trade and the mail keep the flat layout.
local MERCHANT_SCENES = { "store", "fence_keyboard" }
local function AtMerchantSell()
    for _, name in ipairs(MERCHANT_SCENES) do
        if SCENE_MANAGER:IsShowing(name) then return true end
    end
    return false
end

-- Whether the flat trading layout is the one on screen, rather than any trading scene at all.
local function IsTradingLayout()
    return IsTrading() and not AtMerchantSell()
end

-- The bag is on screen in many places. At a bank it is the bank's companion rather than the
-- bag on its own, which the drawers ask (IG.BagOnItsOwn).
local BANK_SCENES = { "bank", "guildBank", "houseBank" }

-- The layout a list is grouped with when it is grouped at all: the flat selling layout, the flat
-- Minimal one, or the usual tree.
local function GroupedMode()
    return sv.flatGrouping and "minimal" or "normal"
end

-- "trading", "minimal" or "normal". Every list is ours while the addon runs; the Global Switch
-- is the one way back to the game's own lists.
local function BackpackMode()
    -- The bag keeps its own layout at a merchant or a fence.
    if IsTrading() and not AtMerchantSell() then return "trading" end
    return GroupedMode()
end

local lastBackpackMode -- what the bag's list was last built as

local function ListMode(inventoryType)
    if inventoryType == INVENTORY_BACKPACK then return BackpackMode() end
    return GroupedMode()
end

-- Whether the bag is on screen on its own: not selling, trading or mailing, and not beside a
-- bank. The drawers belong there and nowhere else (Drawer.lua).
function IG.BagOnItsOwn()
    if IsTrading() then return false end
    for _, sceneName in ipairs(BANK_SCENES) do
        if SCENE_MANAGER:IsShowing(sceneName) then return false end
    end
    return true
end

-- "Show empty groups": a group holding nothing still gets its header. It rides along as a row
-- that carries the path but is dropped again before the list is filled.
-- Two of the modules are a switch and nothing else: no pass collects rows for them, a piece
-- reaches one by hand, and the classifier answers with it in every list there is -- a bench
-- included, exactly as SELL and DECONSTRUCT do. So they are drawn empty wherever the tree is.
-- The rest build their rows for the bag and the bank alone, and an empty heading for one of
-- those at a bench would be a heading nothing could ever fill.
local ASIDE_MODULE_GROUPS = { CUSTOM = true, GUILDSELL = true }
-- Filled at a bench and nowhere else: an empty heading for it would stand in the bag for good.
local NEVER_EMPTY_GROUPS = { JUSTCRAFTED = true }
-- Filled in the backpack and nowhere else: a piece marked for the bank stands on its own
-- anywhere else (Classify.lua, OverrideForSlot), so in the bank's own list it never could be.
local BACKPACK_ONLY_GROUPS = { TOBANK = true }

local function AddEmptyGroups(items, ownBags, invKey, isBackpack)
    local used = {}
    for _, entry in ipairs(items) do used[entry.igPath[1].id] = true end
    -- DISPOSAL is not drawn empty while one of its categories holds something.
    for member in pairs(IG.DISPOSAL_MEMBERS) do
        if used[member] and IG.InDisposal(member) then used[IG.DISPOSAL_KEY] = true end
    end
    for _, group in ipairs(IG.GetOrderedGroups()) do
        local module = MODULE_GROUPS[group.key]
        -- LOCKED is not switched on for everything at once: this list has its own answer.
        local reaches = ownBags or ASIDE_MODULE_GROUPS[group.key] == true
        local available = not module or (reaches and (group.key == "LOCKED"
            and IG.LockedSeparated(invKey) or sv[module] == true))
        if available and not used[group.key] and not NEVER_EMPTY_GROUPS[group.key]
            and not (BACKPACK_ONLY_GROUPS[group.key] and not isBackpack) then
            local path = { IG.MakeGroupNode(group.key) }
            path.isEmptyGroup = true
            items[#items + 1] = { igEmpty = true, igSortName = "", igPath = path, data = {} }
        end
    end
end

-- A stack that grew gets a second row under NEW carrying only the new pieces; the stack itself
-- stays in its usual group with its full count.
local function CollectPartialNewEntries(items)
    local result = {}
    -- The second row exists only to stand under NEW; with no NEW there is nothing for it to
    -- stand under, and the stack is already drawn once with its full count.
    if not sv.newEnabled then return result end
    if not next(partialNew) then return result end
    local root = IG.MakeGroupNode("NEW")
    for _, entry in ipairs(items) do
        local data = entry.data
        local uniqueId = data.uniqueId and data.bagId == BAG_BACKPACK and Id64ToString(data.uniqueId)
        local added = uniqueId and partialNew[uniqueId]
        if added and not LastRunTakesOver(data, uniqueId) and not KeptOutOfNew(data) then
            result[#result + 1] = {
                data = setmetatable({ stackCount = added, igPartialNew = true }, { __index = data }),
                path = { root },
            }
        end
    end
    return result
end

-- A piece you have said you will sell, or break down, is still whatever it was. It stands in
-- the category it belongs to as well -- behind a grey pane with where it has gone written
-- across it -- so the list goes on telling you what you own while saying what you decided.
--
-- A second row for the same piece, the way the modules repeat one, which means everything that
-- can be asked of its own row can be asked of this one too: right click it here and the line
-- that takes it back out is the one you get.
-- Kept per list, from the button on that window's bottom bar: the bank can go on showing them
-- while the bag is done looking at them. The setting on the settings page decides what a window
-- does before it has been asked, and stops reaching it once it has.
--
-- GARBAGE is the one category that never gets its copy back, whatever the button says. It is
-- not a place you keep anything: what stands there is what you have not decided about yet, and
-- the moment you send a piece to SELL you have decided. A stood-down row saying the thing you
-- are done with is still there is the one reminder nobody wants, and it is answered anyway by
-- the row in SELL. So the copy is not made, which is also why nothing below has to be told
-- about it: what is never in the list is not counted in a bracket, not split into a heading,
-- and not offered to the menu that asks what is left to do here.
local ASIDE_NEVER_AT_HOME = { GARBAGE = true }

-- Only a set keeps a stood-down copy. A setless piece (World, Consumables and the like) sent
-- somewhere has no set to be missing from, so it simply goes where it was sent.
local function PathHasSet(path)
    for _, node in ipairs(path) do
        if node.isSet then return true end
    end
    return false
end

local function CollectSetAsideEntries(items, invKey)
    local result = {}
    if not IG.MovedShown(invKey) then return result end
    for _, entry in ipairs(items) do
        local data = entry.data
        -- The game's own rows only. A module's copy of a piece is already a second row, and
        -- a third saying the same thing about the same piece is noise.
        if rawget(data, "bagId") and not entry.igEmpty then
            local home, key = IG.ClassifyAsideHome(data, entry.igNew, entry.igLocked)
            if home and not ASIDE_NEVER_AT_HOME[home[1] and home[1].id] and PathHasSet(home) then
                result[#result + 1] = {
                    data = setmetatable({ igSetAside = key }, { __index = data }),
                    path = home,
                }
            end
        end
    end
    return result
end

-- Frames: every header opens a frame (its top edge); rows inside draw the sides of every
-- frame they're in; a frame's bottom edge goes on the last row before it closes. The settings
-- preview builds a list of its own and runs it through here, so its outlines are the real ones.
-- Where a heading is drawn: one level up when flush with its parent's rows, one more under an
-- open Chips/Tiles button. Nil when it is drawn at its own level.
local function ChipDrawDepth(depth, node, chipShift)
    local drawn = depth - (node.flush and depth > 1 and 1 or 0)
    if drawn - chipShift >= 2 or (drawn - chipShift == 1 and drawn > 1 and not node.isSet) then
        drawn = drawn - chipShift
    end
    if drawn == depth then return nil end
    return drawn
end

local function AssignFrames(scrollData)
    local openFrames = {}
    local previousFrames
    -- The open button of a Chips/Tiles row: its block is framed in its colour, as its heading
    -- would have framed it, the top edge on the first row under the buttons.
    local stripTop = false
    local function CloseFrames(fromDepth)
        while #openFrames > 0 and openFrames[#openFrames].depth >= fromDepth do
            local closing = table.remove(openFrames)
            for _, frame in ipairs(previousFrames or {}) do
                if frame.depth == closing.depth then frame.bottom = true end
            end
        end
    end
    local function CopyOpenFrames()
        local frames = {}
        for index, open in ipairs(openFrames) do
            -- An open button's own frame gives way to a sub-category drawn on its level.
            local nextOpen = openFrames[index + 1]
            local yields = open.chip and nextOpen and (nextOpen.drawDepth or nextOpen.depth) == 1
            if not yields then
            local i = #frames + 1
            -- Open sub-groups that contain other groups keep their thick strip running down.
            frames[i] = {
                -- Where it is drawn, which is not always the level it was opened at: a heading
                -- standing flush with its parent's rows takes its frame with it. Opening and
                -- closing still runs on the real depth, above.
                depth = open.drawDepth or open.depth,
                color = open.color, showBar = open.depth > 1 and not open.isLeaf,
                -- An open set gets a bolder outline around it.
                bold = open.isLeaf and open.expanded and open.depth > 1,
                style = open.style,
                -- Under an open button a spacer still speaks of real levels.
                spacerDepth = open.chipShifted and open.depth or nil,
            }
            end
        end
        return frames
    end
    for _, row in ipairs(scrollData) do
        local data = row.data
        if row.typeId == SPACER_TYPE or row.typeId == SECTION_TYPE or (data and data.isModuleStrip) then
            CloseFrames(1)
            previousFrames = nil
            stripTop = false
            local open = data and data.isModuleStrip and data.railed and data.openChip
            if open then
                openFrames[1] = { depth = 1, color = open.color, expanded = true, chip = true }
                stripTop = true
            end
        elseif data and data.isStripHeading then
            -- The open button's light heading: framed by nothing, and it leaves the block's top
            -- edge to the first real row under it.
            data.igFrames = nil
        elseif row.typeId == SUB_SPACER_TYPE then
            -- Groups deeper than the sibling level end on their last row; the sibling-level group
            -- that just finished ends a few pixels into this spacer, leaving a gap below its frame.
            -- Groups deeper than the sibling level end on the last row, one step above each other,
            -- leaving the usual gap above the sibling-level group's line in this spacer.
            for _, frame in ipairs(previousFrames or {}) do
                local level = frame.spacerDepth or frame.depth
                if level > data.depth then frame.closesBeforeSpacer = level - data.depth - 1 end
            end
            CloseFrames(data.depth + 1)
            local frames = CopyOpenFrames()
            for _, frame in ipairs(frames) do
                if (frame.spacerDepth or frame.depth) >= data.depth then
                    frame.bottom = true
                    frame.bottomInSpacer = true
                end
            end
            while #openFrames > 0 and openFrames[#openFrames].depth >= data.depth do
                table.remove(openFrames)
            end
            data.igFrames = frames
            previousFrames = nil
        elseif row.typeId == SUB_FOOT_TYPE then
            -- Whatever was still open inside the group ends on the row above; the foot belongs to
            -- the group itself and is its last row.
            CloseFrames(data.depth + 1)
            local frames = CopyOpenFrames()
            if frames[#frames] then frames[#frames].foot = true end
            data.igFrames = frames
            previousFrames = frames
        else
            local isHeader = IS_HEADER_TYPE[row.typeId]
            if isHeader then
                CloseFrames(data.depth)
                openFrames[#openFrames + 1] = {
                    depth = data.depth, drawDepth = data.drawDepth, color = data.color,
                    chipShifted = data.chipShifted,
                    isLeaf = data.isLeaf, expanded = data.expanded, style = data.style,
                }
            end
            local frames = CopyOpenFrames()
            if isHeader then frames[#frames].top = true end
            -- The first row under the buttons is inside the open block, not its heading: it
            -- carries the top edge but keeps the fill and left strip (stripTop, ApplyFrames).
            if stripTop and frames[1] and openFrames[1] and openFrames[1].chip
                and (openFrames[2] == nil or (openFrames[2].drawDepth or openFrames[2].depth) ~= 1) then
                frames[1].top = true
                frames[1].stripTop = true
            end
            stripTop = false
            data.igFrames = frames
            previousFrames = frames
        end
    end
    CloseFrames(1)
end

-- Which bag slots ended up in each of the categories that act on the whole of themselves. One
-- entry per real slot: the same piece stands in several groups at once -- a module's copy of it,
-- the grey one left where it was sent from -- and every one of those repeats reads its slot
-- through a metatable, so a raw read answers for the game's own row alone. Without that a piece
-- could be counted twice, or a row belonging to another category could be taken for this one.
--
-- The piles are written down in the same pass, and read their slot the other way round. A pile
-- is drawn from the run's own copies of the pieces, and those copies are exactly the repeats the
-- raw read above exists to skip -- asked rawly, a pile would always come back empty. So the slot
-- is read through the copy, and a piece is written down once per pile instead: a piece belongs
-- to one run and falls in one pile of it, so the same slot cannot arrive twice under one
-- heading, and the guard says so rather than trusting it.
local function NoteActionGroups(invKey, items)
    local members = {}
    local junked, junkSeen = {}, {}
    for _, entry in ipairs(items) do
        -- The category, whether or not it stands inside DISPOSAL.
        local key = CategoryKey(entry.igPath)
        if key and ACTION_GROUPS[key] and not entry.igEmpty then
            local bagId = rawget(entry.data, "bagId")
            local slotIndex = rawget(entry.data, "slotIndex")
            if bagId and slotIndex then
                members[key] = members[key] or {}
                local list = members[key]
                list[#list + 1] = { bagId = bagId, slotIndex = slotIndex }
            end
        end
        -- Every heading the piece is standing under inside JUNK, not the category alone: a
        -- JUNK left as one flat list has no sub-heading to ask, and a split one is asked about
        -- the heading that was clicked. The slot is read through the copy the way a pile's is,
        -- since JUNK builds its rows over the bag's own slot data and the raw read above would
        -- answer nothing for every one of them.
        if key == JUNK_ACTION_KEY and not entry.igEmpty then
            local bagId, slotIndex = entry.data.bagId, entry.data.slotIndex
            if bagId and slotIndex then
                local nodeKey = nil
                for _, node in ipairs(entry.igPath) do
                    nodeKey = nodeKey and (nodeKey .. "/" .. node.id) or node.id
                    local mark = nodeKey .. "\t" .. bagId .. "\t" .. slotIndex
                    if not junkSeen[mark] then
                        junkSeen[mark] = true
                        junked[nodeKey] = junked[nodeKey] or {}
                        local list = junked[nodeKey]
                        list[#list + 1] = { bagId = bagId, slotIndex = slotIndex }
                    end
                end
            end
        end
    end
    groupMembers[invKey] = members
    junkMembers[invKey] = junked
end

-- A piece to look out for while the next list is built, and where that build put it. The answer
-- cannot be worked out from outside: what a row is under is decided in the pass below, and a row
-- inside a closed group is not in the list afterwards to be asked.
local watched, watchedPath, watchedType = nil, nil, nil

-- What the last build of the bag at a merchant or a fence stood its headings on, for the sales
-- that follow to be read against (DropSoldRows): counts[heading key] = how many rows stand
-- under that heading, closed ones and the modules' copies included, and bySlot[bag:slot] = the
-- heading keys of every row that slot is drawn as. Nil after any other build.
local builtUnder

-- What is being searched for in this list, in lower case; "" while nothing is. The bag, the
-- bank and the chests are asked through the game's own text search; a crafting bench has no
-- search box of the game's at all, so there the answer comes from the box this addon builds
-- over the sort header (Craft.lua).
local function ListSearchText(inventory, inventoryType)
    if IG.IsCraftType(inventoryType) then
        return IG.CraftSearchText and IG.CraftSearchText(inventoryType) or ""
    end
    return zo_strlower(inventory.currentContext
        and TEXT_SEARCH_MANAGER:GetSearchText(inventory.currentContext) or "")
end

local function BuildGroupedList(inventory, inventoryType, mode)
    local scrollData = ZO_ScrollList_GetDataList(inventory.listView)
    local isBackpack = inventoryType == INVENTORY_BACKPACK
    local trading = mode == "trading"
    local minimal = mode == "minimal"
    local merchantSell = isBackpack and AtMerchantSell()
    -- Both flat layouts name their categories themselves, so each keeps one memory of its own
    -- rather than one per list. That is about what is open in the list and nothing else.
    local invKey = (trading and "trading") or (minimal and "minimal") or INVENTORY_KEYS[inventoryType]
    -- The window, whatever layout it is wearing at the moment. The buttons on that window's own
    -- bottom bar are the ones that set these two, and they know it by this name; asking under
    -- the layout's name instead meant that in the flat layouts the button wrote one answer and
    -- the list read another, and the count of what was held back was written where nothing
    -- would ever read it.
    local windowKey = INVENTORY_KEYS[inventoryType]

    -- What this list does with the pieces you locked is this window's own answer: leave them
    -- where they belong, gather them at its foot, or keep them out of it altogether.
    local lockedOn = IG.LockedSeparated(windowKey)
    local hideLocked = IG.LockedHidden(windowKey)
    local hiddenLocked = 0
    -- The row the reveal is looking out for, held until every pass that can move it has run.
    local watchedEntry

    -- Classify and sort the raw item entries.
    local items = {}
    for _, entry in ipairs(scrollData) do
        -- Dropped here rather than filtered out of a category later, so that it is out of every
        -- category at once: the modules below read this same list, and a piece kept out of the
        -- bag has no business turning up under ARMORY or UNCOLLECTED either. Counted on the
        -- way past, because the button that hid them says how many that was.
        if not IS_OWN_ROW_TYPE[entry.typeId] and hideLocked and IG.IsSlotLocked(entry.data) then
            hiddenLocked = hiddenLocked + 1
        elseif not IS_OWN_ROW_TYPE[entry.typeId] then
            entry.igSortName = zo_strlower(entry.data.name or "")
            if trading then
                entry.igPath = IG.GetTradingPath(entry.data)
                entry.data.igCollectable = IG.IsUncollectedPiece(entry.data) or nil
            elseif minimal then
                entry.igPath = IG.GetMinimalPath(entry.data)
                entry.data.igCollectable = nil
            else
                local isNew = isBackpack and IsNewSlot(entry.data)
                if isNew and LastRunTakesOver(entry.data) then isNew = false end
                if isNew and KeptOutOfNew(entry.data) then isNew = false end
                entry.igNew = isNew
                entry.igPath = IG.ClassifySlot(entry.data, isNew, lockedOn)
                -- A setup piece keeps its slot's body order (Setups.lua); nil everywhere else.
                entry.igSlotRank = entry.igPath and entry.igPath.slotRank
                entry.igLocked = lockedOn
                -- Selling to a merchant or a fence in the bag's own layout still warns of a set
                -- piece not yet collected, as the flat layout does.
                entry.data.igCollectable = (merchantSell and IG.IsUncollectedPiece
                    and IG.IsUncollectedPiece(entry.data)) or nil
            end
            if watched and entry.data.bagId == watched.bagId
                and entry.data.slotIndex == watched.slotIndex then
                -- The row rather than the path it has at this moment: the split below can hand
                -- it a heading that was not there when it was classified, and the reveal has to
                -- scroll to where the row actually ended up.
                watchedEntry, watchedType = entry, inventoryType
            end
            items[#items + 1] = entry
        end
    end
    -- Said straight away, while the number is in hand: the plate under the button on the bar is
    -- the only thing left saying those pieces are there at all.
    if IG.NoteLockedHidden then IG.NoteLockedHidden(windowKey, hiddenLocked) end
    -- Optional modules add extra rows: ARMORY and RECENT LOOT repeat real items, HOME CONTAINERS
    -- shows saved ones.
    local searchText = ListSearchText(inventory, inventoryType)
    local extras = {}
    -- The flat layouts list the items and nothing else: no modules, no NEW, no empty groups.
    local flat = trading or minimal
    local ownBags = not flat and (inventoryType == INVENTORY_BACKPACK or inventoryType == INVENTORY_BANK)
    for _, list in ipairs(ownBags and {
        -- Worn pieces, in the bag window only (Equipped.lua).
        IG.CollectEquippedEntries(inventory, inventoryType, searchText, items),
        IG.CollectArmoryEntries(inventory, inventoryType, items, searchText),
        IG.CollectLastRunEntries(inventory, inventoryType, items),
        IG.CollectBindOnEquipEntries(inventory, inventoryType, items),
        IG.CollectJunkEntries(inventory, inventoryType, items, searchText),
        IG.CollectHomeEntries(inventory, inventoryType, searchText, STORED_ITEM_TYPE),
        IG.CollectSetupEntries and IG.CollectSetupEntries(inventory, inventoryType, items, searchText, STORED_ITEM_TYPE) or {},
    } or {}) do
        for _, extra in ipairs(list) do extras[#extras + 1] = extra end
    end
    if isBackpack and not flat then
        for _, extra in ipairs(CollectPartialNewEntries(items)) do extras[#extras + 1] = extra end
    end
    if ownBags then
        for _, extra in ipairs(CollectSetAsideEntries(items, windowKey)) do extras[#extras + 1] = extra end
    end
    -- A bench repeats what was made at it this visit, at the top (JustCrafted.lua).
    if IG.IsCraftType(inventoryType) and not flat and IG.CollectJustCraftedEntries then
        for _, extra in ipairs(IG.CollectJustCraftedEntries(items)) do extras[#extras + 1] = extra end
    end
    -- A piece of an equipment setup is shown by its setup, not by the modules (Setups.lua).
    if IG.FilterSetupExtras then extras = IG.FilterSetupExtras(extras) end
    -- A bench lists what the game put there and nothing else. No pass above adds rows to one
    -- (ownBags and isBackpack are both false there), and this is the second guard should one
    -- ever start to: a worn piece never, and at deconstruction only what can be taken apart.
    if IG.IsCraftType(inventoryType) then
        local kept = {}
        for _, extra in ipairs(extras) do
            local data = extra.data
            local bagId, slotIndex = data and data.bagId, data and data.slotIndex
            local ok = bagId ~= nil and slotIndex ~= nil and bagId ~= BAG_WORN
            if ok and inventoryType == IG.CRAFT_INVENTORY_TYPE then
                ok = CanItemBeDeconstructed ~= nil and CanItemBeDeconstructed(bagId, slotIndex) == true
            end
            if ok then kept[#kept + 1] = extra end
        end
        extras = kept
    end
    for _, extra in ipairs(extras) do
        local entry = ZO_ScrollList_CreateDataEntry(extra.typeId or inventory.listDataType, extra.data)
        entry.igSortName = zo_strlower(extra.data.name or "")
        entry.igPath = extra.path
        -- A fixed place inside its heading, beating the sort order (EQUIPPED: slot order).
        entry.igSlotRank = extra.slotRank
        items[#items + 1] = entry
    end
    -- A category with no headings of its own, grown long enough to want some, is broken into
    -- what its pieces are (Classify.lua). Asked before the empty categories are added, which
    -- carry no rows and would only have to be stepped over, and before the sort, which is what
    -- puts the new headings in their places. The flat layouts are left out: they have one level
    -- by definition, and a heading inside one would be the very thing they were picked to avoid.
    local splittable = not flat and IG.SplitFlatCategories(items) or {}
    if watchedEntry then watchedPath = watchedEntry.igPath end
    if sv.showEmptyGroups and not flat then AddEmptyGroups(items, ownBags, invKey, isBackpack) end
    -- After the split (which reads a category at the top of its path) and the empty groups.
    if not flat then
        NestDisposal(items)
        if watchedEntry then watchedPath = watchedEntry.igPath end
    end
    -- A bench's lead (DECONSTRUCT at deconstruction) first, and opened as a visit starts. After
    -- the nesting, which is what puts it inside DISPOSAL, and before anything reads what is open.
    local leadOrder = not flat and LeadFirst(items, inventory.lead, invKey, searchText) or nil
    NoteActionGroups(invKey, items)
    if trading and IG.PrepareTradingSort then IG.PrepareTradingSort() end
    table.sort(items, (trading and IG.CompareTradingEntries)
        or (minimal and IG.CompareMinimalEntries) or leadOrder or CompareEntries)

    -- Two numbers per node. The bracket after a name is how many rows open directly under it --
    -- its sub-categories, or its items where it has none -- because that is what opening it
    -- shows you. The other is everything in its whole tree, for the second bracket that can be
    -- switched on beside the first.
    -- setKids: how many of a node's own children are set headers, so the number beside its
    -- name can say what it is counting.
    -- hasSets: whether a category holds sets anywhere below it, not only as its own children.
    -- PVE SETS keeps its sets a level down, under DUNGEON and TRIAL, and the right click that
    -- says how sets are drawn is on the category, so the question has to reach the whole tree.
    local totals, children, counted, setKids, hasSets = {}, {}, {}, {}, {}
    -- The real categories standing under LOCKED in this build (set keys above, fed to the
    -- module-level lockedCategoryKeys at the end of this function).
    local lockedCategories = {}
    -- And, per category, whether everything standing in it is a piece you sent somewhere else.
    -- sentAway holds where they went while that is one place and true once it is several;
    -- ownRows remembers a category that still has a piece of its own, which is what tells an
    -- emptied category from a category that was always empty.
    local sentAway, ownRows = {}, {}
    -- At a merchant or a fence, what each heading stands on (builtUnder, above). A count of its
    -- own rather than totals, which the rows below are handed and which a sale must not touch.
    local under = merchantSell and { counts = {}, bySlot = {} } or nil
    for _, entry in ipairs(items) do
        if not entry.igEmpty then
            local path = entry.igPath
            -- A module's copy reads its slot through to the game's row, so both land on one slot.
            local slotHeadings
            if under then
                local data = entry.data
                local bagId, slotIndex = data and data.bagId, data and data.slotIndex
                if bagId ~= nil and slotIndex ~= nil then
                    local slot = bagId .. ":" .. slotIndex
                    slotHeadings = under.bySlot[slot] or {}
                    under.bySlot[slot] = slotHeadings
                end
            end
            if path[1] then
                local top = CategoryKey(path)
                local moved = entry.data.igSetAside
                if moved then
                    local seen = sentAway[top]
                    sentAway[top] = (seen == nil or seen == moved) and moved or true
                else
                    ownRows[top] = true
                end
            end
            if path[1] then
                for depth = 1, #path do
                    if path[depth].isSet then
                        hasSets[CategoryKey(path)] = true
                        hasSets[SetViewKey(path)] = true
                        break
                    end
                end
                -- A locked piece's real category -- DUNGEON, ARENA, NONSET, whatever it would
                -- stand under on its own -- is the second step of its path (Classify.lua: LOCKED,
                -- then that category, then its set if it has one). Written down for LOCKED's
                -- "Color All Categories...", the same way lockedSets is for its sets.
                if path[1].id == "LOCKED" and path[2] then
                    lockedCategories[path[2].id] = true
                end
            end
            -- NodeKey walks the path from the start every time, so each level's key is kept and
            -- the one above it is the key the level before handed down.
            local parent
            for depth = 1, #path do
                local key = NodeKey(path, depth)
                totals[key] = (totals[key] or 0) + 1
                if under then
                    under.counts[key] = (under.counts[key] or 0) + 1
                    if slotHeadings then slotHeadings[#slotHeadings + 1] = key end
                end
                -- However many items are inside it, a node is one row under its parent.
                if parent and not counted[key] then
                    counted[key] = true
                    children[parent] = (children[parent] or 0) + 1
                    if path[depth].isSet then setKids[parent] = (setKids[parent] or 0) + 1 end
                end
                parent = key
            end
            -- And the item itself is a row under the node its path ends at.
            if parent then children[parent] = (children[parent] or 0) + 1 end
        end
    end
    builtUnder = under

    -- A category is emptied when it holds something and none of it is its own. An empty one is
    -- not: nothing was decided about it, there is simply nothing there, and saying "all moved"
    -- over nothing at all would be saying it about every category you do not use.
    local allMoved = {}
    for key, moved in pairs(sentAway) do
        if not ownRows[key] then allMoved[key] = { target = moved ~= true and moved or nil } end
    end

    -- Per-set summaries (pieces owned, uncollected count) for the set headers.
    local setSummaries = {}
    local wornSlots = IG.GetWornSetSlots()
    -- The sets under LOCKED that can be opened or shut: with this list's sets drawn as plain
    -- rules (dividers) there is nothing to open, so none are noted.
    local lockedSets = {}
    lockedSetKeys[invKey] = lockedSets
    lockedCategoryKeys[invKey] = lockedCategories
    for _, entry in ipairs(items) do
        local path = entry.igPath
        if path[#path].isSet then
            local key = NodeKey(path, #path)
            if not setSummaries[key] and #path > 1 and path[1].id == "LOCKED"
                and not SetsAsDividersFor(windowKey, path) then
                lockedSets[#lockedSets + 1] = key
            end
            setSummaries[key] = setSummaries[key] or IG.NewSetSummary(wornSlots[path[#path].setId])
            IG.AddToSetSummary(setSummaries[key], entry.data)
        end
    end

    -- Rebuild the scroll data: a header whenever a node starts, items only under expanded nodes.
    -- A search opens everything at first, but into its own table (NoteSearch), so clicks still work.
    NoteSearch(invKey, searchText ~= "" and searchText or nil, inventory.listView)
    ZO_ClearNumericallyIndexedTable(scrollData)
    local previousKeys = {}
    -- A shut section keeps its heading and nothing else; the heading counts what it is hiding.
    -- Asked here, before the scan below reads it: declared further down it was a nil global here,
    -- so no section was ever seen shut and a click changed nothing.
    local sections = not flat and IG.SectionsOn()
    -- Every heading also says how many items stand under it, shut or open: one count per stack,
    -- and a piece a module shows a copy of is counted once per section (its bag slot).
    local sectionShut, sectionCount, sectionSeen = {}, {}, {}
    -- [section] = the one category under it, or false once a second one turns up.
    local sectionOnly = {}
    if sections then
        for _, entry in ipairs(items) do
            local top = entry.igPath and entry.igPath[1]
            local section = top and IG.GetGroupSection(top.id)
            if section then
                local only = sectionOnly[section]
                if only == nil then sectionOnly[section] = top.id
                elseif only ~= top.id then sectionOnly[section] = false end
            end
            if section and sectionShut[section] == nil then
                sectionShut[section] = IsSectionShut(invKey, section)
            end
            if section and not entry.igEmpty then
                local data = entry.data
                local bagId, slotIndex = data and data.bagId, data and data.slotIndex
                local seen = sectionSeen[section] or {}
                sectionSeen[section] = seen
                local id = bagId and slotIndex and (bagId .. ":" .. slotIndex) or entry
                if not seen[id] then
                    seen[id] = true
                    sectionCount[section] = (sectionCount[section] or 0) + 1
                end
            end
        end
    end
    -- Section display (ModuleStrip.lua): under Chips or Tiles the categories of a section give
    -- up their heading rows to one row of buttons, and only the one picked is opened.
    -- A section that is one category of its own name (LOCKED) gets the categories inside it as
    -- its buttons (sectionOnly), the way it gets them as its plates under Rows (headless, below).
    local strip = sections and IG.ModuleStripPlan
        and IG.ModuleStripPlan(items, invKey, inventoryType, children, totals, sectionOnly, NodeKey)
    local openHeaders = {} -- [depth] = data of the most recent header at that depth
    -- Open sub-groups that end before a header of fromDepth get their foot row, deepest first.
    local function CloseFeet(fromDepth)
        for depth = MAX_DEPTH, zo_max(fromDepth, 2), -1 do
            local header = openHeaders[depth]
            -- A Chips/Tiles button at depth 2 (inside LOCKED) ends like one at depth 1: no foot.
            if header and header.expanded and not header.isLeaf and not header.hasFoot
                and not header.chipButton then
                header.hasFoot = true
                scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(SUB_FOOT_TYPE, { depth = depth })
            end
        end
    end
    -- Headings are the tree's own; the flat layouts name their categories themselves (sections, above).
    local shownSection
    -- The gap before a new category. A closed strip of buttons is its own gap: its padding below
    -- the last line is the same as above the first, so a spacer after it would make the space
    -- under the strip larger than the space over it. Once a button is open, its block ends like
    -- any category and takes the spacer as usual.
    local function AddCategoryGap()
        local last = scrollData[#scrollData]
        if not last then return end
        if last.data and last.data.isModuleStrip then return end
        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(SPACER_TYPE, {})
    end
    -- How the sets under a category are drawn is that category's answer in this window, and
    -- only where it has none is it the Don't Group Sets switch. Asked per category rather than
    -- once for the list, and under the window's own name so that the bag and the bank each keep
    -- their own -- the same name the locked and the sent-aside answers are kept under.
    --
    -- This and the split decision never meet: what is split is a category with no headings of
    -- its own, and a category holding sets has them already. If that ever stops being true, the
    -- split decision goes first -- it says what headings exist, this only says how the set ones
    -- among them are drawn.
    local function DividersFor(path)
        if flat or not path[1] then return false end
        return SetsAsDividersFor(windowKey, path)
    end
    for _, entry in ipairs(items) do
        local path = entry.igPath
        local setRules = DividersFor(path)
        local visible = true
        local shutSection = sections and path[1] and IG.GetGroupSection(path[1].id)
        if not (shutSection and sectionShut[shutSection]) then shutSection = nil end
        if shutSection then
            -- Its heading once, then nothing of it. The keys are forgotten so the category
            -- after it starts afresh.
            if shutSection ~= shownSection then
                CloseFeet(2)
                AddCategoryGap()
                scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(SECTION_TYPE,
                    { label = shutSection, rowHeight = metrics.section, isSection = true, shut = true,
                      count = sectionCount[shutSection] or 0, invKey = invKey, inventoryType = inventoryType })
                shownSection = shutSection
            end
            for depth = 1, MAX_DEPTH do previousKeys[depth] = nil; openHeaders[depth] = nil end
            visible = false
        end
        -- Under an open Chips/Tiles button the category heading is the light one under the
        -- buttons, so everything below it is drawn one level shallower: its sub-categories
        -- line up with the buttons and with top-level plates elsewhere.
        -- The button is the top category, or the category inside a one-category section (LOCKED,
        -- whose own level is not drawn): either way its rows move up one level.
        local chipShift = 0
        if strip then
            for depth = 1, zo_min(2, #path) do
                local chip = strip.byKey[NodeKey(path, depth)]
                if chip and chip.depth == depth then chipShift = 1 end
            end
        end
        for depth = 1, shutSection and 0 or #path do
            local key = NodeKey(path, depth)
            -- A set drawn as a rule has no way to be shut and is never asked.
            local expanded = path[depth].isRule
                or (setRules and path[depth].isSet) or IsExpanded(invKey, key)
            local stripChip = strip and strip.byKey[key]
            if stripChip and stripChip.depth ~= depth then stripChip = nil end
            local stripRow = stripChip and strip.sections[stripChip.section]
            if stripRow then expanded = stripRow.openKey == key end
            -- A section that holds one category of its own name (LOCKED) says it once: the
            -- divider stands, the plate under it is not drawn, and the divider does the shutting.
            local headless = depth == 1 and sections and not stripChip
                and IG.GetGroupSection(path[1].id) == path[1].id and sectionOnly[path[1].id] == path[1].id
            if headless then expanded = true end
            if depth == 1 and key == IG.DISPOSAL_KEY then NoteDisposalOpen(invKey, expanded) end
            if previousKeys[depth] ~= key then
                previousKeys[depth] = key
                for deeper = depth + 1, MAX_DEPTH do previousKeys[deeper] = nil end
                if visible then
                    local node = path[depth]
                    CloseFeet(depth)
                    if depth == 1 then
                        if not (stripRow and stripRow.shown) then AddCategoryGap() end
                        -- A heading wherever the run changes hands, the first one included.
                        local section = sections and IG.GetGroupSection(node.id)
                        if section and section ~= shownSection then
                            scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(SECTION_TYPE,
                                { label = section, rowHeight = metrics.section, isSection = true,
                                  count = sectionCount[section] or 0,
                                  invKey = invKey, inventoryType = inventoryType })
                            shownSection = section
                        end
                    elseif depth > 1 and not stripChip and openHeaders[depth] and openHeaders[depth].expanded then
                        -- The previous sibling was open: leave a little room after its frame.
                        -- Buttons have none: the open one's block ends the way a top one's does.
                        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(SUB_SPACER_TYPE, { depth = depth })
                    end
                    -- The row of buttons, where the first of them is passed: right under the
                    -- section divider (inside LOCKED the first button is a level down, under
                    -- the plate that is not drawn).
                    if stripRow and not stripRow.shown then
                        scrollData[#scrollData + 1] = stripRow.entry
                        stripRow.shown = true
                    end
                    local typeId, rowHeight = HEADER_TYPES[depth], metrics.headers[depth]
                    if trading then
                        typeId, rowHeight = TRADE_HEADER_TYPE, metrics.headers[TRADE_HEADER_LOOK]
                    elseif depth == 1 and TALL_HEADER_KEYS[key] then
                        typeId, rowHeight = TALL_HEADER_TYPE, zo_floor(metrics.headers[1] * TALL_HEADER_SCALE + 0.5)
                    end
                    -- A line rather than a button: there is no shutting one, whatever else is
                    -- true of it.
                    local asRule = node.isRule or (node.isSet and setRules)
                    if asRule then
                        typeId, rowHeight = SET_RULE_TYPE, metrics.setRule
                    elseif node.isSet then
                        if sv.showPieces then
                            typeId, rowHeight = SET_TYPE_WITH_PIECES, SetRowHeight()
                        else
                            typeId, rowHeight = SET_TYPE, SetRowHeight()
                        end
                    end
                    -- A colour painted on this heading by hand beats the one it was born with,
                    -- and it is read here rather than where the node was made: every heading on
                    -- screen comes past this line, whoever built it, and the key it is kept
                    -- under is the very key this row is named by. A single colour also puts an
                    -- end to a set's role blend -- the player asked for one colour, not three.
                    -- A category inside DISPOSAL is a category heading drawn one level down.
                    local disposalSub = depth == 2 and path[1].id == IG.DISPOSAL_KEY
                        and IG.DISPOSAL_MEMBERS[node.id] == true
                    -- A category under LOCKED is a category heading drawn one level down too --
                    -- the same category that stands at the top level anywhere else, so its colour
                    -- is the shared group colour, the same as every other category's.
                    local lockedSub = depth == 2 and path[1].id == "LOCKED"
                    local catLevel = depth == 1 or disposalSub or lockedSub
                    -- Hand-painted sets and sub-headings stay cream while the colours are off.
                    local painted = IG.ColorsOn() and (node.isSet and IG.GetManualSetColor(node.setId)
                        or (depth > 1 and not disposalSub and not lockedSub and not node.isSet
                            and IG.GetManualSubColor(key)))
                    local headerColor, headerColors = node.color, node.colors
                    if painted then headerColor, headerColors = IG.Adapt(painted), nil end
                    local headerData = {
                        key = key,
                        invKey = invKey,
                        compact = trading,
                        rowHeight = rowHeight,
                        summary = node.isSet and setSummaries[key] or nil,
                        slotFilter = node.isSet and IG.GetSetSlotFilter(path) or nil,
                        label = node.label,
                        color = headerColor,
                        -- Sets that serve more than one role carry a color per role.
                        colors = headerColors,
                        wide = node.wide,
                        icon = node.icon,
                        iconKey = node.iconKey,
                        location = node.location,
                        subtitle = node.subtitle,
                        badge = node.badge,
                        badgeOnlyWhenExpanded = node.badgeOnlyWhenExpanded,
                        isSet = node.isSet,
                        -- A sub-heading that answers a right click of its own.
                        menu = node.menu,
                        menuRun = node.menuRun,
                        -- Which of a place's piles this heading is, so the menu hands back that
                        -- one rather than whichever pile was asked about first.
                        menuPile = node.menuPile,
                        -- A line rather than a button, and a bare one: what the rule carries for
                        -- a set is about the set, and a place has none of it.
                        isRule = node.isRule,
                        bareRule = node.bareRule,
                        -- Drawn where its parent's own rows are drawn. Its place in the tree is
                        -- unchanged -- this is about the left edge and nothing else.
                        -- An open button's rows move up a level too (chipShift), except a set
                        -- straight under it: a set's indent has room for its role markers.
                        drawDepth = ChipDrawDepth(depth, node, chipShift),
                        chipShifted = chipShift == 1 or nil,
                        -- Stands as a Chips/Tiles button rather than a row (CloseFeet).
                        chipButton = stripChip and true or nil,
                        -- Drawn as one of the rows it stands over rather than as a heading
                        -- over them: same column, same lettering, only the +/- in front.
                        itemLine = node.itemLine,
                        -- A mark that means something of its own rather than naming the group.
                        iconColor = node.iconColor,
                        keepIconColors = node.keepIconColors,
                        setId = node.setId,
                        isLeaf = depth == #path and not path.isEmptyGroup,
                        -- A node can count something other than its rows (RECENT LOOT counts runs).
                        count = node.fixedCount or children[key] or 0,
                        totalItems = totals[key] or 0,
                        -- What the first number is counting, when it is not simply the rows.
                        setCount = setKids[key],
                        countLabel = node.countLabel,
                        -- The tail of the label written in a colour of its own (setup names).
                        labelName = node.labelName,
                        nameColor = node.nameColor,
                        countsItems = node.countsItems,
                        totalOnly = node.totalOnly,
                        disposalSub = disposalSub or nil,
                        lockedSub = lockedSub or nil,
                        -- The plain id the shared group colour (and IG.GROUP_BY_KEY) knows this
                        -- category by -- not "key" above, which is "LOCKED/<id>" (NodeKey) here.
                        lockedGroupKey = lockedSub and node.id or nil,
                        depth = depth,
                        -- A category with no headings of its own, which can therefore be asked
                        -- to make some. Only known while the list is being built, so it is
                        -- written onto the heading for the right click menu to read later.
                        canSplit = catLevel and splittable[key] or nil,
                        -- A category with sets somewhere under it, which can therefore be asked
                        -- how they are to be drawn. Known while the list is built and written
                        -- onto the heading for the right click menu, the same as the line above.
                        -- A category inside LOCKED is a category too, for this one question.
                        hasSets = (catLevel or (depth == 2 and path[1].id == "LOCKED"))
                            and hasSets[key] or nil,
                        -- Nothing left under it but pieces you sent elsewhere, and where they
                        -- went while that is one place. The heading says so and is struck through.
                        allMoved = catLevel and allMoved[key] or nil,
                        expanded = expanded,
                        inventoryType = inventoryType,
                        style = catLevel and HEADER_STYLES[key] or nil,
                    }
                    -- A module under Chips or Tiles is its button instead; the heading it would
                    -- have been is kept on the button for its right click.
                    if stripChip then
                        stripChip.header = headerData
                        -- The open one is named once, straight under the buttons (ModuleStrip.lua).
                        if expanded and IG.ModuleStripHeading then
                            scrollData[#scrollData + 1] = IG.ModuleStripHeading(stripRow.entry.data, stripChip, headerData)
                        end
                    elseif not headless then
                        scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(typeId, headerData)
                    end
                    -- An open sub-group means its parents can offer "Shift: collapse all".
                    openHeaders[depth] = headerData
                    for deeper = depth + 1, MAX_DEPTH do openHeaders[deeper] = nil end
                    -- What a parent offers to shut, and only what it can: a line has no way to
                    -- be closed, so a category whose only open thing is a line -- every set in
                    -- SELL, every place in RECENT LOOT -- was offering to do nothing at all.
                    if expanded and not asRule then
                        for parentDepth = 1, depth - 1 do
                            if openHeaders[parentDepth] then openHeaders[parentDepth].hasOpenChild = true end
                        end
                    end
                end
            end
            visible = visible and expanded
        end
        for deeper = #path + 1, MAX_DEPTH do previousKeys[deeper] = nil end
        if visible and not entry.igEmpty then
            entry.data.igItemLocation = path.itemLocation
            scrollData[#scrollData + 1] = entry
        end
    end
    CloseFeet(2)

    -- Minimal draws none of this: no outlines, no strips, no feet.
    if minimal then return end

    AssignFrames(scrollData)
end

---------------------------------------------------------------------------
-- Header rows
---------------------------------------------------------------------------

-- Right side of a header: "[Shift] + [left mouse]: Collapse All" (orange, while hovering an open
-- group with open sub-groups) and an optional white badge such as "saved 5 minutes ago".
-- The badge steps left of the hint whenever the hint shows, so they never overlap.
local HINT_COLOR = { 1, 0.6, 0.2 }
local BADGE_COLOR = { 1, 1, 1 }
local RIGHT_EDGE_MARGIN = 12
local BOX_GAP = 6

local function HintText(action)
    local mouseIcon = KEY_MOUSE_LEFT and GetMouseIconPathForKeyCode and GetMouseIconPathForKeyCode(KEY_MOUSE_LEFT)
    local mouse = mouseIcon and zo_iconFormat(mouseIcon, 22, 22) or "Click"
    return string.format("%s + %s: %s", ZO_Keybindings_GenerateTextKeyMarkup(GetKeyName(KEY_SHIFT)), mouse, action)
end

-- The one group that is never offered it. Its right side is already spent -- two counts on the
-- name line and its own right click menu at the edge -- so the words had nowhere to stand but
-- on top of its counts; and what is open inside it are places, which are read rather than
-- opened, so there was little for the shift to shut.
local NO_COLLAPSE_HINT = { LASTRUN = true }

-- NEW and RECENT LOOT: Shift+Click distributes (IG.SHIFT_CLICK_ACTIONS), so their hint says so
-- and shows whenever the heading is hovered.
local function IsShiftDistribute(data)
    return data.depth == 1 and not data.isSet and IG.SHIFT_CLICK_ACTIONS[data.key] ~= nil
end

local function CanCollapseChildren(data)
    if IsShiftDistribute(data) then return true end
    if data.depth == 1 and NO_COLLAPSE_HINT[data.key] then return false end
    return data.expanded == true and data.hasOpenChild == true
end

local function EnsureHint(control)
    if not control.igHint then
        control.igHint = IG.CreateTextBox(control, HINT_COLOR, HINT_FONT)
        control.igHint:SetHidden(true)
    end
    -- Pooled rows: the words follow whatever heading the row is today.
    local data = control.igData
    local action = (data and IsShiftDistribute(data)) and "Distribute" or "Collapse All"
    if control.igHintAction ~= action then
        control.igHintAction = action
        IG.SetTextBoxText(control.igHint, HintText(action))
    end
    return control.igHint
end

local function PlaceRightBoxes(control, hintShown)
    local center = control.igLineCenter or control:GetHeight() / 2
    local hint, badge = control.igHint, control.igBadge
    -- The room kept for "[right mouse] Menu", whether it is showing or not, so nothing jumps.
    local edge = RIGHT_EDGE_MARGIN + (control.igMenuWidth or 0)
    if hint then
        hint:ClearAnchors()
        hint:SetAnchor(RIGHT, control, TOPRIGHT, -edge, center)
        hint:SetHidden(not hintShown)
    end
    if badge and control.igBadgeShown then
        badge:ClearAnchors()
        if hintShown then
            badge:SetAnchor(RIGHT, hint, LEFT, -BOX_GAP, 0)
        else
            badge:SetAnchor(RIGHT, control, TOPRIGHT, -edge, center)
        end
    end
end

-- One of the slants over an emptied category's heading. Rows come out of a pool, so a heading
-- keeps the stripes it was once given and hides them when it is next something else.
local function StripePart(control, index, part, turned)
    control.igStripes = control.igStripes or {}
    control.igStripes[index] = control.igStripes[index] or {}
    local piece = control.igStripes[index][part]
    if not piece then
        piece = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        piece:SetColor(unpack(STRIPE_COLOR))
        piece:SetAlpha(STRIPE_ALPHA)
        piece:SetDrawLayer(DL_BACKGROUND)
        -- Over the heading's own surface and under everything written on it.
        piece:SetDrawLevel(4)
        -- The button underneath goes on being a button: opening the category is still the first
        -- thing you would want to do with it.
        piece:SetMouseEnabled(false)
        if turned then piece:SetTransformRotationZ(STRIPE_SLANT) end
        control.igStripes[index][part] = piece
    end
    return piece
end

-- Nothing here cuts anything off. A control that stands outside its parent is not trimmed to
-- it -- a scroll list trims what leaves the list, and that is the only edge in play -- so a
-- turned bar long enough to cross the whole plate hangs its two pointed ends out over the rows
-- above and below, which is what it did. The shape wanted is a parallelogram: a bar leaning
-- over with its ends cut flat, along the plate's own top and bottom lines.
--
-- So it is built rather than trimmed, and out of the two shapes that can be drawn exactly:
-- the leaning body is the longest turned bar that fits inside the plate whole, and the two
-- wedges it leaves at the ends -- each no more than the bar's own thickness leaning over,
-- about four pixels -- are filled by a small upright piece flush with the edge. Body and
-- caps together stand exactly as tall as the plate and not a pixel taller.
--
-- Slicing each bar into flat steps would have cut the ends the same way, and every step in
-- between would have shown as a notch down the bar's sides; it would also have cost twenty
-- controls a stripe instead of three.
local function ApplyMovedStripes(control, shown, left, rowHeight)
    local stripes = control.igStripes
    local drawn = 0
    if shown then
        local lean, upright = math.sin(STRIPE_SLANT), math.cos(STRIPE_SLANT)
        -- Turned, a bar covers its length leaning over plus its own thickness leaning out, so
        -- the length is worked back from the plate's height: the body then reaches both edges
        -- with one corner each and stops there.
        local length = zo_max((rowHeight - STRIPE_WIDTH * lean) / upright, 1)
        -- The wedge left at either end, which is that thickness leaning over, squared off.
        local capWidth, capHeight = STRIPE_WIDTH * upright, STRIPE_WIDTH * lean
        -- Turning a control the positive way takes its head to the left and its foot to the
        -- right (the wordmark on the sort bar is turned the other way and reads downwards), so
        -- the ends stand this far to either side of where the bar is hung.
        local swing = length * lean / 2
        -- Sideways there is no edge to stop at: a turned bar reaches wider than it is, and the
        -- list's background is not ours to draw on, so the first and last keep their distance.
        local reach = swing + capWidth / 2
        local from, to = left + reach, control:GetWidth() - STRIPE_INSET - reach
        local x = from
        while x <= to and drawn < STRIPE_MAX do
            drawn = drawn + 1
            local body = StripePart(control, drawn, "body", true)
            body:SetDimensions(STRIPE_WIDTH, length)
            body:ClearAnchors()
            body:SetAnchor(CENTER, control, TOPLEFT, x, rowHeight / 2)
            body:SetHidden(false)

            local head = StripePart(control, drawn, "head")
            head:SetDimensions(capWidth, capHeight)
            head:ClearAnchors()
            head:SetAnchor(TOP, control, TOPLEFT, x - swing, 0)
            head:SetHidden(false)

            local foot = StripePart(control, drawn, "foot")
            foot:SetDimensions(capWidth, capHeight)
            foot:ClearAnchors()
            foot:SetAnchor(BOTTOM, control, TOPLEFT, x + swing, rowHeight)
            foot:SetHidden(false)

            x = x + STRIPE_GAP
        end
        stripes = control.igStripes
    end
    if stripes then
        for i = drawn + 1, #stripes do
            for _, piece in pairs(stripes[i]) do piece:SetHidden(true) end
        end
    end
end

-- One line of the words on the right of an emptied category's heading.
local function AllMovedLabel(control, index)
    control.igAllMoved = control.igAllMoved or {}
    local label = control.igAllMoved[index]
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        label:SetColor(unpack(ASIDE_TEXT_COLOR))
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetMaxLineCount(1)
        label:SetMouseEnabled(false)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawLevel(9)
        control.igAllMoved[index] = label
    end
    return label
end

-- Writes them, and answers with how much of the right side they took, so everything else that
-- stands there -- and the name, which is shrunk to what is left -- is told to keep clear.
local function ApplyAllMovedCaption(control, moved, lineCenter)
    if not moved then
        for _, label in ipairs(control.igAllMoved or {}) do label:SetHidden(true) end
        return 0
    end
    -- Whatever the letters measure is what the line is given, so a line is never asked to hold
    -- more than it is wide and nothing is ever cut off to fit.
    local function Place(label, text, size, drop)
        label:SetFont(string.format(ALL_MOVED_FONT, size))
        label:SetText(text)
        local width = label:GetTextWidth() + 2
        label:SetWidth(width)
        label:ClearAnchors()
        label:SetAnchor(RIGHT, control, TOPRIGHT, -ALL_MOVED_RIGHT, lineCenter + drop)
        label:SetHidden(false)
        return width
    end

    local room = zo_max(control:GetWidth() - ALL_MOVED_KEEP, 1)
    -- The category's live name, so one you renamed says what you called it.
    local target = moved.target and zo_strupper(IG.GetGroupLabel(moved.target)) or nil
    local first = AllMovedLabel(control, 1)
    local function Hide(label) if label then label:SetHidden(true) end end

    -- One line for as long as one line fits, at the largest size that does.
    local one = target and string.format(ALL_MOVED_TEXT, target) or ALL_MOVED_MIXED
    for size = ALL_MOVED_ONE_MAX, ALL_MOVED_ONE_MIN, -1 do
        local width = Place(first, one, size, 0)
        if width <= room or size == ALL_MOVED_ONE_MIN and not target then
            Hide(control.igAllMoved[2])
            return width + BOX_GAP
        end
    end

    -- Too long for one line even made small, so it is broken where it reads: what happened,
    -- then where to.
    local second = AllMovedLabel(control, 2)
    for size = ALL_MOVED_TWO_MAX, ALL_MOVED_TWO_MIN, -1 do
        -- The pair sits astride the line the name is written on, half a line either side.
        local step = (size + ALL_MOVED_LINE_GAP) / 2
        local widest = zo_max(Place(first, ALL_MOVED_WRAP_FIRST, size, -step),
            Place(second, string.format(ALL_MOVED_WRAP_SECOND, target), size, step))
        if widest <= room then return widest + BOX_GAP end
    end

    -- A name long enough to beat both of those is not going to be read off a heading anyway,
    -- and half of one is worse than none: the words fall back to saying only what happened,
    -- which fits at any length, and the rows inside go on naming where each piece went.
    Hide(second)
    return Place(first, ALL_MOVED_MIXED, ALL_MOVED_ONE_MAX, 0) + BOX_GAP
end

local function SetCollapseHint(control, shown)
    if shown then EnsureHint(control) end
    PlaceRightBoxes(control, shown)
end

-- The white heading a run of categories is read under, with a line running out of it to either
-- edge and fading as it goes. Fixed white whatever the colours are set to: it is not one of the
-- categories, it is the thing that tells one run of them from the next.
local SECTION_FONT = "$(BOLD_FONT)|18|soft-shadow-thin"
local SECTION_TEXT = { 0.93, 0.93, 0.95 }
local SECTION_LINE_ALPHA = 0.5
local SECTION_LINE_THICKNESS = 1
local SECTION_LINE_GAP = 14  -- between the last letter and where its line begins
local SECTION_LINE_INSET = 2 -- how far short of the row's own edges the lines stop
local SECTION_ICON_SIZE = 20 -- the mark before the word, about the word's own height
local SECTION_ICON_GAP = 6   -- between the mark and the word

-- One piece of a rule: a hairline carrying whatever alpha at each end.
local function RuleLine(control, color, leftAlpha, rightAlpha)
    local line = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    local r, g, b = unpack(color)
    line:SetVertexColors(VERTEX_POINTS_TOPLEFT, r, g, b, leftAlpha)
    line:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, r, g, b, leftAlpha)
    line:SetVertexColors(VERTEX_POINTS_TOPRIGHT, r, g, b, rightAlpha)
    line:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, r, g, b, rightAlpha)
    line:SetHeight(SECTION_LINE_THICKNESS)
    return line
end

-- A heading's line: full where it leaves the word, gone by the time it reaches the edge. One
-- gradient is right here because a heading's line is always the same length -- the width of the
-- page, less the word.
local function SectionLine(control, nearLeft, color, alpha)
    color = color or SECTION_TEXT
    alpha = alpha or SECTION_LINE_ALPHA
    if nearLeft then return RuleLine(control, color, 0, alpha) end
    return RuleLine(control, color, alpha, 0)
end

-- Hovered: the word goes full white. Shut: word and lines a step back. Colour and alpha only, no plate.
local SECTION_SHUT_ALPHA = 0.55
local function SetSectionLook(control, hovered)
    local data, label = control.igData, control.igSectionLabel
    if not (data and label) then return end
    local alpha = hovered and 1 or (data.shut and SECTION_SHUT_ALPHA or 1)
    if hovered then label:SetColor(1, 1, 1, 1) else label:SetColor(unpack(SECTION_TEXT)) end
    label:SetAlpha(alpha)
    -- The mark wears the word's colour and alpha, whatever state it is in.
    if control.igSectionIcon then
        if hovered then control.igSectionIcon:SetColor(1, 1, 1, 1)
        else control.igSectionIcon:SetColor(unpack(SECTION_TEXT)) end
        control.igSectionIcon:SetAlpha(alpha)
    end
    -- The word is near white already, so white alone was no change to see: hovered, the lines
    -- thicken and a bar lights under the word.
    for _, line in ipairs(control.igSectionLines or {}) do
        line:SetAlpha(alpha)
        line:SetHeight(hovered and SECTION_LINE_THICKNESS + 1 or SECTION_LINE_THICKNESS)
    end
    if control.igSectionUnder then control.igSectionUnder:SetHidden(not hovered) end
    label:SetScale(1)
end

-- Pressed: the word gives a little under the finger until the button comes up.
local SECTION_PRESS_SCALE = 0.92

function IG.OnSectionMouseEnter(control)
    SetSectionLook(control, true)
    -- The hand, where the game has one to give. Asked for rather than assumed.
    if MOUSE_CURSOR_UI_HAND then WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_UI_HAND) end
    if IG.RefreshHeaderAction then IG.RefreshHeaderAction(control.igData) end
end

function IG.OnSectionMouseExit(control)
    SetSectionLook(control, false)
    if MOUSE_CURSOR_DO_NOT_CARE then WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE) end
    if IG.DropHeaderAction then IG.DropHeaderAction() end
end

local function SetupSectionRow(control, data)
    control:SetHeight(data.rowHeight)
    local label = control.igSectionLabel
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        label:SetFont(SECTION_FONT)
        label:SetColor(unpack(SECTION_TEXT))
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(CENTER, control, CENTER, 0, 0)
        control.igSectionLabel = label

        -- Hung off the word rather than measured from it: the label is only as wide as what is
        -- written in it, so the two lines find their own ends whatever the heading reads.
        local left = SectionLine(control, true)

        -- The section's mark in front of the word, tinted with it (IG.SECTION_ICONS).
        control.igSectionIcon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        control.igSectionIcon:SetDimensions(SECTION_ICON_SIZE, SECTION_ICON_SIZE)

        local right = SectionLine(control, false)
        right:SetAnchor(LEFT, label, RIGHT, SECTION_LINE_GAP, 0)
        right:SetAnchor(RIGHT, control, RIGHT, -SECTION_LINE_INSET, 0)
        control.igSectionLines = { left, right }

        local under = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        under:SetColor(1, 1, 1, 0.85)
        under:SetHeight(SECTION_LINE_THICKNESS + 1)
        under:SetAnchor(TOPLEFT, label, BOTTOMLEFT, 0, 1)
        under:SetAnchor(TOPRIGHT, label, BOTTOMRIGHT, 0, 1)
        under:SetHidden(true)
        control.igSectionUnder = under
    end
    control.igData = data
    -- Shut, the heading says how much is behind it and sits a step back; the lines stay.
    local text = data.label
    -- One count in brackets, shut or open: how many items stand under it.
    if data.count then text = string.format("%s  |c9A9AA2(%d)|r", text, data.count) end
    label:SetText(text)
    -- Mark and word centred as one; the left line ends at whichever stands first. Re-anchored
    -- every setup: pooled rows (HANDOFF §5).
    local icon = IG.SECTION_ICONS and IG.SECTION_ICONS[data.label]
    local mark = control.igSectionIcon
    mark:SetHidden(icon == nil)
    mark:SetTexture(icon or "")
    local lead = icon and (SECTION_ICON_SIZE + SECTION_ICON_GAP) or 0
    label:ClearAnchors()
    label:SetAnchor(CENTER, control, CENTER, lead / 2, 0)
    mark:ClearAnchors()
    mark:SetAnchor(RIGHT, label, LEFT, -SECTION_ICON_GAP, 0)
    local left = control.igSectionLines[1]
    left:ClearAnchors()
    left:SetAnchor(LEFT, control, LEFT, SECTION_LINE_INSET, 0)
    left:SetAnchor(RIGHT, icon and mark or label, LEFT, -SECTION_LINE_GAP, 0)
    -- The hover bar spans the whole label block: mark, word and its (N) count.
    local under = control.igSectionUnder
    if under then
        under:ClearAnchors()
        under:SetAnchor(TOPLEFT, label, BOTTOMLEFT, -lead, 1)
        under:SetAnchor(TOPRIGHT, label, BOTTOMRIGHT, 0, 1)
    end
    SetSectionLook(control, false)
    -- Only a heading in a real list can be shut; the settings preview's rows carry no list.
    local clickable = data.isSection == true
    control:SetMouseEnabled(clickable)
    if clickable and not control.igSectionHandlers then
        control.igSectionHandlers = true
        control:SetHandler("OnMouseEnter", function(self) IG.OnSectionMouseEnter(self) end)
        control:SetHandler("OnMouseExit", function(self) IG.OnSectionMouseExit(self) end)
        control:SetHandler("OnMouseDown", function(self, button)
            if button == MOUSE_BUTTON_INDEX_LEFT and self.igSectionLabel then
                self.igSectionLabel:SetScale(SECTION_PRESS_SCALE)
                self.igSectionLabel:SetAlpha(0.7)
            end
        end)
        control:SetHandler("OnMouseUp", function(self, button, upInside)
            if self.igSectionLabel then SetSectionLook(self, upInside) end
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT then IG.ToggleSection(self.igData) end
            -- Rows, Chips or Tiles for this section (ModuleStrip.lua).
            if upInside and button == MOUSE_BUTTON_INDEX_RIGHT and IG.ShowSectionDisplayMenu then
                IG.ShowSectionDisplayMenu(self, self.igData)
            end
        end)
    end
end
-- The set's name on a line of its own, the way a run of categories is headed -- but smaller, in
-- the cream the game writes its own lists in rather than in white, and inset to the inside of
-- the category holding it, because it divides that category rather than the page.
local SET_RULE_FONT = "$(BOLD_FONT)|15|soft-shadow-thin"
local SET_RULE_INFO_FONT = "$(BOLD_FONT)|13|soft-shadow-thin"
local SET_RULE_GAP = 12      -- between the last letter and where its line begins
-- Flat, and the same flat everywhere. A rule is as long as its set's name is short, so anything
-- that varies along the line's length -- a gradient over the whole of it, or a fixed fade with a
-- flat run behind it -- makes the rule's weight a reading of the name. And a fade of fixed width
-- has nowhere to go when the name leaves it no room: it drew straight over the words instead.
-- A flat line anchored at both ends cannot do either. Where there is no room it closes to
-- nothing, which is the right answer.
local SET_RULE_ALPHA = 0.4
local SET_RULE_RIGHT = 16    -- where the right hand line stops short of the row's edge
local SET_RULE_ROLE_SIZE = 18
local SET_RULE_ROLE_GAP = 8  -- between the markers and the name they belong to
-- A bare rule -- a place under RECENT LOOT -- is read from the middle out: its name stands in
-- the centre with a line running to either side, and the mark of what kind of place it was goes
-- in front of the name. The pair is centred together, so the name alone is not.
local SET_RULE_ICON_GAP = 6
local SET_RULE_ICON_ROOM = 6 -- how much shorter than its row the mark is drawn
local SET_RULE_COUNT_DARKEN = 0.75    -- the bracket after the name, a shade behind it
local SET_RULE_LOCATION_DARKEN = 0.62 -- and where it drops, a shade behind that

-- The role markers, side by side rather than stacked: a rule has length and no height, which is
-- the opposite of what the button's little pyramid was drawn for. Each one carries its own
-- colour into the label, so one label says all three.
-- IG.GetSetRoles hands back the roles themselves, not their keys -- the same tables
-- IG.ShowSetRoles reads icon and colour off for the button.
local function RuleRoleText(roles)
    local parts = {}
    for _, role in ipairs(roles or {}) do
        if role and role.icon and role.color then
            parts[#parts + 1] = string.format("|c%s|t%d:%d:%s:inheritcolor|t|r",
                IG.RGBToHex(unpack(role.color)), SET_RULE_ROLE_SIZE, SET_RULE_ROLE_SIZE, role.icon)
        end
    end
    return table.concat(parts, " ")
end

-- Where it drops, and how much of it the collection holds: the two things the button said on its
-- right, said on the rule's right in the same order.
local function RuleInfoText(data, cream)
    local parts = {}
    if sv.showLocation and data.location then
        parts[#parts + 1] = string.format("|c%s%s|r",
            IG.DimColor(cream, SET_RULE_LOCATION_DARKEN), data.location)
    end
    local summary = data.summary
    if sv.showCollect and summary and (summary.pieces or 0) > 0 then
        local green = IG.RGBToHex(unpack(IG.COLLECT_COLOR))
        parts[#parts + 1] = string.format("|c%s|t%d:%d:%s:inheritcolor|t %d/%d|r",
            green, SET_RULE_ROLE_SIZE, SET_RULE_ROLE_SIZE, IG.COLLECTED_ICON,
            summary.collected or 0, summary.pieces or 0)
    end
    return table.concat(parts, "  ")
end

local function SetupSetRuleRow(control, data)
    control:SetHeight(data.rowHeight)
    IG.ApplyFrames(control, data.igFrames, true)

    local cream = data.color or IG.DEFAULT_ICON_COLOR
    local label = control.igRuleLabel
    if not label then
        local creamRGB = { IG.HexToRGB(cream) }
        -- The markers, then the name, then whatever room is left: read in that order, from the
        -- left, so a column of rules is a column of names at one edge rather than a row of
        -- centred ones each sitting wherever its own length put it.
        control.igRuleRoles = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        control.igRuleRoles:SetFont(SET_RULE_INFO_FONT)
        control.igRuleRoles:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        label:SetFont(SET_RULE_FONT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control.igRuleLabel = label

        control.igRuleInfo = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        control.igRuleInfo:SetFont(SET_RULE_INFO_FONT)
        control.igRuleInfo:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        control.igRuleInfo:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control.igRuleInfo:SetAnchor(RIGHT, control, RIGHT, -SET_RULE_RIGHT, 0)

        control.igRuleLine = RuleLine(control, creamRGB, SET_RULE_ALPHA, SET_RULE_ALPHA)
        control.igRuleLineLeft = RuleLine(control, creamRGB, SET_RULE_ALPHA, SET_RULE_ALPHA)
        control.igRuleIcon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    end

    -- Painted on every setup, not once: a row is reused, and the one that drew a set last time
    -- draws a place this time. Its colour is the thing that says which.
    local ruleR, ruleG, ruleB = IG.HexToRGB(cream)
    label:SetColor(ruleR, ruleG, ruleB)
    for _, corner in ipairs({ VERTEX_POINTS_TOPLEFT, VERTEX_POINTS_BOTTOMLEFT,
                              VERTEX_POINTS_TOPRIGHT, VERTEX_POINTS_BOTTOMRIGHT }) do
        control.igRuleLine:SetVertexColors(corner, ruleR, ruleG, ruleB, SET_RULE_ALPHA)
        control.igRuleLineLeft:SetVertexColors(corner, ruleR, ruleG, ruleB, SET_RULE_ALPHA)
    end

    local details = sv.setRuleDetails == true and not data.bareRule
    local name = zo_strupper(data.label or "")
    if details and sv.showCounts then
        name = string.format("%s  |c%s(%d)|r", name,
            IG.DimColor(cream, SET_RULE_COUNT_DARKEN), data.count or 0)
    end
    label:SetText(name)

    local roles = details and RuleRoleText(sv.showRoles and
        (data.roles or (data.summary and IG.GetSetRoles(data.setId, data.summary.link))) or nil) or ""
    control.igRuleRoles:SetText(roles)
    control.igRuleRoles:SetHidden(roles == "")

    local left = IG.HeaderIndent(data.depth)
    if data.bareRule then
        local iconSize = zo_max(data.rowHeight - SET_RULE_ICON_ROOM, 0)
        local mark = control.igRuleIcon
        mark:SetHidden(data.icon == nil)
        control.igRuleRoles:SetHidden(true)
        control.igRuleInfo:SetHidden(true)

        -- Centred as one thing: the name is pushed right by half of what stands in front of it,
        -- so the mark and the name together sit in the middle rather than the name alone.
        local lead = data.icon and (iconSize + SET_RULE_ICON_GAP) or 0
        label:ClearAnchors()
        label:SetAnchor(CENTER, control, CENTER, lead / 2, 0)
        if data.icon then
            mark:SetTexture(data.icon)
            mark:SetDimensions(iconSize, iconSize)
            mark:SetColor(ruleR, ruleG, ruleB)
            mark:ClearAnchors()
            mark:SetAnchor(RIGHT, label, LEFT, -SET_RULE_ICON_GAP, 0)
        end

        control.igRuleLineLeft:SetHidden(false)
        control.igRuleLineLeft:ClearAnchors()
        control.igRuleLineLeft:SetAnchor(LEFT, control, LEFT, left, 0)
        control.igRuleLineLeft:SetAnchor(RIGHT, data.icon and mark or label, LEFT, -SET_RULE_GAP, 0)

        control.igRuleLine:ClearAnchors()
        control.igRuleLine:SetAnchor(LEFT, label, RIGHT, SET_RULE_GAP, 0)
        control.igRuleLine:SetAnchor(RIGHT, control, RIGHT, -SET_RULE_RIGHT, 0)
        return
    end
    control.igRuleIcon:SetHidden(true)
    control.igRuleLineLeft:SetHidden(true)

    -- Both start where the category's own indent leaves off; the name steps past the markers
    -- when there are any.
    control.igRuleRoles:ClearAnchors()
    control.igRuleRoles:SetAnchor(LEFT, control, LEFT, left, 0)
    label:ClearAnchors()
    if roles ~= "" then
        label:SetAnchor(LEFT, control.igRuleRoles, RIGHT, SET_RULE_ROLE_GAP, 0)
    else
        label:SetAnchor(LEFT, control, LEFT, left, 0)
    end

    -- The line fills what is left, and ends where the rule ends when there is nothing to say.
    local info = details and RuleInfoText(data, cream) or ""
    control.igRuleInfo:SetText(info)
    control.igRuleInfo:SetHidden(info == "")
    control.igRuleLine:ClearAnchors()
    control.igRuleLine:SetAnchor(LEFT, label, RIGHT, SET_RULE_GAP, 0)
    if info ~= "" then
        control.igRuleLine:SetAnchor(RIGHT, control.igRuleInfo, LEFT, -SET_RULE_GAP, 0)
    else
        control.igRuleLine:SetAnchor(RIGHT, control, RIGHT, -SET_RULE_RIGHT, 0)
    end
end

local function SetupHeaderRow(control, data)
    control.igData = data
    local depth = data.depth
    control:SetHeight(data.rowHeight)
    -- The name line; set headers may have the piece badges on a second line below it.
    local nameLineHeight = data.rowHeight
    if data.isSet then
        -- A set with badges under its name centres the name in the top part only; with the
        -- badges switched off the row is no shorter and the name has all of it.
        nameLineHeight = sv.showPieces and metrics.setName or data.rowHeight
    end
    local lineCenter = nameLineHeight / 2
    -- With badges under it the name is centred in the band above them, which was measured
    -- against where the letters actually sit; with the row to itself it needs the correction.
    if data.isSet and not sv.showPieces then lineCenter = lineCenter + SET_CAP_DROP end
    control.igLineCenter = lineCenter

    local isLeaf = depth > 1 and data.isLeaf
    -- Sizes (font, icon, marker) come from the header's depth, except in the trading layout.
    -- A header drawn somewhere other than its own row can ask for another level's sizes: the
    -- second sticky stands for a sub-category and is drawn smaller than the one it stands for.
    local look = data.look or (data.compact and TRADE_HEADER_LOOK) or depth
    -- Every level steps in by the same small amount; only sets reserve more, for the strip their
    -- role markers live in.
    local indentKind = data.isSet and "set" or nil
    local headerLeft = IG.HeaderIndent(data.drawDepth or depth, indentKind)
    local contentLeft = IG.HeaderContentOffset(depth, headerLeft, data.isSet)
    local marker = control:GetNamedChild("Marker")
    marker:ClearAnchors()
    marker:SetAnchor(LEFT, control, TOPLEFT, contentLeft,
        data.isSet and (lineCenter - SET_MARKER_RISE) or data.rowHeight / 2)
    local markerSize = data.isSet and SET_MARKER_SIZE or MARKER_SIZES[look]
    marker:SetDimensions(markerSize, markerSize)
    marker:SetTexture(data.expanded and MARKER_MINUS or MARKER_PLUS)

    local r, g, b = IG.HexToRGB(data.color)
    -- Text, icon and marker color: the group color, or the header style's own (ARMORY: black).
    -- A set's own color would sink into its colored surface, so its text is lifted toward white
    -- while staying the same hue, and its font carries an outline.
    local textR, textG, textB = r, g, b
    if data.isSet then
        textR, textG, textB = IG.HexToRGB(IG.LightenColor(data.color, SET_TEXT_LIGHTEN))
    end
    if data.style and data.style.text then textR, textG, textB = unpack(data.style.text) end
    marker:SetColor(1, 1, 1, 1)

    -- Sub-level headers sit on the open group's tinted surface; the top header has its own.
    IG.ApplyFrames(control, data.igFrames, depth > 1)
    local special = depth == 1 and GlowTint(data.key)
    local tint = data.expanded and SURFACE_TINT_SUB_EXPANDED or SURFACE_TINT_SUB
    if data.isSet then
        tint = data.expanded and SURFACE_TINT_SET_EXPANDED or SURFACE_TINT_SET
    end
    if special then
        tint = special + (data.expanded and SPECIAL_EXPANDED_EXTRA_TINT or 0)
    elseif depth == 1 then
        tint = data.expanded and SURFACE_TINT_EXPANDED or SURFACE_TINT_COLLAPSED
    end
    local base = special and SpecialBase(data.key, data.color)
    -- A set that serves several roles blends their colors across its header, so the stops are a
    -- list: one per color, in role order.
    local surfaceColors = data.colors or { data.color }
    control.igBgColor, control.igHoverColor = {}, {}
    for i, color in ipairs(surfaceColors) do
        control.igBgColor[i] = IG.GetHeaderSurfaceColor(depth, color, tint, HEADER_BG_ALPHA[depth], base)
        control.igHoverColor[i] = IG.GetHeaderSurfaceColor(depth, color, tint + HEADER_HOVER_TINT,
            HEADER_BG_ALPHA[depth], base)
    end
    local style = data.style
    if style and style.surface then
        control.igBgColor, control.igHoverColor = { style.surface }, { style.hover }
    end
    IG.ApplyHeaderBackground(control, depth, isLeaf, data.isSet, headerLeft, control.igBgColor,
        data.color, data.expanded, data.drawDepth)
    -- The area behind a set's role markers is part of its button, at half the header's strength
    -- (so it brightens with the header when the set is opened).
    -- Struck through when every piece that would stand under it was sent elsewhere by hand.
    -- Only the category itself: a sub-heading inside one is not a thing you empty, and a slant
    -- on every level would be a hatched list rather than a marked category.
    ApplyMovedStripes(control, depth == 1 and data.allMoved ~= nil, headerLeft, data.rowHeight)

    local roleBgColor = data.isSet
        and IG.GetHeaderSurfaceColor(depth, data.color, tint / 2, HEADER_BG_ALPHA[depth]) or nil
    IG.ApplyRoleBackground(control, depth, roleBgColor, data.expanded)

    local style, speed
    if depth == 1 then style, speed = AnimationFor(data.key) end
    IG.SetHeaderAnimation(control, style and data.color or nil, style, speed)

    -- Groups show their icon on the left; sets show it after the name, right before the count.
    local iconPath = sv.icons[data.iconKey] or data.icon
    local icon = control:GetNamedChild("Icon")
    -- Sets carry theirs after the name, a bare header has none at all, and the rest never outgrow
    -- the row however tight the density is.
    local hasIcon = not data.isSet and iconPath ~= nil
    local leftIconSize = hasIcon and zo_min(HEADER_ICON_SIZES[look], data.rowHeight - 6) or 0
    icon:SetDimensions(leftIconSize, leftIconSize)
    icon:SetHidden(not hasIcon)
    -- The icon (and the name anchored to it) sits on the name line, while the marker is centered
    -- on the whole row, which differs for set headers with a piece row underneath.
    icon:ClearAnchors()
    -- (The name hangs 5 px right of this icon; a set has no icon, so this only places its name.)
    local iconLeft = contentLeft + marker:GetWidth() + MARKER_ICON_GAP
    if data.isSet then iconLeft = contentLeft + SET_NAME_OFFSET - 5 end
    -- A line read as an item row puts its mark where the item icons are, centred in their
    -- column. Its name does not follow it there: that is anchored on its own, below.
    if data.itemLine then iconLeft = ITEM_ICON_CENTER - leftIconSize / 2 end
    icon:SetAnchor(LEFT, control, TOPLEFT, iconLeft, lineCenter)
    if hasIcon then
        icon:SetTexture(iconPath)
        -- An icon always wears its own button's color; with colors switched off that is the
        -- cream every button wears.
        if data.iconColor then
            -- A mark of its own keeps its own colour, whatever the line it stands on is
            -- written in: it is not saying which group this is, it is saying what these are.
            local markR, markG, markB = IG.HexToRGB(data.iconColor)
            icon:SetColor(markR, markG, markB, 1)
        elseif data.keepIconColors then
            icon:SetColor(1, 1, 1, 1)
        else
            icon:SetColor(textR, textG, textB, 1)
        end
    end

    local location = control:GetNamedChild("Location")
    location:ClearAnchors()
    location:SetAnchor(RIGHT, control, TOPRIGHT, -16, lineCenter)
    -- Where it goes back to once the Menu hint has stepped it aside (IG.OnHeaderMouseEnter).
    control.igLocationY = lineCenter
    local locationWidth = 0
    -- A set's location is capped (ellipsized past it); every other heading's stays as wide as
    -- its text. Pooled rows: the cap is set or taken off every time.
    local locationMax = data.isSet and zo_floor(control:GetWidth() * SET_LOCATION_MAX_SHARE) or 0
    location:SetDimensionConstraints(0, 0, locationMax, 0)
    location:SetMaxLineCount(1)
    if sv.showLocation and data.location then
        location:SetFont(data.isSet and SET_LOCATION_FONT or LOCATION_FONTS[look])
        if data.isSet then
            location:SetColor(textR, textG, textB, 1)
        else
            location:SetColor(r * LOCATION_DARKEN, g * LOCATION_DARKEN, b * LOCATION_DARKEN)
        end
        location:SetText(data.location)
        location:SetHidden(false)
        local textWidth = location:GetTextWidth()
        if locationMax > 0 then textWidth = zo_min(textWidth, locationMax) end
        locationWidth = textWidth + 12
    else
        location:SetText("")
        location:SetHidden(true)
    end

    -- And it says so in words, at the very right of the heading: that corner is empty on a
    -- top-level heading, so the words take it and grow leftwards from there. Everything else
    -- that stands on the right is told how much they took and steps in front of them.
    local movedWidth = ApplyAllMovedCaption(control, depth == 1 and data.allMoved or nil, lineCenter)
    if movedWidth > 0 then locationWidth = locationWidth + movedWidth end

    -- The headings with a right click menu say so on the right of their header, while hovered.
    -- The question is asked in one place for both the hint and the menu itself (HeaderHasMenu):
    -- a hint on a heading that answers nothing, or a menu nothing told you about, is how those
    -- two drift apart.
    local menuHint = control.igMenuHint
    -- The room kept clear on the right before anything of the hint's own: what the emptied
    -- category's words are already using.
    control.igMenuWidth = movedWidth > 0 and movedWidth or nil
    if HeaderHasMenu(data) then
        if not menuHint then
            menuHint = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            menuHint:SetFont(MENU_HINT_FONT)
            menuHint:SetDrawLevel(20)
            local mouseIcon = KEY_MOUSE_RIGHT and GetMouseIconPathForKeyCode and GetMouseIconPathForKeyCode(KEY_MOUSE_RIGHT)
            menuHint:SetText(string.format("%s |c%sMenu|r", mouseIcon and zo_iconFormat(mouseIcon, 20, 20) or "Right click:",
                SUBTITLE_COLOR))
            control.igMenuHint = menuHint
        end
        menuHint:ClearAnchors()
        menuHint:SetAnchor(RIGHT, control, TOPRIGHT, -(RIGHT_EDGE_MARGIN + movedWidth), lineCenter)
        menuHint:SetHidden(true)
        control.igMenuWidth = movedWidth + menuHint:GetTextWidth() + BOX_GAP
        locationWidth = locationWidth + menuHint:GetTextWidth() + 12
    elseif menuHint then
        menuHint:SetHidden(true)
    end

    local badgeShown = data.badge ~= nil and (data.expanded or not data.badgeOnlyWhenExpanded)
    control.igBadgeShown = badgeShown
    if badgeShown then
        if not control.igBadge then control.igBadge = IG.CreateTextBox(control, BADGE_COLOR, HINT_FONT) end
        IG.SetTextBoxText(control.igBadge, data.badge)
        control.igBadge:SetHidden(false)
        locationWidth = locationWidth + control.igBadge:GetWidth() + RIGHT_EDGE_MARGIN
        if CanCollapseChildren(data) then
            locationWidth = locationWidth + EnsureHint(control):GetWidth() + BOX_GAP
        end
    elseif control.igBadge then
        control.igBadge:SetHidden(true)
    end
    PlaceRightBoxes(control, false)

    -- Names that don't fit on one line shrink until they do.
    local label = control:GetNamedChild("Name")
    label:SetMaxLineCount(1)
    -- The template hangs the name off the icon, which is what puts every heading's name after
    -- its icon. A line read as an item row keeps its name in the item names' own column
    -- instead, wherever its mark ended up, so both ends are anchored by hand here -- and put
    -- back by hand when the same control is next asked to be a heading.
    if data.itemLine then
        label:ClearAnchors()
        label:SetAnchor(LEFT, control, TOPLEFT, ITEM_NAME_LEFT, lineCenter)
        label:SetAnchor(RIGHT, location, LEFT, -NAME_LOCATION_GAP, 0)
        control.igNameMoved = true
    elseif control.igNameMoved then
        control.igNameMoved = nil
        label:ClearAnchors()
        label:SetAnchor(LEFT, icon, RIGHT, NAME_ICON_GAP, 0)
        label:SetAnchor(RIGHT, location, LEFT, -NAME_LOCATION_GAP, 0)
    end
    label:SetColor(textR, textG, textB)
    -- The count wears the group's own color, a shade darker than its name; the total, when it is
    -- switched on, wears the same color a shade darker again, so the two brackets read in order.
    local countColor = data.style and data.style.count or IG.RGBToHex(textR * 0.8, textG * 0.8, textB * 0.8)
    -- A node with nothing but items under it counts the same thing twice: the rows under it and
    -- the items in its tree are one and the same, so it says the number once and plainly. A node
    -- holding other nodes says what it is holding -- sets by name, since that is the one kind
    -- worth telling apart -- and what the whole of it comes to.
    local items = data.totalItems or 0
    local rows = data.count or 0
    -- A category that counts the things in it rather than the rows they are arranged into
    -- says one number, and the second bracket has nothing left to add.
    if data.countsItems then rows = items end
    local flat = rows == items
    -- A node that counts something other than rows says what it counts, so the number is not
    -- read as the rows waiting under it. Sets are named here because a category holding sets is
    -- the one kind worth telling apart; anything else names itself (RECENT LOOT: instances).
    --
    -- And what it says it counts is what it counts: a category holding one set and a loose
    -- item opens two rows and has one set in it, and the number beside the word "Sets" is the
    -- number of sets.
    local countLabel, countValue = data.countLabel, rows
    if not countLabel and not flat and (data.setCount or 0) > 0 then
        countLabel, countValue = "Sets", data.setCount
    end
    local count = ""
    if data.totalOnly then
        -- DISPOSAL: the items in it, said once (its categories are counted on their own rows).
        count = string.format("|c%s(Total Items: %d)|r", countColor, items)
        if not sv.showCounts and not sv.showTotalItems then count = "" end
        flat = true
    elseif sv.showCounts then
        if countLabel then
            count = string.format("|c%s(%s: %d)|r", countColor, countLabel, countValue)
        else
            count = string.format("|c%s(%d)|r", countColor, rows)
        end
    end
    local total = ""
    if sv.showTotalItems and not flat then
        total = string.format("  |c%s(Total Items: %d)|r",
            IG.RGBToHex(textR * TOTAL_DARKEN, textG * TOTAL_DARKEN, textB * TOTAL_DARKEN),
            items)
    end
    -- Every heading is written in capitals; a line read as an item row is written the way the
    -- names beside it are, or the capitals alone would give it away as a heading.
    local name = data.itemLine and data.label or zo_strupper(data.label)
    if data.nameColor and data.labelName and not data.itemLine
        and data.label:sub(-#data.labelName) == data.labelName then
        name = string.format("%s|c%s%s|r",
            zo_strupper(data.label:sub(1, #data.label - #data.labelName)),
            data.nameColor, zo_strupper(data.labelName))
    end
    if data.isSet then
        label:SetText(string.format("%s  %s%s", name, count, total))
    else
        local subtitle = data.subtitle
            and string.format("  |c%s%s|r", data.subtitleColor or SUBTITLE_COLOR, data.subtitle) or ""
        -- SELL and DECONSTRUCT say when their action will empty them (Classify.lua).
        local tag, tagColor = nil, nil
        if data.depth == 1 or data.disposalSub == true then
            tag, tagColor = IG.ActionHeaderTag(data.key)
        end
        if tag then subtitle = subtitle .. string.format("  |c%s%s|r", tagColor, tag) end
        label:SetText(string.format("%s  %s%s%s", name, count, total, subtitle))
    end
    local nameLeft = contentLeft + marker:GetWidth() + MARKER_ICON_GAP + leftIconSize + ICON_NAME_GAP
    if data.isSet then nameLeft = contentLeft + SET_NAME_OFFSET end
    if data.itemLine then nameLeft = ITEM_NAME_LEFT end
    local available = control:GetWidth() - nameLeft - locationWidth - 16

    -- Under the drop location, right aligned: what the set collection already holds of this set,
    -- and beside it -- pulsing -- how many collection slots the pieces in this list could still
    -- fill. It takes no room off the name: it is on a line of its own.
    local summary = data.summary
    if data.isSet and sv.showCollect and summary and (summary.pieces or 0) > 0 then
        IG.ShowSetCollected(control, summary, COLLECT_FONT, -16, lineCenter + COLLECTED_DROP)
    else
        IG.HideSetCollected(control)
    end

    local face, size, shadow = unpack((data.isSet and SET_FONT)
        or (data.itemLine and ITEM_LINE_FONT) or HEADER_FONTS[look])
    if data.isSet and not sv.showPieces then size = SET_FONT_TALL_SIZE end
    repeat
        label:SetFont(string.format("%s|%d|%s", face, size, data.style and data.style.fontShadow or shadow))
        size = size - 1
    until label:GetTextWidth() <= available or size < MIN_FONT_SIZE

    if data.isSet and sv.showPieces and summary then
        -- The badges start under the +/-, not under the name: the mark is part of the name now.
        IG.ShowSetPieces(control, summary, data.slotFilter, data.color, contentLeft + SET_BADGE_OFFSET, metrics.piecesTop)
    else
        IG.HideSetPieces(control)
    end

    -- What the set is mostly for (damage / tank / support), stacked in the gap left of its header.
    if data.isSet and sv.showRoles and summary and (data.roles or summary.link) then
        IG.ShowSetRoles(control, data.roles or IG.GetSetRoles(data.setId, summary.link), IG.RoleArea(depth))
    else
        IG.HideSetRoles(control)
    end

    -- Redrawn under the cursor, which is what happens to the header you just pressed the key
    -- on: it says the opposite now, and the strip is told so.
    if IG.IsUnderMouse and IG.IsUnderMouse(control) and IG.RefreshHeaderAction then
        IG.RefreshHeaderAction(data)
    end
end


---------------------------------------------------------------------------
-- The sample group the settings page shows beside itself
---------------------------------------------------------------------------

-- Preview.lua draws it; it is built here because everything it is made of lives in this file --
-- the row types, the row heights, the frame pass, the header styles. Nothing below reads the bag:
-- the sample is written out by hand, so it costs nothing and cannot go wrong on an item that is
-- not there. Everything else about it -- colors, surfaces, outlines, animations -- comes out of
-- the same code the real lists go through, so what it shows is what you get.
IG.DressHeaderRow = SetupHeaderRow
IG.DressSectionRow = SetupSectionRow
IG.DressSetRuleRow = SetupSetRuleRow

-- Nothing in the sample carries a name that could be taken for a real one: every category says
-- what it is a preview of, and every item is a "sample" of something. The modules are all here
-- whether or not they are switched on, because their glow and their animation are settings on
-- this page and a module that was not drawn would leave nothing to look at; one that is off
-- stands in its place grey and dim instead.
--
-- It answers the mouse, too. Clicking a header opens or closes it exactly as clicking one in the
-- bag does, and what opens holds items that belong in it, so the switches about what is inside an
-- open group have something to be seen on.
local PREVIEW_SUFFIX = " preview" -- headers are drawn in capitals, so this is written in lower case
local PREVIEW_OFF_KEY = "PREVIEW_OFF" -- a key nothing glows or animates against
local PREVIEW_OFF_COLOR = "6E6E74"
-- A section drawn as Chips or Tiles (LAYOUT, ModuleStrip.lua): one row standing for every
-- category in it, same as the real list puts up in place of their heading rows. Only used by
-- this file and Preview.lua, so it does not need to sit with the real list's own row types above.
local PREVIEW_STRIP_TYPE = 1740
-- Why a row is sitting there doing nothing, written after its name. Red while that is a state
-- the player might want to change; in the row's own color once it is not.
local PREVIEW_NOTE = {
    -- Short, and in capitals like the rest: a category with a long name of its own has
    -- little room left for a note beside it, and HOME CONTAINERS already had none.
    module = "[ INACTIVE ]",        -- its switch under Modules is off
    empty = "[ EMPTY ]",            -- the sample gives it nothing, as a bag would
}
local PREVIEW_ALERT_COLOR = "FF5C5C"
local PREVIEW_NOTE_DARKEN = 0.8 -- the same shade the count beside it wears

-- The game's own item quality colors, so a shelf of sample rows is not all one shade.
local PREVIEW_QUALITY = { normal = "FFFFFF", fine = "2DC50E", superior = "3A92FF",
    epic = "A02EF7", legendary = "EEC600" }

-- Icons the addon already ships against: every one of these is a group or sub-group icon from
-- Colors.lua, so none of them can turn out not to be there.
local PREVIEW_ART = "EsoUI/Art/"
local PREVIEW_ICON = {
    armor = PREVIEW_ART .. "Inventory/inventory_tabIcon_armor_up.dds",
    weapon = PREVIEW_ART .. "Inventory/inventory_tabIcon_weapons_up.dds",
    jewelry = PREVIEW_ART .. "Crafting/jewelry_tabIcon_icon_up.dds",
    consumable = PREVIEW_ART .. "Inventory/inventory_tabIcon_consumables_up.dds",
    crafting = PREVIEW_ART .. "Inventory/inventory_tabIcon_crafting_up.dds",
    container = PREVIEW_ART .. "Inventory/inventory_tabIcon_Container_up.dds",
    misc = PREVIEW_ART .. "Inventory/inventory_tabIcon_misc_up.dds",
    stolen = PREVIEW_ART .. "Inventory/inventory_stolenItem_icon.dds",
    token = PREVIEW_ART .. "MainMenu/menuBar_collections_up.dds",
    mythic = PREVIEW_ART .. "Journal/journal_tabIcon_antiquities_up.dds",
    trophy = PREVIEW_ART .. "LFG/LFG_indexIcon_dungeon_up.dds",
    housing = PREVIEW_ART .. "Collections/collections_tabIcon_housing_up.dds",
    loadout = "EsoUI/Art/Armory/buildItem_icon.dds",
}

-- A row in the bag says more than a name: a lock on the ones you locked, a tick on the ones
-- already in your collection, and what a merchant would give for it. A sample row that said
-- only a name would be the one thing in the preview that did not look like the bag.
--
-- Which rows carry what is worked out here rather than written out forty times, and the prices
-- are made up once, at load: a number that changed every time the preview was drawn would be
-- the only thing moving on the page.
local previewItems = 0

local function PreviewItem(label, count, quality, icon)
    previewItems = previewItems + 1
    return { label = label, count = count,
        color = PREVIEW_QUALITY[quality], icon = PREVIEW_ICON[icon],
        price = math.random(4, 480),
        locked = previewItems % 3 == 0,
        known = previewItems % 4 == 1 }
end

-- What each category holds. Things that belong in it, and a different number of them in each, so
-- that the counts beside the names are not one number repeated all the way down.
local PREVIEW_BAG = {
    NEW = {
        PreviewItem("Sample shoulders", 1, "epic", "armor"),
        PreviewItem("Sample glyph", 2, "fine", "misc"),
        PreviewItem("Sample recipe", 1, "superior", "consumable"),
    },
    REWARDS = {
        PreviewItem("Sample reward box", 1, "epic", "container"),
        PreviewItem("Sample mail attachment", 3, "normal", "container"),
    },
    LASTRUN = {
        PreviewItem("Sample trophy", 1, "legendary", "trophy"),
        PreviewItem("Sample ring", 1, "epic", "jewelry"),
        PreviewItem("Sample greatsword", 1, "superior", "weapon"),
        PreviewItem("Sample potion", 5, "fine", "consumable"),
    },
    LOCKED = {
        PreviewItem("Sample locked greatsword", 1, "legendary", "weapon"),
        PreviewItem("Sample locked ring", 1, "epic", "jewelry"),
    },
    JUNK = {
        PreviewItem("Sample cracked pelt", 2, "normal", "trophy"),
        PreviewItem("Sample rusty dagger", 1, "normal", "weapon"),
    },
    BINDONEQUIP = {
        PreviewItem("Sample unbound cuirass", 1, "epic", "armor"),
        PreviewItem("Sample unbound staff", 1, "superior", "weapon"),
        PreviewItem("Sample unknown motif", 1, "epic", "misc"),
    },
    ARMORY = {
        PreviewItem("Sample loadout", 1, "normal", "loadout"),
        PreviewItem("Sample second loadout", 1, "normal", "loadout"),
    },
    HOME = {
        PreviewItem("Sample stored ingot", 12, "fine", "crafting"),
        PreviewItem("Sample stored furnishing", 1, "superior", "housing"),
        PreviewItem("Sample stored motif", 2, "epic", "misc"),
    },
    MYTHIC = {
        PreviewItem("Sample mythic ring", 1, "legendary", "mythic"),
        PreviewItem("Sample mythic girdle", 1, "legendary", "mythic"),
    },
    TOKENS = {
        PreviewItem("Sample token", 7, "normal", "token"),
        PreviewItem("Sample seal", 24, "fine", "token"),
        PreviewItem("Sample key", 3, "superior", "token"),
    },
    CONSUMABLES = {
        PreviewItem("Sample food", 8, "fine", "consumable"),
        PreviewItem("Sample potion", 15, "superior", "consumable"),
        PreviewItem("Sample poison", 4, "normal", "consumable"),
        PreviewItem("Sample drink", 2, "epic", "consumable"),
    },
    CRAFT = {
        PreviewItem("Sample ore", 42, "normal", "crafting"),
        PreviewItem("Sample rune", 9, "fine", "crafting"),
        PreviewItem("Sample style stone", 5, "superior", "crafting"),
    },
    STOLEN = {
        PreviewItem("Sample stolen trinket", 3, "fine", "stolen"),
        PreviewItem("Sample stolen dish", 1, "normal", "stolen"),
    },
    CRAFTABLE = {
        PreviewItem("Sample crafted cuirass", 1, "epic", "armor"),
        PreviewItem("Sample crafted axe", 1, "superior", "weapon"),
    },
    MONSTER = {
        PreviewItem("Sample monster helm", 1, "epic", "armor"),
    },
    PVP = {
        PreviewItem("Sample campaign ring", 1, "superior", "jewelry"),
        PreviewItem("Sample campaign greaves", 1, "epic", "armor"),
    },
    CLASS = {
        PreviewItem("Sample class staff", 1, "epic", "weapon"),
        PreviewItem("Sample class robe", 1, "superior", "armor"),
    },
    GARBAGE = {
        PreviewItem("Sample trash", 6, "normal", "misc"),
        PreviewItem("Sample broken trinket", 2, "normal", "misc"),
    },
    WORLD = {
        PreviewItem("Sample overland ring", 1, "superior", "jewelry"),
        PreviewItem("Sample survey", 3, "fine", "misc"),
    },
    FURNISHING = {
        PreviewItem("Sample chair", 1, "fine", "housing"),
        PreviewItem("Sample rug", 2, "normal", "housing"),
    },
    MISC = {
        PreviewItem("Sample oddment", 11, "normal", "misc"),
    },
    -- EVENTS, TREASURE MAPS, COMPANION GEAR and QUEST ITEMS are left out on purpose: a bag has
    -- empty categories in it, and the switch about whether those show is on the page.
}

-- The one category with a tree under it, and the one that starts open.
local PREVIEW_OPEN = "PVE"

-- The two sub-groups inside it, looked up for their colors and their icons and labelled their
-- own way. One child under a group reads as part of the group rather than as a level of its own,
-- so there are two: the first holds the sets, the second is a plain one and holds items.
local PREVIEW_SUBS = {
    { name = "Trial Sets", label = "sub-group" },
    { name = "Arena Sets", label = "second sub-group", items = {
        PreviewItem("Sample gauntlets", 1, "epic", "armor"),
        PreviewItem("Sample dagger", 1, "superior", "weapon"),
        PreviewItem("Sample necklace", 1, "epic", "jewelry"),
    } },
}

-- Two sets, so a blended header and a plain one are both on screen, and so the counters and the
-- short badge row of a two-piece set are there to be seen.
local PREVIEW_SETS = {
    {
        label = "damage + tank set" .. PREVIEW_SUFFIX,
        roles = { "damage", "tank" },
        where = "Trial",
        slots = { head = 1, chest = 2, hands = 1, legs = 1, feet = 1, neck = 1, ring = 2 },
        worn = { chest = true },
        uncollected = 3,
        collected = 6,
        pieces = 12,
        items = {
            PreviewItem("Sample cuirass", 1, "epic", "armor"),
            PreviewItem("Sample ring", 1, "superior", "jewelry"),
        },
    },
    {
        label = "support set" .. PREVIEW_SUFFIX,
        roles = { "support" },
        where = "Dungeon",
        slots = { head = 1 },
        worn = {},
        uncollected = 1,
        collected = 11,
        pieces = 12,
        -- A monster set: two pieces and no jewellery, so its badge row is a short one.
        slotFilter = { head = true, shoulders = true },
        items = {
            PreviewItem("Sample helm", 1, "epic", "armor"),
            PreviewItem("Sample pauldrons", 1, "fine", "armor"),
        },
    },
}

-- Both numbers a header can wear, worked out from the sample rather than written into it: how
-- many rows open directly under it, and how many items are in its whole tree. Opening a category
-- never turns either of its own numbers into a lie.
local function PreviewSubCount(index)
    local sub = PREVIEW_SUBS[index]
    return sub.items and #sub.items or #PREVIEW_SETS
end

local function PreviewSubTotal(index)
    local sub = PREVIEW_SUBS[index]
    if sub.items then return #sub.items end
    local total = 0
    for _, sample in ipairs(PREVIEW_SETS) do total = total + #sample.items end
    return total
end

local function PreviewGroupCount(key)
    if key == PREVIEW_OPEN then return #PREVIEW_SUBS end
    local items = PREVIEW_BAG[key]
    return items and #items or 0
end

local function PreviewGroupTotal(key)
    if key == PREVIEW_OPEN then
        local total = 0
        for index = 1, #PREVIEW_SUBS do total = total + PreviewSubTotal(index) end
        return total
    end
    local items = PREVIEW_BAG[key]
    return items and #items or 0
end

-- What the preview has open, by node key, and what it starts on: open all the way down to the
-- items, so the first look at the page already has a group, a sub-group, a set and the rows
-- inside it on screen at once.
--
-- One thing at a time at every level, the way the addon's own "One group open at a time" works.
-- Closing a category leaves what was open inside it alone, so reopening it picks up where it was.
local previewOpen = {
    [PREVIEW_OPEN] = true,
    [PREVIEW_OPEN .. "/sub1"] = true,
    [PREVIEW_OPEN .. "/sub1/set1"] = true,
}

-- A key is its parent's, a slash, and its own name; the top level has no slash and so no parent.
local function ParentOf(key)
    return key:match("^(.*)/[^/]*$")
end

function IG.TogglePreviewNode(key)
    local wasOpen = previewOpen[key]
    -- The same switch the real lists answer, so the preview shows what it does.
    if sv.accordion then
        local parent = ParentOf(key)
        for other in pairs(previewOpen) do
            if ParentOf(other) == parent then previewOpen[other] = nil end
        end
    end
    previewOpen[key] = (not wasOpen) or nil
end

local function PreviewRoles(keys)
    local roles = {}
    for index, key in ipairs(keys) do roles[index] = IG.ROLE_BY_KEY[key] end
    return roles
end

local function PreviewSummary(sample)
    local summary = IG.NewSetSummary(sample.worn)
    for key, count in pairs(sample.slots) do summary.slots[key] = count end
    summary.uncollected = sample.uncollected
    summary.collected, summary.pieces = sample.collected, sample.pieces
    return summary
end

-- A module whose switch is off: drawn, but not lit, and not opened either -- in the bag it
-- would not be there at all. Names why, so the row can say so beside its own name.
local function PreviewGroupOff(key)
    if key == "LOCKED" then
        -- No list of its own: the sample answers for the bag, which is the list it is a
        -- sample of.
        if not IG.LockedSeparated(IG.InventoryKey(INVENTORY_BACKPACK)) then return "module" end
        return nil
    end
    local flag = MODULE_GROUPS[key]
    if flag and sv[flag] ~= true then return "module" end
    return nil
end

-- Every category the player has, in the order they put them in on the Groups page. More than
-- fits is what the preview scrolls for; leaving some out would mean the sample said nothing
-- about the order, which is a setting of its own.
-- The sample fills nearly every category, so the few it leaves empty all sit near the bottom of
-- the list, where the switch about empty categories cannot be seen working without scrolling to
-- them. Two are brought up to stand with the modules instead, so what is not showing, and why,
-- reads as one run at the top.
local PREVIEW_EMPTY_UP = { "EVENTS", "QUEST" }
local PREVIEW_EMPTY_AFTER = "HOME" -- the last of the modules, wherever the player has put it

-- The sample shows everything by default, modules you have switched off and categories it has
-- nothing to put in included, full colour and all, so changing a colour or a style can be seen
-- on every category it would ever reach. "Show My Current Settings" (Preview's one toggle) asks
-- it to stop pretending and draw only what your bag would actually have in it.
local function PreviewShows(key)
    if sv.previewRealOnly ~= true then return true end
    return not PreviewGroupOff(key)
end

local function PreviewGroupKeys()
    local lifted = {}
    for _, key in ipairs(PREVIEW_EMPTY_UP) do lifted[key] = true end

    local keys, placed = {}, false
    local function AddLifted()
        placed = true
        for _, key in ipairs(PREVIEW_EMPTY_UP) do
            if PreviewShows(key) then keys[#keys + 1] = key end
        end
    end

    for _, group in ipairs(IG.GetOrderedGroups()) do
        if not lifted[group.key] then
            if PreviewShows(group.key) then keys[#keys + 1] = group.key end
            if group.key == PREVIEW_EMPTY_AFTER then AddLifted() end
        end
    end
    -- Whatever it was meant to follow is gone: better at the end than not at all.
    if not placed then AddLifted() end
    return keys
end

-- One level, nothing drawn: the flat layout names its own categories, gives them all the one
-- cream color and opens them, and draws no outline anywhere. A preview of the tree would be a
-- lie while that is what the lists are doing.
local FLAT_PREVIEW = { "set", "second set", "gear", "consumables", "crafting" }

local function FlatPreview()
    local entries = {}
    for index, label in ipairs(FLAT_PREVIEW) do
        if index > 1 then
            entries[#entries + 1] = ZO_ScrollList_CreateDataEntry(SPACER_TYPE, { rowHeight = metrics.spacer })
        end
        entries[#entries + 1] = ZO_ScrollList_CreateDataEntry(HEADER_TYPES[1], {
            key = "PREVIEW_FLAT" .. index,
            depth = 1,
            expanded = true,
            isLeaf = true,
            rowHeight = metrics.headers[1],
            label = label .. PREVIEW_SUFFIX,
            color = IG.DEFAULT_ICON_COLOR,
            count = 18 - index * 3,
            totalItems = 18 - index * 3,
        })
    end
    return entries, {}
end

local function TreePreview()
    local entries, dimmed = {}, {}
    -- The headings the bag reads its categories under, by the same switch. The preview is where
    -- that switch is watched, so leaving them out of it left it saying nothing.
    local sections = IG.SectionsOn()
    local shownSection
    local function Add(entry, off)
        entries[#entries + 1] = entry
        if off then dimmed[entry.data] = true end
    end

    local function AddItems(items)
        for _, item in ipairs(items or {}) do
            Add(ZO_ScrollList_CreateDataEntry(STORED_ITEM_TYPE, {
                rowHeight = STORED_ITEM_HEIGHT,
                label = item.label,
                color = item.color,
                count = item.count,
                icon = item.icon,
            }))
        end
    end

    local setType, setHeight = SET_TYPE, SetRowHeight()
    if sv.showPieces then setType = SET_TYPE_WITH_PIECES end
    -- Drawn as a rule, a set is never shut, so the sample never shows one that is. The sample
    -- category answers the way the bag's own does: its right click (Group Sets / Don't Group
    -- Sets) or, never asked, the default.
    local bagKey = INVENTORY_KEYS and INVENTORY_KEYS[INVENTORY_BACKPACK]
    local setRules = IG.SetsAsDividers(bagKey, PREVIEW_OPEN)
    if setRules then setType, setHeight = SET_RULE_TYPE, metrics.setRule end

    local function AddSets(subKey, subColor, setType, setHeight)
        for index, sample in ipairs(PREVIEW_SETS) do
            local setKey = subKey .. "/set" .. index
            local setOpen = setRules or previewOpen[setKey] == true
            local roles = PreviewRoles(sample.roles)
            local setColor, setColors = IG.GetRoleLook(roles)
            Add(ZO_ScrollList_CreateDataEntry(setType, {
                key = setKey,
                igPreviewKey = not setRules and setKey or nil,
                depth = 3,
                expanded = setOpen,
                isSet = true,
                isLeaf = true,
                rowHeight = setHeight,
                label = sample.label,
                color = setColor or subColor,
                colors = setColors,
                location = sample.where,
                slotFilter = sample.slotFilter,
                count = #sample.items,
                totalItems = #sample.items,
                summary = PreviewSummary(sample),
                -- No item to read the roles off, so the sample says what they are.
                roles = roles,
            }))
            if setOpen then AddItems(sample.items) end
        end
    end

    -- The one category with a tree under it: two sub-groups, sets in the first of them, and
    -- items wherever something is open.
    local function AddTree(key)
        local groupColor = IG.GetGroupColor(key)
        for subIndex, sub in ipairs(PREVIEW_SUBS) do
            local subKey = key .. "/sub" .. subIndex
            local subOpen = previewOpen[subKey] == true
            -- A sub-group that was open leaves a little room above the next one, the way
            -- BuildGroupedList does after a sibling it had to close.
            if subIndex > 1 and previewOpen[key .. "/sub" .. (subIndex - 1)] then
                Add(ZO_ScrollList_CreateDataEntry(SUB_SPACER_TYPE,
                    { depth = 2, rowHeight = metrics.subSpacer }))
            end
            local look = IG.SUBGROUPS[sub.name]
            local subColor = IG.GetSubColor(groupColor, look)
            Add(ZO_ScrollList_CreateDataEntry(HEADER_TYPES[2], {
                key = subKey,
                igPreviewKey = subKey,
                depth = 2,
                expanded = subOpen,
                isLeaf = false,
                rowHeight = metrics.headers[2],
                label = sub.label .. PREVIEW_SUFFIX,
                color = subColor,
                icon = look and look.icon,
                iconKey = look and ("sub:" .. look.label),
                count = PreviewSubCount(subIndex),
                totalItems = PreviewSubTotal(subIndex),
            }))
            if subOpen then
                if sub.items then
                    AddItems(sub.items)
                else
                    AddSets(subKey, subColor, setType, setHeight)
                end
                Add(ZO_ScrollList_CreateDataEntry(SUB_FOOT_TYPE, { depth = 2, rowHeight = metrics.foot }))
            end
        end
    end

    -- Keys that fail PreviewShows never reach this loop at all (PreviewGroupKeys), so a module
    -- switched off is never seen here: only "Show My Current Settings" asks that question, and
    -- it has already been asked. What is left to decide per row is whether an empty category --
    -- one the sample has nothing to put in -- is shut and marked [ EMPTY ] the way the real bag
    -- would mark it, and that only matters once real settings are what is being shown. It still
    -- wears its own colour either way: [ EMPTY ] already says what grey used to say twice over.
    local realOnly = sv.previewRealOnly == true

    -- One category, drawn the way Rows always has: its own heading row, opened if the sample
    -- says so. What LAYOUT's Chips/Tiles asks for is answered by AddStrip below instead.
    local function AddCategoryRow(key)
        local empty = key ~= PREVIEW_OPEN and not PREVIEW_BAG[key]
        local emptyHidden = realOnly and empty and sv.showEmptyGroups ~= true
        local open = not emptyHidden and previewOpen[key] == true
        local color = IG.GetGroupColor(key)
        local group = IG.GROUP_BY_KEY[key]

        local note, noteColor
        if emptyHidden then
            note = PREVIEW_NOTE.empty
            noteColor = PREVIEW_ALERT_COLOR
        end

        Add(ZO_ScrollList_CreateDataEntry(HEADER_TYPES[1], {
            -- Shut and ungnawable, the key nothing glows or animates against: there is nothing
            -- under an emptied-and-hidden row to open.
            key = emptyHidden and PREVIEW_OFF_KEY or key,
            igPreviewKey = not emptyHidden and key or nil,
            depth = 1,
            expanded = open,
            isLeaf = false,
            rowHeight = metrics.headers[1],
            label = IG.GetGroupLabel(key) .. PREVIEW_SUFFIX,
            subtitle = note,
            subtitleColor = noteColor,
            color = color,
            icon = group.icon,
            iconKey = key,
            count = emptyHidden and 0 or PreviewGroupCount(key),
            totalItems = emptyHidden and 0 or PreviewGroupTotal(key),
            style = HEADER_STYLES[key],
        }), false)

        if open and key == PREVIEW_OPEN then
            AddTree(key)
        elseif open then
            AddItems(PREVIEW_BAG[key])
        end
    end

    -- A whole section's worth of categories, as the one row of buttons Chips or Tiles stands in
    -- their heading rows' place with. Never opened in the sample: a real button opens the
    -- category right under it in the real list, and the sample has no real list to open it in,
    -- so the row only ever says what it would look like closed.
    local LOOKS = IG.MODULE_STRIP_LOOKS
    local function AddStrip(section, mode, keys)
        local look = LOOKS and LOOKS[mode]
        local items = {}
        for _, key in ipairs(keys) do
            local group = IG.GROUP_BY_KEY[key]
            items[#items + 1] = {
                key = key,
                label = IG.GetGroupLabel(key),
                color = IG.GetGroupColor(key),
                icon = group.icon,
                count = PreviewGroupCount(key),
            }
        end
        local perLine = (look and look.perLine) or #items
        local lines = zo_max(1, zo_ceil(#items / zo_max(1, perLine)))
        local rowHeight = look and (look.pad * 2 + lines * look.height + (lines - 1) * look.gap)
            or metrics.headers[1]
        Add(ZO_ScrollList_CreateDataEntry(PREVIEW_STRIP_TYPE, {
            rowHeight = rowHeight,
            mode = mode,
            items = items,
        }), false)
    end

    -- Keys that fail PreviewShows never reach this loop at all (PreviewGroupKeys), so a module
    -- switched off is never seen here: only "Show My Current Settings" asks that question, and
    -- it has already been asked.
    local keys = PreviewGroupKeys()
    local index = 1
    while index <= #keys do
        local key = keys[index]
        local section = sections and IG.GetGroupSection(key)
        local mode = (section and bagKey and IG.SectionDisplay) and IG.SectionDisplay(bagKey, section)
            or "rows"

        if #entries > 0 then
            Add(ZO_ScrollList_CreateDataEntry(SPACER_TYPE, { rowHeight = metrics.spacer }))
        end
        if section and section ~= shownSection then
            Add(ZO_ScrollList_CreateDataEntry(SECTION_TYPE,
                { label = section, rowHeight = metrics.section }))
            shownSection = section
        end

        if mode ~= "rows" and section then
            -- Every key still to come that shares this section and this heading: one strip for
            -- all of them, the way the real list's build groups them under one row of buttons.
            local blockKeys = {}
            while index <= #keys and sections and IG.GetGroupSection(keys[index]) == section do
                blockKeys[#blockKeys + 1] = keys[index]
                index = index + 1
            end
            AddStrip(section, mode, blockKeys)
        else
            AddCategoryRow(key)
            index = index + 1
        end
    end
    return entries, dimmed
end

-- What Preview.lua walks: one row per control, saying which of the three kinds of control it
-- wants, whether it is to be drawn dim, and carrying the data SetupHeaderRow (or ApplyFrames, or
-- Preview.lua's own item row) is given.
local PREVIEW_KIND = { [STORED_ITEM_TYPE] = "item", [SECTION_TYPE] = "section",
    [SET_RULE_TYPE] = "setrule", [PREVIEW_STRIP_TYPE] = "strip" }

function IG.PreviewRows()
    -- Written out rather than picked with "and ... or": a call in the middle of one of those is
    -- cut down to a single value, and the second table would never arrive.
    local entries, dimmed
    if sv.flatGrouping == true then
        -- The flat layout draws no outlines at all, exactly where BuildGroupedList leaves it.
        entries, dimmed = FlatPreview()
    else
        entries, dimmed = TreePreview()
        AssignFrames(entries)
    end

    local rows = {}
    for index, entry in ipairs(entries) do
        rows[index] = {
            kind = IS_HEADER_TYPE[entry.typeId] and "header" or PREVIEW_KIND[entry.typeId] or "frame",
            dim = dimmed[entry.data] == true,
            data = entry.data,
        }
    end
    return rows
end

-- Item rows inside a group: how far the price sits from the row's right edge (the game uses 5).
local PRICE_RIGHT_INSET = 12

-- The row of a piece that is standing in two places at once: here, where it belongs, and in
-- the category it was sent to.
--
-- The row itself is faded rather than covered. A pane laid over the top only paints: what is
-- under it keeps its colour and shows through, and the pane takes the list's own outlines with
-- it. Taking the row's alpha down takes everything the row has with it -- its icon, its name,
-- what it is worth -- and the one line that says why does not go along, because a control can
-- be told not to inherit what its parent does with its alpha.
local ASIDE_ROW_ALPHA = 0.22
local ASIDE_FONT = "$(BOLD_FONT)|13|soft-shadow-thin"
-- (ASIDE_TEXT_COLOR is up with the header constants: the heading of an emptied category is
-- written in the same red and is drawn long before this.)
-- Brighter than the row it stands on, and not by much: it is the one thing on a stood-down
-- row that has to be read, not the loudest thing in the list. Its own strength rather than
-- the row's, since it is told not to inherit that.
local ASIDE_CAPTION_ALPHA = 0.5
local ASIDE_CAPTION = 'MOVED TO "%s"'
-- Over the name rather than across it: the row goes on saying what it is, and this stands
-- above it the way a heading over a line does. Measured up from the middle of the row, which
-- is where the name sits, far enough that a little air is left between the two.
local ASIDE_CAPTION_RISE = -15
local ASIDE_NAME_LEFT = 110
-- Where the name's box starts is a hair left of where its first letter does, and a bold face
-- starts further in again: this is what lines the two up by eye rather than by box.
local ASIDE_NAME_NUDGE = 1

-- With Hide Moved on, the UNCOLLECTED row stays at full strength: it is not a copy of another
-- row, it is the only place that group lists the piece, so standing it down would be standing
-- the answer itself down. What it still has to say is that the piece was sent somewhere, and it
-- says it quietly -- beside the name rather than over it, clearly smaller than the name
-- (ITEM_LINE_FONT is 20) but still a size you read rather than squint at, in the same red the
-- stood-down line uses. Same face and the same "shadow" the name is set in, not the thin soft
-- one our own small print uses: a different shadow is the one thing that would make these words
-- look like they were sitting on a surface of their own instead of on the row, next to the name.
local MOVED_NOTE_FONT = "$(MEDIUM_FONT)|13|shadow"
local MOVED_NOTE_TEXT = "Moved to %s"
-- Centred against the name's box, smaller letters read as riding above the name rather than
-- standing with it: the shorter word has no descenders to fill the space under it. Dropped by
-- eye until the two sit on one line, and only this note is dropped -- what is written beside it
-- is a different size again and lines up where it already did.
local MOVED_NOTE_DROP = 2
-- Everything that stands after the name keeps this much air in front of it, and each one starts
-- where the one before it ended so the three never land on top of one another.
local NAME_NOTE_GAP = 10

-- Held back in SELL [GUILD STORE], for one of the two reasons Classify.lua keeps. The row stays
-- at full strength and says so twice: one line beside the name in capitals ("AWAITING
-- UPGRADE!"), in the face the UNCOLLECTED note uses, and a slow pulse of light over the whole
-- row in the same colour -- for an upgrade, the colour of the quality the piece is waiting to
-- become (IG.AwaitingColor). The note keeps its own strength rather than the row's.
--
-- The pulse is one flat wash per row and one timeline per row, made the first time that row is
-- asked to pulse and kept: rows come out of a pool, so each setup says again whether this row
-- pulses and in which colour, and a row that is now some other piece (or a header) stops. The
-- wash stops its timeline when it stops being on screen (scrolled out of the list, the bag
-- shut) and starts it again when it comes back, so nothing animates where nobody can see it.
local PULSE_LOW, PULSE_HIGH = 0.04, 0.26
local AWAITING_NOTE_RISE = -16   -- the note's middle sits this far above the name's middle
local PULSE_HALF_MS = 2200   -- one fade, in or out: a whole breath is twice this

local function PulseWanted(wash)
    return wash.igPulseOn and not wash:IsControlHidden()
end

local function AwaitingPulse(control, hex)
    local wash = control.igAwaitingWash
    if not hex then
        if wash and wash.igPulseOn then
            wash.igPulseOn = false
            wash.igTimeline:Stop()
            wash:SetAlpha(PULSE_LOW)
            wash:SetHidden(true)
        end
        return
    end
    if not wash then
        wash = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        wash:SetAnchorFill(control)
        wash:SetDrawLayer(DL_BACKGROUND)
        wash:SetDrawLevel(1)
        wash:SetMouseEnabled(false)
        -- Added onto the row rather than blended over it: at the bottom of the fade it adds
        -- nothing, so the row is back to its normal ground and never goes dark.
        wash:SetBlendMode(TEX_BLEND_MODE_ADD)
        -- Its own strength: the animation drives it, not the row's alpha.
        wash:SetInheritAlpha(false)
        wash:SetHidden(true)
        local timeline = ANIMATION_MANAGER:CreateTimeline()
        local fade = timeline:InsertAnimation(ANIMATION_ALPHA, wash, 0)
        fade:SetAlphaValues(PULSE_LOW, PULSE_HIGH)
        fade:SetDuration(PULSE_HALF_MS)
        if ZO_EaseInOutQuadratic then fade:SetEasingFunction(ZO_EaseInOutQuadratic) end
        timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
        wash.igTimeline = timeline
        wash:SetHandler("OnEffectivelyHidden", function(self) self.igTimeline:Stop(); self:SetAlpha(PULSE_LOW) end)
        wash:SetHandler("OnEffectivelyShown", function(self)
            if PulseWanted(self) and not self.igTimeline:IsPlaying() then
                self.igTimeline:PlayFromStart()
            end
        end)
        control.igAwaitingWash = wash
    end
    -- An untextured texture ignores the alpha of SetColor (HANDOFF): colour here, strength by
    -- SetAlpha, which is what the animation writes.
    local r, g, b = IG.HexToRGB(hex)
    wash:SetColor(r, g, b, 1)
    wash.igPulseOn = true
    wash:SetHidden(false)
    if not wash:IsControlHidden() and not wash.igTimeline:IsPlaying() then
        wash:SetAlpha(PULSE_LOW)
        wash.igTimeline:PlayFromStart()
    end
end

-- Mythic items have no set header, so their location goes on the item row, right after the name.
local function DecorateItemRow(control, data)
    -- The lock/equipped/new status icon sits just right of the group's left strip; when it's
    -- showing, frame lines step around it instead of running through it.
    local inGroup = data.igFrames and #data.igFrames > 0
    local status = control:GetNamedChild("Status")
    local gap
    if status then
        -- Re-anchoring costs a layout pass, so only do it when the row changes side.
        if control.igStatusInGroup ~= inGroup then
            control.igStatusInGroup = inGroup
            status:ClearAnchors()
            status:SetAnchor(TOPLEFT, control, TOPLEFT, inGroup and IG.STATUS_ICON_LEFT or 0, 10)
        end
        local icons = status:GetNamedChild("Texture")
        if inGroup and icons and icons.iconData and #icons.iconData > 0 then
            gap = IG.GetStatusIconGap()
        end
    end
    IG.ApplyFrames(control, data.igFrames, true, gap)

    -- A NEW row standing for the pieces a stack just gained shows that number, not the whole stack.
    if data.igPartialNew then
        local button = control:GetNamedChild("Button")
        local stackLabel = button and button:GetNamedChild("StackCount")
        if stackLabel then stackLabel:SetText(data.stackCount) end
    end

    -- Pull the price in a little so it stays clear of the group frames' right edges.
    local price = control:GetNamedChild("SellPrice")
    if price and control.igPriceInGroup ~= inGroup then
        control.igPriceInGroup = inGroup
        price:ClearAnchors()
        price:SetAnchor(RIGHT, control, RIGHT, inGroup and -PRICE_RIGHT_INSET or -5, 0)
    end


    -- Sent aside and drawn here as well: the row is stood down and one line says why. Not
    -- mouse enabled -- the row underneath is a real row of a real piece, and taking it back
    -- out is done on it.
    local aside = data.igSetAside
    -- Never on the copy: that row is already stood down and already carries a line saying where
    -- the piece went. The piece's own row, over in the guild store pile, is where the waiting is
    -- happening and where the words belong.
    local awaiting = not aside and IG.AwaitingFor(data)
    if aside then
        control:SetAlpha(ASIDE_ROW_ALPHA)
        if not control.igAsideCaption then
            local caption = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            caption:SetFont(ASIDE_FONT)
            caption:SetColor(unpack(ASIDE_TEXT_COLOR))
            -- The one thing on a stood-down row that is not stood down with it -- though it
            -- is stood down some of the way, or it would be shouting over a whole list.
            caption:SetInheritAlpha(false)
            caption:SetAlpha(ASIDE_CAPTION_ALPHA)
            caption:SetDrawLayer(DL_OVERLAY)
            caption:SetDrawLevel(9)
            caption:SetMouseEnabled(false)
            control.igAsideCaption = caption
        end
        -- Where the name starts, a line above it. Hung off the row rather than off the name:
        -- what the game makes that label's box is the game's business, and a box as tall as
        -- the row would have put this outside it.
        local nameLabel = control:GetNamedChild("Name")
        local nameLeft = nameLabel and (nameLabel:GetLeft() - control:GetLeft()) or ASIDE_NAME_LEFT
        control.igAsideCaption:ClearAnchors()
        control.igAsideCaption:SetAnchor(LEFT, control, LEFT, nameLeft + ASIDE_NAME_NUDGE,
            ASIDE_CAPTION_RISE)
        -- The category's own name, so a category you renamed says what you called it.
        control.igAsideCaption:SetText(string.format(ASIDE_CAPTION,
            zo_strupper(IG.GetGroupLabel(aside))))
        control.igAsideCaption:SetHidden(false)
    else
        -- Rows come out of a pool: the one that was stood down a moment ago is this one now.
        -- A row held back for an upgrade or a price is at full strength: it pulses instead
        -- (AwaitingPulse), which says "waiting" without making the row hard to read.
        if control:GetAlpha() ~= 1 then control:SetAlpha(1) end
        if control.igAsideCaption then control.igAsideCaption:SetHidden(true) end
    end

    -- Marked with ctrl, and the hint that says it can be.
    IG.DressSelection(control, data)

    local nameLabel = control:GetNamedChild("Name")

    -- Where the name ends, which is where the notes after it begin. Each note that shows moves
    -- this along, so the next one stands after it instead of across it.
    local nameRight = nameLabel and zo_min(nameLabel:GetTextWidth(), nameLabel:GetWidth()) or 0

    -- While selling: a piece your set collection doesn't have yet says so, right after its name.
    local collectable = control.igCollectable
    if data.igCollectable and nameLabel then
        if not collectable then
            collectable = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            collectable:SetFont(COLLECT_FONT)
            collectable:SetColor(unpack(COLLECTABLE_COLOR))
            collectable:SetText("Collectable !")
            control.igCollectable = collectable
        end
        collectable:ClearAnchors()
        collectable:SetAnchor(LEFT, nameLabel, LEFT, nameRight + NAME_NOTE_GAP, 0)
        collectable:SetHidden(false)
        nameRight = nameRight + NAME_NOTE_GAP + collectable:GetTextWidth()
    elseif collectable then
        collectable:SetHidden(true)
    end

    -- Sent aside, on a row that is not being stood down for it: the bare words, in the category's
    -- own name, so a category you renamed says what you called it. No alpha of its own to keep --
    -- the row it hangs on is at full strength, which is the whole point of this shape.
    local movedNote = control.igMovedNote
    if data.igMovedNote and nameLabel then
        if not movedNote then
            movedNote = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            movedNote:SetFont(MOVED_NOTE_FONT)
            movedNote:SetColor(unpack(ASIDE_TEXT_COLOR))
            movedNote:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            movedNote:SetMouseEnabled(false)
            control.igMovedNote = movedNote
        end
        movedNote:SetText(string.format(MOVED_NOTE_TEXT, IG.GetGroupLabel(data.igMovedNote)))
        movedNote:ClearAnchors()
        movedNote:SetAnchor(LEFT, nameLabel, LEFT, nameRight + NAME_NOTE_GAP, MOVED_NOTE_DROP)
        movedNote:SetHidden(false)
        nameRight = nameRight + NAME_NOTE_GAP + movedNote:GetTextWidth()
    elseif movedNote then
        -- Rows come out of a pool: what the last piece here said is not this one's to say.
        movedNote:SetHidden(true)
    end

    -- Held back until something better turns up, said beside the name and joining the same
    -- chain: whatever already stands after the name, this starts where that ended.
    local awaitingNote = control.igAwaitingNote
    if awaiting and nameLabel then
        if not awaitingNote then
            awaitingNote = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            awaitingNote:SetFont(MOVED_NOTE_FONT)
            awaitingNote:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            awaitingNote:SetMouseEnabled(false)
            awaitingNote:SetDrawLayer(DL_OVERLAY)
            control.igAwaitingNote = awaitingNote
        end
        -- Said again every time: the row out of the pool may have been waiting for the other
        -- thing a moment ago, and this piece may have changed its mind since it was last drawn.
        awaitingNote:SetText(IG.AwaitingMarkup(awaiting, data))
        awaitingNote:ClearAnchors()
        -- Stacked directly above the name, left-aligned with it; nameRight is left alone because
        -- nothing now stands beside the name on its line.
        awaitingNote:SetAnchor(LEFT, nameLabel, LEFT, 0, AWAITING_NOTE_RISE)
        awaitingNote:SetHidden(false)
    elseif awaitingNote then
        -- The same pool, and the same answer: this row is not the one that was waiting.
        awaitingNote:SetHidden(true)
    end
    AwaitingPulse(control, awaiting and IG.AwaitingColor(awaiting, data) or nil)

    -- WORN after the name of a worn piece's copy in an equipment setup (Setups.lua).
    if IG.DressSetupRow then nameRight = IG.DressSetupRow(control, data, nameLabel, nameRight) end

    local location = control.igLocation
    if not (sv.showLocation and data.igItemLocation) then
        if location then location:SetHidden(true) end
        return
    end
    if not nameLabel then return end
    if not location then
        location = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        location:SetFont(LOCATION_FONTS[#LOCATION_FONTS])
        location:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control.igLocation = location
    end
    local r, g, b = nameLabel:GetColor()
    location:SetColor(r * LOCATION_DARKEN, g * LOCATION_DARKEN, b * LOCATION_DARKEN)
    location:SetText(data.igItemLocation)
    location:ClearAnchors()
    location:SetAnchor(LEFT, nameLabel, LEFT, nameRight + NAME_NOTE_GAP, 0)
    location:SetHidden(false)
end

local function HookItemRows(listView)
    local dataType = listView and ZO_ScrollList_GetDataTypeTable(listView, 1)
    local originalSetup = dataType and dataType.setupCallback
    if not originalSetup then return end
    dataType.setupCallback = function(control, data, ...)
        originalSetup(control, data, ...)
        DecorateItemRow(control, data)
    end
end

-- Crafting stations have inventories of their own and build their lists the same way (Craft.lua).
IG.CRAFT_INVENTORY_TYPE = -1
-- The improvement bench is a list of its own: what is open in it, and what it does with locked
-- and moved pieces, are kept apart from deconstruction's.
IG.IMPROVE_INVENTORY_TYPE = -2

function IG.IsCraftType(inventoryType)
    return inventoryType == IG.CRAFT_INVENTORY_TYPE or inventoryType == IG.IMPROVE_INVENTORY_TYPE
end

function IG.IsOwnRowType(typeId)
    return IS_OWN_ROW_TYPE[typeId] == true
end

-- itemType: the bench's own item row type (ZO_SharedCraftingInventory:GetScrollDataType). The
-- build gives a proxy row with no typeId of its own the list's item type (listDataType, as the
-- bag's inventories carry); without it JUST CRAFTED's rows came out with a nil typeId, and
-- ZO_ScrollList_Commit indexed the missing data type and broke the whole station window.
-- lead: the category the bench is there for, { key, fresh }, drawn first and opened as each
-- visit starts (LeadFirst); nil for a bench with none.
function IG.BuildCraftList(list, inventoryType, itemType, lead)
    BuildGroupedList({ listView = list, listDataType = itemType, lead = lead },
        inventoryType or IG.CRAFT_INVENTORY_TYPE, "normal")
    -- Second guard: a row whose type is not registered on this list (ZO_ScrollList_GetDataTypeTable,
    -- scrolltemplates.lua) is dropped rather than handed to the commit, which cannot survive it.
    local scrollData = ZO_ScrollList_GetDataList(list)
    local dropped
    for _, entry in ipairs(scrollData) do
        if not (entry.typeId and ZO_ScrollList_GetDataTypeTable(list, entry.typeId)) then
            dropped = true
            break
        end
    end
    if not dropped then return end
    local kept = {}
    for _, entry in ipairs(scrollData) do
        local typeId = entry.typeId
        if typeId and ZO_ScrollList_GetDataTypeTable(list, typeId) then
            kept[#kept + 1] = entry
        end
    end
    ZO_ClearNumericallyIndexedTable(scrollData)
    for _, entry in ipairs(kept) do scrollData[#scrollData + 1] = entry end
end

-- Keybind: drops the cursor straight into the search box of whichever list is open. Searching
-- opens every group, so this is the quickest way to find one item in a full bag.
local SEARCH_BOX_NAMES = {
    [INVENTORY_BACKPACK] = "ZO_PlayerInventorySearchBox",
    [INVENTORY_BANK] = "ZO_PlayerBankSearchBox",
    [INVENTORY_GUILD_BANK] = "ZO_GuildBankSearchBox",
}

function IG.FocusSearch()
    -- A bench first: its box is ours (Craft.lua), and while one is open it is the list in front
    -- of the player whatever the bag behind it is doing.
    local craftType = IG.VisibleCraftStation and IG.VisibleCraftStation()
    local craftBox = craftType and IG.CraftSearchBox and IG.CraftSearchBox(craftType)
    if craftBox and not craftBox:IsHidden() then
        craftBox:TakeFocus()
        return
    end
    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        local box = (inventory and inventory.searchBox) or _G[SEARCH_BOX_NAMES[inventoryType]]
        if box and not box:IsHidden() then
            if box.TakeFocus then box:TakeFocus() else box:SetFocus() end
            return
        end
    end
    -- Nothing open yet: show the bag, and the same key takes the search box next time.
    SCENE_MANAGER:Show("inventory")
end

-- Rebuilds both lists, e.g. after a settings change.
-- Rebuilding a list snaps it back to the top; put it back where the player was. work, when given,
-- runs before the rebuild and may build the list again itself as often as it needs to: the place
-- is read before it starts, so a job that takes several passes still lands back where it was.
local function RefreshKeepingPlace(inventoryType, work)
    if IG.IsCraftType(inventoryType) then
        local craftList = IG.VisibleCraftList and IG.VisibleCraftList()
        KeepingScroll(craftList, function()
            if work and craftList then work(craftList) end
            IG.RefreshCraftLists()
        end)
        return
    end
    local list = PLAYER_INVENTORY.inventories[inventoryType].listView
    KeepingScroll(list, function()
        if work then work(list) end
        PLAYER_INVENTORY:UpdateList(inventoryType, true)
    end)
end

-- The grouped list the player is looking at right now.
local function VisibleInventory()
    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        local list = inventory and inventory.listView
        if list and not list:IsHidden() then return inventoryType, list end
    end
end

IG.VisibleList = VisibleInventory
IG.RefreshKeepingPlace = RefreshKeepingPlace

-- The same, for the header buttons alone: a crafting bench has no bag list on screen, so its
-- own list answers when none of the bag's does.
local function VisibleOrCraft()
    local inventoryType, list = VisibleInventory()
    if inventoryType then return inventoryType, list end
    if IG.VisibleCraftStation then return IG.VisibleCraftStation() end
end
IG.GROUPED_LISTS = GROUPED_INVENTORIES

-- The name a list keeps its own answers under -- what is open in it, whether it gathers what
-- you locked. Its own, whatever layout it happens to be drawn in at the moment.
function IG.InventoryKey(inventoryType)
    return INVENTORY_KEYS[inventoryType]
end

-- The buttons on the game's own bars (Toolbar.lua). Every one of them acts on the list on screen
-- and leaves the others as they were.
-- Where a list's open/closed state is kept: its own, or the one the flat layout in force shares.
local function ListKey(inventoryType)
    -- At a merchant the bag is drawn as the bag, so it keeps the bag's open/closed state.
    if IsTradingLayout() then return "trading" end
    if sv.flatGrouping then return "minimal" end
    return INVENTORY_KEYS[inventoryType]
end

function IG.CollapseVisible()
    local inventoryType, list = VisibleOrCraft()
    if not inventoryType then return end
    local invKey = ListKey(inventoryType)
    CollapseBuiltList(invKey, list)
    -- Any open Chips/Tiles button in this list shuts too, in the same rebuild.
    local open = sv.sectionStripOpen
    if open and invKey and open[invKey] then ZO_ClearTable(open[invKey]) end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    RefreshKeepingPlace(inventoryType)
end

-- The Chips/Tiles buttons on screen in a list that are not open (ModuleStrip.lua).
local function ClosedStripChips(list)
    local chips = {}
    if not list or not list.activeControls then return chips end
    for _, row in ipairs(list.activeControls) do
        if not row:IsHidden() and row.igChips then
            for _, chip in ipairs(row.igChips) do
                local info, strip = chip.igChip, chip.igStrip
                if info and strip and not chip:IsHidden() and strip.openKey ~= info.key then
                    chips[#chips + 1] = chip
                end
            end
        end
    end
    return chips
end

-- The keybind and the settings button: every list, not just the one on screen.
-- Forget that a group was ever closed, in every list: what it starts as then applies again.
function IG.OpenGroupEverywhere(key)
    if not sv or not sv.expanded then return end
    for _, states in pairs(sv.expanded) do states[key] = nil end
end

function IG.CollapseEverything()
    for _, states in pairs(sv.expanded) do ZO_ClearTable(states) end
    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        CollapseBuiltList(ListKey(inventoryType), inventory and inventory.listView)
    end
end

function IG.ExpandVisible()
    local inventoryType, list = VisibleOrCraft()
    if not inventoryType then return end
    local invKey = ListKey(inventoryType)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    RefreshKeepingPlace(inventoryType, function(built)
        for _ = 1, EXPAND_PASSES do
            if not ExpandBuiltList(invKey, built) then return end
            if IG.IsCraftType(inventoryType) then
                IG.RefreshCraftLists()
            else
                PLAYER_INVENTORY:UpdateList(inventoryType, true)
            end
        end
    end)
    -- Chips/Tiles are not opened by this; the closed ones blink, on the rebuilt list.
    local _, shown = VisibleOrCraft()
    IG.BlinkControls(ClosedStripChips(shown or list))
end

function IG.ScrollVisibleToTop()
    local _, list = VisibleOrCraft()
    if not list then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ZO_ScrollList_ScrollAbsolute(list, 0)
end

-- Which slot a tracked id is in right now. A run remembers ids; anything that has to ask the
-- game about the piece itself -- whether it is stolen, say -- needs the slot that holds it.
function IG.SlotForTrackedId(id)
    for _, bagId in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        for slotIndex = 0, GetBagSize(bagId) - 1 do
            if HasItemInSlot(bagId, slotIndex)
                and Id64ToString(GetItemUniqueId(bagId, slotIndex)) == id then
                return bagId, slotIndex
            end
        end
    end
end

function IG.RefreshLists()
    -- Above the line below on purpose: with the addon switched off there are no lists of ours to
    -- rebuild, but the settings page is still open and its preview still has to keep up.
    if IG.RefreshPreview then IG.RefreshPreview() end
    -- The same goes for the buttons that answer a switch: they are on the game's own window and
    -- are still on screen whatever we do to the list under them.
    if IG.RepaintToolbar then IG.RepaintToolbar() end
    if not IG.IsEnabled() then return end
    IG.ClearClassifyCache()
    IG.ClearBindOnEquipCache()
    if IG.ClearResearchableCache then IG.ClearResearchableCache() end
    -- Every list comes back where the player left it. Anything that means to move the view (a
    -- reveal, the Top button, the scroll on opening) scrolls after this returns, so it still wins.
    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        if inventory then
            KeepingScroll(inventory.listView, function()
                PLAYER_INVENTORY.isListDirty[inventoryType] = true
                PLAYER_INVENTORY:UpdateList(inventoryType)
            end)
        end
    end
    KeepingScroll(IG.VisibleCraftList and IG.VisibleCraftList(), IG.RefreshCraftLists)
end

-- How far above the row the view stops: a row on its own against the top edge says where it is
-- but not what it is under, and its category's header is the answer to that.
local REVEAL_LEAD = 90

-- How much light the two washes carry: the category enough to see the whole of it light up,
-- the row enough to be the thing in it you end up looking at.
local CATEGORY_FLASH = 0.38
local ROW_FLASH = 0.85

-- Where the game's own row for a piece is, and where the whole of the category holding it
-- begins and ends, measured down the built list. A module's copy of the same piece carries its
-- bag and slot through a metatable rather than as its own, so the copies are stepped over and
-- the row the piece really has is the one that answers. One walk answers both questions.
local function RevealSpans(list, bagId, slotIndex, anyCopy)
    local y, categoryTop = 0, nil
    local rowTop, rowHeight, blockTop, blockEnd
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local data = entry.data
        local dataType = entry.typeId and ZO_ScrollList_GetDataTypeTable(list, entry.typeId)
        local height = (dataType and dataType.height) or (data and data.rowHeight) or 0
        -- A category starts at its own header. The gap in front of that header stands between
        -- two categories and belongs to neither, so it ends the one before it.
        -- Under Chips/Tiles the open category has no header row; the light heading under the
        -- buttons (ModuleStrip.lua) stands in for it.
        local opens = data ~= nil and ((data.depth == 1 and data.key ~= nil) or data.isStripHeading == true)
        if blockTop and not blockEnd and (opens or entry.typeId == SPACER_TYPE) then blockEnd = y end
        if opens then categoryTop = y end
        -- anyCopy: a module's copy answers too (only when the real row is nowhere in the list).
        local dBag = data and (anyCopy and data.bagId or rawget(data, "bagId"))
        local dSlot = data and (anyCopy and data.slotIndex or rawget(data, "slotIndex"))
        if not rowTop and data and dBag == bagId and dSlot == slotIndex then
            rowTop, rowHeight, blockTop = y, height, categoryTop
        end
        y = y + height
    end
    if not rowTop then return nil end
    return rowTop, rowHeight, blockTop, (blockEnd or y) - (blockTop or 0)
end

-- Rebuild every list, then follow one piece to wherever it landed: open the category it is in
-- and everything inside that down to it, and put the view on the row. A decision about where a
-- piece belongs is worth watching happen; going to look for it afterwards is the same answer
-- given later and less of it.
-- framed (IG.RevealItem): also unshut the category's section and make it the open Chips/Tiles
-- button, and frame header and row together instead of the fixed lead. Returns true once the
-- row was found and the view put on it.
function IG.RevealSlot(bagId, slotIndex, framed)
    watched, watchedPath, watchedType = { bagId = bagId, slotIndex = slotIndex }, nil, nil
    IG.RefreshLists()
    local path, inventoryType = watchedPath, watchedType
    watched, watchedPath, watchedType = nil, nil, nil

    local inventory = inventoryType and PLAYER_INVENTORY.inventories[inventoryType]
    local list = inventory and inventory.listView
    if not (path and list) then return false end

    local invKey = ListKey(inventoryType)
    -- The same opening the fence does for STOLEN: only ever opens. The one thing it can close is
    -- another Chips/Tiles button in the same section, as clicking this one would.
    -- A path node names its group by .id (Classify.lua GroupNode); .key was always nil here, so
    -- under Chips/Tiles the button was never opened and the row never built.
    local key = framed and path[1] and path[1].id
    local section = key and IG.GetGroupSection and IG.GetGroupSection(key)
    if invKey and section then
        SectionStates(invKey)[section] = nil
        sv.sectionStripOpen = sv.sectionStripOpen or {}
        sv.sectionStripOpen[invKey] = sv.sectionStripOpen[invKey] or {}
        sv.sectionStripOpen[invKey][section] = key
    end
    for depth = 1, #path do
        local key = NodeKey(path, depth)
        -- One group open at a time still means one: opening this one closes what stands beside
        -- it, the same way clicking it would have.
        if depth == 1 and sv.accordion and not IsTradingLayout() and not IsExpanded(invKey, key) then
            CollapseSiblings(invKey, key, list)
        end
        SetExpanded(invKey, key, true)
    end
    PLAYER_INVENTORY:UpdateList(inventoryType, true)

    local top, height, blockTop, blockHeight = RevealSpans(list, bagId, slotIndex)
    -- The real row is preferred; only if it is nowhere (its category hidden) does a module's copy do.
    if not top then
        top, height, blockTop, blockHeight = RevealSpans(list, bagId, slotIndex, true)
    end
    if not top then return false end
    local bar = list.scrollbar
    if bar then
        local lowest, highest = bar:GetMinMax()
        local target = top - REVEAL_LEAD
        if framed then
            -- Header at the top edge (the stuck header then covers only itself) when header and
            -- row fit in one view with a row of air under the row; otherwise the row centred.
            local view = list:GetHeight()
            if blockTop and view > 0 and top + height * 2 - blockTop <= view then
                target = blockTop
            else
                target = top + height / 2 - view / 2
            end
        end
        ZO_ScrollList_ScrollAbsolute(list, zo_clamp(target, lowest, highest))
    end

    -- And once it is on screen, it says so: the category lights up and the row in it lights up
    -- brighter, once, in the category's own colour.
    local color = path[1] and path[1].color
    local spans = {}
    if blockTop and blockHeight > 0 then
        spans[#spans + 1] = { top = blockTop, height = blockHeight, color = color, strength = CATEGORY_FLASH }
    end
    spans[#spans + 1] = { top = top, height = height, color = color, strength = ROW_FLASH }
    IG.FlashSpans(list, spans)
    return true
end

-- Where a whole category begins and ends, measured down the built list: its own header, and
-- everything under it as far as the gap that parts it from the next one.
-- A category inside DISPOSAL is found by its own heading one level down, and ends at the next
-- heading at its level or above it.
local function CategorySpan(list, key)
    local y, top, depth = 0, nil, nil
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local data = entry.data
        local dataType = entry.typeId and ZO_ScrollList_GetDataTypeTable(list, entry.typeId)
        local height = (dataType and dataType.height) or (data and data.rowHeight) or 0
        local head = data ~= nil and data.key ~= nil and IS_HEADER_TYPE[entry.typeId] and data.depth
        if top and ((head and head <= depth) or entry.typeId == SPACER_TYPE
            or (data and data.isSection)) then
            return top, y - top
        end
        if not top and head and data.key == key and (head == 1 or data.disposalSub) then
            top, depth = y, head
        end
        y = y + height
    end
    if top then return top, y - top end
end

-- Opens DISPOSAL for one of its categories: its section unshut, its Chips/Tiles button the
-- open one and its heading open. Nothing for a category standing at the top level.
local function OpenDisposalFor(invKey, key, list)
    if not (invKey and IG.InDisposal(key)) then return end
    local disposal = IG.DISPOSAL_KEY
    local section = IG.GetGroupSection and IG.GetGroupSection(disposal)
    if section then
        SectionStates(invKey)[section] = nil
        sv.sectionStripOpen = sv.sectionStripOpen or {}
        sv.sectionStripOpen[invKey] = sv.sectionStripOpen[invKey] or {}
        sv.sectionStripOpen[invKey][section] = disposal
    end
    if sv.accordion and not IsTradingLayout() and not IsExpanded(invKey, disposal) then
        CollapseSiblings(invKey, disposal, list)
    end
    SetExpanded(invKey, disposal, true)
end

-- The same road IG.RevealSlot takes, for a whole category rather than for one piece: open it,
-- put the view on it and let it say so. This is what a line in a drawer jumps by -- the Fence
-- line to STOLEN, the Vendor line to SELL -- and it is deliberately the road that already
-- exists. Nothing here commits a list: the categories are opened, the game is asked to build
-- the list again, and the view is moved afterwards (HANDOFF: the commit is the game's to make).
function IG.RevealGroup(key)
    if not key then return end
    local inventoryType, list = VisibleInventory()
    if not (inventoryType and list) then return end

    local invKey = ListKey(inventoryType)
    -- A category inside DISPOSAL: DISPOSAL is opened first.
    OpenDisposalFor(invKey, key, list)
    if sv.accordion and not IsTradingLayout() and not IsExpanded(invKey, key) then
        CollapseSiblings(invKey, key, list)
    end
    SetExpanded(invKey, key, true)
    PLAYER_INVENTORY:UpdateList(inventoryType, true)

    local top, height = CategorySpan(list, key)
    if not top then return end
    local bar = list.scrollbar
    if bar then
        local lowest, highest = bar:GetMinMax()
        ZO_ScrollList_ScrollAbsolute(list, zo_clamp(top - REVEAL_LEAD, lowest, highest))
    end
    local group = IG.GROUP_BY_KEY[key]
    IG.FlashSpans(list, { { top = top, height = height,
        color = group and IG.GetGroupColor(key) or nil, strength = CATEGORY_FLASH } })
end

-- Public API: IG.RevealItem / IG.RevealItemLink (documented at the top of this file).
-- One reveal pending at a time; a newer call replaces it. The work runs on a polling timer
-- once the inventory scene and the right tab are on screen, never inside the caller's stack.
local REVEAL_TIMER = "InventoryGroupingRevealItem"
local REVEAL_POLL_MS = 100
local REVEAL_MAX_POLLS = 30 -- 3 s for the scene to come up, then give up quietly
local revealPending, revealRunning = nil, false

local function RevealStop()
    EVENT_MANAGER:UnregisterForUpdate(REVEAL_TIMER)
    revealPending = nil
end

-- The craft bag is the game's own list: find the row, centre it, light it.
local function RevealInCraftBag(slotIndex)
    local inventory = PLAYER_INVENTORY.inventories[INVENTORY_CRAFT_BAG]
    local list = inventory and inventory.listView
    if not list then return false end
    local y, top, height = 0, nil, 0
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local data = entry.data
        local dataType = entry.typeId and ZO_ScrollList_GetDataTypeTable(list, entry.typeId)
        local h = (dataType and dataType.height) or 0
        if data and data.bagId == BAG_VIRTUAL and data.slotIndex == slotIndex then
            top, height = y, h
            break
        end
        y = y + h
    end
    if not top then return false end
    local bar = list.scrollbar
    if bar then
        local lowest, highest = bar:GetMinMax()
        ZO_ScrollList_ScrollAbsolute(list, zo_clamp(top + height / 2 - list:GetHeight() / 2, lowest, highest))
    end
    IG.FlashSpans(list, { { top = top, height = height, strength = ROW_FLASH } })
    return true
end

-- A search that hides the piece is cleared (the only thing a reveal ever clears), once.
local function ClearSearch(inventoryType)
    local inventory = PLAYER_INVENTORY.inventories[inventoryType]
    local box = inventory and inventory.searchBox
    if box and box:GetText() ~= "" then
        box:SetText("")
        return true
    end
    return false
end

local function RevealTick()
    local job = revealPending
    if not job or revealRunning then return end
    job.polls = job.polls + 1
    if job.polls > REVEAL_MAX_POLLS or not HasItemInSlot(job.bagId, job.slotIndex) then
        RevealStop()
        return
    end
    if not SCENE_MANAGER:IsShowing("inventory") then return end
    local craft = job.bagId == BAG_VIRTUAL
    local fragment = craft and CRAFT_BAG_FRAGMENT or INVENTORY_FRAGMENT
    if not (fragment and fragment:IsShowing()) then
        if not job.tabAsked and INVENTORY_MENU_BAR and INVENTORY_MENU_BAR.modeBar then
            job.tabAsked = true
            INVENTORY_MENU_BAR.modeBar:SelectFragment(craft and SI_INVENTORY_MODE_CRAFT_BAG
                or SI_INVENTORY_MODE_ITEMS)
        end
        return
    end
    -- One tick of grace after the tab shows: the game's own rebuild and the scroll put back on
    -- showing (WatchBagScenes) go first, so ours is the last word.
    if not job.settled then job.settled = true return end

    revealRunning = true
    local ok, found = pcall(function()
        if craft then return RevealInCraftBag(job.slotIndex) end
        if not IG.IsEnabled() then return false end
        return IG.RevealSlot(job.bagId, job.slotIndex, true)
    end)
    revealRunning = false
    if ok and found then RevealStop() return end
    -- Not in the list: a search may be hiding it. Clear it once and try again a moment later.
    if not job.searchCleared and ClearSearch(craft and INVENTORY_CRAFT_BAG or INVENTORY_BACKPACK) then
        job.searchCleared, job.settled = true, false
        return
    end
    RevealStop()
end

function IG.RevealItem(bagId, slotIndex)
    local ok, result = pcall(function()
        if bagId ~= BAG_BACKPACK and bagId ~= BAG_VIRTUAL then return false end
        if type(slotIndex) ~= "number" or not HasItemInSlot(bagId, slotIndex) then return false end
        RevealStop()
        revealPending = { bagId = bagId, slotIndex = slotIndex, polls = 0 }
        if not SCENE_MANAGER:IsShowing("inventory") then SCENE_MANAGER:Show("inventory") end
        EVENT_MANAGER:RegisterForUpdate(REVEAL_TIMER, REVEAL_POLL_MS, RevealTick)
        return true
    end)
    return ok and result == true
end

function IG.RevealItemLink(itemLink)
    local ok, result = pcall(function()
        if type(itemLink) ~= "string" or itemLink == "" then return false end
        local itemId = GetItemLinkItemId(itemLink)
        local candidates = {}
        for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
            if HasItemInSlot(BAG_BACKPACK, slotIndex) then
                candidates[#candidates + 1] = { BAG_BACKPACK, slotIndex }
            end
        end
        local slotId = GetNextVirtualBagSlotId(nil)
        while slotId do
            candidates[#candidates + 1] = { BAG_VIRTUAL, slotId }
            slotId = GetNextVirtualBagSlotId(slotId)
        end
        -- The exact link first (same quality, level, enchantment...), then the same item id.
        for _, c in ipairs(candidates) do
            if GetItemLink(c[1], c[2]) == itemLink then return IG.RevealItem(c[1], c[2]) end
        end
        if not itemId or itemId == 0 then return false end
        for _, c in ipairs(candidates) do
            if GetItemId(c[1], c[2]) == itemId then return IG.RevealItem(c[1], c[2]) end
        end
        return false
    end)
    return ok and result == true
end

-- Locking a piece changes where it belongs: a locked piece with no set is not garbage
-- (Classify.lua), so it moves to NON-SET ITEMS. The game repaints the one slot it was told
-- about and nothing else, so the list is rebuilt here -- once, not once per item. Each lock
-- restarts a short wait, so locking a handful in a row settles into a single rebuild, and the
-- place the player was looking at is kept.
local LOCK_TIMER = "InventoryGroupingLocked"
local LOCK_SETTLE = 150

local function RebuildAfterLock()
    EVENT_MANAGER:UnregisterForUpdate(LOCK_TIMER)
    IG.ClearClassifyCache()
    -- Every grouped list is holding the old answer. The one on screen is rebuilt now; the rest
    -- are marked so they come back right the next time they are shown.
    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        if PLAYER_INVENTORY.inventories[inventoryType] then
            PLAYER_INVENTORY.isListDirty[inventoryType] = true
        end
    end
    local visible = VisibleInventory()
    if visible then RefreshKeepingPlace(visible) end
    IG.RefreshCraftLists()
end

-- The lock the player puts on an item arrives as an ordinary single slot update carrying a
-- reason of its own; there is no event for it.
local function OnSlotLocked(_, _, _, _, _, inventoryUpdateReason)
    if inventoryUpdateReason ~= INVENTORY_UPDATE_REASON_PLAYER_LOCKED then return end
    EVENT_MANAGER:UnregisterForUpdate(LOCK_TIMER)
    EVENT_MANAGER:RegisterForUpdate(LOCK_TIMER, LOCK_SETTLE, RebuildAfterLock)
end

-- A category that opens pulls the view down with it: what it has just shown should not be left
-- under the bottom edge. The view moves only as far as it has to, and never so far that the
-- header itself goes under the top -- nor under the category header standing stuck there, when
-- what opened is a sub-category. Run after the game has built the list again, never before.
-- matches picks the opened row out of the new list (its data tables are new ones).
-- ZO_ScrollList_ScrollAbsolute is not instant: it starts the list's own 400 ms slide
-- (SetSliderValue in the game's scrolltemplates.lua). KeepingScroll's restore starts one, so a
-- pull measured on the same frame read the bar while it was still sliding and gave up. The pull
-- is therefore measured on the next frame, from where the restore is heading, and slides by
-- itself: a short ease-out, stepping the bar each frame. A wheel turn, a new pull or a rebuild
-- that moves the bar under it stops it.
local PULL_TIMER = "InventoryGroupingPullOpened"
local PULL_MS = 220

local function SlideList(list, from, to)
    local bar = list.scrollbar
    EVENT_MANAGER:UnregisterForUpdate(PULL_TIMER)
    local start, last = GetFrameTimeMilliseconds(), from
    EVENT_MANAGER:RegisterForUpdate(PULL_TIMER, 0, function()
        if list:IsHidden() or list.animationTarget or zo_abs(bar:GetValue() - last) > 0.5 then
            EVENT_MANAGER:UnregisterForUpdate(PULL_TIMER)
            return
        end
        local t = zo_min(1, (GetFrameTimeMilliseconds() - start) / PULL_MS)
        local eased = 1 - (1 - t) * (1 - t) * (1 - t)
        local lowest, highest = bar:GetMinMax()
        last = zo_clamp(from + (to - from) * eased, lowest, highest)
        bar:SetValue(last)
        if t >= 1 then EVENT_MANAGER:UnregisterForUpdate(PULL_TIMER) end
    end)
end

local function MeasurePull(list, matches)
    local bar = list and list.scrollbar
    if not bar or list:IsHidden() then return end
    local y, top, lead, depth, bottom = 0, nil, 0, nil, nil
    local categoryHeight = 0
    for _, entry in ipairs(ZO_ScrollList_GetDataList(list)) do
        local data = entry.data
        local dataType = entry.typeId and ZO_ScrollList_GetDataTypeTable(list, entry.typeId)
        local height = (dataType and dataType.height) or (data and data.rowHeight) or 0
        if top then
            -- The opened part ends at the next row standing at its own level or above it.
            if entry.typeId == SPACER_TYPE or (data and data.isSection)
                or (depth and data and data.depth and data.key ~= nil and data.depth <= depth) then
                bottom = y
                break
            end
        elseif matches(data) then
            top, depth = y, data.depth
            if depth and depth > 1 then lead = categoryHeight end
        elseif data and data.depth == 1 and data.key ~= nil then
            categoryHeight = height
        end
        y = y + height
    end
    if not top then return end
    bottom = bottom or y
    -- Where the bar is heading, not where it is mid-slide; the slide is stopped and settled first.
    local offset = list.animationTarget or bar:GetValue()
    if list.timeline then list.timeline:Stop() end
    if zo_abs(bar:GetValue() - offset) > 0.001 then bar:SetValue(offset) end
    local view = list:GetHeight()
    if bottom <= offset + view then return end
    local lowest, highest = bar:GetMinMax()
    local target = zo_clamp(zo_min(bottom - view, top - lead), lowest, highest)
    if target <= offset then return end
    SlideList(list, offset, target)
end

local function PullOpenedIntoView(list, matches)
    if not list then return end
    EVENT_MANAGER:UnregisterForUpdate(PULL_TIMER)
    EVENT_MANAGER:RegisterForUpdate(PULL_TIMER, 0, function()
        EVENT_MANAGER:UnregisterForUpdate(PULL_TIMER)
        MeasurePull(list, matches)
    end)
end
IG.PullOpenedIntoView = PullOpenedIntoView

-- The list a header belongs to, as it stands now.
local function ListFor(inventoryType)
    if IG.IsCraftType(inventoryType) then return IG.VisibleCraftList and IG.VisibleCraftList() end
    local inventory = PLAYER_INVENTORY.inventories[inventoryType]
    return inventory and inventory.listView
end
IG.ListFor = ListFor

-- What a click on a header does, and what the key over a header does: one thing, written once.
-- shut closes what is open inside it rather than the header itself, which is what shift asks.
-- A section heading: shut or open everything under it. Shift's Collapse All leaves these alone.
function IG.ToggleSection(data)
    if not (data and data.isSection and data.invKey and data.label) then return end
    local states = SectionStates(data.invKey)
    states[data.label] = not states[data.label] or nil
    PlaySound(SOUNDS.DEFAULT_CLICK)
    RefreshKeepingPlace(data.inventoryType)
    -- A heading that is open now was closed a moment ago: bring what it opened up into view.
    if not states[data.label] then
        local label = data.label
        PullOpenedIntoView(ListFor(data.inventoryType), function(row)
            return row ~= nil and row.isSection and row.label == label
        end)
    end
end

-- A top-level category heading that has a Shift+Click (IG.SHIFT_CLICK_ACTIONS).
local function IsShiftClickHeading(data)
    return data ~= nil and data.depth == 1 and not data.isSet
        and IG.SHIFT_CLICK_ACTIONS[data.key] ~= nil
end

function IG.ToggleHeader(data, shut)
    if not (data and data.key) then return end
    local invKey = data.invKey or INVENTORY_KEYS[data.inventoryType]
    local opening = false
    if shut then
        CollapseChildren(invKey, data.key)
    else
        opening = not IsExpanded(invKey, data.key)
        ToggleExpanded(invKey, data.key)
        -- The trading layout keeps everything open; closing one category mustn't close the rest.
        if opening and sv.accordion and not data.compact then
            local inventory = PLAYER_INVENTORY.inventories[data.inventoryType]
            CollapseSiblings(invKey, data.key, inventory and inventory.listView)
        end
    end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    RefreshKeepingPlace(data.inventoryType)
    if opening then
        local key, depth = data.key, data.depth
        PullOpenedIntoView(ListFor(data.inventoryType), function(row)
            return row ~= nil and row.key == key and row.depth == depth
        end)
    end
end

---------------------------------------------------------------------------
-- The key that uses a thing, over a header
---------------------------------------------------------------------------
-- The game answers its own rows with it: hover an item, press it, the item is used. Over one
-- of our headers there is nothing under the mouse as far as the game is concerned, so the key
-- had nothing to answer with. It has now -- the same thing a click on that header does --
-- offered on the strip along the bottom of the window, which is also where it says which of
-- the two it is going to do before you press it.
local HEADER_ACTION = {
    keybind = "UI_SHORTCUT_PRIMARY",
    alignment = KEYBIND_STRIP_ALIGN_RIGHT,
}

local function DropHeaderAction()
    if KEYBIND_STRIP then KEYBIND_STRIP:RemoveKeybindButton(HEADER_ACTION) end
end

-- Taken away and offered again rather than changed where it stands: what it says depends on
-- the header under the mouse, and the strip is told once, when that changes.
local function OfferHeaderAction(data)
    DropHeaderAction()
    if not (KEYBIND_STRIP and data and (data.key or data.isSection)) then return end
    -- A line is not a button: there is nothing to open, and nothing to say about it.
    if data.isRule then return end
    if data.isSection then
        HEADER_ACTION.name = data.shut and "Open" or "Close"
    else
        HEADER_ACTION.name = data.expanded and "Close" or "Open"
    end
    HEADER_ACTION.callback = function()
        DropHeaderAction()
        if data.isSection then IG.ToggleSection(data) else IG.ToggleHeader(data) end
    end
    KEYBIND_STRIP:AddKeybindButton(HEADER_ACTION)
end

-- Pressing it rebuilds the list, so the row the mouse is on is a new row saying the opposite
-- of what it said a moment ago. Dressing a header asks for the offer to be made again when no
-- mouse has moved and nothing else is going to ask (SetupHeaderRow).
IG.RefreshHeaderAction = OfferHeaderAction
IG.DropHeaderAction = DropHeaderAction

function IG.OnHeaderMouseEnter(control)
    IG.SetHeaderSurface(control, control.igHoverColor)
    local data = control.igData
    if not data then return end
    OfferHeaderAction(data)
    if data.isSet and sv.showSetTooltip then
        IG.ShowSetTooltip(control, data)
    end
    SetCollapseHint(control, CanCollapseChildren(data))
    if control.igMenuHint and control.igMenuWidth then
        control.igMenuHint:SetHidden(false)
        -- The drop location stands where the hint does; while the hint shows it steps to the
        -- hint's left rather than being written over.
        local location = control:GetNamedChild("Location")
        if location and not location:IsHidden() and location:GetText() ~= "" then
            location:ClearAnchors()
            location:SetAnchor(RIGHT, control.igMenuHint, LEFT, -BOX_GAP * 2, 0)
            control.igLocationMoved = true
        end
    end
end

function IG.OnHeaderMouseExit(control)
    IG.SetHeaderSurface(control, control.igBgColor)
    DropHeaderAction()
    IG.HideSetTooltip()
    SetCollapseHint(control, false)
    if control.igMenuHint then control.igMenuHint:SetHidden(true) end
    if control.igLocationMoved then
        control.igLocationMoved = nil
        local location = control:GetNamedChild("Location")
        location:ClearAnchors()
        location:SetAnchor(RIGHT, control, TOPRIGHT, -16, control.igLocationY or 0)
    end
end

-- Close one category from somewhere other than its own row. The sticky header's marker does
-- this: what it closes is above the view rather than under the mouse, so there is no row to
-- read it off and the caller says which.
function IG.CloseCategory(inventoryType, invKey, key)
    invKey = invKey or INVENTORY_KEYS[inventoryType]
    if not (invKey and key) then return end
    if IsExpanded(invKey, key) then ToggleExpanded(invKey, key) end
    RefreshKeepingPlace(inventoryType)
end

---------------------------------------------------------------------------
-- Renaming a category from its own header
---------------------------------------------------------------------------
-- What a category is called is already the player's to change (Settings > Groups), but the one
-- category that is nothing except what you put in it is the one that gets renamed, and it gets
-- renamed while you are looking at it. So it can be done from where you are.
local RENAME_DIALOG = "INVENTORY_GROUPING_RENAME"
local renaming

local function RenameEdit()
    local dialog = InventoryGrouping_RenameDialog
    return dialog and dialog:GetNamedChild("FieldEdit")
end

-- The buttons, the enter key and the dialog's own wiring can all reach these, so each is
-- written to happen once and to do nothing at all the second time.
function IG.AcceptRename()
    local key, edit = renaming, RenameEdit()
    renaming = nil
    if not key then return end
    local name = edit and zo_strtrim(edit:GetText()) or ""
    ZO_Dialogs_ReleaseDialog(RENAME_DIALOG)
    -- A setup keeps its name with the character's setups (SetupsUI.lua).
    if IG.RenameSetup and IG.RenameSetup(key, name) then return end
    -- Nothing typed is not a name: the category goes back to the one it was given.
    -- The line is written before the name changes, so it names the category the way it was
    -- called when you asked for it to be renamed.
    IG.UndoStep(string.format("the name of %s", IG.MenuGroupName(key)),
        function() IG.SetGroupSetting(key, "name", name ~= "" and name or nil) end)
    IG.RefreshLists()
    if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
end

function IG.CancelRename()
    if not renaming then return end
    renaming = nil
    ZO_Dialogs_ReleaseDialog(RENAME_DIALOG)
end

function IG.RenameGroup(key)
    if not (InventoryGrouping_RenameDialog and ZO_Dialogs_ShowDialog) then return end
    renaming = key
    ZO_Dialogs_ShowDialog(RENAME_DIALOG)
end

local function InitRenameDialog()
    local dialog = InventoryGrouping_RenameDialog
    if not (dialog and ZO_Dialogs_RegisterCustomDialog) then return end
    ZO_Dialogs_RegisterCustomDialog(RENAME_DIALOG, {
        customControl = dialog,
        title = { text = "Rename this category" },
        setup = function()
            local edit = RenameEdit()
            if not edit then return end
            edit:SetText(renaming and (IG.SetupRenameText and IG.SetupRenameText(renaming)
                or IG.GetGroupLabel(renaming)) or "")
            edit:SelectAll()
        end,
        buttons = {
            { control = dialog:GetNamedChild("Accept"), text = SI_DIALOG_ACCEPT,
              keybind = "DIALOG_PRIMARY", callback = function() IG.AcceptRename() end },
            { control = dialog:GetNamedChild("Cancel"), text = SI_DIALOG_CANCEL,
              keybind = "DIALOG_NEGATIVE", callback = function() IG.CancelRename() end },
        },
    })
end

-- ESO's own colour wheel -- the one the settings page opens, called the way LibAddonMenu's
-- colorpicker widget calls it (controls/colorpicker.lua): the callback first, then the colour
-- the wheel opens on. Alpha is handed in and taken back at 1 and never stored: a half
-- transparent heading is not a colour anybody asked for.
local function PickColor(current, apply)
    if not COLOR_PICKER then return end
    local r, g, b = IG.HexToRGB(current or IG.DEFAULT_ICON_COLOR)
    COLOR_PICKER:Show(function(newR, newG, newB)
        apply(IG.RGBToHex(newR, newG, newB))
        -- The same way every colour change from the settings page lands: the lists are built
        -- again, which throws away the classifier's cached colours with them.
        IG.RefreshLists()
    end, r, g, b, 1)
end
IG.PickColor = PickColor

-- Everything standing under one of those headings that the game will still take the junk mark
-- for. Asked twice -- once to know whether the line is worth putting in the menu, once when it
-- is pressed -- because the two are not the same moment, and in between a piece may have been
-- junked, sold or spent by other means.
local function JunkableOf(members)
    local pieces = {}
    for _, member in ipairs(members or {}) do
        -- The game says what it will not have marked -- a quest item, something bound to a
        -- purpose -- and asking it first is cheaper than being told off once per piece.
        local allowed = CanItemBeMarkedAsJunk == nil
            or CanItemBeMarkedAsJunk(member.bagId, member.slotIndex)
        if allowed and not IsItemJunk(member.bagId, member.slotIndex) then
            pieces[#pieces + 1] = member
        end
    end
    return pieces
end

-- Everything under one of those headings that some crafting station will take apart.
local function DeconstructableOf(members)
    local pieces = {}
    for _, member in ipairs(members or {}) do
        if CanItemBeDeconstructed(member.bagId, member.slotIndex) then
            pieces[#pieces + 1] = member
        end
    end
    return pieces
end

-- GARBAGE is the heading that offers something done to the whole of what is under it. What is
-- in it is what you have already agreed you do not want, so saying it once is one press instead
-- of one per row, sub-categories and all. There are two ways of being done with a thing -- sell
-- it or throw it away -- and the heading offers both, in that order: what is worth a coin is
-- worth the coin whether or not you also junk it, and junking is the answer for what is not.
-- Nothing is asked first in either case: both are taken back as easily as they are given, and a
-- window in the way of that is a window in the way of everything. Either line is left out where
-- it has nothing to touch -- a line that does nothing when pressed has to be read twice to find
-- that out.
--
-- The pieces are handed in as a function rather than a list, because both lines ask again when
-- they are pressed. The menu was built at one moment and the press happens at another, and in
-- between a piece may have been junked, sold or spent.
local function AddWholeGroupItems(AllMembers)
    -- A piece a crafting writ is waiting for lives in DAILY WRIT, not here; should one still be
    -- listed under the heading, no line below sells, breaks or junks it (DailyWrit.lua).
    local function Members()
        local kept = {}
        for _, member in ipairs(AllMembers()) do
            if not (IG.IsDailyWritItem and IG.IsDailyWritItem(member)) then kept[#kept + 1] = member end
        end
        return kept
    end
    if #Members() == 0 then return end

    -- Sold rather than thrown away. It is the player's own answer about each piece, so it goes
    -- where every hand-moved piece goes, and the list is built again afterwards because not one
    -- of them belongs in the row it is sitting in. Offered only while there is somewhere to
    -- send them: a category switched off is not a destination.
    if IG.IsGroupAvailable("SELL") then
        AddMenuItem("Move all to " .. IG.MenuGroupName("SELL"), function()
            -- One line moved them and one press hands them back: what a heading did to the
            -- whole of what is under it is one thing done, however many rows it was.
            IG.UndoStep(nil, function()
                local moved = 0
                for _, member in ipairs(Members()) do
                    local pieceId = IG.PieceId(member.bagId, member.slotIndex)
                    if pieceId then
                        IG.NoteSaved(IG.sv.overrides.items, pieceId)
                        IG.sv.overrides.items[pieceId] = "SELL"
                        -- Same reason the single line has: the mark belongs to the pile a piece
                        -- is waiting in, not to the piece.
                        IG.SetAwaitingReason(pieceId, nil)
                        moved = moved + 1
                    end
                end
                if moved > 0 then
                    return string.format("%s moved to %s", IG.UndoPieces(moved),
                        IG.MenuGroupName("SELL"))
                end
            end)
            IG.RefreshLists()
        end)
    end

    -- Taken apart rather than sold: the same move, for only the pieces a station will take.
    -- The game says which ones (CanItemBeDeconstructed, craft type left out so any station
    -- counts); the rest stay where they are. Counted twice for the reason the junk line is.
    if IG.IsGroupAvailable("DECON") and CanItemBeDeconstructed then
        local decon = DeconstructableOf(Members())
        if #decon > 0 then
            AddMenuItem(string.format("Move %d to %s", #decon, IG.MenuGroupName("DECON")), function()
                IG.UndoStep(nil, function()
                    local moved = 0
                    for _, member in ipairs(DeconstructableOf(Members())) do
                        local pieceId = IG.PieceId(member.bagId, member.slotIndex)
                        if pieceId then
                            IG.NoteSaved(IG.sv.overrides.items, pieceId)
                            IG.sv.overrides.items[pieceId] = "DECON"
                            IG.SetAwaitingReason(pieceId, nil)
                            moved = moved + 1
                        end
                    end
                    if moved > 0 then
                        return string.format("%s moved to %s", IG.UndoPieces(moved),
                            IG.MenuGroupName("DECON"))
                    end
                end)
                IG.RefreshLists()
            end)
        end
    end

    if #JunkableOf(Members()) == 0 then return end
    AddMenuItem("Mark all as " .. IG.MenuGroupName("JUNK"), function()
        IG.UndoStep(nil, function()
            local pieces = JunkableOf(Members())
            for _, piece in ipairs(pieces) do
                IG.MarkItemAsJunk(piece.bagId, piece.slotIndex)
            end
            if #pieces > 0 then
                return string.format("%s marked as %s", IG.UndoPieces(#pieces),
                    IG.MenuGroupName("JUNK"))
            end
        end)
        -- No list is built from here. Junking takes a piece out of every other tab, so the game
        -- rebuilds after the mark itself, and a list built from inside our own frame is the
        -- whole of the insecure callstack trouble (see Junk.lua, and HANDOFF section 5).
    end)
end

-- Everything the build put in one of the categories that act on the whole of themselves, sub-
-- categories and all: what the category holds is known by its key alone.
local function AddGroupActionItems(data)
    local invKey = data.invKey or INVENTORY_KEYS[data.inventoryType]
    local function Members() return (groupMembers[invKey] or {})[data.key] or {} end
    -- The selling layout's Sell heading gets one line and none of the two above, which would
    -- both read as nonsense over it: a category cannot be moved into itself, and what you have
    -- already decided to sell is the last pile to be throwing away. Its line is the only one in
    -- the addon that parts with your things, so it lives with the layout it belongs to.
    -- The bag's own SELL heading offers it too; the line answers only at a merchant.
    if data.key == "TRADE_SELL" or data.key == "SELL" then
        if IG.AddSellAllItem then IG.AddSellAllItem(Members) end
        return
    end
    AddWholeGroupItems(Members)
end

-- What is standing under one heading inside JUNK and still wearing the mark. Asked twice, the
-- same as the marking lines above and for the same reason: the menu is built at one moment and
-- pressed at another, and in between a piece may have been sold, spent or taken out of junk by
-- the game's own row menu.
local function JunkedUnder(data)
    local invKey = data.invKey or INVENTORY_KEYS[data.inventoryType]
    local pieces = {}
    for _, member in ipairs((junkMembers[invKey] or {})[data.key] or {}) do
        if IsItemJunk(member.bagId, member.slotIndex) then pieces[#pieces + 1] = member end
    end
    return pieces
end

-- Taking a whole heading back out of JUNK. The mark goes on in sweeps -- the game's own auto
-- junk, the stolen rubbish switch, the "Mark all" lines above -- so it is regretted in sweeps
-- too, and one press per row is the wrong shape for undoing something that was never done a row
-- at a time. Every heading inside JUNK is offered it, the category itself included: what JUNK is
-- broken into follows a setting, and a JUNK left as one flat list has no sub-heading to click.
--
-- Where the pieces land is not decided here and does not need to be. The mark is the only thing
-- that was holding them in JUNK, so taking it off leaves each of them in the category it would
-- have been classified into all along. Nothing is asked first: this is itself the answer to a
-- press that has been regretted, and a window in front of it would be a window in front of the
-- one line here that undoes something.
local function AddUnjunkItems(data)
    if not data.key then return end
    if #JunkedUnder(data) == 0 then return end
    AddMenuItem("Unmark all as " .. IG.MenuGroupName(JUNK_ACTION_KEY), function()
        IG.UndoStep(nil, function()
            local pieces = JunkedUnder(data)
            for _, piece in ipairs(pieces) do
                IG.UnmarkItemAsJunk(piece.bagId, piece.slotIndex)
            end
            if #pieces > 0 then
                return string.format("%s taken out of %s", IG.UndoPieces(#pieces),
                    IG.MenuGroupName(JUNK_ACTION_KEY))
            end
        end)
        -- No list is built from here, the same as the marking line. Taking the mark off puts a
        -- piece back on every other tab, so the game rebuilds after the mark itself, and a list
        -- built from inside our own frame is the whole of the insecure callstack trouble (see
        -- Junk.lua, and HANDOFF section 5).
    end)
end

-- One of DISPOSAL's categories moved out to the top level, or back in: per category, kept
-- account-wide (Colors.lua: IG.SetDisposalOut). Not in the flat layouts, which have no DISPOSAL.
local function AddDisposalItems(data)
    if not (data.key and IG.DISPOSAL_MEMBERS[data.key]) or data.compact then return end
    local inside
    if data.disposalSub then
        inside = true
    elseif data.depth == 1 and not IG.InDisposal(data.key) then
        inside = false
    else
        return
    end
    local key = data.key
    AddMenuItem(inside and "Move Out of Disposal" or "Move Into Disposal", function()
        IG.UndoStep(string.format("where %s stands", IG.MenuGroupName(key)),
            function() IG.SetDisposalOut(key, inside) end)
        -- Through the game's own refresh, never committed from inside our frame.
        IG.RefreshLists()
    end)
end

-- RECENT LOOT lifted to the head of ATTENTION from its own menu, and put back where it stood.
-- The same two settings the Heading picker writes (sv.groups.LASTRUN: section, order), with
-- what they held before kept beside them as attentionFrom, so Move Out returns it to the very
-- place it left -- under MODULES, or wherever the player had sent it. Not in the flat layouts,
-- which have no headings to move between.
local ATTENTION_SECTION = "ATTENTION"
local ATTENTION_MOVABLE = { LASTRUN = true }

local function AddAttentionItems(data)
    if not (IsCategoryHead(data) and ATTENTION_MOVABLE[data.key]) or data.compact then return end
    if not (IG.SectionsOn() and sv.groups) then return end
    local key = data.key
    local entry = sv.groups[key]
    local from = entry and entry.attentionFrom
    local inside = IG.GetGroupSection(key) == ATTENTION_SECTION
    if inside and not from then return end -- sent there from the settings page: moved back there
    AddMenuItem(inside and "Move Out of Attention" or "Move Into Attention", function()
        IG.UndoStep(string.format("where %s stands", IG.MenuGroupName(key)), function()
            if inside then
                IG.SetGroupSetting(key, "section", from.section)
                IG.SetGroupSetting(key, "order", from.order)
                IG.SetGroupSetting(key, "attentionFrom", nil)
                return
            end
            -- Above every other category of the heading, whichever of them this list draws.
            local first
            for _, group in ipairs(IG.GROUPS) do
                if group.key ~= key and IG.GetGroupSection(group.key) == ATTENTION_SECTION then
                    local order = IG.GetGroupOrder(group.key)
                    if not first or order < first then first = order end
                end
            end
            IG.SetGroupSetting(key, "attentionFrom",
                { section = entry and entry.section, order = entry and entry.order })
            IG.SetGroupSetting(key, "section", ATTENTION_SECTION)
            IG.SetGroupSetting(key, "order", (first or 1) - 1)
        end)
        -- Through the game's own refresh, never committed from inside our frame.
        IG.RefreshLists()
        if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
    end)
end

-- What a category is broken into is the one thing in its menu that is neither about the pieces
-- standing under it nor about the colour it wears, so the lines saying it are lettered in a
-- colour of their own and read as a group of three.
local SPLIT_MENU_COLOR = "6FD3E8"

-- Only a category with no headings of its own is asked, and only one that is drawing rows
-- today: a category already broken up by the classifier has an arrangement somebody thought
-- about, and a second one laid over it would be two answers to one question.
--
-- The category's own answer beats the setting in both directions, which is the whole point of
-- having it: a bag where one long list wants breaking up and another wants leaving alone is
-- the ordinary case, and a single number cannot say that. The third line is only there once
-- there is an answer to take back -- a line that undoes nothing is a line read twice to find
-- that out.
local function AddSplitItems(data)
    if not data.canSplit or not data.key then return end
    local function Say(text, choice)
        AddMenuItem(string.format("|c%s%s|r", SPLIT_MENU_COLOR, text), function()
            IG.UndoStep(string.format("the way %s is broken up", IG.MenuGroupName(data.key)),
                function() IG.SetSplitChoice(data.key, choice) end)
            -- The same road every other line here takes home: the lists are built again from
            -- the game's own refresh, never committed from inside our frame.
            IG.RefreshLists()
        end)
    end
    Say("Split by type", "split")
    Say("Merge into one list", "merge")
    if IG.SplitChoice(data.key) then Say("Follow the setting", nil) end
end

-- And how the sets under it are drawn, which is the other thing about a category's shape rather
-- than about its pieces or its colour, so it is lettered in the same colour as the lines above
-- and read as a group with them.
--
-- The two shapes are the two Don't Group Sets already makes and no others: a line with the
-- set's name on it and its pieces standing under it, or a button that opens and closes. Only a
-- category that actually holds sets is asked, and the answer is this window's own -- the bank
-- splitting its sets apart while the bag gathers them into buttons is the whole point of
-- asking here rather than on the settings page. The third line is only there once there is an
-- answer to hand back.
local function AddSetViewItems(data)
    if not data.hasSets or not data.key or data.compact then return end
    local listKey = INVENTORY_KEYS[data.inventoryType]
    if not listKey then return end
    local function Say(text, choice)
        AddMenuItem(string.format("|c%s%s|r", SPLIT_MENU_COLOR, text), function()
            -- A category inside LOCKED is named as itself, not by its "LOCKED/..." key.
            local named = data.key:match("^LOCKED/(.+)$") or data.key
            IG.UndoStep(string.format("the way %s draws its sets", IG.MenuGroupName(named)),
                function() IG.SetSetViewChoice(listKey, data.key, choice) end)
            -- The same road the lines above take home: the list is built again from the game's
            -- own refresh, never committed from inside our frame.
            IG.RefreshLists()
        end)
    end
    -- Grouping is the button: a set that gathers its pieces behind a name you open and close.
    -- Not grouping is the line: the name on a divider and every piece of it out in the open.
    Say("Group Sets", IG.SET_VIEW_BUTTONS)
    Say("Don't Group Sets", IG.SET_VIEW_DIVIDERS)
    if IG.SetViewChoice(listKey, data.key) then Say("Back to default", nil) end
end

-- The two colour lines every heading's menu ends with, written in the colour the heading is
-- wearing at that moment, so the menu shows what it is about to change rather than saying it.
-- The second line is only there when there is something to take back.
local function AddColorItems(data)
    local painted, write, named
    if data.isSet and data.setId then
        painted = IG.GetManualSetColor(data.setId)
        write = function(hex) IG.SetManualSetColor(data.setId, hex) end
        named = "a set's colour"
    elseif IsCategoryHead(data) then
        -- A trading heading carries the layout's own key, and a LOCKED one carries "LOCKED/<id>"
        -- (NodeKey) rather than its plain id; the colour belongs to the real category either way,
        -- and one that stands for none has no colour to change.
        local key = data.lockedSub and data.lockedGroupKey or data.key
        if IG.TradingSourceKey then key = IG.TradingSourceKey(key) end
        if not key or not IG.GROUP_BY_KEY[key] then return end
        painted = IG.sv.groups[key] and IG.sv.groups[key].color
        write = function(hex) IG.SetGroupSetting(key, "color", hex) end
        named = string.format("the colour of %s", IG.MenuGroupName(key))
    elseif data.key then
        painted = IG.GetManualSubColor(data.key)
        write = function(hex) IG.SetManualSubColor(data.key, hex) end
        named = "a sub-heading's colour"
    else
        return
    end
    -- Both lines write the colour the same way, so both are taken back the same way: one step
    -- under one line, whichever of the two put the colour there.
    local function apply(hex)
        IG.UndoStep(named, function() write(hex) end)
    end
    local shown = data.color or IG.DEFAULT_ICON_COLOR
    AddMenuItem(string.format("|c%sChange this colour|r", shown), function()
        PickColor(painted or shown, apply)
    end)
    if painted then
        AddMenuItem(string.format("|c%sReset this colour|r", shown), function()
            apply(nil)
            IG.RefreshLists()
        end)
    end
end

-- The same two lines for a whole section at once, asked from the section heading's own menu
-- (ModuleStrip.lua). Only the top-level categories standing under it are painted -- the ones the
-- section is made of; their sub-headings and sets keep whatever colour they have. The whole
-- batch is one step, so a single ctrl+z hands every category its old colour back.
--
-- LOCKED is the one heading this cannot answer by IG.GROUP_BY_KEY section alone: it is its own
-- section (DEFAULT_SECTION, Colors.lua), but what reads under it is not a LOCKED category -- it
-- is whatever category each locked piece would stand in on its own (DUNGEON, ARENA, NONSET, ...),
-- in the section it actually belongs to. Asking by section would paint only the LOCKED heading
-- itself and nothing a player can see move. lockedCategoryKeys says what is really on screen.
local function SectionGroupKeys(section, invKey)
    if section == "LOCKED" then
        local keys = {}
        for key in pairs(lockedCategoryKeys[invKey] or {}) do keys[#keys + 1] = key end
        return keys
    end
    local keys = {}
    for key in pairs(IG.GROUP_BY_KEY) do
        if IG.GetGroupSection(key) == section then keys[#keys + 1] = key end
    end
    return keys
end

function IG.AddSectionColorItems(section, invKey)
    if not (section and IG.sv and IG.sv.groups) then return end
    local keys = SectionGroupKeys(section, invKey)
    if #keys == 0 then return end
    local function paintAll(hex)
        IG.UndoStep(string.format("the colours under %s", section), function()
            for _, key in ipairs(keys) do IG.SetGroupSetting(key, "color", hex) end
        end)
    end
    AddMenuItem("Color All Categories...", function()
        PickColor(IG.DEFAULT_ICON_COLOR, paintAll)
    end)
    local anyPainted = false
    for _, key in ipairs(keys) do
        if IG.sv.groups[key] and IG.sv.groups[key].color then anyPainted = true; break end
    end
    if anyPainted then
        AddMenuItem("Reset Category Colors", function()
            IG.UndoStep(string.format("the colours under %s", section), function()
                for _, key in ipairs(keys) do
                    -- Only the ones that have a colour of their own: a note for an untouched
                    -- category would give it an empty settings entry it never had.
                    if IG.sv.groups[key] and IG.sv.groups[key].color then
                        IG.SetGroupSetting(key, "color", nil)
                    end
                end
            end)
            IG.RefreshLists()
        end)
    end
end

-- Every set under LOCKED opened or shut in one go, from the LOCKED heading's menu. Each set is
-- written down the way a click on it writes it (the same per-list state), the categories between
-- LOCKED and its sets are not touched, and the list is rebuilt once at the end.
local function SetAllLockedSets(invKey, inventoryType, open)
    local keys = lockedSetKeys[invKey]
    if not keys then return end
    for _, key in ipairs(keys) do SetExpanded(invKey, key, open) end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    RefreshKeepingPlace(inventoryType)
end

-- Only the line that has something to do: Expand while some set is shut, Collapse while some set
-- is open (both when it is mixed). Nothing at all while LOCKED holds no set that can be opened.
local function AddLockedSetItems(invKey, inventoryType)
    local keys = invKey and lockedSetKeys[invKey]
    if not (keys and #keys > 0) then return end
    local open = 0
    for _, key in ipairs(keys) do
        if IsExpanded(invKey, key) then open = open + 1 end
    end
    if open < #keys then
        AddMenuItem("Expand all sets", function() SetAllLockedSets(invKey, inventoryType, true) end)
    end
    if open > 0 then
        AddMenuItem("Collapse all sets", function() SetAllLockedSets(invKey, inventoryType, false) end)
    end
end
-- Also asked from the LOCKED section divider's own menu (ModuleStrip.lua).
IG.AddLockedSetItems = AddLockedSetItems

function IG.OnHeaderMouseUp(control, button, upInside)
    local data = control.igData
    if not upInside or not data then return end
    if button == MOUSE_BUTTON_INDEX_RIGHT then
        if not HeaderHasMenu(data) then return end
        ClearMenu()
        -- EQUIPPED's "Save as Setup" and a setup's own lines (SetupsUI.lua).
        if IG.AddSetupHeaderMenu then IG.AddSetupHeaderMenu(data) end
        if data.menu == "pileRun" then
            AddMenuItem("Distribute items", function()
                IG.DistributePileFromRun(data.menuRun, data.menuPile)
            end)
        elseif data.isSet then
            -- Opening and shutting the set from its menu: the same toggle (and the same saved
            -- per-list state) as a left click, offered here because a set row reads like a line
            -- of information and nothing on it says it opens.
            AddMenuItem(data.expanded and "Collapse set" or "Expand set", function()
                IG.ToggleHeader(data)
            end)
            -- The set's own two lines, moving it to another category and back. They need
            -- LibCustomMenu (a submenu), so without it the menu is the colours alone rather
            -- than nothing at all. The link one of its pieces was read off goes with them, so
            -- the menu can ask what colour the set is without asking the set itself, which
            -- would answer for good.
            IG.AddSetMenuEntries(data.setId, data.label, data.summary and data.summary.link)
        elseif IsCategoryHead(data) and HasMenu(data.key) then
            if MENU_GROUPS[data.key] then
                AddMenuItem("Distribute items", data.key == "NEW" and IG.DistributeNew or IG.DistributeLastRun)
            end
            if data.key == "NEW" then
                -- Only offered while NEW holds something it would take out.
                local unnecessary = CountUnnecessaryNew()
                if unnecessary > 0 then
                    AddMenuItem(string.format("Distribute |cFF9933Only|r Unnecessary (%d)", unnecessary),
                        function() IG.DistributeUnnecessaryNew() end)
                end
            end
            -- The categories whose name is the whole of what they say.
            if RENAME_GROUPS[data.key] then
                AddMenuItem("Rename this category", function() IG.RenameGroup(data.key) end)
            end
            local module = MODULE_GROUPS[data.key]
            if data.key == "BINDONEQUIP" then
                -- The same switch as on the settings page, said the way the list stands now.
                local shown = IG.sv.bindOnEquipShowGuild
                AddMenuItem(shown and "Hide Guild Store Pieces" or "Show Guild Store Pieces", function()
                    IG.sv.bindOnEquipShowGuild = not shown
                    IG.RefreshLists()
                    if IG.RefreshSettingsPanel then IG.RefreshSettingsPanel() end
                end)
            end
            if data.key == "LOCKED" then
                AddLockedSetItems(data.invKey or INVENTORY_KEYS[data.inventoryType], data.inventoryType)
                -- This list's answer, not every list's: the bank can go on gathering them.
                -- The heading is only ever on screen while this list is gathering them, so
                -- "off" has one meaning here out of the three the button steps through: put
                -- them back in the categories they belong to. It never hides anything --
                -- nothing reached from a heading should make that heading's items vanish.
                AddMenuItem("Turn this off for this list", function()
                    IG.SetLockedSeparated(data.invKey or INVENTORY_KEYS[data.inventoryType], false)
                    IG.RefreshLists()
                    IG.RepaintToolbar()
                end)
            elseif module then
                -- It comes back from the settings page (Modules). TO BANK's switch only hides
                -- it, so the line says that rather than turning anything off.
                AddMenuItem(data.key == "TOBANK" and "Hide TO BANK" or "Turn this module off", function()
                    IG.SetModuleEnabled(module, false)
                end)
            end
        elseif IsCategoryHead(data) and ACTION_GROUPS[data.key] then
            AddGroupActionItems(data)
        end
        AddDisposalItems(data)
        AddAttentionItems(data)
        -- The one line that is about the items but belongs to no branch above: every heading
        -- inside JUNK carries it, at whatever depth the category happens to be broken to today.
        AddUnjunkItems(data)
        -- What the heading does with its items comes first, what it is shaped like next and
        -- what it looks like after: the colour is the line you are least likely to have opened
        -- the menu for. Asked of every category rather than inside one of the branches above,
        -- since which ones can be broken up cuts across all of them.
        AddSplitItems(data)
        AddSetViewItems(data)
        AddColorItems(data)
        AddMenuItem(IG.CANCEL_LABEL, function() end)
        ShowMenu(control)
        return
    end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    local shut = IsShiftKeyDown()
    if shut and IsShiftClickHeading(data) then
        -- NEW and RECENT LOOT: Shift+Click distributes instead of Collapse All; nothing toggles.
        IG.DistributeDelayed(control, data.key)
        return
    end
    IG.ToggleHeader(data, shut)
end

-- A saved house chest item: icon, stack size and name; the tooltip shows the full item.
local function SetupStoredRow(control, data)
    control.igData = data
    IG.ApplyFrames(control, data.igFrames, true)
    control:GetNamedChild("Icon"):SetTexture(GetItemLinkIcon(data.link))
    control:GetNamedChild("Count"):SetText(data.count > 1 and data.count or "")
    -- A setup's "missing" / "in bank" line is drawn faded (Setups.lua); pooled rows reset.
    control:SetAlpha(data.igFaded and 0.5 or 1)
    local name = control:GetNamedChild("Name")
    name:SetText(data.name)
    name:SetColor(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, GetItemLinkDisplayQuality(data.link)))
end

function IG.OnStoredRowMouseEnter(control)
    local data = control.igData
    if not data then return end
    InitializeTooltip(ItemTooltip, control, RIGHT, -5, 0, LEFT)
    ItemTooltip:SetLink(data.link)
end

function IG.OnStoredRowMouseExit()
    ClearTooltip(ItemTooltip)
end

-- The height each of our row types is laid out with, at the density in force.
local function RowHeights()
    local heights = {
        [TRADE_HEADER_TYPE] = metrics.headers[TRADE_HEADER_LOOK],
        [SET_TYPE] = SetRowHeight(),
        [SET_TYPE_WITH_PIECES] = SetRowHeight(),
        [SECTION_TYPE] = metrics.section,
        [SET_RULE_TYPE] = metrics.setRule,
        [SPACER_TYPE] = metrics.spacer,
        [SUB_SPACER_TYPE] = metrics.subSpacer,
        [SUB_FOOT_TYPE] = metrics.foot,
        [STORED_ITEM_TYPE] = STORED_ITEM_HEIGHT, -- the saved item row's art is a fixed size
    }
    for depth, typeId in ipairs(HEADER_TYPES) do heights[typeId] = metrics.headers[depth] end
    heights[TALL_HEADER_TYPE] = zo_floor(metrics.headers[1] * TALL_HEADER_SCALE + 0.5)
    return heights
end

local registeredLists = {}

local function RegisterHeaderTypes(listView)
    local heights = RowHeights()
    registeredLists[#registeredLists + 1] = listView
    for _, typeId in ipairs(HEADER_TYPES) do
        ZO_ScrollList_AddDataType(listView, typeId, "InventoryGrouping_HeaderRow", heights[typeId], SetupHeaderRow)
    end
    ZO_ScrollList_AddDataType(listView, TRADE_HEADER_TYPE, "InventoryGrouping_HeaderRow",
        heights[TRADE_HEADER_TYPE], SetupHeaderRow)
    ZO_ScrollList_AddDataType(listView, TALL_HEADER_TYPE, "InventoryGrouping_HeaderRow",
        heights[TALL_HEADER_TYPE], SetupHeaderRow)
    ZO_ScrollList_AddDataType(listView, SET_TYPE, "InventoryGrouping_HeaderRow", heights[SET_TYPE], SetupHeaderRow)
    ZO_ScrollList_AddDataType(listView, SET_TYPE_WITH_PIECES, "InventoryGrouping_HeaderRow",
        heights[SET_TYPE_WITH_PIECES], SetupHeaderRow)
    ZO_ScrollList_AddDataType(listView, SECTION_TYPE, "InventoryGrouping_Spacer", heights[SECTION_TYPE],
        SetupSectionRow)
    ZO_ScrollList_AddDataType(listView, SET_RULE_TYPE, "InventoryGrouping_Spacer", heights[SET_RULE_TYPE],
        SetupSetRuleRow)
    ZO_ScrollList_AddDataType(listView, SPACER_TYPE, "InventoryGrouping_Spacer", heights[SPACER_TYPE], function() end)
    ZO_ScrollList_AddDataType(listView, STORED_ITEM_TYPE, "InventoryGrouping_StoredItemRow",
        heights[STORED_ITEM_TYPE], SetupStoredRow)
    ZO_ScrollList_AddDataType(listView, SUB_FOOT_TYPE, "InventoryGrouping_Spacer", heights[SUB_FOOT_TYPE],
        function(control, data)
            control:SetHeight(metrics.foot)
            IG.ApplyFrames(control, data.igFrames, true)
        end)
    ZO_ScrollList_AddDataType(listView, SUB_SPACER_TYPE, "InventoryGrouping_Spacer", heights[SUB_SPACER_TYPE],
        function(control, data)
            control:SetHeight(metrics.subSpacer)
            IG.ApplyFrames(control, data.igFrames, true)
        end)
    if IG.RegisterModuleStripTypes then IG.RegisterModuleStripTypes(listView) end
end

-- Changing the density only changes the height each list lays our rows out with. Registering the
-- types again would build a second control pool under the same names, so the heights that are
-- already registered are edited in place instead.
function IG.ApplyRowDensity()
    metrics = DENSITY[sv.rowDensity] or DENSITY.normal
    local heights = RowHeights()
    for _, list in ipairs(registeredLists) do
        for typeId, height in pairs(heights) do
            local dataType = ZO_ScrollList_GetDataTypeTable(list, typeId)
            if dataType then dataType.height = height end
        end
    end
end

-- Crafting stations register the same row types and row decoration on their own lists.
IG.RegisterRowTypes = RegisterHeaderTypes
IG.HookRowSetup = HookItemRows

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

-- The order we laid the rows out in, kept through the sort the game is about to do.
--
-- We used to commit the list ourselves and tell the game its own sort had already happened.
-- The last thing ZO_ScrollList_Commit does is run OnMouseEnter again for whatever the pointer
-- is already sitting on (CheckRunHandler), and for an item row that rebuilds the slot's
-- actions -- so the "deposit this" the keybind then holds was a function born while our Lua
-- was on the stack. The game calls such a function insecure and refuses the protected move
-- inside it: the first item you sent to the bank with the key went, and the second threw
-- "Attempt to access a private function 'PickupInventoryItem' from insecure code".
--
-- So the list is ours to lay out and the commit is the game's to make. Every row is numbered
-- as it is built, the manager is handed a comparator that keeps that numbering, and its own
-- ApplySort does the sorting and the committing -- by which time our hook has returned and
-- the only thing on the stack is the game's own hook wrapper.
-- Set when the player clicks a column header while the selling layout is up; until then its
-- categories keep their own order (Trading.lua). Every visit starts without it.
local tradingHeaderClicked = false

-- What each list was last built with (ApplySortHook). A plain ApplySort that finds our own
-- rows on a list built moments ago with the same layout and the same sort -- the bag opening
-- asks for one right after its UpdateList -- only needs the game's own sort by the kept order
-- and its commit, not a second build of the whole list.
local lastBuild = {}
local REBUILD_WINDOW_MS = 500

-- The game's header click goes ChangeSort -> ApplySort (inventory.lua); ApplySort is ours to
-- rebuild through, so this only notes that the click happened and returns nothing.
local function NoteHeaderSort()
    if IsTrading() then tradingHeaderClicked = true end
    ZO_ClearTable(lastBuild)
end

local function KeepBuiltOrder(first, second)
    return (first.igOrder or 0) < (second.igOrder or 0)
end

-- A list nobody can see is not built. The game asks for the bag's list again on every slot
-- update -- each piece looted from a box, each stack that grows -- with the bag shut, and a
-- build is the most expensive thing this addon does: profiled, one loot frame in the field was
-- 103 ms of ours. So a list that is off screen only notes that it is owed one, and is built
-- when it is shown.
--
-- "Off screen" is asked of the control (IsControlHidden: itself or any parent) and, because the
-- fragment says SHOWING while the window it shows is still hidden (Drawer.lua, CreateDrawers),
-- also of what is about to show it: the bag's fragment, or a bank's scene. The game's own
-- rebuild on opening comes in during SHOWING and goes through exactly as before.
local LIST_SCENES = {
    [INVENTORY_BANK] = "bank",
    [INVENTORY_GUILD_BANK] = "guildBank",
    [INVENTORY_HOUSE_BANK] = "houseBank",
}

local function ListOnScreen(inventory, inventoryType)
    local list = inventory.listView
    if not list or not list:IsControlHidden() then return true end
    if inventoryType == INVENTORY_BACKPACK then
        return INVENTORY_FRAGMENT ~= nil and INVENTORY_FRAGMENT:IsShowing()
    end
    local scene = LIST_SCENES[inventoryType]
    return scene ~= nil and (SCENE_MANAGER:IsShowing(scene) or SCENE_MANAGER:IsShowingNext(scene))
end

-- [inventoryType] = true while a build was skipped and none has been done since.
local owedBuild = {}

-- The fallback for an owed build the game does not do itself on opening: once the list is
-- really on screen (a frame after it is shown, so the game's own opening rebuild goes first and
-- clears the debt if it comes), the list is built here. Nothing happens if it was paid already.
local function PayOwedBuild(inventoryType)
    if not owedBuild[inventoryType] then return end
    zo_callLater(function()
        if not owedBuild[inventoryType] then return end
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        local list = inventory and inventory.listView
        if not list or list:IsControlHidden() then return end
        PLAYER_INVENTORY:UpdateList(inventoryType, true)
        -- The counts the toolbar shows come out of the build, which came after its own pass.
        if IG.RepaintToolbar then IG.RepaintToolbar() end
    end, 0)
end

-- Selling at a merchant or a fence empties one slot per sale, and the game answers each one
-- with UpdateList: the list is refilled with the bag's raw rows and handed to ApplySort, which
-- ran the whole grouped build again -- measured in the field, a 51-59 ms frame on nearly every
-- sale at the fence. A sale changes nothing but which pieces are there, so the rows of the last
-- build are kept and the sold ones dropped from them (DropSoldRows): the piece leaves the list
-- on the frame it is sold, and nothing else moves. The headings' counts, the set badges and the
-- module numbers are the build's, so one real build follows once the selling has paused for
-- SOLD_SETTLE_MS; each further sale restarts the wait, so a run of sales costs one build.
--
-- A heading cannot wait for that build. Dropping a piece's rows leaves the heading over them --
-- and the section and the Chips/Tiles button over that -- exactly where the build put them, so
-- the sale that took the last piece out of a category (at a fence, the last stolen piece of all)
-- left a heading standing over nothing, still counting the piece, until the wait ran out: the
-- piece looked as though it had stayed for a second and a half and then gone. A sale that empties
-- a heading still drops its rows on the spot, but the build it is owed comes after
-- SOLD_EMPTIED_MS rather than SOLD_SETTLE_MS, and no sale after it pushes that wait back. Built
-- on the spot instead, inside the game's own UpdateList, it cost one build per heading emptied:
-- with set-aside copies on, nearly every set piece sent to SELL is the only row under its home
-- set, so a sell-all built once per sale again, several in one frame, which is what this whole
-- block is here to stop. Waiting a moment lets a burst of sales share the one build, and a
-- heading over nothing for that moment is not seen.
local SOLD_SETTLE = "InventoryGroupingSoldSettle"
local SOLD_SETTLE_MS = 1500
local SOLD_EMPTIED_MS = 100
-- True while the wait armed is the short one, which a later sale leaves where it is.
local settleSoon = false

-- No build is owed after selling any more: the one owed has been done, or is not going to be.
local function CancelSettle()
    EVENT_MANAGER:UnregisterForUpdate(SOLD_SETTLE)
    settleSoon = false
end

local function SlotKey(data)
    local bagId, slotIndex = data and data.bagId, data and data.slotIndex
    if bagId == nil or slotIndex == nil then return nil end
    return bagId .. ":" .. slotIndex
end

-- The bag's raw rows as the build found them: [slot key] = { bag, slot, piece id }. Taken only
-- at a merchant or a fence, the one place DropSoldRows reads it.
local function NoteRawSlots(scrollData)
    local slots, count = {}, 0
    for _, entry in ipairs(scrollData) do
        local data = entry.data
        local key = SlotKey(data)
        if not key then return nil, 0 end
        slots[key] = { data.bagId, data.slotIndex,
            data.uniqueId and Id64ToString(data.uniqueId) or nil }
        count = count + 1
    end
    return slots, count
end

local function SettleAfterSelling()
    CancelSettle()
    local list = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK].listView
    if not list or list:IsHidden() then
        lastBuild[INVENTORY_BACKPACK] = nil
        PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
        return
    end
    RefreshKeepingPlace(INVENTORY_BACKPACK)
end

-- True when the raw rows the game just put in the list are the last build's less pieces that
-- were sold, and the last build's rows have been put back without them. Anything else -- a piece
-- that arrived, a piece that changed, a slot missing from the rows but still full in the bag (a
-- filter tab or a search), another layout, sort or filter -- answers false and is built in full.
-- A sale that leaves a heading over nothing is dropped all the same, and owed a build soon.
local function DropSoldRows(inventory, inventoryType, scrollData, mode)
    if inventoryType ~= INVENTORY_BACKPACK or not AtMerchantSell() then return false end
    local last = lastBuild[inventoryType]
    if not (last and last.rows and last.slots) then return false end
    if last.mode ~= mode or last.sortKey ~= inventory.currentSortKey
        or last.sortOrder ~= inventory.currentSortOrder
        or last.headerClicked ~= tradingHeaderClicked
        or last.filter ~= inventory.currentFilter
        or last.search ~= ListSearchText(inventory, inventoryType) then
        return false
    end
    for _, entry in ipairs(scrollData) do
        if IS_OWN_ROW_TYPE[entry.typeId] then return false end
    end
    local slots, count = NoteRawSlots(scrollData)
    if not slots or count >= last.slotCount then return false end
    for key, now in pairs(slots) do
        local before = last.slots[key]
        if not before then return false end
        if before[3] and now[3] and before[3] ~= now[3] then return false end
    end
    -- What is missing has to be gone from the bag, not merely left out of the rows.
    if not HasItemInSlot then return false end
    local gone = {}
    for key, before in pairs(last.slots) do
        if not slots[key] then
            if HasItemInSlot(before[1], before[2]) then return false end
            gone[key] = true
        end
    end
    -- And whether a heading is left over nothing once they are out (above SOLD_SETTLE): a sold
    -- slot takes its rows off the count of every heading they stood under, a closed heading and
    -- a module's copy included, and a count that runs out wants the build soon.
    local under = last.under
    if not under then return false end
    local left, emptied = {}, false
    for key in pairs(gone) do
        for _, heading in ipairs(under.bySlot[key] or {}) do
            local remaining = (left[heading] or under.counts[heading] or 0) - 1
            if remaining <= 0 then emptied = true end
            left[heading] = remaining
        end
    end

    local kept = {}
    for _, row in ipairs(last.rows) do
        local key = SlotKey(row.data)
        if not (key and gone[key]) then kept[#kept + 1] = row end
    end
    ZO_ClearNumericallyIndexedTable(scrollData)
    for index, row in ipairs(kept) do
        scrollData[index] = row
        row.igOrder = index
    end
    -- A frame whose last row was sold closes on the row above it now.
    if mode ~= "minimal" then AssignFrames(scrollData) end
    inventory.sortFn = KeepBuiltOrder
    last.rows, last.slots, last.slotCount = kept, slots, count
    for heading, remaining in pairs(left) do under.counts[heading] = remaining end
    last.list, last.count, last.time = scrollData, #scrollData, GetFrameTimeMilliseconds()
    -- The long wait starts again with every sale; the short one, once armed, is left to run out.
    if not settleSoon then
        EVENT_MANAGER:UnregisterForUpdate(SOLD_SETTLE)
        settleSoon = emptied
        EVENT_MANAGER:RegisterForUpdate(SOLD_SETTLE, emptied and SOLD_EMPTIED_MS or SOLD_SETTLE_MS,
            SettleAfterSelling)
    end
    return true
end

local function ApplySortHook(manager, inventoryType)
    local inventory, resolvedType = ResolveInventory(manager, inventoryType)
    if not inventory then return false end

    -- Off screen: the game sorts and commits whatever the list holds (its raw rows, or ours in
    -- their kept order) and the real build waits for the list to be shown (PayOwedBuild).
    if not ListOnScreen(inventory, resolvedType) then
        owedBuild[resolvedType] = true
        lastBuild[resolvedType] = nil
        PLAYER_INVENTORY.isListDirty[resolvedType] = true
        return false
    end

    local scrollData = ZO_ScrollList_GetDataList(inventory.listView)
    -- A list that already contains headers was built by us and is missing collapsed items:
    -- rebuild it from the inventory slots, which calls back into this hook with raw data.
    for _, entry in ipairs(scrollData) do
        if IS_OWN_ROW_TYPE[entry.typeId] then
            local last = lastBuild[resolvedType]
            if last and last.list == scrollData and last.count == #scrollData
                and GetFrameTimeMilliseconds() - last.time <= REBUILD_WINDOW_MS
                and last.mode == ListMode(resolvedType)
                and last.sortKey == inventory.currentSortKey
                and last.sortOrder == inventory.currentSortOrder
                and last.headerClicked == tradingHeaderClicked then
                -- Still the list we built: the game sorts it by the kept order and commits.
                inventory.sortFn = KeepBuiltOrder
                return false
            end
            manager:UpdateList(resolvedType, true)
            return true
        end
    end

    local mode = ListMode(resolvedType)
    -- A sale at a merchant or a fence: the last build less what was sold, no build (above).
    if DropSoldRows(inventory, resolvedType, scrollData, mode) then return false end
    -- A full build makes any wait for one after selling moot.
    CancelSettle()
    -- The raw rows, noted before the build replaces them, for the next sale to be read against.
    local merchant = resolvedType == INVENTORY_BACKPACK and AtMerchantSell()
    local rawSlots, rawCount
    if merchant then rawSlots, rawCount = NoteRawSlots(scrollData) end
    if resolvedType == INVENTORY_BACKPACK then lastBackpackMode = mode end
    -- The selling layout has no Sort button: once its column header was clicked, that header
    -- orders the items inside each category (IG.CompareByHeader).
    IG.headerSort = nil
    -- The same at a merchant or a fence, where the bag keeps its own layout.
    local selling = mode == "trading" or (resolvedType == INVENTORY_BACKPACK and AtMerchantSell())
    if selling and tradingHeaderClicked then
        IG.headerSort = { key = inventory.currentSortKey, order = inventory.currentSortOrder,
            keys = ZO_Inventory_GetDefaultHeaderSortKeys() }
    end

    owedBuild[resolvedType] = nil
    BuildGroupedList(inventory, resolvedType, mode)
    IG.headerSort = nil
    local built = ZO_ScrollList_GetDataList(inventory.listView)
    for index = 1, #built do built[index].igOrder = index end
    inventory.sortFn = KeepBuiltOrder
    lastBuild[resolvedType] = { list = built, count = #built, time = GetFrameTimeMilliseconds(),
        mode = mode, sortKey = inventory.currentSortKey, sortOrder = inventory.currentSortOrder,
        headerClicked = tradingHeaderClicked }
    if merchant and rawSlots then
        local rows = {}
        for index = 1, #built do rows[index] = built[index] end
        local last = lastBuild[resolvedType]
        last.rows, last.slots, last.slotCount = rows, rawSlots, rawCount
        last.filter, last.search = inventory.currentFilter, ListSearchText(inventory, resolvedType)
        last.under = builtUnder
    end
    return false
end

-- The bag list is shared by every scene it appears in, so walking up to a merchant (or away
-- from one) has to rebuild it in the right layout.
local function OnBagSceneStateChange(_, newState)
    -- What a sale is read against belongs to one visit (DropSoldRows), and a build owed for
    -- selling is not paid after leaving. Not cleared on SHOWING: the game's opening rebuild may
    -- already have come, and the plain ApplySort after it needs lastBuild to skip a second build.
    if newState == SCENE_HIDDEN then
        lastBuild[INVENTORY_BACKPACK] = nil
        CancelSettle()
    end
    if newState == SCENE_SHOWING then
        -- And with nothing marked: a selection is a sentence you were halfway through saying.
        IG.ClearSelection()
        -- Every visit starts with all categories open.
        ZO_ClearTable(sv.expanded.trading)
        tradingHeaderClicked = false
        PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
    elseif newState == SCENE_SHOWN then
        if lastBackpackMode ~= BackpackMode() then PLAYER_INVENTORY:UpdateList(INVENTORY_BACKPACK, true) end
    elseif newState == SCENE_HIDDEN then
        lastBackpackMode = nil
        PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
    end
    -- Walking up to a merchant changes the answer to every question the toolbar asks -- which
    -- switch decides the bag, and whether the sort button belongs on this layout at all -- and
    -- until now nothing asked them again. The buttons kept whatever they were wearing in the
    -- bag until something else repainted them, so the first press at a guild store was spent
    -- on putting them right and read as the button destroying itself. This only hides and
    -- paints; it builds no list and commits nothing (see "the commit is the game's to make").
    if IG.RepaintToolbar then IG.RepaintToolbar() end
end

-- The bag's list is one control shared by every scene it appears in, so scrolling it at a bank
-- moved the bag too, and the rebuild on the way back kept the bank's offset: the bag "forgot"
-- where it was left. Each scene keeps its own offset, taken as it hides and put back once it is
-- shown (after the game's rebuild), clamped to what the new list can scroll. Open categories
-- stay shared on purpose: the bank and the bag use the same layout, so a category opened there
-- is open here too.
local bagScrollByScene = {}

local function RememberBagScroll(sceneName, newState)
    local list = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK].listView
    if not (list and list.scrollbar) then return end
    if newState == SCENE_HIDING then
        bagScrollByScene[sceneName] = list.scrollbar:GetValue()
    elseif newState == SCENE_SHOWN then
        local saved = bagScrollByScene[sceneName]
        if saved then
            local lowest, highest = list.scrollbar:GetMinMax()
            ZO_ScrollList_ScrollAbsolute(list, zo_clamp(saved, lowest, highest))
        end
    end
end

local function WatchBagScenes()
    local names = {}
    for _, name in ipairs(TRADING_SCENES) do names[#names + 1] = name end
    for _, name in ipairs(BANK_SCENES) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        local scene = SCENE_MANAGER:GetScene(name)
        if scene then scene:RegisterCallback("StateChange", OnBagSceneStateChange) end
    end
    names[#names + 1] = "inventory"
    for _, name in ipairs(names) do
        local scene = SCENE_MANAGER:GetScene(name)
        -- Registered after OnBagSceneStateChange, so SHOWN restores after its rebuild.
        if scene then
            scene:RegisterCallback("StateChange", function(_, newState) RememberBagScroll(name, newState) end)
        end
    end
    -- A fence is there for STOLEN, so walking up to one (sell or launder, one list) opens it:
    -- its section unshut, its heading open or its Chips/Tiles button the open one, and the view
    -- put on it. Written into the bag's shared state, so it stays open afterwards. Registered
    -- last, so it runs after the rebuild and the scroll put back above.
    local fence = SCENE_MANAGER:GetScene("fence_keyboard")
    if fence then
        fence:RegisterCallback("StateChange", function(_, newState)
            if newState ~= SCENE_SHOWN then return end
            local invKey = ListKey(INVENTORY_BACKPACK)
            -- Inside DISPOSAL, DISPOSAL is the button that opens (IG.RevealGroup opens STOLEN
            -- inside it); at the top level, STOLEN's own.
            local opens = IG.InDisposal("STOLEN") and IG.DISPOSAL_KEY or "STOLEN"
            local section = IG.GetGroupSection and IG.GetGroupSection(opens)
            if invKey and section then
                SectionStates(invKey)[section] = nil
                sv.sectionStripOpen = sv.sectionStripOpen or {}
                sv.sectionStripOpen[invKey] = sv.sectionStripOpen[invKey] or {}
                sv.sectionStripOpen[invKey][section] = opens
            end
            IG.RevealGroup("STOLEN")
        end)
    end
end

-- Opening a box from the bag ("Use" on a container) swaps the inventory for the loot window,
-- which hides the inventory without you having left it. That hide must not empty NEW. What you
-- owned at that moment is kept aside instead; the loot the box gives arrives after it, so it
-- stays NEW either way. Going back to the bag drops the copy (its own next close empties NEW as
-- usual); closing the loot window to anywhere else commits it, which is what that close would
-- have done. ("loot" is LOOT_SCENE, esoui/ingame/zo_loot/loot.lua; SCENE_MANAGER:IsShowingNext
-- and IsShowing, zo_scenemanager_base.lua.)
local pendingSeen -- { known = {...}, partial = {...} } while NEW waits out a loot window

local function HoldSeenForLootWindow()
    local current = csv.known
    SnapshotKnownItems()
    local held = { known = csv.known, partial = {} }
    csv.known = current
    pendingSeen = held
end

local function CommitHeldSeen()
    local held = pendingSeen
    pendingSeen = nil
    if not held or not csv.known then return end
    for id in pairs(held.known) do csv.known[id] = true end
    -- Pieces counted as new before the box was opened are seen now; any the box added stay.
    for id, pieces in pairs(held.partial) do
        local left = (partialNew[id] or 0) - pieces
        partialNew[id] = left > 0 and left or nil
        if not partialNew[id] then partialFromRun[id] = nil end
    end
    PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
end

local function OnInventoryFragmentStateChange(oldState, newState)
    if newState == SCENE_FRAGMENT_HIDDEN then
        if SCENE_MANAGER:IsShowingNext("loot") or SCENE_MANAGER:IsShowing("loot") then
            -- partialNew is read before HoldSeenForLootWindow's snapshot clears it.
            local partial = {}
            for id, pieces in pairs(partialNew) do partial[id] = pieces end
            HoldSeenForLootWindow()
            ZO_ClearTable(partialNew)
            for id, pieces in pairs(partial) do partialNew[id] = pieces end
            pendingSeen.partial = partial
        else
            pendingSeen = nil
            SnapshotKnownItems()
        end
        PLAYER_INVENTORY.isListDirty[INVENTORY_BACKPACK] = true
    elseif newState == SCENE_FRAGMENT_SHOWING then
        -- Back in the bag from the loot window: nothing was left, so nothing is seen yet.
        pendingSeen = nil
    end
end

local function OnLootSceneStateChange(oldState, newState)
    if newState ~= SCENE_HIDDEN or not pendingSeen then return end
    -- The next scene starts showing after this one hides; look once it has.
    zo_callLater(function()
        if pendingSeen and not INVENTORY_FRAGMENT:IsShowing() then CommitHeldSeen() end
    end, 100)
end

-- Both addons rearrange the same list, so they fight over it.
local function WarnAboutConflicts()
    if AutoCategory then
        d(string.format("|cFFB627%s:|r AutoCategory is running too. Both addons sort the same list, "
            .. "so turn one of them off in the add-on menu.", IG.DISPLAY_NAME))
    end
end

-- Closing the inventory makes the game run its status icon setup over every visible row, headers
-- and spacers included. Those rows have no status control, so they sit that pass out.
local function SkipOwnRowStatusIcons(rowControl)
    local entry = rowControl and rowControl.dataEntry
    return entry ~= nil and IS_OWN_ROW_TYPE[entry.typeId] == true
end

-- At a fence, the Launder tab runs its own ColorCost callback over every VISIBLE backpack row:
-- ZO_ScrollList_RefreshVisible applies an override callback to all active controls, whatever
-- row type they are. That callback reads data.stackLaunderPrice, which our headers, spacers and
-- feet do not carry, and the game's own code then compares a number with nil. The refresh is
-- done here instead, with our rows left out of the pass.
local function SkipOwnRowsInFenceRefresh(self, callback)
    if not callback then return false end
    local inventory = self.inventories[INVENTORY_BACKPACK]
    if not (inventory and inventory.listView) then return false end
    ZO_ScrollList_RefreshVisible(inventory.listView, nil, function(rowControl, data, scrollList)
        local entry = rowControl and rowControl.dataEntry
        if entry and IS_OWN_ROW_TYPE[entry.typeId] then return end
        return callback(rowControl, data, scrollList)
    end)
    return true
end

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(IG.name, EVENT_PLAYER_ACTIVATED)
    WarnAboutConflicts()
    -- Hooked last, so our rows are skipped before any other addon's status icon code sees them.
    ZO_PreHook("ZO_UpdateStatusControlIcons", SkipOwnRowStatusIcons)
    -- Wrap the item row setup only now, after every addon has installed its own row hooks, so our
    -- decoration runs last and sees their icons (no need to re-check rows later).
    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        HookItemRows(inventory and inventory.listView)
    end
    IG.InitCraftStations()
    IG.AttachGameSearchClears()
    IG.CreateToolbar()
    InitRenameDialog()
    -- After the row hooks above, so a ctrl click is answered before the game's own handler.
    IG.StartSelection()
    IG.StartItemShiftDistribute()
    -- First run for this character: everything currently owned counts as seen.
    if not csv.known then
        SnapshotKnownItems()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= IG.name then return end
    EVENT_MANAGER:UnregisterForEvent(IG.name, EVENT_ADD_ON_LOADED)

    INVENTORY_KEYS = {
        [INVENTORY_BACKPACK] = "backpack",
        [INVENTORY_BANK] = "bank",
        [INVENTORY_GUILD_BANK] = "guildbank",
        -- All house chests share one memory: what you left open is open at the next chest too.
        [INVENTORY_HOUSE_BANK] = "housebank",
    }
    BENCH_KEYS = {
        [IG.CRAFT_INVENTORY_TYPE] = "craft",
        [IG.IMPROVE_INVENTORY_TYPE] = "improve",
    }
    -- The benches are answered as they are asked for: each skill's bench keeps its own memory.
    setmetatable(INVENTORY_KEYS, { __index = function(_, inventoryType)
        local base = BENCH_KEYS[inventoryType]
        return base and BenchKey(base) or nil
    end })

    -- Account-wide settings, kept apart per megaserver (NA/EU/PTS): an account played on more
    -- than one server used to read and write the very same table no matter which one was live,
    -- so a change made on one server silently overwrote what the other had. GetWorldName() as the
    -- profile is the pattern ESOUI's own moderator recommends for this (two ZO_SavedVars calls
    -- with and without it are two different places in the same global table, never the same one).
    --
    -- The one-time step below is what keeps that split from reading as "my settings are gone" to
    -- anyone who already has a save: the pre-split call still reaches the old, single table, and
    -- if the new per-server table has never been written to before, it starts out as a copy of
    -- whatever the old one held rather than empty. Every server a player logs into after today
    -- gets that same starting point once; from then on each server is independent, for good.
    sv = ZO_SavedVars:NewAccountWide("InventoryGrouping_SV", 1, nil, IG.DEFAULT_SETTINGS, GetWorldName())
    if not sv.serverSplitDone then
        local preSplit = ZO_SavedVars:NewAccountWide("InventoryGrouping_SV", 1, nil, IG.DEFAULT_SETTINGS)
        if preSplit ~= sv then
            for key, value in pairs(preSplit) do
                sv[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
            end
        end
        sv.serverSplitDone = true
    end
    sv.expanded.guildbank = sv.expanded.guildbank or {}
    sv.expanded.housebank = sv.expanded.housebank or {}
    sv.expanded.craft = sv.expanded.craft or {}
    sv.expanded.improve = sv.expanded.improve or {}
    sv.expanded.trading = sv.expanded.trading or {}
    sv.expanded.minimal = sv.expanded.minimal or {}
    csv = ZO_SavedVars:NewCharacterIdSettings("InventoryGrouping_SV", 1, nil, {})
    IG.sv = sv
    -- The Global Switch only takes hold here, at load: the settings page compares what it says
    -- now with this to know whether a reload is still owed.
    IG.startedEnabled = IG.IsEnabled()
    metrics = DENSITY[sv.rowDensity] or DENSITY.normal
    -- Before the cleanup: it drops saved state of categories it does not know (Setups.lua).
    if IG.InitSetups then IG.InitSetups(csv) end
    IG.MigrateSavedVars(sv)
    IG.CleanupSavedVars(sv)
    IG.InitModules(sv, csv)
    -- Above the Global Switch's own line, like the modules: what is already saved about this
    -- character's money is tidied whether or not we are listening today.
    IG.InitGold(sv, csv)
    IG.InitOverrides()
    IG.InitEquipped()

    -- The settings page is built either way: it is where the Global Switch lives, so it has to be
    -- reachable to turn the addon back on.
    IG.CreateSettingsPanel()

    -- Global Switch off: nothing below this line runs, so not one hook of ours is installed and
    -- the game's inventory is the stock one.
    if not IG.IsEnabled() then return end

    -- Every module that listens to the game all session long (IG.MODULE_APPLY) picks up its
    -- starting state here, instead of registering unconditionally the moment its own file loads.
    if IG.ApplyAllModuleEvents then IG.ApplyAllModuleEvents() end
    -- Junk's two arrival watches (Junk.lua) answer to switches of their own rather than a module
    -- flag, so they are not in IG.MODULE_APPLY; same idea, picked up here instead.
    if IG.ApplyJunkEventGates then IG.ApplyJunkEventGates() end

    for _, inventoryType in ipairs(GROUPED_INVENTORIES) do
        local inventory = PLAYER_INVENTORY.inventories[inventoryType]
        if inventory and inventory.listView then
            RegisterHeaderTypes(inventory.listView)
            -- Fires for the list when it or any parent is shown (the bag window, a bank).
            ZO_PostHookHandler(inventory.listView, "OnEffectivelyShown", function()
                PayOwedBuild(inventoryType)
            end)
        end
    end

    -- Before the selection's own hook, which is installed at the first player activation: two
    -- things answer Escape now and ZO_PreHook asks the one installed last first, so this one
    -- going in earlier is what puts the marked pieces in front of the drawer (Drawer.lua).
    if IG.InitDrawers then IG.InitDrawers() end
    if IG.StartSticky then IG.StartSticky() end
    ZO_PreHook(PLAYER_INVENTORY, "ChangeSort", NoteHeaderSort)
    ZO_PreHook(PLAYER_INVENTORY, "ApplySort", ApplySortHook)
    ZO_PreHook(PLAYER_INVENTORY, "RefreshBackpackWithFenceData", SkipOwnRowsInFenceRefresh)
    INVENTORY_FRAGMENT:RegisterCallback("StateChange", OnInventoryFragmentStateChange)
    if LOOT_SCENE then LOOT_SCENE:RegisterCallback("StateChange", OnLootSceneStateChange) end
    WatchBagScenes()

    EVENT_MANAGER:RegisterForEvent(IG.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(IG.name .. "Seen", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnBackpackSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(IG.name .. "Seen", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    -- No bag filter: a piece can be locked in the bank and in a house chest too.
    EVENT_MANAGER:RegisterForEvent(IG.name .. "Locked", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotLocked)
end

EVENT_MANAGER:RegisterForEvent(IG.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
