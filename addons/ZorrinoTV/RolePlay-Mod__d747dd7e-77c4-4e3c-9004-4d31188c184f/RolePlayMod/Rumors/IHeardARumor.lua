if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- French interface; official POI names and descriptions come from the live client.
local function IsFrench()
    return string.lower(GetCVar("language.2") or "en") == "fr"
end
local function L(text)
    return IsFrench() and IHR_FR and IHR_FR.text[text] or text
end
local function FormatName(text)
    return zo_strformat("<<C:1>>", text or "")
end
local function ServiceLabel(service)
    return IsFrench() and IHR_FR and IHR_FR.services[service] or service
end
local function SamePlace(englishName, clientName)
    local target = zo_strlower(FormatName(clientName))
    if zo_strlower(FormatName(englishName)) == target then return true end
    local names = IHR_FR and IHR_FR.towns[englishName]
    for _, name in ipairs(names or {}) do
        if zo_strlower(FormatName(name)) == target then return true end
    end
    return false
end

ZO_CreateStringId("SI_BINDING_NAME_IHR_ASK_FOR_INFORMATION", L("Ask for Information"))
IHeardARumor = IHeardARumor or {}
IHeardARumor.RumorsWindow = nil
IHeardARumor.RumorsButton = nil
TamrielServiceMap = TamrielServiceMap or {}

local available_services = {}
local isServiceWindowOpen = false
--=======================--
local MINIMUM_DISTANCE = 0.04
local MID_DISTANCE = 0.2
 local playerPinVar = false




local originalShowPin
local function HidePlayerPin()
    local pin = ZO_MapPin0
    if pin then
        pin:SetHidden(true)
        originalShowPin = originalShowPin or pin.SetHidden
        pin.SetHidden = function()  end -- Prevent re-showing
    end
end

local function ShowPlayerPin()
    local pin = ZO_MapPin0
    -- The pin may not exist yet, and hiding may never have been requested.
    if pin and originalShowPin then
        pin.SetHidden = originalShowPin
        originalShowPin = nil
        pin:SetHidden(false)
    end

end


local function TogglePlayerPin(value)
    --ModifyPlayerPinLayout(value)
    if value then
        HidePlayerPin()
    else
        ShowPlayerPin()

    end
    IHeardARumor.savedVars.hidePlayerPin = value
    playerPinVar = value
end

local prevX = 0
local prevY = 0
local services_window = WINDOW_MANAGER:CreateTopLevelWindow("IHeardARumor_ServicesWindow")

local function ShowSimpleDialog(title, text, buttonText)
    ZO_Dialogs_RegisterCustomDialog("RPN_TEMP_DIALOG", {
        title = { text = title },
        mainText = { text = text },
        buttons = {
            {
                text = buttonText or L("Close"),
                callback = function() end,
            },
        },
    })
    zo_callLater(function()
        ZO_Dialogs_ShowDialog("RPN_TEMP_DIALOG")
    end, 200)
end

local DIRECTION_NAMES = {
    [1] = L("east"), L("southeast"), L("south"), L("southwest"),
    L("west"), L("northwest"), L("north"), L("northeast"),L("east")
}

local directionThresholds = {
    [1] = 22.5, 67.5, 112.5, 157.5, 202.5, 247.5, 292.5, 337.5, 360
}


local function CloseServicesWindow()
    --d('Close Signal Received')

    services_window:SetHidden(true)
    if IHeardARumor.RumorsWindow then
        isServiceWindowOpen = false
        IHeardARumor.RumorsWindow:SetHidden(true)
    end


end

--=======================--


local function clampDegrees(deg)
    return deg % 360
end

local function getDirectionFromDegrees(deg)
    deg = clampDegrees(deg)
    --d("DEG:" .. tostring(deg))
    for i, threshold in ipairs(directionThresholds) do
        if deg < threshold then return DIRECTION_NAMES[i] end
    end
    return DIRECTION_NAMES[1]  -- Wraps to L("east")
end

local function getZoneName()
    return GetZoneName(GetUnitZoneIndex("player"))
end

local function getSubZoneName()
    local mapName = GetMapName()
    return mapName ~= "" and mapName or getZoneName()
end

local function getPlayerPosition()
    if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    return GetMapPlayerPosition("player")
end


--===========================--


