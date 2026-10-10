if SPT == nil then SPT = {} end
local Skills = { firstCharacter = 1, stateKey = "Skills" }
SPT.Skills = Skills

local categories = {
    SKILL_TYPE_CLASS, SKILL_TYPE_WEAPON, SKILL_TYPE_ARMOR, SKILL_TYPE_WORLD,
    SKILL_TYPE_GUILD, SKILL_TYPE_AVA, SKILL_TYPE_RACIAL, SKILL_TYPE_TRADESKILL,
}

local function ReadState(skillType, index)
    -- Use committed engine state, not the manager's pending respec overrides.
    local rank, _, active, discovered = GetSkillLineDynamicInfo(skillType, index)
    return (rank or 0) * 4 + (discovered and 1 or 0) + (active and 2 or 0)
end

local function UnpackState(state)
    return math.floor(state / 4), state % 2 == 1, math.floor(state / 2) % 2 == 1
end

local function CanGainRankXP(skillType, index, rank)
    local startXP, nextXP = GetSkillLineRankXPExtents(skillType, index, rank)
    return startXP ~= nil and nextXP ~= nil and nextXP > startXP
end

local function GetMaximumRank(skillType, index)
    if not CanGainRankXP(skillType, index, 1) then return end
    -- The cap is the first rank without an advancing XP interval. The engine may
    -- return nil extents there, rather than a terminal 0/equal XP pair.
    local low, high = 1, 2
    while CanGainRankXP(skillType, index, high) do
        low, high = high, high * 2
        if high > 2147483647 then return end
    end
    while high - low > 1 do
        local middle = math.floor((low + high) / 2)
        if CanGainRankXP(skillType, index, middle) then low = middle else high = middle end
    end
    return high
end

function Skills:IsReady()
    return SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER:IsDataReady()
end

