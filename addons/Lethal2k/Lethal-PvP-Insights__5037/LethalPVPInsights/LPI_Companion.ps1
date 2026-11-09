<#
  Lethal PVP Insights Companion - PowerShell edition (no Python needed)

  Built into Windows 10/11: Windows PowerShell 5.1 + .NET Framework. Does the same as LPI_Companion.pyw:
    * reads Logs\Encounter.log and writes LPI_Imported.lua (gear + skill bars)
    * watches the log and pops up / imports after each captured fight
    * answers the in-game Upload button on http://127.0.0.1:47613/import
  Uses the same cache and settings files as the Python version, so you can switch between them.

  Start it with "LPI COMPANION.bat". Command-line options:
    -Background   start minimised (used by "Start with Windows")
    -ImportOnly   import once and exit (prints a summary)
    -NoGui        run watcher + Upload endpoint without a window
    -Reset        with -ImportOnly: forget earlier imports and re-read the whole log
    -UploadOnly   upload PVPDataInsight.lua to esopvp.com once and exit (used by the window, in the background)
    -LogPath / -AddonDir   override the detected paths
#>
param(
    [switch]$Background,
    [switch]$ImportOnly,
    [switch]$UploadOnly,
    [switch]$NoGui,
    [switch]$Reset,
    [string]$LogPath = "",
    [string]$AddonDir = ""
)

Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

$MAX_ACCOUNTS  = 200
$MAX_VARIANTS  = 5
$OUT_NAME      = 'LPI_Imported.lua'
$CACHE_NAME    = 'LPI_import_cache.json'
$SETTINGS_NAME = 'PVPDataInsight_companion.json'
$PORT          = 47613
$IDLE_SEC      = 20
$WANTED        = @{ 'BEGIN_LOG' = 1; 'ZONE_CHANGED' = 1; 'UNIT_ADDED' = 1; 'UNIT_CHANGED' = 1; 'PLAYER_INFO' = 1; 'ABILITY_INFO' = 1 }
$UTF8          = New-Object System.Text.UTF8Encoding($false)

# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------
function New-HT { return (New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)) }
function New-List { return ,(New-Object System.Collections.ArrayList) }

# (the leading comma keeps a one-element list from being unrolled into its element)
function Get-F($f, [int]$i) {
    if ($null -ne $f -and $i -lt $f.Count) {
        $x = $f[$i]
        if ($x -is [System.Collections.IList] -and -not ($x -is [string])) { return ,$x }
        return $x
    }
    return $null
}

function To-Int($v, $default = 0) {
    if ($v -is [long] -or $v -is [int]) { return [long]$v }
    $r = [long]0
    if ($v -is [string] -and [long]::TryParse($v, [ref]$r)) { return $r }
    return $default
}

function As-List($v) {
    if ($v -is [System.Collections.IList] -and -not ($v -is [string])) { return ,$v }
    return ,(New-Object System.Collections.ArrayList)
}

function Unix-Now { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }

# JSON (PowerShell 5.1 has no -AsHashtable): PSCustomObject -> case-sensitive Hashtable / ArrayList
function ConvertTo-HT($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = New-HT
        foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-HT $p.Value }
        return $h
    }
    if ($o -is [System.Collections.IList] -and -not ($o -is [string])) {
        $a = New-Object System.Collections.ArrayList
        foreach ($x in $o) { [void]$a.Add((ConvertTo-HT $x)) }
        return ,$a
    }
    return $o
}

# --------------------------------------------------------------------------
# Line parsing: comma separated, "quoted strings", [nested,[lists]]
# --------------------------------------------------------------------------
function Parse-Fields([string]$s) {
    $stack = New-Object System.Collections.ArrayList
    [void]$stack.Add((New-Object System.Collections.ArrayList))
    $sb = New-Object System.Text.StringBuilder
    $pending = $false
    $inQ = $false
    $n = $s.Length
    $i = 0
    while ($i -lt $n) {
        $c = $s[$i]
        if ($inQ) {
            if ($c -eq [char]'"') {
                if ($i + 1 -lt $n -and $s[$i + 1] -eq [char]'"') { [void]$sb.Append('"'); $i++ }
                else { $inQ = $false }
            } else { [void]$sb.Append($c) }
        } elseif ($c -eq [char]'"') {
            $inQ = $true; $pending = $true
        } elseif ($c -eq [char]'[') {
            [void]$stack.Add((New-Object System.Collections.ArrayList))
        } elseif ($c -eq [char]']' -or $c -eq [char]',') {
            if ($pending) {
                [void]$stack[$stack.Count - 1].Add($sb.ToString())
                [void]$sb.Clear()
                $pending = $false
            }
            if ($c -eq [char]']' -and $stack.Count -gt 1) {
                $lst = $stack[$stack.Count - 1]
                $stack.RemoveAt($stack.Count - 1)
                [void]$stack[$stack.Count - 1].Add($lst)
            }
        } else {
            [void]$sb.Append($c); $pending = $true
        }
        $i++
    }
    if ($pending) { [void]$stack[$stack.Count - 1].Add($sb.ToString()) }
    return ,$stack[0]
}

# --------------------------------------------------------------------------
# Fast path: a small C# helper (compiled once at start by Windows' own .NET) scans the log and parses
# lines ~50x faster than PowerShell script code. If it can't be compiled, the script code above is used.
# --------------------------------------------------------------------------
$script:FAST = $false
$PDI_CS = @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Text;

public static class PdiScan
{
    static readonly string[] Wanted = { "BEGIN_LOG", "ZONE_CHANGED", "UNIT_ADDED", "UNIT_CHANGED", "PLAYER_INFO", "ABILITY_INFO" };
    static readonly byte[][] WantedBytes;
    static readonly byte[] PlayerBytes = Encoding.ASCII.GetBytes("PLAYER");
    static readonly byte[] PlayerInfoBytes = Encoding.ASCII.GetBytes("PLAYER_INFO");
    static readonly byte[] EndLogBytes = Encoding.ASCII.GetBytes("END_LOG");

    static PdiScan()
    {
        WantedBytes = new byte[Wanted.Length][];
        for (int i = 0; i < Wanted.Length; i++) WantedBytes[i] = Encoding.ASCII.GetBytes(Wanted[i]);
    }

    // position of the n-th comma (0-based) in buf[start..end), or -1
    static int NthComma(byte[] buf, int start, int end, int n)
    {
        for (int i = start; i < end; i++)
        {
            if (buf[i] == (byte)',') { if (n == 0) return i; n--; }
        }
        return -1;
    }

    static bool Eq(byte[] buf, int start, int end, byte[] word)
    {
        if (end - start != word.Length) return false;
        for (int i = 0; i < word.Length; i++) if (buf[start + i] != word[i]) return false;
        return true;
    }

    // field index 1 = event name, field index 3 = unit type for UNIT_ADDED
    static int EventIndex(byte[] buf, int start, int end)
    {
        int c0 = NthComma(buf, start, end, 0);
        if (c0 < 0) return -1;
        int c1 = NthComma(buf, c0 + 1, end, 0);
        int evEnd = c1 < 0 ? end : c1;
        for (int w = 0; w < WantedBytes.Length; w++)
        {
            if (Eq(buf, c0 + 1, evEnd, WantedBytes[w]))
            {
                if (w == 2) // UNIT_ADDED: only players matter
                {
                    if (c1 < 0) return -1;
                    int c2 = NthComma(buf, c1 + 1, end, 0);
                    if (c2 < 0) return -1;
                    int c3 = NthComma(buf, c2 + 1, end, 0);
                    if (!Eq(buf, c2 + 1, c3 < 0 ? end : c3, PlayerBytes)) return -1;
                }
                return w;
            }
        }
        return -1;
    }

