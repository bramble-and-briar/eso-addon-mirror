if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
ZO_CreateStringId("SI_BINDING_NAME_RPN_CHECK_NEEDS", "Consulter mes besoins")
ZO_CreateStringId("SI_BINDING_NAME_RPN_TAKE_NAP", "Prendre un repos partiel")
local meters = {
    hunger = {
        iconPaths = {
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_01.dds",
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_02.dds",
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_02.dds",
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_02.dds",
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_03.dds",
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_03.dds",
            "RolePlayMod/Survival/ui/icon_food_meat_chunk_03.dds",
            "RolePlayMod/Survival/ui/wheel/eatW.dds",
            "RolePlayMod/Survival/ui/wheel/eatW.dds",
            "RolePlayMod/Survival/ui/wheel/eatW.dds",
        }
    },
    water = {
        iconPaths = {
            "RolePlayMod/Survival/ui/icon_water_01.dds",
            "RolePlayMod/Survival/ui/icon_water_02.dds",
            "RolePlayMod/Survival/ui/icon_water_02.dds",
            "RolePlayMod/Survival/ui/icon_water_02.dds",
            "RolePlayMod/Survival/ui/icon_water_03.dds",
            "RolePlayMod/Survival/ui/icon_water_03.dds",
            "RolePlayMod/Survival/ui/icon_water_03.dds",
            "RolePlayMod/Survival/ui/wheel/drinkW.dds",
            "RolePlayMod/Survival/ui/wheel/drinkW.dds",
            "RolePlayMod/Survival/ui/wheel/drinkW.dds",
        }
    },

    alcohol = {
        iconPaths = {
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
            "RolePlayMod/Survival/ui/icon_alcohol.dds",
        }
    },
    fatigue = {
        iconPaths = {
            "RolePlayMod/Survival/ui/fatigue1.dds",
            "RolePlayMod/Survival/ui/fatigue2.dds",
            "RolePlayMod/Survival/ui/fatigue3.dds",
            "RolePlayMod/Survival/ui/wheel/restW.dds",
        }
    },



}

local function containsString(str, substr)
    return string.find(str, substr) ~= nil
end
local function CATCHER(needle)
    for i = 1, GetNumEmotes() do

    local slashName, category, command, isHidden, isEmote = GetEmoteInfo(i)          -- BY NAME METHOD
    if containsString(slashName, needle) or containsString(command, needle) then
        d(string.format("%d: %s", i, slashName, command))
    end

    end
end

local wm = GetWindowManager()
local em = GetEventManager()
local lastInventoryState = {}
local IconTimer = 500
local messageCD = 0
local messageTimer = 0
local isWheelOpen = false
RolePlayNeeds = RolePlayNeeds or {}
function RolePlayNeeds.SetWheelOpen(value) isWheelOpen=not not value end
RolePlayNeeds.name = "RolePlayMod"
RolePlayNeeds.version = "0.8.3-FR.1"

local estimatedSpeed = 1
local function IsAnyMainUIOpen()
    return not SCENE_MANAGER:IsShowing("hud")
end
RolePlayNeeds.settings = {
    survivalModeOn = true,
    alpha = 50,
    diseaseChance = 1,
    hungerTickSeconds = 750,
    waterTickSeconds = 750,
    diseaseTickSeconds = 300,
    alcoholTickSeconds = 180,
    diseasesMechanicEnabled = true,
    MAX_FATIGUE = 2500,
    partialRestsRemaining = 2, -- persisted; only an inn night resets this allowance
    fatigueLv = 0,
    fatigueMultiplier = 5,
    recoverFatigueMultiplier = 5,
    restingEmoteIndex = 119,
    eatEmoteIndex = 168,
    drinkEmoteIndex = 8,
    emptyIconsOpacity = 50,
    hasDisease = false,
    diseaseLv= -1,
    diseaseOverlayalpha1= 0.75,
    diseaseOverlayalpha2= 0.75,
    diseaseOverlayalpha3= 0.75,
    canEatRaw = false,
    canDrinkRaw = true,
    hunger = {
        opacity_max = 100,
        opacity_empty = 50,
        x = GuiRoot:GetWidth() * 0.65,
        y = GuiRoot:GetHeight() * 0.93,
        shown = true,
        currentStage = 4,
    },
    water = {
        opacity_max = 100,
        opacity_empty = 100,
        x = GuiRoot:GetWidth() * 0.65 + 30,
        y = GuiRoot:GetHeight() * 0.93,
        shown = true,
        currentStage = 4,
    },
    alcohol = {
        opacity_max = 100,
        opacity_empty = 100,
        x = GuiRoot:GetWidth() * 0.65 + 90,
        y = GuiRoot:GetHeight() * 0.93,
        shown = true,
        currentStage = 1,
    },
    fatigue = {
        opacity_max = 100,
        opacity_empty = 100,
        x = GuiRoot:GetWidth() * 0.65 + 60,
        y = GuiRoot:GetHeight() * 0.93,
        shown = true,
        currentStage = 4,
    },

}
local isMount = false
EVENT_MANAGER:RegisterForEvent("MountTracker", EVENT_MOUNTED_STATE_CHANGED, function(_, isMounted)
    isMount = isMounted
end)

local prevX, prevY
local isMoving = false
local isFighting = false
local isCatchingBreath = false
local RESTING_EMOTE = 119

GlobalclockTicker = 0
RolePlayNeeds.hunger = {}
RolePlayNeeds.water = {}
RolePlayNeeds.alcohol = {}
RolePlayNeeds.fatigue = {}
RolePlayNeeds.isEmoting = false


local function UpdateStage(meterName, stage)
    if not RolePlayMod.Enabled(meterName) then return end
    local meter = RolePlayNeeds[meterName]
    local settings = RolePlayNeeds.settings



    if meterName == "fatigue" then

        if stage < 1 then stage = 1 end
        if stage > #meters[meterName].iconPaths then stage = #meters[meterName].iconPaths end
        stage = RolePlayNeeds.settings.fatigueLv
        --d(meter.currentStage .. tostring(RolePlayNeeds.settings.fatigueLv))
        local FSTG4 = RolePlayNeeds.settings.MAX_FATIGUE - ((RolePlayNeeds.settings.MAX_FATIGUE/100)*95)
        local FSTG3 = RolePlayNeeds.settings.MAX_FATIGUE - ((RolePlayNeeds.settings.MAX_FATIGUE/100)*80)
        local FSTG2 = RolePlayNeeds.settings.MAX_FATIGUE - ((RolePlayNeeds.settings.MAX_FATIGUE/100)*60)
        local FSTG1 = RolePlayNeeds.settings.MAX_FATIGUE - ((RolePlayNeeds.settings.MAX_FATIGUE/100)*35)
        local FSTG0 = RolePlayNeeds.settings.MAX_FATIGUE - ((RolePlayNeeds.settings.MAX_FATIGUE/100)*15)

        if stage <= FSTG4  then      -- 85%
            --d(FSTG4)
            meter.currentStage = 4
        elseif stage <= FSTG3 then
--            d(FSTG3)
            meter.currentStage = 3
        elseif stage <= FSTG2 then
--            d(FSTG2)
            meter.currentStage = 3
        elseif stage <= FSTG1 then
--            d(FSTG1)
            meter.currentStage = 2
        elseif stage <= FSTG0 then
--            d(FSTG0)
            meter.currentStage = 2
        elseif stage <= RolePlayNeeds.settings.MAX_FATIGUE then
            --d("MAX!")
            meter.currentStage = 1
        end
        if meter.texture then
            meter.texture:SetTexture(meters[meterName].iconPaths[meter.currentStage])
        end
    else
        local meter = RolePlayNeeds[meterName]
        local settings = RolePlayNeeds.settings
        if stage < 1 then stage = 1 end
        if stage > #meters[meterName].iconPaths then stage = #meters[meterName].iconPaths end
        meter.currentStage = stage
        local fs = stage or 1
        settings[meterName].currentStage = fs
        if meter.texture then
            meter.texture:SetTexture(meters[meterName].iconPaths[stage])
        end


    end


end

-- Resource deficits use the character's actual maximum, never a fixed stat value.
local function GetResourceDeficit(powerType)
    local current, maximum = GetUnitPower("player", powerType)
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or current
    if maximum <= 0 then return 0 end
    return math.max(0, math.min(1, (maximum - current) / maximum))
end

-- Units of fatigue per second, before the existing gain/recovery multiplier.
local function GetActivityFatigueRate(speed)
    if RolePlayNeeds.FatigueRules then return RolePlayNeeds.FatigueRules.GetRate(speed) end
    return 0
end

