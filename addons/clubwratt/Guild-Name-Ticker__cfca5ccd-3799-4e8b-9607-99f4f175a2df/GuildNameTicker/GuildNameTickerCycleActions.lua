-- GuildNameTickerCycleActions.lua: The guild-name state machine.
--
-- Two entry points share the same machinery:
--   SetName(name)  ("single" mode, /gt): disband the previous ticker guild if
--     we still lead one (you can only be guildmaster of one guild), create the
--     new name, represent it in the Character menu, and keep it until the next
--     SetName/Clear/Start.
--   Start()        ("ticker" mode): same create/represent steps, but each name
--     only holds for intervalMs before being disbanded and replaced by the
--     next line, looping forever.
--
-- Per name: GuildCreate -> EVENT_GUILD_SELF_JOINED_GUILD ->
-- SetRepresentedGuildId -> (ticker only: hold, GuildLeave ->
-- EVENT_GUILD_SELF_LEFT_GUILD -> next).
--
-- Crash/reload safety: savedVars.lastCreatedGuildName is written when
-- GuildCreate is dispatched and only cleared once the server confirms the
-- disband, so after /reloadui the next SetName/Clear/Start can always find
-- and disband the leftover guild by name.
--
-- Console note: the stock dialog's platform name pre-validation
-- (RequestNameValidation) calls the private RequestConsoleTextValidation and
-- errors from addon code, so we only run the client-side IsValidGuildName
-- check and let the server reject anything else via EVENT_SOCIAL_ERROR.

local GuildNameTickerCycleActions = {}

local WATCHDOG_MS = 15000
local FAILURE_RETRY_DELAY_MS = 1000

local function GetRun()
    return GuildNameTicker.state.run
end

local function GetSettings()
    return GuildNameTicker.state.savedVars
end

local function Log(format, ...)
    GuildNameTicker.Log(string.format(format, ...))
end

---Wrap a base name in the configured prefix/suffix, verbatim: no separator
---is inserted, so the user includes the space themselves if they want one.
---@param name string
---@return string
local function Decorate(name)
    local settings = GetSettings()
    return (settings.prefix or "") .. name .. (settings.suffix or "")
end

---How many characters remain for the base name once the prefix/suffix are
---accounted for. Zero or negative means the decoration alone is too long.
---@return integer
local function GetEffectiveMaxNameLength()
    local settings = GetSettings()
    return GuildNameTicker.GuildUtils.GetMaxNameLength() - #(settings.prefix or "") - #(settings.suffix or "")
end

---Schedule a callback that self-cancels if the run is stopped/restarted.
---@param delayMs integer
---@param callback function
local function After(delayMs, callback)
    local token = GetRun().token
    zo_callLater(function()
        if GetRun().token == token then
            callback()
        end
    end, delayMs)
end

-- Forward declaration: AttemptNextCreate and the failure path call each other.
local AttemptNextCreate

---Count a failed create; in single mode one failure ends the run, in ticker
---mode we move on and only give up after a full lap of failures.
local function SkipChunk()
    local run = GetRun()
    run.attemptId = run.attemptId + 1
    run.pendingName = nil
    run.consecutiveFailures = run.consecutiveFailures + 1
    if run.mode == "single" then
        GuildNameTickerCycleActions.Stop("could not set that guild name; see the reason above")
        return
    end
    if run.consecutiveFailures >= #run.chunks then
        GuildNameTickerCycleActions.Stop("every name failed; check the log for reasons")
        return
    end
    After(FAILURE_RETRY_DELAY_MS, AttemptNextCreate)
end

---Alliance for new guilds: the Advanced setting, or the player's own
---alliance when it is 0 ("your alliance"). Only settable at creation.
---@return integer
local function GetCreationAlliance()
    local alliance = GetSettings().alliance or 0
    if alliance == 0 then
        return GetUnitAlliance("player")
    end
    return alliance
end

