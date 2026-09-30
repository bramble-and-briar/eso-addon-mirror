local A = OneDungeon
local statusStrings = { completed = ONEDUNGEON_COMPLETED, incomplete = ONEDUNGEON_INCOMPLETE,
    unavailable = ONEDUNGEON_UNAVAILABLE, unknown = ONEDUNGEON_UNKNOWN }
A.achievementCache = {}

function A:ResolveAchievement(id)
    if not id or id == 0 then return { state = "unknown" } end
    if self.achievementCache[id] then return self.achievementCache[id] end
    local name, description, _, icon, complete = GetAchievementInfo(id)
    if not name or name == "" or type(complete) ~= "boolean" then return { state = "unknown", id = id } end
    local data = { id = id, name = name, description = description, icon = icon,
        state = complete and "completed" or "incomplete" }
    self.achievementCache[id] = data
    return data
end

function A:ResolveCategory(value)
    if value == false then return { state = "unavailable" } end
    if type(value) ~= "table" then return self:ResolveAchievement(value) end
    if #value == 0 then return { state = "unknown" } end
    if #value == 1 then return self:ResolveAchievement(value[1]) end
    local result = { state = "completed", ids = value, id = value[1], name = GetString(ONEDUNGEON_HARD_MODE_TITLE) }
    local descriptions = { GetString(ONEDUNGEON_ALL_HARD_MODES) }
    local representative, firstIncomplete
    for _, id in ipairs(value) do
        local data = self:ResolveAchievement(id)
        representative = representative or data
        if data.state == "incomplete" then firstIncomplete = firstIncomplete or data end
        if data.state == "unknown" then result.state = "unknown"
        elseif data.state == "incomplete" and result.state ~= "unknown" then result.state = "incomplete" end
        descriptions[#descriptions + 1] = (data.name or tostring(id)) .. ": " .. GetString(statusStrings[data.state]) .. "\n" .. (data.description or "")
    end
    representative = firstIncomplete or representative
    result.id, result.icon = representative.id, representative.icon
    result.description = table.concat(descriptions, "\n\n")
    return result
end

function A:GetAchievements(row)
    local result, entry = {}, self.catalog[row.zoneId] or {}
    for _, category in ipairs({ "veteranClear", "hardMode", "trifecta" }) do
        result[category] = self:Optional("achievement " .. category, function()
            return self:ResolveCategory(entry[category])
        end, { state = "unknown" })
    end
    return result
end

function A:Enrich(row)
    row.quest = self:Optional("quests", function() return self:GetQuestState(row) end,
        { story = "unknown", today = "unknown", active = "unknown" })
    row.achievements = self:Optional("achievements", function() return self:GetAchievements(row) end,
        { veteranClear = { state = "unknown" }, hardMode = { state = "unknown" }, trifecta = { state = "unknown" } })
end
