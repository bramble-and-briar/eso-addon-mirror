-- This file is part of CyrHUD
--
-- (C) 2016 Scott Yeskie (Sasky)
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

CyrHUD = CyrHUD or {}
CyrHUD.addonVars = {}
CyrHUD.addonVars.version	= "2026.09.28"
CyrHUD.addonVars.name 		= "CyrHUD"
CyrHUD.addonVars.author 	= "Sasky, |c4779ce@aldericon|r, |c3CB371@Masteroshi430|r"
CyrHUD.addonVars.website	= "http://www.esoui.com/downloads/fileinfo.php?id=559#info"
-- CyrHUD.yourKills = 0
-- CyrHUD.yourDeaths = 0



CyrHUD.keepsToObjectivesMap = {}

-- Fort Warden
CyrHUD.keepsToObjectivesMap[3] = {lower = 55, upper = 56}

-- Fort Rayles
CyrHUD.keepsToObjectivesMap[4] = {lower = 76, upper = 75}

-- Fort Glademist
CyrHUD.keepsToObjectivesMap[5] = {lower = 71, upper = 70}

-- Fort Ash
CyrHUD.keepsToObjectivesMap[6] = {lower = 178, upper = 177}

-- Fort Aleswell
CyrHUD.keepsToObjectivesMap[7] = {lower = 174, upper = 173}

-- Fort Dragonclaw
CyrHUD.keepsToObjectivesMap[8] = {lower = 170, upper = 169}

-- Chalman Keep
CyrHUD.keepsToObjectivesMap[9] = {lower = 180, upper = 179}

-- Arrius Keep
CyrHUD.keepsToObjectivesMap[10] = {lower = 66, upper = 65}

-- Kingscrest Keep
CyrHUD.keepsToObjectivesMap[11] = {lower = 78, upper = 77}

-- Farragut Keep
CyrHUD.keepsToObjectivesMap[12] = {lower = 50, upper = 51}

-- Blue Road Keep
CyrHUD.keepsToObjectivesMap[13] = {lower = 175, upper = 176}

-- Drakelowe Keep
CyrHUD.keepsToObjectivesMap[14] = {lower = 172, upper = 171}

-- Castle Alessia
CyrHUD.keepsToObjectivesMap[15] = {lower = 168, upper = 167}

-- Castle Faregyl
CyrHUD.keepsToObjectivesMap[16] = {lower = 61, upper = 60}

-- Castle Roebeck
CyrHUD.keepsToObjectivesMap[17] = {lower = 166, upper = 165}

-- Castle Brindle
CyrHUD.keepsToObjectivesMap[18] = {lower = 164, upper = 163}

-- Castle Black Boot
CyrHUD.keepsToObjectivesMap[19] = {lower = 48, upper = 49}

-- Castle Bloodmayne
CyrHUD.keepsToObjectivesMap[20] = {lower = 41, upper = 40}

-- Nikel Outpost
CyrHUD.keepsToObjectivesMap[132] = {lower = 217, upper = 216}

-- Sejanus Outpost
CyrHUD.keepsToObjectivesMap[133] = {lower = 215, upper = 214}

-- Bleaker's Outpost
CyrHUD.keepsToObjectivesMap[134] = {lower = 219, upper = 218}

-- Winter's Reach Outpost
CyrHUD.keepsToObjectivesMap[163] = {lower = 432, upper = 431}

-- Carmala Outpost
CyrHUD.keepsToObjectivesMap[164] = {lower = 434, upper = 433}

-- Harlun's Outpost
CyrHUD.keepsToObjectivesMap[165] = {lower = 436, upper = 435}

-- Vlastarus
CyrHUD.keepsToObjectivesMap[149] = {merchant = 303, central = 294, outlier = 304}

-- Bruma
CyrHUD.keepsToObjectivesMap[151] = {merchant = 299, central = 296, outlier = 297}

-- Cropsford
CyrHUD.keepsToObjectivesMap[152] = {merchant = 301, central = 300, outlier = 302}

----------------------------------------------
-- Utility
----------------------------------------------

local function bl(val)
	if val == nil then return "NIL" elseif val then return "T" else return "F" end
end

local function nn(val)
    if val == nil then return "NIL" end
    return val
end

function CyrHUD.formatTime(delta, inclueSec, doAdditional)
    local sec = delta % 60
    delta = (delta - sec) / 60
    local min = delta % 60

    -- 05/07/2026 performance improvement:
    -- formatTime() runs once a second for every timed row across the addon
    -- (Battle, ScoringBar, PatrollingHorror, MovingObjective). The old code
    -- unconditionally built `out = min .. "m"` up front, but when doAdditional
    -- is true and min is 0 or between 1 and 9, that value is immediately
    -- discarded and overwritten by one of the branches below -- the
    -- concatenation was wasted work on those calls. We now only build it in
    -- the branches that actually keep it.
    local out

	if doAdditional == true then
		if min == 0 then
		    if sec == 0 then
			    out = '  '.."now"
			else
			    out = '  '..sec.."s"
			end
			
		elseif min > 9 then
            out = '  '..min.."m" 		
		else
		    if sec < 10 then sec = "0"..sec end
			out = '  '..min..":"..sec
		end
	else
	    out = min .. "m"
	end

    if inclueSec then
        out = out .. " " .. sec .. "s"
    end

    return out
end

-- function CyrHUD.dump()
    -- for keepIdCounter = 1, 165 do
		 -- for objectiveIdCounter = 1, 1000 do
			 -- local objectiveName, _, objectiveState =  GetObjectiveInfo(keepIdCounter, objectiveIdCounter, BGQUERY_LOCAL)

             -- if objectiveName and objectiveName ~= "" then
			     -- d(objectiveName.." keepid: "..keepIdCounter.." objectiveId: "..objectiveIdCounter)
			 -- end
		 -- end
	-- end 
-- end


CyrHUD.errors = {}

function CyrHUD:error(val)
    if not self.errors[val] then
        self.errors[val] = 1
        d("|cFF0000ERROR (CyrHUD): " .. val .. "\n|CCCCCCCPlease file this bug info with a screenshot at |CEEEEFFesoui.com (CyrHUD)")
    end
end

----------------------------------------------
-- Events
----------------------------------------------

