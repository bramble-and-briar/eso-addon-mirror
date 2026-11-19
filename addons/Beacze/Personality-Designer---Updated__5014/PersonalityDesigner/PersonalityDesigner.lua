local PD = PersonalityDesigner
local LAM = LibAddonMenu2

local CR = CHAT_ROUTER
local chatLibPrefix = "<".. PD.name ..">"

-- data from ZOS
PD.categories = {}
PD.actions = {}
PD.mounts = {}

-- all of the created/saved personalities
PD.personalities = {}

-- various individual personalities
PD.defaultPersonality = {}
PD.personalityActive = {}
PD.personalityDesign = {}

-- various UI fields
PD.newPersonalityName = ""
PD.deletePersonalityName = ""
PD.searchTerm = ""
PD.frequencies = {GetString(P_DESIGNER_INFREQUENT), GetString(P_DESIGNER_DEFAULT), GetString(P_DESIGNER_FREQUENT)}

-- enable/disable checks
--PD.toggle = false
PD.enabled = true
PD.active = 1
PD.playlist = {}
PD.playingActions = false

function PD.TogglePD()
	PD.enabled = not PD.enabled
	PD:SaveData()

	local msgText
	if PD.enabled and table.getn(PD.playlist) > 0 then
		msgText = zo_strformat(" <<1>>", GetString(P_DESIGNER_ENABLED))

		EVENT_MANAGER:RegisterForUpdate(PD.name .. "IdleCheck", 1000, function() PD:IsPlayerIdle() end)
	elseif PD.enabled and (PD.playlist == nil or table.getn(PD.playlist) == 0) then
		msgText = zo_strformat(" <<1>>", GetString(P_DESIGNER_EMPTY))
		PD.enabled = false
	else
		msgText = zo_strformat(" <<1>>", GetString(P_DESIGNER_DISABLED))

		EVENT_MANAGER:RegisterForUpdate(PD.name .. "IdleCheck", 1000, function() PD:IsPlayerIdle() end)
		EVENT_MANAGER:UnregisterForUpdate(PD.name .. "PlayAfterIdleTime")
		EVENT_MANAGER:UnregisterForUpdate(PD.name .. "PlayAfterDelayTime")
	end

	
	CR:AddSystemMessage(chatLibPrefix .. msgText)
end

function PD.CyclePersonality()
	local numPersonalities = table.getn(PD.personalities)
	if numPersonalities == 0 then return end

	if PD.active + 1 <= numPersonalities then
		PD.active = PD.active + 1
	else PD.active = 1 end

	PD:SetActivePersonality()

	local msgText = zo_strformat(" <<1>>: <<2>>", GetString(P_DESIGNER_CYCLE_TO), PD.personalities[PD.active].name)

	if PD.enabled and (PD.playlist == nil or table.getn(PD.playlist) == 0) then
		PD.enabled = false
		msgText = msgText.. ": " ..zo_strformat(" <<1>>", GetString(P_DESIGNER_CYCLE_EMPTY))
	end
	
	CR:AddSystemMessage(chatLibPrefix .. msgText)
end

SLASH_COMMANDS["/pd-toggle"] = function() PD.TogglePD() end
SLASH_COMMANDS["/pd-cycle"] = function() PD.CyclePersonality() end

local CEREMONIAL = GetString(P_DESIGNER_CEREMONIAL)
local CHEERS_JEERS = GetString(P_DESIGNER_CHEERS_JEERS)
local EMOTION = GetString(P_DESIGNER_EMOTION)
local ENTERTAIN = GetString(P_DESIGNER_ENTERTAIN)
local FOOD_DRINK = GetString(P_DESIGNER_FOOD_DRINK)
local DIRECTIONS = GetString(P_DESIGNER_DIRECTIONS)
local PHYSICAL = GetString(P_DESIGNER_PHYSICAL)
local POSES = GetString(P_DESIGNER_POSES)
local PROP = GetString(P_DESIGNER_PROP)
local SOCIAL = GetString(P_DESIGNER_SOCIAL)

function PD:Initialize()