local function GetServiceLocation(serviceName, subZoneName)
    local prefix = serviceName .. "::"
    for key, entry in pairs(TamrielServiceMap or {}) do
        if key:sub(1, #prefix) == prefix and SamePlace(entry.subZoneId, subZoneName) then
            return entry
        end
    end
    return nil
end

local function getPoiDirections(indexP)
	if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
	end

    local playerX, playerY = GetMapPlayerPosition("player")

	if GetMapContentType() == MAP_CONTENT_DUNGEON or GetMapType() == MAPTYPE_SUBZONE then
		MapZoomOut()
		zoneName = GetMapName()
		zoneMapId = GetCurrentMapIndex()
		playerX, playerY = GetMapPlayerPosition("player")
	end

    local zoneIndex = GetUnitZoneIndex("player")
    local poiX, poiY = GetPOIMapInfo(zoneIndex, indexP)
    local name, _, icon, _, _, isHidden, _, poiType, isShownInCurrentMap = GetPOIInfo(zoneIndex, indexP)
    local dx = poiX - playerX
    local dy = poiY - playerY

    --d('POI:'.. tostring(name) .. tostring(poiX) .."|".. tostring(poiX))
    --d("POI: " .. tostring(indexP))
    local distance = math.sqrt(dx * dx + dy * dy)
    --d("POI distance: " .. tostring(distance))
    local angle = math.atan2(dy, dx)
    local deg = math.deg(angle) --

    if deg > 360 then
        deg = deg - 360
    end
    if deg < 0 then
        deg = deg + 360
    end
    local direction = "--"

    if deg >= 337.5 or deg < 22.5 then
        direction = L("east of here")
    elseif deg < 67.5 then
        direction = L("southeast of here")
    elseif deg < 112.5 then
        direction = L("south of here")
    elseif deg < 157.5 then
        direction = L("southwest of here")
    elseif deg < 202.5 then
        direction = L("west of here")
    elseif deg < 247.5 then
        direction = L("northwest of here")
    elseif deg < 292.5 then
        direction = L("north of here")
    else
        direction = L("northeast of here")
    end


    local distancePhrase = ""
    if distance < MINIMUM_DISTANCE then
        distancePhrase =  L("Right here!")

    elseif distance < 0.05 then
        distancePhrase = L("It's actually really close!")
    elseif distance < 0.1 then
        distancePhrase = L("you're almost there.")
    elseif distance < 0.15 then
        distancePhrase = L("You can easily walk there.")
    elseif distance < MID_DISTANCE then
        distancePhrase = L("it's not that far... I think.")
    elseif distance < 0.3 then
        distancePhrase = L("You could get there by walking, but with a horse is better")
    elseif distance < 0.4 then
        distancePhrase = L("It's actually a pretty good walk, remember to take some supplies with you on the road if you're willing to travel there.")
    else
        distancePhrase = L("And It's a pretty long journey... you better be ready.")
    end

    return  direction, distancePhrase, distance
end



local function PrepareZoneMap()
    if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    if GetMapContentType() == MAP_CONTENT_DUNGEON or GetMapType() == MAPTYPE_SUBZONE then
        MapZoomOut()
    end
end

local function ChooseZonePOI(zoneIndex, new)
    PrepareZoneMap()
    local candidates = {}
    for index = 1, GetNumPOIs(zoneIndex) do
        local name = GetPOIInfo(zoneIndex, index)
        local x, y, _, _, shown = GetPOIMapInfo(zoneIndex, index)
        if name and name ~= "" and type(x) == "number" and type(y) == "number"
            and (x ~= 0 or y ~= 0) and x >= 0 and x <= 1 and y >= 0 and y <= 1
            and shown then
            candidates[#candidates + 1] = index
        end
    end
    if not new and IHeardARumor.lastPOIZone == zoneIndex then
        for _, index in ipairs(candidates) do
            if index == IHeardARumor.lastPOI then return index end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(1, #candidates)]
end

local function SaveZonePOIsToFile(indexPOI)
    if not indexPOI then
        local empty = IsFrench() and "Je n’ai aucun renseignement précis sur les environs."
            or "I have no precise information about the area."
        return empty, empty
    end
    local zoneIndex = GetUnitZoneIndex("player")
    local rawName, _, startDescription, finishedDescription = GetPOIInfo(zoneIndex, indexPOI)
    local name = FormatName(rawName)
    local directions, distancePhrase = getPoiDirections(indexPOI)
    local _, _, pinType = GetPOIMapInfo(zoneIndex, indexPOI)
    local description = startDescription
    if pinType == MAP_PIN_TYPE_POI_COMPLETE and finishedDescription and finishedDescription ~= "" then
        description = finishedDescription
    end
    local location = IsFrench() and string.format("%s ? C’est %s. %s", name, directions, distancePhrase)
        or string.format("%s? It's %s. %s", name, directions, distancePhrase)
    -- Reuse the game's map description; never invent events or dangers.
    if type(description) == "string" and description ~= "" then
        location = location .. "\n\n" .. zo_strformat(description)
    end
    return location, location
end

local function GetDirectionsToService(serviceX, serviceY)
    local px, py = getPlayerPosition()
    local dx, dy = serviceX - px, serviceY - py
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = math.deg(math.atan2(dy, dx))
    local dir = getDirectionFromDegrees(angle)

    local distTxt = (dist < 0.045 and L("Right here!"))
        or (dist < 0.07 and L("(Gesturing with their chin)"))
        or (dist < 0.12 and L("It's just over there."))
        or (dist < 0.15 and L("It's close, actually."))
        or (dist < 0.2 and L("A couple houses that way."))
        or (dist < 0.3 and L("On the other side."))
        or (dist < 0.4 and L("You going to walk a bit."))
        or L("I think it's on the other side of town.")

    return dir, distTxt, dist
end


local function GetServicesForSubZone(subZoneName)
    local result = {}
    local found = false
    local b2TXT = L("Nevermind")
    for key, entry in pairs(TamrielServiceMap or {}) do
        found = true

        if type(entry) == "table" and SamePlace(entry.subZoneId, subZoneName) then
            b2TXT = L("Services")
            table.insert(result, entry.service)
        end
    end
    if not found then
        d(L("[RPN - Rumors]: 'Tamriel_Data.lua' NOT FOUND for this Zone. (yet)"))
    end


    return result,b2TXT
end


local bgControl

local function ShowServiceList(npcNAME, servicesAround)
    if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    isServiceWindowOpen = true
    local services = servicesAround


    local windowHeight = 10+(33*#services)
    --d(#services, windowHeight)
    local topWindow = services_window
    topWindow:ClearAnchors()
    topWindow:SetDimensions(300, windowHeight)
    topWindow:SetAnchor(CENTER, GuiRoot, CENTER, 0, 10)
    topWindow:SetMovable(true)
    topWindow:SetMouseEnabled(true)
    topWindow:SetClampedToScreen(true)
    topWindow:SetHidden(false)

    SCENE_MANAGER:ShowTopLevel(topWindow, true)
    PushActionLayerByName("UI_SHORTCUT_PRIMARY")
    CHAT_SYSTEM:Minimize()


    if bgControl and not bgControl:IsHidden() then
        bgControl:SetHidden(true)
        bgControl:ClearAnchors()
        bgControl:SetParent(nil)
        bgControl = nil
    end


    bgControl = WINDOW_MANAGER:CreateControl(nil, topWindow, CT_BACKDROP)
    bgControl:SetAnchorFill()
    bgControl:SetCenterColor(0, 0, 0, 0.6)
    bgControl:SetEdgeColor(1, 1, 1, 1)
    bgControl:SetEdgeTexture(nil, 1, 1, 1, 1)
    StartChatInput()
    CHAT_SYSTEM:Minimize()
    --  Build clean new list
    for i, service in ipairs(services) do
        --d('Loading: ' .. service)

        local button = WINDOW_MANAGER:CreateControl(nil, bgControl, CT_BUTTON)
        button:SetFont("ZoFontGamepad18")
        button:SetText(ServiceLabel(service))
        button:SetDimensions(250, 30)
        button:SetAnchor(CENTER, bgControl, TOP, 0, 30 + (i - 1) * 32)
        button:SetClickSound("Click")
        button:SetMouseEnabled(true)
        button.serviceName = service

        button:SetHandler("OnClicked", function(self)
            local subZone = GetMapName()
            local entry = GetServiceLocation(self.serviceName, subZone)
            local caption = FormatName(GetUnitCaption("reticleover"))
            if entry then
                local dir, distText, distRaw = GetDirectionsToService(entry.mapX, entry.mapY)
                local response

                if self.serviceName == npcNAME or ServiceLabel(self.serviceName) == caption then
                    response = L("You're in the right place. Are you looking for me?")
                elseif distText == L("Right here!") then
                    response = L("Right here! Take a look around.")
                else
                    response = string.format(L("%s? That way - (%s). %s"), ServiceLabel(self.serviceName), dir, distText)
                end

                services_window:SetHidden(true)

                ShowSimpleDialog(L("Directions"), response, L("Thanks."))
            else
                d(string.format(L("[RolePlayMod] %s not found in %s"), self.serviceName, subZone))
                ShowSimpleDialog(L("Hmm..."), L("I’m not sure where that is, sorry."), L("Okay."))
            end
        end)
    end
end


--=============================--
local function ShowRumorDialogForZone(npcNAME ,new)
    local zoneIndex = GetUnitZoneIndex("player")
    local POI_I = ChooseZonePOI(zoneIndex, new)
    local zoneTXT, _ = SaveZonePOIsToFile(POI_I)



    ZO_Dialogs_RegisterCustomDialog("RPN_RUMORS_DIALOG", {
    title = { text = npcNAME },
    mainText = { text = zoneTXT},
    buttons = {
    {
    text = L("Really? (Follow Rumor)"),
    callback = function()
        IHeardARumor.lastPOI = POI_I
        IHeardARumor.lastPOIZone = zoneIndex
    end
    },
    {
    text = L("What else?"),
    callback = function()
        ShowRumorDialogForZone(npcNAME,true)
    end
    },

    }
    })

    zo_callLater(function()
        ZO_Dialogs_ShowDialog("RPN_RUMORS_DIALOG")
    end, 500)

end



function IsTargetFriendlyNPC()
    if isServiceWindowOpen then
        services_window:SetHidden(true)
        isServiceWindowOpen = false
    else
        PlayEmoteByIndex(46)
        local unitTag = "reticleover"
        local zoneIndex = GetUnitZoneIndex("player")
        if not DoesUnitExist(unitTag) then
            d(L("There's nobody there."))
            return false
        end

        local POI_I = ChooseZonePOI(zoneIndex, false)

        local reaction = GetUnitReaction(unitTag)
        if reaction == UNIT_REACTION_FRIENDLY or reaction == 2 or reaction == 5 then
            local npcName = FormatName(GetUnitName(unitTag))
            local greeting = zo_strformat(L("<<C:1>> says: 'Hello there.'"), npcName)
            local POI_REACT = POI_I
            local _, worldX, worldY = GetUnitWorldPosition("player")
            prevX, prevY = worldX, worldY

            local _, rumorText = SaveZonePOIsToFile(POI_REACT)
            if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
                CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
            end
            local SZ = getSubZoneName()
            local servicesAround,b2TXT = GetServicesForSubZone(SZ)
            --local b2TXT = L("Nevermind")
            ZO_Dialogs_RegisterCustomDialog("RPN_RUMORS_DIALOG_RUMOR", {
                title = { text = L("Rumors") },
                mainText = { text = rumorText },
                buttons = {
                    {
                        text = L("Thanks!"),
                        callback = function()
                            services_window:SetHidden(true)
                        end,
                    },
                    {
                        text = L("What else?"),
                        callback = function()
                            ShowRumorDialogForZone(npcName, true)
                        end
                    },
                }
            })

            ZO_Dialogs_RegisterCustomDialog("RPN_RUMORS_DIALOG_HELLO", {
                title = { text = L("Talk") },
                mainText = { text = greeting },
                buttons = {
                    {
                        text = L("Rumor"),
                        callback = function()
                            services_window:SetHidden(true)
                            IHeardARumor.lastPOI = POI_REACT
                            IHeardARumor.lastPOIZone = zoneIndex
                            zo_callLater(function()
                                ZO_Dialogs_ShowDialog("RPN_RUMORS_DIALOG_RUMOR")
                            end, 500)
                        end
                    },
                    {
                        text = b2TXT,
                        callback = function()
                            if #servicesAround > 0 then
                                --   local SZ = getSubZoneName()
                                --   local servicesA,b2TXT = GetServicesForSubZone(SZ)

                                ShowServiceList(npcName, servicesAround)
                            end

                        end
                    },
                }
            })

            zo_callLater(function()
                ZO_Dialogs_ShowDialog("RPN_RUMORS_DIALOG_HELLO")
            end, 500)
        else
            d(L("That's not a friendly NPC."))
        end

    end
end


-- Compatibility with RolePlayNeeds' radial menu and chat command.
SLASH_COMMANDS["/askforinfo"] = IsTargetFriendlyNPC

local NPC_ROLES = {
    ["Innkeeper"] = {
        ["en"] = "Innkeeper",
        ["fr"] = "Aubergiste",
        ["de"] = "Gastwirt",
        ["jp"] = "宿屋",
        ["es"] = "Tabernero",
        ["ptbr"] = "Estalajadeiro",
    },
    ["Brewer"] = {
        ["en"] = "Brewer",
        ["fr"] = "Brasseur",
        ["de"] = "Brauer",
        ["jp"] = "醸造者",
        ["es"] = "Cervecero",
        ["ptbr"] = "Cervejeiro",
    },
    ["Chef"] = {
        ["en"] = "Chef",
        ["fr"] = "Chef",
        ["de"] = "Küchenchef",
        ["jp"] = "シェフ",
        ["es"] = "Chef",
        ["ptbr"] = "Chefe",
    },
}
local function IsRoleCaption(caption)
    local lang = GetCVar("Language.2")
    if lang == "pt" then lang = "ptbr" end

    for _, translations in pairs(NPC_ROLES) do
        if translations[lang] and string.find(caption, translations[lang]) then
            return true
        end
    end
    return false
end

local function OnAddOnLoaded(event, addonName)
    if addonName ~= "RolePlayMod" then return end
    -- Discard obsolete runtime-only fields from older saved-variable tables.
    IHeardARumor.Base = nil
    IHeardARumor.Beta = nil
    IHeardARumor.savedVars = RolePlayMod.Storage("base", function() return IHeardARumor.savedVars or {} end, {hidePlayerPin=false})
    playerPinVar = IHeardARumor.savedVars.hidePlayerPin or false
    TogglePlayerPin(playerPinVar)
    local panelData = {
    type = "panel",
    name = L("RolePlayNeeds - I Heard A Rumor"),
    displayName = L("I Heard A Rumor"),
    version = "0.6.0-beta.1",
    registerForRefresh = true,
    registerForDefaults = true,
}
local optionsTable = {
    {
        type = "checkbox",
        name = L("Hide Player Map Pin"),
        tooltip = L("Hides the player pin on the map to make self-discovery more immersive.\n TIP: (To hide your companion, you must open your map, on the right side tabs and uncheck 'Companions' in 'Pins')"),
        getFunc = function() return IHeardARumor.savedVars.hidePlayerPin or false end,
        setFunc = function(value) TogglePlayerPin(value) end,
        default = false,
    },

}

    local LAM = LibAddonMenu2
    local panelName = "IHeardARumor_OptionsPanel"
    -- Options are provided by the single RolePlayMod panel.

    EVENT_MANAGER:UnregisterForEvent("IHeardARumor", EVENT_ADD_ON_LOADED)


end


EVENT_MANAGER:RegisterForEvent("IHeardARumor", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForUpdate("MovementTrackerRumor", 300, function()
        local xa, worldX, worldY, xb = GetUnitWorldPosition("player")

        if prevX and prevY then
            if  worldX ~= prevX and worldY ~= prevY then
              CloseServicesWindow()
              isServiceWindowOpen= false
            end
            prevX = worldX
            prevY = worldY
        end


    end)



SLASH_COMMANDS["/serviceshere"] = function()
    local subzone = getSubZoneName()
    local available_services,_ = GetServicesForSubZone(subzone)
    d(L("Services in ") .. subzone .. ":")
    for _, s in ipairs(available_services) do d(" - " .. ServiceLabel(s)) end
end
-- Narrow bridge for the beta: keep the original service database and calculations.
IHR_Runtime = IHR_Runtime or {}
IHR_Runtime.Base = {
    TogglePlayerPin = TogglePlayerPin,
    GetServices = GetServicesForSubZone,
    GetService = GetServiceLocation,
    ServiceLabel = ServiceLabel,
    ServiceDirections = GetDirectionsToService,
    SubZone = getSubZoneName,
    SamePlace = SamePlace,
    PrepareMap = PrepareZoneMap,
    ChoosePOI = ChooseZonePOI,
    Rumor = SaveZonePOIsToFile,
    POIDirections = getPoiDirections,
}
