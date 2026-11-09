#!/usr/bin/env python3
"""
Lethal PVP Insights - Encounter.log importer

ESO addons cannot read files, so this small tool reads the game's encounter log
(Documents/Elder Scrolls Online/live/Logs/Encounter.log), extracts every player's
gear (sets, traits, enchants) and front/back skill bars from PLAYER_INFO lines, and
writes them to LPI_Imported.lua inside the addon folder. The addon loads
that file on the next /reloadui.

Usage:
    python LPI_Import.py                 # auto-detect paths (script lives in the addon folder)
    python LPI_Import.py --log PATH      # custom Encounter.log
    python LPI_Import.py --reset         # forget previous imports and re-read the whole log

Only the part of the log that was added since the last run is read, so it stays fast
even when Encounter.log is very large. Standard library only.
"""
import argparse
import hashlib
import json
import os
import sys
import time

MAX_ACCOUNTS = 200        # same cap as the in-game group history
MAX_VARIANTS = 5          # distinct builds kept per account (newest first)
OUT_NAME = "LPI_Imported.lua"
CACHE_NAME = "LPI_import_cache.json"
WANTED = {"BEGIN_LOG", "ZONE_CHANGED", "UNIT_ADDED", "UNIT_CHANGED", "PLAYER_INFO", "ABILITY_INFO"}


# --------------------------------------------------------------------------
# Line parsing: comma separated, "quoted strings", [nested,[lists]]
# --------------------------------------------------------------------------
def parse_fields(s):
    stack = [[]]
    buf = []
    pending = False
    in_q = False
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if in_q:
            if c == '"':
                if i + 1 < n and s[i + 1] == '"':
                    buf.append('"')
                    i += 1
                else:
                    in_q = False
            else:
                buf.append(c)
        elif c == '"':
            in_q = True
            pending = True
        elif c == '[':
            stack.append([])
        elif c == ']' or c == ',':
            if pending:
                stack[-1].append("".join(buf))
                buf, pending = [], False
            if c == ']' and len(stack) > 1:
                lst = stack.pop()
                stack[-1].append(lst)
        else:
            buf.append(c)
            pending = True
        i += 1
    if pending:
        stack[-1].append("".join(buf))
    return stack[0]


def to_int(v, default=0):
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def as_list(v):
    return v if isinstance(v, list) else []


# --------------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------------
def default_paths():
    addon_dir = os.path.dirname(os.path.abspath(__file__))
    # .../live/AddOns/LethalPVPInsights -> .../live/Logs/Encounter.log
    live_dir = os.path.dirname(os.path.dirname(addon_dir))
    log = os.path.join(live_dir, "Logs", "Encounter.log")
    if not os.path.isfile(log):
        home = os.path.expanduser("~")
        for docs in (os.path.join(home, "Documents"), os.path.join(home, "OneDrive", "Documents")):
            for realm in ("live", "liveeu", "pts"):
                cand = os.path.join(docs, "Elder Scrolls Online", realm, "Logs", "Encounter.log")
                if os.path.isfile(cand):
                    return addon_dir, cand
    return addon_dir, log


# --------------------------------------------------------------------------
# Cache
# --------------------------------------------------------------------------
def load_cache(path):
    if os.path.isfile(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            pass
    return {"offset": 0, "size": 0, "epoch": 0, "zone": "", "units": {}, "abilities": {}, "accounts": {}}


def save_cache(path, cache):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cache, f)
    os.replace(tmp, path)


# --------------------------------------------------------------------------
# Import
# --------------------------------------------------------------------------
def unit_from_added(f):
    # ts,UNIT_ADDED,unitId,unitType,isLocalPlayer,playerPerSessionId,monsterId,isBoss,classId,raceId,
    # name,displayName,characterId,level,championPoints,ownerUnitId,reaction,isGroupedWithLocalPlayer
    return {
        "type": f[3] if len(f) > 3 else "",
        "local": (f[4] == "T") if len(f) > 4 else False,
        "cls": to_int(f[8]) if len(f) > 8 else 0,
        "race": to_int(f[9]) if len(f) > 9 else 0,
        "char": f[10] if len(f) > 10 else "",
        "acct": f[11] if len(f) > 11 else "",
        "level": to_int(f[13]) if len(f) > 13 else 0,
        "cp": to_int(f[14]) if len(f) > 14 else 0,
        "reaction": f[16] if len(f) > 16 else "",
        "grouped": (f[17] == "T") if len(f) > 17 else False,
    }


