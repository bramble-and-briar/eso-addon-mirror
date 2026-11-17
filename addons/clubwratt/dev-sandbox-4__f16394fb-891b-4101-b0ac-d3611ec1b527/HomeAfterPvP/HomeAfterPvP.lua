-- HomeAfterPvP.lua: Root namespace
HomeAfterPvP = {
    name = "HomeAfterPvP",
    version = "0.1.0",
    savedVarsName = "HomeAfterPvPSavedVars",
    savedVarsVersion = 1,
    ---@type HomeAfterPvPState
    state = nil,
}

---Buffer a line in LibConsoleLogger when it is installed and enabled; no-op
---otherwise. Buffer only (never chat), and every caller is event-driven, so
---the lines can stay in a shipping build.
---@param message string
function HomeAfterPvP.Log(message)
    local lib = _G["LibConsoleLogger"]
    if lib then
        lib:For(HomeAfterPvP.name):Buffer(message)
    end
end