function CyrHUD.eventAttackChange(_, keepID, battlegroundContext, underAttack)
    local self = CyrHUD

    -- 05/07/2026 performance improvement:
    -- GetKeepType(keepID) is an engine API call, and this function used to call
    -- it up to 6 times (lines checking KEEPTYPE_IMPERIAL_CITY_DISTRICT, then
    -- KEEPTYPE_BRIDGE/KEEPTYPE_MILEGATE, then KEEPTYPE_ARTIFACT_GATE/BRIDGE/
    -- MILEGATE again) every single time this fires, which happens on every
    -- EVENT_KEEP_UNDER_ATTACK_CHANGED event during PvP combat. Crossing the
    -- engine API boundary repeatedly for a value that never changes within this
    -- call is wasted work, so we fetch it once into a local and reuse it.
    local keepType = GetKeepType(keepID)

    --Optionally hide IC district battles
    if keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT then
        if CyrHUD.cfg.hideImpBattles then
            return
        end
    end
	
	if (keepType == KEEPTYPE_BRIDGE or keepType == KEEPTYPE_MILEGATE) and CyrHUD.cfg.hideBridgesAndMilegates then
	   return
	end

	
	-- 05/07/2026 bug fix:
	-- `gateOpen` was declared with `local` inside the "if keepType ==
	-- KEEPTYPE_ARTIFACT_GATE or BRIDGE or MILEGATE" block below, so it only
	-- existed within that block's scope. The `if underAttack or gateOpen`
	-- check further down was therefore reading an out-of-scope global
	-- `gateOpen` (always nil), meaning a gate/bridge/milegate opening was
	-- never actually able to trigger self:add(keepID) on its own -- only
	-- `underAttack` could. Declaring it here in the function's outer scope
	-- lets the value set inside the if-block actually reach the check below.
	local gateOpen = false

	if keepType == KEEPTYPE_ARTIFACT_GATE or keepType == KEEPTYPE_BRIDGE or keepType == KEEPTYPE_MILEGATE then
	
		local pinType,_,_ = GetKeepPinInfo(keepID, battlegroundContext)
		if pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_ALDMERI_DOMINION or pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_DAGGERFALL_COVENANT or pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_EBONHEART_PACT then
			 gateOpen = true
		elseif pinType == MAP_PIN_TYPE_KEEP_BRIDGE_IMPASSABLE or pinType == MAP_PIN_TYPE_KEEP_MILEGATE_IMPASSABLE or pinType == MAP_PIN_TYPE_KEEP_MILEGATE_CENTER_DESTROYED then
		    gateOpen = true -- yep, it should be keepImpassable = true but the code is cleaner/has less lines like that   
		end
	end


    if underAttack or gateOpen then
        self:add(keepID)
    elseif self.battles[keepID] ~= nil then
        self.battles[keepID]:update()
    end

    self.battleContext = battlegroundContext
end


function CyrHUD.SetMovingObjective(_, keepId, objectiveId, battlegroundContext, objectiveName, objectiveType, objectiveControlEvent, state, holdingAlliance, attackingAlliance, pinType)
   local self = CyrHUD

    if state == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED or state == OBJECTIVE_CONTROL_STATE_FLAG_HELD or objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_SPAWNED then
        objectiveName = LocalizeString('<<1>>', objectiveName)

        -- 05/07/2026 performance improvement:
        -- The old code re-indexed the global table chain
        -- `CyrHUD.MovingObjective[objectiveId]` nine separate times in a row to
        -- set each field, each of those being a global lookup plus a table
        -- index rather than a single cheap local variable read. We now look it
        -- up once, cache it in a local, and reuse that local for every field
        -- assignment below.
        CyrHUD.MovingObjective[objectiveId] = CyrHUD.MovingObjective[objectiveId] or {}
        local obj = CyrHUD.MovingObjective[objectiveId]

		obj.startMovingObjective = obj.startMovingObjective or GetTimeStamp()
		obj.endMovingObjective = nil
		local _, holderName = GetCarryableObjectiveHoldingCharacterInfo(keepId, objectiveId, battlegroundContext)
		obj.holder = holderName
        obj.name = objectiveName
		obj.objectiveId = objectiveId 
		obj.keepId = keepId
		obj.objectiveType = objectiveType
		obj.objectiveControlEvent = objectiveControlEvent
		obj.holdingAlliance = holdingAlliance
		obj.color = CyrHUD.info[holdingAlliance].color:UnpackRGBA()
		obj.texture = ZO_MapPin.PIN_DATA[pinType].texture
		obj.type = "MovingObjective"


	   if self.MovingObjectives[objectiveId] ~= nil then
	       CyrHUD.MovingObjectives[objectiveId]:update()
	   else
	       self:addObj(objectiveId)
	   end

   else
       -- remove the objective if not held or dropped
	   if CyrHUD.MovingObjectives[objectiveId] then CyrHUD.MovingObjectives[objectiveId] = nil end 
   end


   self.battleContext = battlegroundContext 
end

local g_pvpKillFeedDeathRecurrenceTracker = nil
do
    -- The PvP Kill Feed uses ZO_RecurrenceTracker to track whether any given
    -- killer/victim message has been shown within the last 10 seconds from a
    -- given source (local vs. kill location). Note that the instance count
    -- tracked by ZO_RecurrenceTracker is irrelevant here for the purpose of
    -- the kill feed.
    local EXPIRATION_MS = 10000 -- 10 seconds
    local EXTENSION_MS = 10000 -- 10 seconds
    g_pvpKillFeedDeathRecurrenceTracker = ZO_RecurrenceTracker:New(EXPIRATION_MS, EXTENSION_MS)
end

