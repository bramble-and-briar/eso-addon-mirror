# LibESQL

An Elder Scrolls Online library that lets add-ons query game data with SQL. It works on PC/Mac and on console (PS5/Xbox).

```lua
local res = LibESQL.Query("SELECT id, name, duration_ms FROM abilities WHERE id = ?", { params = { 46340 } })
```

It has about 48 tables: every ability id, skills and morphs, champion stars, scribing, live buffs and debuffs, every set with its bonuses and pieces, every item id, your inventory, achievements, collectibles, quests, zones, POIs, wayshrines, dungeons, the game's constants, strings and functions, and more. `SHOW TABLES` and `DESCRIBE <table>` list them all.

The **ESQL** add-on is the window and console panel built on this library. You don't need it to use LibESQL.

## Documentation

[API Reference](API%20Reference.md) covers every function with its arguments, returns, and `nil`/`false` cases. It also covers the data structures, the full SQL dialect, every scalar function, performance notes, and all 49 tables with every column.

## Examples

[LibESQL-Examples](../LibESQL-Examples/README.md) has ten ready-to-install example add-ons:
- query basics
- ability lookup
- set search
- buff watcher
- combat summary
- your own table
- your own function
- scan progress
- collection report
- a console settings panel

## Install

Copy the `LibESQL` folder into `Documents/Elder Scrolls Online/live/AddOns/` and add it to your manifest:

```
## DependsOn: LibESQL>=10000
```

No other libraries are needed.

## Quick start

```lua
-- Rows as objects
for _, s in ipairs(LibESQL.Select("SELECT name, set_type FROM sets WHERE name LIKE ?", { "%mother%" })) do
    d(s.name .. " (" .. s.set_type .. ")")
end

-- One value
local n = LibESQL.Scalar("SELECT COUNT(*) FROM achievements WHERE completed")

-- Big queries in the background, spread over frames (no hitching)
LibESQL.QueryAsync("SELECT id, name FROM abilities WHERE name LIKE '%rune%'", function(res, err)
    if not res then d(err) return end
    d(#res.rows .. " abilities")
end)
```

## Functions

| Function | Returns |
|---|---|
| `LibESQL.Query(sql, opts?)` | `result` or `nil, errorText`. Runs now. |
| `LibESQL.QueryAsync(sql, callback, opts?)` | A job handle. Later calls `callback(result)` or `callback(nil, errorText)`. |
| `LibESQL.Select(sql, params?)` | An array of row objects keyed by column name, or `nil, errorText`. |
| `LibESQL.Scalar(sql, params?)` | The first column of the first row, or `nil` (`nil, errorText` on error). |
| `LibESQL.ToObjects(result)` | The rows of a result as objects. |
| `LibESQL.Quote(value)` | The value as an SQL literal: `Kinras's` becomes `'Kinras''s'`, `nil` becomes `NULL`. |
| `LibESQL.Validate(sql)` | `true`, or `false, errorText`. Parses the SQL without running it. |
| `LibESQL.RegisterTable(def)` | Adds your own table (see below). |
| `LibESQL.RegisterFunction(name, fn)` | Adds an SQL function. |
| `LibESQL.GetTableNames()` | Every table name. |
| `LibESQL.GetColumns(table)` | `{ {name, type, description, lazy}, ... }`, or `nil` if there is no such table. |
| `LibESQL.Refresh(table?)` | Drops cached rows so the next query rebuilds them. Leave out the table to refresh all of them. |
| `LibESQL.Scan(table, callback?, force?)` | Builds the id index of `abilities` or `items` in the background, then calls `callback(count)`. |
| `LibESQL.IsScanned(table)` | `true, count` once the index exists for the current API version. |
| `LibESQL.SetEffectTracking(bool)` / `IsEffectTracking()` | Records every buff/debuff id you see into `effects_seen`. This is saved. |
| `LibESQL.SetCombatLogging(bool)` / `IsCombatLogging()` / `ClearCombatLog()` | Keeps combat events in memory for `combat_log`. |
| `LibESQL.RegisterCallback(event, fn)` / `UnregisterCallback(event, fn)` | Subscribes to an event (listed below). |
| `LibESQL.CancelJobs()` | Stops every background job. |

**`result`** is `{ columns = { "id", "name" }, rows = { { 46340, "Molten Whip" }, ... }, truncated, elapsedMs, message }`. A `NULL` is a `nil` inside a row.

**`opts`** can hold:
- `params`: values for the `?` placeholders, in order. To bind a `NULL` as the last value, set `n = count`.
- `maxRows`: the most rows to return. When it cuts the result, `truncated` is set.

Use `params` instead of building SQL strings from player input.

### Sync or async

`Query` runs everything in the current frame. That is fine for most tables. The first query on `abilities` or `items` has to scan every id (300k to 600k checks). Do that first query through `QueryAsync` or `Scan`. After it, the id list is saved per game update in `LibESQL_SV`, and later queries start at once.

A lookup by primary key, such as `WHERE id = 123` or `WHERE id IN (1, 2, 3)`, never needs the scan.

### Callbacks

| Event | Arguments |
|---|---|
| `Loaded` | none (fires once the SavedVariables are ready) |
| `ScanProgress` | `tableName, fraction (0-1), idsFound` |
| `ScanDone` | `tableName, count` |
| `UserTableCreated` | `name` |
| `UserTableDropped` | `name` |

## Your own tables

