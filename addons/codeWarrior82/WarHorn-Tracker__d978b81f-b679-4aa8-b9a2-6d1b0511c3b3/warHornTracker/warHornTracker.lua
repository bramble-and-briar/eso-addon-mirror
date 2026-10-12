local appName = "warHornTracker"

local isLoaded = false
local isWhActive = false
local timeRemaining = 0
local abilityTmp = 0
local isMenuOpen = false
--warhorn hotbar skill ids
local basicBase = 38563
local aggressiveBase = 40223
local sturdyBase = 40220
local isEquiped = false
local ultimateSlot = 8

warHornTracker = {}

warHornTracker.defaults = {
    trackWh = true,
    autoTrack = true,
	playSound = true,
    yAxisText = 700,
    xAxisText = 780,
}

warHornTracker.isBasicHorn = {
    [38564] = true,		-- I
	[46526] = true,		-- II
	[46528] = true,		-- III
	[46530] = true		-- IV
}

warHornTracker.isAggressiveHorn = {
	[40224] = true,		-- I
	[46532] = true,		-- II
	[46535] = true,		-- III
	[46538] = true		-- IV
}

warHornTracker.isSturdyHorn = {
    [40221] = true,		-- I
	[46541] = true,		-- II
	[46544] = true,		-- III
	[46547] = true		-- IV
}

--print message to chat box
local function printMessage(msg)
	local chat = LibChatMessage(appName, "MA")
	chat:Print(msg)
end

--check if LibNotify is available
local function isLibAvailable()
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" then
        return true
    else 
		return false
    end
end

--is warhorn is not active
local function warhornInactive()
    whtAddonTextIcon:SetText("War Horn Ended")
    whtAddonText:SetHidden(true)
    isWhActive = false
end

--timer for warhorn text
local function updateTime()

    if timeRemaining > 0 then

        if warHornTracker.isAggressiveHorn[abilityTmp] and timeRemaining < 20 then
            whtAddonTextIcon:SetColor(0, 204, 0, 255)
        elseif warHornTracker.isAggressiveHorn[abilityTmp] and timeRemaining >= 20 then
            whtAddonTextIcon:SetColor(204, 0, 0, 255)
        elseif warHornTracker.isSturdyHorn[abilityTmp] and timeRemaining < 23 then
            whtAddonTextIcon:SetColor(0, 204, 0, 255)
        elseif warHornTracker.isSturdyHorn[abilityTmp] and timeRemaining >= 23 then
            whtAddonTextIcon:SetColor(204, 0, 0, 255)
        elseif warHornTracker.isBasicHorn[abilityTmp] then
            whtAddonTextIcon:SetColor(0, 204, 0, 255)
        end

        EVENT_MANAGER:RegisterForUpdate("warhornUpdate", 1000, updateTime)
        local text = string.format("War Horn Active %d", timeRemaining)
        whtAddonTextIcon:SetText(text)

    else
        warhornInactive()
        EVENT_MANAGER:UnregisterForUpdate("warhornUpdate")

    end

    timeRemaining = timeRemaining - 1

end

--is warhorn is active
local function warhornActive()
    local text = string.format("War Horn Active %d", timeRemaining)
    whtAddonTextIcon:SetText(text)
    whtAddonText:SetHidden(false)
    isWhActive = true
    updateTime()
end

--handle effect change alert
local function effectReport( _,  changeType,  _,  _,  unitTag, beginTime, endTime, stackCount,  _,  _,  effectType, _,  _,  unitName, unitId, abilityId, sourceType)
	--changeType
	-- 1 = EFFECT_RESULT_GAINED
	-- 2 = EFFECT_RESULT_FADED
	-- 3 = EFFECT_RESULT_UPDATED

    --war horn active
	if changeType == EFFECT_RESULT_GAINED and warHornTracker.isBasicHorn[abilityId] or changeType == EFFECT_RESULT_GAINED and warHornTracker.isAggressiveHorn[abilityId] or changeType == EFFECT_RESULT_GAINED and warHornTracker.isSturdyHorn[abilityId] then
        timeRemaining = endTime - GetFrameTimeSeconds()
        abilityTmp = abilityId
        warhornActive()
		if playSound then PlaySound(SOUNDS.DUEL_START) end
	end

    --double war horn		
	if changeType == EFFECT_RESULT_UPDATED and warHornTracker.isBasicHorn[abilityId] or changeType == EFFECT_RESULT_UPDATED and warHornTracker.isAggressiveHorn[abilityId] or changeType == EFFECT_RESULT_UPDATED and warHornTracker.isSturdyHorn[abilityId] then
        timeRemaining = endTime - GetFrameTimeSeconds()
        abilityTmp = abilityId
        warhornActive()
	end

    --war horn ended	
	if changeType == EFFECT_RESULT_FADED and warHornTracker.isBasicHorn[abilityId] or changeType == EFFECT_RESULT_FADED and warHornTracker.isAggressiveHorn[abilityId] or changeType == EFFECT_RESULT_FADED and warHornTracker.isSturdyHorn[abilityId] then
        warhornInactive()
        timeRemaining = 0
	end