EVENT_MANAGER:RegisterForEvent("CombatTracker", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
    if inCombat then
        isFighting = true
    else
        isFighting = false

    end
end)
local function ClampFatigue(value)
    local clamped = math.min(math.max(value, 0), RolePlayNeeds.settings.MAX_FATIGUE)

    return clamped
end


function GetRandomCraftMessage()
    return CRAFT_MESSAGES[math.random(1, #CRAFT_MESSAGES)]
end
function GetRandomCollectMessage()
    return COLLECT_MESSAGES[math.random(1, #COLLECT_MESSAGES)]
end

EVENT_MANAGER:RegisterForEvent("RolePlayNeeds_Gathering", EVENT_LOOT_RECEIVED, function(_, receivedBy, itemName, itemName2, itemName3, itemName4, source)


    if RolePlayNeeds.settings.survivalModeOn and (itemName3 == 19 and RolePlayNeeds.settings.canDrinkRaw and not containsString(tostring(itemName),"Ichor") and not containsString(tostring(itemName),"Grease") ) then
        RolePlayNeeds.IncreaseWaterNeutral()
    end
    if RolePlayNeeds.settings.survivalModeOn and (itemName3 == 25 and RolePlayNeeds.settings.canEatRaw) then
        RolePlayNeeds.IncreaseHungerNeutral()
    end
    if RolePlayNeeds.settings.survivalModeOn and (itemName3 == 40 or itemName3 == 23 or itemName3==19 or itemName3 == 22 or itemName3 == 26 or itemName3 == 15 or itemName3 == 30 or itemName3 == 37  or itemName3 == 39) and(messageTimer <= 0) then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, GetRandomCollectMessage())
        messageTimer = 30
    end
end)
EVENT_MANAGER:RegisterForEvent("RolePlayNeeds_Crafting", EVENT_CRAFT_COMPLETED, function()
    if RolePlayNeeds.settings.survivalModeOn then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, GetRandomCraftMessage())
    end
end)



local previousMovementTime, previousMovementZone
EVENT_MANAGER:RegisterForUpdate("MovementTracker", 100, function()
    -- ESO world coordinates are zone, X, height, Z. Only X/Z measure travel.
    local getPosition = GetUnitRawWorldPosition or GetUnitWorldPosition
    local zone, worldX, _, worldZ = getPosition("player")
    local now = GetFrameTimeMilliseconds()
    local elapsed = previousMovementTime and (now - previousMovementTime) / 1000 or 0
    -- Do not count loading screens, pauses or map transitions as exertion.
    elapsed = math.max(0, math.min(1, elapsed))
    isMounted = IsMounted()
    messageTimer = messageTimer - 1
    if prevX and prevY and zone == previousMovementZone and elapsed > 0 then
        local dx, dz = worldX - prevX, worldZ - prevY
        local distanceSquared = dx * dx + dz * dz
        estimatedSpeed = math.sqrt(distanceSquared) / elapsed
        if distanceSquared > 0.0001 then
            if not isMoving then
                isMoving = true
                if RolePlayNeeds.isResting then
                    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Vous ne vous reposez plus.")
                    d("Vous ne vous reposez plus.")
                end
                RolePlayNeeds.isResting = false
                if isWheelOpen then
                    isWheelOpen = false
                    SLASH_COMMANDS["/mywheel"]()
                    SetGameCameraUIMode(false)
                end
            end
        else
            isMoving = false
        end
        local rate = GetActivityFatigueRate(estimatedSpeed)
        local multiplier = rate > 0 and (RolePlayNeeds.settings.fatigueMultiplier or 5)
            or (RolePlayNeeds.settings.recoverFatigueMultiplier or 5)
        RolePlayNeeds.settings.fatigueLv = ClampFatigue((RolePlayNeeds.settings.fatigueLv or 0) + rate * elapsed * multiplier / 5)
        if RolePlayNeeds.settings.survivalModeOn then UpdateStage("fatigue", RolePlayNeeds.settings.fatigueLv) end
        if RolePlayNeeds.FatigueRules then RolePlayNeeds.FatigueRules.EnforceWalkOnly(estimatedSpeed) end
    end
    prevX, prevY = worldX, worldZ
    previousMovementTime, previousMovementZone = now, zone
end)
local diseaseOverlay1 = WINDOW_MANAGER:CreateTopLevelWindow("DiseaseOverlay1")
local diseaseOverlay2 = WINDOW_MANAGER:CreateTopLevelWindow("DiseaseOverlay2")
local diseaseOverlay3 = WINDOW_MANAGER:CreateTopLevelWindow("DiseaseOverlay3")
local diseaseOverlays = {diseaseOverlay1, diseaseOverlay2, diseaseOverlay3}
local diseaseTextures = {"GREEN_OVERLAY.dds", "RED_OVERLAY.dds", "BLUE_OVERLAY.dds"}
local loadedDiseaseTextures = {}

local function InitDiseaseOverlay()
    for level, overlay in ipairs(diseaseOverlays) do
        overlay:SetAnchorFill()
        overlay:SetMouseEnabled(false)
        overlay:SetAlpha(RolePlayNeeds.settings['diseaseOverlayalpha'..level] or .75)
        overlay:SetHidden(true)
    end
end

function RolePlayNeeds.OnCombatEvent(eventCode, result, isError, abilityName,
                                     abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName,
                                     targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if RolePlayNeeds.settings.survivalModeOn then
        if targetType == COMBAT_UNIT_TYPE_PLAYER and sourceName then
        local lowerName = string.lower(sourceName)
        if RolePlayNeeds.settings.diseasesMechanicEnabled then
            local val =  math.random()
            if math.random() < (RolePlayNeeds.settings.diseaseChance/100) then
                local diseaseLV = 1
                local message = "Je ne me sens pas bien… Je suis peut-être malade."
                if val > 0.6 then
                    diseaseLV = 2
                    message = "Argh… Cette blessure me fait souffrir…"
                end
                if val > 0.9 then
                    diseaseLV = 3
                    message = "Ma tête… Que m’arrive-t-il ? Argh !"
                end
                RolePlayNeeds.ApplyDisease(message, diseaseLV)
            end

        end

    end
    end

end



EVENT_MANAGER:RegisterForEvent("RolePlayNeeds_DiseaseSystem", EVENT_COMBAT_EVENT, RolePlayNeeds.OnCombatEvent)
EVENT_MANAGER:AddFilterForEvent("RolePlayNeeds_DiseaseSystem", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE)

local function contains(str, needle)
    return string.find(string.lower(str), needle, 1, true) ~= nil
end


function RolePlayNeeds.OnInventoryChange(eventCode, bagId, slotId, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    local prevLink = lastInventoryState[bagId .. ":" .. slotId]
    local currentLink = GetItemLink(bagId, slotId)


    local itemLink = currentLink ~= "" and currentLink or prevLink

    if stackCountChange < 0 and itemLink and itemLink ~= "" then

        local itemName = GetItemLinkName(itemLink)
        local itemType, specializedItemType = GetItemLinkItemType(itemLink)
        --d(tostring(itemName) .."//".. tostring(itemType) .."//".. tostring(specializedItemType) .. "//" .. tostring(eventCode).. "//" .. tostring(isNewItem))
        if (RolePlayNeeds.diseaseLv == 1 and (specializedItemType == 150 or specializedItemType == 151 or specializedItemType == 152)) or ((specializedItemType == 150 or specializedItemType == 152) and RolePlayNeeds.diseaseLv == 2) or (specializedItemType == 151 and RolePlayNeeds.diseaseLv == 3) then
           RolePlayNeeds.CureDisease()
        end


        if specializedItemType == 20 then
            RolePlayNeeds.IncreaseAlcohol()
            RolePlayNeeds.IncreaseWater()

        elseif itemType == 7 then
            if (contains(itemName, 'stamina') or contains(itemName, 'vigueur')) and RolePlayNeeds.diseaseLv == 1 then
                RolePlayNeeds.CureDisease()
            elseif (contains(itemName, 'health') or contains(itemName, 'santé')) and RolePlayNeeds.diseaseLv == 2 then
                RolePlayNeeds.CureDisease()
            elseif (contains(itemName, 'magicka') or contains(itemName, 'magie')) and RolePlayNeeds.diseaseLv == 3 then
                RolePlayNeeds.CureDisease()
            end

        elseif itemType == ITEMTYPE_DRINK then
            RolePlayNeeds.IncreaseWater()
        elseif itemType == ITEMTYPE_FOOD then
            RolePlayNeeds.IncreaseHunger()
        end
    end


    lastInventoryState[bagId .. ":" .. slotId] = currentLink
end


function RPN_CheckNeeds()
    if RolePlayNeeds and RolePlayNeeds.CheckNeeds then
        RolePlayNeeds.CheckNeeds()
    else
        d("Les besoins ne sont pas encore disponibles.")
    end
end

local function StartTimers()

    local function tickHunger()
        local survivalModeOn = RolePlayNeeds.settings.survivalModeOn or false
        if survivalModeOn and RolePlayMod.Enabled("hunger") then
            local current = RolePlayNeeds.hunger.currentStage

            if current > 1 then
                UpdateStage("hunger", current - 1)
            end
        end
        zo_callLater(tickHunger, RolePlayNeeds.settings.hungerTickSeconds * 1000)
    end

    local function tickWater()
        local survivalModeOn = RolePlayNeeds.settings.survivalModeOn or false
        if survivalModeOn and RolePlayMod.Enabled("water") then
            local current = RolePlayNeeds.water.currentStage
            if current > 1
                then UpdateStage("water", current - 1)
            end
        end
        zo_callLater(tickWater, RolePlayNeeds.settings.waterTickSeconds * 1000)
    end

    local function tickDisease()
        local current = RolePlayNeeds.diseaseLv
            if current == 1 and RolePlayMod.Enabled("disease") then
                RolePlayNeeds.CureDisease()
            end
        zo_callLater(tickDisease, RolePlayNeeds.settings.diseaseTickSeconds * 1000)
    end
    zo_callLater(tickDisease, RolePlayNeeds.settings.diseaseTickSeconds * 1000)
    zo_callLater(tickHunger, RolePlayNeeds.settings.hungerTickSeconds * 1000)
    zo_callLater(tickWater, RolePlayNeeds.settings.waterTickSeconds * 1000)

end


local function CreateMeterUI(meterName)
    local meter = RolePlayNeeds[meterName]
    local settings = RolePlayNeeds.settings[meterName]


    if meter.control and meter.control:IsControlHidden() == false then
        meter.control:SetHidden(true)
    end


    local control = wm:CreateTopLevelWindow("RolePlayNeeds_" .. meterName .. "_Control")
    control:SetDimensions(32, 32)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.x, settings.y)
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:SetClampedToScreen(true)



    control:SetHandler("OnMouseUp", function(self)
        self:StopMovingOrResizing()
        local left, top = self:GetLeft(), self:GetTop()
        settings.x = left
        settings.y = top
    end)



    local tex = wm:CreateControl("$(parent)_Texture", control, CT_TEXTURE)
    tex:SetAnchorFill()

    meter.control = control
    meter.texture = tex

    if not meterName == "fatigue" then
        UpdateStage(meterName, settings.currentStage)
    end


    d("[Survie] Indicateur créé : " .. meterName)
    return meter

end



function RolePlayNeeds.ApplyDisease(diseaseMessage, lv )
    lv = lv or 1
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,  diseaseMessage )
    --d("[RPN]: " .. diseaseMessage )
    RolePlayNeeds.hasDisease = true
    RolePlayNeeds.diseaseLv = lv or 1
    RolePlayNeeds.settings.hasDisease = true
    RolePlayNeeds.settings.diseaseLv = lv or 1
    RolePlayNeeds.ShowDiseaseOverlay(true, lv)
end

function RolePlayNeeds.CureDisease()

    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je suis guéri ! Je me sens bien mieux.")
    --d("[RPN] I have been cured! I feel much better.")
    RolePlayNeeds.hasDisease = false
    RolePlayNeeds.diseaseLv = -1
    RolePlayNeeds.settings.hasDisease = false
    RolePlayNeeds.settings.diseaseLv = -1

    RolePlayNeeds.ShowDiseaseOverlay(false, -1)
    if not isMoving and not IsAnyMainUIOpen() then
        RolePlayMod.PlaySurvivalEmote(25)

    end
end

function RolePlayNeeds.ShowDiseaseOverlay(state, lv)
    for level, overlay in ipairs(diseaseOverlays) do
        if state and level == lv then
            if not loadedDiseaseTextures[level] then
                local texture = WINDOW_MANAGER:CreateControl(nil, overlay, CT_TEXTURE)
                texture:SetAnchorFill()
                texture:SetTexture("RolePlayMod/Survival/ui/"..diseaseTextures[level])
                loadedDiseaseTextures[level] = texture
            end
            overlay:SetHidden(false)
        else
            overlay:SetHidden(true)
        end
    end
end

function RolePlayNeeds.tickSober()
    local current = RolePlayNeeds.alcohol.currentStage
    if current > 1 then UpdateStage("alcohol", current - 1) end
    zo_callLater(RolePlayNeeds.tickSober, RolePlayNeeds.settings.alcoholTickSeconds * 1000)
end

function RolePlayNeeds.IncreaseHungerNeutral()
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    local current = RolePlayNeeds.hunger.currentStage or 10
    IconTimer = 500
    if current >= #meters.hunger.iconPaths then
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus faim…")
    return
    end
    UpdateStage("hunger", current + 5)
        if not isMoving and not IsAnyMainUIOpen() then
            RolePlayMod.PlaySurvivalEmote(9)

        end
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai mangé.")

end

function RolePlayNeeds.IncreaseHunger()
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    local current = RolePlayNeeds.hunger.currentStage or 10
    IconTimer = 500
    if current >= #meters.hunger.iconPaths then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus faim…")
        return
    end

    UpdateStage("hunger", current + 5)
        if not isMoving and not IsAnyMainUIOpen() then
            RolePlayMod.PlaySurvivalEmote(168)
        end
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai mangé.")

end

function RolePlayNeeds.IncreaseWater()
     RolePlayMod.PlaySurvivalEmote(8)
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    IconTimer = 500
    local current = RolePlayNeeds.water.currentStage or 10
    if current >= #meters.water.iconPaths then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus soif.")
        RolePlayNeeds.water.currentStage = #meters.water.iconPaths
        return
    end
    UpdateStage("water", current + 3)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai bu de l’eau.")
end
function RolePlayNeeds.IncreaseWaterNeutral()

     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    IconTimer = 500
    local current = RolePlayNeeds.water.currentStage or 10
    if current >= #meters.water.iconPaths then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus soif.")
        RolePlayNeeds.water.currentStage = #meters.water.iconPaths
        return
    end
    UpdateStage("water", current + 3)

        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai bu de l’eau.")
end
function RolePlayNeeds.IncreaseWater2()
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    IconTimer = 500
    local current = RolePlayNeeds.water.currentStage or 10
    if current >= #meters.water.iconPaths then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus soif.")
        RolePlayNeeds.water.currentStage = #meters.water.iconPaths
        return
    end
    UpdateStage("water", current + 3)
        if not isMoving and not IsAnyMainUIOpen() then
            RolePlayMod.PlaySurvivalEmote(173)
        end
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai bu de l’eau.")


end

function RolePlayNeeds.IncreaseWater3()
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    IconTimer = 500
    local current = RolePlayNeeds.water.currentStage or 10
    if current >= #meters.water.iconPaths then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus soif.")
        RolePlayNeeds.water.currentStage = #meters.water.iconPaths
        return
    end
    UpdateStage("water", current + 3)
        if not isMoving and not IsAnyMainUIOpen() then
            RolePlayMod.PlaySurvivalEmote(200)
        end
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai bu de l’eau.")


end

function RolePlayNeeds.IncreaseWaterSit()
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
    IconTimer = 500
    local current = RolePlayNeeds.water.currentStage or 10
    if current >= #meters.water.iconPaths then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je n’ai plus soif.")
        RolePlayNeeds.water.currentStage = #meters.water.iconPaths
        return
    end
    UpdateStage("water", current + 3)
        if not isMoving and not IsAnyMainUIOpen() then
            RolePlayMod.PlaySurvivalEmote(417)
        end
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil,"J’ai bu de l’eau.")


end

function RolePlayNeeds.IncreaseAlcohol()
     if isWheelOpen then
        SetGameCameraUIMode(false)
        SLASH_COMMANDS["/mywheel"]()
        isWheelOpen = false
     end
IconTimer = 500
local current = RolePlayNeeds.alcohol.currentStage or 1
    if not isMoving and not IsAnyMainUIOpen() then
        RolePlayMod.PlaySurvivalEmote(8)

    end
UpdateStage("alcohol", current + 2)
d("[Survie] Vous avez bu de l’alcool.")
end


function RolePlayNeeds.ResetHunger()
UpdateStage("hunger", 1)
d("[Survie] Faim réinitialisée : affamé.")
--RolePlayNeeds.HungerLoop()
end

function RolePlayNeeds.ResetWater()
UpdateStage("water", 1)
d("[Survie] Soif réinitialisée : assoiffé.")

end

function RolePlayNeeds.ResetAlcohol()
UpdateStage("alcohol", 1)
d("[Survie] Ivresse réinitialisée : sobre.")
    if not isMoving and not IsAnyMainUIOpen() then
        RolePlayMod.PlaySurvivalEmote(8)

    end

end

function RolePlayNeeds.GetNeedDescription(value, needType)
    value = tonumber(value) or 0
    if needType == "Food" then
        if value <= 1 then return "Je meurs de faim !"
        elseif value <= 3 then return "J’ai très faim."
        elseif value <= 5 then return "Je mangerais bien quelque chose."
        elseif value <= 7 then return "J’ai encore un peu faim."
        elseif value <= 10 then return "Je suis rassasié."
        else return "J’ai trop mangé…" end
    elseif needType == "Water" then
        if value <= 1 then return "Je suis déshydraté !"
        elseif value <= 3 then return "J’ai très soif."
        elseif value <= 5 then return "J’aurais besoin de boire."
        elseif value <= 7 then return "Je boirais bien une gorgée."
        elseif value <= 10 then return "Je n’ai plus soif."
        else return "J’ai trop bu d’eau…" end
    elseif needType == "Disease" then
        if value == 1 then return "Je me sens un peu malade. Je devrais voir un alchimiste."
        elseif value == 2 then return "Je suis malade. Il me faut un remède."
        elseif value == 3 then return "Je suis très malade ! Je dois trouver un alchimiste."
        else return "Je suis en bonne santé." end
    elseif needType == "Alcohol" then
        if value <= 1 then return "Je suis sobre."
        elseif value <= 2 then return "Je me sens d’humeur joyeuse."
        elseif value <= 5 then return "La tête me tourne un peu."
        elseif value <= 7 then return "Je suis ivre…"
        elseif value <= 9 then return "J’ai beaucoup trop bu…"
        else return "Je tiens à peine debout !" end
    elseif needType == "Fatigue" then
        local ratio = value / math.max(1, RolePlayNeeds.settings.MAX_FATIGUE)
        if ratio <= 0.05 then return "Je suis parfaitement reposé."
        elseif ratio <= 0.15 then return "Je me sens en pleine forme."
        elseif ratio <= 0.25 then return "Je me sens bien."
        elseif ratio <= 0.50 then return "J’ai besoin de reprendre mon souffle."
        elseif ratio <= 0.65 then return "Je suis fatigué. Une pause me ferait du bien."
        elseif ratio <= 0.85 then return "Je suis très fatigué. Il faut que je me repose."
        else return "Je suis épuisé ! Il me faut du sommeil." end
    end
    return ""
end

ZO_Dialogs_RegisterCustomDialog("RPN_FAKE_NOCURE_DIALOG", {
    title = { text = "Soigner la maladie" },
    mainText = { text = "Hum… Vous m’avez l’air en bonne santé. Buvez un peu plus d’eau." },
    buttons = {
        {
            text = SI_YES,
            callback = function()
                RolePlayNeeds.settings.hasDisease = false
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je suis guéri de ma maladie.")
                RolePlayNeeds.CureDisease()

            end
        },
        {
            text = SI_NO,
        }
    }
})
ZO_Dialogs_RegisterCustomDialog("RPN_FAKE_CURE_DIALOG", {
    title = { text = "Soigner la maladie" },
    mainText = { text = "Tenez, ceci devrait vous guérir.\n\n(L’alchimiste me propose un remède. Dois-je l’accepter ?)" },
    buttons = {
        {
            text = SI_YES,
            callback = function()
                RolePlayNeeds.settings.hasDisease = false
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Je suis guéri de ma maladie.")
                RolePlayNeeds.CureDisease()

            end
        },
        {
            text = SI_NO,
        }
    }
})



local function IsAlchemistVendor()

    for i = 1, GetNumStoreItems() do
        local itemTypeA, itemName, itemTypeD, itemTypeC, itemTypeX, itemTypeZ, itemType = GetStoreEntryInfo(i)
        local nameCheck = tostring(itemName)
        if contains(nameCheck, "poison") then
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "Un alchimiste ! Je pourrais lui demander un remède.")

            return true
        end
    end
    return false
