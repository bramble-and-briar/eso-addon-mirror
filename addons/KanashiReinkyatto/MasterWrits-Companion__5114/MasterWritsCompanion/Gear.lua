-- Blacksmithing, clothing, woodworking and jewelry writs: recognising finished items and their materials.
-- Writ task fields: 1 item code, 2 material code, 3 quality, 4 set id, 5 trait type, 6 style id (0 for jewelry).
MWC.Gear = {
  ITEMS_PER_WRIT = 1,
  STACK_SIZE = 1,
  REQUIRED_CP = 150,
  -- Crown Mimic Stone: replaces the style material (the motif must still be known). Used only for writs the
  -- player switched to it, never on its own: the stones are valuable.
  MIMIC_STONE_ID = 71668,
}

local GEAR_ITEM_TYPES = { [ITEMTYPE_WEAPON] = true, [ITEMTYPE_ARMOR] = true }
local RESULT_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- The crafted item is named after its set ("Pauldron of Hunding's Rage"), not like the writ ("Rubedite
-- Pauldron"), so items are matched by kind: weapon type, or armor weight plus slot, or jewelry slot.
-- Light chests come as robe or jerkin; only the icon tells them apart.
local function WeaponKind(weaponType)
  return "w" .. weaponType
end

local function ArmorKind(armorType, equipType, cut)
  return string.format("a%d:%d%s", armorType, equipType, cut and (":" .. cut) or "")
end

local function JewelryKind(equipType)
  return "j" .. equipType
end

local H, M, L = ARMORTYPE_HEAVY, ARMORTYPE_MEDIUM, ARMORTYPE_LIGHT
-- Writ field 1 (item code) -> kind.
local ITEM_KIND = {
  [53] = WeaponKind(WEAPONTYPE_AXE), [56] = WeaponKind(WEAPONTYPE_HAMMER), [59] = WeaponKind(WEAPONTYPE_SWORD),
  [68] = WeaponKind(WEAPONTYPE_TWO_HANDED_AXE), [67] = WeaponKind(WEAPONTYPE_TWO_HANDED_SWORD),
  [69] = WeaponKind(WEAPONTYPE_TWO_HANDED_HAMMER), [62] = WeaponKind(WEAPONTYPE_DAGGER),
  [46] = ArmorKind(H, EQUIP_TYPE_CHEST), [50] = ArmorKind(H, EQUIP_TYPE_FEET), [52] = ArmorKind(H, EQUIP_TYPE_HAND),
  [44] = ArmorKind(H, EQUIP_TYPE_HEAD), [49] = ArmorKind(H, EQUIP_TYPE_LEGS), [47] = ArmorKind(H, EQUIP_TYPE_SHOULDERS),
  [48] = ArmorKind(H, EQUIP_TYPE_WAIST),
  [28] = ArmorKind(L, EQUIP_TYPE_CHEST, "robe"), [75] = ArmorKind(L, EQUIP_TYPE_CHEST, "shirt"),
  [32] = ArmorKind(L, EQUIP_TYPE_FEET), [34] = ArmorKind(L, EQUIP_TYPE_HAND), [26] = ArmorKind(L, EQUIP_TYPE_HEAD),
  [31] = ArmorKind(L, EQUIP_TYPE_LEGS), [29] = ArmorKind(L, EQUIP_TYPE_SHOULDERS), [30] = ArmorKind(L, EQUIP_TYPE_WAIST),
  [37] = ArmorKind(M, EQUIP_TYPE_CHEST), [41] = ArmorKind(M, EQUIP_TYPE_FEET), [43] = ArmorKind(M, EQUIP_TYPE_HAND),
  [35] = ArmorKind(M, EQUIP_TYPE_HEAD), [40] = ArmorKind(M, EQUIP_TYPE_LEGS), [38] = ArmorKind(M, EQUIP_TYPE_SHOULDERS),
  [39] = ArmorKind(M, EQUIP_TYPE_WAIST),
  [70] = WeaponKind(WEAPONTYPE_BOW), [72] = WeaponKind(WEAPONTYPE_FIRE_STAFF), [73] = WeaponKind(WEAPONTYPE_FROST_STAFF),
  [74] = WeaponKind(WEAPONTYPE_LIGHTNING_STAFF), [71] = WeaponKind(WEAPONTYPE_HEALING_STAFF), [65] = WeaponKind(WEAPONTYPE_SHIELD),
  [24] = JewelryKind(EQUIP_TYPE_RING), [18] = JewelryKind(EQUIP_TYPE_NECK),
}

-- Writ item code -> research line and the regular station's pattern (they differ for clothing and
-- woodworking: robe and jerkin share a research line, the shield is the second pattern but the sixth line).
local BS_CODES = { 53, 56, 59, 68, 69, 67, 62, 46, 50, 52, 44, 49, 47, 48 } -- axe … dagger, cuirass … girdle
local CL_CODES = { 28, 75, 32, 34, 26, 31, 29, 30, 37, 41, 43, 35, 40, 38, 39 } -- robe, jerkin … sash, jack … belt
local CL_LINES = { 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }
local WW_CODES = { 70, 65, 72, 73, 74, 71 } -- bow, shield, inferno, ice, lightning, restoration (pattern order)
local WW_LINES = { 1, 6, 2, 3, 4, 5 }
local CRAFT_OF = {}
local LINE_OF, PATTERN_OF = {}, {}
for i, code in ipairs(BS_CODES) do
  CRAFT_OF[code], LINE_OF[code], PATTERN_OF[code] = CRAFTING_TYPE_BLACKSMITHING, i, i
