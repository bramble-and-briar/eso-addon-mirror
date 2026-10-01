-- AutoNomNom add-on for Elder Scrolls Online
-- Author: Tim-P

AutoNomNom = {
    Name = "AutoNomNom",
    Author = "@Tim-P",
    Version = 1.00,
    SettingsVersion = 1.0,
    SettingsName = "AutoNomNom_SavedVariables"
}
local nn = AutoNomNom

----------------------------------
--			Defaults			--
----------------------------------
nn.defaultsAccount = {	
	foodBufferSeconds = 300,
	lowInventoryWarningThreshold = 1,
	autoEatFailureWarningIntervalSeconds = 600, -- default 10 minutes
	debugEnabled = false,    
}

nn.defaultsCharacter = {
    isAutoEatFood = true,   
    foodLink = "",	
}

----------------------------------
--		Variables/Constants		--
----------------------------------

--variables
--todo: Do these need to be global???
nn.State = {
    buffActive = false,
    remainingBuffTime = 0,
    abilityId = nil,
    buffChanged = false,
    foodEatenLink = nil,
    inventoryCount = 0,
}

nn.lastStackSnapshot = {}
nn.debugEnabled = true
local isEatOnNextUpdate = false
local lastMessageTime = GetFrameTimeSeconds()
local lastMessageText = nil

--potentially deprecated
local lastWarningTime = GetFrameTimeSeconds()
--nn.inventoryWarningCountdown = 0
--nn.remainingInventory = nil
--local out_of_inventory_warning_frequency = 2--300 -- ticks

--constants
local LFDB = LIB_FOOD_DRINK_BUFF
local player_unit_tag = "player"
local update_timer_period = 1000 -- milliseconds
local consumed_message_delay = 2000 -- milliseconds
local food_buffer_seconds_min = 0 -- seconds
local food_buffer_seconds_max = 600 -- seconds (was 600)
local context_menu_label_on = "NomNom Next"
local context_menu_delay = 50
local update_sound = SOUNDS.DIALOG_ACCEPT
local placeholder_buff_time_remaining = "{{Buff Time Remaining}}"


----------------------------------
--		Messaging			--
----------------------------------
--todo - move these to utils now
function DebugMessage(message)
    if nn.accountWide.debugEnabled then
        d("|c4FC3F7AutoNomNom (DEBUG):|r " .. message)
    end
end

function UserMessage(message, alert)
	if (message) then d("|cFFFFFFAutoNomNom: |r" .. message) end
	if (alert) then nn.Utils.ShowAlertSmall("|cFFFFFFAutoNomNom: " .. alert .. "|r") end
end

function UserError(message, alert)	
    if (message) then d("|cFF5252AutoNomNom: |r" .. message) end
	if (alert) then nn.Utils.ShowAlertSmall("|cFF5252AutoNomNom: " .. alert .. "|r") end
end

function UserWarning(message, alert)
	if (message) then d("|cFFEB3BAutoNomNom: |r" .. message) end
	if (alert) then nn.Utils.ShowAlertSmall("|cFFEB3BAutoNomNom: " .. alert .. "|r") end
end

