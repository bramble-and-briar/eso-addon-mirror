KD = KyzderpsDerps
KD.Altoholic = KD.Altoholic or {}
local Altoholic = KD.Altoholic


---------------------------------------------------------------------
-- Current saved values structure
---------------------------------------------------------------------
--[[
characters = {
    Kyrozan = {
        availPoints = 13,
        playedTime = 123987219841,
        armoryBuilds = {
            {
                name = Stam,
            },
            {
                name = Tank,
            }
        }
    }
}
]]


---------------------------------------------------------------------
-- Update the character's data
---------------------------------------------------------------------
local function UpdateSkillPoints()
    local currCharInfo = KD.savedValues.charIdInfo[GetCurrentCharacterId()]
    currCharInfo.availPoints = GetAvailableSkillPoints()

    -- Collect total skill points using skills data manager, since respecs are now free
    local totalUsed = 0
    for skillType = 1, GetNumSkillTypes() do
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            local skillLineId = GetSkillLineId(skillType, skillLineIndex)
            local _, _, isActive = GetSkillLineDynamicInfo(skillType, skillLineIndex)
            if (isActive) then
                local skillLineData = SKILLS_DATA_MANAGER:GetSkillLineDataById(skillLineId)
                if (skillLineData and skillLineData.GetNumPointsAllocated) then
                    totalUsed = totalUsed + skillLineData:GetNumPointsAllocated()
                end
            end
        end
    end
    currCharInfo.totalPoints = totalUsed + GetAvailableSkillPoints()
end

local function UpdatePlayedTime()
    local currCharInfo = KD.savedValues.charIdInfo[GetCurrentCharacterId()]
    currCharInfo.playedTime = GetSecondsPlayed()
end

local function UpdateArmoryBuilds()
    local builds = {}
    for i = 1, GetNumUnlockedArmoryBuilds() do
        local build = {}
        local name = GetArmoryBuildName(i)
        if (not name or name == "") then
            name = "[Empty]"
        end
        build.name = name
        table.insert(builds, {name = name, iconIndex = GetArmoryBuildIconIndex(i)})
    end

    local currCharInfo = KD.savedValues.charIdInfo[GetCurrentCharacterId()]
    currCharInfo.armoryBuilds = builds
end

local function UpdateAll()
    UpdatePlayedTime()
    UpdateSkillPoints()
    UpdateArmoryBuilds()
end


---------------------------------------------------------------------
-- Sort a table using a particular order
---------------------------------------------------------------------
-- lazy, copied from https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a, b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end


---------------------------------------------------------------------
-- Build the entire string for all played
---------------------------------------------------------------------
function Altoholic.BuildPlayed(accName)
    accName = accName or GetUnitDisplayName("player")
    if (accName == GetUnitDisplayName("player")) then
        UpdatePlayedTime()
    end

    -- Get SV
    local tab = KyzderpsDerpsSavedVariables.Default[accName]
    if (not tab) then
        return "|cFF0000Unknown account name: " .. accName, 0
    end
    tab = tab["$AccountWide"].Values.charIdInfo
    if (not tab) then
        return "|cFF0000Account " .. accName .. " hasn't been migrated to character IDs yet!", 0
    end

    local result = "=== Time Played ==="
    local totalTime = 0

    -- sort by descending amount played
    for charId, info in spairs(tab, function(t, a, b) return t[b].playedTime < t[a].playedTime end) do
        local seconds = info.playedTime
        local name = info.lastKnownName
        totalTime = totalTime + seconds
        result = result .. "\n|cFFFFFF" .. name .. " -|r "
        result = result .. ZO_FormatTime(seconds, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL, TIME_FORMAT_PRECISION_SECONDS)
        result = result .. "|cFFFFFF" .. string.format(" (%.2f hours)", seconds / 3600) .. "|r"
    end

    -- print the total as well
    result = result .. "\n\n|cFFFFFFTOTAL -|r "
    result = result .. ZO_FormatTime(totalTime, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL, TIME_FORMAT_PRECISION_SECONDS)
    result = result .. "|cFFFFFF" .. string.format(" (%.2f hours)", totalTime / 3600) .. "|r"

    return result, totalTime
end

function Altoholic.BuildPlayedAll()
    local totalTime = 0
    for accName, _ in pairs(KyzderpsDerpsSavedVariables.Default) do
        local str, time = Altoholic.BuildPlayed(accName)
        CHAT_ROUTER:AddSystemMessage(zo_strformat("vvv <<1>> vvv\n<<2>>\n^^^ <<1>> ^^^", accName, str))
        totalTime = totalTime + time
    end

    CHAT_ROUTER:AddSystemMessage(string.format("|c00FF00Total TOTAL time -|r %s |c00FF00(%.2f hours)|r", ZO_FormatTime(totalTime, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL, TIME_FORMAT_PRECISION_SECONDS), totalTime / 3600))