end


function RolePlayNeeds.CureDialogOpen()
    zo_callLater(function()
        ZO_Dialogs_ShowDialog("RPN_FAKE_CURE_DIALOG")
    end, 500)
end

local NAP_SCREEN = nil

local function CreateNapFade()
    if not NAP_SCREEN then
        NAP_SCREEN = WINDOW_MANAGER:CreateTopLevelWindow("TakeANap_Blackout")
        NAP_SCREEN:SetAnchorFill(GuiRoot)
        NAP_SCREEN:SetDrawLayer(DL_OVERLAY)
        NAP_SCREEN:SetMouseEnabled(false)

        local blackBg = WINDOW_MANAGER:CreateControl("$(parent)_Bg", NAP_SCREEN, CT_BACKDROP)
        blackBg:SetAnchorFill()
        blackBg:SetCenterColor(0, 0, 0, 1)
        blackBg:SetEdgeColor(0, 0, 0, 0)
    end
    NAP_SCREEN:SetHidden(true)
end

local activeNap

function RolePlayNeeds.GetPartialRestsRemaining()
    local settings = RolePlayNeeds.settings
    if settings.partialRestsRemaining == nil then settings.partialRestsRemaining = 2 end
    return math.max(0, math.min(2, math.floor(tonumber(settings.partialRestsRemaining) or 0)))
