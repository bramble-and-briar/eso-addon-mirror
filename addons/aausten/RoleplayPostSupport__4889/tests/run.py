"""Run standalone Lua specs without third-party Python dependencies.

Usage from the repository root:
    python3 tests/run.py
    python3 tests/run.py tests/queue_chat_spec.lua
    python3 tests/run.py --syntax-only
    python3 tests/run.py --library /path/to/liblua5.1.so --syntax-only
    python3 tests/run.py --lua /path/to/lua5.1

The runner can also be launched by absolute path from another directory; Lua
paths are always relative to the repository root.

Prefer an installed Lua executable; on Linux fall back to a shared library found
by ctypes.util.find_library (e.g. Debian's liblua5.4.so.0). --library accepts a
loader name or an absolute path, including a locally built Lua 5.1 library. No
installation/download is performed. ctypes supports standard Lua 5.1, 5.3, 5.4
ABIs; use --lua for other interpreters/custom builds. Each spec gets a fresh
state/process. Root-level RoleplayPostSupport*.lua and real lang/*.lua files are
compiled, never executed, before tests; the $(language) template is never loaded.
--syntax-only only performs that check. A 5.4 syntax check does
not establish 5.1 compatibility: rerun with 5.1 when available.
"""

import argparse
import ctypes
import ctypes.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class LuaLibrary:
    def __init__(self, name):
        self.lib = ctypes.CDLL(name)
        lib = self.lib
        # Feature detection avoids lua_version's incompatible 5.4 return ABI.
        if hasattr(lib, "lua_newuserdatauv"):
            version = "5.4"
        elif hasattr(lib, "lua_rotate"):
            version = "5.3"
        elif hasattr(lib, "lua_pcall") and not hasattr(lib, "lua_pcallk"):
            version = "5.1"
        else:
            raise ValueError("Unsupported library ABI; use --lua (supported: 5.1, 5.3, 5.4)")
        self.description = f"{name} (Lua {version} ctypes ABI)"

        def bind(symbol, arguments, result):
            function = getattr(lib, symbol)
            function.argtypes = arguments
            function.restype = result
            return function

        state = ctypes.c_void_p  # Never allow ctypes' default int to truncate pointers.
        self.newstate = bind("luaL_newstate", [], state)
        self.openlibs = bind("luaL_openlibs", [state], None)
        self.close = bind("lua_close", [state], None)
        self.tolstring = bind("lua_tolstring", [state, ctypes.c_int,
                                              ctypes.POINTER(ctypes.c_size_t)], state)
        if version == "5.1":
            loadfile = bind("luaL_loadfile", [state, ctypes.c_char_p], ctypes.c_int)
            pcall = bind("lua_pcall", [state, ctypes.c_int, ctypes.c_int,
                                       ctypes.c_int], ctypes.c_int)
            self.loadfile = loadfile
            self.pcall = lambda vm: pcall(vm, 0, 0, 0)
        else:
            loadfile = bind("luaL_loadfilex", [state, ctypes.c_char_p,
                                               ctypes.c_char_p], ctypes.c_int)
            # lua_KContext is intptr_t in standard 5.3/5.4; continuation is NULL.
            pcall = bind("lua_pcallk", [state, ctypes.c_int, ctypes.c_int,
                                        ctypes.c_int, ctypes.c_ssize_t, state], ctypes.c_int)
            self.loadfile = lambda vm, path: loadfile(vm, path, None)
            self.pcall = lambda vm: pcall(vm, 0, 0, 0, 0, None)

    def run(self, path, syntax_only=False):
        vm = self.newstate()
        if not vm:
            raise MemoryError("luaL_newstate failed")
        try:
            if not syntax_only:
                self.openlibs(vm)
            status = self.loadfile(vm, os.fsencode(path))
            if status == 0 and not syntax_only:
                status = self.pcall(vm)
            if status:
                size = ctypes.c_size_t()
                pointer = self.tolstring(vm, -1, ctypes.byref(size))
                if pointer:
                    return ctypes.string_at(pointer, size.value).decode("utf-8", errors="replace")
                return f"Lua error {status} (non-string error object)"
            return None
        finally:
            self.close(vm)


