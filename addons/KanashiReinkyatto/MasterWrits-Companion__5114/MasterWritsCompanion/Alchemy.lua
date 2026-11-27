local L = MWC.L
MWC.Alchemy = {
  ITEMS_PER_WRIT = 16,
  STACK_SIZE = 100,
  REQUIRED_CP = 150,
}

-- The Chemistry passive adds one potion per rank to every craft (the game's ALCHEMY_CREATE_EXTRA bonus, up
-- to 3); poisons yield four times as many.
local CHEMISTRY_MAX = 3
local POISONS_PER_POTION = 4

function MWC.Alchemy.IsChemistryBelowMax()
  local extra = MWC.SkillBonus("NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA")
  return extra ~= nil and extra < CHEMISTRY_MAX
end

-- If the bonus can't be read, assume it is maxed; the post-craft check catches a wrong guess.
function MWC.Alchemy.Yield(isPoison)
  local potions = 1 + (MWC.SkillBonus("NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA") or CHEMISTRY_MAX)
  return isPoison and potions * POISONS_PER_POTION or potions
end

local POISON_SOLVENT_CODE = 239
local SOLVENT_ITEM_ID = { potion = 64501, poison = 75365 } -- Lorkhan's Tears, Alkahest
-- Potion links store their effects in this field, one effect id per byte.
local POTION_EFFECTS_FIELD = 24
local RESULT_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Effects that cancel each other out when both are active.
local OPPOSITE_PAIRS = {
  { 1, 2 }, { 3, 4 }, { 5, 6 }, { 7, 8 }, { 9, 10 }, { 11, 12 }, { 15, 16 }, { 19, 20 }, { 21, 22 },
  { 23, 24 }, { 25, 26 }, { 27, 28 }, { 29, 30 }, { 31, 32 }, { 33, 34 }, { 35, 36 }, { 37, 38 },
}

-- Reagent item id -> its four effect ids, in the order the game lists them.
-- Kept as data because the game hides traits the character hasn't discovered yet.
local REAGENTS = {
  [30148] = { 4, 34, 1, 22 },    -- Blue Entoloma
  [30149] = { 10, 2, 35, 6 },    -- Stinkhorn
  [30151] = { 2, 4, 6, 20 },     -- Emetic Russula
  [30152] = { 8, 2, 11, 4 },     -- Violet Coprinus
  [30153] = { 36, 23, 22, 19 },  -- Namira's Rot
  [30154] = { 36, 4, 7, 21 },    -- White Cap
  [30155] = { 6, 1, 24, 12 },    -- Luminous Russula
  [30156] = { 12, 6, 9, 36 },    -- Imp Stool
  [30157] = { 5, 11, 34, 23 },   -- Blessed Thistle
  [30158] = { 35, 3, 8, 15 },    -- Lady's Smock
  [30159] = { 15, 24, 21, 19 },  -- Wormwood
  [30160] = { 7, 1, 37, 3 },     -- Bugloss
  [30161] = { 3, 11, 2, 21 },    -- Corn Flower
  [30162] = { 11, 5, 10, 15 },   -- Dragonthorn
  [30163] = { 9, 1, 12, 5 },     -- Mountain Flower
  [30164] = { 1, 3, 5, 19 },     -- Columbine
  [30165] = { 2, 16, 22, 34 },   -- Nirnroot
  [30166] = { 1, 15, 20, 33 },   -- Water Hyacinth
  [77581] = { 10, 16, 21, 37 },  -- Torchbug Thorax
  [77583] = { 8, 9, 25, 29 },    -- Beetle Scuttle
  [77584] = { 24, 22, 33, 30 },  -- Spider Egg
  [77585] = { 1, 33, 27, 29 },   -- Butterfly Wing
  [77587] = { 6, 26, 28, 29 },   -- Fleshfly Larva
  [77589] = { 38, 23, 26, 27 },  -- Scrib Jelly
  [77590] = { 2, 25, 28, 30 },   -- Nightshade
  [77591] = { 7, 9, 25, 30 },    -- Mudcrab Chitin
  [139019] = { 37, 23, 29, 25 }, -- Powdered Mother of Pearl
  [139020] = { 7, 24, 26, 30 },  -- Clam Gall
  [150669] = { 32, 4, 38, 21 },  -- Chaurus Egg
  [150670] = { 32, 2, 3, 25 },   -- Vile Coagulant
  [150671] = { 3, 16, 31, 23 },  -- Dragon Rheum
  [150672] = { 32, 35, 28, 1 },  -- Crimson Nirnroot
  [150731] = { 27, 5, 31, 30 },  -- Dragon's Blood
  [150789] = { 31, 26, 22, 29 }, -- Dragon's Bile
  [224357] = { 31, 11, 37, 33 }, -- Cultivated Cryptpods
  [224358] = { 30, 34, 12, 20 }, -- Daedra-Blood Maggots
  [224359] = { 31, 5, 35, 21 },  -- Fossilized Verminous Bones
  [224360] = { 38, 34, 30, 8 },  -- Winter's Grave Tongue
}

