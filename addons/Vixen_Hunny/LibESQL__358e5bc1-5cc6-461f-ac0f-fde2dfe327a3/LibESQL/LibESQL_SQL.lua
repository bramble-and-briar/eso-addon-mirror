-- ESQL SQL engine: tokenizer, parser, compiler and executor (pure Lua 5.1).
--
-- Supported:
--   SELECT [DISTINCT] expr [AS a], *, t.* [INTO new_table]
--   FROM t [AS a] | (SELECT ...) a  [ [INNER|LEFT [OUTER]|CROSS] JOIN t2 ON ... | , t2 ]
--   WHERE / GROUP BY / HAVING / ORDER BY expr [ASC|DESC] / LIMIT n [OFFSET m] / LIMIT m, n
--   = == != <> < <= > >=  AND OR NOT  + - * / %  ||  LIKE  IN (...)  IN (SELECT ...)
--   BETWEEN  IS [NOT] NULL  EXISTS (SELECT ...)  (SELECT ...)  CASE  CAST(x AS INT|REAL|TEXT)
--   COUNT SUM AVG MIN MAX TOTAL GROUP_CONCAT, plus scalar functions (see FUNCS)
--   SHOW TABLES, DESCRIBE t, DROP TABLE t, REFRESH t|ALL, SCAN abilities|items, HELP
--
-- String comparison (=, <, ORDER BY) and LIKE are case-insensitive.

local E = LibESQL
local SQL = {}
E.SQL = SQL

local lower, upper, sub, find, format, byte = string.lower, string.upper, string.sub, string.find, string.format, string.byte
local floor, huge = math.floor, math.huge
local Tick = function(n) E.Tick(n) end

local function fail(msg, ...)
    error({ esql = true, msg = select("#", ...) > 0 and format(msg, ...) or msg }, 0)
end
SQL.Fail = fail

---------------------------------------------------------------------------
-- Tokenizer
---------------------------------------------------------------------------
local KEYWORDS = {}
for w in ([[SELECT DISTINCT FROM WHERE GROUP BY HAVING ORDER ASC DESC LIMIT OFFSET AND OR NOT
    LIKE IN BETWEEN IS NULL TRUE FALSE AS JOIN INNER LEFT OUTER CROSS ON INTO CASE WHEN THEN
    ELSE END CAST EXISTS ALL]]):gmatch("%S+") do
    KEYWORDS[w] = true
end

