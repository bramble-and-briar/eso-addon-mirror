--[[
    Mansu's InstanceReset
    ---------------------
    Three bindable keys for what the group window is otherwise opened for when
    resetting an instance:

      * Reset   - switches the dungeon mode (Normal / Veteran) to the other
                  value and straight back, the usual way to get a fresh
                  dungeon instance.  The mode ends where it started.
      * Toggle  - switches between Normal and Veteran and stays there.
      * Leave   - leaves the instance you are in.  The key has to be pressed
                  twice, so a stray press in a fight only shows a message.

    The /mir chat command does the same.

    Every change of mode is requested from the game exactly the way the two
    buttons of the group window request it, so the game's own rules still
    decide whether it is allowed (solo or group leader only, not while in a
    dungeon, not in an activity-finder group, not with an active Group Finder
    listing, level 50 required).  When the game refuses, its own explanation
    is shown.  The instance reset itself is the game's doing; the add-on only
    switches the mode.

    Verified against the ESO UI source (esoui 12.1.5, API 101051):
      ingame/lfg/veterandifficultysettings.lua
          CanPlayerChangeGroupDifficulty()      -> canChange, reason
          CanUnitGainChampionPoints("player")   -> Veteran button enabled or not
          SetVeteranDifficulty(isVeteran)       -> what the two buttons call
      ingame/group/grouputils.lua
          ZO_GetEffectiveDungeonDifficulty()    -> group setting when grouped, own setting otherwise
      ingame/alerttext/alerthandlers.lua, alerttext_shared.lua
          the game announces a group change itself; ZO_Alert drops a message
          it has already shown during the last 3 seconds
      ingame/group/keyboard/zo_grouplist_keyboard.lua, ingame/globals/ingamedialogs.lua
          "Leave Instance" is offered when CanExitInstanceImmediately() and,
          once confirmed, calls ExitInstanceImmediately()
      ingame/globals/bindings.xml
          the game binds a key straight to ExitInstanceImmediately() itself
          (INSTANCE_KICK_LEAVE_INSTANCE); battlegrounds have their own
          LeaveBattleground() dialog and are left alone here

    AI disclosure: the code was generated with an AI assistant (Anthropic Claude) under the
    author's direction.

    Credits: Raidificator (code65536, Olivierko) already offers a key to reset instances,
    by disbanding and reforming the group, and a key to leave an instance that must be
    pressed twice.  This add-on resets by a different method; the leave key and its
    double press follow the same idea.  No code was taken from it.
]]

MansusInstanceReset = MansusInstanceReset or {}
local MIR = MansusInstanceReset

MIR.name        = "MansusInstanceReset"
MIR.displayName = "Mansu's InstanceReset"
MIR.version     = "1.0.1"
MIR.author      = "Karim"

-- Each change is asked from the server. Until it answers, the add-on looks at the current mode
-- every CHECK_INTERVAL_MS and gives up after CONFIRM_TIMEOUT_MS. The timeout stays below the
-- 3 seconds during which ZO_Alert drops a repeated message (see AlertChanged).
local CHECK_INTERVAL_MS  = 100
local CONFIRM_TIMEOUT_MS = 2000
local UPDATE_NAME        = MIR.name .. "Confirm"

-- ---------------------------------------------------------------------------
-- Texts
-- The add-on's own texts are string ids created in lang/en.lua and translated in
-- lang/<language>.lua (see the manifest); they are read with GetString / zo_strformat.
-- The mode names, the "changed to ..." alerts and the refusal reasons are the game's own
-- strings, so they follow the client language by themselves.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Chat output
-- ---------------------------------------------------------------------------
function MIR.Msg(text)
    local line = "|c00BFFFMIR|r " .. tostring(text)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(line)
    else
        d(line)
    end
end

-- ---------------------------------------------------------------------------
-- Current mode
-- ---------------------------------------------------------------------------
-- true when the mode that applies to the player right now is Veteran: the group's setting when
-- grouped, the player's own setting otherwise (the rule of ZO_GetEffectiveDungeonDifficulty).
function MIR.IsVeteran()
    if IsUnitGrouped("player") then
        return IsGroupUsingVeteranDifficulty() == true
    end
    return IsUnitUsingVeteranDifficulty("player") == true
end

-- "Normal" / "Veteran" in the client language
local function GetModeName(isVeteran)
    local difficulty = isVeteran and DUNGEON_DIFFICULTY_VETERAN or DUNGEON_DIFFICULTY_NORMAL
    return GetString("SI_DUNGEONDIFFICULTY", difficulty)
end

