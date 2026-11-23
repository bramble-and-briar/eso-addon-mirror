local AH = _G.MarkTrialHelper
local fabledText = GetString(_G.MARKTRIALHELPER_FABLED):lower()
local shardText = GetString(_G.MARKTRIALHELPER_SHARD):lower()
local gwText = GetString(_G.MARKTRIALHELPER_GW):lower()
local flameShaperText = GetString(_G.MARKTRIALHELPER_FLAMESHAPER):lower()
-- local cache for performance
local GetUnitName, GetUnitTargetMarkerType = GetUnitName, GetUnitTargetMarkerType
local IsUnitDead, AssignTargetMarkerToReticleTarget = IsUnitDead, AssignTargetMarkerToReticleTarget
-- ТАБЛИЦА МАРКЕРОВ (КАК В IAHelper)
local MARKER_TABLE = {
    ["Fabled Infuser"]          = TARGET_MARKER_TYPE_FIVE,
    ["Fabled Spellthief"]       = TARGET_MARKER_TYPE_SIX,
    ["Fabled Flameshaper"]      = TARGET_MARKER_TYPE_FOUR,
    ["Fabled Sun-Eater"]        = TARGET_MARKER_TYPE_TWO,
    ["Fabled Totem Master"]     = TARGET_MARKER_TYPE_TWO,
    ["Fabled Brewmaster"]       = TARGET_MARKER_TYPE_FIVE,
    ["Fabled Stormcaller"]      = TARGET_MARKER_TYPE_FIVE,
    ["Fabled Lightbringer"]     = TARGET_MARKER_TYPE_TWO,
    ["Fabled Mystic"]           = TARGET_MARKER_TYPE_THREE,
    
    ["Dwarven Arquebus"]        = TARGET_MARKER_TYPE_ONE,
    ["Ascendant Archer"]        = TARGET_MARKER_TYPE_ONE,
    ["Grovebound Blightbow"]    = TARGET_MARKER_TYPE_ONE,
    ["Dreadhorn Scrapper"]      = TARGET_MARKER_TYPE_EIGHT,
    ["Dremora Conduit"]         = TARGET_MARKER_TYPE_ONE,
    ["Dro-m'Athra Conduit"]     = TARGET_MARKER_TYPE_ONE,
    ["Silver Rose Stormcaster"] = TARGET_MARKER_TYPE_ONE,
    ["Firesong Druid"]          = TARGET_MARKER_TYPE_EIGHT,
    ["Gw the Pilferer"]         = TARGET_MARKER_TYPE_EIGHT,
    
    -- Дополнительные опасные мобы
    ["Infuser"]                 = TARGET_MARKER_TYPE_FIVE,
    ["Spellthief"]              = TARGET_MARKER_TYPE_SIX,
    ["Flameshaper"]             = TARGET_MARKER_TYPE_FOUR,
    ["Imp"]                     = TARGET_MARKER_TYPE_ONE,
    ["Stormcaller"]             = TARGET_MARKER_TYPE_FIVE,
    ["Lightbringer"]            = TARGET_MARKER_TYPE_TWO,
    ["Brewmaster"]              = TARGET_MARKER_TYPE_FIVE,
    ["Conduit"]                 = TARGET_MARKER_TYPE_ONE,
    ["Scrapper"]                = TARGET_MARKER_TYPE_EIGHT,
    ["Mystic"]                  = TARGET_MARKER_TYPE_THREE,
}

-- marker 8 reserved for marauders
AH.MARKERS = {
    [1] = {marker = TARGET_MARKER_TYPE_ONE, used = false, manual = false},
    [2] = {marker = TARGET_MARKER_TYPE_TWO, used = false, manual = false},
    [3] = {marker = TARGET_MARKER_TYPE_THREE, used = false, manual = false},
    [4] = {marker = TARGET_MARKER_TYPE_FOUR, used = false, manual = false},
    [5] = {marker = TARGET_MARKER_TYPE_FIVE, used = false, manual = false},
    [6] = {marker = TARGET_MARKER_TYPE_SIX, used = false, manual = false},
    [7] = {marker = TARGET_MARKER_TYPE_SEVEN, used = false, manual = false}
}

local markerKeys = {1, 2, 3, 4, 5, 6, 7}