local OPPOSITE = {}
for _, pair in ipairs(OPPOSITE_PAIRS) do
  OPPOSITE[pair[1]] = pair[2]
  OPPOSITE[pair[2]] = pair[1]
end

local REAGENT_IDS = {}
for id in pairs(REAGENTS) do
  table.insert(REAGENT_IDS, id)
end
table.sort(REAGENT_IDS)

function MWC.Alchemy.ReagentIds()
  return REAGENT_IDS
end

function MWC.Alchemy.ReagentEffects(itemId)
  return REAGENTS[itemId]
end

function MWC.Alchemy.IsPoison(solventCode)
  return solventCode == POISON_SOLVENT_CODE
end

function MWC.Alchemy.SolventItemId(isPoison)
  return isPoison and SOLVENT_ITEM_ID.poison or SOLVENT_ITEM_ID.potion
end

-- Canonical, order-independent identifier for a set of effects.
function MWC.Alchemy.EffectKey(effects)
  local sorted = {}
  for _, effect in ipairs(effects) do
    if effect and effect > 0 then
      table.insert(sorted, effect)
    end
  end
  table.sort(sorted)
  return table.concat(sorted, ",")
end

-- An effect is active when at least two reagents share it and no reagent has its opposite: a single reagent
-- with the opposite effect is enough to cancel it (seen in game: Blue Entoloma's Restore Health cancelled the
-- Ravage Health two other reagents shared).
local function ResultKey(reagentIds)
  local counts = {}
  for _, id in ipairs(reagentIds) do
    for _, effect in ipairs(REAGENTS[id]) do
      counts[effect] = (counts[effect] or 0) + 1
    end
  end
  local result = {}
  for effect, count in pairs(counts) do
    if count >= 2 and not counts[OPPOSITE[effect]] then
      table.insert(result, effect)
    end
  end
  return MWC.Alchemy.EffectKey(result)
end
MWC.Alchemy.ResultKey = ResultKey

-- Every 2- or 3-reagent combination that produces exactly these effects. Static data: all combinations are
-- worked out once, on first use, and indexed by their effects (a search per writ froze the game for a moment).
local comboIndex

-- Without the Laboratory Use passive a third reagent can't be added: only pairs are usable then.
function MWC.Alchemy.HasLaboratoryUse()
  local thirdSlot = MWC.SkillBonus("NON_COMBAT_BONUS_ALCHEMY_THIRD_SLOT")
  return thirdSlot == nil or thirdSlot >= 1
end

-- The combinations the character can use (see HasLaboratoryUse).
function MWC.Alchemy.UsableCombos(effectKey)
  local combos = MWC.Alchemy.Combos(effectKey)
  if MWC.Alchemy.HasLaboratoryUse() then return combos end
  local twoReagents = {}
  for _, combo in ipairs(combos) do
    if #combo == 2 then
      table.insert(twoReagents, combo)
    end
  end
  return twoReagents
end

function MWC.Alchemy.Combos(effectKey)
  if not comboIndex then
    comboIndex = {}
    local function Add(combo)
      local key = ResultKey(combo)
      if key ~= "" then
        comboIndex[key] = comboIndex[key] or {}
        table.insert(comboIndex[key], combo)
      end
    end
    local count = #REAGENT_IDS
    for i = 1, count do
      for j = i + 1, count do
        local a, b = REAGENT_IDS[i], REAGENT_IDS[j]
        Add({ a, b })
        for k = j + 1, count do
          Add({ a, b, REAGENT_IDS[k] })
        end
      end
    end
  end
  return comboIndex[effectKey] or {}
