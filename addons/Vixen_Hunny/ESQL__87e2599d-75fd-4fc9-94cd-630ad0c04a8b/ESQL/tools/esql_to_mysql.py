#!/usr/bin/env python3
"""
esql_to_mysql.py - turn ESQL / LibESQL SavedVariables into a MySQL dump for phpMyAdmin.

What goes into the dump:
  * every export you saved in the game with  /esql export <name>   ->  table esql_<name>
  * every table you created in the game (CREATE TABLE, SELECT ... INTO) -> table <name>

Usage (Windows: open a terminal in this folder, or double-click to use the defaults):
  python esql_to_mysql.py                      find SavedVariables and write esql_dump.sql
  python esql_to_mysql.py -o my.sql            choose the output file
  python esql_to_mysql.py --sv-dir "C:/Users/me/Documents/Elder Scrolls Online/live/SavedVariables"
  python esql_to_mysql.py --database eso       add CREATE DATABASE / USE eso
  python esql_to_mysql.py --only esql_export,notes   only these tables
  python esql_to_mysql.py --clean              strip ESO colour codes, icons and link markup
  python esql_to_mysql.py --list               show what would be exported, write nothing

Then in phpMyAdmin: pick (or create) a database > Import > choose the .sql file > Go.

SavedVariables are written by the game on /reloadui or logout, so do one of those first.
Needs Python 3.7+ and nothing else. MIT licensed, part of ESQL.
"""

import argparse
import datetime
import math
import os
import re
import sys

INT32 = 2147483647

# --------------------------------------------------------------------------
# Reading SavedVariables (a Lua file of `Name = { ... }` assignments)
# --------------------------------------------------------------------------

class LuaParseError(Exception):
    pass


