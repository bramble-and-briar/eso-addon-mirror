-- Initialize AC namespace if not exists
if not AC then AC = {} end

local ADDON_NAME = 'AntiquarianCodex'

-- Optimization Constants
local PROCESS_BATCH_SIZE = 50
local BATCH_DELAY_MS = 1
local CACHE_CLEAR_INTERVAL = 600000 -- 10 minutes in milliseconds
local MAX_CACHE_SIZE = 1000 -- Maximum number of cached entries

-- Initialize data tables
local units = {}
local setsminfound = {}
local setAntiquities = {}
local populateEpoch = 0 -- incremented on each PopulateUnits call to cancel stale batches

local ZO_GamepadAntiquityJournal_hooked = false
local buttonGroup
local currentWaypointLeadId -- new: track currently highlighted lead for waypoint keybind
local addonInitialized = false -- new: guard to ensure per-character init runs exactly once

--------------------------------------------------------------------
-- DEBUG Helper : simple debug print (disabled in release if needed)
--------------------------------------------------------------------
-- ===== Early debug ring buffer (captures messages before /ac_debug) =====
local preDebugBuffer = {}
local preDebugBufferMax = 50
local function bufferDebugLine(txt)
	if #preDebugBuffer >= preDebugBufferMax then table.remove(preDebugBuffer, 1) end
	preDebugBuffer[#preDebugBuffer + 1] = txt
end

local debugEnabled = false -- shared flag everyone sees
local debugCount = 0

local function dbg(msg)
	-- capture everything in buffer (even if debug off) for later review
	bufferDebugLine(msg)
	if debugEnabled then
		debugCount = debugCount + 1
		if type(d) == 'function' then d('|c99CCFF[AC ' .. debugCount .. ']|r ' .. msg) end
	end
end

local function SwitchDebugMode()
	if debugEnabled then
		dbg('Debug disabled')
		debugEnabled = false
		debugCount = 0
	else
		debugEnabled = true
		dbg('Debug enabled')
		-- flush buffered lines (without double-buffering)
		if #preDebugBuffer > 0 then
			for _, ln in ipairs(preDebugBuffer) do
				debugCount = debugCount + 1
				if type(d) == 'function' then d('|c99CCFF[AC PRE ' .. debugCount .. ']|r ' .. ln) end
			end
		end
		if not addonInitialized then dbg('Addon not initialized yet (waiting for PLAYER_ACTIVATED).') end
	end
end

--------------------------------------------------------------------
-- Show waypoint announcement helper
--------------------------------------------------------------------
local function ShowWaypointAnnouncement(text)
	if CENTER_SCREEN_ANNOUNCE and CENTER_SCREEN_ANNOUNCE.CreateMessageParams then
		local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE)
		params:SetText(text)
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
	end
end

local function SetLeadWaypoint(leadId)
	-- New implementation: use stored unit coordinates
	if not leadId then return end
	local data = units and units[leadId]
	if not data then
		dbg("SetLeadWaypoint: no data for leadId " .. tostring(leadId))
		return
	end

	local x, y = data.x, data.y
	local zoneId = data.ZoneId
	-- Optional explicit mapId from location entry (6th field)
	local explicitMapId = data.mapId
	if not x or not y then
		-- No coordinates, so nothing to set
		local msg = string.format("No waypoint data for lead %s", tostring(data.Lead or leadId))
		if type(d) == "function" then d(msg) end
		return
	end
	if (not zoneId or zoneId == 0) and not explicitMapId then
		local msg = string.format("No waypoint data for lead %s", tostring(data.Lead or leadId))
		if type(d) == "function" then d(msg) end
		return
	end

	-- Coordinates are expected to be pre-normalized (0-1) at data population time.
	if x < 0 or x > 1 or y < 0 or y > 1 then
		dbg("SetLeadWaypoint: stored coords invalid (" .. tostring(x) .. "," .. tostring(y) .. ")")
		return
	end

	local currentMapId = GetCurrentMapId()
	-- Prefer explicit mapId (6th field) if provided; otherwise derive from ZoneId
	local targetMapId = explicitMapId or (GetMapIdByZoneId and zoneId and GetMapIdByZoneId(zoneId) or nil)
	local mapChanged = false
	if targetMapId and targetMapId ~= 0 and targetMapId ~= currentMapId then
		local res = SetMapToMapId(targetMapId)
		mapChanged = (res == SET_MAP_RESULT_MAP_CHANGED)
	end

	PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, y)

	if mapChanged then
		-- Restore original map silently
		SetMapToMapId(currentMapId)
	end

	local msg = string.format("Waypoint set for %s in %s", tostring(data.Lead or leadId), tostring(data.Zone or "Unknown Zone"))
	ShowWaypointAnnouncement(msg)
	if type(d) == "function" then d(msg) end
end

-- Centralized keybind updater so we can call it from multiple contexts (hooks + scene callbacks)
local function UpdateWaypointKeybind()
	-- Only keep the keybind active within the antiquity journal scene
	local sceneName = SCENE_MANAGER and SCENE_MANAGER:GetCurrentSceneName()
	if sceneName ~= 'gamepad_antiquity_journal' then
		-- Proactively remove our group if we are not in the target scene
		if buttonGroup then
			pcall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(buttonGroup) end)
		end
		return
	end
	-- Create (or recreate) the buttonGroup lazily
	if not buttonGroup then
		buttonGroup = {{
			name = "Set Waypoint",
			alignment = KEYBIND_STRIP_ALIGN_LEFT, -- keep it just to the right of other left-aligned buttons
			keybind = "UI_SHORTCUT_QUATERNARY",
			ethHold = true,
			holdDuration = 1000,
			callback = function() if currentWaypointLeadId then SetLeadWaypoint(currentWaypointLeadId) end end,
			visible = function()
				local dta = currentWaypointLeadId and units[currentWaypointLeadId]
				return dta and dta.x and dta.y
			end
		}}
		KEYBIND_STRIP:AddKeybindButtonGroup(buttonGroup)
	else
		-- Re-add in case scene transitions cleared it
		-- (Remove first to avoid duplicate internal state; Remove is safe even if not present.)
		pcall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(buttonGroup) end)
		KEYBIND_STRIP:AddKeybindButtonGroup(buttonGroup)
		KEYBIND_STRIP:UpdateKeybindButtonGroup(buttonGroup)
	end