--[[ Emote categories
	These are the Emote categories per https://wiki.esoui.com/Constant_Values
	and their constant value
	
	TODO: Could probably pull these programatically
	
0	EMOTE_CATEGORY_INVALID
0	EMOTE_CATEGORY_ITERATION_BEGIN
0	EMOTE_CATEGORY_MIN_VALUE
1	EMOTE_CATEGORY_CEREMONIAL
2	EMOTE_CATEGORY_CHEERS_AND_JEERS
3	EMOTE_CATEGORY_DEPRECATED
4	EMOTE_CATEGORY_EMOTION
5	EMOTE_CATEGORY_ENTERTAINMENT
6	EMOTE_CATEGORY_FOOD_AND_DRINK
7	EMOTE_CATEGORY_GIVE_DIRECTIONS
8	EMOTE_CATEGORY_PERPETUAL
9	EMOTE_CATEGORY_PHYSICAL
10	EMOTE_CATEGORY_POSES_AND_FIDGETS
11	EMOTE_CATEGORY_PROP
12	EMOTE_CATEGORY_SOCIAL
13	EMOTE_CATEGORY_PERSONALITY_OVERRIDE
14	EMOTE_CATEGORY_ITERATION_END
14	EMOTE_CATEGORY_MAX_VALUE
14	EMOTE_CATEGORY_COLLECTED
]]--
	
	-- not all categories are used. Also, more readable category names
	local categories = {
		{constVal = 1,  category = CEREMONIAL},
		{constVal = 2,  category = CHEERS_JEERS},
		{constVal = 4,  category = EMOTION},
		{constVal = 5,  category = ENTERTAIN},
		{constVal = 6,  category = FOOD_DRINK},
		{constVal = 7,  category = DIRECTIONS},
		{constVal = 9,  category = PHYSICAL},
		{constVal = 10, category = POSES},
		{constVal = 11, category = PROP},
		{constVal = 12, category = SOCIAL},
	}
	local categoryNames = {}
	local function addCategory(categoryName)
		if not categoryNames[categoryName] then
			categoryNames[categoryName] = true
			table.insert(PD.categories, categoryName)
		end
	end
	PD.categories = {}
	
	-- Now to populate PD.action with emotes, which is pretty easy
	for i = 1, GetNumEmotes() do
		local slashName, catNum, emoteId, displayName = GetEmoteInfo(i)
		local collectibleId = GetEmoteCollectibleId(i)
		local unlocked = collectibleId == nil or IsCollectibleUnlocked(collectibleId)
		
		if unlocked then
			local categoryName = "Category " .. tostring(catNum or "Other")
			for k, v in pairs(categories) do
				if v.constVal == catNum then
					categoryName = v.category
				end
			end
			addCategory(categoryName)
			
			local emote = {}
			emote.kind = "emote"
			emote.id = emoteId or slashName
			emote.slashName = slashName
			emote.displayName = displayName
			emote.category = categoryName
			emote.action = displayName
			emote.command = i
			table.insert(PD.actions, emote)
		end
	end

	local emoteNameCounts = {}
	for k, emote in pairs(PD.actions) do
		if emote.kind == "emote" then
			emoteNameCounts[emote.category] = emoteNameCounts[emote.category] or {}
			local counts = emoteNameCounts[emote.category]
			counts[emote.displayName] = (counts[emote.displayName] or 0) + 1
		end
	end
	for k, emote in pairs(PD.actions) do
		if emote.kind == "emote" and emoteNameCounts[emote.category][emote.displayName] > 1 then
			emote.action = emote.action .. " (/" .. tostring(emote.slashName or emote.id) .. ")"
		end
	end
	
