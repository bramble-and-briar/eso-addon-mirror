--[[
    Move mode (/hmark) and slash commands.
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]
local T, Msg = HMK.T, HMK.Msg
local ui = HMK.ui
local SavePosition, ApplyMarkStyle = HMK.SavePosition, HMK.ApplyMarkStyle

local function ApplyLockState()
    local win = ui.mark
    win:SetMouseEnabled(HMK.unlocked == true)   -- dragging only in move mode
    win:SetMovable(HMK.unlocked == true)
    ApplyMarkStyle()
end

function HMK.SetMoveMode(on)
    on = on == true
    if HMK.unlocked == on then return end

    -- Invalidate any pending camera-UI callback from a previous toggle.
    HMK.moveModeGeneration = (HMK.moveModeGeneration or 0) + 1
    local generation = HMK.moveModeGeneration
    HMK.unlocked = on
    ApplyLockState()

    if on then
        SCENE_MANAGER:ShowBaseScene()
        zo_callLater(function()
            -- A quick second /hmark must not re-enable camera UI mode after turning it off.
            if HMK.unlocked and HMK.moveModeGeneration == generation then
                SetGameCameraUIMode(true)
            end
        end, 200)
    else
        SetGameCameraUIMode(false)
        SavePosition(ui.mark, HMK.sv.mark)
    end
end

local function ShowCommandHelp()
    Msg(T("COMMANDS_HEADER"))
    Msg(T("COMMAND_MOVE"))
    Msg(T("COMMAND_SETTINGS"))
end

local function OnSlash(arg)
    local command = zo_strlower((arg or ""):match("^%s*(.-)%s*$"))

    if command == "" then
        HMK.SetMoveMode(not HMK.unlocked)
    elseif command == "help" then
        ShowCommandHelp()
    else
        Msg(T("UNKNOWN_OPTION"))
    end
end

HMK.OnSlash = OnSlash
