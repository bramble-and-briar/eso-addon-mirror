-- SatchelExchange.lua: Root namespace
SatchelExchange = {
    name = "SatchelExchange",
    version = "0.10.0",
    savedVarsName = "SatchelExchangeSavedVars",
    -- v8: defaults reset so auto-unbox is on out of the box for everyone
    savedVarsVersion = 8,
    ---@type SatchelExchangeState
    state = nil,
}

---Log through LibConsoleLogger when it happens to be installed; no-op
---otherwise. The logger is an optional diagnostic dependency, so it is
---resolved lazily at call time rather than captured at file load.
---@param message string
function SatchelExchange.Log(message)
    local logger = _G["LibConsoleLogger"]
    if logger then
        logger:Log("[SatchelExchange] " .. message)
    end
end
