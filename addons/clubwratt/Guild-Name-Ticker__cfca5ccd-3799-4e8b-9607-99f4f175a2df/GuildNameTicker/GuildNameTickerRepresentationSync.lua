-- GuildNameTickerRepresentationSync.lua: Keep the represented ("equipped")
-- guild consistent across characters.
--
-- Representation is per-character and the console UI changes it engine-side,
-- so there is no event to hook: instead a light poll records the currently
-- represented guild's name into the account-wide saved vars, and on login the
-- recorded name is re-applied (guild membership is account-wide, so every
-- character can represent the same guild). This covers guilds set manually
-- through the Guilds menu, not just ones this addon created.

local GuildNameTickerRepresentationSync = {}

local POLL_INTERVAL_MS = 2000
local UPDATE_NAMESPACE = "GuildNameTickerRepSync"

---@return GuildNameTickerSavedVars
local function GetSettings()
    return GuildNameTicker.state.savedVars
end

---Name of the guild currently represented on this character ("" = none).
---@return string
local function GetCurrentRepresentedName()
    local guildId = GetRepresentedGuildId()
    if guildId and guildId > 0 then
        return GetGuildName(guildId)
    end
    return ""
end

---Record the current representation. Skipped while a run is active so the
---ticker's rapid create/disband churn does not thrash the saved value; the
---restored (or single-mode final) guild is recorded once the run settles.
local function Record()
    if GuildNameTicker.state.run.active then
        return
    end
    local name = GetCurrentRepresentedName()
    if GetSettings().representedGuildName ~= name then
        GetSettings().representedGuildName = name
    end
end

---Apply the recorded representation to this character at login.
local function Apply()
    local saved = GetSettings().representedGuildName
    if saved == nil then
        -- First run of the sync on this account: adopt whatever this
        -- character has instead of clobbering it with an empty default.
        Record()
        return
    end
    if saved == GetCurrentRepresentedName() then
        return
    end
    if saved == "" then
        SetRepresentedGuildId(0)
        return
    end
    local guildId = GuildNameTicker.GuildUtils.FindGuildIdByName(saved)
    if guildId then
        SetRepresentedGuildId(guildId)
    end
    -- If the guild no longer exists (e.g. a disbanded throwaway), leave the
    -- current representation alone; the poll re-records it as the new truth.
end

function GuildNameTickerRepresentationSync.Initialize()
    EVENT_MANAGER:RegisterForEvent(UPDATE_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        -- Apply once per UI load, then start recording changes. The poll must
        -- not run before Apply, or this character's old representation would
        -- overwrite the name we are about to restore.
        EVENT_MANAGER:UnregisterForEvent(UPDATE_NAMESPACE, EVENT_PLAYER_ACTIVATED)
        Apply()
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAMESPACE, POLL_INTERVAL_MS, Record)
    end)
end

GuildNameTicker.RepresentationSync = GuildNameTickerRepresentationSync
