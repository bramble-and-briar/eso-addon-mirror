-- The stored roster. One entry per character name, account-wide:
--   sv.characters[name]  what the scanner read from the game the last time you logged in on it
--   sv.manual[name]      what only you know: role, gear, planned race (picked from dropdowns)
local CT = FurysCharacterTracker
local U = CT.Util
local Roster = {}
CT.Roster = Roster

-- Dropdown choices. Gear is what you have farmed for that character, not what it is wearing.
Roster.ROLES = { "Tank", "Healer", "DPS", "Tank/DPS", "Tank/Healer", "DPS/Healer", "Tank/Healer/DPS" }
Roster.GEAR = { "Trial set", "Crafted set", "Overland set", "Mixed", "None" }
Roster.RACES = { "", "Altmer", "Argonian", "Bosmer", "Breton", "Dark Elf", "Imperial", "Khajiit", "Nord", "Orc", "Redguard" }

Roster.FIELDS = {
    role         = { title = "Role", values = Roster.ROLES },
    dpsGear      = { title = "DPS gear", values = Roster.GEAR },
    roleGear     = { title = "Tank/healer gear", values = Roster.GEAR },
    plannedRace  = { title = "Planned race", values = Roster.RACES },
}

-- Saved data from pre-1.0 test versions: renamed picks, and starter rows that were never read from the game.
local OLD_ROLE = { Heal = "Healer", ["DPS/Heal"] = "DPS/Healer" }
local OLD_DPS_SETS = { Trial = "Trial set", Crafted = "Crafted set", No = "None" }
local OLD_ROLE_SETS = { Yes = "Trial set", No = "None" }

