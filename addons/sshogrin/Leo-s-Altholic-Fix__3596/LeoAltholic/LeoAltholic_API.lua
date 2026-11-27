local LeoAltholic = LeoAltholic
local function get(tbl, k, ...)
    if tbl == nil or tbl[k] == nil then return nil end
    if select('#', ...) == 0 then return tbl[k] end
    return get(tbl[k], ...)
end

--[[
Return the timestamp from today's reset (specifically for craft writs)
]]
function LeoAltholic.TodayReset()
    local secondsUntilNextReset = GetTimeUntilNextDailyLoginRewardClaimS()
    if secondsUntilNextReset and secondsUntilNextReset > 0 then
        return (GetTimeStamp() + secondsUntilNextReset) - 86400
    end

    -- Fallback if called before EVENT_ADD_ON_LOADED (10:00 UTC NA / 03:00 UTC EU)
    local baseReset = (GetWorldName() == "EU Megaserver") and 1538190000 or 1538215200
    local diff = zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(), baseReset) / 86400)
    return baseReset + (diff * 86400)
end

--[[
Return if the timestamp is after the today's reset.
]]
function LeoAltholic.IsAfterReset(timestamp)
    if not timestamp then return false end
    return timestamp >= LeoAltholic.TodayReset()
end

--[[
Return if the timestamp is before the today's reset.
]]
function LeoAltholic.IsBeforeReset(timestamp)
    return timestamp <= LeoAltholic.TodayReset()
end

--[[
Formats a time
]]
function LeoAltholic.FormatTime(seconds, short, colorizeCountdown)
    if short == nil then short = false end
    local formats = {
        dhm = SI_TIME_FORMAT_DDHHMM_DESC_SHORT,
        day = SI_TIME_FORMAT_DAYS,
        hm = SI_TIME_FORMAT_HHMM_DESC_SHORT,
        hms = SI_TIME_FORMAT_HHMMSS_DESC_SHORT,
        hour = SI_TIME_FORMAT_HOURS,
        ms = SI_TIME_FORMAT_MMSS_DESC_SHORT,
        m = SI_TIME_FORMAT_MINUTES
    }
    if seconds and seconds > 0 then
        local ss = seconds % 60
        local mm = math.floor(seconds / 60)
        local hh = math.floor(mm / 60)
        mm = mm % 60
        local dn = math.floor(hh / 24)
        local hhdn = hh - (dn*24)

        local ssF = string.format("%02d", ss)
        local mmF = string.format("%02d", mm)
        local hhF = string.format("%02d", hh)
        local hhdnF = string.format("%02d", hhdn)

        local result = ''
        if dn > 0 then
            if short then
                result = ZO_CachedStrFormat(GetString(formats.day), dn) .." "..ZO_CachedStrFormat(GetString(formats.hour), hhdnF)
            else
                result = ZO_CachedStrFormat(GetString(formats.dhm), dn, hhdnF, mmF)
            end
        elseif hh > 0 then
            if short then
                result = ZO_CachedStrFormat(GetString(formats.hm), hhF, mmF)
            else
                result = ZO_CachedStrFormat(GetString(formats.hms), hhF, mmF, ssF)
            end
        elseif mm >= 0 then result = ZO_CachedStrFormat(GetString(formats.ms), mmF, ssF)
        end
        if colorizeCountdown == true then
            if seconds < 3600 then result = '|c'..LeoAltholic.color.hex.red..result..'|r'
            elseif seconds < 86400 then result = '|c'..LeoAltholic.color.hex.yellow..result..'|r'
            elseif seconds < 604800 then result = '|c'..LeoAltholic.color.hex.white..result..'|r'
            else result = '|c'..LeoAltholic.color.hex.green..result..'|r' end
        end
        return result
    else return '|cFF4020'..ZO_CachedStrFormat(GetString(formats.m), 0)..'|r' end
end

function LeoAltholic.TimeAgo(timestamp)
    local diff = GetTimeStamp() - timestamp
    if diff < 3600 then
        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_MINUTES), math.floor(diff / 60))
    elseif diff < 3600 then
        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_HOURS), math.floor(diff / 3600))
    else
        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_DAYS), math.floor(diff / 86400))
    end
    return ZO_CachedStrFormat(GetString(SI_TIME_DURATION_AGO), ago)
end

--[[
Return if the craft is done for the day for the charName (if not specified, the current character is used)
]]
function LeoAltholic.IsWritDoneToday(craft, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]
    if not char then return end
    for _, writ in pairs(char.quests.writs) do
        if craft == writ.craft then