-- ---------------------------------------------------------------------------
-- Alerts (top-right corner, like the game's own messages)
-- ---------------------------------------------------------------------------
-- The game's explanation for a refusal - the text behind the "?" icon of the group window.
local function GetReasonText(reason)
    local text = GetString("SI_GROUPDIFFICULTYCHANGEREASON", reason)
    if not text or text == "" then
        -- e.g. GROUP_DIFFICULTY_CHANGE_REASON_NO_UNIT has no text of its own
        return GetString(SI_MANSUSINSTANCERESET_CANNOT_CHANGE)
    end
    if reason == GROUP_DIFFICULTY_CHANGE_REASON_NOT_UNLOCKED then
        -- "Unlocked once your character reaches Level 50." needs its subject outside the group window
        return GetString(SI_DUNGEON_DIFFICULTY_HEADER) .. " " .. text
    end
    return text
end

local function AlertRefused(text)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, text)
end

-- Same text and sound as the alert the game raises by itself when a group's mode changes, so if
-- the game has just announced the change, ZO_Alert drops this one instead of showing it twice.
local function AlertChanged(isVeteran)
    if isVeteran then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DUNGEON_DIFFICULTY_VETERAN, GetString(SI_DUNGEON_DIFFICULTY_CHANGED_TO_VETERAN))
    else
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.DUNGEON_DIFFICULTY_NORMAL, GetString(SI_DUNGEON_DIFFICULTY_CHANGED_TO_NORMAL))
    end
end

-- ---------------------------------------------------------------------------
-- Changing the mode
-- ---------------------------------------------------------------------------
-- A job is the list of modes still to be asked from the server, one after the other:
-- one step for a plain change, two for a reset (the other mode, then the original one).
--   job = { steps = { true/false, ... }, index = current step, deadline = frame time in ms }
local job -- nil when idle

local function StopJob()
    job = nil
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
end

local function RequestCurrentStep()
    job.deadline = GetFrameTimeMilliseconds() + CONFIRM_TIMEOUT_MS
    SetVeteranDifficulty(job.steps[job.index])
end

-- Called on the game's "difficulty changed" events and every CHECK_INTERVAL_MS while a job is
-- running. It only trusts the mode the game reports, not the events' arguments.
local function CheckJob()
    if not job then
        return
    end

    local wantVeteran = job.steps[job.index]
    if MIR.IsVeteran() == wantVeteran then
        AlertChanged(wantVeteran)
        if job.index < #job.steps then
            job.index = job.index + 1
            RequestCurrentStep()
        else
            StopJob()
        end
    elseif GetFrameTimeMilliseconds() >= job.deadline then
        local failedStep = job.index
        StopJob()
        if failedStep > 1 then
            -- a reset went to the other mode but did not come back
            AlertRefused(zo_strformat(SI_MANSUSINSTANCERESET_NOT_RESTORED, GetModeName(MIR.IsVeteran())))
        else
            AlertRefused(GetString(SI_MANSUSINSTANCERESET_NOT_CHANGED))
        end
    end
end

-- Checks shared by every action. Shows the game's explanation and returns false when the mode
-- cannot be changed.
local function CanStart(steps)
    if job then
        return false -- the server has not answered the previous key press yet
    end

    local canChange, reason = CanPlayerChangeGroupDifficulty()
    if not canChange then
        AlertRefused(GetReasonText(reason))
        return false
    end

    -- The group window disables its Veteran button for characters that cannot earn Champion Points yet.
    if not CanUnitGainChampionPoints("player") then
        for _, wantVeteran in ipairs(steps) do
            if wantVeteran then
                AlertRefused(GetReasonText(GROUP_DIFFICULTY_CHANGE_REASON_NOT_UNLOCKED))
                return false
            end
        end
    end

    return true
end

local function StartJob(steps)
    job = { steps = steps, index = 1 }
    RequestCurrentStep()
    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, CHECK_INTERVAL_MS, CheckJob)
end

-- Asks the game to set the dungeon mode (true = Veteran, false = Normal).
-- Returns true when a request was sent to the server.
function MIR.SetVeteran(wantVeteran)
    wantVeteran = wantVeteran == true

    local steps = { wantVeteran }
    if not CanStart(steps) then
        return false
    end

    if MIR.IsVeteran() == wantVeteran then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, zo_strformat(SI_MANSUSINSTANCERESET_ALREADY, GetModeName(wantVeteran)))
        return false
    end

    StartJob(steps)
    return true
end

-- The Toggle key: Normal -> Veteran, Veteran -> Normal.
function MIR.Toggle()
    return MIR.SetVeteran(not MIR.IsVeteran())
