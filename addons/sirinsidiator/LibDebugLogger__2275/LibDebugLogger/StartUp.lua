-- SPDX-FileCopyrightText: 2025 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

-- first thing we do is to measure the start time
local UI_LOAD_START_TIME = GetTimeStamp() * 1000
local SESSION_START_TIME = UI_LOAD_START_TIME - GetGameTimeMilliseconds()

local LIB_IDENTIFIER = "LibDebugLogger"

assert(not _G[LIB_IDENTIFIER], LIB_IDENTIFIER .. " is already loaded")

local callbackObject = ZO_CallbackObject:New()

local function FireCallbacks(self, ...)
    return callbackObject:FireCallbacks(...)
end

local lib = {
    id = LIB_IDENTIFIER,
    internal = {
        class = {},
        log = {},
        verboseWhitelist = {},
        callbackObject = callbackObject,
        FireCallbacks = FireCallbacks,
        UI_LOAD_START_TIME = UI_LOAD_START_TIME,
        SESSION_START_TIME = SESSION_START_TIME,
        LOGGER_CONFIG = {
            tag = LIB_IDENTIFIER
        }
    },
    callback = {},
}
_G[LIB_IDENTIFIER] = lib
