local appName = "aeriesCryTracker"
local aeriesAbilityID = 227605
local eaglesAbilityID = 226887
local timeRemaining = 0
local picPath = GetAbilityIcon(aeriesAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local buffRunning = false
local setId = 781
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackAeries"

aeriesCryTracker = {}

aeriesCryTracker.defaults = {
    trackAeries = true,
    autoTrack = true,
    trackEagles = true,
    notify = false,
	notifyStart = true,
    yAxisTextAeries = 760,
    xAxisTextAeries = 750,
    yAxisTextEagles = 660,
    xAxisTextEagles = 420
}

--check if libNotify is available
local function isLibAvailable()
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" and type(LibNotify.getSet) == "function" then
        return true
    else 
		return false
    end
end

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--clean player names
local function cleanName(str)
    return str:sub(1, -4)
end

--change aeries anchor to move around the screen at app start
local function setAnchorStartupIconAeries(x, y)  
    actrack:ClearAnchors()
    actrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change aeries anchor to move around the screen at app start
local function setAnchorStartupIconEagles(x, y)  
    emtrack:ClearAnchors()
    emtrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--is buff active
local function buffActive()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == aeriesAbilityID then
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function processBuff()
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
            actrackLabelMain:SetText(text)
        else
            actrackLabelMain:SetText("")
        end

        zo_callLater(function() processBuff() end, 1000)
    else
        buffRunning = false
        actrackLabelMain:SetText("")
        if isLibAvailable() and aeriesCryTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, aeriesAbilityID, "Aerie's Cry ended")
        end
    end
end

--report when new effect is gained
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")

    --player lost buff so naturally there is no target
    if changeType == 2 then
        emtrackIcon:SetText("")
        return
    end

    if nameTmp ~= cleanName(unitName) or changeType ~= 1 or abilityID ~= aeriesAbilityID then
        return
    end
	
	if isLibAvailable() and aeriesCryTracker.savedVariables.notifyStart then
		LibNotify.notifyForAddonPlease(appName, aeriesAbilityID, "Aerie's Cry Started")
    end
    processBuff()

end

local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    --target type 0 = npc's / innocents / world adds / world bosses / dungeon adds / dungeon bosses / pvp guards
    --target type 3 = players
    --target type 4 = training dummies

    if isError then
        return
    end

    if result ~= 2240 then
        return
    end

    --display name
    if aeriesCryTracker.savedVariables.trackEagles and aeriesCryTracker.savedVariables.trackAeries then
        if targetType == 3 then
            emtrackIcon:SetText(zo_strformat("<<1>>", cleanName(targetName)))
        else
            emtrackIcon:SetText(zo_strformat("<<1>>", targetName))
        end
    end

end

--change aeries anchor to move text around the screen
local function setAnchorIconAeries(x, y)  
    actrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then actrack:SetHidden(true) end end, 2000)
    actrack:ClearAnchors()
    actrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change eagles anchor to move text around the screen
local function setAnchorIconEagles(x, y)
    if not buffRunning then
        emtrackIcon:SetText("Target Name")
    end
    emtrack:SetHidden(false)
    zo_callLater(function () if not buffRunning then emtrackIcon:SetText("") end if isMenuOpen == true then emtrack:SetHidden(true) end end, 2000)
    emtrack:ClearAnchors()
    emtrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    actrack:SetHidden(true)
    emtrack:SetHidden(true)
end