local function getMarkerIndex(marker)
    for index, info in ipairs(AH.MARKERS) do
        if (info.marker == marker) then
            return index
        end
    end
end

local function makeMarkerAvailable(marker)
    local index = type(marker) == "number" and marker or getMarkerIndex(marker)

    if (AH.MARKERS) then
        if (AH.MARKERS[index]) then
            AH.MARKERS[index].used = false
            AH.MARKERS[index].manual = false
        end
    end
end

local function getAvailableMarker()
    -- probably not necessary, but...
    table.sort(markerKeys)

    for _, key in ipairs(markerKeys) do
        if (AH.MARKERS[key].used == false) then
            AH.MARKERS[key].used = true

            return AH.MARKERS[key].marker, key
        end
    end

    -- all markers used up, reset and start again
    for _, info in pairs(AH.MARKERS) do
        info.used = false
    end

    return TARGET_MARKER_TYPE_ONE, 1
end

local function buildSearchTable()
    AH.SearchText = {}

    if (AH.CHECK_FABLED) then
        table.insert(AH.SearchText, fabledText)
    end

    if (AH.CHECK_SHARDS) then
        table.insert(AH.SearchText, shardText)
    end

    if (AH.CHECK_GW) then
        table.insert(AH.SearchText, gwText)
    end

    if (AH.CHECK_FLAMESHAPER) then
        table.insert(AH.SearchText, flameShaperText)
    end
end

local function doChecks()
    local stage, cycle, arc = ENDLESS_DUNGEON_MANAGER:GetProgression()

    AH.GetArchiveQuestIndexes()

    AH.CHECK_MARAUDERS = AH.Vars.MarauderCheck
    AH.CHECK_FABLED = AH.Vars.FabledCheck
    AH.CHECK_SHARDS = false
    AH.CHECK_GW = false
    AH.CHECK_FLAMESHAPER = false
    AH.FOUND_GW = false

    if (arc == 1) then
        -- no marauders in arc 1
        AH.CHECK_MARAUDERS = false
        if (cycle < 4) then
            -- no fabled before arc 1 cycle 4
            AH.CHECK_FABLED = false
        end
    end

    if (cycle < 5 and stage == 3) then
        -- possible fabled due to one boss, no marauders or shards
        AH.CHECK_FLAMESHAPER = true and AH.Vars.FabledCheck
        AH.CHECK_FABLED = false
        AH.CHECK_MARAUDERS = false
        AH.CHECK_SHARDS = false
        AH.CHECK_GW = true and AH.Vars.GwCheck
    end

    if (cycle == 5 and stage == 3 and arc < 4) then
        -- only get shards in cycle 5, stage 3, up to arc 4, no marauders or fabled
        AH.CHECK_SHARDS = true and AH.Vars.ShardCheck
        AH.CHECK_MARAUDERS = false
        AH.CHECK_FABLED = false
    end

    if ((arc >= 4 and cycle >= 3) and (not AH.ShardIgnore)) then
        -- shards now appear as trash mobs
        AH.CHECK_SHARDS = true and AH.Vars.ShardCheck
    end

    buildSearchTable()
end

local function isItDeadDave()
    if (IsUnitDead("reticleover")) then
        local marker = GetUnitTargetMarkerType("reticleover")

        if (marker ~= TARGET_MARKER_TYPE_NONE) then
            makeMarkerAvailable(marker)
        end
    end
end
-- НОВАЯ ФУНКЦИЯ МАРКЕРОВ (КАК В IAHelper)
function AH.ReticleChanged()
    if not AH.Vars.FabledCheck and not AH.Vars.ShardCheck and not AH.Vars.GwCheck and not AH.Vars.MarauderCheck then
        return
    end
    
    if not IsInstanceEndlessDungeon() then
        return
    end
    
    if not IsUnitAttackable("reticleover") then
        return
    end
    
    -- Проверяем, что мы лидер группы или соло
    if not IsUnitSoloOrGroupLeader("player") then
        return
    end
    
    local name = zo_strformat('<<1>>', GetUnitName("reticleover"))
    if not name or name == "" then
        return
    end
    
    -- Проверяем по полному имени (как в IAHelper)
    local marker = MARKER_TABLE[name]
    if not marker then
        -- Проверяем по части имени (для мобов с доп. словами)
        for key, value in pairs(MARKER_TABLE) do
            if name:find(key, 1, true) then
                marker = value
                break
            end
        end
    end
    
    if marker and GetUnitTargetMarkerType("reticleover") ~= marker then
        AssignTargetMarkerToReticleTarget(marker)
    end
