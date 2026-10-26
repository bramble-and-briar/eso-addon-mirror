local A = ALTHarvestItems
local function L(key) return A:T(key) end
-- World-node labels from HarvestMap's published node table. These identify the
-- interaction source only; material identity and selection remain numeric IDs.
local worldNodes = {
    ["psijic portal"] = true, ["psijik-portal"] = true, ["portail psijique"] = true,
    ["giant clam"] = true, ["riesenmuschel"] = true, ["palourde géante"] = true,
    ["heavy sack"] = true, ["schwerer sack"] = true, ["sac lourd"] = true,
    ["heavy crate"] = true,
    ["тяжелый мешок"] = true, -- Published HarvestMap Russian label.
}
local function MailKey(mailId) return Id64ToString and Id64ToString(mailId) or tostring(mailId) end
local function TargetName(name)
    return zo_strlower(zo_strformat("<<z:1>>", name or ""))
end
function A:MarkWorldNode()
    self:ClearHarvest()
    if self.transferUntil and self.Now() < self.transferUntil then return end
    local _, name, blocked = GetGameCameraInteractableActionInfo()
    if not blocked and worldNodes[TargetName(name)] then
        self.harvestEvidence = { at = self.Now(), name = name, worldNode = true }
        self.lootContext = nil
    end
end
function A:ClearHarvest()
    self.harvestEvidence, self.lootContext = nil, nil
end
function A:BlockTransfer()
    self:ClearHarvest()
    self.observedLoot = nil
    self.transferUntil = self.Now() + 2
end
-- ESO has no dedicated harvest-begin event. Observe the interaction, not bag deltas.
function A:PollInteraction()
    self:UpdateWindowVisibility()
    if self.transferUntil and self.Now() < self.transferUntil then self:ClearHarvest(); return end
    local current = GetInteractionType()
    if current == INTERACTION_HARVEST then
        self.observedLoot = nil
        local _, name = GetGameCameraInteractableActionInfo()
        self.harvestEvidence = { at = self.Now(), name = name or "" }
    elseif current ~= INTERACTION_NONE and current ~= INTERACTION_LOOT then
        self:ClearHarvest()
    end
end
function A:HarvestSource()
    self:PollInteraction()
    local evidence = self.harvestEvidence
    if not evidence then return false, L("NO_HARVESTING_INTERACTION_DETECTED") end
    if evidence.closedUntil and self.Now() > evidence.closedUntil then
        self:ClearHarvest(); return false, L("HARVEST_LOOT_WINDOW_ALREADY_CLOSED")
    end
    local name, targetType = GetLootTargetInfo()
    if targetType == INTERACT_TARGET_TYPE_CLIENT_CHARACTER or targetType == INTERACT_TARGET_TYPE_AOE_LOOT then
        self:ClearHarvest()
        return false, L("CORPSE_AREA_LOOT_EXCLUDED")
    end
    if name and name ~= "" and evidence.name ~= "" and TargetName(name) ~= TargetName(evidence.name) then
        self:ClearHarvest()
        return false, L("DIFFERENT_LOOT_TARGET")
    end
    local context = self.lootContext
    if context and context.untilTime >= self.Now() then return true, L("HARVEST_LOOT_WINDOW") end
    if self.Now() - evidence.at <= (evidence.worldNode and 5 or 1.5) then
        return true, evidence.worldNode and L("CONFIRMED_WORLD_RESOURCE_NODE") or L("HARVEST_INTERACTION")
    end
    return false, L("HARVEST_EVIDENCE_EXPIRED")
end
function A:LootOpened()
    if not self.transferUntil or self.Now() >= self.transferUntil then
        local name, targetType = GetLootTargetInfo()
        if targetType == INTERACT_TARGET_TYPE_CLIENT_CHARACTER or targetType == INTERACT_TARGET_TYPE_AOE_LOOT then
            self.observedLoot = { name = name, untilTime = self.Now() + 120 }
        end
    end
    local observed = self.observedLoot
    local valid = self:HarvestSource()
    self.observedLoot = observed -- HarvestSource rejects bodies without discarding observation context.
    if valid then
        self.lootContext = { untilTime = self.Now() + 120 }
    end
