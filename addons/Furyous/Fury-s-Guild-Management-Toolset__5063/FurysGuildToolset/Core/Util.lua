local GT = FurysGuildToolset
local U = {}
GT.Util = U

-- Shows a pop-up window (export/copy, confirm, text box, alert) in front of the Toolset
-- window (1.14.1). Pop-ups draw on the high tier, and each one shown goes above the one before.
local popupLevel = 0
function U.ShowOnTop(control)
    if control:IsHidden() then SCENE_MANAGER:ShowTopLevel(control) end
    popupLevel = popupLevel + 1
    control:SetDrawTier(DT_HIGH)
    control:SetDrawLevel(popupLevel)
end

function U.Print(fmt, ...)
    local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    local line = "|cA08CFF[Fury GMT]|r " .. text
    CHAT_ROUTER:AddSystemMessage(line)
end

function U.Alert(text)
    U.Print(text)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, text)
end

-- "a, b\nc" -> { a = true, b = true, c = true }, lowercased and trimmed.
function U.ParseList(str)
    local set = {}
    for raw in string.gmatch(str or "", "[^,\n;]+") do
        local entry = zo_strtrim(raw)
        if entry ~= "" then set[zo_strlower(entry)] = true end
    end
    return set
end

-- Display names always start with "@". Accept entries typed with or without it.
function U.NormalizeName(name)
    name = zo_strtrim(name or "")
    if name ~= "" and name:sub(1, 1) ~= "@" then name = "@" .. name end
    return name
end

function U.FormatDuration(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds < 86400 * 2 then
        return string.format("%.1fh", seconds / 3600)
    end
    return string.format("%.1fd", seconds / 86400)
end

function U.FormatAgo(timestamp)
    return U.FormatDuration(GetTimeStamp() - (timestamp or 0)) .. " ago"
end

function U.FormatDate(timestamp)
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

function U.FormatGold(amount)
    return ZO_CommaDelimitNumber(amount or 0) .. "g"
end

function U.GuildName(guildId)
    local name = GetGuildName(guildId)
    if not name or name == "" then return "guild " .. tostring(guildId) end
    return name
end

function U.GetGuildIds()
    local ids = {}
    for i = 1, GetNumGuilds() do
        ids[#ids + 1] = GetGuildId(i)
    end
    return ids
end

function U.IsPlayerInGuild(guildId)
    for i = 1, GetNumGuilds() do
        if GetGuildId(i) == guildId then return true end
    end
    return false
end

-- Returns rankIndex, rankName for a current member, or nil if they are no longer in the guild.
-- Rank index 1 is the Guild Master; larger numbers are lower ranks.
function U.GetMemberRank(guildId, displayName)
    local memberIndex = GetGuildMemberIndexFromDisplayName(guildId, displayName)
    if not memberIndex then return nil end
    local _, _, rankIndex = GetGuildMemberInfo(guildId, memberIndex)
    return rankIndex, GetFinalGuildRankName(guildId, rankIndex)
end

function U.IsMember(guildId, displayName)
    return GetGuildMemberIndexFromDisplayName(guildId, displayName) ~= nil
end

function U.HasPermission(guildId, permission)
    return DoesPlayerHaveGuildPermission(guildId, permission)
end

-- Shared exclusion check used by any module that has "ignore these people" settings.
-- settings.excludeNames: "@a, @b"   settings.excludeRanks: "Officer, Banker"
-- settings.excludeTopRanks: ignore rank indexes 1..N (1 = Guild Master)
function U.IsExcluded(guildId, displayName, settings)
    if displayName == GetDisplayName() then return true end
    local names = U.ParseList(settings.excludeNames)
    if names[zo_strlower(displayName)] or names[zo_strlower((displayName:gsub("^@", "")))] then
        return true
    end
    local rankIndex, rankName = U.GetMemberRank(guildId, displayName)
    if rankIndex then
        if (settings.excludeTopRanks or 0) >= rankIndex then return true end
        local ranks = U.ParseList(settings.excludeRanks)
        if rankName and ranks[zo_strlower(rankName)] then return true end
    end
    return false
end

function U.Count(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do n = n + 1 end
    return n
end
