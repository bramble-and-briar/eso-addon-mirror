InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Extra information on set headers: which pieces you have (badge row under the name),
-- how many aren't in the set collection yet (pulsing counter), and a bonus tooltip on hover.

-- Bright tab icons from the guild store filters, so owned slots can glow in the set color.
local TH = "EsoUI/Art/TradingHouse/tradingHouse_"

-- Gear slots in display order; "group" puts a small gap between armor, jewelry and weapons.
-- cap: how many of that slot count toward set bonuses (two rings, two weapons when dual wielding).
local SLOTS = {
    { key = "head",      label = "Head",      icon = TH .. "apparel_head_up.dds",                    group = 1, cap = 1 },
    { key = "shoulders", label = "Shoulders", icon = TH .. "apparel_shoulders_up.dds",               group = 1, cap = 1 },
    { key = "chest",     label = "Chest",     icon = TH .. "apparel_chest_up.dds",                   group = 1, cap = 1 },
    { key = "hands",     label = "Hands",     icon = TH .. "apparel_hands_up.dds",                   group = 1, cap = 1 },
    { key = "waist",     label = "Waist",     icon = TH .. "apparel_waist_up.dds",                   group = 1, cap = 1 },
    { key = "legs",      label = "Legs",      icon = TH .. "apparel_legs_up.dds",                    group = 1, cap = 1 },
    { key = "feet",      label = "Feet",      icon = TH .. "apparel_feet_up.dds",                    group = 1, cap = 1 },
    { key = "neck",      label = "Neck",      icon = TH .. "apparel_accessories_necklace_up.dds",    group = 2, cap = 1 },
    { key = "ring",      label = "Ring",      icon = TH .. "apparel_accessories_ring_up.dds",        group = 2, cap = 2 },
    { key = "weapon",    label = "Weapon",    icon = TH .. "weapons_1h_sword_up.dds",                group = 3, cap = 2 },
    { key = "offhand",   label = "Off-hand",  icon = "EsoUI/Art/Inventory/inventory_tabIcon_shield_up.dds", group = 3, cap = 1 },
}
local SLOT_BY_KEY = {}
for _, slot in ipairs(SLOTS) do SLOT_BY_KEY[slot.key] = slot end

local SLOT_BY_EQUIP_TYPE = {}
for name, key in pairs({
    EQUIP_TYPE_HEAD = "head", EQUIP_TYPE_SHOULDERS = "shoulders", EQUIP_TYPE_CHEST = "chest",
    EQUIP_TYPE_HAND = "hands", EQUIP_TYPE_WAIST = "waist", EQUIP_TYPE_LEGS = "legs", EQUIP_TYPE_FEET = "feet",
    EQUIP_TYPE_NECK = "neck", EQUIP_TYPE_RING = "ring",
    EQUIP_TYPE_ONE_HAND = "weapon", EQUIP_TYPE_TWO_HAND = "weapon", EQUIP_TYPE_MAIN_HAND = "weapon",
    EQUIP_TYPE_OFF_HAND = "offhand",
}) do
    if _G[name] ~= nil then SLOT_BY_EQUIP_TYPE[_G[name]] = key end
end

-- Which slots a set can have at all, so missing ones only show where they make sense.
local MONSTER_SLOTS = { head = true, shoulders = true }
local WEAPON_SLOTS = { weapon = true, offhand = true }

function IG.GetSetSlotFilter(path)
    if path[1].id == "MONSTER" then return MONSTER_SLOTS end
    if path[2] and path[2].id == "Arena Sets" then return WEAPON_SLOTS end
    return nil -- every slot
end

---------------------------------------------------------------------------
-- Per-set summary of the items in the current list
---------------------------------------------------------------------------

function IG.NewSetSummary(worn)
    -- uncollectedIds is why uncollected is not simply a count of items: two swords of the same
    -- set are one slot in the collection, so collecting either of them moves the counter once.
    return { slots = {}, uncollected = 0, uncollectedIds = {}, worn = worn or {} }