end

local function PotionKey(link)
  local value = tonumber(({ ZO_LinkHandler_ParseLink(link) })[POTION_EFFECTS_FIELD]) or 0
  return MWC.Alchemy.EffectKey({ value % 256, math.floor(value / 256) % 256, math.floor(value / 65536) % 256 })
end

-- The same effects can come out under different names: the combination of reagents decides which effect
-- names the potion (tested: all six orders of one combination gave the same name), and a writ accepts only the
-- name it asks for. So the name is part of the key, next to the effects and the type (potions and poisons
-- share effect ids).
function MWC.Alchemy.NameKey(name)
  return zo_strlower(zo_strformat("<<1>>", name or ""))
end

-- The icon of each potion name, taken from every potion seen in the bags and every station preview, so writ
-- rows can show the icon of the potion they ask for. The icon is kept itself: a link rebuilt from the bare item
-- id lacks the potion's data and shows a question mark.
local function RememberItem(link, isPoison)
  local icon = GetItemLinkInfo(link)
  if not icon or icon == "" then return end
  MWC.sv.potionIcons = MWC.sv.potionIcons or {}
  MWC.sv.potionIcons[(isPoison and "poison:" or "potion:") .. MWC.Alchemy.NameKey(GetItemLinkName(link))] = icon
end

-- The icon of the potion with this name, or nil until such a potion has been seen.
function MWC.Alchemy.IconFor(isPoison, nameKey)
  return nameKey and MWC.sv.potionIcons and MWC.sv.potionIcons[(isPoison and "poison:" or "potion:") .. nameKey]
end

function MWC.Alchemy.IndexKey(isPoison, effectKey, name)
  return string.format("%s%s|%s", isPoison and "poison:" or "potion:", effectKey, MWC.Alchemy.NameKey(name))
end

-- Names by reagents ----------------------------------------------------------------------------------------
-- Which effect names a potion depends on the reagents, by rules the game doesn't expose (some combinations with
-- the right effects can never give the writ's name). The station's preview tells it for reagents at hand, and
-- the answer never changes, so every preview is kept (per account, by solvent and reagent order; orders are
-- still tried in case they matter somewhere). Planning uses what is known; at a station the rest is asked.

local function SlotOf(itemId)
  local craftBagCount = GetSlotStackSize(BAG_VIRTUAL, itemId)
  if craftBagCount > 0 then
    return BAG_VIRTUAL, itemId, craftBagCount
  end
  local bestSlot, bestCount
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    if GetItemId(BAG_BACKPACK, slot) == itemId then
      local count = GetSlotStackSize(BAG_BACKPACK, slot)
      if not bestCount or count > bestCount then
        bestSlot, bestCount = slot, count
      end
    end
  end
  if bestSlot then
    return BAG_BACKPACK, bestSlot, bestCount
  end
end
MWC.Alchemy.SlotOf = SlotOf

function MWC.Alchemy.Permutations(items)
  if #items <= 1 then return { items } end
  local result = {}
  for i, first in ipairs(items) do
    local rest = {}
    for j, item in ipairs(items) do
      if j ~= i then table.insert(rest, item) end
    end
    for _, tail in ipairs(MWC.Alchemy.Permutations(rest)) do
      table.insert(result, { first, unpack(tail) })
    end
  end
  return result
end

local function OrderKey(solventId, ids)
  return solventId .. ":" .. table.concat(ids, ",")
end

