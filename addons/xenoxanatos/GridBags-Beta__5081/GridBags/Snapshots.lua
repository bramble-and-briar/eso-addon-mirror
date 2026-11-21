GridBagsSnapshots = {}
local S = GridBagsSnapshots
local UPDATE = "GridBagsSnapshotUpdate"
local BANK_KEY = "@account-bank"

function S:ReadGold(bank)
    if not GetCurrencyAmount then return nil end
    return GetCurrencyAmount(CURT_MONEY, bank and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER)
end

local function CaptureBags(bags)
    local items, sources, capacity, used = {}, {}, 0, 0
    for _, bag in ipairs(bags) do
        capacity = capacity + GetBagUseableSize(bag)
        used = used + GetNumBagUsedSlots(bag)
        for slot = 0, GetBagSize(bag) - 1 do
            if GetItemId(bag, slot) ~= 0 then
                local icon, stack, _, usable, locked, _, _, _, quality = GetItemInfo(bag, slot)
                local _, maxStack = GetSlotStackSize(bag, slot)
                local displayName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemName(bag, slot))
                items[#items + 1] = { name = zo_strlower(displayName), displayName = displayName,
                    link = GetItemLink(bag, slot), icon = icon, stack = stack, usable = usable, locked = locked,
                    quality = quality, playerLocked = IsItemPlayerLocked(bag, slot), stolen = IsItemStolen(bag, slot),
                    junk = IsItemJunk(bag, slot), filters = { GetItemFilterTypeInfo(bag, slot) }, order = #items + 1,
                    equipSlot = bag == BAG_WORN and slot or nil,
                    uid = Id64ToString(GetItemUniqueId(bag, slot)), maxStack = maxStack,
                    bound = IsItemBound(bag, slot),
                    deconstruction = bag ~= BAG_WORN and GridBagsGearRouting:Observe(bag,slot,GetItemLink(bag,slot)) or nil }
                sources[#sources + 1] = { bag = bag, slot = slot }
            end
        end
    end
    local record = { items = items, capacity = capacity, used = used, updatedAt = GetTimeStamp() }
    GridBagsSnapshotFilters:Enrich(record, sources)
    return record
end

function S:CaptureBank()
    -- Never treat cached/closed-bank API data as a live observation.
    if not IsBankOpen() or GetBankingBag() ~= BAG_BANK then return end
    local record = CaptureBags({ BAG_BANK, BAG_SUBSCRIBER_BANK })
    record.name = "Account bank"
    record.gold = self:ReadGold(true)
    self.owner.saved.bankSnapshots[self.world] = record
end

function S:Initialize(owner)
    self.owner = owner
    self.characterId = GetCurrentCharacterId()
    self.world = GetWorldName()
    owner.saved.snapshots = owner.saved.snapshots or {}
    owner.saved.snapshots[self.world] = owner.saved.snapshots[self.world] or {}
    self.records = owner.saved.snapshots[self.world]
    owner.saved.bankSnapshots = owner.saved.bankSnapshots or {}
    self.ready = false
    for _, name in ipairs({ "EVENT_RECIPE_LEARNED", "EVENT_SKILL_POINTS_CHANGED", "EVENT_SKILL_RESPEC_RESULT", "EVENT_SKILL_RANK_UPDATE" }) do
      if _G[name] then
        EVENT_MANAGER:RegisterForEvent("GridBagsCraftingScan", _G[name], function()
            GridBagsCrafting.recipeCache = nil; GridBagsCrafting.skillFrame = nil; self:QueueCapture()
        end)
      end
    end
    if EVENT_MONEY_UPDATE then
        EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_MONEY_UPDATE, function()
            self:QueueCapture(); owner:QueueRefresh()
        end)
    end
    if EVENT_BANKED_MONEY_UPDATE then
        EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_BANKED_MONEY_UPDATE, function()
            self:CaptureBank(); owner:QueueRefresh()
        end)
    end
    EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_PLAYER_ACTIVATED, function()
        GridBagsCrafting.recipeCache = nil
        GridBagsCrafting.skillFrame = nil
        self.ready = true
        self.pending = false
        GridBagsSnapshotFilters.cache = {}
        self:Capture()
        owner:QueueRefresh()
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_PLAYER_DEACTIVATED, function()
        GridBagsSnapshotFilters.cache = {}
        self:Capture()
        self.ready = false
        self.pending = false
        EVENT_MANAGER:UnregisterForUpdate(UPDATE)
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bag)
        if bag == BAG_BACKPACK or bag == BAG_WORN then self:QueueCapture() end
        if bag == BAG_BANK or bag == BAG_SUBSCRIBER_BANK then self:CaptureBank() end
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_INVENTORY_FULL_UPDATE, function()
        self:QueueCapture(); self:CaptureBank()
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_OPEN_BANK, function()
        -- Observe after the native bank-open handlers populate their inventories.
        EVENT_MANAGER:RegisterForUpdate("GridBagsBankCapture", 100, function()
            EVENT_MANAGER:UnregisterForUpdate("GridBagsBankCapture")
            self:CaptureBank()
            owner:QueueRefresh()
        end)
    end)
    EVENT_MANAGER:RegisterForEvent("GridBagsSnapshots", EVENT_CLOSE_BANK, function()
        self:CaptureBank()
        EVENT_MANAGER:UnregisterForUpdate("GridBagsBankCapture")
    end)
