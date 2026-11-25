-- varint.lua: unsigned LEB128 varints and delta encoding (pure Lua 5.1, arithmetic only).

CompanionExport = CompanionExport or {}

local Varint = {}
CompanionExport.Varint = Varint

local floor = math.floor

--- Append the LEB128 encoding of a non-negative integer to buf (array of bytes).
function Varint.write(buf, value)
    assert(type(value) == "number" and value >= 0 and value == floor(value),
        "varint: non-negative integer required")
    repeat
        local b = value % 128
        value = floor(value / 128)
        if value > 0 then
            b = b + 128
        end
        buf[#buf + 1] = b
    until value == 0
end

--- Append a list of (id, qty) pairs sorted by id: count, then (id - previousId, qty) per pair.
--- `counts` maps itemId -> quantity. Pairs with qty <= 0 are skipped.
function Varint.writeIdQtyMap(buf, counts)
    local ids = {}
    for id, qty in pairs(counts) do
        if qty > 0 then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    Varint.write(buf, #ids)
    local prev = 0
    for _, id in ipairs(ids) do
        Varint.write(buf, id - prev)
        Varint.write(buf, counts[id])
        prev = id
    end
end
