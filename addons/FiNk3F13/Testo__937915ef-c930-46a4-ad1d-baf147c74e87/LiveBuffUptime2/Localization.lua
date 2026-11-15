local language = GetCVar and GetCVar("language.2") or "de"
local english = LiveBuffUptime2English or {}
local Localization = {language = language}
LiveBuffUptime2Localization = Localization

function Localization.Text(text)
    if language == "de" then return text end
    return english[text] or text
end

function Localization.Decimal(value, format)
    local text = string.format(format or "%.2f", value)
    if language == "de" then return (text:gsub("%.", ",")) end
    return text
end
