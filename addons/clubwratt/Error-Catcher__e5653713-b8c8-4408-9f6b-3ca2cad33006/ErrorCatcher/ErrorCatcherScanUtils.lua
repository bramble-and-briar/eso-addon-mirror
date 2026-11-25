-- ErrorCatcherScanUtils.lua: which globals the scan reads, and wording its result (pure)
local ScanUtils = {}

local GAME_PREFIX = "ZO_"

---A global function of the game's UI code. Add-on globals are untrusted by nature, so only the game's
---own prefix is read.
---@param name string
---@return boolean
function ScanUtils.IsGameFunctionName(name)
    return string.sub(name, 1, 3) == GAME_PREFIX
end

---A global table that may be the game's: a class (ZO_ prefix) or a singleton (ALL_CAPS).
---@param name string
---@return boolean
function ScanUtils.IsGameTableName(name)
    return string.sub(name, 1, 3) == GAME_PREFIX or string.match(name, "^[A-Z][A-Z0-9_][A-Z0-9_]+$") ~= nil
end

-- Game tables add-ons put functions of their own into as a matter of course: every slash command of every
-- add-on is an untrusted member of SLASH_COMMANDS, and says nothing about a game function.
local REGISTRY_TABLES = {
    SLASH_COMMANDS = true,
}

---@param name string
---@return boolean
function ScanUtils.IsRegistryTableName(name)
    return REGISTRY_TABLES[name] == true
end

---Whether a table's untrusted members are worth listing, going by its own members: a table with trusted
---functions too is the game's with something replaced; an ALL_CAPS table without any is an add-on's own,
---unless it is an instance of a game class, which the caller asks of the game.
---@param name string
---@param trustedCount number
---@return boolean
function ScanUtils.IsGameTable(name, trustedCount)
    return trustedCount > 0 or string.sub(name, 1, 3) == GAME_PREFIX
end

---Names joined into lines of a readable width, each line starting with the title.
---@param title string
---@param names string[]
---@param maxChars number
---@return string[] lines
function ScanUtils.Pack(title, names, maxChars)
    local lines = {}
    local current = nil
    for _, name in ipairs(names) do
        if current and #current + #name + 2 <= maxChars then
            current = current .. ", " .. name
        else
            if current then
                lines[#lines + 1] = current
            end
            current = title .. ": " .. name
        end
    end
    if current then
        lines[#lines + 1] = current
    end
    return lines
end

---@param names string[]
---@return string[] unique Sorted, each name once
function ScanUtils.SortedUnique(names)
    local unique, seen = {}, {}
    for _, name in ipairs(names) do
        if not seen[name] then
            seen[name] = true
            unique[#unique + 1] = name
        end
    end
    table.sort(unique)
    return unique
end

---A short fingerprint of the lines, to tell one UI load's result from the last.
---@param lines string[]
---@return string
function ScanUtils.Digest(lines)
    local hash = 5381
    for _, line in ipairs(lines) do
        for index = 1, #line do
            hash = (hash * 33 + string.byte(line, index)) % 2147483647
        end
        hash = (hash * 33 + 10) % 2147483647
    end
    return string.format("%d:%d", #lines, hash)
end

ErrorCatcher.ScanUtils = ScanUtils
