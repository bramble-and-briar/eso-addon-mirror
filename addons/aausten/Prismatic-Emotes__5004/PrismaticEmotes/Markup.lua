local PE = PrismaticEmotes
PE.Markup = {}
local Markup = PE.Markup

local function color(text, hex)
    return "|c" .. hex .. text .. "|r"
end

-- Match complete words/names, not substrings of larger words. Treat UTF-8
-- bytes as word characters so a match cannot begin inside an accented word.
local function isWordByte(byte)
    return byte ~= nil and (byte >= 128 or
        (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or
        (byte >= 97 and byte <= 122) or byte == 95)
end

local function findMention(segment, start, entries)
    local lower = string.lower(segment)
    local bestStart, bestEnd, bestColor
    for _, entry in ipairs(entries) do
        local pos = start
        while true do
            local first, last = lower:find(entry.key, pos, true)
            if not first or (bestStart and first > bestStart) then
                break
            end
            if not isWordByte(segment:byte(first - 1)) and
                not isWordByte(segment:byte(last + 1)) then
                if not bestStart or first < bestStart or
                    (first == bestStart and last > bestEnd) then
                    bestStart, bestEnd, bestColor = first, last, entry.color
                end
                break
            end
            pos = first + 1
        end
    end
    return bestStart, bestEnd, bestColor
end

local function highlightSegment(segment, baseHex, entries)
    local out = {}
    local cursor = 1
    while cursor <= #segment do
        local first, last, mentionColor = findMention(segment, cursor, entries)
        if not first then
            out[#out + 1] = segment:sub(cursor)
            break
        end
        out[#out + 1] = segment:sub(cursor, first - 1)
        local matched = segment:sub(first, last)
        if baseHex == mentionColor then
            out[#out + 1] = matched
        elseif baseHex then
            out[#out + 1] = "|c" .. mentionColor .. matched .. "|c" .. baseHex
        else
            out[#out + 1] = color(matched, mentionColor)
        end
        cursor = last + 1
    end
    return table.concat(out)
end

-- Scan ESO formatting tokens; never search/replace inside link destinations,
-- textures, or color codes. Link captions are deliberately left unchanged.
local function highlightPlainText(text, baseHex, entries)
    local out = {}
    local i, length = 1, #text
    while i <= length do
        local pipe = text:find("|", i, true)
        if not pipe then
            out[#out + 1] = highlightSegment(text:sub(i), baseHex, entries)
            break
        end
        if pipe > i then
            out[#out + 1] = highlightSegment(text:sub(i, pipe - 1), baseHex, entries)
            i = pipe
        else
            local tag = text:sub(i, i + 1)
            local finish
            if tag == "|H" then
                local headerEnd = text:find("|h", i + 2, true)
                finish = headerEnd and text:find("|h", headerEnd + 2, true)
                if finish then finish = finish + 1 end
            elseif tag == "|t" or tag == "|T" then
                finish = text:find(tag, i + 2, true)
                if finish then finish = finish + 1 end
            elseif tag == "|c" and text:sub(i + 2, i + 7):match("^%x%x%x%x%x%x$") then
                finish = i + 7
            elseif tag == "|r" or tag == "||" then
                finish = i + 1
            end
            finish = finish or i
            out[#out + 1] = text:sub(i, finish)
            i = finish + 1
        end
    end
    return table.concat(out)
end

-- Do not mistake an item/player hyperlink's hidden destination for the body.
local function isInLinkDestination(formatted, position)
    local index = 1
    while true do
        local linkStart = formatted:find("|H", index, true)
        if not linkStart or linkStart >= position then
            return false
        end
        local headerEnd = formatted:find("|h", linkStart + 2, true)
        if not headerEnd then
            return true
        end
        if position < headerEnd + 2 then
            return true
        end
        index = headerEnd + 2
    end
end

local function findBody(formatted, rawText)
    if type(rawText) ~= "string" or rawText == "" then
        return nil
    end
    local start, found = 1, nil
    while true do
        local position = formatted:find(rawText, start, true)
        if not position then
            break
        end
        if not isInLinkDestination(formatted, position) then
            found = position
        end
        start = position + 1
    end
    return found
end

-- Only look for an author's name in visible text *before* the emote body.
-- A player link is wrapped intact, rather than editing its hidden link target.
local function colorAuthor(formatted, candidate, hex, limit)
    candidate = PE.Palette.CleanName(candidate)
    if not candidate then
        return nil
    end
    local target = string.lower(candidate)
    local i, max = 1, (limit and limit - 1 or #formatted)
    while i <= max do
        local pipe = formatted:find("|", i, true)
        local textEnd = math.min(max, (pipe and pipe - 1 or #formatted))
        if i <= textEnd then
            local visible = formatted:sub(i, textEnd)
            local first, last = string.lower(visible):find(target, 1, true)
            if first then
                local at = i + first - 1
                local matchEnd = i + last - 1
                return formatted:sub(1, at - 1) .. color(formatted:sub(at, matchEnd), hex)
                    .. formatted:sub(matchEnd + 1)
            end
        end
        if not pipe or pipe > max then
            break
        end
        i = pipe
        local tag = formatted:sub(i, i + 1)
        if tag == "|H" then
            local headerEnd = formatted:find("|h", i + 2, true)
            local linkEnd = headerEnd and formatted:find("|h", headerEnd + 2, true)
            if linkEnd then
                local caption = formatted:sub(headerEnd + 2, linkEnd - 1)
                if string.lower(caption):find(target, 1, true) and linkEnd < max then
                    return formatted:sub(1, i - 1)
                        .. color(formatted:sub(i, linkEnd + 1), hex)
                        .. formatted:sub(linkEnd + 2)
                end
                i = linkEnd + 2
            else
                i = i + 1
            end
        elseif tag == "|c" and formatted:sub(i + 2, i + 7):match("^%x%x%x%x%x%x$") then
            i = i + 8
        elseif tag == "|r" or tag == "||" then
            i = i + 2
        elseif tag == "|t" or tag == "|T" then
            local textureEnd = formatted:find(tag, i + 2, true)
            i = textureEnd and textureEnd + 2 or i + 1
        else
            i = i + 1
        end
    end
    return nil
end

-- Returns formatted output without modifying channel metadata, sender ID,
-- narration, or other addons' return values. A body changed by another addon
-- may not be found verbatim; in that case its content is left untouched.
function Markup.Format(formatted, rawText, fromName, fromDisplayName, hex, mode,
                       highlightMentions, mentionEntries)
    if type(formatted) ~= "string" or type(hex) ~= "string" then
        return formatted
    end

    local bodyPosition = findBody(formatted, rawText)
    if mode == "author" or mode == "both" then
        local recolored = colorAuthor(formatted, fromName, hex, bodyPosition)
            or colorAuthor(formatted, fromDisplayName, hex, bodyPosition)
        formatted = recolored or formatted
        bodyPosition = findBody(formatted, rawText)
    end

    if not bodyPosition then
        return formatted
    end
    local baseColor = (mode == "body" or mode == "both") and hex or nil
    if not baseColor and not highlightMentions then
        return formatted
    end

    local body = rawText
    if highlightMentions and mentionEntries and #mentionEntries > 0 then
        body = highlightPlainText(body, baseColor, mentionEntries)
    end
    if baseColor then
        body = color(body, baseColor)
    end

    return formatted:sub(1, bodyPosition - 1) .. body
        .. formatted:sub(bodyPosition + #rawText)
end
