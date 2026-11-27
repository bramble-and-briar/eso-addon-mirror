local L = MWC.L
-- Session journal: every writ whose quest was started through the addon, from the moment the writ is used
-- until its quest is handed in. A used writ leaves the inventory, so without this the addon would forget it:
-- its crafted items would look free for other writs, and its materials and vouchers would drop out of the
-- session figures. Writs never used by the addon (in a chest, in the bank) are not recorded at all.
--
-- Entry states: "accepting" (writ used, quest not in the journal yet), "active" (quest in the journal),
-- "completed" (handed in), "abandoned" (quest removed without completion), "unknown" (the quest left the
-- journal while the addon couldn't see it, e.g. with the addon off). Kept until the session is reset.
MWC.Journal = {}

local ACCEPT_TIMEOUT_S = 60

local function Entries()
  local session = MWC.sv.session
  session.journal = session.journal or {}
  return session.journal
end

local function CharacterId()
  return GetCurrentCharacterId()
end

-- Master writ quest names are learned from the quests this addon starts (kept per account); a name seen for
-- several crafts counts for all of them.
local function LearnQuestName(name, craft)
  MWC.sv.questCrafts = MWC.sv.questCrafts or {}
  local crafts = MWC.sv.questCrafts[name] or {}
  crafts[craft] = true
  MWC.sv.questCrafts[name] = crafts
end

-- The game describes a master writ quest in numbers: craft, item, material, quality, set, trait, style and the
-- alchemy traits. Daily writs and other quests have none of it.
local CRAFT_BY_TYPE = {
  [CRAFTING_TYPE_BLACKSMITHING] = "blacksmithing", [CRAFTING_TYPE_CLOTHIER] = "clothier",
  [CRAFTING_TYPE_WOODWORKING] = "woodworking", [CRAFTING_TYPE_JEWELRYCRAFTING] = "jewelry",
  [CRAFTING_TYPE_ALCHEMY] = "alchemy", [CRAFTING_TYPE_ENCHANTING] = "enchanting",
  [CRAFTING_TYPE_PROVISIONING] = "provisioning",
}

local function QuestVouchers(questIndex)
  for reward = 1, GetJournalQuestNumRewards(questIndex) do
    local rewardType, _, amount = GetJournalQuestRewardInfo(questIndex, reward)
    if rewardType == REWARD_TYPE_WRIT_VOUCHERS then
      return amount or 0
    end
  end
  return 0
end

-- Holiday writ quests carry master writ data like master writs (what to make), so they are told apart, in any
-- client language, by:
--   * their names: the Witches Festival quests are named like their writ items (read in the client's language),
--     and every holiday quest once recognised by its data is remembered by name (kept per account);
--   * their data: master writ data without a voucher reward (every master writ quest rewards vouchers). Only
--     while the crafting step lasts: the hand-in step has no data, there the remembered name tells.
--   * the English charity names from the language file, for quests started before this was known.
local eventQuestNames
-- Names of quests seen with master writ data and vouchers: master writs, not looked at again (this session).
local masterQuestNames = {}

local function EventQuestNames()
  if not eventQuestNames then
    eventQuestNames = {}
    for _, itemId in ipairs(MWC.Writs.EVENT_ITEM_IDS) do
      local itemName = GetItemLinkName(MWC.LinkFromItemId(itemId))
      if itemName ~= "" then
        eventQuestNames[zo_strformat("<<1>>", itemName)] = MWC.Writs.EventKindOfItem(itemId)
      end
    end
  end
  return eventQuestNames
end

-- The kind of a holiday writ quest by its name (nil for any other quest, or one not recognised yet).
function MWC.Journal.EventKindOfName(name)
  name = zo_strformat("<<1>>", name or "")
  if name == "" then return nil end
  local kind = EventQuestNames()[name] or (MWC.sv.eventQuestNames and MWC.sv.eventQuestNames[name])
  if kind then return kind end
  local charity = MWC.L.CHARITY_QUEST
  if charity and charity.prefix and name:find(charity.prefix, 1, true) == 1 then
    for eventKind, word in pairs(charity.kinds or {}) do
      if name:find(word, 1, true) then return eventKind end
    end
    return charity.default
  end
  return nil
end

function MWC.Journal.IsEventQuestName(name)
  return MWC.Journal.EventKindOfName(name) ~= nil
end

-- A holiday writ quest by its data (see above): its kind, "unknown" when the writ was never seen, or nil.
local function EventKindOfData(questIndex, name)
  if masterQuestNames[name] then return nil end
  local step = QUEST_MAIN_STEP_INDEX or 1
  for condition = 1, GetJournalQuestNumConditions(questIndex, step) do
    local itemId, solvent, craftType = GetQuestConditionMasterWritInfo(questIndex, step, condition)
    if itemId then
      -- A task only a holiday writ asks for (a holiday food or furnishing seen on a holiday writ) is told by
      -- that alone: some holiday quests reward vouchers too. Alchemy tasks are told only by their solvent,
      -- which master writs share, so for them the vouchers decide.
      local taskKind = craftType ~= CRAFTING_TYPE_ALCHEMY and MWC.Writs.EventKindOfTask(craftType, itemId, solvent)
      if not taskKind and QuestVouchers(questIndex) > 0 then
        masterQuestNames[name] = true
        return nil
      end
      local kind = taskKind or MWC.Writs.EventKindOfTask(craftType, itemId, solvent) or "unknown"
      if kind ~= "unknown" and name ~= "" then
        MWC.sv.eventQuestNames = MWC.sv.eventQuestNames or {}
        if MWC.sv.eventQuestNames[name] ~= kind then
          MWC.sv.eventQuestNames[name] = kind
          MWC.Log("Event: quest name learned, %s = %s", name, kind)
        end
      end
      return kind
    end
  end
  return nil
end

function MWC.Journal.EventKindOfQuest(questIndex)
  local name = zo_strformat("<<1>>", GetJournalQuestName(questIndex))
  return MWC.Journal.EventKindOfName(name) or EventKindOfData(questIndex, name)
end

function MWC.Journal.IsEventQuest(questIndex)
  return MWC.Journal.EventKindOfQuest(questIndex) ~= nil
end

-- Holiday writ quests in the journal as active writs (their writ items are gone once used), read from the quest
-- itself: what to make is in its crafting condition. Started by the addon or by hand, before a reload or after.
function MWC.Journal.EventQuestWrits()
  local writs = {}
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    local kind = IsValidQuestIndex(questIndex) and MWC.Journal.EventKindOfQuest(questIndex)
    if kind and kind ~= "unknown" then
      local step = QUEST_MAIN_STEP_INDEX or 1
      for condition = 1, GetJournalQuestNumConditions(questIndex, step) do
        local itemId, solvent, craftType = GetQuestConditionMasterWritInfo(questIndex, step, condition)
        if itemId then
          local writ = MWC.Writs.EventQuestWrit(kind, craftType, itemId, solvent)
          if writ then
            table.insert(writs, writ)
          end
          break
        end
      end
    end
  end
  return writs
end

-- A master writ quest's data, or nil for any other quest (holiday writ quests included).
function MWC.Journal.MasterWritInfo(questIndex)
  if not IsValidQuestIndex(questIndex) or MWC.Journal.IsEventQuest(questIndex) then return nil end
  local itemId, materialItemId, craftType, quality, templateId, setId, traitType, styleId, alchemyTraits =
    GetQuestConditionMasterWritInfo(questIndex, QUEST_MAIN_STEP_INDEX or 1, 1)
  if itemId == nil then return nil end
  return {
    itemId = itemId, materialItemId = materialItemId, craft = CRAFT_BY_TYPE[craftType], quality = quality,
    templateId = templateId, setId = setId, traitType = traitType, styleId = styleId, alchemyTraits = alchemyTraits,
  }
end

local function IsCraftingQuest(questIndex, name)
  return MWC.Journal.MasterWritInfo(questIndex) ~= nil
    and (not name or GetJournalQuestName(questIndex) == name)
end

-- A material's link is saved only when it holds more than the item id (a level, a style): a plain one is
-- rebuilt from the id, so the history keeps every figure in a fraction of the space.
local function SavedLink(link, itemId)
  if link and link:match("^|H%d:item:(%d+)[:0]*|h|h$") == tostring(itemId) then return nil end
  return link
end

local function MaterialLink(material, itemId)
  return material.link or MWC.LinkFromItemId(itemId)
end

-- Older sessions saved every link: the plain ones are dropped once, at load.
function MWC.Journal.Compact()
  for _, entry in pairs(MWC.sv.session.journal or {}) do
    for id, material in pairs(entry.materials or {}) do
      material.link = SavedLink(material.link, id)
    end
  end
end

-- The writ was used and its quest accepted: from now on it lives here. The materials are its share of the
-- group's (a group's ingredients cover all its pending writs).
function MWC.Journal.RecordAccepted(writ, group)
  -- Holiday quests are no master writ quests: an entry for one would hold its craft as "active" (see ActiveCrafts).
  if group.event then return end
  local materials = {}
  local pending = math.max(group.selectedCount, 1)
  for _, ingredient in ipairs(group.ingredients) do
    if (ingredient.total or 0) > 0 then
      local itemId = GetItemLinkItemId(ingredient.link)
      materials[itemId] = {
        link = SavedLink(ingredient.link, itemId), kind = ingredient.kind or "Base", amount = ingredient.total / pending,
      }
    end
  end
  Entries()[writ.uid] = {
    uid = writ.uid, link = writ.link, craft = writ.type, vouchers = writ.vouchers, character = CharacterId(),
    state = "accepting", acceptedAt = GetTimeStamp(), materials = materials,
  }
end

-- The quest that the most recent "accepting" writ of the same craft produced.
function MWC.Journal.OnQuestAdded(questIndex, questName)
  local info = MWC.Journal.MasterWritInfo(questIndex)
  if not info then return end
  local newest
  for _, entry in pairs(Entries()) do
    if entry.state == "accepting" and entry.character == CharacterId() and (not info.craft or entry.craft == info.craft)
        and (not newest or entry.acceptedAt >= newest.acceptedAt) then
      newest = entry
    end
  end
  if not newest then return end
  newest.state, newest.questIndex, newest.questName = "active", questIndex, questName
  LearnQuestName(questName, newest.craft)
end

-- Matched by journal slot and name; failing that (slots can move) by name and craft, since a craft can only
-- have one active master writ quest.
function MWC.Journal.OnQuestRemoved(isCompleted, questIndex, questName)
  local match, byCraft
  local crafts = MWC.sv.questCrafts and MWC.sv.questCrafts[questName] or {}
  for _, entry in pairs(Entries()) do
    if entry.state == "active" and entry.character == CharacterId() and entry.questName == questName then
      if entry.questIndex == questIndex then
        match = entry
      elseif crafts[entry.craft] then
        byCraft = entry
      end
    end
  end
  match = match or byCraft
  if not match then return false end
  match.state = isCompleted and "completed" or "abandoned"
  match.finishedAt = GetTimeStamp()
  return true
end

-- After a reload or login: active entries whose quest is gone, and acceptances that never produced a quest,
-- can't be told apart between handed in and abandoned, so they become "unknown" instead of a guess.
function MWC.Journal.Reconcile()
  local now = GetTimeStamp()
  for _, entry in pairs(Entries()) do
    if entry.character == CharacterId() then
      if entry.state == "active" and not IsCraftingQuest(entry.questIndex, entry.questName) then
        -- The slot may have moved: look for the same quest name elsewhere in the journal. After a switch of the
        -- client language the name differs: then the quest of the same craft (one per craft) is it, in its slot
        -- first.
        local found
        for questIndex = 1, MAX_JOURNAL_QUESTS do
          if IsCraftingQuest(questIndex, entry.questName) then
            found = questIndex
          end
        end
        if not found then
          local claimed = {}
          for _, other in pairs(Entries()) do
            if other ~= entry and other.state == "active" and other.character == CharacterId() and other.questIndex then
              claimed[other.questIndex] = true
            end
          end
          local function SameCraft(questIndex)
            local info = not claimed[questIndex] and MWC.Journal.MasterWritInfo(questIndex)
            return info and info.craft == entry.craft
          end
          if entry.questIndex and SameCraft(entry.questIndex) then
            found = entry.questIndex
          else
            for questIndex = 1, MAX_JOURNAL_QUESTS do
              if not found and SameCraft(questIndex) then
                found = questIndex
              end
            end
          end
        end
        if found then
          entry.questIndex, entry.questName = found, GetJournalQuestName(found)
        else
          entry.state = "unknown"
        end
      elseif entry.state == "accepting" then
        -- The quest may have arrived while the addon was reloading: bind it if one of this craft is open.
        local claimed = {}
        for _, other in pairs(Entries()) do
          if other.state == "active" and other.character == CharacterId() and other.questIndex then
            claimed[other.questIndex] = true
          end
        end
        for questIndex = 1, MAX_JOURNAL_QUESTS do
          local name = IsCraftingQuest(questIndex) and GetJournalQuestName(questIndex)
          local crafts = name and MWC.sv.questCrafts and MWC.sv.questCrafts[name]
          if entry.state == "accepting" and crafts and crafts[entry.craft] and not claimed[questIndex] then
            entry.state, entry.questIndex, entry.questName = "active", questIndex, name
          end
        end
        if entry.state == "accepting" and now - entry.acceptedAt > ACCEPT_TIMEOUT_S then
          entry.state = "unknown"
        end
      end
    end
  end
end

-- A writ still in the bags was not used after all (say, the quest journal was full): drop a pending or
-- unknown acceptance of it. Entries of writs really handed in or active are never touched here.
-- A just-used writ stays in the bag for a moment, so a fresh acceptance gets this long first.
local SETTLE_S = 10

function MWC.Journal.ForgetUnused(uidsInBags)
  local entries, now = Entries(), GetTimeStamp()
  for uid, entry in pairs(entries) do
    local stale = entry.state == "unknown" or (entry.state == "accepting" and now - entry.acceptedAt > SETTLE_S)
    if uidsInBags[uid] and entry.character == CharacterId() and stale then
      entries[uid] = nil
    end
  end
end

-- Writ records (like Writs.Scan's, without a bag) for this character's entries, with their state.
function MWC.Journal.Writs()
  local writs = {}
  for _, entry in pairs(Entries()) do
    if entry.character == CharacterId() then
      local writ = MWC.Writs.FromLink(entry.link, entry.uid)
      if writ then
        writ.state = entry.state == "accepting" and "active" or entry.state
        table.insert(writs, writ)
      end
    end
  end
  return writs
end

-- Crafts that have an active master writ quest: this character's journal entries, plus crafting quests in
-- the quest journal that the addon didn't start but whose name it has learned. Also the number of active
-- crafting quests and how many of them belong to no known craft.
function MWC.Journal.ActiveCrafts()
  local crafts, claimed = {}, {}
  for _, entry in pairs(Entries()) do
    if (entry.state == "active" or entry.state == "accepting") and entry.character == CharacterId() then
      crafts[entry.craft] = true
      if entry.questIndex then
        claimed[entry.questIndex] = true
      end
    end
  end
  local count, unknown = 0, 0
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    if IsCraftingQuest(questIndex) then
      count = count + 1
      local info = not claimed[questIndex] and MWC.Journal.MasterWritInfo(questIndex)
      if info and info.craft then
        crafts[info.craft] = true
      elseif not claimed[questIndex] then
        local known = MWC.sv.questCrafts and MWC.sv.questCrafts[GetJournalQuestName(questIndex)]
        if known then
          for craft in pairs(known) do
            crafts[craft] = true
          end
        else
          unknown = unknown + 1
        end
      end
    end
  end
  return crafts, count, unknown
end

-- Importing quests the addon didn't start ---------------------------------------------------------------
-- A crafting quest started by hand (writ used from the inventory) has no journal entry. Its task text names
-- the same things as the writ's text ("Craft a Damage Health Poison IX ... Ravage Health, Ravage Magicka ..."),
-- so it is matched against the writs the addon sees: the writ whose every significant word appears in the
-- quest, with the most such words, is the one. Without a matching writ nearby it can't be imported.
local FILLER_WORDS = {}
for word in zo_strlower(L.IMPORT_FILLER_WORDS or ""):gmatch("[^%s]+") do
  FILLER_WORDS[word] = true
end

local function Words(text)
  local words = {}
  for word in zo_strlower(text or ""):gsub("%^%a+", ""):gmatch("[%w'\128-\255]+") do
    if not FILLER_WORDS[word] then
      words[word] = true
    end
  end
  return words
end

local function QuestText(questIndex)
  local _, _, stepText = GetJournalQuestInfo(questIndex)
  local parts = { stepText or "" }
  for condition = 1, GetJournalQuestNumConditions(questIndex, QUEST_MAIN_STEP_INDEX or 1) do
    table.insert(parts, (GetJournalQuestConditionInfo(questIndex, QUEST_MAIN_STEP_INDEX or 1, condition)))
  end
  return table.concat(parts, " ")
end

-- Alchemy quests can be rebuilt without a writ nearby: the game writes a writ's text from its fields, so the
-- trait names are learned by having it describe one effect at a time, the quest's traits are read in the
-- order its text lists them, and the rebuilt writ is accepted only if its own text matches the quest's.
local ALCHEMY_WRIT_ITEM_ID = 119818
local POTION_SOLVENT, POISON_SOLVENT = 199, 239
local MAX_EFFECT_ID = 40
local traitIds

local function AlchemyWritLink(solvent, e1, e2, e3, reward)
  return string.format("|H0:item:%d:5:1:0:0:0:%d:%d:%d:%d:0:0:0:0:0:0:0:0:0:0:%d|h|h", ALCHEMY_WRIT_ITEM_ID,
    solvent, e1, e2 or 0, e3 or 0, reward or 0)
end

local function TraitIds()
  if traitIds then return traitIds end
  traitIds = {}
  for id = 1, MAX_EFFECT_ID do
    local text = GenerateMasterWritBaseText(AlchemyWritLink(POTION_SOLVENT, id)) or ""
    local name = text:match(":%s*([^:\n]+)%s*$")
    if name and name ~= "" then
      traitIds[zo_strlower(zo_strtrim(name))] = id
    end
  end
  return traitIds
end

local function RebuildAlchemyWrit(questIndex, questText, questWords)
  local text = zo_strlower(questText)
  -- Longest names first, so "Gradual Ravage Health" isn't also read as "Ravage Health".
  local names = {}
  for name in pairs(TraitIds()) do
    table.insert(names, name)
  end
  table.sort(names, function(a, b) return #a > #b end)
  local found, taken = {}, {}
  for _, name in ipairs(names) do
    local start = 1
    while true do
      local first, last = text:find(name, start, true)
      if not first then break end
      local free = true
      for i = first, last do
        if taken[i] then free = false end
      end
      if free then
        for i = first, last do taken[i] = true end
        table.insert(found, { at = first, id = TraitIds()[name] })
      end
      start = last + 1
    end
  end
  if #found < 2 or #found > 3 then return nil end
  table.sort(found, function(a, b) return a.at < b.at end)
  local solvent = text:find(zo_strlower(L.POISON_WORD or "poison"), 1, true) and POISON_SOLVENT or POTION_SOLVENT
  local link = AlchemyWritLink(solvent, found[1].id, found[2].id, found[3] and found[3].id,
    QuestVouchers(questIndex) * 10000)
  for word in pairs(Words(GenerateMasterWritBaseText(link))) do
    if not questWords[word] then return nil end
  end
  return link
end

-- Active crafting quests of this character with no journal entry.
function MWC.Journal.UntrackedQuests()
  local claimed = {}
  for _, entry in pairs(Entries()) do
    if (entry.state == "active" or entry.state == "accepting") and entry.character == CharacterId() and entry.questIndex then
      claimed[entry.questIndex] = true
    end
  end
  local quests = {}
  for questIndex = 1, MAX_JOURNAL_QUESTS do
    if IsCraftingQuest(questIndex) and not claimed[questIndex] then
      table.insert(quests, questIndex)
    end
  end
  return quests
end

-- Imports every untracked quest that matches exactly one writ group. Returns imported count and the names of
-- the quests that couldn't be matched.
-- Every writ the addon has seen, one link per task (kept per account): a quest whose writ was used by hand
-- is matched against these exactly, even when no writ of its kind is left.
function MWC.Journal.RememberWrit(writ)
  MWC.sv.seenWrits = MWC.sv.seenWrits or {}
  MWC.sv.seenWrits[writ.key] = writ.link
end

-- Writs that were never seen can still be rebuilt for provisioning and enchanting: candidates are the foods and
-- glyphs whose names appear in the quest, at every level and quality a writ can ask for; the match decides.
local WRIT_ITEM_ID = { provisioning = 119693, enchanting = 119564 }
local GLYPH_LEVELS, GLYPH_QUALITIES = { 207, 225 }, { 4, 5 }

local function WritLink(itemId, fields, reward)
  return string.format("|H0:item:%d:5:1:0:0:0:%d:%d:%d:%d:%d:%d:0:0:0:0:0:0:0:0:0:%d|h|h", itemId,
    fields[1] or 0, fields[2] or 0, fields[3] or 0, fields[4] or 0, fields[5] or 0, fields[6] or 0, reward or 0)
end

local function NameIn(text, itemId)
  local name = zo_strlower(zo_strformat("<<1>>", GetItemLinkName(MWC.LinkFromItemId(itemId))))
  return name ~= "" and text:find(name, 1, true) ~= nil
end

local function GeneratedCandidates(questIndex, questText, questWords)
  local text, reward = zo_strlower(questText), QuestVouchers(questIndex) * 10000
  local links = {}
  local alchemy = RebuildAlchemyWrit(questIndex, questText, questWords)
  if alchemy then
    table.insert(links, alchemy)
  end
  for itemId in pairs(MWC.Recipes.Build()) do
    if NameIn(text, itemId) then
      table.insert(links, WritLink(WRIT_ITEM_ID.provisioning, { itemId }, reward))
    end
  end
  for _, glyphId in ipairs(MWC.Enchanting.GlyphIds()) do
    if NameIn(text, glyphId) then
      for _, level in ipairs(GLYPH_LEVELS) do
        for _, quality in ipairs(GLYPH_QUALITIES) do
          table.insert(links, WritLink(WRIT_ITEM_ID.enchanting, { glyphId, level, quality }, reward))
        end
      end
    end
  end
  return links
end

-- The writ a master writ quest came from, built from the quest's own data (GetQuestConditionMasterWritInfo):
-- exact numbers, no text. Returns candidate links (alchemy: every order of its traits, the right one is found
-- by matching), or nothing for a quest without that data.
local QUEST_WRIT_ITEM = {
  blacksmithing = 119563, clothier = 119694, woodworking = 119681, jewelry = 153737,
  alchemy = 119818, enchanting = 119564, provisioning = 119693,
}
local SOLVENT_CODE = { [64501] = 199, [75365] = 239 } -- Lorkhan's Tears, Alkahest

local function QuestDataCandidates(questIndex)
  local info = MWC.Journal.MasterWritInfo(questIndex)
  local itemId = info and QUEST_WRIT_ITEM[info.craft]
  if not itemId then return {} end
  local reward = QuestVouchers(questIndex) * 10000
  if info.craft == "provisioning" then
    return { WritLink(itemId, { info.itemId }, reward) }
  elseif info.craft == "enchanting" then
    return { WritLink(itemId, { info.itemId, info.materialItemId, info.quality }, reward) }
  elseif info.craft == "alchemy" then
    local solvent, traits = SOLVENT_CODE[info.materialItemId], tonumber(info.alchemyTraits) or 0
    if not solvent or traits == 0 then return {} end
    local effects = {}
    for _, effect in ipairs({ traits % 256, math.floor(traits / 256) % 256, math.floor(traits / 65536) % 256 }) do
      if effect > 0 then table.insert(effects, effect) end
    end
    local links = {}
    for _, order in ipairs(MWC.Alchemy.Permutations(effects)) do
      table.insert(links, WritLink(itemId, { solvent, order[1], order[2], order[3] }, reward))
    end
    return links
  end
  local material = MWC.Gear.MaterialCodeOf(info.materialItemId)
  if not material then return {} end
  return { WritLink(itemId, { info.templateId, material, info.quality, info.setId, info.traitType, info.styleId }, reward) }
end

-- How well a writ's text fits the quest's: the number of its significant words, or nil if any is missing.
local function Fit(link, questWords)
  local count = 0
  for word in pairs(Words(GenerateMasterWritBaseText(link))) do
    if not questWords[word] then return nil end
    count = count + 1
  end
  return count > 0 and count or nil
end

-- Imports every untracked quest that matches exactly one writ among the writs at hand, every writ ever seen
-- and rebuilt ones. When the writ's kind is at hand, its materials are recorded too. Returns the imported
-- count and the quests that couldn't be matched.
function MWC.Journal.ImportQuests(groups)
  local imported, unmatched = 0, {}
  local groupByKey = {}
  for _, group in ipairs(groups) do
    groupByKey[group.key] = group
  end
  for _, questIndex in ipairs(MWC.Journal.UntrackedQuests()) do
    local questText = QuestText(questIndex)
    local questWords = Words(questText)
    local function Best(links)
      local best, bestCount, tie = nil, 0, false
      for _, link in ipairs(links) do
        local count = Fit(link, questWords)
        if count and count > bestCount then
          best, bestCount, tie = link, count, false
        elseif count and count == bestCount and link ~= best then
          tie = true
        end
      end
      return not tie and best or nil
    end
    -- All sources compete at once: the fullest match wins, so a writ whose words are only part of the task
    -- can't win over the complete one from another source.
    local links, listed = {}, {}
    local function Add(link)
      if link and not listed[link] then
        listed[link] = true
        table.insert(links, link)
      end
    end
    for _, group in ipairs(groups) do
      Add(group.link)
    end
    for _, link in pairs(MWC.sv.seenWrits or {}) do
      Add(link)
    end
    for _, link in ipairs(GeneratedCandidates(questIndex, questText, questWords)) do
      Add(link)
    end
    -- First the quest's own data: a writ kind at hand with exactly that key, or the one its text confirms.
    local link
    local fromData = QuestDataCandidates(questIndex)
    for _, candidate in ipairs(fromData) do
      local writ = MWC.Writs.FromLink(candidate, "")
      if writ and (groupByKey[writ.key] or (not link and MWC.sv.seenWrits and MWC.sv.seenWrits[writ.key])) then
        link = candidate
      end
    end
    -- The quest's own data is exact, so its writ stands even when the texts can't confirm it: other languages
    -- word the task differently, and on the delivery step the quest's text no longer names the item.
    link = link or Best(fromData) or Best(links) or fromData[1]
    local writ = link and MWC.Writs.FromLink(link, string.format("quest:%s:%d:%d", CharacterId(), questIndex, GetTimeStamp()))
    local questName = GetJournalQuestName(questIndex)
    if writ then
      local group = groupByKey[writ.key]
      if group then
        MWC.Journal.RecordAccepted(writ, group)
      else
        Entries()[writ.uid] = {
          uid = writ.uid, link = writ.link, craft = writ.type, vouchers = writ.vouchers, character = CharacterId(),
          acceptedAt = GetTimeStamp(), materials = {},
        }
      end
      local entry = Entries()[writ.uid]
      entry.state, entry.questIndex, entry.questName, entry.imported = "active", questIndex, questName, true
      LearnQuestName(questName, writ.type)
      imported = imported + 1
    else
      table.insert(unmatched, string.format("%s (%s)", questName, zo_strtrim(questText)))
    end
  end
  return imported, unmatched
end

-- This character's writ quests the addon knows are open (started, not handed in yet).
function MWC.Journal.OpenCount()
  local count = 0
  for _, entry in pairs(Entries()) do
    if (entry.state == "active" or entry.state == "accepting") and entry.character == CharacterId() then
      count = count + 1
    end
  end
  return count
end

-- Session figures from handed-in writs: count, vouchers, and materials per item id.
-- crafts (optional): only writs of these crafts.
function MWC.Journal.Completed(crafts)
  local count, vouchers, materials = 0, 0, {}
  for _, entry in pairs(Entries()) do
    if entry.state == "completed" and entry.character == CharacterId() and (not crafts or crafts[entry.craft]) then
      count = count + 1
      vouchers = vouchers + (entry.vouchers or 0)
      for id, material in pairs(entry.materials or {}) do
        local total = materials[id]
          or { link = MaterialLink(material, id), kind = material.kind, craft = entry.craft, amount = 0 }
        total.amount = total.amount + material.amount
        materials[id] = total
      end
    end
  end
  return count, vouchers, materials
end