end

function S:QueueCapture()
    if not self.ready then return end
    -- Coalesce changes, but do not restart the timer indefinitely during busy bags.
    if self.pending then return end
    self.pending = true
    EVENT_MANAGER:RegisterForUpdate(UPDATE, 2000, function()
        EVENT_MANAGER:UnregisterForUpdate(UPDATE)
        self.pending = false
        self:Capture()
    end)
end

function S:Capture()
    if not self.ready then return end
    local record = CaptureBags({ BAG_BACKPACK })
    record.name = zo_strformat(SI_UNIT_NAME, GetUnitName("player"))
    record.gold = self:ReadGold(false)
    -- Equipment is context for planning, never part of the transferable bag list.
    record.equipment = CaptureBags({ BAG_WORN })
    record.equipment.name = record.name .. " equipped"
    record.equipment.gold = record.gold
    record.professions = GridBagsSmartRouting:CaptureProfessions()
    record.craftingRecipes = GridBagsCrafting:CaptureRecipes()
    self.records[self.characterId] = record
end

function S:GetSelected(owner)
    -- The current character is ALWAYS read live, even if its record exists.
    if not owner.selectedCharacter or owner.selectedCharacter == self.characterId then return nil end
    if owner.selectedCharacter == BANK_KEY then return owner.saved.bankSnapshots[self.world] end
    local record = self.records[owner.selectedCharacter]
    if owner.equipmentView and record and record.equipment then return record.equipment end
    return record
end

function S:Select(owner, id, equipment)
    if id ~= self.characterId and not self.records[id] and not (id == BANK_KEY and owner.saved.bankSnapshots[self.world]) then return end
    if owner:IsBankScene() then id = self.characterId end
    ClearMenu()
    owner.selectedCharacter = id
    owner.equipmentView = equipment == true and id ~= self.characterId and id ~= BANK_KEY
    owner.backpack.scrollRow = 0
    owner.backpack.query = ""
    owner.backpack.search:SetText("")
    owner.backpack.filter = nil
    owner.backpack.snapshotSelection = nil
    owner:Refresh()
end

function S:ShowSelector(owner, control)
    ClearMenu()
    AddMenuItem(zo_strformat(SI_UNIT_NAME, GetUnitName("player")) .. " (LIVE)", function()
        self:Select(owner, self.characterId)
    end)
    if owner.saved.bankSnapshots[self.world] then
        AddMenuItem("Account bank (snapshot)", function() self:Select(owner, BANK_KEY) end)
    end
    local entries = {}
    for id, record in pairs(self.records) do
        if id ~= self.characterId then entries[#entries + 1] = { id = id, record = record } end
    end
    table.sort(entries, function(a, b) return a.record.name < b.record.name end)
    for _, entry in ipairs(entries) do
        local id = entry.id
        AddMenuItem(entry.record.name .. " (snapshot)", function() self:Select(owner, id) end)
        if entry.record.equipment then
            AddMenuItem(entry.record.name .. " (equipped snapshot)", function() self:Select(owner, id, true) end)
        end
    end
    ShowMenu(control)
end