function ShowSnapshot(snap)
    if not snap then
        DebugMessage("Snapshot is nil")
        return
    end

    -- Collect keys for deterministic ordering
    local keys = {}
    for itemLink, _ in pairs(snap) do
        table.insert(keys, itemLink)
    end
    table.sort(keys)

    DebugMessage("Snapshot contains " .. tostring(#keys) .. " food/drink stacks")

    for _, itemLink in ipairs(keys) do
        local count = snap[itemLink]
        local name = GetItemLinkName(itemLink)
        DebugMessage(string.format("%s  | %d", itemLink, count))
    end

    DebugMessage("---- End Snapshot ----")
end

----------------------------------
--		Food Buff Tracking		--
----------------------------------
-- On a timer, poll the current buff, and store a snapshot of the user's bag's food items.
-- if the buff has changed, take another snapshot and diff them. If precisely one stack has reduced
-- by precicely one item, then assume that is the food they have eaten. Then store that as the new food link.

local function GetBackpackInventory(itemLink)
    local inventoryCount = 0
    if itemLink == "" then return inventoryCount end

    local numSlots = GetBagSize(BAG_BACKPACK)
    for slotIndex = 0, numSlots do
        local slotItemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if slotItemLink == itemLink then
            local itemCount = GetItemTotalCount(BAG_BACKPACK, slotIndex)
            inventoryCount = inventoryCount + itemCount
        end
    end
    return inventoryCount
end

local function IsExperienceDrink(bagId, slotIndex)
    local itemId = GetItemId(bagId, slotIndex)
    if itemId == 64221 then return true
    elseif itemId == 120076 then return true
    elseif itemId == 115027 then return true
    else return false end
end

local function IsValidFoodOrDrink(bagId, slotIndex)
    local itemType = GetItemType(bagId, slotIndex)
    if not (itemType == ITEMTYPE_DRINK or itemType == ITEMTYPE_FOOD) then 
        return false
    end
    if IsExperienceDrink(bagId, slotIndex) then return false end
    return true
end

local function DetectConsumedFood(oldSnap, newSnap)
    local consumedItemLink = nil
    local changes = 0

    -- Check items that existed before
    for itemLink, oldCount in pairs(oldSnap) do
        local newCount = newSnap[itemLink] or 0
        local delta = newCount - oldCount

        if delta ~= 0 then
            if delta == -1 then
                consumedItemLink = itemLink
                changes = changes + 1
            else
                return nil   -- invalid change
            end
        end
    end

    -- Abort if any new food type appears
    for itemLink, _ in pairs(newSnap) do
        if oldSnap[itemLink] == nil then
            return nil
        end
    end

    return (changes == 1) and consumedItemLink or nil
end

local function BuildFoodStackSnapshot()
    local snapshot = {}
    local numSlots = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, numSlots do	
	  local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if itemLink ~= "" then
		if IsValidFoodOrDrink(BAG_BACKPACK, slotIndex) then
			local count = GetItemTotalCount(BAG_BACKPACK, slotIndex)
			snapshot[itemLink] = (snapshot[itemLink] or 0) + count            
		end
        end
    end

    return snapshot
end

----------------------------------
--			AutoConsume			--
----------------------------------

local function CanUseItem(bagId, slotIndex)
    local usable, usableOnlyFromActionSlot = IsItemUsable(bagId, slotIndex)
    local canInteract = CanInteractWithItem(bagId, slotIndex)
    return usable and not usableOnlyFromActionSlot and canInteract
end

local function TryUseFoodItem(bagId, slotIndex)
    if IsValidFoodOrDrink(bagId, slotIndex) then
        if CanUseItem(bagId, slotIndex) then
            local success = CallSecureProtected("UseItem", bagId, slotIndex)
            return success
        end
    end
end

local function VerifyConsumed()
    local isBuffActive, timeLeftInSeconds, abilityId = LFDB:IsFoodBuffActiveAndGetTimeLeft(player_unit_tag)
    return isBuffActive and timeLeftInSeconds > food_buffer_seconds_max
end

local function IsUnitAbleToUseFood(unitTag)
    if IsUnitInCombat(unitTag) then return
    elseif IsUnitDeadOrReincarnating(unitTag) then return
    elseif IsUnitSwimming(unitTag) then return
    elseif IsPlayerInteractingWithObject() then return
    elseif IsScryingInProgress() then return
    elseif IsDiggingGameActive() then return
    else return true end
end

local function ShowConsumedMessage(itemLink)
    if VerifyConsumed() then
        UserMessage(itemLink .. " has been automatically consumed. Nom Nom Nom!")
    end
end

local function EatFood()	
    local numSlots = GetBagSize(BAG_BACKPACK)

    for slotIndex = 0, numSlots do
        local slotItemLink = GetItemLink(BAG_BACKPACK, slotIndex)
        if slotItemLink == nn.character.foodLink then
            local success = TryUseFoodItem(BAG_BACKPACK, slotIndex)
			--UserMessage(nn.character.foodLink .. " is coming up - Nom Nom Nom!")
            if success then
                zo_callLater(function() ShowConsumedMessage(slotItemLink) end, consumed_message_delay)
                return true
            else
                return false
            end
        end
    end	
end

local function AutoEat()
	--can the player eat right now?
   if not nn.character.isAutoEatFood then return end --addon disabled
   if not IsUnitAbleToUseFood(player_unit_tag) then return end --not allowed to eat
   if nn.character.foodLink == "" then return end  --don't know what to eat
	
	--DebugMessage("AutoEat()-----------------------------")
	--do they need to eat right now
	if nn.State.buffActive and nn.State.remainingBuffTime > nn.accountWide.foodBufferSeconds then return end --don't need to eat
	
    if not nn.State.buffActive then
		--in this case the character may have eaten but the buff isn't showing yet, so we defer until the next tick, then eat if it is still the case that there is no food buff active.
        if not isEatOnNextUpdate then
            isEatOnNextUpdate = true
			DebugMessage("AutoEat Set EatOnNextUpdate TRUE and Quit.")
			return
		end			
    end
	
    isEatOnNextUpdate = false
	DebugMessage("AutoEat Set EatOnNextUpdate FALSE")
	
	DebugMessage("Eating Food")
    EatFood()  
end

 local function CheckFoodStores_GetSendLevel(messageImportance, messageText)
    local now = GetFrameTimeSeconds()
	
	--is this a brand new message?
    local isNewMessage = (lastMessageText ~= messageText)	
	lastMessageText = messageText
	
	--empty messages do not get sent
	if not (messageText) then return "none" end
	
	--new messages get sent (their text is different from the last one)
    if isNewMessage then return messageImportance end
		
	-- Urgent messages use 60 second cadence ONLY when buff < 10 minutes
    if messageImportance == "urgent" and  nn.State.buffActive and nn.State.remainingBuffTime <= 600 and  (now - lastMessageTime) >= 60 then 
		return messageImportance
	end

	-- All other messages (urgent >10 mins or normal ones) use the normal relaxed cadence
	if (now - lastMessageTime) >= nn.accountWide.autoEatFailureWarningIntervalSeconds then
		return messageImportance
	end
	
	return "none"
end

local function CheckFoodStores()
    local messageText = nil
	local messageShort = nil
    local messageImportance = nil
		
    -- build the message
    if nn.character.foodLink == "" then
        messageText = "I'm not sure what you are eating at the moment. I'm not going to be able to feed you another one when it ends. You can right click on a food to set it to the one you want, or just eat one (as long as it changes your current buff - I'll see it."
		messageShort = "AutoNomNom needs to know what food you are eating."
        messageImportance = "urgent"

    elseif nn.State.inventoryCount == 0 then
		if nn.State.remainingBuffTime < 3600 then 
			messageText = "You don't have any " .. nn.character.foodLink .. " in your bag, and time is running out. You only have " .. placeholder_buff_time_remaining .. " left!"
			messageShort = "You are out of " .. nn.character.foodLink .. "  and only have " .. placeholder_buff_time_remaining .. " left!"
		else		
			messageText = "Uh oh! You asked me to keep you topped up with " .. nn.character.foodLink .. ", but you don’t have any left in your bag. Better restock before you go hungry. (Just saying)"
			messageShort = "You are out of " .. nn.character.foodLink .. "  you still have " .. placeholder_buff_time_remaining .. " left"
		end
        messageImportance = "urgent"
		
    elseif nn.State.inventoryCount <= nn.accountWide.lowInventoryWarningThreshold then
        local suffix = (nn.State.inventoryCount == 1) and "" or "s"
        messageText = "You have only " .. nn.State.inventoryCount .. " portion" .. suffix ..
                      " of " .. nn.character.foodLink .. " left in your bag. Don't let yourself get hungry!"
        messageImportance = "normal"
    end

    -- ask the oracle
	local sendType = CheckFoodStores_GetSendLevel(messageImportance, messageText)
	
	--substitute in for placeholder text
	if (messageText) then messageText = messageText:gsub(placeholder_buff_time_remaining, nn.Utils.FormatTime(nn.State.remainingBuffTime)) end
	if (messageShort) then messageShort = messageShort:gsub(placeholder_buff_time_remaining, nn.Utils.FormatTime(nn.State.remainingBuffTime)) end
	
	if sendType == "urgent" then 
		UserError(messageText,messageShort)	
	elseif sendType == "normal" then 
		UserWarning(messageText,messageShort)
	else
		return
	end

	--we sent a message, update the lastMessageTime
    lastMessageTime = GetFrameTimeSeconds()
end

local function OnBuffChanged()
    -- 1. Update lastAbilityId because the buff changed
    nn.lastAbilityId = nn.State.abilityId

    -- 2. If we detected the consumed food
    if nn.State.foodEatenLink then
        -- Same food refreshed
        if nn.State.foodEatenLink == nn.character.foodLink then
            UserMessage("Looks like you just staved off starvation with a portion of " .. nn.State.foodEatenLink .. ". Don't worry - I'll keep you topped up from now on....")
        else
            -- New food chosen
            nn.character.foodLink = nn.State.foodEatenLink
            UserMessage("You just changed the menu! I'll keep you topped up with " .. nn.State.foodEatenLink .. " until you tell me not to.")
        end

        return
    end

    -- 3. If buff changed but we couldn't detect the food eaten
    UserError("I couldn't work out what you just ate, so I'll keep using your previous food (" .. nn.character.foodLink .. "). Please eat one portion at a time so I can detect the change.")
end

local function GetState(fullDebug)
    ----------------------------------------------------------------
    -- 1. Buff scan (single LFDB call)
    ----------------------------------------------------------------
    local buffActive, timeLeft, abilityId = LFDB:IsFoodBuffActiveAndGetTimeLeft(player_unit_tag)

    nn.State.buffActive = buffActive
    nn.State.remainingBuffTime = timeLeft or 0
    nn.State.abilityId = abilityId

    ----------------------------------------------------------------
    -- 2. Buff change detection (pure data, no side‑effects)
    ----------------------------------------------------------------
    if buffActive then
        if nn.lastAbilityId ~= abilityId then
            nn.State.buffChanged = true
        else
            nn.State.buffChanged = false
        end
    else
        nn.State.buffChanged = false
    end

    ----------------------------------------------------------------
    -- 3. Inventory count for the currently tracked food
    ----------------------------------------------------------------
    if nn.character.foodLink ~= "" then
        nn.State.inventoryCount = GetBackpackInventory(nn.character.foodLink)
    else
        nn.State.inventoryCount = 0
    end

    ----------------------------------------------------------------
    -- 4. Food eaten detection (snapshot diff)
    --    NOTE: snapshot itself is NOT stored in state.
    ----------------------------------------------------------------
    local newSnap = BuildFoodStackSnapshot()
    local oldSnap = nn.lastStackSnapshot or {}

    nn.State.foodEatenLink = DetectConsumedFood(oldSnap, newSnap)

    ----------------------------------------------------------------
    -- 5. Update last snapshot (historical, not state)
    ----------------------------------------------------------------
    nn.lastStackSnapshot = newSnap
	
	----------------------------------------------------------------
    -- 6. Debug dump of state (one line per value)
    ----------------------------------------------------------------
    if nn.accountWide.debugEnabled and fullDebug then
		DebugMessage("GetState Ran:")
        DebugMessage("STATE.buffActive = " .. tostring(nn.State.buffActive))
        DebugMessage("STATE.remainingBuffTime = " .. tostring(nn.State.remainingBuffTime))
        DebugMessage("STATE.abilityId = " .. tostring(nn.State.abilityId))
        DebugMessage("STATE.buffChanged = " .. tostring(nn.State.buffChanged))
        DebugMessage("STATE.inventoryCount = " .. tostring(nn.State.inventoryCount))
        DebugMessage("STATE.foodEatenLink = " .. tostring(nn.State.foodEatenLink))
		DebugMessage("CHAR.isAutoEatFood = " .. tostring(nn.character.isAutoEatFood))
		DebugMessage("-------------------------------------------------------------------")
		DebugMessage("CHAR.foodLink = " .. tostring(nn.character.foodLink))
		DebugMessage("-------------------------------------------------------------------")
		DebugMessage("ACC.foodBufferSeconds = " .. tostring(nn.accountWide.foodBufferSeconds))
		DebugMessage("ACC.lowInventoryWarningThreshold = " .. tostring(nn.accountWide.lowInventoryWarningThreshold))
		DebugMessage("ACC.autoEatFailureWarningIntervalSeconds = " .. tostring(nn.accountWide.autoEatFailureWarningIntervalSeconds))
		DebugMessage("ACC.debugEnabled = " .. tostring(nn.accountWide.debugEnabled))
		DebugMessage("-------------------------------------------------------------------")
		DebugMessage("lastAbilityId = " .. tostring(nn.lastAbilityId))
		DebugMessage("lastMessageTime = " .. tostring(lastMessageTime))
		DebugMessage("lastMessageText = " .. tostring(lastMessageText))
		DebugMessage("-------------------------------------------------------------------")
		DebugMessage("isEatOnNextUpdate = " .. tostring(isEatOnNextUpdate))
		DebugMessage("playerCanEat = " .. tostring(IsUnitAbleToUseFood(player_unit_tag)))		
    end
end

----------------------------------
--			Main Loop			--
----------------------------------
local function DoLoop()
--Get the state		
	DebugMessage("LOOP: GetState()")
	GetState()
	--If the buff has changed, discover what food was just eaten, record it
	DebugMessage("LOOP: OnBuffChanged()")
	if nn.State.buffChanged then OnBuffChanged() end
	--if we are not auto-eating then break;	
	if not nn.character.isAutoEatFood then return end --don't bother with any thing else	
	--if we have any issues with the setup, then warn the user. Remember warning them so we don't spam
	DebugMessage("LOOP: CheckFoodStores")
	CheckFoodStores()	
	--if it is time to autoeat, then do that
	DebugMessage("LOOP: AutoEat()")
	AutoEat()
end

local function OnUpdateTimer()

	if not nn.accountWide.debugEnabled then DoLoop() end
end

----------------------------------
-- Context Menu Integration
----------------------------------
local function AddContextMenuItem(rowControl)
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(rowControl)
    if not bagId or not slotIndex then return end

    local itemType = GetItemType(bagId, slotIndex)
    if itemType ~= ITEMTYPE_FOOD and itemType ~= ITEMTYPE_DRINK then
        return
    end

    local itemLink = GetItemLink(bagId, slotIndex)

    AddCustomMenuItem(context_menu_label_on,
        function()			
            nn.character.foodLink = itemLink
			UserMessage("You just changed the menu! I'll keep you topped up with " .. nn.character.foodLink .. " when your current food runs out.")
            PlaySound(update_sound)
        end,
        MENU_ADD_OPTION_LABEL)

    ShowMenu()
end

local function AddContextMenuItemWithDelay(rowControl)
    zo_callLater(function()
        AddContextMenuItem(rowControl)
    end, context_menu_delay)
end

----------------------------------
--			Settings			--
----------------------------------
local function CreateSettingsPanel()

    local LAM = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = "AutoNomNom",
        displayName = "AutoNomNom",
        author = "Tim-P",
        version = "1.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel("AutoNomNomPanel", panelData)

	local optionsData = {

		-- Account‑wide Debug Mode
		{
			type = "header",
			name = "Account Settings",
		},
		{
			type = "slider",
			name = "Food Buffer (seconds)",
			tooltip = "Eat this many seconds before food expires.",
			min = 0,
			max = 600,
			getFunc = function() return nn.accountWide.foodBufferSeconds end,
			setFunc = function(v) nn.accountWide.foodBufferSeconds = v end,
			default = nn.defaultsAccount.foodBufferSeconds,
		},
		{
			type = "slider",
			name = "Low Inventory Warning Threshold",
			tooltip = "Warn me when my remaining portions drop to this number or below.",
			min = 0,
			max = 20,
			getFunc = function() return nn.accountWide.lowInventoryWarningThreshold end,
			setFunc = function(v) nn.accountWide.lowInventoryWarningThreshold = v end,
			default = nn.defaultsAccount.lowInventoryWarningThreshold,
		},
		{
			type = "slider",
			name = "Auto-Eat Warning Interval",
			tooltip = "How often AutoNomNom should remind you that it cannot auto‑eat because you have no food.",
			min = 10,
			max = 1200,
			getFunc = function() return nn.accountWide.autoEatFailureWarningIntervalSeconds end,
			setFunc = function(v) nn.accountWide.autoEatFailureWarningIntervalSeconds = v end,
			default = nn.defaultsAccount.autoEatFailureWarningIntervalSeconds,
		},
		{
			type = "checkbox",
			name = "Enable Debug Mode",
			tooltip = "Turn on detailed debug logging for all characters.",
			getFunc = function() return nn.accountWide.debugEnabled end,
			setFunc = function(value) nn.accountWide.debugEnabled = value end,
			default = nn.defaultsAccount.debugEnabled,
		},

		{
			type = "divider",
		},

		-- Character‑specific settings
		{
			type = "header",
			name = "Character Settings",
		},

		{
			type = "checkbox",
			name = "Enable Automatic Eating",
			tooltip = "Master switch for AutoNomNom on this character only.",
			getFunc = function() return nn.character.isAutoEatFood end,
			setFunc = function(v) nn.character.isAutoEatFood = v end,
			default = nn.defaultsCharacter.isAutoEatFood,
		},		
		{
			type = "description",
			title = "Current Food",
			text = function()
				local link = nn.character.foodLink
				if link == "" then
					return "No food has been detected yet. Eat one portion so AutoNomNom can learn your current choice."
				else
					return "AutoNomNom will keep you topped up with: " .. link
				end
			end,
		},

	}

    LAM:RegisterOptionControls("AutoNomNomPanel", optionsData)
end

----------------------------------
--		Initialization			--
----------------------------------
local function Initialize()
	nn.accountWide = ZO_SavedVars:NewAccountWide(nn.SettingsName,nn.SettingsVersion,"Account",nn.defaultsAccount)
	nn.character = ZO_SavedVars:NewCharacterNameSettings(nn.SettingsName,nn.SettingsVersion,"Character",nn.defaultsCharacter)
	CreateSettingsPanel()
    
	ZO_CreateStringId("SI_BINDING_NAME_AUTONOMNOM_DEBUG", "AutoNomNom Debug Hotkey")
	ZO_CreateStringId("SI_BINDING_NAME_AUTONOMNOM_AUTOEAT_ON", "Enable NomNom")
	ZO_CreateStringId("SI_BINDING_NAME_AUTONOMNOM_AUTOEAT_OFF", "Disable NomNom")
	ZO_CreateStringId("SI_BINDING_NAME_AUTONOMNOM_AUTOEAT_TOGGLE", "Toggle NomNom")
	
	-- Prime the state before the first timer tick
	GetState()
	nn.lastAbilityId = nn.State.abilityId
	
    EVENT_MANAGER:RegisterForUpdate(nn.name, update_timer_period, OnUpdateTimer)
	ZO_PreHook("ZO_InventorySlot_ShowContextMenu", AddContextMenuItemWithDelay)
end

local function OnAddOnLoaded(eventCode, name)
    if (name == nn.Name) then
        EVENT_MANAGER:UnregisterForEvent(nn.Name, eventCode)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(nn.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

----------------------------------
--		HotKeys			--
----------------------------------
  
local function ToggleDebugMode()
    nn.accountWide.debugEnabled = not nn.accountWide.debugEnabled

    if nn.accountWide.debugEnabled then
        UserWarning("Debug mode is now ON.")
        UserMessage("I'll show detailed internal messages to help you diagnose behaviour.")
		DebugMessage("This is an example DEBUG message")
		UserMessage("This is an example USER message")
		UserWarning("This is an example WARNING message")
		UserError("This is an example ERROR message")
    else
        UserWarning("Debug mode is now OFF.")
        UserMessage("I'll keep quiet unless something important happens.")
    end
end

function nn.RunTimingTest(testData)
	--set state	
    nn.State.buffActive = testData.buffActive
	nn.State.remainingBuffTime = testData.remainingBuffTime    
	lastMessageTime = testData.lastMessageTime
	lastMessageText = testData.lastMessageText
	
	local result = CheckFoodStores_GetSendLevel(testData.importance, testData.messageText)
	
	if result == testData.expected then
        d("|c00FF00PASS|r " .. testData.description .. " → " .. tostring(result))
    else
        d("|cFF0000FAIL|r " .. testData.description .. " → got " .. tostring(result) .. ", expected " .. tostring(testData.expected))
    end	
end

function nn.Hotkey_AutoEatOn()
    nn.character.isAutoEatFood = true
    UserMessage("NomNom is now enabled. I'll keep you fed if I can!")
end

function nn.Hotkey_AutoEatOff()
    nn.character.isAutoEatFood = false
    UserMessage("NomNom is OFF the table! Don't let yourself get hungry now...")
end

function nn.Hotkey_AutoEatToggle()
    nn.character.isAutoEatFood = not nn.character.isAutoEatFood

    if nn.character.isAutoEatFood then
        UserMessage("NomNom is now enabled. I'll keep you fed if I can!")
    else
        UserMessage("NomNom is OFF the table! Don't let yourself get hungry now...")
    end
end

function nn.DebugHotkey()
	DoLoop()
   --nn.utils.ShowMainMessage_Medium("Hello")   
   --nn.UnitTests.TimingTests()
   --nn.Utils.ShowMainMessage_Small("Hello, this is a test of how long we can make a message before it looks |cff0000Ridiculous. |r is it |c00ff00this|r long, or |c0000ffthis|r long?")
end