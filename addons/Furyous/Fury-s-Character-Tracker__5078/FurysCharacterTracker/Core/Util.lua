-- shared
-- Small helpers used everywhere.
local CT = FurysCharacterTracker
local U = {}
CT.Util = U

function U.Print(fmt, ...)
    local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    CHAT_ROUTER:AddSystemMessage("|cA08CFF[Character Tracker]|r " .. text)
end

function U.FormatDate(timestamp)
    if not timestamp or timestamp == 0 then return "" end
    return os.date("%Y-%m-%d", timestamp)
end

-- "Sat 03:15 PM"
function U.DayTime(timestamp)
    return os.date("%a %I:%M %p", timestamp)
end

function U.Plain(text)
    -- Strip the game's grammar markers ("Infuryate^Mx" -> "Infuryate").
    return zo_strformat("<<1>>", text or "")
end

-- 1234567 -> "1,234,567". Whole numbers only.
function U.Comma(n)
    return ZO_CommaDelimitNumber(math.floor((n or 0) + 0.5))
end

-- A whole number as text: "5", never "5.0" (the offline viewer's Lua writes whole decimals that way).
function U.Whole(n)
    return string.format("%d", math.floor((n or 0) + 0.5))
end

-- "12/50"
function U.Of(value, max)
    return U.Whole(value) .. "/" .. U.Whole(max)
end

-- A craft's name: the game's own in game, English in the offline viewer.
function U.CraftName(craft)
    if CT.live then return U.Plain(GetString("SI_TRADESKILLTYPE", craft)) end
    return CT.TEXT.CRAFTS[craft] or "?"
end

-- "+1,234", "-56", "0"
function U.Signed(n)
    n = math.floor((n or 0) + 0.5)
    if n > 0 then return "+" .. ZO_CommaDelimitNumber(n) end
    if n < 0 then return "-" .. ZO_CommaDelimitNumber(-n) end
    return "0"
end

-- 1234567 -> "1.2M", 45200 -> "45k", 950 -> "950": for cells too narrow for the whole number.
function U.Short(n)
    n = math.floor((n or 0) + 0.5)
    local sign = n < 0 and "-" or ""
    if n < 0 then n = -n end
    if n >= 1000000 then return string.format("%s%.1fM", sign, math.floor(n / 100000) / 10) end
    if n >= 10000 then return string.format("%s%dk", sign, math.floor(n / 1000)) end
    return sign .. ZO_CommaDelimitNumber(n)
end

-- "1 character", "3 characters"
function U.Count(n, word, plural)
    return string.format("%d %s", n, n == 1 and word or (plural or (word .. "s")))
end

-- "2d 4h", "5h 12m", "12m"
function U.Duration(seconds)
    seconds = math.max(0, seconds)
    local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if days > 0 then return string.format("%dd %dh", days, hours) end
    if hours > 0 then return string.format("%dh %dm", hours, minutes) end
    return string.format("%dm", math.max(minutes, 1))
end

-- Noon of the calendar day a moment falls on, in your own time zone.
local function Noon(timestamp)
    local d = os.date("*t", timestamp)
    return os.time({ year = d.year, month = d.month, day = d.day, hour = 12 })
end

-- Whole calendar days from one moment to another.
function U.DaysBetween(from, to)
    return math.floor((Noon(to) - Noon(from)) / 86400 + 0.5)
end

-- "today", "yesterday", "3 days ago", by calendar day in your own time zone.
function U.Ago(timestamp)
    if not timestamp or timestamp == 0 then return "never" end
    local days = U.DaysBetween(timestamp, GetTimeStamp())
    if days <= 0 then return "today" end
    if days == 1 then return "yesterday" end
    return days .. " days ago"
end

-- Splits "a|b|c" into { "a", "b", "c" } (empty parts kept).
function U.Split(text, separator)
    local parts, from = {}, 1
    while true do
        local at = string.find(text, separator, from, true)
        if not at then
            parts[#parts + 1] = string.sub(text, from)
            return parts
        end
        parts[#parts + 1] = string.sub(text, from, at - 1)
        from = at + #separator
    end
end

-- Text safe to put between "|" and ";" separators in saved lines.
function U.Clean(text)
    return (tostring(text or ""):gsub("[|;\n]", " "))
end

-- A game icon drawn inside text.
function U.Icon(path, size)
    if not path or path == "" then return "" end
    return string.format("|t%d:%d:%s|t", size or 20, size or 20, path)
end
