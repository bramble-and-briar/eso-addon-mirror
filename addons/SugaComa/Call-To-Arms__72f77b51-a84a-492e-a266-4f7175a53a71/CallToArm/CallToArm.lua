-- CallToArm.lua
-- CallToArm — Guild-focused Call-to-Arms alerts for Cyrodiil
-- By SugaComa

-- Create or reuse the global namespace table (safe if reloaded)
local CallToArm = _G.CallToArm or {}
_G.CallToArm = CallToArm

CallToArm.name = "CallToArm"

local EM = EVENT_MANAGER
local CURRENT_SCHEMA = (CallToArm.Config and CallToArm.Config.SCHEMA_VERSION) or 1
local LOCK_UPDATE_HANDLE = "CALLTOARM_LOCK_STATE_UPDATE"

local function Debug(msg)
    if CallToArm.SV and CallToArm.SV.debug then
        d("|c88ccffCALLTOARM|r: " .. tostring(msg))
    end
end

local function MigrateSV(sv)
    if type(sv) ~= "table" then return end
    sv.schemaVersion = tonumber(sv.schemaVersion) or 0

    sv.guild = sv.guild or { defaultName = "CallToArm", alliance = 0 }
    sv.cta = sv.cta or { representedGuildId = 0, representLockedUntil = 0 }
    sv.byGuild = sv.byGuild or {}
    sv.ui = sv.ui or {}

    if sv.debugSafeMode == nil then
        sv.debugSafeMode = false
    end

    sv.schemaVersion = CURRENT_SCHEMA
end

local function InitSavedVars()
    CallToArm.SV = ZO_SavedVars:NewAccountWide("CallToArm_SV", 1, nil, CallToArm.Config.Defaults)
    MigrateSV(CallToArm.SV)
    if CallToArm.SV then
        CallToArm.SV.lastSessionLoadedAt = GetTimeStamp and GetTimeStamp() or 0
        CallToArm.SV.sessionCounter = tonumber(CallToArm.SV.sessionCounter) or 0
        CallToArm.SV.sessionCounter = CallToArm.SV.sessionCounter + 1
    end
end

