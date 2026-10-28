local ADDON = "GuildCompare"
local PAGE_SIZE = 8
local snapshot

local function Print(message)
    -- Local system output only; never sends messages to a guild or other players.
    d("[Guild Compare] " .. message)
end

local function DisplayName(name)
    if ZO_FormatUserFacingDisplayName then
        return ZO_FormatUserFacingDisplayName(name)
    end
    return name
end

local function ReadRoster(guildId)
    local roster = {}
    local count = GetNumGuildMembers(guildId)
    if count == 0 then return nil end
    for index = 1, count do
        local name, _, rankIndex = GetGuildMemberInfo(guildId, index)
        if not name or name == "" or not rankIndex or rankIndex < 1 then
            return nil
        end
        roster[string.lower(name)] = {
            name = name,
            rank = GetFinalGuildRankName(guildId, rankIndex),
            rankIndex = rankIndex,
        }
    end
    return roster
end

local function ShowPage(page)
    if not snapshot then
        Print("Run /gc 1 2 first. Use /gc guilds to see your guild slots.")
        return
    end
    local pages = math.max(1, math.ceil(#snapshot.rows / PAGE_SIZE))
    page = math.max(1, math.min(pages, page))
    snapshot.page = page
    Print(snapshot.nameA .. " / " .. snapshot.nameB)
    Print(string.format("%d shared members | Page %d/%d | Snapshot; /gc refresh updates ranks.", #snapshot.rows, page, pages))
    if #snapshot.rows == 0 then Print("No shared members found in the loaded rosters.") end
    for index = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #snapshot.rows) do
        local row = snapshot.rows[index]
        Print(DisplayName(row.name))
        Print("  " .. snapshot.nameA .. ": " .. row.rankA .. " | " .. snapshot.nameB .. ": " .. row.rankB)
    end
    if page < pages then Print("/gc next for more; /gc prev to go back.") end
end

local function Compare(slotA, slotB)
    local total = GetNumGuilds()
    if slotA < 1 or slotB < 1 or slotA > total or slotB > total or slotA == slotB then
        Print("Choose two different joined guild slots. Use /gc guilds.")
        return
    end
    local idA, idB = GetGuildId(slotA), GetGuildId(slotB)
    local rosterA, rosterB = ReadRoster(idA), ReadRoster(idB)
    if not rosterA or not rosterB then
        Print("Roster data is not ready. Open both guild rosters, wait for them to load, then repeat /gc " .. slotA .. " " .. slotB .. ".")
        return
    end
    local rows = {}
    for key, memberA in pairs(rosterA) do
        local memberB = rosterB[key]
        if memberB then
            rows[#rows + 1] = {
                name = memberA.name,
                rankA = memberA.rank or ("Rank " .. memberA.rankIndex),
                rankB = memberB.rank or ("Rank " .. memberB.rankIndex),
            }
        end
    end
    table.sort(rows, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    snapshot = { idA = idA, idB = idB, nameA = GetGuildName(idA), nameB = GetGuildName(idB), rows = rows, page = 1 }
    ShowPage(1)
end

local function Command(text)
    text = string.lower(text or ""):match("^%s*(.-)%s*$")
    local a, b = text:match("^(%d+)%s+(%d+)$")
    if a then Compare(tonumber(a), tonumber(b)); return end
    if text == "guilds" then
        if GetNumGuilds() == 0 then Print("You have not joined any guilds.") end
        for slot = 1, GetNumGuilds() do Print(slot .. ": " .. GetGuildName(GetGuildId(slot))) end
    elseif text == "next" then
        ShowPage(snapshot and snapshot.page + 1 or 1)
    elseif text == "prev" then
        ShowPage(snapshot and snapshot.page - 1 or 1)
    elseif text == "refresh" and snapshot then
        local slotA, slotB
        for slot = 1, GetNumGuilds() do
            local id = GetGuildId(slot)
            if id == snapshot.idA then slotA = slot end
            if id == snapshot.idB then slotB = slot end
        end
        if slotA and slotB then Compare(slotA, slotB)
        else
            snapshot = nil
            Print("You left one of the compared guilds. Choose another pair with /gc guilds.")
        end
    elseif text:match("^page%s+%d+$") then
        ShowPage(tonumber(text:match("%d+$")))
    else
        Print("/gc guilds - list guild slots")
        Print("/gc 1 2 - compare slots 1 and 2 (or any two of your guilds)")
        Print("/gc next | /gc prev | /gc page 3 | /gc refresh")
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    SLASH_COMMANDS["/gc"] = Command
    SLASH_COMMANDS["/guildcompare"] = Command
end)
