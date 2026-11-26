-- Fury's Account Sync - what each addon keeps in its saved data
-- Keyed by the name of the addon's saved variable (the "## SavedVariables:" line of its manifest).
--   "settings"        the main's account-wide settings are copied to the other accounts
--   { keep = {...} }  the same, but these parts stay as each account has them (stats, logs, history)
--   { layout = "harvest", keep = {} }  HarvestMap's own layout, see AddonCopy.lua
--   "data"            never copied (inventories, knowledge, history, guild data)
--   "own"             this addon, the base game, or an addon this one replaces
-- An addon that isn't listed is left alone. The Windows tool uses the same list.

local AS = FurysAccountSync

AS.RULES = {
    AddonSelectorSavedVars                 = "settings",
    AdvancedFilters_Settings               = "settings",
    ArchiveHelperSavedVars                 = "settings",
    AsquartOsseinCageHelperSavedVariables  = "settings",
    AutoBindVariables                      = "settings",
    AutoCategorySavedVars                  = "settings",
    AutoCatRules                           = "settings",
    AutoInviteSettings                     = "settings",
    AutoRecruitSavedVars                   = "settings",
    BSCHTKASaved                           = "settings",
    BanditsCompanions_SavedVars            = "settings",
    BUI_VARS                               = "settings",
    CombatInsightsSavedVariables           = "settings",
    CombatMetrics_Save                     = "settings",
    CombatMetronomeSavedVars               = "settings",
    CrutchAlertsSavedVariables             = "settings",
    DDPositions_SavedVars                  = "settings",
    DDPositions_Mirror_SavedVars           = "settings",
    dolgubonslazysetcraftersavedvars       = "settings",
    DryzlerElderGeekNetTauntSavedVariables = "settings",
    FancyActionBarSV                       = "settings",
    GroupFinderPlus_SavedVariables         = "settings",
    GroupManager_Data                      = "settings",
    HodorReflexesSavedVars                 = "settings",
    HowToCloudrestVariables                = "settings",
    HowToKyneVariables                     = "settings",
    HowToSunspireVariables                 = "settings",
    ILeadListVars                          = "settings",
    InsatiableHungerBlocker_SV             = "settings",
    LBooks_SavedVariables                  = "settings",
    LibCustomIconsSV                       = "settings",
    LibScrollableMenu_SavedVars            = "settings",
    LPNSavedVars                           = "settings",
    MeterskullSettings                     = "settings",
    MP_SavedGlobal                         = "settings",
    NowhereVaultSecretSeekerSavedVars      = "settings",
    OSIStore                               = "settings",
    OsseinCageHelperSavedVariables         = "settings",
    PerfectPixel                           = "settings",
    PerfectWeaveSV                         = "settings",
    PersonalAssistant_SavedVariables       = "settings",
    PersonalAssistantBanking_SavedVariables     = "settings",
    PersonalAssistantConsume_SavedVariables     = "settings",
    PersonalAssistantIntegration_SavedVariables = "settings",
    PersonalAssistantJunk_SavedVariables        = "settings",
    PersonalAssistantLoot_SavedVariables        = "settings",
    PersonalAssistantRepair_SavedVariables      = "settings",
    PersonalAssistantWorker_SavedVariables      = "settings",
    PotionMaker_Data                       = "settings",
    PowerfulAssaultTrackerSavedVars        = "settings",
    QcellDreadsailReefHelperSavedVariables = "settings",
    QcellRockgroveHelperSavedVariables     = "settings",
    QuestMap_SavedVariables                = "settings",
    RDLVars                                = "settings",
    ResistOMeterSettings                   = "settings",
    RNVars                                 = "settings",
    SanitysEdgeHelperSavedVariables        = "settings",
    StudsGroupFinderTweaksVars             = "settings",
    SurveyZoneListSavedVariables           = "settings",
    Untaunted_Save                         = "settings",
    WhoPulledVariables                     = "settings",
    WritWorthyVars                         = "settings",

    BeamMeUp_SV                       = { keep = { "portCounterPerZone", "lastPortedZones", "savedGold", "initialTimeStamp", "houseFurnitureCount_LII", "lastofflineReminder" } },
    CSPSSavedVariables                = { keep = { "charData" } },
    DolgubonsWritCrafterSavedVars     = { keep = { "rewards", "craftLog", "writLocations", "skipItemQuests", "totalCraftsCount" } },
    EzStalking_SavedVars              = { keep = { "log" } },
    MagicCarpetSavedVars              = { keep = { "EarnedTrophies", "LastOogyBoogy" } },
    MagicSorter                       = { keep = { "Data" } },
    PCHAT_OPTS                        = { keep = { "LineStrings", "history" } },
    PortToFriendsHouseVars            = { keep = { "myHousesFavorites" } },
    ResearchAssistant_Settings_Server = { keep = { "acquiredTraits", "blacksmithCharacter", "clothierCharacter", "leatherworkerCharacter", "weaponsmithCharacter", "woodworkingCharacter", "jewelryCraftingCharacter" } },
    SkillLinesSavedVars               = { keep = { "NA Megaserver", "EU Megaserver" } },
    TamrielTradeCentreVars            = { keep = { "NAData", "EUData" } },
    WizardsWardrobeSV                 = { keep = { "accountWideStorage" } },
    XLGearBankerSavedVariables        = { keep = { "gearSetList", "pages", "displayingSet", "displayingPage" } },

    ArmoryStyleManagerData              = "data",
    AutomateSavedVars                   = "data",
    AwesomeGuildStore_Data              = "data",
    BUI_REPORTS                         = "data",
    CombatInsightsFightDataSV           = "data",
    CombatMetricsFightData              = "data",
    CraftStore_Account                  = "data",
    CraftStore_Character                = "data",
    DecoTrackSavedVars                  = "data",
    DSSTSavedVariables                  = "data",
    EssentialHousingCommunitySavedVars  = "data",
    FCOItemSaver_Settings               = "data",
    FurnitureCatalogue_Settings         = "data",
    FuryCT_SV                           = "data",
    FuryGMT_SV                          = "data",
    FuryGTT_SV                          = "data",
    FurysGuildCrier_SV                  = "data",
    FurysInventoryLedger_SV             = "data",
    -- HarvestMap keeps its settings in its own layout: account.<name without @>. Its pins are in other files.
    Harvest_SavedVars                   = { layout = "harvest", keep = {} },
    IIFA_DATABASE                       = "data",
    LeoAltholicSavedVariables           = "data",
    LibCharacterKnowledgeData           = "data",
    LibCustomNamesSV                    = "data",
    USPF_Settings                       = "data",   -- Urich's Skill Point Finder stopped working after a copy (0.4.1)
    LibDebugLoggerLog                   = "data",
    LibDebugLoggerSettings              = "data",
    LibHistoire_GuildHistoryCache       = "data",
    LibHistoire_Settings                = "data",
    MP_ChestData                        = "data",
    MP_ThievesTrove                     = "data",
    PithkaSavedVariables                = "data",
    SUPERSTAR                           = "data",
    WPamA_SV_Debug                      = "data",
    WPamA_SV_Main                       = "data",
    ZO_InternalIngame_SavedVariables    = "data",

    AccountSettings_SV          = "own",
    FurysAccountSync_SV         = "own",
    ZO_Ingame_SavedVariables    = "own",
    ZO_Pregame_SavedVariables   = "own",
}

