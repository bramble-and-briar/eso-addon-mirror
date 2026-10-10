local appName = "mechAcuityTracker"
local mechAbilityID = 99204
local abilityIDspare = 0
local timeCooldown = 25
local timeLeftStack = 4
local previousStacks = 0
local buffRunning = false
local trackingCooldown = false
local picPath = "esoui/art/icons/gear_clockwork_medium_head_a.dds"
local picPathBase = GetAbilityIcon(abilityIDspare)--gear_clockwork_medium_head_b.dds
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local iconTextBase = zo_iconTextFormat(picPathBase, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local setId = 353 
local setCount = 5 --5,2,3,1
local isEquiped = false
local callBackName = "callbackMech"

mechAcuityTracker = {}

mechAcuityTracker.defaults = {
    trackMech = true,
    autoTrack = true,
	notify = true,
	notifyStart = true,
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
    matrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if mechAcuityTracker.savedVariables.trackMech and isEquiped and mechAcuityTracker.savedVariables.autoTrack then
        matrack:SetHidden(false)
    elseif mechAcuityTracker.savedVariables.trackMech and not mechAcuityTracker.savedVariables.autoTrack then
        matrack:SetHidden(false)
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
    matrack:ClearAnchors()
    matrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    matrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then matrack:SetHidden(true) end end, 2000)
    matrack:ClearAnchors()
    matrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--is buff active
local function buffActive()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == mechAbilityID then
            timeLeftStack = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle if player has buff
local function trackBuff()
    if buffActive() then
        buffRunning = true
		if isLibAvailable() and mechAcuityTracker.savedVariables.notifyStart then
            LibNotify.notifyForAddonPlease(appName, mechAbilityID, "Mechanical Acuity Started")
        end
        zo_callLater(function() trackBuff() end, 1000)
    else
        buffRunning = false
    end
end

local function trackCooldown()

    local text
    
    if timeCooldown >= 10 then
        text = string.format("%d", timeCooldown)
    else   
        text = string.format(" %d", timeCooldown)
    end

    if timeCooldown >= 0 then
        trackingCooldown = true
        EVENT_MANAGER:RegisterForUpdate("mechCool", 1000, trackCooldown)
        matrackLabelMain:SetText(text)
    else
        trackingCooldown = false
        EVENT_MANAGER:UnregisterForUpdate("mechCool")
        matrackLabelMain:SetText("")
        timeCooldown = 25
		if isLibAvailable() and mechAcuityTracker.savedVariables.notify then
            LibNotify.notifyForAddonPlease(appName, mechAbilityID, "Mechanical Acuity Ready")
        end
    end

    timeCooldown = timeCooldown - 1
end

--report when new effect is gained
local function effectReport(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, 
    effectType, abilityType, statusEffectType, unitName, unitID, abilityID)

    local nameTmp = GetUnitName("player")

    if nameTmp ~= cleanName(unitName) or abilityID ~= mechAbilityID then
        return
    end

    if changeType == 1 then
        --GAINED- happens once when you first get the buff 
        buffRunning = true
        matrackLabelCorner:SetText(zo_strformat("<<1>>", stackCount))
		if isLibAvailable() and mechAcuityTracker.savedVariables.notifyStart then
            LibNotify.notifyForAddonPlease(appName, mechAbilityID, "Mechanical Acuity Started")
        end

    elseif changeType == 2 then
        --LOST- happens once at the end
        buffRunning = false
        previousStacks = 0
        matrackLabelCorner:SetText("")
        if not trackingCooldown then
            timeCooldown = 25
            matrackLabelMain:SetText(zo_strformat("<<1>>", timeCooldown))
            trackCooldown()
        end

    elseif changeType == 3 then
        --UPDATED- happens each time you gain a stack, plus multiple inappropriate times

        if previousStacks == 5 and not trackingCooldown then
            timeCooldown = 25
            matrackLabelMain:SetText(zo_strformat("<<1>>", timeCooldown))
            trackCooldown()
            return
            end

        if previousStacks == stackCount then return end

        if buffRunning then
            previousStacks = stackCount
            matrackLabelCorner:SetText(zo_strformat("<<1>>", stackCount))
        end

    else
        printMessage(zo_strformat("ERROR TRACKING"))
    end

end

--register for notifications about proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("mechProc", EVENT_EFFECT_CHANGED, effectReport)
    EVENT_MANAGER:AddFilterForEvent("mechProc", EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, mechAbilityID)
end

--unregister for notifications about proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("mechProc", EVENT_EFFECT_CHANGED)
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

    if mechAcuityTracker.savedVariables.trackMech and mechAcuityTracker.savedVariables.autoTrack then
        printMessage("Mechanical Acuity set not found")
        unRegisterAlerts()
        matrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if mechAcuityTracker.savedVariables.trackMech and mechAcuityTracker.savedVariables.autoTrack then
        printMessage("Found Mechanical Acuity set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and mechAcuityTracker.savedVariables.autoTrack and mechAcuityTracker.savedVariables.trackMech then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Machanical Acuity Tracker",
        displayName = "Machanical Acuity Tracker",
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
            tooltip = "Displays the current stack amount of Mechanical Acuity and the cooldown time.",
            getFunc = function()
                return mechAcuityTracker.savedVariables.trackMech
            end,
            setFunc = function(value)
                mechAcuityTracker.savedVariables.trackMech = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = mechAcuityTracker.defaults.trackMech,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return mechAcuityTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                mechAcuityTracker.savedVariables.autoTrack = value
            end,
            default = mechAcuityTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return mechAcuityTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                mechAcuityTracker.savedVariables.xAxisText = value
                setAnchorIcon(mechAcuityTracker.savedVariables.xAxisText, mechAcuityTracker.savedVariables.yAxisText)
            end,
            default = mechAcuityTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return mechAcuityTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                mechAcuityTracker.savedVariables.yAxisText = value
                setAnchorIcon(mechAcuityTracker.savedVariables.xAxisText, mechAcuityTracker.savedVariables.yAxisText)
            end,
            default = mechAcuityTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification Start",
            tooltip = "Displays a notification and plays a sound when the Mechanical Acuity buff starts.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return mechAcuityTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                mechAcuityTracker.savedVariables.notifyStart = value
            end,
            default = mechAcuityTracker.defaults.notifyStart,
        },
		{
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the echanical Acuity buff cooldown is finished and the set is ready to proc again.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return mechAcuityTracker.savedVariables.notify
            end,
            setFunc = function(value)
                mechAcuityTracker.savedVariables.notify = value
            end,
            default = mechAcuityTracker.defaults.notify,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Machanical Acuity Tracker", panelData)
    LAM:RegisterOptionControls("Machanical Acuity Tracker", optionsData)
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
    mechAcuityTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("mechAddonVars", 1, "Settings", mechAcuityTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()
	
	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and mechAcuityTracker.savedVariables.trackMech then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and mechAcuityTracker.savedVariables.autoTrack and mechAcuityTracker.savedVariables.trackMech then
        --notify set not found
        zo_callLater(function() printMessage("Mechanical Acuity set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and mechAcuityTracker.savedVariables.autoTrack and mechAcuityTracker.savedVariables.trackMech then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Mechanical Acuity set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    matrack:SetMovable(true)
    matrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    matrackIconBase:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    matrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    matrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_42)|soft-shadow-thick")
    matrackIcon:SetText(iconText)
    matrackIconBase:SetText(iconTextBase)
    matrackLabelMain:SetText("")
    --matrackLabelMain:SetColor(255, 0, 0, 255)
    matrackLabelCorner:SetText("")
    matrackLabelCorner:SetColor(0, 255, 0, 255)

    setAnchorStartupIcon(mechAcuityTracker.savedVariables.xAxisText, mechAcuityTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if mechAcuityTracker.savedVariables.trackMech and not mechAcuityTracker.savedVariables.autoTrack then
        registerAlerts()
        matrack:SetHidden(false)
    elseif mechAcuityTracker.savedVariables.trackMech and mechAcuityTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        matrack:SetHidden(false)
    elseif mechAcuityTracker.savedVariables.trackMech and mechAcuityTracker.savedVariables.autoTrack and not isEquiped then
        matrack:SetHidden(true)
    elseif not mechAcuityTracker.savedVariables.trackMech then
        matrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
