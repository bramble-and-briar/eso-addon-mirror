-- shared
-- The stored roster. One entry per character, saved under the game's character ID:
--   data.characters[id]  what was read from the game the last time you logged in on it
--   data.manual[id]      what only you know: role, gear, planned race, note
--   data.order           the ids in your board order
-- A board entry `e` is { id =, name =, c = data.characters[id], m = data.manual[id] }.
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

-- Upgrade steps (see CT.UPGRADES in FurysCharacterTracker.lua) ------------------------------------

-- Saved data from pre-1.0 test versions: renamed picks, and starter rows that were never read from the game.
local OLD_ROLE = { Heal = "Healer", ["DPS/Heal"] = "DPS/Healer" }
local OLD_DPS_SETS = { Trial = "Trial set", Crafted = "Crafted set", No = "None" }
local OLD_ROLE_SETS = { Yes = "Trial set", No = "None" }

-- Step 1.
function Roster.UpgradeOldPicks(data)
    -- Rows that were never read from the game: drop them. Picks for them stay in data.manual and
    -- come back the first time you log in on that character.
    if data.seeded ~= nil then
        local keep = {}
        for _, name in ipairs(data.order) do
            local c = data.characters[name]
            if c and c.source == "live" then
                keep[#keep + 1] = name
            else
                data.characters[name] = nil
            end
        end
        data.order = keep
        data.seeded = nil
    end
    for _, m in pairs(data.manual) do
        if m.role then m.role = OLD_ROLE[m.role] or m.role end
        if m.dpsSets then m.dpsGear = m.dpsGear or OLD_DPS_SETS[m.dpsSets]; m.dpsSets = nil end
        if m.roleSets then m.roleGear = m.roleGear or OLD_ROLE_SETS[m.roleSets]; m.roleSets = nil end
        if m.proposedRace then m.plannedRace = m.plannedRace or m.proposedRace; m.proposedRace = nil end
    end
end

-- Step 2 (1.5.0): everything that was saved under a character's name moves under its character ID.
-- The ID was already saved inside each character. One without it (never seen in practice) stays
-- under its name until you log in on it, and Roster:Store moves it then.
function Roster.UpgradeToIds(data)
    local idOf, characters = {}, {}
    for name, c in pairs(data.characters) do
        local id = c.id and tostring(c.id) or name
        c.id, c.name = id, c.name or name
        characters[id], idOf[name] = c, id
    end
    data.characters = characters
    local function Rekey(list)
        local out = {}
        for name, value in pairs(list or {}) do out[idOf[name] or name] = value end
        return out
    end
    data.manual, data.hidden = Rekey(data.manual), Rekey(data.hidden)
    if data.companionSeen then data.companionSeen = Rekey(data.companionSeen) end
    local order = {}
    for _, name in ipairs(data.order) do
        if idOf[name] then order[#order + 1] = idOf[name] end
    end
    data.order = order
    data.exportRows = {}
    -- Sort orders were saved by column number; columns have names now.
    data.sort = {}
    local alliances = { ["Aldmeri Dominion"] = 1, ["Ebonheart Pact"] = 2, ["Daggerfall Covenant"] = 3 }
    data.history = data.history or {}
    for id, c in pairs(characters) do
        c.allianceId = c.allianceId or alliances[c.alliance or ""]
        -- Progress over time starts from what was saved at the last read.
        if c.lastScan and not data.history[id] then data.history[id] = { CT.History.Line(c, c.lastScan) } end
    end
end

-- Storing what was read -----------------------------------------------------------------------

local function InOrder(data, id)
    for _, other in ipairs(data.order) do
        if other == id then return true end
    end
    return false
end

-- Things saved under a character's name before its ID was known (old data, or picks made on a
-- row that had not been read yet) move under the ID.
local function Adopt(data, name, id)
    if not name or name == id then return end
    for _, list in ipairs({ data.manual, data.history, data.companionSeen or {} }) do
        if list[name] ~= nil then
            if list[id] == nil then list[id] = list[name] end
            list[name] = nil
        end
    end
    data.hidden[name] = nil
    if data.characters[name] then
        data.characters[name] = nil
        for index, other in ipairs(data.order) do
            if other == name then data.order[index] = id end
        end
    end
end

-- Game only: called by the reader with the character you are on.
function Roster:Store(id, c)
    local sv = CT.sv
    sv.characters[id] = c
    sv.hidden[id] = nil
    Adopt(sv, c.name, id)
    if not InOrder(sv, id) then sv.order[#sv.order + 1] = id end
    if not sv.manual[id] then
        -- The role the group finder is set to, for a character you have not given a role yet.
        local lfgRoles = { [LFG_ROLE_TANK] = "Tank", [LFG_ROLE_DPS] = "DPS", [LFG_ROLE_HEAL] = "Healer" }
        sv.manual[id] = { role = lfgRoles[GetSelectedLFGRole()] or "DPS" }
    end
    CT.History.Record(sv, id, c)
end

function Roster:UpdatePlayed(id, seconds)
    local c = CT.sv.characters[id]
    if c then
        c.playedHours = zo_round(seconds / 3600)
    end
end

-- Reading the roster --------------------------------------------------------------------------

function Roster:Get(id, data)
    data = data or CT.Data()
    return data.characters[id], data.manual[id] or {}
end

function Roster:Entry(id, data)
    data = data or CT.Data()
    local c = data.characters[id]
    if not c then return nil end
    return { id = id, name = c.name or id, c = c, m = data.manual[id] or {} }
end

function Roster:IdByName(name, data)
    data = data or CT.Data()
    for id, c in pairs(data.characters) do
        if c.name == name then return id end
    end
end

function Roster:SetManual(id, field, value)
    local data = CT.Data()
    data.manual[id] = data.manual[id] or {}
    data.manual[id][field] = (value ~= "") and value or nil
end

function Roster:Hide(key)
    CT.Data().hidden[key] = true
end

function Roster:ShowAll()
    local hidden = CT.Data().hidden
    for key in pairs(hidden) do hidden[key] = nil end
end

-- True when "Show removed" has something to bring back.
function Roster:AnyHidden()
    return next(CT.Data().hidden) ~= nil
end

-- Your own row order: move a character up or down one row, or to the top or bottom.
-- `where`: "up", "down", "top", "bottom". Hidden characters keep their place and are skipped over.
function Roster:Move(id, where)
    local data = CT.Data()
    local order, at = data.order, nil
    for index, other in ipairs(order) do
        if other == id then at = index end
    end
    if not at then return false end
    local function Shown(index)
        local other = order[index]
        return other and data.characters[other] and not data.hidden[other]
    end
    local to = at
    if where == "up" or where == "down" then
        local step = where == "up" and -1 or 1
        to = at + step
        while order[to] and not Shown(to) do to = to + step end
        if not order[to] then return false end
    elseif where == "top" then
        to = 1
    elseif where == "bottom" then
        to = #order
    end
    if to == at then return false end
    table.remove(order, at)
    table.insert(order, to, id)
    return true
end

-- Characters on the board, in board order (or sorted by a column value).
-- `data` defaults to the account being viewed. `sortValue` is function(entry) -> number or text.
function Roster:List(sortValue, descending, data)
    data = data or CT.Data()
    local list = {}
    for index, id in ipairs(data.order) do
        local c = data.characters[id]
        if c and not data.hidden[id] then
            list[#list + 1] = { id = id, name = c.name or id, c = c, m = data.manual[id] or {}, index = index }
        end
    end
    if sortValue then
        local keys = {}
        for _, entry in ipairs(list) do keys[entry] = sortValue(entry) end
        table.sort(list, function(a, b)
            local va, vb = keys[a], keys[b]
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

-- Game only. What the game knows about every character on your account without logging in on it,
-- in the game's own order.
function Roster:GameCharacters()
    local list = {}
    for index = 1, GetNumCharacters() do
        local name, gender, level, classId, raceId, alliance, id = GetCharacterInfo(index)
        list[#list + 1] = { id = id, name = U.Plain(name), classId = classId, class = U.Plain(GetClassName(gender, classId)),
                            raceId = raceId, race = U.Plain(GetRaceName(gender, raceId)), level = level,
                            allianceId = alliance, alliance = U.Plain(GetAllianceName(alliance)) }
    end
    return list
end

-- One saved line per character on the account, for the rows of characters not read yet.
function Roster.RosterLine(info)
    return table.concat({ info.id, U.Clean(info.name), info.classId, U.Clean(info.class), info.raceId, U.Clean(info.race), info.level,
                          info.allianceId, U.Clean(info.alliance) }, "|")
end

-- Every character on the account being viewed. Your own account, in game: asked from the game.
-- Otherwise: what the account saved the last time it was played ("id|name|classId|class|raceId|
-- race|level|allianceId|alliance"; "name|class|race|level|alliance" or only names before 1.5.0).
function Roster:AccountRoster()
    if CT.IsHome() then return self:GameCharacters() end
    local account = CT.Data().account or {}
    local list = {}
    if account.roster then
        for _, text in ipairs(account.roster) do
            local p = U.Split(text, "|")
            if #p >= 9 then
                list[#list + 1] = { id = p[1], name = p[2], classId = tonumber(p[3]), class = p[4], raceId = tonumber(p[5]), race = p[6],
                                    level = tonumber(p[7]), allianceId = tonumber(p[8]), alliance = p[9] }
            elseif #p >= 5 then
                list[#list + 1] = { name = p[1], class = p[2], race = p[3], level = tonumber(p[4]), alliance = p[5] }
            end
        end
    else
        for _, name in ipairs(account.characterNames or {}) do list[#list + 1] = { name = name } end
    end
    return list
end

-- Characters on the account the addon has never read, A to Z, with what the game says about them.
-- Ones you removed from the board don't count. `key` is what the row is hidden under.
function Roster:Unread()
    local data, list = CT.Data(), {}
    local names = {}
    for _, c in pairs(data.characters) do
        if c.name then names[c.name] = true end
    end
    for _, info in ipairs(self:AccountRoster()) do
        local known = (info.id and data.characters[info.id]) or names[info.name]
        info.key = info.id or info.name
        if not known and not data.hidden[info.key] and not data.hidden[info.name] then list[#list + 1] = info end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Characters to log in on: never read, then the ones not read in the last `days` days, oldest first.
-- Names of the characters whose last read was by a version that gathered less than this one.
function Roster:ReadByOlderVersion()
    local names = {}
    for _, entry in ipairs(self:List()) do
        if (entry.c.v or 1) < CT.READ_VERSION then names[#names + 1] = entry.name end
    end
    return names
end

function Roster:PrintToDo(days)
    local never = {}
    for _, info in ipairs(self:Unread()) do never[#never + 1] = info.name end
    local cutoff = GetTimeStamp() - days * 86400
    local due = {}
    for _, entry in ipairs(self:List()) do
        local last = entry.c.lastScan or 0
        if last < cutoff then due[#due + 1] = { name = entry.name, last = last } end
    end
    table.sort(due, function(a, b) return a.last < b.last end)
    local old = self:ReadByOlderVersion()
    if #old > 0 then
        U.Print("%d last read by an older version, so the new columns show a dash (log in on each once): %s", #old, table.concat(old, ", "))
    end
    if #never == 0 and #due == 0 then
        if #old > 0 then return end
        U.Print("All %s on this account were read in the last %d days. Nothing to do.", U.Count(#self:AccountRoster(), "character"), days)
        return
    end
    if #never > 0 then
        U.Print("%d never read (log in on each for a few seconds): %s", #never, table.concat(never, ", "))
    end
    if #due > 0 then
        local names = {}
        for _, d in ipairs(due) do names[#names + 1] = string.format("%s (%s)", d.name, U.Ago(d.last)) end
        U.Print("%d not read in %d days, oldest first: %s", #due, days, table.concat(names, ", "))
    end
end

-- Export ------------------------------------------------------------------------------
-- One row per character. The columns are the `export` lists of the trackers, in tracker order.

function Roster:ExportColumns()
    local columns = {}
    for _, tracker in ipairs(CT.Trackers.list) do
        for _, column in ipairs(tracker.export or {}) do columns[#columns + 1] = column end
    end
    return columns
end

-- { header row, one row per character }, each a list of texts, for the account on the board
-- (or `data`, saved by the account `view`). The first two cells say whose characters they are.
function Roster:ExportRows(data, view)
    data, view = data or CT.Data(), view or CT.view
    local columns = self:ExportColumns()
    local header = { "Account", "Server" }
    for _, column in ipairs(columns) do header[#header + 1] = column[1] end
    local rows = { header }
    local account, server = view and view.account or "", view and (view.world:gsub(" Megaserver", "")) or ""
    for _, entry in ipairs(self:List(nil, nil, data)) do
        local row = { account, server }
        for _, column in ipairs(columns) do
            local value = column[2](entry)
            -- One cell, one line: a tab or a line break inside a value would split the row in Excel.
            row[#row + 1] = value == nil and "" or (string.gsub(tostring(value), "[\t\r\n]", " "))
        end
        rows[#rows + 1] = row
    end
    return rows
end

-- Game only: "FCT|" lines, tab separated, saved for ExportToExcel.ps1 and AutoExport.ps1 (Windows
-- Tools). Your own account's rows, written on the way out (logout, /reloadui) and when you export.
function Roster:BuildExportRows()
    local rows = {}
    for i, row in ipairs(self:ExportRows(CT.sv, CT.home)) do
        rows[i] = "FCT|" .. table.concat(row, "\t")
    end
    CT.sv.exportRows = rows
    return #rows - 1
end
