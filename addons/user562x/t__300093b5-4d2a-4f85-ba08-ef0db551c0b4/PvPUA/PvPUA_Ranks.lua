local PvPUA = PvPUA
local U = PvPUA.util
local DC_HEX = U.DC_HEX
local AD_HEX = U.AD_HEX
local EP_HEX = U.EP_HEX

--------------------------------------------------
-- PvP Ranks
--------------------------------------------------
local R = {}
PvPUA.Ranks = R

local RANKS_MAX = 50
local RANKS_ICON_SIZE = 35
local RANKS_SKILL_ICON_SIZE = 32
local RANKS_MAX_SKILL_RANK = 10

function R:Data()
    if self.data then return self.data end
    local gender = GetUnitGender("player")
    local data = {}
    local points = 0
    for rank = 0, RANKS_MAX do
        local _, _, startsAt, nextRankAt = GetAvARankProgress(points)
        local endsAt = startsAt ~= nextRankAt and nextRankAt - 1 or nil
        points = nextRankAt + 1
        data[rank] = {
            name = zo_strformat(SI_STAT_RANK_NAME_FORMAT, GetAvARankName(gender, rank)),
            icon = zo_iconFormatInheritColor(GetAvARankIcon(rank), RANKS_ICON_SIZE, RANKS_ICON_SIZE),
            startsAt = startsAt,
            endsAt = endsAt,
        }
    end
    self.data = data
    return data
end

function R:Label(rank)
    local entry = self:Data()[rank]
    if not entry then return "" end

    local current = GetUnitAvARank("player")
    local alliance = GetUnitAlliance("player")
    if current ~= self.lastRank or alliance ~= self.lastAlliance then
        self.lastRank = current
        self.lastAlliance = alliance
        local data = self:Data()
        for i = 0, RANKS_MAX do
            data[i].label = nil
        end
    end

    if not entry.label then
        local text = rank .. ")  " .. entry.icon .. " " .. entry.name
        if rank == current then
            text = "|c" .. GetAllianceColor(alliance):ToHex() .. text .. "|r"
        end
        entry.label = text
    end

    return entry.label
end

function R:LineRankSpread(lineIndex)
    local lineData = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillLineDataByIndices
                 and SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(SKILL_TYPE_AVA, lineIndex)
    if not (lineData and lineData.GetNumSkills) then return 0 end
    local seen, distinct = {}, 0
    for i = 1, lineData:GetNumSkills() do
        local skillData = lineData:GetSkillDataByIndex(i)
        local lineRank = skillData and skillData.GetLineRankNeededToPurchase
                     and skillData:GetLineRankNeededToPurchase() or 0
        if lineRank > 0 and not seen[lineRank] then
            seen[lineRank] = true
            distinct = distinct + 1
        end
    end
    return distinct
end