end

function RolePlayNeeds.ApplyRestNeeds(fullRest)
    if RolePlayMod.Options().restConsumesNeeds==false then return end
    local costs=fullRest and {hunger=2,water=3} or {hunger=1,water=1}
    for key,cost in pairs(costs) do
        if RolePlayMod.Enabled(key) then
            local meter=RolePlayNeeds[key]
            if meter then UpdateStage(key,math.max(1,(tonumber(meter.currentStage) or 1)-cost)) end
        end
    end
    if RolePlayNeeds.NeedsHUD then RolePlayNeeds.NeedsHUD.Update() end
end

local function StartNap(duration, fullRest)
    local settings = RolePlayNeeds.settings
    if not settings or not RolePlayMod.Enabled(fullRest and "rooms" or "partialRests") then return false, "Ce type de repos est désactivé dans les options de RolePlayMod." end
    if activeNap then return false, "Vous êtes déjà en train de dormir." end
    if IsUnitInCombat("player") or IsUnitDead("player") or IsMounted() then
        return false, "Vous ne pouvez pas dormir dans cette situation."
    end
    local remaining = RolePlayNeeds.GetPartialRestsRemaining()
    if not fullRest and remaining == 0 then return false, "Vos deux repos partiels sont épuisés. Passez une nuit à l’auberge." end
    if not fullRest and settings.fatigueLv <= 1 then return false, "Vous êtes déjà reposé." end
    SetGameCameraUIMode(false)
    RolePlayNeeds.isResting = false
    RolePlayMod.PlaySurvivalEmote(118)
    CreateNapFade()
    NAP_SCREEN:SetAlpha(0)
    NAP_SCREEN:SetHidden(false)
    local zone, x, y, z = GetUnitWorldPosition("player")
    local nap = {started = GetFrameTimeMilliseconds(), zone = zone, x = x, y = y, z = z}
    activeNap = nap
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fadeIn = timeline:InsertAnimation(ANIMATION_ALPHA, NAP_SCREEN, 0)
    fadeIn:SetAlphaValues(0, 1); fadeIn:SetDuration(1000)
    local hold = timeline:InsertAnimation(ANIMATION_ALPHA, NAP_SCREEN, 1000)
    hold:SetAlphaValues(1, 1); hold:SetDuration(duration * 1000)
    local fadeOut = timeline:InsertAnimation(ANIMATION_ALPHA, NAP_SCREEN, 1000 + duration * 1000)
    fadeOut:SetAlphaValues(1, 0); fadeOut:SetDuration(1000)
    timeline:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT, 1)
    timeline:SetHandler("OnStop", function()
        if activeNap ~= nap then return end
        activeNap = nil
        EVENT_MANAGER:UnregisterForUpdate("RPNRestCycleWatch")
        NAP_SCREEN:SetHidden(true)
        -- An interrupted animation never grants recovery or consumes a short rest.
        if not nap.cancelled and RolePlayMod.Enabled(fullRest and "rooms" or "partialRests") and GetFrameTimeMilliseconds() - nap.started >= duration * 1000 + 2000 then
            if fullRest then
                settings.fatigueLv = 0
                settings.partialRestsRemaining = 2
                d("[Survie] Nuit complète : fatigue récupérée, deux repos partiels disponibles.")
            else
                settings.fatigueLv = math.max(0, settings.fatigueLv - settings.MAX_FATIGUE * 0.5)
                settings.partialRestsRemaining = remaining - 1
                d("[Survie] Repos partiel terminé. Repos restants : " .. settings.partialRestsRemaining .. "/2.")
            end
            UpdateStage("fatigue", settings.fatigueLv)
            RolePlayNeeds.ApplyRestNeeds(fullRest)
        end
        RolePlayMod.PlaySurvivalEmote(91)
    end)
    EVENT_MANAGER:RegisterForUpdate("RPNRestCycleWatch", 100, function()
        local currentZone, px, py, pz = GetUnitWorldPosition("player")
        if not RolePlayMod.Enabled(fullRest and "rooms" or "partialRests") or IsUnitInCombat("player") or IsUnitDead("player") or IsMounted()
            or zone ~= currentZone or (px-x)^2 + (py-y)^2 + (pz-z)^2 > 2500 then
            nap.cancelled = true
            timeline:Stop()
        end
    end)
    timeline:PlayFromStart()
    return true, fullRest and "Vous passez la nuit à l’auberge." or "Vous prenez un repos partiel."
