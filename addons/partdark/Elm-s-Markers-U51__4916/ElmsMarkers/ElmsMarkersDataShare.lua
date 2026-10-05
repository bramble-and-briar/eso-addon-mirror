ElmsMarkers = ElmsMarkers or { }

local LGB = LibGroupBroadcast

-- Message types for the zone sync stream (protocol 331)
local SYNC_MSG_HEADER = 1 -- header: zone + total marker count
local SYNC_MSG_DATA = 2   -- one block containing ALL markers (array field)
local SYNC_MSG_END = 3    -- footer: "transfer complete, N markers sent"

local ZONE_SHARE_MAX_MARKERS = 500
local ZONE_SHARE_TICK_MS = 250
local ZONE_SHARE_FRAME_MS = 1100           -- estimated duration of one broadcast frame
local ZONE_SHARE_FRAME_GAP_MS = 1100       -- clean cooldown gap required between phases
local ZONE_SHARE_FINALIZE_DELAY_MS = 2500  -- short pause after END before finishing the share
local ZONE_SHARE_COOLDOWN_MS = 8000        -- minimum pause between two zone shares
local ZONE_SHARE_MAX_FAILURES = 10         -- abort after this many consecutive failed sends
local ZONE_SHARE_PROGRESS_STEP = 5         -- print transfer progress every N percent
local ZONE_SHARE_PHASE_TIMEOUT_MS = 15000  -- safety net if a phase stalls (busy channel)

-- Called from ElmsMarkers.OnAddOnLoaded once LibGroupBroadcast is guaranteed to be loaded
-- (the addon lists it in ## DependsOn). Registers a handler and the group sharing protocols.
function ElmsMarkers.InitDataShare()
  if not LGB then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] LibGroupBroadcast is not installed, group sharing is disabled.")
    return
  end

  -- handlerName is optional and must NOT be identical to the addonName (library assertion).
  local ok, handler = pcall(function()
    return LGB:RegisterHandler("ElmsMarkers")
  end)
  if not ok or not handler then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Failed to register LibGroupBroadcast handler, group sharing is disabled.")
    return
  end
  handler:SetDisplayName("Elms Markers")
  handler:SetDescription("Shares markers and rendezvous commands with your group.")

  -- IMPORTANT: The protocol ids and names must be globally unique across all addons. Before
  -- releasing this addon publicly the author has to reserve ids 330-332 on
  -- https://wiki.esoui.com/LibGroupBroadcast_IDs (ids above 511 are NOT supported by the library).
  -- Each protocol is set up independently: a failure of one only disables that feature.

  local protocols = {}

  -- 330: single marker operations (publish add / remove / rendezvous)
  local ok, protocol = pcall(function()
    return handler:DeclareProtocol(330, "ElmsMarkersProtocol")
  end)
  if ok and protocol then
    protocol:SetDisplayName("Elms Markers Group Sharing")
    protocol:AddField(LGB.CreateNumericField("zone", { maxValue = 65535 }))
    protocol:AddField(LGB.CreateNumericField("wX", { minValue = -1000000, maxValue = 1000000 }))
    protocol:AddField(LGB.CreateNumericField("wY", { minValue = -1000000, maxValue = 1000000 }))
    protocol:AddField(LGB.CreateNumericField("wZ", { minValue = -1000000, maxValue = 1000000 }))
    protocol:AddField(LGB.CreateNumericField("iconId", { maxValue = 255 }))
    protocol:AddField(LGB.CreateFlagField("isAdd"))
    protocol:AddField(LGB.CreateFlagField("isRendezvous"))
    protocol:AddField(LGB.CreateFlagField("isZoneShare"))
    protocol:OnData(function(unitTag, data)
      ElmsMarkers.HandleDataShareReceived(unitTag, data)
    end)
    protocol:Finalize({
      isRelevantInCombat = false,
      replaceQueuedMessages = false,
    })
    protocols.single = protocol
    ElmsMarkers.protocol = protocol -- backward compatible alias
  else
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Failed to declare protocol 330 (ID in use by another addon?), publish/remove sharing is disabled.")
  end

  -- 331: zone sync stream (HEADER -> DATA block -> END)
  local ok, syncProtocol = pcall(function()
    return handler:DeclareProtocol(331, "ElmsMarkersZoneSyncProtocol")
  end)
  if ok and syncProtocol then
    syncProtocol:SetDisplayName("Elms Markers Zone Sync")
    syncProtocol:AddField(LGB.CreateNumericField("msgType", { maxValue = 3 }))
    syncProtocol:AddField(LGB.CreateNumericField("zone", { maxValue = 65535 }))
    syncProtocol:AddField(LGB.CreateNumericField("totalCount", { maxValue = ZONE_SHARE_MAX_MARKERS }))
    local markerField = LGB.CreateTableField("marker", {
      LGB.CreateNumericField("wX", { minValue = -1000000, maxValue = 1000000 }),
      LGB.CreateNumericField("wY", { minValue = -1000000, maxValue = 1000000 }),
      LGB.CreateNumericField("wZ", { minValue = -1000000, maxValue = 1000000 }),
      LGB.CreateNumericField("iconId", { maxValue = 255 }),
    })
    syncProtocol:AddField(LGB.CreateArrayField(markerField, { maxLength = ZONE_SHARE_MAX_MARKERS }))
    syncProtocol:OnData(function(unitTag, data)
      ElmsMarkers.HandleZoneSyncMessage(unitTag, data)
    end)
    syncProtocol:Finalize({
      isRelevantInCombat = true, -- deliberate user action, transmit even in combat
      replaceQueuedMessages = true,
    })
    protocols.zoneSync = syncProtocol
  else
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Failed to declare protocol 331 (ID in use by another addon?), zone sharing is disabled.")
  end

  ElmsMarkers.protocols = protocols

  CHAT_SYSTEM:AddMessage(string.format(
    "[ElmsMarkers] Ready: publish=%s, zoneSync=%s.",
    protocols.single and "ok" or "FAIL",
    protocols.zoneSync and "ok" or "FAIL"))
