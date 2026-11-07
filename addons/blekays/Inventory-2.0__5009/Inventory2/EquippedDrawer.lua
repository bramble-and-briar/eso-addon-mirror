InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- The EQUIPPED SETS drawer: what you are wearing, drawn as the body that wears it.
--
-- The question this page answers is not "which sets do I own" -- the bag answers that -- but
-- "where are the holes". So the page is a figure with its slots in their own places, each one
-- painted the colour of the set that fills it, and the reading is done with the eye: two colours
-- on the figure is two sets, one white box is a piece with no set in it, one red outline is a
-- piece missing altogether.
--
-- There is no silhouette texture in the game's own art, and the addon may not ship a DDS of its
-- own (HANDOFF, the white square). What the game does have is the empty-slot mark it draws on
-- its own character sheet for each place on the body (EsoUI/Art/CharacterWindow/gearSlot_*,
-- characterwindow in the game's UI source). The figure here is those marks, in the arrangement
-- a body puts them in.
--
-- Nothing on this page is written down anywhere. What you are wearing is read off BAG_WORN when
-- the page is looked at, and the colours are handed out to the sets on it at that moment.

---------------------------------------------------------------------------
-- The body
---------------------------------------------------------------------------

local ART = "EsoUI/Art/CharacterWindow/"

-- Sizes in the page's own units, before it is scaled down to a narrow panel (see Scale).
local ARMOR_BOX = 42
local CHEST_BOX = 51          -- the chest is the middle of the figure and half again as big
local JEWEL_BOX = 25
local WEAPON_BOX = 35
local ICON_INSET = 3

-- Where each box's centre sits, x from the middle of the page and y from its top, so the figure
-- is symmetrical by construction rather than by arithmetic. Head and shoulders side by side on
-- top, the hands left of the chest, the belt under it, legs and feet side by side at the bottom.
local ARMOR = {
    { slot = "EQUIP_SLOT_HEAD",      icon = ART .. "gearslot_head.dds",      x = -24,   y = 21,    size = ARMOR_BOX },
    { slot = "EQUIP_SLOT_SHOULDERS", icon = ART .. "gearslot_shoulders.dds", x = 24,    y = 21,    size = ARMOR_BOX },
    { slot = "EQUIP_SLOT_CHEST",     icon = ART .. "gearslot_chest.dds",     x = 0,     y = 73.5,  size = CHEST_BOX },
    { slot = "EQUIP_SLOT_HAND",      icon = ART .. "gearslot_hands.dds",     x = -52.5, y = 73.5,  size = ARMOR_BOX },
    { slot = "EQUIP_SLOT_WAIST",     icon = ART .. "gearslot_belt.dds",      x = 0,     y = 126,   size = ARMOR_BOX },
    { slot = "EQUIP_SLOT_LEGS",      icon = ART .. "gearslot_legs.dds",      x = -24,   y = 174,   size = ARMOR_BOX },
    { slot = "EQUIP_SLOT_FEET",      icon = ART .. "gearslot_feet.dds",      x = 24,    y = 174,   size = ARMOR_BOX },
}
local FIGURE_HEIGHT = 195

-- The jewellery stands in a column of its own right of the body, apart from it: nothing joins it
-- to the chest. Its right edge (94.5) stays inside half the page's design width (120), and its
-- foot (115) above the weight key's frame (124).
local JEWELRY = {
    { slot = "EQUIP_SLOT_NECK",  icon = ART .. "gearslot_neck.dds", x = 82, y = 44.5 },
    { slot = "EQUIP_SLOT_RING1", icon = ART .. "gearslot_ring.dds", x = 82, y = 73.5 },
    { slot = "EQUIP_SLOT_RING2", icon = ART .. "gearslot_ring.dds", x = 82, y = 102.5 },
}

-- The two weapon bars side by side under the figure, each a numbered disc and two boxes.
local BARS = {
    { label = "1", main = "EQUIP_SLOT_MAIN_HAND",   off = "EQUIP_SLOT_OFF_HAND" },
    { label = "2", main = "EQUIP_SLOT_BACKUP_MAIN", off = "EQUIP_SLOT_BACKUP_OFF" },
}
local BAR_DISC = 26
local BAR_INNER_GAP = 6
local WEAPON_GAP = 5
-- A two-handed weapon takes both places of its bar: one wide box, as wide as the two it replaces.
local TWO_HAND_BOX = WEAPON_BOX * 2 + WEAPON_GAP
local BAR_WIDTH = BAR_DISC + BAR_INNER_GAP + TWO_HAND_BOX
local BAR_SPACE = 18
local BARS_TOP = FIGURE_HEIGHT + 18
local LIST_TOP = BARS_TOP + WEAPON_BOX + 20

-- Wide enough for the two bars side by side with a little air; a narrower panel scales the
-- figure and the bars down together rather than letting them run off its edge.
local DESIGN_WIDTH = BAR_WIDTH * 2 + BAR_SPACE + 8
local MIN_SCALE = 0.5

-- The disc behind a bar's numeral is the crafting station's own black circle
-- (craftingutils.xml, "Underlay"), and the ring round it the skills window's passive frame
-- (skillscomponents_keyboard.lua), drawn grey.
local DISC_TEXTURE = "EsoUI/Art/Crafting/blackcircle.dds"
local RING_TEXTURE = "EsoUI/Art/ActionBar/passiveAbilityFrame_round_up.dds"

-- The mark in a weapon box is the weapon that is in it. The paths are the game's own trading
-- house and inventory filter icons, keyed by weapon type exactly as the game keys them
-- (itemfilterutils.lua, WEAPONTYPE_ICONS and EQUIPMENT_FILTER_TYPE_ICONS). Looked up when the
-- page is drawn, not at load, so a missing constant costs one blank mark rather than the file.
local WEAPON_ICON_BY_NAME = {
    WEAPONTYPE_AXE                = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_1h_Axe_Up.dds",
    WEAPONTYPE_HAMMER             = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_1h_Mace_Up.dds",
    WEAPONTYPE_SWORD              = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_1h_Sword_Up.dds",
    WEAPONTYPE_DAGGER             = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_1h_Dagger_Up.dds",
    WEAPONTYPE_TWO_HANDED_AXE     = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_2h_Axe_Up.dds",
    WEAPONTYPE_TWO_HANDED_HAMMER  = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_2h_Mace_Up.dds",
    WEAPONTYPE_TWO_HANDED_SWORD   = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_2h_Sword_Up.dds",
    WEAPONTYPE_FIRE_STAFF         = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Flame_Up.dds",
    WEAPONTYPE_FROST_STAFF        = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Frost_Up.dds",
    WEAPONTYPE_LIGHTNING_STAFF    = "EsoUI/Art/TradingHouse/Tradinghouse_Weapons_Staff_Lightning_Up.dds",
    WEAPONTYPE_HEALING_STAFF      = "EsoUI/Art/Inventory/inventory_tabIcon_healStaff_up.dds",
    WEAPONTYPE_BOW                = "EsoUI/Art/Inventory/inventory_tabIcon_bow_up.dds",
    WEAPONTYPE_SHIELD             = "EsoUI/Art/Inventory/inventory_tabIcon_shield_up.dds",
}
local weaponIcons

local function WeaponIcon(weaponType)
    if not weaponIcons then
        weaponIcons = {}
        for name, path in pairs(WEAPON_ICON_BY_NAME) do
            local value = _G[name]
            if value ~= nil then weaponIcons[value] = path end
        end
    end
    return weaponType and weaponIcons[weaponType] or nil
end

local ROW_HEIGHT = 30
local SWATCH = 18
local COUNT_WIDTH = 56
local MAX_ROWS = 10

local NAME_FONT = "$(MEDIUM_FONT)|19|soft-shadow-thin"
local COUNT_FONT = "$(BOLD_FONT)|19|soft-shadow-thin"
local BAR_FONT = "$(BOLD_FONT)|18|soft-shadow-thin"
local EMPTY_FONT = "$(MEDIUM_FONT)|16|soft-shadow-thin"
local WEIGHT_FONT = "$(MEDIUM_FONT)|14|soft-shadow-thin"
local WEIGHT_TITLE_FONT = "$(BOLD_FONT)|14|soft-shadow-thin"

-- The weight key stands in the empty corner right of the feet and under the rings, framed, with
-- a rule under it. Page units, like the figure.
local KEY_LEFT, KEY_RIGHT = 50, 120
local KEY_TOP, KEY_BOTTOM = 124, 198
local KEY_TITLE_Y = 135
local KEY_FIRST_Y = 153
local KEY_STEP = 17
local KEY_MARK = 13
local KEY_MARK_GAP = 5
local KEY_RULE_Y = 205

-- An empty slot is a dark hole with a thin red line round it: the one thing on the page that is
-- wrong rather than merely different.
local EMPTY_EDGE = "B4453C"
local EMPTY_FILL = "0D0D10"
local DIM = "9A9AA2"
local RULE = "5A5A62"

-- Three colours nothing else may wear: a mythic is always orange, a monster set always red, and
-- a piece with no set at all always white.
local MYTHIC_COLOR = "FF8A1E"
local MONSTER_COLOR = "E03C3C"
local NO_SET_COLOR = "F2F2F2"

-- The mark inside a box says how heavy the piece is. Jewellery and weapons have no weight and
-- get a white mark with the same black line (a dark one was an unreadable blot on the colour). These three colours are the only source: the figure's marks and the
-- key both go through PaintMark with the same texture, so what the key shows is what is drawn.
local WEIGHT = {
    { name = "ARMORTYPE_LIGHT",  label = "Light",  color = "2CFF3C" },
    { name = "ARMORTYPE_MEDIUM", label = "Medium", color = "FFE600" },
    { name = "ARMORTYPE_HEAVY",  label = "Heavy",  color = "FF1E1E" },
}
local NEUTRAL_MARK = "0A0A0D"
local PLAIN_MARK = "FFFFFF"
-- The trading house weapon art leaves a wide empty margin round the weapon, so a weapon mark
-- is drawn over the whole box rather than inside the inset.
local WEAPON_MARK_SCALE = 1.1

-- The switch at the foot of the page: off, armour marks are the plain dark one and the key goes.
-- Off unless switched on.
local TOGGLE_FONT = "$(MEDIUM_FONT)|16|soft-shadow-thin"
local TOGGLE_ON = "2CFF3C"
local TOGGLE_HOVER = "FFFFFF"
local TOGGLE_GAP = 8

local function ShowWeight()
    return IG.sv ~= nil and IG.sv.showArmorWeight == true
end

local FILL_ALPHA = 0.6
local EDGE_ALPHA = 0.85
local ICON_ALPHA = 1
local EMPTY_FILL_ALPHA = 0.55
local EMPTY_ICON_ALPHA = 0.25
-- A legend line's ground is the set's colour taken most of the way to black, so the name written
-- in the colour itself still reads on it.
local ROW_GROUND_DIM = 0.24

---------------------------------------------------------------------------
-- A colour per set, and never two alike
---------------------------------------------------------------------------

-- A hash of the set id gave each set a colour of its own but could not stop two of them landing
-- on neighbouring hues, and two sets on the figure the same blue is the one thing this page may
-- not do. So the sets on the character are handed colours from a fixed run of hues set well
-- apart on the wheel, clear of the orange, red and white kept back above, in order of their set
-- id: while you wear the same sets, each keeps the same colour.
local PALETTE_HUES = { 210, 120, 280, 58, 180, 320, 90, 245, 155, 195 }
local palette

local function PaletteColor(index)
    if not palette then
        palette = {}
        for i, hue in ipairs(PALETTE_HUES) do palette[i] = IG.HSLToHex(hue, 0.78, 0.6) end
    end
    local count = #palette
    local color = palette[(index - 1) % count + 1]
    -- A second time round the run is lighter, so an eleventh set is still not the first one.
    if index > count then color = IG.LightenColor(color, 0.4) end
    return color
end
-- The same run for anything else that wants neighbours told apart (Setups.lua: setup names).
IG.DistinctPaletteColor = PaletteColor

---------------------------------------------------------------------------
-- What is on the character
---------------------------------------------------------------------------

-- How many pieces a set needs for its largest bonus -- the number after the slash. A set's
-- bonuses never change, so the answer is kept by setId for the session: the drawer is drawn
-- again on every bag opening and would otherwise ask each bonus of each worn set every time.
local bonusMaxBySet = {}
local function BonusMax(itemLink, setId)
    if setId and bonusMaxBySet[setId] then return bonusMaxBySet[setId] end
    local _, _, numBonuses = GetItemLinkSetInfo(itemLink, false)
    local most = 0
    for index = 1, numBonuses or 0 do
        local required = GetItemLinkSetBonusInfo(itemLink, false, index)
        if required and required > most then most = required end
    end
    if setId and most > 0 then bonusMaxBySet[setId] = most end
    return most
end

local function IsMythic(link)
    return ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE ~= nil and GetItemLinkDisplayQuality ~= nil
        and GetItemLinkDisplayQuality(link) == ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
end

local function IsMonsterSet(setId)
    return ITEM_SET_TYPE_MONSTER ~= nil and GetItemSetType ~= nil
        and GetItemSetType(setId) == ITEM_SET_TYPE_MONSTER
end

local function WeightColor(armorType)
    if not armorType then return nil end
    for _, weight in ipairs(WEIGHT) do
        if _G[weight.name] ~= nil and armorType == _G[weight.name] then return weight.color end
    end
    return nil
end

-- Everything worn, slot by slot. The count per set is not "every piece of it you are wearing":
-- only one weapon bar is live at a time, so the bar that carries more of the set is the one
-- counted, and armour and jewellery -- worn on both bars -- are counted once. A two-handed
-- weapon is two pieces, which is the game's own rule.
local function ReadCharacter()
    local sets, order = {}, {}
    local worn = {}
    local barCount = { {}, {} }

    local function Read(slotName)
        local slot = _G[slotName]
        if slot == nil then return nil end
        local link = GetItemLink(BAG_WORN, slot)
        if not link or link == "" then return nil end
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
        local piece = {
            slot = slot,
            link = link,
            armorType = GetItemLinkArmorType(link),
            weaponType = GetItemLinkWeaponType(link),
        }
        if hasSet and setId and setId ~= 0 then
            piece.setId = setId
            local set = sets[setId]
            if not set then
                set = {
                    setId = setId,
                    label = zo_strformat("<<1>>", setName),
                    needed = BonusMax(link, setId),
                    count = 0,
                    link = link,
                }
                if IsMythic(link) then
                    set.color = MYTHIC_COLOR
                elseif IsMonsterSet(setId) then
                    set.color = MONSTER_COLOR
                end
                sets[setId] = set
                order[#order + 1] = set
            end
        end
        return piece
    end

    for _, entry in ipairs(ARMOR) do worn[entry.slot] = Read(entry.slot) end
    for _, entry in ipairs(JEWELRY) do worn[entry.slot] = Read(entry.slot) end
    for index, bar in ipairs(BARS) do
        worn[bar.main] = Read(bar.main)
        worn[bar.off] = Read(bar.off)
        local main = worn[bar.main]
        if main then
            main.twoHanded = EQUIP_TYPE_TWO_HAND ~= nil
                and GetItemLinkEquipType(main.link) == EQUIP_TYPE_TWO_HAND
        end
        local function Count(piece)
            if not (piece and piece.setId) then return end
            local weight = piece.twoHanded and 2 or 1
            barCount[index][piece.setId] = (barCount[index][piece.setId] or 0) + weight
        end
        Count(main)
        Count(worn[bar.off])
    end

    for _, entry in ipairs(ARMOR) do
        local piece = worn[entry.slot]
        if piece and piece.setId then sets[piece.setId].count = sets[piece.setId].count + 1 end
    end
    for _, entry in ipairs(JEWELRY) do
        local piece = worn[entry.slot]
        if piece and piece.setId then sets[piece.setId].count = sets[piece.setId].count + 1 end
    end
    for setId, set in pairs(sets) do
        set.count = set.count + zo_max(barCount[1][setId] or 0, barCount[2][setId] or 0)
    end

    -- The palette, handed out by set id to the sets that do not have a colour of their own.
    local plain = {}
    for _, set in ipairs(order) do
        if not set.color then plain[#plain + 1] = set end
    end
    table.sort(plain, function(a, b) return a.setId < b.setId end)
    for index, set in ipairs(plain) do set.color = PaletteColor(index) end
    for _, set in ipairs(order) do set.color = IG.Adapt(set.color) end

    -- The fullest set first, ties settled by the set's own id.
    table.sort(order, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.setId < b.setId
    end)

    local loose = 0
    for _, piece in pairs(worn) do
        if not piece.setId then loose = loose + 1 end
    end

    return worn, order, loose
end

-- The same reading, for the HUD panel (EquippedHud.lua), so the two never count differently.
IG.ReadEquippedSets = ReadCharacter

---------------------------------------------------------------------------
-- The pieces on screen
---------------------------------------------------------------------------

local function Label(parent, font, color)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetFont(font)
    label:SetColor(IG.HexToRGB(color or "F2F2F2"))
    label:SetMouseEnabled(false)
    return label
end

local function Rule(parent)
    local line = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    line:SetColor(IG.HexToRGB(RULE))
    line:SetAlpha(0.8)
    line:SetMouseEnabled(false)
    return line
end

-- The piece under the mouse says what it is in the game's own words.
local function ShowPieceTooltip(box)
    if not box.igLink then return end
    InitializeTooltip(ItemTooltip, box, RIGHT, -8, 0, LEFT)
    ItemTooltip:SetBagItem(BAG_WORN, box.igSlot)
end

local function HidePieceTooltip()
    ClearTooltip(ItemTooltip)
end

-- A click on a piece opens the set's own category in the bag and lights it.
local function OnBoxClicked(box)
    if not box.igSetId then return end
    local key = IG.SetGroupKey and IG.SetGroupKey(box.igSetId)
    if not key then return end
    PlaySound(SOUNDS.DEFAULT_CLICK)
    IG.RevealGroup(key)
end

-- The black line round a mark: the same texture four times, one pixel off each way, under it.
local MARK_BOOSTS = 2        -- extra added copies of a coloured mark over the mark itself
local SHADOW_OFFSETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

local GLOW_OUT = 3            -- how far the glow frame stands outside the box
local GLOW_WIDTH = 2
local GLOW_MS = 520
local SHIMMER_LOW = 0.15      -- the white sheet over a pulsing box, dimmest and brightest
local SHIMMER_HIGH = 0.38

-- One place on the body: a ground in the set's colour, the mark for that place with a black
-- line round it, a thin outline, and a white frame outside it all that pulses while the set's
-- line in the legend is under the mouse. The frame stands outside the box, so it never covers
-- the mark. The ground is a textureless control, so how solid it is is set with SetAlpha and
-- not with the alpha of SetColor, which is ignored there (HANDOFF).
local function NewBox(parent)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box:SetMouseEnabled(true)

    box.fill = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
    box.fill:SetAnchorFill(box)
    box.fill:SetDrawLevel(0)

    -- A white sheet over the ground that pulses with the frame, so the set's boxes themselves
    -- brighten. It sits under the mark (draw level), so the body part always shows through.
    box.shimmer = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
    box.shimmer:SetAnchorFill(box)
    box.shimmer:SetColor(1, 1, 1, 1)
    box.shimmer:SetDrawLevel(1)
    box.shimmer:SetMouseEnabled(false)
    box.shimmer:SetHidden(true)

    -- The mark is square and sits in the box's centre, sized by SizeMark once the box has its
    -- size, so a wide box (a two-hander) never stretches it.
    box.shadows = {}
    for index, offset in ipairs(SHADOW_OFFSETS) do
        local shadow = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
        shadow:SetAnchor(CENTER, box, CENTER, offset[1], offset[2])
        shadow:SetColor(0, 0, 0, 1)
        shadow:SetDrawLevel(2)
        box.shadows[index] = shadow
    end

    box.icon = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
    box.icon:SetAnchor(CENTER, box, CENTER, 0, 0)
    box.icon:SetDrawLevel(3)

    -- SetColor on a texture multiplies its pixels, and the gearSlot art is a mid grey, so a
    -- vivid weight colour came out dark whatever the colour said. A coloured mark is therefore
    -- drawn added onto what is under it (SetBlendMode(TEX_BLEND_MODE_ADD) -- ESOUIDocumentation,
    -- and CombatMetrics / FancyActionBar+ use it), several times over on the same spot, so the
    -- grey is lifted to the full colour. Over the black line beneath, added light is the colour.
    box.boosts = {}
    for index = 1, MARK_BOOSTS do
        local boost = WINDOW_MANAGER:CreateControl(nil, box, CT_TEXTURE)
        boost:SetAnchor(CENTER, box, CENTER, 0, 0)
        boost:SetDrawLevel(3)
        boost:SetBlendMode(TEX_BLEND_MODE_ADD)
        boost:SetHidden(true)
        box.boosts[index] = boost
    end

    IG.AddEdges(box)

    local glow = WINDOW_MANAGER:CreateControl(nil, box, CT_CONTROL)
    glow:SetAnchor(TOPLEFT, box, TOPLEFT, -GLOW_OUT, -GLOW_OUT)
    glow:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, GLOW_OUT, GLOW_OUT)
    glow:SetMouseEnabled(false)
    glow:SetHidden(true)
    for _, points in ipairs({ { TOPLEFT, TOPRIGHT, true }, { BOTTOMLEFT, BOTTOMRIGHT, true },
                              { TOPLEFT, BOTTOMLEFT, false }, { TOPRIGHT, BOTTOMRIGHT, false } }) do
        local side = WINDOW_MANAGER:CreateControl(nil, glow, CT_TEXTURE)
        side:SetAnchor(points[1], glow, points[1])
        side:SetAnchor(points[2], glow, points[2])
        if points[3] then side:SetHeight(GLOW_WIDTH) else side:SetWidth(GLOW_WIDTH) end
        side:SetColor(1, 1, 1, 1)
        side:SetDrawLayer(DL_OVERLAY)
    end
    box.glow = glow

    box:SetHandler("OnMouseEnter", ShowPieceTooltip)
    box:SetHandler("OnMouseExit", HidePieceTooltip)
    box:SetHandler("OnMouseUp", function(self, _, upInside)
        if upInside then OnBoxClicked(self) end
    end)
    return box
end

-- Boxes made ahead of the page (WarmBoxes, below), parked on a hidden holder. A box is about
-- twenty controls and the page holds seventeen of them: made all at once, they were most of a
-- 177 ms frame the first time the page opened.
local spareBoxes = {}

local function Box(parent, icon)
    local box = table.remove(spareBoxes)
    if box then
        box:SetParent(parent)
    else
        box = NewBox(parent)
    end
    box.igIcon = icon
    box.icon:SetTexture(icon)
    for _, shadow in ipairs(box.shadows) do shadow:SetTexture(icon) end
    for _, boost in ipairs(box.boosts) do boost:SetTexture(icon) end
    return box
end

-- A box's mark and its black line are always the same texture.
local function SetMark(box, icon)
    if box.igIcon == icon then return end
    box.igIcon = icon
    box.icon:SetTexture(icon)
    for _, shadow in ipairs(box.shadows) do shadow:SetTexture(icon) end
    for _, boost in ipairs(box.boosts) do boost:SetTexture(icon) end
end

-- The mark as the largest square the box holds inside its inset, in pixels.
local function SizeMark(box, side)
    local size = zo_max(1, side)
    box.icon:SetDimensions(size, size)
    for _, shadow in ipairs(box.shadows) do shadow:SetDimensions(size, size) end
    for _, boost in ipairs(box.boosts) do boost:SetDimensions(size, size) end
end

-- A mark in a weight colour, with its black line round it -- the one way the figure and the key
-- both paint one, so the key cannot drift from what the figure shows. color nil is a plain dark
-- mark with no line.
local function PaintMark(box, color, alpha)
    local icon = box.icon
    icon:SetColor(IG.HexToRGB(color or NEUTRAL_MARK))
    icon:SetAlpha(alpha)
    -- A dark mark added to its ground would vanish, so only a coloured one is added (see Box).
    icon:SetBlendMode(color and TEX_BLEND_MODE_ADD or TEX_BLEND_MODE_ALPHA)
    local r, g, b = IG.HexToRGB(color or NEUTRAL_MARK)
    for _, boost in ipairs(box.boosts) do
        boost:SetColor(r, g, b, 1)
        boost:SetAlpha(alpha)
        boost:SetHidden(color == nil)
    end
    for _, shadow in ipairs(box.shadows) do shadow:SetHidden(color == nil) end
end

-- The pulse, built the first time it is wanted: an alpha animation on the frame, played back
-- and forth for as long as it is left running (ANIMATION_MANAGER:CreateTimeline,
-- InsertAnimation(ANIMATION_ALPHA ...), SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG,
-- LOOP_INDEFINITELY) -- ESOUIDocumentation, and the same calls in crowncrates.lua).
local function StartGlow(box)
    if not box.igPulse then
        local timeline = ANIMATION_MANAGER:CreateTimeline()
        local fade = timeline:InsertAnimation(ANIMATION_ALPHA, box.glow, 0)
        fade:SetAlphaValues(0.15, 1)
        fade:SetDuration(GLOW_MS)
        -- The white sheet is textureless, so the animation's SetAlpha is what dims it (HANDOFF).
        local shimmer = timeline:InsertAnimation(ANIMATION_ALPHA, box.shimmer, 0)
        shimmer:SetAlphaValues(SHIMMER_LOW, SHIMMER_HIGH)
        shimmer:SetDuration(GLOW_MS)
        timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
        box.igPulse = timeline
    end
    box.glow:SetHidden(false)
    box.shimmer:SetHidden(false)
    box.igPulse:PlayFromStart()
end

local function StopGlow(box)
    if box.igPulse then box.igPulse:Stop() end
    box.glow:SetHidden(true)
    box.shimmer:SetHidden(true)
end

-- What a box is carrying today. piece is nil for a slot with nothing in it; markColor is the
-- colour of the mark (the armour weight), nil for a plain dark one.
local function PaintBox(box, piece, set, markColor)
    box.igLink = piece and piece.link or nil
    box.igSlot = piece and piece.slot or nil
    box.igSetId = piece and piece.setId or nil
    box:SetMouseEnabled(piece ~= nil)

    local fill, edge, fillAlpha
    if not piece then
        fill, edge, fillAlpha = EMPTY_FILL, EMPTY_EDGE, EMPTY_FILL_ALPHA
        -- A hole's faint white mark would be drowned by a black line, so it has none.
        PaintMark(box, nil, EMPTY_ICON_ALPHA)
        box.icon:SetColor(1, 1, 1, 1)
    else
        fill = set and set.color or NO_SET_COLOR
        edge = IG.LightenColor(fill, 0.45)
        fillAlpha = FILL_ALPHA
        PaintMark(box, markColor, ICON_ALPHA)
    end

    box.fill:SetColor(IG.HexToRGB(fill))
    box.fill:SetAlpha(fillAlpha)
    local r, g, b = IG.HexToRGB(edge)
    for _, side in ipairs(box.edges) do
        side:SetColor(r, g, b, 1)
        side:SetAlpha(EDGE_ALPHA)
    end
end

-- Every box wearing the set, pulsing while its line in the legend is under the mouse.
local function GlowSet(body, setId)
    for _, box in ipairs(body.igBoxes) do
        if setId and box.igSetId == setId then StartGlow(box) else StopGlow(box) end
    end
end

-- One line of the legend: a ground in the set's colour darkened, the colour, the name written
-- in it, and how much of the set is on you, with a thin rule under it.
local function Row(parent, body)
    local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    row:SetHeight(ROW_HEIGHT)
    row:SetMouseEnabled(true)

    row.ground = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.ground:SetAnchorFill(row)
    row.ground:SetMouseEnabled(false)

    row.swatch = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.swatch:SetDimensions(SWATCH, SWATCH)
    row.swatch:SetAnchor(LEFT, row, LEFT, 6, 0)

    row.name = Label(row, NAME_FONT)
    row.name:SetAnchor(LEFT, row.swatch, RIGHT, 10, 0)
    row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name:SetMaxLineCount(1)

    row.count = Label(row, COUNT_FONT, DIM)
    row.count:SetAnchor(RIGHT, row, RIGHT, -8, 0)
    row.count:SetWidth(COUNT_WIDTH)
    row.count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    row.rule = Rule(row)
    row.rule:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
    row.rule:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
    row.rule:SetHeight(1)

    row:SetHandler("OnMouseEnter", function(self) GlowSet(body, self.igSetId) end)
    row:SetHandler("OnMouseExit", function() GlowSet(body, nil) end)
    return row
end

---------------------------------------------------------------------------
-- The drawer itself
---------------------------------------------------------------------------

-- A control of the page placed by its centre, in page units, at the page's current scale.
local function Place(body, control, x, y, width, height)
    local k = body.igScale
    control:ClearAnchors()
    control:SetDimensions(width * k, (height or width) * k)
    control:SetAnchor(CENTER, body, TOP, x * k, y * k)
end

-- A straight line between two points in page units. One pixel thick whatever the scale.
local function PlaceLine(body, line, x1, y1, x2, y2)
    local k = body.igScale
    line:ClearAnchors()
    if y1 == y2 then
        line:SetDimensions(zo_max(1, (x2 - x1) * k), 1)
    else
        line:SetDimensions(1, zo_max(1, (y2 - y1) * k))
    end
    line:SetAnchor(CENTER, body, TOP, (x1 + x2) / 2 * k, (y1 + y2) / 2 * k)
end

-- Everything above the legend, placed for the panel's width as it is now.
local function Layout(body)
    local width = body:GetWidth()
    local k = 1
    if width > 0 and width < DESIGN_WIDTH then k = zo_max(MIN_SCALE, width / DESIGN_WIDTH) end
    body.igScale = k
    body.igLaidWidth = width

    for _, entry in ipairs(ARMOR) do
        local box = body.igArmor[entry.slot]
        Place(body, box, entry.x, entry.y, entry.size)
        SizeMark(box, (entry.size - ICON_INSET * 2) * k)
    end
    for _, entry in ipairs(JEWELRY) do
        local box = body.igJewelry[entry.slot]
        Place(body, box, entry.x, entry.y, JEWEL_BOX)
        SizeMark(box, (JEWEL_BOX - ICON_INSET * 2) * k)
    end

    local left = -(BAR_WIDTH * 2 + BAR_SPACE) / 2
    local middle = BARS_TOP + WEAPON_BOX / 2
    for index = 1, #BARS do
        local bar = body.igWeapons[index]
        local x = left + (index - 1) * (BAR_WIDTH + BAR_SPACE)
        Place(body, bar.disc, x + BAR_DISC / 2, middle, BAR_DISC)
        x = x + BAR_DISC + BAR_INNER_GAP
        -- A two-hander's box spans both places and the off hand's box is not shown at all.
        local mark = WEAPON_BOX * WEAPON_MARK_SCALE * k
        if bar.igTwoHanded then
            Place(body, bar.main, x + TWO_HAND_BOX / 2, middle, TWO_HAND_BOX, WEAPON_BOX)
        else
            Place(body, bar.main, x + WEAPON_BOX / 2, middle, WEAPON_BOX)
        end
        SizeMark(bar.main, mark)
        x = x + WEAPON_BOX + WEAPON_GAP
        Place(body, bar.off, x + WEAPON_BOX / 2, middle, WEAPON_BOX)
        SizeMark(bar.off, mark)
        bar.off:SetHidden(bar.igTwoHanded == true)
    end

    -- The weight key: its frame, the heading, and the three lines as one block centred in it.
    local key = body.igWeightKey
    Place(body, key.frame, (KEY_LEFT + KEY_RIGHT) / 2, (KEY_TOP + KEY_BOTTOM) / 2,
        KEY_RIGHT - KEY_LEFT, KEY_BOTTOM - KEY_TOP)
    key.title:ClearAnchors()
    key.title:SetAnchor(CENTER, body, TOP, (KEY_LEFT + KEY_RIGHT) / 2 * k, KEY_TITLE_Y * k)
    local widest = 0
    for _, line in ipairs(key.lines) do widest = zo_max(widest, line.label:GetTextWidth()) end
    local block = KEY_MARK * k + KEY_MARK_GAP + widest
    local blockLeft = (KEY_LEFT + KEY_RIGHT) / 2 * k - block / 2
    for index, line in ipairs(key.lines) do
        local y = (KEY_FIRST_Y + (index - 1) * KEY_STEP) * k
        line.mark:ClearAnchors()
        line.mark:SetDimensions(KEY_MARK * k, KEY_MARK * k)
        line.mark:SetAnchor(LEFT, body, TOP, blockLeft, y)
        SizeMark(line.mark, KEY_MARK * k)
    end
    PlaceLine(body, body.igWeightRule, KEY_LEFT, KEY_RULE_Y, KEY_RIGHT, KEY_RULE_Y)
end

function IG.BuildEquippedDrawer(body)
    body.igArmor, body.igJewelry, body.igWeapons, body.igRows = {}, {}, {}, {}
    body.igBoxes = {}
    body.igScale = 1

    for _, entry in ipairs(ARMOR) do
        local box = Box(body, entry.icon)
        body.igArmor[entry.slot] = box
        body.igBoxes[#body.igBoxes + 1] = box
    end
    for _, entry in ipairs(JEWELRY) do
        local box = Box(body, entry.icon)
        body.igJewelry[entry.slot] = box
        body.igBoxes[#body.igBoxes + 1] = box
    end

    for index, bar in ipairs(BARS) do
        local disc = WINDOW_MANAGER:CreateControl(nil, body, CT_CONTROL)
        local ground = WINDOW_MANAGER:CreateControl(nil, disc, CT_TEXTURE)
        ground:SetTexture(DISC_TEXTURE)
        ground:SetAnchorFill(disc)
        local ring = WINDOW_MANAGER:CreateControl(nil, disc, CT_TEXTURE)
        ring:SetTexture(RING_TEXTURE)
        ring:SetAnchorFill(disc)
        ring:SetDesaturation(1)
        ring:SetColor(IG.HexToRGB("C8C8CE"))
        local numeral = Label(disc, BAR_FONT, "F2F2F2")
        numeral:SetText(bar.label)
        numeral:SetAnchor(CENTER, disc, CENTER, 0, 1)

        local main = Box(body, ART .. "gearslot_mainhand.dds")
        local off = Box(body, ART .. "gearslot_offhand.dds")
        body.igWeapons[index] = { disc = disc, main = main, off = off }
        body.igBoxes[#body.igBoxes + 1] = main
        body.igBoxes[#body.igBoxes + 1] = off
    end

    body.igEmpty = Label(body, EMPTY_FONT, DIM)
    body.igEmpty:SetHidden(true)

    -- The key to the marks' colours. Each line's mark is a box's own mark (the chest's), painted
    -- by PaintMark exactly as the figure paints its marks.
    body.igWeightRule = Rule(body)
    local frame = WINDOW_MANAGER:CreateControl(nil, body, CT_CONTROL)
    frame:SetMouseEnabled(false)
    local frameGround = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
    frameGround:SetAnchorFill(frame)
    frameGround:SetColor(IG.HexToRGB(EMPTY_FILL))
    frameGround:SetAlpha(0.5)
    IG.AddEdges(frame)
    local er, eg, eb = IG.HexToRGB(RULE)
    for _, side in ipairs(frame.edges) do
        side:SetColor(er, eg, eb, 1)
        side:SetAlpha(0.8)
    end
    local key = { frame = frame, lines = {} }
    key.title = Label(frame, WEIGHT_TITLE_FONT, DIM)
    key.title:SetText("Armor")
    for index, weight in ipairs(WEIGHT) do
        local mark = Box(frame, ART .. "gearslot_chest.dds")
        mark:SetMouseEnabled(false)
        mark.fill:SetHidden(true)
        for _, side in ipairs(mark.edges) do side:SetHidden(true) end
        PaintMark(mark, weight.color, ICON_ALPHA)
        local label = Label(frame, WEIGHT_FONT, DIM)
        label:SetText(weight.label)
        label:SetAnchor(LEFT, mark, RIGHT, KEY_MARK_GAP, 0)
        key.lines[index] = { mark = mark, label = label }
    end
    body.igWeightKey = key

    -- The switch for the weight colours, under a rule at the very foot of the page.
    body.igToggleRule = Rule(body)
    body.igToggleRule:SetHeight(1)
    local toggle = Label(body, TOGGLE_FONT, DIM)
    toggle:SetMouseEnabled(true)
    toggle:SetHandler("OnMouseEnter", function(self) self.igHover = true; self.igPaint() end)
    toggle:SetHandler("OnMouseExit", function(self) self.igHover = false; self.igPaint() end)
    toggle:SetHandler("OnMouseUp", function(self, _, upInside)
        if not upInside or not IG.sv then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        IG.sv.showArmorWeight = not ShowWeight()
        IG.RefreshEquippedDrawer(body)
    end)
    toggle.igPaint = function()
        local on = ShowWeight()
        toggle:SetColor(IG.HexToRGB(toggle.igHover and TOGGLE_HOVER or DIM))
        toggle:SetText(string.format("Show Armor Weight: |c%s%s|r",
            on and TOGGLE_ON or DIM, on and "ON" or "OFF"))
    end
    body.igToggle = toggle
    IG.equippedBody = body

    -- A panel dragged narrower lays the page out again. Deferred to a one-shot timer with one
    -- pending at a time, and only when the width really moved: nothing here resizes the body,
    -- but reacting to a rect change inside the rect change is what froze the game once already.
    body:SetHandler("OnRectChanged", function()
        if body.igLayoutPending then return end
        body.igLayoutPending = true
        zo_callLater(function()
            body.igLayoutPending = false
            local width = body:GetWidth()
            if body.igLaidWidth and math.abs(width - body.igLaidWidth) > 0.5 then
                IG.RefreshEquippedDrawer(body)
            end
        end, 0)
    end)

    IG.RefreshEquippedDrawer(body)
end

function IG.RefreshEquippedDrawer(body)
    if not body.igArmor then return end
    local worn, sets, loose = ReadCharacter()
    for index, bar in ipairs(BARS) do
        local main = worn[bar.main]
        body.igWeapons[index].igTwoHanded = main ~= nil and main.twoHanded == true
    end
    Layout(body)
    local width = body:GetWidth()
    local k = body.igScale

    local byId = {}
    body.igFullSets = {}
    for _, set in ipairs(sets) do
        byId[set.setId] = set
        if set.needed > 0 and set.count >= set.needed then body.igFullSets[set.setId] = true end
    end

    local function SetOf(piece)
        return piece and piece.setId and byId[piece.setId] or nil
    end

    -- Off, armour marks are the plain dark one (weightless pieces stay white) and the key goes.
    local weight = ShowWeight()
    body.igWeightKey.frame:SetHidden(not weight)
    body.igWeightRule:SetHidden(not weight)

    for _, entry in ipairs(ARMOR) do
        local piece = worn[entry.slot]
        local box = body.igArmor[entry.slot]
        SetMark(box, entry.icon)
        PaintBox(box, piece, SetOf(piece), weight and piece and WeightColor(piece.armorType) or nil)
    end
    for _, entry in ipairs(JEWELRY) do
        local piece = worn[entry.slot]
        local box = body.igJewelry[entry.slot]
        SetMark(box, entry.icon)
        PaintBox(box, piece, SetOf(piece), PLAIN_MARK)
    end

    for index, bar in ipairs(BARS) do
        local pair = body.igWeapons[index]
        local main, off = worn[bar.main], worn[bar.off]
        SetMark(pair.main, main and WeaponIcon(main.weaponType) or ART .. "gearslot_mainhand.dds")
        PaintBox(pair.main, main, SetOf(main), PLAIN_MARK)
        SetMark(pair.off, off and WeaponIcon(off.weaponType) or ART .. "gearslot_offhand.dds")
        PaintBox(pair.off, off, SetOf(off), PLAIN_MARK)
    end
    -- A redraw under a still mouse would leave a stale pulse on a box that changed hands.
    GlowSet(body, nil)

    -- The legend. Rows are made as they are first needed and kept.
    local listTop = LIST_TOP * k
    local previous = nil
    local shown = 0
    for index, set in ipairs(sets) do
        if index > MAX_ROWS then break end
        shown = index
        local row = body.igRows[index]
        if not row then
            row = Row(body, body)
            body.igRows[index] = row
        end
        row.igSetId = set.setId
        row:ClearAnchors()
        row:SetWidth(width)
        if previous then
            row:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 0)
        else
            row:SetAnchor(TOPLEFT, body, TOPLEFT, 0, listTop)
        end
        row.ground:SetColor(IG.HexToRGB(IG.DimColor(set.color, ROW_GROUND_DIM)))
        row.ground:SetAlpha(1)
        local r, g, b = IG.HexToRGB(set.color)
        row.swatch:SetColor(r, g, b, 1)
        row.swatch:SetAlpha(1)
        row.name:SetText(set.label)
        row.name:SetColor(r, g, b, 1)
        row.name:SetWidth(zo_max(20, width - SWATCH - COUNT_WIDTH - 34))
        -- Complete, the count wears the set's own colour; short of it, it stays grey.
        local full = set.needed > 0 and set.count >= set.needed
        row.count:SetColor(IG.HexToRGB(full and set.color or DIM))
        row.count:SetText(set.needed > 0
            and string.format("%d/%d", set.count, set.needed)
            or tostring(set.count))
        row.rule:SetHidden(false)
        row:SetHidden(false)
        previous = row
    end
    for index = shown + 1, #body.igRows do body.igRows[index]:SetHidden(true) end
    if previous then previous.rule:SetHidden(true) end

    local note = body.igEmpty
    note:ClearAnchors()
    if previous then
        note:SetAnchor(TOPLEFT, previous, BOTTOMLEFT, 0, 6)
    else
        note:SetAnchor(TOPLEFT, body, TOPLEFT, 0, listTop)
    end
    if loose > 0 then
        note:SetColor(IG.HexToRGB(NO_SET_COLOR))
        note:SetText(loose == 1 and "1 piece belongs to no set" or
            string.format("%d pieces belong to no set", loose))
        note:SetHidden(false)
    elseif shown == 0 then
        note:SetColor(IG.HexToRGB(DIM))
        note:SetText("Nothing equipped")
        note:SetHidden(false)
    else
        note:SetHidden(true)
    end

    -- The switch goes under whatever the page ended with.
    local last = not note:IsHidden() and note or previous
    local rule, toggle = body.igToggleRule, body.igToggle
    rule:ClearAnchors()
    rule:SetWidth(width)
    if last then
        rule:SetAnchor(TOPLEFT, last, BOTTOMLEFT, 0, TOGGLE_GAP)
    else
        rule:SetAnchor(TOPLEFT, body, TOPLEFT, 0, listTop)
    end
    toggle:ClearAnchors()
    toggle:SetAnchor(TOPLEFT, rule, BOTTOMLEFT, 6, TOGGLE_GAP)
    toggle.igPaint()
end

---------------------------------------------------------------------------
-- Keeping up with the character
---------------------------------------------------------------------------

-- The drawer's row in IG.DRAWERS is written where the drawers are, and what fills its body is
-- written here; the two are joined at load rather than in that table so that this page can be
-- taken out of the addon by dropping one file.
for _, drawer in ipairs(IG.DRAWERS or {}) do
    if drawer.key == "equippedSets" then
        drawer.build = function(body) return IG.BuildEquippedDrawer(body) end
        drawer.refresh = function(body) return IG.RefreshEquippedDrawer(body) end
    end
end

-- Changing one piece of gear sends several slot updates in a row -- the old one out, the new one
-- in, and the game's own bookkeeping behind them -- so the redraw waits a moment and a run of
-- them settles into one. Nothing here touches a list: these are our own controls being painted
-- again, which is why waiting is allowed at all (HANDOFF: the list's commit is the game's).
local SETTLE = "InventoryGroupingEquipped"
local SETTLE_DELAY = 120

local function Redraw()
    EVENT_MANAGER:UnregisterForUpdate(SETTLE)
    IG.RefreshOpenDrawer()
end

local function OnWornSlotUpdate()
    -- Only when this page is the one on screen. The drawer that is open is written down as the
    -- page is opened, so asking costs nothing, and a character that changes gear all day with
    -- the bag shut redraws nothing at all.
    if not (IG.sv and IG.sv.drawerOpen == "equippedSets") then return end
    EVENT_MANAGER:UnregisterForUpdate(SETTLE)
    EVENT_MANAGER:RegisterForUpdate(SETTLE, SETTLE_DELAY, Redraw)
end

-- BAG_WORN's own slot updates, which is what the game sends for every change to what is on the
-- character: equipping, unequipping, swapping, and an Armory loadout being called up, which is
-- a dozen of them at once and the reason for the wait above.
EVENT_MANAGER:RegisterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornSlotUpdate)
-- DEFAULT only: durability/charge ticking on a worn piece fires this same event under its own
-- reason (see Repair.lua) and has nothing to redraw here -- filtered out before it reaches Lua.
EVENT_MANAGER:AddFilterForEvent(SETTLE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    REGISTER_FILTER_BAG_ID, BAG_WORN,
    REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

-- The page's boxes, made one at a time a while after logging in, so the first opening of the
-- page only has to hang them on it. One box per step, a step every WARM_STEP_MS, none in
-- combat; it stops for good once the page is built (it then takes what was made and makes the
-- rest itself) or once every box it needs is waiting.
local WARM = "InventoryGroupingEquippedWarm"
local WARM_DELAY_MS = 5000
local WARM_STEP_MS = 50
local WARM_TOTAL = #ARMOR + #JEWELRY + #BARS * 2 + #WEIGHT
local warmHolder

local function WarmStep()
    if IG.equippedBody or #spareBoxes >= WARM_TOTAL then
        EVENT_MANAGER:UnregisterForUpdate(WARM)
        return
    end
    if IsUnitInCombat("player") then return end
    if not warmHolder then
        warmHolder = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_CONTROL)
        warmHolder:SetHidden(true)
    end
    spareBoxes[#spareBoxes + 1] = NewBox(warmHolder)
end

EVENT_MANAGER:RegisterForEvent(WARM, EVENT_PLAYER_ACTIVATED, function()
    EVENT_MANAGER:UnregisterForEvent(WARM, EVENT_PLAYER_ACTIVATED)
    if IG.IsEnabled and not IG.IsEnabled() then return end
    zo_callLater(function()
        if IG.equippedBody then return end
        EVENT_MANAGER:RegisterForUpdate(WARM, WARM_STEP_MS, WarmStep)
    end, WARM_DELAY_MS)
end)