---Apply the Advanced attributes (description, MOTD, guild finder playtime
---hours) to a guild we lead. Empty strings and an empty hour window
---(start == end) leave that attribute untouched.
---@param guildId integer
local function ApplyAttributesTo(guildId)
    local settings = GetSettings()
    if settings.description and settings.description ~= "" then
        SetGuildDescription(guildId, settings.description)
    end
    if settings.motd and settings.motd ~= "" then
        SetGuildMotD(guildId, settings.motd)
    end
    local startHour = settings.playtimeStartHour or 0
    local endHour = settings.playtimeEndHour or 0
    if startHour ~= endHour then
        SetGuildRecruitmentStartTime(guildId, startHour)
        SetGuildRecruitmentEndTime(guildId, endHour)
        SaveGuildRecruitmentPendingChanges(guildId)
    end
end

---@param name string
local function DoCreate(name)
    local run = GetRun()
    local canCreate, reason = GuildNameTicker.GuildUtils.CanCreateGuildNow()
    if not canCreate then
        GuildNameTickerCycleActions.Stop("cannot create a guild right now: " .. reason)
        return
    end

    run.phase = "creating"
    run.pendingName = name
    run.attemptId = run.attemptId + 1
    local attemptId = run.attemptId

    -- Record the name before the create round-trips: if the UI reloads while
    -- the create is in flight, the next run can still find the guild by name.
    -- A failed create leaves a stale name behind, which is harmless because
    -- the lookup verifies a solo-led guild with that name actually exists.
    GetSettings().lastCreatedGuildName = name

    GuildCreate(name, GetCreationAlliance())

    After(WATCHDOG_MS, function()
        if run.attemptId == attemptId and run.phase == "creating" then
            Log("no response to GuildCreate('%s') after %dms; skipping", name, WATCHDOG_MS)
            SkipChunk()
        end
    end)
end

