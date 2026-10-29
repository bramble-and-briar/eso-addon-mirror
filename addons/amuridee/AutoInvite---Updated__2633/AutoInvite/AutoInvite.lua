-- This file is part of AutoInvite
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

AutoInvite = AutoInvite or {}
AutoInvite.AddonId = "AutoInvite"
AutoInvite.Version = "2026.10.29"

------------------------------------------------
--- Utility functions
------------------------------------------------
local function b(v) if v then return "T" else return "F" end end
local function nn(val) if val == nil then return "NIL" else return val end end
local function dbg(msg) if AutoInvite.debug then d("|c999999" .. msg) end end
local function echo(msg) CHAT_ROUTER:AddSystemMessage("|CFFFFFF[AutoInvite] |r|CFFFF00" .. msg) end

AutoInvite.isCyrodiil = function(unit)
    if unit == nil then unit = "player" end
    -- GetUnitZone(unit) was previously called twice per invocation (once to build
    -- the debug message, unconditionally, and once for the actual check). Cache it
    -- once and only build the debug string when debug output is actually enabled.
    local zone = GetUnitZone(unit)
    if AutoInvite.debug then dbg("Current zone: '" .. zone .. "'") end
    return zone == "Cyrodiil"
end


------------------------------------------------
--- Regular functions
------------------------------------------------

AutoInvite.postEnrolment = function()
    
    if not AutoInvite.enabled or not AutoInvite.listening then
        AutoInvite.startListening()
		return
    end
	
	local enrolment = AutoInvite.cfg.enrollStr
	local campaignName = GetCampaignName(GetCurrentCampaignId()) or ""
	local groupSize = GetGroupSize() or 1 
	
	if groupSize == 0 then groupSize = 1 end 
	local remainingSpots = AutoInvite.cfg.maxSize - groupSize
	
	local numTanks = 0
	local numHealers = 0
	local numDDs = 0
	
	if groupSize > 1 then
		for index = 1, groupSize do
				 local unitTag = GetGroupUnitTagByIndex(index)
				 local role = GetGroupMemberSelectedRole(unitTag)
				 if role == LFG_ROLE_TANK then
						numTanks = numTanks + 1
				 elseif role == LFG_ROLE_HEAL then
						numHealers = numHealers + 1  
				 elseif role == LFG_ROLE_DPS then
						numDDs = numDDs + 1
				 end
		end
	else
	             local role = GetSelectedLFGRole()
				 if role == LFG_ROLE_TANK then
						numTanks = numTanks + 1
				 elseif role == LFG_ROLE_HEAL then
						numHealers = numHealers + 1  
				 elseif role == LFG_ROLE_DPS then
						numDDs = numDDs + 1
				 end
	end
	

	
	local tanksNeeded = AutoInvite.cfg.tanksNeeded - numTanks 
    local healersNeeded = AutoInvite.cfg.healersNeeded - numHealers 
	local ddsNeeded = AutoInvite.cfg.ddsNeeded - numDDs 
	
	local roleMessage = ""
	
	if tanksNeeded > 0 then
	    roleMessage = roleMessage..tanksNeeded.."T"
	end

	if healersNeeded > 0 then
	    if roleMessage ~= "" then
		   roleMessage = roleMessage..", "
		end
	    roleMessage = roleMessage..healersNeeded.."H"
	end
	
	if ddsNeeded > 0 then
	    if roleMessage ~= "" then
		   roleMessage = roleMessage..", "
		end
	    roleMessage = roleMessage..ddsNeeded.."DD"
	end
	
	-- replace the keywords by data
	enrolment = enrolment:gsub("++cn", campaignName)
	enrolment = enrolment:gsub("++gs", groupSize)
	enrolment = enrolment:gsub("++rs", remainingSpots)
	enrolment = enrolment:gsub("++ro", roleMessage) 
	
	
	CHAT_SYSTEM:StartTextEntry(enrolment)
end


