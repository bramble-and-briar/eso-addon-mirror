WizardsHelper = {
    name = "WizardsHelper",
    title = "Wizard's Helper",
    version = "0.1.0-beta.1",
    sliceMilliseconds = 2,
    operationsPerSlice = 40,
}
local WH = WizardsHelper

ZO_CreateStringId("SI_BINDING_NAME_WIZARDS_HELPER_TOGGLE", "Toggle Wizard's Helper")

function WH:Message(text)
    local message = "|c92c9ff[Wizard's Helper]|r " .. tostring(text)
    if CHAT_ROUTER then CHAT_ROUTER:AddSystemMessage(message) else d(message) end
end

function WH:SetStatus(text, announce)
    self.status = text
    if self.ui then self.ui.status:SetText(text) end
    if self.UpdateKeybinds then self:UpdateKeybinds() end
    if announce then self:Message(text) end
end

function WH:Initialize()
    local ok, reason = self:CheckWardrobe()
    if not ok then self:Message(reason); return end
    self.sv = ZO_SavedVars:NewAccountWide("WizardsHelperSV", 1, nil, {
        window = {},
        sources = {},
    }, GetWorldName())
    self:CreateUI()
    self:RegisterGamepadMenu()
    EVENT_MANAGER:RegisterForEvent(self.name .. "Menu", EVENT_PLAYER_ACTIVATED, function()
        if self:RegisterGamepadMenu() then EVENT_MANAGER:UnregisterForEvent(self.name .. "Menu", EVENT_PLAYER_ACTIVATED) end
    end)
    self:RegisterRadial()
    SLASH_COMMANDS["/whelper"] = function() self:Toggle() end
    SLASH_COMMANDS["/wizardshelper"] = SLASH_COMMANDS["/whelper"]
    self.initialized = true
end

EVENT_MANAGER:RegisterForEvent(WH.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= WH.name then return end
    EVENT_MANAGER:UnregisterForEvent(WH.name, EVENT_ADD_ON_LOADED)
    WH:Initialize()
end)
