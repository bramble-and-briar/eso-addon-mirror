#!/usr/bin/env python3
"""
Lethal PVP Insights Companion

A small desktop window that sits next to the game. It watches Encounter.log and, as soon as the
addon switches the log off after a fight, pops up with the log path already filled in so you can
import the captured gear & skill bars with one click. Then /reloadui in game.

Start it by double-clicking "LPI COMPANION.bat" (Windows) or `python3 LPI_Companion.pyw`.
Standard library only (tkinter ships with Python on Windows and macOS).
"""
import html
import json
import os
import queue
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import LPI_Import as importer  # noqa: E402
import LPI_Cloud as cloud  # noqa: E402

UPLOADER = None   # cloud.Uploader once the window runs (its status goes into the heartbeat file)

SETTINGS_NAME = "PVPDataInsight_companion.json"
POLL_MS = 1500
IDLE_SEC = 20          # no new log lines for this long after a fight = capture finished
PORT = 47613           # local web endpoint used by the in-game Upload button (also the single-instance guard)
HEARTBEAT_NAME = "LPI_Companion.lua"
LAUNCHER = os.path.join(HERE, "LPI COMPANION.bat")
OLD_STARTUP = ("PVPDI Companion.bat", "PDI Companion.bat")      # names older versions used
OLD_SHORTCUT = "PDI Companion.lnk"
ICON = os.path.join(HERE, "LPI.ico")
NO_WINDOW = 0x08000000  # CREATE_NO_WINDOW


# --------------------------------------------------------------------------
# Log watcher (no GUI code, so it can be tested on its own)
# --------------------------------------------------------------------------
class LogWatcher:
    CHUNK = 4 * 1024 * 1024

    def __init__(self, path, from_start=False):
        self.path = path
        self.offset = 0 if from_start or not os.path.isfile(path) else os.path.getsize(path)
        self.units = set()
        self.ended = False
        self.last_growth = 0.0
        self.head = importer.read_head(path) if os.path.isfile(path) else None

    def set_path(self, path):
        if path != self.path:
            self.__init__(path)

    def poll(self, now):
        """Returns the number of players captured once a capture has finished, else None."""
        if not os.path.isfile(self.path):
            return None
        size = os.path.getsize(self.path)
        head = importer.read_head(self.path)
        if size < self.offset or (self.head is not None and head != self.head):
            self.offset = 0
        self.head = head
        if size > self.offset:
            with open(self.path, "rb") as f:
                f.seek(self.offset)
                while self.offset < size:
                    data = f.read(min(self.CHUNK, size - self.offset))
                    if not data:
                        break
                    cut = data.rfind(b"\n")
                    if cut < 0:
                        break
                    self._scan(data[:cut + 1])
                    self.offset += cut + 1
                    f.seek(self.offset)
            self.last_growth = now
        if self.units and (self.ended or now - self.last_growth >= IDLE_SEC):
            n = len(self.units)
            self.units, self.ended = set(), False
            return n
        return None

    def _scan(self, data):
        for line in data.split(b"\n"):
            if b",PLAYER_INFO," in line:
                parts = line.split(b",", 3)
                if len(parts) > 2:
                    self.units.add(parts[2])
            elif b",END_LOG" in line:
                self.ended = True


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------
def addon_from_log(log):
    """.../live/Logs/Encounter.log -> .../live/AddOns/LethalPVPInsights (else the folder this script is in)."""
    live = os.path.dirname(os.path.dirname(os.path.abspath(log)))
    for folder in ("LethalPVPInsights", "PVPDataInsight"):       # PVPDataInsight = before the rename
        for name in ("AddOns", "Addons"):
            cand = os.path.join(live, name, folder)
            if os.path.isdir(cand):
                return cand
    return HERE


def settings_dir():
    """Settings live outside the addon folder (%APPDATA%\\PDI Companion), so replacing or deleting the
    addon folder for an update keeps the esopvp.com registration and the other choices."""
    base = os.environ.get("APPDATA")
    return os.path.join(base, "PDI Companion") if base else HERE


