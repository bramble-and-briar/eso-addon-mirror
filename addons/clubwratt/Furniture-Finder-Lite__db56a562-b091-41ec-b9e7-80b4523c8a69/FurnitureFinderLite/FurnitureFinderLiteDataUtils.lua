-- FurnitureFinderLiteDataUtils.lua: pure readers of the packed data (no game calls).
--
-- Nothing is unpacked ahead of time: a lookup finds the block by its first id, cuts the
-- furnishing's line out of the block string and splits it into tokens. The few small tables that
-- makes are garbage as soon as the tooltip has its lines.
local FFL = FurnitureFinderLite

local DataUtils = {}

---The block a furnishing id falls in: the last one whose first id is not above it.
---@param first integer[] first furnishing id of each block, ascending
---@param itemId integer
---@return integer|nil blockIndex nil when the id is below every block
function DataUtils.BlockIndex(first, itemId)
    local low, high, found = 1, #first, nil
    while low <= high do
        local middle = math.floor((low + high) / 2)
        if first[middle] <= itemId then
            found = middle
            low = middle + 1
        else
            high = middle - 1
        end
    end
    return found
end

---The packed sources of a furnishing.
---@param data FurnitureFinderLiteData|nil
---@param itemId integer|nil
---@return string|nil line "record;record", nil when the furnishing is not in the data
function DataUtils.Line(data, itemId)
    if type(data) ~= "table" or type(itemId) ~= "number" then
        return nil
    end
    local blockIndex = DataUtils.BlockIndex(data.first, itemId)
    local block = blockIndex and data.blocks[blockIndex]
    if not block then
        return nil
    end
    local _, keyEnd = string.find(block, "\n" .. itemId .. "=", 1, true)
    if not keyEnd then
        return nil
    end
    local lineEnd = string.find(block, "\n", keyEnd + 1, true)
    return string.sub(block, keyEnd + 1, (lineEnd or (#block + 1)) - 1)
end

---Split a packed line into its sources and their tokens.
---@param line string "record;record", a record being "token,token", a token a letter and a value
---@return FurnitureFinderLiteRecord[]
function DataUtils.Parse(line)
    local records = {}
    for recordText in string.gmatch(line, "[^;]+") do
        local record = {}
        for token in string.gmatch(recordText, "[^,]+") do
            record[#record + 1] = { string.sub(token, 1, 1), string.sub(token, 2) }
        end
        records[#records + 1] = record
    end
    return records
end

---The sources of a furnishing, unpacked.
---@param data FurnitureFinderLiteData|nil
---@param itemId integer|nil
---@return FurnitureFinderLiteRecord[]|nil records nil when the furnishing is not in the data
function DataUtils.Records(data, itemId)
    local line = DataUtils.Line(data, itemId)
    if not line then
        return nil
    end
    return DataUtils.Parse(line)
end

FFL.DataUtils = DataUtils
