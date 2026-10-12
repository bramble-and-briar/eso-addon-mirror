local Hermes = _G['Hermes']
local EVENT_MANAGER = EVENT_MANAGER

local calculateConstraints = SharedChatContainer.CalculateConstraints

function Hermes:SetChatHook()
    function SharedChatContainer.CalculateConstraints(...)
        local container = ...
        local w, h = GuiRoot:GetDimensions()
        container.system.maxContainerWidth, container.system.maxContainerHeight = w * 0.95, h * 0.95
        return calculateConstraints(...)
    end
end

function Hermes:ConvRGBToHex(r, g, b)
    return string.format("|c%.2x%.2x%.2x", zo_floor(r * 255), zo_floor(g * 255), zo_floor(b * 255))
end

function Hermes:ConvHexToRGB(colourString)
    local r = tonumber(string.sub(colourString, 3, 4), 16) or 255
    local g = tonumber(string.sub(colourString, 5, 6), 16) or 255
    local b = tonumber(string.sub(colourString, 7, 8), 16) or 255
    return r / 255, g / 255, b / 255
end

function Hermes.Debounce(namespace, timeout, callbackFunc)
    EVENT_MANAGER:UnregisterForUpdate(namespace)

    EVENT_MANAGER:RegisterForUpdate(namespace, timeout, function()
        EVENT_MANAGER:UnregisterForUpdate(namespace)
        callbackFunc()
    end)
end