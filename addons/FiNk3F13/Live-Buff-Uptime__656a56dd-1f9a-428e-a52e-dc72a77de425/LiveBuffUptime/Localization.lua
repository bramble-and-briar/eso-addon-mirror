local language = GetCVar and GetCVar("language.2") or "de"
local english = LiveBuffUptimeEnglish or {}
local Localization = {language = language}
LiveBuffUptimeLocalization = Localization

function Localization.Text(text)
    if language == "de" then return text end
    return english[text] or text
end

function Localization.Decimal(value, format)
    local text = string.format(format or "%.2f", value)
    if language == "de" then return (text:gsub("%.", ",")) end
    return text
end
