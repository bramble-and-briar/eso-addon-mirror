-- HomeAfterPvPSettingsActions.lua: Gamepad-friendly settings page via
-- LibHarvensAddonSettings (register with AddAddon + AddSetting).

local HomeAfterPvPSettingsActions = {}

---@return HomeAfterPvPSavedVars
local function GetSettings()
    return HomeAfterPvP.state.savedVars
end

function HomeAfterPvPSettingsActions.Initialize()
    local LAS = _G["LibHarvensAddonSettings"]
    if not LAS or not LAS.AddAddon then
        HomeAfterPvP.Log("LibHarvensAddonSettings not available; settings page disabled")
        return
    end

    local panel = LAS:AddAddon("Home After PvP")
    panel.author = "clubwratt"
    panel.version = "v" .. tostring(HomeAfterPvP.version)

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Travel home after PvP",
        tooltip = "When a battleground, Cyrodiil or the Imperial City returns you to the main world, travel to your primary residence at once. Landing in a house or a dungeon is left alone.",
        getFunction = function()
            return GetSettings().enabled
        end,
        setFunction = function(value)
            GetSettings().enabled = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_CHECKBOX,
        label = "Leave from the scoreboard",
        tooltip = "When a battleground match ends, start the trip home from the scoreboard wherever the game allows it, so the travel cast runs while the scoreboard is up and the stop in the main world is skipped.",
        getFunction = function()
            return GetSettings().fromScoreboard
        end,
        setFunction = function(value)
            GetSettings().fromScoreboard = value
        end,
    })

    panel:AddSetting({
        type = LAS.ST_BUTTON,
        label = "Travel home now",
        tooltip = "Close this menu and travel to your primary residence.",
        buttonText = "Travel",
        clickHandler = function()
            HomeAfterPvP.TravelActions.TravelNow()
            SCENE_MANAGER:ShowBaseScene()
        end,
    })
end

HomeAfterPvP.SettingsActions = HomeAfterPvPSettingsActions