end

function RolePlayNeeds.StartInnRest()
    return StartNap(5, true)
end


function RolePlayNeeds:CreateAlchemistWindow()
    if self.CureWindow then return end  -- Only once

    RolePlayNeeds.topWindow = WINDOW_MANAGER:CreateTopLevelWindow("DialogWindow")
    RolePlayNeeds.topWindow:SetDimensions(200, 50)
    RolePlayNeeds.topWindow:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 50, -150)  -- changed anchor here
    RolePlayNeeds.topWindow:SetMovable(true)
    RolePlayNeeds.topWindow:SetMouseEnabled(true)
    RolePlayNeeds.topWindow:SetClampedToScreen(true)
    RolePlayNeeds.topWindow:SetHidden(true)  -- Start hidden, keep as is


    RolePlayNeeds.bg = WINDOW_MANAGER:CreateControl(nil, RolePlayNeeds.topWindow, CT_BACKDROP)
    RolePlayNeeds.bg:SetAnchorFill()
    RolePlayNeeds.bg:SetCenterColor(0, 0, 0, 0.6)
    RolePlayNeeds.bg:SetEdgeColor(1, 1, 1, 1)
    RolePlayNeeds.bg:SetEdgeTexture(nil, 1, 1, 1, 1)


    RolePlayNeeds.btn_alch = WINDOW_MANAGER:CreateControl("RPN_AlchemistButton", RolePlayNeeds.topWindow, CT_BUTTON)
    RolePlayNeeds.btn_alch:SetDimensions(120, 30)
    RolePlayNeeds.btn_alch:SetAnchor(CENTER, topWindow, CENTER, 0, 0)
    RolePlayNeeds.btn_alch:SetText("Soigner la maladie")
    RolePlayNeeds.btn_alch:SetFont("ZoFontGamepad18")
    RolePlayNeeds.btn_alch:SetNormalFontColor(1, 1, 1, 1)
    RolePlayNeeds.btn_alch:SetMouseEnabled(true)
    RolePlayNeeds.btn_alch:SetHandler("OnClicked", function()
        if RolePlayNeeds.hasDisease then
            zo_callLater(function()
            ZO_Dialogs_ShowDialog("RPN_FAKE_CURE_DIALOG")
            end, 500)
        else
            zo_callLater(function()
            ZO_Dialogs_ShowDialog("RPN_FAKE_NOCURE_DIALOG")
            end, 500)
        end

    end)
    RolePlayNeeds.CureWindow = RolePlayNeeds.topWindow
    RolePlayNeeds.CureButton = RolePlayNeeds.btn_alch
end

function RolePlayNeeds.ShowCureButton(show)
    RolePlayNeeds.topWindow:SetHidden(not show)
end

function RolePlayNeeds.OnStoreClose()
    if RolePlayNeeds.CureWindow then
        RolePlayNeeds.CureWindow:SetHidden(true)
    end
end


function RolePlayNeeds.OnStoreOpen()
        if IsAlchemistVendor() then
            RolePlayNeeds:CreateAlchemistWindow()
            RolePlayNeeds.CureWindow:SetHidden(false)
        else
            if RolePlayNeeds.CureWindow then
                RolePlayNeeds.CureWindow:SetHidden(true)
            end
        end

end



local function ShowCenterMessage(text)
    local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
    messageParams:SetText(RPM_LOCALE.Text(text))
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_COUNTDOWN) -- Optional visual style
    messageParams:SetSound(SOUNDS.DUEL_START) -- Optional
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
end

local function AnnounceWhiteText(text)
    local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
    params:SetText(RPM_LOCALE.Text(text))
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end


SLASH_COMMANDS["/logmarker"] = function()
PingMap(MAP_PIN_TYPE_USER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, 0.5, 0.5)

end
local function UpdateRadialStatus()
    if MyFakeRadialButton5 then
        local status = ""
        if RolePlayNeeds.settings.survivalModeOn then
            status = "Mode survie : activé"
            MyFakeRadialButton5:SetNormalTexture("RolePlayMod/Survival/ui/wheel/survivalG.dds")
            MyFakeRadialButton5:SetPressedTexture("RolePlayMod/Survival/ui/wheel/survivalR.dds")
            MyFakeRadialButton5:SetMouseOverTexture("RolePlayMod/Survival/ui/wheel/survivalG.dds")

        else
            status = "Mode survie : désactivé"
            MyFakeRadialButton5:SetNormalTexture("RolePlayMod/Survival/ui/wheel/survivalR.dds")
            MyFakeRadialButton5:SetPressedTexture("RolePlayMod/Survival/ui/wheel/survivalG.dds")
            MyFakeRadialButton5:SetMouseOverTexture("RolePlayMod/Survival/ui/wheel/survivalR.dds")

        end
        if status and MyFakeRadialHoverLabel then
            MyFakeRadialHoverLabel:SetText(status)
        end
end
end
function RolePlayNeeds.CheckNeeds()

    local need1 = RolePlayNeeds.GetNeedDescription(RolePlayNeeds.hunger.currentStage, "Food")
    local need2 = RolePlayNeeds.GetNeedDescription(RolePlayNeeds.water.currentStage, "Water")
    local need3 = RolePlayNeeds.GetNeedDescription(RolePlayNeeds.alcohol.currentStage, "Alcohol")
    local need4 = RolePlayNeeds.GetNeedDescription(RolePlayNeeds.diseaseLv, "Disease")
    local need5 = RolePlayNeeds.GetNeedDescription(RolePlayNeeds.settings.fatigueLv, "Fatigue")
    if RolePlayNeeds.settings.survivalModeOn then
        IconTimer = 500
    else
        messageCD = 200
        IconTimer = 0
    end

            --d(RolePlayNeeds.diseaseLv)

    if RolePlayNeeds.diseaseLv > 0 and RolePlayMod.Enabled("disease") then

        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need4)
    end
    if RolePlayNeeds.alcohol.currentStage > 1 and RolePlayMod.Enabled("alcohol") then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need3)
    end
    if RolePlayNeeds.isResting == true and RolePlayNeeds.settings.survivalModeOn then
        if messageCD <= 0 then
            if RolePlayMod.Enabled("hunger") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need1) end
            if RolePlayMod.Enabled("water") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need2) end
            if RolePlayMod.Enabled("fatigue") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need5) end

            messageCD = 120
        else
           if not isWheelOpen then
             SLASH_COMMANDS["/mywheel"]()
             isWheelOpen = true
             UpdateRadialStatus()
           end
        end
    else
        if messageCD <= 0 and RolePlayNeeds.settings.survivalModeOn  then
            if RolePlayMod.Enabled("hunger") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need1) end
            if RolePlayMod.Enabled("water") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need2) end
            if RolePlayMod.Enabled("fatigue") then ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, need5) end

            messageCD = 120
        else
           if not isWheelOpen then
             SLASH_COMMANDS["/mywheel"]()
             isWheelOpen = true
           elseif isWheelOpen then
             SLASH_COMMANDS["/mywheel"]()
             isWheelOpen = false
           end

        end
    end

end

function RolePlayNeeds:ForceInventoryScan()
    for slotId = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if HasItemInSlot(BAG_BACKPACK, slotId) then
            local itemLink = GetItemLink(BAG_BACKPACK, slotId)
            lastInventoryState[BAG_BACKPACK .. ":" .. slotId] = itemLink
        end
    end
end