    // Reads complete lines from offset; returns only the lines the importer needs.
    // ABILITY_INFO lines (thousands in a big log) are reduced to an id -> name table right here.
    // result[0] = new offset (long), result[1] = number of lines read (long), result[2] = List<string>,
    // result[3] = Hashtable abilityId -> name
    public static object[] ReadWanted(string path, long offset)
    {
        List<string> outLines = new List<string>();
        Hashtable abilities = new Hashtable();
        long lines = 0;
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 1 << 16))
        {
            fs.Seek(offset, SeekOrigin.Begin);
            byte[] buf = new byte[8 << 20];
            int have = 0;
            while (true)
            {
                int n = fs.Read(buf, have, buf.Length - have);
                if (n <= 0) break;
                have += n;
                int start = 0;
                for (int i = 0; i < have; i++)
                {
                    if (buf[i] != (byte)'\n') continue;
                    int end = i;
                    if (end > start && buf[end - 1] == (byte)'\r') end--;
                    lines++;
                    int ev = end > start ? EventIndex(buf, start, end) : -1;
                    if (ev == 5)
                    {
                        ArrayList f = ParseFields(Encoding.UTF8.GetString(buf, start, end - start));
                        if (f.Count > 3 && f[2] is string && f[3] is string) abilities[(string)f[2]] = (string)f[3];
                    }
                    else if (ev >= 0) outLines.Add(Encoding.UTF8.GetString(buf, start, end - start));
                    start = i + 1;
                }
                offset += start;
                if (start < have) Buffer.BlockCopy(buf, start, buf, 0, have - start);
                have -= start;
                if (have == buf.Length) { Array.Resize(ref buf, buf.Length * 2); }
            }
        }
        return new object[] { offset, lines, outLines, abilities };
    }

    // Watcher: scans new complete lines for PLAYER_INFO unit ids and END_LOG.
    // result[0] = new offset, result[1] = bool ended, result[2] = List<string> unit ids
    public static object[] Watch(string path, long offset)
    {
        List<string> units = new List<string>();
        bool ended = false;
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 1 << 16))
        {
            fs.Seek(offset, SeekOrigin.Begin);
            byte[] buf = new byte[4 << 20];
            int have = 0;
            while (true)
            {
                int n = fs.Read(buf, have, buf.Length - have);
                if (n <= 0) break;
                have += n;
                int start = 0;
                for (int i = 0; i < have; i++)
                {
                    if (buf[i] != (byte)'\n') continue;
                    int end = i;
                    int c0 = NthComma(buf, start, end, 0);
                    if (c0 >= 0)
                    {
                        int c1 = NthComma(buf, c0 + 1, end, 0);
                        int evEnd = c1 < 0 ? end : c1;
                        if (evEnd > c0 + 1 && buf[evEnd - 1] == (byte)'\r') evEnd--;
                        if (c1 >= 0 && Eq(buf, c0 + 1, evEnd, PlayerInfoBytes))
                        {
                            int c2 = NthComma(buf, c1 + 1, end, 0);
                            units.Add(Encoding.ASCII.GetString(buf, c1 + 1, (c2 < 0 ? end : c2) - c1 - 1));
                        }
                        else if (Eq(buf, c0 + 1, evEnd, EndLogBytes)) ended = true;
                    }
                    start = i + 1;
                }
                offset += start;
                if (start < have) Buffer.BlockCopy(buf, start, buf, 0, have - start);
                have -= start;
                if (have == buf.Length) { Array.Resize(ref buf, buf.Length * 2); }
            }
        }
        return new object[] { offset, ended, units };
    }

    static long ToInt(object v)
    {
        string str = v as string;
        long r;
        if (str != null && long.TryParse(str, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture, out r)) return r;
        return 0;
    }

    static IList AsList(object v)
    {
        IList l = v as IList;
        return (l != null && !(v is string)) ? l : new ArrayList();
    }

    static ArrayList IntList(object raw)
    {
        ArrayList outList = new ArrayList();
        foreach (object x in AsList(raw)) outList.Add(ToInt(x));
        return outList;
    }

    static string JsonStr(string s) { return "\"" + (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"") + "\""; }

    static string Str(object o) { return o == null ? "" : Convert.ToString(o, System.Globalization.CultureInfo.InvariantCulture); }

    // PLAYER_INFO fields -> { effects, gear, bar1, bar2, hash } exactly like Handle-PlayerInfo / handle_player_info.
    // Returns null when the line has neither gear nor a front bar.
    public static Hashtable PlayerInfoVariant(ArrayList f)
    {
        Hashtable v = new Hashtable(StringComparer.Ordinal);
        v["effects"] = IntList(f.Count > 3 ? f[3] : null);
        ArrayList gear = new ArrayList();
        foreach (object g0 in AsList(f.Count > 5 ? f[5] : null))
        {
            IList g = AsList(g0);
            if (g.Count < 7) continue;
            Hashtable e = new Hashtable(StringComparer.Ordinal);
            e["slot"] = Str(g[0]); e["item"] = ToInt(g[1]); e["cp"] = Str(g[2]) == "T"; e["lvl"] = ToInt(g[3]);
            e["trait"] = Str(g[4]); e["q"] = Str(g[5]); e["set"] = ToInt(g[6]);
            e["ench"] = g.Count > 7 ? Str(g[7]) : "";
            e["enchCP"] = g.Count > 8 && Str(g[8]) == "T";
            e["enchLvl"] = g.Count > 9 ? ToInt(g[9]) : 0L;
            e["enchQ"] = g.Count > 10 ? Str(g[10]) : "";
            gear.Add(e);
        }
        v["gear"] = gear;
        ArrayList bar1 = IntList(f.Count > 6 ? f[6] : null);
        ArrayList bar2 = IntList(f.Count > 7 ? f[7] : null);
        v["bar1"] = bar1; v["bar2"] = bar2;
        if (gear.Count == 0 && bar1.Count == 0) return null;

        // identical to Python: sha1(json.dumps([[(slot,item,trait,set,ench)...], bar1, bar2], sort_keys=True))[:12]
        List<string> parts = new List<string>();
        foreach (Hashtable e in gear)
            parts.Add("[" + JsonStr((string)e["slot"]) + ", " + Str(e["item"]) + ", " + JsonStr((string)e["trait"]) + ", " +
                      Str(e["set"]) + ", " + JsonStr((string)e["ench"]) + "]");
        List<string> b1 = new List<string>(); foreach (object x in bar1) b1.Add(Str(x));
        List<string> b2 = new List<string>(); foreach (object x in bar2) b2.Add(Str(x));
        string key = "[[" + string.Join(", ", parts.ToArray()) + "], [" + string.Join(", ", b1.ToArray()) + "], [" +
                     string.Join(", ", b2.ToArray()) + "]]";
        using (System.Security.Cryptography.SHA1 sha = System.Security.Cryptography.SHA1.Create())
        {
            byte[] h = sha.ComputeHash(new UTF8Encoding(false).GetBytes(key));
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < 6; i++) sb.Append(h[i].ToString("x2"));
            v["hash"] = sb.ToString();
        }
        return v;
    }

    // ---------- JSON / Lua writers (no PowerShell wrapper objects can leak into the output) ----------
    // PowerShell sometimes stores values wrapped in a PSObject; serializers that reflect over it fail
    // ("circular reference ... PSParameterizedProperty"). Unwrap by reflection (no extra references needed).
    static object Unwrap(object o)
    {
        while (o != null && o.GetType().FullName == "System.Management.Automation.PSObject")
        {
            System.Reflection.PropertyInfo pi = o.GetType().GetProperty("BaseObject");
            object b = pi == null ? null : pi.GetValue(o, null);
            if (b == null || ReferenceEquals(b, o)) break;
            o = b;
        }
        return o;
    }

    static bool IsNum(object o)
    {
        return o is int || o is long || o is double || o is decimal || o is short || o is byte ||
               o is uint || o is ulong || o is ushort || o is sbyte || o is float;
    }

    static string NumStr(object o) { return Convert.ToString(o, System.Globalization.CultureInfo.InvariantCulture); }

    static void JsonString(StringBuilder sb, string s)
    {
        sb.Append('"');
        foreach (char c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default:
                    if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                    else sb.Append(c);
                    break;
            }
        }
        sb.Append('"');
    }

    static void JsonWrite(StringBuilder sb, object o, int depth)
    {
        o = Unwrap(o);
        if (depth > 100) { sb.Append("null"); return; }
        if (o == null) { sb.Append("null"); return; }
        if (o is bool) { sb.Append((bool)o ? "true" : "false"); return; }
        if (o is string) { JsonString(sb, (string)o); return; }
        if (o is char) { JsonString(sb, o.ToString()); return; }
        if (IsNum(o))
        {
            if (o is double || o is float) sb.Append(((IFormattable)o).ToString("R", System.Globalization.CultureInfo.InvariantCulture));
            else sb.Append(NumStr(o));
            return;
        }
        IDictionary d = o as IDictionary;
        if (d != null)
        {
            sb.Append('{');
            bool first = true;
            foreach (DictionaryEntry e in d)
            {
                if (!first) sb.Append(',');
                first = false;
                JsonString(sb, Convert.ToString(Unwrap(e.Key), System.Globalization.CultureInfo.InvariantCulture));
                sb.Append(':');
                JsonWrite(sb, e.Value, depth + 1);
            }
            sb.Append('}');
            return;
        }
        IEnumerable list = o as IEnumerable;
        if (list != null)
        {
            sb.Append('[');
            bool first = true;
            foreach (object x in list)
            {
                if (!first) sb.Append(',');
                first = false;
                JsonWrite(sb, x, depth + 1);
            }
            sb.Append(']');
            return;
        }
        JsonString(sb, o.ToString());
    }

    public static string ToJson(object o)
    {
        StringBuilder sb = new StringBuilder();
        JsonWrite(sb, o, 0);
        return sb.ToString();
    }

    // JavaScriptSerializer.DeserializeObject result -> case-sensitive Hashtable / ArrayList (fast)
    public static object FromJson(object o)
    {
        o = Unwrap(o);
        if (o == null || o is string) return o;
        IDictionary d = o as IDictionary;
        if (d != null)
        {
            Hashtable h = new Hashtable(StringComparer.Ordinal);
            foreach (DictionaryEntry e in d) h[Convert.ToString(e.Key, System.Globalization.CultureInfo.InvariantCulture)] = FromJson(e.Value);
            return h;
        }
        IList l = o as IList;
        if (l != null)
        {
            ArrayList a = new ArrayList();
            foreach (object x in l) a.Add(FromJson(x));
            return a;
        }
        return o;
    }

    static string LuaStr(string s) { return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n") + "\""; }

    // Same layout as Lua-Val / lua_val: sorted keys, [n] for numeric keys, numeric lists on one line
    public static string ToLua(object v, string indent)
    {
        v = Unwrap(v);
        if (v == null) return "nil";
        if (v is bool) return (bool)v ? "true" : "false";
        if (IsNum(v)) return NumStr(v);
        if (v is string) return LuaStr((string)v);
        IDictionary d = v as IDictionary;
        if (d != null)
        {
            if (d.Count == 0) return "{}";
            string inner = indent + "  ";
            List<KeyValuePair<string, object>> keys = new List<KeyValuePair<string, object>>();
            foreach (object k in d.Keys) keys.Add(new KeyValuePair<string, object>(NumStr(Unwrap(k)), k));
            keys.Sort(delegate(KeyValuePair<string, object> a, KeyValuePair<string, object> b) { return string.CompareOrdinal(a.Key, b.Key); });
            StringBuilder sb = new StringBuilder("{\n");
            foreach (KeyValuePair<string, object> kv in keys)
            {
                string kTxt = IsNum(Unwrap(kv.Value)) ? "[" + kv.Key + "]" : "[" + LuaStr(kv.Key) + "]";
                sb.Append(inner).Append(kTxt).Append('=').Append(ToLua(d[kv.Value], inner)).Append(",\n");
            }
            sb.Append(indent).Append('}');
            return sb.ToString();
        }
        IList l = v as IList;
        if (l != null)
        {
            if (l.Count == 0) return "{}";
            bool allNum = true;
            foreach (object x in l) if (!IsNum(Unwrap(x))) { allNum = false; break; }
            if (allNum)
            {
                List<string> parts = new List<string>();
                foreach (object x in l) parts.Add(NumStr(Unwrap(x)));
                return "{" + string.Join(",", parts.ToArray()) + "}";
            }
            string inner = indent + "  ";
            StringBuilder sb = new StringBuilder("{\n");
            foreach (object x in l) sb.Append(inner).Append(ToLua(x, inner)).Append(",\n");
            sb.Append(indent).Append('}');
            return sb.ToString();
        }
        return "nil";
    }

    // Start times (unix seconds) of every logging session in the file: one BEGIN_LOG line per session
    static readonly byte[] BeginLogBytes = Encoding.ASCII.GetBytes("BEGIN_LOG");
    public static List<long> BeginTimes(string path)
    {
        List<long> times = new List<long>();
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 1 << 16))
        {
            byte[] buf = new byte[4 << 20];
            int have = 0;
            while (true)
            {
                int n = fs.Read(buf, have, buf.Length - have);
                if (n <= 0) break;
                have += n;
                int start = 0;
                for (int i = 0; i < have; i++)
                {
                    if (buf[i] != (byte)'\n') continue;
                    int c0 = NthComma(buf, start, i, 0);
                    if (c0 >= 0)
                    {
                        int c1 = NthComma(buf, c0 + 1, i, 0);
                        if (c1 >= 0 && Eq(buf, c0 + 1, c1, BeginLogBytes))
                        {
                            int c2 = NthComma(buf, c1 + 1, i, 0);
                            long ms;
                            string f = Encoding.ASCII.GetString(buf, c1 + 1, (c2 < 0 ? i : c2) - c1 - 1).Trim();
                            if (long.TryParse(f, out ms)) times.Add(ms / 1000);
                        }
                    }
                    start = i + 1;
                }
                if (start < have) Buffer.BlockCopy(buf, start, buf, 0, have - start);
                have -= start;
                if (have == buf.Length) { Array.Resize(ref buf, buf.Length * 2); }
            }
        }
        return times;
    }

    // Same rules as Parse-Fields / parse_fields: comma separated, "quoted", [nested,[lists]]
    public static ArrayList ParseFields(string s)
    {
        List<ArrayList> stack = new List<ArrayList>();
        stack.Add(new ArrayList());
        StringBuilder sb = new StringBuilder();
        bool pending = false, inQ = false;
        int n = s.Length;
        for (int i = 0; i < n; i++)
        {
            char c = s[i];
            if (inQ)
            {
                if (c == '"')
                {
                    if (i + 1 < n && s[i + 1] == '"') { sb.Append('"'); i++; }
                    else inQ = false;
                }
                else sb.Append(c);
            }
            else if (c == '"') { inQ = true; pending = true; }
            else if (c == '[') { stack.Add(new ArrayList()); }
            else if (c == ']' || c == ',')
            {
                if (pending) { stack[stack.Count - 1].Add(sb.ToString()); sb.Length = 0; pending = false; }
                if (c == ']' && stack.Count > 1)
                {
                    ArrayList lst = stack[stack.Count - 1];
                    stack.RemoveAt(stack.Count - 1);
                    stack[stack.Count - 1].Add(lst);
                }
            }
            else { sb.Append(c); pending = true; }
        }
        if (pending) stack[stack.Count - 1].Add(sb.ToString());
        return stack[0];
    }
}

'@
try {
    if (-not ('PdiScan' -as [type])) { Add-Type -TypeDefinition $PDI_CS -Language CSharp -ErrorAction Stop }
    $script:FAST = $true
} catch { $script:FAST = $false }

# --------------------------------------------------------------------------
# Paths, settings, cache
# --------------------------------------------------------------------------
function Get-DefaultPaths {
    $addon = $PSScriptRoot
    if (-not $addon) { $addon = Split-Path -Parent $MyInvocation.PSCommandPath }
    $live = Split-Path -Parent (Split-Path -Parent $addon)
    $log = Join-Path (Join-Path $live 'Logs') 'Encounter.log'
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) {
        $docs = @([Environment]::GetFolderPath('MyDocuments'), (Join-Path $HOME 'Documents'), (Join-Path $HOME 'OneDrive\Documents'))
        foreach ($d in $docs) {
            if (-not $d) { continue }
            foreach ($realm in @('live', 'liveeu', 'pts')) {
                $cand = Join-Path $d ("Elder Scrolls Online\" + $realm + "\Logs\Encounter.log")
                if ($d -and (Test-Path -LiteralPath $cand -PathType Leaf)) { return @($addon, $cand) }
            }
        }
    }
    return @($addon, $log)
}

# Windows PowerShell 5.1's ConvertFrom-Json stops at ~2 MB, so use JavaScriptSerializer when available
$script:JSS = $null
try {
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $script:JSS = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $script:JSS.MaxJsonLength = [int]::MaxValue
    $script:JSS.RecursionLimit = 200
} catch { $script:JSS = $null }

# plain .NET copy of a value tree (PSObject wrappers make JavaScriptSerializer fail)
function Unwrap-PS($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSObject]) { $o = $o.PSObject.BaseObject }
    if ($o -is [System.Collections.IDictionary]) {
        $h = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        foreach ($k in $o.Keys) { $h[[string]$k] = Unwrap-PS $o[$k] }
        return ,$h
    }
    if ($o -is [System.Collections.IList] -and -not ($o -is [string])) {
        $a = New-Object System.Collections.ArrayList
        foreach ($x in $o) { [void]$a.Add((Unwrap-PS $x)) }
        return ,$a
    }
    return $o
}

function ConvertFrom-JSS($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Collections.IDictionary]) {
        $h = New-HT
        foreach ($k in $o.Keys) { $h[[string]$k] = ConvertFrom-JSS $o[$k] }
        return $h
    }
    if ($o -is [System.Collections.IList] -and -not ($o -is [string])) {
        $a = New-Object System.Collections.ArrayList
        foreach ($x in $o) { [void]$a.Add((ConvertFrom-JSS $x)) }
        return ,$a
    }
    return $o
}

