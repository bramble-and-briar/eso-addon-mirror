local appName = "rushOfAgonyTracker"
local rushAbilityID = 159275
local timeRemaining = 0
local picPath = GetAbilityIcon(rushAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local setId = 604
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackRush"

rushOfAgonyTracker = {}

rushOfAgonyTracker.defaults = {
    trackRush = true,
    autoTrack = true,
	notify = true,
    yAxisText = 930,
    xAxisText = 1300
}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--clean player names
local function cleanName(str)
    return str:sub(1, -4)
end

--check if LibNotify is available
local function isLibAvailable()
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" and type(LibNotify.getSet) == "function" then
        return true
    else 
		return false
    end
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    roatrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if rushOfAgonyTracker.savedVariables.trackRush and isEquiped and rushOfAgonyTracker.savedVariables.autoTrack then
        roatrack:SetHidden(false)
    elseif rushOfAgonyTracker.savedVariables.trackRush and not rushOfAgonyTracker.savedVariables.autoTrack then
        roatrack:SetHidden(false)
    end
end

local function onSceneStateChange(scene, oldState, newState)
    if isLoaded then
        local sceneName = SCENE_MANAGER:GetCurrentScene():GetName()

        if sceneName == "hud" then
            if  newState == SCENE_HIDING then onMenuOpened()
            elseif  newState == SCENE_HIDDEN then onMenuClosed()
            end
        end
    end
end

--change archdruid anchor to move around the screen at app start
local function setAnchorStartupIcon(x, y)  
    roatrack:ClearAnchors()
    roatrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    roatrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then roatrack:SetHidden(true) end end, 2000)
    roatrack:ClearAnchors()
    roatrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--handle cooldown
local function processCooldown()

    local text
    if timeRemaining >= 10 then
        text = string.format(" %d", timeRemaining)
    else
        text = string.format("  %d", timeRemaining)
    end

    if timeRemaining > 0 then
        EVENT_MANAGER:RegisterForUpdate("rushUpdate", 1000, processCooldown)
        roatrackLabelMain:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("rushUpdate")
        roatrackLabelMain:SetText("")
        timeRemaining = 5
		if isLibAvailable() and rushOfAgonyTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, rushAbilityID, "Rush of Agony Ready")
        end
    end

    timeRemaining = timeRemaining - 1
end

local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    local nameTmp = GetUnitName("player")

    if isError then
        return
    end

    if nameTmp ~= cleanName(sourceName) or abilityId ~= rushAbilityID then
        return
    end

    timeRemaining = 5
    processCooldown()
end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("rushProc", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("rushProc", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, rushAbilityID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("rushProc", EVENT_COMBAT_EVENT)
end

--query lib to check if set is equipped
local function isSetEquiped(id, count)
	if isLibAvailable() then
		if LibNotify.getSet(appName, id, count) then
			isEquiped = true
			return true
		else
			isEquiped = false
			return false
		end
    end
end

--stop tracking if set is not equipped
local function stopTrackingAuto()

    if rushOfAgonyTracker.savedVariables.trackRush and rushOfAgonyTracker.savedVariables.autoTrack then
        printMessage("Rush of Agony set not found")
        unRegisterAlerts()
        roatrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if rushOfAgonyTracker.savedVariables.trackRush and rushOfAgonyTracker.savedVariables.autoTrack then
        printMessage("Found Rush of Agony set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and rushOfAgonyTracker.savedVariables.autoTrack and rushOfAgonyTracker.savedVariables.trackRush then startTrackingAuto() else stopTrackingAuto() end
	end, 1000)
    end

end

--request callbacks when gear items are equipped or unequipped
local function enableCallbacksGear()
    EVENT_MANAGER:RegisterForEvent(callBackName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onEquipmentChanged)
    EVENT_MANAGER:AddFilterForEvent(callBackName, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
end

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Rush of Agony Tracker",
        displayName = "Rush of Agony Tracker",
        author = "codewarrior82",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            title = "Add-On Settings",
            width = "full",
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Track cooldown",
            tooltip = "Displays a timer that tracks the Rush of Agony cooldown.",
            getFunc = function()
                return rushOfAgonyTracker.savedVariables.trackRush
            end,
            setFunc = function(value)
                rushOfAgonyTracker.savedVariables.trackRush = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = rushOfAgonyTracker.defaults.trackRush,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return rushOfAgonyTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                rushOfAgonyTracker.savedVariables.autoTrack = value
            end,
            default = rushOfAgonyTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return rushOfAgonyTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                rushOfAgonyTracker.savedVariables.xAxisText = value
                setAnchorIcon(rushOfAgonyTracker.savedVariables.xAxisText, rushOfAgonyTracker.savedVariables.yAxisText)
            end,
            default = rushOfAgonyTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return rushOfAgonyTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                rushOfAgonyTracker.savedVariables.yAxisText = value
                setAnchorIcon(rushOfAgonyTracker.savedVariables.xAxisText, rushOfAgonyTracker.savedVariables.yAxisText)
            end,
            default = rushOfAgonyTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification",
            tooltip = "Displays a notification and plays a sound when the Rush of Agony cooldown is finished and the set is ready to proc again.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return rushOfAgonyTracker.savedVariables.notify
            end,
            setFunc = function(value)
                rushOfAgonyTracker.savedVariables.notify = value
            end,
            default = rushOfAgonyTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Rush of Agony Tracker", panelData)
    LAM:RegisterOptionControls("Rush of Agony Tracker", optionsData)
end

--an addon has loaded
local function onAddOnLoaded(event, name)

    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    rushOfAgonyTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("roatAddonVars", 1, "Settings", rushOfAgonyTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()
	
	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and rushOfAgonyTracker.savedVariables.trackRush then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and rushOfAgonyTracker.savedVariables.autoTrack and rushOfAgonyTracker.savedVariables.trackRush then
        --notify set not found
        zo_callLater(function() printMessage("Rush of Agony set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and rushOfAgonyTracker.savedVariables.autoTrack and rushOfAgonyTracker.savedVariables.trackRush then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Rush of Agony set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    roatrack:SetMovable(true)
    roatrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    roatrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_61)|soft-shadow-thick")
    roatrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    roatrackIcon:SetText(iconText)
    roatrackLabelMain:SetText("")
    --roatrackLabelMain:SetColor(255, 255, 0, 255)
    roatrackLabelCorner:SetText("")
    --roatrackLabelCorner:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(rushOfAgonyTracker.savedVariables.xAxisText, rushOfAgonyTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if rushOfAgonyTracker.savedVariables.trackRush and not rushOfAgonyTracker.savedVariables.autoTrack then
        registerAlerts()
        roatrack:SetHidden(false)
    elseif rushOfAgonyTracker.savedVariables.trackRush and rushOfAgonyTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        roatrack:SetHidden(false)
    elseif rushOfAgonyTracker.savedVariables.trackRush and rushOfAgonyTracker.savedVariables.autoTrack and not isEquiped then
        roatrack:SetHidden(true)
    elseif not rushOfAgonyTracker.savedVariables.trackRush then
        roatrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
