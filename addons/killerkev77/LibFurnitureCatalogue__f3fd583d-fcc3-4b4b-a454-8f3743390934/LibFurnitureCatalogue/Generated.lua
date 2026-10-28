local LFC = LibFurnitureCatalogue
local data, vocabulary = assert(LFCGeneratedDatabase), assert(LFCGeneratedConstants)
local constants = LFC.Internal.Constants
local src = constants.ItemSources
local generated = {}
local containers = {}
LFC.Internal.Generated = generated

local currencies = {
  GOLD = CURT_MONEY,
  AP = CURT_ALLIANCE_POINTS,
  TEL_VAR = CURT_TELVAR_STONES,
  WRIT_VOUCHERS = CURT_WRIT_VOUCHERS,
  EVENT_TICKETS = CURT_TRADE_BARS,
  CROWNS = CURT_CROWNS,
  CROWN_GEMS = CURT_CROWN_GEMS,
  SEALS = CURT_ENDEAVOR_SEALS,
  UNDAUNTED_KEYS = CURT_UNDAUNTED_KEYS,
  ARCHIVAL_FORTUNES = CURT_ARCHIVAL_FORTUNES,
  TRADE_BARS = CURT_TRADE_BARS,
}
local kinds = {
  recipe = src.CRAFTING,
  luxury = src.LUXURY,
  writ_vendor = src.ROLIS,
  pvp_vendor = src.PVP,
  event_drop = src.FESTIVAL_DROP,
  event_vendor = src.FESTIVAL_DROP,
  crown_crate = src.CROWN,
  crown_store = src.CROWN,
  drop = src.DROP,
  quest_reward = src.QUEST,
  dungeon_drop = src.DUNGEON,
  housing = src.CROWN,
  companion = src.QUEST,
  guild_gift = src.DROP,
  tome_pack = src.TOMES,
  ignored = src.IGNORED,
}
local drops = {
  chest = src.CHEST,
  dark_brotherhood = src.DROP,
  tales_of_tribute = src.QUEST,
  wardrobe = src.STEAL_CONTAINER,
  cabinet = src.STEAL_CONTAINER,
  safebox = src.STEAL_CONTAINER,
  fish = src.FISHING,
  steal = src.STEAL_CONTAINER,
  pickpocket = src.PICKPOCKET,
  harvest = src.HARVEST,
  scryable = src.ANTIQUITY,
}
local categories = {
  chest = SI_FURC_SRC_CHESTS,
  safebox = SI_FURC_SRC_SAFEBOX,
  fish = SI_FURC_SRC_FISH,
  steal = SI_FURC_SRC_STEAL,
  pickpocket = SI_FURC_SRC_PICK,
  harvest = SI_FURC_SRC_HARVEST,
  scryable = SI_FURC_SRC_SCRYING,
  tales_of_tribute = SI_FURC_SRC_TOT,
  dark_brotherhood = SI_FURC_DB,
  wardrobe = SI_FURC_SRC_WARDROBE,
  cabinet = SI_FURC_SRC_CABINET,
}
local enumFields = vocabulary.sourceVocabularies
local fieldNames =
  { skill_line = "skillLine", skill_rank = "skillRank", part_of = "partOf", npc_class = "npcClass", npc_group = "note" }
local function symbol(group, id)
  return assert(vocabulary.symbols[group][id], "unknown generated vocabulary id")
end
local function resolve(group, id)
  if type(id) == "table" then
    local result = {}
    for i, member in ipairs(id) do
      result[i] = resolve(group, member)
    end
    return result
  end
  local meta = assert(vocabulary.metadata[group][id], "missing generated game identifier")
  return meta.zone or meta.item or meta.crate or meta.skill_line or assert(_G[meta.si], meta.si)
end
local function placements(values)
  if not values then
    return
  end
  local result = {}
  for i, value in ipairs(values) do
    result[i] = {
      location = value[1] and resolve("locations", value[1]),
      place = value[2] and resolve("places", value[2]),
      note = value[3],
    }
  end
  return result
end
local function note(value)
  if value == "LEVELUP_REWARD" then
    return SI_FURC_SRC_LVLUP
  end
  if constants.NpcIds[value] then
    return { npc = constants.NpcIds[value] }
  end
  return _G[value] or value
end
local sourceColumn = {}
for i, name in ipairs(vocabulary.sourceFields) do
  sourceColumn[name] = vocabulary.sourceFieldOffset + i