end

-- Slots the character is wearing, per set: [setId] = { [slotKey] = count }.
function IG.GetWornSetSlots()
    local worn = {}
    for slotIndex = 0, GetBagSize(BAG_WORN) - 1 do
        if HasItemInSlot(BAG_WORN, slotIndex) then
            local itemLink = GetItemLink(BAG_WORN, slotIndex)
            local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
            local slotKey = SLOT_BY_EQUIP_TYPE[GetItemLinkEquipType(itemLink)]
            if hasSet and slotKey then
                worn[setId] = worn[setId] or {}
                worn[setId][slotKey] = (worn[setId][slotKey] or 0) + 1
            end
        end
    end
    return worn
end

function IG.AddToSetSummary(summary, slotData)
    local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
    summary.link = summary.link or itemLink
    local slotKey = SLOT_BY_EQUIP_TYPE[slotData.equipType]
    if slotKey then
        summary.slots[slotKey] = (summary.slots[slotKey] or 0) + 1
    end

    -- How much of this set the collection already holds. Asked once per set rather than per
    -- piece, and of the collection rather than of the bag: it is true whether or not you are
    -- carrying anything.
    if summary.pieces == nil and GetNumItemSetCollectionPieces then
        local _, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if setId and setId ~= 0 then
            local pieces = GetNumItemSetCollectionPieces(setId)
            if pieces and pieces > 0 then
                summary.pieces = pieces
                summary.collected = GetNumItemSetCollectionSlotsUnlocked(setId) or 0
            end
        end
    end

    -- What the set is still missing from the collection. A piece that is already in it is not
    -- counted at all: being in the collection says nothing about whether you want to keep it.
    -- Counted once per collection slot, not once per item: carrying two of the same sword would
    -- otherwise promise the counter two steps it can only take one of.
    if IsItemLinkSetCollectionPiece(itemLink) and not IsItemLinkReconstructed(itemLink) then
        local itemId = GetItemLinkItemId(itemLink)
        if not IsItemSetCollectionPieceUnlocked(itemId) and not summary.uncollectedIds[itemId] then
            summary.uncollectedIds[itemId] = true
            summary.uncollected = summary.uncollected + 1
        end
    end
end

-- Pieces that count toward set bonuses (e.g. at most two rings).
local function CountedPieces(summary)
    local total = 0
    for key, count in pairs(summary.slots) do
        total = total + zo_min(count, SLOT_BY_KEY[key].cap)
    end
    return total
end

---------------------------------------------------------------------------
-- Piece badges
---------------------------------------------------------------------------

-- The row under a set's name says which pieces of it you are carrying: owned slots are lit in
-- the set's color, the ones you don't have stay in place as dim outlines.
local BADGE_SIZE = 23
local BADGE_SPACING = 2 -- badge + spacing = the +/- mark's step, so the second badge starts under the name
-- Armor, jewelry and weapons are told apart by a hairline in the middle of the gap between them,
-- which says more than empty space and lets the gap itself be smaller.
local GROUP_GAP = 7
local DIVIDER_HEIGHT = 15
local DIVIDER_ALPHA = 0.4
local OWNED_LIGHTEN = 0.45               -- owned slots: the set color pushed toward white
local WORN_COLOR = { 0.22, 1, 0.08 }     -- slots you're wearing right now
local MISSING_COLOR = { 0.6, 0.6, 0.6, 0.22 } -- slots you have no piece for

local function CreateBadges(row)
    local container = WINDOW_MANAGER:CreateControl(nil, row, CT_CONTROL)
    container:SetDimensions(10, BADGE_SIZE)
    local badges = {}
    local x, previousGroup = 0, nil
    for _, slot in ipairs(SLOTS) do
        if previousGroup and slot.group ~= previousGroup then x = x + GROUP_GAP end
        previousGroup = slot.group

        local icon = WINDOW_MANAGER:CreateControl(nil, container, CT_TEXTURE)
        icon:SetDimensions(BADGE_SIZE, BADGE_SIZE)
        icon:SetTexture(slot.icon)
        icon:SetDrawLevel(20)

        -- The stack count label is only created the first time a slot needs one.
        badges[slot.key] = { icon = icon, x = x }
        x = x + BADGE_SIZE + BADGE_SPACING
    end
    return { container = container, badges = badges, dividers = {} }
