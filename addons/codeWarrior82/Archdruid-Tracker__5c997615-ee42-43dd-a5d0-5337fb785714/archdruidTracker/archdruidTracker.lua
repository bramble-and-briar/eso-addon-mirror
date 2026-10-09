local appName = "archdruidTracker"
local bearProcID = 176813
local timeRemaining = 0
local picPath = GetAbilityIcon(bearProcID)
local iconText = zo_iconTextFormat(picPath, 80, 80, " ")
local isLoaded = false
local procTime = 15
local vulnTime = 7
local isMenuOpen = false
local setId = 666
local setCount = 2 --5,2,3,1
local isEquiped = false
local callBackName = "callbackArch"

local archdruidTracker = {}

archdruidTracker.defaults = {
    trackArch = true,
    autoTrack = true,
    trackVuln = true,
	notifyEnd = true,
	notifyVuln = true,
    yAxisTextArch = 950,
    xAxisTextArch = 1300
}

archdruidTracker.majorEffects = {
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
	[176815] = true,--archdruid major buln proc 
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
	return archdruidTracker.majorEffects[abilityID]
end

local function processProc()

    local text 
    if procTime > 9 then
        text = string.format(" %d", procTime)
    else
        text = string.format("  %d", procTime)
    end

    if procTime >= 0 then   
        EVENT_MANAGER:RegisterForUpdate("archdruidUpdate", 1000, processProc)
        archAddonTextLabelTime:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("archdruidUpdate")
        archAddonTextLabelTime:SetText("")
        procTime = 15
		if isLibAvailable() and archdruidTracker.savedVariables.notifyEnd then
            LibNotify.notifyForAddonPlease(appName, bearProcID, "Archdruid Ready")
        end	
    end

    procTime = procTime - 1
end

local function processVuln()

    local text = string.format("%d", vulnTime)
       
    if vulnTime >= 0 then   
        EVENT_MANAGER:RegisterForUpdate("archdruidUpdateVuln", 1000, processVuln)
        archAddonTextLabelVuln:SetText(text)
    else
        EVENT_MANAGER:UnregisterForUpdate("archdruidUpdateVuln")
        archAddonTextLabelVuln:SetText("")
        vulnTime = 7
		if isLibAvailable() and archdruidTracker.savedVariables.notifyVuln then
            LibNotify.notifyForAddonPlease(appName, bearProcID, "Major Vuln ended")
        end
    end

    vulnTime = vulnTime - 1
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

    --was player who procced archdruid
    if(abilityId == bearProcID and nameTmp == cleanName(sourceName)) then
        processProc()
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
        if hitValue == 1 and archdruidTracker.savedVariables.trackVuln then 
            processVuln() 
        end
    end

end

--register for notifications about archdruid vulnerability proc
local function registerAlertsVuln()
    EVENT_MANAGER:RegisterForEvent("archVulnDebuff", EVENT_COMBAT_EVENT, combatReportVuln)
	EVENT_MANAGER:AddFilterForEvent("archVulnDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 176815)--major vulnerability abilityId, archdruid
end
 
--unregister for notifications about archdruid vulnerability proc
local function unRegisterAlertsVuln()
    EVENT_MANAGER:UnregisterForEvent("archVulnDebuff", EVENT_COMBAT_EVENT)
end

--register for notifications about archdruid proc
local function registerAlerts()
    EVENT_MANAGER:RegisterForEvent("archDebuff", EVENT_COMBAT_EVENT, combatReport)
    EVENT_MANAGER:AddFilterForEvent("archDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED)
    EVENT_MANAGER:AddFilterForEvent("archDebuff", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, bearProcID)
end

--unregister for notifications about archdruid proc
local function unRegisterAlerts()
    EVENT_MANAGER:UnregisterForEvent("archDebuff", EVENT_COMBAT_EVENT)
end

--when UI opens
local function onMenuOpened()
	isMenuOpen = true
    archAddonText:SetHidden(true)
end

--when UI closes
local function onMenuClosed()
	isMenuOpen = false
    if archdruidTracker.savedVariables.trackArch and isEquiped and archdruidTracker.savedVariables.autoTrack then
        archAddonText:SetHidden(false)
    elseif archdruidTracker.savedVariables.trackArch and not archdruidTracker.savedVariables.autoTrack then
        archAddonText:SetHidden(false)
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
    archAddonText:ClearAnchors()
    archAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

--change icon anchor to move text around the screen
local function setAnchorIcon(x, y)  
    archAddonText:SetHidden(false)
	zo_callLater(function () if isMenuOpen == true then archAddonText:SetHidden(true) end end, 2000)
    archAddonText:ClearAnchors()
    archAddonText:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
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

    if archdruidTracker.savedVariables.trackArch and archdruidTracker.savedVariables.autoTrack then
        printMessage("Archdruid set not found")
        unRegisterAlerts()
        archAddonText:SetHidden(true)
        unRegisterAlertsVuln()
    end
end

--start tracking if set is not equipped
local function startTrackingAuto()
    if archdruidTracker.savedVariables.trackArch and archdruidTracker.savedVariables.autoTrack then
        printMessage("Found Archdruid set")
        registerAlerts()
        archAddonText:SetHidden(false)
    end

    if archdruidTracker.savedVariables.trackVuln then
        registerAlertsVuln()
    end
end

--handle equipment change callbacks
local function onEquipmentChanged(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason)
    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then 
        zo_callLater(function ()
	if isSetEquiped(setId, setCount) and archdruidTracker.savedVariables.autoTrack and archdruidTracker.savedVariables.trackArch then startTrackingAuto() else stopTrackingAuto() end
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
        name = "Archdruid Tracker",
        displayName = "Archdruid Tracker",
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
            name = "Track Cooldown",
            tooltip = "Displays a timer while the Archdruid cooldown is active.\nDisabling this option will also disable tracking the Major Vulnerability debuff.",
            getFunc = function()
                return archdruidTracker.savedVariables.trackArch
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.trackArch = value
                if not value then
                    unRegisterAlerts()
                else
                    registerAlerts()
                end
            end,
            default = archdruidTracker.defaults.trackArch,
        },
        {
            type = "checkbox",
            name = "Auto Track",
            tooltip = "The Add-on will automatically detect if you are wearing all the pieces of the correct set and enable/disable tracking.\nFor auto track to work the tracking option above must be enabled.",
            getFunc = function()
                return archdruidTracker.savedVariables.autoTrack
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.autoTrack = value
            end,
            default = archdruidTracker.defaults.autoTrack,
        },
        {
            type = "checkbox",
            name = "Track Debuff",
            tooltip = "Displays a smaller timer that tracks the Archdruid Major Vulnerability debuff.\nTo track the Major Vulnerability debuff tracking for the cooldown needs to be enabled.",
            getFunc = function()
                return archdruidTracker.savedVariables.trackVuln
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.trackVuln = value
				if not value then
                    unRegisterAlertsVuln()
                else
                    registerAlertsVuln()
                end
            end,
            default = archdruidTracker.defaults.trackVuln,
        },
        {
            type = "slider",
            name = "Icon and Text x Position",
            tooltip = "Adjust the left and right position of the on screen icon and timer text.",
            min = 0, max = 1700, step = 10,
            getFunc = function()
                return archdruidTracker.savedVariables.xAxisTextArch
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.xAxisTextArch = value
                setAnchorIcon(archdruidTracker.savedVariables.xAxisTextArch, archdruidTracker.savedVariables.yAxisTextArch)
            end,
            default = archdruidTracker.defaults.xAxisTextArch,
        },
        {
            type = "slider",
            name = "Icon and Text y Position",
            tooltip = "Adjust the up and down position of the on screen icon and timer text.",
            min = 0, max = 1000, step = 10,
            getFunc = function()
                return archdruidTracker.savedVariables.yAxisTextArch
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.yAxisTextArch = value
                setAnchorIcon(archdruidTracker.savedVariables.xAxisTextArch, archdruidTracker.savedVariables.yAxisTextArch)
            end,
            default = archdruidTracker.defaults.yAxisTextArch,
        },
		{
            type = "checkbox",
            name = "Notification Vuln",
            tooltip = "Displays a notification and plays a sound when the Major Vulnerability debuff has finished.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return archdruidTracker.savedVariables.notifyVuln
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.notifyVuln = value
            end,
            default = archdruidTracker.defaults.notifyVuln,
        },
		{
            type = "checkbox",
            name = "Notification End",
            tooltip = "Displays a notification and plays a sound when the Archdruid cooldown finishes and the set is ready to proc again.\nThe settings for the notification can be changed in the LibNotify Add-on options.",
            getFunc = function()
                return archdruidTracker.savedVariables.notifyEnd
            end,
            setFunc = function(value)
                archdruidTracker.savedVariables.notifyEnd = value
            end,
            default = archdruidTracker.defaults.notifyEnd,
        },
        {
            type = "divider",
            height = 0,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel("Archdruid Tracker New", panelData)
    LAM:RegisterOptionControls("Archdruid Tracker New", optionsData)
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
    archdruidTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("archAddonVars", 1, "Settings", archdruidTracker.defaults, GetUnitName("player"))

    --setup add on menu options
    createOptions()

    --register for callbacks when an equiped piece of gear is added or removed
    enableCallbacksGear()

	--notify about new library
	if not isLibAvailable() then
		zo_callLater(function() printMessage("add-on Disabled") printMessage("Please install LibNotify from the browse add-ons menu") end, 400)
		return
	elseif  isLibAvailable() and archdruidTracker.savedVariables.trackArch then
		--notify that add-on has been loaded
	    zo_callLater(function() printMessage("add-on loaded") end, 400)
	end

    --check if set is equipped
    if not isSetEquiped(setId, setCount) and archdruidTracker.savedVariables.autoTrack and archdruidTracker.savedVariables.trackArch then
        --notify set not found
        zo_callLater(function() printMessage("Archdruid set not found") end, 600)
    elseif isSetEquiped(setId, setCount) and archdruidTracker.savedVariables.autoTrack and archdruidTracker.savedVariables.trackArch then
        isEquiped = true
        --notify set found
        zo_callLater(function() printMessage("Found Archdruid set") end, 600)
    end

    --double check if set is equipped without autotracking stipulation
    if isSetEquiped(setId, setCount) then isEquiped = true end

    --setup text field areas
    archAddonText:SetMovable(true)
    archAddonTextIcon:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_54)|soft-shadow-thick")
    archAddonTextLabelTime:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_54)|soft-shadow-thick")
    archAddonTextLabelVuln:SetFont("$(GAMEPAD_BOLD_FONT)|$(GP_34)|soft-shadow-thick")
    archAddonTextIcon:SetText(iconText)
    archAddonTextLabelTime:SetText("")
    archAddonTextLabelTime:SetColor(255, 255, 0, 255)
    archAddonTextLabelVuln:SetText("")
    archAddonTextLabelVuln:SetColor(255, 255, 0, 255)

    setAnchorStartupIcon(archdruidTracker.savedVariables.xAxisTextArch, archdruidTracker.savedVariables.yAxisTextArch)

    --register for combat alerts if tracking is enabled
    if archdruidTracker.savedVariables.trackArch and not archdruidTracker.savedVariables.autoTrack then
        registerAlerts()
        archAddonText:SetHidden(false)
    elseif archdruidTracker.savedVariables.trackArch and archdruidTracker.savedVariables.autoTrack and isEquiped then
        registerAlerts()
        archAddonText:SetHidden(false)
    elseif archdruidTracker.savedVariables.trackArch and archdruidTracker.savedVariables.autoTrack and not isEquiped then
        archAddonText:SetHidden(true)
    elseif not archdruidTracker.savedVariables.trackArch then
        archAddonText:SetHidden(true)
    end

    --register for combat alerts if tracking is enabled for major vulnerability
    if archdruidTracker.savedVariables.trackVuln  and isEquiped then
        registerAlertsVuln()
    end

    --register for notifications of menu or map opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", onSceneStateChange)

    --set is loaded boolean for use later, to stop scene change hiding tracker icon at first load in
    zo_callLater(function () isLoaded = true end, 2000)
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, onAddOnLoaded)