end
for i, code in ipairs(CL_CODES) do
  CRAFT_OF[code], LINE_OF[code], PATTERN_OF[code] = CRAFTING_TYPE_CLOTHIER, CL_LINES[i], i
end
for i, code in ipairs(WW_CODES) do
  CRAFT_OF[code], LINE_OF[code], PATTERN_OF[code] = CRAFTING_TYPE_WOODWORKING, WW_LINES[i], i
end
CRAFT_OF[24], LINE_OF[24] = CRAFTING_TYPE_JEWELRYCRAFTING, 1 -- ring
CRAFT_OF[18], LINE_OF[18] = CRAFTING_TYPE_JEWELRYCRAFTING, 2 -- necklace

-- Writ item code -> the motif chapter (book page) the piece needs.
local CHAPTER_OF = {}
local function Chapter(chapter, codes)
  for _, code in ipairs(codes) do
    CHAPTER_OF[code] = chapter
  end
end
Chapter(ITEM_STYLE_CHAPTER_AXES, { 53, 68 })
Chapter(ITEM_STYLE_CHAPTER_MACES, { 56, 69 })
Chapter(ITEM_STYLE_CHAPTER_SWORDS, { 59, 67 })
Chapter(ITEM_STYLE_CHAPTER_DAGGERS, { 62 })
Chapter(ITEM_STYLE_CHAPTER_CHESTS, { 46, 28, 75, 37 })
Chapter(ITEM_STYLE_CHAPTER_BOOTS, { 50, 32, 41 })
Chapter(ITEM_STYLE_CHAPTER_GLOVES, { 52, 34, 43 })
Chapter(ITEM_STYLE_CHAPTER_HELMETS, { 44, 26, 35 })
Chapter(ITEM_STYLE_CHAPTER_LEGS, { 49, 31, 40 })
Chapter(ITEM_STYLE_CHAPTER_SHOULDERS, { 47, 29, 38 })
Chapter(ITEM_STYLE_CHAPTER_BELTS, { 48, 30, 39 })
Chapter(ITEM_STYLE_CHAPTER_BOWS, { 70 })
Chapter(ITEM_STYLE_CHAPTER_STAVES, { 72, 73, 74, 71 })
Chapter(ITEM_STYLE_CHAPTER_SHIELDS, { 65 })

-- Whether the writ's trait is researched on its item, and how many traits that item has researched.
-- Nil when the item code is unknown.
function MWC.Gear.TraitResearch(fields)
  local craft, line = CRAFT_OF[fields[1]], LINE_OF[fields[1]]
  if not craft then return nil end
  local known, count = false, 0
  local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
  for trait = 1, numTraits or 0 do
    local traitType, _, isKnown = GetSmithingResearchLineTraitInfo(craft, line, trait)
    if isKnown then
      count = count + 1
      if traitType == fields[5] then
        known = true
      end
    end
  end
  return known, count
end

-- Traits a set needs researched, learned from the station (the game tells it only there) and kept.
function MWC.Gear.RememberSetTraits(setId, required)
  if setId and required and required > 0 then
    MWC.sv.setTraits = MWC.sv.setTraits or {}
    MWC.sv.setTraits[setId] = required
  end
