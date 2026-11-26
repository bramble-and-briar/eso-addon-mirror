MWC.Enchanting = {
  ITEMS_PER_WRIT = 1,
  YIELD = 1,
  STACK_SIZE = 1,
}

-- Writ field 2: glyph level. Writ field 3: quality (functional quality ids).
local LEVEL_CP = { [207] = 150, [225] = 160 }
local POTENCY_RUNE = {
  add = { [207] = 64509, [225] = 68341 }, -- Rejera, Repora
  sub = { [207] = 64508, [225] = 68340 }, -- Jehade, Itade
}
local ASPECT_RUNE = { [4] = 45853, [5] = 45854 } -- Rekuta, Kuta

local OKO, MAKKO, DENI, OKOMA, MAKKOMA, DENIMA = 45831, 45832, 45833, 45834, 45835, 45836
local KUOKO, RAKEIPA, DEKEIPA, MEIP, HAOKO, DETERI = 45837, 45838, 45839, 45840, 45841, 45842
local OKORI, ORU, TADERI, MAKDERI, KADERI, HAKEIJO = 45843, 45846, 45847, 45848, 45849, 68342

-- Glyph item id -> essence rune and potency type. The item id is the same at every level.
local GLYPHS = {
  [26580] = { OKO, "add" },      -- Health
  [26582] = { MAKKO, "add" },    -- Magicka
  [26588] = { DENI, "add" },     -- Stamina
  [68343] = { HAKEIJO, "add" },  -- Prismatic Defense
  [26848] = { RAKEIPA, "add" },  -- Flame
  [45869] = { OKOMA, "sub" },    -- Decrease Health
  [54484] = { OKORI, "add" },    -- Weapon Damage
  [26841] = { HAOKO, "add" },    -- Foulness
  [26587] = { KUOKO, "add" },    -- Poison
  [5365] = { DEKEIPA, "add" },   -- Frost
  [26844] = { MEIP, "add" },     -- Shock
  [5366] = { DETERI, "add" },    -- Hardening
  [26845] = { DETERI, "sub" },   -- Crushing
  [26591] = { OKORI, "sub" },    -- Weakening
  [43573] = { OKO, "sub" },      -- Absorb Health
  [45867] = { DENI, "sub" },     -- Absorb Stamina
  [45868] = { MAKKO, "sub" },    -- Absorb Magicka
  [68344] = { HAKEIJO, "sub" },  -- Prismatic Onslaught
  [5364] = { DEKEIPA, "sub" },   -- Frost Resist
  [26589] = { DENIMA, "add" },   -- Stamina Recovery
  [45871] = { DENIMA, "sub" },   -- Reduce Feat Cost
  [26847] = { HAOKO, "sub" },    -- Disease Resist
  [45872] = { KADERI, "add" },   -- Bashing
  [45873] = { KADERI, "sub" },   -- Shielding
  [26586] = { KUOKO, "sub" },    -- Poison Resist
  [45884] = { MAKDERI, "add" },  -- Increase Magical Harm
  [45886] = { MAKDERI, "sub" },  -- Decrease Spell Harm
  [26583] = { MAKKOMA, "add" },  -- Magicka Recovery
  [45870] = { MAKKOMA, "sub" },  -- Reduce Spell Cost
  [43570] = { MEIP, "sub" },     -- Shock Resist
  [26581] = { OKOMA, "add" },    -- Health Recovery
  [45874] = { ORU, "add" },      -- Potion Boost
  [45875] = { ORU, "sub" },      -- Potion Speed
  [26849] = { RAKEIPA, "sub" },  -- Flame Resist
  [45883] = { TADERI, "add" },   -- Increase Physical Harm
  [45885] = { TADERI, "sub" },   -- Decrease Physical Harm
}

function MWC.Enchanting.GlyphIds()
  local ids = {}
  for id in pairs(GLYPHS) do
    table.insert(ids, id)
  end
  return ids