AutoInvite.isGroupLeader = function()
    
   local isGroupLeader =  IsUnitGroupLeader("player")
   if not isGroupLeader then
      echo(GetString(SI_AUTO_INVITE_ERROR_NOT_GROUP_LEADER))
   end
   
   return isGroupLeader
end




------------------------------------------------
--- Event handlers
------------------------------------------------

--Main callback fired on chat message
AutoInvite.callback = function(_, messageType, from, message, isCustomerService, fromDisplayName)
    if not AutoInvite.enabled or not AutoInvite.listening then
        return
    end
	
	-- filter unused channel types ASAP
	if isCustomerService or messageType == CHAT_CHANNEL_MONSTER_EMOTE or messageType == CHAT_CHANNEL_MONSTER_SAY or messageType == CHAT_CHANNEL_MONSTER_WHISPER or messageType == CHAT_CHANNEL_PARTY or messageType == CHAT_CHANNEL_SYSTEM or messageType == CHAT_CHANNEL_MONSTER_YELL or messageType == CHAT_CHANNEL_WHISPER_SENT then
	   return 
	end
	
	-- Cheap length check before lower-casing the whole message body. string.lower()
	-- allocates and scans a full copy of "message" on every call, and this callback
	-- runs on every chat message across many channels while listening -- far more
	-- often than any of the once-a-second tick functions. Lower-casing never changes
	-- a string's length, so a message can only match watchStr if the lengths already
	-- match; this rejects the vast majority of traffic for the cost of a length check.
	if #message ~= #AutoInvite.cfg.watchStr then
	   return
	end
	
	-- exclude your own messages ASAP
	-- Display-name only: AutoInvite.player is now GetUnitDisplayName(), so comparing
	-- it against `name` (a raw character name) would never match. fromDisplayName is
	-- part of the EVENT_CHAT_MESSAGE_CHANNEL signature for every channel type, not
	-- just guild/whisper, so this single check covers all channels correctly.
	local name = from:gsub("%^.+", "")
    if fromDisplayName and fromDisplayName == AutoInvite.accountName then
	   return
	end
	

    --TODO: Move this to the actual invite send so not per-message
    if GetGroupSize() >= AutoInvite.cfg.maxSize then
        echo(GetString(SI_AUTO_INVITE_GROUP_FULL_STOP))
        AutoInvite.stopListening()
		return
    end

    if string.lower(message) == AutoInvite.cfg.watchStr and name ~= nil and name ~= "" then
        -- On guild/officer/whisper channels, accountNameLookup still runs its guild/friend
        -- roster search -- that's also where the Cyrodiil zone-gate check (cfg.cyrCheck)
        -- lives, so it stays as a pass/fail gate. Its return value is no longer used as
        -- the invite identity: display name only now, to match kickTable/queue/
        -- MINI_GROUP_LIST, which are all keyed by GetUnitDisplayName(tag) elsewhere.
        if (messageType >= CHAT_CHANNEL_GUILD_1 and messageType <= CHAT_CHANNEL_OFFICER_5) or messageType == CHAT_CHANNEL_WHISPER then
                local lookupResult = AutoInvite.accountNameLookup(messageType, name, fromDisplayName)
                if lookupResult == "" or lookupResult == nil then return end
        end

        if fromDisplayName == nil or fromDisplayName == "" then return end
        from = fromDisplayName

        -- channel filtering
        if AutoInvite.cfg.channelsToListenTo[messageType] then
               echo(zo_strformat(GetString(SI_AUTO_INVITE_SEND_TO_USER), from))
               AutoInvite:invitePlayer(from)
        end
    end
	
    --d("Checking message '" .. string.lower(message) .."' ?= '" .. AutoInvite.cfg.watchStr .."'")
end

--
AutoInvite.playerLeave = function(_, unitTag, connectStatus, isSelf)
    if AutoInvite.enabled and AutoInvite.cfg.restart and not AutoInvite.listening then
            echo(zo_strformat(GetString(SI_AUTO_INVITE_GROUP_OPEN_RESTART), AutoInvite.cfg.watchStr))
            AutoInvite.startListening(true)
    end

    if isSelf then
        AutoInvite.kickTable = {}
    elseif unitTag then
        local unitName = GetUnitDisplayName(unitTag)
        if unitName then
           unitName = unitName:gsub("%^.+", "")
           AutoInvite.kickTable[unitName] = nil
        end
    end
