-- English IDs and optional language overrides are loaded before this helper.
local A = RoleplayPostSupport

function A.L(key, ...)
    local id = assert(_G["RPS_" .. key], "Unknown localization key: " .. tostring(key))
    local text = GetString(id)
    if select("#", ...) == 0 then return text end
    -- Keep user text verbatim; ESO grammar formatting is only used for character names.
    return string.format(text, ...)
end
