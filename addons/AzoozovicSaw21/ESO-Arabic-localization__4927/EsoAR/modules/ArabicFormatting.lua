-- Native LocalizeString corrupts Arabic lam-alef presentation forms, even
-- with the plain <<1>> formatter. Keep those glyphs out of its text parser;
-- restore them before text reaches a label, cache, width probe, or link.
local R = ESO_ARABIC_TEXT
local glyphs = {}
for cp = 0xFEF5, 0xFEFC do glyphs[#glyphs + 1] = R.Char(cp) end
local function hasLigature(value)
    if type(value) ~= 'string' or not value:find('\239\187', 1, true) then return false end
    for _, glyph in ipairs(glyphs) do
        if value:find(glyph, 1, true) then return true end
    end
    return false
end

function R.ProtectLocalizedFormatting(original, formatString, ...)
    local count = select('#', ...)
    local found = hasLigature(formatString)
    if not found then
        for i = 1, count do
            if hasLigature(select(i, ...)) then found = true; break end
        end
    end
    if not found then return original(formatString, ...) end
    local values = {formatString, ...}

    -- Digits and @ survive native title/lower/upper-case formatters. Choose
    -- a delimiter absent from every argument, including literal link text.
    local prefix = '@@'
    for i = 1, count + 1 do
        if type(values[i]) == 'string' then
            while values[i]:find(prefix, 1, true) do prefix = prefix .. '@' end
        end
    end
    for i = 1, count + 1 do
        if type(values[i]) == 'string' then
            for index, glyph in ipairs(glyphs) do
                values[i] = values[i]:gsub(glyph, prefix .. tostring(65012 + index) .. '@')
            end
        end
    end
    local result = original(unpack(values, 1, count + 1))
    if type(result) == 'string' then
        for index, glyph in ipairs(glyphs) do
            result = result:gsub(prefix .. tostring(65012 + index) .. '@', glyph)
        end
    end
    return result
end

if type(LocalizeString) == 'function' then
    local original = LocalizeString
    LocalizeString = function(...) return R.ProtectLocalizedFormatting(original, ...) end
end