class _Parser:
    """Parses the Lua table syntax ESO writes into SavedVariables."""

    def __init__(self, data):
        self.s = data          # bytes
        self.i = 0
        self.n = len(data)

    def error(self, msg):
        line = self.s.count(b"\n", 0, self.i) + 1
        raise LuaParseError("%s at line %d" % (msg, line))

    def skip(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in b" \t\r\n,;":
                self.i += 1
            elif s.startswith(b"--", self.i):
                if s.startswith(b"--[[", self.i):
                    end = s.find(b"]]", self.i)
                    self.i = n if end < 0 else end + 2
                else:
                    end = s.find(b"\n", self.i)
                    self.i = n if end < 0 else end + 1
            else:
                break

    def peek(self):
        self.skip()
        return self.s[self.i:self.i + 1]

    def expect(self, ch):
        self.skip()
        if self.s[self.i:self.i + 1] != ch:
            self.error("expected %r" % ch.decode())
        self.i += 1

    def name(self):
        self.skip()
        m = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*").match(self.s, self.i)
        if not m:
            self.error("expected a name")
        self.i = m.end()
        return m.group().decode()

    def string(self):
        q = self.s[self.i:self.i + 1]
        self.i += 1
        out = bytearray()
        s = self.s
        while True:
            if self.i >= self.n:
                self.error("unterminated string")
            c = s[self.i]
            if c == q[0]:
                self.i += 1
                break
            if c == 0x5C:  # backslash
                self.i += 1
                e = s[self.i:self.i + 1]
                simple = {b"n": b"\n", b"t": b"\t", b"r": b"\r", b"a": b"\a", b"b": b"\b",
                          b"f": b"\f", b"v": b"\v", b"\\": b"\\", b'"': b'"', b"'": b"'", b"\n": b"\n"}
                if e in simple:
                    out += simple[e]
                    self.i += 1
                elif e.isdigit():
                    m = re.compile(rb"\d{1,3}").match(s, self.i)
                    out.append(int(m.group()) & 0xFF)
                    self.i = m.end()
                else:
                    out += e
                    self.i += 1
            else:
                out.append(c)
                self.i += 1
        return out.decode("utf-8", errors="replace")

    def number(self):
        m = re.compile(rb"-?(?:0[xX][0-9A-Fa-f]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)").match(self.s, self.i)
        if not m:
            self.error("bad number")
        self.i = m.end()
        text = m.group().decode()
        if text.lower().lstrip("-").startswith("0x"):
            return int(text, 16)
        v = float(text)
        if v.is_integer() and "e" not in text.lower() and abs(v) < 2 ** 63:
            return int(v)
        return v

    def value(self):
        c = self.peek()
        if c == b"{":
            return self.table()
        if c in (b'"', b"'"):
            return self.string()
        if c == b"-" or c.isdigit() or c == b".":
            return self.number()
        word = self.name()
        if word == "true":
            return True
        if word == "false":
            return False
        if word == "nil":
            return None
        if word == "math" and self.peek() == b".":       # math.huge
            self.i += 1
            self.name()
            return float("inf")
        self.error("unexpected %r" % word)

    def table(self):
        self.expect(b"{")
        result = {}
        auto = 1
        while True:
            c = self.peek()
            if c == b"}":
                self.i += 1
                return result
            if c == b"[":
                self.i += 1
                key = self.value()
                self.expect(b"]")
                self.expect(b"=")
                result[key] = self.value()
            else:
                save = self.i
                m = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*\s*=(?!=)").match(self.s, self.i)
                if m:
                    key = self.name()
                    self.expect(b"=")
                    result[key] = self.value()
                else:
                    self.i = save
                    result[auto] = self.value()
                    auto += 1

    def file(self):
        out = {}
        while True:
            self.skip()
            if self.i >= self.n:
                return out
            name = self.name()
            self.expect(b"=")
            out[name] = self.value()


def read_saved_variables(path):
    with open(path, "rb") as f:
        return _Parser(f.read()).file()


def find_dicts_with(obj, key, path=()):
    """Yield (path, dict) for every dict in obj that contains `key`."""
    if isinstance(obj, dict):
        if key in obj:
            yield path, obj
        for k, v in obj.items():
            yield from find_dicts_with(v, key, path + (k,))


def as_list(t):
    """Lua array table {1=..,2=..} -> Python list (holes become None)."""
    if isinstance(t, list):
        return t
    if not isinstance(t, dict) or not t:
        return []
    keys = [k for k in t if isinstance(k, int) and k >= 1]
    if not keys:
        return []
    return [t.get(i) for i in range(1, max(keys) + 1)]


def account_of(path):
    for p in path:
        if isinstance(p, str) and p.startswith("@"):
            return p
    return ""

# --------------------------------------------------------------------------
# Collecting tables
# --------------------------------------------------------------------------

def collect(esql_sv, libesql_sv):
    """Returns [ {name, columns, types, rows, comment} ]"""
    tables = []
    # exports: ESQL_SV ... exports[name] (and the older single `export`)
    if esql_sv is not None:
        seen_ids = set()
        for path, d in find_dicts_with(esql_sv, "exports"):
            exports = d.get("exports") or {}
            if isinstance(exports, dict):
                for name, x in sorted(exports.items(), key=lambda kv: str(kv[0])):
                    if isinstance(x, dict):
                        seen_ids.add(id(x))
                        tables.append(_table_from_export("esql_" + str(name), x, path))
        for path, d in find_dicts_with(esql_sv, "export"):
            x = d.get("export")
            if isinstance(x, dict) and not d.get("exports"):
                tables.append(_table_from_export("esql_export", x, path))
    # user tables: LibESQL_SV ... userTables[name]
    if libesql_sv is not None:
        for path, d in find_dicts_with(libesql_sv, "userTables"):
            ut = d.get("userTables") or {}
            if isinstance(ut, dict):
                for name, t in sorted(ut.items(), key=lambda kv: str(kv[0])):
                    if not isinstance(t, dict):
                        continue
                    columns = [str(c) for c in as_list(t.get("columns"))]
                    types = as_list(t.get("types"))
                    rows = [as_list(r) for r in as_list(t.get("rows"))]
                    tables.append({
                        "name": str(name), "columns": columns, "types": types, "rows": rows,
                        "comment": "Your table from LibESQL" + (" (" + account_of(path) + ")" if account_of(path) else ""),
                    })
    # unique names (several accounts can have the same table)
    used = {}
    for t in tables:
        base = mysql_table_name(t["name"])
        name, k = base, 1
        while name in used:
            k += 1
            name = "%s_%d" % (base, k)
        used[name] = True
        t["name"] = name
    return tables


def _table_from_export(name, x, path):
    columns = [str(c) for c in as_list(x.get("columns"))]
    rows = [as_list(r) for r in as_list(x.get("rows"))]
    when = x.get("time")
    comment = "Export from ESQL"
    if x.get("query"):
        comment += ": " + str(x["query"])
    if isinstance(when, (int, float)):
        comment += " (saved %s UTC)" % datetime.datetime.utcfromtimestamp(when).strftime("%Y-%m-%d %H:%M")
    return {"name": name, "columns": columns, "types": [], "rows": rows, "comment": comment}

# --------------------------------------------------------------------------
# MySQL output (same rules as LibESQL_Export.lua)
# --------------------------------------------------------------------------

def mysql_table_name(name):
    n = re.sub(r"[^0-9A-Za-z_]", "_", str(name or "").lower())
    n = re.sub(r"_+", "_", n).strip("_")
    if not n:
        n = "esql_export"
    if n[0].isdigit():
        n = "t_" + n
    return n[:64]


def ident(name):
    return "`" + str(name).replace("`", "``") + "`"


_MARKUP = [
    (re.compile(r"\|[cC][0-9A-Fa-f]{6}"), ""), (re.compile(r"\|[rR]"), ""),
    (re.compile(r"\|t[^|]*\|t"), ""), (re.compile(r"\|H[^|]*\|h([^|]*)\|h"), r"\1"),
]


def clean_markup(s):
    for pat, rep in _MARKUP:
        s = pat.sub(rep, s)
    return s


def mysql_value(v, clean=False):
    if v is None:
        return "NULL"
    if v is True:
        return "1"
    if v is False:
        return "0"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if math.isnan(v) or math.isinf(v):
            return "NULL"
        if v.is_integer() and abs(v) < 2 ** 53:
            return str(int(v))
        return repr(v)
    s = str(v)
    if clean:
        s = clean_markup(s)
    s = (s.replace("\\", "\\\\").replace("'", "\\'").replace("\0", "\\0")
          .replace("\n", "\\n").replace("\r", "\\r").replace("\x1a", "\\Z"))
    return "'" + s + "'"


def mysql_column_type(values, declared=None, clean=False):
    if declared == "int":
        return "bigint(20)"
    if declared == "num":
        return "double"
    if declared == "bool":
        return "tinyint(1)"
    vals = [v for v in values if v is not None]
    if declared != "text" and vals:
        if all(isinstance(v, bool) for v in vals):
            return "tinyint(1)"
        if all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in vals):
            if all(float(v).is_integer() for v in vals):
                return "bigint(20)" if any(abs(v) > INT32 for v in vals) else "int(11)"
            return "double"
    max_len = 0
    for v in vals:
        s = str(v) if not isinstance(v, bool) else ("1" if v else "0")
        if clean and isinstance(v, str):
            s = clean_markup(s)
        max_len = max(max_len, len(s.encode("utf-8")))
    if max_len <= 255:
        return "varchar(255)"
    if max_len <= 65535:
        return "text"
    return "mediumtext"


