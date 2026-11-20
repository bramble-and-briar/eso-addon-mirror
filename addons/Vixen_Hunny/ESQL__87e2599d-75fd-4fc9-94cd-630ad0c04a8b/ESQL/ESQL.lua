-- ESQL add-on: the window, console panel and slash commands on top of LibESQL.
-- ESQL reads through to LibESQL for anything it does not define itself
-- (ESQL.Print, ESQL.SQL, ESQL.RunAsync, ...). ESQL.sv is the add-on's own
-- SavedVariables (window, history, text size); game data lives in LibESQL_SV.

assert(LibESQL, "ESQL needs LibESQL")

ESQL = setmetatable({ name = "ESQL", lib = LibESQL }, { __index = LibESQL })