end

--------------------------------------------------------------------------------
-- Single marker operations (protocol 330)
--------------------------------------------------------------------------------

function ElmsMarkers.HandleDataShareReceived(unitTag, data)
  if not unitTag or not data then return end
  -- Ignore our own broadcasts (the game delivers them back to the sender).
  -- The leader already applied the marker locally, so without this guard the
  -- own loopback would place/remove it a second time.
  if AreUnitsEqual(unitTag, 'player') then return end
  -- Only accept updates coming from the group leader.
  if unitTag ~= GetGroupLeaderUnitTag() then return end
  -- Markers are only applied while the user is subscribed to the leader's markers.
  if not ElmsMarkers.savedVars.subscribeToLead then return end

  if data.isRendezvous then
    -- PlaceRendezvousAt additionally checks the optIntoCommands setting.
    ElmsMarkers.PlaceRendezvousAt({data.zone, data.wX, data.wY, data.wZ, data.iconId}, false)
  elseif data.isAdd then
    -- Separate permission for adding single markers from the group lead
    -- (only reachable while subscribeToLead is enabled, see gate above).
    if not ElmsMarkers.savedVars.allowMarkerAdd then return end
    -- Defensive dedupe for repeated zone share messages (legacy path).
    if data.isZoneShare and ElmsMarkers.MarkerExists(data.zone, data.wX, data.wY, data.wZ) then
      return
    end
    ElmsMarkers.PlaceAtLocation({data.zone, data.wX, data.wY, data.wZ, data.iconId})
  else
    -- Separate permission for removing single markers sent by the group lead.
    if not ElmsMarkers.savedVars.allowMarkerRemove then return end
    ElmsMarkers.RemoveExactMarkerAt({data.zone, data.wX, data.wY, data.wZ})
  end
end

