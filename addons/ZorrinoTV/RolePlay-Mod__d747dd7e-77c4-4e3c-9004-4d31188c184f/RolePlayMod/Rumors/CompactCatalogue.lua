-- Packed records share a field layout. Keep the catalogues readable through
-- their existing named fields without a hash table in every record.
local B = IHR_Runtime.Beta
local C = {}
B.CompactCatalogue = C

function C.Schema(fields)
    local slots = {}
    for slot, field in ipairs(fields) do slots[field] = slot end
    return {__index=function(record, field)
        local slot = slots[field]
        if slot then return rawget(record, slot) end
    end}
end

-- Most keys point to a single record. Allocate a list only for homonyms.
local multiple = {}
function C.Add(index, key, record)
    local previous = index[key]
    if previous == nil then
        index[key] = record
    elseif getmetatable(previous) == multiple then
        previous[#previous+1] = record
    else
        index[key] = setmetatable({previous, record}, multiple)
    end
end

local function once(record, position)
    if position == 0 and record ~= nil then return 1, record end
end
function C.Records(value)
    if getmetatable(value) == multiple then return ipairs(value) end
    return once, value, 0
end