def table_sql(t, drop=True, clean=False, rows_per_insert=500, max_insert_bytes=1000000):
    name = t["name"]
    columns = t["columns"] or ["value"]
    ncol = len(columns)
    rows = [list(r) + [None] * (ncol - len(r)) for r in t["rows"]]
    names, used = [], set()
    for c, col in enumerate(columns):
        base = re.sub(r"^.*\.", "", str(col)) or "col%d" % (c + 1)
        n, k = base, 1
        while n.lower() in used:
            k += 1
            n = "%s_%d" % (base, k)
        used.add(n.lower())
        names.append(n)
    out = ["-- --------------------------------------------------------", "", "--",
           "-- Table structure for table " + ident(name), "--"]
    if t.get("comment"):
        out.append("-- " + re.sub(r"[\r\n]+", " ", t["comment"]))
    out.append("")
    if drop:
        out.append("DROP TABLE IF EXISTS %s;" % ident(name))
    types = t.get("types") or []
    defs = []
    for c in range(ncol):
        declared = types[c] if c < len(types) else None
        defs.append("  %s %s DEFAULT NULL" % (ident(names[c]), mysql_column_type([r[c] for r in rows], declared, clean)))
    out.append("CREATE TABLE %s (\n%s\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;" % (ident(name), ",\n".join(defs)))
    if rows:
        out += ["", "--", "-- Dumping data for table " + ident(name), "--", ""]
        head = "INSERT INTO %s (%s) VALUES\n" % (ident(name), ", ".join(ident(n) for n in names))
        tuples, size = [], len(head)
        for r in rows:
            tup = "(" + ", ".join(mysql_value(v, clean) for v in r[:ncol]) + ")"
            if tuples and (len(tuples) >= rows_per_insert or size + len(tup) + 2 > max_insert_bytes):
                out.append(head + ",\n".join(tuples) + ";")
                tuples, size = [], len(head)
            tuples.append(tup)
            size += len(tup) + 2
        if tuples:
            out.append(head + ",\n".join(tuples) + ";")
    return "\n".join(out)