-- Returns true if a marker with the same world coordinates already exists in the zone.
function ElmsMarkers.MarkerExists(zone, wX, wY, wZ)
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  if not zonePositions then return false end
  for k, v in pairs(zonePositions) do
    if v and v[1] == wX and v[2] == wY and v[3] == wZ then
      return true
    end
  end
  return false
end

-- Queues a marker/rendezvous update for transmission to the group via LibGroupBroadcast.
-- Returns true when the message was queued. Prints a reason in chat when it was not, so
-- silent failures (disabled protocol, no group, combat) are visible to the user.
function ElmsMarkers.SendMarkerData(location, isAdd, isRendezvous)
  if not location then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Nothing to publish (no marker found nearby).")
    return false
  end
  if not ElmsMarkers.protocols or not ElmsMarkers.protocols.single then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Group sharing is not initialized yet, publish not sent.")
    return false
  end
  if not IsUnitGrouped("player") then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] You are not in a group, publish not sent.")
    return false
  end
  if not ElmsMarkers.protocols.single:IsEnabled() then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Publishing is disabled in the LibGroupBroadcast settings - enable 'Elms Markers Group Sharing' (protocol 330) to share markers with your group!")
    return false
  end
  if IsUnitInCombat("player") then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Cannot publish while in combat - try again after combat ends.")
    return false
  end

  local zone, wX, wY, wZ, iconId = unpack(location)
  local success = ElmsMarkers.protocols.single:Send({
    zone = zone,
    wX = wX,
    wY = wY,
    wZ = wZ,
    iconId = iconId,
    isAdd = isAdd,
    isRendezvous = isRendezvous,
    -- All declared fields must be present; a nil flag makes FlagField:Serialize fail.
    isZoneShare = false,
  })
  if success then
    ElmsMarkers.lastPingTime = GetGameTimeMilliseconds()
  else
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Failed to queue the publish message (all protocol fields must be valid; check that you are grouped and protocol 330 is enabled in the LibGroupBroadcast settings).")
  end
  return success
end

--------------------------------------------------------------------------------
-- Zone sync stream (protocol 331) - sender side
--------------------------------------------------------------------------------

-- Converts saved markers of a zone into the array payload used by the sync protocol.
function ElmsMarkers.BuildMarkerPayload(zonePositions)
  local markers = {}
  if zonePositions then
    for k, v in pairs(zonePositions) do
      if v and v[1] and v[2] and v[3] and v[4] then
        table.insert(markers, { wX = v[1], wY = v[2], wZ = v[3], iconId = v[4] })
      end
    end
  end
  return markers
end

-- Sends one message of the zone sync stream.
function ElmsMarkers.SendZoneSyncMessage(msgType, zone, total, markerList)
  if not ElmsMarkers.protocols or not ElmsMarkers.protocols.zoneSync then return false end
  if not ElmsMarkers.protocols.zoneSync:IsEnabled() then
    if not ElmsMarkers.zoneSyncDisabledWarned then
      ElmsMarkers.zoneSyncDisabledWarned = true
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Zone sync protocol is disabled in the LibGroupBroadcast settings - sharing will not work!")
    end
    return false
  end
  ElmsMarkers.zoneSyncDisabledWarned = nil
  return ElmsMarkers.protocols.zoneSync:Send({
    msgType = msgType,
    zone = zone,
    totalCount = total,
    marker = markerList or {},
  })
end

