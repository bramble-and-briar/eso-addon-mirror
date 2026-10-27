local addon = InventoryCompanion or {}
addon.Utils = addon.Utils or {}
addon.Utils.addon = addon
local this = addon.Utils

-- Cache for computed fallback name
local cachedDisplayName = addon.DisplayName

------------------------------------------------------------
--  Enums & Constants
------------------------------------------------------------
this.Enums = {
    Interaction = {
        Bank      = "bank",
        Store     = "store",
        Fence     = "fence",
        Inventory = "inventory",
    }
}


local function UnCamelCase(str)
    str = str:gsub("(%l)(%u)", "%1 %2")
    str = str:gsub("(%u)(%u%l)", "%1 %2")
    str = str:gsub("(%a)(%d)", "%1 %2")
    return str
end

function this.DisplayName()
    if cachedDisplayName then return cachedDisplayName end

    cachedDisplayName = this.addon.Name or "InventoryCompanion"
    cachedDisplayName = UnCamelCase(cachedDisplayName)
    
    return cachedDisplayName
end

------------------------------------------------------------
--  Announcements (Center Screen Announcements)
------------------------------------------------------------
local function ShowCSA(message, category)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(
        category,
        SOUNDS.NONE
    )

    params:SetText(message)
    params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    params:MarkSuppressIconFrame()

    CENTER_SCREEN_ANNOUNCE:DisplayMessage(params)
end

function this.ShowAlertLarge(message)
    ShowCSA(message, CSA_CATEGORY_LARGE_TEXT)
end

function this.ShowAlertMedium(message)
    ShowCSA(message, CSA_CATEGORY_MAJOR_TEXT)
end

function this.ShowAlertSmall(message)
    ShowCSA(message, CSA_CATEGORY_SMALL_TEXT)
end

------------------------------------------------------------
--  Messaging & Spam Rate Limiting
------------------------------------------------------------
local lastMessageTime = 0
local spamCount = 0
local SPAM_WINDOW_SECONDS = 1

-- Track the last sent message text to prevent exact duplicate spam
local lastSentText = ""
local lastSentTimeMS = 0

-- Test support: while capturing, messages that would reach chat/HUD are recorded instead, after
-- the duplicate and spam handling below, so tests see exactly what the player would. An optional
-- clock (returning milliseconds) lets tests control that timing.
local capturedMessages = nil
local captureClockMs = nil
local savedLimiterState = nil

local function GetNowMs()
    if captureClockMs then return captureClockMs() end
    return GetGameTimeMilliseconds()
end

function this.BeginMessageCapture(clockMs)
    capturedMessages = {}
    captureClockMs = clockMs
    savedLimiterState = { lastMessageTime, spamCount, lastSentText, lastSentTimeMS }
    lastMessageTime, spamCount, lastSentText, lastSentTimeMS = -math.huge, 0, "", -math.huge
end

-- Returns the captured messages as { chat, hud, suppressed } entries, or an empty list if not capturing.
function this.EndMessageCapture()
    local messages = capturedMessages or {}
    if savedLimiterState then
        lastMessageTime, spamCount, lastSentText, lastSentTimeMS = unpack(savedLimiterState)
    end
    capturedMessages, captureClockMs, savedLimiterState = nil, nil, nil
    return messages
end

local function SendMessageNow(chatMessage, hudAlert, colorPrefix)
    colorPrefix = colorPrefix or "|cFFFFFF"
    if capturedMessages then
        table.insert(capturedMessages, { chat = chatMessage, hud = hudAlert })
        return
    end
    if chatMessage then 
        d(colorPrefix .. this.DisplayName() .. ": |r" .. chatMessage) 
    end
    if hudAlert then 
        this.ShowAlertSmall(colorPrefix .. hudAlert .. "|r") 
    end
end

