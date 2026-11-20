-- Tables about the database and the game API itself:
-- tables, columns, constants, events, strings, functions, sounds.

local E = LibESQL
local Tick = E.Tick

E.RegisterTable({
    name = "tables",
    desc = "Every table you can query",
    key = "name",
    live = true,
    columns = {
        { "name", "text", "Table name" },
        { "kind", "text", "static (cached), live (read every query), scan (id index), user (yours)" },
        { "description", "text", "What is in it" },
        { "num_columns", "int", "Column count" },
        { "key", "text", "Primary key column" },
        { "rows_cached", "int", "Rows in memory or ids indexed (NULL until first use)" },
    },
    build = function(rows)
        for _, name in ipairs(E.tableOrder) do
            local def = E.tables[name]
            if def then
                local cached
                if def.kind == "scan" then cached = def.count
                elseif def.rows then cached = #def.rows
                elseif def.cache then cached = #def.cache end
                rows[#rows + 1] = {
                    name = name, kind = def.kind, description = def.desc,
                    num_columns = #def.columns, key = def.key, rows_cached = cached,
                }
            end
        end
    end,
})

E.RegisterTable({
    name = "columns",
    desc = "Every column of every table",
    live = true,
    columns = {
        { "table_name", "text", "Table" },
        { "column_name", "text", "Column" },
        { "position", "int", "Column order" },
        { "type", "text", "int, num, text, bool" },
        { "description", "text", "Meaning" },
        { "lazy", "bool", "Computed when read" },
    },
    build = function(rows)
        for _, name in ipairs(E.tableOrder) do
            local def = E.tables[name]
            if def then
                for _, c in ipairs(def.columns) do
                    rows[#rows + 1] = {
                        table_name = name, column_name = c.name, position = c.position,
                        type = c.type, description = c.desc, lazy = c.get ~= nil,
                    }
                end
            end
        end
    end,
})

-- One pass over _G without yielding (other add-ons may add globals while we
-- are suspended, which would break `next`).
local function snapshotGlobals(filter)
    local out = {}
    for k, v in E.GlobalPairs() do
        if type(k) == "string" and filter(k, v) then out[#out + 1] = { k, v } end
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end

local function family(name)
    -- ACTION_RESULT_DAMAGE -> ACTION_RESULT ; single word -> itself
    return name:match("^(.+)_[^_]+$") or name
end

E.RegisterTable({
    name = "constants",
    desc = "Every numeric game constant (enums, flags, limits) except SI_ string ids",
    key = "name",
    columns = {
        { "name", "text", "Constant name" },
        { "value", "num", "Value" },
        { "family", "text", "Name without its last word (ACTION_RESULT_DAMAGE -> ACTION_RESULT)" },
    },
    build = function(rows)
        local list = snapshotGlobals(function(k, v)
            return type(v) == "number" and k:find("^[A-Z][A-Z0-9_]*$") ~= nil and k:sub(1, 3) ~= "SI_"
        end)
        for _, kv in ipairs(list) do
            Tick()
            rows[#rows + 1] = { name = kv[1], value = kv[2], family = family(kv[1]) }
        end
    end,
})

E.RegisterTable({
    name = "events",
    desc = "Every EVENT_* id",
    key = "name",
    columns = { { "name", "text", "Event name" }, { "id", "int", "Event id" } },
    build = function(rows)
        local list = snapshotGlobals(function(k, v) return type(v) == "number" and k:sub(1, 6) == "EVENT_" end)
        for _, kv in ipairs(list) do
            Tick()
            rows[#rows + 1] = { name = kv[1], id = kv[2] }
        end
    end,
})

E.RegisterTable({
    name = "strings",
    desc = "Every localized string (SI_* ids) in your game language",
    key = "name",
    columns = {
        { "name", "text", "String id name" },
        { "id", "int", "String id" },
        { "text", "text", "Localized text", function(r) return GetString(r.id) end },
    },
    build = function(rows)
        local list = snapshotGlobals(function(k, v) return type(v) == "number" and k:sub(1, 3) == "SI_" end)
        for _, kv in ipairs(list) do
            Tick()
            rows[#rows + 1] = { name = kv[1], id = kv[2] }
        end
    end,
})

E.RegisterTable({
    name = "functions",
    desc = "Every global function (game API and add-on functions)",
    key = "name",
    columns = {
        { "name", "text", "Function name" },
        { "kind", "text", "api (from the game, PascalCase) or lua (other)" },
    },
    build = function(rows)
        local list = snapshotGlobals(function(_, v) return type(v) == "function" end)
        for _, kv in ipairs(list) do
            Tick()
            local name = kv[1]
            rows[#rows + 1] = { name = name, kind = name:find("^[A-Z]") and not name:find("^ZO_") and "api" or "lua" }
        end
    end,
})

E.RegisterTable({
    name = "sounds",
    desc = "Every entry in the SOUNDS table (PlaySound names)",
    key = "name",
    columns = { { "name", "text", "SOUNDS key" }, { "value", "text", "Sound id" } },
    build = function(rows)
        if type(SOUNDS) ~= "table" then return end
        local list = {}
        for k, v in pairs(SOUNDS) do list[#list + 1] = { tostring(k), tostring(v) } end
        table.sort(list, function(a, b) return a[1] < b[1] end)
        for _, kv in ipairs(list) do
            Tick()
            rows[#rows + 1] = { name = kv[1], value = kv[2] }
        end
    end,
})