def dump(tables, database=None, drop=True, clean=False):
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out = [
        "-- MySQL dump made by ESQL (Elder Scrolls Online) - esql_to_mysql.py",
        "-- phpMyAdmin compatible. Generated %s" % now,
        "-- Tables: %s" % (", ".join(t["name"] for t in tables) or "(none)"),
        "",
        'SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";',
        "START TRANSACTION;",
        'SET time_zone = "+00:00";',
        "SET NAMES utf8mb4;",
        "",
    ]
    if database:
        db = ident(database)
        out += ["CREATE DATABASE IF NOT EXISTS %s DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" % db,
                "USE %s;" % db, ""]
    for t in tables:
        out.append(table_sql(t, drop=drop, clean=clean))
        out.append("")
    out.append("COMMIT;")
    return "\n".join(out) + "\n"

# --------------------------------------------------------------------------
# Finding the files
# --------------------------------------------------------------------------

def candidate_dirs():
    homes = [os.path.expanduser("~")]
    for env in ("USERPROFILE", "OneDrive"):
        if os.environ.get(env):
            homes.append(os.environ[env])
    seen, dirs = set(), []
    roots = [os.path.join(h, docs) for h in homes for docs in ("Documents", "OneDrive/Documents", "My Documents", "")]
    if os.environ.get("LOCALAPPDATA"):
        roots.append(os.environ["LOCALAPPDATA"])
    for root in roots:
        for server in ("live", "pts", "pccert", "xb1cert"):
            d = os.path.normpath(os.path.join(root, "Elder Scrolls Online", server, "SavedVariables"))
            real = os.path.normcase(os.path.realpath(d))   # "My Documents" is a link to "Documents"
            if real not in seen:
                seen.add(real)
                dirs.append(d)
    return dirs


def console_clients():
    """ESO clients that use the console UI and keep add-on data off-disk (pccert, xb1cert)."""
    found = []
    base = os.environ.get("LOCALAPPDATA")
    if base:
        for server in ("pccert", "xb1cert"):
            if os.path.isdir(os.path.join(base, "Elder Scrolls Online", server, "CachedData", "AddOnsManaged", "ESQL")):
                found.append(server)
    return found


NOT_FOUND_HELP = """
Why: the game writes SavedVariables files only from the PC clients (live, pts),
on /reloadui or logout. %s
Two ways to get your data out:
  1. Install ESQL and LibESQL in the PTS or live client
     (Documents\\Elder Scrolls Online\\pts\\AddOns), run your queries there,
     /esql export <name>, /reloadui, then run this script again.
  2. In any client: open the Copy window, switch the format to MySQL (.sql),
     Select all + Ctrl+C each page in order, and paste them into one .sql file.
"""