end

-- One hairline, in the set's own color, centered on the badge row.
local function ShowDivider(pieces, index, x, r, g, b)
    local line = pieces.dividers[index]
    if not line then
        line = WINDOW_MANAGER:CreateControl(nil, pieces.container, CT_TEXTURE)
        line:SetDrawLevel(19)
        line:SetDimensions(1, DIVIDER_HEIGHT)
        pieces.dividers[index] = line
    end
    line:ClearAnchors()
    line:SetAnchor(TOPLEFT, pieces.container, TOPLEFT, x, zo_floor((BADGE_SIZE - DIVIDER_HEIGHT) / 2))
    line:SetColor(r, g, b, DIVIDER_ALPHA)
    line:SetHidden(false)
end

function IG.ShowSetPieces(row, summary, slotFilter, color, left, top)
    local pieces = row.igPieces
    if not pieces then
        pieces = CreateBadges(row)
        row.igPieces = pieces
    end
    pieces.container:ClearAnchors()
    pieces.container:SetAnchor(TOPLEFT, row, TOPLEFT, left, top)
    pieces.container:SetHidden(false)

    local r, g, b = IG.HexToRGB(color)
    r, g, b = r + (1 - r) * OWNED_LIGHTEN, g + (1 - g) * OWNED_LIGHTEN, b + (1 - b) * OWNED_LIGHTEN
    local x, drawn = 0, 0
    local previousGroup
    for _, slot in ipairs(SLOTS) do
        local badge = pieces.badges[slot.key]
        local owned = summary.slots[slot.key] or 0
        local shown = not slotFilter or slotFilter[slot.key] == true
        badge.icon:SetHidden(not shown)
        if badge.count then badge.count:SetHidden(true) end
        if shown then
            -- Only between two runs that are both on screen: a monster set has no jewelry at all.
            if previousGroup and slot.group ~= previousGroup then
                drawn = drawn + 1
                ShowDivider(pieces, drawn, x + zo_floor(GROUP_GAP / 2), r, g, b)
                x = x + GROUP_GAP
            end
            previousGroup = slot.group
            badge.icon:ClearAnchors()
            badge.icon:SetAnchor(TOPLEFT, pieces.container, TOPLEFT, x, 0)
            x = x + BADGE_SIZE + BADGE_SPACING

            if summary.worn[slot.key] then
                badge.icon:SetColor(WORN_COLOR[1], WORN_COLOR[2], WORN_COLOR[3], 1)
            elseif owned == 0 then
                badge.icon:SetColor(unpack(MISSING_COLOR))
            else
                badge.icon:SetColor(r, g, b, 1)
            end
            if owned > 1 then
                if not badge.count then
                    badge.count = WINDOW_MANAGER:CreateControl(nil, pieces.container, CT_LABEL)
                    badge.count:SetFont("$(BOLD_FONT)|13|thick-outline")
                    badge.count:SetAnchor(BOTTOMRIGHT, badge.icon, BOTTOMRIGHT, 3, 3)
                    badge.count:SetDrawLevel(21)
                end
                badge.count:SetText(owned)
                badge.count:SetHidden(false)
            end
        end
    end
    for i = drawn + 1, #pieces.dividers do pieces.dividers[i]:SetHidden(true) end
end

---------------------------------------------------------------------------
-- Role markers: what a set mostly does, from its bonus text
---------------------------------------------------------------------------

local LFG = "EsoUI/Art/LFG/"

-- What a set is for, read from its bonus text. Terms are matched as whole words (so "ally" never
-- matches "critically") and carry a weight: a set that says "Adds Maximum Magicka" is not a damage
-- set for that reason alone, while one that says "weapon and spell damage" is.
local STRONG, NORMAL, WEAK = 3, 1.5, 0.6

