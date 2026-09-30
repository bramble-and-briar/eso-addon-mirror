PacketByteExporter = PacketByteExporter or {}
local PBE = PacketByteExporter

PBE.name = "PacketByteExporter"
PBE.version = "0.1.4"
PBE.schemaVersion = 1
PBE.chunkSize = 1350

local defaults = {
    endpoint = "",
    includeAccountName = false,
    includeLocation = true,
    queue = nil,
}

function PBE.Print(message)
    local text = "|c69D2E7[PBE]|r " .. tostring(message)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(text)
    elseif d then
        d(text)
    end
end

function PBE.Safe(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if ok then
        return value
    end
    return nil
end

function PBE.SafeMulti(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local function Pack(...)
        return { n = select("#", ...), ... }
    end
    local results = Pack(pcall(fn, ...))
    if not results[1] then
        return false
    end
    return true, unpack(results, 2, results.n)
end

function PBE.CleanText(value)
    if value == nil then
        return nil
    end
    local text = tostring(value)
    text = text:gsub("%^[%a]+$", "")
    if zo_strformat then
        text = zo_strformat("<<1>>", text)
    end
    return text
end

function PBE.Now()
    return PBE.Safe(GetTimeStamp) or 0
end

function PBE.GetSettings()
    return PBE.saved or defaults
end

function PBE.NormalizeEndpoint(value)
    local endpoint = (value or ""):match("^%s*(.-)%s*$")
    if endpoint == "" then
        return ""
    end
    if endpoint:match("^https?://") then
        return endpoint
    end

    local a, b, c, d = endpoint:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if a then
        local octets = { tonumber(a), tonumber(b), tonumber(c), tonumber(d) }
        for _, octet in ipairs(octets) do
            if not octet or octet < 0 or octet > 255 then
                return nil, "That is not a valid IPv4 address."
            end
        end
        return "http://" .. endpoint .. ":8787/ingest"
    end

    local host, port = endpoint:match("^([%w][%w%.%-]*):(%d+)$")
    if host and tonumber(port) and tonumber(port) >= 1 and tonumber(port) <= 65535 then
        return "http://" .. host .. ":" .. port .. "/ingest"
    end

    if endpoint:match("^[%w][%w%.%-]*$") then
        return "http://" .. endpoint .. ":8787/ingest"
    end

    return nil, "Enter the PC IP address or a complete http:// or https:// URL."
end

local function Initialize()
    local world = PBE.Safe(GetWorldName) or "Default"
    PBE.saved = ZO_SavedVars:NewAccountWide(
        "PacketByteExporterSavedVariables",
        1,
        world,
        defaults
    )
    PBE.Print("Ready. Use /pbe help or bind the PacketByte Exporter actions in Controls.")
end

EVENT_MANAGER:RegisterForEvent(PBE.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= PBE.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(PBE.name, EVENT_ADD_ON_LOADED)
    Initialize()
end)