class LuaExecutable:
    def __init__(self, executable):
        self.executable = str(Path(executable).resolve())
        self.description = self.executable

    def run(self, path, syntax_only=False):
        if syntax_only:
            # Pass the filename on stdin, not interpolated as Lua source. This
            # works with Lua 5.1 too, and loadfile does not execute the chunk.
            command = [self.executable, "-e",
                       "local f,e=loadfile(io.read('*l')); if not f then error(e,0) end"]
            result = subprocess.run(command, input=str(path) + "\n", text=True,
                                    cwd=ROOT, timeout=60, capture_output=True, check=False)
        else:
            result = subprocess.run([self.executable, str(path)], text=True,
                                    cwd=ROOT, timeout=60, capture_output=True, check=False)
        if result.stdout:
            print(result.stdout, end="", flush=True)
        if result.returncode:
            return result.stderr.strip() or f"interpreter exited {result.returncode}"
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr, flush=True)
        return None


def choose_runtime(args):
    if args.library:
        return LuaLibrary(args.library)
    if args.lua:
        executable = shutil.which(args.lua)
        if not executable:
            raise ValueError("Lua executable not found: " + args.lua)
        return LuaExecutable(executable)
    for name in ("lua5.1", "lua5.4", "lua5.3", "lua", "luajit"):
        executable = shutil.which(name)
        if executable:
            return LuaExecutable(executable)
    failures = []
    for name in ("lua5.4", "lua5.3", "lua5.1", "lua-5.4", "lua-5.1", "lua"):
        library = ctypes.util.find_library(name)
        if library:
            try:
                return LuaLibrary(library)
            except (OSError, AttributeError, ValueError) as error:
                failures.append(str(error))
    raise ValueError("No usable Lua runtime. Supply --lua /path/to/lua5.1 or "
                     "--library /path/to/liblua5.4.so.0. " + "; ".join(failures))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    runtime = parser.add_mutually_exclusive_group()
    runtime.add_argument("--library", help="shared library path or loader name")
    runtime.add_argument("--lua", help="Lua executable path or command name")
    parser.add_argument("--syntax-only", action="store_true", help="compile packaged Lua without executing it")
    parser.add_argument("files", nargs="*", help="spec paths relative to the repository root (default: tests/*_spec.lua)")
    args = parser.parse_args()
    if args.syntax_only and args.files:
        parser.error("--syntax-only checks packaged Lua; omit spec paths")
    packaged = sorted([*ROOT.glob("RoleplayPostSupport*.lua"),
                       *(path for path in (ROOT / "lang").glob("*.lua")
                         if path.name != "$(language).lua")])
    specs = [ROOT / name for name in args.files] if args.files else sorted((ROOT / "tests").glob("*_spec.lua"))
    if not packaged or (not args.syntax_only and not specs):
        parser.error("no packaged Lua or test suites found")
    for path in packaged + ([] if args.syntax_only else specs):
        if not path.is_file():
            parser.error("file not found: " + str(path))
    try:
        engine = choose_runtime(args)
    except (OSError, AttributeError, ValueError) as error:
        print("Runtime error: " + str(error), file=sys.stderr)
        return 2
    print("Runtime: " + engine.description, flush=True)
    # Existing standalone specs use repository-relative dofile paths.
    os.chdir(ROOT)
    jobs = [(path, True) for path in packaged]
    if not args.syntax_only:
        jobs.extend((path, False) for path in specs)
    failed = 0
    for path, syntax_only in jobs:
        label = ("syntax " if syntax_only else "suite ") + os.path.relpath(path, ROOT)
        try:
            error = engine.run(path, syntax_only)
        except (OSError, MemoryError, subprocess.TimeoutExpired) as exception:
            error = str(exception)
        if error is not None:
            failed += 1
            print("FAIL " + label + "\n" + error, file=sys.stderr, flush=True)
        else:
            print("PASS " + label, flush=True)
    print(f"{len(jobs)} checks: {len(jobs) - failed} passed, {failed} failed", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
