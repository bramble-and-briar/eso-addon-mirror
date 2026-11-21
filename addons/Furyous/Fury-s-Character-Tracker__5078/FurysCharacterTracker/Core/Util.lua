local CT = FuryCT
local U = {}
CT.Util = U

function U.Print(fmt, ...)
    local text = select("#", ...) > 0 and string.format(fmt, ...) or fmt
    local line = "|cD4AF37[Characters]|r " .. text
    if CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(line)
    else
        d(line)
    end
end

function U.FormatDate(timestamp)
    if not timestamp or timestamp == 0 then return "" end
    return os.date("%Y-%m-%d", timestamp)
end

function U.Plain(text)
    -- Strip the game's grammar markers ("Infuryate^Mx" -> "Infuryate").
    return zo_strformat("<<1>>", text or "")
end
