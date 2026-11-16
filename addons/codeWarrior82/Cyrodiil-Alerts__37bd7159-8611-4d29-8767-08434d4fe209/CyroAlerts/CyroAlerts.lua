
--todo
--add map pins for doors at keeps in cyrodiil
--maybe add shalks and other armour debuffs
--shattered rocks, arcanist stun and maybe others

appName = "CyroAlerts"

appStart = {}
appStart.appVersion = 1  -- bump this on each update
appStart.isVamp = false
appStart.vampStage = 0
appStart.loaded = false
appStart.currentZone = 0
appStart.corrosiveID = 17879
appStart.onslaughtID = 83229
appStart.wellPinsIcon = "CyroAlerts/pins.dds"
appStart.wellPinsName = "CyroWellPins"
appStart.hammerPinsIcon = "CyroAlerts/hammerPins.dds"
appStart.hammerPinsName = "CyroHammerPins"
appStart.LMP = LibMapPins
appStart.isMenuOpen = false

appStart.defaults = {
    alertsEnabled = true,
    alertStatusEnabled = true,
    combatState = true,
    showVampStage = true,
    trackVampireStage = true,
    trackCorrosive = true,
    trackOnslaught = true,
    yAxisText = 0,
    xAxisText = 1380,
    yAxisTextCorro = 210,
    xAxisTextCorro = 640,
    yAxisTextOnslaught = 270,
    xAxisTextOnslaught = 640,
    showWellMapPins = false,
    showHammerMapPins = false,
    lastSeenVersion = 0
}

--check if LibNotify is available
local function isLibAvailable()
    if LibNotify and type(LibNotify.notifyForAddonPlease) == "function" then
        return true
    else 
		return false
    end
end

--start function once addon has been loaded
function appStart.OnAddOnLoaded(event, name)

    --if add-on loaded was not this add-on quit
    if name ~= appName then
        return
    end

    --unregister for notifications of add-on loaded
    EVENT_MANAGER:UnregisterForEvent(appName, EVENT_ADD_ON_LOADED)

    --load saved variables
    appStart.savedVariables = ZO_SavedVars:NewCharacterIdSettings("cyrodiilAlertsSavedVariables", 1, "Settings", appStart.defaults, GetUnitName("player"))

    --notify about new library
	if not isLibAvailable() then
		zo_callLater(function() functions.printMessage("add-on Disabled") functions.printMessage("Please install LibNotify from the browse add-ons menu") end, 500)
		return
    elseif isLibAvailable() then
		--notify that add-on has been loaded
		zo_callLater(function() functions.printMessage("add-on loaded") end, 500)
	end

    --load text positions from saved vars
    cyroText:SetMovable(true)
    combatStateText:SetMovable(true)
    vampText:SetMovable(true)
    corrosiveText:SetMovable(true)
    onslaughtText:SetMovable(true)
    functions.setAnchor(appStart.savedVariables.xAxisText, appStart.savedVariables.yAxisText)
    functions.setAnchorCorro(appStart.savedVariables.xAxisTextCorro, appStart.savedVariables.yAxisTextCorro)
    functions.setAnchorOnslaught(appStart.savedVariables.xAxisTextOnslaught, appStart.savedVariables.yAxisTextOnslaught)

    --setup alerts active text
    cyroTextLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    if appStart.savedVariables.alertsEnabled then
        cyroTextLabel:SetText("Alerts - Active")
    else
        cyroTextLabel:SetText("Alerts - Inactive")
    end
    if appStart.savedVariables.alertStatusEnabled then
        functions.showAlertText()
    else
        functions.hideAlertText()
    end

    --setup combat state text
    combatStateTextLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    combatStateTextLabel:SetColor(0, 204, 0, 255)
    combatStateTextLabel:SetText("Not in Combat")
    if appStart.savedVariables.combatState then
        --register for combat state notifications
        EVENT_MANAGER:RegisterForEvent(appName, EVENT_PLAYER_COMBAT_STATE, functions.combatStatusChanged)
    else
        combatStateTextLabel:SetHidden(true)
    end

    --setup vamp state text
    vampTextLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_36)|soft-shadow-thick")
    vampTextLabel:SetColor(125, 0, 255, 255)
    if not appStart.savedVariables.showVampStage then
        functions.hideVamp()
    end

    --check for vampire status
    functions.vampStatus()

    --setup corrosive alert text
    corrosiveTextLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_61)|soft-shadow-thick")
    corrosiveTextLabel:SetHidden(true)
    local preText = "|cFF0000Alert |r "
    local iconText = zo_iconTextFormat("esoui/art/icons/ability_dragonknight_018_b.dds", 60, 60, " ")
    corrosiveTextLabel:SetText(iconText .. preText .. "Corrosive Armour Near")

    --register for combat event alerts, for dk corrosive
    if appStart.savedVariables.trackCorrosive then
        EVENT_MANAGER:RegisterForEvent(appName, EVENT_COMBAT_EVENT, functions.combatAlert)
        EVENT_MANAGER:AddFilterForEvent(appName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, appStart.corrosiveID)
    end

    --setup onslaught alert text
    onslaughtTextLabel:SetFont("$(GAMEPAD_MEDIUM_FONT)|$(GP_61)|soft-shadow-thick")
    onslaughtTextLabel:SetHidden(true)
    local preTextOn = "|cFF0000Alert |r "
    local iconTextOn = zo_iconTextFormat("esoui/art/icons/ability_onslaught.dds", 60, 60, " ")
    onslaughtTextLabel:SetText(iconTextOn .. preTextOn .. "Onslaught User Near")

    --register for combat event alerts, for onslaught
    if appStart.savedVariables.trackOnslaught then
        EVENT_MANAGER:RegisterForEvent("onslaughtAlert", EVENT_COMBAT_EVENT, functions.combatAlertOn)
        EVENT_MANAGER:AddFilterForEvent("onslaughtAlert", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, appStart.onslaughtID)
    end

    --register for zone change notifications, leaving this always active
    EVENT_MANAGER:RegisterForEvent(appName, EVENT_PLAYER_ACTIVATED, functions.zoneChanged)

    --setup map pins for ayleid wells
    functions.registerPins()

    --show or hide ayleid well map pins map pins
    if appStart.savedVariables.showWellMapPins then
        appStart.LMP:Enable(appStart.wellPinsName)
        appStart.LMP:SetEnabled(appStart.wellPinsName, true)
    else
        appStart.LMP:Disable(appStart.wellPinsName)
        appStart.LMP:SetEnabled(appStart.wellPinsName, false)
    end

    --setup map pins for volendrung spawn locations
    functions.registerPinsHammer()

    --show or hide volendrung map pins
    if appStart.savedVariables.showHammerMapPins then
        appStart.LMP:Enable(appStart.hammerPinsName)
        appStart.LMP:SetEnabled(appStart.hammerPinsName, true)
    else
        appStart.LMP:Disable(appStart.hammerPinsName)
        appStart.LMP:SetEnabled(appStart.hammerPinsName, false)
    end

    --register for notifications of UI opening
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", functions.onSceneStateChange)

    --setup options menu
    functions.createOptions()
end

--register for notification that an addon has been loaded
EVENT_MANAGER:RegisterForEvent(appName, EVENT_ADD_ON_LOADED, appStart.OnAddOnLoaded)