--[[COLLECTIBLE CATEGORY TYPES - my unofficial descriptions
	Mementos are collectibles, but just one type of many

	1	dungeons
	2 	mounts
	3 	pets
	4	clothing
	5	mementos
	6	outfit
	7	?
	8	assistants
	9	personalities
	10	store gear
	11	skins
	12	polymorphs
	13	hairstyle
	14	facial hair
	15	adornments
	16	minor adornments
	17	face markings
	18	body markings
	19	housing
	20	trophies/busts
	21	crown store emotes
	22	current expansion
	23	companion skin
	24	gear
	25	furniture
	26	event items
]]--

	-- Add unlocked mementos to the same action catalog.
	for i=1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO) do
		local collectibleId = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
		if collectibleId and GetCollectibleUnlockStateById(collectibleId) ~= COLLECTIBLE_UNLOCK_STATE_LOCKED then
			addCategory(GetString(P_DESIGNER_MEMENTO))
			local name = GetCollectibleName(collectibleId)

			local memento = {}
			memento.kind = "memento"
			memento.id = collectibleId
			memento.category = GetString(P_DESIGNER_MEMENTO)
			memento.action = name
			memento.command = collectibleId

			table.insert(PD.actions, memento)
		end
	end

	-- Here are some starter personalities
	PD.personalityDefault = {
		name = GetString(P_DESIGNER_DEFAULT_BLANK),
		idleTime = 1,
		delayTime = 1,
		action01 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action02 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action03 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action04 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action05 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action06 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action07 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action08 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action09 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action10 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
	}
	local default1 = {
		name = GetString(P_DESIGNER_DEFAULT_FIT),
		idleTime = 5,
		delayTime = 5,
		action01 = {enabled=true,category=POSES,action="Dust off",command=80,frequency=2,},
		action02 = {enabled=true,category=PHYSICAL,action="Jumping jacks",command=84,frequency=2,},
		action03 = {enabled=true,category=PHYSICAL,action="Push-ups strong",command=85,frequency=3,},
		action04 = {enabled=true,category=PHYSICAL,action="Push-ups weak",command=86,frequency=1,},
		action05 = {enabled=true,category=PHYSICAL,action="Situps",command=113,frequency=3,},
		action06 = {enabled=true,category=POSES,action="Breathless",command=114,frequency=1,},
		action07 = {enabled=true,category=POSES,action="Wipe brow",command=95,frequency=2,},
		action08 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action09 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action10 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
	}
	local default2 = {
		name = GetString(P_DESIGNER_DEFAULT_MAGIC),
		idleTime = 5,
		delayTime = 5,
		action01 = {enabled=true,category=ENTERTAIN,action="Juggle flame",command=194,frequency=2,},
		action02 = {enabled=true,category=PROP,action="Use wand once",command=163,frequency=2,},
		action03 = {enabled=true,category=POSES,action="Idle royalty",command=190,frequency=2,},
		action04 = {enabled=true,category=CEREMONIAL,action="Ritual",command=98,frequency=2,},
		action05 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action06 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action07 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action08 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action09 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action10 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
	}
	local default3 = {
		name = GetString(P_DESIGNER_DEFAULT_RUDE),
		idleTime = 5,
		delayTime = 5,
		action01 = {enabled=true,category=POSES,action="Idle angry",command=197,frequency=2,},
		action02 = {enabled=true,category=CHEERS_JEERS,action="Spit",command=178,frequency=3,},
		action03 = {enabled=true,category=POSES,action="Crack Knuckles",command=170,frequency=2,},
		action04 = {enabled=true,category=PROP,action="Hammer kneel",command=128,frequency=1,},
		action05 = {enabled=true,category=ENTERTAIN,action="Bored",command=138,frequency=3,},
		action06 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action07 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action08 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action09 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
		action10 = {enabled=false,category=CEREMONIAL,action="Bless",command=20,frequency=2,},
	}
	
	-- are there any saved personalities?
	-- if yes, skip these presets
	-- if no, initialize with these presets
	PD:LoadData()

	-- first time on account, initialize the 
	if PD.personalities == nil or table.getn(PD.personalities) == 0 or (table.getn(PD.personalities) == 1 and PD.personalities[1].name == "Blank") then
		PD.personalities = {}
		
		--table.insert(PD.personalities, PD.personalityDefault)
		table.insert(PD.personalities, default1)
		table.insert(PD.personalities, default2)
		table.insert(PD.personalities, default3)
	end
	
	local blankIndex
	-- Reset the Blank personality, and update presets if they still exist
	for i = 1, table.getn(PD.personalities) do
		if PD.personalities[i].name == GetString(P_DESIGNER_DEFAULT_BLANK) then
			blankIndex = i
		end

		if PD.personalities[i].name == GetString(P_DESIGNER_DEFAULT_FIT) and PD.personalities[i] ~= default1 then
			PD.personalities[i] = default1
		elseif PD.personalities[i].name == GetString(P_DESIGNER_DEFAULT_MAGIC) and PD.personalities[i] ~= default2 then
			PD.personalities[i] = default2
		elseif PD.personalities[i].name == GetString(P_DESIGNER_DEFAULT_RUDE) and PD.personalities[i] ~= default3 then
			PD.personalities[i] = default3
		end
	end

	if blankIndex then
		table.remove(PD.personalities, blankIndex)
	end

	PD:RefreshPersonalityActions(PD.personalityDefault)
	for i = 1, table.getn(PD.personalities) do
		PD:RefreshPersonalityActions(PD.personalities[i])
	end

	-- first time on character
	if PD.active == nil or not PD.personalities[PD.active] then
		PD.active = 1
		PD.enabled = true
	end

	PD.personalityActive = PD.personalities[PD.active]
	PD.personalityDesign = PD.personalities[PD.active]
	
	PD:SaveData()
	PD:GeneratePlaylist()
