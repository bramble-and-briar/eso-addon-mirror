-- GuildNameTicker.lua: Root namespace
GuildNameTicker = {
    name = "GuildNameTicker",
    version = "0.5.0",
    savedVarsName = "GuildNameTickerSavedVars",
    -- v2: message/packWords replaced by quickName + lines[]
    savedVarsVersion = 2,
    ---@type GuildNameTickerState
    state = nil,
}

---Errors and usage hints go to the chat system channel; the success path is
---silent (the Character menu itself shows the result).
---@param message string
function GuildNameTicker.Log(message)
    local chatRouter = _G["CHAT_ROUTER"]
    if chatRouter then
        chatRouter:AddSystemMessage("[GuildNameTicker] " .. message)
    end
end
