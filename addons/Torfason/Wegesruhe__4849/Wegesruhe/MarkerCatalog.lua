local WR = Wegesruhe

WR.pinCategories = {}
WR.managedCompassPins = {}
WR.managedFloatingPins = {}
WR.managedFloatingPinSet = {}

local function AddPin(targetList, constantName, category)
    local pinType = _G[constantName]
    if type(pinType) ~= "number" then
        return
    end
    targetList[#targetList + 1] = pinType
    if targetList == WR.managedFloatingPins then
        WR.managedFloatingPinSet[pinType] = true
    end
    WR.pinCategories[pinType] = category
end

local function AddBoth(constantName, category)
    AddPin(WR.managedCompassPins, constantName, category)
    AddPin(WR.managedFloatingPins, constantName, category)
end

function WR:BuildMarkerCatalog()
    self.pinCategories = {}
    self.managedCompassPins = {}
    self.managedFloatingPins = {}
    self.managedFloatingPinSet = {}

    AddBoth("MAP_PIN_TYPE_QUEST_OFFER", "questOffers")
    AddBoth("MAP_PIN_TYPE_QUEST_OFFER_REPEATABLE", "questOffers")
    AddBoth("MAP_PIN_TYPE_QUEST_OFFER_ZONE_STORY", "questOffers")

    -- ESO also uses a tracked zone-story quest-offer marker in the 3D world.
    -- Keep it world-only: do not introduce new compass filtering behavior.
    AddPin(self.managedFloatingPins, "MAP_PIN_TYPE_TRACKED_QUEST_OFFER_ZONE_STORY", "questOffers")

    local assisted = {
        "MAP_PIN_TYPE_ASSISTED_QUEST_CONDITION",
        "MAP_PIN_TYPE_ASSISTED_QUEST_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_ASSISTED_QUEST_ENDING",
        "MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_CONDITION",
        "MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_ASSISTED_QUEST_REPEATABLE_ENDING",
        "MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_CONDITION",
        "MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_ENDING",
        "MAP_PIN_TYPE_TRACKED_QUEST_CONDITION",
        "MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_TRACKED_QUEST_ENDING",
        "MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_CONDITION",
        "MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_ENDING",
        "MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_CONDITION",
        "MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_ENDING",
    }
    for _, constantName in ipairs(assisted) do
        AddBoth(constantName, "assistedObjectives")
    end

    local secondary = {
        "MAP_PIN_TYPE_QUEST_CONDITION",
        "MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_QUEST_ENDING",
        "MAP_PIN_TYPE_QUEST_REPEATABLE_CONDITION",
        "MAP_PIN_TYPE_QUEST_REPEATABLE_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_QUEST_REPEATABLE_ENDING",
        "MAP_PIN_TYPE_QUEST_ZONE_STORY_CONDITION",
        "MAP_PIN_TYPE_QUEST_ZONE_STORY_OPTIONAL_CONDITION",
        "MAP_PIN_TYPE_QUEST_ZONE_STORY_ENDING",
    }
    for _, constantName in ipairs(secondary) do
        AddBoth(constantName, "secondaryObjectives")
    end

    AddPin(self.managedCompassPins, "MAP_PIN_TYPE_POI_SEEN", "poiSeen")
    AddPin(self.managedCompassPins, "MAP_PIN_TYPE_POI_COMPLETE", "poiComplete")
end

function WR:IsCompassPinVisible(pinType)
    local category = self.pinCategories[pinType]
    if not category then
        return true
    end
    local profile = self:GetActiveProfile()
    if profile.compassPins == false or profile.compass[category] == false then
        return false
    end

    -- Per-pin quest identity is not exposed by the compass container. Only
    -- suppress a whole quest-icon category when NO eligible journal quest
    -- remains in that category. Mixed allowed/blocked secondary quests stay
    -- visible, rather than accidentally hiding an allowed quest's guidance.
    if self.questCompassEligibility and self.questCompassEligibility[category] == false then
        return false
    end
    return true
end

function WR:IsFloatingPinVisible(pinType)
    local category = self.pinCategories[pinType]
    if not category then
        return true
    end
    if category == "poiSeen" or category == "poiComplete" then
        return true
    end
    local profile = self:GetActiveProfile()
    return profile.world[category] ~= false
end

function WR:AreBreadcrumbsVisible()
    local profile = self:GetActiveProfile()
    return profile.world.breadcrumbs ~= false
end
