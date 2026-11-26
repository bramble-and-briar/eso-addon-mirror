-- Original catalog model; source data comes from the bundled acquisition catalog.
AntiquityAtlas = AntiquityAtlas or {}
local A = AntiquityAtlas
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    -- Optional provider methods may be absent; errors in present methods must remain visible.
    local value = fn(...)
    return value
end
A.Call = call
local function method(object, name, ...)
    if object and type(object[name]) == "function" then return call(object[name], object, ...) end
end
A.Method = method
local function format(text)
    return A.DisplayName(text)
end
local function lower(text)
    return (zo_strlower or string.lower)(text or "")
end
A.Lower = lower
function A.ItemLink(setId)
    local itemId = A.Data and A.Data.SETID_2_ITEMID and A.Data.SETID_2_ITEMID[setId]
    if itemId then
        return string.format("|H1:item:%d:4:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h", itemId)
    end
end
function A.Read()
    local ready, message = A.RefreshGeography()
    if not ready then return nil, message end
    ready, message = A.RefreshProvider()
    if not ready then return nil, message end
    local provider = A.Data or {}
    local groups, leads = {}, {}
    local id = GetNextAntiquityId()
    while id do
        local setId = GetAntiquitySetId(id) or 0
        local name = format(GetAntiquityName(id))
        local source = provider.Locations and provider.Locations[id]
        if not source or not source[1] or source[1] == "" or string.find(source[1], "??", 1, true) then
            source = (A.FallbackLocations and A.FallbackLocations[id]) or source
        end
        local zoneId = GetAntiquityZoneId(id)
        local findZoneId = provider.FindScryDifferentZones and provider.FindScryDifferentZones[id] or zoneId
        local findZone = A.FindZoneName(findZoneId)
        local englishSource = A.FallbackLocations and A.FallbackLocations[id]
        local row = {
            id = id, setId = setId, name = name,
            quality = GetAntiquityQuality(id) or 1,
            have = DoesAntiquityHaveLead(id), dug = GetNumAntiquitiesRecovered(id) or 0,
            seconds = GetAntiquityLeadTimeRemainingSeconds(id) or 0,
            zone = A.ZoneName(zoneId), findZone = findZone,
            zoneId = zoneId, findZoneId = findZoneId,
            sourceRaw = source and source[1] or "",
            sourceShort = source and source[3] or "",
            sourceType = source and source[2] or "",
            sourceTypeEnglish = englishSource and englishSource[2] or "",
            sourceEnglish = englishSource and ((englishSource[1] or "") .. " " .. (englishSource[3] or "")) or "",
            source = A.LocalizeSource(source and source[1] ~= "" and source[1] or A.L("Источник пока не указан")),
            reward = GetAntiquityRewardId(id),
            icon = call(GetAntiquityIcon, id),
        }
        row.source = A.LocalizeSource(source and source[1] ~= "" and source[1] or A.L("Источник пока не указан"), row)
        local key = setId > 0 and "s" .. setId or "a" .. id
        local group = groups[key]
        if not group then
            local data = setId > 0 and method(ANTIQUITY_DATA_MANAGER, "GetAntiquitySetData", setId)
            local reward = setId > 0 and (call(GetAntiquitySetRewardId, setId) or method(data, "GetRewardId")) or row.reward
            group = {
                key = key, name = setId > 0 and format(GetAntiquitySetName(setId)) or name,
                setId = setId, quality = setId > 0 and (GetAntiquitySetQuality(setId) or row.quality) or row.quality,
                parts = {}, reward = reward, link = A.ItemLink(setId),
            }
            group.mythic = group.link ~= nil
            group.kind = group.mythic and A.L("Мифик") or (reward and method(REWARDS_MANAGER, "GetRewardContextualTypeString", reward)) or A.L("Составная награда")
            if group.kind == "" then group.kind = A.L("Древность") end
            group.icon = (group.link and call(GetItemLinkIcon, group.link))
                or (setId > 0 and call(GetAntiquitySetIcon, setId)) or call(GetAntiquityIcon, id)
                or "/esoui/art/icons/icon_missing.dds"
            groups[key] = group
        end
        row.group = group
        table.insert(group.parts, row)
        table.insert(leads, row)
        id = GetNextAntiquityId(id)
    end
    local rewards = {}
    for _, group in pairs(groups) do
        group.have, group.dug, group.minimum, group.expiry = 0, 0, math.huge, math.huge
        local haystack = { group.name, group.kind }
        for _, part in ipairs(group.parts) do
            if part.have then group.have = group.have + 1 end
            if part.dug > 0 then group.dug = group.dug + 1 end
            group.minimum = math.min(group.minimum, part.dug)
            if part.have and part.seconds > 0 then group.expiry = math.min(group.expiry, part.seconds) end
            table.insert(haystack, part.name .. " " .. part.source .. " " .. (part.sourceRaw or "") .. " " .. (part.sourceShort or "") .. " " .. (part.sourceEnglish or "") .. " " .. part.findZone)
        end
        -- Current assembly must be relative to the least excavated part, not lifetime dug > 0.
        group.current = 0
        for _, part in ipairs(group.parts) do
            part.current = part.dug > group.minimum
            if part.current then group.current = group.current + 1 end
        end
        group.search = lower(table.concat(haystack, " "))
        table.sort(group.parts, function(a, b) return a.id < b.id end)
        table.insert(rewards, group)
    end
    A.rewards, A.leads = rewards, leads
    return rewards