end
local function decode(record)
  local kind = symbol("source_types", record[1])
  local fields = {}
  for name, column in pairs(sourceColumn) do
    fields[name] = record[column]
  end
  local subtype = fields.subtype and symbol(kind .. "_subtypes", fields.subtype)
  local source = { type = kinds[kind] }
  if kind == "vendor" then
    source.type = subtype == "home_goods" and src.HOME_GOODS
      or subtype == "achievement" and src.ACHIEVEMENT
      or src.VENDOR
  elseif kind == "drop" then
    source.type = drops[subtype] or src.DROP
    if subtype == "wardrobe" or subtype == "cabinet" or subtype == "safebox" then
      source.containerKind = categories[subtype]
    else
      source.category = categories[subtype]
    end
  elseif kind == "crown_store" and subtype == "housing_editor" then
    source.type = src.EDITOR
  elseif kind == "quest_reward" and subtype == "daily" then
    source.category = SI_FURC_SRC_QUEST_DAILY
  end
  for field, value in pairs(fields) do
    local target = fieldNames[field] or field
    if enumFields[field] and field ~= "companion" then
      source[target] = resolve(enumFields[field], value)
    elseif field == "locations" then
      source.locations = placements(value)
    elseif field == "note" then
      source.note = note(value)
    elseif field ~= "subtype" and field ~= "companion" then
      source[target] = type(value) == "table" and ZO_DeepTableCopy(value) or value
    end
  end
  if source.packs and type(source.packs) ~= "table" then
    source.packs = { source.packs }
  end
  if not source.locations and fields.vendor then
    source.locations = placements(vocabulary.vendorLocations[fields.vendor])
  end
  if kind == "guild_gift" then
    source.category = SI_FURC_SRC_PLAYER_GUILD
  end
  if kind == "companion" then
    local names = {
      AZANDAR = "Azandar",
      EMBER = "Ember",
      ISOBEL = "Isobel",
      SHARP_AS_NIGHT = "Sharp-as-Night",
      TANLORIN = "Tanlorin",
      ZERITH_VAR = "Zerith-var",
    }
    source.note = assert(names[symbol("companions", fields.companion)]) .. " rapport"
  end
  if kind == "tome_pack" then
    local names = { armor = "ARMOR", dawn = "DAWN", logic = "LOGIC" }
    source.itemPack = constants.TomesPacks[names[fields.note]]
    if source.itemPack then
      source.note = nil
    end
  end
  if record[5] then
    local rarity = symbol("rarities", record[5])
    source.rarity = rarity == "rare" and SI_FURC_RARITY_RARE
      or rarity == "extremely_rare" and SI_FURC_RARITY_EXTREMELYRARE
      or nil
  end
  return source, kind