def unit_from_changed(u, f):
    # ts,UNIT_CHANGED,unitId,classId,raceId,name,displayName,characterId,level,championPoints,
    # ownerUnitId,reaction,isGroupedWithLocalPlayer
    if len(f) > 3: u["cls"] = to_int(f[3], u.get("cls", 0))
    if len(f) > 4: u["race"] = to_int(f[4], u.get("race", 0))
    if len(f) > 5 and f[5]: u["char"] = f[5]
    if len(f) > 6 and f[6]: u["acct"] = f[6]
    if len(f) > 8: u["level"] = to_int(f[8], u.get("level", 0))
    if len(f) > 9: u["cp"] = to_int(f[9], u.get("cp", 0))
    if len(f) > 11 and f[11]: u["reaction"] = f[11]
    if len(f) > 12: u["grouped"] = f[12] == "T"


def parse_gear(raw):
    gear = []
    for g in as_list(raw):
        g = as_list(g)
        if len(g) < 7:
            continue
        gear.append({
            "slot": g[0], "item": to_int(g[1]), "cp": g[2] == "T", "lvl": to_int(g[3]),
            "trait": g[4], "q": g[5], "set": to_int(g[6]),
            "ench": g[7] if len(g) > 7 else "", "enchCP": (g[8] == "T") if len(g) > 8 else False,
            "enchLvl": to_int(g[9]) if len(g) > 9 else 0, "enchQ": g[10] if len(g) > 10 else "",
        })
    return gear


def variant_hash(v):
    key = json.dumps([[(g["slot"], g["item"], g["trait"], g["set"], g["ench"]) for g in v["gear"]],
                      v["bar1"], v["bar2"]], sort_keys=True)
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:12]


def handle_player_info(cache, f, ts):
    # ts,PLAYER_INFO,unitId,[effects],[effectStacks],[[gear]...],[frontBar],[backBar]
    u = cache["units"].get(f[2]) if len(f) > 2 else None
    if not u or u.get("local"):
        return False
    key = u.get("acct")
    if not key:
        # Players with "appear anonymous in encounter logs" have empty names. Keep grouped ones under a
        # class/race/CP key - the addon matches them to the right group member in game.
        if not (u.get("grouped") and u.get("cls")):
            return False
        key = "#anon:{}:{}:{}".format(u.get("cls", 0), u.get("race", 0), u.get("cp", 0))
    variant = {
        "seen": int((cache["epoch"] + ts) / 1000) if cache["epoch"] else int(time.time()),
        "zone": cache.get("zone", ""),
        "effects": [to_int(x) for x in as_list(f[3] if len(f) > 3 else [])],
        "gear": parse_gear(f[5] if len(f) > 5 else []),
        "bar1": [to_int(x) for x in as_list(f[6] if len(f) > 6 else [])],
        "bar2": [to_int(x) for x in as_list(f[7] if len(f) > 7 else [])],
    }
    if not variant["gear"] and not variant["bar1"]:
        return False
    variant["hash"] = variant_hash(variant)

    acc = cache["accounts"].setdefault(key, {"variants": []})
    for k in ("char", "cls", "race", "level", "cp", "reaction"):
        if u.get(k):
            acc[k] = u[k]
    acc["grouped"] = acc.get("grouped", False) or u.get("grouped", False)
    if key.startswith("#anon:"):
        acc["anon"] = True
    acc["last"] = variant["seen"]

    variants = [v for v in acc["variants"] if v.get("hash") != variant["hash"]]
    variants.insert(0, variant)
    acc["variants"] = variants[:MAX_VARIANTS]
    return True


def read_head(path):
    """First line of the log - identifies the file so a deleted and re-created log is read from the start."""
    with open(path, "rb") as f:
        return f.readline(200).decode("utf-8", errors="replace")


def import_log(log_path, cache):
    size = os.path.getsize(log_path)
    head = read_head(log_path)
    if size < cache.get("offset", 0) or cache.get("head") != head:   # log was deleted / restarted
        cache["offset"], cache["units"] = 0, {}
    cache["head"] = head
    found = 0
    lines = 0
    with open(log_path, "rb") as fh:
        fh.seek(cache.get("offset", 0))
        while True:
            raw = fh.readline()
            if not raw:
                break
            if not raw.endswith(b"\n"):          # partial line still being written
                fh.seek(-len(raw), os.SEEK_CUR)
                break
            lines += 1
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
            head = line.split(",", 2)
            if len(head) < 2 or head[1] not in WANTED:
                continue
            ev = head[1]
            f = parse_fields(line)
            ts = to_int(f[0])
            if ev == "BEGIN_LOG":
                cache["epoch"] = to_int(f[2]) if len(f) > 2 else 0
                cache["units"] = {}
            elif ev == "ZONE_CHANGED":
                cache["zone"] = f[3] if len(f) > 3 else ""
            elif ev == "UNIT_ADDED":
                if len(f) > 3 and f[3] == "PLAYER":
                    cache["units"][f[2]] = unit_from_added(f)
            elif ev == "UNIT_CHANGED":
                u = cache["units"].get(f[2]) if len(f) > 2 else None
                if u:
                    unit_from_changed(u, f)
            elif ev == "ABILITY_INFO":
                if len(f) > 3:
                    cache["abilities"][f[2]] = f[3]
            elif ev == "PLAYER_INFO":
                if handle_player_info(cache, f, ts):
                    found += 1
        cache["offset"] = fh.tell()
    cache["size"] = size
    return found, lines


