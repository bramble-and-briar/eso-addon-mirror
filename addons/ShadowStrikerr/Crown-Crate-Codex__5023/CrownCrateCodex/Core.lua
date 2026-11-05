CrownCrateCodex = { name = "CrownCrateCodex", version = "0.12.6" }
local C = CrownCrateCodex
C.L = function(text) return text end -- English fallback for standalone core consumers.
C.Lower = function(text) return (zo_strlower or string.lower)(text) end

-- CrownCrateData is owned by Crown Crate Tracker by Faunter, not Crown Crate Codex.
-- Read it at operation time: do not create, rename, or cache its global at load.
function C:TrackerRecords()
    local trackerData = CrownCrateData
    local crates = trackerData and trackerData.Crates
    return crates and crates["Crate info"]
end
function C:InitializeServerStore(store,shared,world,root,accountName)
    self.world,self.shared=world,shared
    self.profileRoot,self.profileAccount=root,accountName
    shared.approvedLegacy=shared.approvedLegacy or {}
    shared.legacyConsentCutoff=shared.legacyConsentCutoff or GetTimeStamp()
    local preferred=store
    local largest=#(store.history or {})
    shared.trackerOwners=shared.trackerOwners or {}
    for profile,accounts in pairs(root or {}) do
        local account=type(accounts)=="table" and accounts[accountName]
        local data=type(account)=="table" and account["$AccountWide"]
        if profile~="Codex Shared" and type(data)=="table" then
            if #(data.history or {})>largest then preferred=data; largest=#data.history end
            for _,opening in ipairs(data.history or {}) do
                local raw=opening.trackerRaw or opening.legacyRaw
                if raw and not shared.trackerOwners[raw] then shared.trackerOwners[raw]=profile end
            end
        end
    end
    if not shared.settings then shared.settings=preferred.settings or {} end
    if not shared.legacyWorld then
        shared.legacyWorld=world
        for profile,accounts in pairs(root or {}) do
            local account=type(accounts)=="table" and accounts[accountName]
            local data=type(account)=="table" and account["$AccountWide"]
            if data==preferred then shared.legacyWorld=profile end
        end
    end
    -- Untagged old Tracker/seed records cannot reveal their original server.
    -- Preserve their existing Codex profile rather than copying them to both.
    if not shared.legacyBaselineSet then
        local records = self:TrackerRecords() or {}
        for _,record in ipairs(records) do
            local raw=type(record)=="table" and record.Data or record
            if type(raw)=="string" and not shared.trackerOwners[raw] then shared.trackerOwners[raw]=shared.legacyWorld end
        end
        shared.legacyBaselineSet=true
    end
    for _,raw in ipairs(self.legacySeed or {}) do
        if not shared.trackerOwners[raw] then shared.trackerOwners[raw]=shared.legacyWorld end
    end
    store.settings=shared.settings
    self.sessionIds={}
    self:InitializeStore(store)
end

function C:InitializeStore(store)
    self.db = store
    store.crates = store.crates or {}
    store.history = store.history or {}
    store.nextId = store.nextId or 1
    store.diagnostics = store.diagnostics or { failedOpens = 0, unreadableOpens = 0 }
    store.wishes = store.wishes or {}
    store.rejectedTrackerRecords = store.rejectedTrackerRecords or {}
    store.settings = store.settings or {}
    local storeSettings = store.settings
    if not storeSettings.language then storeSettings.language = "auto" end
    if storeSettings.gamepadNavigation==nil then storeSettings.gamepadNavigation=true end
    if storeSettings.includeImported == nil then storeSettings.includeImported = true end
    if storeSettings.includeImportedTiers == nil then storeSettings.includeImportedTiers = true end
    if self.legacySeed and not storeSettings.importTierDefaultMigrated then storeSettings.includeImportedTiers=true end
    storeSettings.importTierDefaultMigrated=true
    if storeSettings.largeText == nil then storeSettings.largeText = true end
    if not storeSettings.displaySize then storeSettings.displaySize = storeSettings.largeText and "Large" or "Compact" end
    if not storeSettings.windowScale then storeSettings.windowScale = 100 end
    if not storeSettings.browseMode then storeSettings.browseMode = "Pages" end
    if storeSettings.alwaysOnTop == nil then storeSettings.alwaysOnTop = true end
    if not storeSettings.backgroundOpacity then storeSettings.backgroundOpacity = 96 end
    if not storeSettings.scrollStep then storeSettings.scrollStep = 1 end
    if storeSettings.showHelp == nil then storeSettings.showHelp = true end
    if storeSettings.showAccountName == nil then storeSettings.showAccountName = true end
    storeSettings.actionColor=storeSettings.actionColor or {0.41,0.84,1}
    if not storeSettings.tooltipWidth then storeSettings.tooltipWidth=640 end
    if storeSettings.showOfficialReference==nil then storeSettings.showOfficialReference=true end
    self.sessionIds = self.sessionIds or {}