end

-- What the station said, else LibSets' data (installed with WritWorthy), else nil (checked at the station).
function MWC.Gear.SetTraitsRequired(setId)
  local seen = MWC.sv.setTraits and MWC.sv.setTraits[setId]
  if seen then return seen end
  if LibSets and LibSets.GetTraitsNeeded then
    local ok, needed = pcall(LibSets.GetTraitsNeeded, setId)
    if ok and type(needed) == "number" then return needed end
  end
end

-- Gold quality takes 8 tempers per item at full improvement skill and many more below it.
function MWC.Gear.IsImprovementMaxed(writType)
  return MWC.Gear.BoostersForStep(writType, 4) <= 8
end

-- The exact item id of a writ's set item is known at the station; once seen, its kind is remembered, so a
-- robe and a jerkin (same slot and weight) are told apart by id instead of by their icon's file name.
-- Link -> its key parts and whether it is writ-grade, worked out once (a link never changes). Emptied when an
-- item's kind is learned, since that can change a key.
local keyPartsByLink, gradeByLink = {}, {}

function MWC.Gear.RememberItemKind(itemId, kind)
  if itemId and itemId ~= 0 then
    MWC.sv.gearKinds = MWC.sv.gearKinds or {}
    if MWC.sv.gearKinds[itemId] ~= kind then
      MWC.sv.gearKinds[itemId] = kind
      keyPartsByLink = {}
    end
  end
end

function MWC.Gear.KindOfLink(link)
  local remembered = MWC.sv.gearKinds and MWC.sv.gearKinds[GetItemLinkItemId(link)]
  if remembered then return remembered end
  local weaponType = GetItemLinkWeaponType(link)
  if weaponType ~= WEAPONTYPE_NONE then return WeaponKind(weaponType) end
  local equipType = GetItemLinkEquipType(link)
  if equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK then return JewelryKind(equipType) end
  local armorType = GetItemLinkArmorType(link)
  local cut
  if armorType == L and equipType == EQUIP_TYPE_CHEST then
    local icon = zo_strlower((GetItemLinkInfo(link)))
    cut = icon:find("robe", 1, true) and "robe" or icon:find("shirt", 1, true) and "shirt" or "unknown"
  end
  return ArmorKind(armorType, equipType, cut)
end

function MWC.Gear.WritKind(fields)
  return ITEM_KIND[fields[1]] or ("code" .. fields[1])
end

function MWC.Gear.IndexKey(kind, setId, trait, style, quality)
  return string.format("gear:%s:%d:%d:%d:%d", kind, setId, trait, style, quality)
end

function MWC.Gear.WritKey(writ)
  local fields = writ.fields
  return MWC.Gear.IndexKey(MWC.Gear.WritKind(fields), fields[4], fields[5], fields[6], fields[3])
end

-- The same key for an item, at the given quality instead of its own (used while improving).
function MWC.Gear.LinkKey(link, quality)
  local parts = keyPartsByLink[link]
  if not parts then
    parts = { MWC.Gear.KindOfLink(link), select(6, GetItemLinkSetInfo(link)) or 0, (GetItemLinkTraitInfo(link)),
      GetItemLinkItemStyle(link), GetItemLinkFunctionalQuality(link) }
    keyPartsByLink[link] = parts
  end
  return MWC.Gear.IndexKey(parts[1], parts[2], parts[3], parts[4], quality or parts[5])
end

function MWC.Gear.IsWritGrade(link)
  local grade = gradeByLink[link]
  if grade == nil then
    -- Exactly CP150: a CP160 item of the same set, trait and style doesn't satisfy the writ.
    grade = (GEAR_ITEM_TYPES[GetItemLinkItemType(link)] and IsItemLinkCrafted(link)
      and GetItemLinkRequiredChampionPoints(link) == MWC.Gear.REQUIRED_CP) or false
    gradeByLink[link] = grade
  end
  return grade
end

