-- GuildNameTickerGuildUtils.lua: Read-only helpers over the guild API.
-- No state mutation; safe to call from any phase.

local GuildNameTickerGuildUtils = {}

---MAX_GUILD_NAME_LENGTH is a client global not present in the offline type
---stubs; fall back to the known live value if it ever goes missing.
---@return integer
function GuildNameTickerGuildUtils.GetMaxNameLength()
    return _G["MAX_GUILD_NAME_LENGTH"] or 24
end

---@param name string
---@return integer[] violations Empty when the name passes client-side naming rules
function GuildNameTickerGuildUtils.GetNameViolations(name)
    return { IsValidGuildName(name) }
end

---@param result integer SocialActionResult
---@return string
function GuildNameTickerGuildUtils.DescribeSocialResult(result)
    local text = GetString("SI_SOCIALACTIONRESULT", result)
    if text and text ~= "" then
        return string.format("%s (%d)", text, result)
    end
    return string.format("social result %d", result)
end

---A guild we lead and are the only member of: leaving it disbands it, so it
---is safe for the ticker to discard.
---@param guildId integer
---@return boolean
function GuildNameTickerGuildUtils.IsSoloLedGuild(guildId)
    return IsPlayerGuildMaster(guildId) and GetNumGuildMembers(guildId) == 1
end

---Any guild this account belongs to with the given name, member or leader.
---@param name string
---@return integer|nil guildId
function GuildNameTickerGuildUtils.FindGuildIdByName(name)
    if not name or name == "" then
        return nil
    end
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if GetGuildName(guildId) == name then
            return guildId
        end
    end
    return nil
end

---@param name string
---@return integer|nil guildId
function GuildNameTickerGuildUtils.FindSoloLedGuildIdByName(name)
    if not name or name == "" then
        return nil
    end
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if GetGuildName(guildId) == name and GuildNameTickerGuildUtils.IsSoloLedGuild(guildId) then
            return guildId
        end
    end
    return nil
end

---Wraps ZO_CanPlayerCreateGuild (UI global) with a readable failure reason.
---@return boolean canCreate, string|nil reason
function GuildNameTickerGuildUtils.CanCreateGuildNow()
    local canCreate, tooManyGuilds, isAlreadyGuildmaster, tooLowLevel = _G["ZO_CanPlayerCreateGuild"]()
    if canCreate then
        return true, nil
    end
    if tooManyGuilds then
        return false, "already in the maximum number of guilds"
    elseif isAlreadyGuildmaster then
        return false, "already guildmaster of another guild"
    elseif tooLowLevel then
        return false, "player level too low to create a guild"
    end
    return false, "guild creation unavailable"
end

GuildNameTicker.GuildUtils = GuildNameTickerGuildUtils
