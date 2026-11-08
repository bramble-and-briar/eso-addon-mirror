-- SPDX-FileCopyrightText: 2026 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if not Taneth or not Taneth.IsExternal() then return end

ADDON_STATE_NO_STATE = 0
ADDON_STATE_TOC_LOADED = 1
ADDON_STATE_ENABLED = 2
ADDON_STATE_DISABLED = 3
ADDON_STATE_VERSION_MISMATCH = 4
ADDON_STATE_DEPENDENCIES_DISABLED = 5
ADDON_STATE_ERROR_STATE_UNABLE_TO_LOAD = 6

FULLSCREEN_MODE_WINDOWED = 0
FULLSCREEN_MODE_FULLSCREEN_WINDOWED = 1
FULLSCREEN_MODE_FULLSCREEN_EXCLUSIVE = 2

GAMEPAD_TYPE_NONE = 0
GAMEPAD_TYPE_XBOX = 1
GAMEPAD_TYPE_PS4 = 2
GAMEPAD_TYPE_SWITCH = 3
GAMEPAD_TYPE_STADIA = 4
GAMEPAD_TYPE_DEPRECATED = 5
GAMEPAD_TYPE_PS5 = 6
GAMEPAD_TYPE_XBSX = 7

SLASH_COMMANDS = SLASH_COMMANDS or {}
if not ZO_ERROR_FRAME then
    ZO_ERROR_FRAME = { suppressedErrors = {} }
end

if not CHAT_ROUTER then
    CHAT_ROUTER = ZO_CallbackObject:New()
    function CHAT_ROUTER:AddSystemMessage(messageText)
        if RequestDebugPrintText then
            RequestDebugPrintText(messageText)
        end
    end
    function CHAT_ROUTER:AddDebugMessage(messageText)
        self:AddSystemMessage(messageText)
    end
end

function GetWorldName() return "ESOLua" end
function GetPlatformServiceType() return PLATFORM_SERVICE_TYPE_ZOS end

function GetAddOnManager()
    return {
        GetNumAddOns = function(self) return 0 end,
        GetAddOnInfo = function(self, index) return nil end,
        GetAddOnVersion = function(self, index) return 0 end,
        GetAddOnRootDirectoryPath = function(self, index) return "" end,
        GetAddOnNumDependencies = function(self, index) return 0 end,
        GetAddOnDependencyInfo = function(self, index, dependencyIndex) return nil end,
        GetLoadOutOfDateAddOns = function(self) return false end,
    }
end

function GetFramerate() return 60 end
function GetLatency() return 0 end