```lua
LibESQL.RegisterTable({
    name = "my_parses",
    desc = "Saved parses from MyAddon",
    key = "id",                 -- optional: makes WHERE id = x fast
    live = true,                -- rebuild every query (omit to cache rows until Refresh)
    columns = {
        { "id", "int", "Parse id" },
        { "boss", "text", "Boss name" },
        { "dps", "int", "Damage per second" },
        -- a 4th entry makes the column lazy: computed only when a query reads it
        { "boss_upper", "text", "Upper-case boss", function(row) return row.boss:upper() end },
    },
    build = function(rows)
        for i, p in ipairs(MyAddon.saved.parses) do
            LibESQL.Tick()      -- lets long builds spread over frames
            rows[#rows + 1] = { id = i, boss = p.boss, dps = p.dps }
        end
    end,
})

LibESQL.Query("SELECT boss, MAX(dps) FROM my_parses GROUP BY boss ORDER BY 2 DESC")
```

- Row keys are the lower-case column names.
- Column types are `int`, `num`, `text` and `bool`.
- Inside `build`, call `LibESQL.Tick()` in loops. Don't call it inside `pcall`, a metamethod or a `table.sort` comparator.

## Your own SQL functions

```lua
LibESQL.RegisterFunction("SECONDS", function(ms) return ms and ms / 1000 end)
LibESQL.Query("SELECT name, SECONDS(duration_ms) FROM abilities WHERE id = 46340")
```

## SQL reference

- `SELECT [DISTINCT] expr [AS alias], *, t.* [INTO new_table] FROM t [alias]`
- `[INNER | LEFT [OUTER] | CROSS] JOIN t2 ON ...`, or comma joins with `WHERE`
- Subqueries: `FROM (SELECT ...) alias`, `IN (SELECT ...)`, `EXISTS (SELECT ...)`, and `(SELECT ...)` as a value
- `WHERE`, `GROUP BY` (by expression, alias or number), `HAVING`, `ORDER BY ... [ASC|DESC]`, `LIMIT n [OFFSET m]`, `LIMIT m, n`
- Operators: `= == != <> < <= > >=`, `AND OR NOT`, `+ - * / %`, `||`, `LIKE`, `IN`, `BETWEEN`, `IS [NOT] NULL`, `CASE`, `CAST(x AS INT|REAL|TEXT|BOOL)`, and `?` parameters
- Aggregates: `COUNT(*)`, `COUNT(DISTINCT x)`, `SUM`, `AVG`, `MIN`, `MAX`, `TOTAL`, `GROUP_CONCAT(x, sep)`
- Text functions: `LOWER UPPER LENGTH SUBSTR LEFT RIGHT TRIM REPLACE INSTR CONTAINS STARTSWITH CONCAT CONCAT_WS PRINTF`
- Pattern functions: `MATCH(s, luaPattern)` and `CAPTURE(s, luaPattern)`
- Math functions: `ABS ROUND FLOOR CEIL SQRT POWER MOD SIGN RANDOM`
- NULL and logic functions: `COALESCE IFNULL NULLIF IIF TYPEOF`, plus `MIN`/`MAX` with two or more arguments
- ESO functions:
  - Names and details: `ABILITY_NAME ABILITY_DESC ABILITY_ICON ABILITY_DURATION ABILITY_LINK SET_NAME ZONE_NAME ITEM_NAME ITEM_LINK ITEM_ID COLLECTIBLE_NAME ACHIEVEMENT_NAME`
  - Text and display: `CLEAN` strips markup, `ICON(path, size)` makes texture markup, `STR(SI_x)` returns a localized string
  - Constants: `ENUM(prefix, value)` gives the name of an enum value, and `CONST(name)` gives the value of a constant
- Statements: `SHOW TABLES`, `DESCRIBE t`, `DROP TABLE t` (your tables only), `REFRESH t|ALL`, `SCAN abilities|items`, `HELP`

Text comparison (`=`, `<`, `ORDER BY`) and `LIKE` ignore case. `SELECT ... INTO name` saves a result as a table in `LibESQL_SV`. Console allows 5,000 rows per saved table and PC allows 50,000.

## Tables

Run `SHOW TABLES` and `DESCRIBE <name>` for the complete list with column descriptions.

| Group | Tables |
|---|---|
| Abilities and effects | `abilities` (scanned), `effects` (live), `effects_seen`, `combat_log`, `hotbar` |
| Skills | `skill_lines`, `skills`, `class_skill_lines`, `champion_skills`, `crafted_abilities`, `scribing_scripts` |
| Items | `sets`, `set_bonuses`, `set_pieces`, `items` (scanned), `inventory` |
| Character | `character`, `characters`, `stats`, `currencies`, `quests`, `completed_quests`, `titles` |
| Collections | `achievements`, `achievement_criteria`, `collectibles`, `dyes`, `emotes`, `lore_books`, `antiquities`, `recipes` |
| Social | `guilds`, `guild_members`, `friends`, `group_members` |
| World | `zones`, `pois`, `wayshrines`, `activities`, `classes`, `races`, `maps` |
| Game API | `constants`, `events`, `strings`, `functions`, `sounds` |
| Meta | `tables`, `columns` |

Table kinds:
- **static** tables build on first use and stay cached.
- **live** tables are read fresh on every query.
- **scan** tables stream rows from the saved id index.
- **user** tables are the ones you made with `INTO`.

## Console notes

- Console uses smaller per-frame budgets and memory caps:
  - 700 operations per frame
  - 5,000 combat events
  - 3,000 tracked effects
  - 5,000 rows per saved table
- PC keeps the names of scanned abilities for the session so repeated name searches run fast. Console skips this to save memory.

## License

MIT. See [LICENSE](LICENSE).
