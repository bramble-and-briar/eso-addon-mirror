-- TravelWheel.lua: Root namespace
TravelWheel = {
    name = "TravelWheel",
    title = "Travel Wheel",
    version = "0.5.0",
    savedVarsName = "TravelWheelSavedVars",
    savedVarsVersion = 1,
    ---@type TravelWheelState
    state = nil,
}

---Buffer a line in LibConsoleLogger when it is installed and enabled; no-op
---otherwise. Buffer only (never chat), and every caller is a button press or
---an event, so the lines can stay in a shipping build.
---@param message string
function TravelWheel.Log(message)
    local lib = _G["LibConsoleLogger"]
    if lib then
        lib:For(TravelWheel.name):Buffer(message)
    end
end

---Tell the player on screen, and keep the same line in the log.
---@param message string
function TravelWheel.Alert(message)
    TravelWheel.Log("alert: " .. message)
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, TravelWheel.title .. ": " .. message)
end
