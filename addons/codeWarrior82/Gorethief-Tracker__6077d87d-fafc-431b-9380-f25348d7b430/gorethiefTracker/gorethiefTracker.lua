local appName = "gorethiefTracker"
local gorethiefAbilityID = 260047
local timeRemaining = 0
local picPath = GetAbilityIcon(gorethiefAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local buffRunning = false
local readyToNotify = true
local setId = 855 
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackGore"

gorethiefTracker = {}

gorethiefTracker.defaults = {
    trackGore = true,
    autoTrack = true,
	notify = true,
    yAxisText = 930,
    xAxisText = 1400
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
    gttrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if gorethiefTracker.savedVariables.trackGore and isEquiped and gorethiefTracker.savedVariables.autoTrack then
        gttrack:SetHidden(false)
    elseif gorethiefTracker.savedVariables.trackGore and not gorethiefTracker.savedVariables.autoTrack then
        gttrack:SetHidden(false)
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
    gttrack:ClearAnchors()
    gttrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    gttrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then gttrack:SetHidden(true) end end, 2000)
    gttrack:ClearAnchors()
    gttrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--is buff active
local function buffActive()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == gorethiefAbilityID then
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end


local function trackStacks()
    if buffActive() then

        buffRunning = true

        local time = timeRemaining

        local text = ""

        if time >= 10 then
            text = string.format(" %d", time)
        else
            text = string.format("  %d", time)
        end

        if time > 0 then
            gttrackLabelCorner:SetText(text)
        else
            gttrackLabelCorner:SetText("")
        end

        zo_callLater(function() trackStacks() end, 1000)
    else
        buffRunning = false
        gttrackLabelCorner:SetText("")
    end

end

--report when new effect is gained
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(unitName) or abilityID ~= gorethiefAbilityID then
        return
    end

    if changeType == 2 then
        gttrackLabelMain:SetText("")
        gttrackLabelCorner:SetText("")
		--reset counter
		readyToNotify = true
        return
    end

    local text = ""

	if stackCount == 9 and readyToNotify then
		readyToNotify = false
		if isLibAvailable() and gorethiefTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, gorethiefAbilityID, "Gorethief Ready")
        end
	end

	if stackCount >= 9 then
		gttrackLabelMain:SetColor(0, 255, 0, 255)
	else
		gttrackLabelMain:SetColor(255, 255, 255, 255)
	end
	
    if stackCount == 10 then
        text = string.format(" %d", stackCount)
    else
        text = string.format("  %d", stackCount)
    end
    gttrackLabelMain:SetText(text)

    if not buffRunning then
        trackStacks()
    end
    
end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("goreProc", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("goreProc", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, gorethiefAbilityID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("goreProc", EVENT_EFFECT_CHANGED)
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

    if gorethiefTracker.savedVariables.trackGore and gorethiefTracker.savedVariables.autoTrack then
        printMessage("Gorethief set not found")
        unRegisterAlerts()
        gttrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if gorethiefTracker.savedVariables.trackGore and gorethiefTracker.savedVariables.autoTrack then
        printMessage("Found Gorethief set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and gorethiefTracker.savedVariables.autoTrack and gorethiefTracker.savedVariables.trackGore then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Gorethief Tracker",
        displayName = "Gorethief Tracker",
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
            name = "Track buff and cooldown",
            tooltip = "Displays the current stack amount of Gorethief while Gorethief is active.",
            getFunc = function()
                return gorethiefTracker.savedVariables.trackGore
            end,
            setFunc = function(value)
                gorethiefTracker.savedVariables.trackGore = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = gorethiefTracker.defaults.trackGore,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return gorethiefTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                gorethiefTracker.savedVariables.autoTrack = value
            end,
            default = gorethiefTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return gorethiefTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                gorethiefTracker.savedVariables.xAxisText = value
                setAnchorIcon(gorethiefTracker.savedVariables.xAxisText, gorethiefTracker.savedVariables.yAxisText)
            end,
            default = gorethiefTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return gorethiefTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                gorethiefTracker.savedVariables.yAxisText = value
                setAnchorIcon(gorethiefTracker.savedVariables.xAxisText, gorethiefTracker.savedVariables.yAxisText)
            end,
            default = gorethiefTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification",
            tooltip = "Displays a notification and plays a sound when the Gorethief proc is ready to use.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return gorethiefTracker.savedVariables.notify
            end,
            setFunc = function(value)
                gorethiefTracker.savedVariables.notify = value
            end,
            default = gorethiefTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Gorethief Tracker", panelData)
    LAM:RegisterOptionControls("Gorethief Tracker", optionsData)
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
    gorethiefTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("gttAddonVars", 1, "Settings", gorethiefTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()
	
	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and gorethiefTracker.savedVariables.trackGore then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and gorethiefTracker.savedVariables.autoTrack and gorethiefTracker.savedVariables.trackGore then
        --notify set not found
        zo_callLater(function() printMessage("Gorethief set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and gorethiefTracker.savedVariables.autoTrack and gorethiefTracker.savedVariables.trackGore then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Gorethief set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    gttrack:SetMovable(true)
    gttrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    gttrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_61)|soft-shadow-thick")
    gttrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_27)|soft-shadow-thick")
    gttrackIcon:SetText(iconText)
    gttrackLabelMain:SetText("")
    gttrackLabelCorner:SetText("")
    --gttrackLabelMain:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(gorethiefTracker.savedVariables.xAxisText, gorethiefTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if gorethiefTracker.savedVariables.trackGore and not gorethiefTracker.savedVariables.autoTrack then
        registerAlerts()
        gttrack:SetHidden(false)
    elseif gorethiefTracker.savedVariables.trackGore and gorethiefTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        gttrack:SetHidden(false)
    elseif gorethiefTracker.savedVariables.trackGore and gorethiefTracker.savedVariables.autoTrack and not isEquiped then
        gttrack:SetHidden(true)
    elseif not gorethiefTracker.savedVariables.trackGore then
        gttrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