--when UI closes
--replace this function
local function onMenuClosed()
	isMenuOpen = false
    if aeriesCryTracker.savedVariables.trackAeries and isEquiped and aeriesCryTracker.savedVariables.autoTrack then
        actrack:SetHidden(false)
    elseif aeriesCryTracker.savedVariables.trackAeries and not aeriesCryTracker.savedVariables.autoTrack then
        actrack:SetHidden(false)
    end

    if aeriesCryTracker.savedVariables.trackEagles and aeriesCryTracker.savedVariables.trackAeries and isEquiped and aeriesCryTracker.savedVariables.autoTrack then
        emtrack:SetHidden(false)
    elseif aeriesCryTracker.savedVariables.trackEagles and aeriesCryTracker.savedVariables.trackAeries and not aeriesCryTracker.savedVariables.autoTrack then
        emtrack:SetHidden(false)
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

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("aeriesProc", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("aeriesProc", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, aeriesAbilityID)

    EVENT_MANAGER:RegisterForEvent("eaglesProc", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("eaglesProc", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, eaglesAbilityID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("aeriesProc", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("eaglesProc", EVENT_COMBAT_EVENT)
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

    if aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.autoTrack then
        printMessage("Aerie's Cry set not found")
        unRegisterAlerts()
        actrack:SetHidden(true)
        emtrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.autoTrack then
        printMessage("Found Aerie's Cry set")
        registerAlerts()
        actrack:SetHidden(false)
        emtrack:SetHidden(false)
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and aeriesCryTracker.savedVariables.autoTrack and aeriesCryTracker.savedVariables.trackArch then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Aeries Cry Tracker",
        displayName = "Aeries Cry Tracker",
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
            tooltip = "Displays a timer while the Aerie's Call buff is active.",
            getFunc = function()
                return aeriesCryTracker.savedVariables.trackAeries
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.trackAeries = value
                aeriesCryTracker.savedVariables.trackEagles = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = aeriesCryTracker.defaults.trackAeries,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return aeriesCryTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.autoTrack = value
            end,
            default = aeriesCryTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return aeriesCryTracker.savedVariables.xAxisTextAeries
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.xAxisTextAeries = value
                setAnchorIconAeries(aeriesCryTracker.savedVariables.xAxisTextAeries, aeriesCryTracker.savedVariables.yAxisTextAeries)
            end,
            default = aeriesCryTracker.defaults.xAxisTextAeries,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return aeriesCryTracker.savedVariables.yAxisTextAeries
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.yAxisTextAeries = value
                setAnchorIconAeries(aeriesCryTracker.savedVariables.xAxisTextAeries, aeriesCryTracker.savedVariables.yAxisTextAeries)
            end,
            default = aeriesCryTracker.defaults.yAxisTextAeries,
        },
        {
            type = "checkbox",
            name = "Track Eagle's Mark",
            tooltip = "Displays text with the name of the target that has Eagle's Mark applied to them.\nIn order to track the Eagle's Mark tracking for Aerie's Call must be enabled.",
            getFunc = function()
                return aeriesCryTracker.savedVariables.trackEagles
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.trackEagles = value
            end,
            default = aeriesCryTracker.defaults.trackEagles,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return aeriesCryTracker.savedVariables.xAxisTextEagles
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.xAxisTextEagles = value
                setAnchorIconEagles(aeriesCryTracker.savedVariables.xAxisTextEagles, aeriesCryTracker.savedVariables.yAxisTextEagles)
            end,
            default = aeriesCryTracker.defaults.xAxisTextEagles,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return aeriesCryTracker.savedVariables.yAxisTextEagles
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.yAxisTextEagles = value
                setAnchorIconEagles(aeriesCryTracker.savedVariables.xAxisTextEagles, aeriesCryTracker.savedVariables.yAxisTextEagles)
            end,
            default = aeriesCryTracker.defaults.yAxisTextEagles,
        },
		{
            type = "checkbox",
            name = "Notification Start",
            tooltip = "Displays a notification and plays a sound when the Aerie's Cry buff starts.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return aeriesCryTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.notifyStart = value
            end,
            default = aeriesCryTracker.defaults.notifyStart,
        },
        {
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the Aerie's Cry buff finishes.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return aeriesCryTracker.savedVariables.notify
            end,
            setFunc = function(value)
                aeriesCryTracker.savedVariables.notify = value
            end,
            default = aeriesCryTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Aeries Cry Tracker", panelData)
    LAM:RegisterOptionControls("Aeries Cry Tracker", optionsData)
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
    aeriesCryTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("aeriesAddonVars", 1, "Settings", aeriesCryTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()
        
    --register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and aeriesCryTracker.savedVariables.trackAeries then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and aeriesCryTracker.savedVariables.autoTrack and aeriesCryTracker.savedVariables.trackAeries then
        --notify set not found
        zo_callLater(function() printMessage("Aerie's Cry set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and aeriesCryTracker.savedVariables.autoTrack and aeriesCryTracker.savedVariables.trackAeries then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Aerie's Cry set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    actrack:SetMovable(true)
    actrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    actrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    actrackIcon:SetText(iconText)
    actrackLabelMain:SetText("")
    actrackLabelMain:SetColor(255, 255, 0, 255)

    setAnchorStartupIconAeries(aeriesCryTracker.savedVariables.xAxisTextAeries, aeriesCryTracker.savedVariables.yAxisTextAeries)

    emtrack:SetMovable(true)
    emtrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    emtrackIcon:SetText("")
    emtrackIcon:SetColor(0, 255, 0, 255)

    setAnchorStartupIconEagles(aeriesCryTracker.savedVariables.xAxisTextEagles, aeriesCryTracker.savedVariables.yAxisTextEagles)

    --register for combat alerts if tracking is enabled
    if aeriesCryTracker.savedVariables.trackAeries and not aeriesCryTracker.savedVariables.autoTrack then
        registerAlerts()
        actrack:SetHidden(false)
    elseif aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        actrack:SetHidden(false)
    elseif aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.autoTrack and not isEquiped then
        actrack:SetHidden(true)
    elseif not aeriesCryTracker.savedVariables.trackAeries then
        actrack:SetHidden(true)
    end

    if aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.trackEagles and not aeriesCryTracker.savedVariables.autoTrack then
        emtrack:SetHidden(false)
    elseif aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.trackEagles and aeriesCryTracker.savedVariables.autoTrack and isEquiped then
        emtrack:SetHidden(false)
    elseif aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.trackEagles and aeriesCryTracker.savedVariables.autoTrack and not isEquiped then
        emtrack:SetHidden(true)
    elseif not aeriesCryTracker.savedVariables.trackAeries and aeriesCryTracker.savedVariables.trackEagles then
        emtrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