-- 20/07/2026 bug fix:
-- This function's parameter list previously named its 3rd/4th and 7th/8th
-- parameters "killerPlayerDisplayName, killerPlayerCharacterName" and
-- "victimPlayerDisplayName, victimPlayerCharacterName", but the event
-- registration wrapper below (see CyrHUD:init) calls this function passing
-- CharacterName before DisplayName for both killer and victim (matching the
-- actual EVENT_PVP_KILL_FEED_DEATH argument order). That meant the local
-- variable named killerPlayerDisplayName actually held the character name
-- value, and vice versa. This was silently harmless today because only the
-- "DisplayName" locals are read below (for the spam-filter key) and the
-- "CharacterName" locals were never used elsewhere in this function, but it
-- was mislabeled and would silently misbehave the moment that assumption
-- changed (e.g. the commented-out "yourDisplayName" kill/death tally further
-- down, which compares against GetDisplayName() and needs an actual display
-- name, not a character name). Parameter names now match the order they're
-- actually called with.
--
-- Separately: `isKillLocation` below is referenced but is not a parameter of
-- this function (nor a local), so it always reads as the undefined global
-- `nil`. That doesn't crash, but it does mean the "this message was kill
-- location sourced" branch of the spam-filter is permanently dead code --
-- every call takes the "locally sourced" branch. If a second call site
-- (e.g. a kill-location-broadcast event) is meant to pass true here, it
-- needs to be wired up and this function needs an `isKillLocation` parameter;
-- as written, the two-key ZO_RecurrenceTracker dedup this function sets up
-- can never actually use its second key.
function CyrHUD.playerKilled(_, killLocation, killerPlayerCharacterName, killerPlayerDisplayName, killerPlayerAlliance, killerPlayerRank, victimPlayerCharacterName, victimPlayerDisplayName, victimPlayerAlliance, victimPlayerRank)
    local self = CyrHUD
	
	killLocation = LocalizeString('<<1>>', killLocation)
	
	-- clean previous data if no deaths in the place during the last 6 mn
	if CyrHUD.Graveyard and CyrHUD.Graveyard[killLocation] and GetDiffBetweenTimeStamps(GetTimeStamp(), CyrHUD.Graveyard[killLocation].lastUpdate) > 360 then
        CyrHUD.Graveyard[killLocation] = nil
    end	

	
	-- ZOS' spam filter
	local messageKeySuffix = string.format("%s___%s", killerPlayerDisplayName, victimPlayerDisplayName)
	local messageKeyLocal = "L" .. messageKeySuffix
	local messageKeyKillLocation = "B" .. messageKeySuffix
	if isKillLocation then
		-- This message was kill location sourced.
		if g_pvpKillFeedDeathRecurrenceTracker:RemoveValue(messageKeyLocal) ~= nil then
			-- The same message was already shown as a result of a local message;
			-- remove the original message from the tracker and suppress this message.
			return
		end
		-- Track this kill location sourced message.
		g_pvpKillFeedDeathRecurrenceTracker:AddValue(messageKeyKillLocation)
	else
		-- This message was locally sourced.
		if g_pvpKillFeedDeathRecurrenceTracker:RemoveValue(messageKeyKillLocation) ~= nil then
			-- The same message was already shown as a result of a kill location message;
			-- remove the original message from the tracker and suppress this message.
			return
		end
		-- Track this locally sourced message.
		g_pvpKillFeedDeathRecurrenceTracker:AddValue(messageKeyLocal)
	end

	
	-- populate your kills and deaths
	-- local yourDisplayName = GetDisplayName()
	-- if killerPlayerDisplayName == yourDisplayName then
	       -- CyrHUD.yourKills = CyrHUD.yourKills + 1
	-- elseif victimPlayerDisplayName == yourDisplayName then
	       -- CyrHUD.yourDeaths = CyrHUD.yourDeaths + 1
	-- end
	
	-- We terminate previous graveyards in case there is a new one when there is more than 10 entries to avoid too much infos 
	if not self.Graveyards[killLocation] and CyrHUD.entryCount > 10 then
	   for k, _ in pairs(self.Graveyards) do
           self.Graveyards[k].endGraveyard = GetTimeStamp()
		   CyrHUD.Graveyards[k] = nil
       end
	end
	
	-- 05/07/2026 performance improvement:
	-- playerKilled() fires on every EVENT_PVP_KILL_FEED_DEATH, which in a busy
	-- zerg fight can happen many times per second -- making this by far the
	-- hottest path in the addon. The old code re-indexed the global table
	-- chain `CyrHUD.Graveyard[killLocation]` well over 25 times below (each one
	-- a global lookup plus a table index) to read/write fields on the exact
	-- same table. We now resolve it once into a local and reuse that local for
	-- every field access.
	CyrHUD.Graveyard = CyrHUD.Graveyard or {}
	CyrHUD.Graveyard[killLocation] = CyrHUD.Graveyard[killLocation] or {}
	local grave = CyrHUD.Graveyard[killLocation]

    grave.startGraveyard = grave.startGraveyard or GetTimeStamp()
	grave.name = killLocation
	grave.endGraveyard = nil
	grave.lastUpdate = GetTimeStamp()
	grave.type = "Graveyard"
	
	-- avoid nil values
	grave.allianceKills = grave.allianceKills or {}
	grave.allianceKills[1] = grave.allianceKills[1] or 0
	grave.allianceKills[2] = grave.allianceKills[2] or 0
	grave.allianceKills[3] = grave.allianceKills[3] or 0
	grave.allianceDeaths = grave.allianceDeaths or {}
	grave.allianceDeaths[1] = grave.allianceDeaths[1] or 0
	grave.allianceDeaths[2] = grave.allianceDeaths[2] or 0
	grave.allianceDeaths[3] = grave.allianceDeaths[3] or 0
	
	-- increment the location's alliance counters for kills & deaths
	grave.allianceKills[killerPlayerAlliance] = grave.allianceKills[killerPlayerAlliance] + 1
	grave.allianceDeaths[victimPlayerAlliance] = grave.allianceDeaths[victimPlayerAlliance] + 1
	
	-- calculate if we are in the winning alliance
	local ADscore = grave.allianceKills[1] - grave.allianceDeaths[1]
	local DCscore = grave.allianceKills[3] - grave.allianceDeaths[3]
	local EPscore = grave.allianceKills[2] - grave.allianceDeaths[2]
	
	--d("ADscore: "..ADscore.." EPscore: "..EPscore.." DCscore: "..DCscore)

	if ADscore >= DCscore and ADscore >= EPscore then
	       grave.winningAlliance = 1
	elseif DCscore >= ADscore and DCscore >= EPscore then
	       grave.winningAlliance = 3
	elseif EPscore >= ADscore and EPscore >= DCscore then  
	       grave.winningAlliance = 2
	else
	       grave.winningAlliance = 0
	end
	
	
	-- the data is entered but has it enough deaths (10) to be displayed? 
	if grave.allianceDeaths[1] + grave.allianceDeaths[2] + grave.allianceDeaths[3] < 10 then
	   return
	end
	
	
	-- choose the right texture 
	local ADinvolved = (grave.allianceKills[1] + grave.allianceDeaths[1]) > 0 
	local DCinvolved = (grave.allianceKills[3] + grave.allianceDeaths[3]) > 0
	local EPinvolved = (grave.allianceKills[2] + grave.allianceDeaths[2]) > 0
	
	if ADinvolved and DCinvolved and EPinvolved then
	      grave.texture = "EsoUI/Art/MapPins/AvA_3Way.dds"
	elseif ADinvolved and DCinvolved then
	       grave.texture = "EsoUI/Art/MapPins/AvA_AldmeriVDaggerfall.dds"
	elseif ADinvolved and EPinvolved then
	       grave.texture = "EsoUI/Art/MapPins/AvA_AldmeriVEbonheart.dds"
	elseif DCinvolved and EPinvolved then
	       grave.texture = "EsoUI/Art/MapPins/AvA_EbonheartVDaggerfall.dds"
	else
	       grave.texture = "/esoui/art/treeicons/gamepad/gp_tutorial_idexicon_death.dds"
	end
	
	if self.Graveyards[killLocation] ~= nil then
	    CyrHUD.Graveyards[killLocation]:update()
	else
	    self:addGraveyard(killLocation)
	end

end


function CyrHUD.onMonsterDeath(_, unitTag, isDead)
    if GetCurrentMapId() ~= 660 then return end -- only in imperial city upper district
	-- mapid 785 is Barathrum Centrata (Molag Bal) 
    local self = CyrHUD	
	local monsterName = GetUnitName(unitTag)
	local isDeadly = GetUnitDifficulty(unitTag) == MONSTER_DIFFICULTY_DEADLY
	
	if monsterName == nil or monsterName == "" or not isDeadly then return end -- Abort if unit is not part of Patrolling Horrors

	if isDead == true then -- Imperial City Boss just died
	     
		local currentAreaName = string.gsub(GetPlayerLocationName(), "(%w+)[%^]+.*", "%1") 
		if not currentAreaName then return end
		local areaBossName = currentAreaName.." "..GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES501)
		
		if self.PatrollingHorrors[areaBossName] ~= nil then
			CyrHUD.PatrollingHorrors[areaBossName]:restart()
		else
			self:addPatrollingHorror(areaBossName)
		end

	end
