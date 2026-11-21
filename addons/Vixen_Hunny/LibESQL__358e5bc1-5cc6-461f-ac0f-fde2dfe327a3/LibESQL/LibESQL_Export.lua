-- LibESQL MySQL export: turns a query result into a phpMyAdmin-style SQL dump
-- (CREATE TABLE + INSERT statements, utf8mb4, InnoDB). The same rules are used
-- by ESQL/tools/esql_to_mysql.py, which builds a dump from SavedVariables.

local E = LibESQL
local SQL = E.SQL
local format, floor = string.format, math.floor

local INT32 = 2147483647

-- MySQL identifier: `name`, backticks doubled
local function ident(name)
    return "`" .. tostring(name):gsub("`", "``") .. "`"
end

-- a safe table name: letters, digits and _ only
function E.MySQLTableName(name)
    local n = tostring(name or ""):lower():gsub("[^%w_]", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
    if n == "" then n = "esql_export" end
    if n:find("^%d") then n = "t_" .. n end
    return n:sub(1, 64)
end

local ESCAPES = { ["\\"] = "\\\\", ["'"] = "\\'", ["\0"] = "\\0", ["\n"] = "\\n", ["\r"] = "\\r", ["\26"] = "\\Z" }

-- MySQL literal for one value
function E.MySQLValue(v)
    if v == nil then return "NULL" end
    if v == true then return "1" end
    if v == false then return "0" end
    local tv = type(v)
    if tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "NULL" end
        -- %.0f, not %d: %d is 32-bit in some Lua builds (2^40 would print as -2147483648)
        if v == floor(v) and math.abs(v) < 2 ^ 53 then return v == 0 and "0" or format("%.0f", v) end
        return format("%.17g", v)
    end
    return "'" .. tostring(v):gsub("[\\'%z\n\r\26]", ESCAPES) .. "'"
end

-- MySQL column type for a column's values (declared: int|num|text|bool|any)
function E.MySQLColumnType(values, declared)
    if declared == "int" then return "bigint(20)" end
    if declared == "num" then return "double" end
    if declared == "bool" then return "tinyint(1)" end
    local allBool, allInt, allNum, any = true, true, true, false
    local maxLen, bigInt = 0, false
    for _, v in pairs(values) do
        any = true
        local tv = type(v)
        if tv ~= "boolean" then allBool = false end
        if tv == "number" then
            if v ~= floor(v) then allInt = false elseif math.abs(v) > INT32 then bigInt = true end
        else
            allInt, allNum = false, false
        end
        local len = #(tv == "string" and v or tostring(v))
        if len > maxLen then maxLen = len end
    end
    if declared ~= "text" and any then
        if allBool then return "tinyint(1)" end
        if allInt then return bigInt and "bigint(20)" or "int(11)" end
        if allNum then return "double" end
    end
    if maxLen <= 255 then return "varchar(255)" end
    if maxLen <= 65535 then return "text" end
    return "mediumtext"
end

local HEADER = {
    "-- MySQL dump made by LibESQL (Elder Scrolls Online), phpMyAdmin compatible",
    "-- Import it in phpMyAdmin: select a database, then Import > choose this file > Go.",
    "",
    'SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";',
    "START TRANSACTION;",
    'SET time_zone = "+00:00";',
    "SET NAMES utf8mb4;",
    "",
}

--[[
    LibESQL.ToMySQL(result, tableName, opts) -> dumpText, blocks
    result     a query result ({ columns, rows })
    tableName  MySQL table name (made safe with MySQLTableName)
    opts       (all optional)
      types            { "int"|"num"|"text"|"bool"|"any", ... } per column; nil infers from the values
      header           true: SET / START TRANSACTION before and COMMIT after (default true)
      dropTable        true: DROP TABLE IF EXISTS before CREATE TABLE (default true)
      rowsPerInsert    rows per INSERT statement (default 500)
      maxInsertBytes   start a new INSERT before one grows past this (default 1000000)
      comment          extra comment line above the table
    blocks: { { text = "...", first = row, last = row }, ... } whole statements,
    for splitting the dump into pages without cutting a statement in half.
]]
function E.ToMySQL(res, tableName, opts)
    opts = opts or {}
    local name = E.MySQLTableName(tableName)
    local cols = res.columns
    local ncol = #cols
    local rowsPerInsert = opts.rowsPerInsert or 500
    local maxBytes = opts.maxInsertBytes or 1000000
    local blocks = {}
    local function block(text, first, last) blocks[#blocks + 1] = { text = text, first = first, last = last } end

    -- unique, safe column names
    local colNames, used = {}, {}
    for c = 1, ncol do
        local base = tostring(cols[c]):gsub("^.*%.", "")
        if base == "" then base = "col" .. c end
        local n, k = base, 1
        while used[n:lower()] do k = k + 1; n = base .. "_" .. k end
        used[n:lower()] = true
        colNames[c] = n
    end

    if opts.header ~= false then block(table.concat(HEADER, "\n")) end

    -- structure
    local defs = {}
    for c = 1, ncol do
        local values = {}
        for r = 1, #res.rows do
            local v = res.rows[r][c]
            if v ~= nil then values[#values + 1] = v end
            if r % 2000 == 0 then E.Tick() end
        end
        local declared = opts.types and opts.types[c]
        defs[c] = "  " .. ident(colNames[c]) .. " " .. E.MySQLColumnType(values, declared) .. " DEFAULT NULL"
    end
    local structure = {
        "-- --------------------------------------------------------",
        "",
        "--",
        "-- Table structure for table " .. ident(name),
        "--",
    }
    if opts.comment then structure[#structure + 1] = "-- " .. tostring(opts.comment):gsub("[\r\n]+", " ") end
    structure[#structure + 1] = ""
    if opts.dropTable ~= false then structure[#structure + 1] = "DROP TABLE IF EXISTS " .. ident(name) .. ";" end
    structure[#structure + 1] = "CREATE TABLE " .. ident(name) .. " (\n" .. table.concat(defs, ",\n") ..
        "\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
    block(table.concat(structure, "\n"))

    -- data
    if #res.rows > 0 then
        -- the "Dumping data" comment travels with the first INSERT, so a page
        -- never ends on it
        local dataComment = "--\n-- Dumping data for table " .. ident(name) .. "\n--\n\n"
        local quoted = {}
        for c = 1, ncol do quoted[c] = ident(colNames[c]) end
        local head = "INSERT INTO " .. ident(name) .. " (" .. table.concat(quoted, ", ") .. ") VALUES\n"
        local tuples, bytes, first = {}, #head, 1
        local function flush(last)
            if #tuples > 0 then
                block(dataComment .. head .. table.concat(tuples, ",\n") .. ";", first, last)
                dataComment = ""
                tuples, bytes, first = {}, #head, last + 1
            end
        end
        for r = 1, #res.rows do
            E.Tick()
            local row = res.rows[r]
            local vals = {}
            for c = 1, ncol do vals[c] = E.MySQLValue(row[c]) end
            local tuple = "(" .. table.concat(vals, ", ") .. ")"
            if #tuples > 0 and (#tuples >= rowsPerInsert or bytes + #tuple + 2 > maxBytes) then flush(r - 1) end
            tuples[#tuples + 1] = tuple
            bytes = bytes + #tuple + 2
        end
        flush(#res.rows)
    end

    if opts.header ~= false then block("COMMIT;") end

    local parts = {}
    for i, b in ipairs(blocks) do parts[i] = b.text end
    return table.concat(parts, "\n\n") .. "\n", blocks
end
