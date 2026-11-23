-- Gold Digger selling: which trader each of your guilds holds this week, and where it stands.
-- The game gives a guild's trader by name only, so places are learned when you visit a trader.

local GP = ESOC_GoldDigger
local Selling = {}
GP.Selling = Selling

local BETTER_BY = 1.1      -- another guild's market must be this much better to switch from your main one
local MAX_PLACES = 300

local guilds = {}

-- Mournhold is the city inside Deshaan, and the game may report either name.
function Selling.ZoneKey(zone)
    local key = string.lower(zone or "")
    if string.find(key, "mournhold", 1, true) then return "deshaan" end
    return key
end

local function canSellIn(guildId)
    local hasPrivilege = rawget(_G, "DoesGuildHavePrivilege")
    local privilege = rawget(_G, "GUILD_PRIVILEGE_TRADING_HOUSE")
    if hasPrivilege and privilege ~= nil and not hasPrivilege(guildId, privilege) then return false end
    local hasPermission = rawget(_G, "DoesPlayerHaveGuildPermission")
    local permission = rawget(_G, "GUILD_PERMISSION_STORE_SELL")
    if hasPermission and permission ~= nil and not hasPermission(guildId, permission) then return false end
    return true
end

function Selling.SplitKiosk(kiosk)
    if not kiosk then return nil, nil end
    local npc, town = string.match(kiosk, "^(.-) [Ii][Nn] (.+)$")
    if npc and npc ~= "" then return npc, town end
    return kiosk, nil
end

-- Traders change hands every week, so this is read fresh rather than saved.
function Selling.Refresh()
    local list = {}
    local getKiosk = rawget(_G, "GetGuildOwnedKioskInfo")
    for index = 1, GetNumGuilds() do
        local guildId = GetGuildId(index)
        local kiosk
        if getKiosk then
            local ok, name = pcall(getKiosk, guildId)
            if ok and name and name ~= "" then kiosk = zo_strformat("<<1>>", name) end
        end
        local ok, allowed = pcall(canSellIn, guildId)
        -- The game names a hired trader like "Erwurlde in Mournhold"
        local npc, namedTown = Selling.SplitKiosk(kiosk)
        local place = npc and GP.sv.kioskPlaces[string.lower(npc)] or nil
        local town = place and place.town or namedTown
        local zone = place and place.zone
        if not zone and town and Selling.ZoneKey(town) == "deshaan" then zone = "Deshaan" end
        list[#list + 1] = {
            id = guildId, name = GetGuildName(guildId), kiosk = npc, canSell = not ok or allowed,
            town = town, zone = zone,
        }
    end
    guilds = list
end

function Selling.Guilds()
    return guilds
end

-- Remembers where a trader stands, whichever guild holds it now.
function Selling.Learn(npc, town, zone)
    if not npc or npc == "" then return end
    local key = string.lower(npc)
    local places = GP.sv.kioskPlaces
    local known = places[key]
    if known and known.zone == zone and known.town == town then return end
    if not known then
        local count = 0
        for _ in pairs(places) do count = count + 1 end
        if count >= MAX_PLACES then return end
    end
    places[key] = { town = town, zone = zone }
    Selling.Refresh()
end

local function usable(guild)
    return guild.canSell and guild.kiosk ~= nil
end

-- Your chosen guild, or the one whose trader is in your selling zone.
function Selling.Primary()
    local options = GP.sv.options
    if options.sellGuild then
        for _, guild in ipairs(guilds) do
            if guild.name == options.sellGuild and usable(guild) then return guild end
        end
    end
    local wanted = Selling.ZoneKey(options.sellZone or "Deshaan")
    for _, guild in ipairs(guilds) do
        if usable(guild) and guild.zone and Selling.ZoneKey(guild.zone) == wanted then return guild end
    end
    for _, guild in ipairs(guilds) do
        if usable(guild) and guild.zone then return guild end
    end
    return nil
end

-- Guilds with a trader are on unless you turn them off. Guilds without one are off unless you turn them on.
function Selling.GuildEnabled(guild)
    local choices = GP.sv.options.sellGuilds
    local choice = choices and choices[tostring(guild.id)]
    if choice ~= nil then return choice end
    return guild.kiosk ~= nil
end

function Selling.SetGuildEnabled(guild, enabled)
    GP.sv.options.sellGuilds = GP.sv.options.sellGuilds or {}
    GP.sv.options.sellGuilds[tostring(guild.id)] = enabled
end

-- Where listings go: your main guild, your selling zone, other known zones, then the rest.
function Selling.ListingOrder()
    local primary, wanted = Selling.Primary(), Selling.ZoneKey(GP.sv.options.sellZone or "Deshaan")
    local ranked = {}
    for index, guild in ipairs(guilds) do
        if guild.canSell and Selling.GuildEnabled(guild) then
            local rank = 4
            if primary and guild.id == primary.id then rank = 1
            elseif not guild.kiosk then rank = 5
            elseif guild.zone and Selling.ZoneKey(guild.zone) == wanted then rank = 2
            elseif guild.zone then rank = 3 end
            ranked[#ranked + 1] = { guild = guild, rank = rank, index = index }
        end
    end
    table.sort(ranked, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.index < b.index
    end)
    local order = {}
    for position, row in ipairs(ranked) do order[position] = row.guild end
    return order
end

function Selling.MarketKey(guild)
    if guild.zone then return Selling.ZoneKey(guild.zone) end
    return "guild:" .. tostring(guild.id)
end

function Selling.PrimaryZone()
    local primary = Selling.Primary()
    return primary and primary.zone or GP.sv.options.sellZone or "Deshaan"
end

function Selling.InSellZone(zone)
    local key = Selling.ZoneKey(zone)
    if key == Selling.ZoneKey(GP.sv.options.sellZone or "Deshaan") then return true end
    for _, guild in ipairs(guilds) do
        if usable(guild) and guild.zone and Selling.ZoneKey(guild.zone) == key then return true end
    end
    return false
end

-- The market to sell an item in. It stays with your main guild unless another is clearly better.
function Selling.BestAsks(itemKey, asksByZone)
    local primary = Selling.Primary()
    local primaryKey = Selling.ZoneKey(Selling.PrimaryZone())
    local zoneAsks = asksByZone[primaryKey]
    local best, bestGuild = zoneAsks and zoneAsks[itemKey], primary
    for _, guild in ipairs(guilds) do
        if usable(guild) and guild.zone and Selling.ZoneKey(guild.zone) ~= primaryKey then
            local other = asksByZone[Selling.ZoneKey(guild.zone)]
            local asks = other and other[itemKey]
            if asks and (not best or asks[1].p > best[1].p * BETTER_BY) then
                best, bestGuild = asks, guild
            end
        end
    end
    return best, bestGuild
end

function Selling.PlaceText(guild)
    if guild.town and guild.zone and guild.town ~= guild.zone then return guild.town .. ", " .. guild.zone end
    return guild.town or guild.zone or "Location not known yet"
end

-- The "your selling traders" block of the report.
function Selling.GuildLines()
    local lines = {}
    for _, guild in ipairs(guilds) do
        lines[#lines + 1] = "Guild: " .. guild.name
        if not guild.canSell then
            lines[#lines + 1] = "   You can't sell in this guild"
        elseif not guild.kiosk then
            lines[#lines + 1] = "   No trader this week, members only"
        else
            lines[#lines + 1] = "   Trader: " .. guild.kiosk
            lines[#lines + 1] = "   Town: " .. Selling.PlaceText(guild)
        end
    end
    return lines
end
