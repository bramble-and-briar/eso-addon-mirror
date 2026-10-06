if not DakJanielsApostropheFix and zo_plainstrfind(GetESOVersionString(), "12.1.5") then
    DakJanielsApostropheFix = true

    local function FixApostropheEscape(s)
        if not s then return end
        return (s:gsub("\\'", "'"))
    end

    local function OverrideNameAPI(fn)
        local original = _G[fn]
        _G[fn] = function(...)
            return FixApostropheEscape(original(...))
        end
    end

    local nameFunctions = {
        "GetUnitName",
        "GetRawUnitName",
        "GetUnitDisplayName",
        "GetUnitPlatformDisplayName",
        "GetUnitNameHighlightedByReticle",
        "GetDisplayName",
        "GetPlatformDisplayName",
        "GetCrossplayDisplayName",
        "DecorateDisplayName",
        "UndecorateDisplayName",
        "DecoratePlatformDisplayName",
    }

    for i = 1, #nameFunctions do
        OverrideNameAPI(nameFunctions[i])
    end
end