end

-- Every rune a master writ can ask for, with its kind (for the Key items list).
function MWC.Enchanting.WritRunes()
  local runes, seen = {}, {}
  local function Add(id, kind)
    if not seen[id] then
      seen[id] = true
      table.insert(runes, { itemId = id, kind = kind })
    end
  end
  for _, byLevel in pairs(POTENCY_RUNE) do
    for _, id in pairs(byLevel) do Add(id, "Potency") end
  end
  for _, glyph in pairs(GLYPHS) do Add(glyph[1], "Essence") end
  for _, id in pairs(ASPECT_RUNE) do Add(id, "Aspect") end
  return runes
end

local GLYPH_ITEM_TYPES = {
  [ITEMTYPE_GLYPH_ARMOR] = true,
  [ITEMTYPE_GLYPH_WEAPON] = true,
  [ITEMTYPE_GLYPH_JEWELRY] = true,
}
local RESULT_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

function MWC.Enchanting.IndexKey(glyphId, quality, cp)
  return string.format("glyph:%d:%d:%d", glyphId, quality, cp)
end

-- A gold (legendary) glyph needs Kuta, which only Aspect Improvement at its top rank allows (the game's
-- ENCHANTING_RARITY_LEVEL bonus at 4).
local GOLD_QUALITY = 5
local GOLD_ASPECT_LEVEL = 4

function MWC.Enchanting.CanUseGoldAspect()
  local level = MWC.SkillBonus("NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL")
  return level == nil or level >= GOLD_ASPECT_LEVEL
end

function MWC.Enchanting.NeedsGoldAspect(quality)
  return quality == GOLD_QUALITY
end

-- What a writ asks for: the three runes and how to recognise the finished glyph. Nil plus a reason if unknown.
function MWC.Enchanting.Recipe(writ)
  local glyphId, levelCode, quality = writ.fields[1], writ.fields[2], writ.fields[3]
  local glyph = GLYPHS[glyphId]
  if not glyph then return nil, "unknown glyph" end
  local potency, aspect, cp = POTENCY_RUNE[glyph[2]][levelCode], ASPECT_RUNE[quality], LEVEL_CP[levelCode]
  if not (potency and aspect and cp) then return nil, "unknown glyph level or quality" end
  return {
    runes = { potency, glyph[1], aspect },
    quality = quality,
    indexKey = MWC.Enchanting.IndexKey(glyphId, quality, cp),
  }
end

local keyByLink = {}

function MWC.Enchanting.SlotIndexKey(bag, slot)
  if not GLYPH_ITEM_TYPES[GetItemType(bag, slot)] or not MWC.IsMine(bag, slot) then return nil end
  local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
  local key = keyByLink[link]
  if not key then
    key = MWC.Enchanting.IndexKey(GetItemLinkItemId(link), GetItemLinkFunctionalQuality(link),
      GetItemLinkRequiredChampionPoints(link))
    keyByLink[link] = key
  end
  return key
end

-- One pass over the bags: index key -> { bag = n, bank = n } for glyphs.
function MWC.Enchanting.GlyphIndex()
  local index = {}
  for _, at in ipairs(MWC.ItemSlots(RESULT_BAGS, GLYPH_ITEM_TYPES)) do
    local bag, slot = at[1], at[2]
    local key = MWC.Enchanting.SlotIndexKey(bag, slot)
    if key then
      local entry = index[key] or { bag = 0, bank = 0 }
      index[key] = entry
      if bag == BAG_BACKPACK then
        entry.bag = entry.bag + GetSlotStackSize(bag, slot)
      else
        entry.bank = entry.bank + GetSlotStackSize(bag, slot)
      end
    end
  end
  return index
end

function MWC.Enchanting.CountResults(group)
  local entry = MWC.Enchanting.GlyphIndex()[group.indexKey]
  return entry and (entry.bag + entry.bank) or 0
end