end

-- ****************************************************
--
-- Helper functions
--
-- ****************************************************

function table.copy_default()
	-- apparently LUA only does references when using =
	-- so need a function to copy tables
	-- Only ever copy the default personality which simplifies things
	local t2 = {}
	for k,v in pairs(PD.personalityDefault) do
		t2[k] = v
	end
	return t2
end

function PD:PrintActions()
	-- This is purely for debugging/testing
	for k, v in pairs(PD.actions) do
		d("category:" .. v.category .. ", action:" .. v.action .. ", command:" .. v.command)
	end
end

-- Thief Tools - mod uses both account & character
function PD:SaveData()
-- almost all the data is account wide
-- only the active flag is character
	PD.savedCharacterData.enabled = PD.enabled
	PD.savedCharacterData.active = PD.active
	PD.savedAccountData.personalities = PD.personalities
end

function PD:LoadData()
	PD.savedAccountData = ZO_SavedVars:NewAccountWide("PersonalityAccountData", PD.savedVariablesVersion, nil, {})
	PD.savedCharacterData = ZO_SavedVars:NewCharacterIdSettings("PersonalityCharacterData", PD.savedVariablesVersion, nil, {})
	
	PD.enabled = PD.savedCharacterData.enabled
	PD.active  = PD.savedCharacterData.active
	PD.personalities = PD.savedAccountData.personalities
end

function PD:GetPersonalityNames()
	-- get a list of the personalities for displaying in the various dropdowns
	local names = {}
	
	for k, v in pairs(PD.personalities) do
		table.insert(names, v.name)
	end
	return names
end

function PD:GetIndexFromName(n)
	--performs a reverse lookup on the personalities
	-- i.e., I have a name and need the key
	-- also, another reason why personality names need to be unique

	for k, v in pairs(PD.personalities) do
		if v.name == n then
			return k
		end
	end
end

function PD:GetActionFromName(n, category)
	for k, v in pairs(PD.actions) do
		if v.action == n and (category == nil or v.category == category) then
			return {
				kind = v.kind,
				id = v.id,
				category = v.category,
				action = v.action,
				command = v.command,
				enabled = true,
				frequency = 2,
			}
		end
	end
end

function PD:RefreshPersonalityActions(personality)
	for key, action in pairs(personality) do
		if type(action) == "table" and string.match(key, "^action%d%d$") then
			local kind = action.kind
			if kind == nil then
				kind = action.category == GetString(P_DESIGNER_MEMENTO) and "memento" or "emote"
			end

			local currentAction
			if action.id ~= nil then
				for k, catalogAction in pairs(PD.actions) do
					if catalogAction.kind == kind and catalogAction.id == action.id then
						currentAction = catalogAction
						break
					end
				end
			end

			if currentAction == nil then
				for k, catalogAction in pairs(PD.actions) do
					if catalogAction.kind == kind and (catalogAction.action == action.action or catalogAction.displayName == action.action) and catalogAction.category == action.category then
						currentAction = catalogAction
						break
					end
				end
			end

			action.kind = kind
			if currentAction then
				action.id = currentAction.id
				action.category = currentAction.category
				action.action = currentAction.action
				action.command = currentAction.command
			else
				action.command = nil
			end
		end
	end
end

function PD:SetActivePersonality(n)
	-- Find the index using the personality name and update active
	PD.active = PD:GetIndexFromName(n) or PD.active 
	
	-- update the reference to the newly selected personality
	PD.personalityActive = PD.personalities[PD.active]
	PD:GeneratePlaylist()

	if PD.enabled and table.getn(PD.playlist) > 0 then
		EVENT_MANAGER:RegisterForUpdate(PD.name .. "IdleCheck", 1000, function() PD:IsPlayerIdle() end)
	end
	
	PD:SaveData()
end

function PD:SetDesignPersonality(n)
	-- This is called performed after the user selects an DesignPersonality
	-- update the reference to the newly selected personality
	PD.personalityDesign = PD.personalities[PD:GetIndexFromName(n)]
	
end

