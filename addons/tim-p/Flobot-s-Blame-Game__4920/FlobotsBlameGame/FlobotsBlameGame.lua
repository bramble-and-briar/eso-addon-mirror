FlobotsBlameGame = FlobotsBlameGame or {}
local this = FlobotsBlameGame
----------------------------------
--			Defaults			--
----------------------------------
this.defaultsAccount = {		
	debugEnabled = false, 
}

this.defaultsCharacter = {
	someProperty = true,
}

FlobotsBlameGame = FlobotsBlameGame or {}
local this = FlobotsBlameGame

----------------------------------
--       Blame Generation       --
----------------------------------

-- Core function to pick a blame target and reason
function this.GenerateBlame()
    local targetName = ""
    local reason = ""
    local groupSize = GetGroupSize()

    -- 70% chance to pick a group member if in a group
    if math.random() <= this.constants.PLAYER_BLAME_CHANCE then --and groupSize > 0 then
        local candidates = {			
		}
        for i = 1, groupSize do
            local unitTag = GetGroupUnitTagByIndex(i)
            if DoesUnitExist(unitTag) then
                local rawName = GetUnitName(unitTag)
                table.insert(candidates, zo_strformat(SI_UNIT_NAME, rawName))
            end
        end

		--testing - add a phantom player if there are none generated
		if #candidates == 0 then table.insert(candidates, zo_strformat(SI_UNIT_NAME, "a shadowy figure")) end
		
        if #candidates > 0 then
            targetName = candidates[math.random(#candidates)]
            reason = this.playerReasons[math.random(#this.playerReasons)]
        end
    end

    -- Fallback to external factor (30% roll or solo play)
    if targetName == "" then
        local factor = this.externalFactors[math.random(#this.externalFactors)]
        targetName = factor.name
        reason = factor.reasons[math.random(#factor.reasons)]
    end

    return targetName, reason
end

-- Formats and announces the blame string via Utils.UserError
function this.AnnounceBlame(eventText)
    -- Default event text if none is passed in
    if not eventText or eventText == "" then
        eventText = "That happened"
    end

    local target, reason = this.GenerateBlame()
    
    -- Format: "That happened because [Target] — [Reason]"
    local chatMsg = string.format("%s because of %s - %s.", eventText, target, reason)
    local alertMsg = string.format("%s because of %s - %s", eventText, target, reason)

    -- Outputs both to chat console and small center screen announcement
    this.Utils.UserError(chatMsg, alertMsg)
end

-- Death event callback
local function OnUnitDied(eventCode, unitTag, isDead)
    -- isDead is true on death, false on respawn/revive
    if not isDead then return end
	--d("OnUnitDied unitTag " .. unitTag)
    -- Get character name formatted without gender tags (^Mx)
    local rawName = GetUnitName(unitTag)
    --local victimName = --tostring(rawName) -- ZO_StrFormat(SI_UNIT_NAME, rawName)
	local victimName = zo_strformat(SI_UNIT_NAME, rawName)
    -- Trigger the blame announcement!
    this.AnnounceBlame(tostring(victimName) .. " died")
end

----------------------------------
--           Keybinds           --
----------------------------------

-- Called by keybinds, slash commands, or debugging
function this.TriggerBlameKey()
    this.AnnounceBlame("That happened")
end

local function Initialize()
	this.accountWide = ZO_SavedVars:NewAccountWide(this.SettingsName,this.SettingsVersion,"Account",this.defaultsAccount)
	this.character = ZO_SavedVars:NewCharacterNameSettings(this.SettingsName,this.SettingsVersion,"Character",this.defaultsCharacter)
	
	--CreateSettingsPanel()
    ZO_CreateStringId("SI_BINDING_NAME_FlobotsBlameGame_Debug_Key", "Debug Key")
	ZO_CreateStringId("SI_BINDING_NAME_FlobotsBlameGame_Blame_Key", "Blame")
	
	-- Set up initial state 
	--e.g. GetState()
	
	--any event registrations
	-- 1. Register the listener ONCE under the key "FlobotsBlameGameDeath"
	EVENT_MANAGER:RegisterForEvent(this.Name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDied)

	-- 2. Add Criteria A to "FlobotsBlameGameDeath" (matches tags starting with "group")
	EVENT_MANAGER:AddFilterForEvent(this.Name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")

	-- 3. Add Criteria B to "FlobotsBlameGameDeath" (matches tag exactly equal to "player")
	EVENT_MANAGER:AddFilterForEvent(this.Name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
end

local function OnAddOnLoaded(event, addonName)
    if addonName == this.Name then
        EVENT_MANAGER:UnregisterForEvent(this.Name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(this.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

--	Hotkeys
function this.BlameKey()
	this.AnnounceBlame("That happened")
end
----------------------------------
--	Debug
----------------------------------
local function listGroupMembers()
    this.Utils.UserMessage("Checking group members...", "Debug Active")

    local groupSize = GetGroupSize()
    local members = {}

    if groupSize > 0 then
        for i = 1, groupSize do
            local unitTag = GetGroupUnitTagByIndex(i)
            if DoesUnitExist(unitTag) then
                local rawName = GetUnitName(unitTag)
                local cleanName = zo_strformat(SI_UNIT_NAME, rawName)
                table.insert(members, cleanName)
            end
        end
    end

    if #members > 0 then
        local memberListStr = table.concat(members, ", ")
        this.Utils.UserMessage("Group Members: " .. memberListStr, "")
    else
        this.Utils.UserMessage("Group Members: None", "No members in group")
    end
end

local function listGroupMembers()
    this.Utils.UserMessage("Checking group members...", "Debug Active")

    local isGrouped = IsUnitGrouped("player")
    local groupSize = GetGroupSize()
    local members = {}

    -- Diagnostic output directly to chat
    d(string.format("[FB Debug] IsGrouped: %s | GroupSize: %d", tostring(isGrouped), groupSize))

    if groupSize > 0 then
        for i = 1, groupSize do
            local unitTag = GetGroupUnitTagByIndex(i)
            local exists = DoesUnitExist(unitTag)
            local rawName = GetUnitName(unitTag)
            
            d(string.format("[FB Debug] Index %d -> Tag: %s | Exists: %s | RawName: '%s'", 
                i, tostring(unitTag), tostring(exists), tostring(rawName)))

            -- Check if we have a valid character name (works even out of render range)
            if rawName and rawName ~= "" then
                local cleanName = zo_strformat(SI_UNIT_NAME, rawName)
                table.insert(members, cleanName)
            end
        end
    end

    if #members > 0 then
        local memberListStr = table.concat(members, ", ")
        this.Utils.UserMessage("Group Members: " .. memberListStr, "")
    else
        this.Utils.UserMessage("Group Members: None", "No members in group")
    end
end

function this.Debug()
	--this.AnnounceBlame("I died")
    --CHAT_SYSTEM:StartTextEntry("/s Testing group chat routing!")	
    -- Call the death callback directly, passing 'player' as the unitTag and true for isDead
    --OnUnitDied(EVENT_UNIT_DEATH_STATE_CHANGED, "player", true)
	listGroupMembers()
end