end

function CyrHUD.onMonsterReticle(_)
    if GetCurrentMapId() ~= 660 then return end -- only in imperial city upper district
    local self = CyrHUD
	local unitName = GetUnitNameHighlightedByReticle()
    local isDeadly = GetUnitDifficulty('reticleover') == MONSTER_DIFFICULTY_DEADLY
		
	if unitName == nil or unitName == "" or not isDeadly then return end -- Abort if unit is not part of Patrolling Horrors
	
	local isDead = IsUnitDead('reticleover')
    local currentAreaName = string.gsub(GetPlayerLocationName(), "(%w+)[%^]+.*", "%1")
	if not currentAreaName then return end
	local areaBossName = currentAreaName.." "..GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES501) 
	
	-- 05/07/2026 performance improvement:
	-- onMonsterReticle() fires on every EVENT_RETICLE_TARGET_CHANGED while in
	-- the Imperial City upper district -- easily multiple times per second
	-- just from moving the camera, making this one of the hottest event
	-- handlers in the addon. The old code re-indexed the global table chain
	-- `self.PatrollingHorrors[areaBossName]` up to 8 times in a row below.
	-- We resolve it once per branch into a local and reuse that local.
	if isDead == true then -- Imperial City Boss is dead on the floor 
		local horror = self.PatrollingHorrors[areaBossName]
		if horror then
			if horror.lastSeenAlive and GetDiffBetweenTimeStamps( GetTimeStamp(), horror.lastSeenAlive) < 5 then -- died before your eyes
			       horror.lastSeenAlive = nil
                   horror:restart()  			
			elseif horror:getRawDuration() > 960 then -- Already dead before you arrive, we end the notification
				horror.endPatrollingHorror = GetTimeStamp()
			end
        end

	else -- Imperial City Boss is facing you alive  
	    local horror = self.PatrollingHorrors[areaBossName]
	    if horror == nil then -- no notification yet 
            self:engagePatrollingHorror(areaBossName)  
        elseif (900 - horror:getRawDuration()) > 0 then -- adjust time
		     horror.startPatrollingHorror = GetTimeStamp() - 900
		else
             horror.lastSeenAlive = GetTimeStamp()		
		end	
         		
	end
end




function CyrHUD.saveWindowPosition( window )
    local _, sP, _, aP, x, y = window:GetAnchor()
    CyrHUD.cfg.anchPoint = aP
    CyrHUD.cfg.selfPoint = sP
    CyrHUD.cfg.xoff = x
    CyrHUD.cfg.yoff = y
end

function CyrHUD.actionLayerChange(_, _, activeLayerIndex)
    CyrHUD_UI:SetHidden(activeLayerIndex > 2)
end

----------------------------------------------
-- Notification UI pool
----------------------------------------------

CyrHUD.entryCount = 0
CyrHUD.entries = {}

function CyrHUD:reconfigureLabels()
    for _,entry in pairs(self.entries) do
        --Forces reconfigure on next update
        entry.type = nil
    end
end

function CyrHUD:hideRow(index)
    if self.entries[index] then
        self.entries[index].main:SetHidden(true)
    end
end

function CyrHUD:getUIRow(index)
    if #self.entries < index then
        table.insert(self.entries, self.Label())
        index = #self.entries
    end

    self.entries[index].main:SetHidden(false)

    return self.entries[index]
end

-- 20/07/2026 performance improvement:
-- This logic used to live inline inside CyrHUD.Battle:updateLabel() in
-- Battle.lua, which runs once a second for EVERY displayed keep row. Since
-- it scans *all* AvA objectives with GetNumObjectives()/GetAvAObjectiveKeysByIndex()
-- looking for captured Elder Scrolls, and even re-counts the entire
-- CyrHUD.scrolls table with an inner pairs() loop every time it finds one,
-- running it once per keep row per second made the actual engine-call cost
-- O(displayed keeps x AvA objectives) every second, even though the result
-- (which keep holds which scroll, and the AD/DC/EP scroll totals) doesn't
-- depend on which keep row is being drawn at all -- it's the same answer for
-- every row. We now compute it exactly once per second here, cache "which
-- keepID currently displays which scroll pin" in self.scrollHolderByKeep,
-- and have Battle:updateLabel() do a single cheap table lookup into that
-- cache instead of re-scanning every objective itself.
function CyrHUD:updateElderScrollHolders()
    self.scrolls = self.scrolls or {}
    local scrollHolderByKeep = {}

    local numObjectives = GetNumObjectives()
    for i = 1, numObjectives do
        local okeepId, objectiveId, obgContext = GetAvAObjectiveKeysByIndex(i)
        local thatKeep = GetKeepThatHasCapturedThisArtifactScrollObjective(okeepId, objectiveId, obgContext)

        if thatKeep ~= 0 then
            self.scrolls[objectiveId] = GetKeepAlliance(thatKeep, self.battleContext)

            local objectiveControlState = GetObjectiveControlState(okeepId, objectiveId, obgContext)
            if objectiveControlState == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE or objectiveControlState == OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE then
                local scrollPinType = GetObjectivePinInfo(okeepId, objectiveId, obgContext)
                scrollHolderByKeep[thatKeep] = scrollPinType
            end
        end
    end
    self.scrollHolderByKeep = scrollHolderByKeep

    local adCount, dcCount, epCount = 0, 0, 0
    for _,alliance in pairs(self.scrolls) do
        if alliance == ALLIANCE_ALDMERI_DOMINION then adCount = adCount + 1
        elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then dcCount = dcCount + 1
        elseif alliance == ALLIANCE_EBONHEART_PACT then epCount = epCount + 1
        end
    end
    self.ADscrolls = adCount
    self.DCscrolls = dcCount
    self.EPscrolls = epCount
end

