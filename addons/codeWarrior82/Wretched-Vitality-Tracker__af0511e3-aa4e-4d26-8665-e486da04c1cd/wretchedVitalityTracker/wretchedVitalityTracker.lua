local appName = "wretchedVitalityTracker"
local majorAbilityID = 163102
local minorAbilityID = 163108
local timeRemainingMajor = 15
local timeRemainingMinor = 15
local picPathMajor = GetAbilityIcon(majorAbilityID)
local picPathMinor = GetAbilityIcon(minorAbilityID)
local iconTextMajor = zo_iconTextFormat(picPathMajor, 80, 80, " ")
local iconTextMinor = zo_iconTextFormat(picPathMinor, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local trackingWretchedMajor = false
local trackingWretchedMinor = false
local setId = 610 
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackWretch"

wretchedVitalityTracker = {}

wretchedVitalityTracker.defaults = {
    trackWretch = true,
    autoTrack = true,
	notify = true,
	notifyStart = false,
    yAxisText = 720,
    xAxisText = 1060
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
    wvtrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if wretchedVitalityTracker.savedVariables.trackWretch and isEquiped and wretchedVitalityTracker.savedVariables.autoTrack then
        wvtrack:SetHidden(false)
    elseif wretchedVitalityTracker.savedVariables.trackWretch and not wretchedVitalityTracker.savedVariables.autoTrack then
        wvtrack:SetHidden(false)
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
    wvtrack:ClearAnchors()
    wvtrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    wvtrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then wvtrack:SetHidden(true) end end, 2000)
    wvtrack:ClearAnchors()
    wvtrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--is buff active
local function buffActiveMajor()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        --local buffName, startTime, endTime, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, 
        --statusEffectType, abilityId, canClickOff, castByPlayer = GetBuffInfo("player", i)

        if abilityId == majorAbilityID then
            timeRemainingMajor = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function processBuffMajor()

    if buffActiveMajor() then
        trackingWretchedMajor = true

        local text = ""

        if timeRemainingMajor >= 10 then
            text = string.format("%d", timeRemainingMajor)
        else
            text = string.format(" %d", timeRemainingMajor)
        end

        wvtrackLabelMajor:SetText(text)

        zo_callLater(function() processBuffMajor() end, 1000)
    else
        trackingWretchedMajor = false
        wvtrackLabelMajor:SetText("")
		if isLibAvailable() and wretchedVitalityTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, majorAbilityID, "Wretched Major ended")
        end
    end
end

--is buff active
local function buffActiveMinor()

    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        --local buffName, startTime, endTime, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, 
        --statusEffectType, abilityId, canClickOff, castByPlayer = GetBuffInfo("player", i)

        if abilityId == minorAbilityID then
            timeRemainingMinor = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function processBuffMinor()
    
    if buffActiveMinor() then

        trackingWretchedMinor = true

        local text = ""

        if timeRemainingMinor >= 10 then
            text = string.format("%d", timeRemainingMinor)
        else
            text = string.format(" %d", timeRemainingMinor)
        end

        wvtrackLabelMinor:SetText(text)

        zo_callLater(function() processBuffMinor() end, 1000)
    else
        trackingWretchedMinor = false
        wvtrackLabelMinor:SetText("")
		if isLibAvailable() and wretchedVitalityTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, minorAbilityID, "Wretched Minor ended")
        end
    end
end

--report when new effect is gained
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(unitName) then
        return
    end

    if abilityID ~= majorAbilityID and abilityID ~= minorAbilityID then
        return
    end

    if changeType == 2 then
        if abilityID == majorAbilityID then
            wvtrackLabelMajor:SetText("")
            trackingWretchedMajor = false
            return
        elseif abilityID == minorAbilityID then
            wvtrackLabelMinor:SetText("")
            trackingWretchedMinor = false
            return
        end
    end


    if abilityID == majorAbilityID and not trackingWretchedMajor then
	if isLibAvailable() and wretchedVitalityTracker.savedVariables.notifyStart then
		LibNotify.notifyForAddonPlease(appName, majorAbilityID, "Wretched Major Started")
	end
        processBuffMajor()
    elseif abilityID == minorAbilityID and not trackingWretchedMinor then
	if isLibAvailable() and wretchedVitalityTracker.savedVariables.notifyStart then
		LibNotify.notifyForAddonPlease(appName, minorAbilityID, "Wretched Minor Started")
	end
        processBuffMinor()
    end

