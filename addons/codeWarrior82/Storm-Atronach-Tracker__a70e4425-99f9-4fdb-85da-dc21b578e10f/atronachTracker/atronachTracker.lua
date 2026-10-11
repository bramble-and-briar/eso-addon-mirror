local appName = "atronachTracker"
local atronachAbilityID = 25312
local atroBaseID = 80459
local atroGreaterID = 80463
local atroChargedID = 80468
local berserkID = 62195
local timeRemaining = 10
local procTime = 15
local picPath = GetAbilityIcon(atroBaseID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local isTracking = false
--storm atro hotbar skill ids
local atroBase = 23634
local atroGreat = 23492
local atroSummon = 23495
local isEquiped = false
local ultimateSlot = 8

atronachTracker = {}

atronachTracker.defaults = {
    trackAtro = true,
    autoTrack = true,
	notifyStart = true,
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
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" then
        return true
    else 
		return false
    end
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    satrack:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if atronachTracker.savedVariables.trackAtro and isEquiped and atronachTracker.savedVariables.autoTrack then
        satrack:SetHidden(false)
    elseif atronachTracker.savedVariables.trackAtro and not atronachTracker.savedVariables.autoTrack then
        satrack:SetHidden(false)
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
    satrack:ClearAnchors()
    satrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    satrack:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then satrack:SetHidden(true) end end, 2000)
    satrack:ClearAnchors()
    satrack:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--handle if player has buff
local function processBuff()

    isTracking = true
    local text
    if timeRemaining >= 10 then
        text = string.format("%d", timeRemaining)
    else
        text = string.format(" %d", timeRemaining)
    end

    if timeRemaining > 0 then
        EVENT_MANAGER:RegisterForUpdate("berserkTrack", 1000, processBuff)
        satrackLabelCorner:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("berserkTrack")
        satrackLabelCorner:SetText("")
        isTracking = false
    end

    timeRemaining = timeRemaining - 1
end

local function processCooldown()

    local text
    if procTime >= 10 then
        text = string.format("%d", procTime)
    else
        text = string.format(" %d", procTime)
    end

    if procTime > 0 then
        EVENT_MANAGER:RegisterForUpdate("atroTrack", 1000, processCooldown)
        satrackLabelMain:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("atroTrack")
        satrackLabelMain:SetText("")
    end

    procTime = procTime - 1
end

local function combatReport(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, 
    sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if isError then
        return
    end

    if abilityId == atronachAbilityID and result == 2240 then

        if isLibAvailable() and atronachTracker.savedVariables.notifyStart then
            LibNotify.notifyForAddonPlease(appName, atroBaseID, "Atronach Active")
        end
		
		procTime = 15
        processCooldown()
		
    elseif abilityId == berserkID and not isTracking then
        timeRemaining = 10
        processBuff()
    end
end

--register for notifications
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("atro", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("atro", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, atronachAbilityID)

    EVENT_MANAGER:RegisterForEvent("berserk", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("berserk", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, berserkID)

end

--unregister for notifications 
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("atro", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent("berserk", EVENT_COMBAT_EVENT)
end

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "Storm Atronach Tracker",
        displayName = "Storm Atronach Tracker",
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
            tooltip = "Displays a timer while the Storm Atronach is .",
            getFunc = function()
                return atronachTracker.savedVariables.trackAtro
            end,
            setFunc = function(value)
                atronachTracker.savedVariables.trackAtro = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = atronachTracker.defaults.trackAtro,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you have the correct Ultimate ability equipped and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return atronachTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                atronachTracker.savedVariables.autoTrack = value
            end,
            default = atronachTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return atronachTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                atronachTracker.savedVariables.xAxisText = value
                setAnchorIcon(atronachTracker.savedVariables.xAxisText, atronachTracker.savedVariables.yAxisText)
            end,
            default = atronachTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return atronachTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                atronachTracker.savedVariables.yAxisText = value
                setAnchorIcon(atronachTracker.savedVariables.xAxisText, atronachTracker.savedVariables.yAxisText)
            end,
            default = atronachTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification Start",
            tooltip = "Displays a notification and plays a sound when a Storm Atronach drops.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return atronachTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                atronachTracker.savedVariables.notifyStart = value
            end,
            default = atronachTracker.defaults.notifyStart,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Storm Atronach Tracker", panelData)
    LAM:RegisterOptionControls("Storm Atronach Tracker", optionsData)
end

--stop tracking if set is not equipped
local function stopTrackingAuto()

    if atronachTracker.savedVariables.trackAtro and atronachTracker.savedVariables.autoTrack then
        printMessage("Atronach Ultimate not found")
        unRegisterAlerts()
        satrack:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if atronachTracker.savedVariables.trackAtro and atronachTracker.savedVariables.autoTrack then
        printMessage("Found Atronach Ultimate")
        registerAlerts()
    end
end

--check if skill is equipped
local function checkSkills()
    --hotbarCategory = HOTBAR_CATEGORY_PRIMARY / HOTBAR_CATEGORY_BACKUP
    --index is 1 and 2 are heavy attack and bash, 3 through 7 are skills, 8 is ulti

    --read front and back bar ulti slots
    local slottedAbilityIdFront = GetSlotBoundId(ultimateSlot, HOTBAR_CATEGORY_PRIMARY)
    local slottedAbilityIdBack = GetSlotBoundId(ultimateSlot, HOTBAR_CATEGORY_BACKUP)

    --printMessage("skill id front - " .. tostring(slottedAbilityIdFront))
    --printMessage("skill id back - " .. tostring(slottedAbilityIdBack))

    --determine if ability is slotted on front or back bar
    if slottedAbilityIdFront == atroBase or slottedAbilityIdBack == atroBase then
        isEquiped = true
        return true
    elseif slottedAbilityIdFront == atroGreat or slottedAbilityIdBack == atroGreat then
        isEquiped = true
        return true
    elseif slottedAbilityIdFront == atroSummon or slottedAbilityIdBack == atroSummon then
        isEquiped = true
        return true
    else
        isEquiped = false
        return false
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
    atronachTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("atAddonVars", 1, "Settings", atronachTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 500)
		return
    elseif isLibAvailable() and atronachTracker.savedVariables.trackAtro then
		--notify that add-on has been loaded
		zo_callLater(function() printMessage("add-on loaded") end, 500)
	end

    --check if set is equipped
    if not checkSkills() and atronachTracker.savedVariables.autoTrack and atronachTracker.savedVariables.trackAtro then
        --notify set not found
        zo_callLater(function() printMessage("Atronach Ultimate not found") end, 600)
    elseif checkSkills() and atronachTracker.savedVariables.autoTrack and atronachTracker.savedVariables.trackAtro then
        --notify set found
        zo_callLater(function() printMessage("Found Atronach Ultimate") end, 600)
    end

    --setup text field areas
    satrack:SetMovable(true)
    satrackIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    satrackLabelMain:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    satrackLabelCorner:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    satrackIcon:SetText(iconText)
    satrackLabelMain:SetText("")
    satrackLabelMain:SetColor(255, 255, 0, 255)
    satrackLabelCorner:SetText("")
    satrackLabelCorner:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(atronachTracker.savedVariables.xAxisText, atronachTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if atronachTracker.savedVariables.trackAtro and not atronachTracker.savedVariables.autoTrack then
        registerAlerts()
        satrack:SetHidden(false)
    elseif atronachTracker.savedVariables.trackAtro and atronachTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        satrack:SetHidden(false)
    elseif atronachTracker.savedVariables.trackAtro and atronachTracker.savedVariables.autoTrack and not isEquiped then
        satrack:SetHidden(true)
    elseif not atronachTracker.savedVariables.trackAtro then
        satrack:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --register for a callback when a skill is change, removed or updated, then check for relevent ulti
    ACTION_BAR_ASSIGNMENT_MANAGER:RegisterCallback("SlotUpdated", function(actionSlotIndex, hotbarCategory, isChangedByPlayer)
        if isChangedByPlayer then
            zo_callLater(function () if checkSkills() then startTrackingAuto() else stopTrackingAuto() end end, 200)
        end
    end)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)