function CyrHUD:printAll()
	local i = 1

    self:updateElderScrollHolders()

    for _,status in ipairs(self.statusBars) do
        self:getUIRow(i):update(status)
        i = i + 1
    end
    
    
    CyrHUD.rowDisplayedCount = CyrHUD.rowDisplayedCount or 0 
    local rowDislpayedCount = 0
    -- we reorder by priority: keeps, outposts, towns and then the rest

    -- 05/07/2026 performance improvement:
    -- This used to loop over self.battles with `pairs()` five separate times
    -- (once per keepType bucket) every second via the UIUpdate timer, i.e. O(5n)
    -- table traversals just to bucket/sort entries by keepType. Instead, we now
    -- walk self.battles a single time and bucket each battle into a small table
    -- based on its keepType, then iterate those (much smaller) buckets in the
    -- desired priority order. This turns the 5x O(n) pairs() scans into a single
    -- O(n) scan plus cheap O(bucket size) ipairs() scans, with identical output
    -- ordering and identical rowDislpayedCount/thrashKeepCount semantics.
    local artifactGateBattles, keepBattles, outpostBattles, townBattles, otherBattles = {}, {}, {}, {}, {}

    for _,battle in pairs(self.battles) do
        local keepType = battle.keepType
        if keepType == KEEPTYPE_ARTIFACT_GATE then
            artifactGateBattles[#artifactGateBattles+1] = battle
        elseif keepType == KEEPTYPE_KEEP then
            keepBattles[#keepBattles+1] = battle
        elseif keepType == KEEPTYPE_OUTPOST then
            outpostBattles[#outpostBattles+1] = battle
        elseif keepType == KEEPTYPE_TOWN then
            townBattles[#townBattles+1] = battle
        else
            otherBattles[#otherBattles+1] = battle
        end
    end

    for _,battle in ipairs(artifactGateBattles) do
          self:getUIRow(i):update(battle)
          i = i + 1
          rowDislpayedCount = rowDislpayedCount +1
    end

    for _,battle in ipairs(keepBattles) do
          self:getUIRow(i):update(battle)
          i = i + 1
          rowDislpayedCount = rowDislpayedCount +1
    end

    for _,battle in ipairs(outpostBattles) do
          self:getUIRow(i):update(battle)
          i = i + 1
          rowDislpayedCount = rowDislpayedCount +1
    end

    for _,battle in ipairs(townBattles) do
          self:getUIRow(i):update(battle)
          i = i + 1
          rowDislpayedCount = rowDislpayedCount +1
    end

    local thrashKeepCount = 0
    for _,battle in ipairs(otherBattles) do
        if CyrHUD.rowDisplayedCount + thrashKeepCount < 11 then
          self:getUIRow(i):update(battle)
          i = i + 1
          thrashKeepCount = thrashKeepCount +1
        end
    end
    
    ----------------------------------------
	
	for _,MovingObjective in pairs(self.MovingObjectives) do
        self:getUIRow(i):update(MovingObjective)
        i = i + 1
        rowDislpayedCount = rowDislpayedCount +1
    end
	
	for _,Graveyard in pairs(self.Graveyards) do
        self:getUIRow(i):update(Graveyard)
        i = i + 1
        rowDislpayedCount = rowDislpayedCount +1
    end
	
	for _,PatrollingHorror in pairs(self.PatrollingHorrors) do
        self:getUIRow(i):update(PatrollingHorror)
        i = i + 1
        rowDislpayedCount = rowDislpayedCount +1
    end

    --Fix since auto-resize doesn't seem to work well
    self.ui:SetHeight(math.max(i*35,70))
	
	-- 05/07/2026 bug fix:
	-- `i` starts at 1 and is incremented exactly once for every row actually
	-- displayed above (status bars, battles, moving objectives, graveyards,
	-- patrolling horrors), so the true displayed row count is i-1, not i-2.
	-- The old `i-2` undercounted by one, which matters because playerKilled()
	-- checks `CyrHUD.entryCount > 10` to decide when to clear out graveyard
	-- entries to avoid clutter -- with the off-by-one, that cleanup only
	-- kicked in once 12 rows were actually displayed instead of the intended
	-- 11, letting the HUD get one row more cluttered than the comment there
	-- ("more than 10 entries") describes.
	CyrHUD.entryCount = i-1
  CyrHUD.rowDisplayedCount = rowDislpayedCount


    for j=i,#self.entries do
        self:hideRow(j)
    end

end

----------------------------------------------
-- Battle management
----------------------------------------------

CyrHUD.battles = {}
CyrHUD.MovingObjectives = {}
CyrHUD.Graveyards = {} 
CyrHUD.PatrollingHorrors = {} 

function CyrHUD:add(keepID)
    if self.battles[keepID] == nil then
        self.battles[keepID] = self.Battle(keepID)
    else
        self.battles[keepID]:restart()
    end
end

function CyrHUD:checkAdd(keepID, fromFlag)
    if self.battles[keepID] == nil then
        local battle = self.Battle(keepID)

      if battle:isBattle() or fromFlag then 
              self.battles[keepID] = battle
        if fromFlag then
            self.battles[keepID].flagUAsince = GetTimeStamp()
        end
        
      end
    elseif self.battles[keepID]:isBattle() or fromFlag then
        self.battles[keepID]:restart()
		if fromFlag then
			self.battles[keepID].flagUAsince = GetTimeStamp()
		end
    end
end

function CyrHUD:scanKeeps()

    if IsInImperialCity() then
	    -- Districts
		self:checkAdd(141)
		self:checkAdd(142)
		self:checkAdd(143)
		self:checkAdd(146)
		self:checkAdd(147)
		self:checkAdd(148)

	elseif IsInCyrodiil() then
	    -- Keeps / Resources
		for i=3,87 do
			self:checkAdd(i)
		end

		-- Outposts
		for i=132,134 do
			self:checkAdd(i)
		end
        
		-- Outposts
		for i=163,165 do
			self:checkAdd(i)
		end

		-- Towns
		self:checkAdd(149)
		self:checkAdd(151)
		self:checkAdd(152)

        if not CyrHUD.cfg.hideBridgesAndMilegates then
			-- Bridges / Milegates
			for i=154,162 do 
				self:checkAdd(i)
			end
		end
		
		-- Scroll temple Gates
		for i=124,129 do 
			self:checkAdd(i)
		end	
		
		-- Border Keeps: 105 to 110
		
		-- Scroll temples: 118 to 123
		   -- 118 altadoon 124 it's gate
		   -- 119 mnem     125 it's gate
		   -- 120 ghartok  126 it's gate
		   -- 121 chim     127 it's gate
		   -- 122 ni mohk  128 it's gate
		   -- 123 alma ruma 129 it's gate

		
		-- held Volendrung & Scrolls
		for i = 1, GetNumObjectives() do
		   local okeepId, objectiveId, obgContext = GetAvAObjectiveKeysByIndex(i)
	        if(IsLocalBattlegroundContext(obgContext)) then
			    local objectiveName, objectiveType, objectiveState = GetObjectiveInfo(okeepId, objectiveId, obgContext)
			   if objectiveType == OBJECTIVE_ARTIFACT_DEFENSIVE or objectiveType == OBJECTIVE_ARTIFACT_OFFENSIVE or objectiveType == OBJECTIVE_DAEDRIC_WEAPON then
			      local objectiveControlEvent = GetLastObjectiveControlEvent(okeepId, objectiveId, obgContext)
			      if objectiveState == OBJECTIVE_CONTROL_STATE_FLAG_DROPPED or objectiveState == OBJECTIVE_CONTROL_STATE_FLAG_HELD or objectiveControlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_SPAWNED then
			         local holdingAlliance, lastHoldingAlliance = GetCarryableObjectiveHoldingAllianceInfo(okeepId, objectiveId, obgContext)
				     local pinType = GetObjectivePinInfo(okeepId, objectiveId, obgContext) 
			         CyrHUD.SetMovingObjective(nil, okeepId, objectiveId, obgContext, objectiveName, objectiveType, objectiveControlEvent, objectiveState, holdingAlliance, lastHoldingAlliance, pinType)
			       
			      end 
			   end
		    end 
        end		

	end
end

----------------------------------------------
-- held Scrolls & Volendrung management
----------------------------------------------


function CyrHUD:addObj(objectiveId)
    if self.MovingObjectives[objectiveId] == nil then
        self.MovingObjectives[objectiveId] = self.MovingObjective(objectiveId)
    else
        self.MovingObjectives[objectiveId]:restart()
    end
end

function CyrHUD:checkAddObj(objectiveId)
    if self.MovingObjectives[objectiveId] == nil then
        local MovingObjective = self.MovingObjective(objectiveId)
       
        self.MovingObjectives[objectiveId] = MovingObjective
		
    else
        self.MovingObjectives[objectiveId]:restart()
    end
end


----------------------------------------------
-- Graveyards management
----------------------------------------------


function CyrHUD:addGraveyard(killLocation)
    if self.Graveyards[killLocation] == nil then
         self.Graveyards[killLocation] = self.Graveyard(killLocation)
    else
         self.Graveyards[killLocation]:restart()
    end
end

-- 05/07/2026 bug fix:
-- checkAddGraveyard indexed `self.Graveyard[killLocation]` instead of calling
-- the constructor `self.Graveyard(killLocation)`. self.Graveyard is the class
-- table, not keyed by location, so this always evaluated to nil -- meaning
-- checkAddGraveyard could never actually create a new Graveyard entry.
function CyrHUD:checkAddGraveyard(killLocation)
    if self.Graveyards[killLocation] == nil then
        local Graveyard = self.Graveyard(killLocation)
       
        self.Graveyards[killLocation] = Graveyard
		
    else
        self.Graveyards[killLocation]:restart()
    end
end

----------------------------------------------
-- Patrolling Horrors management
----------------------------------------------


-- 05/07/2026 bug fix:
-- The restart branch referenced `self.PatrollingHorror[areaBossName]`
-- (singular -- the class table) instead of `self.PatrollingHorrors[areaBossName]`
-- (plural -- the instance table checked in the `if` just above). Indexing the
-- class table by name returns nil, so calling :restart() on it would error
-- with "attempt to call a nil value" if this branch were ever reached.
function CyrHUD:addPatrollingHorror(areaBossName)
    if self.PatrollingHorrors[areaBossName] == nil then
         self.PatrollingHorrors[areaBossName] = self.PatrollingHorror(areaBossName)
    else
         self.PatrollingHorrors[areaBossName]:restart()
    end
end

function CyrHUD:engagePatrollingHorror(areaBossName)
    if self.PatrollingHorrors[areaBossName] == nil then
         self.PatrollingHorrors[areaBossName] = self.PatrollingHorror(areaBossName, true)
    end
end

-- 05/07/2026 bug fix:
-- checkAddPatrollingHorror indexed `self.PatrollingHorror[areaBossName]`
-- instead of calling the constructor `self.PatrollingHorror(areaBossName)`.
-- self.PatrollingHorror is the class table, not keyed by boss name, so this
-- always evaluated to nil -- meaning checkAddPatrollingHorror could never
-- actually create a new entry.
function CyrHUD:checkAddPatrollingHorror(areaBossName)
    if self.PatrollingHorrors[areaBossName] == nil then
        local PatrollingHorror = self.PatrollingHorror(areaBossName)
       
        self.PatrollingHorrors[areaBossName] = PatrollingHorror
		
    else
        self.PatrollingHorrors[areaBossName]:restart()
    end
end

--------------------------------------------------


-- 05/07/2026 performance improvement:
-- updateAll() runs on the 5-second KeepCheck timer and iterates every tracked
-- battle/objective/graveyard/patrolling horror. The old code took the value
-- pairs() already hands back on each iteration, threw it away as `_`, and then
-- re-indexed the same table with the key (self.battles[i], self.MovingObjectives[j],
-- self.Graveyards[k], self.PatrollingHorrors[k]) just to call :update() on it --
-- an extra, unnecessary table lookup per tracked entity per cycle for a value
-- we already had in hand.
function CyrHUD:updateAll()
    for _,battle in pairs(self.battles) do
        --Update in-place
        battle:update()
    end
	
	for _,movingObjective in pairs(self.MovingObjectives) do
       movingObjective:update()
    end
	
	for _,graveyard in pairs(self.Graveyards) do
       graveyard:update()
    end
	
	for _,patrollingHorror in pairs(self.PatrollingHorrors) do
       patrollingHorror:update()
    end

    for _,status in pairs(self.statusBars) do
        status:update()
    end

	-- to test
	if GetAssignedCampaignId() == self.campaign then
	   if #self.statusBars == 1 then
			CyrHUD:refresh()
	   end
	elseif IsInImperialCity() then
	   if #self.statusBars == 1 then
			CyrHUD:refresh()
	   end       
	else
	    if #self.statusBars == 2 then
			table.remove(self.statusBars, 2)
	   end 
	end
end



------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

CyrHUD.visible = false

function CyrHUD:init()
    --Init UI
    self:disableQuestTrackers()
    self.ui:SetHidden(false)

    --Populate data
    self:refresh()

    --Add events
    EVENT_MANAGER:RegisterForUpdate(CyrHUD.addonVars.name .. "KeepCheck", 5000, function()
        self:scanKeeps()
        self:updateAll()
		
		-- -- for testing scrolls & volendrung only (generate fake ones)
		-- if not trumpet then 
		     -- CyrHUD.SetMovingObjective(_, 2000, 2000, CyrHUD.battleContext, "Volendrung", OBJECTIVE_DAEDRIC_WEAPON, 145, OBJECTIVE_CONTROL_STATE_FLAG_DROPPED, 1, 2, MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI)

		     -- trumpet = true
		-- else
		     -- CyrHUD.SetMovingObjective(_, 2000, 2000, CyrHUD.battleContext, "Elder Scroll of Alma Ruma", OBJECTIVE_DAEDRIC_WEAPON, 145, OBJECTIVE_CONTROL_STATE_FLAG_AT_ENEMY_BASE, 1, 2, MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI)
		     -- trumpet = false  
		-- end
		-- if not done then 
		-- for objectiveIdCounter = 439, 462 do
		    -- local _, x, y = GetObjectivePinInfo(nil, objectiveIdCounter, CyrHUD.battleContext)
			-- local x, y = LibGPS3:LocalToGlobal(x, y)
		    -- d("["..objectiveIdCounter.."] = {[1] = "..x..",[2] = "..y..",},")
		-- end
		-- done = true
		-- end
	
		
		--for testing Graveyards only (generate fake ones)
		-- local killLocation = "verylongnamefromhell" --GetKeepName(math.random(162))
		-- if not killLocation or killLocation == "" then return end
		-- local killerPlayerAlliance = math.random(3)
		-- local victimPlayerAlliance = killerPlayerAlliance
		-- while (victimPlayerAlliance == killerPlayerAlliance) do
		       -- victimPlayerAlliance = math.random(3)
		-- end
		-- if not saxophone then 
		
		     -- CyrHUD.playerKilled(_, killLocation, "", "", killerPlayerAlliance, "", "", "", victimPlayerAlliance, "") 
		     -- saxophone = true
		-- else
		     -- CyrHUD.playerKilled(_, killLocation, "", "", killerPlayerAlliance, "", "", "", victimPlayerAlliance, "") 
		     -- saxophone = false  
		-- end
		
		
		
		--for testing Patrolling Horrors only (generate fake ones)
		-- if not piano then 
		     -- local self = CyrHUD	
			 -- local currentAreaName = string.gsub(GetPlayerLocationName(), "(%w+)[%^]+.*", "%1")
			 -- if not currentAreaName then return end
			 -- local areaBossName = currentAreaName.." "..GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES501)
			
			 -- if self.PatrollingHorrors[areaBossName] ~= nil then
			 
				-- CyrHUD.PatrollingHorrors[areaBossName]:restart()
			 -- else
			  	-- self:addPatrollingHorror(areaBossName)
			 -- end
		     -- piano = true
		-- else
		     -- local self = CyrHUD
                -- local currentAreaName = string.gsub(GetPlayerLocationName(), "(%w+)[%^]+.*", "%1")
				-- if not currentAreaName then return end
				-- local areaBossName = currentAreaName.." "..GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES501)
				
				-- if self.PatrollingHorrors[areaBossName] and self.PatrollingHorrors[areaBossName]:getRawDuration() >= 60 then -- Already dead before you arrive, we end the notification
					-- self.PatrollingHorrors[areaBossName].endPatrollingHorror = GetTimeStamp()
				-- end
		     -- piano = false  
		-- end
		
		
    end)

    EVENT_MANAGER:RegisterForUpdate(CyrHUD.addonVars.name .. "UIUpdate", 1000, function()
        self:printAll()
    end)

    EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."AttackChange", EVENT_KEEP_UNDER_ATTACK_CHANGED, self.eventAttackChange)
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."ObjectiveControlState", EVENT_OBJECTIVE_CONTROL_STATE, self.SetFlagStateData)
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."ArtifactControlState", EVENT_ARTIFACT_CONTROL_STATE, self.SetArtifactStateData)
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."ArtifactControlStatePreSet", EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED, self.PreSetArtifactStateData) 
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."ArtifactControlSpawned", EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED, self.ArtifactSpawned)
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."GateChange", EVENT_KEEP_GATE_STATE_CHANGED, function(_, keepID, open) self.eventAttackChange(_, keepID, CyrHUD.battleContext)  end)
    -- 20/07/2026 bug fix:
    -- This closure's own parameter is named `keepId` (lowercase d), but the
    -- call below referenced `keepID` (uppercase D) -- a different, never-
    -- assigned identifier. Lua is case-sensitive and there's no local/upvalue
    -- named `keepID` in scope here, so that reference silently resolved to
    -- the undefined global `keepID`, i.e. always nil. That meant every
    -- EVENT_KEEP_IS_PASSABLE_CHANGED (a milegate or bridge becoming passable
    -- or impassable) called eventAttackChange(_, nil, ...) instead of
    -- eventAttackChange(_, keepId, ...) -- so GetKeepType(nil) was queried
    -- instead of the actual keep that changed, and CyrHUD:add()/update()
    -- never ran for the correct milegate/bridge on this event. The handler
    -- right above it (GateChange) uses a parameter actually named `keepID`
    -- and was unaffected. Fixed to reference the correct parameter.
  EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."PassableChange", EVENT_KEEP_IS_PASSABLE_CHANGED, function(_, keepId, battlegroundContext, isPassable) self.eventAttackChange(_, keepId, CyrHUD.battleContext) end)
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."KillFeed", EVENT_PVP_KILL_FEED_DEATH, function(_, killLocation, killerPlayerCharacterName, killerPlayerDisplayName, killerPlayerAlliance, killerPlayerRank, victimPlayerCharacterName, victimPlayerDisplayName, victimPlayerAlliance, victimPlayerRank)  CyrHUD.playerKilled(_, killLocation, killerPlayerCharacterName, killerPlayerDisplayName, killerPlayerAlliance, killerPlayerRank, victimPlayerCharacterName, victimPlayerDisplayName, victimPlayerAlliance, victimPlayerRank) end)
	EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name.."CampaignDataReceived",EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED, function() CyrHUD.CampaignDataPending = false end)


    self.visible = true

    EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name, EVENT_ACTION_LAYER_POPPED, self.actionLayerChange)
    EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name, EVENT_ACTION_LAYER_PUSHED, self.actionLayerChange)