local function Migrate(sv)
    -- Rows that were never read from the game: drop them. Picks for them stay in sv.manual and
    -- come back the first time you log in on that character.
    if sv.seeded ~= nil then
        local keep = {}
        for _, name in ipairs(sv.order) do
            local c = sv.characters[name]
            if c and c.source == "live" then
                keep[#keep + 1] = name
            else
                sv.characters[name] = nil
            end
        end
        sv.order = keep
        sv.seeded = nil
    end
    for _, m in pairs(sv.manual) do
        if m.role then m.role = OLD_ROLE[m.role] or m.role end
        if m.dpsSets then m.dpsGear = m.dpsGear or OLD_DPS_SETS[m.dpsSets]; m.dpsSets = nil end
        if m.roleSets then m.roleGear = m.roleGear or OLD_ROLE_SETS[m.roleSets]; m.roleSets = nil end
        if m.proposedRace then m.plannedRace = m.plannedRace or m.proposedRace; m.proposedRace = nil end
    end
end

function Roster:Initialize()
    Migrate(CT.sv)
    self:BuildExportRows()
end

local function InOrder(name)
    for _, n in ipairs(CT.sv.order) do
        if n == name then return true end
    end
    return false
end

-- The role the group finder is set to, for a character you have not given a role yet.
local LFG_ROLES = { [LFG_ROLE_TANK] = "Tank", [LFG_ROLE_DPS] = "DPS", [LFG_ROLE_HEAL] = "Healer" }

function Roster:Store(name, c)
    local sv = CT.sv
    local previous = sv.characters[name]
    if previous then
        -- Vampire and Werewolf vanish from the skill list when cured: keep the best rank seen.
        for lineName, def in pairs(CT.LINE_BY_NAME) do
            if def.keepPeak then
                c.lines[lineName] = math.max(c.lines[lineName] or 0, (previous.lines and previous.lines[lineName]) or 0)
            end
        end
        if c.skillPoints == nil then c.skillPoints = previous.skillPoints end
    end
    sv.characters[name] = c
    sv.hidden[name] = nil
    if not InOrder(name) then sv.order[#sv.order + 1] = name end
    if not sv.manual[name] then
        sv.manual[name] = { role = LFG_ROLES[GetSelectedLFGRole()] or "DPS" }
    end
    self:BuildExportRows()
    CT.Window:RefreshIfShown()
    CT.Timers:RefreshIfShown()
end

function Roster:UpdatePlayed(name, seconds)
    local c = CT.sv.characters[name]
    if c then
        c.playedHours = zo_round(seconds / 3600)
        self:BuildExportRows()
    end
end

function Roster:Get(name)
    local data = CT.Data()
    return data.characters[name], data.manual[name] or {}
end

function Roster:SetManual(name, field, value)
    local data = CT.Data()
    data.manual[name] = data.manual[name] or {}
    data.manual[name][field] = (value ~= "") and value or nil
    self:BuildExportRows()
end

function Roster:Hide(name)
    CT.Data().hidden[name] = true
end

function Roster:ShowAll()
    ZO_ClearTable(CT.Data().hidden)
end

-- Characters on the board, in board order (or sorted by a column value).
-- `data` defaults to the account being viewed.
function Roster:List(sortValue, descending, data)
    data = data or CT.Data()
    local list = {}
    for index, name in ipairs(data.order) do
        if data.characters[name] and not data.hidden[name] then
            list[#list + 1] = { name = name, index = index }
        end
    end
    if sortValue then
        table.sort(list, function(a, b)
            local va, vb = sortValue(a.name), sortValue(b.name)
            if va == vb then return a.index < b.index end
            if descending then return va > vb end
            return va < vb
        end)
    end
    return list
end

-- Lines of a group at their top rank, for one character.
function Roster:MaxedInGroup(c, group)
    local maxed = 0
    for _, line in ipairs(group.lines) do
        if (c.lines and c.lines[line.name] or 0) >= line.max then maxed = maxed + 1 end
    end
    return maxed
end

-- Every character on the account (the game knows them all, even ones you haven't logged in on).
-- For another account: the names it saved the last time it was played.
function Roster:AccountCharacters()
    if not CT.IsHome() then return (CT.Data().account or {}).characterNames or {} end
    local names = {}
    for index = 1, GetNumCharacters() do
        names[#names + 1] = U.Plain((GetCharacterInfo(index)))
    end
    return names
end

-- Characters on the account the addon has never read (removed ones you hid don't count).
function Roster:NeverRead()
    local missing = {}
    for _, name in ipairs(self:AccountCharacters()) do
        if not CT.Data().characters[name] then missing[#missing + 1] = name end
    end
    table.sort(missing)
    return missing
end

-- Characters to log in on: never read, then the ones not read in the last `days` days, oldest first.
function Roster:PrintToDo(days)
    local never = self:NeverRead()
    local cutoff = GetTimeStamp() - days * 86400
    local due = {}
    for _, entry in ipairs(self:List()) do
        local last = CT.Data().characters[entry.name].lastScan or 0
        if last < cutoff then due[#due + 1] = { name = entry.name, last = last } end
    end
    table.sort(due, function(a, b) return a.last < b.last end)
    if #never == 0 and #due == 0 then
        U.Print("All %d characters on this account were read in the last %d days. Nothing to do.", #self:AccountCharacters(), days)
        return
    end
    if #never > 0 then
        U.Print("%d never read (log in on each for a few seconds): %s", #never, table.concat(never, ", "))
    end
    if #due > 0 then
        local names = {}
        for _, d in ipairs(due) do names[#names + 1] = string.format("%s (%s)", d.name, U.FormatDate(d.last)) end
        U.Print("%d not read in %d days, oldest first: %s", #due, days, table.concat(names, ", "))
    end
end

-- Export ------------------------------------------------------------------------------
-- One "FCT|" line per character, tab separated. ExportToExcel.ps1 turns them into a CSV.

function Roster:ExportHeader()
    local cols = { "Name", "Class", "Race", "Planned race", "Alliance", "Role", "DPS gear", "Tank/healer gear", "Level",
                   "Skill points", "Unassigned", "Achievement points" }
    for _, group in ipairs(CT.GROUPS) do
        for _, line in ipairs(group.lines) do cols[#cols + 1] = line.name end
    end
    for _, col in ipairs({ "Crafting lines maxed", "Research", "Scribing (grimoires + scripts)", "Recipes", "Recipes total",
                           "Furnishing plans", "Furnishing plans total", "Motif styles", "Motif styles total", "Riding",
                           "Companions", "Companion names", "Hours played", "Updated" }) do
        cols[#cols + 1] = col
    end
    return cols
end

function Roster:ExportRow(name)
    local c, m = CT.sv.characters[name], CT.sv.manual[name] or {}
    local function v(x) return x == nil and "" or tostring(x) end
    local row = { name, v(c.class), v(c.race), v(m.plannedRace), v(c.alliance), v(m.role), v(m.dpsGear), v(m.roleGear),
                  v(c.level), v(c.skillPoints), v(c.unspent), v(c.achievementPoints) }
    for _, group in ipairs(CT.GROUPS) do
        for _, line in ipairs(group.lines) do
            row[#row + 1] = v(math.min((c.lines or {})[line.name] or 0, line.max))
        end
    end
    local companions = c.companions or {}
    for _, value in ipairs({ c.craftMaxed, c.research, c.scripts, c.recipes, c.recipesTotal, c.furnishings, c.furnishingsTotal,
                             c.motifs, c.motifsTotal, c.riding, #companions, table.concat(companions, ", "), c.playedHours,
                             U.FormatDate(c.lastScan) }) do
        row[#row + 1] = v(value)
    end
    return row
end

function Roster:BuildExportRows()
    local rows = { "FCT|" .. table.concat(self:ExportHeader(), "\t") }
    local list = self:List(nil, nil, CT.sv)   -- always your own account
    for _, entry in ipairs(list) do
        rows[#rows + 1] = "FCT|" .. table.concat(self:ExportRow(entry.name), "\t")
    end
    CT.sv.exportRows = rows
    return #list
end
