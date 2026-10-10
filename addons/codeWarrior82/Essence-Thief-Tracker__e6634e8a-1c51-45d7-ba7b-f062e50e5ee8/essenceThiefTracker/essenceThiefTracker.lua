local appName = "essenceThiefTracker"
local essenceAbilityID = 67334
local poolAbilityID = 67324
local timeRemaining = 0
local procTime = 10
local picPath = GetAbilityIcon(essenceAbilityID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local setId = 198
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackEssence"

essenceThiefTracker = {}

essenceThiefTracker.defaults = {
    trackEssence = true,
    autoTrack = true,
	notify = true,
	notifyStart = true,
	notifyProc = true,
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
    ettrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if essenceThiefTracker.savedVariables.trackEssence and isEquiped and essenceThiefTracker.savedVariables.autoTrack then
        ettrack:SetHidden(false)
    elseif essenceThiefTracker.savedVariables.trackEssence and not essenceThiefTracker.savedVariables.autoTrack then
        ettrack:SetHidden(false)
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
    ettrack:ClearAnchors()
    ettrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    ettrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then ettrack:SetHidden(true) end end, 2000)
    ettrack:ClearAnchors()
    ettrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--is buff active
local function buffActive()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == essenceAbilityID then
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function processBuff()
    if buffActive() then

        local time = timeRemaining

        local text = ""

        if time >= 10 then
            text = string.format("%d", time)
        else
            text = string.format(" %d", time)
        end

        if time > 0 then
            ettrackLabelMain:SetText(text)
        else
            ettrackLabelMain:SetText("")
        end

        zo_callLater(function() processBuff() end, 1000)
    else
		if isLibAvailable() and essenceThiefTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, essenceAbilityID, "Essence Thief ended")
        end
        ettrackLabelMain:SetText("")
    end
end

--report when new effect is gained
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(unitName) or changeType ~= 1 or abilityID ~= essenceAbilityID then
        return
    end

    processBuff()

end

--handle if essence has been created
local function processCooldown()

    local text
    if procTime >= 10 then
        text = string.format("%d", procTime)
    else
        text = string.format(" %d", procTime)
    end

    if procTime >= 0 then
        EVENT_MANAGER:RegisterForUpdate("essenceUpdate", 1000, processCooldown)
        ettrackLabelCorner:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("essenceUpdate")
        ettrackLabelCorner:SetText("")
        procTime = 10
		if isLibAvailable() and essenceThiefTracker.savedVariables.notifyProc then
            LibNotify.notifyForAddonPlease(appName, essenceAbilityID, "Essence Pool Ready")
        end
    end

    procTime = procTime - 1
end

local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    if result ~= 2240 then
        return
    end

    procTime = 10
	if isLibAvailable() and essenceThiefTracker.savedVariables.notifyStart then
		LibNotify.notifyForAddonPlease(appName, essenceAbilityID, "Collect Essence Pool")
	end
    processCooldown()

end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("essenceProc", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("essenceProc", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, essenceAbilityID)

    EVENT_MANAGER:RegisterForEvent("essenceProc2", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("essenceProc2", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, poolAbilityID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("essenceProc", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent("essenceProc2", EVENT_COMBAT_EVENT)
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

    if essenceThiefTracker.savedVariables.trackEssence and essenceThiefTracker.savedVariables.autoTrack then
        printMessage("Essence Thief set not found")
        unRegisterAlerts()
        ettrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if essenceThiefTracker.savedVariables.trackEssence and essenceThiefTracker.savedVariables.autoTrack then
        printMessage("Found Essence Thief set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and essenceThiefTracker.savedVariables.autoTrack and essenceThiefTracker.savedVariables.trackEssence then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Essence Thief Tracker",
        displayName = "Essence Thief Tracker",
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
            tooltip = "Displays a timer while the Essence Thief buff is active.",
            getFunc = function()
                return essenceThiefTracker.savedVariables.trackEssence
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.trackEssence = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = essenceThiefTracker.defaults.trackEssence,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return essenceThiefTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.autoTrack = value
            end,
            default = essenceThiefTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return essenceThiefTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.xAxisText = value
                setAnchorIcon(essenceThiefTracker.savedVariables.xAxisText, essenceThiefTracker.savedVariables.yAxisText)
            end,
            default = essenceThiefTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return essenceThiefTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.yAxisText = value
                setAnchorIcon(essenceThiefTracker.savedVariables.xAxisText, essenceThiefTracker.savedVariables.yAxisText)
            end,
            default = essenceThiefTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification Collect",
            tooltip = "Displays a notification and plays a sound when an Essence Thief pool is created and ready to be collected.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return essenceThiefTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.notifyStart = value
            end,
            default = essenceThiefTracker.defaults.notifyStart,
        },
		{
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the Essence Thief buff finishes.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return essenceThiefTracker.savedVariables.notify
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.notify = value
            end,
            default = essenceThiefTracker.defaults.notify,
        },
		{
            type = "checkbox",
            name = "Notification Ready",
            tooltip = "Displays a notification and plays a sound when a new Essence Thief pool can be created.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return essenceThiefTracker.savedVariables.notifyProc
            end,
            setFunc = function(value)
                essenceThiefTracker.savedVariables.notifyProc = value
            end,
            default = essenceThiefTracker.defaults.notifyProc,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Essence Thief Tracker", panelData)
    LAM:RegisterOptionControls("Essence Thief Tracker", optionsData)
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
    essenceThiefTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("ettAddonVars", 1, "Settings", essenceThiefTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()
	
	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()


	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and essenceThiefTracker.savedVariables.trackEssence then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and essenceThiefTracker.savedVariables.autoTrack and essenceThiefTracker.savedVariables.trackEssence then
        --notify set not found
        zo_callLater(function() printMessage("Essence Thief set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and essenceThiefTracker.savedVariables.autoTrack and essenceThiefTracker.savedVariables.trackEssence then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Essence Thief set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    ettrack:SetMovable(true)
    ettrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    ettrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    ettrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    ettrackIcon:SetText(iconText)
    ettrackLabelMain:SetText("")
    --rctrackLabelMain:SetColor(255, 255, 0, 255)
    ettrackLabelCorner:SetText("")
    --rctrackLabelCorner:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(essenceThiefTracker.savedVariables.xAxisText, essenceThiefTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if essenceThiefTracker.savedVariables.trackEssence and not essenceThiefTracker.savedVariables.autoTrack then
        registerAlerts()
        ettrack:SetHidden(false)
    elseif essenceThiefTracker.savedVariables.trackEssence and essenceThiefTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        ettrack:SetHidden(false)
    elseif essenceThiefTracker.savedVariables.trackEssence and essenceThiefTracker.savedVariables.autoTrack and not isEquiped then
        ettrack:SetHidden(true)
    elseif not essenceThiefTracker.savedVariables.trackEssence then
        ettrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