end

--------------------------------------------------------------------
-- Coordinate normalization helper
-- Accepts raw x,y which may be nil, 0-1 normalized, or 0-100 percent.
-- Returns normalized (0-1) or nil,nil if invalid/suspicious.
--------------------------------------------------------------------
local function NormalizeCoords(rawX, rawY, contextId)
	if rawX == nil or rawY == nil then return nil, nil end
	local x = tonumber(rawX)
	local y = tonumber(rawY)
	if not x or not y then return nil, nil end
	-- Reject absurd values early
	if x < 0 or y < 0 then
		dbg(string.format('NormalizeCoords: negative coords (%s,%s) id=%s', tostring(x), tostring(y), tostring(contextId)))
		return nil, nil
	end
	if x > 1 or y > 1 then
		-- Treat as percent if plausible (<=100)
		if x <= 100 and y <= 100 then
			x = x / 100
			y = y / 100
		else
			dbg(string.format('NormalizeCoords: suspicious large coords (%s,%s) id=%s', tostring(x), tostring(y), tostring(contextId)))
			return nil, nil
		end
	end
	if x < 0 or x > 1 or y < 0 or y > 1 then
		dbg(string.format('NormalizeCoords: out of range after normalization (%s,%s) id=%s', tostring(x), tostring(y), tostring(contextId)))
		return nil, nil
	end
	return x, y
end

-- Memory monitoring function
local function GetMemoryUsage()
	local units_count = 0
	local setsminfound_count = 0
	for _ in pairs(units or {}) do units_count = units_count + 1 end
	for _ in pairs(setsminfound or {}) do setsminfound_count = setsminfound_count + 1 end
	return { units = units_count, setsminfound = setsminfound_count }
end

--[[
-- Enhanced colorizeExpiration function
local function colorizeExpiration(leadtimeleft)
    if leadtimeleft < 3600 then
        return '|cFF0000' -- red
    elseif leadtimeleft < 86400 then
        return '|cFFA500' -- orange
    elseif leadtimeleft < 604800 then
        return '|cFFFF00' -- yellow
    else
        return '|c00FF00' -- green
    end
end
 ]]

-- Helper function to extract antiquity ID from item link
local function GetAntiquityIdFromItemLink(itemLink)
	if type(itemLink) ~= 'string' or itemLink == '' then return nil end
	local itemId = GetItemLinkItemId(itemLink)
	return AC.TradeableLeadItems and AC.TradeableLeadItems[itemId]
end