def settings_path():
    return os.path.join(settings_dir(), SETTINGS_NAME)


def load_settings(default_log):
    s = {"log": default_log, "watch": True, "auto": True, "firstRun": True, "deleteAfter": False}
    # the new place first; older versions kept the file in the addon folder
    for path in (settings_path(), os.path.join(HERE, SETTINGS_NAME)):
        try:
            with open(path, "r", encoding="utf-8") as f:
                s.update(json.load(f))
            break
        except (OSError, ValueError):
            continue
    s["addon"] = addon_from_log(s["log"])
    return s


def save_settings(s):
    try:
        os.makedirs(settings_dir(), exist_ok=True)
        tmp = settings_path() + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(s, f, indent=2)
        os.replace(tmp, settings_path())
    except OSError:
        pass


def write_heartbeat(addon, running):
    """The game loads this file with the addon, so the in-game import window knows if we were running."""
    try:
        path = os.path.join(addon, HEARTBEAT_NAME)
        extra = "".join(", " + f for f in (UPLOADER.lua_fields() if UPLOADER else []))
        with open(path + ".tmp", "w", encoding="utf-8") as f:
            f.write("-- Written by the LPI Companion while it runs - do not edit\n"
                    "PVPDataInsight_Companion = {{ seen = {}, running = {}, edition = \"Python\"{} }}\n".format(
                        int(time.time()), "true" if running else "false", extra))
        os.replace(path + ".tmp", path)
    except OSError:
        pass


def pythonw_exe():
    """pythonw.exe next to the interpreter running us (works for py launcher, python.org and venv installs)."""
    exe = sys.executable or ""
    cand = os.path.join(os.path.dirname(exe), "pythonw.exe")
    return cand if os.path.isfile(cand) else exe


def startup_dir():
    appdata = os.environ.get("APPDATA")
    return os.path.join(appdata, "Microsoft", "Windows", "Start Menu", "Programs", "Startup") if appdata else None


def startup_bat_path():
    d = startup_dir()
    return os.path.join(d, "LPI Companion.bat") if d else None


def write_startup(path):
    """Start with Windows = run the one launcher, LPI COMPANION.bat, in background mode."""
    for name in OLD_STARTUP:
        old = os.path.join(startup_dir() or "", name)
        if os.path.isfile(old):
            os.remove(old)
    with open(path, "w", encoding="utf-8") as f:
        f.write('@echo off\r\ncall "{}" --background\r\n'.format(LAUNCHER))


def migrate_startup():
    """Older versions wrote "PVPDI Companion.bat" / "PDI Companion.bat" into Startup - point it at the new launcher."""
    d = startup_dir()
    cur = startup_bat_path()
    stale = False
    if cur and os.path.isfile(cur):
        try:
            stale = LAUNCHER.lower() not in open(cur, encoding="utf-8", errors="replace").read().lower()
        except OSError:
            pass
    if d and (stale or any(os.path.isfile(os.path.join(d, n)) for n in OLD_STARTUP)):
        try:
            write_startup(startup_bat_path())
        except OSError:
            pass


_desktop = []


def shortcut_path():
    return os.path.join(_desktop_dir(), "LPI Companion.lnk")


def _desktop_dir():
    if _desktop:
        return _desktop[0]
    _desktop.append(os.path.join(os.path.expanduser("~"), "Desktop"))
    try:   # the real Desktop folder (OneDrive moves it)
        import subprocess
        out = subprocess.run(["powershell", "-NoProfile", "-Command", "[Environment]::GetFolderPath('Desktop')"],
                             capture_output=True, text=True, creationflags=NO_WINDOW, timeout=15)
        d = out.stdout.strip()
        if d and os.path.isdir(d):
            _desktop[0] = d
    except Exception:
        pass
    return _desktop[0]


FOLDER_SHORTCUT = "Lethal PVP Insights Companion.lnk"


