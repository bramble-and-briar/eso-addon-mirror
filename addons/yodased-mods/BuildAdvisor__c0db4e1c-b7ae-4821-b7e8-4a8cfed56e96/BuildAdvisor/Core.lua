BuildAdvisor = BuildAdvisor or {}
local BA = BuildAdvisor
BA.name = "BuildAdvisor"
BA.version = "0.1.6"
-- Schema 2: no default build. Schema 1 saved "oak_sorc_ia" for everyone as a default, not a choice.
BA.schema = 2
-- Account-wide: the player's own preferences.
BA.defaults = { popupSeconds = 10 }
-- Per character: what this character is built for. nil means guess from the scan.
BA.characterDefaults = { role = nil, activity = nil }

function BA:Print(message)
    d("|c66CCFF[Build Advisor]|r " .. tostring(message))
end

function BA:Init()
    if ZO_SavedVars then
        self.saved = ZO_SavedVars:NewAccountWide("BuildAdvisorSaved", self.schema, nil, self.defaults)
        self.char = ZO_SavedVars:NewCharacterIdSettings("BuildAdvisorSaved", self.schema, nil, self.characterDefaults)
    else
        self.saved = self.defaults
        self.char = self.characterDefaults
    end
    -- Data removed from Data/*.lua must not leave a dangling selection.
    self.char.selectedBuild = nil -- left over from before builds were reference-only
    if self.char.role and not self.rolesById[self.char.role] then self.char.role = nil end
    if self.char.activity and not self.activitiesById[self.char.activity] then self.char.activity = nil end
    if self.InitializeMenu then self:InitializeMenu() end
end

SLASH_COMMANDS["/buildadvisor"] = function() BA:ShowSummary() end
SLASH_COMMANDS["/badv"] = function() BA:ShowSummary() end

local function OnAddonLoaded(_, name)
    if name ~= BA.name then return end
    EVENT_MANAGER:UnregisterForEvent(BA.name, EVENT_ADD_ON_LOADED)
    BA:Init()
end
EVENT_MANAGER:RegisterForEvent(BA.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
