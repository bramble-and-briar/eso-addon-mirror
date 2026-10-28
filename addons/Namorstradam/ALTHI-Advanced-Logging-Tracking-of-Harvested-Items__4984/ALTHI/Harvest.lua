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
    self:RememberCreatureInteraction()
    self:RememberLootInteraction()
    local _, name, blocked = GetGameCameraInteractableActionInfo()
    if not blocked and worldNodes[TargetName(name)] then
        self.harvestEvidence = { at = self.Now(), name = name, worldNode = true }
        self.lootContext = nil
    end
end
function A:ClearHarvest()
    self.harvestEvidence, self.lootContext = nil, nil
    self.containerLoot = nil
end
function A:BlockTransfer()
    self:ClearHarvest()
    self.observedLoot = nil
    self.creatureAttempt = nil
    self.interactionAttempt = nil
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
        if targetType == INTERACT_TARGET_TYPE_OBJECT and name and name ~= "" and GetInteractionType() == INTERACTION_LOOT
            and not (self.recentItemUseUntil and self.Now() < self.recentItemUseUntil) then
            self.containerLoot = { name = name, untilTime = self.Now() + 120 }
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
    if self.containerLoot then self.containerLoot.untilTime = self.Now() + 0.25 end
end
function A:GatheredContainerSource(id)
    local item = self.db.catalog[id]
    if not item or item.category == 'fishing' and item.itemType ~= ITEMTYPE_LURE then return end
    if self.transferUntil and self.Now() < self.transferUntil then return end
    if self.recentItemUseUntil and self.Now() < self.recentItemUseUntil then return end
    if self.filletObservation or self.fishingActive then return end
    local interaction = GetInteractionType()
    if interaction ~= INTERACTION_NONE and interaction ~= INTERACTION_LOOT then return end
    local name, kind = GetLootTargetInfo()
    if kind == INTERACT_TARGET_TYPE_OBJECT and name and name ~= '' and interaction == INTERACTION_LOOT then return name end
    local context = self.containerLoot
    if context and context.untilTime >= self.Now() then
        if kind == INTERACT_TARGET_TYPE_OBJECT and TargetName(name) == TargetName(context.name)
            or kind == INTERACT_TARGET_TYPE_NONE and (not name or name == '') then return context.name end
    end
end
-- Autoloot may clear both the target and reticle unit before LOOT_RECEIVED.
-- Capture only an actual player interaction, using ESO's localized action IDs.
function A:RememberLootInteraction()
    self.interactionAttempt = nil
    if self.transferUntil and self.Now() < self.transferUntil then return end
    if self.InventoryOpen and self:InventoryOpen() then return end
    if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode() then return end
    if self.recentItemUseUntil and self.Now() < self.recentItemUseUntil then return end
    local action, name, blocked, _, extra = GetGameCameraInteractableActionInfo()
    if blocked or not action or not name or name == '' or extra == ADDITIONAL_INTERACT_INFO_FISHING_NODE then return end
    local allowed = false
    for _, index in ipairs({1, 7, 19, 20}) do
        local key = _G['SI_GAMECAMERAACTIONTYPE' .. index]
        if key and GetString and TargetName(action) == TargetName(GetString(key)) then allowed = true; break end
    end
    -- Some harvesting sub-actions (for example catching insects) have native
    -- localized labels outside the generic camera-action enum. An available,
    -- non-quest world interaction is additional proof, but menus/talking/item
    -- use and fishing must never authorize this fallback.
    if not allowed and GetGameCameraInteractableInfo then
        local exists, available, quest = GetGameCameraInteractableInfo()
        local excluded = false
        for _, index in ipairs({2, 5, 6, 10, 15, 16, 17, 18, 21, 23, 24, 25, 26, 27}) do
            local key = _G['SI_GAMECAMERAACTIONTYPE' .. index]
            if key and GetString and TargetName(action) == TargetName(GetString(key)) then excluded = true; break end
        end
        allowed = exists and available and not quest and not excluded
    end
    if not allowed then return end
    local creature = self:ReticleCreatureName() or IsGameCameraInteractableUnitMonster and IsGameCameraInteractableUnitMonster()
    self.interactionAttempt = { name = name, kind = creature and 'creature' or 'world', untilTime = self.Now() + 2 }
end
function A:GatheredInteractionSource()
    local attempt = self.interactionAttempt
    if not attempt or attempt.untilTime < self.Now() then return end
    if self.transferUntil and self.Now() < self.transferUntil then return end
    if self.recentItemUseUntil and self.Now() < self.recentItemUseUntil then return end
    if self.filletObservation or self.fishingActive or self.InventoryOpen and self:InventoryOpen() then return end
    local interaction = GetInteractionType()
    if interaction ~= INTERACTION_NONE and interaction ~= INTERACTION_LOOT then return end
    if interaction == INTERACTION_NONE and SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode() then return end
    local name, kind = GetLootTargetInfo()
    if kind ~= INTERACT_TARGET_TYPE_NONE and kind ~= INTERACT_TARGET_TYPE_OBJECT
        and kind ~= INTERACT_TARGET_TYPE_CLIENT_CHARACTER and kind ~= INTERACT_TARGET_TYPE_AOE_LOOT then return end
    if name and name ~= '' and TargetName(name) ~= TargetName(attempt.name) then return end
    local _, camera = GetGameCameraInteractableActionInfo()
    if (not name or name == '') and camera and camera ~= '' and TargetName(camera) ~= TargetName(attempt.name) then return end
    return attempt.name, attempt.kind
