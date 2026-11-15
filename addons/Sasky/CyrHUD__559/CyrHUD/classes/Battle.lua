-- This file is part of CyrHUD
--
-- (C) 2014 Scott Yeskie (Sasky)
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

local function n0(val) if val == nil then return 0 end return val end

-- Setup class
CyrHUD.Battle = {}
CyrHUD.Battle.__index = CyrHUD.Battle
CyrHUD.Battle.type = "Battle"

setmetatable(CyrHUD.Battle, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

local shortenResourceName = function(str)
    str = LocalizeString('<<1>>', str)
    return str:gsub("%^.d$", "")
        :gsub("Castle ","")
        :gsub("[fF]ort ","")
        :gsub("Keep ","")
        :gsub("Lumber ","")
    --DE
        :gsub("Burg ","")
        :gsub("Feste ","")
        :gsub("Kastells ","")
        :gsub("Holzfällerlager ","")
        :gsub("Bauernhof ","")
        :gsub("Mine ","")
        :gsub("des ","")
        :gsub("der ","")
end

local shortenKeepName = function(str)
    str = LocalizeString('<<1>>', str) 
    return str:gsub(",..$", ""):gsub("%^.d$", "")
		:gsub("District", "")
		:gsub("Scroll Temple of ", "")
	--FR
        :gsub("avant.poste d[eu] ", "")
        :gsub("bastille d[eu]s? ", "")
        :gsub("fort de la ", "")
    --DE
        :gsub("Kastell ", "")
        :gsub("Burg ", "")
        :gsub("Feste ", "")
        :gsub("Schriftentempel von ", "Tempel ")
        :gsub("-Schriftrolle ", "-Rolle")
        :gsub(" Jagdgründe", "")
        :gsub("Carmala-Außenposten'", "Carmala")
        :gsub("Nikels Außenposten", "Nikels")
        :gsub("Sejanus' Außenposten", "Sejanus")
        :gsub("Harluns Außenposten", "Harluns")
        :gsub("Winterweite-Außenposten", "Winterweite")
        :gsub("die ","")
        :gsub("das ","")
end

----------------------------------------------
-- Creation
----------------------------------------------

CyrHUD.Battle.new = function(keepID)
    local self = setmetatable({}, CyrHUD.Battle)

    self.startBattle = self.startBattle or GetTimeStamp()
    self.endBattle = nil
    -- 05/07/2026 performance improvement:
    -- checkAdd() constructs a throwaway CyrHUD.Battle(keepID) for every keep that
    -- isn't already tracked, every 5 seconds (self:scanKeeps -> self:checkAdd),
    -- just to call isBattle() on it -- and for the large majority of the ~90
    -- keeps/outposts/towns/gates scanned, isBattle() is false and the object is
    -- immediately discarded. isBattle() only needs self.keepType, self.gateOpen,
    -- self.keepUA/self.keepCut and self.siege -- it never needs the display name.
    -- The old code unconditionally ran GetKeepName() + LocalizeString() + ~20
    -- chained gsub() calls (shortenKeepName/shortenResourceName) right here in
    -- the constructor, so that expensive string work happened for every
    -- discarded, never-displayed keep on every scan. We now only remember
    -- whether this is a resource keep, and compute/cache the actual name lazily
    -- via getKeepName() the first time it's actually needed for display -- which
    -- only happens for battles that survive isBattle() and get shown in the UI.
    self.keepID = keepID
    self.keepType = GetKeepType(keepID)
    self.isResourceKeep = (self.keepType == KEEPTYPE_RESOURCE)

    if self.isResourceKeep then
        self.keepType = 10 + GetKeepResourceType(keepID)
    end
	
	local pinType, nX, nY = GetKeepPinInfo(self.keepID, CyrHUD.battleContext)
	self.nX = nX
	self.nY = nY
	
	
	if self.keepType == KEEPTYPE_ARTIFACT_GATE or self.keepType == KEEPTYPE_BRIDGE or self.keepType == KEEPTYPE_MILEGATE then

		local gateOpen = false
		if pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_ALDMERI_DOMINION or pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_DAGGERFALL_COVENANT or pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_EBONHEART_PACT then
			gateOpen = true
		elseif pinType == MAP_PIN_TYPE_KEEP_BRIDGE_IMPASSABLE or pinType == MAP_PIN_TYPE_KEEP_MILEGATE_IMPASSABLE or pinType == MAP_PIN_TYPE_KEEP_MILEGATE_CENTER_DESTROYED then
		    gateOpen = true -- yep, it should be keepImpassable = true but the code is cleaner/has less lines like that   
		end
		self.gateOpen = gateOpen
		
		if self.keepType == KEEPTYPE_ARTIFACT_GATE then -- only display scroll gates if there is a scroll in the temple
			local gateTemple = self.keepID - 6
		    local scrollObjectiveId = GetKeepArtifactObjectiveId(gateTemple)
			local scrolIsAtBase = GetObjectiveControlState(gateTemple, scrollObjectiveId, CyrHUD.battleContext) == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE
			if scrolIsAtBase then
			     self.gateTempleHasScroll = true
			else
			     self.gateTempleHasScroll = false
			end
		end
	end
	
	
	

	self.cyroChatIcon = nil
    self.siege = {}

    self:update()

    return self
end

--[[
    Lazily computes and caches the display name for this keep.
    See the 05/07/2026 performance improvement note above Battle.new() for why
    this isn't computed eagerly in the constructor.
]]
function CyrHUD.Battle:getKeepName()
    if not self.keepName then
        local name = shortenKeepName(GetKeepName(self.keepID))
        if self.isResourceKeep then
            name = shortenResourceName(name)
        end
        self.keepName = name
    end
    return self.keepName
end

----------------------------------------------
-- Label update
----------------------------------------------

--Label fields
local L_ICON, L_UA = "img1", "img2"
local CYROCHAT_ICON = 'img4'
local L_NAME, L_ATT_SIEGE, L_DEF_SIEGE, L_TIME = "txt1", "txt2", "txt3", "txt4"
local L_LUMB, L_MINE, L_FARM = "img5", "img6", "img7"
local L_SCROLL = "img8"
local L_ICON_DEATHS_AD, L_ICON_DEATHS_EP, L_ICON_DEATHS_DC = "img12", "img13", "img14"
local L_DEATHS_AD, L_DEATHS_EP, L_DEATHS_DC = "txt11", "txt12", "txt13"
local L_KILLS_AD, L_KILLS_EP, L_KILLS_DC = "txt23", "txt24", "txt25"
local LEGEND_KILLS, LEGEND_DEATHS = "txt26", "txt27"
local L_ATT_SIEGE_ICON, L_DEF_SIEGE_ICON = "img15", "img16"
local L_CONNECTED = "img17"
local L_ARROW = "img18"
local L_HOLDER = "txt16"

local ICON_EMPEROR = "img25"
local TEXT_PLAYERNAME = "txt17"
local TEXT_RIVALNAME = "txt18"
local TEXT_PLAYERRANK = "txt19"
local TEXT_RIVALRANK = "txt20"
local TEXT_PLAYERSCORE = "txt21"
local TEXT_RIVALSCORE = "txt22"

local ICON_ASH = "img26"
local ICON_WELL = "img27"
local ICON_CHAL = "img28"
local ICON_BRK = "img29"
local ICON_SIA = "img30"
local ICON_ROE = "img31"


function CyrHUD.Battle:configureLabel(label)
    label:exposeControls(2,4)

	-- CyroChat Battles
	label:positionControl(CYROCHAT_ICON, 40, 40, -35, -2)

    -- Objective icon
    label:positionControl(L_ICON, 40, 40, -2, -2)
    label:getControl(L_ICON):SetDrawLayer(2)

    -- Under attack graphic
    label:positionControl(L_UA, 40, 40, -2, -2)
    local ua = label:getControl(L_UA)
    ua:SetDrawLayer(1)
    ua:SetTexture(CyrHUD.info.underAttack)

    --Objective name
    label:positionControl(L_NAME, 150, 30, 35, 5)
	
	-- Animated arrow
    label:positionControl(L_ARROW, 20, 20, 35, 7)
    label:getControl(L_ARROW):SetTexture(CyrHUD.icons["arrow"]) 
	label:getControl(L_ARROW):SetTransformRotationZ(math.rad(180))
	label:getControl(L_ARROW):SetAlpha(0)
	
	--Holder name
	label:positionControl(L_HOLDER, 150, 30, 35, 20)

	
	--Keep resources around keep
	label:getControl(L_LUMB):SetDrawLayer(4)
	label:getControl(L_MINE):SetDrawLayer(4)
	label:getControl(L_FARM):SetDrawLayer(4)
	label:positionControl(L_LUMB, 20, 20, -5, -5) 
	label:positionControl(L_MINE, 20, 20, -5, 20) 
	label:positionControl(L_FARM, 20, 20, 22, 20) 
	
	-- keep is connected icon
	label:getControl(L_CONNECTED):SetDrawLayer(4)
	label:positionControl(L_CONNECTED, 40, 40, -2, -2)
	label:getControl(L_CONNECTED):SetTexture(CyrHUD.icons["ConnectedKeep"]) 
	label:getControl(L_CONNECTED):SetColor(CyrHUD.info.linkColor:UnpackRGBA())
	
	-- Scroll on objective icon
	label:getControl(L_SCROLL):SetDrawLayer(3)
	label:positionControl(L_SCROLL, 50, 50, -6, -6)

    --Defensive siege count
    label:positionControl(L_DEF_SIEGE, 30, 30, 224, 5) 
	label:positionControl(L_DEF_SIEGE_ICON, 30, 30, 210, 0)
	label:getControl(L_DEF_SIEGE_ICON):SetTexture(CyrHUD.icons["defSiege"])
	label:getControl(L_DEF_SIEGE_ICON):SetColor(CyrHUD.info[4].color:UnpackRGBA())

    --Attacker siege count
    label:positionControl(L_ATT_SIEGE, 30, 30, 190, 5)
	label:positionControl(L_ATT_SIEGE_ICON, 30, 30, 180, 0)
	label:getControl(L_ATT_SIEGE_ICON):SetTexture(CyrHUD.icons["offSiege"])
	label:getControl(L_ATT_SIEGE_ICON):SetColor(CyrHUD.info[4].color:UnpackRGBA())
	
    --Time
    label:positionControl(L_TIME, 35, 30, 245, 5) 
end

function CyrHUD.SetFlagStateData(eventCode, keepId, objectiveId, battlegroundContext, objectiveName, objectiveType, objectiveControlEvent, state, holdingAlliance, attackingAlliance, pinType)
    if objectiveType ~= OBJECTIVE_CAPTURE_AREA then
        if objectiveType == OBJECTIVE_ARTIFACT_DEFENSIVE or objectiveType == OBJECTIVE_ARTIFACT_OFFENSIVE or objectiveType == OBJECTIVE_DAEDRIC_WEAPON then	
		    CyrHUD.SetMovingObjective(eventCode, keepId, objectiveId, battlegroundContext, objectiveName, objectiveType, objectiveControlEvent, state, holdingAlliance, attackingAlliance, pinType)
		end
	    return 
	end

	-- 05/07/2026 performance improvement:
	-- SetFlagStateData() fires on every EVENT_OBJECTIVE_CONTROL_STATE change,
	-- which happens repeatedly as a flag/capture-area progresses through its
	-- attack steps during active sieges. The old code re-indexed the
	-- three-level global table chain `CyrHUD.flags[keepId][objectiveId]` 15
	-- times in a row (each one two global table lookups plus two indexes) to
	-- read/write fields on the exact same table. We now resolve it once into
	-- a local and reuse that local for every access.
	CyrHUD.flags = CyrHUD.flags or {}
	CyrHUD.flags[keepId] = CyrHUD.flags[keepId] or {}
	CyrHUD.flags[keepId][objectiveId] = CyrHUD.flags[keepId][objectiveId] or {}
	local flag = CyrHUD.flags[keepId][objectiveId]

	-- we set everything to 0
    flag[0] = 0
    flag[1] = 0
    flag[2] = 0
    flag[3] = 0

	
	-- add 16.666% each step (100/6 for the 7 steps of an attack)
	   if state == OBJECTIVE_CONTROL_STATE_AREA_ABOVE_CONTROL_THRESHOLD then -- 6 none attacks defending alliance with positive or negative attack, second or sixth step of an attack
	      	 flag[holdingAlliance] = 66.666 --80
		     flag[attackingAlliance] = 33.333 --20
			 flag.defender = holdingAlliance 
	   elseif state == OBJECTIVE_CONTROL_STATE_AREA_BELOW_CONTROL_THRESHOLD then  -- 5 attacking alliance attacks none with positive or negative attack, third or fith step of an attack
	         flag[holdingAlliance] = 51 --40
		     flag[attackingAlliance] = 49 --60
			 flag.defender = holdingAlliance
	   elseif state == OBJECTIVE_CONTROL_STATE_AREA_NO_CONTROL then -- 4  none attacks none, flag is neutral, fourth step of attack 
             flag[attackingAlliance] = 100
	   elseif state == OBJECTIVE_CONTROL_STATE_AREA_MAX_CONTROL then -- 7  none attacks defending alliance with positive or negative attack, first or seventh (last) step of an attack
	         flag[holdingAlliance] = 83.333 --90
			 flag[attackingAlliance] = 16.666 --10
			 flag.defender = holdingAlliance
	   else
            return
	   end 
	   
    --d(GetKeepName(keepId).." "..GetAllianceName(attackingAlliance).." attacks "..GetAllianceName(holdingAlliance).." "..state )
	
	CyrHUD:checkAdd(keepId, true) 
end

function CyrHUD.UTF8ToCharArray(str)
     local charArray = {}
     local iStart = 0
     local strLen = str:len()

     local function bit(b)
           return 2 ^ (b - 1)
     end

     local function hasbit(w, b)
           return w % (b + b) >= b
     end

     local function checkMultiByte(i)
           if (iStart ~= 0) then
               charArray[#charArray + 1] = str:sub(iStart, i - 1)
               iStart = 0
           end
     end

     for i = 1, strLen do
         local b = str:byte(i)
         local multiStart = hasbit(b, bit(7)) and hasbit(b, bit(8))
         local multiTrail = not hasbit(b, bit(7)) and hasbit(b, bit(8))
         if (multiStart) then
            checkMultiByte(i)
            iStart = i
         elseif (not multiTrail) then
            checkMultiByte(i)
            charArray[#charArray + 1] = str:sub(i, i)
         end
     end

      -- process if last character is multi-byte 
     checkMultiByte(strLen + 1)
     return charArray
end

-- 05/07/2026 performance improvement:
-- SetColouredName() calls this up to 4 times (once per alliance color segment
-- plus the "rest") every second for any keep with contested capture progress.
-- The old version built the result with `str = str..v` inside a loop, which is
-- O(n^2) in Lua since each `..` allocates a brand new string; it also used
-- `pairs()` and `table.insert()` on what is really a plain array, both of which
-- carry more overhead than `ipairs()` and direct index assignment. We now
-- collect the pieces into a table and join them once with table.concat (an
-- O(n) single-pass operation), and use ipairs()/direct indexing for the array
-- traversal.
function CyrHUD.charArrayToString(array, limit)
	local strParts = {}
	local newArray = {}
	local newArrayCount = 0
	for i, v in ipairs(array) do
		if i <= limit then
		    strParts[i] = v
        else
            newArrayCount = newArrayCount + 1
            newArray[newArrayCount] = v
		end   
	end
    return table.concat(strParts), newArray	
end


function CyrHUD.SetFlagGauges(label,keep) -- set flag gauges
    local holder = label:getControl(L_HOLDER)
	  local gaugeMessage = ""
    local iconsize = 14
    
    if CyrHUD.flags and CyrHUD.flags[keep.keepID] and NonContiguousCount(CyrHUD.flags[keep.keepID]) > 0 then 

       if (keep.keepType == KEEPTYPE_KEEP or keep.keepType == KEEPTYPE_OUTPOST) then
	       local lowerFlagId = CyrHUD.keepsToObjectivesMap[keep.keepID].lower
	       local upperFlagId = CyrHUD.keepsToObjectivesMap[keep.keepID].upper
		   
		   CyrHUD.flags[keep.keepID][lowerFlagId] = CyrHUD.flags[keep.keepID][lowerFlagId] or {}
		   local lowerFlagAD = CyrHUD.flags[keep.keepID][lowerFlagId][1] or 0
		   local lowerFlagEP = CyrHUD.flags[keep.keepID][lowerFlagId][2] or 0
		   local lowerFlagDC = CyrHUD.flags[keep.keepID][lowerFlagId][3] or 0
		   local lowerFlagNE = CyrHUD.flags[keep.keepID][lowerFlagId][0] or 0
		   local lowerDefender =  CyrHUD.flags[keep.keepID][lowerFlagId].defender or 0
		   if lowerDefender == 0 then lowerDefender = keep.defender end
		   
		   local maxLowerFlagValue = math.max(lowerFlagAD,lowerFlagEP,lowerFlagDC)
		   
		   local texture = CyrHUD.info["gauge"][0][0]["100"]
		   
		   if lowerFlagNE == 100 then

		   elseif maxLowerFlagValue == 0 then	
			      texture = CyrHUD.info["gauge"][lowerDefender][0]["100"] 
           elseif lowerFlagAD == maxLowerFlagValue then
		          texture = CyrHUD.info["gauge"][1][0][tostring(lowerFlagAD)] 
           elseif lowerFlagEP == maxLowerFlagValue then
		          texture = CyrHUD.info["gauge"][2][0][tostring(lowerFlagEP)]
           elseif lowerFlagDC == maxLowerFlagValue then	
		          texture = CyrHUD.info["gauge"][3][0][tostring(lowerFlagDC)]
		   end
		   
		   gaugeMessage = zo_iconTextFormatNoSpace(texture,iconsize,iconsize,"")
		   
		   CyrHUD.flags[keep.keepID][upperFlagId] = CyrHUD.flags[keep.keepID][upperFlagId] or {}
		   local upperFlagAD = CyrHUD.flags[keep.keepID][upperFlagId][1] or 0
		   local upperFlagEP = CyrHUD.flags[keep.keepID][upperFlagId][2] or 0
		   local upperFlagDC = CyrHUD.flags[keep.keepID][upperFlagId][3] or 0
		   local upperFlagNE = CyrHUD.flags[keep.keepID][upperFlagId][0] or 0
		   local upperDefender =  CyrHUD.flags[keep.keepID][upperFlagId].defender or 0
		   if upperDefender == 0 then upperDefender = keep.defender end
		   
		   local texture2 = CyrHUD.info["gauge"][0][0]["100"]
		   local maxUpperFlagValue = math.max(upperFlagAD,upperFlagEP,upperFlagDC)
		   if upperFlagNE == 100 then
		   
		   elseif maxUpperFlagValue == 0 then
                  texture2 = CyrHUD.info["gauge"][upperDefender][0]["100"] 				  
           elseif upperFlagAD == maxUpperFlagValue then	
                  texture2 = CyrHUD.info["gauge"][1][0][tostring(upperFlagAD)]				  
           elseif upperFlagEP == maxUpperFlagValue then
				  texture2 = CyrHUD.info["gauge"][2][0][tostring(upperFlagEP)]
           elseif upperFlagDC == maxUpperFlagValue then	
                  texture2 = CyrHUD.info["gauge"][3][0][tostring(upperFlagDC)]		   
		   end
		   
		   gaugeMessage = gaugeMessage.."     "..zo_iconTextFormatNoSpace(texture2,iconsize,iconsize,"")
		   
	   elseif keep.keepType == KEEPTYPE_TOWN then

       local merchantFlagId = CyrHUD.keepsToObjectivesMap[keep.keepID].merchant
	     local centralFlagId = CyrHUD.keepsToObjectivesMap[keep.keepID].central
		   local outlierFlagId = CyrHUD.keepsToObjectivesMap[keep.keepID].outlier
		   
		   CyrHUD.flags[keep.keepID][merchantFlagId] = CyrHUD.flags[keep.keepID][merchantFlagId] or {}
		   local merchantFlagAD = CyrHUD.flags[keep.keepID][merchantFlagId][1] or 0
		   local merchantFlagEP = CyrHUD.flags[keep.keepID][merchantFlagId][2] or 0
		   local merchantFlagDC = CyrHUD.flags[keep.keepID][merchantFlagId][3] or 0
		   local merchantFlagNE = CyrHUD.flags[keep.keepID][merchantFlagId][0] or 0
		   local merchantDefender =  CyrHUD.flags[keep.keepID][merchantFlagId].defender or 0
		   if merchantDefender == 0 then merchantDefender = keep.defender end

		   
		   local texture = CyrHUD.info["gauge"][0][0]["100"]
		   local maxMerchantFlagValue = math.max(merchantFlagAD,merchantFlagEP,merchantFlagDC)
		   if merchantFlagNE == 100 then

		   elseif maxMerchantFlagValue == 0 then	
                  texture = CyrHUD.info["gauge"][merchantDefender][0]["100"]				  
           elseif merchantFlagAD == maxMerchantFlagValue then
                  texture = CyrHUD.info["gauge"][1][0][tostring(merchantFlagAD)] 		   
           elseif merchantFlagEP == maxMerchantFlagValue then
		          texture = CyrHUD.info["gauge"][2][0][tostring(merchantFlagEP)]
           elseif merchantFlagDC == maxMerchantFlagValue then	
                  texture = CyrHUD.info["gauge"][3][0][tostring(merchantFlagDC)]		   
		   end
		   
		   gaugeMessage = zo_iconTextFormatNoSpace(texture,iconsize,iconsize,"")
		   
		   CyrHUD.flags[keep.keepID][centralFlagId] = CyrHUD.flags[keep.keepID][centralFlagId] or {}
		   local centralFlagAD = CyrHUD.flags[keep.keepID][centralFlagId][1] or 0
		   local centralFlagEP = CyrHUD.flags[keep.keepID][centralFlagId][2] or 0
		   local centralFlagDC = CyrHUD.flags[keep.keepID][centralFlagId][3] or 0
		   local centralFlagNE = CyrHUD.flags[keep.keepID][centralFlagId][0] or 0
		   local centrelDefender =  CyrHUD.flags[keep.keepID][centralFlagId].defender or 0
		   if centrelDefender == 0 then centrelDefender = keep.defender end
		   
		   local texture2 = CyrHUD.info["gauge"][0][0]["100"]
		   local maxCentralFlagValue = math.max(centralFlagAD,centralFlagEP,centralFlagDC)
		   if centralFlagNE == 100 then

		   elseif maxCentralFlagValue == 0 then	
                   texture2 = CyrHUD.info["gauge"][centrelDefender][0]["100"]				 
           elseif centralFlagAD == maxCentralFlagValue then	
		           texture2 = CyrHUD.info["gauge"][1][0][tostring(centralFlagAD)]
           elseif centralFlagEP == maxCentralFlagValue then
		           texture2 = CyrHUD.info["gauge"][2][0][tostring(centralFlagEP)]
           elseif centralFlagDC == maxCentralFlagValue then	
                   texture2 = CyrHUD.info["gauge"][3][0][tostring(centralFlagDC)]		   
		   end
		   
		   gaugeMessage = gaugeMessage.."     "..zo_iconTextFormatNoSpace(texture2,iconsize,iconsize,"")
		   
		   
		   CyrHUD.flags[keep.keepID][outlierFlagId] = CyrHUD.flags[keep.keepID][outlierFlagId] or {}
		   local outlierFlagAD = CyrHUD.flags[keep.keepID][outlierFlagId][1] or 0
		   local outlierFlagEP = CyrHUD.flags[keep.keepID][outlierFlagId][2] or 0
		   local outlierFlagDC = CyrHUD.flags[keep.keepID][outlierFlagId][3] or 0
		   local outlierFlagNE = CyrHUD.flags[keep.keepID][outlierFlagId][0] or 0
		   local outlierDefender =  CyrHUD.flags[keep.keepID][outlierFlagId].defender or 0
		   if outlierDefender == 0 then outlierDefender = keep.defender end
		   
		   local texture3 = CyrHUD.info["gauge"][0][0]["100"]
		   local maxOutlierFlagValue = math.max(outlierFlagAD,outlierFlagEP,outlierFlagDC)
		   if outlierFlagNE == 100 then

		   elseif maxOutlierFlagValue == 0 then	
                  texture3 = CyrHUD.info["gauge"][outlierDefender][0]["100"]				  
           elseif outlierFlagAD == maxOutlierFlagValue then
                  texture3 = CyrHUD.info["gauge"][1][0][tostring(outlierFlagAD)]		   
           elseif outlierFlagEP == maxOutlierFlagValue then
		          texture3 = CyrHUD.info["gauge"][2][0][tostring(outlierFlagEP)]  
           elseif outlierFlagDC == maxOutlierFlagValue then	
                  texture3 = CyrHUD.info["gauge"][3][0][tostring(outlierFlagDC)]		   
		   end
		   
		   gaugeMessage = gaugeMessage.."     "..zo_iconTextFormatNoSpace(texture3,iconsize,iconsize,"")

       -- 05/07/2026 performance improvement:
       -- This branch used to call GetKeepResourceType(keep.keepID) -- another
       -- engine API round-trip -- every time SetFlagGauges runs, which is once
       -- per second for every displayed keep that has active flag data. But
       -- Battle.new() already determined whether this keep is a resource and
       -- cached it on the instance as `isResourceKeep` (see the getKeepName()
       -- performance note above), so we can reuse that cached flag instead of
       -- re-querying the engine for the same answer every update.
       elseif keep.isResourceKeep or keep.keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT then	 -- resources  
		   for flag, alliance in pairs(CyrHUD.flags[keep.keepID]) do -- AD1 EP2 DC3
			 local ad = alliance[1] or 0 
			 local ep = alliance[2] or 0
			 local dc = alliance[3] or 0
			 local ne = alliance[0] or 0
		     local defender =  CyrHUD.flags[keep.keepID][flag].defender or 0
			 if defender == 0 then defender = keep.defender end
			 
			   local texture = CyrHUD.info["gauge"][0][0]["100"] 
			   local maxFlagValue = math.max(ad,ep,dc)
			   if ne == 100 then

		       elseif maxFlagValue == 0 then	
                       texture = CyrHUD.info["gauge"][defender][0]["100"]					 
			   elseif ad == maxFlagValue then	
					 texture = CyrHUD.info["gauge"][1][0][tostring(ad)]
			   elseif ep == maxFlagValue then
					 texture = CyrHUD.info["gauge"][2][0][tostring(ep)]
			   elseif dc == maxFlagValue then		   
					 texture = CyrHUD.info["gauge"][3][0][tostring(dc)]
			   end
			   gaugeMessage = zo_iconTextFormatNoSpace(texture,iconsize,iconsize,"")
		   end
	   end
    end
	
	if gaugeMessage ~= "" then
	   gaugeMessage = "     "..gaugeMessage
	end

	holder:SetText(gaugeMessage)
end

function CyrHUD.SetColouredName(label,keep) -- set flag percentage coloured name
	local name = label:getControl(L_NAME)


	-- 05/07/2026 performance improvement:
	-- NonContiguousCount() walks the (sparse) CyrHUD.flags[keep.keepID] table with
	-- pairs() to count its entries, and this function is called from updateLabel()
	-- for every visible keep row roughly once a second. The old code called it
	-- twice back-to-back on the exact same table (once in the if-condition, once
	-- to populate numFlags), doubling that traversal cost for no reason. We now
	-- compute it once and reuse the cached result -- including in the `for
	-- flag,alliance in pairs(...)` loop below, which used to re-index
	-- CyrHUD.flags[keep.keepID] yet again instead of reusing keepFlags.
	local keepFlags = CyrHUD.flags and CyrHUD.flags[keep.keepID]
	local numFlags = keepFlags and NonContiguousCount(keepFlags) or 0

	if keepFlags and numFlags > 0 then 
	   
	   local ADpercent = 0
	   local DCpercent = 0
	   local EPpercent = 0
	   local NEpercent = 0
	   
	   
	   for flag,alliance in pairs(keepFlags) do -- AD1 EP2 DC3
            local ad = alliance[1] or 0
			local ep = alliance[2] or 0
			local dc = alliance[3] or 0
			local ne = alliance[0] or 0
			ADpercent = ADpercent + ad
			DCpercent = DCpercent + dc
			EPpercent = EPpercent + ep
			NEpercent = NEpercent + ne
       end
	   
	 
	   if (keep.keepType == KEEPTYPE_KEEP or keep.keepType == KEEPTYPE_OUTPOST) and numFlags ~= 2 then 
	          if keep.defender == 1  then 
			     ADpercent = ADpercent + 100
              elseif keep.defender == 2  then
	             EPpercent = EPpercent + 100
			  elseif keep.defender == 3  then
			     DCpercent = DCpercent + 100
              end
              ADpercent = ADpercent/2
			  EPpercent = EPpercent/2
			  DCpercent = DCpercent/2
			  NEpercent = NEpercent/2
			  
			  
	   elseif keep.keepType == KEEPTYPE_TOWN then 	  
		      if numFlags == 1 then
				  if keep.defender == 1  then 
					 ADpercent = ADpercent + 200
				  elseif keep.defender == 2  then
					 EPpercent = EPpercent + 200
				  elseif keep.defender == 3  then
					 DCpercent = DCpercent + 200
				  end
			  
              elseif numFlags == 2 then	
				  if keep.defender == 1  then 
					 ADpercent = ADpercent + 100
				  elseif keep.defender == 2  then
					 EPpercent = EPpercent + 100
				  elseif keep.defender == 3  then
					 DCpercent = DCpercent + 100
				  end
			  end
	              ADpercent = ADpercent/3
				  EPpercent = EPpercent/3
				  DCpercent = DCpercent/3
				  NEpercent = NEpercent/3
	   end
	   
	   -- Who's attacking?
	   if keep.prevADpercent and ADpercent > keep.prevADpercent then
	       keep.attacker = 1
		   -- animate arrow
		   CyrHUD.Battle:animateArrow(label, keep, nil, nil, label.entryName)
	   elseif keep.prevDCpercent and DCpercent > keep.prevDCpercent then
	       keep.attacker = 3
		   -- animate arrow
		   CyrHUD.Battle:animateArrow(label, keep, nil, nil, label.entryName)
	   elseif keep.prevEPpercent and EPpercent > keep.prevEPpercent then
	       keep.attacker = 2
		   -- animate arrow
		   CyrHUD.Battle:animateArrow(label, keep, nil, nil, label.entryName)
	   elseif keep.prevNEpercent and NEpercent > keep.prevNEpercent then
	       keep.attacker = 0
		   -- animate arrow
		   CyrHUD.Battle:animateArrow(label, keep, nil, nil, label.entryName) 
	   elseif (keep.prevADpercent and ADpercent < keep.prevADpercent ) or (keep.prevDCpercent and DCpercent < keep.prevDCpercent) or (keep.prevEPpercent and EPpercent < keep.prevEPpercent) then
	       keep.attacker = 0
		   -- animate arrow
		   CyrHUD.Battle:animateArrow(label, keep, nil, nil, label.entryName) 
	   end

	   
	   -- populate previous stats
	   keep.prevNEpercent = NEpercent
	   keep.prevADpercent = ADpercent
	   keep.prevDCpercent = DCpercent
	   keep.prevEPpercent = EPpercent
	   
	   

	   if NEpercent == 100 or ADpercent == 100 or DCpercent == 100 or EPpercent == 100 then -- no need to calculate here
	      name:SetText(keep:getKeepName())
		  if NEpercent == 100 then
		      name:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
		  elseif ADpercent == 100 then
              name:SetColor(CyrHUD.info[1].color:UnpackRGBA())
		  elseif EPpercent == 100 then
              name:SetColor(CyrHUD.info[2].color:UnpackRGBA()) 
		  elseif DCpercent == 100 then
              name:SetColor(CyrHUD.info[3].color:UnpackRGBA())
		  end
	   elseif NEpercent == 0 and ADpercent == 0 and DCpercent == 0 and EPpercent == 0 then
	        name:SetColor(CyrHUD.info[keep.defender].color:UnpackRGBA())
	   else -- calculate keepname string colors
		   local keepNameArray = CyrHUD.UTF8ToCharArray(keep:getKeepName())
		   local rest = keepNameArray
		   
		   local colorLimitLetterAD = math.floor(ADpercent/100*#keepNameArray)
		   local ADstring = ""
		   if colorLimitLetterAD ~= 0 then
		       local allianceColor = GetAllianceColor(1)
               local ADcolor = "|c"..allianceColor:ToHex()
               local arrayTostring, newArray = CyrHUD.charArrayToString(keepNameArray,colorLimitLetterAD)			   
		       ADstring = ADcolor..arrayTostring.."|r"
			   rest = newArray
		   end
		   
		   local colorLimitLetterDC = math.floor(DCpercent/100*#keepNameArray)
		   local DCstring = ""
		   if colorLimitLetterDC ~= 0 then
		       local allianceColor = GetAllianceColor(3)
               local DCcolor = "|c"..allianceColor:ToHex()	
			   local arrayTostring, newArray = CyrHUD.charArrayToString(rest,colorLimitLetterDC)
		       DCstring = DCcolor..arrayTostring.."|r"
			   rest = newArray
		   end
	   
		   local colorLimitLetterEP = math.floor(EPpercent/100*#keepNameArray)
		   local EPstring = ""
		   if colorLimitLetterEP ~= 0 then
		       local allianceColor = GetAllianceColor(2)
               local EPcolor = "|c"..allianceColor:ToHex()
			   local arrayTostring, newArray = CyrHUD.charArrayToString(rest,colorLimitLetterEP)
		       EPstring = EPcolor..arrayTostring.."|r"
			   rest = newArray
		   end
		   
		   local restLength = math.floor(#rest)
		   if restLength ~= 0 then 
		        local neutralColor = CyrHUD.info[ALLIANCE_NONE].color
		        local restColor = "|c"..neutralColor:ToHex()
				local arrayTostring, newArray = CyrHUD.charArrayToString(rest,#rest)
		        rest = restColor..arrayTostring.."|r"
		   else
		       rest = ""
		   end
		   
		   -- colourise rest
		   local fullString = ADstring..DCstring..EPstring..rest
	       name:SetText(fullString)
	   end


	else -- no data or no data yet for flags
        name:SetText(keep:getKeepName())
        name:SetColor(CyrHUD.info[keep.defender].color:UnpackRGBA())
	end
       
end

function CyrHUD.Battle:updateLabel(label)

  label:getControl(L_ICON_DEATHS_AD):SetHidden(true)
	label:getControl(L_ICON_DEATHS_EP):SetHidden(true)
	label:getControl(L_ICON_DEATHS_DC):SetHidden(true)
  label:getControl(L_DEATHS_AD):SetHidden(true)
	label:getControl(L_DEATHS_EP):SetHidden(true)
	label:getControl(L_DEATHS_DC):SetHidden(true)
  label:getControl(L_KILLS_AD):SetHidden(true)
	label:getControl(L_KILLS_EP):SetHidden(true)
	label:getControl(L_KILLS_DC):SetHidden(true)
	label:getControl(LEGEND_KILLS):SetHidden(true)
	label:getControl(LEGEND_DEATHS):SetHidden(true)

	
	label:getControl(L_HOLDER):SetHidden(false)
	
	label:getControl(ICON_EMPEROR):SetHidden(true)
	label:getControl(TEXT_PLAYERNAME):SetHidden(true)
	label:getControl(TEXT_RIVALNAME):SetHidden(true)
	label:getControl(TEXT_PLAYERRANK):SetHidden(true)
	label:getControl(TEXT_RIVALRANK):SetHidden(true)
	label:getControl(TEXT_PLAYERSCORE):SetHidden(true)
	label:getControl(TEXT_RIVALSCORE):SetHidden(true)
	label:getControl(ICON_ASH):SetHidden(true)
	label:getControl(ICON_WELL):SetHidden(true)
	label:getControl(ICON_CHAL):SetHidden(true)
	label:getControl(ICON_BRK):SetHidden(true)
	label:getControl(ICON_SIA):SetHidden(true)
	label:getControl(ICON_ROE):SetHidden(true)
	
	label:getControl(L_NAME):SetHidden(false)
	label:getControl(L_ICON):SetHidden(false)
	label:getControl(L_TIME):SetHidden(false)

	-- 05/07/2026 performance improvement:
	-- updateLabel() runs once a second for every displayed keep row -- the
	-- single most numerous row type in the addon. L_CONNECTED was fetched via
	-- getControl() 7 times, L_NAME 5 times, L_TIME 4 times, L_ICON 3 times,
	-- CYROCHAT_ICON 3 times, and L_SCROLL up to 4 times across this function's
	-- various branches, each a method call plus a table index for the exact
	-- same control. We fetch each one once here and reuse the cached
	-- reference everywhere below. (Same fix already applied to the analogous
	-- pattern in ScoringBar.lua, RankingBar.lua, PatrollingHorrors.lua and
	-- MovingObjectives.lua.)
	local nameControl = label:getControl(L_NAME)
	local iconControl = label:getControl(L_ICON)
	local timeControl = label:getControl(L_TIME)
	local connectedControl = label:getControl(L_CONNECTED)
	local cyroChatControl = label:getControl(CYROCHAT_ICON)
	
	

  --Keep icon
  iconControl:SetTexture(self:getIcon())
  label:getControl(L_UA):SetHidden(not self.keepUA)

	-- CyroChat Battles
	cyroChatControl:SetTexture(self.cyroChatIcon)

	if self.cyroChatIcon ~= nil then
		cyroChatControl:SetHidden(false)
	else
		cyroChatControl:SetHidden(true)
	end

    --Keep name
	  CyrHUD.SetColouredName(label,self)
	  
    --flag gauges
      CyrHUD.SetFlagGauges(label,self)	
	
	--Keep resources around icon 
	-- 05/07/2026 performance improvement:
	-- Same redundant engine call as the one fixed above in Battle:update() --
	-- self.keepType is already cached from Battle.new() and never changes, so
	-- there's no need to call GetKeepType(self.keepID) again. This one is in
	-- updateLabel(), which runs every second for every displayed keep row, so
	-- reusing the cached field here saves an API round-trip every second per
	-- visible keep rather than just every 5 seconds.
	if self.keepType == KEEPTYPE_KEEP then -- check resources 
	  local lumbermillID = GetResourceKeepForKeep(self.keepID, RESOURCETYPE_WOOD)
		local mineID = GetResourceKeepForKeep(self.keepID, RESOURCETYPE_ORE)
		local farmID = GetResourceKeepForKeep(self.keepID, RESOURCETYPE_FOOD)
		
		if lumbermillID > 0 then
		   local lumbermill = label:getControl(L_LUMB)
		   local color = GetAllianceColor(GetKeepAlliance(lumbermillID, CyrHUD.battleContext))
		   lumbermill:SetTexture(CyrHUD.icons[10 + RESOURCETYPE_WOOD]) 
		   lumbermill:SetColor(color:UnpackRGBA())
		   lumbermill:SetHidden(false)
		else
		   label:getControl(L_LUMB):SetHidden(true)
		end 
		
		if mineID > 0 then
		   local mine = label:getControl(L_MINE)
		   local color = GetAllianceColor(GetKeepAlliance(mineID, CyrHUD.battleContext))
		   mine:SetTexture(CyrHUD.icons[10 + RESOURCETYPE_ORE])
		   mine:SetColor(color:UnpackRGBA())
		   mine:SetHidden(false)
		else
		   label:getControl(L_MINE):SetHidden(true)
		end
		
		if farmID > 0 then
		   local farm = label:getControl(L_FARM)
		   local color = GetAllianceColor(GetKeepAlliance(farmID, CyrHUD.battleContext))
		   farm:SetTexture(CyrHUD.icons[10 + RESOURCETYPE_FOOD])
		   farm:SetColor(color:UnpackRGBA())
		   farm:SetHidden(false)
		else
		   label:getControl(L_FARM):SetHidden(true)
		end
	else
	    label:getControl(L_FARM):SetHidden(true)
		  label:getControl(L_MINE):SetHidden(true)
		  label:getControl(L_LUMB):SetHidden(true)
    end
	

	if self.keepCut and not self.keepUA then -- keep has no resources
        connectedControl:SetHidden(false) 
        connectedControl:SetTexture(CyrHUD.icons["DisconnectedKeep"])
        connectedControl:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
	elseif GetKeepAccessible(self.keepID, CyrHUD.battleContext) and not self.keepUA then -- display if we can port to/from
		connectedControl:SetHidden(false)
    connectedControl:SetTexture(CyrHUD.icons["ConnectedKeep"])
    connectedControl:SetColor(CyrHUD.info.linkColor:UnpackRGBA())
  else
	    connectedControl:SetHidden(true)
	end

    -- 20/07/2026 performance improvement:
	-- This used to loop over GetNumObjectives() AvA objectives itself, every
	-- second, for every displayed keep row (see CyrHUD:updateElderScrollHolders()
	-- in CyrHUD.lua for the full writeup) -- including a nested pairs() scan
	-- over CyrHUD.scrolls to recompute AD/DC/EP totals on every match, for
	-- every row. That global scan/count is now done exactly once per second
	-- in CyrHUD:printAll(), so all this row needs is a single cheap lookup
	-- into the precomputed cache for whether *this* keep is currently
	-- holding a scroll.
	local scrollPinType = CyrHUD.scrollHolderByKeep and CyrHUD.scrollHolderByKeep[self.keepID]
	local scroll = label:getControl(L_SCROLL)
	if scrollPinType then
	    scroll:SetTexture(ZO_MapPin.PIN_DATA[scrollPinType].texture)
	    scroll:SetHidden(false)
	else
	    scroll:SetHidden(true)
	end
	
	-- elder scrolls on temples icons
	if self.keepType == KEEPTYPE_ARTIFACT_GATE then
	   if self.gateTempleHasScroll then
	        local scroll = label:getControl(L_SCROLL)
		    local scrollPintype,_,_,_ = GetObjectivePinInfo(self.keepID - 6, GetKeepArtifactObjectiveId(self.keepID - 6), CyrHUD.battleContext)
	        scroll:SetTexture(ZO_MapPin.PIN_DATA[scrollPintype].texture)
	        scroll:SetHidden(false)
			nameControl:SetText(shortenKeepName(GetKeepName(self.keepID - 6)))
       else
	       	local scroll = label:getControl(L_SCROLL)
			scroll:SetHidden(true)
       end	   
	end

    --Time
    timeControl:SetText(self:getDuration())
	if self.endBattle then 
        timeControl:SetColor(CyrHUD.info[self.defender].color:UnpackRGBA())
		nameControl:SetText(self:getKeepName())
        nameControl:SetColor(CyrHUD.info[self.defender].color:UnpackRGBA())
	else
        timeControl:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())	
	end   
	
    --Defensive siege
    local ds, dc = self:getDefSiege()
    local defSiege = label:getControl(L_DEF_SIEGE)
    defSiege:SetText(ds)
    defSiege:SetColor(dc:UnpackRGBA())
    iconControl:SetColor(dc:UnpackRGBA())
	if ds ~= "" then
	   label:getControl(L_DEF_SIEGE_ICON):SetHidden(false)
	   if ds == "?" or ds < 10 then
		   label:positionControl(L_DEF_SIEGE, 30, 30, 224, 5) 
	   else
		   label:positionControl(L_DEF_SIEGE, 30, 30, 220, 5) 
	   end	
	else
	   label:getControl(L_DEF_SIEGE_ICON):SetHidden(true)
    end 


    --Attacking siege
    local as, ac = self:getAttSiege()
    local attSiege = label:getControl(L_ATT_SIEGE)
    attSiege:SetText(as)
    attSiege:SetColor(ac:UnpackRGBA())
	if as ~= "" then
	   label:getControl(L_ATT_SIEGE_ICON):SetHidden(false)
	   if as == "?" or as < 10 then
	       label:positionControl(L_ATT_SIEGE, 30, 30, 190, 5)
	   else
	       label:positionControl(L_ATT_SIEGE, 30, 30, 186, 5)
	   end
	else
	   label:getControl(L_ATT_SIEGE_ICON):SetHidden(true)
    end 
	
	-- animated arrows check
	if CyrHUD.animatedArrows and CyrHUD.animatedArrows[self.keepID]	and CyrHUD.animatedArrows[self.keepID].entryName and CyrHUD.animatedArrows[self.keepID].entryName == label.entryName then
	     -- do nothing
    else
	     -- removes arrow
		 local arrow = label:getControl(L_ARROW)
		 arrow:SetAlpha(0)
		 if CyrHUD.animatedArrows and CyrHUD.animatedArrows[self.keepID] and CyrHUD.animatedArrows[self.keepID].entryName then
		    CyrHUD.animatedArrows[self.keepID].label = label
		    CyrHUD.animatedArrows[self.keepID].entryName = label.entryName
		 end
		 
	end
	
	

    --Background color
    label.main:SetCenterColor(self:getBGColor():UnpackRGBA())
	
	-- set waypoint or rallypoint on click
	nameControl:SetMouseEnabled(true)
    nameControl:SetHandler("OnMouseUp", function(_, button, upInside, ctrl, alt, shift, command)
        if upInside then
		     if self.nX ~= nil and self.nY ~= nil  then
			    CyrHUD:setWaypoint(self.nX, self.nY)
			 end
        end
    end)

end

function CyrHUD.Battle:animateArrow(label, keep, x, alpha, entryName, timeStamp)
	
	CyrHUD.animatedArrows = CyrHUD.animatedArrows or {}

	-- 05/07/2026 performance improvement:
	-- animateArrow() re-invokes itself via zo_callLater every 20ms for as long
	-- as an attack arrow is animating -- making it by far the highest-frequency
	-- function call in the addon (50 times/sec per animating keep, vs. once a
	-- second or once every 5 seconds for everything else we've optimized so
	-- far). The old code re-indexed the global table chain
	-- `CyrHUD.animatedArrows[keep.keepID]` up to 8 times per invocation, each
	-- one a global lookup plus a table index. We now resolve it once into a
	-- local and reuse that local everywhere. (Every real call site passes
	-- x=nil, alpha=nil on the very first invocation for a keep -- see the
	-- callers in checkAdd/add above -- so the entry is always already
	-- initialized by the time a recursive self-call supplies x/alpha, meaning
	-- it's safe to ensure the sub-table exists unconditionally up front rather
	-- than only inside the `not x and not alpha` branch.)
	CyrHUD.animatedArrows[keep.keepID] = CyrHUD.animatedArrows[keep.keepID] or {}
	local arrowState = CyrHUD.animatedArrows[keep.keepID]

	if not x and not alpha then -- new info about the this keep so we update the label in database, 
		arrowState.label = label
		arrowState.entryName = entryName
		timeStamp = GetTimeStamp()
		arrowState.timeStamp = timeStamp
	end

	
	if arrowState.entryName ~= entryName then -- this avoids arrows animations displayed on the wrong keep when list changes 
       label = arrowState.label
       entryName = arrowState.entryName
	end
	
	if arrowState.timeStamp ~= timeStamp then -- allow only one animated arrow at a time (fixes weird display and loop causing lag)
	   return
	end
	
	local arrow = label:getControl(L_ARROW)
	
    local minX = 35	
	local maxX = 165
    alpha = alpha or 0.1
	
	local r, g, b = GetAllianceColor(keep.attacker):UnpackRGB()

    if keep.attacker == 0 then

	    arrow:SetTransformRotationZ(math.rad(0))
		
		x = x or maxX
		if x < minX then
		   x = maxX
		   alpha = 0
		else
		    
		    x = x - 1
			
			if x > 100 then 
			   alpha = alpha + 0.0166
			else
			    alpha = alpha - 0.0166
            end
		end

         label:positionControl(L_ARROW, 20, 20, x, 7)
		 arrow:SetTexture(CyrHUD.icons["arrow"])
		 arrow:SetColor(r, g, b, alpha)

	else 

	    arrow:SetTransformRotationZ(math.rad(0))
		
		x = x or minX
		if x > maxX then
		   x = minX
		   alpha = 0
		else
		    x = x + 1
			if x < 100 then 
			   alpha = alpha + 0.0166
			else
			    alpha = alpha - 0.0166
            end			
		end

		label:positionControl(L_ARROW, 80, 80, x, -23)
		arrow:SetTexture(CyrHUD.icons[keep.attacker])
		arrow:SetColor(r, g, b, alpha)
    end

	 if keep.endBattle then 
	    arrow:SetAlpha(0)
		return
	 end
	 
     if arrow:GetAlpha() ~= 0 then
	    zo_callLater(function() CyrHUD.Battle:animateArrow(label, keep, x, alpha, entryName, timeStamp) end, 20)
	 end 
end
 
----------------------------------------------
-- Model update
----------------------------------------------

function CyrHUD.Battle:update()
    self.defender = GetKeepAlliance(self.keepID, CyrHUD.battleContext)
    self.keepUA = GetKeepUnderAttack(self.keepID, CyrHUD.battleContext)
    
    -- 05/07/2026 performance improvement:
    -- self.keepType is already cached on this instance from Battle.new() (and
    -- a keep's fundamental type never changes over its lifetime), so calling
    -- GetKeepType(self.keepID) again here every time update() runs is another
    -- avoidable engine API round-trip for information we already have.
	  if self.keepType == KEEPTYPE_KEEP then -- check if keep is cut 
        self.keepCut = (self.defender == GetUnitAlliance("player")) and not GetKeepHasResourcesForTravel(self.keepID, CyrHUD.battleContext)
    end
    self.siege[ALLIANCE_ALDMERI_DOMINION] = GetNumSieges(self.keepID, CyrHUD.battleContext, ALLIANCE_ALDMERI_DOMINION)
    self.siege[ALLIANCE_DAGGERFALL_COVENANT] = GetNumSieges(self.keepID, CyrHUD.battleContext, ALLIANCE_DAGGERFALL_COVENANT)
    self.siege[ALLIANCE_EBONHEART_PACT] = GetNumSieges(self.keepID, CyrHUD.battleContext, ALLIANCE_EBONHEART_PACT)
	local pinType, nX, nY = GetKeepPinInfo(self.keepID, CyrHUD.battleContext)
	self.nX = nX
	self.nY = nY
	
	
	if self.keepType == KEEPTYPE_ARTIFACT_GATE or self.keepType == KEEPTYPE_BRIDGE or self.keepType == KEEPTYPE_MILEGATE then

		local gateOpen = false
		if pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_ALDMERI_DOMINION or pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_DAGGERFALL_COVENANT or pinType == MAP_PIN_TYPE_ARTIFACT_GATE_OPEN_EBONHEART_PACT then
			gateOpen = true
		elseif pinType == MAP_PIN_TYPE_KEEP_BRIDGE_IMPASSABLE or pinType == MAP_PIN_TYPE_KEEP_MILEGATE_IMPASSABLE or pinType == MAP_PIN_TYPE_KEEP_MILEGATE_CENTER_DESTROYED then 
		    gateOpen = true -- yep, it should be keepImpassable = true but the code is cleaner/has less lines like that   
		end
		self.gateOpen = gateOpen
		
		if self.keepType == KEEPTYPE_ARTIFACT_GATE then -- only display scroll gates if there is a scroll in the temple
			local gateTemple = self.keepID - 6
		    local scrollObjectiveId = GetKeepArtifactObjectiveId(gateTemple)
			local scrolIsAtBase = GetObjectiveControlState(gateTemple, scrollObjectiveId, CyrHUD.battleContext) == OBJECTIVE_CONTROL_STATE_FLAG_AT_BASE
			if scrolIsAtBase then
			     self.gateTempleHasScroll = true
			else
			     self.gateTempleHasScroll = false
			end
		end
	end
	
    if not self:isBattle() then
        if self.endBattle then
            --Remove after time
            if GetDiffBetweenTimeStamps(GetTimeStamp(), self.endBattle) > 15 then
				CyrHUD.battles[self.keepID] = nil
				self.flagUAsince = nil
            end
        elseif (self.flagUAsince and GetDiffBetweenTimeStamps(GetTimeStamp(), self.flagUAsince) > 25) or not self.flagUAsince then
            self.endBattle = GetTimeStamp()
        end

    end
	
	-- update imperial keeps ownership when in Cyrodiil / imperial district ownership list when in Imperial City, JerallPass
    if self.keepID == 6 or self.keepID == 7 or self.keepID == 9 or self.keepID == 13 or self.keepID == 15 or self.keepID == 17 or self.keepType == KEEPTYPE_IMPERIAL_CITY_DISTRICT or self.keepID == 1 or self.keepID == 25 or self.keepID == 26 or self.keepID == 27 then
	    CyrHUD.imperialKeeps = CyrHUD.imperialKeeps or {}
		  CyrHUD.imperialKeeps[self.keepID] = self.defender
	end
	
end

function CyrHUD.Battle:restart()
    self.endBattle = nil
end

function CyrHUD.Battle:addIcon(icon)
	self.cyroChatIcon = icon
end

----------------------------------------------
-- Getters
----------------------------------------------

--[[
    @return red, green, blue, alpha for background color
        all in range [0,1]
--]]
function CyrHUD.Battle:getBGColor()
    if self.endBattle then
        if self.defender == GetUnitAlliance("player") then
            return CyrHUD.info.defendedColor
        end

        return CyrHUD.info.endAttackColor
    end

    -- 05/07/2026 performance improvement:
    -- getBGColor() runs every second for every displayed battle row (via
    -- updateLabel -> label.main:SetCenterColor(self:getBGColor():UnpackRGBA())).
    -- A "flash red then fade" effect for newly-started attacks was restored
    -- here briefly, but for battles specifically that color is already used
    -- to communicate the OUTCOME of a battle (endAttackColor = lost to
    -- another alliance, defendedColor = held/won) in the self.endBattle
    -- branch above -- so flashing the same red on every new attack as well
    -- would be visually confusing/redundant with that existing signal. We
    -- keep the flash-fade effect for PatrollingHorrors.lua and
    -- MovingObjectives.lua (which have no equivalent outcome-color use), but
    -- intentionally skip it here and just return defaultBGColor.

    return CyrHUD.info.defaultBGColor
end

--[[
    @return elapsed time of battle event
        if an end is specified, will show total lenth
        otherwise will show current length
--]]
function CyrHUD.Battle:getDuration()
    return CyrHUD.formatTime(GetDiffBetweenTimeStamps(self.endBattle or GetTimeStamp(), self.startBattle), false, true)
end

--[[
    @return numSiege, color
        numSiege - number of defending siege equipment
        color - color for the defending faction
]]
function CyrHUD.Battle:getDefSiege()
    local siege = self.siege[self.defender]

    if not siege or siege == 0 then
		siege = ""
	end

    return siege, CyrHUD.info[self.defender].color
end

--[[
    @return numSiege, color
        numSiege - number of defending siege equipment
        color - color for the defending faction
    @note If two attacking factions, will sum the siege and show white for color
]]
function CyrHUD.Battle:getAttSiege()
    local count, faction = 0, nil

    for f,c in pairs(self.siege) do
        if f ~= self.defender and c > 0 then
            count = count + c

            if faction == nil then
                faction = f
            else
                faction = 0
            end
        end
    end

    local color = CyrHUD.info[ALLIANCE_NONE].color

    if faction and faction ~= 0 then
        color = CyrHUD.info[faction].color
    end
    

    if count == 0 then
        if not self.keepUA and n0(self.siege[self.defender]) > 0 then
            count = "?"
        else
            count = ""
        end
    end

    return count, color
end

--[[
    @return true iff battle is active
        a) keep is under attack status
        b) there is siege setup at keep
--]]
function CyrHUD.Battle:isBattle()

	if (self.keepType == KEEPTYPE_BRIDGE or self.keepType == KEEPTYPE_MILEGATE) and CyrHUD.cfg.hideBridgesAndMilegates then
	   return false
	end

    if self.keepType == KEEPTYPE_ARTIFACT_GATE then
	   return self.gateOpen and self.gateTempleHasScroll
	end

    if self.keepUA or self.gateOpen or self.keepCut then
		return true
	end

    return (self.siege[ALLIANCE_ALDMERI_DOMINION] + self.siege[ALLIANCE_DAGGERFALL_COVENANT] + self.siege[ALLIANCE_EBONHEART_PACT]) > 0
end


--[[
    @return icon for battle
        icon is based on resource type, faction, and whether it is under attack
    @see CyrHUD.info
]]
function CyrHUD.Battle:getIcon()
    -- 20/07/2026 bug fix:
    -- This "if CyrHUD.icons[self.keepType] == nil" check can never be true:
    -- CyrHUD.icons has a fallback __index metatable set up in Info.lua that
    -- returns a default texture (and logs a one-time error) for *any* missing
    -- key, so a direct index into it never actually returns nil. That makes
    -- this branch unreachable dead code, and the CyrHUD.info.noIcon it would
    -- have returned isn't defined anywhere in the addon (Info.lua sets up
    -- CyrHUD.info.underAttack/defendedColor/etc. but never .noIcon), so if
    -- this branch ever *did* somehow fire, it would hand back nil to
    -- iconControl:SetTexture(nil) instead of a usable fallback texture.
    -- Removed the dead check; unknown keep types are already handled
    -- correctly (and more robustly) by CyrHUD.icons' own fallback below.
	if self.keepType == KEEPTYPE_ARTIFACT_GATE then
	    if self.gateOpen then
		   if self.gateTempleHasScroll then
		       local pinType,_,_ = GetKeepPinInfo(self.keepID - 6, CyrHUD.battleContext)
		       return CyrHUD.icons[KEEPTYPE_ARTIFACT_KEEP*pinType]
		   else
		       return CyrHUD.icons[KEEPTYPE_ARTIFACT_GATE]
		   end
		    
	        
		else
		    return CyrHUD.icons[KEEPTYPE_ARTIFACT_GATE+999]
        end		
	end
	
	-- 05/07/2026 performance improvement:
	-- getIcon() runs every second for every displayed keep row. The old code
	-- unconditionally called IsKeepPassable(self.keepID, ...) here for every
	-- single keep, even though `passable` is only ever read inside the
	-- "keepType == MILEGATE or BRIDGE" branch below -- for the ~85 ordinary
	-- keeps that aren't milegates/bridges, that API call's result was always
	-- thrown away unused. We now only make that call for the keep types that
	-- actually need it.
	local pinType,_,_ = GetKeepPinInfo(self.keepID, CyrHUD.battleContext)
	if self.keepType == KEEPTYPE_MILEGATE or self.keepType == KEEPTYPE_BRIDGE then
	    local passable = IsKeepPassable(self.keepID, CyrHUD.battleContext)
		if not passable then
		    return CyrHUD.icons[self.keepType+999]
		end
	end
	if pinType == MAP_PIN_TYPE_KEEP_MILEGATE_CENTER_DESTROYED then	
	    return CyrHUD.icons[self.keepType+555] 
	else
		return CyrHUD.icons[self.keepType]
	end
    
end

-- in which Imperial City District is the battle
function CyrHUD.isInWhichDistrict(x,y)
   if not IsInImperialCity() then return "" end
   
    local Districts = {141,142,143,146,147,148}
	
	local keepName = ""
	local minDistance = 10000
	
	for i, keepId in ipairs(Districts) do
	   local pt, Kx, Ky = GetKeepPinInfo(keepId, BGQUERY_ASSIGNED_AND_LOCAL) 
	   local distance = math.sqrt( (Kx-x)^2 + (Ky-y)^2 )
	   if distance < minDistance then
          keepName = GetKeepName(keepId)
		      minDistance = distance
       end		  
	end
	
	return keepName
end
