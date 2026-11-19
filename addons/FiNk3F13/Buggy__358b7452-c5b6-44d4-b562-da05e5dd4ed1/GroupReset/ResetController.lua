-- Reset through ESO's difficulty change, as used by FastReset. Observe the
-- actual change and restore the captured difficulty rather than toggling a
-- second time based on a possibly stale server value.
GroupResetReset = {}
local R = GroupResetReset
local settings, report, state
local UPDATE = "GroupResetDifficulty"
local function Now() return GetFrameTimeMilliseconds() end
local function InInstance()
    return IsPlayerInRaid() or IsUnitInDungeon("player")
        or (type(IsPlayerInRaidStagingArea) == "function" and IsPlayerInRaidStagingArea())
end
local function Stop()
    state = nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE)
end
local function SameLeader()
    return IsUnitGrouped("player") and IsUnitGroupLeader("player")
        and GetUnitDisplayName("player") == state.leader
end

local function Poll()
    if not state then return end
    if not SameLeader() then
        local changed = state.phase == "flipping" or state.phase == "restoring"
        Stop()
        if changed then report("Lead oder Gruppe geaendert. Schwierigkeit bitte vor dem naechsten Versuch pruefen.") end
        return
    end
    if state.phase == "waiting" then
        if not settings.enabled or not settings.autoReset then Stop(); return end
        if Now() >= state.expires then
            Stop(); report("Auto-Reset wartet nicht weiter: Gruppe noch in einer Instanz oder Aenderung nicht moeglich."); return
        end
        if InInstance() or IsAnyGroupMemberInDungeon() or IsUnitInCombat("player") then return end
        if type(IsGroupModificationAvailable) == "function" and not IsGroupModificationAvailable() then return end
        state.phase = "flipping"
        state.restoreAt = Now() + 1000
        local ok = pcall(SetVeteranDifficulty, not state.original)
        if not ok then Stop(); report("ESO hat den Auto-Reset nicht ausgefuehrt.") end
        return
    end
    if InInstance() then
        Stop(); report("Instanz waehrend des Resets betreten. Schwierigkeit bitte pruefen."); return
    end
    local current = IsGroupUsingVeteranDifficulty()
    if state.phase == "flipping" then
        if current ~= state.original then state.sawChange = true end
        if Now() < state.restoreAt then return end
        state.phase = "restoring"
        state.expires, state.retryAt, state.attempts = Now() + 10000, Now() + 2000, 1
        -- Restore even when the first server response has not arrived yet.
        -- Once a change was requested, switching off must still restore it.
        local ok = pcall(SetVeteranDifficulty, state.original)
        if not ok then report("Urspruengliche Schwierigkeit noch nicht wiederhergestellt; erneuter Versuch folgt.") end
        return
    end
    if state.phase == "restoring" then
        if current ~= state.original then state.sawChange = true end
        if state.sawChange and current == state.original then Stop(); return end
        if Now() >= state.expires then
            local text = current == state.original
                and "Schwierigkeit ist unveraendert; ESO hat den Instanz-Reset nicht bestaetigt."
                or "Schwierigkeit konnte nicht wiederhergestellt werden. Bitte in der Gruppe manuell zurueckstellen."
            Stop(); report(text); return
        end
        if current ~= state.original and Now() >= state.retryAt and state.attempts < 3 then
            state.attempts = state.attempts + 1
            state.retryAt = Now() + 2000
            pcall(SetVeteranDifficulty, state.original)
        end
    end
end

function R.Prepare()
    if not settings.enabled or not settings.autoReset or not IsUnitGroupLeader("player") then return end
    state = {phase = "leaving", original = IsGroupUsingVeteranDifficulty(),
        leader = GetUnitDisplayName("player"), expires = Now() + 60000}
end

function R.Activated()
    if not state or state.phase ~= "leaving" then return end
    if Now() >= state.expires or InInstance() then Stop(); return end
    state.phase = "waiting"
    state.expires = Now() + 60000
    EVENT_MANAGER:RegisterForUpdate(UPDATE, 250, Poll)
    Poll()
end

function R.CancelPending()
    if state and (state.phase == "waiting" or state.phase == "leaving") then Stop() end
end

function R.Describe() return state and ("Auto-Reset: " .. state.phase) or "kein Auto-Reset ausstehend" end
function R.Initialize(config, output) settings, report = config, output end