local ROLES = {
    {
        key = "damage", color = { 1, 0.3, 0.3 }, icon = LFG .. "LFG_icon_dps.dds",
        terms = {
            { weight = STRONG, list = {
                "weapon and spell damage", "weapon damage", "spell damage", "critical damage",
                "critical chance", "penetration", "damage done", "major force", "minor force",
                "major berserk", "minor berserk", "major brutality", "major sorcery",
                "major savagery", "major prophecy", "minor vulnerability", "major vulnerability" } },
            { weight = NORMAL, list = {
                "damage over time", "direct damage", "light attack", "heavy attack", "bash damage",
                "flame damage", "shock damage", "frost damage", "poison damage", "bleed damage",
                "disease damage", "magic damage", "physical damage", "deal damage", "deals damage" } },
            -- Own resource pools and their recovery feed the wearer's rotation. They used to count as
            -- support, which left pure magicka sets (Necropotence) scoring on no role at all.
            { weight = WEAK, list = { "maximum magicka", "maximum stamina", "critical", "ultimate",
                "magicka recovery", "stamina recovery" } },
        },
    },
    {
        key = "tank", color = { 0.3, 0.64, 1 }, icon = LFG .. "LFG_icon_tank.dds",
        terms = {
            { weight = STRONG, list = {
                "maximum health", "damage taken", "major resolve", "minor resolve", "damage shield",
                "taunt", "taunts", "block cost", "blocking", "physical and spell resistance",
                "major protection", "minor protection", "absorb", "immovable" } },
            { weight = NORMAL, list = {
                "health recovery", "mitigation", "spell resistance", "physical resistance",
                "roll dodge", "crowd control", "reduce the damage" } },
            { weight = WEAK, list = { "armor", "resistance", "block", "shield" } },
        },
    },
    {
        key = "support", color = { 1, 0.85, 0.3 }, icon = LFG .. "LFG_icon_healer.dds",
        terms = {
            { weight = STRONG, list = {
                "healing done", "healing taken", "healing received", "major courage", "minor courage",
                "major slayer", "minor slayer", "major aegis", "minor aegis", "allies", "group members",
                "your group", "resurrect", "synergy" } },
            { weight = NORMAL, list = {
                "healing", "heals", "heal", "ally", "restore magicka to", "restore stamina to" } },
            { weight = WEAK, list = { "restore magicka", "restore stamina", "restore health" } },
        },
    },
}
-- The markers themselves, in the order they read: damage, armour, buff. The settings page shows
-- them beside the switch that turns their colors on, as an example of what it means.
-- The settings preview has no item to read a set's roles out of, so it names the ones its sample
-- set serves and hands them straight to ShowSetRoles.
IG.ROLE_BY_KEY = {}
for _, role in ipairs(ROLES) do IG.ROLE_BY_KEY[role.key] = role end

function IG.GetRoleSamples()
    local samples = {}
    for index, role in ipairs(ROLES) do
        samples[index] = { icon = role.icon, color = IG.RGBToHex(unpack(role.color)) }
    end
    return samples
end

local SET_BONUS_WEIGHT = 2   -- the full-set bonus says the most about what a set is for
local MIN_ROLE_SCORE = 2.5   -- below this the set only brushes against the role: not worth a marker
local SECOND_ROLE_SHARE = 0.5 -- a second or third role has to come this close to the strongest one

local roleCache = {}

-- Whole-word (or whole-phrase) match, so "ally" doesn't hit "critically" and "armor" doesn't hit
-- "armory". The text has been through IG.NormalizeWords.
local Mentions = IG.HasWord

-- The strongest thing a single bonus line says about one role. Lines don't stack terms: a line
-- that names three damage stats still only says "this is about damage" once.
local function LineScore(text, role)
    for _, group in ipairs(role.terms) do
        for _, term in ipairs(group.list) do
            if Mentions(text, term) then return group.weight, term end
        end
    end
    return 0