function R:SkillLines()
    if self.lines then return self.lines end
    local lines = {}
    local count = GetNumSkillLines and GetNumSkillLines(SKILL_TYPE_AVA) or 0
    for lineIndex = 1, count do
        if GetSkillLineRankXPExtents(SKILL_TYPE_AVA, lineIndex, 2)
           and self:LineRankSpread(lineIndex) >= 2 then
            lines[#lines + 1] = lineIndex
        end
    end
    self.lines = lines
    return lines
end

function R:Unlocks()
    if self.unlocks then return self.unlocks end

    local lines = self:SkillLines()
    if #lines == 0 then return nil end

    local byLineRank = {}
    for lineRank = 1, RANKS_MAX_SKILL_RANK do
        local startsAt
        if lineRank == RANKS_MAX_SKILL_RANK then
            local _, nextExtent = GetSkillLineRankXPExtents(SKILL_TYPE_AVA, lines[1], lineRank - 1)
            startsAt = nextExtent
        else
            startsAt = GetSkillLineRankXPExtents(SKILL_TYPE_AVA, lines[1], lineRank)
        end
        if not startsAt then return nil end
        byLineRank[lineRank] = { startsAt = startsAt, skills = {} }
    end

    for _, lineIndex in ipairs(lines) do
        local lineData = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillLineDataByIndices
                     and SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(SKILL_TYPE_AVA, lineIndex)
        if lineData and lineData.GetNumSkills then
            for i = 1, lineData:GetNumSkills() do
                local skillData = lineData:GetSkillDataByIndex(i)
                if skillData then
                    local lineRank = skillData.GetLineRankNeededToPurchase
                                 and skillData:GetLineRankNeededToPurchase() or 0
                    if byLineRank[lineRank] then
                        local prog = skillData.GetCurrentProgressionData and skillData:GetCurrentProgressionData()
                        local name = prog and prog.GetFormattedName and prog:GetFormattedName() or ""
                        local icon = prog and prog.GetIcon and prog:GetIcon() or ""
                        if name ~= "" then
                            table.insert(byLineRank[lineRank].skills, { name = name, icon = icon })
                        end
                    end
                end
            end
        elseif GetNumSkillAbilities and GetSkillAbilityLineRankNeededToUnlock then
            for i = 1, GetNumSkillAbilities(SKILL_TYPE_AVA, lineIndex) do
                local lineRank = GetSkillAbilityLineRankNeededToUnlock(SKILL_TYPE_AVA, lineIndex, i) or 0
                if byLineRank[lineRank] and GetSkillAbilityInfo then
                    local name, icon = GetSkillAbilityInfo(SKILL_TYPE_AVA, lineIndex, i)
                    table.insert(byLineRank[lineRank].skills, { name = name or "", icon = icon or "" })
                end
            end
        end
    end

    self.unlocks = byLineRank
    return self.unlocks
end

function R:UnlocksFor(startsAt, endsAt)
    local byLineRank = self:Unlocks()
    if not byLineRank then return nil end
    for lineRank = 1, RANKS_MAX_SKILL_RANK do
        local entry = byLineRank[lineRank]
        if entry and entry.startsAt >= startsAt and (not endsAt or entry.startsAt <= endsAt) then
            return entry.skills
        end
    end
    return nil
end

function R:APIcon()
    if not self.apIcon then
        self.apIcon = zo_iconFormat("/esoui/art/currency/alliancepoints.dds", "100%", "100%")
    end
    return self.apIcon
end

function R:Tooltip(rank)
    local entry = self:Data()[rank]
    if not entry then return "" end
    if not entry.tip then
        local ap = self:APIcon()
        local text = "Starts at " .. ZO_CommaDelimitNumber(entry.startsAt) .. " " .. ap
        if entry.endsAt then
            text = text .. "\nEnds at " .. ZO_CommaDelimitNumber(entry.endsAt) .. " " .. ap
        end

        local ready = self:Unlocks() ~= nil
        local skills = self:UnlocksFor(entry.startsAt, entry.endsAt)
        if skills and #skills > 0 then
            text = text .. "\n"
            for i = 1, #skills do
                local skill = skills[i]
                local mark = skill.icon ~= "" and zo_iconFormat(skill.icon, RANKS_SKILL_ICON_SIZE, RANKS_SKILL_ICON_SIZE) .. " " or ""
                text = text .. "\n" .. mark .. skill.name
            end
        end

        if not ready then return text end
        entry.tip = text
    end
    return entry.tip
end

function R.Jump()
    local panel = PvPUA.settingsPanel
    if not (panel and panel.SelectRow) then return end
    panel:SelectRow(GetUnitAvARank("player") + 1)
end


function R:DetailsColor(rank, text)
    if rank == GetUnitAvARank("player") then
        return "|c" .. GetAllianceColor(GetUnitAlliance("player")):ToHex() .. text .. "|r"
    end
    return text
end

function R:DetailsNumber(rank)
    return self:DetailsColor(rank, rank .. ")")
end

function R:DetailsTitle(rank)
    local entry = self:Data()[rank]
    if not entry then return "" end
    return self:DetailsColor(rank, entry.icon .. " " .. entry.name)
end

function R:GetOptions()
    local out = {}
    for rank = 0, RANKS_MAX do
        out[#out + 1] = {
            type = "button",
            name = function() return R:Label(rank) end,
            detailsNumber = function() return R:DetailsNumber(rank) end,
            detailsTitle = function() return R:DetailsTitle(rank) end,
            tooltip = function() return R:Tooltip(rank) end,
            buttonText = "My Rank",
            func = R.Jump,
        }
    end
    return out
end

--------------------------------------------------
-- Menu
--------------------------------------------------
function PvPUA:RanksMenu()
    return { type = "submenu",
          name = "|c" .. DC_HEX .. "P|r|c" .. AD_HEX .. "v|r|c" .. EP_HEX .. "P|r |cFFFFFFRanks|r",
          childrenAlign = "leftFlush",
          icon = PVPUA_ADDON_ICON,
          options = PvPUA.Ranks and PvPUA.Ranks:GetOptions() or {} }
end