--            return writ.lastDone ~= nil and LeoAltholic.IsAfterReset(writ.lastDone)    --original code, Teva added 2 conditions as shown on the next line
            return writ.lastDone ~= nil and LeoAltholic.IsAfterReset(writ.lastDone) and writ.lastDone > writ.lastStarted and LeoAltholic.IsAfterReset(writ.lastStarted)
        end
    end
    return false
end

function LeoAltholic.IsWritStartedToday(craft, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]
    if not char then return end
    for _, writ in pairs(char.quests.writs) do
        if craft == writ.craft then
            return writ.lastStarted ~= nil and LeoAltholic.IsAfterReset(writ.lastStarted)
        end
    end
    return false
end

function LeoAltholic.HasStillResearchFor(craft, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]
    if not char then return end
    for line = 1, GetNumSmithingResearchLines(craft) do
        local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
        for trait = 1, numTraits do
            if not char.research.done[craft][line][trait] then
                return true
            end
        end
    end
end

function LeoAltholic.GetNumMissingTraitsFor(craft, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]
    if not char then return end
    local missing = 0
    for line = 1, GetNumSmithingResearchLines(craft) do
        local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
        for trait = 1, numTraits do
            if not LeoAltholic.CharKnowsTrait(craft, line, trait, charName) then
                missing = missing + 1
            end
        end
    end
    return missing
end

function LeoAltholic.CharKnowsTrait(craftSkill, line, trait, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]
    if not char then return end
    if not char.research.done then return false end
    return get(char.research.done, craftSkill, line, trait) == true
end

function LeoAltholic.ResearchStatus(craftSkill, line, trait, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]

    local isKnown = LeoAltholic.CharKnowsTrait(craftSkill, line, trait, charName)
    local isResearching = false

    for _, researching in pairs(char.research.doing[craftSkill]) do
        if researching.line == line and researching.trait == trait then
            isResearching = researching.doneAt < GetTimeStamp()
            break
        end
    end

    return isKnown, isResearching
end

function LeoAltholic.GetNumTraitKnownPerLine(charName)
    local levels = {}
    for _,craft in pairs(LeoAltholic.craftResearch) do
        levels[craft] = {}
        for line = 1, GetNumSmithingResearchLines(craft) do
            levels[craft][line] = 0
            local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
            for trait = 1, numTraits do
                if LeoAltholic.CharKnowsTrait(craft, line, trait, charName) then
                    levels[craft][line] = levels[craft][line] + 1
                end
            end
        end
    end
    return levels
end

--[[
Return the number of researches in progress, the total and the time of the first one to be completed (can be 0 or negative,
  indicating it's done)
]]
function LeoAltholic.GetResearchCounters(craft, charName)
    if not charName then charName = LeoAltholic.CharName end
    local char = LeoAltholic.globalData.CharList[charName]
    if not char then return end
    local lowest = -1
    if #char.research.doing[craft] > 0 then
        local research = char.research.doing[craft][1]
        lowest = research.doneAt
	if charName == LeoAltholic.CharName then
	local _, remaining = GetSmithingResearchLineTraitTimes(craft, research.line, research.trait)
	if remaining ~= nil then
		research.doneAt = remaining + GetTimeStamp()
	end
else
local now = GetTimeStamp()
local remaining = GetDiffBetweenTimeStamps(research.doneAt, now)
research.doneAt = remaining + now
end
    end
    return #char.research.doing[craft], char.research.done[craft].max, lowest
end

local function copy(obj, seen)
    return obj -- major performance boost ...
    --[[if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res]]
end

--[[
Return a copy of the complete table with all tracked chars. Structure soon.
]]
function LeoAltholic.ExportCharacters(forceUpdate)
    LeoAltholic.GetCharacters(forceUpdate)
    local chars = copy(LeoAltholic.charList)
    return chars
end

--[[
Return the list of character names
]]
function LeoAltholic.GetCharactersNames()
    local list = {}
    for _, char in pairs(LeoAltholic.GetCharacters()) do
        table.insert(list, char.bio.name)
    end
    return list
end

--[[
Return all info on 1 char by name
]]
function LeoAltholic.GetCharByName(name, forceUpdate)
    local chars = LeoAltholic.ExportCharacters(forceUpdate)
    for k, v in pairs(chars) do
        if v.bio.name == name then return v end
    end
    return nil
end

--[[
Return all info on the current char
]]
function LeoAltholic.GetMyself()
    local myself = copy(LeoAltholic.globalData.CharList[LeoAltholic.CharName])
    return myself
end

--[[
Return if a specific tab is visible
]]
function LeoAltholic.IsTabVisible(tab)
    return LeoAltholic.hidden == false and LeoAltholic.globalData.activeTab == tab
end