function To-Json($o) {
    if ($script:FAST) { return [PdiScan]::ToJson($o) }
    if ($script:JSS) { return $script:JSS.Serialize((Unwrap-PS $o)) }
    return ($o | ConvertTo-Json -Depth 30 -Compress)
}

function Read-JsonFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $txt = [System.IO.File]::ReadAllText($path, $UTF8)
        if (-not $txt.Trim()) { return $null }
        if ($script:JSS) {
            $raw = $script:JSS.DeserializeObject($txt)
            if ($script:FAST) { return [PdiScan]::FromJson($raw) }
            return ConvertFrom-JSS $raw
        }
        return ConvertTo-HT ($txt | ConvertFrom-Json)
    } catch { return $null }
}

function Write-TextAtomic([string]$path, [string]$text) {
    $tmp = $path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, $text, $UTF8)
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

function New-Cache {
    $c = New-HT
    $c['offset'] = 0; $c['size'] = 0; $c['epoch'] = 0; $c['zone'] = ''
    $c['units'] = New-HT; $c['abilities'] = New-HT; $c['accounts'] = New-HT
    return $c
}

function Load-Cache([string]$path) {
    $c = Read-JsonFile $path
    if ($null -eq $c -or -not ($c -is [System.Collections.IDictionary])) { return New-Cache }
    foreach ($k in @('units', 'abilities', 'accounts')) { if (-not ($c[$k] -is [System.Collections.IDictionary])) { $c[$k] = New-HT } }
    foreach ($k in @('offset', 'size', 'epoch')) { if ($null -eq $c[$k]) { $c[$k] = 0 } }
    if ($null -eq $c['zone']) { $c['zone'] = '' }
    return $c
}

function Save-Cache([string]$path, $cache) {
    Write-TextAtomic $path (To-Json $cache)
}