def find_sv_dir(explicit=None):
    if explicit:
        return explicit
    found = [d for d in candidate_dirs()
             if os.path.isfile(os.path.join(d, "ESQL.lua")) or os.path.isfile(os.path.join(d, "LibESQL.lua"))]
    if not found:
        return None
    # most recently written first
    found.sort(key=lambda d: max(os.path.getmtime(os.path.join(d, f)) for f in ("ESQL.lua", "LibESQL.lua")
                                 if os.path.isfile(os.path.join(d, f))), reverse=True)
    return found[0]


def load(sv_dir):
    esql = libesql = None
    p = os.path.join(sv_dir, "ESQL.lua")
    if os.path.isfile(p):
        esql = read_saved_variables(p).get("ESQL_SV")
    p = os.path.join(sv_dir, "LibESQL.lua")
    if os.path.isfile(p):
        libesql = read_saved_variables(p).get("LibESQL_SV")
    return esql, libesql


def main(argv=None):
    ap = argparse.ArgumentParser(description="Turn ESQL / LibESQL SavedVariables into a phpMyAdmin .sql dump.")
    ap.add_argument("--sv-dir", help="the SavedVariables folder (default: found automatically)")
    ap.add_argument("-o", "--output", default="esql_dump.sql", help="output file (default esql_dump.sql)")
    ap.add_argument("--database", help="also CREATE DATABASE IF NOT EXISTS and USE this database")
    ap.add_argument("--only", help="comma-separated table names to include")
    ap.add_argument("--no-exports", action="store_true", help="leave out /esql export results")
    ap.add_argument("--no-user-tables", action="store_true", help="leave out your CREATE TABLE / INTO tables")
    ap.add_argument("--no-drop", action="store_true", help="don't add DROP TABLE IF EXISTS")
    ap.add_argument("--clean", action="store_true", help="strip ESO colour codes, icons and link markup from text")
    ap.add_argument("--list", action="store_true", help="only list what would be exported")
    args = ap.parse_args(argv)

    sv_dir = find_sv_dir(args.sv_dir)
    if not sv_dir or not os.path.isdir(sv_dir):
        print("Couldn't find ESQL.lua or LibESQL.lua in any SavedVariables folder.")
        existing = [d for d in candidate_dirs() if os.path.isdir(d)]
        if existing:
            print("SavedVariables folders on this PC (none has ESQL data yet):")
            for d in existing:
                print("  " + d)
        consoles = console_clients()
        note = ""
        if consoles:
            if len(consoles) == 1:
                note = ("You have ESQL in the %s client, which uses the console UI and keeps\n"
                        "add-on data off this PC, so it never writes these files." % consoles[0])
            else:
                note = ("You have ESQL in the %s clients, which use the console UI and keep\n"
                        "add-on data off this PC, so they never write these files." % " and ".join(consoles))
        print(NOT_FOUND_HELP % note)
        print("If your files are somewhere else, pass --sv-dir \"<folder>\".")
        return 1
    try:
        esql, libesql = load(sv_dir)
    except LuaParseError as e:
        print("Couldn't read the SavedVariables in %s: %s" % (sv_dir, e))
        return 1
    tables = collect(None if args.no_exports else esql, None if args.no_user_tables else libesql)
    if args.only:
        wanted = {mysql_table_name(n) for n in args.only.split(",") if n.strip()}
        tables = [t for t in tables if t["name"] in wanted]
    print("SavedVariables: " + sv_dir)
    if not tables:
        print("Nothing to export. In the game: run a query, then /esql export <name>, then /reloadui.")
        return 1
    for t in tables:
        print("  %-30s %6d rows  %d columns" % (t["name"], len(t["rows"]), len(t["columns"])))
    if args.list:
        return 0
    sql = dump(tables, database=args.database, drop=not args.no_drop, clean=args.clean)
    with open(args.output, "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)
    print("Wrote %s (%d tables, %.1f KB). Import it in phpMyAdmin: Import > choose file > Go."
          % (os.path.abspath(args.output), len(tables), len(sql.encode("utf-8")) / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
