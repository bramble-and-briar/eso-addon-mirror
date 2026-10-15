-- Imperial City district ownership; read only while locally in IC.
-- Keep IDs are the six Imperial City districts from the ESO HUD Tel Var implementation.
ICT.icDistrictKeepIds = {141, 142, 143, 146, 147, 148}
ICT.icFlagOwners = {}
ICT.icFlagUnderAttack = {}
ICT.icFlagDistrictByKeep = {}

local function normalize(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local aliases = {
    [SI_ICTHENEXTBOSS_ARENADISTRICT] = {"arena"},
    [SI_ICTHENEXTBOSS_TEMPLEDISTRICT] = {"temple", "tempel"},
    [SI_ICTHENEXTBOSS_ARBORETUMDISTRICT] = {"arboretum", "baumgarten"},
    [SI_ICTHENEXTBOSS_NOBLESDISTRICT] = {"nobles", "noble", "adels"},
    [SI_ICTHENEXTBOSS_MEMORIALDISTRICT] = {"memorial", "gedenk"},
    [SI_ICTHENEXTBOSS_ELVENGARDENSDISTRICT] = {"elven", "elfen"},
}

local function findDistrict(keepName)
    local key = normalize(keepName)
    if key == "" then return nil end
    for stringId, words in pairs(aliases) do
        local district = GetString(stringId)
        local normalizedDistrict = normalize(district)
        if normalizedDistrict ~= "" and (key:find(normalizedDistrict, 1, true) or normalizedDistrict:find(key, 1, true)) then
            return district
        end
        for _, word in ipairs(words) do
            if key:find(word, 1, true) then return district end
        end
    end
    return nil
end

function ICT.refreshFlagOwnership()
    ICT.icFlagOwners = {}
    ICT.icFlagUnderAttack = {}
    ICT.icFlagDistrictByKeep = {}
    if not ICT.running or type(GetKeepName) ~= "function" or type(GetKeepAlliance) ~= "function" then return end
    for _, keepId in ipairs(ICT.icDistrictKeepIds) do
        local district = findDistrict(GetKeepName(keepId))
        if district then
            ICT.icFlagDistrictByKeep[keepId] = district
            if type(GetKeepUnderAttack) == "function" then
                ICT.icFlagUnderAttack[district] = GetKeepUnderAttack(keepId, BGQUERY_LOCAL) == true
            end
            local alliance = GetKeepAlliance(keepId, BGQUERY_LOCAL)
            if alliance == ALLIANCE_ALDMERI_DOMINION or alliance == ALLIANCE_DAGGERFALL_COVENANT or alliance == ALLIANCE_EBONHEART_PACT then
                ICT.icFlagOwners[district] = alliance
            end
        end
    end
end

function ICT.getFlagText(district)
    -- No live flag data is retained or displayed outside Imperial City.
    if not ICT.running then return "|cFFD700unknown|r" end
    local owner = ICT.icFlagOwners[district]
    local label
    if owner == ALLIANCE_ALDMERI_DOMINION then label = "|cFFD700AD|r"
    elseif owner == ALLIANCE_DAGGERFALL_COVENANT then label = "|c479DFFDC|r"
    elseif owner == ALLIANCE_EBONHEART_PACT then label = "|cFF5555EP|r"
    else label = "|cFFD700unknown|r" end
    if ICT.icFlagUnderAttack[district] == true then
        return label .. " |cFFA500under attack|r"
    end
    return label
end

function ICT.onFlagUnderAttackChanged(_, keepId, _, underAttack)
    if not ICT.running then return end
    local district = ICT.icFlagDistrictByKeep[keepId]
    if district then
        ICT.icFlagUnderAttack[district] = underAttack == true
        ICT.updateTimers()
    end
end

function ICT.onFlagOwnershipChanged(_, keepId)
    if not ICT.running then return end
    for _, knownId in ipairs(ICT.icDistrictKeepIds) do
        if keepId == knownId then
            ICT.refreshFlagOwnership()
            ICT.updateTimers()
            return
        end
    end
end
