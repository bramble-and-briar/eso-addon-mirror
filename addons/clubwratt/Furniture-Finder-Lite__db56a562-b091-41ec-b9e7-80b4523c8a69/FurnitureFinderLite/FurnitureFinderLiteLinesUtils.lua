-- FurnitureFinderLiteLinesUtils.lua: pure wording of a furnishing's sources (no game calls).
--
-- A source reads as a header and indented detail lines, the way Furniture Finder writes them:
--   Source: Luxury Furnisher
--     Price: 50,000 gold
--     Last seen: 2026-05-01
-- Names the game knows (zones, achievements, quests, items) come through the `resolve` function
-- the caller passes in, so this file needs no game.
local FFL = FurnitureFinderLite

local LinesUtils = {}

-- The detail lines, in the order shown: a label, the token letters it gathers, and how many
-- values it lists before "+N more".
LinesUtils.FIELDS = {
    { label = "Location", letters = "zp", limit = 6 },
    { label = "Event", letters = "e" },
    { label = "Price", letters = "$" },
    { label = "Requires", letters = "asC" },
    { label = "Quest", letters = "q" },
    { label = "Houses", letters = "h", limit = 4 },
    { label = "Found in", letters = "c" },
    { label = "Pack", letters = "P", limit = 3 },
    { label = "Bundle", letters = "b" },
    { label = "From", letters = "Gg" },
    { label = "Rarity", letters = "r" },
    { label = "Note", letters = "n" },
    { label = "Last seen", letters = "d" },
    { label = "Plan", letters = "B" },
}

local HEADER_LETTER = "w"
local INDENT = "  "

---"260501" -> "2026-05-01".
---@param value string yymmdd
---@return string|nil
function LinesUtils.DateText(value)
    local year, month, day = string.match(value, "^(%d%d)(%d%d)(%d%d)$")
    if not year then
        return nil
    end
    return "20" .. year .. "-" .. month .. "-" .. day
end

---1234567 -> "1,234,567".
---@param amount integer
---@return string
function LinesUtils.NumberText(amount)
    local text = tostring(math.floor(amount))
    local grouped
    repeat
        text, grouped = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
    until grouped == 0
    return text
end

---The lines of a furnishing's sources.
---@param records FurnitureFinderLiteRecord[]
---@param resolve fun(letter: string, value: string): string|nil the text of a token, nil to leave it out
---@return string[] lines
function LinesUtils.Compose(records, resolve)
    local lines = {}
    for index, record in ipairs(records) do
        local header, valuesByLetter = nil, {}
        for _, token in ipairs(record) do
            local letter, value = token[1], token[2]
            local text = resolve(letter, value)
            if text and text ~= "" then
                if letter == HEADER_LETTER then
                    header = text
                else
                    local values = valuesByLetter[letter]
                    if not values then
                        values = {}
                        valuesByLetter[letter] = values
                    end
                    values[#values + 1] = text
                end
            end
        end
        header = header or "Unknown"
        lines[#lines + 1] = #records > 1 and ("Source " .. index .. ": " .. header) or ("Source: " .. header)
        for _, field in ipairs(LinesUtils.FIELDS) do
            local values = {}
            for position = 1, #field.letters do
                for _, text in ipairs(valuesByLetter[string.sub(field.letters, position, position)] or {}) do
                    values[#values + 1] = text
                end
            end
            if #values > 0 then
                local limit = field.limit or #values
                local shown = {}
                for position = 1, math.min(limit, #values) do
                    shown[position] = values[position]
                end
                local text = table.concat(shown, ", ")
                if #values > limit then
                    text = text .. ", +" .. (#values - limit) .. " more"
                end
                lines[#lines + 1] = INDENT .. field.label .. ": " .. text
            end
        end
    end
    return lines
end

FFL.LinesUtils = LinesUtils