end

--register for notifications about mask buff and debuff
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("whtEvent", EVENT_EFFECT_CHANGED, effectReport)
	EVENT_MANAGER:AddFilterForEvent("whtEvent", EVENT_EFFECT_CHANGED, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
end

--unregister for notifications about mask buff and debuff
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("whtEvent", EVENT_EFFECT_CHANGED)
end

--change icon anchor to move icon around the screen at app start
local function setAnchorStartupIcon(x, y)  
    whtAddonText:ClearAnchors()
    whtAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    whtAddonText:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then whtAddonText:SetHidden(true) end end, 2000)
    whtAddonText:ClearAnchors()
    whtAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    whtAddonText:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if isWhActive then
     if warHornTracker.savedVariables.trackWh and isEquiped and warHornTracker.savedVariables.autoTrack then
        whtAddonText:SetHidden(false)
    elseif warHornTracker.savedVariables.trackWh and not warHornTracker.savedVariables.autoTrack then
        whtAddonText:SetHidden(false)
    end
end
end

--menu has been opened
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

--setup options menu
local function createOptions()

    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "War Horn Tracker",
        displayName = "War Horn Tracker",
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
            name = "Track Buff",
            tooltip = "Displays a notification while a War Horn is active.",
            getFunc = function()
                return warHornTracker.savedVariables.trackWh
            end,
            setFunc = function(value)
                warHornTracker.savedVariables.trackWh = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = warHornTracker.defaults.trackWh,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you have the correct Ultimate ability equipped and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return warHornTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                warHornTracker.savedVariables.autoTrack = value
            end,
            default = warHornTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the notification text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return warHornTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                warHornTracker.savedVariables.xAxisText = value
                setAnchorIcon(warHornTracker.savedVariables.xAxisText, warHornTracker.savedVariables.yAxisText)
            end,
            default = warHornTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the notification text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return warHornTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                warHornTracker.savedVariables.yAxisText = value
                setAnchorIcon(warHornTracker.savedVariables.xAxisText, warHornTracker.savedVariables.yAxisText)
            end,
            default = warHornTracker.defaults.yAxisText,
        },
		{
            type = "checkbox",
            name = "Notification Sound",
            tooltip = "Plays a sound when you are notified that War Horn is active.",
            getFunc = function()
                return warHornTracker.savedVariables.playSound
            end,
            setFunc = function(value)
                warHornTracker.savedVariables.playSound = value
            end,
            default = warHornTracker.defaults.playSound,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("warH Tracker", panelData)
    LAM:RegisterOptionControls("warH Tracker", optionsData)
end

--stop tracking if set is not equipped
local function stopTrackingAuto()

    if warHornTracker.savedVariables.trackWh and warHornTracker.savedVariables.autoTrack then
        printMessage("Warhorn Ultimate not found")
        unRegisterAlerts()
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if warHornTracker.savedVariables.trackWh and warHornTracker.savedVariables.autoTrack then
        printMessage("Found Warhorn Ultimate")
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
    if slottedAbilityIdFront == basicBase or slottedAbilityIdBack == basicBase then
        isEquiped = true
        return true
    elseif slottedAbilityIdFront == aggressiveBase or slottedAbilityIdBack == aggressiveBase then
        isEquiped = true
        return true
    elseif slottedAbilityIdFront == sturdyBase or slottedAbilityIdBack == sturdyBase then
        isEquiped = true
        return true
    else
        isEquiped = false
        return false
    end
end

--addon loaded
local function onAddOnLoadedWht(event, name)
    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    warHornTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("whtAddonVars", 1, "Settings", warHornTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and warHornTracker.savedVariables.trackWh then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not checkSkills() and warHornTracker.savedVariables.autoTrack and warHornTracker.savedVariables.trackWh then
        --notify set not found
        zo_callLater(function() printMessage("Warhorn Ultimate not found") end, 600)
    elseif checkSkills() and warHornTracker.savedVariables.autoTrack and warHornTracker.savedVariables.trackWh then
        --notify set found
        zo_callLater(function() printMessage("Found Warhorn Ultimate") end, 600)
    end

    --setup text field areas
    whtAddonText:SetMovable(true)
    whtAddonTextIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    whtAddonTextIcon:SetText("War Horn Tracker")
    whtAddonTextIcon:SetColor(255, 255, 255, 255)
    whtAddonText:SetHidden(true)
    setAnchorStartupIcon(warHornTracker.savedVariables.xAxisText, warHornTracker.savedVariables.yAxisText)

    --register for combat alerts if tracking is enabled
    if warHornTracker.savedVariables.trackWh and not warHornTracker.savedVariables.autoTrack then
        registerAlerts()
    elseif warHornTracker.savedVariables.trackWh and warHornTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
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
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoadedWht)