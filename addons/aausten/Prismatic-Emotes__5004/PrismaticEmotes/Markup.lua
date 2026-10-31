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

-- First-name aliases must not match fragments of apostrophized or hyphenated names.
local function isJoinedName(segment, first, last)
    local before, after = segment:byte(first - 1), segment:byte(last + 1)
    return ((before == 39 or before == 45) and isWordByte(segment:byte(first - 2)))
        or ((after == 39 or after == 45) and isWordByte(segment:byte(last + 2)))
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
                not isWordByte(segment:byte(last + 1)) and
                not (entry.firstName and isJoinedName(segment, first, last)) then
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

local function tokenEnd(text, index)
    local tag = text:sub(index, index + 1)
    local finish, headerEnd
    if tag == "|H" then
        headerEnd = text:find("|h", index + 2, true)
        finish = headerEnd and text:find("|h", headerEnd + 2, true)
        if finish then finish = finish + 1 end
    elseif tag == "|t" or tag == "|T" then
        finish = text:find(tag, index + 2, true)
        if finish then finish = finish + 1 end
    elseif tag == "|c" and text:sub(index + 2, index + 7):match("^%x%x%x%x%x%x$") then
        finish = index + 7
    elseif tag == "|r" or tag == "||" then
        finish = index + 1
    end
    return finish or index, tag, headerEnd, finish ~= nil
end