end
function A.Matches(group, state)
    if state.tab == "mythics" and not group.mythic then return false end
    if state.tab == "owned" and group.have == 0 then return false end
    if state.tab == "history" and group.dug == 0 then return false end
    if state.quality >= 0 and group.quality ~= state.quality then return false end
    if state.kind and state.kind ~= A.L("Все типы") and group.kind ~= state.kind then return false end
    local text = lower(state.query)
    if text ~= "" and not string.find(group.search, text, 1, true) then return false end
    if state.status == 2 and group.have == 0 then return false end
    if state.status == 3 and group.dug > 0 then return false end
    if state.status == 4 and group.minimum > 0 then return false end
    return true
end
function A.AssemblyProgress(group)
    local count = 0
    for _, part in ipairs(group.parts) do
        -- One part fills one assembly slot, even if a new copy of its lead is held.
        if part.have or part.current then count = count + 1 end
    end
    return count
end
function A.Filter(state)
    local result, progress = {}, {}
    for _, group in ipairs(A.rewards or {}) do
        if A.Matches(group, state) then
            table.insert(result, group)
            if state.sort == 4 then progress[group] = A.AssemblyProgress(group) / math.max(1, #group.parts) end
        end
    end
    table.sort(result, function(a, b)
        if state.sort == 4 and (#a.parts > 1) ~= (#b.parts > 1) then
            return #a.parts > 1
        end
        if state.sort == 2 and a.quality ~= b.quality then return a.quality > b.quality end
        if state.sort == 3 and a.expiry ~= b.expiry then return a.expiry < b.expiry end
        if state.sort == 4 and progress[a] ~= progress[b] then
            return progress[a] > progress[b]
        end
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return result
end
function A.PartStatus(part, group)
    local lines = {}
    if part.have then
        local time = part.seconds > 0 and string.format(A.L(" · %.1f дней"), part.seconds / 86400) or A.L(" · срок не указан")
        table.insert(lines, A.L("|c6ED9F5Зацепка есть") .. time .. "|r")
    end
    if #group.parts > 1 then
        if part.current then table.insert(lines, A.L("|c84D69AВыкопано для текущей сборки|r"))
        elseif not part.have then table.insert(lines, A.L("|cF2B872Нужна зацепка для новой сборки|r")) end
    elseif not part.have and part.dug == 0 then
        table.insert(lines, A.L("|cF2B872Зацепка не найдена|r"))
    end
    table.insert(lines, string.format(A.L("Выкопано всего: %d"), part.dug))
    return table.concat(lines, "\n")
end