-- Shares all markers of the current zone with the group. Only the group leader can do this.
-- Flow: HEADER (count) -> DATA (all markers in one block) -> END -> collect reports.
-- Only one of our messages is in the broadcast queue at a time, which avoids the library's
-- frame-packing message loss.
function ElmsMarkers.ShareZoneMarkers()
  local now = GetGameTimeMilliseconds()

  if not AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] You must be the group lead to share zone markers!")
    return
  end
  if not ElmsMarkers.protocols or not ElmsMarkers.protocols.zoneSync then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Group sharing is not available.")
    return
  end
  if ElmsMarkers.zoneShareState then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Zone share already in progress, please wait.")
    return
  end
  if ElmsMarkers.lastShareEnd and (now - ElmsMarkers.lastShareEnd) < ZONE_SHARE_COOLDOWN_MS then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Zone share is on cooldown, try again in a few seconds.")
    return
  end

  local zone = GetUnitRawWorldPosition("player")
  local payload = ElmsMarkers.BuildMarkerPayload(ElmsMarkers.savedVars.positions[zone])
  if #payload == 0 then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] No markers in this zone to share.")
    return
  end
  if #payload > ZONE_SHARE_MAX_MARKERS then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Too many markers in this zone (" .. #payload .. "), maximum is " .. ZONE_SHARE_MAX_MARKERS .. ".")
    return
  end

  -- Estimate the size of the DATA block to drive progress reporting:
  -- msgType(2) + zone(16) + totalCount(9) + count(9) + N*(wX21+wY21+wZ21+iconId8)
  local totalBits = 36 + 71 * #payload
  local dataBytes = math.ceil(totalBits / 8)
  local framesNeeded = math.max(1, math.ceil(dataBytes / 28))

  ElmsMarkers.zoneShareState = {
    zone = zone,
    payload = payload,
    total = #payload,
    framesNeeded = framesNeeded,
    totalMs = framesNeeded * ZONE_SHARE_FRAME_MS + 800,
    phase = "header",
    cdPrev = GetGroupAddOnDataBroadcastCooldownRemainingMS(),
    failures = 0,
  }

  CHAT_SYSTEM:AddMessage("[ElmsMarkers] Starting zone share: " .. #payload .. " markers for zone " .. zone .. ".")
  ElmsMarkers.ZoneShareRegisterTicker()
  ElmsMarkers.ZoneShareTick()
end

-- Ticker entry point: abort checks, frame detection, then the phase machine (protected).
function ElmsMarkers.ZoneShareTick()
  local state = ElmsMarkers.zoneShareState
  if not state then return end
  local now = GetGameTimeMilliseconds()

  -- Abort when no longer the leader / not grouped anymore.
  if not IsUnitGrouped("player") or not AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
    ElmsMarkers.ZoneShareAbort(true)
    return
  end

  -- LibGroupBroadcast does not transmit non-combat-relevant messages while in combat.
  if IsUnitInCombat("player") then return end

  -- Detect completed broadcast frames via the API cooldown (goes >0 on a broadcast, back to 0).
  local cd = GetGroupAddOnDataBroadcastCooldownRemainingMS()
  if state.cdPrev and state.cdPrev > 0 and cd == 0 then
    state.framesDone = (state.framesDone or 0) + 1
    state.lastFrameEnd = now
  end
  state.cdPrev = cd

  local ok, err = pcall(function()
    ElmsMarkers.ZoneShareTickInternal(state, now, cd)
  end)
  if not ok then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Zone share error: " .. tostring(err))
    ElmsMarkers.ZoneShareAbort(true)
  end
end

-- Phase machine: header -> wait_header -> data -> track_data -> end -> reports.
function ElmsMarkers.ZoneShareTickInternal(state, now, cd)
  local phase = state.phase

  if phase == "header" then
    if ElmsMarkers.SendZoneSyncMessage(SYNC_MSG_HEADER, state.zone, state.total) then
      state.lastSend = now
      state.phase = "wait_header"
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Stage 1/4: header sent (" .. state.total .. " markers, zone " .. state.zone .. ").")
    else
      ElmsMarkers.ZoneShareCountFailure(state)
    end

  elseif phase == "wait_header" then
    -- Proceed once the header frame has been broadcast and the channel is clean again.
    if (now - state.lastSend) > ZONE_SHARE_PHASE_TIMEOUT_MS then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Header frame was not broadcast (channel busy?), share aborted. Try again.")
      ElmsMarkers.ZoneShareAbort(true)
      return
    end
    if state.lastFrameEnd and state.lastFrameEnd >= state.lastSend
      and (now - state.lastFrameEnd) >= ZONE_SHARE_FRAME_GAP_MS and cd == 0 then
      state.phase = "data"
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Stage 2/4: sending data block (" .. state.total .. " markers)...")
    end

  elseif phase == "data" then
    if ElmsMarkers.SendZoneSyncMessage(SYNC_MSG_DATA, state.zone, state.total, state.payload) then
      state.dataStart = now
      state.lastPct = 0
      state.phase = "track_data"
    else
      ElmsMarkers.ZoneShareCountFailure(state)
    end

  elseif phase == "track_data" then
    local elapsed = now - state.dataStart
    if elapsed > state.totalMs + ZONE_SHARE_PHASE_TIMEOUT_MS then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Data block transfer stalled, share aborted. Try again.")
      ElmsMarkers.ZoneShareAbort(true)
      return
    end
    local pct = math.min(100, math.floor(elapsed / state.totalMs * 100))
    local rounded = math.floor(pct / ZONE_SHARE_PROGRESS_STEP) * ZONE_SHARE_PROGRESS_STEP
    if rounded > (state.lastPct or 0) then
      state.lastPct = rounded
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Data transfer: " .. rounded .. "%.")
    end

    -- Complete once the estimated duration has passed and the channel is idle, so the
    -- DATA block really got a chance to be transmitted (END follows it by library ordering).
    local clean = state.lastFrameEnd and state.lastFrameEnd >= state.dataStart and cd == 0
    if elapsed >= state.totalMs and clean then
      state.phase = "end"
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Stage 3/4: data block sent (100%).")
    end

  elseif phase == "end" then
    -- The library guarantees ordering: the END message is only transmitted after the DATA
    -- block has fully arrived. Give it a moment to go out, then finish.
    if ElmsMarkers.SendZoneSyncMessage(SYNC_MSG_END, state.zone, state.total) then
      state.finalizeStart = now
      state.phase = "finalize"
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Stage 4/4: transfer complete.")
    else
      ElmsMarkers.ZoneShareCountFailure(state)
    end

  elseif phase == "finalize" then
    if now - state.finalizeStart >= ZONE_SHARE_FINALIZE_DELAY_MS then
      ElmsMarkers.FinishZoneShare()
    end
  end
end

function ElmsMarkers.ZoneShareCountFailure(state)
  state.failures = state.failures + 1
  if state.failures >= ZONE_SHARE_MAX_FAILURES then
    ElmsMarkers.ZoneShareAbort(true)
  end
end

-- Finishes the share: prints the final summary and cleans up.
function ElmsMarkers.FinishZoneShare()
  local state = ElmsMarkers.zoneShareState
  if not state then return end

  CHAT_SYSTEM:AddMessage("[ElmsMarkers] Zone share finished: " .. state.total .. " markers sent for zone " .. state.zone .. ".")
  ElmsMarkers.lastShareEnd = GetGameTimeMilliseconds()
  ElmsMarkers.ZoneShareAbort(false)
end

function ElmsMarkers.ZoneShareRegisterTicker()
  if not ElmsMarkers.zoneShareTickerRegistered then
    EVENT_MANAGER:RegisterForUpdate(ElmsMarkers.name .. "ZoneShare", ZONE_SHARE_TICK_MS, ElmsMarkers.ZoneShareTick)
    ElmsMarkers.zoneShareTickerRegistered = true
  end
end

function ElmsMarkers.ZoneShareUnregisterTicker()
  if ElmsMarkers.zoneShareTickerRegistered then
    EVENT_MANAGER:UnregisterForUpdate(ElmsMarkers.name .. "ZoneShare")
    ElmsMarkers.zoneShareTickerRegistered = nil
  end
end

function ElmsMarkers.ZoneShareAbort(notify)
  ElmsMarkers.zoneShareState = nil
  ElmsMarkers.ZoneShareUnregisterTicker()
  if notify then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Zone share aborted.")
  end
end

--------------------------------------------------------------------------------
-- Zone sync stream (protocol 331) - receiver side
--------------------------------------------------------------------------------

function ElmsMarkers.HandleZoneSyncMessage(unitTag, data)
  if not unitTag or not data then return end
  -- Ignore our own broadcasts (the game delivers them back to the sender).
  if AreUnitsEqual(unitTag, 'player') then return end
  -- Only accept syncs coming from the group leader.
  if unitTag ~= GetGroupLeaderUnitTag() then return end
  -- Markers are only applied while the user is subscribed to the leader's markers.
  if not ElmsMarkers.savedVars.subscribeToLead then return end

  local zone = data.zone
  local state = ElmsMarkers.zoneReceiveState

  if data.msgType == SYNC_MSG_HEADER then
    ElmsMarkers.zoneReceiveState = {
      sender = unitTag,
      zone = zone,
      total = data.totalCount,
      markers = {},
    }
  elseif data.msgType == SYNC_MSG_DATA then
    -- The data block can arrive without a HEADER if its frame was lost, so buffer it anyway.
    if not state or state.sender ~= unitTag or state.zone ~= zone then
      state = { sender = unitTag, zone = zone, total = data.totalCount, markers = {} }
      ElmsMarkers.zoneReceiveState = state
    end
    state.markers = data.marker or {}
    if state.total then
      state.total = math.max(state.total, data.totalCount)
    else
      state.total = data.totalCount
    end
  elseif data.msgType == SYNC_MSG_END then
    if not state or state.sender ~= unitTag or state.zone ~= zone then
      state = { sender = unitTag, zone = zone, total = data.totalCount, markers = {} }
    else
      state.total = data.totalCount
    end
    ElmsMarkers.zoneReceiveState = nil
    ElmsMarkers.ApplyZoneSync(state)
  end
end

-- Applies a finished zone sync and reports the result to the leader (always).
function ElmsMarkers.ApplyZoneSync(state)
  if not state or not state.total or state.total < 1 then return end

  local flat = {}
  local markers = state.markers or {}
  local receivedCount = 0
  for i = 1, state.total do
    local m = markers[i]
    if m and m.wX and m.wY and m.wZ and m.iconId then
      flat[#flat + 1] = { m.wX, m.wY, m.wZ, m.iconId }
      receivedCount = receivedCount + 1
    end
  end

  if receivedCount > 0 then
    ElmsMarkers.ReplaceZoneMarkers(state.zone, flat)
  end

  if receivedCount >= state.total then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Received all " .. state.total .. " markers for zone " .. state.zone .. " from the group lead.")
  else
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] WARNING: received only " .. receivedCount .. " of " .. state.total .. " markers for zone " .. state.zone .. " - NOT all markers arrived.")
  end
end

-- Replaces the marker set of a zone with the given list of {wX, wY, wZ, iconId} entries.
function ElmsMarkers.ReplaceZoneMarkers(zone, newMarkers)
  -- Remove existing icons of the zone.
  if ElmsMarkers.placedIcons[zone] then
    for k, v in pairs(ElmsMarkers.placedIcons[zone]) do
      if v and OSI and OSI.DiscardPositionIcon then
        OSI.DiscardPositionIcon(v)
      end
    end
  end
  ElmsMarkers.placedIcons[zone] = {}

  local newList = {}
  local isCurrentZone = zone == GetUnitRawWorldPosition("player")
  for i = 1, #newMarkers do
    local m = newMarkers[i]
    if m and m[1] and m[2] and m[3] and m[4] and ElmsMarkers.iconData[m[4]] then
      table.insert(newList, { m[1], m[2], m[3], m[4] })
      if isCurrentZone then
        ElmsMarkers.DoPlaceIcon(zone, m[1], m[2], m[3], ElmsMarkers.iconData[m[4]])
      end
    end
  end
  ElmsMarkers.savedVars.positions[zone] = newList
  ElmsMarkers.CreateConfigString()
end

--------------------------------------------------------------------------------
-- Rendezvous / publish helpers (unchanged behavior)
--------------------------------------------------------------------------------

function ElmsMarkers.PlaceRendezvousAt(location, isLeader)
  if not isLeader and not ElmsMarkers.savedVars.optIntoCommands then return end
  if not OSI or not OSI.CreatePositionIcon then return end
  local zone, wX, wY, wZ, iconId = unpack(location)
  local texture = ElmsMarkers.iconData[iconId]
  -- local zone, wX, wY, wZ = GetUnitRawWorldPosition( "player" )

  local iconSize = ElmsMarkers.savedVars.selectedIconSize / 64.0
  local iconPlacement = OSI.CreatePositionIcon( wX, wY, wZ, texture, iconSize * OSI.GetIconSize(), {1,1,1}, 2.5, function( data )
      data.offset = 1 + 1 * math.sin( GetGameTimeMilliseconds() / 1000 * 7 )
    end
  )
  PlaySound(SOUNDS.BATTLEGROUND_ONE_MINUTE_WARNING)
  ElmsMarkers.UI.announcementBannerLabel:SetText("[Elms Markers] REGROUP!")
  ElmsMarkers.UI.announcementBanner:SetHidden(false)

  zo_callLater(function() 
    OSI.DiscardPositionIcon(iconPlacement)
    ElmsMarkers.UI.announcementBannerLabel:SetText("[Elms Markers] Sample text")
    ElmsMarkers.UI.announcementBanner:SetHidden(true)
    end
  , 3500)

  return {zone, wX, wY, wZ, iconId}
end

function ElmsMarkers.PreparePublish(isAdd)
  local timeNow = GetGameTimeMilliseconds()
  if(ElmsMarkers.lastPingTime == nil or (timeNow - ElmsMarkers.lastPingTime > ElmsMarkers.PING_RATE)) then
    if AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
      local location
      if isAdd then
        location = ElmsMarkers.PlaceAtMe()
      else
        location = ElmsMarkers.RemoveNearMe()
      end

      -- RemoveNearMe() returns nil when no marker is close enough; sending nil would crash.
      if not location then
        CHAT_SYSTEM:AddMessage("[ElmsMarkers] " .. (isAdd and "Could not place a marker here." or "No marker found nearby to remove.") .. " Nothing published.")
        return nil
      end

      local sent = ElmsMarkers.SendMarkerData(location, isAdd, false)
      if sent then
        CHAT_SYSTEM:AddMessage("[ElmsMarkers] " .. (isAdd and "Marker published to the group." or "Marker removal published to the group."))
      end
      return location
    else
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] You must be the group lead to publish markers!")
    end
  else
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] You're publishing too quickly! Publish not sent, try again later.")
  end
