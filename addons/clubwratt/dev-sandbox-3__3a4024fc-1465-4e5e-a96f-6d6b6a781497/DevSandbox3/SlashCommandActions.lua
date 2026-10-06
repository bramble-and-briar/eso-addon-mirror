-- SlashCommandActions.lua: /ds3
local Slash = {}
local LogUtils = DevSandbox3.LogUtils

function Slash.Status()
    local D, Sl = DevSandbox3.Detection, DevSandbox3.SlotActions
    local s = DevSandbox3.state.savedVars.settings
    local empty, unknown, lingering = 0, 0, 0
    for _ in pairs(Sl.empty) do empty = empty + 1 end
    for _ in pairs(Sl.unknown) do unknown = unknown + 1 end
    for _ in pairs(D.lingering) do lingering = lingering + 1 end
    LogUtils.Log("v%s: pins live %d, located %d (+%d lingering), confirmed to %dm; zone %s, %d locations within %dm: %d EMPTY, %d unconfirmed; drawn: %d empty, %d unknown, %d checked; orange=%s purple=%s yellow=%s cyan=%s",
        DevSandbox3.version, D.liveCount, D.locatedCount, lingering, math.floor(Sl.confirmedM + 0.5), tostring(Sl.zoneId), Sl.inRangeCount, Sl.RANGE_M, empty, unknown,
        DevSandbox3.Markers.drawn.empty, DevSandbox3.Markers.drawn.unknown, DevSandbox3.Markers.drawn.checked,
        tostring(s.markWarTorte), tostring(s.markPsijic), tostring(s.markUnknown), tostring(s.debugNodes))
    local _, prx, _py, prz = GetUnitRawWorldPosition("player")
    local px, pz = prx / 100, prz / 100
    local list = {}
    for _, node in pairs(D.located) do
        local dx, dz = node.x - px, node.z - pz
        list[#list + 1] = { d = math.sqrt(dx * dx + dz * dz), node = node }
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    for i = 1, math.min(8, #list) do
        local n = list[i].node
        local best
        for j = 1, Sl.inRangeCount do
            local slot = Sl.inRange[j]
            local dx, dz = slot.x - n.x, slot.z - n.z
            local d = math.sqrt(dx * dx + dz * dz)
            if not best or d < best then best = d end
        end
        LogUtils.Log("  node %dm away (type %s) -> nearest known location %s", math.floor(list[i].d + 0.5), tostring(n.pinTypeId or "?"), best and string.format("%.1fm", best) or "none in range")
    end
end

function Slash.Handle(args)
    local cmd = string.lower(string.match(args or "", "^%s*(%S+)") or "")
    local s = DevSandbox3.state.savedVars.settings
    if cmd == "" or cmd == "status" then Slash.Status()
    elseif cmd == "export" then LogUtils.Export()
    elseif cmd == "clear" then DevSandbox3.SlotActions.ClearCheckpoints()
    elseif cmd == "nodes" then s.debugNodes = not s.debugNodes; LogUtils.Log("cyan node dots %s", s.debugNodes and "ON" or "OFF")
    elseif cmd == "debug" then s.debug = not s.debug; LogUtils.Log("debug logging %s", s.debug and "ON" or "OFF")
    else LogUtils.Log("/ds3 status | clear (forget checkpoints) | export (push log to receiver) | nodes (cyan dot on every located node) | debug") end
end

DevSandbox3.Slash = Slash