function Read-Head([string]$path) {
    $fs = [System.IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
    try {
        $buf = New-Object byte[] 200
        $n = $fs.Read($buf, 0, 200)
        $s = $UTF8.GetString($buf, 0, $n)
        $nl = $s.IndexOf("`n")
        if ($nl -ge 0) { $s = $s.Substring(0, $nl + 1) }
        return $s
    } finally { $fs.Close() }
}

# --------------------------------------------------------------------------
# Import (same logic and file formats as LPI_Import.py)
# --------------------------------------------------------------------------
function Unit-FromAdded($f) {
    # ts,UNIT_ADDED,unitId,unitType,isLocalPlayer,playerPerSessionId,monsterId,isBoss,classId,raceId,
    # name,displayName,characterId,level,championPoints,ownerUnitId,reaction,isGroupedWithLocalPlayer
    $u = New-HT
    $u['type'] = [string](Get-F $f 3)
    $u['local'] = ((Get-F $f 4) -ceq 'T')
    $u['cls'] = To-Int (Get-F $f 8)
    $u['race'] = To-Int (Get-F $f 9)
    $u['char'] = [string](Get-F $f 10)
    $u['acct'] = [string](Get-F $f 11)
    $u['level'] = To-Int (Get-F $f 13)
    $u['cp'] = To-Int (Get-F $f 14)
    $u['reaction'] = [string](Get-F $f 16)
    $u['grouped'] = ((Get-F $f 17) -ceq 'T')
    return $u
}

function Unit-FromChanged($u, $f) {
    # ts,UNIT_CHANGED,unitId,classId,raceId,name,displayName,characterId,level,championPoints,ownerUnitId,reaction,grouped
    if ($f.Count -gt 3) { $u['cls'] = To-Int (Get-F $f 3) $u['cls'] }
    if ($f.Count -gt 4) { $u['race'] = To-Int (Get-F $f 4) $u['race'] }
    if ($f.Count -gt 5 -and (Get-F $f 5)) { $u['char'] = [string](Get-F $f 5) }
    if ($f.Count -gt 6 -and (Get-F $f 6)) { $u['acct'] = [string](Get-F $f 6) }
    if ($f.Count -gt 8) { $u['level'] = To-Int (Get-F $f 8) $u['level'] }
    if ($f.Count -gt 9) { $u['cp'] = To-Int (Get-F $f 9) $u['cp'] }
    if ($f.Count -gt 11 -and (Get-F $f 11)) { $u['reaction'] = [string](Get-F $f 11) }
    if ($f.Count -gt 12) { $u['grouped'] = ((Get-F $f 12) -ceq 'T') }
}

function Parse-Gear($raw) {
    $gear = New-Object System.Collections.ArrayList
    foreach ($g0 in (As-List $raw)) {
        $g = As-List $g0
        if ($g.Count -lt 7) { continue }
        $e = New-HT
        $e['slot'] = [string]$g[0]; $e['item'] = To-Int $g[1]; $e['cp'] = ($g[2] -ceq 'T'); $e['lvl'] = To-Int $g[3]
        $e['trait'] = [string]$g[4]; $e['q'] = [string]$g[5]; $e['set'] = To-Int $g[6]
        $e['ench'] = ''; $e['enchCP'] = $false; $e['enchLvl'] = 0; $e['enchQ'] = ''
        if ($g.Count -gt 7) { $e['ench'] = [string]$g[7] }
        if ($g.Count -gt 8) { $e['enchCP'] = ($g[8] -ceq 'T') }
        if ($g.Count -gt 9) { $e['enchLvl'] = To-Int $g[9] }
        if ($g.Count -gt 10) { $e['enchQ'] = [string]$g[10] }
        [void]$gear.Add($e)
    }
    return ,$gear
}

function Int-List($raw) {
    $out = New-Object System.Collections.ArrayList
    foreach ($x in (As-List $raw)) { [void]$out.Add((To-Int $x)) }
    return ,$out
}

function Json-Str([string]$s) { return '"' + $s.Replace('\', '\\').Replace('"', '\"') + '"' }

# identical to Python: sha1(json.dumps([[(slot,item,trait,set,ench)...], bar1, bar2], sort_keys=True))[:12]
$script:SHA1 = [System.Security.Cryptography.SHA1]::Create()
function Variant-Hash($v) {
    $g = New-Object System.Collections.Generic.List[string]
    foreach ($e in $v['gear']) {
        $g.Add('[' + (Json-Str $e['slot']) + ', ' + $e['item'] + ', ' + (Json-Str $e['trait']) + ', ' + $e['set'] + ', ' + (Json-Str $e['ench']) + ']')
    }
    $b1 = '[' + ([string[]]@($v['bar1']) -join ', ') + ']'
    $b2 = '[' + ([string[]]@($v['bar2']) -join ', ') + ']'
    $key = '[[' + ($g -join ', ') + '], ' + $b1 + ', ' + $b2 + ']'
    $bytes = $script:SHA1.ComputeHash($UTF8.GetBytes($key))
    return ([System.BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()).Substring(0, 12)
}

function Handle-PlayerInfo($cache, $f, [long]$ts) {
    # ts,PLAYER_INFO,unitId,[effects],[effectStacks],[[gear]...],[frontBar],[backBar]
    $uid = [string](Get-F $f 2)
    $u = $cache['units'][$uid]
    if ($null -eq $u -or $u['local']) { return $false }
    $key = [string]$u['acct']
    if (-not $key) {
        # "appear anonymous in encounter logs": keep grouped players under class/race/CP; the addon matches them
        if (-not ($u['grouped'] -and $u['cls'])) { return $false }
        $key = '#anon:' + $u['cls'] + ':' + $u['race'] + ':' + $u['cp']
    }
    if ($script:FAST) {
        $v = [PdiScan]::PlayerInfoVariant($f)
        if ($null -eq $v) { return $false }
    } else {
        $v = New-HT
        $v['effects'] = Int-List (Get-F $f 3)
        $v['gear'] = Parse-Gear (Get-F $f 5)
        $v['bar1'] = Int-List (Get-F $f 6)
        $v['bar2'] = Int-List (Get-F $f 7)
        if ($v['gear'].Count -eq 0 -and $v['bar1'].Count -eq 0) { return $false }
        $v['hash'] = Variant-Hash $v
    }
    $epoch = [long](To-Int $cache['epoch'])
    if ($epoch) { $v['seen'] = [long][math]::Floor(($epoch + $ts) / 1000) } else { $v['seen'] = Unix-Now }
    $v['zone'] = [string]$cache['zone']

    $acc = $cache['accounts'][$key]
    if ($null -eq $acc) { $acc = New-HT; $acc['variants'] = New-Object System.Collections.ArrayList; $cache['accounts'][$key] = $acc }
    foreach ($k in @('char', 'cls', 'race', 'level', 'cp', 'reaction')) { if ($u[$k]) { $acc[$k] = $u[$k] } }
    $acc['grouped'] = [bool]($acc['grouped'] -or $u['grouped'])
    if ($key.StartsWith('#anon:')) { $acc['anon'] = $true }
    $acc['last'] = $v['seen']

    $vars = New-Object System.Collections.ArrayList
    [void]$vars.Add($v)
    foreach ($old in (As-List $acc['variants'])) { if ($old['hash'] -ne $v['hash'] -and $vars.Count -lt $MAX_VARIANTS) { [void]$vars.Add($old) } }
    $acc['variants'] = $vars
    return $true
}

function Process-Line($cache, [string]$line, [ref]$found) {
    $head = $line.Split([char[]]@(','), 3)
    if ($head.Count -lt 2 -or -not $WANTED.ContainsKey($head[1])) { return }
    $ev = $head[1]
    if ($script:FAST) { $f = [PdiScan]::ParseFields($line) } else { $f = Parse-Fields $line }
    $ts = To-Int (Get-F $f 0)
    switch -CaseSensitive ($ev) {
        'BEGIN_LOG'    { $cache['epoch'] = To-Int (Get-F $f 2); $cache['units'] = New-HT }
        'ZONE_CHANGED' { $cache['zone'] = [string](Get-F $f 3) }
        'UNIT_ADDED'   { if ((Get-F $f 3) -ceq 'PLAYER') { $cache['units'][[string](Get-F $f 2)] = Unit-FromAdded $f } }
        'UNIT_CHANGED' { $u = $cache['units'][[string](Get-F $f 2)]; if ($u) { Unit-FromChanged $u $f } }
        'ABILITY_INFO' { if ($f.Count -gt 3) { $cache['abilities'][[string](Get-F $f 2)] = [string](Get-F $f 3) } }
        'PLAYER_INFO'  { if (Handle-PlayerInfo $cache $f $ts) { $found.Value++ } }
    }
}

function Import-Log([string]$log, $cache) {
    $size = (Get-Item -LiteralPath $log).Length
    $head = Read-Head $log
    if ($size -lt [long]$cache['offset'] -or $cache['head'] -ne $head) { $cache['offset'] = 0; $cache['units'] = New-HT }
    $cache['head'] = $head
    $found = 0
    $lines = 0
    if ($script:FAST) {
        $r = [PdiScan]::ReadWanted($log, [long]$cache['offset'])
        foreach ($line in $r[2]) { Process-Line $cache $line ([ref]$found) }
        $ab = $cache['abilities']
        foreach ($k in $r[3].Keys) { $ab[[string]$k] = [string]$r[3][$k] }
        $cache['offset'] = [long]$r[0]
        $cache['size'] = $size
        return @($found, [long]$r[1])
    }
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        $offset = [long]$cache['offset']
        [void]$fs.Seek($offset, 'Begin')
        $chunk = New-Object byte[] (4MB)
        $carry = New-Object System.IO.MemoryStream
        while ($true) {
            $n = $fs.Read($chunk, 0, $chunk.Length)
            if ($n -le 0) { break }
            $carry.Write($chunk, 0, $n)
            $data = $carry.ToArray()
            $cut = [Array]::LastIndexOf($data, [byte]10)
            if ($cut -lt 0) { continue }
            $text = $UTF8.GetString($data, 0, $cut + 1)
            foreach ($raw in $text.Split("`n")) {
                if ($raw.Length -eq 0) { continue }
                $lines++
                Process-Line $cache ($raw.TrimEnd("`r", "`n")) ([ref]$found)
            }
            $offset += $cut + 1
            $carry = New-Object System.IO.MemoryStream
            if ($cut + 1 -lt $data.Length) { $carry.Write($data, $cut + 1, $data.Length - $cut - 1) }
        }
        $cache['offset'] = $offset
    } finally { $fs.Close() }
    $cache['size'] = $size
    return @($found, $lines)
}

function Trim-Accounts($cache) {
    $accs = $cache['accounts']
    if ($accs.Count -le $MAX_ACCOUNTS) { return }
    $keep = $accs.Keys | Sort-Object -Property @{ Expression = { [long](To-Int $accs[$_]['last']) } } -Descending | Select-Object -First $MAX_ACCOUNTS
    $n = New-HT
    foreach ($k in $keep) { $n[$k] = $accs[$k] }
    $cache['accounts'] = $n
}

# ---------- Lua output (same layout as the Python writer) ----------
function Lua-Str([string]$s) { return '"' + $s.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n') + '"' }

function Is-Num($x) { return ($x -is [int] -or $x -is [long] -or $x -is [double] -or $x -is [decimal] -or $x -is [int16] -or $x -is [byte]) }

function Lua-Val($v, [string]$indent) {
    if ($v -is [bool]) { if ($v) { return 'true' } else { return 'false' } }
    if (Is-Num $v) { return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $v)) }
    if ($v -is [string]) { return (Lua-Str $v) }
    if ($v -is [System.Collections.IDictionary]) {
        if ($v.Count -eq 0) { return '{}' }
        $inner = $indent + '  '
        $keys = [string[]]@($v.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($keys, [System.StringComparer]::Ordinal)
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append("{`n")
        foreach ($ks in $keys) {
            $kObj = $null
            foreach ($k in $v.Keys) { if ([string]$k -ceq $ks) { $kObj = $k; break } }
            $kTxt = '[' + (Lua-Str $ks) + ']'
            if (Is-Num $kObj) { $kTxt = '[' + $ks + ']' }
            [void]$sb.Append($inner + $kTxt + '=' + (Lua-Val $v[$kObj] $inner) + ",`n")
        }
        [void]$sb.Append($indent + '}')
        return $sb.ToString()
    }
    if ($v -is [System.Collections.IList]) {
        if ($v.Count -eq 0) { return '{}' }
        $allNum = $true
        foreach ($x in $v) { if (-not (Is-Num $x)) { $allNum = $false; break } }
        if ($allNum) { return '{' + (($v | ForEach-Object { [string]$_ }) -join ',') + '}' }
        $inner = $indent + '  '
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append("{`n")
        foreach ($x in $v) { [void]$sb.Append($inner + (Lua-Val $x $inner) + ",`n") }
        [void]$sb.Append($indent + '}')
        return $sb.ToString()
    }
    return 'nil'
}

function Write-Lua([string]$path, $cache) {
    $builds = New-HT
    foreach ($acct in @($cache['accounts'].Keys)) {
        $a = $cache['accounts'][$acct]
        $names = New-Object System.Collections.Hashtable
        foreach ($v in (As-List $a['variants'])) {
            foreach ($aid in (@($v['bar1']) + @($v['bar2']))) {
                if ($null -eq $aid) { continue }
                $nm = $cache['abilities'][[string]$aid]
                if ($nm) { $names[[long]$aid] = $nm }
            }
        }
        $entry = New-HT
        foreach ($k in @('char', 'cls', 'race', 'level', 'cp', 'reaction', 'grouped', 'last', 'anon')) {
            if ($a.ContainsKey($k)) { $entry[$k] = $a[$k] }
        }
        $vars = New-Object System.Collections.ArrayList
        foreach ($v in (As-List $a['variants'])) {
            $nv = New-HT
            foreach ($k in @('seen', 'zone', 'effects', 'gear', 'bar1', 'bar2', 'hash')) { $nv[$k] = $v[$k] }
            [void]$vars.Add($nv)
        }
        $entry['variants'] = $vars
        $entry['names'] = $names
        $builds[$acct] = $entry
    }
    $data = New-HT
    $data['generated'] = Unix-Now
    $data['builds'] = $builds
    $text = "-- Generated by LPI_Import.py - do not edit, it is overwritten on each import`n" +
            'PVPDataInsight_Imported = ' + $(if ($script:FAST) { [PdiScan]::ToLua($data, '') } else { Lua-Val $data '' }) + "`n"
    Write-TextAtomic $path $text
    return $builds.Count
}

function Run-Import([string]$log, [string]$addon, [bool]$reset) {
    $cachePath = Join-Path $addon $CACHE_NAME
    if ($reset) { $cache = New-Cache } else { $cache = Load-Cache $cachePath }
    $t0 = Get-Date
    $r = Import-Log $log $cache
    Trim-Accounts $cache
    $total = Write-Lua (Join-Path $addon $OUT_NAME) $cache
    # keep only ability names that are referenced by stored bars
    $used = New-HT
    foreach ($acc in $cache['accounts'].Values) {
        foreach ($v in (As-List $acc['variants'])) { foreach ($aid in (@($v['bar1']) + @($v['bar2']))) { if ($null -ne $aid) { $used[[string]$aid] = 1 } } }
    }
    $ab = New-HT
    foreach ($k in $cache['abilities'].Keys) { if ($used.ContainsKey($k)) { $ab[$k] = $cache['abilities'][$k] } }
    $cache['abilities'] = $ab
    Save-Cache $cachePath $cache
    return @{ found = $r[0]; lines = $r[1]; total = $total; seconds = ((Get-Date) - $t0).TotalSeconds }
}

function Do-Import($cfg) {
    $log = [string]$cfg['log']; $addon = [string]$cfg['addon']
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { return @($false, "Encounter.log not found at $log - set the path (Browse...).") }
    if (-not (Test-Path -LiteralPath $addon -PathType Container)) { return @($false, "Addon folder not found at $addon.") }
    try {
        $r = Run-Import $log $addon $false
        $msg = ("Imported {0} build record(s) - {1} players stored. Back in the game, click Reload UI (or type /reloadui)." -f $r.found, $r.total)
    } catch {
        return @($false, ("Import failed: " + $_.Exception.Message))
    }
    if ($cfg['deleteAfter']) { $msg = $msg + ' ' + (Auto-DeleteLog $cfg) }
    return @($true, $msg)
}

# --------------------------------------------------------------------------
# Who started the encounter log? The addon remembers every time it switched the log on (captureStarts,
# sent along with the in-game Upload / Delete links and saved in SavedVariables after a reload). Every
# logging session in Encounter.log starts with a BEGIN_LOG line; a session that doesn't match one of
# the addon's start times was started by the player (/encounterlog) - such a log is never deleted
# without asking.
# --------------------------------------------------------------------------
$CAPTURE_MATCH_SEC = 30
$script:KnownCaps = New-Object 'System.Collections.Generic.HashSet[long]'
$script:PendingDelete = $false

function Add-Caps([string]$csv) {
    if (-not $csv) { return }
    foreach ($p in $csv.Split(',')) { $v = [long]0; if ([long]::TryParse($p.Trim(), [ref]$v) -and $v -gt 0) { [void]$script:KnownCaps.Add($v) } }
}

function Query-Value([string]$query, [string]$name) {
    foreach ($kv in $query.Split('&')) {
        $pair = $kv.Split('=', 2)
        if ($pair.Count -eq 2 -and $pair[0] -eq $name) { return [System.Uri]::UnescapeDataString($pair[1]) }
    }
    return ''
}

# ...\live\Logs\Encounter.log -> ...\live\SavedVariables\LethalPVPInsights.lua
function Read-SvCaptures([string]$log) {
    try {
        $live = Split-Path -Parent (Split-Path -Parent $log)
        $sv = Sv-Path (Join-Path $live 'AddOns\LethalPVPInsights')
        if (-not (Test-Path -LiteralPath $sv -PathType Leaf)) { return }
        $txt = [System.IO.File]::ReadAllText($sv)
        foreach ($m in [regex]::Matches($txt, '\["captureStarts"\]\s*=\s*\{([^}]*)\}')) {
            foreach ($n in [regex]::Matches($m.Groups[1].Value, '=\s*(\d+)')) { [void]$script:KnownCaps.Add([long]$n.Groups[1].Value) }
        }
    } catch { }
}

function Session-Starts([string]$log) {
    if ($script:FAST) { return @([PdiScan]::BeginTimes($log)) }
    $out = @()
    foreach ($line in [System.IO.File]::ReadLines($log)) {
        if ($line.Contains(',BEGIN_LOG,')) { $f = $line.Split(','); $v = [long]0; if ([long]::TryParse($f[2], [ref]$v)) { $out += [long]($v / 1000) } }
    }
    return $out
}

# Number of logging sessions in the file that the addon didn't start
function Foreign-Sessions($cfg) {
    $log = [string]$cfg['log']
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { return 0 }
    Read-SvCaptures $log
    $n = 0
    foreach ($s in (Session-Starts $log)) {
        $mine = $false
        foreach ($k in $script:KnownCaps) { if ([math]::Abs($s - $k) -le $CAPTURE_MATCH_SEC) { $mine = $true; break } }
        if (-not $mine) { $n++ }
    }
    return $n
}

$FOREIGN_MSG = 'Encounter.log also contains logging that LPI did not start (you turned /encounterlog on yourself, or LPI''s capture is not confirmed yet).'

# "Delete log after import": only when every session in the log is LPI's own; otherwise wait
function Auto-DeleteLog($cfg) {
    if ((Foreign-Sessions $cfg) -gt 0) {
        $script:PendingDelete = $true
        return 'Encounter.log was kept: ' + $FOREIGN_MSG + ' It is deleted automatically once LPI''s capture is confirmed (after /reloadui), or use Delete log now.'
    }
    $script:PendingDelete = $false
    return (Do-DeleteLog $cfg $true)[1]
}

# Re-check a postponed automatic delete (called from the window timer)
function Retry-PendingDelete($cfg) {
    if (-not $script:PendingDelete) { return $null }
    if (-not (Test-Path -LiteralPath ([string]$cfg['log']) -PathType Leaf)) { $script:PendingDelete = $false; return $null }
    if ((Foreign-Sessions $cfg) -gt 0) { return $null }
    $script:PendingDelete = $false
    return (Do-DeleteLog $cfg $true)[1]
}

# Delete Encounter.log (its data is already imported). Without $confirmed, a log containing sessions the
# addon didn't start is not deleted: returns @($false, message, 'confirm') so the caller can ask.
function Do-DeleteLog($cfg, [bool]$confirmed = $false) {
    $log = [string]$cfg['log']
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { return @($true, 'Encounter.log is already deleted.') }
    if (-not $confirmed) {
        $n = Foreign-Sessions $cfg
        if ($n -gt 0) { return @($false, ("Not deleted yet - " + $FOREIGN_MSG + " ({0} logging session(s).) Delete it anyway?" -f $n), 'confirm') }
    }
    $script:PendingDelete = $false
    $mb = '{0:N1}' -f ((Get-Item -LiteralPath $log).Length / 1MB)
    try {
        Remove-Item -LiteralPath $log -Force -ErrorAction Stop
        return @($true, "Encounter.log deleted ($mb MB freed).")
    } catch {
        try {   # the game may still hold it open: emptying it works when deleting doesn't
            $fs = [System.IO.File]::Open($log, 'Open', 'Write', 'ReadWrite')
            $fs.SetLength(0); $fs.Close()
            return @($true, "Encounter.log emptied ($mb MB freed).")
        } catch {
            return @($false, "Couldn't delete Encounter.log - the game is still writing to it. Turn the encounter log off (/encounterlog) or close the game, then try again.")
        }
    }
}

# --------------------------------------------------------------------------
# Log watcher: notices when a capture has finished
# --------------------------------------------------------------------------
$script:W = @{ path = ''; offset = 0; head = $null; units = @{}; ended = $false; lastGrowth = 0 }

function Watcher-Reset([string]$path) {
    $script:W.path = $path
    $script:W.units = @{}
    $script:W.ended = $false
    $script:W.lastGrowth = 0
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $script:W.offset = (Get-Item -LiteralPath $path).Length
        $script:W.head = Read-Head $path
    } else { $script:W.offset = 0; $script:W.head = $null }
}

function Watcher-Poll([double]$now) {
    $p = $script:W.path
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return 0 }
    $size = (Get-Item -LiteralPath $p).Length
    $head = Read-Head $p
    if ($size -lt $script:W.offset -or ($null -ne $script:W.head -and $head -ne $script:W.head)) { $script:W.offset = 0 }
    $script:W.head = $head
    if ($size -gt $script:W.offset -and $script:FAST) {
        $r = [PdiScan]::Watch($p, [long]$script:W.offset)
        foreach ($u in $r[2]) { $script:W.units[$u] = 1 }
        if ($r[1]) { $script:W.ended = $true }
        $script:W.offset = [long]$r[0]
        $script:W.lastGrowth = $now
    } elseif ($size -gt $script:W.offset) {
        $fs = [System.IO.File]::Open($p, 'Open', 'Read', 'ReadWrite')
        try {
            [void]$fs.Seek($script:W.offset, 'Begin')
            $len = [int][math]::Min($size - $script:W.offset, 64MB)
            $buf = New-Object byte[] $len
            $n = $fs.Read($buf, 0, $len)
            $cut = -1
            if ($n -gt 0) { $cut = [Array]::LastIndexOf($buf, [byte]10, $n - 1) }
            if ($cut -ge 0) {
                $text = $UTF8.GetString($buf, 0, $cut + 1)
                foreach ($line in $text.Split("`n")) {
                    if ($line.Contains(',PLAYER_INFO,')) {
                        $parts = $line.Split([char[]]@(','), 4)
                        if ($parts.Count -gt 2) { $script:W.units[$parts[2]] = 1 }
                    } elseif ($line.Contains(',END_LOG')) { $script:W.ended = $true }
                }
                $script:W.offset += $cut + 1
            }
        } finally { $fs.Close() }
        $script:W.lastGrowth = $now
    }
    if ($script:W.units.Count -gt 0 -and ($script:W.ended -or ($now - $script:W.lastGrowth) -ge $IDLE_SEC)) {
        $count = $script:W.units.Count
        $script:W.units = @{}
        $script:W.ended = $false
        return $count
    }
    return 0
}

# --------------------------------------------------------------------------
# Local endpoint for the in-game Upload button (polled, no threads)
# --------------------------------------------------------------------------
$PAGE = @'
<!doctype html><html><head><meta charset="utf-8"><title>Lethal PVP Insights</title>
<style>body{background:#14120e;color:#e8e2cf;font:16px/1.5 Segoe UI,Arial,sans-serif;display:flex;
align-items:center;justify-content:center;height:90vh;margin:0}.box{max-width:560px;padding:28px 32px;
border:1px solid #6b604a;border-radius:8px;background:#1d1a14}h1{color:#c5c29e;font-size:20px;margin:0 0 12px}
.ok{color:#7fd47f}.err{color:#ff8a7a}small{color:#999}</style></head><body><div class="box">
<h1>Lethal PVP Insights</h1><p class="{CLS}">{MSG}</p><small>You can close this tab and return to the game.</small>
</div></body></html>
'@

function Start-Endpoint {
    try {
        $l = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback, $PORT)
        $l.Start()
        return $l
    } catch { return $null }
}

function Send-Page($client, [bool]$ok, [string]$msg, [string]$linkHref = '', [string]$linkText = '') {
    try {
        $stream = $client.GetStream()
        $code = '200 OK'
        $cls = 'err'; if ($ok) { $cls = 'ok' }
        $html = [System.Net.WebUtility]::HtmlEncode($msg)
        if ($linkHref) {
            $html += '</p><p><a href="' + $linkHref + '" style="display:inline-block;padding:8px 16px;background:#7a2a20;color:#fff;border-radius:4px;text-decoration:none">' +
                     [System.Net.WebUtility]::HtmlEncode($linkText) + '</a>'
        }
        $body = $UTF8.GetBytes($PAGE.Replace('{CLS}', $cls).Replace('{MSG}', $html))
        $hdr = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $code`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n")
        $stream.Write($hdr, 0, $hdr.Length)
        $stream.Write($body, 0, $body.Length)
        $stream.Flush()
    } catch { } finally { try { $client.Close() } catch { } }
}

# Handles one waiting browser request. With -AsyncImport (window mode) an /import request starts the
# background import and the browser gets its answer when that finishes (the window stays responsive).
# Returns the message of a request handled right away, or $null.
function Serve-Pending($listener, $cfg, [switch]$AsyncImport) {
    if ($null -eq $listener -or -not $listener.Pending()) { return $null }
    $client = $listener.AcceptTcpClient()
    $path = '/'; $query = ''
    try {
        $client.ReceiveTimeout = 2000
        $buf = New-Object byte[] 4096
        $n = $client.GetStream().Read($buf, 0, $buf.Length)
        $req = [System.Text.Encoding]::ASCII.GetString($buf, 0, [math]::Max(0, $n))
        if ($req -match '^[A-Z]+ (\S+)') {
            $parts = $Matches[1].Split('?', 2)
            $path = $parts[0]; if ($parts.Count -gt 1) { $query = $parts[1] }
        }
    } catch { try { $client.Close() } catch { }; return $null }
    Add-Caps (Query-Value $query 'caps')
    if ($script:KnownCaps.Count -gt 0) { Save-KnownCaps $cfg }

    if ($path -eq '/import') {
        if ($AsyncImport) {
            $err = Start-ImportJob $cfg
            if ($err) { Send-Page $client $false $err; return $err }
            [void]$script:Job.clients.Add($client)
            return 'Importing...'
        }
        $r = Do-Import $cfg
        Send-Page $client $r[0] $r[1]; return $r[1]
    }
    if ($path -eq '/deletelog') {
        if ($script:Job) { $m = 'An import is running - try again in a moment.'; Send-Page $client $false $m; return $m }
        $r = Do-DeleteLog $cfg ((Query-Value $query 'confirm') -eq '1')
        if ($r.Count -gt 2 -and $r[2] -eq 'confirm') {
            Send-Page $client $false $r[1] '/deletelog?confirm=1' 'Delete Encounter.log anyway'
            return 'Waiting for confirmation in the browser before deleting Encounter.log.'
        }
        Send-Page $client $r[0] $r[1]; return $r[1]
    }
    if ($path -eq '/' -or $path -eq '/status') { Send-Page $client $true 'The LPI Companion is running.'; return $null }
    Send-Page $client $false 'Not found.'
    return $null
}

# --------------------------------------------------------------------------
# Background import (window mode): a hidden second PowerShell process does the work, so a big
# Encounter.log never freezes the window ("Not Responding"). The window polls it from its timer.
# --------------------------------------------------------------------------
$script:Job = $null

function Quote-Arg([string]$s) { return '"' + $s.TrimEnd('\') + '"' }

# Returns $null when started (or already running), otherwise an error message
function Start-ImportJob($cfg) {
    if ($script:Job) { return $null }
    $log = [string]$cfg['log']; $addon = [string]$cfg['addon']
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { return "Encounter.log not found at $log - choose it with Browse..." }
    if (-not (Test-Path -LiteralPath $addon -PathType Container)) { return "Addon folder not found at $addon." }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File ' + (Quote-Arg $PSCommandPath) + ' -ImportOnly -LogPath ' +
                     (Quote-Arg $log) + ' -AddonDir ' + (Quote-Arg $addon)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    try { $p = [System.Diagnostics.Process]::Start($psi) } catch { return ('Import failed to start: ' + $_.Exception.Message) }
    $script:Job = @{
        proc = $p; started = Get-Date; clients = (New-Object System.Collections.ArrayList)
        out = $p.StandardOutput.ReadToEndAsync(); err = $p.StandardError.ReadToEndAsync()
    }
    return $null
}

# Returns @($ok, $message) once the background import has finished, otherwise $null
function Poll-ImportJob($cfg) {
    $j = $script:Job
    if ($null -eq $j -or -not $j.proc.HasExited) { return $null }
    $out = ''; $err = ''
    try { $out = [string]$j.out.Result } catch { }
    try { $err = [string]$j.err.Result } catch { }
    $ok = $false; $msg = ''
    foreach ($line in ($out -split "`r?`n")) {
        if ($line.StartsWith("PDI_RESULT`t")) {
            $p = $line.Split("`t")
            $ok = $true
            $msg = ("Imported {0} build record(s) - {1} players stored ({2:N0} lines in {3}s). Back in the game, click Reload UI (or type /reloadui)." -f $p[1], $p[2], [long]$p[3], $p[4])
        } elseif ($line.StartsWith("PDI_ERROR`t")) { $msg = 'Import failed: ' + $line.Substring(10) }
    }
    if (-not $ok -and -not $msg) {
        $e = $err.Trim(); if (-not $e) { $e = 'no result from the import process' }
        $msg = 'Import failed: ' + $e
    }
    if ($ok -and $cfg['deleteAfter']) { $msg = $msg + ' ' + (Auto-DeleteLog $cfg) }
    foreach ($c in $j.clients) { Send-Page $c $ok $msg }
    $script:Job = $null
    return @($ok, $msg)
}

# --------------------------------------------------------------------------
# Heartbeat for the game: LPI_Companion.lua is loaded with the addon, so on each UI load the
# in-game import window can tell whether the Companion was running (addons can't check that live).
# --------------------------------------------------------------------------
$HEARTBEAT_NAME = 'LPI_Companion.lua'
function Write-Heartbeat([string]$addon, [bool]$running) {
    try {
        $r = 'false'; if ($running) { $r = 'true' }
        $extra = ''
        foreach ($f in (Cloud-LuaFields)) { $extra += ', ' + $f }
        $txt = "-- Written by the LPI Companion while it runs - do not edit`nPVPDataInsight_Companion = { seen = " +
               (Unix-Now) + ", running = $r, edition = `"PowerShell`"$extra }`n"
        Write-TextAtomic (Join-Path $addon $HEARTBEAT_NAME) $txt
    } catch { }
}


# --------------------------------------------------------------------------
# esopvp.com: upload PVPDataInsight.lua (SavedVariables) after the game writes it - only after the
# player agreed. Same settings ("cloud" in PVPDataInsight_companion.json) as the Python edition.
# --------------------------------------------------------------------------
$COMPANION_VER = '2.3.2'
$API = 'https://esopvp.com/api/v1'
if ($env:PDI_API) { $API = $env:PDI_API.TrimEnd('/') }
$SITE = $API -replace '/api/.*$', ''
$CLOUD_SETTLE = 3
$CLOUD_RETRY = @(60, 120, 300, 600)
$CONSENT_TEXT = "Share your LPI data with esopvp.com?`n`n" +
    "After each /reloadui or logout the Companion uploads what Lethal PVP Insights recorded: the kill feed " +
    "(killer, victim, keep, time), your own kills and assists, builds you saw (class, skills, buffs, sets) " +
    "and your Data sharing settings. It also sends your guild names and a hashed friends list so your " +
    "sharing choices can be applied.`n`n" +
    "Opponent data and the kill feed feed the public stats. Group builds, saved builds and friendly " +
    "players are shown only to whom your Data sharing settings allow (addon settings).`n`n" +
    "You can stop uploading or delete everything you uploaded at any time. Privacy notice: $SITE/privacy"
$script:Cloud = $null          # the 'cloud' table of the settings
$script:CloudJob = $null
$script:CloudFails = 0
$script:CloudNext = 0

function Cloud-Table($cfg) {
    $c = $cfg['cloud']
    if (-not ($c -is [System.Collections.IDictionary])) { $c = New-HT; $cfg['cloud'] = $c }
    $script:Cloud = $c
    return $c
}

function Protect-Key([string]$k) {
    try {
        Add-Type -AssemblyName System.Security
        $p = [System.Security.Cryptography.ProtectedData]::Protect([System.Text.Encoding]::UTF8.GetBytes($k), $null, 'CurrentUser')
        return 'dpapi:' + [Convert]::ToBase64String($p)
    } catch { return 'plain:' + $k }
}

function Unprotect-Key([string]$s) {
    if (-not $s) { return '' }
    if ($s.StartsWith('plain:')) { return $s.Substring(6) }
    if ($s.StartsWith('dpapi:')) {
        try {
            Add-Type -AssemblyName System.Security
            $b = [System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($s.Substring(6)), $null, 'CurrentUser')
            return [System.Text.Encoding]::UTF8.GetString($b)
        } catch { return '' }
    }
    return ''
}

function Cloud-Key { if ($script:Cloud) { return (Unprotect-Key ([string]$script:Cloud['key'])) } return '' }
function Cloud-Enabled { return ($script:Cloud -and [bool]$script:Cloud['consent'] -and [bool](Cloud-Key)) }

# the game names the saved file after the addon folder: LethalPVPInsights.lua (PVPDataInsight.lua before
# the rename, used while the new one doesn't exist yet)
function Sv-Path([string]$addon) {
    $live = Split-Path -Parent (Split-Path -Parent $addon.TrimEnd('\'))
    $new = Join-Path $live 'SavedVariables\LethalPVPInsights.lua'
    $old = Join-Path $live 'SavedVariables\PVPDataInsight.lua'
    if ((Test-Path -LiteralPath $new -PathType Leaf) -or -not (Test-Path -LiteralPath $old -PathType Leaf)) { return $new }
    return $old
}

# Once after the rename: copy SavedVariables\PVPDataInsight.lua to LethalPVPInsights.lua so the renamed
# addon keeps everything recorded so far. Only while the game is closed (it rewrites the files on exit).
function Migrate-SavedData($cfg) {
    if ($cfg['svMigrated']) { return $null }
    $live = Split-Path -Parent (Split-Path -Parent ([string]$cfg['addon']).TrimEnd('\'))
    $old = Join-Path $live 'SavedVariables\PVPDataInsight.lua'
    $new = Join-Path $live 'SavedVariables\LethalPVPInsights.lua'
    if (-not (Test-Path -LiteralPath $old -PathType Leaf)) { $cfg['svMigrated'] = $true; return $null }
    if ((Test-Path -LiteralPath $new -PathType Leaf) -and ((Get-Item -LiteralPath $new).Length -ge (Get-Item -LiteralPath $old).Length)) {
        $cfg['svMigrated'] = $true; return $null
    }
    if (Get-Process -Name 'eso64' -ErrorAction SilentlyContinue) {
        return 'Close the game once so your saved data can move to the renamed addon (Lethal PVP Insights).'
    }
    try { Copy-Item -LiteralPath $old -Destination $new -Force } catch { return ('Could not move your saved data to the renamed addon: ' + $_.Exception.Message) }
    $cfg['svMigrated'] = $true
    return 'Your saved data was moved to the renamed addon (Lethal PVP Insights). Start the game as usual.'
}

# -> hashtable with ok / error / status / the answer's fields
function Cloud-Call([string]$method, [string]$path, [string]$key, [byte[]]$body, [string]$ctype = 'application/json', [int]$timeoutSec = 60) {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $res = New-HT
    try {
        $req = [System.Net.HttpWebRequest]::Create($API + $path)
        $req.Method = $method
        $req.Timeout = $timeoutSec * 1000
        $req.ReadWriteTimeout = $timeoutSec * 1000
        $req.UserAgent = 'PDI-Companion/' + $COMPANION_VER
        $req.Headers.Add('X-PDI-Companion', $COMPANION_VER)
        $req.Headers.Add('X-PDI-Clock', [string][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())   # server corrects kill times by it
        if ($key) { $req.Headers.Add('Authorization', 'Bearer ' + $key) }
        if ($null -ne $body) {
            $req.ContentType = $ctype
            $req.ContentLength = $body.Length
            $st = $req.GetRequestStream(); $st.Write($body, 0, $body.Length); $st.Close()
        }
        $resp = $req.GetResponse()
        $txt = (New-Object System.IO.StreamReader($resp.GetResponseStream(), $UTF8)).ReadToEnd()
        $resp.Close()
        $res = ConvertTo-HT ($txt | ConvertFrom-Json)
    } catch [System.Net.WebException] {
        $r = $_.Exception.Response
        if ($r) {
            $code = [int]$r.StatusCode
            $txt = ''
            try { $txt = (New-Object System.IO.StreamReader($r.GetResponseStream(), $UTF8)).ReadToEnd() } catch { }
            try { $res = ConvertTo-HT ($txt | ConvertFrom-Json) } catch { $res = New-HT }
            $res['ok'] = $false; $res['status'] = $code
            if (-not $res['error']) { $res['error'] = "server answered $code" }
        } else {
            $res['ok'] = $false; $res['error'] = 'could not reach esopvp.com (' + $_.Exception.Status + ')'
        }
    } catch {
        $res['ok'] = $false; $res['error'] = 'could not reach esopvp.com (' + $_.Exception.Message + ')'
    }
    if (-not ($res -is [System.Collections.IDictionary])) { $h = New-HT; $h['ok'] = $false; $h['error'] = 'bad answer'; $res = $h }
    return $res
}

function Cloud-Register {
    $b = $UTF8.GetBytes('{"consent": true, "companion": "' + $COMPANION_VER + '"}')
    return (Cloud-Call 'POST' '/register' '' $b)
}

function Gzip-File([string]$path) {
    $raw = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream
    $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
    $gz.Write($raw, 0, $raw.Length); $gz.Close()
    return ,$ms.ToArray()
}

# one upload; -> @($ok, $message, $status)
function Cloud-UploadOnce([string]$addon, [string]$key) {
    $p = Sv-Path $addon
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @($false, "PVPDataInsight.lua not found at $p", 0) }
    $body = Gzip-File $p
    $r = Cloud-Call 'POST' '/upload' $key $body 'application/gzip' 180
    if ($r['ok']) {
        $tok = ''
        $wt = $r['wipe_tokens']
        if ($wt -is [System.Collections.IDictionary]) { foreach ($k in $wt.Keys) { $tok += $k + '=' + [string]$wt[$k] + ';' } }
        $script:WipeTokens = $tok
        $script:ResetAt = 0; try { if ($r['reset_at']) { $script:ResetAt = [long]$r['reset_at'] } } catch { }
        $c = $r['counts']; $nk = 0; $nb = 0
        if ($c -is [System.Collections.IDictionary]) {
            foreach ($k in $c.Keys) { if ($k -eq 'kill_reports') { $nk = [int]$c[$k] } elseif ($k.StartsWith('builds_')) { $nb += [int]$c[$k] } }
        }
        return @($true, "uploaded $nk new kill(s), $nb build record(s)", 200)
    }
    return @($false, [string]$r['error'], [int]$r['status'])
}

# players other uploaders saw lately -> LPI_Shared.lua in the addon folder (read at /reloadui)
function Cloud-DownloadShared([string]$addon, [string]$key) {
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $req = [System.Net.HttpWebRequest]::Create($API + '/shared')
        $req.Method = 'GET'
        $req.Timeout = 120000; $req.ReadWriteTimeout = 120000
        $req.UserAgent = 'PDI-Companion/' + $COMPANION_VER
        $req.Headers.Add('X-PDI-Companion', $COMPANION_VER)
        $req.Headers.Add('Authorization', 'Bearer ' + $key)
        $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
        $resp = $req.GetResponse()
        $ms = New-Object System.IO.MemoryStream
        $resp.GetResponseStream().CopyTo($ms); $resp.Close()
        $bytes = $ms.ToArray()
        $head = $UTF8.GetString($bytes, 0, [Math]::Min(400, $bytes.Length))
        if (-not $head.StartsWith('--') -or -not $head.Contains('PVPDataInsight_Shared')) { return @($false, 'shared data: unexpected answer') }
        $dst = Join-Path $addon 'LPI_Shared.lua'
        $tmp = $dst + '.tmp'
        [System.IO.File]::WriteAllBytes($tmp, $bytes)
        Move-Item -LiteralPath $tmp -Destination $dst -Force
        return @($true, ('shared data updated ({0} KB)' -f [int]($bytes.Length / 1024)))
    } catch {
        return @($false, 'shared data: could not download (' + $_.Exception.Message + ')')
    }
}

function Lua-Q([string]$s) { return '"' + $s.Replace('\', '\\').Replace('"', '\"').Replace("`n", ' ').Replace("`r", '') + '"' }

function Cloud-LuaFields {
    $out = @()
    $c = $script:Cloud
    if (-not $c) { return $out }
    if ($c['consent'] -and $c['identifier']) { $out += ('identifier = ' + (Lua-Q ([string]$c['identifier']))) }
    $u = $c['uploaded']
    if ($u -is [System.Collections.IDictionary] -and $u.Count -gt 0) {
        $parts = @()
        foreach ($k in $u.Keys) { $parts += ('[' + (Lua-Q ([string]$k)) + '] = ' + [long]$u[$k]) }
        $out += ('uploaded = {' + ($parts -join ', ') + '}')
    }
    if ($c['clearAt']) { $out += ('clear = ' + [long]$c['clearAt']) }    # 'Clear collected data' button
    if ($c['resetAt']) { $out += ('reset = ' + [long]$c['resetAt']) }    # server data reset (clears everything)
    if ($c['mtime']) { try { $out += ('sent = ' + [long][double]$c['mtime']) } catch { } }   # file esopvp.com confirmed
    $l = $c['last']
    if ($l -is [System.Collections.IDictionary]) {
        $ok = 'false'; if ($l['ok']) { $ok = 'true' }
        $out += ('upload = { t = ' + [long]$l['t'] + ', ok = ' + $ok + ', msg = ' + (Lua-Q ([string]$l['msg'])) + ' }')
    }
    return $out
}

function Cloud-Due([double]$now) {
    if ($script:CloudJob -or -not (Cloud-Enabled) -or $now -lt $script:CloudNext) { return $false }
    $p = Sv-Path ([string]$cfg['addon'])
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $false }
    $m = [double]([DateTimeOffset](Get-Item -LiteralPath $p).LastWriteTimeUtc).ToUnixTimeSeconds()
    $seen = 0.0; try { $seen = [double]$script:Cloud['mtime'] } catch { }
    return ($m -gt $seen -and ($now - $m) -ge $CLOUD_SETTLE)
}

# upload in a hidden child process so the window never freezes
function Start-CloudJob($cfg) {
    if ($script:CloudJob) { return }
    $p = Sv-Path ([string]$cfg['addon'])
    $m = [double]([DateTimeOffset](Get-Item -LiteralPath $p).LastWriteTimeUtc).ToUnixTimeSeconds()
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File ' + (Quote-Arg $PSCommandPath) + ' -UploadOnly -AddonDir ' + (Quote-Arg ([string]$cfg['addon']))
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    if ($env:PDI_API) { $psi.EnvironmentVariables['PDI_API'] = $env:PDI_API }
    try { $proc = [System.Diagnostics.Process]::Start($psi) } catch { return }
    $script:CloudJob = @{ proc = $proc; mtime = $m; out = $proc.StandardOutput.ReadToEndAsync(); err = $proc.StandardError.ReadToEndAsync() }
}

# -> $null while running, else @($ok, $message)
function Poll-CloudJob($cfg) {
    $j = $script:CloudJob
    if ($null -eq $j -or -not $j.proc.HasExited) { return $null }
    $out = ''; try { $out = [string]$j.out.Result } catch { }
    $ok = $false; $msg = 'no result from the upload process'; $status = 0; $tokens = ''; $resetAt = 0
    foreach ($line in ($out -split "`r?`n")) {
        if ($line.StartsWith("PDI_UPLOAD`t")) {
            $p = $line.Split("`t")
            $ok = ($p[1] -eq '1'); $status = [int]$p[2]; $msg = $p[3]
            if ($p.Count -gt 4) { $tokens = $p[4] }
            if ($p.Count -gt 5) { try { $resetAt = [long]$p[5] } catch { } }
        }
    }
    if (-not $ok -and $msg -eq 'no result from the upload process') { try { $e = ([string]$j.err.Result).Trim(); if ($e) { $msg = $e } } catch { } }
    $c = Cloud-Table $cfg
    if ($ok) {
        $c['mtime'] = $j.mtime; $script:CloudFails = 0; $script:CloudNext = 0
        # the server's data was reset: the addon clears everything it collected before that time
        if ($resetAt -gt 0) { $c['resetAt'] = $resetAt }
        # tokens of a pending "clear local data": the addon clears only after seeing them
        if ($tokens) {
            $u = $c['uploaded']
            if (-not ($u -is [System.Collections.IDictionary])) { $u = New-HT; $c['uploaded'] = $u }
            foreach ($pair in $tokens.Split(';')) {
                $kv = $pair.Split('=')
                if ($kv.Count -eq 2 -and $kv[0]) { $u[$kv[0]] = [long]$kv[1] }
            }
        }
    } else {
        $script:CloudNext = (Unix-Now) + $CLOUD_RETRY[[math]::Min($script:CloudFails, $CLOUD_RETRY.Count - 1)]
        $script:CloudFails++
        if ($status -eq 401) {
            $c['key'] = ''; $c['identifier'] = ''
            $msg = "This PC's registration is no longer valid. Tick 'Upload to esopvp.com' again."
        }
    }
    $l = New-HT; $l['t'] = (Unix-Now); $l['ok'] = $ok; $l['msg'] = $msg
    $c['last'] = $l
    Save-Settings $cfg
    Write-Heartbeat ([string]$cfg['addon']) $true
    $script:CloudJob = $null
    return @($ok, $msg)
}

# --------------------------------------------------------------------------
# Settings and paths
# --------------------------------------------------------------------------
$HERE = $PSScriptRoot
if (-not $HERE) { $HERE = Split-Path -Parent $MyInvocation.MyCommand.Path }
$paths = Get-DefaultPaths
$defLog = $paths[1]
if ($LogPath) { $defLog = $LogPath }

# ...\live\Logs\Encounter.log -> ...\live\AddOns\LethalPVPInsights (PVPDataInsight before the rename;
# falls back to the folder this script is in)
function Addon-FromLog([string]$log) {
    if ($AddonDir) { return $AddonDir }
    try {
        $live = Split-Path -Parent (Split-Path -Parent $log)
        foreach ($name in @('AddOns\LethalPVPInsights', 'Addons\LethalPVPInsights', 'AddOns\PVPDataInsight', 'Addons\PVPDataInsight')) {
            $cand = Join-Path $live $name
            if (Test-Path -LiteralPath $cand -PathType Container) { return (Get-Item -LiteralPath $cand).FullName }
        }
    } catch { }
    return $HERE
}

# Settings live outside the addon folder (%APPDATA%\PDI Companion), so replacing or deleting the addon
# folder for an update keeps the esopvp.com registration and the other choices.
function Settings-Dir { if ($env:APPDATA) { return (Join-Path $env:APPDATA 'PDI Companion') } return $HERE }
function Settings-Path { return (Join-Path (Settings-Dir) $SETTINGS_NAME) }

function Load-Settings {
    $s = New-HT
    $s['log'] = $defLog; $s['watch'] = $true; $s['auto'] = $true; $s['firstRun'] = $true; $s['deleteAfter'] = $false
    $j = Read-JsonFile (Settings-Path)
    # older versions kept the file in the addon folder
    if (-not ($j -is [System.Collections.IDictionary])) { $j = Read-JsonFile (Join-Path $HERE $SETTINGS_NAME) }
    if ($j -is [System.Collections.IDictionary]) { foreach ($k in $j.Keys) { $s[$k] = $j[$k] } }
    if ($LogPath) { $s['log'] = $LogPath }
    $s['addon'] = Addon-FromLog ([string]$s['log'])
    return $s
}

# remembered between runs, so a capture confirmed through the Upload link stays confirmed
function Save-KnownCaps($s) {
    $cut = (Unix-Now) - 30 * 86400
    $list = New-Object System.Collections.ArrayList
    foreach ($k in $script:KnownCaps) { if ($k -ge $cut) { [void]$list.Add($k) } }
    $s['knownCaps'] = $list
    Save-Settings $s
}

function Save-Settings($s) {
    try {
        $d = Settings-Dir
        if (-not (Test-Path -LiteralPath $d)) { [void](New-Item -ItemType Directory -Path $d -Force) }
        Write-TextAtomic (Settings-Path) (To-Json $s)
    } catch { }
}

# "Start with Windows" and the desktop shortcut both run the one launcher, LPI COMPANION.bat
$LAUNCHER = Join-Path $HERE 'LPI COMPANION.bat'
$ICON = Join-Path $HERE 'LPI.ico'

function Startup-Dir {
    if (-not $env:APPDATA) { return $null }
    return (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup')
}
function Startup-BatPath { $d = Startup-Dir; if ($d) { return (Join-Path $d 'LPI Companion.bat') } return $null }
$OLD_STARTUP = @('PVPDI Companion.bat', 'PDI Companion.bat')      # names older versions used

function Write-Startup([string]$bat) {
    foreach ($n in @('PVPDI Companion.bat', 'PDI Companion.bat')) {     # names older versions used
        $old = Join-Path (Startup-Dir) $n
        if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
    }
    $line = '@echo off' + "`r`n" + 'call "' + $LAUNCHER + '" --background' + "`r`n"
    [System.IO.File]::WriteAllText($bat, $line, (New-Object System.Text.ASCIIEncoding))
}

# older versions wrote "PVPDI Companion.bat" into Startup - point it at the new launcher
function Migrate-Startup {
    $d = Startup-Dir
    if (-not $d) { return }
    $cur = Startup-BatPath
    $stale = $false
    if ($cur -and (Test-Path -LiteralPath $cur)) {      # points at a launcher in another (the old) addon folder
        try { $stale = -not ([System.IO.File]::ReadAllText($cur).ToLower().Contains($LAUNCHER.ToLower())) } catch { }
    }
    if ($stale) { try { Write-Startup $cur } catch { }; return }
    foreach ($n in $OLD_STARTUP) {
        if (Test-Path -LiteralPath (Join-Path $d $n)) { try { Write-Startup (Startup-BatPath) } catch { }; break }
    }
}

function Shortcut-Path { return (Join-Path ([Environment]::GetFolderPath('Desktop')) 'LPI Companion.lnk') }

$FOLDER_SHORTCUT = 'Lethal PVP Insights Companion.lnk'

function Write-Shortcut([string]$Path = '') {
    if (-not $Path) { $Path = Shortcut-Path }
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($Path)
    $lnk.TargetPath = $LAUNCHER
    $lnk.WorkingDirectory = $HERE
    $lnk.WindowStyle = 7
    $lnk.Description = 'Lethal PVP Insights Companion - imports gear and skill bars from Encounter.log'
    if (Test-Path -LiteralPath $ICON) { $lnk.IconLocation = $ICON + ',0' }
    $lnk.Save()
}

# --------------------------------------------------------------------------
# Modes
# --------------------------------------------------------------------------
if ($ImportOnly) {
    $log = $defLog
    $addon = Addon-FromLog $log
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { Write-Output "Encounter.log not found at:`n  $log"; Write-Output "PDI_ERROR`tEncounter.log not found at $log"; exit 1 }
    try {
        $r = Run-Import $log $addon ([bool]$Reset)
    } catch {
        Write-Output ("PDI_ERROR`t" + $_.Exception.Message)
        exit 1
    }
    Write-Output 'Lethal PVP Insights importer (PowerShell)'
    Write-Output ("  log:      " + $log)
    Write-Output ("  read:     {0:N0} new lines in {1:N1}s" -f $r.lines, $r.seconds)
    Write-Output ("  builds:   {0} build records read, {1} accounts stored (max {2})" -f $r.found, $r.total, $MAX_ACCOUNTS)
    Write-Output 'Done - type /reloadui in game to load the builds.'
    Write-Output ("PDI_RESULT`t{0}`t{1}`t{2}`t{3}" -f $r.found, $r.total, $r.lines, [math]::Round($r.seconds, 1).ToString([System.Globalization.CultureInfo]::InvariantCulture))
    exit 0
}

if ($UploadOnly) {
    $cfg = Load-Settings
    $c = Cloud-Table $cfg
    $key = Cloud-Key
    if (-not $c['consent'] -or -not $key) { Write-Output "PDI_UPLOAD`t0`t0`tuploads are off"; exit 1 }
    $r = Cloud-UploadOnce ([string]$cfg['addon']) $key
    if ([int]$r[2] -ne 401) {
        $sh = Cloud-DownloadShared ([string]$cfg['addon']) $key
        if ($r[0] -and -not $sh[0]) { $r[1] = [string]$r[1] + '; ' + [string]$sh[1] }
    }
    $okf = '0'; if ($r[0]) { $okf = '1' }
    Write-Output ("PDI_UPLOAD`t{0}`t{1}`t{2}`t{3}`t{4}" -f $okf, $r[2], ([string]$r[1]).Replace("`t", ' ').Replace("`n", ' '), [string]$script:WipeTokens, [string][long]$script:ResetAt)
    exit 0
}

$cfg = Load-Settings
[void](Cloud-Table $cfg)
foreach ($k in (As-List $cfg['knownCaps'])) { $v = [long]0; if ([long]::TryParse([string]$k, [ref]$v)) { [void]$script:KnownCaps.Add($v) } }
$listener = Start-Endpoint
$guiOk = $false
if (-not $NoGui) {
    try { Add-Type -AssemblyName System.Windows.Forms, System.Drawing; $guiOk = $true } catch { $guiOk = $false }
}

if ($null -eq $listener) {
    if ($guiOk) { [void][System.Windows.Forms.MessageBox]::Show('The LPI Companion is already running (look for it in the taskbar).', 'Lethal PVP Insights') }
    else { Write-Output 'The LPI Companion is already running.' }
    exit 0
}

Watcher-Reset ([string]$cfg['log'])
$firstRun = [bool]$cfg['firstRun']
$sbat = Startup-BatPath
if ($firstRun -and $sbat) { try { Write-Startup $sbat } catch { } } else { Migrate-Startup }
# a shortcut with the icon next to LPI COMPANION.bat in the addon folder (made again when the folder moved)
try {
    $hereLnk = Join-Path $HERE $FOLDER_SHORTCUT
    if (-not (Test-Path -LiteralPath $hereLnk) -or [string]$cfg['shortcutFolder'] -ne $HERE) { Write-Shortcut $hereLnk }
} catch { }
# the shortcut of older versions ("PDI Companion") points at the old launcher: replace it
try {
    $oldLnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'PDI Companion.lnk'
    if (Test-Path -LiteralPath $oldLnk) { Remove-Item -LiteralPath $oldLnk -Force; Write-Shortcut }
    elseif ((Test-Path -LiteralPath (Shortcut-Path)) -and [string]$cfg['shortcutFolder'] -ne $HERE) { Write-Shortcut }   # folder renamed/moved
    $cfg['shortcutFolder'] = $HERE
} catch { }
if (-not $cfg['shortcutDone']) {
    try { Write-Shortcut } catch { }
    $cfg['shortcutDone'] = $true
}
$cfg['firstRun'] = $false
Save-Settings $cfg
Write-Heartbeat ([string]$cfg['addon']) $true

if (-not $guiOk) {
    # console mode: watcher + Upload endpoint
    Write-Output "LPI Companion running (no window). Upload endpoint: http://127.0.0.1:$PORT/import  - Ctrl+C to stop."
    $last = 0; $lastBeat = [double](Unix-Now)
    try {
        while ($true) {
            $m = Serve-Pending $listener $cfg
            if ($m) { Write-Output ("In-game Upload: " + $m) }
            $now = [double](Unix-Now)
            if ($now - $lastBeat -ge 60) {
                $lastBeat = $now; Write-Heartbeat ([string]$cfg['addon']) $true
                $m2 = Retry-PendingDelete $cfg; if ($m2) { Write-Output $m2 }
            }
            if (Cloud-Due $now) { Start-CloudJob $cfg }
            if ($script:CloudJob) { $cr = Poll-CloudJob $cfg; if ($cr) { Write-Output ('esopvp.com: ' + $cr[1]) } }
            if ($now - $last -ge 1.5) {
                $last = $now
                $n = 0
                if ($cfg['watch']) { try { $n = Watcher-Poll $now } catch { $n = 0 } }
                if ($n -gt 0) {
                    if ($cfg['auto']) { $r = Do-Import $cfg; Write-Output $r[1] }
                    else { Write-Output "Fight captured - $n player(s). Run with -ImportOnly or enable auto import." }
                }
            }
            Start-Sleep -Milliseconds 200
        }
    } finally { Write-Heartbeat ([string]$cfg['addon']) $false }
}

# ---------- Window ----------
# hide the console this script runs in (when it was started without -WindowStyle Hidden)
try {
    Add-Type -Name PdiWin -Namespace Pdi -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);' -ErrorAction Stop
    $cw = [Pdi.PdiWin]::GetConsoleWindow()
    if ($cw -ne [IntPtr]::Zero) { [void][Pdi.PdiWin]::ShowWindow($cw, 0) }
} catch { }

[System.Windows.Forms.Application]::EnableVisualStyles()
$font = New-Object System.Drawing.Font('Segoe UI', 9)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'LPI Companion - Encounter Log Import'
$form.Size = New-Object System.Drawing.Size(780, 420)
$form.MinimumSize = New-Object System.Drawing.Size(640, 410)
$form.StartPosition = 'CenterScreen'
$form.Font = $font
if (Test-Path -LiteralPath $ICON) { try { $form.Icon = New-Object System.Drawing.Icon($ICON) } catch { } }

function Add-Ctl($ctl, [int]$x, [int]$y, [int]$w, [int]$h) {
    $ctl.Location = New-Object System.Drawing.Point($x, $y)
    $ctl.Size = New-Object System.Drawing.Size($w, $h)
    $form.Controls.Add($ctl)
    return $ctl
}

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Lethal PVP Insights Companion  -  by Lethal2k'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
[void](Add-Ctl $title 12 10 500 28)

$lblLog = New-Object System.Windows.Forms.Label; $lblLog.Text = 'Encounter.log:'; [void](Add-Ctl $lblLog 12 50 100 22)
$txtLog = New-Object System.Windows.Forms.TextBox; $txtLog.Text = [string]$cfg['log']; $txtLog.Anchor = 'Top,Left,Right'; [void](Add-Ctl $txtLog 115 48 530 24)
$btnLog = New-Object System.Windows.Forms.Button; $btnLog.Text = 'Browse...'; $btnLog.Anchor = 'Top,Right'; [void](Add-Ctl $btnLog 655 46 95 28)
$lblAdd = New-Object System.Windows.Forms.Label; $lblAdd.ForeColor = [System.Drawing.Color]::DimGray; $lblAdd.Anchor = 'Top,Left,Right'; [void](Add-Ctl $lblAdd 115 76 635 20)
function Show-AddonPath { $lblAdd.Text = 'Builds are saved to: ' + [string]$cfg['addon'] }
Show-AddonPath

$chkWatch = New-Object System.Windows.Forms.CheckBox; $chkWatch.Text = 'Pop up after each captured fight'; $chkWatch.Checked = [bool]$cfg['watch']; [void](Add-Ctl $chkWatch 12 104 220 24)
$chkAuto = New-Object System.Windows.Forms.CheckBox; $chkAuto.Text = 'Import automatically'; $chkAuto.Checked = [bool]$cfg['auto']; [void](Add-Ctl $chkAuto 235 104 150 24)
$chkDelete = New-Object System.Windows.Forms.CheckBox; $chkDelete.Text = 'Delete log after import'; $chkDelete.Checked = [bool]$cfg['deleteAfter']; [void](Add-Ctl $chkDelete 388 104 165 24)
$chkStart = New-Object System.Windows.Forms.CheckBox; $chkStart.Text = 'Start with Windows'; [void](Add-Ctl $chkStart 555 104 140 24)
$chkStart.Checked = ($sbat -and (Test-Path -LiteralPath $sbat))
if (-not $sbat) { $chkStart.Enabled = $false }
$chkLnk = New-Object System.Windows.Forms.CheckBox; $chkLnk.Text = 'Desktop shortcut'; [void](Add-Ctl $chkLnk 12 128 220 24)
$chkLnk.Checked = (Test-Path -LiteralPath (Shortcut-Path))

$btnImport = New-Object System.Windows.Forms.Button; $btnImport.Text = 'Import'; $btnImport.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold); [void](Add-Ctl $btnImport 12 160 160 32)
$btnDel = New-Object System.Windows.Forms.Button; $btnDel.Text = 'Delete log now'; [void](Add-Ctl $btnDel 182 160 120 32)
$btnHide = New-Object System.Windows.Forms.Button; $btnHide.Text = 'Hide'; [void](Add-Ctl $btnHide 312 160 90 32)

$status = New-Object System.Windows.Forms.Label
$status.Anchor = 'Top,Left,Right'
$status.Text = 'Watching for captured fights. Leave this running while you play.'
if ($firstRun) { $status.Text = 'Ready. The Companion now starts with Windows and imports captured fights automatically - in game you only need to click Reload UI.' }
[void](Add-Ctl $status 12 204 740 50)


# ---------- esopvp.com ----------
$grp = New-Object System.Windows.Forms.GroupBox; $grp.Text = 'esopvp.com'; $grp.Anchor = 'Top,Left,Right'
[void](Add-Ctl $grp 12 258 740 110)
function Add-G($ctl, [int]$x, [int]$y, [int]$w, [int]$h) {
    $ctl.Location = New-Object System.Drawing.Point($x, $y); $ctl.Size = New-Object System.Drawing.Size($w, $h)
    $grp.Controls.Add($ctl); return $ctl
}
$chkCloud = New-Object System.Windows.Forms.CheckBox; $chkCloud.Text = 'Upload my LPI data to esopvp.com'
[void](Add-G $chkCloud 10 20 250 24)
$lblIdent = New-Object System.Windows.Forms.Label; $lblIdent.Font = New-Object System.Drawing.Font('Consolas', 10)
[void](Add-G $lblIdent 265 22 460 22)
$btnCopy = New-Object System.Windows.Forms.Button; $btnCopy.Text = 'Copy Identifier'; [void](Add-G $btnCopy 10 48 120 28)
$btnSite = New-Object System.Windows.Forms.Button; $btnSite.Text = 'Open esopvp.com'; [void](Add-G $btnSite 136 48 125 28)
$btnNewId = New-Object System.Windows.Forms.Button; $btnNewId.Text = 'New Identifier'; [void](Add-G $btnNewId 267 48 110 28)
$btnDelCloud = New-Object System.Windows.Forms.Button; $btnDelCloud.Text = 'Clear collected data'; [void](Add-G $btnDelCloud 383 48 170 28)
$lblUp = New-Object System.Windows.Forms.Label; $lblUp.ForeColor = [System.Drawing.Color]::DimGray; $lblUp.Anchor = 'Top,Left,Right'
[void](Add-G $lblUp 10 80 720 22)
$script:cloudInit = $true
$chkCloud.Checked = [bool]$script:Cloud['consent']
$script:cloudInit = $false

function Refresh-Cloud {
    $c = $script:Cloud
    if ($c['consent'] -and $c['identifier']) { $lblIdent.Text = 'Identifier: ' + [string]$c['identifier'] }
    else { $lblIdent.Text = 'Identifier: - (tick Upload to get one)' }
    $l = $c['last']
    if (-not $c['consent']) { $lblUp.Text = 'Uploads are off. Nothing leaves this PC.' }
    elseif ($script:CloudJob) { $lblUp.Text = 'Uploading to esopvp.com...' }
    elseif ($l -is [System.Collections.IDictionary]) {
        $when = ([DateTimeOffset]::FromUnixTimeSeconds([long]$l['t'])).LocalDateTime.ToString('HH:mm')
        $res = 'failed - '; if ($l['ok']) { $res = 'OK - ' }
        $lblUp.Text = "Last upload ${when}: " + $res + [string]$l['msg']
    } else { $lblUp.Text = 'Waiting for the game to save (after /reloadui, logout or exit).' }
    if ($c['consent'] -and -not (Cloud-Key)) {
        $lblUp.Text = "This PC's esopvp.com key can't be read - untick and tick 'Upload' again to fix it."
    }
    $en = [bool](Cloud-Enabled)
    $btnCopy.Enabled = $en; $btnSite.Enabled = $en; $btnNewId.Enabled = $en
}

function Set-Consent {
    $c = $script:Cloud
    if ($chkCloud.Checked) {
        if (-not (Cloud-Key)) {
            $r = Cloud-Register
            if (-not $r['ok']) {
                $script:cloudInit = $true; $chkCloud.Checked = $false; $script:cloudInit = $false
                [void][System.Windows.Forms.MessageBox]::Show('Registration failed: ' + [string]$r['error'], 'esopvp.com')
                Refresh-Cloud; return
            }
            $c['key'] = Protect-Key ([string]$r['key']); $c['identifier'] = [string]$r['identifier']
        }
        $c['consent'] = $true; $c['consentAt'] = (Unix-Now); $c['mtime'] = 0
    } else { $c['consent'] = $false }
    $c['asked'] = $true
    Save-Settings $cfg
    Write-Heartbeat ([string]$cfg['addon']) $true
    Refresh-Cloud
}

$chkCloud.Add_CheckedChanged({ if (-not $script:cloudInit) { Set-Consent } })
$btnCopy.Add_Click({ [System.Windows.Forms.Clipboard]::SetText([string]$script:Cloud['identifier']); $status.Text = 'Identifier copied. Paste it on esopvp.com when you register.' })
$btnSite.Add_Click({ Start-Process ($SITE + '/register') })
$btnNewId.Add_Click({
    $ans = [System.Windows.Forms.MessageBox]::Show('Make a new Identifier? The old one stops working; a website account already linked to this PC stays linked.', 'New Identifier', 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }
    $r = Cloud-Call 'POST' '/identifier' (Cloud-Key) ($UTF8.GetBytes('{}'))
    if ($r['ok']) { $script:Cloud['identifier'] = [string]$r['identifier']; Save-Settings $cfg; Write-Heartbeat ([string]$cfg['addon']) $true }
    else { [void][System.Windows.Forms.MessageBox]::Show([string]$r['error'], 'esopvp.com') }
    Refresh-Cloud
})
$btnDelCloud.Add_Click({
    $msg = "Clear the data Lethal PVP Insights collected on this PC (kill counts, kill feed, opponents, group history, " +
           "targeted players, gear from the encounter log)?`n`nSaved builds and your settings are kept. Anything already " +
           "uploaded stays on esopvp.com.`n`nIt's done by the addon the next time it loads: type /reloadui in game (or log in)."
    $ans = [System.Windows.Forms.MessageBox]::Show($msg, 'Clear collected data', 'YesNo', 'Warning')
    if ($ans -ne 'Yes') { return }
    $script:Cloud['clearAt'] = (Unix-Now)
    Save-Settings $cfg; Write-Heartbeat ([string]$cfg['addon']) $true
    $status.Text = 'Collected data will be cleared at your next /reloadui (saved builds are kept).'
})
Refresh-Cloud

function Persist {
    $cfg['log'] = $txtLog.Text
    $cfg['addon'] = Addon-FromLog $txtLog.Text
    Show-AddonPath
    $cfg['watch'] = $chkWatch.Checked; $cfg['auto'] = $chkAuto.Checked; $cfg['deleteAfter'] = $chkDelete.Checked
    Save-Settings $cfg
    if ($script:W.path -ne $cfg['log']) { Watcher-Reset ([string]$cfg['log']) }
}

function Popup {
    $form.Show()
    $form.WindowState = 'Normal'
    $form.TopMost = $true
    $form.Activate()
    $form.TopMost = $false
    [System.Media.SystemSounds]::Asterisk.Play()
}

function Run-GuiImport {
    if ($script:Job) { return }
    Persist
    $err = Start-ImportJob $cfg
    if ($err) { $status.Text = $err; return }
    $btnImport.Enabled = $false; $btnDel.Enabled = $false
    $status.Text = 'Importing...'
}

$btnLog.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = 'Select Encounter.log'; $dlg.FileName = 'Encounter.log'; $dlg.Filter = 'Encounter log (*.log)|*.log|All files (*.*)|*.*'
    if ($dlg.ShowDialog() -eq 'OK') { $txtLog.Text = $dlg.FileName; Persist }
})
$txtLog.Add_Leave({ Persist })
$chkWatch.Add_CheckedChanged({ Persist })
$chkAuto.Add_CheckedChanged({ Persist })
$chkDelete.Add_CheckedChanged({ Persist })
$btnDel.Add_Click({
    Persist
    $r = Do-DeleteLog $cfg
    if ($r.Count -gt 2 -and $r[2] -eq 'confirm') {
        $ans = [System.Windows.Forms.MessageBox]::Show($r[1], 'Delete Encounter.log?', 'YesNo', 'Warning')
        if ($ans -eq 'Yes') { $r = Do-DeleteLog $cfg $true } else { $r = @($false, 'Encounter.log was kept.') }
    }
    $status.Text = $r[1]
})
$chkStart.Add_CheckedChanged({
    try {
        if ($chkStart.Checked) { Write-Startup $sbat } elseif (Test-Path -LiteralPath $sbat) { Remove-Item -LiteralPath $sbat -Force }
    } catch { $status.Text = 'Could not change the startup entry: ' + $_.Exception.Message }
})
$chkLnk.Add_CheckedChanged({
    try {
        if ($chkLnk.Checked) { Write-Shortcut } elseif (Test-Path -LiteralPath (Shortcut-Path)) { Remove-Item -LiteralPath (Shortcut-Path) -Force }
    } catch { $status.Text = 'Could not change the desktop shortcut: ' + $_.Exception.Message }
})
$btnImport.Add_Click({ Run-GuiImport })
$btnHide.Add_Click({ $form.WindowState = 'Minimized' })

$script:tickCount = 0
$script:beatCount = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200
$timer.Add_Tick({
    $m = Serve-Pending $listener $cfg -AsyncImport
    if ($m) { $status.Text = 'From the game: ' + $m }
    if ($m -eq 'Importing...') { $btnImport.Enabled = $false; $btnDel.Enabled = $false }
    if ($script:Job) {
        $done = Poll-ImportJob $cfg
        if ($done) {
            $status.Text = $done[1]
            $btnImport.Enabled = $true; $btnDel.Enabled = $true
        } else {
            $status.Text = ('Importing... {0:N0}s (big logs take a little longer - the window stays usable)' -f ((Get-Date) - $script:Job.started).TotalSeconds)
        }
    }
    if ($script:PendingDelete -and -not $script:Job -and ($script:beatCount % 50) -eq 0) {
        $m2 = Retry-PendingDelete $cfg
        if ($m2) { $status.Text = $m2 }
    }
    if (($script:beatCount % 10) -eq 0) {
        if ($script:CloudJob) { $cr = Poll-CloudJob $cfg; if ($cr) { Refresh-Cloud } }
        elseif (Cloud-Due ([double](Unix-Now))) { Start-CloudJob $cfg; Refresh-Cloud }
    }
    if (-not $cfg['svMigrated'] -and ($script:beatCount % 100) -eq 1) {     # the renamed addon's saved data
        $m3 = Migrate-SavedData $cfg
        if ($cfg['svMigrated']) { Save-Settings $cfg }
        if ($m3) { $status.Text = $m3 }
    }
    $script:beatCount++
    if ($script:beatCount -ge 300) { $script:beatCount = 0; Write-Heartbeat ([string]$cfg['addon']) $true }   # every minute
    $script:tickCount++
    if ($script:tickCount -ge 7 -and $chkWatch.Checked) {
        $script:tickCount = 0
        $n = 0
        try { $n = Watcher-Poll ([double](Unix-Now)) } catch { $n = 0 }
        if ($n -gt 0) {
            $status.Text = "Fight captured - gear & skill bars for $n player(s) are in the log. Click Import."
            if ($chkAuto.Checked) { Run-GuiImport } else { Popup }
        }
    }
})
$timer.Start()

$form.Add_FormClosed({
    $timer.Stop()
    try { $listener.Stop() } catch { }
    Write-Heartbeat ([string]$cfg['addon']) $false
})
if ($Background) { $form.WindowState = 'Minimized' }
[void][System.Windows.Forms.Application]::Run($form)
