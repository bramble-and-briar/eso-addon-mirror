-- GuildNameTickerTextUtils.lua: Pure helpers that split the user's message
-- into guild-name-sized chunks. No game API access, no side effects.

local GuildNameTickerTextUtils = {}

---@param message string
---@return string[] words
function GuildNameTickerTextUtils.SplitWords(message)
    local words = {}
    for word in string.gmatch(message or "", "%S+") do
        table.insert(words, word)
    end
    return words
end

---Split a single over-long word into maxLen-sized pieces.
---Byte-based; multi-byte (non-ASCII) text may split one character short of
---the limit's intent, which is harmless for display purposes.
---@param word string
---@param maxLen integer
---@return string[] pieces
function GuildNameTickerTextUtils.HardSplit(word, maxLen)
    local pieces = {}
    local index = 1
    while index <= #word do
        table.insert(pieces, string.sub(word, index, index + maxLen - 1))
        index = index + maxLen
    end
    return pieces
end

---Build the ordered list of guild names to cycle through.
---packWords=false: one word per name. packWords=true: greedily join words
---with spaces while they fit within maxLen.
---@param message string
---@param maxLen integer
---@param packWords boolean
---@return string[] chunks
function GuildNameTickerTextUtils.BuildChunks(message, maxLen, packWords)
    local words = GuildNameTickerTextUtils.SplitWords(message)
    local chunks = {}

    local function AddWordPieces(word)
        for _, piece in ipairs(GuildNameTickerTextUtils.HardSplit(word, maxLen)) do
            table.insert(chunks, piece)
        end
    end

    if not packWords then
        for _, word in ipairs(words) do
            AddWordPieces(word)
        end
        return chunks
    end

    local current = ""
    for _, word in ipairs(words) do
        if #word > maxLen then
            if current ~= "" then
                table.insert(chunks, current)
                current = ""
            end
            AddWordPieces(word)
        elseif current == "" then
            current = word
        elseif #current + 1 + #word <= maxLen then
            current = current .. " " .. word
        else
            table.insert(chunks, current)
            current = word
        end
    end
    if current ~= "" then
        table.insert(chunks, current)
    end
    return chunks
end

GuildNameTicker.TextUtils = GuildNameTickerTextUtils