end


---------------------------------------------------------------------
-- Build the entire string for available skill points
---------------------------------------------------------------------
function Altoholic.BuildPoints()
    UpdateSkillPoints()

    local result = "=== Unspent / Approx.Total Skill Points ==="

    -- sort by descending unspent skill points
    for charId, info in spairs(KD.savedValues.charIdInfo, function(t, a, b) return t[b].availPoints < t[a].availPoints end) do
        local name = info.lastKnownName
        result = result .. "\n|cFFFFFF" .. name .. " -|r "
        result = result .. tostring(info.availPoints)
        if (info.totalPoints) then
            result = result .. " |cAAAAAA/ " .. tostring(info.totalPoints) .. "|r"
        end
    end

    return result
end


---------------------------------------------------------------------
-- Build the entire string for total skill points
---------------------------------------------------------------------
function Altoholic.BuildTotalPoints()
    UpdateSkillPoints()

    local result = "=== Unspent / Approx.Total Skill Points ==="

    -- sort by descending total skill points
    for charId, info in spairs(KD.savedValues.charIdInfo, function(t, a, b) return (t[b].totalPoints or 0) < (t[a].totalPoints or 0) end) do
        local name = info.lastKnownName
        result = result .. "\n|cFFFFFF" .. name .. " - |cAAAAAA"
        result = result .. tostring(info.availPoints) .. "|r"
        if (info.totalPoints) then
            result = result .. " / " .. tostring(info.totalPoints)
        end
    end

    return result
end


---------------------------------------------------------------------
-- Build the entire string for armory builds
---------------------------------------------------------------------
function Altoholic.BuildArmory()
    UpdateArmoryBuilds()

    local result = "=== Armory Builds ==="

    -- Sort by character index
    for index = 1, GetNumCharacters() do
        local name, _, _, _, _, _, charId = GetCharacterInfo(index)
        local info = KD.savedValues.charIdInfo[charId]
        if (info and info.armoryBuilds) then
            local buildNames = {}
            for _, build in ipairs(info.armoryBuilds) do
                local buildString = string.format("|t24:24:/esoui/art/armory/buildicons/buildicon_%d.dds|t%s", build.iconIndex, build.name)
                table.insert(buildNames, buildString)
            end

            result = result .. string.format("\n%s (%d) - ", name, #buildNames)
            result = result .. table.concat(buildNames, " || ", 1, math.min(5, #buildNames))
            if (#buildNames > 5) then
                -- Apparently, with too many builds, or probably just too long of a message
                -- due to my color coding, it won't show for the same line
                result = result .. "\n    ... " .. table.concat(buildNames, " || ", 6)
            end
        end
    end

    return result
end


---------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------
function Altoholic.Initialize()
    KD:dbg("    Initializing Altoholic module...")

    -- 1-time migration, or initialize
    if (ZO_IsTableEmpty(KD.savedValues.charIdInfo)) then
        for index = 1, GetNumCharacters() do
            local name, _, _, _, _, _, charId = GetCharacterInfo(index)
            local formattedName = zo_strformat("<<1>>", name)

            local oldInfo = KD.savedValues.charInfo and (KD.savedValues.charInfo.characters[name] or KD.savedValues.charInfo.characters[formattedName])
            if (oldInfo) then
                KD.savedValues.charIdInfo[charId] = ZO_DeepTableCopy(oldInfo)
                KD.savedValues.charIdInfo[charId].lastKnownName = formattedName
            end
        end
    end

    -- Could be new char (or the other megaserver that wasn't migrated)
    if (not KD.savedValues.charIdInfo[GetCurrentCharacterId()]) then
        KD.savedValues.charIdInfo[GetCurrentCharacterId()] = {}
    end

    -- yeah it's probably nicer to loop through GetCharacterInfo to display most updated char names,
    -- but this way the SVs also have a name for readability for people (me) who like to dig around
    -- in there, and also lets me be lazy and not have to update as much code
    KD.savedValues.charIdInfo[GetCurrentCharacterId()].lastKnownName = zo_strformat("<<1>>", GetUnitName("player"))

    -- Get rid of this weird bug that happened at some point, maybe not initialized?
    if (KD.savedValues.charInfo) then
        KD.savedValues.charInfo.characters["LocalPlayer"] = nil
        -- TODO: yeet charInfo at some point
    end
    KD.savedValues.playedChart = nil -- yeet the old af thing

    UpdateAll()

    ZO_PreHook("ReloadUI", UpdateAll)
    ZO_PreHook("Logout", UpdateAll)
    ZO_PreHook("SetCVar", UpdateAll)
    ZO_PreHook("Quit", UpdateAll)

    EVENT_MANAGER:RegisterForEvent(KD.name .. "SkillPoint", EVENT_SKILL_POINTS_CHANGED, UpdateSkillPoints)
end
