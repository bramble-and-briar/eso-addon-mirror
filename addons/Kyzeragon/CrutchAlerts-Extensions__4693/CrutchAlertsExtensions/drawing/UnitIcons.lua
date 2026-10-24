local CAE = CrutchAlertsExtensions
local Crutch = CrutchAlerts


---------------------------------------------------------------------
local KNOWN_PETS = {
    ["Feral Guardian"] = "esoui/art/icons/ability_warden_018.dds",
    ["Eternal Guardian"] = "esoui/art/icons/ability_warden_018_b.dds",
    ["Wild Guardian"] = "esoui/art/icons/ability_warden_018_c.dds",
    ["Gloom Wraith"] = "esoui/art/icons/ability_nightblade_001_a.dds",
}

local BANKER = 1
local MERCHANT = 2
local DECON = 3
local ARMORY = 4
local FENCE = 5

local ASSISTANT_TEXTURES = {
    [BANKER] = "esoui/art/icons/servicemappins/servicepin_bank.dds",
    [MERCHANT] = "esoui/art/icons/servicemappins/servicepin_vendor.dds",
    [DECON] = "esoui/art/crafting/gamepad/gp_crafting_menuicon_deconstruct.dds",
    [ARMORY] = "esoui/art/icons/servicemappins/servicepin_armory.dds",
    [FENCE] = "esoui/art/icons/mapkey/mapkey_fence.dds",
}

local KNOWN_COLLECTIBLES = {
    -- Armory
    [9745] = ARMORY, -- Ghrasharog, Armory Assistant
    [10618] = ARMORY, -- Zuqoth, Armory Advisor
    [11876] = ARMORY, -- Drinweth, Valenwood Armorer
    [13518] = ARMORY, -- Voko, Carnaval Weapondancer

    -- Banker
    [267] = BANKER, -- Tythis Andromo, the Banker
    [6376] = BANKER, -- Ezabi the Banker
    [8994] = BANKER, -- Baron Jangleplume, the Banker
    [9743] = BANKER, -- Factotum Property Steward
    [11097] = BANKER, -- Pyroclast, Infernace Conservator
    [12413] = BANKER, -- Eri, Barking Banker
    [13517] = BANKER, -- Celia Tyde, Lost Fleet Bursar

    -- Decon
    [10184] = DECON, -- Giladil the Ragpicker
    [10617] = DECON, -- Aderene, Fargrave Dregs Dealer
    [11877] = DECON, -- Tzozabrar, Dwarven Deconstructor
    [13063] = DECON, -- Siluruz, Realm Craftsmaster
    [14018] = DECON, -- Pontius Remus, Lupine Scavenger

    -- Merchant
    [301] = MERCHANT, -- Nuzhimeh the Merchant
    [6378] = MERCHANT, -- Fezez the Merchant
    [8995] = MERCHANT, -- Peddler of Prizes, the Merchant
    [9744] = MERCHANT, -- Factotum Commerce Delegate
    [11059] = MERCHANT, -- Hoarfrost, Takubar Trader
    [12414] = MERCHANT, -- Xyn, Planar Purveyor
    [13066] = MERCHANT, -- Terilorne, Dibellan Freetrader

    -- Fence
    [300] = FENCE, -- Pirharri the Smuggler
    [14204] = FENCE, -- Cambio Zammes, Rooster in Exile
}


---------------------------------------------------------------------
-- Assistant detection
local function GetActiveAssistantTexture()
    local collectibleId = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_ASSISTANT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if (not collectibleId) then return end
    local collectibleType = KNOWN_COLLECTIBLES[collectibleId]
    if (not collectibleType) then return "esoui/art/companion/gamepad/gp_category_u30_allies.dds" end
    return ASSISTANT_TEXTURES[collectibleType]
end


---------------------------------------------------------------------
local function GetKnownTexture(unitTag)
    local knownTexture = KNOWN_PETS[GetUnitName(unitTag)]
    if (knownTexture) then return knownTexture end

    if (IsUnitFriendlyFollower(unitTag) and GetUnitCaption(unitTag)) then
        return GetActiveAssistantTexture()
    end
end


---------------------------------------------------------------------
local function StartsWith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local function GetIconTexture(unitTag)
    if (unitTag == "companion") then
        return "esoui/art/mappins/activecompanion_pin.dds"
    end

    if (not StartsWith(unitTag, "playerpet")) then return nil end

    local knownTexture = GetKnownTexture(unitTag)
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    if (knownTexture) then
        if (not profile.iconsForKnownPets) then return nil end
        return knownTexture
    end

    if (profile.iconsForPets) then
        return "CrutchAlerts/assets/poop.dds"
    end

    return nil
end