function PD.GetPersonalityAction(catName, actName)
	for k, v in pairs(PD.actions) do
		if v.category == catName and v.action == actName then
			return v
		end
	end
end

function PD:CreatePersonality()
	-- TODO: provide feedback to the user
	--
	-- Ideally, the create button wouldn't even be usuable until the name
	-- passed the data checks performed below.
	--
	-- Would be cool to repurpose the labels as feedback, in lieu of
	-- message boxes
	--
	-- But I can't figure it out
	
	-- no blank names
	if PD.newPersonalityName == "" then
		return
	end
	
	-- name must be unique
	for k, v in pairs(PD.personalities) do
		if v.name == PD.newPersonalityName then
			return
		end
	end
	
	-- ok, passes the checks, copy the default and update the name
	local newPersonality = table.copy_default()
	newPersonality.name = PD.newPersonalityName
	
	table.insert(PD.personalities, newPersonality)
	
	PD.newPersonalityName = ""
	
	PD:UpdateTheDropdowns()
	PD:SaveData()
end

function PD:DeletePersonality()
	-- if the designPersonality is the same as the activePersonality
	-- then change active to default
	if (PD.deletePersonalityName == PD.personalityActive.name) then
		PD.CyclePersonality() --PD.personalityActive = PD.personalityDefault
	end

	table.remove(PD.personalities, PD:GetIndexFromName(PD.deletePersonalityName))
	
	PD.deletePersonalityName = ""
	
	PD:UpdateTheDropdowns()
	PD:SaveData()
end

function PD:UpdateTheDropdowns()
	-- need this to refresh the dropdowns, otherwise the UI doesn't update
	local names = PD:GetPersonalityNames()
	DeleteDropdown:UpdateChoices(names)
	ActiveDropdown:UpdateChoices(names)
	DesignDropdown:UpdateChoices(names)
end

function PD:FilterActions(selectedCategory)
	local filtered = {}
	local search = string.lower(PD.searchTerm or "")
	
	for k, v in pairs(PD.actions) do
		if v.category == selectedCategory then
			local actionName = string.lower(v.action or "")
			if search == "" or string.find(actionName, search, 1, true) ~= nil then
				table.insert(filtered, v.action)
			end
		end
	end
	
	table.sort(filtered)
	
	return filtered
end

function PD:GeneratePlaylist()
	PD.playlist = {}
	
	-- Create a playlist from the actions in the personalityActive
	-- each action gets added a number of times per the frequency
	-- Infrequent: added 1x
	-- Default:    added 2x
	-- Frequent:   added 4x

	for k, v in pairs(PD.personalityActive) do
		if k ~= "name" and k ~= "idleTime" and k ~= "delayTime" then
			if v.enabled then
				for i = 0, (v.frequency * 2) - 2 do
					table.insert(PD.playlist,v)
				end
			end
		end
	end
end

function PD:PlayAction(action)
	--TODO: can't play emotes when the menu is open
	-- can an add-on, close the window, run the command and then open back up?
	if not action or not action.command then return end
	if action.kind == "memento" then
		UseCollectible(action.command)
	elseif action.kind == "emote" then
		PlayEmoteByIndex(action.command)
	end
end