end

local function find(name)
    name = name:lower()

    for _, text in ipairs(AH.SearchText) do
        if (name:find(text, 1, true)) then
            return text
        end
    end

    return false
end

local function markerCheck()
    local extantMarker = GetUnitTargetMarkerType("reticleover")

    if (extantMarker == TARGET_MARKER_TYPE_NONE) then
        local found = find(GetUnitName("reticleover"))

        if (found and (not IsUnitDead("reticleover"))) then
            local marker = getAvailableMarker()
            AssignTargetMarkerToReticleTarget(marker)

            if ((found == gwText) and (not AH.FOUND_GW)) then
                if (AH.Vars.GwPlay) then
                    AH.PlayAlarm(AH.Sounds.Gw)
                end
                AH.FOUND_GW = true
                AH.ShareData(AH.SHARE.GW, 2)
            end
        end
    elseif (extantMarker ~= TARGET_MARKER_TYPE_EIGHT) then
        -- sanity check
        local index = getMarkerIndex(extantMarker)

        if (not find(GetUnitName("reticleover")) and (not AH.MARKERS[index].manual)) then
            AssignTargetMarkerToReticleTarget(extantMarker)
            makeMarkerAvailable(index)
        end
    end
end

function AH.MarauderCheck()
    if (AH.MARAUDER) then
        local extantMarker = GetUnitTargetMarkerType("reticleover")

        if (extantMarker == TARGET_MARKER_TYPE_NONE) then
            if (GetUnitName("reticleover") == AH.MARAUDER and not IsUnitDead("reticleover")) then
                AssignTargetMarkerToReticleTarget(TARGET_MARKER_TYPE_EIGHT)
            end
        elseif (extantMarker == TARGET_MARKER_TYPE_EIGHT) then
            -- sanity check
            if (not GetUnitName("reticleover") == AH.MARAUDER) then
                AssignTargetMarkerToReticleTarget(extantMarker)
            end
        end
    end
end

-- for keybinds
function AH.MarkCurrentTarget()
    if (GetUnitTargetMarkerType("reticleover") == TARGET_MARKER_TYPE_NONE) then
        local marker, key = getAvailableMarker()

        AssignTargetMarkerToReticleTarget(marker)
        AH.MARKERS[key].manual = true
        AH.ShareData(AH.SHARE.MARK, key)
    end
end

function AH.UnmarkCurrentTarget()
    local marker = GetUnitTargetMarkerType("reticleover")

    if (marker ~= TARGET_MARKER_TYPE_NONE) then
        AssignTargetMarkerToReticleTarget(marker)
        makeMarkerAvailable(marker)
        AH.ShareData(AH.SHARE.UNMARK, getMarkerIndex(marker))
    end
end

function AH.CombatCheck(_, incombat)
    local check = AH.Vars.FabledCheck and AH.CompatibilityCheck()

    check = check or AH.Vars.MarauderCheck or AH.Vars.ShardCheck or AH.Vars.GwCheck

    if (check and AH.InsideArchive) then
        if (not incombat) then
            EVENT_MANAGER:UnregisterForEvent(AH.Name .. "_Fabled", EVENT_COMBAT_EVENT)
            EVENT_MANAGER:UnregisterForEvent(AH.Name, EVENT_RETICLE_TARGET_CHANGED)

            for _, info in pairs(AH.MARKERS) do
                info.used = false
            end

            AH.MARAUDER = nil
        else
            doChecks()

            -- Используем новый обработчик как в IAHelper
            EVENT_MANAGER:RegisterForEvent(AH.Name, EVENT_RETICLE_TARGET_CHANGED, function()
                if (AH.InsideArchive) then
                    AH.ReticleChanged()
                    
                    if (#AH.SearchText > 0) then
                        markerCheck()
                    end

                    if (AH.CHECK_MARAUDERS) then
                        AH.MarauderCheck()
                    end

                    isItDeadDave()
                end
            end)
        end
    end

    AH.InCombet = incombat
end