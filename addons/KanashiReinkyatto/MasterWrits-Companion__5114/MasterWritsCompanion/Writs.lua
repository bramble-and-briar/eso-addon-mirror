MWC.Writs = {}

local TYPE_BY_ICON = {
  ["/esoui/art/icons/master_writ_blacksmithing.dds"] = "blacksmithing",
  ["/esoui/art/icons/master_writ_clothier.dds"] = "clothier",
  ["/esoui/art/icons/master_writ_woodworking.dds"] = "woodworking",
  ["/esoui/art/icons/master_writ_jewelry.dds"] = "jewelry",
  ["/esoui/art/icons/master_writ_provisioning.dds"] = "provisioning",
  ["/esoui/art/icons/master_writ_alchemy.dds"] = "alchemy",
  ["/esoui/art/icons/master_writ_enchanting.dds"] = "enchanting",
}

-- Positions in the data returned by ZO_LinkHandler_ParseLink for a master writ link.
local FIELD = { FOOD_ITEM_ID = 10, FIRST_WRIT = 10, LAST_WRIT = 15, REWARD = 24 }
local REWARD_PER_VOUCHER = 10000

-- An item link never changes, so what it says is worked out once per session (scans go over every slot of
-- every bag, again and again).
local typeByLink, parsedByLink = {}, {}

function MWC.Writs.TypeOf(link)
  local known = typeByLink[link]
  if known == nil then
    known = GetItemLinkItemType(link) == ITEMTYPE_MASTER_WRIT and TYPE_BY_ICON[(GetItemLinkInfo(link))] or false
    typeByLink[link] = known
  end
  return known or nil
end

local function Parse(link)
  local fields = { ZO_LinkHandler_ParseLink(link) }
  local parts, numbers = {}, {}
  for i = FIELD.FIRST_WRIT, FIELD.LAST_WRIT do
    table.insert(parts, fields[i] or "")
    table.insert(numbers, tonumber(fields[i]) or 0)
  end
  return fields, table.concat(parts, ":"), numbers
end

local function Record(link, writType, uid, bag, slot)
  local parsed = parsedByLink[link]
  if not parsed then
    parsed = { Parse(link) }
    parsedByLink[link] = parsed
  end
  local fields, taskKey, taskFields = parsed[1], parsed[2], parsed[3]
  return {
    bag = bag,
    slot = slot,
    link = link,
    type = writType,
    key = writType .. ":" .. taskKey,
    -- Task fields: provisioning = { food item id }, alchemy = { solvent code, effect 1, effect 2, effect 3 }.
    fields = taskFields,
    uid = uid,
    foodItemId = writType == "provisioning" and tonumber(fields[FIELD.FOOD_ITEM_ID]) or nil,
    vouchers = zo_round((tonumber(fields[FIELD.REWARD]) or 0) / REWARD_PER_VOUCHER),
  }
end

-- Holiday writs (Witches Festival, New Life / Deep Winter / Imperial Charity) are master writ items of their own:
-- the item to make sits where a provisioning master writ has its food, and the Witches Festival alchemy writ is
-- laid out like an alchemy master writ. Kind by item id, or by icon for an id not listed here.
local EVENT_BY_ITEM_ID = {
  [153482] = "witches", [153510] = "witches", [145572] = "newlife",
  [156733] = "deepwinter", [156734] = "deepwinter", [156735] = "deepwinter",
  [167169] = "imperial", [167170] = "imperial", [167171] = "imperial", [167172] = "imperial",
}
local EVENT_BY_ICON = {
  ["/esoui/art/icons/master_writ_witchesfestival.dds"] = "witches",
  ["/esoui/art/icons/master_writ-newlife.dds"] = "newlife",
}
MWC.Writs.EVENT_ITEM_IDS = {}
for itemId in pairs(EVENT_BY_ITEM_ID) do
  table.insert(MWC.Writs.EVENT_ITEM_IDS, itemId)
end

function MWC.Writs.EventKindOfItem(itemId)
  return EVENT_BY_ITEM_ID[itemId]
end

-- A writ item of each kind for food and furnishings, to rebuild a writ from its quest when it was never seen.
local EVENT_WRIT_ITEM = { witches = 153482, newlife = 145572, deepwinter = 156735, imperial = 167172 }
-- Solvent codes of an alchemy writ (potion, poison), in the place of the item to make.
local ALCHEMY_SOLVENT_CODES = { [199] = true, [239] = true }
local CRAFT_BY_CRAFTING_TYPE = {
  [CRAFTING_TYPE_BLACKSMITHING] = "blacksmithing", [CRAFTING_TYPE_CLOTHIER] = "clothier",
  [CRAFTING_TYPE_WOODWORKING] = "woodworking", [CRAFTING_TYPE_JEWELRYCRAFTING] = "jewelry",
  [CRAFTING_TYPE_ALCHEMY] = "alchemy", [CRAFTING_TYPE_ENCHANTING] = "enchanting",
  [CRAFTING_TYPE_PROVISIONING] = "provisioning",
}
-- Deep Winter's plain cup and bowl are wanted 3 at a time, its other plain furnishings 12.
local DEEP_WINTER_THREE = { [120410] = true, [117943] = true }

