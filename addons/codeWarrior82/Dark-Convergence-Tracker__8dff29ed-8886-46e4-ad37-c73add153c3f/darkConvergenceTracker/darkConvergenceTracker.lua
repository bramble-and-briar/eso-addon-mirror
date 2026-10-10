local appName = "darkConvergenceTracker"
local darkAbilityID = 159388
local timeRemaining = 0
local picPath = GetAbilityIcon(darkAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local setId = 616
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackDark"

darkConvergenceTracker = {}

darkConvergenceTracker.defaults = {
    trackDark = true,
    autoTrack = true,
	notify = true,
    yAxisText = 930,
    xAxisText = 1420
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
    dctrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if darkConvergenceTracker.savedVariables.trackDark and isEquiped and darkConvergenceTracker.savedVariables.autoTrack then
        dctrack:SetHidden(false)
    elseif darkConvergenceTracker.savedVariables.trackDark and not darkConvergenceTracker.savedVariables.autoTrack then
        dctrack:SetHidden(false)
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
    dctrack:ClearAnchors()
    dctrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    dctrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then dctrack:SetHidden(true) end end, 2000)
    dctrack:ClearAnchors()
    dctrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
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
        EVENT_MANAGER:RegisterForUpdate("darkUpdate", 1000, processCooldown)
        dctrackLabelMain:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("darkUpdate")
        dctrackLabelMain:SetText("")
        timeRemaining = 24
		if isLibAvailable() and darkConvergenceTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, darkAbilityID, "Dark Convergence Ready")
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

    if nameTmp ~= cleanName(sourceName) or abilityId ~= darkAbilityID then
        return
    end

    timeRemaining = 24
    processCooldown()
end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("darkProc", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("darkProc", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, darkAbilityID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("darkProc", EVENT_COMBAT_EVENT)
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

    if darkConvergenceTracker.savedVariables.trackDark and darkConvergenceTracker.savedVariables.autoTrack then
        printMessage("Dark Convergence set not found")
        unRegisterAlerts()
        dctrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if darkConvergenceTracker.savedVariables.trackDark and darkConvergenceTracker.savedVariables.autoTrack then
        printMessage("Found Dark Convergence set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and darkConvergenceTracker.savedVariables.autoTrack and darkConvergenceTracker.savedVariables.trackDark then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Dark Convergence Tracker",
        displayName = "Dark Convergence Tracker",
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
            tooltip = "Displays a timer that tracks the Dark Convergence cooldown.",
            getFunc = function()
                return darkConvergenceTracker.savedVariables.trackDark
            end,
            setFunc = function(value)
                darkConvergenceTracker.savedVariables.trackDark = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = darkConvergenceTracker.defaults.trackDark,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return darkConvergenceTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                darkConvergenceTracker.savedVariables.autoTrack = value
            end,
            default = darkConvergenceTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return darkConvergenceTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                darkConvergenceTracker.savedVariables.xAxisText = value
                setAnchorIcon(darkConvergenceTracker.savedVariables.xAxisText, darkConvergenceTracker.savedVariables.yAxisText)
            end,
            default = darkConvergenceTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return darkConvergenceTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                darkConvergenceTracker.savedVariables.yAxisText = value
                setAnchorIcon(darkConvergenceTracker.savedVariables.xAxisText, darkConvergenceTracker.savedVariables.yAxisText)
            end,
            default = darkConvergenceTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification",
            tooltip = "Displays a notification and plays a sound when the Dark Convergence cooldown is finished and the set is ready to proc again.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return darkConvergenceTracker.savedVariables.notify
            end,
            setFunc = function(value)
                darkConvergenceTracker.savedVariables.notify = value
            end,
            default = darkConvergenceTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Dark Convergence Tracker", panelData)
    LAM:RegisterOptionControls("Dark Convergence Tracker", optionsData)
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
    darkConvergenceTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("dctAddonVars", 1, "Settings", darkConvergenceTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

    --register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()


	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and darkConvergenceTracker.savedVariables.trackDark then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and darkConvergenceTracker.savedVariables.autoTrack and darkConvergenceTracker.savedVariables.trackDark then
        --notify set not found
        zo_callLater(function() printMessage("Dark Convergence set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and darkConvergenceTracker.savedVariables.autoTrack and darkConvergenceTracker.savedVariables.trackDark then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Dark Convergence set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    dctrack:SetMovable(true)
    dctrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    dctrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_61)|soft-shadow-thick")
    dctrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    dctrackIcon:SetText(iconText)
    dctrackLabelMain:SetText("")
    dctrackLabelMain:SetColor(255, 0, 0, 255)
    dctrackLabelCorner:SetText("")
    --dctrackLabelCorner:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(darkConvergenceTracker.savedVariables.xAxisText, darkConvergenceTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if darkConvergenceTracker.savedVariables.trackDark and not darkConvergenceTracker.savedVariables.autoTrack then
        registerAlerts()
        dctrack:SetHidden(false)
    elseif darkConvergenceTracker.savedVariables.trackDark and darkConvergenceTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        dctrack:SetHidden(false)
    elseif darkConvergenceTracker.savedVariables.trackDark and darkConvergenceTracker.savedVariables.autoTrack and not isEquiped then
        dctrack:SetHidden(true)
    elseif not darkConvergenceTracker.savedVariables.trackDark then
        dctrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