-- What a solvent and reagents in this order make, as "effects|name": from the station's preview when live and
-- the items are at hand (and then remembered), otherwise what was remembered, or nil when unknown. Both the
-- effects and the name must match a writ: the name alone once let a potion through that had lost two effects.
local function ResultFor(solventId, ids, live)
  MWC.sv.alchemyResults = MWC.sv.alchemyResults or {}
  local key = OrderKey(solventId, ids)
  if live then
    local slots = {}
    for _, itemId in ipairs({ solventId, unpack(ids) }) do
      local bag, slot = SlotOf(itemId)
      if not bag then return MWC.sv.alchemyResults[key] end
      table.insert(slots, { bag, slot })
    end
    local s, r1, r2, r3 = slots[1], slots[2], slots[3], slots[4] or {}
    local ok, link = pcall(GetAlchemyResultingItemLink, s[1], s[2], r1[1], r1[2], r2[1], r2[2], r3[1], r3[2],
      LINK_STYLE_DEFAULT)
    if ok and link and link ~= "" then
      RememberItem(link, GetItemLinkItemType(link) == ITEMTYPE_POISON)
      MWC.sv.alchemyResults[key] = PotionKey(link) .. "|" .. MWC.Alchemy.NameKey(GetItemLinkName(link))
    end
  end
  return MWC.sv.alchemyResults[key]
end

local function HasAll(ids)
  for _, itemId in ipairs(ids) do
    if not SlotOf(itemId) then return false end
  end
  return true
end

-- The first combination (in the given order) with an order that makes the wanted name: returns the reagent ids
-- in that order and "confirmed". Failing that, the first combination whose orders aren't all known yet, with
-- "unchecked"; or nil when every order of every combination is known to give another name. With onlyAtHand,
-- combinations missing a reagent are left out (crafting).
-- writText: the writ's own text, which names the wanted potion. Returns the order, "confirmed" and the name key
-- the preview showed (to be remembered for the writ).
function MWC.Alchemy.ChooseByResult(solventId, combos, effectKey, writText, live, onlyAtHand)
  local firstUnknown
  for _, combo in ipairs(combos) do
    if not onlyAtHand or HasAll(combo) then
      local unknown = false
      for _, order in ipairs(MWC.Alchemy.Permutations(combo)) do
        local made = ResultFor(solventId, order, live)
        local madeEffects, madeName = (made or ""):match("^([^|]*)|(.*)$")
        if made and madeEffects == effectKey and MWC.Alchemy.NameInText(writText, madeName) then
          return order, "confirmed", madeName
        elseif made == nil then
          unknown = true
        end
      end
      if unknown and not firstUnknown then
        firstUnknown = combo
      end
    end
  end
  if firstUnknown then
    return firstUnknown, "unchecked"
  end
  return nil, L.PROBLEM_NO_EXACT_POTION
end

-- At an alchemy station: preview every alchemy writ's combinations at hand, so planning knows which give the
-- right name. Previews are quick and nothing is crafted.
function MWC.Alchemy.LearnNames(groups)
  for _, group in ipairs(groups) do
    if group.type == "alchemy" and group.effectKey then
      local _, verdict, nameKey = MWC.Alchemy.ChooseByResult(MWC.Alchemy.SolventItemId(group.isPoison),
        MWC.Plan.RankCombos(MWC.Alchemy.UsableCombos(group.effectKey), 1), group.effectKey,
        GenerateMasterWritBaseText(group.link), true, true)
      if verdict == "confirmed" then
        MWC.Alchemy.LearnName(group.key, nameKey)
      end
    end
  end
end

