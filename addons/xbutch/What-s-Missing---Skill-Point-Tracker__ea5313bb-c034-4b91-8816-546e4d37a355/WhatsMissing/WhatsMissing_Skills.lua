if SPT == nil then SPT = {} end
local Skills = { firstCharacter = 1 }
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

function Skills:IsReady()
    return SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER:IsDataReady()
end

function Skills:Capture()
    if not self:IsReady() then return end
    local parts = {}
    for _, skillTypeData in SKILLS_DATA_MANAGER:SkillTypeIterator() do
        for _, line in skillTypeData:SkillLineIterator() do
            if not line:IsClassMastery() then
                local skillType, index = line:GetIndices()
                parts[#parts + 1] = string.format("%d:%d,", line:GetId(), ReadState(skillType, index))
            end
        end
    end
    if #parts == 0 then return end -- Never replace a good snapshot with uninitialized data.
    table.sort(parts)
    SPT.CharCache:WriteProgressionSnapshot("skillLines", "1;" .. table.concat(parts))
end

function Skills:Init()
    local function OnLineUpdated(line)
        if not SPT.progressionReady or line:IsClassMastery() then return end
        local entry = SPT.CharCache.roster[SPT.CharCache:GetCharId()]
        local snapshot = entry and entry.skillLines
        local skillType, index = line:GetIndices()
        local previous = type(snapshot) == "string" and snapshot:match("[;,]" .. line:GetId() .. ":(%d+),")
        -- SkillLineUpdated includes XP events. Ignore those that leave our state unchanged.
        if tonumber(previous) ~= ReadState(skillType, index) then
            SPT:QueueProgressionSnapshot(self)
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
                catalog[#catalog + 1] = {
                    id = line:GetId(), skillType = skillType, index = index,
                    classId = GetSkillLineClassId(skillType, index),
                    name = zo_strformat("<<C:1>>", GetSkillLineNameById(line:GetId())),
                }
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
    if not discovered or rank < 1 then return false end
    -- Rank extents are static native data, including for an offline character's rank.
    local startXP, nextXP = GetSkillLineRankXPExtents(line.skillType, line.index, rank)
    return startXP ~= nil and (nextXP == nil or nextXP == 0 or nextXP == startXP)
end

local function FormatRank(line, state, classId)
    if state == nil then return "?" end
    if not IsApplicable(line, state, classId) then return "n/a" end
    local rank, discovered, active = UnpackState(state)
    local text = discovered and tostring(rank) or "--"
    if not active then text = text .. "*" end
    return IsComplete(line, state) and "|cFFFFFF" .. text .. "|r" or "|cE8B864" .. text .. "|r"
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
        if line.skillType == skillType and IsApplicable(line, states[line.id], classId) then
            total = total + 1
            if states[line.id] == nil then unknown = unknown + 1 end
            if IsComplete(line, states[line.id]) then done = done + 1 end
        end
    end
    return string.format("%d/%d%s", done, total, unknown > 0 and " ?" or "")
end

function Skills:BuildView()
    local catalog = self:GetCatalog()
    local view = SPT:CreateProgressionTableView(self, GetString(SPT_GUI_SKILL_LINE), GetString(SPT_GUI_SKILLS_LEGEND))
    view.infoTitle = GetString(SPT_GUI_TAB_SKILLS)
    if not catalog then
        view.rows[1] = { source = GetString(SPT_GUI_DATA_UNAVAILABLE), cells = {} }
        return view
    end

    for _, category in ipairs(categories) do
        local expanded = SPT:IsProgressionGroupExpanded(self, category)
        view.rows[#view.rows + 1] = { source = (expanded and "[-] " or "[+] ") .. GetCategoryName(category),
            groupId = category, rowKey = "category:" .. category, cells = {} }
        if expanded then
            for _, line in ipairs(catalog) do
                if line.skillType == category then
                    view.rows[#view.rows + 1] = { source = "  " .. line.name,
                        rowKey = "line:" .. line.id, line = line, cells = {},
                        info = { line.name, GetCategoryName(category), GetString(SPT_GUI_SKILLS_RANK_LEGEND) } }
                end
            end
        end
    end

    for column, id in ipairs(view.characters) do
        local entry = SPT.CharCache.roster[id]
        local states = GetStates(id, catalog)
        local classId = SPT.CharCache:GetClassId(id)
        local status = SPT:GetProgressionStatus(id, "skillLines", states ~= nil)
        for _, row in ipairs(view.rows) do
            local text
            if row.groupId then
                text = states and GetCounts(catalog, states, row.groupId, classId) or "?"
            else
                text = FormatRank(row.line, states and states[row.line.id], classId)
            end
            SPT:AddProgressionTableCell(row, column, entry.name, text, status)
        end
    end
    return SPT:FinishProgressionTableView(view)
end
