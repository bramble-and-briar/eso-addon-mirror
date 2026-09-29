-- Scrollkeeper Provision Member: Core tracking/evaluation logic

-- Local references
local Scrollkeeper = Scrollkeeper
local SF = Scrollkeeper.Framework
local SF_Set = Scrollkeeper.Settings

if type(SF) ~= "table" or type(SF_Set) ~= "table" then
  d(SF.func._L("ScrollkeeperProvisionMember", "ERROR_FRAMEWORK_MISSING"))
  return
end

-- Initialize module
Scrollkeeper.ProvisionMember = Scrollkeeper.ProvisionMember or { Name = "ScrollkeeperProvisionMember", Version = "1" }
local _addon = Scrollkeeper.ProvisionMember

-- Backward compatibility (DEPRECATED)
_G.ScrollkeeperProvisionMember = Scrollkeeper.ProvisionMember

local DEBUG_FILTERS = false  -- Set to true for debugging

-- Ensure the API table exists
SF.ProvisionMember = SF.ProvisionMember or {}
local PM = SF.ProvisionMember

-- Shared state/helpers consumed by ScrollkeeperProvisionMemberUI and ScrollkeeperProvisionMemberCommands
PM.Internal = PM.Internal or {}

-- LibHistoire integration for accurate guild join times
local LibHistoire = LibHistoire
PM.Internal.histoireReady = false

-- 🧠 Settings defaults
PM.Internal.defaults = {
  enabled = false,
  trackingDays = 30,
  autoTag = true,
  notifyOnJoin = true,
  taggedMembers = {},
  guildSettings = {},
  processedMembers = {},
}

-- Get settings using unified system
function PM.Internal.getSettings()
  -- Safe guards: framework table and required method must exist
  if type(SF) ~= "table" or type(SF.getModuleSettings) ~= "function" then
    local safe = {}
    for k, v in pairs(PM.Internal.defaults) do safe[k] = v end
    return safe
  end

  -- Defensive account name retrieval
  local accountName = (type(GetDisplayName) == "function") and GetDisplayName() or "UnknownAccount"
  if accountName == "" then accountName = "UnknownAccount" end
  local accountKey = _addon.Name .. "_" .. accountName

  -- Call framework method but guard the result
  local ok, settings = pcall(SF.getModuleSettings, accountKey, PM.Internal.defaults)
  if not ok or type(settings) ~= "table" then
    local safe = {}
    for k, v in pairs(PM.Internal.defaults) do safe[k] = v end
    return safe
  end

  -- Ensure required subtables exist
  settings.taggedMembers = settings.taggedMembers or {}
  settings.guildSettings = settings.guildSettings or {}
  settings.processedMembers = settings.processedMembers or {}

  return settings
end

function PM.promoteMember(guildName, memberName, notes)
  local settings = PM.Internal.getSettings()
  if not settings or not guildName or not memberName then return false end
  if settings.taggedMembers[guildName] and settings.taggedMembers[guildName][memberName] then
    settings.taggedMembers[guildName][memberName].status = SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED")
    settings.taggedMembers[guildName][memberName].promotedDate = GetTimeStamp()
    settings.taggedMembers[guildName][memberName].promotedBy = GetUnitName("player")
    if notes then
      local currentNotes = settings.taggedMembers[guildName][memberName].notes or ""
      settings.taggedMembers[guildName][memberName].notes = currentNotes .. " | Promoted: " .. notes
    end
    return true
  end
  return false
end

function PM.removeMember(guildName, memberName, reason)
  local settings = PM.Internal.getSettings()
  if not settings or not guildName or not memberName then return false end

  if settings.taggedMembers[guildName] and settings.taggedMembers[guildName][memberName] then
    -- Get the tracking reason before removing
    local trackingReason = settings.taggedMembers[guildName][memberName].reason or SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK")

    -- Remove from active tracking
    settings.taggedMembers[guildName][memberName] = nil

    -- Mark as processed with the reason
    settings.processedMembers = settings.processedMembers or {}
    settings.processedMembers[guildName] = settings.processedMembers[guildName] or {}
    settings.processedMembers[guildName][memberName] = {
      reason = trackingReason,
      removedTime = GetTimeStamp(),
      removedBy = GetUnitName("player")
    }
    return true
  end
  return false
end

