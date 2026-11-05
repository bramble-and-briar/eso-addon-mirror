local C = CrownCrateCodex

function C:LegacyFingerprint(opening)
    local parts = { tostring(opening.timestamp), tostring(opening.crateId) }
    for index, reward in ipairs(opening.rewards) do
        if not reward.referenceId then return nil end
        local kind
        if reward.productType == MARKET_PRODUCT_TYPE_ITEM then kind = "i"
        elseif reward.productType == MARKET_PRODUCT_TYPE_COLLECTIBLE then kind = "c"
        else return nil end
        parts[#parts + 1] = index .. (reward.bonus and "=" or "-") .. kind .. reward.stack .. "x" .. reward.referenceId
    end
    return table.concat(parts, ",") .. "]"
end

function C:ParseLegacy(raw)
    if type(raw) ~= "string" then return nil, "Missing record" end
    local timestamp, crateId, payload = string.match(raw, "^(%d+),(%d+),(.+)%]$")
    timestamp, crateId = tonumber(timestamp), tonumber(crateId)
    if not timestamp or not crateId or crateId < 1 then return nil, "Invalid header" end
    local opening = { timestamp = timestamp, crateId = crateId, rewards = {}, source = "tracker", legacyRaw = raw }
    for token in string.gmatch(payload .. ",", "(.-),") do
        local index, bonus, kind, stack, identity = string.match(token, "^(%d+)([-=])([ic?])(%d+)x(.+)$")
        index, stack = tonumber(index), tonumber(stack)
        if not index or index ~= #opening.rewards + 1 or not stack or stack < 1 then return nil, "Invalid reward" end
        local referenceId = tonumber(identity)
        if kind ~= "?" and (not referenceId or referenceId < 1) then return nil, "Invalid reward identity" end
        local reward = { name = "Unresolved reward " .. identity, stack = stack, bonus = bonus == "=", tier = 0,
            referenceId = referenceId, gems = nil, typeText = "", link = "", legacyToken = token }
        if kind == "i" then
            reward.productType = MARKET_PRODUCT_TYPE_ITEM
            reward.link = "|H1:item:" .. identity .. ":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
        elseif kind == "c" then
            reward.productType = MARKET_PRODUCT_TYPE_COLLECTIBLE
            reward.link = "|H1:collectible:" .. identity .. "|h|h"
        else
            reward.productType = "legacy-unknown"
            reward.referenceId = identity
        end
        self:EnrichReward(reward)
        opening.rewards[#opening.rewards + 1] = reward
    end
    if #opening.rewards == 0 then return nil, "No rewards" end
    return opening
end

function C:ImportLegacy(records, matchPending)
    local report = { imported = 0, existing = 0, invalid = 0, rejected = 0 }
    if type(records) ~= "table" then return report end
    local existing, occurrences = {}, {}
    for _, opening in ipairs(self.db.history) do
        local raw = opening.trackerRaw or opening.legacyRaw or self:LegacyFingerprint(opening)
        if raw then existing[raw] = (existing[raw] or 0) + 1 end
    end
    self.db.importErrors = self.db.importErrors or {}
    local indices = {}
    for index in pairs(records) do if type(index) == "number" then indices[#indices + 1] = index end end
    table.sort(indices)
    for _, index in ipairs(indices) do
        local record = records[index]
        local raw = type(record) == "table" and record.Data or record
        local otherWorld=false
        if self.shared and type(raw)=="string" then
            local owner=self.shared.trackerOwners[raw]
            if not owner then self.shared.trackerOwners[raw]=self.world
            elseif owner~=self.world then otherWorld=true end
        end
        local timestamp=type(raw)=="string" and tonumber(raw:match("^(%d+),"))
        local approved=self.shared and self.shared.approvedLegacy and self.shared.approvedLegacy[raw]==self.world
        local alreadySaved=type(raw)=="string" and (existing[raw] or 0)>(occurrences[raw] or 0)
        if self.shared and self.shared.legacyConsentCutoff and timestamp and timestamp<self.shared.legacyConsentCutoff and not approved and not alreadySaved then
            report.needsConfirmation=(report.needsConfirmation or 0)+1
        elseif self.shared and self.shared.historyStartTimestamp and timestamp and timestamp<self.shared.historyStartTimestamp and not approved then
            report.beforeFreshStart=(report.beforeFreshStart or 0)+1
        elseif otherWorld then
            report.otherServer=(report.otherServer or 0)+1
        elseif matchPending and self.db.rejectedTrackerRecords[index] == raw and raw ~= nil then
            report.rejected = report.rejected + 1
        else
        if type(raw) == "string" then occurrences[raw] = (occurrences[raw] or 0) + 1 end
        local alreadyPresent = type(raw) == "string" and occurrences[raw] <= (existing[raw] or 0)
        local matched
        if matchPending and type(raw) == "string" then
            local timestamp, payload = string.match(raw, "^(%d+),(.+)$")
            for _, candidate in ipairs(self.pendingTracker or {}) do
                if not candidate.trackerRaw and candidate.legacyRaw then
                    local _, candidatePayload = string.match(candidate.legacyRaw, "^(%d+),(.+)$")
                    -- Only pair this event batch's live openings, one-to-one. Do not
                    -- apply a fuzzy timestamp rule to the historical archive.
                    if payload == candidatePayload and math.abs((tonumber(timestamp) or 0) - candidate.timestamp) <= 2
                        and (not alreadyPresent or candidate.legacyRaw == raw) then
                        candidate.trackerRaw = raw
                        if not alreadyPresent then
                            existing[candidate.legacyRaw] = math.max(0, (existing[candidate.legacyRaw] or 0) - 1)
                            existing[raw] = (existing[raw] or 0) + 1
                        end
                        matched = true
                        break
                    end
                end
            end
        end
        local opening, problem
        if not alreadyPresent and not matched then opening, problem = self:ParseLegacy(raw) end
        if alreadyPresent or matched then
            report.existing = report.existing + 1
        elseif not opening then
            report.invalid = report.invalid + 1
            self.db.importErrors[tostring(index)] = { raw = raw, problem = problem }
        else
                self:LearnCrate(opening.crateId)
                opening.id = self.db.nextId
                self.db.nextId = self.db.nextId + 1
                self.db.history[#self.db.history + 1] = opening
                report.imported = report.imported + 1
        end
        end
    end
    if report.imported > 0 then
        for id in pairs(self.db.crates) do self:BackfillLegacyTiers(id) end
        self:RebuildCatalog()
    end
    self.db.lastImport = report
    return report
end

function C:ReconcileTrackerResponses()
    local records = self:TrackerRecords()
    local responses = self.trackerResponses or {}
    -- The installed Tracker writes one row even for failed requests. When this
    -- batch has a one-to-one appended row/event correspondence, retain those
    -- failed rows in the source but explicitly exclude them from Codex.
    if records and records == self.lastTrackerTable and #records - (self.lastTrackerCount or 0) == #responses then
        for offset, success in ipairs(responses) do
            if not success then
                local index = self.lastTrackerCount + offset
                local record = records[index]
                if type(record) == "table" and type(record.Data) == "string" then self.db.rejectedTrackerRecords[index] = record.Data end
            end
        end
    end
    self.trackerResponses = {}
end

function C:ImportAvailable(force)
    local seed = { imported = 0, existing = 0, invalid = 0 }
    if not self.didSeedImport or force then seed = self:ImportLegacy(self.legacySeed); self.didSeedImport = true end
    local old = self:TrackerRecords()
    local report
    local count = type(old) == "table" and #old or 0
    local tail = count > 0 and old[count] and old[count].Data
    if not force and self.lastTrackerTable == old and self.lastTrackerCount == count and self.lastTrackerTail == tail then
        report = { imported = 0, existing = self.lastTrackerExisting or 0, invalid = self.lastTrackerInvalid or 0, rejected = self.lastTrackerRejected or 0 }
    else
        report = self:ImportLegacy(old, true)
        self.lastTrackerTable, self.lastTrackerCount, self.lastTrackerTail = old, count, tail
        self.lastTrackerExisting, self.lastTrackerInvalid = report.existing + report.imported, report.invalid
        self.lastTrackerRejected = report.rejected
    end
    report.imported = report.imported + seed.imported
    if type(old)~="table" then report.existing=seed.existing end
    report.invalid = report.invalid + seed.invalid
    report.timestamp = GetTimeStamp()
    report.trackerAvailable = type(old) == "table"
    self.pendingTracker = {}
    self.db.lastImport = report
    return report
end
