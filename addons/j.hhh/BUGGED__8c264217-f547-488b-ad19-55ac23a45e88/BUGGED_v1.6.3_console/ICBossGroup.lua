-- Optional cooperative boss sightings. No group communications without LibGroupBroadcast.
-- PROVISIONAL protocol ID 500: MUST be registered at wiki.esoui.com/LibGroupBroadcast_IDs
-- before publishing. A collision prevents sync; the base addon continues to work.
ICT.groupProtocolId = nil -- Set only after registering a unique ID on ESOUI
ICT.groupProtocol = nil

function ICT.observeLivingBoss(name, received)
    local district = ICT.locations[name]
    if not district or not ICT.running then return end
    local now = os.time()
    ICT.bossObservedAlive[name] = now
    -- A recently seen living boss is current evidence, but never a permanent state.
    ICT.confirmedAlive[district] = now + ICT.aliveTTL
    ICT.timetable[district] = 0
    ICT.persistBossTimers()
    if not received then
        ICT.fallbackTimes[name] = ICT.fallbackMaxTime
        ICT.broadcastLivingBoss(name)
    end
    ICT.updateTimers()
end

function ICT.broadcastLivingBoss(name)
    if not ICT.savedVariables or not ICT.savedVariables.groupSync then return end
    if not ICT.groupProtocol or not IsUnitGrouped("player") then return end
    local id = ICT.bossToId[name]
    if not id then return end
    local now = os.time()
    if now - (ICT.lastBroadcast[name] or 0) < 20 then return end
    ICT.lastBroadcast[name] = now
    ICT.groupProtocol:Send({bossId = id})
end

function ICT.initializeGroupBroadcast()
    for name in pairs(ICT.locations) do
        ICT.idToBoss[#ICT.idToBoss + 1] = name
    end
    table.sort(ICT.idToBoss)
    for id, name in ipairs(ICT.idToBoss) do ICT.bossToId[name] = id end
    if not ICT.groupProtocolId then return end -- No unsafe protocol collision.
    local lib = LibGroupBroadcast
    if not lib or not lib.RegisterHandler or not lib.CreateNumericField then return end
    local ok, proto = pcall(function()
        local handler = lib:RegisterHandler(ICT.name .. "BossSightings")
        if not handler then return nil end
        local protocol = handler:DeclareProtocol(ICT.groupProtocolId, "ICTBossSightingsV1")
        protocol:AddField(lib.CreateNumericField("bossId", {minValue = 1, maxValue = 12}))
        protocol:OnData(function(unitTag, data)
            if not ICT.running or not ICT.savedVariables.groupSync then return end
            if not IsUnitGrouped("player") then return end
            -- The library identifies senders by their group unit tag.
            if type(unitTag) ~= "string" or not string.match(unitTag, "^group%d+$") then return end
            local name = data and ICT.idToBoss[data.bossId]
            if name then ICT.observeLivingBoss(name, true) end
        end)
        if protocol:Finalize({isRelevantInCombat = false, replaceQueuedMessages = true}) then
            return protocol
        end
        return nil
    end)
    if ok then ICT.groupProtocol = proto end
end