end

AutoInvite.offlineEvent = function(_, unitTag, connectStatus)
    if not IsUnitGroupLeader("player") then return end 
    local unitName = GetUnitDisplayName(unitTag):gsub("%^.+", "")
    if connectStatus then
        dbg(unitTag .. "/" .. unitName .. " has reconnected")
        AutoInvite.kickTable[unitName] = nil
    else
        dbg(unitTag .. "/" .. unitName .. " has disconnected")
        AutoInvite.kickTable[unitName] = GetTimeStamp()
    end
    MINI_GROUP_LIST:updateSingle(unitName)
end

--Auto-disable if the player stops being group leader while AutoInvite is running
--(leadership transferred away, promoted someone else, etc). GetGroupSize() guard
--avoids false positives, since IsUnitGroupLeader("player") is trivially true
--while solo/ungrouped.
AutoInvite.leaderUpdate = function(_, leaderTag)
    if AutoInvite.enabled and GetGroupSize() > 0 and not IsUnitGroupLeader("player") then
        echo(GetString(SI_AUTO_INVITE_ERROR_NOT_GROUP_LEADER))
        AutoInvite.disable()
    end
end


------------------------------------------------
--- Loops
------------------------------------------------


-- tick function: called every 1s
function AutoInvite.tick()
    local self = AutoInvite
    self.kickCheck()

    if self.listening then
        if GetGroupSize() >= self.cfg.maxSize then
            self.stopListening()
        else
            self:checkSentInvites()
            self:processQueue()
        end
    end
	
end

-- every 1s
function AutoInvite.groupDisplayTick()
	if AI_SMALL_GROUP_LIST_FRAGMENT:IsShowing() then
		AutoInviteUI.refresh()
	else
	    AutoInviteUI.textUpdated = false
	end
end

------------------------------------------------
--- Event control
------------------------------------------------
AutoInvite.disable = function()
    echo(GetString(SI_AUTO_INVITE_OFF))
    AutoInvite.enabled = false
    AutoInvite.stopListening()
    EVENT_MANAGER:UnregisterForUpdate(AutoInvite.AddonId.."Tick")
    EVENT_MANAGER:UnregisterForEvent(AutoInvite.AddonId, EVENT_GROUP_INVITE_RESPONSE)
end

AutoInvite.stopListening = function()
    EVENT_MANAGER:UnregisterForEvent(AutoInvite.AddonId, EVENT_CHAT_MESSAGE_CHANNEL)
    AutoInvite.listening = false
end

--@param restart: (boolean) - true if restarted listening due to space open up
--currently only used for different print strings
AutoInvite.startListening = function(restart)
    if GetGroupSize() > 0 and not AutoInvite.isGroupLeader() then
	    return
	end

    if not AutoInvite.enabled then
        AutoInvite.enabled = true
        AutoInvite.checkOffline()
        EVENT_MANAGER:RegisterForUpdate(AutoInvite.AddonId.."Tick", 1000, AutoInvite.tick)
        EVENT_MANAGER:RegisterForEvent(AutoInvite.AddonId, EVENT_GROUP_INVITE_RESPONSE, AutoInvite.inviteResponse)
    end

    if not AutoInvite.listening and GetGroupSize() < AutoInvite.cfg.maxSize then
        --Add handler
        EVENT_MANAGER:RegisterForEvent(AutoInvite.AddonId, EVENT_CHAT_MESSAGE_CHANNEL, AutoInvite.callback)
        AutoInvite.listening = true
        if restart ~= nil then
            echo(zo_strformat(GetString(SI_AUTO_INVITE_GROUP_OPEN_RESTART), AutoInvite.cfg.watchStr))
        else
            echo(zo_strformat(GetString(SI_AUTO_INVITE_START_ON), AutoInvite.cfg.watchStr))
        end
    end
