local L = MWC.L
MWC.Plan = {
  FOOD_STACK_SIZE = 100,
  MAX_YIELD = 4,
  ITEMS_PER_PROVISIONING_WRIT = 8,
}

local TYPE_ORDER = {
  blacksmithing = 1, clothier = 2, woodworking = 3, jewelry = 4, alchemy = 5, enchanting = 6, provisioning = 7,
}
-- Gear writ labels and icons; gear crafting itself is in GearCraft.lua.
local GEAR_LABEL = L.CRAFT_TAB
local GEAR_ICON = {
  blacksmithing = "esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds",
  clothier = "esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds",
  woodworking = "esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds",
  jewelry = "esoui/art/inventory/inventory_tabicon_craftbag_jewelrycrafting_up.dds",
}
local FOOD_ICON = "esoui/art/treeicons/provisioner_indexicon_meat_up.dds"
-- Holiday writs show their writ's own icon and kind.
local EVENT_ICON = {
  witches = "/esoui/art/icons/master_writ_witchesfestival.dds", newlife = "/esoui/art/icons/master_writ-newlife.dds",
  deepwinter = "/esoui/art/icons/master_writ-newlife.dds", imperial = "/esoui/art/icons/master_writ-newlife.dds",
}
local EVENT_LABEL = L.EVENT_LABEL
local DRINK_ICON = "esoui/art/treeicons/provisioner_indexicon_beer_up.dds"
-- Real potion and poison links (a potion's icon depends on its effects); only their icons are used.
local SAMPLE_POTION_LINK = "|H0:item:54339:308:50:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:65536|h|h"
local SAMPLE_POISON_LINK = "|H0:item:76833:30:3:0:0:0:0:0:0:0:0:0:0:0:0:36:1:0:0:0:525312|h|h"
local GLYPH_LABEL = {
  [ITEMTYPE_GLYPH_ARMOR] = L.TYPE_GLYPH_ARMOR,
  [ITEMTYPE_GLYPH_WEAPON] = L.TYPE_GLYPH_WEAPON,
  [ITEMTYPE_GLYPH_JEWELRY] = L.TYPE_GLYPH_JEWELRY,
}

local INGREDIENT_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
-- Problems nothing but learning can fix: such writs start skipped (once per session).
local AUTO_SKIP_PROBLEMS = {
  [L.PROBLEM_STYLE_UNKNOWN] = true, [L.PROBLEM_RECIPE_UNKNOWN] = true, [L.PROBLEM_TRAIT_UNKNOWN] = true,
  [L.PROBLEM_GOLD_GLYPH] = true, [L.PROBLEM_THREE_REAGENTS] = true,
}

-- Prices are cached for the session by MWC.Price.
local function PriceOf(link)
  return MWC.Price.Of(link)
end

local function Owned(link)
  local backpack, bank, craftBag = GetItemLinkStacks(link)
  return backpack + bank + craftBag
end

-- Crafted items can differ from the recipe's result link in non-id fields, so count by item id; only this
-- character's own (see MWC.IsMine).
local function CountInBag(bag, itemId)
  local count = 0
  for slot = 0, GetBagSize(bag) - 1 do
    if GetItemId(bag, slot) == itemId and MWC.IsMine(bag, slot) then
      count = count + GetSlotStackSize(bag, slot)
    end
  end
  return count
end

-- Returns total, backpack, bank.
function MWC.Plan.CountItem(itemId)
  local backpack = CountInBag(BAG_BACKPACK, itemId)
  local bank = CountInBag(BAG_BANK, itemId) + CountInBag(BAG_SUBSCRIBER_BANK, itemId)
  return backpack + bank, backpack, bank
end

-- Free room in stacks of this item already in the backpack; new items fill these first.
function MWC.Plan.PartialStackRoom(itemId)
  local room = 0
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    -- A new craft stacks only onto this character's own stacks.
    if GetItemId(BAG_BACKPACK, slot) == itemId and MWC.IsMine(BAG_BACKPACK, slot) then
      local stack, maxStack = GetSlotStackSize(BAG_BACKPACK, slot)
      room = room + (maxStack - stack)
    end
  end
  return room
end

-- Without an item id (potions differ by effects, not id) no partial stacks are assumed.
function MWC.Plan.SlotsFor(itemId, count, stackSize)
  local room = itemId and MWC.Plan.PartialStackRoom(itemId) or 0
  return math.ceil(math.max(0, count - room) / (stackSize or MWC.Plan.FOOD_STACK_SIZE))
end

-- Real links of owned materials (by item id); constructed links may not match inventory counts. A material's
-- link never changes, so the bags and the craft bag are read once and again only after crafting or banking by
-- the addon (MWC.Plan.ForgetLinks) or a reload; a material not found falls back to a constructed link.
local ownedLinks

function MWC.Plan.ForgetLinks()
  ownedLinks = nil
end

-- A material that arrives later (looted, bought, from the bank) is added on the spot, without a new scan.
EVENT_MANAGER:RegisterForEvent(MWC.name .. "OwnedLinks", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
  function(_, bag, slot, isNewItem)
    if not (ownedLinks and isNewItem) then return end
    local id = GetItemId(bag, slot)
    if id ~= 0 and not ownedLinks[id] then
      ownedLinks[id] = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    end
  end)

local function OwnedLinks()
  if ownedLinks then return ownedLinks end
  local links = {}
  local function Add(bag, slot)
    local id = GetItemId(bag, slot)
    if id ~= 0 and not links[id] then
      links[id] = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    end
  end
  for _, bag in ipairs(INGREDIENT_BAGS) do
    for slot = 0, GetBagSize(bag) - 1 do
      Add(bag, slot)
    end
  end
  for _, data in pairs(SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_VIRTUAL)) do
    Add(data.bagId, data.slotIndex)
  end
  ownedLinks = links
  return links
