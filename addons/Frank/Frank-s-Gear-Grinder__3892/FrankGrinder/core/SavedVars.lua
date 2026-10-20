
FrankGrinder.defaults = {
    firstRun = true,
    numChars = 0,
    charInfo = nil,
    timeData = {},
    options = {
        leadWarningEnabled = true,
        leadWarningAnnounce = true,
        leadWarningChatWindow = true,
        leadWarningPeriod = 7,
        leadNoWarningPeriod = 30,

        overridePAKnown = false,
        saleValueThreshold = 10000,
        crafterCharacterName = "",
        traderCharacterName = "",
        withdrawToTrader = false,

        mailToOtherAccount = false,
        mailItemsAccount = "",
        mailMatsAccount = "",
        mailIntricateWoodcrafting = false,
        mailIntricateClothier = false,
        mailIntricateBlacksmithing = false,
        mailIntricateJewelry = false,
        mailGlyphs = false,
        mailCraftingMats = false,
        mailBoEItems = false,
        mailUnknownWrits = false,
        mailUnknownSurveys = false,
        mailUnknownTreasures = false,

        hideAdventureZoneHudTracker = false,
        
        enableElmsInjection = false,

        keyChordingEnabled = false,

        -- Night Market Group Finder automation config
        nmAutomationConfig = {
            mode = "argent",        -- "dungeon" | "argent" | "adventure"
            titlePrefix = "",       -- free text prepended to Group Finder title
            tank = 2,
            heal = 2,
            dps  = 8,
            cp   = 500,
            kickOffline = false,
        },

        groupFinderEnabled = true,
        groupFinderCheckInterval = 60,
        groupFinderTrials = {
            AA = true, AS = true, CR = true, HoF = true, HRC = true, SO = true, MoL = true,
            SS = true, KA = true, RG = true, DSR = true, SE = true, LC = true, OC = true,
        },
    },
    leadWarning = {},

    -- Markers this addon has injected into ElmsMarkers, keyed by zoneId.
    -- Persisted so a crash or hard exit can't orphan them there.
    elmsZoneTrackMarkers = {},

    version = FrankGrinder.savedVarsSchemaVersion,
}

FrankGrinder.timeDataDefaults = {
    AA = 0, AS = 0, HoF = 0, HRC = 0, SO = 0, MoL = 0, CR = 0,
    SS = 0, KA = 0, RG = 0, DSR = 0, SE = 0, LC = 0, OC = 0,
}

function FrankGrinder.UpgradeSavedVariablesV2toV3(sv)
    if not sv or sv.version ~= 2 then return end

    local timeData = sv.timeData
    if not timeData then
        sv.version = FrankGrinder.savedVarsSchemaVersion
        return
    end

    local keyMap = {
        timeAA  = "AA",
        timeSO  = "SO",
        timeOC  = "OC",
        timeSS  = "SS",
        timeLC  = "LC",
        timeHRC = "HRC",
        timeCR  = "CR",
        timeSE  = "SE",
        timeDSR = "DSR",
        timeAS  = "AS",
        timeKA  = "KA",
        timeRG  = "RG",
        timeHoF = "HoF",
        timeMaw = "MoL",
    }

    for _, charData in pairs(timeData) do
        for oldKey, newKey in pairs(keyMap) do
            local oldValue = charData[oldKey]
            if oldValue ~= nil then
                charData[newKey] = oldValue
            elseif charData[newKey] == nil then
                charData[newKey] = 0
            end
        end
        for oldKey in pairs(keyMap) do
            charData[oldKey] = nil
        end
    end

    sv.version = FrankGrinder.savedVarsSchemaVersion
end

function FrankGrinder:InitSavedVars(world)
    self.SV = ZO_SavedVars:NewAccountWide(
        self.name .. "_Settings",
        self.savedVarsApiVersion,
        world,
        self.defaults
    )

    if self.SV.version == nil then
        self.SV.version = self.savedVarsSchemaVersion
    end

    self.UpgradeSavedVariablesV2toV3(self.SV)
end