end

function CyrHUD:refresh()
    --Get initial scan
    self.battles = {}
	  self.MovingObjectives = {}
	  self.Graveyards = {}
	  self.PatrollingHorrors  = {}
    self.battleContext = BGQUERY_LOCAL

    -- 20/07/2026 bug fix:
    -- This register/unregister block used to live inside the
    -- "self.campaign ~= GetCurrentCampaignId()" branch below, which only runs
    -- when the player's campaign has actually changed. But it's the only
    -- code that reacts to CyrHUD.cfg.hidePatrollingHorrors, and menu.lua's
    -- "Hide Patrolling Horrors" checkbox setFunc calls CyrHUD:refresh()
    -- directly, with no campaign change involved. That meant toggling the
    -- checkbox mid-session never actually registered/unregistered
    -- EVENT_UNIT_DEATH_STATE_CHANGED/EVENT_RETICLE_TARGET_CHANGED -- it only
    -- cleared self.PatrollingHorrors once (line above), which onMonsterDeath/
    -- onMonsterReticle would then just start repopulating on the very next
    -- boss death or reticle-over, or (if starting from "hidden") the events
    -- would simply never get registered until the player changed campaigns
    -- or reloaded the UI. Moved out of the campaign-change gate so every
    -- refresh() call -- whichever of scanKeeps/playerInit/the settings menu
    -- triggered it -- re-evaluates the current setting.
    if IsInImperialCity() and not CyrHUD.cfg.hidePatrollingHorrors then -- reset Imperial City Boss timers & manage corresponding events
        EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name, EVENT_UNIT_DEATH_STATE_CHANGED, self.onMonsterDeath)
        EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name, EVENT_RETICLE_TARGET_CHANGED, self.onMonsterReticle)
    else
        EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name, EVENT_UNIT_DEATH_STATE_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name, EVENT_RETICLE_TARGET_CHANGED)
    end
	
	if self.campaign ~= GetCurrentCampaignId() then 
	    self:disableQuestTrackers()
	    CyrHUD.imperialKeeps = nil -- reset imperial keeps/ Imperial City Districts
		--CyrHUD.yourKills = 0
        --CyrHUD.yourDeaths = 0
		self.ImperialCityBossTimers = {}
		self.ArtifactHolders = {}
	end
	
    self.campaign = GetCurrentCampaignId()

    --Could separate this with a data refresh eventually, but just do a hard reset for now
    self.statusBars = {}
    table.insert(self.statusBars, self.ScoringBar())
	if GetAssignedCampaignId() == self.campaign or IsInImperialCity() then
	   table.insert(self.statusBars, 2, self.RankingBar())
	end
    self:scanKeeps()

    --Force update on status bar
    self:reconfigureLabels()