end

-- Material kind for the Materials Used tabs; gear writs set their own (Base, Upgrade, Trait, Style).
local INGREDIENT_KIND = { provisioning = "Ingredient", alchemy = "Reagent", enchanting = "Rune" }

local function FillCrafting(group, recipe)
  group.crafts = math.ceil(math.max(0, group.required - group.have) / recipe.yield)
  group.produce = group.crafts * recipe.yield
  group.slots = MWC.Plan.SlotsFor(recipe.resultItemId, group.produce, recipe.stackSize)
  -- For the session totals: everything the queued writs take, and the part already in crafted items.
  local totalCrafts = math.ceil(group.selectedCount * group.perWrit / recipe.yield)
  local usedCrafts = math.min(totalCrafts, math.ceil((group.ready or 0) * group.perWrit / recipe.yield))
  for _, ingredient in ipairs(recipe.ingredients) do
    local entry = {
      link = ingredient.link,
      kind = INGREDIENT_KIND[group.type],
      need = ingredient.quantity * group.crafts,
      have = Owned(ingredient.link),
      total = ingredient.quantity * totalCrafts,
      used = ingredient.quantity * usedCrafts,
    }
    table.insert(group.ingredients, entry)
    if entry.have < entry.need then
      table.insert(group.shortIngredients, entry)
    end
  end
end

local function FillProvisioning(group, recipes)
  local foodItemId = group.writs[1].foodItemId
  local recipe = foodItemId and recipes[foodItemId]
  local foodLink = recipe and recipe.resultLink or MWC.LinkFromItemId(foodItemId)
  -- Holiday writs (food or furnishings, made the same way from a recipe) want their own count.
  local perWrit = group.writs[1].eventCount or MWC.Plan.ITEMS_PER_PROVISIONING_WRIT

  group.perWrit = perWrit
  group.name = MWC.ItemName(foodLink)
  group.quality = GetItemLinkFunctionalQuality(foodLink)
  local isDrink = GetItemLinkItemType(foodLink) == ITEMTYPE_DRINK
  group.typeLabel = isDrink and L.TYPE_DRINK or L.TYPE_FOOD
  group.typeIcon = isDrink and DRINK_ICON or FOOD_ICON
  group.required = group.selectedCount * perWrit

  local have, haveBag, haveBank = 0, 0, 0
  if foodItemId then
    have, haveBag, haveBank = MWC.Plan.CountItem(foodItemId)
  end
  group.have = have
  group.readyBag = math.floor(haveBag / perWrit)
  group.readyBank = math.floor(haveBank / perWrit)
  group.ready = math.min(group.selectedCount, math.floor(have / perWrit))

  group.crafts, group.produce, group.slots = 0, 0, 0
  if not recipe or not recipe.known then
    group.problem = L.PROBLEM_RECIPE_UNKNOWN
  end
  if recipe then
    group.recipe = recipe
    FillCrafting(group, recipe)
  end
end

-- Combinations ordered best first: those without a reagent from Keep materials (always first: a kept reagent
-- is used only when no combination avoids it), then those the owned reagents fully cover, then the cheapest
-- (TTC), then the fewest reagents. Planning takes the first; crafting tries them in this order at the station.
function MWC.Plan.RankCombos(combos, crafts, links)
  links = links or {}
  local ranked = {}
  for _, combo in ipairs(combos) do
    local enough, cost, kept = true, 0, false
    for _, id in ipairs(combo) do
      local link = links[id] or MWC.LinkFromItemId(id)
      if Owned(link) < crafts then
        enough = false
      end
      if MWC.KeyItems.IsEnabled(MWC.KeyItems.ItemKey(id)) then
        kept = true
      end
      cost = cost + (PriceOf(link) or 0)
    end
    table.insert(ranked, { combo = combo, enough = enough, cost = cost, kept = kept })
  end
  table.sort(ranked, function(a, b)
    if a.kept ~= b.kept then return not a.kept end
    if a.enough ~= b.enough then return a.enough end
    if a.cost ~= b.cost then return a.cost < b.cost end
    return #a.combo < #b.combo
  end)
  local result = {}
  for _, entry in ipairs(ranked) do
    table.insert(result, entry.combo)
  end
  return result
end

-- The combinations with no reagent from Keep materials, in their order.
function MWC.Plan.WithoutKept(combos)
  local result = {}
  for _, combo in ipairs(combos) do
    local kept = false
    for _, id in ipairs(combo) do
      if MWC.KeyItems.IsEnabled(MWC.KeyItems.ItemKey(id)) then
        kept = true
      end
    end
    if not kept then
      table.insert(result, combo)
    end
  end
  return result
end