end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("wvProcMajor", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("wvProcMajor", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, majorAbilityID)
    EVENT_MANAGER:RegisterForEvent("wvProcMinor", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("wvProcMinor", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, minorAbilityID)
end

--unregister for notifications about proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("wvProcMajor", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("wvProcMinor", EVENT_EFFECT_CHANGED)
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

    if wretchedVitalityTracker.savedVariables.trackWretch and wretchedVitalityTracker.savedVariables.autoTrack then
        printMessage("Wretched Vitality set not found")
        unRegisterAlerts()
        wvtrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if wretchedVitalityTracker.savedVariables.trackWretch and wretchedVitalityTracker.savedVariables.autoTrack then
        printMessage("Found Wretched Vitality set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and wretchedVitalityTracker.savedVariables.autoTrack and wretchedVitalityTracker.savedVariables.trackWretch then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Wretched Vitality Tracker",
        displayName = "Wretched Vitality Tracker",
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
            tooltip = "Displays timers while the Wretched Vitality buffs are active.",
            getFunc = function()
                return wretchedVitalityTracker.savedVariables.trackWretch
            end,
            setFunc = function(value)
                wretchedVitalityTracker.savedVariables.trackWretch = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = wretchedVitalityTracker.defaults.trackWretch,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return wretchedVitalityTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                wretchedVitalityTracker.savedVariables.autoTrack = value
            end,
            default = wretchedVitalityTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return wretchedVitalityTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                wretchedVitalityTracker.savedVariables.xAxisText = value
                setAnchorIcon(wretchedVitalityTracker.savedVariables.xAxisText, wretchedVitalityTracker.savedVariables.yAxisText)
            end,
            default = wretchedVitalityTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return wretchedVitalityTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                wretchedVitalityTracker.savedVariables.yAxisText = value
                setAnchorIcon(wretchedVitalityTracker.savedVariables.xAxisText, wretchedVitalityTracker.savedVariables.yAxisText)
            end,
            default = wretchedVitalityTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification Start",
            tooltip = "Displays a notification and plays a sound when the Wretched Vitality buff starts.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return wretchedVitalityTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                wretchedVitalityTracker.savedVariables.notifyStart = value
            end,
            default = wretchedVitalityTracker.defaults.notifyStart,
        },
		{
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the Wretched Vitality buff finishes.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return wretchedVitalityTracker.savedVariables.notify
            end,
            setFunc = function(value)
                wretchedVitalityTracker.savedVariables.notify = value
            end,
            default = wretchedVitalityTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Wretched Vitality Tracker", panelData)
    LAM:RegisterOptionControls("Wretched Vitality Tracker", optionsData)
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
    wretchedVitalityTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("wvAddonVars", 1, "Settings", wretchedVitalityTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and wretchedVitalityTracker.savedVariables.trackWretch then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and wretchedVitalityTracker.savedVariables.autoTrack and wretchedVitalityTracker.savedVariables.trackWretch then
        --notify set not found
        zo_callLater(function() printMessage("Wretched Vitality set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and wretchedVitalityTracker.savedVariables.autoTrack and wretchedVitalityTracker.savedVariables.trackWretch then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Wretched Vitality set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    wvtrack:SetMovable(true)

    wvtrackIconMajor:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    wvtrackLabelMajor:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_61)|soft-shadow-thick")
    wvtrackIconMajor:SetText(iconTextMajor)
    wvtrackLabelMajor:SetText("")

    wvtrackIconMinor:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    wvtrackLabelMinor:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_61)|soft-shadow-thick")
    wvtrackIconMinor:SetText(iconTextMinor)
    wvtrackLabelMinor:SetText("")

    setAnchorStartupIcon(wretchedVitalityTracker.savedVariables.xAxisText, wretchedVitalityTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if wretchedVitalityTracker.savedVariables.trackWretch and not wretchedVitalityTracker.savedVariables.autoTrack then
        registerAlerts()
        wvtrack:SetHidden(false)
    elseif wretchedVitalityTracker.savedVariables.trackWretch and wretchedVitalityTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        wvtrack:SetHidden(false)
    elseif wretchedVitalityTracker.savedVariables.trackWretch and wretchedVitalityTracker.savedVariables.autoTrack and not isEquiped then
        wvtrack:SetHidden(true)
    elseif not wretchedVitalityTracker.savedVariables.trackWretch then
        wvtrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
