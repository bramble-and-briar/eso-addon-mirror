-- Localization. UI text is written in English at the call site and passed through DT.L(text).
-- A translation is a table keyed by the English string; missing entries fall back to English, so a
-- partial translation never breaks the UI. Add a language with DT.AddTranslation("de", { ... }).

local DT = DebuffTracker

local translations = {}
local active = nil

local function ClientLanguage()
    if type(GetCVar) == "function" then
        local lang = GetCVar("language.2")
        if type(lang) == "string" and lang ~= "" then return lang end
    end
    return "en"
end

function DT.AddTranslation(lang, map)
    translations[lang] = translations[lang] or {}
    for k, v in pairs(map) do translations[lang][k] = v end
    if lang == ClientLanguage() then active = translations[lang] end
end

-- L("Text") or L("Removed <<1>> trackers", 3)  (<<n>> placeholders, like zo_strformat)
function DT.L(text, ...)
    if active == nil then active = translations[ClientLanguage()] or false end
    local s = (active and active[text]) or text
    if select("#", ...) > 0 then
        local args = { ... }
        s = s:gsub("<<(%d)>>", function(n) local v = args[tonumber(n)]; return v ~= nil and tostring(v) or "" end)
    end
    return s
end