-- Get per-guild settings with enhanced filters
function PM.Internal.getGuildSettings(guildName)
  if not guildName or type(guildName) ~= "string" or guildName == "" then
    return {
      enabled = false,
      autoTag = false,
      notifyOnJoin = false,
      trackingDays = 30,
      goldDonationFilter = {
        enabled = false,
        requiredAmount = 5000,
        timePeriodDays = 30,
        timeUnit = "days" -- "days", "weeks", "months"
      },
      inactivityFilter = {
        enabled = false,
        inactiveDays = 30
      },
      donorFilter = {
        enabled = false,
        minimumAmount = 1000,
        timePeriodDays = 30
      }
    }
  end

  local settings = PM.Internal.getSettings()
  settings.guildSettings = settings.guildSettings or {}

  if not settings.guildSettings[guildName] then
    settings.guildSettings[guildName] = {
      enabled = true,
      autoTag = true,
      notifyOnJoin = true,
      trackingDays = 30,
      goldDonationFilter = {
        enabled = false,
        requiredAmount = 5000,
        timePeriodDays = 30,
        timeUnit = "days"
      },
      inactivityFilter = {
        enabled = false,
        inactiveDays = 30
      },
      donorFilter = {
        enabled = false,
        minimumAmount = 1000,
        timePeriodDays = 30
      }
    }
  else
    -- Ensure new filters exist
    if not settings.guildSettings[guildName].inactivityFilter then
      settings.guildSettings[guildName].inactivityFilter = {
        enabled = false,
        inactiveDays = 30
      }
    end
    if not settings.guildSettings[guildName].donorFilter then
      settings.guildSettings[guildName].donorFilter = {
        enabled = false,
        minimumAmount = 1000,
        timePeriodDays = 30
      }
    end

    -- Legacy gold filter migration
    local gdf = settings.guildSettings[guildName].goldDonationFilter
    if not gdf then
      settings.guildSettings[guildName].goldDonationFilter = { enabled = false, requiredAmount = 5000, timePeriodDays = 30, timeUnit = "days" }
    else
      if not gdf.requiredAmount then gdf.requiredAmount = gdf.minAmount or 5000 end
      if not gdf.timePeriodDays then gdf.timePeriodDays = gdf.daysSinceLastDonation or 30 end
      if not gdf.timeUnit then gdf.timeUnit = "days" end
      gdf.minAmount = nil
      gdf.daysSinceLastDonation = nil
      gdf.checkFrequency = nil
    end
  end

  return settings.guildSettings[guildName]
end

-- Check for Advanced Member Tooltip availability
PM.Internal.AMTAvailable = false
-- Enhanced getMemberJoinTime with Data module integration
local function getMemberJoinTime(guildId, displayName)
  local guildName = GetGuildName(guildId)

  -- Priority 1: Try Advanced Member Tooltip
  if PM.Internal.AMTAvailable and AMT.savedData and AMT.savedData[guildName] then
    local memberKey = string.lower(displayName)
    local amtMemberData = AMT.savedData[guildName][memberKey]

    if amtMemberData and amtMemberData.timeJoined and amtMemberData.timeJoined > 0 then
      return amtMemberData.timeJoined, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_AMT")
    end
  end

  -- Priority 2: Try ScrollkeeperData event cache
  if SF.Data and SF.Data.getEvents then
    local events = SF.Data.getEvents(guildName, "roster", 10000)

    -- Find join event for this member
    for _, event in ipairs(events) do
      if event.eventType == GUILD_HISTORY_ROSTER_EVENT_JOIN then
        local eventDisplayName = event.info.displayName or event.info.targetDisplayName
        if eventDisplayName == displayName then
          return event.timestamp, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_DATA")
        end
      end
    end
  end

  -- Priority 3: Try LibHistoire (if available)
  if LibHistoire and PM.Internal.histoireReady then
    local guildData = LibHistoire:GetGuildHistoryProcessor(guildId)
    if guildData and guildData.GetMemberJoinTime then
      local success, joinTime = pcall(guildData.GetMemberJoinTime, guildData, displayName)
      if success and joinTime and joinTime > 0 then
        return joinTime, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_HISTOIRE")
      end
    end
  end

  return nil, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_UNKNOWN")
end

