-- ESO Adventurer Suite - Wayshrine Auto Message
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
--
-- Prepares a user-customized chat message when a NEW wayshrine is discovered.
-- ESO requires the player to confirm normal chat messages, so this module fills
-- the chat entry box and leaves the final Enter/send action to the player.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach

EPC.WayshrineAutoMessage = EPC.WayshrineAutoMessage or {}
local W = EPC.WayshrineAutoMessage

local EVENT_NAMESPACE = "ESOAdventurerSuite_WayshrineAutoMessage"

local function clean(value, fallback)
    local text = tostring(value or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return fallback or "" end
    return text
end

local function safeCall(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e
end

local function nowMs()
    if type(GetFrameTimeMilliseconds) == "function" then
        return tonumber(GetFrameTimeMilliseconds()) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return tonumber(GetGameTimeMilliseconds()) or 0
    end
    return 0
end

function W:IsEnabled()
    return EPC.saved and EPC.saved.wayshrineAutoMessageEnabled == true
end

function W:GetTriggerKey()
    local key = EPC.saved and tostring(EPC.saved.wayshrineAutoMessageTrigger or "FAST_TRAVEL") or "FAST_TRAVEL"
    key = string.upper(key)
    if key ~= "FAST_TRAVEL" and key ~= "DISCOVERY" and key ~= "BOTH" then key = "FAST_TRAVEL" end
    return key
end

function W:ShouldTrigger(kind)
    local selected = self:GetTriggerKey()
    kind = string.upper(tostring(kind or ""))
    return selected == "BOTH" or selected == kind
end

function W:GetTemplate()
    if not EPC.saved then return "Discovered {wayshrine} in {zone}!" end
    local template = tostring(EPC.saved.wayshrineAutoMessageTemplate or "")
    if template == "" then template = tostring(EPC.defaults.wayshrineAutoMessageTemplate or "Discovered {wayshrine} in {zone}!") end
    return template
end

function W:GetGuildLink()
    if not EPC.saved then return "" end
    local link = tostring(EPC.saved.wayshrineAutoMessageGuildLink or "")
    -- Preserve ESO's |H...|h...|h link markup exactly. Only collapse line
    -- breaks and trim outer whitespace so the link remains clickable.
    link = link:gsub("\r", " "):gsub("\n", " ")
    link = link:gsub("^%s+", ""):gsub("%s+$", "")
    return link
end

function W:HasGuildLink()
    return self:GetGuildLink() ~= ""
end

function W:LimitMessagePreservingGuildLink(message, guildLink, maxLength)
    message = tostring(message or "")
    guildLink = tostring(guildLink or "")
    maxLength = tonumber(maxLength) or 350
    if #message <= maxLength then return message end

    -- Never truncate through the middle of ESO's clickable guild-link markup.
    -- When the link exists in an overlong message, preserve the entire link and
    -- trim ordinary recruitment prose around it instead.
    if guildLink ~= "" and #guildLink < maxLength then
        local startPos, endPos = string.find(message, guildLink, 1, true)
        if startPos and endPos then
            local before = string.sub(message, 1, startPos - 1)
            local after = string.sub(message, endPos + 1)
            local room = maxLength - #guildLink
            local beforeRoom = math.floor(room * 0.72)
            local afterRoom = room - beforeRoom
            if #before < beforeRoom then
                afterRoom = afterRoom + (beforeRoom - #before)
                beforeRoom = #before
            end
            if #after < afterRoom then
                beforeRoom = math.min(#before, beforeRoom + (afterRoom - #after))
                afterRoom = #after
            end
            before = string.sub(before, 1, beforeRoom)
            after = string.sub(after, math.max(1, #after - afterRoom + 1))
            return before .. guildLink .. after
        end
    end

    return string.sub(message, 1, maxLength)
end

function W:GetChannelKey()
    local key = EPC.saved and tostring(EPC.saved.wayshrineAutoMessageChannel or "ZONE") or "ZONE"
    key = string.upper(key)
    local allowed = {
        SAY = true, ZONE = true, GROUP = true,
        GUILD1 = true, GUILD2 = true, GUILD3 = true, GUILD4 = true, GUILD5 = true,
        LOCAL = true,
    }
    if not allowed[key] then key = "ZONE" end
    return key
end

function W:GetChannelId(key)
    key = string.upper(tostring(key or self:GetChannelKey()))
    if key == "SAY" then return rawget(_G, "CHAT_CHANNEL_SAY") end
    if key == "ZONE" then return rawget(_G, "CHAT_CHANNEL_ZONE") end
    if key == "GROUP" then return rawget(_G, "CHAT_CHANNEL_PARTY") end
    if key == "GUILD1" then return rawget(_G, "CHAT_CHANNEL_GUILD_1") end
    if key == "GUILD2" then return rawget(_G, "CHAT_CHANNEL_GUILD_2") end
    if key == "GUILD3" then return rawget(_G, "CHAT_CHANNEL_GUILD_3") end
    if key == "GUILD4" then return rawget(_G, "CHAT_CHANNEL_GUILD_4") end
    if key == "GUILD5" then return rawget(_G, "CHAT_CHANNEL_GUILD_5") end
    return nil
end

function W:GetChannelDisplayName(key)
    key = string.upper(tostring(key or self:GetChannelKey()))
    local names = {
        SAY = "Say", ZONE = "Zone", GROUP = "Group",
        GUILD1 = "Guild 1", GUILD2 = "Guild 2", GUILD3 = "Guild 3",
        GUILD4 = "Guild 4", GUILD5 = "Guild 5", LOCAL = "Local / Suite Chat",
    }
    return names[key] or "Zone"
end

function W:FormatMessage(wayshrineName, zoneName)
    local message = self:GetTemplate()
    local characterName = clean(safeCall(GetUnitName, "", "player"), "Adventurer")
    local accountName = clean(safeCall(GetDisplayName, ""), "")
    local shrine = clean(wayshrineName, "Wayshrine")
    local zone = clean(zoneName, "Tamriel")
    local guildLink = self:GetGuildLink()

    local replacements = {
        ["{wayshrine}"] = shrine,
        ["{shrine}"] = shrine,
        ["{zone}"] = zone,
        ["{character}"] = characterName,
        ["{account}"] = accountName,
        ["{guildlink}"] = guildLink,
    }
    for token, value in pairs(replacements) do
        message = message:gsub(token, function() return value end)
    end

    message = message:gsub("\r", " "):gsub("\n", " ")
    message = message:gsub("%s+", " ")
    message = clean(message, "")
    -- Keep comfortably below ESO chat's maximum after user substitutions, but
    -- never cut through the middle of the clickable guild link.
    message = self:LimitMessagePreservingGuildLink(message, guildLink, 350)
    return message
end

function W:IsWayshrinePOI(zoneIndex, poiIndex)
    zoneIndex = tonumber(zoneIndex) or 0
    poiIndex = tonumber(poiIndex) or 0
    if zoneIndex <= 0 or poiIndex < 0 then return false end

    if type(GetPOIType) == "function" and rawget(_G, "POI_TYPE_WAYSHRINE") ~= nil then
        local poiType = safeCall(GetPOIType, nil, zoneIndex, poiIndex)
        if poiType ~= POI_TYPE_WAYSHRINE then return false end
    end

    -- When possible, verify that this POI also belongs to ESO's fast-travel node
    -- table. This filters the occasional POI that shares a generic wayshrine type.
    local getNodePoi = rawget(_G, "GetFastTravelNodePOIIndicies") or rawget(_G, "GetFastTravelNodePOIIndices")
    if type(getNodePoi) == "function" and type(GetNumFastTravelNodes) == "function" then
        local total = tonumber(safeCall(GetNumFastTravelNodes, 0)) or 0
        for nodeIndex = 1, total do
            local z, p = safeCall(getNodePoi, nil, nodeIndex)
            if tonumber(z) == zoneIndex and tonumber(p) == poiIndex then
                return true, nodeIndex
            end
        end
        -- Do not reject solely because a node lookup failed. DLC/API map index
        -- timing can lag briefly during the discovery event itself.
    end

    return true, nil
end

function W:GetWayshrineName(zoneIndex, poiIndex, nodeIndex)
    if tonumber(nodeIndex) and type(GetFastTravelNodeInfo) == "function" then
        local _, nodeName = safeCall(GetFastTravelNodeInfo, nil, tonumber(nodeIndex))
        nodeName = clean(nodeName, "")
        if nodeName ~= "" then return nodeName end
    end

    if type(GetPOIInfo) == "function" then
        local name = safeCall(GetPOIInfo, "", tonumber(zoneIndex) or 0, tonumber(poiIndex) or 0)
        name = clean(name, "")
        if name ~= "" then return name end
    end
    return "Wayshrine"
end

function W:GetZoneName(zoneIndex)
    zoneIndex = tonumber(zoneIndex) or 0
    local name = ""
    if zoneIndex > 0 and type(GetZoneNameByIndex) == "function" then
        name = clean(safeCall(GetZoneNameByIndex, "", zoneIndex), "")
    end
    if name == "" and type(GetUnitZone) == "function" then
        name = clean(safeCall(GetUnitZone, "", "player"), "")
    end
    return name ~= "" and name or "Tamriel"
end

function W:SafeStartChatInput(message, channelId)
    message = clean(message, "")
    if message == "" then return false, "Message template is empty." end

    -- Current ESO/console-safe path: use the chat system's public text-entry
    -- method instead of attempting any protected submit/send function.
    if type(IsChatSystemAvailableForCurrentPlatform) == "function" then
        local available = safeCall(IsChatSystemAvailableForCurrentPlatform, true)
        if available == false then return false, "Chat is unavailable on this platform right now." end
    end

    if type(ZO_GetChatSystem) == "function" then
        local chat = safeCall(ZO_GetChatSystem, nil)
        if chat and type(chat.StartTextEntry) == "function" then
            local ok = pcall(chat.StartTextEntry, chat, message, channelId, nil, true)
            if ok then return true end
        end
    end

    if type(StartChatInput) == "function" then
        local ok = pcall(StartChatInput, message, channelId)
        if ok then return true end
    end

    return false, "ESO chat input could not be opened."
end

function W:PrepareMessage(wayshrineName, zoneName, isTest)
    local message = self:FormatMessage(wayshrineName, zoneName)
    if message == "" then
        if EPC.Print then EPC:Print("Wayshrine Auto Message: message template is empty.") end
        return false
    end

    local channelKey = self:GetChannelKey()
    self.lastPreparedMessage = message
    self.lastPreparedWayshrine = clean(wayshrineName, "Wayshrine")
    self.lastPreparedZone = clean(zoneName, "Tamriel")
    self.lastPreparedAt = nowMs()

    if channelKey == "LOCAL" then
        if EPC.Print then EPC:Print(message) elseif type(d) == "function" then d(message) end
        return true
    end

    local channelId = self:GetChannelId(channelKey)
    if channelId == nil then
        if EPC.Print then EPC:Print("Wayshrine Auto Message: selected chat channel is unavailable.") end
        return false
    end

    local ok, reason = self:SafeStartChatInput(message, channelId)
    if not ok and EPC.Print then EPC:Print("Wayshrine Auto Message: " .. tostring(reason or "could not open chat.")) end
    if ok and isTest and EPC.Print then
        EPC:Print("Wayshrine Auto Message test prepared. Press Enter to send or Escape to cancel.")
    end
    return ok
end

function W:OnPOIDiscovered(_, zoneIndex, poiIndex)
    if not self:IsEnabled() or not self:ShouldTrigger("DISCOVERY") then return end

    local isWayshrine, nodeIndex = self:IsWayshrinePOI(zoneIndex, poiIndex)
    if not isWayshrine then return end

    local shrineName = self:GetWayshrineName(zoneIndex, poiIndex, nodeIndex)
    local zoneName = self:GetZoneName(zoneIndex)
    local key = tostring(zoneIndex or 0) .. ":" .. tostring(poiIndex or 0)
    local current = nowMs()

    -- EVENT_POI_DISCOVERED should fire once, but suppress duplicate callbacks
    -- during map/load transitions so one discovery can never open chat twice.
    if self.lastDiscoveryKey == key and current - (tonumber(self.lastDiscoveryAt) or 0) < 15000 then return end
    self.lastDiscoveryKey = key
    self.lastDiscoveryAt = current
    self.lastDiscoveredWayshrine = shrineName
    self.lastDiscoveredZone = zoneName

    local generation = (tonumber(self.prepareGeneration) or 0) + 1
    self.prepareGeneration = generation
    local function prepare()
        if self.prepareGeneration ~= generation then return end
        if not self:IsEnabled() then return end
        self:PrepareMessage(shrineName, zoneName, false)
    end
    if type(zo_callLater) == "function" then zo_callLater(prepare, 650) else prepare() end
end

function W:GetFastTravelDestination(nodeIndex)
    nodeIndex = tonumber(nodeIndex) or 0
    if nodeIndex <= 0 then return nil end

    local name = "Wayshrine"
    if type(GetFastTravelNodeInfo) == "function" then
        local known, nodeName = safeCall(GetFastTravelNodeInfo, nil, nodeIndex)
        nodeName = clean(nodeName, "")
        if nodeName ~= "" then name = nodeName end
    end

    local zoneIndex = 0
    local poiIndex = 0
    local getNodePoi = rawget(_G, "GetFastTravelNodePOIIndicies") or rawget(_G, "GetFastTravelNodePOIIndices")
    if type(getNodePoi) == "function" then
        local z, p = safeCall(getNodePoi, nil, nodeIndex)
        zoneIndex = tonumber(z) or 0
        poiIndex = tonumber(p) or 0
    end

    local zoneName = self:GetZoneName(zoneIndex)
    return {
        nodeIndex = nodeIndex,
        zoneIndex = zoneIndex,
        poiIndex = poiIndex,
        wayshrineName = name,
        zoneName = zoneName,
    }
end

function W:ArmPendingTravelDestination(destination)
    if not self:IsEnabled() or not self:ShouldTrigger("FAST_TRAVEL") then return nil end
    if type(destination) ~= "table" then return nil end

    self.fastTravelGeneration = (tonumber(self.fastTravelGeneration) or 0) + 1
    destination.generation = self.fastTravelGeneration
    destination.startedAt = nowMs()
    self.pendingFastTravel = destination

    -- If travel never completes (error/interruption), do not let the stale flag
    -- turn an unrelated later loading screen into a wayshrine message.
    if type(zo_callLater) == "function" then
        local generation = destination.generation
        zo_callLater(function()
            local pending = W.pendingFastTravel
            if pending and pending.generation == generation then W.pendingFastTravel = nil end
        end, 90000)
    end
    return destination.generation
end

function W:ArmFastTravel(nodeIndex)
    if not self:IsEnabled() or not self:ShouldTrigger("FAST_TRAVEL") then return nil end
    local destination = self:GetFastTravelDestination(nodeIndex)
    if not destination then return nil end
    destination.source = "ESO_WAYSHRINE"
    return self:ArmPendingTravelDestination(destination)
end

-- Suite Teleporter routes are not limited to FastTravelToNode. Friend, guild,
-- group, and house jumps use separate ESO APIs, so arm the same arrival flow
-- directly after the Suite successfully requests one of those travels.
function W:ArmSuiteTeleporterTravel(entry)
    if not self:IsEnabled() or not self:ShouldTrigger("FAST_TRAVEL") then return nil end
    if type(entry) ~= "table" then return nil end

    local kind = string.upper(tostring(entry.kind or ""))
    local destination = nil
    local nodeIndex = tonumber(entry.nodeIndex) or 0

    if (kind == "SHRINE" or kind == "INSTANCE") and nodeIndex > 0 then
        destination = self:GetFastTravelDestination(nodeIndex)
    end

    if not destination then
        local label = clean(entry.name, "")
        if label == "" then label = clean(entry.displayName, "") end
        if label == "" then label = clean(entry.characterName, "") end
        if label == "" then label = clean(entry.zoneName, "") end
        if label == "" then label = "Suite Teleporter destination" end

        destination = {
            nodeIndex = nodeIndex,
            zoneIndex = tonumber(entry.zoneIndex) or 0,
            wayshrineName = label,
            zoneName = clean(entry.zoneName, ""),
            resolveArrivalZone = true,
        }
    end

    destination.source = "SUITE_TELEPORTER"
    destination.teleporterKind = kind
    -- Social/house destinations can report stale or parent-zone text before the
    -- load. Resolve the player's actual zone after EVENT_PLAYER_ACTIVATED.
    if kind ~= "SHRINE" and kind ~= "INSTANCE" then
        destination.resolveArrivalZone = true
    end
    return self:ArmPendingTravelDestination(destination)
end

function W:RegisterFastTravelHook()
    if self.fastTravelHookRegistered then return true end
    if type(ZO_PreHook) ~= "function" or type(rawget(_G, "FastTravelToNode")) ~= "function" then return false end

    ZO_PreHook(_G, "FastTravelToNode", function(nodeIndex)
        W:ArmFastTravel(nodeIndex)
    end)
    self.fastTravelHookRegistered = true
    return true
end

function W:OnPlayerActivated(_, initial)
    -- FastTravelToNode and slash-command globals can be unavailable very early
    -- during addon load on some clients. Retry both once the player scene is active.
    self:RegisterFastTravelHook()
    self:RegisterPromoSlashCommand()

    local pending = self.pendingFastTravel
    if not pending then return end
    self.pendingFastTravel = nil
    if not self:IsEnabled() or not self:ShouldTrigger("FAST_TRAVEL") then return end

    local age = nowMs() - (tonumber(pending.startedAt) or 0)
    if age < 0 or age > 120000 then return end

    local shrineName = clean(pending.wayshrineName, "Wayshrine")
    local zoneName = clean(pending.zoneName, "")
    if pending.resolveArrivalZone == true or zoneName == "" or zoneName == "Tamriel" then
        zoneName = self:GetZoneName(0)
    end

    -- Let the destination scene/chat system finish restoring after the load.
    local generation = (tonumber(self.prepareGeneration) or 0) + 1
    self.prepareGeneration = generation
    local function prepare()
        if self.prepareGeneration ~= generation then return end
        if not self:IsEnabled() or not self:ShouldTrigger("FAST_TRAVEL") then return end
        self.lastFastTravelWayshrine = shrineName
        self.lastFastTravelZone = zoneName
        self:PrepareMessage(shrineName, zoneName, false)
    end
    if type(zo_callLater) == "function" then zo_callLater(prepare, 700) else prepare() end
end

function W:TestMessage()
    local zoneName = self:GetZoneName(safeCall(GetCurrentMapZoneIndex, 0))
    return self:PrepareMessage("Example Wayshrine", zoneName, true)
end

-- Manual resend for the player's configured wayshrine promo.  /promo is an
-- explicit player action, so it works even when the automatic trigger is
-- disabled.  Reuse the most recently prepared/arrived/discovered wayshrine
-- context so an immediate resend matches the message the player just saw.
function W:PromoMessage()
    local shrineName = clean(
        self.lastPreparedWayshrine
        or self.lastFastTravelWayshrine
        or self.lastDiscoveredWayshrine,
        "Wayshrine"
    )
    local zoneName = clean(
        self.lastPreparedZone
        or self.lastFastTravelZone
        or self.lastDiscoveredZone,
        ""
    )
    if zoneName == "" then
        zoneName = self:GetZoneName(safeCall(GetCurrentMapZoneIndex, 0))
    end

    local ok = self:PrepareMessage(shrineName, zoneName, false)
    if ok and self:GetChannelKey() ~= "LOCAL" and EPC.Print then
        EPC:Print("/promo prepared your Wayshrine Auto Message again. Press Enter to send or Escape to cancel.")
    end
    return ok
end

function W:RegisterPromoSlashCommand()
    if self.promoSlashRegistered then return true end
    if type(SLASH_COMMANDS) ~= "table" then return false end

    SLASH_COMMANDS["/promo"] = function()
        W:PromoMessage()
    end
    self.promoSlashRegistered = true
    return true
end

function W:GetStatusText()
    if not self:IsEnabled() then return "Disabled - no wayshrine messages will be prepared." end
    local channel = self:GetChannelDisplayName(self:GetChannelKey())
    local triggerNames = {
        FAST_TRAVEL = "Fast travel + Suite Teleporter",
        DISCOVERY = "New wayshrine discovery",
        BOTH = "Fast travel + Teleporter + discovery",
    }
    local linkStatus = self:HasGuildLink() and "SET" or "NOT SET"
    local text = "Enabled | Trigger: " .. (triggerNames[self:GetTriggerKey()] or "Wayshrine fast travel") .. " | Channel: " .. channel .. " | Guild Link: " .. linkStatus
    local last = self.lastFastTravelWayshrine or self.lastDiscoveredWayshrine
    if last then text = text .. " | Last: " .. tostring(last) end
    return text
end

function W:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:RegisterFastTravelHook()
    self:RegisterPromoSlashCommand()

    if EVENT_MANAGER and rawget(_G, "EVENT_POI_DISCOVERED") ~= nil then
        EPC.Runtime:RegisterEvent("WayshrineAutoMessage", "PoiDiscovered", EVENT_POI_DISCOVERED, function(...)
            W:OnPOIDiscovered(...)
        end)
        self.discoveryEventRegistered = true
    else
        self.discoveryEventRegistered = false
    end

    if EVENT_MANAGER and rawget(_G, "EVENT_PLAYER_ACTIVATED") ~= nil then
        EPC.Runtime:RegisterEvent("WayshrineAutoMessage", "PlayerActivated", EVENT_PLAYER_ACTIVATED, function(...)
            W:OnPlayerActivated(...)
        end)
        self.playerActivatedRegistered = true
    else
        self.playerActivatedRegistered = false
    end
end