end


function CyrHUD:setWaypoint(x,y)
    if x ~= nil and y ~= nil then
	
	   if IsUnitGroupLeader("player") then
	       --if GetCurrentMapId() ~= 16 then SetMapToMapId(16) end
	       PingMap(MAP_PIN_TYPE_RALLY_POINT, MAP_TYPE_LOCATION_CENTERED, x, y)
		   --SetMapToPlayerLocation()
	   else
	       --if GetCurrentMapId() ~= 16 then SetMapToMapId(16) end
	       PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, y)
		   --SetMapToPlayerLocation()
	   end
    end	
end

function CyrHUD:disableQuestTrackers()
    self.trackers = self.trackers or {}

    if IsInCyrodiil() then
		--Ravalox Questtracker
		if QuestTrackerWin then
			self.trackers.QuestTrackerWin = self.trackers.QuestTrackerWin or QuestTrackerWin:IsHidden() -- Tracker hidden state before CyrHUD init to restore on CyrHUD deinit  
			QuestTrackerWin:SetHidden(self.cfg.ravTrackerDisableCyro)
		end

		--ZOs build in game quest tracker
		self.trackers.ZO_FocusedQuestTrackerPanel = self.trackers.ZO_FocusedQuestTrackerPanel or ZO_FocusedQuestTrackerPanel:IsHidden() -- Tracker hidden state before CyrHUD init to restore on CyrHUD deinit  
		ZO_FocusedQuestTrackerPanel:SetHidden(self.cfg.zosTrackerDisableCyro)
		
	elseif IsInImperialCity() then
		--Ravalox Questtracker
		if QuestTrackerWin then
			self.trackers.QuestTrackerWin = self.trackers.QuestTrackerWin or QuestTrackerWin:IsHidden() -- Tracker hidden state before CyrHUD init to restore on CyrHUD deinit  
			QuestTrackerWin:SetHidden(self.cfg.ravTrackerDisableIC)
		end

		--ZOs build in game quest tracker
		self.trackers.ZO_FocusedQuestTrackerPanel = self.trackers.ZO_FocusedQuestTrackerPanel or ZO_FocusedQuestTrackerPanel:IsHidden() -- Tracker hidden state before CyrHUD init to restore on CyrHUD deinit  
		ZO_FocusedQuestTrackerPanel:SetHidden(self.cfg.zosTrackerDisableIC)
	end
