local PRT = PotionResourceTags
local NAME = "PotionResourceTags"

local function OnLoaded(_, addonName)
    if addonName ~= NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    PRT.Diagnostics.Initialize()
    PRT.Hooks.Initialize()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        PRT.Hooks.RefreshHUD()
    end)
    if #PRT.Hooks.missing > 0 then
        local command = PRT.Diagnostics.registeredCommands[1]
        d("Potion Resource Tags: UI connection incomplete; " .. (command and command .. " status" or "no diagnostic command alias available"))
    end
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, OnLoaded)