-- ****************************************************
--
-- Build the Addon Menu
--
-- ****************************************************
function PD:InitializeLAM()

	local panelName = PD.name
 
	local panelInfo = {
		type = "panel",
		name = PD.title,
		displayName = PD.title,
		author = PD.author,
		version = PD.version,
		slashCommand = "/personalitydesigner",
		registerForRefresh = true,
		registerForDefaults = false
	}
	
	LAM.panel = LAM:RegisterAddonPanel(panelName, panelInfo)
	
	local activeSubmenu = {
		{
			type = "dropdown",
			name = GetString(P_DESIGNER_ACTIVE_PERSONALITY),
			scrollable = true,
			choices = PD:GetPersonalityNames(),
			getFunc = function() return PD.personalityActive.name end,
			setFunc = function(x) PD:SetActivePersonality(x) end,
			reference = "ActiveDropdown",
		},
		{
			type = "slider",
			name = GetString(P_DESIGNER_IDLE),
			tooltip = GetString(P_DESIGNER_IDLE_DESC),
			min = 0,
			max = 600,
			step = 1,
			getFunc = function() return PD.personalityActive.idleTime end,
			setFunc = function(x) PD.personalityActive.idleTime = x PD:SaveData() end,
		},
		{
			type = "slider",
			name = GetString(P_DESIGNER_DELAY),
			tooltip = GetString(P_DESIGNER_DELAY_DESC),
			min = 0,
			max = 600,
			step = 1,
			getFunc = function() return PD.personalityActive.delayTime end,
			setFunc = function(x) PD.personalityActive.delayTime = x PD:SaveData() end,
		},
	}
	
	local createSubmenu = {
		{
			type = "editbox",
			name = "",
			tooltip = GetString(P_DESIGNER_NAME_TOOLTIP),
			getFunc = function() return PD.newPersonalityName end,
			setFunc = function(x) PD.newPersonalityName = x end,
			isMultiline = false,
		},
		{
			type = "button",
			name = GetString(P_DESIGNER_CREATE),
			func = function() PD:CreatePersonality() end,
		},
	}
	
	local actionNames = {
		GetString(P_DESIGNER_ACTION_01), GetString(P_DESIGNER_ACTION_02),
		GetString(P_DESIGNER_ACTION_03), GetString(P_DESIGNER_ACTION_04),
		GetString(P_DESIGNER_ACTION_05), GetString(P_DESIGNER_ACTION_06),
		GetString(P_DESIGNER_ACTION_07), GetString(P_DESIGNER_ACTION_08),
		GetString(P_DESIGNER_ACTION_09), GetString(P_DESIGNER_ACTION_10),
	}
	PD.actionDropdowns = {}

	local function CreateActionRow(index)
		local actionKey = string.format("action%02d", index)
		local actionReference = string.format("Action%02dDropdown", index)
		local actionDropdown

		return {
			type = "custom",
			reference = string.format("Action%02dRow", index),
			width = "full",
			minHeight = 54,
			maxHeight = 54,
			createFunc = function(row)
				local rowWidth = row:GetWidth()
				local enabledWidth = 112
				local categoryWidth = 175
				local actionWidth = rowWidth - enabledWidth - categoryWidth

				local enabledControl = LAMCreateControl.checkbox(row, {
					type = "checkbox",
					name = actionNames[index],
					getFunc = function() return PD.personalityDesign[actionKey].enabled end,
					setFunc = function(value)
						PD.personalityDesign[actionKey].enabled = value
						if PD.personalityDesign.name == PD.personalityActive.name then
							PD.personalityActive[actionKey].enabled = value
							PD:SaveData()
							PD:GeneratePlaylist()
						end
					end,
				}, string.format("Action%02dEnabled", index))

				enabledControl:ClearAnchors()
				enabledControl:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
				enabledControl:SetDimensions(enabledWidth, 52)
				enabledControl.label:ClearAnchors()
				enabledControl.label:SetAnchor(TOPLEFT, enabledControl, TOPLEFT, 0, 0)
				enabledControl.label:SetDimensions(75, 26)
				enabledControl.container:ClearAnchors()
				enabledControl.container:SetAnchor(TOPLEFT, enabledControl, TOPLEFT, 75, 26)
				enabledControl.container:SetDimensions(35, 26)
				enabledControl.checkbox:ClearAnchors()
				enabledControl.checkbox:SetAnchor(LEFT, enabledControl.container, LEFT, 0, 0)

				local function ConfigureDropdown(control, left, width)
					control:ClearAnchors()
					control:SetAnchor(TOPLEFT, row, TOPLEFT, left, 0)
					control:SetDimensions(width, 52)
					control.label:ClearAnchors()
					control.label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
					control.label:SetDimensions(width, 26)
					control.container:ClearAnchors()
					control.container:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 26)
					control.container:SetDimensions(width, 26)
					control.combobox:ClearAnchors()
					control.combobox:SetAnchor(TOPLEFT, control.container, TOPLEFT, 0, 0)
					control.combobox:SetDimensions(width, 26)
					control.dropdown.m_containerWidth = width
				end

				local categoryControl = LAMCreateControl.dropdown(row, {
					type = "dropdown",
					name = GetString(P_DESIGNER_CATEGORY),
					scrollable = true,
					choices = PD.categories,
					getFunc = function() return PD.personalityDesign[actionKey].category end,
					setFunc = function(value)
						PD.personalityDesign[actionKey].category = value
						actionDropdown:UpdateChoices(PD:FilterActions(value))
						if PD.personalityDesign.name == PD.personalityActive.name then
							PD.personalityActive[actionKey].category = value
							PD:SaveData()
						end
					end,
					disabled = function() return not PD.personalityDesign[actionKey].enabled end,
				}, string.format("Action%02dCategory", index))
				ConfigureDropdown(categoryControl, enabledWidth, categoryWidth)

				actionDropdown = LAMCreateControl.dropdown(row, {
					type = "dropdown",
					name = GetString(P_DESIGNER_ACTION),
					scrollable = true,
					choices = PD:FilterActions(PD.personalityDesign[actionKey].category),
					getFunc = function()
						local dropdown = PD.actionDropdowns[index]
						if dropdown then
							dropdown:UpdateChoices(PD:FilterActions(PD.personalityDesign[actionKey].category))
						end
						return PD.personalityDesign[actionKey].action
					end,
					setFunc = function(value)
						local action = PD:GetActionFromName(value, PD.personalityDesign[actionKey].category)
						action.enabled = true
						action.frequency = 2
						PD.personalityDesign[actionKey] = action
						if PD.personalityDesign.name == PD.personalityActive.name then
							PD.personalityActive[actionKey] = action
							PD:SaveData()
							PD:GeneratePlaylist()
						end
					end,
					disabled = function() return not PD.personalityDesign[actionKey].enabled end,
					reference = actionReference,
				}, actionReference)
				ConfigureDropdown(actionDropdown, enabledWidth + categoryWidth, actionWidth)
				PD.actionDropdowns[index] = actionDropdown
			end,
		}
	end

	local designSubmenu = {
		{
			type = "dropdown",
			name = GetString(P_DESIGNER_PERSONALITY),
			choices = PD:GetPersonalityNames(),
			getFunc = function() return PD.personalityDesign.name end,
			setFunc = function(value) PD:SetDesignPersonality(value) end,
			reference = "DesignDropdown",
		},
		{
			type = "editbox",
			name = "Search emotes",
			tooltip = "Type to filter the current emote list by name or slash command.",
			getFunc = function() return PD.searchTerm end,
			setFunc = function(value)
				PD.searchTerm = value or ""
				for index = 1, 10 do
					local dropdown = PD.actionDropdowns[index]
					if dropdown then
						local actionKey = string.format("action%02d", index)
						dropdown:UpdateChoices(PD:FilterActions(PD.personalityDesign[actionKey].category))
					end
				end
			end,
			isMultiline = false,
		},
	}
	for index = 1, 10 do
		table.insert(designSubmenu, CreateActionRow(index))
	end

	local deleteSubmenu = {
		{
			type = "dropdown",
			name = "",
			scrollable = true,
			--tooltip = "Cannot delete the Blank personality",
			choices = PD:GetPersonalityNames(),
			getFunc = function() return PD.deletePersonalityName end,
			setFunc = function(x) PD.deletePersonalityName = x end,
			reference = "DeleteDropdown",
		},
		{
			type = "button",
			name = GetString(P_DESIGNER_DELETE),
			func = function() PD:DeletePersonality() end,
			disabled =
				-- no deleteing the default ("blank")
				function()
					if PD.deletePersonalityName == PD.personalityDefault.name then
						return true
					end
					return false
				end,
		},
	}
	
	local optionsData = {
		{
			type = "checkbox",
			name = GetString(P_DESIGNER_PDENABLED),
			getFunc = function() return PD.enabled end,
			setFunc =
				function(x)
					PD.enabled = x
					PD:SaveData()
					if PD.enabled and table.getn(PD.playlist) > 0 then
						EVENT_MANAGER:RegisterForUpdate(PD.name .. "IdleCheck", 1000, function() PD:IsPlayerIdle() end)
					else
						EVENT_MANAGER:UnregisterForUpdate(PD.name .. "IdleCheck")
					end
				end
		},
		{ type = "divider" },
		{
			type = "submenu",
			name = GetString(P_DESIGNER_ACTIVE),
			controls = activeSubmenu,
		},
		{ type = "divider" },
		{
			type = "submenu",
			name = GetString(P_DESIGNER_CREATE),
			controls = createSubmenu,
		},
		{ type = "divider" },
		{
			type = "submenu",
			name = GetString(P_DESIGNER_DESIGN),
			controls = designSubmenu,
		},
		{ type = "divider" },
		{
			type = "submenu",
			name = GetString(P_DESIGNER_DELETE),
			controls = deleteSubmenu,
		},
	}

	LAM:RegisterOptionControls(panelName, optionsData)