def write_shortcut(lnk=None):
    """Shortcut with the LPI icon (a .bat can't have its own icon, a shortcut can): on the desktop, or the given path."""
    import subprocess
    lnk = lnk or shortcut_path()
    ps = ("$s=(New-Object -ComObject WScript.Shell).CreateShortcut('{lnk}');$s.TargetPath='{t}';"
          "$s.WorkingDirectory='{w}';$s.WindowStyle=7;$s.IconLocation='{i},0';"
          "$s.Description='Lethal PVP Insights Companion';$s.Save()").format(
        lnk=lnk.replace("'", "''"), t=LAUNCHER.replace("'", "''"), w=HERE.replace("'", "''"), i=ICON.replace("'", "''"))
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], creationflags=NO_WINDOW, timeout=30)
    return lnk


# --------------------------------------------------------------------------
# Import (shared by the Import button, auto-import and the in-game Upload button)
# --------------------------------------------------------------------------
_import_lock = threading.Lock()


def perform_import(cfg):
    """Returns (ok, message)."""
    log, addon = cfg["log"], cfg["addon"]
    if not os.path.isfile(log):
        return False, "Encounter.log not found at {} - set the path in the Companion window (Browse...).".format(log)
    if not os.path.isdir(addon):
        return False, "Addon folder not found at {}.".format(addon)
    if not _import_lock.acquire(blocking=False):
        return False, "An import is already running - try again in a moment."
    try:
        r = importer.run_import(log, addon)
        msg = ("Imported {} build record(s) - {} players stored. "
               "Back in the game, click Reload UI (or type /reloadui).").format(r["found"], r["total"])
    except Exception as e:  # report any problem instead of crashing
        return False, "Import failed: {}".format(e)
    finally:
        _import_lock.release()
    if cfg.get("deleteAfter"):
        msg += " " + auto_delete(cfg)
    return True, msg


# --------------------------------------------------------------------------
# Who started the encounter log? The addon remembers every time it switched the log on (captureStarts,
# sent with the in-game Upload / Delete links and saved in SavedVariables after a reload). Every logging
# session in Encounter.log starts with a BEGIN_LOG line; a session that doesn't match one of the addon's
# start times was started by the player (/encounterlog) - such a log is never deleted without asking.
# --------------------------------------------------------------------------
CAPTURE_MATCH_SEC = 30
KNOWN_CAPS = set()
_pending = {"delete": False}
FOREIGN_MSG = ("Encounter.log also contains logging that LPI did not start (you turned /encounterlog on "
               "yourself, or LPI's capture is not confirmed yet).")


def add_caps(csv):
    for part in (csv or "").split(","):
        try:
            v = int(part.strip())
            if v > 0:
                KNOWN_CAPS.add(v)
        except ValueError:
            pass


def save_known_caps(cfg):
    cut = int(time.time()) - 30 * 86400
    cfg["knownCaps"] = sorted(k for k in KNOWN_CAPS if k >= cut)
    save_settings(cfg)


def read_sv_captures(log):
    """.../live/Logs/Encounter.log -> .../live/SavedVariables/LethalPVPInsights.lua"""
    import re
    live = os.path.dirname(os.path.dirname(os.path.abspath(log)))
    sv = cloud.sv_path(os.path.join(live, "AddOns", "LethalPVPInsights"))
    try:
        with open(sv, "r", encoding="utf-8", errors="replace") as f:
            txt = f.read()
    except OSError:
        return
    for m in re.finditer(r'\["captureStarts"\]\s*=\s*\{([^}]*)\}', txt):
        for n in re.finditer(r"=\s*(\d+)", m.group(1)):
            KNOWN_CAPS.add(int(n.group(1)))


