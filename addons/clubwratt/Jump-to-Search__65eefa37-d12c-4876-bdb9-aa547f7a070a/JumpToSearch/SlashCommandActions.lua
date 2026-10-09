local Log = JumpToSearch.LogUtils
local ScreenUtils = JumpToSearch.ScreenUtils

local SlashCommandActions = {}

local USAGE = "/jts on|off | keyboard on|off | debug | status | export"

---@param value boolean
---@return string
local function OnOff(value)
    return value and "on" or "off"
end

local function PrintStatus()
    local state = JumpToSearch.state
    local sv = state.savedVars
    local counters = state.counters
    Log.Log("v%s enabled=%s keyboard=%s debug=%s layer=%s active=%s",
        JumpToSearch.version, OnOff(sv.enabled), OnOff(sv.openKeyboard), OnOff(sv.debug),
        tostring(IsActionLayerActiveByName(JumpToSearch.actionLayerName)),
        state.activeTarget and state.activeTarget.name or "none")
    Log.Log("D-pad Right presses=%d jumps=%d fallthroughs=%d returns=%d",
        counters.keyDowns, counters.jumps, counters.fallthroughs, counters.returns)

    local target = state.activeTarget
    if target then
        local screen = target.getScreen()
        local canJump, reason = ScreenUtils.CanJump(screen)
        local list = screen and target.getList(screen) or nil
        Log.Log("%s: canJump=%s (%s) index=%s/%s headerActive=%s",
            target.name, tostring(canJump), reason,
            tostring(ScreenUtils.GetSelectedIndex(list)), tostring(ScreenUtils.GetNumItems(list)),
            tostring(screen and screen.IsHeaderActive and screen:IsHeaderActive()))
    end
end

---@param args string Raw command arguments
function SlashCommandActions.HandleCommand(args)
    local command, remaining = JumpToSearch.SlashCommandUtils.ParseCommand(args)
    local state = JumpToSearch.state
    if not state then
        Log.Log("not initialized yet")
        return
    end
    local sv = state.savedVars

    if command == "on" then
        sv.enabled = true
        Log.Log("D-pad Right jump enabled")
    elseif command == "off" then
        sv.enabled = false
        Log.Log("D-pad Right jump disabled")
    elseif command == "keyboard" then
        if remaining == "on" or remaining == "off" then
            sv.openKeyboard = (remaining == "on")
        else
            sv.openKeyboard = not sv.openKeyboard
        end
        Log.Log("open keyboard on jump: %s", OnOff(sv.openKeyboard))
    elseif command == "debug" then
        sv.debug = not sv.debug
        Log.Log("debug logging %s", OnOff(sv.debug))
    elseif command == "status" or command == "" then
        PrintStatus()
    elseif command == "export" then
        Log.Export()
    else
        Log.Log("unknown command '%s'. %s", command, USAGE)
    end
end

JumpToSearch.SlashCommandActions = SlashCommandActions