local function highlightSegment(segment, baseHex, entries, offset, spans)
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
        if spans then
            spans[#spans + 1] = { first = offset + first, last = offset + last, color = mentionColor }
        end
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
---@param spans? table[]
local function highlightPlainText(text, baseHex, entries, spans)
    local out = {}
    local i, length = 1, #text
    while i <= length do
        local pipe = text:find("|", i, true)
        if not pipe then
            out[#out + 1] = highlightSegment(text:sub(i), baseHex, entries, i - 1, spans)
            break
        end
        if pipe > i then
            out[#out + 1] = highlightSegment(text:sub(i, pipe - 1), baseHex, entries, i - 1, spans)
            i = pipe
        else
            local finish = tokenEnd(text, i)
            out[#out + 1] = text:sub(i, finish)
            i = finish + 1
        end
    end
    return table.concat(out)
end

-- pChat's copy links reference a stored row. Their captions may be split into
-- smaller links with the same header, but color tags must stay outside them.
local function projectBody(formatted)
    local parts, projected = {}, {}
    local index, length, offset = 1, #formatted, 0
    local activeColor
    while index <= length do
        local pipe = formatted:find("|", index, true)
        local finish, tag, headerEnd, complete
        if not pipe or pipe > index then
            finish = pipe and pipe - 1 or length
        else
            finish, tag, headerEnd, complete = tokenEnd(formatted, index)
        end
        local invalid = (tag == "|H" or tag == "|t" or tag == "|T") and not complete
        if invalid then finish = length end
        local text = formatted:sub(index, finish)
        local copyHeader
        if tag == "|H" and complete then
            local header = formatted:sub(index, headerEnd + 1)
            local row, channel = header:match("^|H1:p:(%d+):(%d+)|h$")
            local caption = formatted:sub(headerEnd + 2, finish - 2)
            -- URL links (channel 97) use their caption as the URL itself.
            if row and tonumber(channel) ~= 97 and caption ~= "" and not caption:find("|", 1, true) then
                copyHeader, text = header, caption
            end
        end
        local before = activeColor
        local isColor = complete and (tag == "|c" or tag == "|r")
        if isColor then
            activeColor = tag == "|c" and text:sub(3) or nil
        end
        parts[#parts + 1] = {
            first = offset + 1, last = offset + #text,
            sourceFirst = index, sourceLast = finish, text = text,
            copyHeader = copyHeader, protected = tag ~= nil and not copyHeader,
            invalid = invalid, isColor = isColor, color = before, afterColor = activeColor,
        }
        projected[#projected + 1] = text
        offset, index = offset + #text, finish + 1
    end
    return table.concat(projected), parts
end

local function findBody(formatted, rawText)
    if type(rawText) ~= "string" or rawText == "" then
        return nil
    end
    local projected, parts = projectBody(formatted)
    local start, found = 1, nil
    while true do
        local position = projected:find(rawText, start, true)
        if not position then break end
        local last = position + #rawText - 1
        local firstPart, lastPart, hasCopies
        local valid = true
        -- Never fall back to an earlier prefix match if the last occurrence is unsafe.
        found = nil
        for _, part in ipairs(parts) do
            if part.last >= position and part.first <= last then
                if part.invalid or ((part.copyHeader or part.protected)
                    and (position > part.first or last < part.last)) then
                    valid = false
                    break
                end
                firstPart, lastPart = firstPart or part, part
                hasCopies = hasCopies or part.copyHeader ~= nil
            end
        end
        if valid and firstPart and lastPart then
            found = {
                first = firstPart.copyHeader and firstPart.sourceFirst
                    or firstPart.sourceFirst + position - firstPart.first,
                last = lastPart.copyHeader and lastPart.sourceLast
                    or lastPart.sourceFirst + last - lastPart.first,
                viewFirst = position, viewLast = last, parts = parts, hasCopies = hasCopies,
                color = firstPart.color, endColor = lastPart.afterColor,
            }
        end
        start = position + 1
    end
    return found
end

local function restoreColor(hex)
    return hex and ("|c" .. hex) or "|r"
end

local function formatCopyBody(location, baseHex, spans)
    local out = {}
    local currentColor = baseHex or location.color
    if baseHex then out[#out + 1] = "|c" .. baseHex end
    for _, part in ipairs(location.parts) do
        local first, last = math.max(part.first, location.viewFirst), math.min(part.last, location.viewLast)
        if first <= last then
            if part.protected then
                out[#out + 1] = part.text:sub(first - part.first + 1, last - part.first + 1)
                if part.isColor then currentColor = part.afterColor end
            else
                local function appendText(from, to)
                    if from <= to then
                        local text = part.text:sub(from - part.first + 1, to - part.first + 1)
                        out[#out + 1] = part.copyHeader and (part.copyHeader .. text .. "|h") or text
                    end
                end
                local cursor = first
                for _, span in ipairs(spans) do
                    local spanFirst = math.max(first, location.viewFirst + span.first - 1)
                    local spanLast = math.min(last, location.viewFirst + span.last - 1)
                    if spanFirst <= spanLast and span.color ~= currentColor then
                        appendText(cursor, spanFirst - 1)
                        out[#out + 1] = "|c" .. span.color
                        appendText(spanFirst, spanLast)
                        out[#out + 1] = restoreColor(currentColor)
                        cursor = spanLast + 1
                    end
                end
                appendText(cursor, last)
            end
        end
    end
    if baseHex then out[#out + 1] = restoreColor(location.endColor) end
    return table.concat(out)
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
                local copyLink = formatted:sub(i, headerEnd + 1):match("^|H%d+:p:")
                if not copyLink and string.lower(caption):find(target, 1, true) and linkEnd < max then
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
-- narration, or other addons' return values. Copy-link wrappers are projected
-- out for body matching; other rewrites are left untouched if no safe match exists.
function Markup.Format(formatted, rawText, fromName, fromDisplayName, hex, mode,
                       highlightMentions, mentionEntries)
    if type(formatted) ~= "string" or type(hex) ~= "string" then
        return formatted
    end

    local location = findBody(formatted, rawText)
    if mode == "author" or mode == "both" then
        local limit = location and location.first
        local recolored = colorAuthor(formatted, fromName, hex, limit)
            or colorAuthor(formatted, fromDisplayName, hex, limit)
        formatted = recolored or formatted
        location = findBody(formatted, rawText)
    end

    if not location then
        return formatted
    end
    local baseColor = (mode == "body" or mode == "both") and hex or nil
    if not baseColor and not highlightMentions then
        return formatted
    end

    local body = rawText
    if location.hasCopies then
        local spans = {}
        if highlightMentions and mentionEntries and #mentionEntries > 0 then
            highlightPlainText(rawText, nil, mentionEntries, spans)
        end
        body = formatCopyBody(location, baseColor, spans)
    else
        if highlightMentions and mentionEntries and #mentionEntries > 0 then
            body = highlightPlainText(body, baseColor or location.color, mentionEntries)
        end
        if baseColor then body = color(body, baseColor) end
    end

    return formatted:sub(1, location.first - 1) .. body .. formatted:sub(location.last + 1)
end
