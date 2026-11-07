EldenRingUI = EldenRingUI or {}
EldenRingUI.FoodTracker = EldenRingUI.FoodTracker or {}
local FoodTracker = EldenRingUI.FoodTracker

FoodTracker.name = "ERUI_FoodTracker"

local trackedFoods = {
    [127596] = true, -- Bewitched Sugar Skulls
    [61261] = true,  -- Max Stamina
    [86673] = true,  -- Max Stamina and Stam Regen
    [61255] = true,  -- Max Stamina and Max Health
    [61260] = true,  -- Max Magicka
    [84720] = true,  -- Max Magicka and Max Regen
    [61257] = true,  -- Max Magicka and Max Health
    [89955] = true,  -- Candied Jester's Coins
    [84709] = true,  -- Crunchy Spider Skewer
    [89971] = true,  -- Jewels of Misrule
    [72824] = true,  -- Smoked Bear Haunch
    [107748] = true, -- Artaeum Picked Fish Bowl
    [89957] = true,  -- Dubious Camoran Throne
}

local function FormatFoodName(name)
    return (name:gsub("^%l", string.upper))
end

local function SetFoodText(text)
    ERUI_FoodTrackerWindowLabel:SetText(text)
    ERUI_FoodTrackerWindowLabel:SetColor(0.9, 0.9, 0.9, 0.9)
end

function FoodTracker.UpdateFood()
    for i = 1, GetNumBuffs("player") do
        local buffName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if trackedFoods[abilityId] then
            SetFoodText(FormatFoodName(buffName))
            return
        end
    end
    SetFoodText("No Food Active")
end

function FoodTracker.OnEffectChanged(_, changeType, _, effectName, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or not trackedFoods[abilityId] then return end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        SetFoodText(FormatFoodName(effectName))
    elseif changeType == EFFECT_RESULT_FADED then
        FoodTracker.UpdateFood()
    end
end

function FoodTracker.OnAddOnLoaded(_, addonName)
    if addonName ~= "EldenRingUI" then return end
    EVENT_MANAGER:UnregisterForEvent(FoodTracker.name, EVENT_ADD_ON_LOADED)

    local fragment = ZO_HUDFadeSceneFragment:New(ERUI_FoodTrackerWindow)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    FoodTracker.UpdateFood()

    EVENT_MANAGER:RegisterForEvent(FoodTracker.name, EVENT_EFFECT_CHANGED, FoodTracker.OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(FoodTracker.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
end

EVENT_MANAGER:RegisterForEvent(FoodTracker.name, EVENT_ADD_ON_LOADED, FoodTracker.OnAddOnLoaded)