local function tokenize(src)
    local toks, i, n = {}, 1, #src
    local function push(t, v, s, e, q)
        toks[#toks + 1] = { t = t, v = v, s = s, e = e, q = q }
    end
    while i <= n do
        local c = sub(src, i, i)
        if find(c, "%s") then
            i = i + 1
        elseif sub(src, i, i + 1) == "--" then
            local e = find(src, "\n", i, true)
            i = e and e + 1 or n + 1
        elseif sub(src, i, i + 1) == "/*" then
            local _, e = find(src, "*/", i + 2, true)
            i = e and e + 1 or n + 1
        elseif find(c, "[%a_]") then
            local s, e = find(src, "^[%w_]+", i)
            local word = sub(src, s, e)
            local up = upper(word)
            if KEYWORDS[up] then push("kw", up, s, e) else push("id", word, s, e) end
            i = e + 1
        elseif find(c, "%d") or (c == "." and find(sub(src, i + 1, i + 1), "%d")) then
            local s, e = find(src, "^0[xX]%x+", i)
            local v
            if s then
                v = tonumber(sub(src, s + 2, e), 16)
            else
                s, e = find(src, "^%d*%.?%d*[eE][%+%-]?%d+", i)
                if not s then s, e = find(src, "^%d*%.?%d*", i) end
                v = tonumber(sub(src, s, e))
            end
            if not v then fail("bad number near '%s'", sub(src, i, i + 10)) end
            push("num", v, s, e)
            i = e + 1
        elseif c == "'" then
            local buf, j = {}, i + 1
            while true do
                if j > n then fail("unterminated string starting at %d", i) end
                local ch = sub(src, j, j)
                if ch == "'" then
                    if sub(src, j + 1, j + 1) == "'" then
                        buf[#buf + 1] = "'"; j = j + 2
                    else
                        break
                    end
                else
                    buf[#buf + 1] = ch; j = j + 1
                end
            end
            push("str", table.concat(buf), i, j)
            i = j + 1
        elseif c == '"' or c == "`" or c == "[" then
            local close = c == "[" and "]" or c
            local e = find(src, close, i + 1, true)
            if not e then fail("unterminated quoted name starting at %d", i) end
            push("id", sub(src, i + 1, e - 1), i, e, true)
            i = e + 1
        else
            local two = sub(src, i, i + 1)
            if two == "<=" or two == ">=" or two == "<>" or two == "!=" or two == "==" or two == "||" then
                push("op", two == "==" and "=" or (two == "<>" and "!=" or two), i, i + 1)
                i = i + 2
            elseif find(c, "[%(%),%.;%*%+%-/%%=<>%?]") then
                push("op", c, i, i)
                i = i + 1
            else
                fail("unexpected character '%s' at %d", c, i)
            end
        end
    end
    push("eof", nil, n + 1, n + 1)
    return toks
end
SQL.Tokenize = tokenize

---------------------------------------------------------------------------
-- Parser
---------------------------------------------------------------------------
local P = {}
P.__index = P

local function newParser(src, params)
    return setmetatable({ src = src, toks = tokenize(src), pos = 1, params = params, nparam = 0 }, P)
end

function P:peek(o) return self.toks[self.pos + (o or 0)] end
function P:next() local t = self.toks[self.pos]; self.pos = self.pos + 1; return t end
function P:isKw(w, o) local t = self:peek(o); return t.t == "kw" and t.v == w end
function P:isOp(op, o) local t = self:peek(o); return t.t == "op" and t.v == op end
function P:isWord(w, o)
    local t = self:peek(o)
    return (t.t == "id" and not t.q and upper(t.v) == w) or (t.t == "kw" and t.v == w)
end
function P:acceptKw(w) if self:isKw(w) then return self:next() end end
function P:acceptOp(op) if self:isOp(op) then return self:next() end end

function P:near()
    local t = self:peek()
    if t.t == "eof" then return "end of query" end
    return "'" .. sub(self.src, t.s, math.min(t.e + 15, #self.src)) .. "'"
end

function P:expectKw(w)
    if not self:isKw(w) then fail("expected %s near %s", w, self:near()) end
    return self:next()
end
function P:expectOp(op)
    if not self:isOp(op) then fail("expected '%s' near %s", op, self:near()) end
    return self:next()
end
function P:ident(what)
    local t = self:peek()
    if t.t ~= "id" then fail("expected %s near %s", what or "a name", self:near()) end
    self.pos = self.pos + 1
    return t.v, t
end

-- give a node its source text, used to name output columns
function P:span(node, startTok)
    local last = self.toks[self.pos - 1]
    node.txt = sub(self.src, startTok.s, last.e)
    return node
end

function P:statement()
    local node
    if self:isKw("SELECT") then
        node = self:select()
    elseif self:isWord("SHOW") then
        self:next()
        if not (self:isWord("TABLES")) then fail("expected SHOW TABLES") end
        self:next()
        node = { k = "show" }
    elseif self:isWord("DESCRIBE") or self:isKw("DESC") then
        self:next()
        node = { k = "describe", name = (self:ident("a table name")) }
    elseif self:isWord("DROP") then
        self:next()
        if not self:isWord("TABLE") then fail("expected DROP TABLE name") end
        self:next()
        node = { k = "drop", name = (self:ident("a table name")) }
    elseif self:isWord("REFRESH") then
        self:next()
        if self:acceptKw("ALL") then node = { k = "refresh", all = true }
        else node = { k = "refresh", name = (self:ident("a table name or ALL")) } end
    elseif self:isWord("SCAN") then
        self:next()
        node = { k = "scan", name = (self:ident("abilities or items")) }
    elseif self:isWord("HELP") then
        self:next()
        node = { k = "help" }
    else
        fail("queries start with SELECT, SHOW TABLES, DESCRIBE, DROP TABLE, REFRESH, SCAN or HELP")
    end
    self:acceptOp(";")
    if self:peek().t ~= "eof" then fail("unexpected text near %s", self:near()) end
    return node
end

local function isAliasToken(t)
    return t.t == "id"
end

function P:select()
    self:expectKw("SELECT")
    local q = { k = "select", items = {}, from = {} }
    if self:acceptKw("DISTINCT") then q.distinct = true else self:acceptKw("ALL") end

    repeat
        local item = {}
        if self:isOp("*") then
            self:next(); item.star = true
        elseif self:peek().t == "id" and self:isOp(".", 1) and self:isOp("*", 2) then
            item.star = true; item.tbl = lower(self:next().v); self:next(); self:next()
        else
            item.expr = self:expr()
            if self:acceptKw("AS") then
                item.alias = (self:ident("an alias"))
            elseif isAliasToken(self:peek()) then
                item.alias = self:next().v
            end
        end
        q.items[#q.items + 1] = item
    until not self:acceptOp(",")

    if self:acceptKw("INTO") then q.into = (self:ident("a new table name")) end

    if self:acceptKw("FROM") then
        q.from[1] = self:tableRef()
        while true do
            local jt
            if self:acceptOp(",") then jt = "cross"
            elseif self:isKw("JOIN") then self:next(); jt = "inner"
            elseif self:isKw("INNER") then self:next(); self:expectKw("JOIN"); jt = "inner"
            elseif self:isKw("CROSS") then self:next(); self:expectKw("JOIN"); jt = "cross"
            elseif self:isKw("LEFT") then self:next(); self:acceptKw("OUTER"); self:expectKw("JOIN"); jt = "left"
            else break end
            local ref = self:tableRef()
            ref.join = jt
            if jt ~= "cross" then
                if self:acceptKw("ON") then
                    ref.on = self:expr()
                elseif jt == "left" then
                    fail("LEFT JOIN needs an ON condition")
                end
            end
            q.from[#q.from + 1] = ref
        end
    end

    if self:acceptKw("WHERE") then q.where = self:expr() end
    if self:acceptKw("GROUP") then
        self:expectKw("BY")
        q.group = {}
        repeat q.group[#q.group + 1] = self:expr() until not self:acceptOp(",")
    end
    if self:acceptKw("HAVING") then q.having = self:expr() end
    if self:acceptKw("ORDER") then
        self:expectKw("BY")
        q.order = {}
        repeat
            local o = { expr = self:expr() }
            if self:acceptKw("DESC") then o.desc = true else self:acceptKw("ASC") end
            q.order[#q.order + 1] = o
        until not self:acceptOp(",")
    end
    if self:acceptKw("LIMIT") then
        local a = self:intLiteral("LIMIT")
        if self:acceptOp(",") then
            q.offset = a; q.limit = self:intLiteral("LIMIT")
        else
            q.limit = a
            if self:acceptKw("OFFSET") then q.offset = self:intLiteral("OFFSET") end
        end
    end
    return q
end

function P:intLiteral(what)
    local t = self:peek()
    if t.t ~= "num" then fail("%s needs a number near %s", what, self:near()) end
    self:next()
    return floor(t.v)
end

function P:tableRef()
    local ref = {}
    if self:isOp("(") then
        self:next()
        ref.sub = self:select()
        self:expectOp(")")
        self:acceptKw("AS")
        ref.alias = lower((self:ident("an alias for the subquery")))
    else
        ref.name = lower((self:ident("a table name")))
        if self:acceptKw("AS") then
            ref.alias = lower((self:ident("an alias")))
        elseif self:peek().t == "id" then
            ref.alias = lower(self:next().v)
        end
        ref.alias = ref.alias or ref.name
    end
    return ref
end

-- precedence climbing ----------------------------------------------------
function P:expr() return self:orExpr() end

function P:orExpr()
    local st = self:peek()
    local a = self:andExpr()
    while self:acceptKw("OR") do
        a = self:span({ k = "bin", op = "or", a = a, b = self:andExpr() }, st)
    end
    return a
end

function P:andExpr()
    local st = self:peek()
    local a = self:notExpr()
    while self:acceptKw("AND") do
        a = self:span({ k = "bin", op = "and", a = a, b = self:notExpr() }, st)
    end
    return a
end

function P:notExpr()
    local st = self:peek()
    if self:acceptKw("NOT") then
        return self:span({ k = "un", op = "not", a = self:notExpr() }, st)
    end
    return self:cmpExpr()
end

local CMP = { ["="] = true, ["!="] = true, ["<"] = true, ["<="] = true, [">"] = true, [">="] = true }

function P:cmpExpr()
    local st = self:peek()
    local a = self:concatExpr()
    while true do
        local t = self:peek()
        if t.t == "op" and CMP[t.v] then
            self:next()
            a = self:span({ k = "bin", op = t.v, a = a, b = self:concatExpr() }, st)
        else
            local neg = false
            if self:isKw("NOT") and (self:isKw("LIKE", 1) or self:isKw("IN", 1) or self:isKw("BETWEEN", 1)) then
                self:next(); neg = true
            end
            if self:acceptKw("LIKE") then
                a = self:span({ k = "like", a = a, b = self:concatExpr(), neg = neg }, st)
            elseif self:acceptKw("IN") then
                self:expectOp("(")
                local node = { k = "in", a = a, neg = neg }
                if self:isKw("SELECT") then
                    node.sub = self:select()
                else
                    node.list = {}
                    if not self:isOp(")") then
                        repeat node.list[#node.list + 1] = self:expr() until not self:acceptOp(",")
                    end
                end
                self:expectOp(")")
                a = self:span(node, st)
            elseif self:acceptKw("BETWEEN") then
                local lo = self:concatExpr()
                self:expectKw("AND")
                local hi = self:concatExpr()
                a = self:span({ k = "between", a = a, lo = lo, hi = hi, neg = neg }, st)
            elseif self:isKw("IS") then
                self:next()
                local n2 = self:acceptKw("NOT") and true or false
                self:expectKw("NULL")
                a = self:span({ k = "isnull", a = a, neg = n2 }, st)
            else
                if neg then fail("expected LIKE, IN or BETWEEN after NOT near %s", self:near()) end
                return a
            end
        end
    end
end

function P:concatExpr()
    local st = self:peek()
    local a = self:addExpr()
    while self:acceptOp("||") do
        a = self:span({ k = "bin", op = "||", a = a, b = self:addExpr() }, st)
    end
    return a
end

function P:addExpr()
    local st = self:peek()
    local a = self:mulExpr()
    while self:isOp("+") or self:isOp("-") do
        local op = self:next().v
        a = self:span({ k = "bin", op = op, a = a, b = self:mulExpr() }, st)
    end
    return a
end

function P:mulExpr()
    local st = self:peek()
    local a = self:unary()
    while self:isOp("*") or self:isOp("/") or self:isOp("%") do
        local op = self:next().v
        a = self:span({ k = "bin", op = op, a = a, b = self:unary() }, st)
    end
    return a
end

function P:unary()
    local st = self:peek()
    if self:acceptOp("-") then
        local a = self:unary()
        if a.k == "lit" and type(a.v) == "number" then a.v = -a.v; return self:span(a, st) end
        return self:span({ k = "un", op = "-", a = a }, st)
    end
    if self:acceptOp("+") then return self:unary() end
    return self:primary()
end

function P:primary()
    local t = self:peek()
    local st = t
    if t.t == "num" then self:next(); return self:span({ k = "lit", v = t.v }, st) end
    if t.t == "str" then self:next(); return self:span({ k = "lit", v = t.v }, st) end
    if t.t == "kw" then
        if t.v == "NULL" then self:next(); return self:span({ k = "lit", v = nil }, st) end
        if t.v == "TRUE" then self:next(); return self:span({ k = "lit", v = true }, st) end
        if t.v == "FALSE" then self:next(); return self:span({ k = "lit", v = false }, st) end
        if t.v == "CASE" then return self:caseExpr() end
        if t.v == "CAST" then
            self:next(); self:expectOp("(")
            local a = self:expr()
            self:expectKw("AS")
            local ty = upper((self:ident("a type")))
            self:expectOp(")")
            return self:span({ k = "cast", a = a, to = ty }, st)
        end
        if t.v == "EXISTS" then
            self:next(); self:expectOp("(")
            local q = self:select()
            self:expectOp(")")
            return self:span({ k = "exists", q = q }, st)
        end
        if t.v == "LEFT" and self:isOp("(", 1) then
            -- LEFT(s, n) string function
            self:next()
            return self:funcCall("LEFT", st)
        end
        fail("unexpected %s near %s", t.v, self:near())
    end
    if t.t == "op" and t.v == "?" then
        -- bound parameter: Query("... WHERE id = ?", { params = { 1234 } })
        self:next()
        self.nparam = self.nparam + 1
        local params, i = self.params, self.nparam
        -- a nil value is a NULL; pass params.n to bind trailing NULLs
        if not params or (params[i] == nil and i > (params.n or #params)) then
            fail("missing value for parameter %d", i)
        end
        return self:span({ k = "lit", v = params[i] }, st)
    end
    if t.t == "op" and t.v == "(" then
        self:next()
        if self:isKw("SELECT") then
            local q = self:select()
            self:expectOp(")")
            return self:span({ k = "sub", q = q }, st)
        end
        local e = self:expr()
        self:expectOp(")")
        e.paren = true
        return e
    end
    if t.t == "id" then
        self:next()
        if self:isOp("(") and not t.q then
            return self:funcCall(upper(t.v), st)
        end
        if self:isOp(".") and self:peek(1).t == "id" then
            self:next()
            local col = self:next()
            return self:span({ k = "col", tbl = lower(t.v), name = col.v, quoted = col.q }, st)
        end
        return self:span({ k = "col", name = t.v, quoted = t.q }, st)
    end
    fail("unexpected %s near %s", t.t == "eof" and "end of query" or "token", self:near())
end

function P:funcCall(name, st)
    self:expectOp("(")
    local node = { k = "fn", name = name, args = {} }
    if self:isOp("*") then
        self:next(); node.star = true
    elseif not self:isOp(")") then
        if self:acceptKw("DISTINCT") then node.distinct = true end
        repeat node.args[#node.args + 1] = self:expr() until not self:acceptOp(",")
    end
    self:expectOp(")")
    return self:span(node, st)
end

function P:caseExpr()
    local st = self:peek()
    self:expectKw("CASE")
    local node = { k = "case", whens = {} }
    if not self:isKw("WHEN") then node.base = self:expr() end
    while self:acceptKw("WHEN") do
        local w = self:expr()
        self:expectKw("THEN")
        node.whens[#node.whens + 1] = { w = w, t = self:expr() }
    end
    if #node.whens == 0 then fail("CASE needs at least one WHEN") end
    if self:acceptKw("ELSE") then node.els = self:expr() end
    self:expectKw("END")
    return self:span(node, st)
end

function SQL.Parse(src, params)
    return newParser(src, params):statement()
end

---------------------------------------------------------------------------
-- Values
---------------------------------------------------------------------------
local function truth(v)
    if v == nil then return nil end
    local tv = type(v)
    if tv == "boolean" then return v end
    if tv == "number" then return v ~= 0 end
    if tv == "string" then local n = tonumber(v); return n ~= nil and n ~= 0 end
    return true
end

local function num(v)
    local tv = type(v)
    if tv == "number" then return v end
    if tv == "boolean" then return v and 1 or 0 end
    if tv == "string" then return tonumber(v) end
    return nil
end

local function cmp(a, b)
    if a == nil or b == nil then return nil end
    if a == true then a = 1 elseif a == false then a = 0 end
    if b == true then b = 1 elseif b == false then b = 0 end
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        if ta == "number" then
            local n = tonumber(b)
            if n then b = n else a = tostring(a) end
        elseif tb == "number" then
            local n = tonumber(a)
            if n then a = n else b = tostring(b) end
        else
            a, b = tostring(a), tostring(b)
        end
    end
    if type(a) == "string" then a, b = lower(a), lower(b) end
    if a < b then return -1 elseif a > b then return 1 end
    return 0
end
SQL.Compare = cmp

-- total order for ORDER BY: NULL < numbers/bools < strings
local function rankOf(v)
    if v == nil then return 0 end
    local tv = type(v)
    if tv == "number" or tv == "boolean" then return 1 end
    if tv == "string" then return 2 end
    return 3
end

local function sortCmp(a, b)
    local ra, rb = rankOf(a), rankOf(b)
    if ra ~= rb then return ra < rb and -1 or 1 end
    if ra == 0 then return 0 end
    if ra == 1 then
        a = a == true and 1 or (a == false and 0 or a)
        b = b == true and 1 or (b == false and 0 or b)
        if a < b then return -1 elseif a > b then return 1 end
        return 0
    end
    if ra == 2 then
        local la, lb = lower(a), lower(b)
        if la < lb then return -1 elseif la > lb then return 1 end
        if a < b then return -1 elseif a > b then return 1 end
        return 0
    end
    local sa, sb = tostring(a), tostring(b)
    if sa < sb then return -1 elseif sa > sb then return 1 end
    return 0
end
SQL.SortCompare = sortCmp

-- key used for hashing / IN sets / DISTINCT / GROUP BY
local function normKey(v)
    if v == nil then return "\0" end
    if v == true then return 1 end
    if v == false then return 0 end
    local tv = type(v)
    if tv == "string" then
        local n = tonumber(v)
        if n then return n end
        return lower(v)
    end
    return v
end
SQL.NormKey = normKey

local function keyString(v)
    local k = normKey(v)
    if type(k) == "number" then return "n" .. k end
    return "s" .. tostring(k)
end

local function toText(v)
    if v == nil then return nil end
    if type(v) == "number" then
        if v == floor(v) and v > -1e15 and v < 1e15 then return format("%d", v) end
        return tostring(v)
    end
    return tostring(v)
end
SQL.ToText = toText

---------------------------------------------------------------------------
-- LIKE
---------------------------------------------------------------------------
local likeCache, likeCacheSize = {}, 0

local function likeMatcher(pat)
    local m = likeCache[pat]
    if m then return m end
    local lp = lower(pat)
    if not find(lp, "_", 1, true) then
        local inner = lp:match("^%%([^%%]*)%%$")
        if inner then
            m = function(s) return find(s, inner, 1, true) ~= nil end
        elseif not find(lp, "%", 1, true) then
            m = function(s) return s == lp end
        else
            local pre = lp:match("^([^%%]*)%%$")
            local suf = lp:match("^%%([^%%]*)$")
            if pre then
                local n = #pre
                m = function(s) return sub(s, 1, n) == pre end
            elseif suf then
                local n = #suf
                m = function(s) return n == 0 or sub(s, -n) == suf end
            end
        end
    end
    if not m then
        local buf = { "^" }
        for i = 1, #lp do
            local c = sub(lp, i, i)
            if c == "%" then buf[#buf + 1] = ".-"
            elseif c == "_" then buf[#buf + 1] = "."
            elseif find(c, "[%^%$%(%)%.%[%]%*%+%-%?]") then buf[#buf + 1] = "%" .. c
            else buf[#buf + 1] = c end
        end
        buf[#buf + 1] = "$"
        local lua = table.concat(buf)
        m = function(s) return find(s, lua) ~= nil end
    end
    if likeCacheSize > 500 then likeCache, likeCacheSize = {}, 0 end
    likeCache[pat] = m
    likeCacheSize = likeCacheSize + 1
    return m
end

local function like(s, pat)
    if s == nil or pat == nil then return nil end
    return likeMatcher(toText(pat))(lower(toText(s)))
end

---------------------------------------------------------------------------
-- Scalar functions. Each gets evaluated argument values.
---------------------------------------------------------------------------
local FUNCS = {}
SQL.FUNCS = FUNCS

local function str(v) return toText(v) end

FUNCS.LOWER = function(s) s = str(s); return s and lower(s) end
FUNCS.UPPER = function(s) s = str(s); return s and upper(s) end
FUNCS.LENGTH = function(s) s = str(s); return s and #s end
FUNCS.LEN = FUNCS.LENGTH
FUNCS.SUBSTR = function(s, i, n)
    s = str(s); i = num(i)
    if not s or not i then return nil end
    if i < 0 then i = #s + i + 1 elseif i == 0 then i = 1 end
    n = num(n)
    if n then return sub(s, i, i + n - 1) end
    return sub(s, i)
end
FUNCS.SUBSTRING = FUNCS.SUBSTR
FUNCS.LEFT = function(s, n) s = str(s); n = num(n); return s and n and sub(s, 1, n) end
FUNCS.RIGHT = function(s, n) s = str(s); n = num(n); if not s or not n then return nil end; return n > 0 and sub(s, -n) or "" end
FUNCS.TRIM = function(s) s = str(s); return s and (s:gsub("^%s+", ""):gsub("%s+$", "")) end
FUNCS.LTRIM = function(s) s = str(s); return s and (s:gsub("^%s+", "")) end
FUNCS.RTRIM = function(s) s = str(s); return s and (s:gsub("%s+$", "")) end
FUNCS.REPLACE = function(s, a, b)
    s, a, b = str(s), str(a), str(b) or ""
    if not s or not a or a == "" then return s end
    local out, i = {}, 1
    while true do
        local x, y = find(s, a, i, true)
        if not x then break end
        out[#out + 1] = sub(s, i, x - 1); out[#out + 1] = b
        i = y + 1
    end
    out[#out + 1] = sub(s, i)
    return table.concat(out)
end
FUNCS.INSTR = function(s, a)
    s, a = str(s), str(a)
    if not s or not a then return nil end
    return find(lower(s), lower(a), 1, true) or 0
end
FUNCS.CONTAINS = function(s, a)
    s, a = str(s), str(a)
    if not s or not a then return nil end
    return find(lower(s), lower(a), 1, true) ~= nil
end
FUNCS.STARTSWITH = function(s, a)
    s, a = str(s), str(a)
    if not s or not a then return nil end
    return sub(lower(s), 1, #a) == lower(a)
end
FUNCS.MATCH = function(s, p)
    s, p = str(s), str(p)
    if not s or not p then return nil end
    local ok, r = pcall(find, s, p)
    if not ok then fail("bad Lua pattern in MATCH: %s", p) end
    return r ~= nil
end
FUNCS.CAPTURE = function(s, p)
    s, p = str(s), str(p)
    if not s or not p then return nil end
    local ok, r = pcall(string.match, s, p)
    if not ok then fail("bad Lua pattern in CAPTURE: %s", p) end
    return r
end
FUNCS.ABS = function(x) x = num(x); return x and math.abs(x) end
FUNCS.ROUND = function(x, n)
    x = num(x); n = num(n) or 0
    if not x then return nil end
    local m = 10 ^ n
    return floor(x * m + 0.5) / m
end
FUNCS.FLOOR = function(x) x = num(x); return x and floor(x) end
FUNCS.CEIL = function(x) x = num(x); return x and math.ceil(x) end
FUNCS.CEILING = FUNCS.CEIL
FUNCS.SQRT = function(x) x = num(x); return x and x >= 0 and math.sqrt(x) or nil end
FUNCS.POWER = function(x, y) x, y = num(x), num(y); return x and y and x ^ y end
FUNCS.POW = FUNCS.POWER
FUNCS.MOD = function(x, y) x, y = num(x), num(y); if not x or not y or y == 0 then return nil end; return x % y end
FUNCS.SIGN = function(x) x = num(x); if not x then return nil end; return x > 0 and 1 or (x < 0 and -1 or 0) end
FUNCS.COALESCE = function(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then return v end
    end
    return nil
end
FUNCS.IFNULL = function(a, b) if a == nil then return b end return a end
FUNCS.NVL = FUNCS.IFNULL
FUNCS.NULLIF = function(a, b) if cmp(a, b) == 0 then return nil end return a end
FUNCS.IIF = function(c, a, b) if truth(c) then return a end return b end
FUNCS.IF = FUNCS.IIF
FUNCS.TYPEOF = function(v)
    if v == nil then return "null" end
    local t = type(v)
    if t == "number" then return v == floor(v) and "integer" or "real" end
    if t == "string" then return "text" end
    return t
end
FUNCS.PRINTF = function(fmt, ...)
    fmt = str(fmt)
    if not fmt then return nil end
    local ok, r = pcall(format, fmt, ...)
    if not ok then fail("PRINTF: %s", tostring(r)) end
    return r
end
FUNCS.FORMAT = FUNCS.PRINTF
FUNCS.HEX = function(x) x = num(x); return x and format("%X", x) end
FUNCS.CHAR = function(...) return string.char(...) end
FUNCS.CONCAT = function(...)
    local buf = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then buf[#buf + 1] = toText(v) end
    end
    return table.concat(buf)
end
FUNCS.CONCAT_WS = function(sep, ...)
    local buf = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then buf[#buf + 1] = toText(v) end
    end
    return table.concat(buf, toText(sep) or "")
end
FUNCS.CLEAN = function(s) return E.StripMarkup(E.CleanName(str(s))) end
FUNCS.STRIP = FUNCS.CLEAN
FUNCS.ICON = function(path, size)
    path = str(path)
    if not path or path == "" then return nil end
    size = num(size) or 24
    return format("|t%d:%d:%s|t", size, size, path)
end
FUNCS.ENUM = function(prefix, v) return E.EnumName(str(prefix), num(v)) end
FUNCS.CONST = function(name) name = str(name); return name and _G[name] end
FUNCS.STR = function(id)
    -- STR(SI_ID or 'SI_NAME') -> GetString
    if type(id) == "string" then id = _G[id] end
    if type(id) ~= "number" or not GetString then return nil end
    return GetString(id)
end
FUNCS.NOW = function() return GetTimeStamp and GetTimeStamp() or os.time() end
FUNCS.DATE = function(ts, fmt)
    ts = num(ts)
    if not ts then return nil end
    if os and os.date then return os.date(str(fmt) or "%Y-%m-%d %H:%M:%S", ts) end
    if FormatAchievementLinkTimestamp then return FormatAchievementLinkTimestamp(ts) end
    return tostring(ts)
end
FUNCS.MS_TO_S = function(ms) ms = num(ms); return ms and ms / 1000 end
FUNCS.RANDOM = function(a, b)
    if a and b then return math.random(num(a), num(b)) end
    return math.random()
end
-- Game lookups (added by the table modules: ABILITY_NAME, SET_NAME, ...)

-- names of aggregate functions
local AGG = { COUNT = true, SUM = true, AVG = true, MIN = true, MAX = true, TOTAL = true, GROUP_CONCAT = true }

---------------------------------------------------------------------------
-- Compiler
---------------------------------------------------------------------------
-- A compiled expression is a function(ctx) -> value.
-- ctx[i] is the current row of source i (false for a LEFT JOIN miss),
-- ctx.agg holds finished aggregate values while evaluating a group.

local compile

local function colClosure(ti, key, get)
    if get then
        return function(ctx)
            local r = ctx[ti]
            if not r then return nil end
            local v = r[key]
            if v == nil then
                local ok, val = pcall(get, r)
                if ok and val ~= nil then r[key] = val; v = val end
            end
            return v
        end
    end
    return function(ctx)
        local r = ctx[ti]
        if not r then return nil end
        return r[key]
    end
end

local function columnList(src)
    local names = {}
    for i, c in ipairs(src.cols) do names[i] = c.name end
    return table.concat(names, ", ")
end

local function resolveColumn(node, cc)
    local name = lower(node.name)
    if node.tbl then
        for ti, src in ipairs(cc.sources) do
            if src.alias == node.tbl then
                local col = src.colIndex[name]
                if not col then fail("table %s has no column '%s'. Columns: %s", src.alias, node.name, columnList(src)) end
                if cc.refs then cc.refs[ti] = true end
                return colClosure(ti, col.key, col.get)
            end
        end
        fail("unknown table or alias '%s'", node.tbl)
    end
    local found, foundTi
    for ti, src in ipairs(cc.sources) do
        local col = src.colIndex[name]
        if col then
            if found then fail("column '%s' is ambiguous; prefix it with a table alias", node.name) end
            found, foundTi = col, ti
        end
    end
    if found then
        if cc.refs then cc.refs[foundTi] = true end
        return colClosure(foundTi, found.key, found.get)
    end
    if cc.aliases and cc.aliases[name] then
        local f = cc.aliases[name]
        if cc.refs and cc.aliasRefs and cc.aliasRefs[name] then
            for k in pairs(cc.aliasRefs[name]) do cc.refs[k] = true end
        end
        return f
    end
    if node.quoted then
        -- "text" that is not a column: treat as a string (like SQLite)
        local v = node.name
        return function() return v end
    end
    if #cc.sources == 0 then fail("unknown column '%s' (the query has no FROM)", node.name) end
    if #cc.sources == 1 then
        fail("no column '%s' in %s. Columns: %s", node.name, cc.sources[1].alias, columnList(cc.sources[1]))
    end
    fail("unknown column '%s'", node.name)
end

local function constValue(node)
    if node.k == "lit" then return true, node.v end
    return false
end

local function runSubquery(q, cc)
    -- uncorrelated: executed once, lazily
    local res
    return function()
        if not res then res = SQL.ExecuteSelect(q, { inner = true }) end
        return res
    end
end

local function compileAgg(node, cc)
    if not cc.aggs then fail("aggregate %s() is not allowed here", node.name) end
    if cc.inAgg then fail("aggregates cannot be nested") end
    local agg = { kind = node.name, distinct = node.distinct }
    if node.name == "COUNT" and node.star then
        agg.kind = "COUNT_STAR"
    else
        if #node.args < 1 then fail("%s() needs an argument", node.name) end
        cc.inAgg = true
        local saveAliases = cc.aliases
        cc.aliases = nil
        agg.arg = compile(node.args[1], cc)
        if node.name == "GROUP_CONCAT" and node.args[2] then
            local ok, v = constValue(node.args[2])
            if not ok then fail("GROUP_CONCAT separator must be a constant") end
            agg.sep = toText(v)
        end
        cc.aliases = saveAliases
        cc.inAgg = false
    end
    local idx = #cc.aggs + 1
    cc.aggs[idx] = agg
    return function(ctx)
        local a = ctx.agg
        return a and a[idx]
    end
end

compile = function(node, cc)
    local k = node.k
    if k == "lit" then
        local v = node.v
        return function() return v end
    elseif k == "col" then
        return resolveColumn(node, cc)
    elseif k == "un" then
        local a = compile(node.a, cc)
        if node.op == "-" then
            return function(ctx) local x = num(a(ctx)); return x and -x end
        end
        return function(ctx)
            local t = truth(a(ctx))
            if t == nil then return nil end
            return not t
        end
    elseif k == "bin" then
        local op = node.op
        local a, b = compile(node.a, cc), compile(node.b, cc)
        if op == "and" then
            return function(ctx)
                local x = truth(a(ctx))
                if x == false then return false end
                local y = truth(b(ctx))
                if y == false then return false end
                if x == nil or y == nil then return nil end
                return true
            end
        elseif op == "or" then
            return function(ctx)
                local x = truth(a(ctx))
                if x == true then return true end
                local y = truth(b(ctx))
                if y == true then return true end
                if x == nil or y == nil then return nil end
                return false
            end
        elseif op == "=" then
            return function(ctx) local c = cmp(a(ctx), b(ctx)); if c == nil then return nil end; return c == 0 end
        elseif op == "!=" then
            return function(ctx) local c = cmp(a(ctx), b(ctx)); if c == nil then return nil end; return c ~= 0 end
        elseif op == "<" then
            return function(ctx) local c = cmp(a(ctx), b(ctx)); if c == nil then return nil end; return c < 0 end
        elseif op == "<=" then
            return function(ctx) local c = cmp(a(ctx), b(ctx)); if c == nil then return nil end; return c <= 0 end
        elseif op == ">" then
            return function(ctx) local c = cmp(a(ctx), b(ctx)); if c == nil then return nil end; return c > 0 end
        elseif op == ">=" then
            return function(ctx) local c = cmp(a(ctx), b(ctx)); if c == nil then return nil end; return c >= 0 end
        elseif op == "||" then
            return function(ctx)
                local x, y = a(ctx), b(ctx)
                if x == nil or y == nil then return nil end
                return toText(x) .. toText(y)
            end
        elseif op == "+" then
            return function(ctx) local x, y = num(a(ctx)), num(b(ctx)); return x and y and x + y end
        elseif op == "-" then
            return function(ctx) local x, y = num(a(ctx)), num(b(ctx)); return x and y and x - y end
        elseif op == "*" then
            return function(ctx) local x, y = num(a(ctx)), num(b(ctx)); return x and y and x * y end
        elseif op == "/" then
            return function(ctx)
                local x, y = num(a(ctx)), num(b(ctx))
                if not x or not y or y == 0 then return nil end
                return x / y
            end
        elseif op == "%" then
            return function(ctx)
                local x, y = num(a(ctx)), num(b(ctx))
                if not x or not y or y == 0 then return nil end
                return math.fmod(x, y)
            end
        end
        fail("unknown operator %s", op)
    elseif k == "like" then
        local a = compile(node.a, cc)
        local neg = node.neg
        local okc, pv = constValue(node.b)
        if okc and pv ~= nil then
            local m = likeMatcher(toText(pv))
            return function(ctx)
                local s = a(ctx)
                if s == nil then return nil end
                local r = m(lower(toText(s)))
                if neg then return not r end
                return r
            end
        end
        local b = compile(node.b, cc)
        return function(ctx)
            local r = like(a(ctx), b(ctx))
            if r == nil then return nil end
            if neg then return not r end
            return r
        end
    elseif k == "in" then
        local a = compile(node.a, cc)
        local neg = node.neg
        local function result(found, sawNull)
            if found then return not neg end
            if sawNull then return nil end
            return neg
        end
        if node.sub then
            local getRes = runSubquery(node.sub, cc)
            local set
            return function(ctx)
                if not set then
                    local res = getRes()
                    if #res.columns ~= 1 then fail("IN (SELECT ...) must return one column") end
                    set = {}
                    for _, row in ipairs(res.rows) do
                        if row[1] ~= nil then set[normKey(row[1])] = true else set.__null = true end
                    end
                end
                local v = a(ctx)
                if v == nil then return nil end
                return result(set[normKey(v)], set.__null)
            end
        end
        local allConst, set, sawNullLit = true, {}, false
        for _, item in ipairs(node.list) do
            local ok, v = constValue(item)
            if not ok then allConst = false; break end
            if v == nil then sawNullLit = true else set[normKey(v)] = true end
        end
        if allConst then
            return function(ctx)
                local v = a(ctx)
                if v == nil then return nil end
                return result(set[normKey(v)], sawNullLit)
            end
        end
        local list = {}
        for i, item in ipairs(node.list) do list[i] = compile(item, cc) end
        return function(ctx)
            local v = a(ctx)
            if v == nil then return nil end
            local sawNull = false
            for i = 1, #list do
                local c = cmp(v, list[i](ctx))
                if c == 0 then return result(true) end
                if c == nil then sawNull = true end
            end
            return result(false, sawNull)
        end
    elseif k == "between" then
        local a, lo, hi = compile(node.a, cc), compile(node.lo, cc), compile(node.hi, cc)
        local neg = node.neg
        return function(ctx)
            local v = a(ctx)
            local c1, c2 = cmp(v, lo(ctx)), cmp(v, hi(ctx))
            if c1 == nil or c2 == nil then return nil end
            local r = c1 >= 0 and c2 <= 0
            if neg then return not r end
            return r
        end
    elseif k == "isnull" then
        local a = compile(node.a, cc)
        if node.neg then return function(ctx) return a(ctx) ~= nil end end
        return function(ctx) return a(ctx) == nil end
    elseif k == "case" then
        local base = node.base and compile(node.base, cc)
        local whens = {}
        for i, w in ipairs(node.whens) do whens[i] = { compile(w.w, cc), compile(w.t, cc) } end
        local els = node.els and compile(node.els, cc)
        return function(ctx)
            local bv = base and base(ctx)
            for i = 1, #whens do
                local w = whens[i]
                if base then
                    if cmp(bv, w[1](ctx)) == 0 then return w[2](ctx) end
                elseif truth(w[1](ctx)) then
                    return w[2](ctx)
                end
            end
            return els and els(ctx)
        end
    elseif k == "cast" then
        local a = compile(node.a, cc)
        local to = node.to
        if to == "INT" or to == "INTEGER" then
            return function(ctx)
                local x = num(a(ctx))
                if not x then return nil end
                return x >= 0 and floor(x) or math.ceil(x)
            end
        elseif to == "REAL" or to == "NUMBER" or to == "NUMERIC" or to == "FLOAT" then
            return function(ctx) return num(a(ctx)) end
        elseif to == "TEXT" or to == "STRING" or to == "VARCHAR" then
            return function(ctx) return toText(a(ctx)) end
        elseif to == "BOOL" or to == "BOOLEAN" then
            return function(ctx) return truth(a(ctx)) end
        end
        fail("CAST to unknown type %s", to)
    elseif k == "sub" then
        local getRes = runSubquery(node.q, cc)
        return function()
            local res = getRes()
            local row = res.rows[1]
            return row and row[1]
        end
    elseif k == "exists" then
        local getRes = runSubquery(node.q, cc)
        return function() return #getRes().rows > 0 end
    elseif k == "fn" then
        local name = node.name
        local isAgg = AGG[name] and (node.star or #node.args == 1 or name == "GROUP_CONCAT" or node.distinct)
        if isAgg then return compileAgg(node, cc) end
        if name == "MIN" or name == "MAX" then
            local args = {}
            for i, a in ipairs(node.args) do args[i] = compile(a, cc) end
            local want = name == "MIN" and -1 or 1
            return function(ctx)
                local best
                for i = 1, #args do
                    local v = args[i](ctx)
                    if v == nil then return nil end
                    if best == nil or sortCmp(v, best) == want then best = v end
                end
                return best
            end
        end
        local fn = FUNCS[name]
        if not fn then fail("unknown function %s()", name) end
        if node.star then fail("%s(*) is not valid", name) end
        local args = {}
        for i, a in ipairs(node.args) do args[i] = compile(a, cc) end
        local n = #args
        if n == 0 then return function() return fn() end end
        if n == 1 then local a1 = args[1]; return function(ctx) return fn(a1(ctx)) end end
        if n == 2 then local a1, a2 = args[1], args[2]; return function(ctx) return fn(a1(ctx), a2(ctx)) end end
        if n == 3 then
            local a1, a2, a3 = args[1], args[2], args[3]
            return function(ctx) return fn(a1(ctx), a2(ctx), a3(ctx)) end
        end
        return function(ctx)
            local vals = {}
            for i = 1, n do vals[i] = args[i](ctx) end
            return fn(unpack(vals, 1, n))
        end
    end
    fail("cannot evaluate expression of kind %s", tostring(k))
end

-- compile and also return which sources the expression reads
local function compileWithRefs(node, cc)
    local saved = cc.refs
    cc.refs = {}
    local f = compile(node, cc)
    local refs = cc.refs
    cc.refs = saved
    if saved then for k in pairs(refs) do saved[k] = true end end
    local maxRef = 0
    for k in pairs(refs) do if k > maxRef then maxRef = k end end
    return f, refs, maxRef
end

local function splitAnd(node, out)
    out = out or {}
    if node and node.k == "bin" and node.op == "and" then
        splitAnd(node.a, out); splitAnd(node.b, out)
    elseif node then
        out[#out + 1] = node
    end
    return out
end

---------------------------------------------------------------------------
-- Aggregate state
---------------------------------------------------------------------------
local function aggNew(agg)
    return { n = 0, seen = agg.distinct and {} or nil }
end

local function aggStep(agg, st, ctx)
    local kind = agg.kind
    if kind == "COUNT_STAR" then st.n = st.n + 1; return end
    local v = agg.arg(ctx)
    if v == nil then return end
    if st.seen then
        local key = keyString(v)
        if st.seen[key] then return end
        st.seen[key] = true
    end
    if kind == "COUNT" then
        st.n = st.n + 1
    elseif kind == "SUM" or kind == "AVG" or kind == "TOTAL" then
        local x = num(v)
        if x then st.n = st.n + 1; st.sum = (st.sum or 0) + x end
    elseif kind == "MIN" then
        if st.v == nil or sortCmp(v, st.v) < 0 then st.v = v end
    elseif kind == "MAX" then
        if st.v == nil or sortCmp(v, st.v) > 0 then st.v = v end
    elseif kind == "GROUP_CONCAT" then
        st.parts = st.parts or {}
        st.parts[#st.parts + 1] = toText(v)
    end
end

local function aggFinal(agg, st)
    local kind = agg.kind
    if kind == "COUNT_STAR" or kind == "COUNT" then return st.n end
    if kind == "SUM" then return st.sum end
    if kind == "TOTAL" then return st.sum or 0 end
    if kind == "AVG" then return st.n > 0 and st.sum / st.n or nil end
    if kind == "MIN" or kind == "MAX" then return st.v end
    if kind == "GROUP_CONCAT" then return st.parts and table.concat(st.parts, agg.sep or ",") end
end

---------------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------------
-- A source wraps a table definition (see ESQL_Schema.lua) or a subquery
-- result. Fields: alias, def, cols, colIndex.

local function makeSource(ref)
    local def
    if ref.sub then
        local res = SQL.ExecuteSelect(ref.sub, { inner = true })
        def = E.MakeResultTable(ref.alias, res)
    else
        def = E.GetTable(ref.name)
        if not def then fail("no table '%s'. Try SHOW TABLES", ref.name) end
    end
    local src = { alias = ref.alias, def = def, cols = def.columns, colIndex = def.colIndex, ref = ref }
    return src
end

---------------------------------------------------------------------------
-- SELECT execution
---------------------------------------------------------------------------
local function outputName(item)
    if item.alias then return item.alias end
    local e = item.expr
    if e.k == "col" then return e.name end
    return e.txt or "?"
end

-- primary-key hints for the first source: key = c, key IN (c...), key BETWEEN a AND b
local function keyHints(conjuncts, src)
    local key = src.def.key
    if not key or not src.def.lookup then return nil end
    local function isKeyCol(n)
        return n.k == "col" and lower(n.name) == key and (not n.tbl or n.tbl == src.alias)
    end
    for _, c in ipairs(conjuncts) do
        if c.k == "bin" and c.op == "=" then
            local other
            if isKeyCol(c.a) then other = c.b elseif isKeyCol(c.b) then other = c.a end
            if other then
                local ok, v = constValue(other)
                if ok then return { v } end
            end
        elseif c.k == "in" and not c.neg and c.list and isKeyCol(c.a) then
            local keys, okAll = {}, true
            for _, item in ipairs(c.list) do
                local ok, v = constValue(item)
                if not ok then okAll = false; break end
                keys[#keys + 1] = v
            end
            if okAll then return keys end
        elseif c.k == "between" and not c.neg and isKeyCol(c.a) then
            local ok1, lo = constValue(c.lo)
            local ok2, hi = constValue(c.hi)
            lo, hi = num(lo), num(hi)
            if ok1 and ok2 and lo and hi and src.def.kind == "scan" and hi - lo <= 200000 then
                return { range = { math.ceil(lo), floor(hi) } }
            end
        end
    end
    return nil
end

-- find "this_source.col = <expr over earlier sources>" for a hash join
local function findEquiJoin(conjNodes, ti, cc)
    for _, c in ipairs(conjNodes) do
        if c.k == "bin" and c.op == "=" then
            for side = 1, 2 do
                local mine = side == 1 and c.a or c.b
                local other = side == 1 and c.b or c.a
                if mine.k == "col" then
                    local f, refs = compileWithRefs(mine, cc)
                    local cnt = 0
                    for _ in pairs(refs) do cnt = cnt + 1 end
                    if refs[ti] and cnt == 1 then
                        local g, _, maxRef = compileWithRefs(other, cc)
                        if maxRef < ti then
                            return { mine = f, other = g, colName = lower(mine.name) }
                        end
                    end
                end
            end
        end
    end
end

function SQL.ExecuteSelect(q, opts)
    opts = opts or {}
    local t0 = E.NowMs()
    local sources = {}
    for i, ref in ipairs(q.from) do
        sources[i] = makeSource(ref)
        for j = 1, i - 1 do
            if sources[j].alias == sources[i].alias then
                fail("table alias '%s' is used twice", sources[i].alias)
            end
        end
    end
    local nsrc = #sources
    local cc = { sources = sources, aggs = {} }

    -- select list -----------------------------------------------------------
    local outCols, outFns = {}, {}
    local aliasMap, aliasRefs = {}, {}
    for _, item in ipairs(q.items) do
        if item.star then
            local any = false
            for ti, src in ipairs(sources) do
                if not item.tbl or item.tbl == src.alias then
                    any = true
                    for _, col in ipairs(src.cols) do
                        local name = col.name
                        if nsrc > 1 and not item.tbl then
                            for tj, other in ipairs(sources) do
                                if tj ~= ti and other.colIndex[lower(name)] then name = src.alias .. "." .. col.name; break end
                            end
                        end
                        outCols[#outCols + 1] = name
                        outFns[#outFns + 1] = colClosure(ti, col.key, col.get)
                    end
                end
            end
            if not any then
                if item.tbl then fail("unknown table or alias '%s'", item.tbl) end
                fail("SELECT * needs a FROM clause")
            end
        else
            local f, refs = compileWithRefs(item.expr, cc)
            local name = outputName(item)
            outCols[#outCols + 1] = name
            outFns[#outFns + 1] = f
            local lname = lower(name)
            if aliasMap[lname] == nil then aliasMap[lname] = f; aliasRefs[lname] = refs end
        end
    end
    local selectAggCount = #cc.aggs

    -- WHERE (split into conjuncts, pushed to the earliest join level) ----------
    local whereConj = splitAnd(q.where)
    local saveAggs = cc.aggs
    cc.aggs = nil
    local levelFilters = {}
    local constFilters = {}
    for i = 0, nsrc do levelFilters[i] = {} end
    for _, node in ipairs(whereConj) do
        local f, _, maxRef = compileWithRefs(node, cc)
        if maxRef == 0 then
            constFilters[#constFilters + 1] = f
        else
            local lf = levelFilters[maxRef]
            lf[#lf + 1] = f
            lf.nodes = lf.nodes or {}
            lf.nodes[#lf.nodes + 1] = node
        end
    end

    -- JOIN ON conditions
    local onFilters, joinPlans = {}, {}
    for i = 2, nsrc do
        local ref = sources[i].ref
        local nodes = splitAnd(ref.on)
        onFilters[i] = {}
        for _, node in ipairs(nodes) do
            local f, _, maxRef = compileWithRefs(node, cc)
            if maxRef > i then fail("ON condition for %s uses a table joined later", sources[i].alias) end
            onFilters[i][#onFilters[i] + 1] = f
        end
        local candidates = {}
        for _, n in ipairs(nodes) do candidates[#candidates + 1] = n end
        if ref.join ~= "left" and levelFilters[i].nodes then
            for _, n in ipairs(levelFilters[i].nodes) do candidates[#candidates + 1] = n end
        end
        joinPlans[i] = findEquiJoin(candidates, i, cc)
    end

    -- GROUP BY / HAVING / ORDER BY ------------------------------------------
    cc.aliases = aliasMap
    cc.aliasRefs = aliasRefs
    local groupFns = {}
    if q.group then
        for i, g in ipairs(q.group) do
            local ok, v = constValue(g)
            if ok and type(v) == "number" then
                if not outFns[v] then fail("GROUP BY %d is out of range", v) end
                groupFns[i] = outFns[v]
            else
                groupFns[i] = compile(g, cc)
            end
        end
    end
    cc.aggs = saveAggs
    local havingFn = q.having and compile(q.having, cc)
    local orderFns = {}
    if q.order then
        for i, o in ipairs(q.order) do
            local ok, v = constValue(o.expr)
            if ok and type(v) == "number" then
                if not outFns[v] then fail("ORDER BY %d is out of range", v) end
                orderFns[i] = { out = v, desc = o.desc }
            else
                orderFns[i] = { fn = compile(o.expr, cc), desc = o.desc }
            end
        end
    end
    cc.aliases = nil

    local grouped = (q.group ~= nil) or #cc.aggs > 0
    if q.having and not grouped then fail("HAVING needs GROUP BY or an aggregate") end
    local aggs = cc.aggs
    local nOut = #outFns

    -- result collection --------------------------------------------------------
    local records = {}
    local limit, offset = q.limit, q.offset or 0
    local maxRows = opts.maxRows
    local canStopEarly = not grouped and not q.distinct and #orderFns == 0
    local stopAt
    if canStopEarly then
        if limit then stopAt = offset + limit end
        if maxRows and (not stopAt or stopAt > offset + maxRows + 1) then stopAt = offset + maxRows + 1 end
    end

    local function project(ctx)
        local vals = {}
        for i = 1, nOut do vals[i] = outFns[i](ctx) end
        local rec = { vals = vals }
        if #orderFns > 0 then
            local keys = {}
            for i, o in ipairs(orderFns) do
                if o.out then keys[i] = vals[o.out] else keys[i] = o.fn(ctx) end
            end
            rec.keys = keys
        end
        records[#records + 1] = rec
    end

    local groups, groupList = {}, {}
    local onRow
    if grouped then
        onRow = function(ctx)
            local key
            if #groupFns == 0 then
                key = ""
            elseif #groupFns == 1 then
                key = keyString(groupFns[1](ctx))
            else
                local parts = {}
                for i = 1, #groupFns do parts[i] = keyString(groupFns[i](ctx)) end
                key = table.concat(parts, "\31")
            end
            local g = groups[key]
            if not g then
                local copy = {}
                for i = 1, nsrc do copy[i] = ctx[i] end
                g = { ctx = copy, states = {} }
                for i, agg in ipairs(aggs) do g.states[i] = aggNew(agg) end
                groups[key] = g
                groupList[#groupList + 1] = g
            end
            for i, agg in ipairs(aggs) do aggStep(agg, g.states[i], ctx) end
            return false
        end
    else
        onRow = function(ctx)
            project(ctx)
            return stopAt ~= nil and #records >= stopAt
        end
    end

    -- row production -------------------------------------------------------------
    local ctx = {}
    local constOk = true
    for _, f in ipairs(constFilters) do
        if truth(f(ctx)) ~= true then constOk = false; break end
    end

    local function passes(list, c)
        for j = 1, #list do
            if truth(list[j](c)) ~= true then return false end
        end
        return true
    end

    local hashes, mats = {}, {}
    local level
    local function materialized(i, def)
        local rows = mats[i]
        if not rows then rows = E.Materialize(def); mats[i] = rows end
        return rows
    end

    local function visit(i, r)
        -- returns true to stop everything
        ctx[i] = r
        if not passes(levelFilters[i], ctx) then return false end
        return level(i + 1)
    end

    level = function(i)
        if i > nsrc then return onRow(ctx) end
        Tick()
        local src = sources[i]
        local def = src.def
        if i == 1 then
            local hints = keyHints(whereConj, src)
            if hints then
                if hints.range then
                    for id = hints.range[1], hints.range[2] do
                        Tick()
                        local r = def.lookup(id)
                        if r and visit(1, r) then return true end
                    end
                else
                    local seen = {}
                    for _, key in ipairs(hints) do
                        local nk = normKey(key)
                        if not seen[nk] then
                            seen[nk] = true
                            local r = def.lookup(key)
                            if r and visit(1, r) then return true end
                        end
                    end
                end
                return false
            end
            local stopped = false
            E.ForEachRow(def, function(r)
                Tick()
                if visit(1, r) then stopped = true; return true end
            end)
            return stopped
        end

        local plan = joinPlans[i]
        local ons = onFilters[i]
        local isLeft = src.ref.join == "left"
        local matched = false
        local function try(r)
            ctx[i] = r
            if not passes(ons, ctx) then return false end
            matched = true
            return visit(i, r)
        end

        if plan and plan.colName == def.key and def.lookup and def.kind == "scan" then
            local kv = plan.other(ctx)
            if kv ~= nil then
                local r = def.lookup(kv)
                if r and try(r) then return true end
            end
        elseif plan then
            local h = hashes[i]
            if not h then
                h = {}
                local tmp = {}
                for _, r in ipairs(materialized(i, def)) do
                    Tick()
                    tmp[i] = r
                    local v = plan.mine(tmp)
                    if v ~= nil then
                        local nk = normKey(v)
                        local bucket = h[nk]
                        if not bucket then bucket = {}; h[nk] = bucket end
                        bucket[#bucket + 1] = r
                    end
                end
                hashes[i] = h
            end
            local kv = plan.other(ctx)
            local bucket = kv ~= nil and h[normKey(kv)]
            if bucket then
                for j = 1, #bucket do
                    if try(bucket[j]) then return true end
                end
            end
        else
            local rows = materialized(i, def)
            for j = 1, #rows do
                Tick()
                if try(rows[j]) then return true end
            end
        end

        if isLeft and not matched then
            if visit(i, false) then return true end
        end
        ctx[i] = nil
        return false
    end

    if constOk then
        if nsrc == 0 then
            onRow(ctx)
        else
            level(1)
        end
    end

    -- groups -> records ------------------------------------------------------------
    if grouped then
        if #groupList == 0 and not q.group then
            local g = { ctx = {}, states = {} }
            for i, agg in ipairs(aggs) do g.states[i] = aggNew(agg) end
            groupList[1] = g
        end
        for _, g in ipairs(groupList) do
            Tick()
            local gctx = g.ctx
            local vals = {}
            for i, agg in ipairs(aggs) do vals[i] = aggFinal(agg, g.states[i]) end
            gctx.agg = vals
            if not havingFn or truth(havingFn(gctx)) == true then
                project(gctx)
            end
        end
    end

    -- DISTINCT ----------------------------------------------------------------------
    if q.distinct then
        local seen, kept = {}, {}
        for _, rec in ipairs(records) do
            Tick()
            local parts = {}
            for i = 1, nOut do parts[i] = keyString(rec.vals[i]) end
            local key = table.concat(parts, "\31")
            if not seen[key] then seen[key] = true; kept[#kept + 1] = rec end
        end
        records = kept
    end

    -- ORDER BY --------------------------------------------------------------------
    if #orderFns > 0 then
        for i, rec in ipairs(records) do rec.idx = i end
        local nk = #orderFns
        table.sort(records, function(x, y)
            local kx, ky = x.keys, y.keys
            for i = 1, nk do
                local c = sortCmp(kx[i], ky[i])
                if c ~= 0 then
                    if orderFns[i].desc then return c > 0 end
                    return c < 0
                end
            end
            return x.idx < y.idx
        end)
    end

    -- OFFSET / LIMIT / cap -------------------------------------------------------
    local rows = {}
    local total = #records
    local last = total
    if limit then last = math.min(total, offset + limit) end
    local truncated = false
    if maxRows and last - offset > maxRows then
        last = offset + maxRows
        truncated = true
    end
    for i = offset + 1, last do rows[#rows + 1] = records[i].vals end

    local res = {
        columns = outCols,
        rows = rows,
        truncated = truncated,
        elapsedMs = E.NowMs() - t0,
    }
    if q.into and not opts.inner then
        E.CreateUserTable(q.into, res)
        res.message = format("Created table %s with %d rows", lower(q.into), #rows)
    end
    return res
end

---------------------------------------------------------------------------
-- Statements
---------------------------------------------------------------------------
local HELP = {
    "SELECT cols FROM table [JOIN t2 ON ...] [WHERE ...] [GROUP BY ...] [HAVING ...] [ORDER BY ... DESC] [LIMIT n]",
    "SHOW TABLES  |  DESCRIBE table  |  SCAN abilities|items  |  REFRESH table|ALL  |  DROP TABLE name",
    "SELECT ... INTO name FROM ...  saves the result as a table you can query later",
    "Text matching is case-insensitive.  LIKE '%fire%'   MATCH(name, 'Lua pattern')",
    "Functions: LOWER UPPER LENGTH SUBSTR REPLACE INSTR CONTAINS TRIM ROUND ABS COALESCE IIF CASE CAST PRINTF CLEAN ICON ENUM",
    "Game lookups: ABILITY_NAME(id) ABILITY_DESC(id) ABILITY_ICON(id) SET_NAME(id) ZONE_NAME(id) ITEM_NAME(id) ITEM_LINK(id) COLLECTIBLE_NAME(id)",
    "Aggregates: COUNT(*) COUNT(DISTINCT x) SUM AVG MIN MAX TOTAL GROUP_CONCAT(x, ', ')",
    "Examples: SELECT * FROM abilities WHERE name LIKE '%rune%' LIMIT 50",
    "          SELECT line_name, COUNT(*) FROM skills GROUP BY line_name ORDER BY 2 DESC",
    "          SELECT s.name, b.num_required, b.description FROM sets s JOIN set_bonuses b ON b.set_id = s.id WHERE s.name LIKE 'mother%'",
}
SQL.HELP = HELP

local function messageResult(lines)
    local rows = {}
    for i, l in ipairs(lines) do rows[i] = { l } end
    return { columns = { "info" }, rows = rows, elapsedMs = 0 }
end

function SQL.ExecuteStatement(stmt, opts)
    local k = stmt.k
    if k == "select" then return SQL.ExecuteSelect(stmt, opts) end
    if k == "show" then
        return SQL.Run("SELECT name, kind, description FROM tables ORDER BY name", opts)
    elseif k == "describe" then
        local name = lower(stmt.name)
        if not E.GetTable(name) then fail("no table '%s'", name) end
        return SQL.Run(format("SELECT column_name, type, description FROM columns WHERE table_name = '%s' ORDER BY position", name), opts)
    elseif k == "drop" then
        local ok, msg = E.DropUserTable(lower(stmt.name))
        if not ok then fail(msg) end
        return messageResult({ msg })
    elseif k == "refresh" then
        local n = E.RefreshTables(not stmt.all and lower(stmt.name) or nil)
        return messageResult({ format("Cleared cached rows for %d table(s)", n) })
    elseif k == "scan" then
        local name = lower(stmt.name)
        local def = E.GetTable(name)
        if not def or not def.scan then fail("SCAN works on: abilities, items") end
        E.ResetScan(def)
        local count = E.EnsureScanned(def)
        return messageResult({ format("%s: indexed %d ids", name, count) })
    elseif k == "help" then
        return messageResult(HELP)
    end
    fail("unknown statement")
end

-- Run SQL text. Call from inside E.RunAsync / E.RunSync (it may yield).
function SQL.Run(text, opts)
    local stmt = SQL.Parse(text, opts and opts.params)
    return SQL.ExecuteStatement(stmt, opts)
end

-- Error objects -> readable text
function SQL.ErrorText(err)
    if type(err) == "table" and err.esql then return err.msg end
    return tostring(err)
end