end

function C:LearnCrate(id)
    if not id or id <= 0 then return end
    local crate = self.db.crates[id]
    if not crate then
        crate = { id = id, firstSeen = GetTimeStamp(), rewards = {} }
        self.db.crates[id] = crate
    end
    local name = GetCrownCrateName(id)
    if self.HistoricalCatalogFor then self:HistoricalCatalogFor(crate) end
    if name and name ~= "" then crate.name = zo_strformat("<<1>>", name) end
    if self.HistoricalCatalogFor then self:HistoricalCatalogFor(crate) end
    crate.name = crate.name or ("Crate #" .. id)
    crate.icon = GetCrownCrateIcon(id)
    crate.lastSeen = GetTimeStamp()
    crate.owned = GetCrownCrateCount(id)
    return crate
end

function C:Discover()
    -- Enumerate only IDs supplied by the client; no guessed ranges or season table.
    for id, crate in pairs(self.db.crates) do self:LearnCrate(id); crate.owned = 0; crate.onSale = false end
    local seen, id = {}, GetNextOwnedCrownCrateId(nil)
    while id and id > 0 and not seen[id] do
        seen[id] = true
        self:LearnCrate(id)
        id = GetNextOwnedCrownCrateId(id)
    end
    local sale = GetOnSaleCrownCrateId()
    if sale and sale > 0 then self:LearnCrate(sale).onSale = true end
end

function C.RewardKey(reward)
    -- Product type is essential: item IDs and collectible IDs can overlap.
    local identity = reward.referenceId
    if not identity or identity == 0 then identity = reward.link and reward.link ~= "" and reward.link or reward.name end
    return tostring(reward.productType) .. ":" .. tostring(identity)
end

