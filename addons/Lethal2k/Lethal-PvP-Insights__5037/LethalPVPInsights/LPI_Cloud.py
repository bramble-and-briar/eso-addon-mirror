"""esopvp.com client for the LPI Companion (Python edition). Standard library only.

Uploads the addon's SavedVariables file (LethalPVPInsights.lua) after the game writes it (on /reloadui,
logout or exit) - only after the player agreed. The server keeps only the LPI fields it needs.
"""
import base64
import gzip
import json
import os
import ssl
import time
import urllib.error
import urllib.request

API = os.environ.get("PDI_API", "https://esopvp.com/api/v1").rstrip("/")
SITE = API.rsplit("/api/", 1)[0]
VERSION = "2.3.2"
SETTLE_SEC = 3            # the file must be unchanged this long before it is read
RETRY_SEC = (60, 120, 300, 600)

CONSENT_TEXT = (
    "Share your LPI data with esopvp.com?\n\n"
    "After each /reloadui or logout the Companion uploads what Lethal PVP Insights recorded: the kill feed "
    "(killer, victim, keep, time), your own kills and assists, builds you saw (class, skills, buffs, sets) "
    "and your Data sharing settings. It also sends your guild names and a hashed friends list so your "
    "sharing choices can be applied.\n\n"
    "Opponent data and the kill feed feed the public stats. Group builds, saved builds and friendly "
    "players are shown only to whom your Data sharing settings allow (addon settings).\n\n"
    "You can stop uploading or delete everything you uploaded at any time. Privacy notice: "
    + SITE + "/privacy")


# ---------------------------------------------------------------- key storage (Windows DPAPI)
def _dpapi(data, protect):
    import ctypes
    from ctypes import wintypes

    class BLOB(ctypes.Structure):
        _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_char))]
    buf = ctypes.create_string_buffer(data, len(data))
    blob_in = BLOB(len(data), ctypes.cast(buf, ctypes.POINTER(ctypes.c_char)))
    blob_out = BLOB()
    fn = ctypes.windll.crypt32.CryptProtectData if protect else ctypes.windll.crypt32.CryptUnprotectData
    if not fn(ctypes.byref(blob_in), None, None, None, None, 0, ctypes.byref(blob_out)):
        raise OSError("DPAPI failed")
    try:
        return ctypes.string_at(blob_out.pbData, blob_out.cbData)
    finally:
        ctypes.windll.kernel32.LocalFree(blob_out.pbData)


def protect_key(key):
    if os.name == "nt":
        try:
            return "dpapi:" + base64.b64encode(_dpapi(key.encode(), True)).decode()
        except Exception:
            pass
    return "plain:" + key


def unprotect_key(stored):
    if not stored:
        return ""
    if stored.startswith("dpapi:") and os.name == "nt":
        try:
            return _dpapi(base64.b64decode(stored[6:]), False).decode()
        except Exception:
            return ""
    if stored.startswith("plain:"):
        return stored[6:]
    return ""