def trim_accounts(cache):
    accs = cache["accounts"]
    if len(accs) <= MAX_ACCOUNTS:
        return
    keep = sorted(accs.items(), key=lambda kv: kv[1].get("last", 0), reverse=True)[:MAX_ACCOUNTS]
    cache["accounts"] = dict(keep)


# --------------------------------------------------------------------------
# Lua output
# --------------------------------------------------------------------------
def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_val(v, indent=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in v):
            return "{" + ",".join(str(x) for x in v) + "}"
        inner = indent + "  "
        return "{\n" + "".join(inner + lua_val(x, inner) + ",\n" for x in v) + indent + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        inner = indent + "  "
        parts = []
        for k in sorted(v.keys(), key=str):
            key = "[" + (str(k) if isinstance(k, int) else lua_str(k)) + "]"
            parts.append(inner + key + "=" + lua_val(v[k], inner) + ",\n")
        return "{\n" + "".join(parts) + indent + "}"
    return "nil"


def write_lua(path, cache):
    builds = {}
    for acct, a in cache["accounts"].items():
        names = {}
        for v in a["variants"]:
            for aid in v["bar1"] + v["bar2"]:
                n = cache["abilities"].get(str(aid))
                if n:
                    names[aid] = n
        entry = {k: a[k] for k in ("char", "cls", "race", "level", "cp", "reaction", "grouped", "last", "anon") if k in a}
        entry["variants"] = [{k: v[k] for k in ("seen", "zone", "effects", "gear", "bar1", "bar2", "hash")}
                             for v in a["variants"]]
        entry["names"] = names
        builds[acct] = entry
    data = {"generated": int(time.time()), "builds": builds}
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("-- Generated by LPI_Import.py - do not edit, it is overwritten on each import\n")
        f.write("PVPDataInsight_Imported = " + lua_val(data) + "\n")
    os.replace(tmp, path)
    return len(builds)


def run_import(log_path, addon_dir, reset=False):
    """Import new lines from log_path. Returns dict with found/lines/total/seconds."""
    cache_path = os.path.join(addon_dir, CACHE_NAME)
    cache = load_cache("") if reset else load_cache(cache_path)
    t0 = time.time()
    found, lines = import_log(log_path, cache)
    trim_accounts(cache)
    total = write_lua(os.path.join(addon_dir, OUT_NAME), cache)
    used = {str(a) for acc in cache["accounts"].values() for v in acc["variants"] for a in v["bar1"] + v["bar2"]}
    cache["abilities"] = {k: n for k, n in cache["abilities"].items() if k in used}
    save_cache(cache_path, cache)
    return {"found": found, "lines": lines, "total": total, "seconds": time.time() - t0}


def main():
    addon_dir, log_default = default_paths()
    ap = argparse.ArgumentParser(description="Import ESO Encounter.log builds into Lethal PVP Insights")
    ap.add_argument("--log", default=log_default, help="path to Encounter.log")
    ap.add_argument("--addon", default=addon_dir, help="path to the LethalPVPInsights addon folder")
    ap.add_argument("--reset", action="store_true", help="forget earlier imports and re-read the whole log")
    args = ap.parse_args()

    if not os.path.isfile(args.log):
        print("Encounter.log not found at:\n  " + args.log)
        print("Turn on the log in game with /pvpdi capture (or /encounterlog), fight, then run this again.")
        return 1

    r = run_import(args.log, args.addon, args.reset)
    print("Lethal PVP Insights importer")
    print("  log:      " + args.log)
    print("  read:     {:,} new lines in {:.1f}s".format(r["lines"], r["seconds"]))
    print("  builds:   {} build records read, {} accounts stored (max {})".format(r["found"], r["total"], MAX_ACCOUNTS))
    print("Done - type /reloadui in game to load the builds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
