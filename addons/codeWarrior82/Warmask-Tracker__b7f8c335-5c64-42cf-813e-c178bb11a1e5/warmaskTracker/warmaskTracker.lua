local appName = "warmaskTracker"
local maskBuffID = 252050
local maskDebuffID = 252048
local markOfHircineID = 252048
local timeRemaining = 0
local timeRemainingDebuff = 0
local picPath = GetAbilityIcon(markOfHircineID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local isMenuOpen = false
local needToNotify = true
local needToNotifyStart = true
local needToNotifyEnd = true
local setId = 845 
local setCount = 1 --5,2,3,1
local isEquiped = false
local callBackName = "callbackHunt"

warmaskTracker = {}

warmaskTracker.defaults = {
    trackWarmask = true,
    autoTrack = true,
    trackWho = false,
    trackSelf = false,
	notifyEnd = false,--ends
	notifyStart = false,--starts
	notifyReapply = true,--when ready to re apply
	notifyEndYou = false,--ends on you -- needs to have if tracked true
	notifyStartYou = true,--starts on you
    yAxisText = 930,
    xAxisText = 1300,
    yAxisTextW = 720,
    xAxisTextW = 830,
    yAxisTextP = 680,
    xAxisTextP = 830
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

--is warmask buff active
local function buffActive()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == maskBuffID then
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--is warmask buff active
local function debuffActive()
    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, _, _, _, _, iconFilename, _, abilityId, _, _ = GetUnitBuffInfo("player", i)
        
        if abilityId == maskDebuffID then
            timeRemaining = timeEnding - GetFrameTimeSeconds()
            return true
        end
    end
    return false
end

--handle who has debuff
local function processDebuff(type, name)

    local targetName

    if type == 3 and name ~= "" then
        targetName = cleanName(name)
    elseif type == 4 and name ~= "" then
        targetName = name
    elseif type == 0 and name ~= "" then
        targetName = name--todo clean the names from all type 0 enemies
    elseif name == "" then
        targetName = "unknown"
        return
    end

    if buffActive and timeRemaining >= 0 then
        wmtAddonTextWLabel:SetText(targetName .. "|c00FF00 is targeted|r")
    else
        wmtAddonTextWLabel:SetText("")
    end

end

--handle if player has buff
local function processBuff()
    if buffActive() then
        local text
		local textM
		local time = timeRemaining - 50

		if time >= 10 then
			textM = string.format("%d", time)
		else
			textM = string.format(" %d", time)
		end
		
		if timeRemaining >= 10 then
			text = string.format(" %d", timeRemaining)
		else
			text = string.format("  %d", timeRemaining)
		end
		
        wmtAddonTextLabel:SetText(text)

        if time >= 0 then
            wmtAddonTextLabelMini:SetText(textM)
        else
            wmtAddonTextLabelMini:SetText("")
			--here, debuff can be re applied----------------------------------------------------------------
			if isLibAvailable() and warmaskTracker.savedVariables.notifyReapply and needToNotify then
				needToNotify = false 
				LibNotify.notifyForAddonPlease(appName, markOfHircineID, "Hircine's Mark Ready")
			end
        end

        zo_callLater(function() processBuff() end, 1000)
    else
        wmtAddonTextLabel:SetText("")
        wmtAddonTextLabelMini:SetText("")
        wmtAddonTextWLabel:SetText("")
		--here, your buff has ended-----------------------------------------------------------------------
		needToNotifyStart = true
		if isLibAvailable() and warmaskTracker.savedVariables.notifyEnd and needToNotifyEnd then
			needToNotifyEnd = false
            LibNotify.notifyForAddonPlease(appName, markOfHircineID, "Hircine's Mark ended")
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

    if(abilityId == maskBuffID) then
        processBuff()
    elseif(abilityId == maskDebuffID) then
        if nameTmp == cleanName(targetName) then 
            --player self has debuff
            if debuffActive() then
                wmtAddonTextPLabel:SetText(cleanName(sourceName) .. "|cFF0000 is targeting you|r")
				--here, debuff start on you
            else
                wmtAddonTextPLabel:SetText("")
				--here, debuff ended on you
            end
        else
			--here, your buff has started-----------------------------------------------------------------------
			needToNotify = true
			if isLibAvailable() and warmaskTracker.savedVariables.notifyStart and needToNotifyStart then
				needToNotifyEnd = true
				needToNotifyStart = false
				LibNotify.notifyForAddonPlease(appName, markOfHircineID, "Hircine's Mark Started")--to do, doesn't notify started if re applying because it technically never finished
			end
            processDebuff(targetType, targetName)
        end
    end
end

--change who is targeted text anchor to move text around the screen at app start
local function setAnchorStartupP(x, y)  
    wmtAddonTextP:ClearAnchors()
    wmtAddonTextP:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change who is targeted text anchor to move text around the screen
local function setAnchorP(x, y)  
    wmtAddonTextPLabel:SetText("(InsertName)|cFF0000 is targeting you|r")
    wmtAddonTextP:SetHidden(false)
    zo_callLater(function () wmtAddonTextPLabel:SetText("") end, 2000)
    zo_callLater(function () wmtAddonTextP:SetHidden(true) end, 2000)
    wmtAddonTextP:ClearAnchors()
    wmtAddonTextP:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change who is targeted text anchor to move text around the screen at app start
local function setAnchorStartupW(x, y)  
    wmtAddonTextW:ClearAnchors()
    wmtAddonTextW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change who is targeted text anchor to move text around the screen
local function setAnchorW(x, y)  
    wmtAddonTextWLabel:SetText("(InsertName)|c00FF00 is targeted|r")
    wmtAddonTextW:SetHidden(false)
    zo_callLater(function () wmtAddonTextWLabel:SetText("") end, 2000)
    zo_callLater(function () wmtAddonTextW:SetHidden(true) end, 2000)
    wmtAddonTextW:ClearAnchors()
    wmtAddonTextW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen at app start
local function setAnchorStartupIcon(x, y)  
    wmtAddonText:ClearAnchors()
    wmtAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    wmtAddonText:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then wmtAddonText:SetHidden(true) end end, 2000)
    wmtAddonText:ClearAnchors()
    wmtAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--register for notifications about mask buff and debuff
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("maskBuff", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("maskBuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, maskBuffID)
    EVENT_MANAGER:RegisterForEvent("maskDebuff", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("maskDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, maskDebuffID)
end

--unregister for notifications about mask buff and debuff
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("maskBuff", EVENT_COMBAT_EVENT)
    EVENT_MANAGER:UnregisterForEvent("maskDebuff", EVENT_COMBAT_EVENT)
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    if warmaskTracker.savedVariables.trackWarmask then
        wmtAddonText:SetHidden(true)
    end
    if warmaskTracker.savedVariables.trackWho then
        wmtAddonTextW:SetHidden(true)    
    end
    if warmaskTracker.savedVariables.trackSelf then
        wmtAddonTextP:SetHidden(true)
    end
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if warmaskTracker.savedVariables.trackWarmask and isEquiped and warmaskTracker.savedVariables.autoTrack then
        wmtAddonText:SetHidden(false)
    elseif warmaskTracker.savedVariables.trackWarmask and not warmaskTracker.savedVariables.autoTrack then
        wmtAddonText:SetHidden(false)
    end
	
	if warmaskTracker.savedVariables.trackWho and isEquiped and warmaskTracker.savedVariables.autoTrack then
        wmtAddonTextW:SetHidden(false)
    elseif warmaskTracker.savedVariables.trackWho and not warmaskTracker.savedVariables.autoTrack then
        wmtAddonTextW:SetHidden(false)
    end
	
	if warmaskTracker.savedVariables.trackSelf and isEquiped and warmaskTracker.savedVariables.autoTrack then
        wmtAddonTextP:SetHidden(false)
    elseif warmaskTracker.savedVariables.trackSelf and not warmaskTracker.savedVariables.autoTrack then
        wmtAddonTextP:SetHidden(false)
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

    if warmaskTracker.savedVariables.trackWarmask and warmaskTracker.savedVariables.autoTrack then
        printMessage("Huntsman's Warmask set not found")
        unRegisterAlerts()
        wmtAddonText:SetHidden(true)
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if warmaskTracker.savedVariables.trackWarmask and warmaskTracker.savedVariables.autoTrack then
        printMessage("Found Huntsman's Warmask set")
        registerAlerts()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)

    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and warmaskTracker.savedVariables.autoTrack and warmaskTracker.savedVariables.trackWarmask then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Warmask Tracker",
        displayName = "Warmask Tracker",
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
            tooltip = "Displays a timer while the Huntsman's Warmask buff is active.",
            getFunc = function()
                return warmaskTracker.savedVariables.trackWarmask
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.trackWarmask = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = warmaskTracker.defaults.trackWarmask,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return warmaskTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.autoTrack = value
            end,
            default = warmaskTracker.defaults.autoTrack,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return warmaskTracker.savedVariables.xAxisText
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.xAxisText = value
                setAnchorIcon(warmaskTracker.savedVariables.xAxisText, warmaskTracker.savedVariables.yAxisText)
            end,
            default = warmaskTracker.defaults.xAxisText,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return warmaskTracker.savedVariables.yAxisText
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.yAxisText = value
                setAnchorIcon(warmaskTracker.savedVariables.xAxisText, warmaskTracker.savedVariables.yAxisText)
            end,
            default = warmaskTracker.defaults.yAxisText,
        },
        {
            type = "checkbox",
            name = "Track Debuff",
            tooltip = "Displays on screen text with the name of the person who has your Mark of Hircine debuff on them.",
            getFunc = function()
                return warmaskTracker.savedVariables.trackWho
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.trackWho = value
            end,
            default = warmaskTracker.defaults.trackWho,
        },
        {
            type = "slider",
            name = "Who has debuff Text x Position",
            tooltip = "Adjust the left and right position of the on screen text that tells you who has the Mark of Hircine debuff.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return warmaskTracker.savedVariables.xAxisTextW
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.xAxisTextW = value
                setAnchorW(warmaskTracker.savedVariables.xAxisTextW, warmaskTracker.savedVariables.yAxisTextW)
            end,
            default = warmaskTracker.defaults.xAxisTextW,
        },
        {
            type = "slider",
            name = "Who has debuff Text y Position",
            tooltip = "Adjust the up and down position of the on screen text that tells you who has the Mark of Hircine debuff.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return warmaskTracker.savedVariables.yAxisTextW
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.yAxisTextW = value
                setAnchorW(warmaskTracker.savedVariables.xAxisTextW, warmaskTracker.savedVariables.yAxisTextW)
            end,
            default = warmaskTracker.defaults.yAxisTextW,
        },
        {
            type = "checkbox",
            name = "Track Debuff on Self",
            tooltip = "Displays on screen text with the name of the person who has placed the Mark of Hircine debuff on you.",
            getFunc = function()
                return warmaskTracker.savedVariables.trackSelf
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.trackSelf = value
            end,
            default = warmaskTracker.defaults.trackSelf,
        },
        {
            type = "slider",
            name = "Who is targeting Text x Position",
            tooltip = "Adjust the left and right position of the on screen text that tells you who targeted you with the Mark of Hircine debuff.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return warmaskTracker.savedVariables.xAxisTextP
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.xAxisTextP = value
                setAnchorP(warmaskTracker.savedVariables.xAxisTextP, warmaskTracker.savedVariables.yAxisTextP)
            end,
            default = warmaskTracker.defaults.xAxisTextP,
        },
        {
            type = "slider",
            name = "Who is targeting Text y Position",
            tooltip = "Adjust the up and down position of the on screen text that tells you who targeted you with the Mark of Hircine debuff.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return warmaskTracker.savedVariables.yAxisTextP
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.yAxisTextP = value
                setAnchorP(warmaskTracker.savedVariables.xAxisTextP, warmaskTracker.savedVariables.yAxisTextP)
            end,
            default = warmaskTracker.defaults.yAxisTextP,
        },
		{
            type = "checkbox",
            name = "Notification Start",
            tooltip = "Displays a notification and plays a sound when you have placed Hircine's Mark on a target.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return warmaskTracker.savedVariables.notifyStart
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.notifyStart = value
            end,
            default = warmaskTracker.defaults.notifyStart,
        },
		{
            type = "checkbox",
            name = "Notification Re-apply",
            tooltip = "Displays a notification and plays a sound when the Hircine's Mark is ready to be re-applied to a new target.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return warmaskTracker.savedVariables.notifyReapply
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.notifyReapply = value
            end,
            default = warmaskTracker.defaults.notifyReapply,
        },
		{
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the Hircine's Mark you have placed on a target ends.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return warmaskTracker.savedVariables.notifyEnd
            end,
            setFunc = function(value)
                warmaskTracker.savedVariables.notifyEnd = value
            end,
            default = warmaskTracker.defaults.notifyEnd,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Warmask Tracker", panelData)
    LAM:RegisterOptionControls("Warmask Tracker", optionsData)
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
    warmaskTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("wmtAddonVars", 1, "Settings", warmaskTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

	--register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif isLibAvailable() and warmaskTracker.savedVariables.trackWarmask then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and warmaskTracker.savedVariables.autoTrack and warmaskTracker.savedVariables.trackWarmask then
        --notify set not found
        zo_callLater(function() printMessage("Huntsman's Warmask set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and warmaskTracker.savedVariables.autoTrack and warmaskTracker.savedVariables.trackWarmask then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Huntsman's Warmask set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --organise on screen text
    wmtAddonText:SetMovable(true)
    wmtAddonTextW:SetMovable(true)
    wmtAddonTextP:SetMovable(true)
    wmtAddonTextLabelMini:SetMovable(true)
    wmtAddonTextIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    wmtAddonTextLabel:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    wmtAddonTextLabelMini:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    wmtAddonTextWLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_42)|soft-shadow-thick")
    wmtAddonTextPLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_42)|soft-shadow-thick")
    wmtAddonTextIcon:SetText(iconText)
    wmtAddonTextLabel:SetText("")
    wmtAddonTextLabelMini:SetText("")
    wmtAddonTextWLabel:SetText("")
    wmtAddonTextPLabel:SetText("")
    setAnchorStartupIcon(warmaskTracker.savedVariables.xAxisText, warmaskTracker.savedVariables.yAxisText)
    setAnchorStartupW(warmaskTracker.savedVariables.xAxisTextW, warmaskTracker.savedVariables.yAxisTextW)
    setAnchorStartupP(warmaskTracker.savedVariables.xAxisTextP, warmaskTracker.savedVariables.yAxisTextP)

    --just good practice
    if warmaskTracker.savedVariables.trackWho then
        wmtAddonTextW:SetHidden(false)
    else
        wmtAddonTextW:SetHidden(true)
    end
    if warmaskTracker.savedVariables.trackSelf then
        wmtAddonTextP:SetHidden(false)
    else
        wmtAddonTextP:SetHidden(true)
    end

    --register for combat alerts if tracking is enabled
    if warmaskTracker.savedVariables.trackWarmask and not warmaskTracker.savedVariables.autoTrack then
        registerAlerts()
        wmtAddonText:SetHidden(false)
    elseif warmaskTracker.savedVariables.trackWarmask and warmaskTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        wmtAddonText:SetHidden(false)
    elseif warmaskTracker.savedVariables.trackWarmask and warmaskTracker.savedVariables.autoTrack and not isEquiped then
        wmtAddonText:SetHidden(true)
    elseif not warmaskTracker.savedVariables.trackWarmask then
        wmtAddonText:SetHidden(true)
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)