local function SanitizeSavedVars(root, removedKeysOut)
    if type(root) ~= "table" then return 0 end
    local removed = 0
    local seen = {}

    local function CleanTable(t, path)
        if seen[t] then return end
        seen[t] = true
        for k, v in pairs(t) do
            local tv = type(v)
            local keyPath = path .. "." .. tostring(k)
            if tv == "function" or tv == "userdata" or tv == "thread" then
                t[k] = nil
                removed = removed + 1
                if removedKeysOut then
                    removedKeysOut[#removedKeysOut + 1] = keyPath .. " (" .. tv .. ")"
                end
            elseif tv == "table" then
                CleanTable(v, keyPath)
            end
        end
    end

    CleanTable(root, "SV")
    return removed
end

local function DumpTableToChat(root, maxDepth, maxLines, header)
    if type(root) ~= "table" then
        d("|c88ccffCALLTOARM|r: SV dump: not a table.")
        return
    end
    maxDepth = tonumber(maxDepth) or 2
    maxLines = tonumber(maxLines) or 80
    if maxDepth < 0 then maxDepth = 0 end
    if maxLines < 1 then maxLines = 1 end
    local lines = 0

    local function CountKeys(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    local function Recurse(t, depth, path)
        if lines >= maxLines then return end
        for k, v in pairs(t) do
            if lines >= maxLines then return end
            local tv = type(v)
            local keyPath = path .. "." .. tostring(k)
            if tv == "table" then
                d(string.format("|c88ccffCALLTOARM|r: %s = table (%d keys)", keyPath, CountKeys(v)))
                lines = lines + 1
                if depth > 0 then
                    Recurse(v, depth - 1, keyPath)
                end
            else
                d(string.format("|c88ccffCALLTOARM|r: %s = %s", keyPath, tostring(v)))
                lines = lines + 1
            end
        end
    end

    local hdr = header or "SV dump"
    d(string.format("|c88ccffCALLTOARM|r: %s start (depth=%s maxLines=%s)", hdr, tostring(maxDepth), tostring(maxLines)))
    Recurse(root, maxDepth, "SV")
    if lines >= maxLines then
        d(string.format("|c88ccffCALLTOARM|r: %s truncated.", hdr))
    else
        d(string.format("|c88ccffCALLTOARM|r: %s end.", hdr))
    end
end

local function BootSystems()
    CallToArm.Guild.AutoSelectDefaultGuildIfNeeded()
    CallToArm.Guild.RefreshSelectedGuildAllianceCache()

    CallToArm.UI.Init()
    if CallToArm.Leaderboard and CallToArm.Leaderboard.Init then
        CallToArm.Leaderboard.Init()
    end
    if CallToArm.CTA and CallToArm.CTA.Init then
        CallToArm.CTA.Init()
    end

    if EM and EM.RegisterForUpdate then
        EM:RegisterForUpdate(LOCK_UPDATE_HANDLE, 1000, function()
            if CallToArm.Guild and CallToArm.Guild.UpdateLockState then
                CallToArm.Guild.UpdateLockState()
            end
        end)
    end
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= CallToArm.name then return end
    EM:UnregisterForEvent(CallToArm.name, EVENT_ADD_ON_LOADED)

    InitSavedVars()
    if CallToArm.SV and CallToArm.SV.debug then
        Debug(string.format("Loaded addonName=%s expected=%s svKey=%s", tostring(addonName), tostring(CallToArm.name), "CallToArm_SV"))
    end

    EM:RegisterForEvent(CallToArm.name, EVENT_PLAYER_ACTIVATED, function()
        EM:UnregisterForEvent(CallToArm.name, EVENT_PLAYER_ACTIVATED)
        BootSystems()

        zo_callLater(function()
            CallToArm.Guild.RefreshSelectedGuildAllianceCache()
            CallToArm.UI.Init()
            Debug("Second-pass init complete")
        end, 1500)

        if CallToArm.SV and CallToArm.SV.debug then
            local loadedAt = CallToArm.SV.lastSessionLoadedAt or 0
            local savedAt = CallToArm.SV.lastSessionSavedAt or 0
            local reason = CallToArm.SV.lastSessionSavedReason or "unknown"
            Debug(string.format("SV: loadedAt=%s savedAt=%s reason=%s", tostring(loadedAt), tostring(savedAt), tostring(reason)))
        end
    end)

    EM:RegisterForEvent("CALLTOARM_SV_SAVE", EVENT_PLAYER_DEACTIVATED, function()
        if CallToArm.SV then
            local removedKeys = {}
            local removed = SanitizeSavedVars(CallToArm.SV, removedKeys)
            CallToArm.SV.lastSessionSavedAt = GetTimeStamp and GetTimeStamp() or 0
            CallToArm.SV.lastSessionSavedReason = "player_deactivated"
            if removed > 0 and CallToArm.SV.debug then
                Debug("SV sanitize removed " .. tostring(removed) .. " entries.")
                Debug("SV sanitize removed keys: " .. table.concat(removedKeys, ", "))
            end
            Debug("SV save stamp updated.")
        end
    end)

    Debug("Loaded")
end

EM:RegisterForEvent(CallToArm.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

SLASH_COMMANDS["/cttimereset"] = function()
    if not CallToArm.SV then return end
    if CallToArm.SV.cta then
        CallToArm.SV.cta.representLockedUntil = 0
    end
    if CallToArm.UI and CallToArm.UI.ShowCenter then
        CallToArm.UI.ShowCenter("CALLTOARM: Guild switch cooldown reset.")
    end
end

function CallToArm.ResetSavedVars()
    if not CallToArm.SV or not CallToArm.Config or not CallToArm.Config.Defaults then return end
    for k in pairs(CallToArm.SV) do
        CallToArm.SV[k] = nil
    end
    ZO_DeepTableCopy(CallToArm.Config.Defaults, CallToArm.SV)
    if CallToArm.UI and CallToArm.UI.ShowCenter then
        CallToArm.UI.ShowCenter("CALLTOARM: Saved vars reset. /reloadui recommended.")
    end
end

SLASH_COMMANDS["/ctreset"] = function()
    CallToArm.ResetSavedVars()
end

SLASH_COMMANDS["/ctsvdebug"] = function()
    if not CallToArm.SV then return end
    local loadedAt = CallToArm.SV.lastSessionLoadedAt or 0
    local savedAt = CallToArm.SV.lastSessionSavedAt or 0
    local reason = CallToArm.SV.lastSessionSavedReason or "unknown"
    local counter = CallToArm.SV.sessionCounter or 0
    d(string.format("|c88ccffCALLTOARM|r: SV loadedAt=%s savedAt=%s reason=%s counter=%s", tostring(loadedAt), tostring(savedAt), tostring(reason), tostring(counter)))
end

SLASH_COMMANDS["/ctsvsanitize"] = function()
    if not CallToArm.SV then return end
    local removedKeys = {}
    local removed = SanitizeSavedVars(CallToArm.SV, removedKeys)
    if removed > 0 then
        d("|c88ccffCALLTOARM|r: SV sanitize removed " .. tostring(removed) .. " entries.")
        d("|c88ccffCALLTOARM|r: SV sanitize removed keys: " .. table.concat(removedKeys, ", "))
    else
        d("|c88ccffCALLTOARM|r: SV sanitize removed 0 entries.")
    end
end

SLASH_COMMANDS["/ctsvdump"] = function(arg)
    if not CallToArm.SV then return end
    local depth = tonumber(arg) or 2
    DumpTableToChat(CallToArm.SV, depth, 80, "SV dump (actual)")
    if CallToArm.SV.default then
        DumpTableToChat(CallToArm.SV.default, depth, 80, "SV dump (default)")
    end
end