end

-- Up to three roles, strongest first. A second or third only shows when the set really serves it.
function IG.GetSetRoles(setId, itemLink)
    local cached = roleCache[setId]
    if cached then return cached end

    local scores = {}
    local _, _, numBonuses = GetItemLinkSetInfo(itemLink, false)
    for i = 1, numBonuses or 0 do
        local _, description = GetItemLinkSetBonusInfo(itemLink, false, i)
        local text = IG.NormalizeWords(description)
        local lineWeight = i == numBonuses and SET_BONUS_WEIGHT or 1
        for _, role in ipairs(ROLES) do
            local hit = LineScore(text, role)
            if hit > 0 then scores[role] = (scores[role] or 0) + hit * lineWeight end
        end
    end

    local ranked = {}
    for role in pairs(scores) do ranked[#ranked + 1] = role end
    table.sort(ranked, function(a, b)
        if scores[a] ~= scores[b] then return scores[a] > scores[b] end
        return a.key < b.key -- same score: a fixed order, so a set always looks the same
    end)

    cached = {}
    local best = ranked[1] and scores[ranked[1]] or 0
    for _, role in ipairs(ranked) do
        local score = scores[role]
        if #cached == 0 then
            if score >= MIN_ROLE_SCORE then cached[1] = role end
        elseif score >= MIN_ROLE_SCORE and score >= best * SECOND_ROLE_SHARE then
            cached[#cached + 1] = role
        end
    end
    roleCache[setId] = cached
    return cached
end

-- A set is colored after the roles it serves: one role means one color, more means a blend
-- running left to right across its header. Sets whose bonuses say nothing return nothing.
function IG.GetSetRoleColors(setId, itemLink)
    local roles = IG.GetSetRoles(setId, itemLink)
    if not roles[1] then return nil end
    local colors = {}
    for i, role in ipairs(roles) do colors[i] = IG.RGBToHex(unpack(role.color)) end
    return colors
end

-- A role marker is the game's own role icon in the role's color. It used to sit inside a ring
-- with a disc behind it; thin circles that size shimmered against each other and against the
-- icon, and they ate the room the icon needed, so the icon now stands on its own.
local ROLE_MAX_SIZE = 32      -- a lone marker never grows past this
local DIAGONAL_RATIO = 0.60   -- two markers on the diagonal, as a share of the strip
local DIAGONAL_INSET = 3      -- two markers step this far in from their corners, toward the middle
local ROLE_GAP = 2            -- between markers
local ROLE_PADDING = 2        -- empty space kept above and below them
local ROLE_ICON_SCALE = 1.25  -- icons drawn this much larger than their layout slot

-- One ring, one soft disc inside it, one icon on top. A second ring used to be drawn a couple of
-- pixels smaller to make the outline bolder, but two thin circles that close together shimmer
-- against each other, so the disc does that job now.
local function CreateRoleMarker(row)
    local icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    icon:SetDrawLevel(21)
    return { icon = icon }
end

-- Where each marker goes inside the role strip, and how big they can be:
--   one role   : as large as the strip allows, in the middle
--   two roles  : on the diagonal, top left and bottom right, so both can grow
--   three roles: a pyramid, one on top of two
-- Sizes and positions are whole even pixels, so the round art stays crisp.
local function RoleLayout(count, left, width, height)
    local size, spots
    if count >= 3 then
        size = zo_min(zo_floor((width - ROLE_GAP) / 2), zo_floor((height - ROLE_GAP) / 2))
        size = size - size % 2
        local pairWidth = size * 2 + ROLE_GAP
        local pairLeft = left + zo_floor((width - pairWidth) / 2)
        local bottom = ROLE_PADDING + height - size
        spots = {
            { x = left + zo_floor((width - size) / 2), y = ROLE_PADDING },
            { x = pairLeft, y = bottom },
            { x = pairLeft + size + ROLE_GAP, y = bottom },
        }
    elseif count == 2 then
        -- Corner to corner, two circles only have to clear each other diagonally, which leaves
        -- room for about 0.58 of the strip each.
        size = zo_floor(zo_min(width, height) * DIAGONAL_RATIO)
        size = size - size % 2
        spots = {
            { x = left + DIAGONAL_INSET, y = ROLE_PADDING + DIAGONAL_INSET },
            { x = left + width - size - DIAGONAL_INSET, y = ROLE_PADDING + height - size - DIAGONAL_INSET },
        }
    else
        size = zo_min(width, height, ROLE_MAX_SIZE)
        size = size - size % 2
        spots = { { x = left + zo_floor((width - size) / 2), y = ROLE_PADDING + zo_floor((height - size) / 2) } }
    end
    return size, spots
end

-- left/width: the strip of the header reserved for these markers (IG.RoleArea).
function IG.ShowSetRoles(row, roles, left, width)
    row.igRoles = row.igRoles or {}
    local height = row:GetHeight() - ROLE_PADDING * 2
    local size, spots = RoleLayout(#roles, left, width, height)
    for i = 1, 3 do
        local marker = row.igRoles[i]
        local role, spot = roles[i], spots[i]
        if role and spot then
            if not marker then
                marker = CreateRoleMarker(row)
                row.igRoles[i] = marker
            end
            -- Drawn a quarter larger than the layout slot, grown evenly around its middle so the
            -- markers keep their centering against the name.
            local drawn = zo_floor(size * ROLE_ICON_SCALE)
            drawn = drawn - drawn % 2
            local grow = (drawn - size) / 2
            marker.icon:SetTexture(role.icon)
            marker.icon:SetDimensions(drawn, drawn)
            marker.icon:SetColor(unpack(role.color))
            marker.icon:ClearAnchors()
            marker.icon:SetAnchor(TOPLEFT, row, TOPLEFT, spot.x - grow, spot.y - grow)
            marker.icon:SetHidden(false)
        elseif marker then
            marker.icon:SetHidden(true)
        end
    end
end

function IG.HideSetRoles(row)
    if not row.igRoles then return end
    for _, marker in pairs(row.igRoles) do marker.icon:SetHidden(true) end
end

function IG.HideSetPieces(row)
    if row.igPieces then row.igPieces.container:SetHidden(true) end
end

---------------------------------------------------------------------------
-- The collection counter: what the set collection holds of this set, and what the bag could
-- still add to it. Under the drop location, right aligned, growing leftward.
---------------------------------------------------------------------------

local COLLECT_COLOR = { 0.22, 1, 0.08 }
local PULSE_MS = 1400
-- The word is the icon. "Collected" spelled out is longer than the number it introduces, and a
-- set header has the room it has; the collection's own tab icon says it in one glyph. Drawn
-- inline in the label with inheritcolor, so it wears the green without being coloured twice.
local COLLECTED_ICON = "EsoUI/Art/Collections/collections_tabIcon_itemSets_up.dds"
-- The set rule draws a counter of its own, and there is one green and one glyph for both.
IG.COLLECT_COLOR = COLLECT_COLOR
IG.COLLECTED_ICON = COLLECTED_ICON
-- Larger than the letters beside it: the glyph is doing the work the word "Collected" used to.
local COLLECTED_ICON_SIZE = 24
local COLLECTED_GAP = 6   -- between the pair and what the bag could add to it

local function PulseCollect(row)
    local phase = (GetFrameTimeMilliseconds() % PULSE_MS) / PULSE_MS
    row.igCollect:SetAlpha(0.55 + 0.45 * math.cos(phase * 2 * math.pi))
end

local function CollectLabel(row, field, level)
    local label = row[field]
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        label:SetColor(unpack(COLLECT_COLOR))
        label:SetDrawLevel(level)
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row[field] = label
    end
    return label
end

-- Two labels, right aligned one after the other: what the collection has (steady) and what is
-- in the bag to add to it (pulsing, and only when there is any). The pulsing one takes the right
-- edge so the pair reads outward from the number that matters.
function IG.ShowSetCollected(row, summary, font, rightInset, lineY)
    local plus = summary.uncollected or 0
    local counter = CollectLabel(row, "igCollected", 20)
    counter:SetFont(font)
    counter:SetText(string.format("|t%d:%d:%s:inheritcolor|t %d/%d",
        COLLECTED_ICON_SIZE, COLLECTED_ICON_SIZE, COLLECTED_ICON,
        summary.collected or 0, summary.pieces or 0))
    counter:SetHidden(false)
    counter:ClearAnchors()

    if plus > 0 then
        local extra = CollectLabel(row, "igCollect", 20)
        extra:SetFont(font)
        extra:SetText(string.format("+%d", plus))
        extra:SetHidden(false)
        extra:ClearAnchors()
        extra:SetAnchor(RIGHT, row, TOPRIGHT, rightInset, lineY)
        counter:SetAnchor(RIGHT, extra, LEFT, -COLLECTED_GAP, 0)
        IG.SetRowAnimation(row, "collect", PulseCollect)
    else
        if row.igCollect then row.igCollect:SetHidden(true) end
        IG.SetRowAnimation(row, "collect", nil)
        counter:SetAnchor(RIGHT, row, TOPRIGHT, rightInset, lineY)
    end
end

function IG.HideSetCollected(row)
    if row.igCollected then row.igCollected:SetHidden(true) end
    if row.igCollect then row.igCollect:SetHidden(true) end
    IG.SetRowAnimation(row, "collect", nil)
end

---------------------------------------------------------------------------
-- Hover tooltip
---------------------------------------------------------------------------

local ACTIVE_BONUS = { 0.92, 0.92, 0.88 }
local INACTIVE_BONUS = { 0.5, 0.5, 0.5 }

function IG.ShowSetTooltip(row, data)
    local summary = data.summary
    if not summary or not summary.link then return end
    local r, g, b = IG.HexToRGB(data.color)

    InitializeTooltip(InformationTooltip, row, RIGHT, -12, 0, LEFT)
    InformationTooltip:AddLine(data.label, "ZoFontWinH2", r, g, b)
    if data.location then
        InformationTooltip:AddLine(data.location, "ZoFontGameSmall", 0.65, 0.65, 0.65)
    end

    ZO_Tooltip_AddDivider(InformationTooltip)
    local owned = CountedPieces(summary)
    local _, _, numBonuses = GetItemLinkSetInfo(summary.link, false)
    for i = 1, numBonuses or 0 do
        local numRequired, description = GetItemLinkSetBonusInfo(summary.link, false, i)
        local color = owned >= numRequired and ACTIVE_BONUS or INACTIVE_BONUS
        InformationTooltip:AddLine(description, "ZoFontGame", unpack(color))
    end

    local function SlotList(counts)
        local parts = {}
        for _, slot in ipairs(SLOTS) do
            local count = counts[slot.key]
            if count then
                parts[#parts + 1] = count > 1 and string.format("%s x%d", slot.label, count) or slot.label
            end
        end
        return #parts > 0 and table.concat(parts, "  ·  ") or nil
    end

    ZO_Tooltip_AddDivider(InformationTooltip)
    InformationTooltip:AddLine("In this bag", "ZoFontWinH5", r, g, b)
    InformationTooltip:AddLine(SlotList(summary.slots) or "-", "ZoFontGame", unpack(ACTIVE_BONUS))
    local worn = SlotList(summary.worn)
    if worn then
        InformationTooltip:AddLine("Equipped", "ZoFontWinH5", unpack(WORN_COLOR))
        InformationTooltip:AddLine(worn, "ZoFontGame", unpack(WORN_COLOR))
    end

    if summary.uncollected > 0 then
        InformationTooltip:AddLine(string.format("%d not in your set collection yet", summary.uncollected),
            "ZoFontGame", unpack(COLLECT_COLOR))
    end
end

function IG.HideSetTooltip()
    ClearTooltip(InformationTooltip)
end