local function FillAlchemy(group, potionIndex, links)
  local writ = group.writs[1]
  local isPoison = MWC.Alchemy.IsPoison(writ.fields[1])
  local perWrit = MWC.Alchemy.ITEMS_PER_WRIT
  local text = GenerateMasterWritBaseText(group.link) or ""

  group.isPoison = isPoison
  group.effectKey = MWC.Alchemy.EffectKeyOf(writ)
  group.perWrit = perWrit
  group.name = MWC.Alchemy.WritPotionName(group.link)
  group.nameKey = MWC.Alchemy.ExpectedName(writ, potionIndex)
  group.quality = GetItemLinkFunctionalQuality(group.link)
  group.typeLabel = isPoison and L.TYPE_POISON or L.TYPE_POTION
  -- The icon of the potion the writ asks for, once one with that name has been seen; a generic one before.
  group.typeIcon = MWC.Alchemy.IconFor(isPoison, group.nameKey)
    or (GetItemLinkInfo(isPoison and SAMPLE_POISON_LINK or SAMPLE_POTION_LINK))
  group.required = group.selectedCount * perWrit
  -- Writs listing the same effects in another order are different writs wanting the same potion: they share one
  -- pool, each taking what its pending writs need (bag first), so no potion is counted for two writs.
  local entry = potionIndex[MWC.Alchemy.IndexKey(isPoison, group.effectKey, group.nameKey)] or { bag = 0, bank = 0 }
  local need = group.selectedCount * perWrit
  local takeBag = math.min(entry.bag - (entry.takenBag or 0), need)
  local takeBank = math.min(entry.bank - (entry.takenBank or 0), need - takeBag)
  entry.takenBag, entry.takenBank = (entry.takenBag or 0) + takeBag, (entry.takenBank or 0) + takeBank
  group.have = takeBag + takeBank
  group.readyBag = math.floor(takeBag / perWrit)
  group.readyBank = math.floor(takeBank / perWrit)
  group.ready = math.min(group.selectedCount, math.floor(group.have / perWrit))

  group.crafts, group.produce, group.slots = 0, 0, 0
  local yield = MWC.Alchemy.Yield(isPoison)
  local crafts = math.ceil(math.max(0, group.required - group.have) / yield)
  local solventId = MWC.Alchemy.SolventItemId(isPoison)
  local ranked = MWC.Plan.RankCombos(MWC.Alchemy.UsableCombos(group.effectKey), crafts, links)
  if #ranked == 0 then
    group.problem = #MWC.Alchemy.Combos(group.effectKey) > 0 and L.PROBLEM_THREE_REAGENTS
      or L.PROBLEM_NO_COMBINATION
    return
  end
  -- The writ wants its exact name, which the reagents decide (see Alchemy.ChooseByResult). Reagents from Keep
  -- materials are never used. The reagents this writ was last crafted with come first, so the plan and the
  -- session history show what was really used.
  local allowed = MWC.Plan.WithoutKept(ranked)
  if #allowed == 0 then
    group.problem = L.PROBLEM_ONLY_KEPT_REAGENTS
    return
  end
  local crafted = MWC.sv.alchemyCrafted and MWC.sv.alchemyCrafted[group.key]
  if crafted and MWC.Alchemy.ResultKey(crafted) == group.effectKey then
    allowed = MWC.Plan.WithoutKept({ crafted, unpack(allowed) })
  end
  local combo, verdict, nameKey = MWC.Alchemy.ChooseByResult(solventId, allowed, group.effectKey, text, false, false)
  if verdict == "confirmed" and nameKey ~= group.nameKey then
    MWC.Alchemy.LearnName(group.key, nameKey)
    group.nameKey = nameKey
  end
  if not combo then
    group.problem = L.PROBLEM_NO_EXACT_POTION
    return
  end
  group.reagentsUnchecked = verdict == "unchecked"

  local ingredients = { { itemId = solventId, link = links[solventId] or MWC.LinkFromItemId(solventId), quantity = 1 } }
  for _, id in ipairs(combo) do
    table.insert(ingredients, { itemId = id, link = links[id] or MWC.LinkFromItemId(id), quantity = 1 })
  end
  group.recipe = { known = true, yield = yield, ingredients = ingredients }
  FillCrafting(group, group.recipe)
end