end

-- ****************************************************
--
-- The Personality Loop
--
-- The mod checks if the player is idle once per second
-- This idle check is kicked off after initialization or when actions are added to the active personality
-- 
-- If the player is idle, a second update is registered: PlayAfterIdleTime, which initiates the Personality Loop
-- If the player leaves the idle state before the idleTime is reached, unregister the update
-- 
-- If they remain idle, then we start the Loop.
-- 	-Unregister the initiating update
-- 	-play the action
-- 	-and register a new update: PlayAfterDelayTime, which calls the Loop after delayTime is reached
-- 
-- But again, if the player leaves the idle state before delayTime is reached, it gets unregistered
--
-- ****************************************************

PD.firstTime = false
function PD:IsPlayerIdle()
-- if even one of these evaluate to true then the player is busy.
-- All have to be false for the player to be idle
	if (not ArePlayerWeaponsSheathed())
		or GetInteractionType() ~= 0
		or GetUnitStealthState("player") ~= 0
		or IsBlockActive()
		or (IsGameCameraUIModeActive() and DoesGameHaveFocus())
		or IsInteracting()
		or IsInteractionPending()
		or IsLooting()
		or IsMounted()
		or IsPlayerInteractingWithObject()
		or IsPlayerMoving()
		or IsPlayerStunned()
		or IsPlayerTryingToMove()
		or IsUnitDeadOrReincarnating("player")
		or IsUnitInCombat("player")
		or IsUnitSwimming("player")
		or (not PD.enabled)
		then
		--Player isn't idle, reset it
		PD.playingActions = false
		PD.firstTime = false
		EVENT_MANAGER:UnregisterForUpdate(PD.name .. "PlayAfterIdleTime")
		EVENT_MANAGER:UnregisterForUpdate(PD.name .. "PlayAfterDelayTime")
	else
		if not PD.playingActions then
			--d("IdleTime wait")
			PD.playingActions = true
			PD.firstTime = true
			EVENT_MANAGER:RegisterForUpdate(PD.name .. "PlayAfterIdleTime", PD.personalityActive.idleTime * 1000, function() PD:PlayPlaylist() end)
		end
	end
