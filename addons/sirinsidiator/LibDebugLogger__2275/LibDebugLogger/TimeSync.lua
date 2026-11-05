-- SPDX-FileCopyrightText: 2026 sirinsidiator
--
-- SPDX-License-Identifier: Artistic-2.0

if (Taneth and Taneth.IsExternal()) or (IsConsoleUI() and GetCVar("ForceConsoleFlow.2") == "0") then return end

local lib = LibDebugLogger
local internal = lib.internal
local LDL_LOGGER_CONFIG = internal.LOGGER_CONFIG

-- small hack to allow the logviewer website to sync time stamps between game logs and our log
-- which has inaccurate timestamps due to the lack of a GetTimeStampMilliseconds api
internal.TIME_SYNC_ERROR_CODE = { [0x32BBA738] = true }
for code in pairs(internal.TIME_SYNC_ERROR_CODE) do ZO_ERROR_FRAME.suppressedErrors[code] = true end
internal.Log(internal.LOG_LEVEL_INFO, LDL_LOGGER_CONFIG, "Time Sync A")
error("Time Sync B")