-- "Craft a Rubedite Dagger; Quality: Epic; Trait: Defending; Set: ...; Style: ..." -> item plus set, trait, style.
local function FillGear(group, gearIndex)
  local writ = group.writs[1]
  -- Names from the writ's numbers (any client language).
  local fields = writ.fields
  group.setName = MWC.CapitalFirst(zo_strformat("<<1>>", GetItemSetName(fields[4])))
  group.styleName = fields[6] > 0 and zo_strformat("<<1>>", GetItemStyleName(fields[6])) or nil
  group.traitName = zo_strformat("<<1>>", GetString("SI_ITEMTRAITTYPE", fields[5]))
  local rawItem = MWC.Gear.ItemName(group.link)
  group.indexKey = MWC.Gear.WritKey(writ)
  -- English writ texts lowercase some words ("platinum Necklace"): see MWC.GearDisplayName.
  group.name = MWC.GearDisplayName(rawItem)
  local entry = gearIndex[group.indexKey] or { bag = 0, bank = 0 }
  group.readyBag, group.readyBank = entry.bag, entry.bank

  -- One item per writ: base material, improvement steps, trait stone and style material, for the writs left.
  local done = math.min(group.selectedCount, entry.bag + entry.bank)
  local remaining = group.selectedCount - done
  local perItem = {}
  for _, material in ipairs(MWC.Gear.Materials(group.type, writ.fields)) do
    table.insert(perItem, { link = MWC.LinkFromItemId(material.itemId), quantity = material.quantity, kind = material.kind })
  end
  local traitStone = MWC.KeyItems.TraitStone(writ.fields[5])
  local styleMaterial = MWC.KeyItems.StyleMaterial(writ.fields[6])
  group.styled = writ.fields[6] > 0
  group.mimic = group.styled and MWC.Session.UsesMimic(group.key) or nil
  if group.mimic then
    styleMaterial = MWC.LinkFromItemId(MWC.Gear.MIMIC_STONE_ID)
  end
  if traitStone then
    table.insert(perItem, { link = traitStone, quantity = 1, kind = "Trait" })
  end
  if styleMaterial then
    table.insert(perItem, { link = styleMaterial, quantity = 1, kind = "Style" })
  end
  for _, material in ipairs(perItem) do
    local need = {
      link = material.link, kind = material.kind, need = remaining * material.quantity, have = Owned(material.link),
      total = group.selectedCount * material.quantity, used = done * material.quantity,
    }
    table.insert(group.ingredients, need)
    if need.have < need.need then
      table.insert(group.shortIngredients, need)
    end
  end
  group.typeLabel = GEAR_LABEL[group.type]
  group.typeIcon = GEAR_ICON[group.type]
  group.quality = writ.fields[3] >= 1 and writ.fields[3] <= 5 and writ.fields[3] or GetItemLinkFunctionalQuality(group.link)
  group.perWrit = MWC.Gear.ITEMS_PER_WRIT
  group.required = group.selectedCount
  group.have = entry.bag + entry.bank
  group.ready = math.min(group.selectedCount, group.have)
  group.crafts = 0
  group.produce, group.slots = remaining, remaining
  if MWC.Gear.IsStyleKnown(writ.fields[6], writ.fields[1]) == false then
    group.problem = L.PROBLEM_STYLE_UNKNOWN
  end
  local traitKnown, traitCount = MWC.Gear.TraitResearch(writ.fields)
  local setNeeds = MWC.Gear.SetTraitsRequired(writ.fields[4])
  if traitKnown == false then
    group.problem = group.problem or L.PROBLEM_TRAIT_UNKNOWN
  elseif traitCount and setNeeds and traitCount < setNeeds then
    group.problem = group.problem or string.format(L.PROBLEM_SET_TRAITS, setNeeds, traitCount)
  end
  group.improvementNotMaxed = group.quality == 5 and not MWC.Gear.IsImprovementMaxed(group.type) or nil
end

local function FillEnchanting(group, glyphIndex, links)
  local writ = group.writs[1]
  local text = GenerateMasterWritBaseText(group.link) or ""
  local spec, problem = MWC.Enchanting.Recipe(writ)

  group.perWrit = MWC.Enchanting.ITEMS_PER_WRIT
  group.name = MWC.WritItemName(text, L.GEAR_NAME_PATTERN)
  local glyphLink = MWC.LinkFromItemId(writ.fields[1])
  group.typeLabel = GLYPH_LABEL[GetItemLinkItemType(glyphLink)] or L.TYPE_GLYPH
  group.typeIcon = (GetItemLinkInfo(glyphLink))
  group.quality = spec and spec.quality or GetItemLinkFunctionalQuality(group.link)
  group.required = group.selectedCount * group.perWrit
  group.have = 0
  group.crafts, group.produce, group.slots = 0, 0, 0
  if not spec then
    group.problem = problem
    return
  end

  group.indexKey = spec.indexKey
  if MWC.Enchanting.NeedsGoldAspect(spec.quality) and not MWC.Enchanting.CanUseGoldAspect() then
    group.problem = L.PROBLEM_GOLD_GLYPH
  end
  local entry = glyphIndex[spec.indexKey] or { bag = 0, bank = 0 }
  group.have = entry.bag + entry.bank
  group.readyBag, group.readyBank = entry.bag, entry.bank
  group.ready = math.min(group.selectedCount, group.have)

  local ingredients = {}
  for _, id in ipairs(spec.runes) do
    table.insert(ingredients, { itemId = id, link = links[id] or MWC.LinkFromItemId(id), quantity = 1 })
  end
  group.recipe = { known = true, yield = MWC.Enchanting.YIELD, stackSize = MWC.Enchanting.STACK_SIZE, ingredients = ingredients }
  FillCrafting(group, group.recipe)
end

