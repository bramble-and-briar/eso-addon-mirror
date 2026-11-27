SimpleCharName = {}
SimpleCharName.name = "SimpleCharName"

local defaults = {
    left = nil,
    top = nil,
}

function SimpleCharName.OnMoveStop()
    SimpleCharName.savedVars.left = SimpleCharNameWindow:GetLeft()
    SimpleCharName.savedVars.top = SimpleCharNameWindow:GetTop()
end

local function Initialize()
    SimpleCharName.savedVars = ZO_SavedVars:NewAccountWide("SimpleCharNameVars", 1, nil, defaults)

    -- Restore saved window position if it has been moved
    if SimpleCharName.savedVars.left and SimpleCharName.savedVars.top then
        SimpleCharNameWindow:ClearAnchors()
        SimpleCharNameWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SimpleCharName.savedVars.left, SimpleCharName.savedVars.top)
    end

    -- Set the label text to your active character's name
    local charName = GetUnitName("player")
    SimpleCharNameWindowLabel:SetText(charName)
end

local function OnAddOnLoaded(event, addonName)
    if addonName == SimpleCharName.name then
        EVENT_MANAGER:UnregisterForEvent(SimpleCharName.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(SimpleCharName.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