end
local function recordsFor(id, active)
  local row = data.items[id]
  if not row then
    return data.rumours[id] and { { source = { type = src.RUMOUR } } } or {}
  end
  active = active or {}
  assert(not active[id], "generated container cycle")
  active[id] = true
  local result, crafting = {}, {}
  for i = 4, #row do
    local record = row[i]
    local first = #result + 1
    local source, kind = decode(record)
    if kind == "container" then
      for _, parent in ipairs(recordsFor(source.partOf, active)) do
        parent.source.partOf = source.partOf
        result[#result + 1] = parent
      end
    else
      assert(source.type, "unknown generated source")
      if #record[3] == 0 then
        result[#result + 1] = { source = source, lastSeen = record[4] }
      else
        for _, cost in ipairs(record[3]) do
          local currency = assert(currencies[symbol("currencies", cost[1])], "unsupported game currency")
          local origin = ZO_DeepTableCopy(source)
          if kind == "crown_store" and currency == CURT_TRADE_BARS then
            origin.type = src.BAZAAR
          end
          result[#result + 1] =
            { source = origin, cost = { currency = currency, amount = cost[2] }, lastSeen = record[4] }
        end
      end
    end
    if record[7] and kind ~= "recipe" then
      for j = first, #result do
        local copy = ZO_DeepTableCopy(result[j])
        copy.source.type = src.CRAFTING
        crafting[#crafting + 1] = copy
      end
    end
  end
  if #crafting > 0 then
    for i = #result, 1, -1 do
      if result[i].source.type == src.CRAFTING then
        table.remove(result, i)
      end
    end
    for _, offer in ipairs(crafting) do
      result[#result + 1] = offer
    end
  end
  active[id] = nil
  table.sort(result, function(a, b)
    return (constants.SOURCE_PRIORITY[a.source.type] or math.huge)
      < (constants.SOURCE_PRIORITY[b.source.type] or math.huge)
  end)
  return result
end
generated.Records = recordsFor
function generated.Key(id)
  if data.items[id] or data.rumours[id] then
    return id
  end
  local target = data.blueprints[id]
  if target and target ~= 0 then
    return target
  end
end

local function bucket(table_, version, source)
  table_[version] = table_[version] or {}
  if source then
    table_[version][source] = table_[version][source] or {}
    return table_[version][source]
  end
  return table_[version]
end
function generated.Install()
  local build = LFC.Internal.Build
  LFC.Internal.IgnoredItems = {}
  FurC.MiscItemSources, FurC.LuxuryFurnisher, FurC.Rolis, FurC.Faustina = {}, {}, {}, {}
  containers = {}
  FurC.Books = {}
  FurC.AchievementVendors, FurC.HomeGoodsFurnisher, FurC.PVP = {}, {}, {}
  FurC.CrownStore, FurC.Antiquities, FurC.Justice, FurC.Fishing = {}, {}, {}, {}
  for id, row in pairs(data.items) do
    local mask = 0
    local records = recordsFor(id)
    for _, record in ipairs(records) do
      mask = build.AddSource(mask, record.source.type)
      if record.source.type == src.IGNORED then
        LFC.Internal.IgnoredItems[id] = true
      end
      local compatibility = ZO_DeepTableCopy(record.source)
      compatibility.type = nil
      if compatibility.locations then
        local zones = {}
        for _, place in ipairs(compatibility.locations) do
          if place.location then
            zones[#zones + 1] = place.location
          end
          compatibility.place = compatibility.place or place.place
        end
        compatibility.locations = #zones > 1 and zones or nil
        compatibility.location = #zones == 1 and zones[1] or nil
      end
      if record.cost then
        compatibility.itemPrice, compatibility.currency = record.cost.amount, record.cost.currency
      end
      compatibility.itemDate = record.lastSeen
      if record.source.vendor == constants.NpcIds.MAGES_MYSTIC and not record.source.achievement then
        bucket(FurC.Books, row[2])[id] = compatibility
      end
      if
        record.source.vendor
        and record.source.locations
        and (
          record.source.type == src.VENDOR
          or record.source.type == src.ACHIEVEMENT
          or record.source.type == src.HOME_GOODS
        )
      then
        local vendors = record.source.type == src.HOME_GOODS and FurC.HomeGoodsFurnisher or FurC.AchievementVendors
        for _, place in ipairs(record.source.locations) do
          local zone = place.location or place.place
          if zone then
            local locations = bucket(vendors, row[2], zone)
            locations[record.source.vendor] = locations[record.source.vendor] or {}
            locations[record.source.vendor][id] = compatibility
          end
        end
      end
      local view = bucket(FurC.MiscItemSources, row[2], record.source.type)
      view[id] = view[id] or compatibility
      if record.source.type == src.LUXURY then
        bucket(FurC.LuxuryFurnisher, row[2])[id] = compatibility
      end
      if record.source.type == src.ROLIS then
        local vendor = record.source.vendor == constants.NpcIds.FAUSTINA and FurC.Faustina or FurC.Rolis
        bucket(vendor, row[2])[row[3] ~= 0 and row[3] or id] = compatibility
      end
    end
    if row[3] ~= 0 then
      mask = build.AddSource(mask, src.CRAFTING)
    end
    build.Upsert(id, { sources = mask, version = row[2], blueprint = row[3] ~= 0 and row[3] or nil })
    for i = 4, #row do
      if row[i][6] then
        containers[id] = { kind = vocabulary.containerKinds[row[i][6]], contents = {} }
      end
    end
  end
  for id, row in pairs(data.items) do
    for i = 4, #row do
      local parent = row[i][sourceColumn.part_of]
      local container = parent and containers[parent]
      if container then
        table.insert(container.contents, row[i][7] or id)
      end
    end
  end
  for _, container in pairs(containers) do
    table.sort(container.contents)
  end
  FurC.BookCollections, FurC.FurnishingFolios = {}, {}
  local byKind = { books = FurC.BookCollections, folio = FurC.FurnishingFolios }
  for id, container in pairs(containers) do
    local target = byKind[container.kind]
    if target then
      target[id] = { contents = ZO_DeepTableCopy(container.contents) }
    end
  end
  for id, version in pairs(data.rumours) do
    build.Upsert(id, { origin = src.RUMOUR, version = version })
  end
end

function generated.Container(id)
  local container = containers[id]
  return container and ZO_DeepTableCopy(container) or nil
end