function Skills:Capture(checkpoint)
    if not self:IsReady() then return end
    local parts = {}
    for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, line in skillTypeData:SkillLineIterator() do
            local skillType, index = line:GetIndices()
            if not line:IsClassMastery() and CanGainRankXP(skillType, index, 1) then
                parts[#parts + 1] = string.format("%d:%d,", line:GetId(), ReadState(skillType, index))
            end
            if checkpoint then checkpoint() end
        end
    end
    if #parts == 0 then return end -- Never replace a good snapshot with uninitialized data.
    table.sort(parts)
    SPT.CharCache:WriteProgressionSnapshot("skillLines", "1;" .. table.concat(parts))
end

function Skills:Init()
    local function OnLineUpdated(line)
        if not SPT.progressionReady or line:IsClassMastery() then return end
        if self.pending then SPT:QueueProgressionSnapshot(self, true); return end
        local entry = SPT.CharCache.roster[SPT.CharCache:GetCharId()]
        local snapshot = entry and entry.skillLines
        local skillType, index = line:GetIndices()
        if not CanGainRankXP(skillType, index, 1) then return end
        local previous = type(snapshot) == "string" and snapshot:match("[;,]" .. line:GetId() .. ":(%d+),")
        -- SkillLineUpdated includes XP events. Ignore those that leave our state unchanged.
        if tonumber(previous) ~= ReadState(skillType, index) then
            SPT:QueueProgressionSnapshot(self, true)
        end
    end
    if SKILLS_DATA_MANAGER then
        SKILLS_DATA_MANAGER:RegisterCallback("FullSystemUpdated", function() SPT:QueueProgressionSnapshot(self) end)
        SKILLS_DATA_MANAGER:RegisterCallback("SkillLineAdded", OnLineUpdated)
        SKILLS_DATA_MANAGER:RegisterCallback("SkillLineUpdated", OnLineUpdated)
    end
end

function Skills:ReleaseDisplay()
    self.catalog = nil
end

function Skills:GetCatalog()
    if self.catalog then return self.catalog end
    if not self:IsReady() then return end
    local catalog = {}
    for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        local skillType = skillTypeData:GetSkillType()
        for _, line in skillTypeData:SkillLineIterator() do
            if not line:IsClassMastery() then
                local _, index = line:GetIndices()
                local maxRank = GetMaximumRank(skillType, index)
                if maxRank then
                    catalog[#catalog + 1] = {
                        id = line:GetId(), skillType = skillType, index = index, maxRank = maxRank,
                        classId = GetSkillLineClassId(skillType, index),
                        name = zo_strformat("<<C:1>>", GetSkillLineNameById(line:GetId())),
                    }
                end
            end
        end
    end
    self.catalog = catalog
    return catalog
end

local function GetCategoryName(skillType)
    return SKILLS_DATA_MANAGER:GetSkillTypeData(skillType):GetName()
end

local function IsApplicable(line, state, classId)
    if state == nil then return true end
    local _, discovered, active = UnpackState(state)
    if line.skillType == SKILL_TYPE_CLASS then
        return line.classId == classId or discovered or active
    elseif line.skillType == SKILL_TYPE_RACIAL then
        return active
    end
    return true
end

local function IsComplete(line, state)
    if state == nil then return false end
    local rank, discovered = UnpackState(state)
    return discovered and rank >= line.maxRank
end

local function FormatRank(line, state, classId)
    if state == nil then return "?" end
    if not IsApplicable(line, state, classId) then return "-" end
    local rank, discovered, active = UnpackState(state)
    local text = discovered and tostring(rank) or "--"
    if not active then text = text .. "*" end
    return IsComplete(line, state) and SPT:ColorCompletedProgression(text, true) or "|cE8B864" .. text .. "|r"
end

local function GetStates(charId, catalog)
    if charId == SPT.CharCache:GetCharId() then
        local states = {}
        for _, line in ipairs(catalog) do
            states[line.id] = ReadState(line.skillType, line.index)
        end
        return states
    end
    return SPT:DecodeProgressionSnapshot(SPT.CharCache.roster[charId].skillLines, true)
end

local function GetCounts(catalog, states, skillType, classId)
    local done, total, unknown = 0, 0, 0
    for _, line in ipairs(catalog) do
        if line.skillType == skillType then
            local state = states[line.id]
            if state == nil then
                unknown = unknown + 1
            elseif IsApplicable(line, state, classId) then
                local _, discovered, active = UnpackState(state)
                if discovered and active then
                    total = total + 1
                    if IsComplete(line, state) then done = done + 1 end
                end
            end
        end
    end
    return SPT:FormatProgressionCount(done, total, unknown)
end

function Skills:BuildView()
    local catalog = self:GetCatalog()
    local view = SPT:CreateProgressionTableView(self, GetString(SPT_GUI_SKILL_LINE), GetString(SPT_GUI_SKILLS_LEGEND))
    view.infoTitle = GetString(SPT_GUI_TAB_SKILLS)
    if not catalog then
        view.rows[1] = { source = GetString(SPT_GUI_DATA_UNAVAILABLE), cells = {} }
        return SPT:FinishProgressionTableView(view)
    end

    for _, category in ipairs(categories) do
        local expanded = SPT:IsProgressionGroupExpanded(self, category)
        view.rows[#view.rows + 1] = { source = (expanded and "[-] " or "[+] ") .. GetCategoryName(category),
            groupId = category, rowKey = "category:" .. category, cells = {},
            tooltipTitle = view.infoTitle .. " - " .. GetCategoryName(category) }
        if expanded then
            for _, line in ipairs(catalog) do
                if line.skillType == category then
                    view.rows[#view.rows + 1] = { source = "  " .. line.name,
                        rowKey = "line:" .. line.id, line = line, cells = {},
                        tooltipTitle = view.infoTitle .. " - " .. line.name }
                end
            end
        end
    end

    local roster = SPT.CharCache:GetSortedIds()
    local visibleColumns = {}
    for column, id in ipairs(view.characters) do visibleColumns[id] = column end
    for _, row in ipairs(view.rows) do
        row.info = {}
        row.maxedCharacters, row.applicableCharacters, row.unknownCharacters = 0, 0, 0
    end
    -- Decode one character at a time; retain only rows, totals, and compact text.
    for _, id in ipairs(roster) do
        local entry = SPT.CharCache.roster[id]
        local states = GetStates(id, catalog)
        local classId = SPT.CharCache:GetClassId(id)
        local column = visibleColumns[id]
        for _, row in ipairs(view.rows) do
            local text
            if row.groupId then
                text = states and GetCounts(catalog, states, row.groupId, classId) or "?"
            else
                local state = states and states[row.line.id]
                text = FormatRank(row.line, state, classId)
                if state == nil then
                    row.unknownCharacters = row.unknownCharacters + 1
                elseif IsApplicable(row.line, state, classId) then
                    row.applicableCharacters = row.applicableCharacters + 1
                    if IsComplete(row.line, state) then row.maxedCharacters = row.maxedCharacters + 1 end
                end
            end
            if column then row.cells[column] = text end
            row.info[#row.info + 1] = entry.name .. ": " .. text
        end
    end
    for _, row in ipairs(view.rows) do
        if row.line then
            local complete = row.applicableCharacters > 0 and row.maxedCharacters == row.applicableCharacters
                and row.unknownCharacters == 0
            row.sourceName = "  " .. SPT:ColorCompletedProgression(row.line.name, complete)
            local total = string.format("[%d/%d]%s", row.maxedCharacters, row.applicableCharacters,
                row.unknownCharacters > 0 and " ?" or "")
            row.accountTotal = SPT:ColorCompletedProgression(total, complete)
            row.source = row.sourceName .. " " .. row.accountTotal
        end
    end
    return SPT:FinishProgressionTableView(view)
end
