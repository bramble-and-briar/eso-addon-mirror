-- Small helpers shared by every module: the fall colours and debug output.

local addon = SlayansBossTimer
local Util = {}
addon.Util = Util

-- Autumn leaf colours, red to gold. All are bright enough to read on the chat window's dark background; brown and
-- dark red are left out on purpose.
local FALL_COLORS = {
    { 0xFF, 0x4F, 0x3A }, -- Maple red
    { 0xFF, 0x57, 0x22 }, -- Scarlet orange
    { 0xFF, 0x8F, 0x00 }, -- Pumpkin
    { 0xFF, 0xB3, 0x00 }, -- Amber
    { 0xFF, 0xD5, 0x4F }, -- Harvest gold
}

-- Returns the colour at a point (0 to 1) along the palette, going red to gold and back to red.
local function FallColorAt(position)
    -- Fold the second half back, so the text starts and ends on red.
    local folded = position <= 0.5 and position * 2 or (1 - position) * 2
    local scaled = folded * (#FALL_COLORS - 1)
    local index = zo_min(zo_floor(scaled) + 1, #FALL_COLORS - 1)
    local fraction = scaled - (index - 1)
    local from, to = FALL_COLORS[index], FALL_COLORS[index + 1]
    local color = {}
    for channel = 1, 3 do
        color[channel] = zo_floor(from[channel] + (to[channel] - from[channel]) * fraction + 0.5)
    end
    return string.format("%02X%02X%02X", color[1], color[2], color[3])
end

-- Colours each letter of the text along the fall palette. Spaces are left plain.
-- Letters are read as whole UTF-8 characters, so accented letters in other languages stay intact.
function Util.FallGradient(text)
    local characters = {}
    for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(characters, character)
    end
    local length = #characters
    local parts = {}
    for index, character in ipairs(characters) do
        if character == " " then
            table.insert(parts, character)
        else
            local position = length > 1 and (index - 1) / (length - 1) or 0
            table.insert(parts, string.format("|c%s%s|r", FallColorAt(position), character))
        end
    end
    return table.concat(parts)
end

-- Prints a debug message to chat when debug output is switched on. There is no chat command for it; on PC, type
-- /script SlayansBossTimer.debug = true
function Util.Debug(message, ...)
    if addon.debug then
        CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", addon.name, string.format(message, ...)))
    end
end
