local appName = "turningTideTracker"
local flowingWaterID = 167350
--167061 id for major vuln from turning tide
local picPath = GetAbilityIcon(flowingWaterID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local procTime = 15
local vulnTime = 10
local isMenuOpen = false
local needToNotify = true
local setId = 622
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackTurn"

turningTideTracker = {}

turningTideTracker.defaults = {
    trackTurn = true,
    autoTrack = true,
    trackVuln = true,
	notifyReady = true,
	notifyVuln = true,
    yAxisText = 930,
    xAxisText = 1300
}

turningTideTracker.majorEffects = {
-- Major Vulnerability
	[106754] = true,
	[106755] = true,
	[106758] = true,
	[106760] = true,
	[106762] = true,
	[122177] = true,
	[122397] = true,
	[122389] = true,
    [132831] = true,
    [148976] = true,
	[163060] = true,
	[167061] = true,
	[176815] = true,
	[195242] = true,
	[192836] = true,
	[226400] = true,
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

--is debuff major
local function isVulnActive(abilityID)
	return turningTideTracker.majorEffects[abilityID]
end

local function processFlowingWater()

    local text 
    if procTime > 9 then
        text = string.format("%d", procTime)
    else
        text = string.format("  %d", procTime)
    end

    if procTime > 5 then
        ttAddonTextLabelTime:SetColor(0, 255, 0, 255)
    else
        ttAddonTextLabelTime:SetColor(255, 0, 0, 255)
    end

    if procTime > 0 then   
        EVENT_MANAGER:RegisterForUpdate("turningFlowUpdate", 1000, processFlowingWater)
        ttAddonTextLabelTime:SetText(text)
        procTime = procTime - 1
    else
        EVENT_MANAGER:UnregisterForUpdate("turningFlowUpdate")
        ttAddonTextLabelTime:SetText("")
        procTime = 15
		needToNotify = true
    end

end

local function processVuln()
   
    local text 
    local textTime 
    if vulnTime > 9 then
        text = string.format("%d", vulnTime)
    else
        text = string.format(" %d", vulnTime)
    end

    if vulnTime > 0 then   
        EVENT_MANAGER:RegisterForUpdate("turnUpdateVuln", 1000, processVuln)
        ttAddonTextLabelVuln:SetText(text)
        vulnTime = vulnTime - 1
    else
        EVENT_MANAGER:UnregisterForUpdate("turnUpdateVuln")
        ttAddonTextLabelVuln:SetText("")
        vulnTime = 10
		if isLibAvailable() and turningTideTracker.savedVariables.notifyVuln then
            LibNotify.notifyForAddonPlease(appName, flowingWaterID, "Major Vuln ended")
        end
    end

end

--handle combat alert major vulnerability
local function combatReportVuln(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    local nameTmp = GetUnitName("player")

    if(isVulnActive(abilityId) and nameTmp == cleanName(sourceName)) then
        if hitValue == 1 and turningTideTracker.savedVariables.trackVuln then
            vulnTime = 10
            processVuln()
        end
    end

end

--handle combat alert
local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    
    --target type 0 = npc's / innocents / world adds / world bosses / dungeon adds / dungeon bosses / pvp guards
    --target type 3 = players
    --target type 4 = training dummies
    if isError then
        return
    end

    local nameTmp = GetUnitName("player")

    if(abilityId == flowingWaterID) then
		if isLibAvailable() and turningTideTracker.savedVariables.notifyReady and needToNotify then
			needToNotify = false
            LibNotify.notifyForAddonPlease(appName, flowingWaterID, "Flowing Water Ready")
        end	
        processFlowingWater()
    end
end

--register for notifications about turning tide vulnerability proc
local function registerAlertsVuln()
    EVENT_MANAGER:RegisterForEvent("turnVulnDebuff", EVENT_COMBAT_EVENT, combatReportVuln)
    EVENT_MANAGER:AddFilterForEvent("turnVulnDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 167061)--major vulnerability abilityId, turning tide
end

--unregister for notifications about archdruid vulnerability proc
local function unRegisterAlertsVuln()
    EVENT_MANAGER:UnregisterForEvent("turnVulnDebuff", EVENT_COMBAT_EVENT)
end

--register for notifications about turning tide proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("turnDebuff", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("turnDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
    EVENT_MANAGER:AddFilterForEvent("turnDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, flowingWaterID)
end

--unregister for notifications about turning tide proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("turnDebuff", EVENT_COMBAT_EVENT)
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    ttAddonText:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if turningTideTracker.savedVariables.trackTurn and isEquiped and turningTideTracker.savedVariables.autoTrack then
        ttAddonText:SetHidden(false)
    elseif turningTideTracker.savedVariables.trackTurn and not turningTideTracker.savedVariables.autoTrack then
        ttAddonText:SetHidden(false)
    end
end

--change archdruid anchor to move around the screen at app start
local function setAnchorStartupIcon(x, y)  
    ttAddonText:ClearAnchors()
    ttAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    ttAddonText:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then ttAddonText:SetHidden(true) end end, 2000)
    ttAddonText:ClearAnchors()
    ttAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
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

    if turningTideTracker.savedVariables.trackTurn and turningTideTracker.savedVariables.autoTrack then
        printMessage("Turning Tide set not found")
        unRegisterAlerts()
        unRegisterAlertsVuln()
        ttAddonText:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if turningTideTracker.savedVariables.trackTurn and turningTideTracker.savedVariables.autoTrack then
        printMessage("Found Turning Tide set")
        registerAlerts()
    end
    if turningTideTracker.savedVariables.trackVuln then
        registerAlertsVuln()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and turningTideTracker.savedVariables.autoTrack and turningTideTracker.savedVariables.trackTurn then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Turning Tide Tracker",
        displayName = "Turning Tide Tracker",
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
            name = "Track Buff and Cooldown",
            tooltip = "Displays a timer while the Flowing Water buff is active.\nDisabling this option will also disable tracking the Major Vulnerability debuff.",
            getFunc = function()
                return turningTideTracker.savedVariables.trackTurn
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.trackTurn = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = turningTideTracker.defaults.trackTurn,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return turningTideTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.autoTrack = value
            end,
            default = turningTideTracker.defaults.autoTrack,
        },
        {
            type = "checkbox",
            name = "Track Debuff",
            tooltip = "Displays a timer that tracks the Turning Tide Major Vulnerability debuff.\nTo track the Major Vulnerability debuff tracking for the buff and cooldown needs to be enabled.",
            getFunc = function()
                return turningTideTracker.savedVariables.trackVuln
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.trackVuln = value
				if not value then
                    unRegisterAlertsVuln()
                else
                    registerAlertsVuln()
                end
            end,
            default = turningTideTracker.defaults.trackVuln,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return turningTideTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.xAxisText = value
                setAnchorIcon(turningTideTracker.savedVariables.xAxisText, turningTideTracker.savedVariables.yAxisText)
            end,
            default = turningTideTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return turningTideTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.yAxisText = value
                setAnchorIcon(turningTideTracker.savedVariables.xAxisText, turningTideTracker.savedVariables.yAxisText)
            end,
            default = turningTideTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification Ready",
            tooltip = "Displays a notification and plays a sound when the Flowing Water buff is ready for you to bash.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return turningTideTracker.savedVariables.notifyReady
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.notifyReady = value
            end,
            default = turningTideTracker.defaults.notifyReady,
        },
		{
            type = "checkbox",
            name = "Notification Vuln",
            tooltip = "Displays a notification and plays a sound when the Major Vulnerability debuff finishes.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return turningTideTracker.savedVariables.notifyVuln
            end,
            setFunc = function(value)
                turningTideTracker.savedVariables.notifyVuln = value
            end,
            default = turningTideTracker.defaults.notifyVuln,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Turning Tide Tracker", panelData)
    LAM:RegisterOptionControls("Turning Tide Tracker", optionsData)
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

--an addon has loaded
local function onAddOnLoaded(event, name)

    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    turningTideTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("turnAddonVars", 1, "Settings", turningTideTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and turningTideTracker.savedVariables.trackTurn then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and turningTideTracker.savedVariables.autoTrack and turningTideTracker.savedVariables.trackTurn then
        --notify set not found
        zo_callLater(function() printMessage("Turning Tide set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and turningTideTracker.savedVariables.autoTrack and turningTideTracker.savedVariables.trackTurn then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Turning Tide set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    ttAddonText:SetMovable(true)
    ttAddonTextIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    ttAddonTextLabelTime:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    ttAddonTextLabelVuln:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    ttAddonTextIcon:SetText(iconText)
    ttAddonTextLabelTime:SetText("")
    ttAddonTextLabelVuln:SetText("")
    --ttAddonTextLabelVuln:SetColor(0, 255, 0, 255)

    setAnchorStartupIcon(turningTideTracker.savedVariables.xAxisText, turningTideTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if turningTideTracker.savedVariables.trackTurn and not turningTideTracker.savedVariables.autoTrack then
        registerAlerts()
        ttAddonText:SetHidden(false)
    elseif turningTideTracker.savedVariables.trackTurn and turningTideTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        ttAddonText:SetHidden(false)
    elseif turningTideTracker.savedVariables.trackTurn and turningTideTracker.savedVariables.autoTrack and not isEquiped then
        ttAddonText:SetHidden(true)
    elseif not turningTideTracker.savedVariables.trackTurn then
        ttAddonText:SetHidden(true)
    end

    --register for combat alerts if tracking is enabled for major vulnerability
    if turningTideTracker.savedVariables.trackVuln and isEquiped then
        registerAlertsVuln()
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)

