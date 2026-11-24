LibDeconValue = LibDeconValue or {}
local LDV = LibDeconValue

-- Learning mode: records what your own deconstructions actually return and blends it
-- with the built-in guesses. Only running totals are kept: for every key a pair
-- { number of deconstructed items, number of yielded materials }, so a new result is
-- an O(1) update and an expectation is a single division.
local Stats = {}
LDV.Stats = Stats

local ADDON_NAME = "LibDeconValue"
local SV_VERSION = 1
-- How many deconstructions the built-in guesses are worth. With n recorded items the
-- expectation is (PRIOR_WEIGHT * guess + yielded) / (PRIOR_WEIGHT + n).
local PRIOR_WEIGHT = 10
local CONTEXT_TTL_MS = 5000
-- Results arriving later than this after the deconstruct message are not trusted.
local RESULT_TIMEOUT_MS = 15000
-- Champion skill id of Meticulous Disassembly (as used by LibLootStats). /ldv prints its name.
local METICULOUS_DISASSEMBLY_ID = 83

local sv

local CRAFT_CODE = {
  [CRAFTING_TYPE_BLACKSMITHING] = "BS",
  [CRAFTING_TYPE_CLOTHIER] = "CL",
  [CRAFTING_TYPE_WOODWORKING] = "WW",
  [CRAFTING_TYPE_JEWELRYCRAFTING] = "JW",
  [CRAFTING_TYPE_ENCHANTING] = "EN",
}
Stats.CRAFT_CODE = CRAFT_CODE

local EXTRACT_BONUS = {
  [CRAFTING_TYPE_BLACKSMITHING] = NON_COMBAT_BONUS_BLACKSMITHING_EXTRACT_LEVEL,
  [CRAFTING_TYPE_CLOTHIER] = NON_COMBAT_BONUS_CLOTHIER_EXTRACT_LEVEL,
  [CRAFTING_TYPE_WOODWORKING] = NON_COMBAT_BONUS_WOODWORKING_EXTRACT_LEVEL,
  [CRAFTING_TYPE_JEWELRYCRAFTING] = NON_COMBAT_BONUS_JEWELRYCRAFTING_EXTRACT_LEVEL,
  [CRAFTING_TYPE_ENCHANTING] = NON_COMBAT_BONUS_ENCHANTING_DECONSTRUCTION_UPGRADE,
}