-- A master writ takes only items this character crafted (the crafter's name is in the item), so items of
-- other characters (shared bank) or bought ones never count as ready or get improved.
function MWC.Gear.IsMine(bag, slot)
  return MWC.IsMine(bag, slot)
end

function MWC.Gear.SlotIndexKey(bag, slot)
  if not GEAR_ITEM_TYPES[GetItemType(bag, slot)] then return nil end
  local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
  if not MWC.Gear.IsWritGrade(link) or not MWC.Gear.IsMine(bag, slot) then return nil end
  return MWC.Gear.LinkKey(link)
end

-- One pass over the bags: index key -> { bag = n, bank = n } for crafted writ-grade gear.
function MWC.Gear.Index()
  local index = {}
  for _, at in ipairs(MWC.ItemSlots(RESULT_BAGS, GEAR_ITEM_TYPES)) do
    local bag, slot = at[1], at[2]
    local key = MWC.Gear.SlotIndexKey(bag, slot)
    if key then
      local entry = index[key] or { bag = 0, bank = 0 }
      index[key] = entry
      if bag == BAG_BACKPACK then
        entry.bag = entry.bag + 1
      else
        entry.bank = entry.bank + 1
      end
    end
  end
  return index
end

-- "Craft a Rubedite Dagger; Quality: ..." -> "Rubedite Dagger"
function MWC.Gear.ItemName(writLink)
  local text = GenerateMasterWritBaseText(writLink) or ""
  return text:match("Craft an? (.-);") or text:match("^[^\n]*")
end

-- Whether the character knows a style (motif) for the writ's piece. Motifs come in chapters (one per piece).
-- LibCharacterKnowledge (installed with WritWorthy, which uses it the same way) answers per chapter; without
-- it the game is asked for the piece's station pattern. Nil when neither can tell.
function MWC.Gear.IsStyleKnown(styleId, itemCode)
  if styleId == 0 then return true end
  local chapter = itemCode and CHAPTER_OF[itemCode]
  local LCK = LibCharacterKnowledge
  if LCK and LCK.GetMotifKnowledgeForCharacter and chapter then
    local ok, knowledge = pcall(LCK.GetMotifKnowledgeForCharacter, styleId, chapter)
    if ok and knowledge == LCK.KNOWLEDGE_KNOWN then return true end
    if ok and knowledge == LCK.KNOWLEDGE_UNKNOWN then return false end
  end
  -- Nil when the game can't tell here: trusted only if it confirms the first style the character knows.
  local pattern = itemCode and PATTERN_OF[itemCode]
  local function Known(style)
    if pattern then return IsSmithingStyleKnown(style, pattern) end
    return IsSmithingStyleKnown(style)
  end
  local reference = GetFirstKnownItemStyleId()
  if not (reference and reference > 0 and Known(reference)) then return nil end
  return Known(styleId)
end

-- Materials ----------------------------------------------------------------
-- Writ field 2 (material code) -> the CP150 base material item.
local BASE_MATERIAL = {
  [188] = 64489, -- Rubedite Ingot
  [190] = 64506, -- Rubedo Leather
  [192] = 64502, -- Sanded Ruby Ash
  [194] = 64504, -- Ancestor Silk
  [255] = 135146, -- Platinum Ounce
}
function MWC.Gear.MaterialCodeOf(itemId)
  for code, id in pairs(BASE_MATERIAL) do
    if id == itemId then return code end
  end
end

local BASE_MATERIALS_BY_CRAFT = {
  blacksmithing = { 64489 },
  clothier = { 64504, 64506 },
  woodworking = { 64502 },
  jewelry = { 135146 },
}
-- Writ field 1 (item code) -> base material count for one CP150 item (a tenth of the CP160 count the stations show).
local BASE_QUANTITY = {
  [53] = 11, [56] = 11, [59] = 11, [68] = 14, [67] = 14, [69] = 14, [62] = 10, -- axe, mace, sword, battle axe, greatsword, maul, dagger
  [46] = 15, [50] = 13, [52] = 13, [44] = 13, [49] = 14, [47] = 13, [48] = 13, -- cuirass, sabatons, gauntlets, helm, greaves, pauldron, girdle
  [28] = 15, [75] = 15, [32] = 13, [34] = 13, [26] = 13, [31] = 14, [29] = 13, [30] = 13, -- robe, jerkin, shoes, gloves, hat, breeches, epaulets, sash
  [37] = 15, [41] = 13, [43] = 13, [35] = 13, [40] = 14, [38] = 13, [39] = 13, -- jack, boots, bracers, helmet, guards, arm cops, belt
  [70] = 12, [72] = 12, [73] = 12, [74] = 12, [71] = 12, [65] = 14, -- bow, inferno, ice, lightning, restoration staff, shield
  [24] = 10, [18] = 15, -- ring, necklace
}
-- Improvement materials per quality step (green, blue, purple, gold). Jewelry platings exist under two ids
-- (old and current items); the one you own wins, then the one the station names, then the current one.
local IMPROVEMENT = {
  blacksmithing = { { 54170 }, { 54171 }, { 54172 }, { 54173 } }, -- honing stone, dwarven oil, grain solvent, tempering alloy
  clothier = { { 54174 }, { 54175 }, { 54176 }, { 54177 } }, -- hemming, embroidery, elegant lining, dreugh wax
  woodworking = { { 54178 }, { 54179 }, { 54180 }, { 54181 } }, -- pitch, turpen, mastic, rosin
  jewelry = { { 203631, 135147 }, { 203632, 135148 }, { 203633, 135149 }, { 203634, 135150 } }, -- terne, iridium, zircon, chromium
}
local CRAFT_TYPE = {
  blacksmithing = CRAFTING_TYPE_BLACKSMITHING, clothier = CRAFTING_TYPE_CLOTHIER,
  woodworking = CRAFTING_TYPE_WOODWORKING, jewelry = CRAFTING_TYPE_JEWELRYCRAFTING,
}
-- The improvement passive raises the chance per booster by this many percent (150 at full rank).
local BOOSTER_BONUS = {
  blacksmithing = NON_COMBAT_BONUS_BLACKSMITHING_BOOSTER_BONUS, clothier = NON_COMBAT_BONUS_CLOTHIER_BOOSTER_BONUS,
  woodworking = NON_COMBAT_BONUS_WOODWORKING_BOOSTER_BONUS, jewelry = NON_COMBAT_BONUS_JEWELRYCRAFTING_BOOSTER_BONUS,
}
-- Chance per booster without the passive: 5, 7, 10 and 20 boosters for a sure step; 2, 3, 4 and 8 at full rank.
local BASE_CHANCE = { 20, 100 / 7, 10, 5 }
local CRAFTED_QUALITY = 1

local function Owned(itemId)
  local backpack, bank, craftBag = GetItemLinkStacks(MWC.LinkFromItemId(itemId))
  return backpack + bank + craftBag
end

function MWC.Gear.ImprovementItemId(craft, step)
  local candidates = IMPROVEMENT[craft] and IMPROVEMENT[craft][step]
  if not candidates then return nil end
  if #candidates == 1 then return candidates[1] end
  for _, id in ipairs(candidates) do
    if Owned(id) > 0 then return id end
  end
  local ok, link = pcall(GetSmithingImprovementItemLink, CRAFT_TYPE[craft], step, LINK_STYLE_DEFAULT)
  local id = ok and link and link ~= "" and GetItemLinkItemId(link)
  if id and id ~= 0 then return id end
  return candidates[1]
end

-- Boosters for a sure improvement step at the character's current passive rank.
function MWC.Gear.BoostersForStep(craft, step)
  local bonus = BOOSTER_BONUS[craft] and GetNonCombatBonus(BOOSTER_BONUS[craft]) or 0
  return math.ceil(100 / (BASE_CHANCE[step] * (1 + bonus / 100)) - 0.0001)
end

-- What one item of a gear writ takes besides the trait stone and style material: { itemId, quantity, kind }.
function MWC.Gear.Materials(writType, fields)
  local materials = {}
  local base, count = BASE_MATERIAL[fields[2]], BASE_QUANTITY[fields[1]]
  if base and count then
    table.insert(materials, { itemId = base, quantity = count, kind = "Base" })
  end
  for step = CRAFTED_QUALITY, (fields[3] or CRAFTED_QUALITY) - 1 do
    local id = MWC.Gear.ImprovementItemId(writType, step)
    if id then
      table.insert(materials, { itemId = id, quantity = MWC.Gear.BoostersForStep(writType, step), kind = "Upgrade" })
    end
  end
  return materials
end

-- Base and improvement materials of a craft, for the Keep materials window.
function MWC.Gear.CatalogMaterials(craft)
  local materials = {}
  for _, id in ipairs(BASE_MATERIALS_BY_CRAFT[craft] or {}) do
    table.insert(materials, { itemId = id, kind = "Base" })
  end
  for step = 1, #(IMPROVEMENT[craft] or {}) do
    table.insert(materials, { itemId = MWC.Gear.ImprovementItemId(craft, step), kind = "Upgrade" })
  end
  return materials
end