function RolePlayNeeds.OnUpdateFunction()

    local houseId = GetCurrentZoneHouseId()
    if houseId ~= 0 then
        RolePlayNeeds.isIndoors = true
    end
    if messageCD > 0 then
       messageCD = messageCD - 1
    end
    if not RolePlayNeeds.settings.survivalModeOn then
        if IconTimer > 0 then
            if RolePlayNeeds['hunger'].texture then
                RolePlayNeeds['hunger'].texture:SetAlpha(0)
            end
            if RolePlayNeeds['water'].texture then
                RolePlayNeeds['water'].texture:SetAlpha(0)
            end
            if RolePlayNeeds['alcohol'].texture then
                RolePlayNeeds['alcohol'].texture:SetAlpha(0)
            end
            if RolePlayNeeds['fatigue'].texture then
                RolePlayNeeds['fatigue'].texture:SetAlpha(0)
            end
        end
    end
    if IconTimer > 0 then
        if RolePlayNeeds.settings.survivalModeOn then

            if RolePlayNeeds['hunger'].texture then
                RolePlayNeeds['hunger'].texture:SetAlpha(IconTimer/200)
            end
            if RolePlayNeeds['water'].texture then
                RolePlayNeeds['water'].texture:SetAlpha(IconTimer/200)
            end
            if RolePlayNeeds['alcohol'].texture then
                RolePlayNeeds['alcohol'].texture:SetAlpha(IconTimer/200)
            end
            if RolePlayNeeds['fatigue'].texture then
                RolePlayNeeds['fatigue'].texture:SetAlpha(IconTimer/200)
            end

        end
        IconTimer = IconTimer - 1



    else --FADE
        local staminaDelta = GetResourceDeficit(POWERTYPE_STAMINA or 3)

        if RolePlayNeeds.settings.survivalModeOn then

            if RolePlayNeeds.hunger.currentStage == 1  then
                RolePlayNeeds['hunger'].texture:SetAlpha(RolePlayNeeds.settings.emptyIconsOpacity/100)
            end
            if RolePlayNeeds.water.currentStage == 1 then
                RolePlayNeeds['water'].texture:SetAlpha(RolePlayNeeds.settings.emptyIconsOpacity/100)
            end

        end

        local FSTG0 = RolePlayNeeds.settings.MAX_FATIGUE - ((RolePlayNeeds.settings.MAX_FATIGUE/100)*15)

        if RolePlayNeeds.settings.fatigueLv > FSTG0  or staminaDelta > 0 then
            staminaDelta = 0
            RolePlayNeeds['fatigue'].texture:SetAlpha(RolePlayNeeds.settings.emptyIconsOpacity/100)
        else
            RolePlayNeeds['fatigue'].texture:SetAlpha(IconTimer/200)
            --RolePlayNeeds['fatigue'].texture:SetAlpha()
        end
        if RolePlayNeeds.isResting then
           RolePlayNeeds['fatigue'].texture:SetAlpha(RolePlayNeeds.settings.emptyIconsOpacity/100)
        end
        if RolePlayNeeds.water.currentStage == 1 then
            RolePlayNeeds['alcohol'].texture:SetAlpha(RolePlayNeeds.settings.alpha/100)
        end

    end
    if RolePlayNeeds['fatigue'].texture then
        local staminaDelta = GetResourceDeficit(POWERTYPE_STAMINA or 3)
        local magickaDelta = GetResourceDeficit(POWERTYPE_MAGICKA or 2)
        if staminaDelta > 0 or magickaDelta > 0 then

            RolePlayNeeds['fatigue'].texture:SetAlpha(0.7) -- MAXHOLD
        else
            if not RolePlayNeeds.isResting and RolePlayNeeds.settings.survivalModeOn then
               RolePlayNeeds['fatigue'].texture:SetAlpha(IconTimer/200)
            end

        end
    end


    if GlobalclockTicker then
        GlobalclockTicker = GlobalclockTicker + 1
    end

    if GlobalclockTicker > 120 then

        local currentFatigue = RolePlayMod.Enabled("fatigue") and (RolePlayNeeds.settings.fatigueLv or 0) or 0
        GlobalclockTicker = 0

        local currentFood = RolePlayMod.Enabled("hunger") and (RolePlayNeeds.hunger.currentStage or 10) or 10
        local currentWater = RolePlayMod.Enabled("water") and (RolePlayNeeds.water.currentStage or 10) or 10
        local currentAlcohol = RolePlayMod.Enabled("alcohol") and (RolePlayNeeds.alcohol.currentStage or 1) or 1
        local currentDisease = RolePlayMod.Enabled("disease") and RolePlayNeeds.hasDisease or false


        if not isMoving and not IsAnyMainUIOpen() and not isMount and not RolePlayNeeds.isResting and not isFighting and RolePlayNeeds.settings.survivalModeOn then
            if currentAlcohol > 9 then
                RolePlayMod.PlaySurvivalEmote(115)
            elseif isBurning then
                RolePlayMod.PlaySurvivalEmote(27)
            elseif currentDisease == true then
                --d(RolePlayNeeds.settings.diseaseLv)
                local specialAnimationIdle1 = 114
                local specialAnimationIdle2 = 114

                if RolePlayNeeds.settings.diseaseLv == 1 then
                    specialAnimationIdle1 = 90
                    specialAnimationIdle2 = 90
                elseif RolePlayNeeds.settings.diseaseLv == 3 then
                    specialAnimationIdle1 = 141
                    specialAnimationIdle2 = 141
                end
                if currentFatigue > RolePlayNeeds.settings.MAX_FATIGUE-((RolePlayNeeds.settings.MAX_FATIGUE/100)*65) then
                    specialAnimationIdle2 = 96
                end
                local numbers = { specialAnimationIdle1,specialAnimationIdle2,specialAnimationIdle1,specialAnimationIdle2, 114,114}
                local chance = math.random() < 0.12
                local choice = numbers[math.random(#numbers)]
                if chance then
                    RolePlayMod.PlaySurvivalEmote(choice)
                end

            elseif currentFatigue > RolePlayNeeds.settings.MAX_FATIGUE-((RolePlayNeeds.settings.MAX_FATIGUE/100)*15) or isCatchingBreath then
                RolePlayMod.PlaySurvivalEmote(114)
            elseif currentFood == 1 or currentWater == 1 then
                if currentAlcohol > 3 then
                    RolePlayMod.PlaySurvivalEmote(115)
                else
                    RolePlayMod.PlaySurvivalEmote(114)
                end
            elseif currentAlcohol > 5 then
                RolePlayMod.PlaySurvivalEmote(79)
            elseif currentAlcohol > 3 then
                RolePlayMod.PlaySurvivalEmote(139)
            end

        end

    end

end

    EVENT_MANAGER:RegisterForUpdate("RPNAddon_UpdateLoop", 0, function(...) return RolePlayNeeds.OnUpdateFunction(...) end)



function RolePlayNeeds.MakeMenu()
    local menu = LibAddonMenu2
    if not menu then
        d("LibAddonMenu2 est nécessaire pour ouvrir les réglages. Installez cette bibliothèque.")
        return
    end

    local set = RolePlayNeeds.settings

    local panel = {
        type = "panel",
        name = "RolePlayNeeds — Survie en Tamriel",
        displayName = "Survie en Tamriel",
        version = RolePlayNeeds.version,
    }

    local options = {
        {
                type = "header",
                name = "Besoins vitaux",
        },
        {
            type = "checkbox",
            name = "Mode survie",
            tooltip = "Activer ensemble la faim, la soif, la fatigue et les maladies.",
            getFunc = function() return set.survivalModeOn end,
            setFunc = function(value)
                set.survivalModeOn = value
                d("Mode survie : " .. tostring(value))
            end,
            default = true,
        },
        {
            type = "slider",
            name = "Délai entre les pertes de satiété",
            tooltip = "Délai en secondes avant de perdre un niveau de satiété.\nAugmentez cette valeur pour avoir faim moins souvent.",
            min = 2,
            max = 1200,
            step = 2,
            getFunc = function() return set.hungerTickSeconds end,
            setFunc = function(value)
                set.hungerTickSeconds = value
                RolePlayNeeds.settings.hungerTickSeconds = value
                d(tostring(RolePlayNeeds.settings.hungerTickSeconds) .. " secondes entre les pertes de satiété.")
            end,
            default = 600,
        },
        {
            type = "slider",
            name = "Délai entre les pertes d’hydratation",
            tooltip = "Délai en secondes avant de perdre un niveau d’hydratation.\nAugmentez cette valeur pour avoir soif moins souvent.",
            min = 1,
            max = 1200,
            step = 1,
            getFunc = function() return set.waterTickSeconds end,
            setFunc = function(value)
                set.waterTickSeconds = value
                d(tostring(RolePlayNeeds.settings.waterTickSeconds) .. " secondes entre les pertes d’hydratation.")
            end,
            default = 600,
        },
                {
            type = "slider",
            name = "Vitesse d’épuisement",
            tooltip = "5 = cycle de 360 minutes au calme. Course ×1,25 ; sprint estimé ×3 ; combat ×2. Augmenter pour accélérer l’épuisement.",
            min = 1,
            max = 20,
            step = 1,
            getFunc = function() return set.fatigueMultiplier end,
            setFunc = function(value)
                set.fatigueMultiplier = value

            end,
            default = 5,
        },
        {
            type = "slider",
            name = "Vitesse de récupération",
            tooltip = "Récupération assise uniquement. À 5, une jauge complète demande 180 minutes de repos assis ; rester debout ne restaure rien.",
            min = 1,
            max = 20,
            step = 1,
            getFunc = function() return set.recoverFatigueMultiplier end,
            setFunc = function(value)
                set.recoverFatigueMultiplier = value

            end,
            default = 7,
        },


 {
            type = "dropdown",
            name = "Animation de repos",
            tooltip = "Choisir l’animation utilisée lorsque votre personnage se repose.",
            choices = {
                "S’asseoir",
                "Méditer",
                "Se détendre",
                "Se détendre (2)",
                "Se détendre (3)",
                "S’asseoir, genou replié",
                "S’asseoir sur une chaise",
                "Somnoler",
                "Dormir",
                "Dormir, épuisé",
                "Guimauve*",
                "Lire assis*",

            },
            choicesValues = {
                99,  -- Sit on ground //sit1
                119,  -- Meditate //sit2
                120,  -- Relax 1 //sit3
                121,  -- Relax 2 // sit4
                123,  -- Relax 3 // sit6
                122, -- Sit down // sit5
                100,   -- Sit Chair // sitchair
                116,   -- Sleep side // sleep2
                118,   -- Sleep Belly Up // sleep
                115,   -- Playdead // sleep
                320,   -- Marshmallow Rest // Extra Emote
                386,   -- Reading  Rest    // Extra Emote
            },


            getFunc = function()

                for i, v in ipairs({
                99,  -- Sit on ground //sit1
                119,  -- Meditate //sit2
                120,  -- Relax 1 //sit3
                121,  -- Relax 2 // sit4
                123,  -- Relax 3 // sit6
                122, -- Sit down // sit5
                100,   -- Sit Chair // sitchair
                116,   -- Sleep side // sleep2
                118,   -- Sleep Belly Up // sleep
                115,   -- Playdead // sleep
                320,   -- Marshmallow Rest // Extra Emote
                386,   -- Reading  Rest    // Extra Emote
            }) do
                    if v == set.restingEmoteIndex then

                        return v
                    end
                end
                return 119
            end,
            setFunc = function(selectedLabel)
                set.restingEmoteIndex = selectedLabel

            end,
            default = 119,
        },
         {
            type = "dropdown",
            name = "Animation de repas",
            tooltip = "Choisir l’animation utilisée pour manger depuis la roue.",
            choices = {
                "Manger de la viande",
                "Manger du pain lentement",
                "Manger une pomme",
                "Manger",
                "Manger une tourte",
                "Manger de la soupe",
                "Manger un petit pain",
                "Manger du pain rapidement",
                "Prendre un repas",
                "Fromage hurlant*",
                "Guimauve*",
                "Soupe épicée*",
            },
            choicesValues = {
                168,
                9,
                177,
                201,
                207,
                208,
                209,
                176,
                210,
                356,
                320,
                329,
            },

            getFunc = function()

                for i, v in ipairs({
                168,
                9,
                177,
                201,
                207,
                208,
                209,
                176,
                210,
                356,
                320,
                329,
            }) do
                if v == set.eatEmoteIndex then
                    return v
                end
                end
                return 168
            end,
            setFunc = function(selectedLabel)
                set.eatEmoteIndex = selectedLabel

            end,
            default = 168,
        },
       {
            type = "dropdown",
            name = "Animation de boisson",
            tooltip = "Choisir l’animation utilisée pour boire depuis la roue.",
            choices = {
                "Boire à la chope",
                "Boire au verre",
                "Boire à la bouteille",
                "Boire assis (1)",
                "Boire dans une corne*",
                "Boire dans un crâne*",
                "Boire assis (2)",

            },
            choicesValues = {
                8,
                173,
                200,
                284,
                287,
                417,
                350,
            },


            getFunc = function()

                for i, v in ipairs({
                8,
                173,
                200,
                417,
                284,
                287,
                350,
            }) do
                    if v == set.drinkEmoteIndex then

                        return v
                    end
                end
                return 8
            end,
            setFunc = function(selectedLabel)
                set.drinkEmoteIndex = selectedLabel

            end,
            default = 8,
        },
        {
            type = "checkbox",
            name = "Manger les aliments récoltés",
            tooltip = "La récolte de nourriture apaise la faim. Désactivé par défaut.",
            getFunc = function() return set.canEatRaw end,
            setFunc = function(value)
                set.canEatRaw = value
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = "Boire l’eau récoltée",
            tooltip = "La récolte d’eau apaise la soif. Activé par défaut.",
            getFunc = function() return set.canDrinkRaw end,
            setFunc = function(value)
                set.canDrinkRaw = value
            end,
            default = true,
        },
        {
            type = "slider",
            name = "Opacité des icônes de besoin",
            tooltip = "Opacité maximale des anciennes icônes lorsqu’un besoin est critique.",
            min = 0,
            max = 100,
            step = 2,
            getFunc = function() return set.emptyIconsOpacity end,
            setFunc = function(value)
                set.emptyIconsOpacity = value
            end,
            default = 50,
        },
        {
                type = "header",
                name = "Maladies",
        },
        {
            type = "checkbox",
            name = "Maladies",
            tooltip = "Activer les maladies du mod.",
            getFunc = function() return set.diseasesMechanicEnabled end,
            setFunc = function(value)
                set.diseasesMechanicEnabled = value
                RolePlayNeeds.CureDisease()
            end,
            default = true,
        },
        {
            type = "slider",
            name = "Risque de maladie",
            tooltip = "Régler le risque de contracter une maladie.",
            min = 0,
            max = 100,
            step = 1,
            getFunc = function() return set.diseaseChance end,
            setFunc = function(value)
                set.diseaseChance = value

            end,
            default = 2,
        },
        {
            type = "slider",
            name = "Opacité de l’effet de maladie",
            tooltip = "Régler l’intensité de la teinte verte liée aux maladies.",
            min = 0,
            max = 1,
            step = 0.1,
            getFunc = function() return set.diseaseOverlayalpha1 end,
            setFunc = function(value)
                set.diseaseOverlayalpha1 = value
                diseaseOverlay1:SetAlpha(value)
            end,
            default = 0.5,
        },
        {
            type = "slider",
            name = "Opacité de l’effet de blessure",
            tooltip = "Régler l’intensité de la teinte rouge liée aux blessures.",
            min = 0,
            max = 1,
            step = 0.1,
            getFunc = function() return set.diseaseOverlayalpha2 end,
            setFunc = function(value)
                set.diseaseOverlayalpha2 = value
                diseaseOverlay2:SetAlpha(value)
            end,
            default = 0.5,
        },
        {
            type = "slider",
            name = "Opacité de l’affliction magique",
            tooltip = "Régler l’intensité de la teinte bleue liée aux afflictions magiques.",
            min = 0,
            max = 1,
            step = 0.1,
            getFunc = function() return set.diseaseOverlayalpha3 end,
            setFunc = function(value)
                set.diseaseOverlayalpha3 = value
                diseaseOverlay3:SetAlpha(value)
            end,
            default = 0.5,
        },

        {
            type = "description",
            text = "\n|cFFFFFFAppuyez deux fois sur « Consulter mes besoins » pour ouvrir la roue.|r",
            width = "full",
        },

    }

    if RolePlayNeeds.FatigueRules then RolePlayNeeds.FatigueRules.AddOptions(options) end
    if RolePlayNeeds.NeedsHUD then RolePlayNeeds.NeedsHUD.AddOptions(options) end
    menu:RegisterAddonPanel("RolePlayNeedsPanel", panel)
    menu:RegisterOptionControls("RolePlayNeedsPanel", options)
end


function RolePlayNeeds.OnAddOnLoaded(event, addonName)
        if addonName ~= RolePlayNeeds.name then return end
        em:UnregisterForEvent(RolePlayNeeds.name, EVENT_ADD_ON_LOADED)


        RolePlayNeeds.settings = RolePlayMod.Storage("survival", function() return ZO_SavedVars:New("RolePlayNeedsSavedVars", 1, nil, RolePlayNeeds.settings) end, RolePlayNeeds.settings)

        local s = RolePlayNeeds.settings

        RolePlayNeeds.hunger.currentStage = s.hunger.currentStage or 10
        RolePlayNeeds.water.currentStage = s.water.currentStage or 10
        RolePlayNeeds.alcohol.currentStage = s.alcohol.currentStage or 1
        RolePlayNeeds.hasDisease = s.hasDisease or false
        RolePlayNeeds.diseaseLv = s.diseaseLv or -1



        StartTimers()
        RolePlayNeeds.tickSober()
        CreateMeterUI("fatigue")
        CreateMeterUI("hunger")
        CreateMeterUI("water")
        CreateMeterUI("alcohol")
        UpdateStage("fatigue", RolePlayNeeds.settings.fatigueLv)
        UpdateStage("hunger", RolePlayNeeds.hunger.currentStage)
        UpdateStage("water", RolePlayNeeds.water.currentStage)
        UpdateStage("alcohol", RolePlayNeeds.alcohol.currentStage)

        InitDiseaseOverlay()
        UpdateRadialStatus()
        SLASH_COMMANDS["/sit"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(99)

            d("Vous vous reposez.")
        end
        SLASH_COMMANDS["/sitchair"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(100)

            d("Vous vous reposez.")
        end

        SLASH_COMMANDS["/sit2"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(119)

            d("Vous vous reposez.")
        end
        SLASH_COMMANDS["/sit3"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(120)

            d("Vous vous reposez.")
        end
        SLASH_COMMANDS["/sit4"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(121)

            d("Vous vous reposez.")
        end
        SLASH_COMMANDS["/sit5"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(122)

            d("Vous vous reposez.")
        end
        SLASH_COMMANDS["/sit6"] = function()
            RolePlayNeeds.isResting = true
            RolePlayMod.PlaySurvivalEmote(123)

            d("Vous vous reposez.")
        end

        SLASH_COMMANDS["/sleep"] = function() SLASH_COMMANDS["/takeanap"]() end
        SLASH_COMMANDS["/sleep2"] = function() SLASH_COMMANDS["/takeanap"]() end

        SLASH_COMMANDS["/eat"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(168)
        end
        SLASH_COMMANDS["/eat2"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(9)
        end
        SLASH_COMMANDS["/eat3"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(177)
        end
        SLASH_COMMANDS["/eat4"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(201)
        end

        SLASH_COMMANDS["/pie"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(207)
        end
        SLASH_COMMANDS["/marshmallowtreat"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(320)
        end
        SLASH_COMMANDS["/meal"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(210)
        end
        SLASH_COMMANDS["/soupbowl"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(208)
        end
        SLASH_COMMANDS["/spicysoup"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(329)
        end
        SLASH_COMMANDS["/smallbread"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(209)
        end
        SLASH_COMMANDS["/eatbread"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(176)
        end
        SLASH_COMMANDS["/drink"] = RolePlayNeeds.IncreaseWater
        SLASH_COMMANDS["/drink2"] = RolePlayNeeds.IncreaseWater2
        SLASH_COMMANDS["/drink3"] = RolePlayNeeds.IncreaseWater3
        SLASH_COMMANDS["/drinkhorn"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            RolePlayMod.PlaySurvivalEmote(284)
        end
        SLASH_COMMANDS["/drinkfromskull"] = function()
            RolePlayNeeds.IncreaseWaterNeutral()
            RolePlayMod.PlaySurvivalEmote(287)
        end
        SLASH_COMMANDS["/eatbread"] = function()
            RolePlayNeeds.IncreaseWaterNeutral()
            RolePlayMod.PlaySurvivalEmote(176)
        end
        SLASH_COMMANDS["/beachdrink"] = function()
            RolePlayNeeds.IncreaseWaterNeutral()
            RolePlayMod.PlaySurvivalEmote(423)
        end
        SLASH_COMMANDS["/sitdrink"] = RolePlayNeeds.IncreaseWaterSit
        SLASH_COMMANDS["/booze"] = RolePlayNeeds.IncreaseAlcohol

        SLASH_COMMANDS["/starve"] = RolePlayNeeds.ResetHunger
        SLASH_COMMANDS["/thirst"] = RolePlayNeeds.ResetWater
        SLASH_COMMANDS["/sober"] = RolePlayNeeds.ResetAlcohol
        SLASH_COMMANDS["/isSurvivalOn"] = function() return RolePlayNeeds.settings.survivalModeOn or false end

        SLASH_COMMANDS["/eatfood"] = function()
            RolePlayNeeds.IncreaseHungerNeutral()
            local X = RolePlayNeeds.settings.eatEmoteIndex or 201
            RolePlayMod.PlaySurvivalEmote(X)
        end
        SLASH_COMMANDS["/openaskforinfo"] = function()
            if isWheelOpen then
                SLASH_COMMANDS["/mywheel"]()
                isWheelOpen = false
            end
            SetGameCameraUIMode(false)
            zo_callLater(function()

                local askForInfo = SLASH_COMMANDS["/askforinfo"]
                if type(askForInfo) == "function" then
                    askForInfo()
                else
                    d("[RolePlayMod] Activez IHeardARumor et ses dependances pour demander des renseignements.")
                end
            end, 300)

        end
        SLASH_COMMANDS["/rest"] = function()

            SetGameCameraUIMode(false)
            if isWheelOpen then
                SLASH_COMMANDS["/mywheel"]()
                isWheelOpen = false
            end
            RolePlayMod.PlaySurvivalEmote(RolePlayNeeds.settings.restingEmoteIndex)
            RolePlayNeeds.isResting = true
            d("Vous vous reposez.")
        end
        SLASH_COMMANDS["/drinkwater"] = function()
            RolePlayNeeds.IncreaseWaterNeutral()
            RolePlayMod.PlaySurvivalEmote(RolePlayNeeds.settings.drinkEmoteIndex)
        end
        SLASH_COMMANDS["/togglesurvival"] = function()
            RolePlayNeeds.settings.survivalModeOn = not RolePlayNeeds.settings.survivalModeOn
            if RolePlayNeeds.settings.survivalModeOn then
                ShowCenterMessage("Mode survie : activé !")
                UpdateRadialStatus()
            else
                UpdateRadialStatus()
                ShowCenterMessage("Mode survie : désactivé !")
            end
        end
        SLASH_COMMANDS["/checkneeds"] = RolePlayNeeds.CheckNeeds

        SLASH_COMMANDS["/openmypets"] = function()
            if isWheelOpen then
                SLASH_COMMANDS["/mywheel"]()
                isWheelOpen = false
            end
            SLASH_COMMANDS["/mypets"]()
        end

        SLASH_COMMANDS["/openmybook"] = function()
            SetGameCameraUIMode(false)
            if isWheelOpen then
                SLASH_COMMANDS["/mywheel"]()
                isWheelOpen = false
            end
            SLASH_COMMANDS["/readlastsaved"]()
        end


        SLASH_COMMANDS["/takeanap"] = function()
            if isWheelOpen then
                SLASH_COMMANDS["/mywheel"]()
                isWheelOpen = false
            end
            local x = 5
            local ok, message = StartNap(x, false)
            if not ok then d("[Survie] " .. message) end
        end
        SLASH_COMMANDS["/applydisease"] = function()
            RolePlayNeeds.ApplyDisease("Essai de maladie : vos articulations vous font souffrir… ", 3)
        end

        SLASH_COMMANDS["/curedisease"] = function()
            RolePlayNeeds.CureDisease()
        end
        if RolePlayNeeds.FatigueRules then RolePlayNeeds.FatigueRules.Initialize() end
        if RolePlayNeeds.NeedsHUD then RolePlayNeeds.NeedsHUD.Initialize() end
        RolePlayNeeds.MakeMenu()
        em:RegisterForEvent("RolePlayNeeds_InventoryListener", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, RolePlayNeeds.OnInventoryChange)
        d(string.format("[Survie] Chargé. Satiété : %d, hydratation : %d", RolePlayNeeds.hunger.currentStage, RolePlayNeeds.water.currentStage))
        RolePlayNeeds.ShowDiseaseOverlay(s['hasDisease'],s['diseaseLv'])
        zo_callLater(function()

            InitializeWheel()
        end, 1500)

    end

em:RegisterForEvent("RolePlayNeeds_Loaded", EVENT_PLAYER_ACTIVATED, function()
    em:UnregisterForEvent("RolePlayNeeds_Loaded", EVENT_PLAYER_ACTIVATED)
    RolePlayNeeds:ForceInventoryScan()
end)


em:RegisterForEvent(RolePlayNeeds.name, EVENT_ADD_ON_LOADED, RolePlayNeeds.OnAddOnLoaded)
em:RegisterForEvent("RPN_StoreHook", EVENT_OPEN_STORE, RolePlayNeeds.OnStoreOpen)
em:RegisterForEvent("RPN_StoreHookClose", EVENT_CLOSE_STORE, RolePlayNeeds.OnStoreClose)
