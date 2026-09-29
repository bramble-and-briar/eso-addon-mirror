BGMeter = BGMeter or {}
local BGMeter = BGMeter

local Acquisition = {}

local PREFIX = "BGMeter_"

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok then return nil end
    return a
end

local function is_live_state(state)
    local C = BGMeter.zenimax.constants
    return state == C.BATTLEGROUND_STATE_STARTING
        or state == C.BATTLEGROUND_STATE_PREROUND
        or state == C.BATTLEGROUND_STATE_RUNNING
        or state == C.BATTLEGROUND_STATE_POSTROUND
end

local function on_state_change(_, previousState, currentState)
    local C = BGMeter.zenimax.constants
    local Capture = BGMeter.Capture

    BGMeter.Log.debug("bg state: %s -> %s",
        tostring(C.BG_STATE_LABEL[previousState] or previousState),
        tostring(C.BG_STATE_LABEL[currentState] or currentState))

    if not Capture.is_active() and is_live_state(currentState) then
        Capture.begin()
    end

    if currentState == C.BATTLEGROUND_STATE_RUNNING and Capture.is_active() then
        Capture.mark_running()
        Capture.rescan("gates open")
    elseif previousState == C.BATTLEGROUND_STATE_RUNNING and Capture.is_active() then
        Capture.mark_paused()
    end

    if currentState == C.BATTLEGROUND_STATE_FINISHED then
        local match = Capture.finalize()
        if match then BGMeter.Pipeline.presentation.publish(match) end
    end
end

local function on_player_activated()
    local A = BGMeter.zenimax.api
    local Capture = BGMeter.Capture
    if safe(A.is_active_bg) then
        local st = safe(A.get_bg_state)
        if not Capture.is_active() and is_live_state(st) then
            Capture.begin()
        end
    else
        if Capture.is_active() then Capture.abort() end
        BGMeter.Pipeline.presentation.on_player_activated()
    end
    if BGMeter.UI and BGMeter.UI.panel and BGMeter.UI.panel.mark_vet_dirty then BGMeter.UI.panel.mark_vet_dirty() end
    if BGMeter.UI and BGMeter.UI.warmup then
        BGMeter.UI.warmup.start()
    end
end

function Acquisition.init()
    local E = BGMeter.zenimax.events
    local C = BGMeter.zenimax.constants
    local Capture = BGMeter.Capture

    E.register(PREFIX .. "State", C.EVENT_BATTLEGROUND_STATE_CHANGED, on_state_change)
    E.register(PREFIX .. "Act",   C.EVENT_PLAYER_ACTIVATED,          on_player_activated)
    E.register(PREFIX .. "AP",    C.EVENT_ALLIANCE_POINT_UPDATE,      Capture.on_ap)
    E.register(PREFIX .. "XP",    C.EVENT_EXPERIENCE_GAIN,            Capture.on_xp)
    E.register(PREFIX .. "CP",    C.EVENT_CHAMPION_POINT_GAINED,      Capture.on_cp)
    E.register(PREFIX .. "Vet",   C.EVENT_REWARD_TRACK_PROGRESS_GAINED, function(...)
        if BGMeter.UI and BGMeter.UI.panel and BGMeter.UI.panel.mark_vet_dirty then BGMeter.UI.panel.mark_vet_dirty() end
        return Capture.on_reward_track(...)
    end)
    E.register(PREFIX .. "Kill",  C.EVENT_BATTLEGROUND_KILL,          Capture.on_kill)
    if C.EVENT_BATTLEGROUND_SCOREBOARD_UPDATED then
        E.register(PREFIX .. "Roster", C.EVENT_BATTLEGROUND_SCOREBOARD_UPDATED, Capture.on_scoreboard)
    end
    if C.EVENT_RETICLE_TARGET_PLAYER_CHANGED then
        E.register(PREFIX .. "Reticle", C.EVENT_RETICLE_TARGET_PLAYER_CHANGED, Capture.on_reticle_player)
    end
    E.register(PREFIX .. "Obj",   C.EVENT_CAPTURE_AREA_STATE_CHANGED, Capture.on_objective)
    if C.EVENT_CAPTURE_FLAG_STATE_CHANGED then
        E.register(PREFIX .. "Relic", C.EVENT_CAPTURE_FLAG_STATE_CHANGED, Capture.on_flag)
    end
    if C.EVENT_MURDERBALL_STATE_CHANGED then
        E.register(PREFIX .. "Ball", C.EVENT_MURDERBALL_STATE_CHANGED, Capture.on_murderball)
    end
    E.register(PREFIX .. "Board", C.EVENT_BATTLEGROUND_LEADERBOARD_DATA_RECEIVED, BGMeter.Standing.on_data)
    local function on_claimed()
        if BGMeter.UI and BGMeter.UI.panel and BGMeter.UI.panel.mark_vet_dirty then BGMeter.UI.panel.mark_vet_dirty() end
        if BGMeter.UI and BGMeter.UI.menu then BGMeter.UI.menu.refresh_if_visible() end
    end
    if C.EVENT_REWARD_TRACK_REWARD_CLAIMED then
        E.register(PREFIX .. "Claim", C.EVENT_REWARD_TRACK_REWARD_CLAIMED, on_claimed)
    end
    if C.EVENT_REWARD_TRACK_REWARDS_CLAIMED then
        E.register(PREFIX .. "ClaimAll", C.EVENT_REWARD_TRACK_REWARDS_CLAIMED, on_claimed)
    end

    on_player_activated()

    BGMeter.Log.debug("acquisition wired")
end

BGMeter.Pipeline = BGMeter.Pipeline or {}
BGMeter.Pipeline.acquisition = Acquisition