-- A group with nothing left to do (only writs already handed in or abandoned, the session history): what its row
-- shows and the key of its crafted item (the bank still recognises leftovers of it), nothing more. No reagents,
-- materials, prices, readiness or skill checks, and no bag scan for it.
local function FillHistory(group)
  local writ = group.writs[1]
  local fields = writ.fields
  group.crafts, group.produce, group.slots = 0, 0, 0
  if group.type == "provisioning" then
    local foodLink = MWC.LinkFromItemId(writ.foodItemId or 0)
    local isDrink = GetItemLinkItemType(foodLink) == ITEMTYPE_DRINK
    group.name = MWC.ItemName(foodLink)
    group.quality = GetItemLinkFunctionalQuality(foodLink)
    group.typeLabel = isDrink and L.TYPE_DRINK or L.TYPE_FOOD
    group.typeIcon = isDrink and DRINK_ICON or FOOD_ICON
  elseif group.type == "alchemy" then
    local isPoison = MWC.Alchemy.IsPoison(fields[1])
    group.isPoison = isPoison
    group.effectKey = MWC.Alchemy.EffectKeyOf(writ)
    group.name = MWC.Alchemy.WritPotionName(group.link)
    group.nameKey = MWC.sv.potionNames and MWC.sv.potionNames[writ.key]
    group.quality = GetItemLinkFunctionalQuality(group.link)
    group.typeLabel = isPoison and L.TYPE_POISON or L.TYPE_POTION
    group.typeIcon = MWC.Alchemy.IconFor(isPoison, group.nameKey)
      or (GetItemLinkInfo(isPoison and SAMPLE_POISON_LINK or SAMPLE_POTION_LINK))
  elseif group.type == "enchanting" then
    local text = GenerateMasterWritBaseText(group.link) or ""
    local spec = MWC.Enchanting.Recipe(writ)
    local glyphLink = MWC.LinkFromItemId(fields[1])
    group.indexKey = spec and spec.indexKey
    group.name = MWC.WritItemName(text, L.GEAR_NAME_PATTERN)
    group.typeLabel = GLYPH_LABEL[GetItemLinkItemType(glyphLink)] or L.TYPE_GLYPH
    group.typeIcon = (GetItemLinkInfo(glyphLink))
    group.quality = spec and spec.quality or GetItemLinkFunctionalQuality(group.link)
  else
    group.setName = MWC.CapitalFirst(zo_strformat("<<1>>", GetItemSetName(fields[4])))
    group.styleName = fields[6] > 0 and zo_strformat("<<1>>", GetItemStyleName(fields[6])) or nil
    group.traitName = zo_strformat("<<1>>", GetString("SI_ITEMTRAITTYPE", fields[5]))
    group.styled = fields[6] > 0
    group.indexKey = MWC.Gear.WritKey(writ)
    group.name = MWC.GearDisplayName(MWC.Gear.ItemName(group.link))
    group.typeLabel = GEAR_LABEL[group.type]
    group.typeIcon = GEAR_ICON[group.type]
    group.quality = fields[3] >= 1 and fields[3] <= 5 and fields[3] or GetItemLinkFunctionalQuality(group.link)
  end
end

-- Ingredients are shared between recipes, so sufficiency and cost must be computed on the sum.
-- With includeDone, materials already fully spent on crafted items are kept too (session totals).
function MWC.Plan.Materials(groups, includeDone)
  local byId, materials = {}, {}
  for _, group in ipairs(groups) do
    for _, ingredient in ipairs(group.ingredients) do
      if ingredient.need > 0 or (includeDone and (ingredient.total or 0) > 0) then
        local id = GetItemLinkItemId(ingredient.link)
        local material = byId[id]
        if not material then
          local price = PriceOf(ingredient.link)
          material = {
            link = ingredient.link, kind = ingredient.kind or "Base", craft = group.type, craftOrder = TYPE_ORDER[group.type],
            need = 0, have = ingredient.have, price = price, total = 0, used = 0,
            key = MWC.KeyItems.IsEnabled(MWC.KeyItems.ItemKey(id)), groups = {},
          }
          byId[id] = material
          table.insert(materials, material)
        end
        material.need = material.need + ingredient.need
        material.total = material.total + (ingredient.total or 0)
        material.used = material.used + (ingredient.used or 0)
        if TYPE_ORDER[group.type] < material.craftOrder then
          material.craft, material.craftOrder = group.type, TYPE_ORDER[group.type]
        end
        table.insert(material.groups, group)
      end
    end
  end
  for _, material in ipairs(materials) do
    material.short = material.have < material.need
    material.cost = (material.price or 0) * material.need
    material.totalCost = (material.price or 0) * material.total
  end
  table.sort(materials, function(a, b) return a.cost > b.cost end)
  return materials
end

-- Adds what handed-in writs took (from the session journal) to a session totals list, for the given crafts.
function MWC.Plan.AddSpent(materials, crafts)
  local byId = {}
  for _, material in ipairs(materials) do
    byId[GetItemLinkItemId(material.link)] = material
  end
  local _, _, spent = MWC.Journal.Completed()
  for id, entry in pairs(spent) do
    if not crafts or crafts[entry.craft] then
      local material = byId[id]
      if not material then
        local price = PriceOf(entry.link)
        material = {
          link = entry.link, kind = entry.kind, craft = entry.craft, craftOrder = TYPE_ORDER[entry.craft] or 99,
          need = 0, have = Owned(entry.link), price = price, total = 0, used = 0, cost = 0,
          key = MWC.KeyItems.IsEnabled(MWC.KeyItems.ItemKey(id)), groups = {},
        }
        byId[id] = material
        table.insert(materials, material)
      end
      material.total = material.total + entry.amount
      material.used = material.used + entry.amount
      material.totalCost = (material.price or 0) * material.total
    end
  end
  return materials
end

function MWC.Plan.Shortages(materials)
  local short = {}
  for _, material in ipairs(materials) do
    if material.short then
      table.insert(short, material)
    end
  end
  return short
end

local function SourceBags()
  local bags = {}
  if MWC.sv.includeBag then
    table.insert(bags, BAG_BACKPACK)
  end
  if MWC.sv.includeBank then
    table.insert(bags, BAG_BANK)
    table.insert(bags, BAG_SUBSCRIBER_BANK)
  end
  return bags
end

local function CompareGroups(a, b)
  if a.type ~= b.type then return TYPE_ORDER[a.type] < TYPE_ORDER[b.type] end
  if a.writCount ~= b.writCount then return a.writCount > b.writCount end
  return a.name < b.name
end

-- Writs that would spend a material from Keep materials, unless everything they ask for is crafted already.
local function MarkKept(group)
  group.kept = nil
  if (group.have or 0) >= group.writCount * (group.perWrit or 1) then return end
  local seen = {}
  for _, ingredient in ipairs(group.ingredients) do
    local id = GetItemLinkItemId(ingredient.link)
    if not seen[id] and MWC.KeyItems.IsEnabled(MWC.KeyItems.ItemKey(id)) then
      seen[id] = true
      group.kept = group.kept or {}
      table.insert(group.kept, ingredient.link)
    end
  end