end
function A:LootClosed()
    if self.observedLoot then self.observedLoot.untilTime = self.Now() + 0.25 end
    if self.lootContext then self.lootContext.untilTime = self.Now() + 0.25 end
    if self.harvestEvidence then self.harvestEvidence.closedUntil = self.Now() + 0.25 end
end
function A:LogDecision(id, count, accepted, reason)
    local log = self.db.diagnostics
    log[#log + 1] = { time = GetTimeStamp(), id = id, count = count, accepted = accepted, reason = reason }
    if #log > 80 then table.remove(log, 1) end
    if self.db.debug then
        local entry = self.db.catalog[id]
        self:Say(string.format("%s | ID %d | +%d | %s", entry and entry.name or L("MATERIAL"), id, count, reason))
    end
end
function A:Loot(_, _, link, count, _, lootType, isSelf)
    if not isSelf or lootType ~= LOOT_TYPE_ITEM then return end
    count = tonumber(count) or 0
    if count <= 0 or count ~= math.floor(count) then return end
    local id = self:Observe(link)
    if not id then
        local rawId = self.ValidId(GetItemLinkItemId(link))
        if rawId and self:HarvestSource() then
            self:LogDecision(rawId, count, false, L("UNSUPPORTED_ITEM_TYPE") .. tostring(GetItemLinkItemType(link)))
        end
        return
    end
    if not self.transferUntil or self.Now() >= self.transferUntil then
        local name, targetType = GetLootTargetInfo()
        local context = self.observedLoot
        local body = targetType == INTERACT_TARGET_TYPE_CLIENT_CHARACTER or targetType == INTERACT_TARGET_TYPE_AOE_LOOT
        if body and (GetInteractionType() == INTERACTION_LOOT or context and context.untilTime >= self.Now() and context.name == name) then
            self:RecordSource(id, "creature", name)
        end
    end
    local valid, reason = self:HarvestSource()
    if not valid then self:LogDecision(id, count, false, reason); return end
    -- A real gathered rare material merits a notice even if its session filter
    -- is disabled. Inventory transfers and mere catalog/stock reads never do.
    self:NotifyRare(link,count)
    local sourceKey = self.harvestEvidence and self.harvestEvidence.worldNode and "world" or "normal"
    self:RecordSource(id, sourceKey, self.harvestEvidence and self.harvestEvidence.name)
    local sources = self.db.catalog[id].sources
    sources[sourceKey] = true
    if not self:IsEnabled(id) then self:LogDecision(id, count, false, L("NOT_ENABLED_IN_FILTER_LIST")); return end
    local accepted = self:AcceptedHarvest(id, count)
    self:LogDecision(id, count, accepted, accepted and reason or L("AUTOMATIC_START_RESUME_DISABLED"))
end

function A:SnapshotMail(mailId)
    if not GetMailItemInfo or not GetAttachedItemLink then return end
    local _, _, _, _, _, _, _, _, count = GetMailItemInfo(mailId)
    local ids = {}
    for index = 1, count or 0 do
        local id = self:Observe(GetAttachedItemLink(mailId, index, LINK_STYLE_DEFAULT))
        if id then ids[#ids + 1] = id end
    end
    self.pendingMail = self.pendingMail or {}
    for key, snapshot in pairs(self.pendingMail) do if self.Now() - snapshot.at > 120 then self.pendingMail[key] = nil end end
    self.pendingMail[MailKey(mailId)] = { ids = ids, at = self.Now() }
    self:BlockTransfer()
end
function A:MailReceived(mailId)
    self:BlockTransfer()
    local key = MailKey(mailId)
    local snapshot = self.pendingMail and self.pendingMail[key]
    if snapshot then
        self.pendingMail[key] = nil
        if self.Now() - snapshot.at <= 120 then
            for _, id in ipairs(snapshot.ids) do self:RecordSource(id, "mail") end
        end
    end
end