end

-- The Reset key: to the other mode, then back to the current one.
-- Returns true when the first request was sent to the server.
function MIR.Reset()
    local current = MIR.IsVeteran()

    local steps = { not current, current }
    if not CanStart(steps) then
        return false
    end

    StartJob(steps)
    return true
end

-- ---------------------------------------------------------------------------
-- Leaving the instance
-- ---------------------------------------------------------------------------
-- The group window asks "Are you sure?" before it leaves. Here the confirmation is a second
-- press of the key within LEAVE_CONFIRM_MS, so a stray press only shows a message.
local LEAVE_CONFIRM_MS = 3000
local leaveArmedUntil = 0 -- frame time (ms) until which the next press of the key leaves

-- Same condition as the group window's "Leave Instance" key. Battlegrounds are left through the
-- game's own dialog, which warns about the penalty, so they are refused here.
local function CanLeaveInstance()
    return CanExitInstanceImmediately() and not IsActiveWorldBattleground()
end

-- Leaves the instance at once. Returns true when the request was sent.
function MIR.LeaveNow()
    leaveArmedUntil = 0
    if not CanLeaveInstance() then
        AlertRefused(GetString(SI_MANSUSINSTANCERESET_LEAVE_NOT_HERE))
        return false
    end

    ExitInstanceImmediately()
    return true
end

-- The Leave key: the first press asks for a second one, the second press leaves.
-- Returns true when the request was sent.
function MIR.Leave()
    local now = GetFrameTimeMilliseconds()
    if now < leaveArmedUntil then
        return MIR.LeaveNow()
    end

    if not CanLeaveInstance() then
        AlertRefused(GetString(SI_MANSUSINSTANCERESET_LEAVE_NOT_HERE))
        return false
    end

    leaveArmedUntil = now + LEAVE_CONFIRM_MS
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, GetString(SI_MANSUSINSTANCERESET_LEAVE_CONFIRM))
    return false
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
local function PrintStatus()
    local _, reason = CanPlayerChangeGroupDifficulty()
    MIR.Msg(GetString(SI_DUNGEON_DIFFICULTY_HEADER) .. " " .. GetModeName(MIR.IsVeteran()))

    -- "You are in control of the dungeon mode." or the reason why it is locked
    local reasonText = GetString("SI_GROUPDIFFICULTYCHANGEREASON", reason)
    if reasonText and reasonText ~= "" then
        MIR.Msg(reasonText)
    end
end

local function PrintHelp()
    PrintStatus()
    MIR.Msg(zo_strformat(SI_MANSUSINSTANCERESET_HELP_TITLE, MIR.version))
    MIR.Msg(GetString(SI_MANSUSINSTANCERESET_HELP_RESET))
    MIR.Msg(GetString(SI_MANSUSINSTANCERESET_HELP_TOGGLE))
    MIR.Msg(GetString(SI_MANSUSINSTANCERESET_HELP_NORMAL))
    MIR.Msg(GetString(SI_MANSUSINSTANCERESET_HELP_VETERAN))
    MIR.Msg(GetString(SI_MANSUSINSTANCERESET_HELP_LEAVE))
    MIR.Msg(GetString(SI_MANSUSINSTANCERESET_HELP_KEYBIND))
end

local function OnSlashCommand(args)
    local command = (args or ""):match("^%s*(%S*)") or ""
    command = command:lower()

    if command == "reset" or command == "r" then
        MIR.Reset()
    elseif command == "toggle" or command == "t" then
        MIR.Toggle()
    elseif command == "vet" or command == "veteran" or command == "v" then
        MIR.SetVeteran(true)
    elseif command == "normal" or command == "n" then
        MIR.SetVeteran(false)
    elseif command == "leave" or command == "l" then
        MIR.LeaveNow() -- a typed command is deliberate: no second confirmation
    else
        PrintHelp()
    end
end

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------
local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= MIR.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(MIR.name, EVENT_ADD_ON_LOADED)

    -- Move a running job forward as soon as the game reports a change (own setting or group setting).
    EVENT_MANAGER:RegisterForEvent(MIR.name, EVENT_VETERAN_DIFFICULTY_CHANGED, CheckJob)
    EVENT_MANAGER:RegisterForEvent(MIR.name, EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED, CheckJob)

    SLASH_COMMANDS["/mir"] = OnSlashCommand
    SLASH_COMMANDS["/instancereset"] = OnSlashCommand
end

EVENT_MANAGER:RegisterForEvent(MIR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