function C:Capture(crateId, response)
    if response ~= LOOT_CRATE_OPEN_RESPONSE_SUCCESS then
        self.db.diagnostics.failedOpens = self.db.diagnostics.failedOpens + 1
        return false
    end
    local count = GetNumCurrentCrownCrateTotalRewards()
    local current = GetCurrentCrownCrateId()
    if not crateId or crateId <= 0 or current ~= crateId or not count or count < 1 then
        self.db.diagnostics.unreadableOpens = self.db.diagnostics.unreadableOpens + 1
        return false
    end
    -- Snapshot synchronously: delayed callbacks could read the next crate's results.
    local opening = { id = self.db.nextId, crateId = crateId, timestamp = GetTimeStamp(), rewards = {} }
    for index = 1, count do
        local name, typeText, image, accent, gems, bonus, tier, stack = GetCrownCrateRewardInfo(index)
        local productType, referenceId = GetCrownCrateRewardProductReferenceData(index)
        if not name or name == "" or not tier or not stack or stack < 1 then
            self.db.diagnostics.unreadableOpens = self.db.diagnostics.unreadableOpens + 1
            return false -- Never publish partial results as a complete opening.
        end
        opening.rewards[index] = {
            name = zo_strformat("<<1>>", name), typeText = typeText, image = image,
            accent = accent, gems = gems or 0, bonus = bonus == true, tier = tier,
            stack = stack, productType = productType, referenceId = referenceId,
            link = GetCrownCrateRewardItemLink(index, LINK_STYLE_DEFAULT) or "",
        }
        self:EnrichReward(opening.rewards[index])
    end
    local crate = self:LearnCrate(crateId)
    for _, reward in ipairs(opening.rewards) do
        if self.ApplyHistoricalCatalog then self:ApplyHistoricalCatalog(opening,reward) end
        local key = C.RewardKey(reward)
        crate.rewards[key] = reward
    end
    self.db.history[#self.db.history + 1] = opening
    self.db.nextId = self.db.nextId + 1
    self.sessionIds[opening.id] = true
    opening.source = "live"
    opening.legacyRaw = self:LegacyFingerprint(opening)
    self.pendingTracker = self.pendingTracker or {}
    self.pendingTracker[#self.pendingTracker + 1] = opening
    self.db.lastRecorded = opening.timestamp
    self:BackfillLegacyTiers(crateId)
    if self.ApplyHistoricalCatalog then
        for _, entry in ipairs(self.db.history) do
            if entry.crateId == crateId and entry.source == "tracker" then
                for _, reward in ipairs(entry.rewards) do self:ApplyHistoricalCatalog(entry, reward) end
            end
        end
    end
    return true
end

function C.TierName(tier)
    -- Preserve raw tier IDs. Guessing Apex from item quality misclassifies rewards.
    if not tier or tier == 0 then return C.L("Unknown tier") end
    return C.L("Tier ") .. tostring(tier)
end

function C:Matches(opening, query, crateId)
    if crateId and opening.crateId ~= crateId then return false end
    if self.categoryFilter and self.RewardCategoryMatches then
        local found = false
        for _,reward in ipairs(opening.rewards) do if self:RewardCategoryMatches(reward) then found=true; break end end
        if not found then return false end
    end
    query = C.Lower(query or "")
    if query == "" then return true end
    local crate = self.db.crates[opening.crateId]
    if string.find(C.Lower(crate and crate.name or tostring(opening.crateId)), query, 1, true) then return true end
    for _, r in ipairs(opening.rewards) do
        local text = r.name .. " " .. (r.typeText or "") .. " " .. C.TierName(r.tier) .. " " .. (C.RewardRarityName and C.RewardRarityName(r) or C.RarityName(r.rarity))
        if r.bonus then text = text .. " bonus" end
        if string.find(C.Lower(text), query, 1, true) then return true end
    end
    return false
end

function C:Statistics(crateId, sessionOnly, ignoreImportSettings)
    local result = { openings = 0, cards = 0, units = 0, gems = 0, bonus = 0, bonusOpenings = 0,
        tiers = {}, rewards = {}, rarities = {}, classifiedOpenings = 0, unknownTierCards = 0, gemKnownOpenings = 0,
        includedImported = 0, excludedImported = 0, tierEligibleOpenings = 0, unresolvedApexCards=0 }
    for _, opening in ipairs(self.db.history) do
        if (not crateId or crateId == opening.crateId) and (not sessionOnly or self.sessionIds[opening.id]) then
            local imported = opening.source == "tracker"
            if imported and not self.db.settings.includeImported and not ignoreImportSettings then
                result.excludedImported = result.excludedImported + 1
            else
            result.openings = result.openings + 1
            if imported then result.includedImported = result.includedImported + 1 end
            local tierEligible = not imported or self.db.settings.includeImportedTiers
            if tierEligible then result.tierEligibleOpenings = result.tierEligibleOpenings + 1 end
            local seenTiers, seenRewards, seenRarities = {}, {}, {}
            local fullyKnown, hasBonus = true, false
            if opening.source ~= "tracker" then result.gemKnownOpenings = result.gemKnownOpenings + 1 end
            for _, r in ipairs(opening.rewards) do
                result.cards = result.cards + 1
                result.units = result.units + r.stack
                result.gems = result.gems + (r.gems or 0)
                if r.bonus then result.bonus = result.bonus + 1; hasBonus = true end
                if r.rarity then seenRarities[r.rarity] = true else fullyKnown = false end
                if not r.rarity then result.unknownTierCards = result.unknownTierCards + 1 end
                if r.apexUnresolved then result.unresolvedApexCards=result.unresolvedApexCards+1 end
                local tierId = r.tier or 0
                local tier = result.tiers[tierId] or { cards = 0, openings = 0 }
                result.tiers[tierId] = tier
                tier.cards = tier.cards + 1
                if not seenTiers[tierId] then tier.openings = tier.openings + 1; seenTiers[tierId] = true end
                local key = C.RewardKey(r)
                local reward = result.rewards[key] or { reward = r, cards = 0, openings = 0, units = 0 }
                result.rewards[key] = reward
                reward.cards = reward.cards + 1
                reward.units = reward.units + r.stack
                if not seenRewards[key] then reward.openings = reward.openings + 1; seenRewards[key] = true end
            end
            if hasBonus then result.bonusOpenings = result.bonusOpenings + 1 end
            if fullyKnown and tierEligible then
                result.classifiedOpenings = result.classifiedOpenings + 1
                for rarity in pairs(seenRarities) do result.rarities[rarity] = (result.rarities[rarity] or 0) + 1 end
            end
            end
        end
    end
    return result
end

function C:HistoryRows(query, crateId)
    local rows = {}
    for index = #self.db.history, 1, -1 do
        local opening = self.db.history[index]
        if self:Matches(opening, query, crateId) then rows[#rows + 1] = opening end
    end
    table.sort(rows, function(a, b)
        if a.timestamp == b.timestamp then return a.id > b.id end
        return a.timestamp > b.timestamp
    end)
    return rows
end

function C.CSV(value)
    return '"' .. string.gsub(tostring(value or ""), '"', '""') .. '"'
end

function C:Export(query, crateId)
    local lines = { "opening_id,timestamp,crate_id,crate_name,card,reward_name,product_type,reference_id,tier,quantity,bonus,gems_exchanged" }
    for _, opening in ipairs(self:HistoryRows(query, crateId)) do
        for index, r in ipairs(opening.rewards) do
            local values = { opening.id, opening.timestamp, opening.crateId, self.db.crates[opening.crateId].name,
                index, r.name, r.productType or "", r.referenceId or "", r.tier or 0, r.stack, tostring(r.bonus), r.gems or "" }
            for i, value in ipairs(values) do values[i] = C.CSV(value) end
            lines[#lines + 1] = table.concat(values, ",")
        end
    end
    return table.concat(lines, "\n")
end
