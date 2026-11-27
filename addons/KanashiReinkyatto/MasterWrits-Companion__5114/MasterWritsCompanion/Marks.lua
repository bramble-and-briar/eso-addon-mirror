local L = MWC.L
MWC.Marks = {}

local SKIP_MARK = "MWCSkipMark"
local READY_MARK = "MWCReadyMark"
local SKIP_TEXTURE = "EsoUI/Art/Buttons/decline_up.dds"
local READY_TEXTURE = "EsoUI/Art/Buttons/accept_up.dds"
local MARK_SIZE = 36
local ALL_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
-- Inventory events come in bursts; recompute readiness once after they calm down.
-- Item lists that use the standard inventory slot row (/esoui/ingame/inventory/inventoryslot.xml).
local HOOKED_LISTS = {
  "ZO_PlayerInventoryList",
  "ZO_PlayerBankBackpack",
  "ZO_GuildBankBackpack",
  "ZO_HouseBankBackpack",
  "ZO_SmithingTopLevelImprovementPanelInventoryBackpack",
  "ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack",
  "ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack",
}

local hookedLists = {}
local readyUids = {}

local function WritUid(bag, slot)
  if not bag or not slot then return nil end
  local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
  if link == "" then return nil end
  -- Holiday writs only while the Event checkbox shows them.
  if not MWC.Writs.TypeOf(link) and not (MWC.sv.showEvent and MWC.Writs.EventOf(link)) then return nil end
  return Id64ToString(GetItemUniqueId(bag, slot))
end

function MWC.Marks.IsExcludedSlot(bag, slot)
  local uid = WritUid(bag, slot)
  return uid ~= nil and MWC.Session.IsExcluded(uid)
end

local function IsReadySlot(bag, slot)
  local uid = WritUid(bag, slot)
  return uid ~= nil and readyUids[uid] == true
end