end
function A:LogDecision(id, count, accepted, reason)
    local log = self.db.diagnostics
    log[#log + 1] = { time = GetTimeStamp(), id = id, count = count, accepted = accepted, reason = reason }
    local _,targetType=GetLootTargetInfo()
    local entry=log[#log]
    entry.interaction=GetInteractionType(); entry.targetType=targetType
    entry.creatureContext=self.observedLoot and self.observedLoot.untilTime>=self.Now() or false
    local action, camera, _, _, extra = GetGameCameraInteractableActionInfo()
    entry.cameraAction, entry.cameraName, entry.cameraExtra = action, camera, extra
    entry.interactionContext = self.interactionAttempt and self.interactionAttempt.untilTime >= self.Now() or false
    if #log > 80 then table.remove(log, 1) end
    if self.db.debug then
        local entry = self.db.catalog[id]
        self:Say(string.format("%s | ID %d | +%d | %s", entry and entry.name or L("MATERIAL"), id, count, reason .. string.format(" [interaction=%s target=%s context=%s]",tostring(GetInteractionType()),tostring(targetType),tostring(log[#log].creatureContext))))
    end
end
function A:ReticleCreatureName()
    if not DoesUnitExist or not IsUnitDead or not GetUnitName then return end
    if not DoesUnitExist('reticleover') or not IsUnitDead('reticleover') then return end
    local name=GetUnitName('reticleover')
    local _,cameraName=GetGameCameraInteractableActionInfo()
    if name and name~='' and cameraName and TargetName(name)==TargetName(cameraName) then return name end
end
function A:RememberCreatureInteraction()
    if self.transferUntil and self.Now()<self.transferUntil then return end
    local name=self:ReticleCreatureName()
    if name then self.creatureAttempt={name=name,untilTime=self.Now()+2} end
end
function A:AutolootCreatureName()
    if self.transferUntil and self.Now()<self.transferUntil then return end
    if self.recentItemUseUntil and self.Now()<self.recentItemUseUntil then return end
    if self.filletObservation or self.fishingActive then return end
    if self.InventoryOpen and self:InventoryOpen() then return end
    local interaction=GetInteractionType()
    if interaction~=INTERACTION_NONE and interaction~=INTERACTION_LOOT then return end
    local name,kind=GetLootTargetInfo()
    if kind~=INTERACT_TARGET_TYPE_NONE or name and name~='' then return end
    if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode() and interaction~=INTERACTION_LOOT then return end
    local current=self:ReticleCreatureName()
    if current then return current end
    local attempt=self.creatureAttempt
    if attempt and attempt.untilTime>=self.Now() then
        local _,cameraName=GetGameCameraInteractableActionInfo()
        if not cameraName or cameraName=='' or TargetName(cameraName)==TargetName(attempt.name) then return attempt.name end
    end
end
function A:Loot(_, _, link, count, _, lootType, isSelf, _, _, itemId)
    if not isSelf or lootType ~= LOOT_TYPE_ITEM then return end
    count = tonumber(count) or 0
    if count <= 0 or count ~= math.floor(count) then return end
    link=self:LootItemLink(link,itemId)
    local id = self:Observe(link)
    if not id then
        local rawId = self.ValidId(GetItemLinkItemId(link))
        if rawId and self:HarvestSource() then
            self:LogDecision(rawId, count, false, L("UNSUPPORTED_ITEM_TYPE") .. tostring(GetItemLinkItemType(link)))
        end
        return
    end
    local confirmedCreature = false
    if not self.transferUntil or self.Now() >= self.transferUntil then
        local name, targetType = GetLootTargetInfo()
        local context = self.observedLoot
        local body = targetType == INTERACT_TARGET_TYPE_CLIENT_CHARACTER or targetType == INTERACT_TARGET_TYPE_AOE_LOOT
        local remembered = context and context.untilTime >= self.Now()
        local clearedTarget = targetType == INTERACT_TARGET_TYPE_NONE and (not name or name == "")
        if body and GetInteractionType() == INTERACTION_LOOT
            or remembered and (body and TargetName(context.name) == TargetName(name) or clearedTarget) then
            self:RecordSource(id, "creature", body and name or context.name)
            confirmedCreature = true
        end
    end
    local valid, reason = self:HarvestSource()
    local attemptName, attemptKind = self:GatheredInteractionSource()
    if not confirmedCreature then
        local creature=self:AutolootCreatureName() or attemptKind == 'creature' and attemptName
        if creature then self:RecordSource(id,'creature',creature); confirmedCreature=true end
    end
    if confirmedCreature then valid, reason = true, L("ANIMAL_NPC_LOOT") end
    local container = not valid and (self:GatheredContainerSource(id) or attemptKind == 'world' and attemptName)
    if container then valid, reason = true, L('WORLD_OBJECTS') end
    if not valid then self:LogDecision(id, count, false, reason); return end
    -- A real gathered rare material merits a notice even if its session filter
    -- is disabled. Inventory transfers and mere catalog/stock reads never do.
    self:NotifyRare(link,count)
    local sourceKey = confirmedCreature and "creature" or (container or self.harvestEvidence and self.harvestEvidence.worldNode) and "world" or "normal"
    if not confirmedCreature then self:RecordSource(id, sourceKey, container or self.harvestEvidence and self.harvestEvidence.name) end
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