-- Returns whether the saved variable is copied, and the set of parts that stay as they are.
function AS.CopyRule(name)
    local rule = AS.RULES[name]
    -- addons the player added in the settings are copied whole
    if rule == nil and AS.SV().extra[name] then return true, {} end
    if rule == "settings" then return true, {} end
    if type(rule) == "table" then
        local keep = {}
        for _, key in ipairs(rule.keep) do keep[key] = true end
        return true, keep
    end
    return false, {}
end

-- Every saved-data name whose settings are copied: the list above plus what the player added.
function AS.CopiedNames()
    local names = {}
    for name in pairs(AS.RULES) do names[#names + 1] = name end
    for name in pairs(AS.SV().extra) do
        if AS.RULES[name] == nil then names[#names + 1] = name end
    end
    return names
end

-- Running addons that keep account-wide settings for the main but aren't on the list, so this
-- addon can't tell their settings from their data. Found by looking at what is loaded: saved data
-- with a "Default" profile that has a section for the main account. Worked out once per session.
local unlisted, unlistedFor
function AS.UnlistedAddons()
    local main = AS.SV().main
    if unlisted and unlistedFor == main then return unlisted end
    unlisted = {}
    unlistedFor = main
    if not main then return unlisted end
    for name, value in zo_insecureNext, _G do
        if type(name) == "string" and type(value) == "table" and AS.RULES[name] == nil then
            local profile = rawget(value, "Default")
            local node = type(profile) == "table" and rawget(profile, main)
            if type(node) == "table" and type(rawget(node, "$AccountWide")) == "table" then
                unlisted[#unlisted + 1] = name
            end
        end
    end
    table.sort(unlisted)
    return unlisted
end

-- Adds a saved-data name to the player's own list. Returns true, or false and why not.
function AS.AddExtra(name)
    name = zo_strtrim(name or "")
    if name == "" then return false, "Type the saved-data name first." end
    local rule = AS.RULES[name]
    if rule == "data" or rule == "own" then return false, name .. " only holds data, so it is never copied." end
    if rule ~= nil then return false, name .. " is already on the built-in list." end
    if type(_G[name]) ~= "table" then
        return false, "No addon that is running here saves its data as \"" .. name .. "\". Check the spelling, capitals included."
    end
    AS.SV().extra[name] = true
    return true
end

------------------------------------------------------------------------------
-- Which of the listed addons are ticked
------------------------------------------------------------------------------
-- Ticked to begin with: a short set of widely used addons whose saved data is settings only.
-- Everything else on the list is there to tick, one at a time, once these are seen to work.
AS.STARTER = {
    BUI_VARS = true, FancyActionBarSV = true, CombatMetrics_Save = true, HodorReflexesSavedVars = true,
    CrutchAlertsSavedVariables = true, RNVars = true, PerfectPixel = true, AdvancedFilters_Settings = true,
    AutoCategorySavedVars = true, AutoCatRules = true, OSIStore = true, CombatMetronomeSavedVars = true,
    PersonalAssistant_SavedVariables = true, PersonalAssistantBanking_SavedVariables = true,
    PersonalAssistantConsume_SavedVariables = true, PersonalAssistantIntegration_SavedVariables = true,
    PersonalAssistantJunk_SavedVariables = true, PersonalAssistantLoot_SavedVariables = true,
    PersonalAssistantRepair_SavedVariables = true, PersonalAssistantWorker_SavedVariables = true,
}

-- Is this addon ticked? The player's own choice wins; without one, the starter set and the
-- addons the player added are ticked.
function AS.IsPicked(name)
    local sv = AS.SV()
    local choice = sv.pick[name]
    if choice ~= nil then return choice end
    return AS.STARTER[name] == true or sv.extra[name] == true
end

function AS.SetPicked(name, on)
    AS.SV().pick[name] = on
end

-- Every copied name, sorted, for the tick list in the settings.
function AS.SortedCopiedNames()
    local names = {}
    for _, name in ipairs(AS.CopiedNames()) do
        if AS.CopyRule(name) then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end