end

-- The plan is made of one part per craft (station). A part is worked out again only when something of its own
-- craft changed: its writs (which, where, queued or not, quest state) or an item of its craft in the bags. A
-- bag change that concerns no craft (own gear, furniture, trophies, mail, trades) costs nothing. Materials,
-- totals and stats are summed up from the parts every time (cheap). Whatever can't be told apart for sure
-- marks every part as changed, so the plan can be slower, never wrong. MWC.Plan.Invalidate (the player's
-- actions, settings, the end of an operation) marks all of them.
local cachedPlan
local craftParts = {}
local dirtyCrafts, allDirty = {}, true
local GEAR_CRAFTS = { "blacksmithing", "clothier", "woodworking", "jewelry" }
local ALL_CRAFTS = { "blacksmithing", "clothier", "woodworking", "jewelry", "alchemy", "enchanting", "provisioning" }

function MWC.Plan.Invalidate()
  allDirty, cachedPlan = true, nil
end

local function MarkDirty(crafts)
  for _, craft in ipairs(crafts) do
    dirtyCrafts[craft] = true
    cachedPlan = nil
  end
end

-- Only these crafts changed (the player's action on their writs or materials): only their parts are worked out
-- again.
MWC.Plan.MarkDirty = MarkDirty

-- The writs or their state may have changed (quests, queueing): the plan is put together again, but a part
-- whose writs are the same (its signature) is kept.
function MWC.Plan.Touch()
  cachedPlan = nil
end
for _, event in ipairs({ EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED }) do
  EVENT_MANAGER:RegisterForEvent(MWC.name .. "PlanCacheQuest" .. event, event, MWC.Plan.Touch)
end

-- Item type -> the crafts it matters to. Any type not listed matters to none.
local CRAFTS_BY_ITEM_TYPE = {}
local function Matters(crafts, typeNames)
  for _, name in ipairs(typeNames) do
    if _G[name] then
      CRAFTS_BY_ITEM_TYPE[_G[name]] = crafts
    end
  end
end
Matters({ "alchemy" }, { "ITEMTYPE_POTION", "ITEMTYPE_POISON", "ITEMTYPE_REAGENT", "ITEMTYPE_POTION_BASE",
  "ITEMTYPE_POISON_BASE" })
Matters({ "enchanting" }, { "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_GLYPH_JEWELRY",
  "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY" })
Matters({ "provisioning" }, { "ITEMTYPE_FOOD", "ITEMTYPE_DRINK", "ITEMTYPE_INGREDIENT" })
-- Gear crafts share style materials and trait stones, so their materials matter to all four.
Matters(GEAR_CRAFTS, { "ITEMTYPE_WEAPON", "ITEMTYPE_ARMOR", "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",
  "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER", "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
  "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_BOOSTER", "ITEMTYPE_WOODWORKING_RAW_MATERIAL",
  "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",
  "ITEMTYPE_JEWELRYCRAFTING_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER",
  "ITEMTYPE_ARMOR_TRAIT", "ITEMTYPE_WEAPON_TRAIT", "ITEMTYPE_JEWELRY_TRAIT", "ITEMTYPE_JEWELRY_RAW_TRAIT",
  "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_MATERIAL", "ITEMTYPE_CROWN_ITEM" })

-- Holiday furnishings: their materials and results matter to the stations that make them (and provisioning).
Matters({ "blacksmithing", "clothier", "woodworking", "jewelry", "provisioning" },
  { "ITEMTYPE_FURNISHING_MATERIAL", "ITEMTYPE_FURNISHING" })

-- The crafts an item matters to: a writ to its own craft (all, when its craft can't be told), materials and
-- results by their type, the Crown Mimic Stone to gear. Empty for anything else.
local NONE = {}
local function CraftsOfLink(link, itemType)
  if itemType == ITEMTYPE_MASTER_WRIT then
    local craft = MWC.Writs.TypeOf(link)
    return craft and { craft } or ALL_CRAFTS
  end
  if GetItemLinkItemId(link) == MWC.Gear.MIMIC_STONE_ID then return GEAR_CRAFTS end
  return CRAFTS_BY_ITEM_TYPE[itemType] or NONE
end

-- The crafts an item matters to, by its link alone.
function MWC.Plan.CraftsOfItem(link)
  return CraftsOfLink(link, GetItemLinkItemType(link))
end

-- What each slot of the bags the plan reads held at the last look, so a removed item (its slot is empty by the
-- time the game reports it) is still known. A bag not looked at yet makes every part changed.
local SNAPSHOT_BAGS = { [BAG_BACKPACK] = true, [BAG_BANK] = true, [BAG_SUBSCRIBER_BANK] = true }
local snapshot = {}

local function Snapshot(bag)
  local slots = {}
  for _, at in ipairs(MWC.ItemSlots({ bag })) do
    local link = GetItemLink(bag, at[2], LINK_STYLE_DEFAULT)
    slots[at[2]] = CraftsOfLink(link, GetItemLinkItemType(link))
  end
  snapshot[bag] = slots
end

local function OnSlotUpdate(_, bag, slot)
  if bag == BAG_VIRTUAL then
    -- Craft bag: the slot is the item id, so what it is never changes.
    local link = MWC.LinkFromItemId(slot)
    MarkDirty(CraftsOfLink(link, GetItemLinkItemType(link)))
    return
  end
  if not SNAPSHOT_BAGS[bag] then return end
  local slots = snapshot[bag]
  if not slots then
    MWC.Plan.Invalidate()
    return
  end
  local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
  local now = link ~= "" and CraftsOfLink(link, GetItemLinkItemType(link)) or NONE
  MarkDirty(slots[slot] or NONE)
  MarkDirty(now)
  slots[slot] = now
end
EVENT_MANAGER:RegisterForEvent(MWC.name .. "PlanCacheSlots", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)

-- A craft finished at a station: that station's crafts (gear stations: all four, they share materials).
local CRAFTS_BY_STATION = {
  [CRAFTING_TYPE_ALCHEMY] = { "alchemy" }, [CRAFTING_TYPE_ENCHANTING] = { "enchanting" },
  [CRAFTING_TYPE_PROVISIONING] = { "provisioning" },
}
EVENT_MANAGER:RegisterForEvent(MWC.name .. "PlanCacheCraft", EVENT_CRAFT_COMPLETED, function(_, craftSkill)
  MarkDirty(CRAFTS_BY_STATION[craftSkill] or GEAR_CRAFTS)
end)

-- Rare changes of what the character knows or can do mark everything.
for _, name in ipairs({ "EVENT_STYLE_LEARNED", "EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED", "EVENT_SKILL_POINTS_CHANGED",
    "EVENT_SKILL_RANK_UPDATE", "EVENT_RECIPE_LEARNED", "EVENT_MULTIPLE_RECIPES_LEARNED" }) do
  if _G[name] then
    EVENT_MANAGER:RegisterForEvent(MWC.name .. "PlanCache" .. name, _G[name], MWC.Plan.Invalidate)
  end
end

-- Everything a part's counters come from: its writs, where they are, queued or not, their quest state.
local function PartSignature(writs)
  local parts = {}
  for _, writ in ipairs(writs) do
    table.insert(parts, string.format("%s:%s:%s:%s", writ.uid or "?", writ.state or "", tostring(writ.bag),
      MWC.Session.IsExcluded(writ.uid) and "x" or ""))
  end
  table.sort(parts)
  return table.concat(parts, ",")
end

local BuildPlan

function MWC.Plan.Build()
  if not cachedPlan then
    cachedPlan = MWC.Timed("plan build", BuildPlan)
  end
  return cachedPlan
end

-- The groups of one craft's writs, counted and worked out.
local function BuildPart(craftWrits)
  local groups, byKey = {}, {}
  for _, writ in ipairs(craftWrits) do
    local group = byKey[writ.key]
    if not group then
      group = {
        type = writ.type, typeOrder = TYPE_ORDER[writ.type], key = writ.key, link = writ.link, writs = {},
        event = writ.event,
        writCount = 0, selectedCount = 0, inBag = 0, inBank = 0, vouchers = 0,
        inventoryCount = 0, queued = 0, queuedVouchers = 0,
        activeCount = 0, activeVouchers = 0, completedCount = 0, completedVouchers = 0, closedCount = 0,
        ingredients = {}, shortIngredients = {},
      }
      byKey[writ.key] = group
      table.insert(groups, group)
    end
    table.insert(group.writs, writ)
    group.voucherMin = math.min(group.voucherMin or writ.vouchers, writ.vouchers)
    group.voucherMax = math.max(group.voucherMax or writ.vouchers, writ.vouchers)
    if not writ.state then
      group.inventoryCount = group.inventoryCount + 1
      group.writCount = group.writCount + 1
      if writ.bag == BAG_BACKPACK then
        group.inBag = group.inBag + 1
      else
        group.inBank = group.inBank + 1
      end
      if not MWC.Session.IsExcluded(writ.uid) then
        group.queued = group.queued + 1
        group.queuedVouchers = group.queuedVouchers + writ.vouchers
        group.selectedCount = group.selectedCount + 1
        group.vouchers = group.vouchers + writ.vouchers
      end
    elseif writ.state == "active" then
      group.activeCount = group.activeCount + 1
      group.activeVouchers = group.activeVouchers + writ.vouchers
      group.writCount = group.writCount + 1
      group.selectedCount = group.selectedCount + 1
      group.vouchers = group.vouchers + writ.vouchers
    elseif writ.state == "completed" then
      group.completedCount = group.completedCount + 1
      group.completedVouchers = group.completedVouchers + writ.vouchers
    else
      group.closedCount = group.closedCount + 1
      group.closedState = writ.state
    end
  end

  local potionIndex, glyphIndex, gearIndex, links
  for _, group in ipairs(groups) do
    if group.selectedCount == 0 and group.inventoryCount == 0 then
      FillHistory(group)
    elseif group.type == "provisioning" or (group.event and group.type ~= "alchemy") then
      FillProvisioning(group, MWC.Recipes.Build())
    elseif group.type == "alchemy" then
      potionIndex = potionIndex or MWC.Alchemy.PotionIndex()
      links = links or OwnedLinks()
      FillAlchemy(group, potionIndex, links)
    elseif group.type == "enchanting" then
      glyphIndex = glyphIndex or MWC.Enchanting.GlyphIndex()
      links = links or OwnedLinks()
      FillEnchanting(group, glyphIndex, links)
    else
      gearIndex = gearIndex or MWC.Gear.Index()
      FillGear(group, gearIndex)
    end
    if group.event then
      group.typeIcon, group.typeLabel = EVENT_ICON[group.event], EVENT_LABEL[group.event]
      group.name = string.format("%s ×%d", group.name or "?", group.perWrit or 0)
    end
    MarkKept(group)
    -- Stats: TTC value of everything the queued writs take, and of the part already in finished items.
    group.materialCost, group.readyMaterialCost = 0, 0
    for _, ingredient in ipairs(group.ingredients) do
      local price = PriceOf(ingredient.link) or 0
      group.materialCost = group.materialCost + (ingredient.total or 0) * price
      group.readyMaterialCost = group.readyMaterialCost + (ingredient.used or 0) * price
    end
  end
  return groups
end

BuildPlan = function()
  -- Writs in the bags, then the session journal's writs whose quest the addon started (their writ item is
  -- gone). Counts used for planning (selectedCount, writCount, vouchers) cover the writs still to be handed
  -- in: queued ones in the bags plus active quests, whose crafted items stay reserved for them. "queued" and
  -- "inventoryCount" are the bag writs alone, which the player can queue and skip.
  for bag in pairs(SNAPSHOT_BAGS) do
    if not snapshot[bag] then Snapshot(bag) end
  end
  local writs, inBags = MWC.Writs.Scan(SourceBags()), {}
  for _, writ in ipairs(writs) do
    inBags[writ.uid] = true
    if not writ.event then
      MWC.Journal.RememberWrit(writ)
    end
  end
  -- Right after a writ is used it can still show in the bag for a moment; it counts once, as a bag writ.
  -- Only the bags searched count here, so an acceptance is dropped only when its writ is seen again.
  MWC.Journal.ForgetUnused(inBags)
  for _, writ in ipairs(MWC.Journal.Writs()) do
    if not inBags[writ.uid] then
      table.insert(writs, writ)
    end
  end
  if MWC.sv.showEvent then
    for _, writ in ipairs(MWC.Journal.EventQuestWrits()) do
      table.insert(writs, writ)
    end
  end

  -- One part per craft, worked out again only when its writs or an item of its craft changed.
  local byCraft = {}
  for _, writ in ipairs(writs) do
    byCraft[writ.type] = byCraft[writ.type] or {}
    table.insert(byCraft[writ.type], writ)
  end
  local groups = {}
  for craft, craftWrits in pairs(byCraft) do
    local signature = PartSignature(craftWrits)
    local part = craftParts[craft]
    if allDirty or dirtyCrafts[craft] or not part or part.signature ~= signature then
      part = { signature = signature, groups = BuildPart(craftWrits) }
      craftParts[craft] = part
    end
    for _, group in ipairs(part.groups) do
      table.insert(groups, group)
    end
  end
  for craft in pairs(craftParts) do
    if not byCraft[craft] then craftParts[craft] = nil end
  end
  allDirty, dirtyCrafts = false, {}

  -- Unknown style or recipe: nothing to craft until it's learned, so such writs start skipped.
  local newlySkipped = false
  for _, group in ipairs(groups) do
    if AUTO_SKIP_PROBLEMS[group.problem] then
      for _, writ in ipairs(group.writs) do
        if not writ.state then
          newlySkipped = MWC.Session.AutoSkip(writ.uid) or newlySkipped
        end
      end
    end
  end
  if newlySkipped then
    zo_callLater(MWC.Marks.Refresh, 0)
    return BuildPlan()
  end
  table.sort(groups, CompareGroups)

  local materials = MWC.Plan.Materials(groups)
  return { groups = groups, materials = materials, shortages = MWC.Plan.Shortages(materials) }
end

-- Largest number of this group's writs that the owned ingredients can cover on their own.
function MWC.Plan.MaxAffordable(group)
  local recipe = group.recipe
  if not recipe then return 0 end
  local perWrit = group.perWrit
  for count = group.writCount, 1, -1 do
    local crafts = math.ceil(math.max(0, count * perWrit - group.have) / recipe.yield)
    local enough = true
    for i, ingredient in ipairs(recipe.ingredients) do
      if ingredient.quantity * crafts > group.ingredients[i].have then
        enough = false
        break
      end
    end
    if enough then return count end
  end
  return 0
end

function MWC.Plan.Totals(groups)
  local t = {
    writs = 0, vouchers = 0, ready = 0, crafts = 0, items = 0, slots = 0,
    readyVouchers = 0, materials = 0, readyMaterials = 0, trackedWrits = 0, completed = 0,
  }
  for _, group in ipairs(groups) do
    t.completed = t.completed + (group.completedCount or 0)
    local ready = group.ready or 0
    -- Only writs whose crafted items the addon can count take part in the progress figure.
    if group.ready then
      t.trackedWrits = t.trackedWrits + group.selectedCount
    end
    t.writs = t.writs + group.selectedCount
    t.vouchers = t.vouchers + group.vouchers
    t.ready = t.ready + ready
    if group.selectedCount > 0 then
      t.readyVouchers = t.readyVouchers + group.vouchers * ready / group.selectedCount
    end
    t.materials = t.materials + (group.materialCost or 0)
    t.readyMaterials = t.readyMaterials + (group.readyMaterialCost or 0)
    t.crafts = t.crafts + group.crafts
    t.items = t.items + group.produce
    t.slots = t.slots + (group.slots or 0)
  end
  t.bagSize = GetBagSize(BAG_BACKPACK)
  t.used = t.bagSize - GetNumBagFreeSlots(BAG_BACKPACK)
  t.usedAfter = t.used + t.slots
  return t
end