-- How many of the item one holiday writ wants: not in the writ, it follows the kind and the item's quality (the
-- rules the wikis and Dolgubon's Lazy Writ Crafter go by). Alchemy wants what an alchemy master writ wants.
local function EventCount(kind, itemId)
  local link = MWC.LinkFromItemId(itemId)
  local magic = GetItemLinkFunctionalQuality(link) >= ITEM_FUNCTIONAL_QUALITY_MAGIC
  local itemType = GetItemLinkItemType(link)
  local food = itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK
  if kind == "witches" then return 4 end
  if kind == "deepwinter" then
    if magic then return 1 end
    return DEEP_WINTER_THREE[itemId] and 3 or 12
  end
  if kind == "imperial" then
    if not magic then return 3 end
    return food and 12 or 1
  end
  return magic and 1 or 12
end

-- A holiday writ: { kind, craft, count } (count nil for alchemy), or nil. Worked out once per link.
local eventByLink = {}
function MWC.Writs.EventOf(link)
  local known = eventByLink[link]
  if known == nil then
    known = false
    if GetItemLinkItemType(link) == ITEMTYPE_MASTER_WRIT then
      local kind = EVENT_BY_ITEM_ID[GetItemLinkItemId(link)] or EVENT_BY_ICON[(GetItemLinkInfo(link))]
      local target = kind and tonumber((select(FIELD.FOOD_ITEM_ID, ZO_LinkHandler_ParseLink(link))))
      if target and ALCHEMY_SOLVENT_CODES[target] then
        known = { kind = kind, craft = "alchemy" }
      elseif target and target > 0 then
        -- The recipe tells the station even while it isn't known.
        local craftingType = GetRecipeInfoFromItemId(target)
        local itemType = GetItemLinkItemType(MWC.LinkFromItemId(target))
        local craft = CRAFT_BY_CRAFTING_TYPE[craftingType]
          or ((itemType == ITEMTYPE_FOOD or itemType == ITEMTYPE_DRINK) and "provisioning" or nil)
        if craft then
          known = { kind = kind, craft = craft, count = EventCount(kind, target), itemId = target }
        end
      end
    end
    eventByLink[link] = known
  end
  return known or nil
end

-- What a holiday writ asks for, the same whether read from the writ or from its quest: kind and item to make, or
-- kind and solvent code for alchemy.
local function EventTaskKey(kind, craft, itemId, solvent)
  if craft == "alchemy" then return string.format("%s:alchemy:%s", kind, tostring(solvent)) end
  return string.format("%s:%s", kind, tostring(itemId))
end

local function EventRecord(link, event, uid, bag, slot)
  local writ = Record(link, event.craft, uid, bag, slot)
  writ.key = "event:" .. event.kind .. ":" .. writ.key
  writ.event = event.kind
  writ.eventCount = event.count
  writ.foodItemId = event.itemId
  -- Its link is kept, so its quest can still be shown once the writ is used (vouchers, alchemy effects).
  local saved = MWC.sv.eventWritLinks or {}
  MWC.sv.eventWritLinks = saved
  saved[EventTaskKey(event.kind, event.craft, event.itemId, writ.fields[1])] = link
  return writ
end

-- The writ of a holiday quest whose writ item is gone (used to start it): from the link seen before, or for
-- food and furnishings rebuilt from the item the quest asks for. Active, with an id of its own. Nil when it
-- can't be told (an alchemy writ never seen).
function MWC.Writs.EventQuestWrit(kind, craftType, itemId, solvent)
  local craft = craftType == CRAFTING_TYPE_ALCHEMY and "alchemy" or nil
  local key = EventTaskKey(kind, craft, itemId, solvent)
  local link = MWC.sv.eventWritLinks and MWC.sv.eventWritLinks[key]
  if not link and not craft and EVENT_WRIT_ITEM[kind] then
    link = string.format("|H0:item:%d:4:1:0:0:0:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", EVENT_WRIT_ITEM[kind], itemId)
  end
  local event = link and MWC.Writs.EventOf(link)
  if not event then return nil end
  local writ = EventRecord(link, event, "quest:" .. key)
  writ.state = "active"
  return writ
end

-- Identical writs share a key (same task), but each has its own unique id.
-- Only the master writs are looked at (the bags' item type filter), not every slot. Holiday writs only with the
-- Event checkbox on.
local WRIT_TYPES = { [ITEMTYPE_MASTER_WRIT] = true }

function MWC.Writs.Scan(bags)
  local writs = {}
  local events = MWC.sv.showEvent
  for _, at in ipairs(MWC.ItemSlots(bags, WRIT_TYPES)) do
    local bag, slot = at[1], at[2]
    local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
    local writType = link ~= "" and MWC.Writs.TypeOf(link)
    if writType then
      table.insert(writs, Record(link, writType, Id64ToString(GetItemUniqueId(bag, slot)), bag, slot))
    elseif events and link ~= "" then
      local event = MWC.Writs.EventOf(link)
      if event then
        table.insert(writs, EventRecord(link, event, Id64ToString(GetItemUniqueId(bag, slot)), bag, slot))
      end
    end
  end
  return writs
end

-- The same record for a writ that is no longer in any bag (used for its quest), from its saved link.
function MWC.Writs.FromLink(link, uid)
  local writType = MWC.Writs.TypeOf(link)
  return writType and Record(link, writType, uid) or nil
end