local function HandleSpamAndSend(message, alert, colorPrefix)
    local nowMS = GetNowMs()
    local now = nowMS / 1000
    local textKey = message or alert or ""

    -- Check if it's a duplicate within the 500ms window
    if textKey == lastSentText and (nowMS - lastSentTimeMS < 500) then
        if capturedMessages then
            table.insert(capturedMessages, { chat = message, hud = alert, suppressed = true })
            return
        end
        local isDebug = this.addon.accountWide and this.addon.accountWide.debugEnabled

        if isDebug then
            -- Debug ON: Push flagged orange version to chat and HUD
            local flaggedColor = "|cFF9800"
            local flaggedMessage = message and ("[DUPLICATE BLOCKED] " .. message) or nil
            local flaggedAlert = alert and ("[DUP] " .. alert) or nil
            SendMessageNow(flaggedMessage, flaggedAlert, flaggedColor)
        else
            -- Debug OFF: Leave HUD alone, just log to chat quietly
            d(string.format("|c888888[%s Dupe Suppressed]:|r %s", this.DisplayName(), tostring(message or alert)))
        end
        return
    end

    lastSentText = textKey
    lastSentTimeMS = nowMS

    local isSpamming = (now - lastMessageTime) < SPAM_WINDOW_SECONDS
    lastMessageTime = now
    
    if not isSpamming then
        spamCount = 1
        SendMessageNow(message, alert, colorPrefix)
        return
    end
    
    spamCount = spamCount + 1
    
    if spamCount < 6 then
        SendMessageNow(message, alert, colorPrefix)
        return
    elseif spamCount == 6 then
        SendMessageNow(message, "...check chat for more!", colorPrefix)
        return
    else
        local chatText = message or alert
        if chatText then 
            SendMessageNow(chatText, nil, colorPrefix)
        end
        return
    end
end

------------------------------------------------------------
--  Public Messaging & Console Output Endpoints
------------------------------------------------------------
function this.DebugMessage(message, alert)   
    if this.addon.accountWide and this.addon.accountWide.debugEnabled then
        if message then d("|c4FC3F7" .. this.DisplayName() .. " (DEBUG):|r " .. tostring(message)) end
		if alert then this.ShowAlertSmall("|cff0000(DEBUG)|cFFFFFF" .. alert .. "|r") end
    end
end

function this.UserMessage(message, alert)
    HandleSpamAndSend(message, alert, "|cFFFFFF")
end

function this.UserError(message, alert) 
    HandleSpamAndSend(message, alert, "|cFF5252")
end

function this.UserWarning(message, alert)
    HandleSpamAndSend(message, alert, "|cFFEB3B")
end

------------------------------------------------------------
--  Formatting Helpers
------------------------------------------------------------
function this.FormatTime(seconds)
    seconds = math.floor(seconds)

    if seconds < 60 then
        return seconds .. "s"
    end

    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60

    if remaining == 0 then
        return minutes .. "m"
    end

    return string.format("%dm %ds", minutes, remaining)
end

function this.FormatBigNumber(value)
    if not value then return "0" end
    if value >= 1000000 then
        -- 2 decimal places for millions, cleaning up trailing zeros (e.g., 1.05m stays 1.05m, 1.00m becomes 1m)
        return string.format("%.2fm", value / 1000000):gsub("0+$", ""):gsub("%.$", "")
    elseif value >= 1000 then
        -- 1 decimal place for thousands, cleaning trailing zeros (e.g., 2.3k)
        return string.format("%.1fk", value / 1000):gsub("%.0+", "")
    end
    return tostring(value)
end

------------------------------------------------------------
--  State Checks
------------------------------------------------------------
function this.GetActiveInteraction()
	local interactionType = GetInteractionType()
	if GetInteractionType() == INTERACTION_VENDOR then 
		if SCENE_MANAGER:IsShowing("store") or SCENE_MANAGER:IsShowing("gamepad_store") then
			return this.Enums.Interaction.Store
		else
			return this.Enums.Interaction.Fence
		end
	elseif IsBankOpen() or SCENE_MANAGER:IsShowing("bank") or SCENE_MANAGER:IsShowing("gamepad_bank") then
        return this.Enums.Interaction.Bank
    elseif SCENE_MANAGER:IsShowing("store") or SCENE_MANAGER:IsShowing("gamepad_store") or (ZO_StoreDefaultDialog and not ZO_StoreDefaultDialog:IsHidden()) then
        return this.Enums.Interaction.Store   
    elseif SCENE_MANAGER:IsShowing("inventory") or SCENE_MANAGER:IsShowing("gamepad_inventory") then
        return this.Enums.Interaction.Inventory   
    end
	
    return nil	
end

-- High-level boolean query: Returns true for any item-fiddling interaction (Bank, Store, Fence, Inventory)
function this.IsItemInteractionActive()
    local interactionType = this.GetActiveInteraction()
    return interactionType == this.Enums.Interaction.Bank or
           interactionType == this.Enums.Interaction.Store or
           interactionType == this.Enums.Interaction.Fence or
           interactionType == this.Enums.Interaction.Inventory
end