---------------------------------------------------------------------
---------------------------------------------------------------------
local UNIT_ICON_UNIQUE_NAME = "CrutchAlertsExtensionsUnitIcon"
local createdTags = {} -- Keep track of all possible in case of unregistering

local function OnUnitCreated(_, unitTag)
    Crutch.dbgSpam("created " .. unitTag .. " - " .. tostring(GetUnitName(unitTag)))
    local texture = GetIconTexture(unitTag)
    if (texture) then
        Crutch.SetAttachedIconForUnit(unitTag, UNIT_ICON_UNIQUE_NAME, 50, texture, nil, nil, true)
        createdTags[unitTag] = true
    end
end

local function OnUnitDestroyed(_, unitTag)
    Crutch.dbgSpam("destroyed " .. unitTag .. " - " .. tostring(GetUnitName(unitTag)))
    Crutch.RemoveAttachedIconForUnit(unitTag, UNIT_ICON_UNIQUE_NAME)
end

-- Units can change when going into another zone, e.g. with a banker
-- summoned as playerpet1, we don't get unit destroyed event after
-- rezoning. So clean up all the pets and redo them.
local function OnPlayerActivated()
    local profile = CAE.profiles[CAE.csvs.currentProfile]
    for i = 1, MAX_PET_UNIT_TAGS do
        local tag = "playerpet" .. i
        OnUnitDestroyed(nil, tag)
        if ((profile.iconsForPets or profile.iconsForKnownPets) and DoesUnitExist(tag)) then
            OnUnitCreated(nil, tag)
        end
    end
end


---------------------------------------------------------------------
---------------------------------------------------------------------
local function InitializeUnitIcons()
    local profile = CAE.profiles[CAE.csvs.currentProfile]

    if (profile.iconsForPets or profile.iconsForKnownPets) then
        EVENT_MANAGER:RegisterForEvent(CAE.name .. "UnitCreated", EVENT_UNIT_CREATED, OnUnitCreated)
        EVENT_MANAGER:RegisterForEvent(CAE.name .. "UnitDestroyed", EVENT_UNIT_DESTROYED, OnUnitDestroyed)
    end

    if (profile.iconsForCompanions) then
        EVENT_MANAGER:RegisterForEvent(CAE.name .. "CompanionActivated", EVENT_COMPANION_ACTIVATED, function() OnUnitCreated(nil, "companion") end)
        EVENT_MANAGER:RegisterForEvent(CAE.name .. "CompanionDeactivated", EVENT_COMPANION_DEACTIVATED, function() OnUnitDestroyed(nil, "companion") end)
    end

    EVENT_MANAGER:RegisterForEvent(CAE.name .. "UnitIconsPlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end
CAE.InitializeUnitIcons = InitializeUnitIcons

local function UnregisterUnitIcons()
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "UnitCreated", EVENT_UNIT_CREATED)
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "UnitDestroyed", EVENT_UNIT_DESTROYED)
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "CompanionActivated", EVENT_COMPANION_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "CompanionDeactivated", EVENT_COMPANION_DEACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "UnitIconsPlayerActivated", EVENT_PLAYER_ACTIVATED)

    for tag, _ in pairs(createdTags) do
        Crutch.RemoveAttachedIconForUnit(tag, UNIT_ICON_UNIQUE_NAME)
    end
end


---------------------------------------------------------------------
function CAE.GetUnitIconsSettings()
    local settings = {
        {
            type = "description",
            title = "|c08BD1DWorld Drawing Tools|r",
            -- text = "",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show icons on companions",
            tooltip = "Shows companion icons above your companions",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].iconsForCompanions end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].iconsForCompanions = value
                UnregisterUnitIcons()
                InitializeUnitIcons()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show icons on specific known \"pets\"",
            tooltip = "Shows icons above your \"pets\" with specific names. Your assistants are considered playerpets, as well as permanent pets. This relies partially on text detection, so some client languages may not be supported, in which case they will be detected as other pets below",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].iconsForKnownPets end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].iconsForKnownPets = value
                UnregisterUnitIcons()
                InitializeUnitIcons()
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show icons on other \"pets\"",
            tooltip = "Shows generic poop icons above your other \"pets.\" This will put icons on any of your playerpets that are NOT from the list above, meaning temporary summons (including from game mechanics like IA verses) and anything that's generally... not worth putting an icon on",
            default = false,
            getFunc = function() return CAE.profiles[CAE.csvs.currentProfile].iconsForPets end,
            setFunc = function(value)
                CAE.profiles[CAE.csvs.currentProfile].iconsForPets = value
                UnregisterUnitIcons()
                InitializeUnitIcons()
            end,
            width = "full",
        },
    }

    for _, setting in ipairs(CAE.GetUnitDrawingSettings()) do
        table.insert(settings, setting)
    end

    return settings
end
