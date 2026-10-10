local appName = "FrenziedMomentumTracker"
local frenziedAbilityID = 147700
local frenziedTrueAbilityID = 147701
local timeRemaining = 0
local stacks = 0
local picPath = GetAbilityIcon(frenziedTrueAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local processingBuff = false
local readyToNotify = true
local setId1 = 559 --normal
local setId2 = 565 --perfected
local setCount = 2 --5,2,3,1
local isEquiped = false
local callBackName = "callbackFrenz"

FrenziedMomentumTracker = {}

FrenziedMomentumTracker.defaults = {
    trackFren = true,
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
    fmtrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if FrenziedMomentumTracker.savedVariables.trackFren and isEquiped and FrenziedMomentumTracker.savedVariables.autoTrack then
        fmtrack:SetHidden(false)
    elseif FrenziedMomentumTracker.savedVariables.trackFren and not FrenziedMomentumTracker.savedVariables.autoTrack then
        fmtrack:SetHidden(false)
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
    fmtrack:ClearAnchors()
    fmtrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    fmtrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then fmtrack:SetHidden(true) end end, 2000)
    fmtrack:ClearAnchors()
    fmtrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--is buff active
local function buffActive()

    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        --local buffName, startTime, endTime, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, 
        --statusEffectType, abilityId, canClickOff, castByPlayer = GetBuffInfo("player", i)

        if abilityId == frenziedTrueAbilityID then
            stacks = stackCount
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function processBuff()
    
    if buffActive() then

        processingBuff = true

        local text = ""
        local time = ""

		if stacks == 5 and readyToNotify then
			readyToNotify = false
			if isLibAvailable() and FrenziedMomentumTracker.savedVariables.notify then
				LibNotify.notifyForAddonPlease(appName, frenziedTrueAbilityID, "Frenzied Momentum Ready")
			end
		end
		
        if stacks >= 5 then
            fmtrackLabelMain:SetColor(0, 255, 0, 255)
        else
            fmtrackLabelMain:SetColor(255, 255, 255, 255)
        end

        if stacks >= 10 then
            text = string.format(" %d", stacks)
        else
            text = string.format("  %d", stacks)
        end

        if timeRemaining >= 10 then
            time = string.format(" %d", timeRemaining)
        else
            time = string.format("  %d", timeRemaining)
        end

        fmtrackLabelMain:SetText(text)
        fmtrackLabelCorner:SetText(time)

        zo_callLater(function() processBuff() end, 1000)
    else
        processingBuff = false
        fmtrackLabelMain:SetText("")
        fmtrackLabelCorner:SetText("")
		readyToNotify = true
    end
end

local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(sourceName) or abilityId ~= frenziedAbilityID then
        return
    end

    if not processingBuff then
        processBuff()
    end
end

--register for notifications about proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("frenProc", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("frenProc", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, frenziedAbilityID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("frenProc", EVENT_COMBAT_EVENT)
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

    if FrenziedMomentumTracker.savedVariables.trackFren and FrenziedMomentumTracker.savedVariables.autoTrack then
        printMessage("Frenzied Momentum set not found")
        unRegisterAlerts()
        fmtrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if FrenziedMomentumTracker.savedVariables.trackFren and FrenziedMomentumTracker.savedVariables.autoTrack then
        printMessage("Found Frenzied Momentum set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)
    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId1, setCount)  or isSetEquiped(setId2, setCount) and FrenziedMomentumTracker.savedVariables.autoTrack and FrenziedMomentumTracker.savedVariables.trackFren then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Frenzied Momentum Tracker",
        displayName = "Frenzied Momentum Tracker",
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
                return FrenziedMomentumTracker.savedVariables.trackFren
            end,
            setFunc = function(value)
                FrenziedMomentumTracker.savedVariables.trackFren = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = FrenziedMomentumTracker.defaults.trackFren,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return FrenziedMomentumTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                FrenziedMomentumTracker.savedVariables.autoTrack = value
            end,
            default = FrenziedMomentumTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return FrenziedMomentumTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                FrenziedMomentumTracker.savedVariables.xAxisText = value
                setAnchorIcon(FrenziedMomentumTracker.savedVariables.xAxisText, FrenziedMomentumTracker.savedVariables.yAxisText)
            end,
            default = FrenziedMomentumTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return FrenziedMomentumTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                FrenziedMomentumTracker.savedVariables.yAxisText = value
                setAnchorIcon(FrenziedMomentumTracker.savedVariables.xAxisText, FrenziedMomentumTracker.savedVariables.yAxisText)
            end,
            default = FrenziedMomentumTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification",
            tooltip = "Displays a notification and plays a sound when the Frenzied Momentum proc is ready to use.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return FrenziedMomentumTracker.savedVariables.notify
            end,
            setFunc = function(value)
                FrenziedMomentumTracker.savedVariables.notify = value
            end,
            default = FrenziedMomentumTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Frenzied Momentum Tracker", panelData)
    LAM:RegisterOptionControls("Frenzied Momentum Tracker", optionsData)
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
    FrenziedMomentumTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("fmtAddonVars", 1, "Settings", FrenziedMomentumTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()
	
	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and FrenziedMomentumTracker.savedVariables.trackFren then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId1, setCount) and not isSetEquiped(setId2, setCount)  and FrenziedMomentumTracker.savedVariables.autoTrack and FrenziedMomentumTracker.savedVariables.trackFren then
        --notify set not found
        zo_callLater(function() printMessage("Frenzied Momentum set not found") end, 600)
    elseif isSetEquiped(setId1, setCount) or isSetEquiped(setId2, setCount)  and FrenziedMomentumTracker.savedVariables.autoTrack and FrenziedMomentumTracker.savedVariables.trackFren then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Frenzied Momentum set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    fmtrack:SetMovable(true)
    fmtrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    fmtrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_61)|soft-shadow-thick")
    fmtrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_27)|soft-shadow-thick")
    fmtrackIcon:SetText(iconText)
    fmtrackLabelMain:SetText("")
    fmtrackLabelCorner:SetText("")
    --fmtrackLabelMain:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(FrenziedMomentumTracker.savedVariables.xAxisText, FrenziedMomentumTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if FrenziedMomentumTracker.savedVariables.trackFren then
        registerAlerts()
        fmtrack:SetHidden(false)
    else
        fmtrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