end

function ElmsMarkers.PrepareRendezvous()
  local timeNow = GetGameTimeMilliseconds()
  if(ElmsMarkers.lastPingTime == nil or (timeNow - ElmsMarkers.lastPingTime > ElmsMarkers.PING_RATE)) then
    if AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
      local zone, wX, wY, wZ = GetUnitRawWorldPosition("player")
      local iconId = 13 --arrow
      ElmsMarkers.SendMarkerData({zone, wX, wY, wZ, iconId}, true, true)
      ElmsMarkers.PlaceRendezvousAt({zone, wX, wY, wZ, iconId}, true)
    else
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] You must be the group lead to send group commands!")
    end
  else 
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] You're sending group commands too quickly! Command not sent, try again later.")
  end
end

function ElmsMarkers.RemoveExactMarkerAt(location)
  local zone, wX, wY, wZ = unpack(location)
  local zoneIcons = ElmsMarkers.placedIcons[zone]
  if(not zoneIcons) then return end

  for k,v in pairs(ElmsMarkers.savedVars.positions[zone]) do
    if v[1] == wX and v[2] == wY and v[3] == wZ then
      ElmsMarkers.savedVars.positions[zone][k] = nil
      ElmsMarkers.CreateConfigString()
    end
  end

  for k, v in pairs(ElmsMarkers.placedIcons[zone]) do
    if v.x == wX and v.y == wY and v.z == wZ then
      OSI.DiscardPositionIcon(v)
      ElmsMarkers.placedIcons[zone][k] = nil
    end
  end
end