-- A writ is ready when enough crafted items exist for it. Active quests (session journal) claim their items
-- first, then backpack writs, then identical writs in the bank.
local function ComputeReady()
  local buckets = {}
  local potionIndex, glyphIndex, gearIndex
  local scanned, inBags, writs = MWC.Writs.Scan(ALL_BAGS), {}, {}
  for _, writ in ipairs(scanned) do
    inBags[writ.uid] = true
  end
  for _, writ in ipairs(MWC.Journal.Writs()) do
    if writ.state == "active" and not inBags[writ.uid] then
      table.insert(writs, writ)
    end
  end
  -- A holiday quest claims its items first too.
  if MWC.sv.showEvent then
    for _, writ in ipairs(MWC.Journal.EventQuestWrits()) do
      table.insert(writs, writ)
    end
  end
  for _, writ in ipairs(scanned) do
    table.insert(writs, writ)
  end
  for _, writ in ipairs(writs) do
    if not MWC.Session.IsExcluded(writ.uid) then
      local key, count, perWrit
      if writ.foodItemId then
        key = "food:" .. writ.foodItemId
        count = function() return (MWC.Plan.CountItem(writ.foodItemId)) end
        perWrit = writ.eventCount or MWC.Plan.ITEMS_PER_PROVISIONING_WRIT
      elseif writ.type == "alchemy" then
        potionIndex = potionIndex or MWC.Alchemy.PotionIndex()
        local indexKey = MWC.Alchemy.IndexKey(MWC.Alchemy.IsPoison(writ.fields[1]), MWC.Alchemy.EffectKeyOf(writ),
          MWC.Alchemy.ExpectedName(writ, potionIndex))
        key = "alchemy:" .. indexKey
        count = function()
          potionIndex = potionIndex or MWC.Alchemy.PotionIndex()
          local entry = potionIndex[indexKey]
          return entry and (entry.bag + entry.bank) or 0
        end
        perWrit = MWC.Alchemy.ITEMS_PER_WRIT
      elseif writ.type == "enchanting" then
        local spec = MWC.Enchanting.Recipe(writ)
        if spec then
          key = "enchanting:" .. spec.indexKey
          count = function()
            glyphIndex = glyphIndex or MWC.Enchanting.GlyphIndex()
            local entry = glyphIndex[spec.indexKey]
            return entry and (entry.bag + entry.bank) or 0
          end
          perWrit = MWC.Enchanting.ITEMS_PER_WRIT
        end
      else
        local indexKey = MWC.Gear.WritKey(writ)
        key = indexKey
        count = function()
          gearIndex = gearIndex or MWC.Gear.Index()
          local entry = gearIndex[indexKey]
          return entry and (entry.bag + entry.bank) or 0
        end
        perWrit = MWC.Gear.ITEMS_PER_WRIT
      end
      if key then
        local bucket = buckets[key] or { writs = {}, count = count, perWrit = perWrit }
        buckets[key] = bucket
        table.insert(bucket.writs, writ)
      end
    end
  end
  local ready = {}
  for _, bucket in pairs(buckets) do
    local covered = math.floor(bucket.count() / bucket.perWrit)
    for i = 1, math.min(#bucket.writs, covered) do
      ready[bucket.writs[i].uid] = true
    end
  end
  readyUids = ready
end

local function GetMark(button, name, texture, size, point, r, g, b)
  local mark = button:GetNamedChild(name)
  if not mark then
    mark = WINDOW_MANAGER:CreateControl(button:GetName() .. name, button, CT_TEXTURE)
    mark:SetTexture(texture)
    mark:SetColor(r, g, b, 1)
    mark:SetDimensions(size, size)
    mark:SetInheritScale(false)
    mark:SetAnchor(point, button, point, 0, 0)
    mark:SetDrawTier(DT_HIGH)
  end
  return mark
end

local function SetMark(button, name, visible, texture, size, point, r, g, b)
  local mark = button:GetNamedChild(name)
  if visible then
    GetMark(button, name, texture, size, point, r, g, b):SetHidden(false)
  elseif mark then
    mark:SetHidden(true)
  end
end

local function UpdateRowMarks(control, data)
  local button = control:GetNamedChild("Button")
  if not button then return end
  local bag, slot = data and data.bagId, data and data.slotIndex
  local skip = MWC.Marks.IsExcludedSlot(bag, slot)
  local ready = not skip and IsReadySlot(bag, slot)
  SetMark(button, SKIP_MARK, skip, SKIP_TEXTURE, MARK_SIZE, CENTER, 1, 0.15, 0.15)
  SetMark(button, READY_MARK, ready, READY_TEXTURE, MARK_SIZE, CENTER, 0.3, 1, 0.3)
end

function MWC.Marks.Refresh()
  MWC.Timed("bag marks", ComputeReady)
  for _, list in ipairs(hookedLists) do
    ZO_ScrollList_RefreshVisible(list)
  end
end


function MWC.Marks.Init()
  for _, name in ipairs(HOOKED_LISTS) do
    local list = _G[name]
    local dataType = list and ZO_ScrollList_GetDataTypeTable(list, 1)
    if dataType then
      SecurePostHook(dataType, "setupCallback", UpdateRowMarks)
      table.insert(hookedLists, list)
    end
  end

  ZO_PostHook(ItemTooltip, "SetBagItem", function(tooltip, bag, slot)
    if MWC.Marks.IsExcludedSlot(bag, slot) then
      tooltip:AddLine(L.TOOLTIP_PREFIX .. L.MARK_SKIP, "ZoFontGameBold", 1, 0.3, 0.3)
    elseif IsReadySlot(bag, slot) then
      tooltip:AddLine(L.TOOLTIP_PREFIX .. L.MARK_READY, "ZoFontGameBold", 0.3, 1, 0.3)
    end
  end)

  -- Not recomputed on every bag change (that scanned all three bags each time and made banking and trading
  -- stutter): only at load, when the addon's window opens, and after the addon changed something (crafting,
  -- banking, opening, starting and turning in quests, queueing). Marks follow the writ, not the slot, so moving
  -- items doesn't put them on the wrong one.
  MWC.Timed("bag marks", ComputeReady)
end