end

function PD:PlayPlaylist()
	if PD.firstTime then
		--d("Unregistering IdleTime, Registering DelayTime")
		EVENT_MANAGER:UnregisterForUpdate(PD.name .. "PlayAfterIdleTime")
		EVENT_MANAGER:RegisterForUpdate(PD.name .. "PlayAfterDelayTime", PD.personalityActive.delayTime * 1000, function() PD:PlayPlaylist() end)
		PD.firstTime = false
	end
	
	-- pick one of the playlist actions at random
	local index = math.random(1, table.getn(PD.playlist))
	--d("Playing action " .. PD.playlist[index].action)
	if PD.playlist[index].command and PD.playlist[index].kind == "memento" then
		--GetCollectibleCooldownAndDuration looked promising for identifying
		-- the memento duration. No luck.
		-- However, the IsPlayerIdle check returns busy while the memento is playing
		-- So, good enough I guess.
		UseCollectible(PD.playlist[index].command)
	elseif PD.playlist[index].command and PD.playlist[index].kind == "emote" then
		PlayEmoteByIndex(PD.playlist[index].command)
	end
	
	table.remove(PD.playlist, index)
	
	-- if we've exhausted the playlist, re-generate it
	if table.getn(PD.playlist) == 0 then
		PD.GeneratePlaylist()
	end
end

-- Step 2. Unregistering from AddOn Loaded, grabbing the data, setting-up the menu, and kicking-off the idle check
local function OnAddonLoaded(event, name)
	if name ~= PD.name then return end
	
	EVENT_MANAGER:UnregisterForEvent(PD.name, event)
	PD:Initialize()
	PD:InitializeLAM()
	--d("Playlist size is: " .. tostring(table.getn(PD.playlist)))
	if PD.enabled and table.getn(PD.playlist) > 0 then
		-- once a second, check if the player is idle
		--d("Just initialized and starting the Idle Check")
		EVENT_MANAGER:RegisterForUpdate(PD.name .. "IdleCheck", 1000, function() PD:IsPlayerIdle() end)
	end
	
	--PD:PrintActions()
end

-- Step 1. As ESO loads the addons, when it finds "PersonalityDesigner" it fires
-- this event which calls the OnAddonLoaded function
EVENT_MANAGER:RegisterForEvent(PD.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)