local NO_TRAIT_MATERIAL = {
  [ITEM_TRAIT_TYPE_NONE] = true,
  [ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = true,
  [ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = true,
  [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = true,
  [ITEM_TRAIT_TYPE_ARMOR_ORNATE] = true,
  [ITEM_TRAIT_TYPE_WEAPON_ORNATE] = true,
  [ITEM_TRAIT_TYPE_JEWELRY_ORNATE] = true,
}

local INTRICATE = {
  [ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = true,
  [ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = true,
  [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = true,
}

local NIRNHONED = {
  [ITEM_TRAIT_TYPE_ARMOR_NIRNHONED] = true,
  [ITEM_TRAIT_TYPE_WEAPON_NIRNHONED] = true,
}

local BASE_MATERIAL = {
  [ITEMTYPE_BLACKSMITHING_MATERIAL] = "BS",
  [ITEMTYPE_CLOTHIER_MATERIAL] = "CL",
  [ITEMTYPE_WOODWORKING_MATERIAL] = "WW",
  [ITEMTYPE_JEWELRYCRAFTING_MATERIAL] = "JW",
}

local BOOSTER = {
  [ITEMTYPE_BLACKSMITHING_BOOSTER] = "BS",
  [ITEMTYPE_CLOTHIER_BOOSTER] = "CL",
  [ITEMTYPE_WOODWORKING_BOOSTER] = "WW",
  [ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = "JW",
}

local function Msg(text)
  d("|c999999LibDeconValue:|r " .. text)
end

----------------------------------------------------------------------------------------
-- Context: everything about the character that may change the yield.

local function Bonus(bonusType)
  if bonusType == nil then return 0 end
  return GetNonCombatBonus(bonusType) or 0
end

local function IsMeticulousDisassemblyActive()
  local id = METICULOUS_DISASSEMBLY_ID
  local maxPoints = GetChampionSkillMaxPoints(id)
  if maxPoints <= 0 or GetNumPointsSpentOnChampionSkill(id) < maxPoints then
    return false
  end
  if CanChampionSkillTypeBeSlotted(GetChampionSkillType(id)) then
    local firstSlot, lastSlot = GetAssignableChampionBarStartAndEndSlots()
    for slot = firstSlot, lastSlot do
      if GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION) == id then
        return true
      end
    end
    return false
  end
  return true
end
Stats.IsMeticulousDisassemblyActive = IsMeticulousDisassemblyActive

local context, contextTime

--- Per crafting type: "<extraction rank>.<meticulous>.<extraction bonus>.<double rewards>"
-- (enchanting: "<rank>.<double rewards>"). Cached for a few seconds.
function Stats.GetContext()
  local now = GetGameTimeMilliseconds()
  if not context or now - contextTime > CONTEXT_TTL_MS then
    local meticulous = IsMeticulousDisassemblyActive() and 1 or 0
    local extraction = Bonus(NON_COMBAT_BONUS_EXTRACTION)
    local double = Bonus(NON_COMBAT_BONUS_DOUBLE_DECONSTRUCTION_REWARDS_CHANCE)
    local ctx = {}
    for craftingType, bonus in pairs(EXTRACT_BONUS) do
      if craftingType == CRAFTING_TYPE_ENCHANTING then
        ctx[craftingType] = string.format("%d.%d", Bonus(bonus), double)
      else
        ctx[craftingType] = string.format("%d.%d.%d.%d", Bonus(bonus), meticulous, extraction, double)
      end
    end
    context, contextTime = ctx, now
  end
  return context
end

----------------------------------------------------------------------------------------
-- Item description and statistic keys.

--- What decides the yield of a deconstructable item.
-- origin: "L" looted, "C" crafted, "R" reconstructed.
function Stats.Describe(itemLink)
  local craftingType = GetItemLinkCraftingSkillType(itemLink)
  local code = CRAFT_CODE[craftingType]
  if not code then return end

  local d = {
    craft = craftingType,
    code = code,
    quality = GetItemLinkFunctionalQuality(itemLink),
  }
  if IsItemLinkReconstructed(itemLink) then
    d.origin = "R"
  elseif IsItemLinkCrafted(itemLink) then
    d.origin = "C"
  else
    d.origin = "L"
  end

  if craftingType ~= CRAFTING_TYPE_ENCHANTING then
    local trait = GetItemLinkTraitType(itemLink)
    d.trait = trait
    d.intricate = INTRICATE[trait] == true
    if not NO_TRAIT_MATERIAL[trait] then
      if craftingType == CRAFTING_TYPE_JEWELRYCRAFTING then
        d.traitGroup = "jw"
      elseif NIRNHONED[trait] then
        d.traitGroup = "nirn"
      else
        d.traitGroup = "std"
      end
    end
    if not DoesSmithingTypeIgnoreStyleItems(craftingType) then
      local styleLink = GetItemStyleMaterialLink(GetItemLinkItemStyle(itemLink), LINK_STYLE_DEFAULT)
      if styleLink and styleLink ~= "" and not LDV.Data.styleMaterialBlacklist[GetItemLinkItemId(styleLink)] then
        d.styleLink = styleLink
      end
    end
    if d.origin == "C" then
      local cp = GetItemLinkRequiredChampionPoints(itemLink)
      d.tier = (cp >= 160 and "160") or (cp >= 150 and "150") or "low"
    end
  end
  return d
end

--- Statistic keys of an item, grouped by "channel". A channel is a kind of output that can
-- be told apart inside one deconstruction batch (e.g. Tempering Alloy can only come from
-- legendary blacksmithing items), the key adds everything else that may change the yield.
local function Keys(d, ctx)
  local c = ctx[d.craft]
  local origin = d.origin
  local keys = {}
  if d.craft == CRAFTING_TYPE_ENCHANTING then
    keys["EN:aspect:" .. d.quality] = { key = string.format("EN:aspect:q%d:%s:%s", d.quality, origin, c), code = "EN", quality = d.quality }
    keys["EN:essence"] = { key = string.format("EN:essence:%s:%s", origin, c) }
    keys["EN:potency"] = { key = string.format("EN:potency:%s:%s", origin, c) }
    return keys
  end

  local baseVariant
  if origin == "C" then
    baseVariant = "C" .. d.tier
  elseif origin == "L" and d.intricate then
    baseVariant = "I"
  else
    baseVariant = origin
  end
  keys["base:" .. d.code] = { key = string.format("%s:base:%s:%s", d.code, baseVariant, c) }
  if d.styleLink then
    keys["style"] = { key = string.format("style:%s:%s", origin, c) }
  end
  if d.quality > ITEM_FUNCTIONAL_QUALITY_NORMAL then
    keys["imp:" .. d.code .. ":" .. d.quality] = { key = string.format("%s:imp:q%d:%s:%s", d.code, d.quality, origin, c), code = d.code, quality = d.quality }
  end
  if d.traitGroup then
    keys["trait:" .. d.traitGroup] = { key = string.format("%s:trait:%s:%s", d.traitGroup, origin, c) }
  end
  if origin == "R" then
    keys["crystals"] = { key = string.format("R:crystals:q%d", d.quality) }
  end
  return keys
end

function Stats.KeysFor(d)
  return Keys(d, Stats.GetContext())
end

--- Learned expectation for a key: blends the guess with the recorded average.
-- Returns expectation, number of recorded items.
function Stats.Expected(key, prior)
  local entry = sv and sv.data[key]
  if not entry or entry[1] <= 0 then
    return prior, 0
  end
  return (PRIOR_WEIGHT * prior + entry[2]) / (PRIOR_WEIGHT + entry[1]), entry[1]
end

----------------------------------------------------------------------------------------
-- Pulverized jewelry trait materials seen in results.

local function RememberRawTrait(rawLink)
  if not sv then return end
  local refined = GetItemLinkRefinedMaterialItemLink(rawLink, LINK_STYLE_DEFAULT)
  if refined and refined ~= "" then
    sv.rawTraits[GetItemLinkItemId(refined)] = GetItemLinkItemId(rawLink)
  end
end

function Stats.GetKnownRawTrait(refinedId)
  return sv and sv.rawTraits[refinedId]
end

----------------------------------------------------------------------------------------
-- Recording.

--- Channel of a deconstruction result and how many units of the channel it counts as.
local function OutputChannel(itemLink)
  local itemType = GetItemLinkItemType(itemLink)
  if BASE_MATERIAL[itemType] then
    return "base:" .. BASE_MATERIAL[itemType], 1
  elseif itemType == ITEMTYPE_STYLE_MATERIAL then
    return "style", 1
  elseif BOOSTER[itemType] then
    return "imp:" .. BOOSTER[itemType] .. ":" .. GetItemLinkFunctionalQuality(itemLink), 1
  elseif itemType == ITEMTYPE_ARMOR_TRAIT or itemType == ITEMTYPE_WEAPON_TRAIT then
    return LDV.Data.nirncrux[GetItemLinkItemId(itemLink)] and "trait:nirn" or "trait:std", 1
  elseif itemType == ITEMTYPE_JEWELRY_RAW_TRAIT then
    RememberRawTrait(itemLink)
    return "trait:jw", 1
  elseif itemType == ITEMTYPE_JEWELRY_TRAIT then
    -- counted in pulverized fragments (10 fragments refine into 1 trait material)
    return "trait:jw", 10
  elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ASPECT then
    return "EN:aspect:" .. GetItemLinkFunctionalQuality(itemLink), 1
  elseif itemType == ITEMTYPE_ENCHANTING_RUNE_ESSENCE then
    return "EN:essence", 1
  elseif itemType == ITEMTYPE_ENCHANTING_RUNE_POTENCY then
    return "EN:potency", 1
  end
end

--- Adds one deconstruction batch to the totals.
-- inputs: { { link, qty } }, outputs: { { link, count } }, currencies: { { type, amount } }
-- A channel is used only when all items feeding it share one key; improvement materials
-- and aspect runes only for the highest quality present (a lower tier could come from a
-- higher quality item). A result that is not a crafting material means these were not
-- deconstruction results, so the whole batch is dropped. Returns true when anything was recorded.
function Stats.RecordBatch(inputs, outputs, currencies, ctx)
  if not sv then return false end
  local materialTypes = LDV.Analysis.itemTypeVector
  for _, output in ipairs(outputs) do
    if not materialTypes[GetItemLinkItemType(output.link)] then
      return false
    end
  end

  local channels, maxQuality, numItems = {}, {}, 0

  for _, input in ipairs(inputs) do
    local d = Stats.Describe(input.link)
    if not d then return false end
    local qty = zo_max(1, input.qty or 1)
    numItems = numItems + qty
    maxQuality[d.code] = zo_max(maxQuality[d.code] or 0, d.quality)
    for channel, info in pairs(Keys(d, ctx)) do
      local c = channels[channel]
      if not c then
        channels[channel] = { key = info.key, code = info.code, quality = info.quality, n = qty, s = 0 }
      elseif c.key ~= info.key then
        c.key = false
      else
        c.n = c.n + qty
      end
    end
  end

  for _, output in ipairs(outputs) do
    local channel, units = OutputChannel(output.link)
    local c = channel and channels[channel]
    if c then
      c.s = c.s + output.count * units
    end
  end

  for _, currency in ipairs(currencies) do
    local c = currency.type == CURT_TRANSMUTE_CRYSTALS and channels["crystals"]
    if c then
      c.s = c.s + currency.amount
    end
  end

  local recorded = false
  for _, c in pairs(channels) do
    if c.key and (not c.quality or c.quality == maxQuality[c.code]) then
      local entry = sv.data[c.key]
      if not entry then
        entry = { 0, 0 }
        sv.data[c.key] = entry
      end
      entry[1] = entry[1] + c.n
      entry[2] = entry[2] + c.s
      recorded = true
    end
  end

  if recorded then
    sv.batches = (sv.batches or 0) + 1
    sv.items = (sv.items or 0) + numItems
  end
  return recorded
end

local pending, sent

local function OnCraftCompleted()
  local batch = sent
  sent = nil
  if not batch or not sv or not sv.learn then return end
  if GetGameTimeMilliseconds() - batch.time > RESULT_TIMEOUT_MS then return end

  local numItems, penaltyApplied = GetNumLastCraftingResultItemsAndPenalty()
  if penaltyApplied then return end

  local outputs = {}
  for i = 1, numItems do
    local _, _, stack = GetLastCraftingResultItemInfo(i)
    table.insert(outputs, { link = GetLastCraftingResultItemLink(i, LINK_STYLE_DEFAULT), count = stack or 1 })
  end
  local currencies = {}
  for i = 1, GetNumLastCraftingResultCurrencies() do
    local currencyType, amount = GetLastCraftingResultCurrencyInfo(i)
    table.insert(currencies, { type = currencyType, amount = amount })
  end

  Stats.RecordBatch(batch.inputs, outputs, currencies, batch.ctx)
end

-- Same calls the game uses for every deconstruction (stations, universal deconstruction,
-- the deconstruction assistant, DoItAll). Wrapped so the return values can be checked.
local function InstallHooks()
  local originalPrepare = PrepareDeconstructMessage
  PrepareDeconstructMessage = function(...)
    pending = { inputs = {}, valid = true }
    return originalPrepare(...)
  end

  local originalAdd = AddItemToDeconstructMessage
  AddItemToDeconstructMessage = function(bagId, slotIndex, quantity, ...)
    local batch = pending
    local itemLink = batch and GetItemLink(bagId, slotIndex) or ""
    local added = originalAdd(bagId, slotIndex, quantity, ...)
    if added and batch then
      if itemLink ~= "" and LDV.Analysis.IsItemLinkDeconstructable(itemLink) then
        table.insert(batch.inputs, { link = itemLink, qty = quantity })
      else
        -- refining, filleting or something unknown: the results can't be attributed
        batch.valid = false
      end
    end
    return added
  end

  local originalSend = SendDeconstructMessage
  SendDeconstructMessage = function(...)
    local batch = pending
    pending = nil
    if batch and batch.valid and #batch.inputs > 0 and sv and sv.learn then
      batch.ctx = Stats.GetContext()
      batch.time = GetGameTimeMilliseconds()
      sent = batch
    else
      sent = nil
    end
    local wasSent = originalSend(...)
    if not wasSent and sent == batch then
      sent = nil
    end
    return wasSent
  end

  EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Stats", EVENT_CRAFT_COMPLETED, OnCraftCompleted)
  EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Stats", EVENT_CRAFT_FAILED, function() sent = nil end)
  EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Stats", EVENT_END_CRAFTING_STATION_INTERACT, function()
    pending, sent = nil, nil
  end)
end

----------------------------------------------------------------------------------------
-- /ldv

local function PrintStats(filter)
  local keys = {}
  for key in pairs(sv.data) do
    if filter == "" or string.find(string.lower(key), filter, 1, true) then
      table.insert(keys, key)
    end
  end
  table.sort(keys)
  if #keys == 0 then
    Msg("no recorded statistics" .. (filter ~= "" and (" matching '" .. filter .. "'") or ""))
    return
  end
  for _, key in ipairs(keys) do
    local entry = sv.data[key]
    Msg(string.format("%s  n=%d  avg=%.3f", key, entry[1], entry[1] > 0 and entry[2] / entry[1] or 0))
  end
end

local function PrintStatus()
  local numKeys = 0
  for _ in pairs(sv.data) do numKeys = numKeys + 1 end
  Msg(string.format("learning %s, %d deconstructions in %d batches, %d keys",
    sv.learn and "ON" or "OFF", sv.items or 0, sv.batches or 0, numKeys))
  local ctx = Stats.GetContext()
  Msg(string.format("context BS=%s CL=%s WW=%s JW=%s EN=%s",
    ctx[CRAFTING_TYPE_BLACKSMITHING], ctx[CRAFTING_TYPE_CLOTHIER], ctx[CRAFTING_TYPE_WOODWORKING],
    ctx[CRAFTING_TYPE_JEWELRYCRAFTING], ctx[CRAFTING_TYPE_ENCHANTING]))
  Msg(string.format("champion skill %d = '%s', counted as active: %s", METICULOUS_DISASSEMBLY_ID,
    tostring(GetChampionSkillName(METICULOUS_DISASSEMBLY_ID)), tostring(IsMeticulousDisassemblyActive())))
  Msg("/ldv stats [filter], /ldv on|off, /ldv reset")
end

local function SlashCommand(args)
  if not sv then return end
  args = string.lower(zo_strtrim(args or ""))
  local command, rest = string.match(args, "^(%S*)%s*(.-)$")
  if command == "on" or command == "off" then
    sv.learn = command == "on"
    Msg("learning " .. (sv.learn and "ON" or "OFF"))
  elseif command == "reset" then
    sv.data, sv.batches, sv.items = {}, 0, 0
    Msg("statistics cleared")
  elseif command == "stats" then
    PrintStats(rest or "")
  else
    PrintStatus()
  end
end

----------------------------------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Stats", EVENT_ADD_ON_LOADED, function(_, name)
  if name ~= ADDON_NAME then return end
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "Stats", EVENT_ADD_ON_LOADED)

  if type(LibDeconValue_Stats) ~= "table" or LibDeconValue_Stats.version ~= SV_VERSION then
    LibDeconValue_Stats = { version = SV_VERSION }
  end
  sv = LibDeconValue_Stats
  sv.data = sv.data or {}
  sv.rawTraits = sv.rawTraits or {}
  if sv.learn == nil then sv.learn = true end

  InstallHooks()
  SLASH_COMMANDS["/ldv"] = SlashCommand
end)
