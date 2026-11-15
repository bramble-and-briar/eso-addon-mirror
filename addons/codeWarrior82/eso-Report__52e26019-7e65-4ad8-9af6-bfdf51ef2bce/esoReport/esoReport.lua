local appName = "esoReport"
local buffRunning = false

local appVersion = 1  -- bump this on each update
local savedVars
local provider
local notifications = {}   -- messages currently shown in the menu

esoReport = {}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--clean player names
local function cleanName(str)
    return str:sub(1, -4)
end

local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName,
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    --local nameTmp = GetUnitName("player")

    --if nameTmp ~= cleanName(targetName) then
    --    return
    --end

    printMessage(" ")
    printMessage("combatReport")
    printMessage(zo_strformat("eventCode- <<1>>", eventCode))
    printMessage(zo_strformat("result- <<1>>", result))
    printMessage(zo_strformat("abilityName- <<1>>", abilityName))
    printMessage(zo_strformat("sourceName- <<1>>", sourceName))
    --printMessage(zo_strformat("sourceType- <<1>>", sourceType))
    printMessage(zo_strformat("targetName- <<1>>", targetName))
    --printMessage(zo_strformat("targetType- <<1>>", targetType))
    --printMessage(zo_strformat("hitValue- <<1>>", hitValue))
    --printMessage(zo_strformat("powerType- <<1>>", powerType))
    --printMessage(zo_strformat("damageType- <<1>>", damageType))
    printMessage(zo_strformat("sourceUnitId- <<1>>", sourceUnitId))
    --printMessage(zo_strformat("targetUnitId- <<1>>", targetUnitId))
    printMessage(zo_strformat("abilityId- <<1>>", abilityId))
    printMessage(" ")
end


local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    --(changeType)	 -- 1 is gained, 2 is gone, 3 is update
	--(effectType)	 -- 1 is debuff, 0 is buff
    printMessage(" ")
    printMessage("effectReport")
    if changeType == 1 then
        printMessage("gained effect")
    elseif changeType == 2 then
        printMessage("lost effect")
    elseif changeType == 3 then
        printMessage("effect update")
    else
        printMessage(zo_strformat("changeType- <<1>>", changeType))
    end
    printMessage(zo_strformat("effectName- <<1>>", effectName))
    printMessage(zo_strformat("unitName- <<1>>", unitName))
    printMessage(zo_strformat("unitID- <<1>>", unitID))
    printMessage(zo_strformat("abilityID- <<1>>", abilityID))
    printMessage(zo_strformat("buffType- <<1>>", buffType))
    printMessage(" ")


    
end

--register for notifications 
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("effectReport", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("effectReport", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 263462)
    --EVENT_MANAGER:RegisterForEvent("effectReport2", EVENT_EFFECT_CHANGED, effectReport)
    --EVENT_MANAGER:AddFilterForEvent("effectReport2", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, 163108)
    EVENT_MANAGER:RegisterForEvent("combatReport", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("combatReport", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 117691)
end































--------------------------------------------------------------------
-- 1. Render our entries (custom icon + heading)
--------------------------------------------------------------------
local function HookEntryRendering()
    local originalAddDataEntry = GAMEPAD_NOTIFICATIONS.AddDataEntry

    function GAMEPAD_NOTIFICATIONS:AddDataEntry(dataType, data, isHeader)
        if not data.isMyAddonNotification then
            return originalAddDataEntry(self, dataType, data, isHeader)
        end

        local entryData = ZO_GamepadEntryData:New(data.shortDisplayText, data.texture)
        entryData.data = data
        entryData:SetIconTintOnSelection(true)
        entryData:SetIconDisabledTintOnSelection(true)

        local template = ZO_NOTIFICATION_TYPE_TO_GAMEPAD_TEMPLATE[dataType]
        if isHeader then
            entryData:SetHeader(data.heading)
            self.list:AddEntryWithHeader(template, entryData)
        else
            self.list:AddEntry(template, entryData)
        end
    end
end

--------------------------------------------------------------------
-- 2. Provider: feeds our messages into the notification list
--------------------------------------------------------------------
local MyProvider = ZO_NotificationProvider:Subclass()

function MyProvider:New(notificationManager)
    local newProvider = ZO_NotificationProvider.New(self, notificationManager)
    table.insert(notificationManager.providers, newProvider)
    return newProvider
end

function MyProvider:BuildNotificationList()
    ZO_ClearNumericallyIndexedTable(self.list)
    self.list = ZO_DeepTableCopy(notifications)
end

function MyProvider:Accept(data)
    if data.acceptCallback then data.acceptCallback(data) end
end

function MyProvider:Decline(data)
    if data.declineCallback then data.declineCallback(data) end
end

--------------------------------------------------------------------
-- 3. Post / dismiss
--------------------------------------------------------------------
local updateMessage

local function DismissUpdateMessage()
    if not updateMessage then return end
    for i, msg in ipairs(notifications) do
        if msg == updateMessage then
            table.remove(notifications, i)
            break
        end
    end
    updateMessage = nil
    provider:pushUpdateCallback()
end

local function PostUpdateNotification()
    updateMessage = {
        isMyAddonNotification = true,
        dataType = NOTIFICATIONS_ALERT_DATA,
        secsSinceRequest = ZO_NormalizeSecondsSince(0),
        heading = "MyAddon",
        message = "MyAddon has been updated to version " .. appVersion .. ".",
        note = "New features and bug fixes are available.",
        shortDisplayText = "MyAddon Updated",
        texture = "/esoui/art/miscellaneous/eso_icon_warning.dds",
        controlsOwnSounds = true,
        acceptCallback = DismissUpdateMessage,
        declineCallback = DismissUpdateMessage,
    }
    table.insert(notifications, updateMessage)
    provider:pushUpdateCallback()
end



local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_PLAYER_ACTIVATED)

    --if savedVars.lastSeenVersion ~= appVersion then
        PostUpdateNotification()
    --    savedVars.lastSeenVersion = appVersion
    --end
end


--an addon has loaded
local function onAddOnLoaded(event, name)

    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

	--notify that add-on has been loaded
	zo_callLater(function() printMessage("add-on loaded") end, 500)

    --registerAlerts()


    savedVars = ZO_SavedVars:NewAccountWide("esoRepAddonVars", 1, nil, { lastSeenVersion = 0 })

    if GAMEPAD_NOTIFICATIONS then
        HookEntryRendering()
        provider = MyProvider:New(GAMEPAD_NOTIFICATIONS)
        EVENT_MANAGER:RegisterForEvent(appName, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    else
        printMessage("no notifications")
    end



    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    --zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)