AttemptNextCreate = function()
    local run = GetRun()
    run.chunkIndex = (run.chunkIndex % #run.chunks) + 1
    local name = run.chunks[run.chunkIndex]

    local violations = GuildNameTicker.GuildUtils.GetNameViolations(name)
    if #violations > 0 then
        Log("'%s' violates guild naming rules (%d violation(s)); skipping", name, #violations)
        SkipChunk()
        return
    end

    DoCreate(name)
end

local function LeaveCurrentGuild()
    local run = GetRun()
    local guildId = run.currentGuildId
    if not guildId then
        AttemptNextCreate()
        return
    end
    if not GuildNameTicker.GuildUtils.IsSoloLedGuild(guildId) then
        GuildNameTickerCycleActions.Stop("refusing to leave guild " .. tostring(guildId) .. ": not a solo guild we lead")
        return
    end

    run.phase = "leaving"
    run.attemptId = run.attemptId + 1
    local attemptId = run.attemptId

    -- A restart while a leave was in flight lands here with the same guild;
    -- don't send a second GuildLeave, just re-arm the watchdog and wait for
    -- the left event.
    if run.disbandingGuildId ~= guildId then
        run.disbandingGuildId = guildId
        GuildLeave(guildId)
    end

    After(WATCHDOG_MS, function()
        if run.attemptId == attemptId and run.phase == "leaving" then
            GuildNameTickerCycleActions.Stop(string.format("no response to GuildLeave after %dms", WATCHDOG_MS))
        end
    end)
end

---Find the throwaway guild we still lead, either from the current run state
---or (after /reloadui or a crash) by the name recorded in saved vars.
---@return integer|nil guildId
local function FindOwnedGuildId()
    local run = GetRun()
    if run.currentGuildId and GuildNameTicker.GuildUtils.IsSoloLedGuild(run.currentGuildId) then
        return run.currentGuildId
    end
    return GuildNameTicker.GuildUtils.FindSoloLedGuildIdByName(GetSettings().lastCreatedGuildName)
end

---Re-apply the Advanced attributes to the guild we currently lead, if any.
---Called by the settings panel so edits take effect immediately instead of
---waiting for the next created guild.
function GuildNameTickerCycleActions.ApplyGuildAttributes()
    local guildId = FindOwnedGuildId()
    if guildId then
        ApplyAttributesTo(guildId)
    end
end

---Start a run in the given mode. Any in-flight run is invalidated (its timers
---and watchdogs self-cancel via token/attemptId), and the throwaway guild we
---currently lead is disbanded first since we can only be guildmaster of one
---guild at a time.
---@param mode string "single" | "ticker"
---@param chunks string[]
local function Begin(mode, chunks)
    local run = GetRun()

    -- A create still in flight from the previous run will land after this
    -- restart; remember that so the joined handler can tell it apart from
    -- our own create and disband it instead of representing it.
    run.stalePendingName = (run.phase == "creating") and run.pendingName or nil

    run.active = true
    run.mode = mode
    run.phase = "idle"
    run.token = run.token + 1
    run.attemptId = run.attemptId + 1
    run.chunks = chunks
    run.chunkIndex = 0
    run.consecutiveFailures = 0
    run.pendingName = nil

    local ownedGuildId = FindOwnedGuildId()

    -- Remember what to restore on stop, but not if we are currently
    -- representing our own throwaway guild (restarting mid-run): keep the
    -- value captured when the first run started instead.
    local representedGuildId = GetRepresentedGuildId()
    if representedGuildId ~= ownedGuildId and representedGuildId ~= run.currentGuildId then
        run.previousRepresentedGuildId = representedGuildId
    end

    if ownedGuildId then
        run.currentGuildId = ownedGuildId
        LeaveCurrentGuild()
    else
        run.currentGuildId = nil
        AttemptNextCreate()
    end
end

local function OnSelfJoinedGuild(_eventId, _guildServerId, _characterName, guildId)
    local run = GetRun()
    if not run.active or run.phase ~= "creating" then
        return
    end
    local name = GetGuildName(guildId)
    if name ~= run.pendingName then
        if not IsPlayerGuildMaster(guildId) then
            return
        end
        if run.stalePendingName then
            -- A create dispatched before this run started (Set/Start pressed
            -- while one was in flight) completed late, and it is not the name
            -- the user wants now. Track it, disband it, and retry the current
            -- chunk once the server confirms the disband. Our own in-flight
            -- create bounces off "already a guildmaster", which the leaving
            -- phase ignores.
            run.stalePendingName = nil
            run.currentGuildId = guildId
            GetSettings().lastCreatedGuildName = name
            run.chunkIndex = run.chunkIndex - 1
            LeaveCurrentGuild()
            return
        end
        -- No stale create can exist, so this is our create with the name
        -- normalized by the server; accept it.
    end

    run.stalePendingName = nil
    run.consecutiveFailures = 0
    run.currentGuildId = guildId
    run.pendingName = nil
    -- Re-record with the server's normalized spelling of the name.
    GetSettings().lastCreatedGuildName = name

    SetRepresentedGuildId(guildId)
    ApplyAttributesTo(guildId)

    if run.mode == "single" then
        -- Done: the guild stays until the next SetName/Clear/Start disbands it.
        run.active = false
        run.phase = "idle"
        run.token = run.token + 1
        run.attemptId = run.attemptId + 1
        return
    end

    run.phase = "displaying"
    After(GetSettings().intervalMs, LeaveCurrentGuild)
end

local function OnSelfLeftGuild(_eventId, _guildServerId, _characterName, guildId)
    local run = GetRun()

    -- The server confirmed the disband of our throwaway guild: only now is it
    -- safe to forget the saved name. An unconfirmed leave keeps the record so
    -- the next run (even after /reloadui) retries the disband.
    if guildId == run.disbandingGuildId then
        run.disbandingGuildId = nil
        GetSettings().lastCreatedGuildName = ""
    end

    if not run.active or run.phase ~= "leaving" or guildId ~= run.currentGuildId then
        return
    end

    run.currentGuildId = nil
    AttemptNextCreate()
end

local function OnSocialError(_eventId, result)
    local run = GetRun()
    if not run.active or run.phase ~= "creating" then
        return
    end
    Log("create '%s' failed: %s", tostring(run.pendingName), GuildNameTicker.GuildUtils.DescribeSocialResult(result))
    SkipChunk()
end

---Set one guild name and keep it (the /gt path). The configured prefix and
---suffix are added verbatim; the base name is truncated so the decorated
---result fits the max guild name length. Disbands the previous ticker guild
---first.
---@param name string
function GuildNameTickerCycleActions.SetName(name)
    name = zo_strtrim(name or "")
    if name == "" then
        Log("usage: /gt <guild name> (or /gt alone to disband the ticker guild)")
        return
    end

    local maxLen = GetEffectiveMaxNameLength()
    if maxLen <= 0 then
        Log("the prefix/suffix alone exceed the %d-character guild name limit", GuildNameTicker.GuildUtils.GetMaxNameLength())
        return
    end
    if #name > maxLen then
        local truncated = zo_strtrim(string.sub(name, 1, maxLen))
        Log("'%s' is longer than the %d characters left after the prefix/suffix; using '%s'", name, maxLen, truncated)
        name = truncated
    end

    Begin("single", { Decorate(name) })
end

---Cycle through the non-empty ticker lines from the settings, holding each
---for intervalMs. Each name gets the configured prefix/suffix verbatim;
---lines longer than the remaining length are split.
function GuildNameTickerCycleActions.Start()
    local settings = GetSettings()
    local maxLen = GetEffectiveMaxNameLength()
    if maxLen <= 0 then
        Log("the prefix/suffix alone exceed the %d-character guild name limit", GuildNameTicker.GuildUtils.GetMaxNameLength())
        return
    end

    local chunks = {}
    for _, line in ipairs(settings.lines) do
        for _, chunk in ipairs(GuildNameTicker.TextUtils.BuildChunks(line, maxLen, true)) do
            table.insert(chunks, Decorate(chunk))
        end
    end
    if #chunks == 0 then
        Log("no ticker names set; fill in some lines in the addon settings")
        return
    end

    Begin("ticker", chunks)
end

---@param reason string
function GuildNameTickerCycleActions.Stop(reason)
    local run = GetRun()
    if not run.active then
        return
    end

    run.active = false
    run.token = run.token + 1
    run.attemptId = run.attemptId + 1
    run.phase = "idle"
    run.pendingName = nil

    -- Disband the throwaway guild and put the Character menu dropdown back
    -- the way we found it (if that guild still exists). The saved name is
    -- cleared by OnSelfLeftGuild once the server confirms the disband.
    if run.currentGuildId and GuildNameTicker.GuildUtils.IsSoloLedGuild(run.currentGuildId)
        and run.disbandingGuildId ~= run.currentGuildId then
        run.disbandingGuildId = run.currentGuildId
        GuildLeave(run.currentGuildId)
    end
    run.currentGuildId = nil

    local previousId = run.previousRepresentedGuildId
    if previousId and previousId > 0 and _G["ZO_ValidatePlayerGuildId"](previousId) then
        SetRepresentedGuildId(previousId)
    else
        SetRepresentedGuildId(0)
    end

    Log("stopped: %s", reason)
end

---Disband whatever throwaway guild we lead and clear the represented guild.
---Works both while a run is active (stops it) and after a single set.
function GuildNameTickerCycleActions.Clear()
    local run = GetRun()
    if run.active then
        GuildNameTickerCycleActions.Stop("cleared")
        return
    end

    local ownedGuildId = FindOwnedGuildId()
    if not ownedGuildId then
        Log("no ticker guild to clear")
        return
    end

    if run.disbandingGuildId ~= ownedGuildId then
        run.disbandingGuildId = ownedGuildId
        GuildLeave(ownedGuildId)
    end
    run.currentGuildId = nil
    SetRepresentedGuildId(0)
end

function GuildNameTickerCycleActions.InitializeEventHandlers()
    EVENT_MANAGER:RegisterForEvent(GuildNameTicker.name, EVENT_GUILD_SELF_JOINED_GUILD, OnSelfJoinedGuild)
    EVENT_MANAGER:RegisterForEvent(GuildNameTicker.name, EVENT_GUILD_SELF_LEFT_GUILD, OnSelfLeftGuild)
    EVENT_MANAGER:RegisterForEvent(GuildNameTicker.name, EVENT_SOCIAL_ERROR, OnSocialError)
end

GuildNameTicker.CycleActions = GuildNameTickerCycleActions