# ---------------------------------------------------------------- HTTP
def _request(method, path, key=None, body=None, content_type="application/json", timeout=60):
    # X-PDI-Clock: this PC's clock - the server corrects kill times by the difference to its own clock
    headers = {"User-Agent": "PDI-Companion/" + VERSION, "X-PDI-Companion": VERSION, "X-PDI-Clock": str(int(time.time()))}
    if key:
        headers["Authorization"] = "Bearer " + key
    if body is not None:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(API + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
            return json.loads(r.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        try:
            data = json.loads(e.read().decode("utf-8"))
            return {"ok": False, "error": data.get("error") or str(e), "status": e.code}
        except Exception:
            return {"ok": False, "error": "server answered %d" % e.code, "status": e.code}
    except Exception as e:  # network down, DNS, TLS...
        return {"ok": False, "error": "could not reach esopvp.com (%s)" % e.__class__.__name__}


def register():
    return _request("POST", "/register", body=json.dumps({"consent": True, "companion": VERSION}).encode())


def new_identifier(key):
    return _request("POST", "/identifier", key=key, body=b"{}")


def delete_data(key):
    return _request("POST", "/delete", key=key, body=b"{}")


SV_NAME = "LethalPVPInsights.lua"        # the game names the saved file after the addon folder
OLD_SV_NAME = "PVPDataInsight.lua"        # before the rename (addon 1.9.58 and older)


def sv_path(addon_dir):
    """...\\live\\AddOns\\LethalPVPInsights -> ...\\live\\SavedVariables\\LethalPVPInsights.lua
    (the old PVPDataInsight.lua while the new one doesn't exist yet)."""
    live = os.path.dirname(os.path.dirname(os.path.normpath(addon_dir)))
    new = os.path.join(live, "SavedVariables", SV_NAME)
    old = os.path.join(live, "SavedVariables", OLD_SV_NAME)
    return new if os.path.isfile(new) or not os.path.isfile(old) else old


def game_running():
    """True while ESO runs (the game rewrites the saved files when it closes)."""
    if os.name != "nt":
        return False
    try:
        import subprocess
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq eso64.exe", "/NH"], capture_output=True, text=True,
                             timeout=15, creationflags=0x08000000).stdout
        return "eso64.exe" in out.lower()
    except Exception:
        return True       # can't tell: better wait than copy over data the game is about to write


def migrate_saved_data(addon_dir, cfg):
    """Once after the rename: copy SavedVariables\\PVPDataInsight.lua to LethalPVPInsights.lua, so the
    renamed addon keeps everything recorded so far. Only while the game is closed. -> message or None."""
    if cfg.get("svMigrated"):
        return None
    live = os.path.dirname(os.path.dirname(os.path.normpath(addon_dir)))
    old = os.path.join(live, "SavedVariables", OLD_SV_NAME)
    new = os.path.join(live, "SavedVariables", SV_NAME)
    if not os.path.isfile(old):
        cfg["svMigrated"] = True
        return None
    if os.path.isfile(new) and os.path.getsize(new) >= os.path.getsize(old):
        cfg["svMigrated"] = True          # the renamed addon already has its own (bigger) data
        return None
    if game_running():
        return "Close the game once so your saved data can move to the renamed addon (Lethal PVP Insights)."
    import shutil
    shutil.copy2(old, new)
    cfg["svMigrated"] = True
    return "Your saved data was moved to the renamed addon (Lethal PVP Insights). Start the game as usual."


def upload(key, path):
    with open(path, "rb") as f:
        raw = f.read()
    body = gzip.compress(raw, 6)
    r = _request("POST", "/upload", key=key, body=body, content_type="application/gzip", timeout=180)
    if r.get("ok"):
        c = r.get("counts") or {}
        r["message"] = "uploaded {} new kill(s), {} build record(s)".format(
            c.get("kill_reports", 0), sum(v for k, v in c.items() if k.startswith("builds_")))
    return r


def download_shared(key, addon_dir, timeout=120):
    """Players other uploaders saw lately -> LPI_Shared.lua in the addon folder (read at /reloadui)."""
    headers = {"User-Agent": "PDI-Companion/" + VERSION, "X-PDI-Companion": VERSION,
               "Authorization": "Bearer " + key, "Accept-Encoding": "gzip"}
    req = urllib.request.Request(API + "/shared", headers=headers, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl.create_default_context()) as r:
            data = r.read()
            if (r.headers.get("Content-Encoding") or "").lower() == "gzip":
                data = gzip.decompress(data)
    except Exception as e:
        return False, "shared data: could not download (%s)" % e.__class__.__name__
    if not data.lstrip().startswith(b"--") or b"PVPDataInsight_Shared" not in data[:400]:
        return False, "shared data: unexpected answer"
    dst = os.path.join(addon_dir, "LPI_Shared.lua")
    tmp = dst + ".tmp"
    try:
        with open(tmp, "wb") as f:
            f.write(data)
        os.replace(tmp, dst)
    except OSError as e:
        return False, "shared data: could not write (%s)" % e
    return True, "shared data updated (%d KB)" % (len(data) // 1024)


class Uploader:
    """Decides when to upload; the GUI calls due() from its timer and runs run() on a thread."""

    def __init__(self, cfg):
        self.cfg = cfg
        cloud = cfg.setdefault("cloud", {})
        cloud.setdefault("consent", None)
        self.busy = False
        self.fails = 0
        self.next_try = 0

    @property
    def cloud(self):
        return self.cfg["cloud"]

    def key(self):
        return unprotect_key(self.cloud.get("key", ""))

    def enabled(self):
        return bool(self.cloud.get("consent")) and bool(self.key())

    def due(self, now=None):
        now = now or time.time()
        if self.busy or not self.enabled() or now < self.next_try:
            return False
        p = sv_path(self.cfg["addon"])
        try:
            m = os.path.getmtime(p)
        except OSError:
            return False
        return m > float(self.cloud.get("mtime") or 0) and now - m >= SETTLE_SEC

    def run(self):
        """Upload once; returns (ok, message). Safe to call from a worker thread."""
        self.busy = True
        try:
            p = sv_path(self.cfg["addon"])
            m = os.path.getmtime(p)
            r = upload(self.key(), p)
            ok = bool(r.get("ok"))
            msg = r.get("message") if ok else r.get("error", "upload failed")
            if ok:
                self.cloud["mtime"] = m
                # tokens of a pending "clear local data": the addon clears only after seeing them
                if r.get("wipe_tokens"):
                    up = self.cloud.setdefault("uploaded", {})
                    up.update({k: int(v) for k, v in r["wipe_tokens"].items()})
                # the server's data was reset: the addon clears everything it collected before that time
                if r.get("reset_at"):
                    self.cloud["resetAt"] = int(r["reset_at"])
                self.fails = 0
                self.next_try = 0
            else:
                self.next_try = time.time() + RETRY_SEC[min(self.fails, len(RETRY_SEC) - 1)]
                self.fails += 1
                if r.get("status") == 401:          # key no longer valid (data deleted on the website)
                    self.cloud["key"] = ""
                    self.cloud["identifier"] = ""
                    msg = "This PC's registration is no longer valid. Tick 'Upload to esopvp.com' again."
            if self.key():
                sok, smsg = download_shared(self.key(), self.cfg["addon"])
                if sok:
                    self.cloud["shared"] = int(time.time())
                if ok and not sok:
                    msg += "; " + smsg
            self.cloud["last"] = {"t": int(time.time()), "ok": ok, "msg": msg}
            return ok, msg
        except OSError as e:
            return False, "could not read the saved data file: %s" % e
        finally:
            self.busy = False

    def lua_fields(self):
        """Extra fields for LPI_Companion.lua (shown in the addon settings after /reloadui)."""
        def q(s):
            return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'
        parts = []
        if self.cloud.get("consent") and self.cloud.get("identifier"):
            parts.append("identifier = " + q(self.cloud["identifier"]))
        up = self.cloud.get("uploaded") or {}
        if up:
            parts.append("uploaded = {" + ", ".join("[{}] = {}".format(q(k), int(v)) for k, v in up.items()) + "}")
        if self.cloud.get("clearAt"):
            parts.append("clear = {}".format(int(self.cloud["clearAt"])))   # "Clear collected data" button
        if self.cloud.get("resetAt"):
            parts.append("reset = {}".format(int(self.cloud["resetAt"])))   # server data reset (clears everything)
        if self.cloud.get("mtime"):
            # the saved data file (its time) that esopvp.com confirmed: the addon may drop what it already sent
            parts.append("sent = {}".format(int(float(self.cloud["mtime"]))))
        last = self.cloud.get("last")
        if last:
            parts.append("upload = {{ t = {}, ok = {}, msg = {} }}".format(
                int(last.get("t") or 0), "true" if last.get("ok") else "false", q(last.get("msg") or "")))
        return parts
