-- AbyssUI localization core
-- Follows game language (GetCVar Language.2). EsoBR / community codes map to pt.
NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
NAGA_UI.LocaleData = NAGA_UI.LocaleData or {}

local Locale = {}
NAGA_UI.Locale = Locale

-- Official ESO client languages + community (pt via EsoBR, pl via community packs)
Locale.SUPPORTED = { "en", "de", "fr", "es", "ru", "jp", "zh", "pt", "pl" }

-- Aliases used by the client, EsoBR, RuESO, community packs, etc.
local ALIASES = {
    ["br"] = "pt",
    ["pt-br"] = "pt",
    ["ptbr"] = "pt",
    ["pt_br"] = "pt",
    ["ja"] = "jp",
    ["jpn"] = "jp",
    ["cn"] = "zh",
    ["zh-cn"] = "zh",
    ["zh_cn"] = "zh",
    ["zh-tw"] = "zh",
    ["tw"] = "zh",
    ["kr"] = "en", -- no KR pack yet → English
    ["ko"] = "en",
}

local function normalize(code)
    if not code or code == "" then return "en" end
    code = string.lower(tostring(code))
    code = ALIASES[code] or code
    for _, s in ipairs(Locale.SUPPORTED) do
        if s == code then return code end
    end
    return "en"
end

function Locale.GetClientLanguage()
    local code = "en"
    if GetCVar then
        code = GetCVar("Language.2") or GetCVar("language.2") or "en"
    end
    -- EsoBR sets language.2 to "br"; also detect the add-on if present
    if EsoBR or (type(_G.EsoBR) == "table") then
        local n = normalize(code)
        if n == "en" and (string.lower(tostring(code)) == "br" or string.lower(tostring(code)):find("pt", 1, true)) then
            return "pt"
        end
    end
    return normalize(code)
end

function Locale.GetLanguage()
    return Locale.current or Locale.GetClientLanguage()
end

function Locale.SetLanguage(code)
    Locale.current = normalize(code)
    return Locale.current
end

--- Translate a UI string (source key = text currently in the Lua files, often PT-BR).
--- Fallback chain: active language → English → original key.
function Locale.T(key)
    if key == nil or key == "" then return key end
    local lang = Locale.GetLanguage()
    local pack = NAGA_UI.LocaleData and NAGA_UI.LocaleData[lang]
    if pack and pack[key] then return pack[key] end
    if lang ~= "en" then
        local en = NAGA_UI.LocaleData and NAGA_UI.LocaleData.en
        if en and en[key] then return en[key] end
    end
    return key
end

-- Short global helper used by settings / modules
function NAGA_UI.T(key)
    return Locale.T(key)
end

-- Initialize as early as possible
Locale.SetLanguage(Locale.GetClientLanguage())

NAGA_UI.OnAddonLoaded(function()
    Locale.SetLanguage(Locale.GetClientLanguage())
end)
