-- High Achiever: Settings > Add-Ons > High Achiever.

local HA = ESOC_HighAchiever
local Settings = {}
HA.Settings = Settings

local function createSettings(LHAS)
    local page = LHAS:AddAddon(HA.TITLE, { allowRefresh = true })
    local options = HA.sv.options
    local function open(tab)
        return function() HA.Screen.Open(tab) end
    end
    page:AddSettings({
        { type = LHAS.ST_LABEL, label = function()
            local ok, text = pcall(function() return HA.Lists.Summary(HA.Place.Get()) end)
            return ok and text or HA.TITLE
        end },
        { type = LHAS.ST_BUTTON, label = "Achievements here", buttonText = "Open",
            tooltip = "Every achievement for where you are, closest to done first. X pins one to your screen. LT and RT change tab, LB and RB change page.",
            clickHandler = open("Here") },
        { type = LHAS.ST_BUTTON, label = "Rewards here", buttonText = "Open",
            tooltip = "Achievements here that give a title, dye, mount, pet or other reward.",
            clickHandler = open("Rewards") },
        { type = LHAS.ST_BUTTON, label = "Done here", buttonText = "Open", clickHandler = open("Done") },
        { type = LHAS.ST_BUTTON, label = "Pin the closest one here", buttonText = "Pin",
            tooltip = "Puts the achievement you're closest to finishing here on the game's on-screen tracker.",
            clickHandler = function()
                local state = HA.Place.Get()
                local entry = state.todo[1]
                if not entry then
                    HA.Alert("nothing left to do here.")
                elseif HA.Pin(entry.id) then
                    HA.Alert("pinned " .. entry.name)
                end
            end },

        { type = LHAS.ST_SECTION, label = "Options" },
        { type = LHAS.ST_CHECKBOX, label = "Show a panel when I arrive somewhere new",
            getFunction = function() return options.showPanel end,
            setFunction = function(value) options.showPanel = value end },
        { type = LHAS.ST_SLIDER, label = "Panel stays for (seconds)", min = 5, max = 60, step = 5, format = "%d",
            getFunction = function() return options.panelSeconds end,
            setFunction = function(value) options.panelSeconds = value end },
        { type = LHAS.ST_CHECKBOX, label = "Pin the closest achievement when I arrive",
            tooltip = "Replaces whatever achievement you had pinned.",
            getFunction = function() return options.autoPin end,
            setFunction = function(value) options.autoPin = value end },

        { type = LHAS.ST_BUTTON, label = "Detection check (for testing)", buttonText = "Open", clickHandler = open("Check") },
    })
end

function Settings.Install()
    local LHAS = LibHarvensAddonSettings
    if LHAS and LHAS.AddAddon then createSettings(LHAS) end
end