def session_starts(log):
    """Start time (unix seconds) of every logging session in the file (BEGIN_LOG lines)."""
    out = []
    with open(log, "rb") as f:
        carry = b""
        while True:
            chunk = f.read(8 * 1024 * 1024)
            if not chunk:
                break
            data = carry + chunk
            cut = data.rfind(b"\n")
            carry = data[cut + 1:] if cut >= 0 else data
            data = data[:cut + 1] if cut >= 0 else b""
            i = data.find(b",BEGIN_LOG,")
            while i >= 0:
                end = data.find(b",", i + 11)
                try:
                    out.append(int(data[i + 11:end]) // 1000)
                except ValueError:
                    pass
                i = data.find(b",BEGIN_LOG,", i + 11)
    return out


def foreign_sessions(cfg):
    log = cfg["log"]
    if not os.path.isfile(log):
        return 0
    read_sv_captures(log)
    n = 0
    for s in session_starts(log):
        if not any(abs(s - k) <= CAPTURE_MATCH_SEC for k in KNOWN_CAPS):
            n += 1
    return n


def auto_delete(cfg):
    """'Delete log after import': only when every session in the log is LPI's own; otherwise wait."""
    if foreign_sessions(cfg) > 0:
        _pending["delete"] = True
        return ("Encounter.log was kept: " + FOREIGN_MSG + " It is deleted automatically once LPI's capture "
                "is confirmed (after /reloadui), or use Delete log now.")
    _pending["delete"] = False
    return perform_delete(cfg, True)[1]


def retry_pending_delete(cfg):
    if not _pending["delete"]:
        return None
    if not os.path.isfile(cfg["log"]):
        _pending["delete"] = False
        return None
    if foreign_sessions(cfg) > 0:
        return None
    _pending["delete"] = False
    return perform_delete(cfg, True)[1]


def perform_delete(cfg, confirmed=False):
    """Delete Encounter.log (its data is already imported). Returns (ok, message, needs_confirmation).
    Without confirmed=True a log that contains sessions LPI didn't start is left alone."""
    log = cfg["log"]
    if not os.path.isfile(log):
        return True, "Encounter.log is already deleted.", False
    if not confirmed:
        n = foreign_sessions(cfg)
        if n > 0:
            return False, "Not deleted yet - {} ({} logging session(s).) Delete it anyway?".format(FOREIGN_MSG, n), True
    _pending["delete"] = False
    size_mb = os.path.getsize(log) / 1048576.0
    try:
        os.remove(log)
        return True, "Encounter.log deleted ({:.1f} MB freed).".format(size_mb), False
    except OSError:
        try:   # the game may still hold it open: emptying it works when deleting doesn't
            with open(log, "r+b") as f:
                f.truncate(0)
            return True, "Encounter.log emptied ({:.1f} MB freed).".format(size_mb), False
        except OSError:
            return False, ("Couldn't delete Encounter.log - the game is still writing to it. Turn the encounter "
                           "log off (/encounterlog) or close the game, then try again."), False


PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>Lethal PVP Insights</title>
<style>body{{background:#14120e;color:#e8e2cf;font:16px/1.5 Segoe UI,Arial,sans-serif;display:flex;
align-items:center;justify-content:center;height:90vh;margin:0}}.box{{max-width:560px;padding:28px 32px;
border:1px solid #6b604a;border-radius:8px;background:#1d1a14}}h1{{color:#c5c29e;font-size:20px;margin:0 0 12px}}
.ok{{color:#7fd47f}}.err{{color:#ff8a7a}}small{{color:#999}}</style></head><body><div class="box">
<h1>Lethal PVP Insights</h1><p class="{cls}">{msg}</p><small>You can close this tab and return to the game.</small>
</div></body></html>"""


def make_handler(cfg, events):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            from urllib.parse import parse_qs
            path, _, query = self.path.partition("?")
            q = parse_qs(query)
            if q.get("caps"):
                add_caps(q["caps"][0])
                save_known_caps(cfg)
            link = ""
            if path == "/import":
                ok, msg = perform_import(cfg)
                events.put(("status", msg))
                code = 200
            elif path == "/deletelog":
                ok, msg, ask = perform_delete(cfg, q.get("confirm", [""])[0] == "1")
                if ask:
                    link = ('</p><p><a href="/deletelog?confirm=1" style="display:inline-block;padding:8px 16px;'
                            'background:#7a2a20;color:#fff;border-radius:4px;text-decoration:none">'
                            'Delete Encounter.log anyway</a>')
                    events.put(("status", "Waiting for confirmation in the browser before deleting Encounter.log."))
                else:
                    events.put(("status", msg))
                code = 200
            elif path in ("/", "/status"):
                ok, msg, code = True, "The LPI Companion is running.", 200
            else:
                ok, msg, code = False, "Not found.", 404
            body = PAGE.format(cls="ok" if ok else "err", msg=html.escape(msg) + link).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass
    return Handler


def start_server(cfg, events):
    """Starts the local endpoint; returns None if another Companion already owns the port."""
    try:
        server = ThreadingHTTPServer(("127.0.0.1", PORT), make_handler(cfg, events))
    except OSError:
        return None
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# --------------------------------------------------------------------------
# GUI
# --------------------------------------------------------------------------
def run_gui():
    import tkinter as tk
    from tkinter import filedialog, messagebox

    _, default_log = importer.default_paths()
    cfg = load_settings(default_log)
    events = queue.Queue()
    if start_server(cfg, events) is None:
        root = tk.Tk()
        root.withdraw()
        messagebox.showinfo("Lethal PVP Insights", "The LPI Companion is already running (look for it in the taskbar).")
        return
    watcher = LogWatcher(cfg["log"])
    global UPLOADER
    UPLOADER = cloud.Uploader(cfg)
    for k in cfg.get("knownCaps") or []:
        try:
            KNOWN_CAPS.add(int(k))
        except (TypeError, ValueError):
            pass
    write_heartbeat(cfg["addon"], True)

    root = tk.Tk()
    root.title("LPI Companion - Encounter Log Import")
    root.geometry("830x400")
    if os.path.isfile(ICON):
        try:
            root.iconbitmap(default=ICON)
        except Exception:
            pass
    if "--background" in sys.argv:
        root.withdraw()   # started with Windows: stay out of the way until a fight is captured or Upload is used
    root.minsize(560, 270)

    pad = {"padx": 10, "pady": 4}
    tk.Label(root, text="Lethal PVP Insights Companion  -  by Lethal2k", font=("Segoe UI", 13, "bold")).grid(
        row=0, column=0, columnspan=3, sticky="w", padx=10, pady=(10, 2))

    log_var = tk.StringVar(value=cfg["log"])
    addon_var = tk.StringVar(value="Builds are saved to: " + cfg["addon"])
    watch_var = tk.BooleanVar(value=cfg["watch"])
    auto_var = tk.BooleanVar(value=cfg["auto"])
    delete_var = tk.BooleanVar(value=bool(cfg.get("deleteAfter")))
    status_var = tk.StringVar(value="Watching for captured fights. Leave this window open while you play.")

    def browse_log():
        p = filedialog.askopenfilename(title="Select Encounter.log", initialfile="Encounter.log",
                                       filetypes=[("Encounter log", "*.log"), ("All files", "*.*")])
        if p:
            log_var.set(os.path.normpath(p))
            persist()

    tk.Label(root, text="Encounter.log:").grid(row=1, column=0, sticky="w", **pad)
    log_entry = tk.Entry(root, textvariable=log_var)
    log_entry.grid(row=1, column=1, sticky="ew", **pad)
    tk.Button(root, text="Browse...", command=browse_log).grid(row=1, column=2, **pad)
    tk.Label(root, textvariable=addon_var, fg="#666", anchor="w").grid(row=2, column=1, sticky="ew", padx=10)
    root.after(100, lambda: log_entry.xview_moveto(1))  # show the file name end
    log_entry.bind("<FocusOut>", lambda e: persist())

    def persist(*_):
        cfg.update(log=log_var.get(), addon=addon_from_log(log_var.get()), watch=watch_var.get(),
                   auto=auto_var.get(), deleteAfter=delete_var.get())
        addon_var.set("Builds are saved to: " + cfg["addon"])
        save_settings(cfg)
        watcher.set_path(cfg["log"])

    opts = tk.Frame(root)
    opts.grid(row=3, column=0, columnspan=3, sticky="w", padx=6)
    tk.Checkbutton(opts, text="Pop up after each captured fight", variable=watch_var, command=persist).pack(side="left")
    tk.Checkbutton(opts, text="Import automatically", variable=auto_var, command=persist).pack(side="left", padx=12)
    tk.Checkbutton(opts, text="Delete log after import", variable=delete_var, command=persist).pack(side="left")

    sbat = startup_bat_path()
    if sbat:
        start_var = tk.BooleanVar(value=os.path.isfile(sbat))

        def toggle_startup():
            if start_var.get():
                write_startup(sbat)
            elif os.path.isfile(sbat):
                os.remove(sbat)

        # first run: start with Windows by default, so the in-game Upload button always has someone to talk to
        if cfg.get("firstRun"):
            try:
                write_startup(sbat)
                start_var.set(True)
            except OSError:
                pass
        tk.Checkbutton(opts, text="Start with Windows", variable=start_var, command=toggle_startup).pack(side="left")
        if not cfg.get("firstRun"):
            migrate_startup()

    if os.name == "nt":
        # a shortcut with the icon next to LPI COMPANION.bat in the addon folder (made again when the folder moved)
        try:
            here_lnk = os.path.join(HERE, FOLDER_SHORTCUT)
            if not os.path.isfile(here_lnk) or cfg.get("shortcutFolder") != HERE:
                write_shortcut(here_lnk)
        except Exception:
            pass
        # the shortcut of older versions ("PDI Companion") points at the old launcher: replace it
        try:
            old_lnk = os.path.join(_desktop_dir(), OLD_SHORTCUT)
            if os.path.isfile(old_lnk):
                os.remove(old_lnk)
                write_shortcut()
            elif os.path.isfile(shortcut_path()) and not cfg.get("shortcutFolder") == HERE:
                write_shortcut()          # the addon folder was renamed or moved: point the shortcut here
            cfg["shortcutFolder"] = HERE
        except Exception:
            pass
        lnk_var = tk.BooleanVar(value=os.path.isfile(shortcut_path()))

        def toggle_shortcut():
            try:
                if lnk_var.get():
                    write_shortcut()
                elif os.path.isfile(shortcut_path()):
                    os.remove(shortcut_path())
            except Exception as e:
                status_var.set("Could not change the desktop shortcut: {}".format(e))
        if not cfg.get("shortcutDone"):
            try:
                write_shortcut()
                lnk_var.set(True)
            except Exception:
                pass
            cfg["shortcutDone"] = True
            save_settings(cfg)
        tk.Checkbutton(opts, text="Desktop shortcut", variable=lnk_var, command=toggle_shortcut).pack(side="left", padx=8)

    busy = {"on": False}

    def popup():
        root.deiconify()
        root.lift()
        root.attributes("-topmost", True)
        root.after(1500, lambda: root.attributes("-topmost", False))
        root.focus_force()
        root.bell()

    def do_import():
        if busy["on"]:
            return
        persist()
        busy["on"] = True
        import_btn.config(state="disabled")
        status_var.set("Importing...")

        def work():
            _, msg = perform_import(cfg)
            events.put(("done", msg))
        threading.Thread(target=work, daemon=True).start()

    def finish(msg):
        busy["on"] = False
        import_btn.config(state="normal")
        status_var.set(msg)

    btns = tk.Frame(root)
    btns.grid(row=4, column=0, columnspan=3, sticky="ew", padx=10, pady=8)
    import_btn = tk.Button(btns, text="Import", width=16, font=("Segoe UI", 10, "bold"), command=do_import)
    import_btn.pack(side="left")
    def delete_now():
        persist()
        ok, msg, ask = perform_delete(cfg)
        if ask:
            if messagebox.askyesno("Delete Encounter.log?", msg, icon="warning"):
                ok, msg, ask = perform_delete(cfg, True)
            else:
                msg = "Encounter.log was kept."
        status_var.set(msg)
    tk.Button(btns, text="Delete log now", width=14, command=delete_now).pack(side="left", padx=8)
    tk.Button(btns, text="Hide", width=10, command=root.iconify).pack(side="left")

    tk.Label(root, textvariable=status_var, justify="left", anchor="w", wraplength=600, fg="#333").grid(
        row=5, column=0, columnspan=3, sticky="ew", padx=10, pady=(4, 6))

    # ---------------- esopvp.com
    up = UPLOADER
    web = tk.LabelFrame(root, text=" esopvp.com ")
    web.grid(row=6, column=0, columnspan=3, sticky="ew", padx=10, pady=(0, 10))
    consent_var = tk.BooleanVar(value=bool(up.cloud.get("consent")))
    ident_var = tk.StringVar()
    upstat_var = tk.StringVar()

    def refresh_cloud():
        ident = up.cloud.get("identifier") or ""
        ident_var.set("Identifier: " + ident if (up.cloud.get("consent") and ident) else
                      "Identifier: - (tick Upload to get one)")
        last = up.cloud.get("last")
        if not up.cloud.get("consent"):
            upstat_var.set("Uploads are off. Nothing leaves this PC.")
        elif last:
            upstat_var.set("Last upload {}: {}".format(time.strftime("%H:%M", time.localtime(last.get("t") or 0)),
                                                        ("OK - " if last.get("ok") else "failed - ") + (last.get("msg") or "")))
        else:
            upstat_var.set("Waiting for the game to save (after /reloadui, logout or exit).")
        if up.cloud.get("consent") and not up.key():
            upstat_var.set("This PC's esopvp.com key can't be read - untick and tick 'Upload' again to fix it.")
        for b in (copy_btn, site_btn, newid_btn):
            b.config(state="normal" if up.enabled() else "disabled")

    def set_consent():
        if consent_var.get():
            if not up.key():
                r = cloud.register()
                if not r.get("ok"):
                    consent_var.set(False)
                    messagebox.showerror("esopvp.com", "Registration failed: " + r.get("error", "?"))
                    return
                up.cloud["key"] = cloud.protect_key(r["key"])
                up.cloud["identifier"] = r["identifier"]
            up.cloud["consent"] = True
            up.cloud["consentAt"] = int(time.time())
            up.cloud["mtime"] = 0          # send the current file right away
        else:
            up.cloud["consent"] = False
        up.cloud["asked"] = True
        save_settings(cfg)
        write_heartbeat(cfg["addon"], True)
        refresh_cloud()

    def copy_ident():
        root.clipboard_clear()
        root.clipboard_append(up.cloud.get("identifier") or "")
        status_var.set("Identifier copied. Paste it on esopvp.com when you register.")

    def open_site():
        import webbrowser
        webbrowser.open(cloud.SITE + "/register")

    def new_ident():
        if not messagebox.askyesno("New Identifier", "Make a new Identifier? The old one stops working; "
                                   "a website account already linked to this PC stays linked."):
            return
        r = cloud.new_identifier(up.key())
        if r.get("ok"):
            up.cloud["identifier"] = r["identifier"]
            save_settings(cfg)
            write_heartbeat(cfg["addon"], True)
        else:
            messagebox.showerror("esopvp.com", r.get("error", "failed"))
        refresh_cloud()

    def clear_local():
        if not messagebox.askyesno(
                "Clear collected data",
                "Clear the data Lethal PVP Insights collected on this PC (kill counts, kill feed, opponents, "
                "group history, targeted players, gear from the encounter log)?\n\n"
                "Saved builds and your settings are kept. Anything already uploaded stays on esopvp.com.\n\n"
                "It's done by the addon the next time it loads: type /reloadui in game (or log in).",
                icon="warning"):
            return
        up.cloud["clearAt"] = int(time.time())
        save_settings(cfg)
        write_heartbeat(cfg["addon"], True)
        status_var.set("Collected data will be cleared at your next /reloadui (saved builds are kept).")

    tk.Checkbutton(web, text="Upload my LPI data to esopvp.com", variable=consent_var,
                   command=set_consent).grid(row=0, column=0, sticky="w", padx=6)
    tk.Label(web, textvariable=ident_var, font=("Consolas", 10)).grid(row=0, column=1, sticky="w", padx=6)
    bf = tk.Frame(web)
    bf.grid(row=1, column=0, columnspan=2, sticky="w", padx=6, pady=4)
    copy_btn = tk.Button(bf, text="Copy Identifier", command=copy_ident)
    copy_btn.pack(side="left")
    site_btn = tk.Button(bf, text="Open esopvp.com", command=open_site)
    site_btn.pack(side="left", padx=6)
    newid_btn = tk.Button(bf, text="New Identifier", command=new_ident)
    newid_btn.pack(side="left")
    del_btn = tk.Button(bf, text="Clear collected data", command=clear_local)
    del_btn.pack(side="left", padx=6)
    tk.Label(web, textvariable=upstat_var, fg="#555", anchor="w", wraplength=760, justify="left").grid(
        row=2, column=0, columnspan=2, sticky="w", padx=6, pady=(0, 4))
    refresh_cloud()

    def start_upload():
        def work():
            ok, msg = up.run()
            events.put(("cloud", msg))
        threading.Thread(target=work, daemon=True).start()

    root.columnconfigure(1, weight=1)

    tick_n = {"n": 0}

    def tick():
        tick_n["n"] += 1
        if not cfg.get("svMigrated") and tick_n["n"] % 20 == 1:      # the renamed addon's saved data
            try:
                m3 = cloud.migrate_saved_data(cfg["addon"], cfg)
            except OSError as e:
                m3 = "Could not move your saved data to the renamed addon: {}".format(e)
            if cfg.get("svMigrated"):
                save_settings(cfg)
            if m3:
                status_var.set(m3)
        if up.due():
            up.busy = True
            upstat_var.set("Uploading to esopvp.com...")
            start_upload()
        if _pending["delete"] and not busy["on"] and tick_n["n"] % 7 == 0:   # about every 10 seconds
            m2 = retry_pending_delete(cfg)
            if m2:
                status_var.set(m2)
        if watch_var.get():
            try:
                n = watcher.poll(time.time())
            except OSError:
                n = None
            if n:
                status_var.set("Fight captured - gear & skill bars for {} player(s) are in the log. "
                               "Click Import.".format(n))
                if auto_var.get():
                    do_import()          # quiet: no window over the game, just import
                else:
                    popup()
        root.after(POLL_MS, tick)

    def pump():
        # results from worker threads / the in-game Upload button, handled on the Tk thread
        try:
            while True:
                kind, msg = events.get_nowait()
                if kind == "done":
                    finish(msg)
                elif kind == "cloud":
                    save_settings(cfg)
                    write_heartbeat(cfg["addon"], True)
                    refresh_cloud()
                else:
                    status_var.set("From the game: " + msg)
        except queue.Empty:
            pass
        root.after(200, pump)

    if cfg.get("firstRun"):
        cfg["firstRun"] = False
        save_settings(cfg)
        status_var.set("Ready. The Companion now starts with Windows and imports captured fights automatically - "
                       "in game you only need to click Reload UI.")

    def heartbeat():
        write_heartbeat(cfg["addon"], True)
        root.after(60000, heartbeat)

    def on_close():
        write_heartbeat(cfg["addon"], False)
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", on_close)
    root.after(POLL_MS, tick)
    root.after(200, pump)
    root.after(60000, heartbeat)
    try:
        root.mainloop()
    finally:
        write_heartbeat(cfg["addon"], False)


if __name__ == "__main__":
    if "--import" in sys.argv:          # headless one-shot import
        sys.exit(importer.main())
    run_gui()