end

function CyrHUD:reEnableQuestTrackers()
    if self.trackers then
        for k,v in pairs(self.trackers) do
            if _G[k] ~= nil then _G[k]:SetHidden(false) end
        end
    end
end

function CyrHUD:deinit()
    self:reEnableQuestTrackers()

    EVENT_MANAGER:UnregisterForUpdate(CyrHUD.addonVars.name.."KeepCheck")
    EVENT_MANAGER:UnregisterForUpdate(CyrHUD.addonVars.name.."UIUpdate")
    EVENT_MANAGER:UnregisterForUpdate(CyrHUD.addonVars.name.."UpdateAPCount")
    EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name, EVENT_ACTION_LAYER_POPPED)
	
    EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name, EVENT_ACTION_LAYER_PUSHED)
    EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."AttackChange", EVENT_KEEP_UNDER_ATTACK_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."ObjectiveControlState", EVENT_OBJECTIVE_CONTROL_STATE)
	  EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."ArtifactControlState", EVENT_ARTIFACT_CONTROL_STATE) 
  	EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."GateChange", EVENT_KEEP_GATE_STATE_CHANGED)
  	EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."PassableChange", EVENT_KEEP_IS_PASSABLE_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."KillFeed", EVENT_PVP_KILL_FEED_DEATH)
  	EVENT_MANAGER:UnregisterForEvent(CyrHUD.addonVars.name.."CampaignDataReceived",EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED)

    CyrHUD_UI:SetHidden(true)
    self.visible = false
end

function CyrHUD.toggle()
    local self = CyrHUD

    if self.visible then
        self:deinit()
    else
        self:init()
    end
end


SLASH_COMMANDS["/cyrhud"] = CyrHUD.toggle

--Called once. Handles controls, etc.
function CyrHUD.addonInit()
    local self = CyrHUD

    --Init saved variables
    local def = {
        xoff = -10,
        yoff = 60,
        ravTrackerDisableCyro = false,
		zosTrackerDisableCyro = false,
		ravTrackerDisableIC = false,
		zosTrackerDisableIC = false,
		hideImpBattles = false,
		hideBridgesAndMilegates = false,
		hidePatrollingHorrors = false,
		enableInCyro = true,
		enableInIC = true,
    showPopBars = false,
    }

    self.cfg = ZO_SavedVars:NewAccountWide("CyrHUD_SavedVars", 1.0, "config", def)

    --Create UI
    self.ui = GetControl("CyrHUD_UI")
    self.ui:SetWidth(CyrHUD.width)
    self.ui:SetHeight(CyrHUD.width)
    self.ui:SetMouseEnabled(true)
    --self.ui:SetMovable(true)
    self.ui:SetClampedToScreen(true)
   -- self.ui:SetHandler("OnMoveStop", self.saveWindowPosition)

    --local _, pt, relTo, relPt = CyrHUD_UI:GetAnchor()
    --self.ui:ClearAnchors()
    --self.ui:SetAnchor(CyrHUD.cfg.selfPoint or TOPLEFT, GuiRoot, CyrHUD.cfg.anchPoint or TOPRIGHT, CyrHUD.cfg.xoff, CyrHUD.cfg.yoff)
    
    HUD_MANAGER:RegisterKeyboardElement(self.ui, "CyrHUD", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) -- for Keyboard UI 
    HUD_MANAGER:RegisterGamepadElement(self.ui, "CyrHUD", { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 40) }, COMPASS_OPTIONS) --for Gamepad UI

    --Create settings menu
    local LAM = LibAddonMenu2
    LAM:RegisterAddonPanel(CyrHUD.addonVars.name .. "-LAM", self.menuPanel)
    LAM:RegisterOptionControls(CyrHUD.addonVars.name .. "-LAM", self.menuOptions)
    self.initLAM = true
end

function CyrHUD.playerInit()
    local self = CyrHUD

    if not self.initLAM then
        self.addonInit()
    end


    if IsPlayerInAvAWorld() then
          if IsInImperialCity() and not self.cfg.enableInIC then
             self:deinit()
             return
          elseif not IsInImperialCity() and not self.cfg.enableInCyro then
             self:deinit()
             return
          end
          
          if self.visible then
              if CyrHUD.campaignID ~= GetCurrentCampaignId() then
                  self:refresh()
              end 
          else
              self:init()
          end
          CyrHUD.campaignID = GetCurrentCampaignId()	
    elseif self.visible then
          self:deinit()
    end
end

EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name .. "-init", EVENT_PLAYER_ACTIVATED, CyrHUD.playerInit)
EVENT_MANAGER:RegisterForEvent(CyrHUD.addonVars.name .. "-init", EVENT_ADD_ON_LOADED, function() CyrHUD.playerInit() EVENT_MANAGER:UnregisterForEvent(EVENT_ADD_ON_LOADED) end)