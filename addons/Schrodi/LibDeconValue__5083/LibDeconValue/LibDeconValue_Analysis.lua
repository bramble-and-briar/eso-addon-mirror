LibDeconValue = LibDeconValue or {}
local LibDeconValue = LibDeconValue

-- Built-in guesses (DeconOrSell defaults; runes from LibLootStats). They are only a
-- starting point: LibDeconValue.Stats blends them with what your own deconstructions
-- returned (see LibDeconValue_Stats.lua).
local baseChance = 1
local baseIntricateChance = 3
local craftedChance = 5
local styleChance = 0.4
local upgradeChance = 0.75
local traitChance = 0.75
local jewelryTraitFragments = 1 -- pulverized fragments per jewelry piece; 10 refine into 1 trait material
local runeChance = 0.29
local reconstructedCrystals = 25 -- reconstructed items (epic or better) return Transmute Crystals only

local Analysis = {}
LibDeconValue.Analysis = Analysis

local itemTypeVector = {
  [ITEMTYPE_ARMOR_BOOSTER] = 'improvement',
  [ITEMTYPE_ARMOR_TRAIT] = 'trait',
  [ITEMTYPE_BLACKSMITHING_BOOSTER] = 'improvement',
  [ITEMTYPE_BLACKSMITHING_MATERIAL] = 'material',
  [ITEMTYPE_BLACKSMITHING_RAW_MATERIAL] = 'raw',
  [ITEMTYPE_CLOTHIER_BOOSTER] = 'improvement',
  [ITEMTYPE_CLOTHIER_MATERIAL] = 'material',
  [ITEMTYPE_CLOTHIER_RAW_MATERIAL] = 'raw',
  [ITEMTYPE_ENCHANTING_RUNE_ASPECT] = 'aspect',
  [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = 'essence',
  [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = 'potency',
  [ITEMTYPE_FURNISHING_MATERIAL] = 'furnishing_material',
  [ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = 'improvement',
  [ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER] = 'raw_improvement',
  [ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = 'material',
  [ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL] = 'raw',
  [ITEMTYPE_JEWELRY_RAW_TRAIT] = 'raw_trait',
  [ITEMTYPE_JEWELRY_TRAIT] = 'trait',
  [ITEMTYPE_RAW_MATERIAL] = 'raw_style',
  [ITEMTYPE_STYLE_MATERIAL] = 'style',
  [ITEMTYPE_WEAPON_BOOSTER] = 'improvement',
  [ITEMTYPE_WEAPON_TRAIT] = 'trait',
  [ITEMTYPE_WOODWORKING_BOOSTER] = 'improvement',
  [ITEMTYPE_WOODWORKING_MATERIAL] = 'material',
  [ITEMTYPE_WOODWORKING_RAW_MATERIAL] = 'raw',
}
Analysis.itemTypeVector = itemTypeVector

-- No longer used internally, kept for addons that may call it.
local function ParseItemLink(itemLink)
  return {string.match(itemLink, "^|H(%d):item:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)|h(.*)|h")}
end
Analysis.ParseItemLink = ParseItemLink

-- The game's own flags instead of guessing (previously: vendor value ~= 500 and bit 256 of
-- link field 15). Stolen items have to be laundered before they can be deconstructed.
local function IsItemLinkDeconstructable(itemLink)
  if not itemLink or itemLink == "" then
    return false
  end
  if itemTypeVector[GetItemLinkItemType(itemLink)] then
    return false
  end

  local craftingType = GetItemLinkCraftingSkillType(itemLink)
  if craftingType == CRAFTING_TYPE_INVALID or craftingType == CRAFTING_TYPE_ALCHEMY or craftingType == CRAFTING_TYPE_PROVISIONING then
    return false
  end
  if IsItemLinkForcedNotDeconstructable(itemLink) or IsItemLinkStolen(itemLink) then
    return false
  end
  return not ZO_IsElementInNumericallyIndexedTable({GetItemLinkFilterTypeInfo(itemLink)}, ITEMFILTERTYPE_COMPANION)
end
Analysis.IsItemLinkDeconstructable = IsItemLinkDeconstructable

function Analysis.ItemVendorValue(item)
  local value = GetItemLinkValue(item)
  if IsItemLinkStolen(item) then
    value = value * 1.1
  end
  return value
end

function Analysis.ItemSaleValue(item)
  local value = GetItemLinkValue(item)
  if IsItemLinkStolen(item) then
    value = value * 1.1
  end
  if not IsItemLinkBound(item) then
    local price = LibPrice and LibPrice.ItemLinkToPriceGold and LibPrice.ItemLinkToPriceGold(item)
    if price then
      return price
    end
  end
  return value
end

-- Rows may carry altItem/altFactor: the unit value is then the better of the two
-- (a pulverized fragment is worth at least 1/10 of the refined trait material).
-- Currency rows (row.currency) have no gold value.
local function AttachExpectationValues(expectation, getValue, minMatPrice)
  minMatPrice = minMatPrice or 0
  local totalValue = 0
  for _, row in ipairs(expectation) do
    if row.item then
      local value = getValue(row.item)
      if row.altItem then
        local altValue = getValue(row.altItem)
        if altValue then
          altValue = altValue * (row.altFactor or 1)
          if not value or altValue > value then
            value = altValue
          end
        end
      end
      if value and value > minMatPrice then
        local expectedValue = value * row.expected
        row.value = expectedValue
        totalValue = totalValue + expectedValue
      end
    end
  end
  expectation.value = totalValue
end
Analysis.AttachExpectationValues = AttachExpectationValues

function LibDeconValue:FindDeconstructionExpectation(itemLink, getValue, minMatPrice)
  if not IsItemLinkDeconstructable(itemLink) then
    return
  end

  local expectation = self.ItemDeconstructionUpside(itemLink) or {}

  if getValue then
    AttachExpectationValues(expectation, getValue, minMatPrice)
  end
  return expectation
end

local function ItemLinkToMaterialId(itemLink)
  local data = LibDeconValue.Data
  if not data then return end

  local craftingType = GetItemLinkCraftingSkillType(itemLink)
  local tableSet = data.base_id[craftingType]
  if not tableSet then return end

  local level = tonumber(GetItemLinkRequiredLevel(itemLink)) or 0
  local cp = tonumber(GetItemLinkRequiredChampionPoints(itemLink)) or 0
  local ranges = cp > 0 and tableSet.cp or tableSet.level
  if not ranges then return end

  local armorType = craftingType == CRAFTING_TYPE_CLOTHIER and GetItemLinkArmorType(itemLink)

  for _, range in ipairs(ranges) do
    if cp > 0 then
      if cp >= range.min and cp <= range.max then
        if armorType == ARMORTYPE_LIGHT then return range.light
        elseif armorType == ARMORTYPE_MEDIUM then return range.medium
        elseif armorType == ARMORTYPE_HEAVY then return range.heavy
        else return range.id end
      end
    else
      if level >= range.min and level <= range.max then
        if armorType == ARMORTYPE_LIGHT then return range.light
        elseif armorType == ARMORTYPE_MEDIUM then return range.medium
        elseif armorType == ARMORTYPE_HEAVY then return range.heavy
        else return range.id end
      end
    end
  end
end

local function ReplaceItemId(itemLink, itemId)
  return (string.gsub(itemLink, "^(|H%d:item:)%d+", function(prefix) return prefix .. itemId end, 1))
end

local pulverizedCache = {}

-- Jewelry deconstruction returns pulverized trait fragments. There is no API from the
-- refined material to its raw form, so use fragments already seen in deconstruction
-- results, or look for the raw item next to the refined item id.
local function GetPulverizedTraitLink(refinedLink)
  local refinedId = GetItemLinkItemId(refinedLink)
  if not refinedId or refinedId == 0 then return end

  local rawId = LibDeconValue.Stats.GetKnownRawTrait(refinedId) or pulverizedCache[refinedId]
  if rawId == nil then
    rawId = false
    for delta = 1, 12 do
      for sign = -1, 1, 2 do
        local candidateId = refinedId + sign * delta
        local candidate = ReplaceItemId(refinedLink, candidateId)
        if GetItemLinkItemType(candidate) == ITEMTYPE_JEWELRY_RAW_TRAIT then
          local refined = GetItemLinkRefinedMaterialItemLink(candidate, LINK_STYLE_DEFAULT)
          if refined and refined ~= "" and GetItemLinkItemId(refined) == refinedId then
            rawId = candidateId
            break
          end
        end
      end
      if rawId then break end
    end
    pulverizedCache[refinedId] = rawId
  end
  return rawId and ReplaceItemId(refinedLink, rawId) or nil
end
Analysis.GetPulverizedTraitLink = GetPulverizedTraitLink

local function AddRow(outcome, row)
  if row.item ~= "" and row.expected and row.expected > 0 then
    table.insert(outcome, row)
  end
end

--- Expected deconstruction results: rows { item = link | currency = CURT_*, expected,
-- samples = number of recorded deconstructions behind the expectation }.
function LibDeconValue.ItemDeconstructionUpside(itemLink, getValue)
  if not IsItemLinkDeconstructable(itemLink) then
    return
  end

  local Stats = LibDeconValue.Stats
  local d = Stats.Describe(itemLink)
  if not d then
    return
  end
  local keys = Stats.KeysFor(d)

  local function Expected(channel, prior)
    local info = keys[channel]
    if not info then
      return prior, 0
    end
    return Stats.Expected(info.key, prior)
  end

  local outcome = {}

  if d.craft == CRAFTING_TYPE_ENCHANTING then
    local lookup = LibLazyCrafting and LibLazyCrafting.getComponentRunesForGlyphItemLink
    if lookup then
      local ids = lookup(itemLink) or {}
      local function AddRune(itemId, channel)
        if itemId then
          local expected, samples = Expected(channel, runeChance)
          AddRow(outcome, { item = '|H0:item:' .. itemId .. ':0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h', expected = expected, samples = samples })
        end
      end
      AddRune(ids.aspectItemID, "EN:aspect:" .. d.quality)
      AddRune(ids.essenceItemID, "EN:essence")
      AddRune(ids.potencyItemID, "EN:potency")
    end
  else
    local craftingType = d.craft
    local reconstructed = d.origin == "R"

    local baseMaterialId = ItemLinkToMaterialId(itemLink)
    if baseMaterialId then
      local prior
      if reconstructed then
        prior = 0
      elseif d.origin == "C" then
        prior = craftedChance
      elseif d.intricate then
        prior = baseIntricateChance
      else
        prior = baseChance
      end
      local expected, samples = Expected("base:" .. d.code, prior)
      AddRow(outcome, { item = string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", baseMaterialId), expected = expected, samples = samples })
    end

    if d.styleLink then
      local expected, samples = Expected("style", reconstructed and 0 or styleChance)
      AddRow(outcome, { item = d.styleLink, expected = expected, samples = samples })
    end

    if d.quality > ITEM_FUNCTIONAL_QUALITY_NORMAL then
      local expected, samples = Expected("imp:" .. d.code .. ":" .. d.quality, upgradeChance)
      AddRow(outcome, { item = GetSmithingImprovementItemLink(craftingType, d.quality - 1, LINK_STYLE_DEFAULT), expected = expected, samples = samples })
    end

    if d.traitGroup then
      local traitLink = GetSmithingTraitItemLink(d.trait + 1, LINK_STYLE_DEFAULT)
      if d.traitGroup == "jw" then
        local expected, samples = Expected("trait:jw", reconstructed and 0 or jewelryTraitFragments)
        local pulverizedLink = GetPulverizedTraitLink(traitLink)
        if pulverizedLink then
          AddRow(outcome, { item = pulverizedLink, expected = expected, samples = samples, altItem = traitLink, altFactor = 0.1 })
        else
          AddRow(outcome, { item = traitLink, expected = expected * 0.1, samples = samples })
        end
      else
        local expected, samples = Expected("trait:" .. d.traitGroup, reconstructed and 0 or traitChance)
        AddRow(outcome, { item = traitLink, expected = expected, samples = samples })
      end
    end

    if reconstructed then
      local prior = d.quality >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT and reconstructedCrystals or 0
      local expected, samples = Expected("crystals", prior)
      if expected > 0 then
        table.insert(outcome, { currency = CURT_TRANSMUTE_CRYSTALS, expected = expected, samples = samples })
      end
    end
  end

  if getValue then
    AttachExpectationValues(outcome, getValue, 0)
  end
  return outcome
end