-----------------------------------------------------
--- Main data collection logic for antiquities
--- This function scans all antiquities and populates the `units` table
--- with detailed information about each antiquity lead.
-----------------------------------------------------
local function PopulateUnits()
	populateEpoch = populateEpoch + 1
	local myEpoch = populateEpoch
	dbg('PopulateUnits: scanning antiquities (epoch=' .. myEpoch .. ')')

	-- Clear existing data
	units = {}
	setsminfound = {}
	setAntiquities = {}

	-- Get all antiquity IDs first
	local antiquityIds = {}
	local i = GetNextAntiquityId()

	if not i then
		dbg('PopulateUnits: No antiquities found')
		return
	end

	-- Collect all IDs first (this is fast)
	while i do
		table.insert(antiquityIds, i)
		i = GetNextAntiquityId(i)
	end

	dbg('PopulateUnits: Found ' .. #antiquityIds .. ' antiquities to process')

	-- Process in batches to prevent UI freezing
	local currentIndex = 1

	local function ProcessBatch()
		if populateEpoch ~= myEpoch then return end -- cancelled by a newer PopulateUnits call
		local batchEnd = math.min(currentIndex + PROCESS_BATCH_SIZE - 1, #antiquityIds)

		for idx = currentIndex, batchEnd do
			local antiquityId = antiquityIds[idx]

			-- Process each antiquity (wrapped in pcall for safety)
			local success, err = pcall(function()
				local havelead = DoesAntiquityHaveLead(antiquityId)
				local azoneid = GetAntiquityZoneId(antiquityId)
				local azone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(azoneid))
				local aname = ZO_CachedStrFormat('<<C:1>>', GetAntiquityName(antiquityId))
				local aquality = GetAntiquityQuality(antiquityId)
				local setid = GetAntiquitySetId(antiquityId)
				local setname = ZO_CachedStrFormat('<<C:1>>', GetAntiquitySetName(setid))
				local setquality = GetAntiquitySetQuality(setid)
				--                local diff = GetAntiquityDifficulty(antiquityId)
				local numrecovered = GetNumAntiquitiesRecovered(antiquityId)
				local repeatable = IsAntiquityRepeatable(antiquityId)

				-- Track minimum fragments found for sets and build set -> antiquities index
				if setid and setid > 0 then
					if setsminfound[setid] == nil or (setsminfound[setid] > numrecovered and not havelead) then setsminfound[setid] = numrecovered end
					local list = setAntiquities[setid]
					if not list then
						list = {}
						setAntiquities[setid] = list
					end
					-- Avoid inserting duplicate antiquityIds for a set (duplicates were causing doubled fragment counts)
					local already = false
					for _, existing in ipairs(list) do
						if existing == antiquityId then
							already = true
							break
						end
					end
					if not already then list[#list + 1] = antiquityId end
				end

				-- Handle special cases for repeatability
				if setid == 22 then repeatable = false end
				if antiquityId == 310 or (antiquityId > 498 and antiquityId < 509) or (antiquityId > 614 and antiquityId < 625) then repeatable = false end
				if antiquityId == 248 and numrecovered == 1 then havelead = false end

				local loreleft = GetNumAntiquityLoreEntries(antiquityId) - GetNumAntiquityLoreEntriesAcquired(antiquityId)
				local leadtimeleft = GetAntiquityLeadTimeRemainingSeconds(antiquityId)

				--[[                 -- Adjust difficulty for display (avoid skill level boosting issues)
                if diff < 5 and (antiquityId < 401 or antiquityId > 415) then
                    diff = aquality
                end ]]

				-- Handle expiration timer edge cases
				if havelead and leadtimeleft == 0 then
					leadtimeleft = 2851200 -- 33 days fallback
				end

				-- Handle different scry/find locations if needed
				if not havelead and AC.FindScryDifferentZones and AC.FindScryDifferentZones[antiquityId] then
					local findzoneid = AC.FindScryDifferentZones[antiquityId]
					if findzoneid < (AC.ZONEID_ALLZONES or 9999) then
						azone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(findzoneid))
						azoneid = findzoneid
					elseif AC.ZONENAME_SPECIAL and AC.ZONENAME_SPECIAL[findzoneid] then
						azone = AC.ZONENAME_SPECIAL[findzoneid]
						azoneid = findzoneid
					end
				end

				-- Handle reward-based set names
				local rewardid = GetAntiquityRewardId(antiquityId)
				if setname == '' and rewardid > 0 then
					setquality = GetAntiquityQuality(antiquityId)
					setname = REWARDS_MANAGER:GetRewardContextualTypeString(rewardid)
					if setname == 'Motif Chapter' then setquality = ANTIQUITY_QUALITY_PURPLE end
				end

				-- Only store antiquities with valid zone data
				if azone ~= '' then
					local location = 'Unknown'
					local xCoord, yCoord = nil, nil -- new: capture coordinates
					local mapIdOverride = nil -- new: optional explicit mapId
					if AC.Locations and AC.Locations[antiquityId] then
						local locEntry = AC.Locations[antiquityId]
						if locEntry[3] then location = locEntry[3] end

						-- new: pull 4th/5th fields (x,y) and normalize
						if locEntry[4] and locEntry[5] then
							local nx, ny = NormalizeCoords(locEntry[4], locEntry[5], antiquityId)
							if nx and ny then
								xCoord = nx
								yCoord = ny
							end
						end
						-- optional 6th field is mapId
						if locEntry[6] then
							local mid = tonumber(locEntry[6])
							if mid and mid > 0 then mapIdOverride = mid end
						end
					end

					units[antiquityId] = {
						Lead = aname,
						Zone = azone,
						ZoneId = azoneid,
						Location = location,
						-- Diff = diff,
						Lore = loreleft,
						Dug = numrecovered,
						Set = setname,
						SetId = setid,
						Expiration = leadtimeleft,
						SetQuality = setquality,
						HaveLead = havelead,
						Repeatable = repeatable,
						RewardId = rewardid,
						x = xCoord, -- new: map X (nil if unavailable)
						y = yCoord, -- new: map Y (nil if unavailable)
						mapId = mapIdOverride -- new: explicit mapId if provided
					}
				end
			end)

			if not success then dbg('Error processing antiquity ' .. tostring(antiquityId) .. ': ' .. tostring(err)) end
		end

		currentIndex = batchEnd + 1

		-- Continue processing if there are more items
		if currentIndex <= #antiquityIds then
			dbg('PopulateUnits: Processed ' .. batchEnd .. '/' .. #antiquityIds .. ' antiquities')
			zo_callLater(ProcessBatch, BATCH_DELAY_MS)
		else
			-- Processing complete
			local totalProcessed = 0
			for _ in pairs(units) do totalProcessed = totalProcessed + 1 end
			dbg('PopulateUnits: scan complete, processed ' .. totalProcessed .. ' valid antiquities')
		end
	end

	-- Start the batch processing
	ProcessBatch()
end

-- Update a single antiquity record (used by events) without a full rescan
local function UpdateAntiquityRecord(antiquityId)
	if not antiquityId then return end
	local ok, err = pcall(function()
		local havelead = DoesAntiquityHaveLead(antiquityId)
		local azoneid = GetAntiquityZoneId(antiquityId)
		local azone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(azoneid))
		local aname = ZO_CachedStrFormat('<<C:1>>', GetAntiquityName(antiquityId))
		local aquality = GetAntiquityQuality(antiquityId)
		local setid = GetAntiquitySetId(antiquityId)
		local setname = ZO_CachedStrFormat('<<C:1>>', GetAntiquitySetName(setid))
		local setquality = GetAntiquitySetQuality(setid)
		--        local diff = GetAntiquityDifficulty(antiquityId)
		local numrecovered = GetNumAntiquitiesRecovered(antiquityId)
		local repeatable = IsAntiquityRepeatable(antiquityId)

		if setid and setid > 0 then
			if setsminfound[setid] == nil or (setsminfound[setid] > numrecovered and not havelead) then setsminfound[setid] = numrecovered end
			-- maintain setAntiquities index incrementally
			local found = false
			local list = setAntiquities[setid]
			if not list then
				list = {}
				setAntiquities[setid] = list
			else
				for _, id in ipairs(list) do
					if id == antiquityId then
						found = true
						break
					end
				end
			end
			if not found then list[#list + 1] = antiquityId end
		end

		if setid == 22 then repeatable = false end
		if antiquityId == 310 or (antiquityId > 498 and antiquityId < 509) or (antiquityId > 614 and antiquityId < 625) then repeatable = false end
		if antiquityId == 248 and numrecovered == 1 then havelead = false end

		local loreleft = GetNumAntiquityLoreEntries(antiquityId) - GetNumAntiquityLoreEntriesAcquired(antiquityId)
		local leadtimeleft = GetAntiquityLeadTimeRemainingSeconds(antiquityId)

		--[[         if diff < 5 and (antiquityId < 401 or antiquityId > 415) then
            diff = aquality
        end ]]

		if havelead and leadtimeleft == 0 then
			leadtimeleft = 2851200 -- 33 days fallback
		end

		if not havelead and AC.FindScryDifferentZones and AC.FindScryDifferentZones[antiquityId] then
			local findzoneid = AC.FindScryDifferentZones[antiquityId]
			if findzoneid < (AC.ZONEID_ALLZONES or 9999) then
				azone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(findzoneid))
				azoneid = findzoneid
			elseif AC.ZONENAME_SPECIAL and AC.ZONENAME_SPECIAL[findzoneid] then
				azone = AC.ZONENAME_SPECIAL[findzoneid]
				azoneid = findzoneid
			end
		end

		local rewardid = GetAntiquityRewardId(antiquityId)
		if setname == '' and rewardid > 0 then
			setquality = GetAntiquityQuality(antiquityId)
			setname = REWARDS_MANAGER:GetRewardContextualTypeString(rewardid)
			if setname == 'Motif Chapter' then setquality = ANTIQUITY_QUALITY_PURPLE end
		end

		if azone ~= '' then
			local location = 'Unknown'
			local xCoord, yCoord = nil, nil -- new: capture coordinates
			local mapIdOverride = nil -- new: optional explicit mapId
			if AC.Locations and AC.Locations[antiquityId] then
				local locEntry = AC.Locations[antiquityId]
				if locEntry[3] then location = locEntry[3] end
				-- new: pull 4th/5th fields (x,y) and normalize
				if locEntry[4] and locEntry[5] then
					local nx, ny = NormalizeCoords(locEntry[4], locEntry[5], antiquityId)
					if nx and ny then
						xCoord = nx
						yCoord = ny
					end
				end
				-- optional 6th field is mapId
				if locEntry[6] then
					local mid = tonumber(locEntry[6])
					if mid and mid > 0 then mapIdOverride = mid end
				end
			end

			units[antiquityId] = {
				Lead = aname,
				Zone = azone,
				ZoneId = azoneid,
				Location = location,
				--                Diff = diff,
				Lore = loreleft,
				Dug = numrecovered,
				Set = setname,
				SetId = setid,
				Expiration = leadtimeleft,
				SetQuality = setquality,
				HaveLead = havelead,
				Repeatable = repeatable,
				RewardId = rewardid,
				x = xCoord, -- new: map X (nil if unavailable)
				y = yCoord, -- new: map Y (nil if unavailable)
				mapId = mapIdOverride -- new: explicit mapId if provided
			}
		end
	end)
	if not ok then dbg('UpdateAntiquityRecord error: ' .. tostring(err)) end
end

-- Append information about an antiquity lead to a tooltip
local function CreateLeadToolip(leadId)
	if not leadId then return {} end
	-- A tooltip may open before the asynchronous catalog scan reaches this lead.
	if not units[leadId] then UpdateAntiquityRecord(leadId) end
	local data = units[leadId]
	if not data then return {} end

	local entry = AC.Locations and AC.Locations[leadId]
	local fullDesc = entry and entry[1]
	local locShort = entry and entry[3]
	local source = AC.UNKNOWN
	if fullDesc and fullDesc ~= '' and fullDesc ~= AC.UNKNOWN then
		source = (locShort and locShort ~= '' and locShort ~= AC.UNKNOWN) and locShort or fullDesc
		-- Acquisition information stays separate from the client dig zone, even for owned leads.
		local findZoneId = AC.FindScryDifferentZones and AC.FindScryDifferentZones[leadId]
		local findZone
		if findZoneId then
			if findZoneId < (AC.ZONEID_ALLZONES or 9999) then
				findZone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(findZoneId))
			else
				findZone = AC.ZONENAME_SPECIAL and AC.ZONENAME_SPECIAL[findZoneId]
			end
		elseif fullDesc ~= AC.LOC_LONG_HIGHSEAS_UNCONFIRMED then
			findZone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(GetAntiquityZoneId(leadId)))
		end
		if findZone and findZone ~= '' then source = zo_strformat('<<1>>, <<2>>', source, findZone) end
	end

	local digZone = ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(GetAntiquityZoneId(leadId)))
	local setName = data.Set and data.Set ~= '' and data.Set or AC.UNKNOWN
	local setColor = ({[1] = '|c00FF00', [2] = '|c0080FF', [3] = '|c8000FF',
		[4] = '|cFFD700', [5] = '|cFF8000'})[data.SetQuality] or ''
	if setColor ~= '' then setName = setColor .. setName .. '|r' end
	local found = GetNumAntiquitiesRecovered(leadId)
	local codexMissing = math.max(0, GetNumAntiquityLoreEntries(leadId) - GetNumAntiquityLoreEntriesAcquired(leadId))
	local lines = {
		zo_strformat(AC.TOOLTIP_SOURCE, source),
		zo_strformat(AC.TOOLTIP_DIG, digZone ~= '' and digZone or AC.UNKNOWN),
		zo_strformat(AC.TOOLTIP_SET, setName),
		zo_strformat(AC.TOOLTIP_FOUND, found),
		zo_strformat(AC.TOOLTIP_CODEX_MISSING, codexMissing)
	}
	if AC.TradeableAntiquities and AC.TradeableAntiquities[leadId] then
		table.insert(lines, AC.TOOLTIP_TRADEABLELEAD)
	end
	if fullDesc and fullDesc ~= '' and fullDesc ~= AC.UNKNOWN and fullDesc ~= locShort then
		table.insert(lines, zo_strformat('<<1>>', fullDesc))
	end
	return lines