end

------------------------------------------------
--- Initialization
------------------------------------------------
AutoInvite.init = function()
    EVENT_MANAGER:UnregisterForEvent("AutoInviteInit", EVENT_PLAYER_ACTIVATED)
    if AutoInvite.initDone then return end
    AutoInvite.initDone = true

    local def = {
        maxSize = 12,
        restart = false,
        cyrCheck = false,
        autoKick = false,
        kickDelay = 300,
        watchStr = "",
		enrollStr = "",
        showPanel = true,
		channelsToListenTo = {
		[CHAT_CHANNEL_GUILD_1] = true,
		[CHAT_CHANNEL_GUILD_2] = true,
		[CHAT_CHANNEL_GUILD_3] = true,
		[CHAT_CHANNEL_GUILD_4] = true,
		[CHAT_CHANNEL_GUILD_5] = true,
		[CHAT_CHANNEL_OFFICER_1] = true,
		[CHAT_CHANNEL_OFFICER_2] = true,
		[CHAT_CHANNEL_OFFICER_3] = true,
		[CHAT_CHANNEL_OFFICER_4] = true,
		[CHAT_CHANNEL_OFFICER_5] = true,
		[CHAT_CHANNEL_SAY] = true,
		[CHAT_CHANNEL_WHISPER] = true,
		[CHAT_CHANNEL_YELL] = true,
		[CHAT_CHANNEL_ZONE] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_1] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_2] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_3] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_4] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_5] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_6] = true,
		[CHAT_CHANNEL_ZONE_LANGUAGE_7] = true,
		},
		tanksNeeded = 0,
		healersNeeded = 0,
		ddsNeeded = 0
    }
    AutoInvite.cfg = ZO_SavedVars:NewAccountWide("AutoInviteSettings", 1.0, "config", def)
    EVENT_MANAGER:RegisterForEvent(AutoInvite.AddonId, EVENT_GROUP_MEMBER_LEFT, AutoInvite.playerLeave)
    EVENT_MANAGER:RegisterForEvent(AutoInvite.AddonId, EVENT_GROUP_MEMBER_CONNECTED_STATUS, AutoInvite.offlineEvent)
    EVENT_MANAGER:RegisterForEvent(AutoInvite.AddonId, EVENT_LEADER_UPDATE, AutoInvite.leaderUpdate)
	EVENT_MANAGER:RegisterForUpdate(AutoInvite.AddonId.."groupDisplayTick", 1000, AutoInvite.groupDisplayTick)

    --Make sure Offline is updated after player zones (is offline for a bit
    EVENT_MANAGER:RegisterForEvent("AutoInviteInit", EVENT_PLAYER_ACTIVATED, AutoInvite.checkOffline)

    AutoInvite.listening = false
    AutoInvite.enabled = false
    -- Display-name based, to match kickTable/queue/MINI_GROUP_LIST, which are all
    -- keyed by GetUnitDisplayName(tag) elsewhere in the addon. AutoInvite.player and
    -- AutoInvite.accountName are now the same value; kept as two names since they're
    -- used in different call sites below.
    AutoInvite.player = GetUnitDisplayName("player")
	  AutoInvite.accountName = GetUnitDisplayName("player")
	
	AutoInvite_Enrol_Button = LibChatMenuButton.addChatButton("AutoInvite_Enrol_Button", {"EsoUI/Art/Campaign/campaign_tabIcon_summary_up.dds", "EsoUI/Art/Campaign/campaign_tabIcon_summary_over.dds", "EsoUI/Art/Campaign/campaign_tabIcon_summary_up.dds"}, "Press once to start listening for your keyword if not then press again to paste your AutoInvite enrolment message in chat", function() AutoInvite.postEnrolment() end)
	AutoInvite_Enrol_Button:show()	
	
    AutoInviteUI.init()
end

EVENT_MANAGER:RegisterForEvent("AutoInviteInit", EVENT_PLAYER_ACTIVATED, AutoInvite.init)