-- Whether a potion name (a name key) stands in a writ's text as a whole name: the writ's text names the potion
-- it wants in the client's language, so no fixed phrasing is needed. Letters include any non-ASCII byte.
-- The longer words of a name (3+ bytes: articles like "de", "du", "of" don't count), apostrophes splitting.
local function NameWords(text)
  local words, count = {}, 0
  local spaced = zo_strlower(text or ""):gsub("\226\128\153", " "):gsub("'", " ")
  for word in spaced:gmatch("[%w\128-\255]+") do
    if #word >= 3 and not words[word] then
      words[word], count = true, count + 1
    end
  end
  return words, count
end

-- Some languages bend the potion's name inside the writ's text: French writes "une puissance du essence" for
-- the potion the game names otherwise. Then the name is told by its words: the same longer words as the name
-- the language file's pattern reads from the writ, in any order.
local function SameWords(nameKey, writName)
  local nameWords, nameCount = NameWords(nameKey)
  local writWords, writCount = NameWords(writName)
  if nameCount == 0 or nameCount ~= writCount then return false end
  for word in pairs(nameWords) do
    if not writWords[word] then return false end
  end
  return true
end

function MWC.Alchemy.NameInText(text, nameKey)
  if not nameKey or nameKey == "" then return false end
  local lower, start = zo_strlower(text or ""), 1
  while true do
    local first, last = lower:find(nameKey, start, true)
    if not first then break end
    local before, after = lower:sub(first - 1, first - 1), lower:sub(last + 1, last + 1)
    if not before:find("[%w\128-\255]") and not after:find("[%w\128-\255]") then return true end
    start = last + 1
  end
  local writName = L.ALCHEMY_NAME_PATTERN and (text or ""):match(L.ALCHEMY_NAME_PATTERN)
  return writName ~= nil and SameWords(nameKey, writName)
end

-- The name key of the potion a writ wants: learned from the station's preview or a matching potion (kept per
-- writ kind), else the longest name of a potion in the bags with the writ's effects that its text names, else
-- the English phrasing "Craft a … with". Nil when none of these tells.
function MWC.Alchemy.ExpectedName(writ, potionIndex)
  MWC.sv.potionNames = MWC.sv.potionNames or {}
  if MWC.sv.potionNames[writ.key] then return MWC.sv.potionNames[writ.key] end
  local text = GenerateMasterWritBaseText(writ.link) or ""
  local prefix = MWC.Alchemy.IndexKey(MWC.Alchemy.IsPoison(writ.fields[1]), MWC.Alchemy.EffectKeyOf(writ), "")
  local best
  for key in pairs(potionIndex or {}) do
    if key:sub(1, #prefix) == prefix then
      local nameKey = key:sub(#prefix + 1)
      if MWC.Alchemy.NameInText(text, nameKey) and (not best or #nameKey > #best) then
        best = nameKey
      end
    end
  end
  if best then
    MWC.sv.potionNames[writ.key] = best
    return best
  end
  local named = L.ALCHEMY_NAME_PATTERN and text:match(L.ALCHEMY_NAME_PATTERN)
  return named and MWC.Alchemy.NameKey(named) or nil
end

function MWC.Alchemy.LearnName(writKey, nameKey)
  MWC.sv.potionNames = MWC.sv.potionNames or {}
  MWC.sv.potionNames[writKey] = nameKey
end

-- "Craft a Damage Health Poison IX with the following Traits: ..." -> "Damage Health Poison IX" (shown only)
function MWC.Alchemy.WritPotionName(writLink)
  local text = GenerateMasterWritBaseText(writLink) or ""
  return MWC.WritItemName(text, L.ALCHEMY_NAME_PATTERN)
end

-- Index key of a writ-grade potion or poison in this slot, or nil for anything else. Worked out once per link.
local keyByLink = {}

function MWC.Alchemy.SlotIndexKey(bag, slot)
  local itemType = GetItemType(bag, slot)
  if itemType ~= ITEMTYPE_POTION and itemType ~= ITEMTYPE_POISON then return nil end
  if not MWC.IsMine(bag, slot) then return nil end
  local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
  local known = keyByLink[link]
  if known == nil then
    known = false
    if GetItemLinkRequiredChampionPoints(link) >= MWC.Alchemy.REQUIRED_CP then
      RememberItem(link, itemType == ITEMTYPE_POISON)
      known = MWC.Alchemy.IndexKey(itemType == ITEMTYPE_POISON, PotionKey(link), GetItemLinkName(link))
    end
    keyByLink[link] = known
  end
  return known or nil
end

local POTION_TYPES = { [ITEMTYPE_POTION] = true, [ITEMTYPE_POISON] = true }

-- One pass over the bags: index key -> { bag = n, bank = n } for writ-grade potions and poisons.
function MWC.Alchemy.PotionIndex()
  local index = {}
  for _, at in ipairs(MWC.ItemSlots(RESULT_BAGS, POTION_TYPES)) do
    local bag, slot = at[1], at[2]
    local key = MWC.Alchemy.SlotIndexKey(bag, slot)
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

function MWC.Alchemy.CountResults(group)
  local entry = MWC.Alchemy.PotionIndex()[MWC.Alchemy.IndexKey(group.isPoison, group.effectKey, group.nameKey)]
  return entry and (entry.bag + entry.bank) or 0
end

function MWC.Alchemy.EffectKeyOf(writ)
  return MWC.Alchemy.EffectKey({ writ.fields[2], writ.fields[3], writ.fields[4] })
end