end

-- Build tooltip lines for a multi-fragment antiquity set reward
local function CreateSetToolip(setId)
	if not setId or setId <= 0 then return {} end
	local lines = {}

	local name = ZO_CachedStrFormat('<<C:1>>', GetAntiquitySetName(setId))
	local quality = GetAntiquitySetQuality(setId)
	local setColor = ''
	if quality == 1 then
		setColor = '|c00FF00' -- green
	elseif quality == 2 then
		setColor = '|c0080FF' -- blue
	elseif quality == 3 then
		setColor = '|c8000FF' -- purple
	elseif quality == 4 then
		setColor = '|cFFD700' -- gold
	elseif quality == 5 then
		setColor = '|cFF8000' -- orange
	end

	if name and name ~= '' then lines[#lines + 1] = zo_strformat('<<1>>Set: <<2>>|r', setColor, name) end

	local parts = setAntiquities[setId]
	if parts and #parts > 0 then
		-- Defensive de-duplication in case duplicates slipped in before this version
		local seen = {}
		local uniqueParts = {}
		for _, aid in ipairs(parts) do
			if not seen[aid] then
				seen[aid] = true
				uniqueParts[#uniqueParts + 1] = aid
			end
		end
		parts = uniqueParts
		-- Progress
		local recovered = 0
		for _, aid in ipairs(parts) do if GetNumAntiquitiesRecovered(aid) > 0 then recovered = recovered + 1 end end
		lines[#lines + 1] = zo_strformat('Fragments: <<1>>/<<2>>', recovered, #parts)

		-- Detail each fragment as a single line:
		--  • <fragName>:  <loc>, <zone>, <details>
		for _, aid in ipairs(parts) do
			local data = units[aid]
			local fragName = data and data.Lead or ZO_CachedStrFormat('<<C:1>>', GetAntiquityName(aid))
			local zone = (data and data.Zone) or ZO_CachedStrFormat('<<C:1>>', GetZoneNameById(GetAntiquityZoneId(aid)))
			local locShort = (data and data.Location) or (AC.Locations and AC.Locations[aid] and AC.Locations[aid][3]) or nil
			if locShort == '' or locShort == 'Unknown' then locShort = nil end
			local full = (AC and AC.Locations and AC.Locations[aid] and AC.Locations[aid][1]) or nil

			local partsLine = {}
			if locShort then partsLine[#partsLine + 1] = locShort end
			if zone and zone ~= '' then partsLine[#partsLine + 1] = zone end
			if full and full ~= '' and full ~= locShort then partsLine[#partsLine + 1] = full end

			local detailsJoined = table.concat(partsLine, ', ')
			if fragName and fragName ~= '' then
				if detailsJoined ~= '' then
					lines[#lines + 1] = zo_strformat(' • <<1>>:  <<2>>', fragName, detailsJoined)
				else
					lines[#lines + 1] = zo_strformat(' • <<1>>', fragName)
				end
			elseif detailsJoined ~= '' then
				lines[#lines + 1] = zo_strformat('<<1>>', detailsJoined)
			end
		end
	else
		-- Fallback: show that fragments could not be resolved
		lines[#lines + 1] = '|cFFFF00Fragments: Not indexed yet|r'
		lines[#lines + 1] = 'Tip: Use /ac_scan and reopen tooltip.'
	end

	return lines
end

-- Fixed AppendLeadToolip function that gets itemLink from tooltip data
local function AppendLeadToolip(tooltipStyle, leadId)
	dbg('AppendLeadToolip called with tooltipStyle: ' .. tostring(tooltipStyle) .. ', leadId: ' .. tostring(leadId))
	local scenes = {
		['gamepad_antiquity_journal'] = true,
		['gamepad_store'] = true -- weekly vendor / “Golden” store
		-- ['gamepad_inventory_root'] = true,
		-- ['gamepad_trading_house'] = true,
		-- ['gamepad_store'] = true,
		-- ['gamepad_antiquity_journal'] = true
	}

	local currentScene = SCENE_MANAGER:GetCurrentSceneName()
	if not scenes[currentScene] then
		dbg('AppendLeadToolip: Not in a valid scene for antiquity tooltips: ' .. tostring(currentScene))
		return
	else
		dbg('AppendLeadToolip.currentScene: ' .. tostring(currentScene))
	end

	-- Get the formatted antiquity info
	if not leadId then
		dbg('AppendLeadToolip.leadId empty')
		return
	end

	local antiquityLines = CreateLeadToolip(leadId) -- Now returns a table
	if not antiquityLines or #antiquityLines == 0 then
		dbg('AppendLeadToolip.antiquityLines empty')
		return
	end

	dbg('AppendLeadToolip.antiquityLines count: ' .. #antiquityLines)

	-- Get the left tooltip (most common for antiquity displays)
	local currentTooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
	if not currentTooltip then
		dbg('Could not get GAMEPAD_LEFT_TOOLTIP')
		return
	end

	local currentBodySection = currentTooltip:GetStyle('bodySection')
	local currentBodyDescription = currentTooltip:GetStyle('bodyDescription')
	local currentDividerLine = currentTooltip:GetStyle('dividerLine')
	local currentSection = currentTooltip:AcquireSection(currentBodySection)

	currentSection:AddTexture(ZO_GAMEPAD_HEADER_DIVIDER_TEXTURE, currentDividerLine)
	-- Add each line separately
	for _, line in ipairs(antiquityLines) do
		dbg('Adding line: ' .. tostring(line))
		currentSection:AddLine(line, currentBodyDescription)
	end

	currentTooltip:AddSection(currentSection)

	dbg('Successfully added antiquity tooltip content')
end

-- Generic helper: append our lines to any ZO_Tooltip instance (keyboard/gamepad)
local function AppendACSectionToTooltip(tip, lines)
	if not tip or not lines or #lines == 0 then return end
	-- Build a short signature for duplicate suppression
	local sig = table.concat(lines, '\31') -- use unlikely separator
	local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
	if tip.__ac_lastAppendSignature == sig and now ~= 0 and tip.__ac_lastAppendTime and (now - tip.__ac_lastAppendTime) < 150 then
		-- Duplicate within 150ms window; skip to avoid double display
		return
	end
	local bodySectionStyle = tip:GetStyle('bodySection')
	local bodyDescStyle = tip:GetStyle('bodyDescription')
	local dividerStyle = tip:GetStyle('dividerLine')

	local section = tip:AcquireSection(bodySectionStyle)
	section:AddTexture(ZO_GAMEPAD_HEADER_DIVIDER_TEXTURE, dividerStyle)
	for _, line in ipairs(lines) do section:AddLine(line, bodyDescStyle) end
	tip:AddSection(section)
	-- Record signature
	tip.__ac_lastAppendSignature = sig
	tip.__ac_lastAppendTime = now
end

-- Install post-hooks on ZO_Tooltip antiquity layouts to catch both keyboard and gamepad
local tooltipHooksInstalled = false
local acOriginalTooltipFns = {} -- store last-seen function pointers to detect replacement
local acHookMonitorActive = false -- avoid multiple monitor loops
local acHookMonitorEnabled = false -- verbose hook monitor logging only; auto-rehook is always active
local acHookedPointers = {} -- "<method>|<pointer>" values we already post-hooked
local acLoggedReplacements = {} -- track already logged replacements to reduce spam
local AC_HOOK_MONITOR_INTERVAL_MS = 3000

local function GetHookPointerKey(name, ptr)
	return tostring(name) .. '|' .. tostring(ptr)
end

local function TooltipLeadHook(self, id)
	id = tonumber(id)
	if not id then return end
	currentWaypointLeadId = id
	UpdateWaypointKeybind()
	AppendACSectionToTooltip(self, CreateLeadToolip(id))
end

local function TooltipFragmentHook(self, id)
	id = tonumber(id)
	if not id then return end
	currentWaypointLeadId = id
	UpdateWaypointKeybind()
	AppendACSectionToTooltip(self, CreateLeadToolip(id))
end

local function TooltipRewardHook(self, id)
	id = tonumber(id)
	if not id then return end
	currentWaypointLeadId = id
	UpdateWaypointKeybind()
	AppendACSectionToTooltip(self, CreateLeadToolip(id))
end

local function TooltipSetRewardHook(self, setId)
	setId = tonumber(setId)
	if not setId or setId <= 0 then return end
	currentWaypointLeadId = nil
	UpdateWaypointKeybind()
	AppendACSectionToTooltip(self, CreateSetToolip(setId))
end

local function TooltipTradeableLeadItemHook(self, itemLink)
	local antiquityId = GetAntiquityIdFromItemLink(itemLink)
	if not antiquityId then return end
	if not units[antiquityId] then UpdateAntiquityRecord(antiquityId) end
	AppendACSectionToTooltip(self, CreateLeadToolip(antiquityId))
end

local function TooltipClearedHook(self)
	-- Duplicate hooks share a layout, but a cleared tooltip starts a new layout.
	self.__ac_lastAppendSignature = nil
	self.__ac_lastAppendTime = nil
end

local TOOLTIP_HOOK_SPECS = {
	{name = 'LayoutAntiquityLead', handler = TooltipLeadHook},
	{name = 'LayoutAntiquitySetFragment', handler = TooltipFragmentHook},
	{name = 'LayoutAntiquityReward', handler = TooltipRewardHook},
	{name = 'LayoutAntiquitySetReward', handler = TooltipSetRewardHook},
	{name = 'LayoutItem', handler = TooltipTradeableLeadItemHook},
	{name = 'ClearLines', handler = TooltipClearedHook}
}

local function EnsureTooltipPostHooks(sourceTag)
	local hooked = 0
	for _, spec in ipairs(TOOLTIP_HOOK_SPECS) do
		if ZO_Tooltip and type(ZO_Tooltip[spec.name]) == 'function' then
			local currentPtr = ZO_Tooltip[spec.name]
			local previousPtr = acOriginalTooltipFns[spec.name]
			if previousPtr and previousPtr ~= currentPtr then
				local replacementKey = GetHookPointerKey(spec.name, currentPtr)
				if acHookMonitorEnabled and not acLoggedReplacements[replacementKey] then
					acLoggedReplacements[replacementKey] = true
					dbg(string.format('Tooltip method %s replaced (%s -> %s), rehooking',
						spec.name, tostring(previousPtr), tostring(currentPtr)))
				end
			end
			acOriginalTooltipFns[spec.name] = currentPtr

			local pointerKey = GetHookPointerKey(spec.name, currentPtr)
			if not acHookedPointers[pointerKey] then
				local ok, err = pcall(function() SecurePostHook(ZO_Tooltip, spec.name, spec.handler) end)
				if ok then
					acHookedPointers[pointerKey] = true
					hooked = hooked + 1
					-- SecurePostHook replaced ZO_Tooltip[spec.name] with a new wrapper.
					-- Store the post-hook pointer so the monitor treats our own wrapper as
					-- "expected" and doesn't falsely detect it as a third-party replacement.
					acOriginalTooltipFns[spec.name] = ZO_Tooltip[spec.name]
				else
					dbg(string.format('SecurePostHook failed for %s: %s', tostring(spec.name), tostring(err)))
				end
			end
		end
	end

	if hooked > 0 then
		tooltipHooksInstalled = true
		if acHookMonitorEnabled then dbg(string.format('Tooltip hooks installed/reinstalled (%s): %d', tostring(sourceTag), hooked)) end
	end

	return hooked
end

local function StartTooltipHookMonitor()
	if acHookMonitorActive then return end
	acHookMonitorActive = true
	local function poll()
		if not acHookMonitorActive then return end
		EnsureTooltipPostHooks('monitor')
		zo_callLater(poll, AC_HOOK_MONITOR_INTERVAL_MS)
	end
	zo_callLater(poll, AC_HOOK_MONITOR_INTERVAL_MS)
end

local function SetupTooltipPostHooks()
	local hooked = EnsureTooltipPostHooks('setup')
	StartTooltipHookMonitor()
	if acHookMonitorEnabled and hooked == 0 and tooltipHooksInstalled then
		dbg('Tooltip hooks already installed; monitor active for replacement detection.')
	end
end

-- Wrapper to attempt initial population when antiquity system might not be ready yet
local function StartInitialScan()
	local attempt = 1
	local maxAttempts = 15
	local delayMs = 1000
	local function try()
		local testId = GetNextAntiquityId()
		if testId then
			dbg(('Initial scan attempt %d: antiquity data available (id=%s), starting PopulateUnits'):format(attempt, tostring(testId)))
			PopulateUnits()
		else
			dbg(('Initial scan attempt %d: no antiquity data yet'):format(attempt))
			if attempt < maxAttempts then
				attempt = attempt + 1
				zo_callLater(try, delayMs)
			else
				dbg('Initial scan aborted: antiquity system not ready (maybe character has not unlocked Scrying).')
			end
		end
	end
	try()
end

-- Initialize the addon
local function InitializeAddon()
	if addonInitialized then
		dbg('InitializeAddon: already initialized, skipping')
		return
	end
	addonInitialized = true
	dbg('InitializeAddon: begin (char=' .. GetUnitName('player') .. ')')

	-- Normalize AC.Locations: ensure structure {desc, type, short, x, y, mapId?}
	if AC and AC.Locations then
		local converted = 0
		for id, entry in pairs(AC.Locations) do
			if type(entry) == 'table' then
				local desc = entry[1]
				local locType = entry[2]
				local shortName = entry[3]
				local x = tonumber(entry[4]) -- leave nil if absent
				local y = tonumber(entry[5])
				local mapId = tonumber(entry[6]) -- optional explicit mapId for waypoint

				if not desc or desc == '' then desc = 'Unknown Location' end
				-- Rebuild only if differs (including new mapId retention) or there are extra trailing fields beyond 6
				if entry[1] ~= desc or entry[2] ~= locType or entry[3] ~= shortName or entry[4] ~= x or entry[5] ~= y or entry[6] ~= mapId or entry[7] ~= nil then
					if mapId then
						AC.Locations[id] = {desc, locType, shortName, x, y, mapId}
					else
						AC.Locations[id] = {desc, locType, shortName, x, y}
					end
					converted = converted + 1
				end
			end
		end
		dbg('Normalized AC.Locations entries (updated ' .. converted .. ')')
	end

	-- Replace direct PopulateUnits call with delayed readiness sequence
	dbg('InitializeAddon: Scheduling initial antiquity scan readiness checks')
	StartInitialScan()

	-- Install global tooltip hooks (works for keyboard and gamepad)
	dbg('InitializeAddon: Installing tooltip post-hooks')
	SetupTooltipPostHooks()

	-- Ensure keybind is re-added whenever the antiquity journal scene is shown again
	local journalScene = SCENE_MANAGER and SCENE_MANAGER:GetScene('gamepad_antiquity_journal')
	if journalScene and not journalScene.__acWaypointKeybindHooked then
		journalScene.__acWaypointKeybindHooked = true
		journalScene:RegisterCallback('StateChange', function(oldState, newState)
			if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
				-- Verify tooltip hooks are still active each time the journal opens.
				-- Catches any replacement made by other addons (e.g. 702 Completionist)
				-- between journal sessions, without waiting for the 3-second poll cycle.
				EnsureTooltipPostHooks('scene-showing')
				-- Re-add/refresh button group; currentWaypointLeadId may be set by upcoming tooltip layout
				UpdateWaypointKeybind()
			end
			if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
				-- Always remove our keybind group when leaving the scene to prevent leakage into other menus
				pcall(function()
					if buttonGroup then KEYBIND_STRIP:RemoveKeybindButtonGroup(buttonGroup) end
				end)
				-- Clear state so we recreate cleanly next time
				buttonGroup = nil
				currentWaypointLeadId = nil
			end
		end)
	end

	-- Keep cache fresh on relevant antiquity events
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITY_LEAD_ACQUIRED, function(_, antiquityId)
		dbg('EVENT_ANTIQUITY_LEAD_ACQUIRED: ' .. tostring(antiquityId))
		UpdateAntiquityRecord(antiquityId)
	end)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITY_UPDATED, function(_, antiquityId)
		dbg('EVENT_ANTIQUITY_UPDATED: ' .. tostring(antiquityId))
		UpdateAntiquityRecord(antiquityId)
	end)
	local antiquitiesUpdatePending = false
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ANTIQUITIES_UPDATED, function()
		dbg('EVENT_ANTIQUITIES_UPDATED: queuing rescan')
		if not antiquitiesUpdatePending then
			antiquitiesUpdatePending = true
			zo_callLater(function()
				antiquitiesUpdatePending = false
				dbg('EVENT_ANTIQUITIES_UPDATED: rescanning (debounced)')
				PopulateUnits()
			end, 500)
		end
	end)
end

-- onLoad initializion
local function OnLoad(eventCode, name)
	if name ~= ADDON_NAME then return end
	dbg('onLoad called for ' .. tostring(name) .. ' (char=' .. GetUnitName('player') .. ')')
	-- extra diagnostics
	dbg('Antiquarian prerequisite check: skill line id presence = ' .. tostring(GetSkillLineId and select(3, GetSkillLineInfo and GetSkillLineInfo(52, 1) or nil) or 'n/a'))

	-- Hook gamepad tooltip instances directly during ADD_ON_LOADED.
	-- ZO_GamepadTooltip uses a lazy-init + zo_mixin pattern: when an instance is first
	-- accessed, ZO_Tooltip methods are copied as own properties. After that, the instance
	-- ignores class-level changes. Addons like 702 Completionist force this init via
	-- GetTooltip() during their own ADD_ON_LOADED (which fires before PLAYER_ACTIVATED),
	-- so by the time AC's class-level SecurePostHook runs, the instance already has a
	-- stale copy. We mirror the pattern used by both 702 and TSCPriceFetcher: hook the
	-- instance directly here, before or alongside the addon that forces its init.
	if GAMEPAD_TOOLTIPS then
		for _, tooltipType in ipairs({GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP}) do
			local ok, tooltip = pcall(function() return GAMEPAD_TOOLTIPS:GetTooltip(tooltipType) end)
			if ok and tooltip then
				for _, spec in ipairs(TOOLTIP_HOOK_SPECS) do
					pcall(function() ZO_PostHook(tooltip, spec.name, spec.handler) end)
				end
				dbg('onLoad: Hooked gamepad instance ' .. tostring(tooltipType))
			end
		end
	end

	dbg('Registering PLAYER_ACTIVATED for deferred init')
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
		dbg('EVENT_PLAYER_ACTIVATED')
		InitializeAddon()
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
	end)

	dbg('onLoad: Unregistering for EVENT_ADD_ON_LOADED')
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

--------------------------------------------------------------------
-- Slash Commands for Testing and Debug
--------------------------------------------------------------------
-- Switch debug mode
SLASH_COMMANDS['/ac_debug'] = SwitchDebugMode

-- Scan for antiquity leads
SLASH_COMMANDS['/ac_scan'] = PopulateUnits

-- Append antiquity lead tooltip command
SLASH_COMMANDS['/ac_testleadtooltip'] = function(leadId)
	leadId = tonumber(leadId) or 57 -- Ancestral High Elf Shoulders
	d('Testing lead ID: ' .. leadId)

	local leadTooltip = CreateLeadToolip(leadId)
	d(tostring(leadTooltip))
	d('Tooltip for lead ID: ' .. tostring(leadId))
end

-- Append antiquity lead tooltip command
SLASH_COMMANDS['/ac_dumplead'] = function(leadId)
	leadId = tonumber(leadId) or 57 -- Ancestral High Elf Shoulders
	if not leadId or not units then
		dbg('Dumping lead: No leadId or units')
		return ''
	else
		dbg('=== Dumping lead ID: ' .. leadId .. ' ===')
	end

	local data = units[leadId]
	if not data then
		dbg('No data for leadId ' .. tostring(leadId))
		return ''
	end

	d('  Data.Lead: ' .. tostring(data.Lead))
	d('  Data.Zone: ' .. tostring(data.Zone))
	d('  Data.Location: ' .. tostring(data.Location))
	d('  Data.Diff: ' .. tostring(data.Diff))
	d('  Data.Set: ' .. tostring(data.Set))
	d('  Data.Dug: ' .. tostring(data.Dug))
	d('  Data.Lore: ' .. tostring(data.Lore))
	d('  Data.HaveLead: ' .. tostring(data.HaveLead))
	d('  Data.Expiration: ' .. tostring(data.Expiration))
	d('  Data.setId: ' .. tostring(data.SetId))
	d('  Data.rewardId: ' .. tostring(data.RewardId))
	d('=== End dumping lead ID ===')
end

-- Dump a set summary by setId for quick sanity checks
SLASH_COMMANDS['/ac_dumpset'] = function(setId)
	setId = tonumber(setId) or 0
	if setId <= 0 then
		d('Usage: /ac_dumpset <setId>')
		return
	end
	local lines = CreateSetToolip(setId)
	if #lines == 0 then
		d('No data for setId ' .. tostring(setId))
	else
		d('=== Set ' .. tostring(setId) .. ' ===')
		for _, ln in ipairs(lines) do d(ln) end
		d('=== End Set ===')
	end
end

-- Memory usage command
SLASH_COMMANDS['/ac_memory'] = function()
	local usage = GetMemoryUsage()
	d('AC Memory Usage:')
	d('  Leads: ' .. usage.units)
	d('  Sets Min Found: ' .. usage.setsminfound)
	d('  Scan epoch: ' .. populateEpoch)
end

-- new: force re-init command (rescans & rehooks)
SLASH_COMMANDS['/ac_reinit'] = function()
	if not addonInitialized then
		d('AC: Not initialized yet; will initialize now.')
	else
		d('AC: Re-initializing.')
		addonInitialized = false
	end
	InitializeAddon()
end

-- new: dump buffered pre-init lines even if debug was off then
SLASH_COMMANDS['/ac_prebuffer'] = function()
	d('AC preDebugBuffer size: ' .. #preDebugBuffer)
	for i, ln in ipairs(preDebugBuffer) do d(('PRE[%d] %s'):format(i, ln)) end
end

-- Show current hook monitor status
SLASH_COMMANDS['/ac_hookstatus'] = function()
	local names = {'LayoutAntiquityLead', 'LayoutAntiquitySetFragment', 'LayoutAntiquityReward', 'LayoutAntiquitySetReward'}
	for _, n in ipairs(names) do
		local ptr = ZO_Tooltip[n]
		local tagged = acHookedPointers[GetHookPointerKey(n, ptr)] and 'HOOKED' or 'UNHOOKED'
		d(string.format('AC Hook %s: %s (%s)', n, tostring(ptr), tagged))
	end
	d('Monitor active=' .. tostring(acHookMonitorActive) .. ' verbose=' .. tostring(acHookMonitorEnabled) .. ' tooltipHooksInstalled=' .. tostring(tooltipHooksInstalled))
end

-- Toggle the hook monitor (disabled by default to reduce spam)
SLASH_COMMANDS['/ac_hookmonitor'] = function(arg)
	arg = (arg or ''):lower()
	if arg == 'on' or arg == '1' or arg == 'enable' then
		acHookMonitorEnabled = true
		StartTooltipHookMonitor()
		EnsureTooltipPostHooks('slash-on')
		d('AC: hook monitor verbose logging enabled')
	elseif arg == 'off' or arg == '0' or arg == 'disable' then
		acHookMonitorEnabled = false
		d('AC: hook monitor verbose logging disabled (auto-rehook still active)')
	elseif arg == 'start' then
		StartTooltipHookMonitor()
		d('AC: hook monitor started')
	elseif arg == 'stop' then
		acHookMonitorActive = false
		d('AC: hook monitor stopped')
	else
		d('Usage: /ac_hookmonitor on|off|start|stop (verbose=' .. tostring(acHookMonitorEnabled) .. ', active=' .. tostring(acHookMonitorActive) .. ')')
	end
end

-- Register for event onlonad
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoad)