-- Check member's gold donations using ScrollkeeperData
function PM.Internal.checkMemberDonations(guildId, guildName, displayName, requiredAmount, timePeriodDays, debugMode)
  if not guildId or not guildName or not displayName then
    if debugMode then
      d(string.format("[PM Debug] checkMemberDonations: Missing params - guildId:%s, guildName:%s, displayName:%s",
        tostring(guildId), tostring(guildName), tostring(displayName)))
    end
    return false, 0
  end

  if not SF.Data or not SF.Data.getEvents then
    if debugMode then
      d("[PM Debug] checkMemberDonations: SF.Data.getEvents not available")
    end
    return false, 0
  end

  -- Get ALL bankedGold events
  local allEvents = SF.Data.getEvents(guildName, "bankedGold", 999999)

  if not allEvents or #allEvents == 0 then
    if debugMode then
      d(string.format("[PM Debug] checkMemberDonations: No events found for guild %s", guildName))
    end
    return false, 0
  end

  local now = GetTimeStamp()
  local cutoffTime = now - (timePeriodDays * 86400)
  local totalInPeriod = 0
  local depositsFound = 0
  local allDepositsForMember = 0
  local oldestEventTime = nil
  local newestEventTime = nil

  if debugMode then
    d(string.format("[PM Debug] Checking %s in %s: Required=%d gold in last %d days",
      displayName, guildName, requiredAmount, timePeriodDays))
    d(string.format("[PM Debug] Current timestamp: %d, Cutoff timestamp: %d", now, cutoffTime))
    d(string.format("[PM Debug] Cutoff date: %s", os.date("%Y-%m-%d %H:%M:%S", cutoffTime)))
    d(string.format("[PM Debug] Total bankedGold events to scan: %d", #allEvents))
  end

  -- Filter and sum deposits
  for _, event in ipairs(allEvents) do
    if event.eventType == GUILD_HISTORY_BANKED_CURRENCY_EVENT_DEPOSITED then
      local eventDisplayName = event.info.displayName or event.info.actingDisplayName

      -- Normalize both names for comparison (remove @ if present)
      local normalizedEventName = eventDisplayName
      local normalizedSearchName = displayName

      if normalizedEventName and string.sub(normalizedEventName, 1, 1) == "@" then
        normalizedEventName = string.sub(normalizedEventName, 2)
      end
      if normalizedSearchName and string.sub(normalizedSearchName, 1, 1) == "@" then
        normalizedSearchName = string.sub(normalizedSearchName, 2)
      end

      if normalizedEventName == normalizedSearchName then
        allDepositsForMember = allDepositsForMember + 1
        local eventAmount = event.info.amount or 0
        local eventDate = os.date("%Y-%m-%d %H:%M:%S", event.timestamp)

        if not oldestEventTime or event.timestamp < oldestEventTime then
          oldestEventTime = event.timestamp
        end
        if not newestEventTime or event.timestamp > newestEventTime then
          newestEventTime = event.timestamp
        end

        if event.timestamp >= cutoffTime then
          totalInPeriod = totalInPeriod + eventAmount
          depositsFound = depositsFound + 1
          if debugMode then
            d(string.format("[PM Debug]   IN PERIOD: %d gold on %s (timestamp: %d)",
              eventAmount, eventDate, event.timestamp))
          end
        else
          if debugMode then
            d(string.format("[PM Debug]   TOO OLD: %d gold on %s (timestamp: %d)",
              eventAmount, eventDate, event.timestamp))
          end
        end
      end
    end
  end

  if debugMode then
    if allDepositsForMember > 0 then
      d(string.format("[PM Debug] Found %d total deposits for %s (oldest: %s, newest: %s)",
        allDepositsForMember,
        displayName,
        oldestEventTime and os.date("%Y-%m-%d", oldestEventTime) or "none",
        newestEventTime and os.date("%Y-%m-%d", newestEventTime) or "none"))
      d(string.format("[PM Debug] In-period: %d deposits = %d gold | Required: %d gold",
        depositsFound, totalInPeriod, requiredAmount))
    else
      d(string.format("[PM Debug] No deposits found for %s in any time period", displayName))
    end

    local meetsRequirement = (totalInPeriod >= requiredAmount)
    d(string.format("[PM Debug] RESULT: %s %s requirement (%d >= %d = %s)",
      displayName,
      meetsRequirement and "MEETS" or "FAILS",
      totalInPeriod,
      requiredAmount,
      tostring(meetsRequirement)))
  end

  -- Returns TRUE if they meet/exceed requirement (don't track)
  -- Returns FALSE if they don't meet requirement (track them)
  local meetsRequirement = (totalInPeriod >= requiredAmount)

  return meetsRequirement, totalInPeriod
end

-- Check member inactivity using ESO's native last online data
function PM.Internal.checkMemberInactivity(guildId, displayName, inactiveDays, debugMode)
  if not guildId or not displayName or not inactiveDays then
    return false, 0
  end

  -- Search guild roster for this member
  for i = 1, GetNumGuildMembers(guildId) do
    local memberName, _, _, _, lastOnline = GetGuildMemberInfo(guildId, i)
    if memberName == displayName then
      -- CRITICAL FIX: ESO's GetGuildMemberInfo returns lastOnline in SECONDS since epoch
      -- but it's actually the time SINCE last online, not a timestamp
      -- We need to get the actual last online time
      local now = GetTimeStamp()
      local secondsSinceOnline = lastOnline
      local daysSinceOnline = math.floor(secondsSinceOnline / 86400)

      if debugMode then
        d(string.format("[PM Inactive] %s: Last online %d seconds ago (%.1f days)",
          displayName, secondsSinceOnline, secondsSinceOnline / 86400))
        d(string.format("[PM Inactive]   Threshold: %d days", inactiveDays))
        d(string.format("[PM Inactive]   Result: %s",
          daysSinceOnline >= inactiveDays and "INACTIVE - TRACK" or "ACTIVE - SKIP"))
      end

      -- Return true if they've been offline longer than threshold
      local isInactive = (daysSinceOnline >= inactiveDays)
      return isInactive, daysSinceOnline
    end
  end

  -- Member not found in roster
  if debugMode then
    d(string.format("[PM Inactive] %s: NOT FOUND in guild roster", displayName))
  end
  return false, 0
end

-- Simplified probationary rank detection - only check rank position
local function isMemberInProbationaryRank(guildId, displayName)
  if not guildId or not displayName then return false end

  -- Get the total number of ranks for this guild
  local numRanks = GetNumGuildRanks(guildId)
  if numRanks == 0 then return false end

  -- Find the member and check their rank
  for i = 1, GetNumGuildMembers(guildId) do
    local memberName, _, rankIndex = GetGuildMemberInfo(guildId, i)
    if memberName == displayName then
      -- ESO uses 1-based indexing where 1 = Guild Master (highest authority)
      -- Higher numbers = lower authority, so numRanks = lowest rank (entry level)
      local isProbationary = (rankIndex == numRanks)

      return isProbationary
    end
  end

  return false
end

function PM.tagMemberAsProvisional(guildName, memberName, notes, reason, actualJoinTime)
  local settings = PM.Internal.getSettings()
  if not settings or not guildName or not memberName then return false end
  settings.taggedMembers[guildName] = settings.taggedMembers[guildName] or {}

    -- Determine status based on reason
  local status = SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROVISIONAL")
  if reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
    status = SF.func._L("ScrollkeeperProvisionMember", "STATUS_PENDING_DONATION")
  elseif reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
    status = SF.func._L("ScrollkeeperProvisionMember", "STATUS_INACTIVE")
  elseif reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR") then
    status = SF.func._L("ScrollkeeperProvisionMember", "STATUS_DONOR")
  end

  -- Generate useful notes based on reason
  local autoNotes = notes or ""

  if reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
    -- For gold filter, show their current donation total
    if SF.Data and SF.Data.getMemberDonationInfo then
      local donationInfo = SF.Data.getMemberDonationInfo(guildName, memberName)
      if donationInfo and donationInfo.totalDonated then
        autoNotes = string.format("Donated: %d gold", donationInfo.totalDonated)
      else
        autoNotes = "No donations found"
      end
    end

  elseif reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR") then
  -- For donor filter, use the same calculation as the filter check
  autoNotes = "Active Donor" -- Default fallback
  
  if SF.Data and SF.Data.getEvents then
    local guildId = nil
    for i = 1, GetNumGuilds() do
      if GetGuildName(GetGuildId(i)) == guildName then
        guildId = GetGuildId(i)
        break
      end
    end
    
    if guildId then
      local guildSettings = PM.Internal.getGuildSettings(guildName)
      if guildSettings and guildSettings.donorFilter then
        -- Safely call checkMemberDonations with error handling
        local success, meetsReq, totalDonated = pcall(function()
          return PM.Internal.checkMemberDonations(
            guildId,
            guildName,
            memberName,
            guildSettings.donorFilter.minimumAmount or 1000,
            guildSettings.donorFilter.timePeriodDays or 30,
            false
          )
        end)
        
        if success and totalDonated and totalDonated > 0 then
          autoNotes = string.format("Total donated: %d gold", totalDonated)
        elseif success and guildSettings.donorFilter.minimumAmount then
          autoNotes = string.format("Donor (min: %d gold)", guildSettings.donorFilter.minimumAmount)
        end
      end
    end
  end

  elseif reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") then
    -- For inactive filter, leave notes blank (days column shows offline time)
    autoNotes = ""
  end

  -- Don't add generic "auto-tagged" message. Only use the specific notes generated above.

  settings.taggedMembers[guildName][memberName] = {
    joinDate = GetTimeStamp(),
    actualJoinTime = actualJoinTime or GetTimeStamp(),
    notes = autoNotes,
    status = status,
    reason = reason or SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK"),
    taggedBy = GetUnitName("player")
  }

  -- Remove from processed list so they can be tracked again
  settings.processedMembers = settings.processedMembers or {}
  settings.processedMembers[guildName] = settings.processedMembers[guildName] or {}
  settings.processedMembers[guildName][memberName] = nil

  return true
end

-- Enhanced member filtering
local function shouldTrackMember(guildId, guildName, displayName, force)
  if not guildName or guildName == "" or not displayName then
    return false, nil, nil
  end

  local guildSettings = PM.Internal.getGuildSettings(guildName)
  if not guildSettings or not guildSettings.enabled then
    return false, nil, nil
  end

  local settings = PM.Internal.getSettings()
  if not settings then return false, nil, nil end

  -- CRITICAL: Check processed members FIRST
  if settings.processedMembers and settings.processedMembers[guildName] and settings.processedMembers[guildName][displayName] then
    local processedData = settings.processedMembers[guildName][displayName]

    if type(processedData) == "table" and processedData.reason then
      -- Rank removals are PERMANENT
      if processedData.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") then
        return false, nil, nil
      end
      -- Gold, inactive, and donor removals can be re-evaluated after 7 days
      if processedData.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") or
         processedData.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE") or
         processedData.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR") then
        local daysSinceRemoval = (GetTimeStamp() - (processedData.removedTime or 0)) / 86400
        if daysSinceRemoval < 7 then
          return false, nil, nil
        end
        -- Cooldown expired, clear and continue
        settings.processedMembers[guildName][displayName] = nil
      end
    else
      -- Legacy format - treat as permanent
      return false, nil, nil
    end
  end

  -- Check if already tracked - be smart about updates
  local memberData = settings.taggedMembers and settings.taggedMembers[guildName] and settings.taggedMembers[guildName][displayName]
  if memberData and memberData.status ~= SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
    -- If not forcing, skip already-tracked members
    if not force then
      return false, nil, nil
    end
    -- If forcing, we'll check below if the reason has changed
    -- and only update if necessary
  end

  -- COLLECT ALL MATCHING FILTERS
  -- We check ALL filters and use the highest priority match
  local matchedFilters = {}

  -- FILTER 1: Probationary rank (RANK-based tracking) - HIGHEST PRIORITY
  local isProbationary = isMemberInProbationaryRank(guildId, displayName)
  
  if isProbationary then
    local actualJoinTime, source = getMemberJoinTime(guildId, displayName)
    
    table.insert(matchedFilters, {
      priority = 1,
      reason = SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK"),
      joinTime = actualJoinTime
    })
    
    if force and DEBUG_FILTERS then
      local daysSinceJoin = actualJoinTime and math.floor((GetTimeStamp() - actualJoinTime) / 86400) or "unknown"
      d(string.format("[PM Rank] %s is probationary (%s days since join)", displayName, tostring(daysSinceJoin)))
    end
  end

  -- FILTER 2: Gold donation filter (checks ALL members, not just probationary)
  if guildSettings.goldDonationFilter and guildSettings.goldDonationFilter.enabled then
    -- Check if data is ready
    if SF.Data and SF.Data.isReady and SF.Data.isReady() then
      local allEvents = SF.Data.getEvents(guildName, "bankedGold", 999999)
      if allEvents and #allEvents > 0 then
        -- Check history depth - be lenient, allow 90% of required days
        local oldestTimestamp = nil
        for _, event in ipairs(allEvents) do
          if not oldestTimestamp or event.timestamp < oldestTimestamp then
            oldestTimestamp = event.timestamp
          end
        end

        local leniency = 0.9
        local lenientHistoryTime = GetTimeStamp() - (guildSettings.goldDonationFilter.timePeriodDays * 86400 * leniency)

        if oldestTimestamp and oldestTimestamp <= lenientHistoryTime then
          local meetsRequirement, totalDonated = PM.Internal.checkMemberDonations(
            guildId,
            guildName,
            displayName,
            guildSettings.goldDonationFilter.requiredAmount,
            guildSettings.goldDonationFilter.timePeriodDays,
            false
          )

          -- If they DON'T meet the requirement, track them for gold reasons
          if not meetsRequirement then
            table.insert(matchedFilters, {
              priority = 3,
              reason = SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD"),
              joinTime = nil
            })
          end
        end
      end
    end
  end

  -- FILTER 3: Inactivity filter (checks ALL members)
  if guildSettings.inactivityFilter and guildSettings.inactivityFilter.enabled then
    if force and DEBUG_FILTERS then
      d(string.format("[PM Inactive] === CHECKING %s ===", displayName))
    end

    local isInactive, daysSince = PM.Internal.checkMemberInactivity(
      guildId,
      displayName,
      guildSettings.inactivityFilter.inactiveDays,
      false
    )

    if isInactive then
      if force and DEBUG_FILTERS then
        d(string.format("[PM Inactive] %s is INACTIVE (%d days) - TRACK", displayName, daysSince))
      end
      
      table.insert(matchedFilters, {
        priority = 4,
        reason = SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE"),
        joinTime = nil
      })
    else
      if force and DEBUG_FILTERS then
        d(string.format("[PM Inactive] %s is ACTIVE (%d days offline) - SKIP", displayName, daysSince))
      end
    end
  end

  -- FILTER 4: Donor filter (tracks members who MEET minimum to recognize them)
  if guildSettings.donorFilter and guildSettings.donorFilter.enabled then
    if force and DEBUG_FILTERS then
      d(string.format("[PM Donor] === CHECKING %s ===", displayName))
      d(string.format("[PM Donor] Filter enabled: minimum=%d gold, period=%d days",
        guildSettings.donorFilter.minimumAmount, guildSettings.donorFilter.timePeriodDays))
    end

    -- Check if data is ready
    if SF.Data and SF.Data.isReady and SF.Data.isReady() then
      local allEvents = SF.Data.getEvents(guildName, "bankedGold", 999999)
      if allEvents and #allEvents > 0 then
        -- Check history depth
        local oldestTimestamp = nil
        for _, event in ipairs(allEvents) do
          if not oldestTimestamp or event.timestamp < oldestTimestamp then
            oldestTimestamp = event.timestamp
          end
        end

        local leniency = 0.9
        local lenientHistoryTime = GetTimeStamp() - (guildSettings.donorFilter.timePeriodDays * 86400 * leniency)

        if oldestTimestamp and oldestTimestamp <= lenientHistoryTime then
          local meetsMinimum, totalDonated = PM.Internal.checkMemberDonations(
            guildId,
            guildName,
            displayName,
            guildSettings.donorFilter.minimumAmount,
            guildSettings.donorFilter.timePeriodDays,
            false
          )

          if force and DEBUG_FILTERS then
            d(string.format("[PM Donor] Result: donated %d gold (minimum: %d) - %s",
              totalDonated, guildSettings.donorFilter.minimumAmount,
              meetsMinimum and "MEETS - TRACK" or "FAILS - SKIP"))
          end

          -- Track them if they DO meet the minimum
          if meetsMinimum then
            table.insert(matchedFilters, {
              priority = 2,
              reason = SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR"),
              joinTime = nil
            })
          end
        end
      end
    end
  end

  -- Now decide which filter to use based on priority
  -- Priority order: 1=Rank (highest), 2=Donor, 3=Gold, 4=Inactive (lowest)
  if #matchedFilters > 0 then
    -- Sort by priority (lower number = higher priority)
    table.sort(matchedFilters, function(a, b) return a.priority < b.priority end)
    
    local winner = matchedFilters[1]
    
    -- Check if already tracked with this reason (avoid unnecessary updates)
    if memberData and memberData.reason == winner.reason then
      return false, nil, nil
    end
    
    return true, winner.reason, winner.joinTime
  end

  -- No filters matched
  return false, nil, nil
end

-- Re-evaluate existing tracked members against current data
function PM.reEvaluateMembers(guildName)
  local settings = PM.Internal.getSettings()
  if not settings or not settings.taggedMembers then return 0 end

  local guildMembers = settings.taggedMembers[guildName] or {}
  local toRemove = {}
  local reEvaluatedCount = 0

  -- Find the guild ID
  local guildId = nil
  for i = 1, GetNumGuilds() do
    if GetGuildName(GetGuildId(i)) == guildName then
      guildId = GetGuildId(i)
      break
    end
  end

  if not guildId then return 0 end

  for memberName, data in pairs(guildMembers) do
    if data and type(data) == "table" and data.status ~= SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
      -- If they're tracked for gold reasons, re-check their donation status
      if data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
        local guildSettings = PM.Internal.getGuildSettings(guildName)
        if guildSettings and guildSettings.goldDonationFilter and guildSettings.goldDonationFilter.enabled then
          local meetsRequirement = PM.Internal.checkMemberDonations(
            guildId,
            guildName,
            memberName,
            guildSettings.goldDonationFilter.requiredAmount,
            guildSettings.goldDonationFilter.timePeriodDays
            -- debugMode defaults to false (nil)
          )

          if meetsRequirement then
            -- They now meet the requirement - remove them
            table.insert(toRemove, memberName)
            reEvaluatedCount = reEvaluatedCount + 1
          end
        end
      end
    end
  end

  -- Remove members who now meet requirements
  for _, memberName in ipairs(toRemove) do
    PM.removeMember(guildName, memberName, "Met gold requirement")
  end

  return reEvaluatedCount
end

-- Create a dedicated function to calculate accurate days since join
function PM.Internal.getAccurateDaysSinceJoin(guildId, guildName, memberName, storedData)
  local now = GetTimeStamp()

  -- 1. Check Advanced Member Tooltip first (most reliable)
  if PM.Internal.AMTAvailable and AMT.savedData and AMT.savedData[guildName] then
    local memberKey = string.lower(memberName)
    local amtMemberData = AMT.savedData[guildName][memberKey]

    if amtMemberData and amtMemberData.timeJoined and amtMemberData.timeJoined > 0 then
      local daysSince = math.floor((now - amtMemberData.timeJoined) / 86400)
      if daysSince >= 0 and daysSince <= 3650 then -- 10 year sanity check
        -- Update our stored data with AMT's accurate time
        storedData.actualJoinTime = amtMemberData.timeJoined
        return daysSince, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_AMT")
      end
    end
  end

  -- 2. Check if we have validated stored time
  if storedData.actualJoinTime and storedData.actualJoinTime > 0 then
    local daysSince = math.floor((now - storedData.actualJoinTime) / 86400)
    if daysSince >= 0 and daysSince <= 3650 then
      return daysSince, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_STORED")
    end
  end

  -- 3. Try LibHistoire
  if LibHistoire and PM.Internal.histoireReady then
    local guildData = LibHistoire:GetGuildHistoryProcessor(guildId)
    if guildData and guildData.GetMemberJoinTime then
      local success, joinTime = pcall(guildData.GetMemberJoinTime, guildData, memberName)
      if success and joinTime and joinTime > 0 then
        local daysSince = math.floor((now - joinTime) / 86400)
        if daysSince >= 0 and daysSince <= 3650 then
          storedData.actualJoinTime = joinTime
          return daysSince, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_HISTOIRE")
        end
      end
    end
  end

  -- 4. Try ScrollkeeperData donation timing
  if SF.Data and SF.Data.getMemberDonationInfo then
    local donationData = SF.Data.getMemberDonationInfo(guildName, memberName)
    if donationData and donationData.firstDonationTime and donationData.firstDonationTime > 0 then
      local daysSince = math.floor((now - donationData.firstDonationTime) / 86400)
      if daysSince >= 0 and daysSince <= 3650 then
        storedData.actualJoinTime = donationData.firstDonationTime
        return daysSince, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_DONATION")
      end
    end
  end

  -- 5. Use tagged time as last resort
  if storedData.joinDate then
    local daysSince = math.floor((now - storedData.joinDate) / 86400)
    if daysSince >= 0 and daysSince <= 3650 then
      return daysSince, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_TAGGED")
    end
  end

  -- Complete unknown
  return nil, SF.func._L("ScrollkeeperProvisionMember", "SOURCE_UNKNOWN")
end

-- Clear existing bad data function
function PM.clearBadData()
  local settings = PM.Internal.getSettings()
  if not settings or not settings.taggedMembers then return 0 end

  local clearedCount = 0
  for guildName, members in pairs(settings.taggedMembers) do
    if members and type(members) == "table" then
      local toRemove = {}
      for memberName, data in pairs(members) do
        if data and type(data) == "table" and data.status ~= SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
          -- Find the guild ID for this guild name
          local guildId = nil
          for i = 1, GetNumGuilds() do
            if GetGuildName(GetGuildId(i)) == guildName then
              guildId = GetGuildId(i)
              break
            end
          end

          if guildId then
            local shouldTrack, reason, actualJoinTime = shouldTrackMember(guildId, guildName, displayName, force)
            if not shouldTrack then
              table.insert(toRemove, memberName)
              clearedCount = clearedCount + 1
            end
          else
            table.insert(toRemove, memberName)
            clearedCount = clearedCount + 1
          end
        end
      end

      for _, memberName in ipairs(toRemove) do
        members[memberName] = nil
      end
    end
  end

  return clearedCount
end

-- Clear only gold-based processed members (allow re-evaluation)
function PM.clearGoldProcessed()
  local settings = PM.Internal.getSettings()
  if not settings or not settings.processedMembers then return 0 end

  local clearedCount = 0
  for guildName, members in pairs(settings.processedMembers) do
    if members and type(members) == "table" then
      local toRemove = {}
      for memberName, data in pairs(members) do
        if type(data) == "table" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD") then
          table.insert(toRemove, memberName)
          clearedCount = clearedCount + 1
        end
      end

      for _, memberName in ipairs(toRemove) do
        members[memberName] = nil
      end
    end
  end

  return clearedCount
end

-- Scan for new members
local function scanForNewMembers(guildId, force)
  if not guildId then return {} end

  local settings = PM.Internal.getSettings()
  if not settings or not settings.enabled then return {} end

  local guildName = GetGuildName(guildId)
  if not guildName then return {} end

  local guildSettings = PM.Internal.getGuildSettings(guildName)
  if not guildSettings or not guildSettings.enabled then
    return {}
  end

  local newMembers = {}

  -- Scan current roster
  for i = 1, GetNumGuildMembers(guildId) do
    local displayName = GetGuildMemberInfo(guildId, i)
    if displayName and displayName ~= "" then
      local shouldTrack, reason, actualJoinTime = shouldTrackMember(guildId, guildName, displayName, true)  -- Force re-evaluation
      if shouldTrack then
        table.insert(newMembers, displayName)
        
        if guildSettings.autoTag then
          PM.tagMemberAsProvisional(guildName, displayName, SF.func._L("ScrollkeeperProvisionMember", "AUTO_TAG_SCAN"), reason, actualJoinTime)
        end
      end
    end
  end

  return newMembers
end

-- Initialize LibHistoire integration
local function initializeLibHistoire()
  if LibHistoire then
    LibHistoire:RegisterCallback("OnHistoireReady", function()
      PM.Internal.histoireReady = true
      d(SF.func._L("ScrollkeeperProvisionMember", "SUCCESS_HISTOIRE_READY"))
    end)
  end
end

-- Event handlers
function _addon.guildMemberAdded(_, guildId, accountName)
  local settings = PM.Internal.getSettings()
  if not settings or not settings.enabled then return end

  local guildName = GetGuildName(guildId)
  if not guildName then return end

  local guildSettings = PM.Internal.getGuildSettings(guildName)
  if not guildSettings or not guildSettings.enabled then return end

  -- Check if we should track this member
  local shouldTrack, reason, actualJoinTime = shouldTrackMember(guildId, guildName, accountName)
  if shouldTrack then
    local joinTime = GetTimeStamp() -- For new joins, use current time
    if guildSettings.autoTag then
      PM.tagMemberAsProvisional(guildName, accountName, SF.func._L("ScrollkeeperProvisionMember", "AUTO_TAG_ONLINE"), reason, joinTime)
    end
    
    -- NO notification here - users will see updates when they open the provision window or run manual scans
  end
end

-- Event management
function _addon:EnableEvents()
  EVENT_MANAGER:RegisterForEvent(_addon.Name, EVENT_GUILD_MEMBER_ADDED, _addon.guildMemberAdded)
  initializeLibHistoire()
  -- NO automatic scanning - user must manually scan from the window
end

function _addon:DisableEvents()
  EVENT_MANAGER:UnregisterForEvent(_addon.Name, EVENT_GUILD_MEMBER_ADDED)
end

-- Manual scan function
function PM.manualScan()
  -- Check if data is ready
  if not SF.Data or not SF.Data.isReady or not SF.Data.isReady() then
    d("[ProvisionMember] ERROR: Guild history data not ready yet. Wait a moment and try again.")
    return
  end

  -- Re-evaluate existing gold-tracked members
  local reEvaluatedTotal = 0
  for i = 1, GetNumGuilds() do
    local guildName = GetGuildName(GetGuildId(i))
    if guildName then
      reEvaluatedTotal = reEvaluatedTotal + PM.reEvaluateMembers(guildName)
    end
  end

  -- Clear bad data
  local clearedCount = PM.clearBadData()

  -- Scan for new members (force=false to disable debug spam)
  local totalNewMembers = 0
  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local newMembers = scanForNewMembers(guildId, false) -- Don't spam debug
    totalNewMembers = totalNewMembers + #newMembers
  end

  -- Single completion message
  d(string.format(SF.func._L("ScrollkeeperProvisionMember", "LOG_SCAN_COMPLETE"), clearedCount, totalNewMembers))

  if reEvaluatedTotal > 0 then
    d(string.format("[ProvisionMember] Re-evaluated: %d members now meet requirements", reEvaluatedTotal))
  end
end

-- Get provisional member report
function PM.getProvisionalReport(guildName)
  if not guildName then return { totalTracked = 0, withinProbation = 0, overdue = 0, recent = {}, promoted = 0 } end
  local settings = PM.Internal.getSettings()
  if not settings or not settings.taggedMembers then return { totalTracked = 0, withinProbation = 0, overdue = 0, recent = {}, promoted = 0 } end
  local guildMembers = settings.taggedMembers[guildName] or {}
  local guildSettings = PM.Internal.getGuildSettings(guildName)

  local report = {
    totalTracked = 0,
    withinProbation = 0,
    overdue = 0,
    recent = {},
    promoted = 0
  }

  local now = GetTimeStamp()
  local dayInSeconds = 86400
  local maxDays = guildSettings.trackingDays or 30

  for memberName, data in pairs(guildMembers) do
    if data and type(data) == "table" then
      report.totalTracked = report.totalTracked + 1

      if data.status == SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROMOTED") then
        report.promoted = report.promoted + 1
      else
        -- Use actual join time if available, otherwise use tagged time
        local referenceTime = data.actualJoinTime or data.joinDate or now
        local daysSinceJoin = (now - referenceTime) / dayInSeconds

        if daysSinceJoin <= maxDays then
          report.withinProbation = report.withinProbation + 1

          if daysSinceJoin <= 7 then
            table.insert(report.recent, {
              name = memberName,
              daysSince = math.floor(daysSinceJoin),
              status = data.status or SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROVISIONAL"),
              notes = data.notes or ""
            })
          end
        else
          report.overdue = report.overdue + 1
        end
      end
    end
  end

  return report
end

-- Get all tracked guilds
function PM.getTrackedGuilds()
  local trackedGuilds = {}

  for i = 1, GetNumGuilds() do
    local guildName = GetGuildName(GetGuildId(i))
    if guildName then
      local guildSettings = PM.Internal.getGuildSettings(guildName)
      if guildSettings and guildSettings.enabled then
        table.insert(trackedGuilds, guildName)
      end
    end
  end

  return trackedGuilds
end

-- Export only filtered members based on current view
function PM.exportMembers(guildName, activeFilter, viewingHighlighted, highlightedMembers)
  local settings = PM.Internal.getSettings()
  if not settings or not settings.taggedMembers then
    return SF.func._L("ScrollkeeperProvisionMember", "STATUS_NO_DATA")
  end
  local guildMembers = settings.taggedMembers[guildName] or {}

  local exportText = string.format(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_REPORT_HEADER"), guildName or "All Guilds") .. "\n"
  exportText = exportText .. string.format(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_GENERATED"), os.date("%Y-%m-%d %H:%M:%S", GetTimeStamp())) .. "\n"

  if activeFilter then
    local filterName = activeFilter == "all" and SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER_ALL") or
                      activeFilter == "rank" and SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER_RANK") or
                      activeFilter == "gold" and SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER_GOLD") or
                      activeFilter == "inactive" and SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER_INACTIVE") or
                      activeFilter == "donor" and SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER_DONOR") or
                      SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER_CUSTOM")
    exportText = exportText .. string.format(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FILTER"), filterName) .. "\n"
  end

  if viewingHighlighted then
    exportText = exportText .. SF.func._L("ScrollkeeperProvisionMember", "EXPORT_VIEW_SELECTED") .. "\n"
  end

  exportText = exportText .. "\n"

  if guildName then
    local exportCount = 0

    for memberName, data in pairs(guildMembers) do
      if data and type(data) == "table" then
        local shouldExport = false

        -- Apply same filtering logic as the display
        if viewingHighlighted then
          shouldExport = highlightedMembers and highlightedMembers[memberName] == true
        else
          if not activeFilter or activeFilter == "all" or
             (activeFilter == "rank" and (data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") or not data.reason)) or
             (activeFilter == "gold" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_GOLD")) or
             (activeFilter == "inactive" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_INACTIVE")) or
             (activeFilter == "donor" and data.reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_DONOR")) then
            shouldExport = true
          end
        end

        if shouldExport then
          local referenceTime = data.actualJoinTime or data.joinDate or GetTimeStamp()
          local daysSince = math.floor((GetTimeStamp() - referenceTime) / 86400)
          local reason = data.reason or SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK")
          local joinType = data.actualJoinTime and SF.func._L("ScrollkeeperProvisionMember", "EXPORT_DAYS_ACTUAL") or SF.func._L("ScrollkeeperProvisionMember", "EXPORT_DAYS_ESTIMATED")

          -- Only show days for rank members
          local daysText = reason == SF.func._L("ScrollkeeperProvisionMember", "REASON_RANK") and
                          string.format(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_DAYS_FORMAT"), daysSince, joinType) or
                          SF.func._L("ScrollkeeperProvisionMember", "EXPORT_DAYS_NA")

          exportText = exportText .. string.format(SF.func._L("ScrollkeeperProvisionMember", "EXPORT_FORMAT"),
            memberName, data.status or SF.func._L("ScrollkeeperProvisionMember", "STATUS_PROVISIONAL"), daysText, reason, data.notes or "") .. "\n"
          exportCount = exportCount + 1
        end
      end
    end

    if exportCount == 0 then
      exportText = exportText .. SF.func._L("ScrollkeeperProvisionMember", "STATUS_NO_FILTER_MATCH") .. "\n"
    end
  end

  return exportText
end