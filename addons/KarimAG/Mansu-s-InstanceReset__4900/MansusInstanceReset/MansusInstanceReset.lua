--[[
    Mansu's InstanceReset
    ---------------------
    Two bindable keys for the "Dungeon Mode:" setting at the top of the group
    window (Normal / Veteran), so the window never has to be opened:

      * Reset   - switches the dungeon mode to the other value and straight
                  back, the usual way to get a fresh dungeon instance.  The
                  mode ends where it started.
      * Toggle  - switches between Normal and Veteran and stays there.

    The /mir chat command does the same.

    Every change is requested from the game exactly the way the two buttons of
    the group window request it, so the game's own rules still decide whether
    it is allowed (solo or group leader only, not while in a dungeon, not in
    an activity-finder group, not with an active Group Finder listing, level
    50 required).  When the game refuses, its own explanation is shown.  The
    instance reset itself is the game's doing; the add-on only switches the
    mode.

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

    AI disclosure: the code was generated with an AI assistant (Anthropic Claude) under the
    author's direction.

    Credits: resetting instances from a key already exists in Raidificator (code65536,
    Olivierko), which does it by disbanding and reforming the group.  This add-on uses a
    different method and no code was taken from it.
]]

MansusInstanceReset = MansusInstanceReset or {}
local MIR = MansusInstanceReset

MIR.name        = "MansusInstanceReset"
MIR.displayName = "Mansu's InstanceReset"
MIR.version     = "1.0.0"
MIR.author      = "Karim"

local KEYBIND_RESET  = "MANSUSINSTANCERESET_RESET"
local KEYBIND_TOGGLE = "MANSUSINSTANCERESET_TOGGLE"

-- Each change is asked from the server. Until it answers, the add-on looks at the current mode
-- every CHECK_INTERVAL_MS and gives up after CONFIRM_TIMEOUT_MS. The timeout stays below the
-- 3 seconds during which ZO_Alert drops a repeated message (see AlertChanged).
local CHECK_INTERVAL_MS  = 100
local CONFIRM_TIMEOUT_MS = 2000
local UPDATE_NAME        = MIR.name .. "Confirm"

-- ---------------------------------------------------------------------------
-- Localisation (falls back to English)
-- The mode names, the "changed to ..." alerts and the refusal reasons are the
-- game's own strings, so they follow the client language by themselves.
-- ---------------------------------------------------------------------------
local STRINGS =
{
    en =
    {
        BINDING_RESET  = "Reset instance (switch dungeon mode and back)",
        BINDING_TOGGLE = "Toggle dungeon mode (Normal / Veteran)",
        CANNOT_CHANGE  = "The dungeon mode cannot be changed right now.",
        NOT_CHANGED    = "The dungeon mode was not changed.",
        NOT_RESTORED   = "Could not switch back: the dungeon mode is now <<1>>.",
        ALREADY        = "The dungeon mode is already <<1>>.",
        HELP_TITLE     = "Mansu's InstanceReset <<1>> - commands:",
        HELP_RESET     = "/mir reset - switch the dungeon mode and straight back (same as the Reset key)",
        HELP_TOGGLE    = "/mir toggle - switch between Normal and Veteran and stay there (same as the Toggle key)",
        HELP_NORMAL    = "/mir normal - set Normal",
        HELP_VETERAN   = "/mir vet - set Veteran",
        HELP_KEYBIND   = "Keys can be bound under Settings > Controls > Keybindings > Mansu's InstanceReset.",
    },
    fr =
    {
        BINDING_RESET  = "Réinitialiser l'instance (changer le mode de donjon puis revenir)",
        BINDING_TOGGLE = "Basculer le mode de donjon (Normal / Vétéran)",
        CANNOT_CHANGE  = "Le mode de donjon ne peut pas être modifié pour le moment.",
        NOT_CHANGED    = "Le mode de donjon n'a pas été modifié.",
        NOT_RESTORED   = "Retour impossible : le mode de donjon est maintenant <<1>>.",
        ALREADY        = "Le mode de donjon est déjà : <<1>>.",
        HELP_TITLE     = "Mansu's InstanceReset <<1>> - commandes :",
        HELP_RESET     = "/mir reset - change le mode de donjon puis revient aussitôt (comme la touche de réinitialisation)",
        HELP_TOGGLE    = "/mir toggle - bascule entre Normal et Vétéran et y reste (comme la touche de bascule)",
        HELP_NORMAL    = "/mir normal - passe en Normal",
        HELP_VETERAN   = "/mir vet - passe en Vétéran",
        HELP_KEYBIND   = "Les touches s'assignent dans Paramètres > Commandes > Raccourcis > Mansu's InstanceReset.",
    },
}

local function GetLanguageStrings()
    local lang = GetCVar and GetCVar("language.2") or "en"
    return STRINGS[lang] or STRINGS.en
end

-- Returns the localised string for a key (English fallback), formatted with zo_strformat when arguments are given.
function MIR.L(key, ...)
    local strings = GetLanguageStrings()
    local text = strings[key] or STRINGS.en[key] or key
    if select("#", ...) > 0 then
        return zo_strformat(text, ...)
    end
    return text
end

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

-- Names shown in Settings > Controls > Keybindings (must exist before the keybindings UI is built)
ZO_CreateStringId("SI_BINDING_NAME_" .. KEYBIND_RESET, MIR.L("BINDING_RESET"))
ZO_CreateStringId("SI_BINDING_NAME_" .. KEYBIND_TOGGLE, MIR.L("BINDING_TOGGLE"))

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
        return MIR.L("CANNOT_CHANGE")
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
            AlertRefused(MIR.L("NOT_RESTORED", GetModeName(MIR.IsVeteran())))
        else
            AlertRefused(MIR.L("NOT_CHANGED"))
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
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, MIR.L("ALREADY", GetModeName(wantVeteran)))
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
    MIR.Msg(MIR.L("HELP_TITLE", MIR.version))
    MIR.Msg(MIR.L("HELP_RESET"))
    MIR.Msg(MIR.L("HELP_TOGGLE"))
    MIR.Msg(MIR.L("HELP_NORMAL"))
    MIR.Msg(MIR.L("HELP_VETERAN"))
    MIR.Msg(MIR.L("HELP_KEYBIND"))
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
