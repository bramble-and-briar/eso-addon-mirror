"""Test and build a deterministic, directly installable RoleplayPostSupport archive."""

import argparse
import hashlib
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ("README.md", "docs/API-VERIFICATION.md", "docs/TESTING.md")
SOURCES = (
    "RoleplayPostSupport.lua",
    "RoleplayPostSupport_Localization.lua",
    "RoleplayPostSupport_Splitter.lua",
    "RoleplayPostSupport_Sessions.lua",
    "RoleplayPostSupport_Queue.lua",
    "RoleplayPostSupport_Chat.lua",
    "RoleplayPostSupport_UI.lua",
)
DEFAULT_CATALOG = "lang/default.lua"
LANGUAGE_TEMPLATE = "lang/$(language).lua"
MANIFEST_ENTRIES = (SOURCES[0], DEFAULT_CATALOG, LANGUAGE_TEMPLATE, *SOURCES[1:])


def validate_file(path):
    relative = path.relative_to(ROOT)
    if (any((ROOT / part).is_symlink() for part in (relative, *relative.parents))
            or not path.is_file()):
        raise ValueError("Missing or symlinked package file: " + str(path))


def package_files():
    manifest = ROOT / "RoleplayPostSupport.txt"
    validate_file(manifest)
    text = manifest.read_text(encoding="utf-8")
    version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", text, re.MULTILINE)
    if not version:
        raise ValueError("Manifest must have a semantic Version header")
    if not re.search(r"^## APIVersion: [0-9]+(?: [0-9]+)*$", text, re.MULTILINE):
        raise ValueError("Manifest must declare space-separated numeric APIVersion values")
    if "## SavedVariables: RoleplayPostSupportSavedVariables" not in text.splitlines():
        raise ValueError("Missing SavedVariables declaration")
    entries = [line.strip() for line in text.splitlines()
               if line.strip() and not line.lstrip().startswith("#")]
    if len(entries) != len(set(entries)):
        raise ValueError("Duplicate manifest entry")
    for name in entries:
        if name not in MANIFEST_ENTRIES:
            raise ValueError("Unexpected manifest entry: " + name)
    if not entries or entries[0] != "RoleplayPostSupport.lua":
        raise ValueError("Bootstrap must load first")
    if tuple(entries) != MANIFEST_ENTRIES:
        raise ValueError("Manifest does not match the required entries and load order")
    if set(SOURCES) != {path.relative_to(ROOT).as_posix()
                        for path in ROOT.glob("RoleplayPostSupport*.lua")}:
        raise ValueError("Manifest does not match the addon's Lua sources")
    files = [manifest] + [ROOT / name for name in (*SOURCES, DEFAULT_CATALOG, *DOCS)]
    for path in files:
        validate_file(path)
    # The template is optional at runtime, not a literal archive member. Any
    # explicit two-letter locale (including en) may override the default catalog.
    for path in sorted((ROOT / "lang").iterdir()):
        if path.is_symlink():
            raise ValueError("Missing or symlinked package file: " + str(path))
        if path.is_dir():
            raise ValueError("Unexpected locale directory: " + str(path))
        if path.name == "default.lua":
            continue
        if path.suffix == ".lua":
            if not re.fullmatch(r"[a-z]{2}\.lua", path.name):
                raise ValueError("Unexpected locale file: " + str(path))
            validate_file(path)
            files.append(path)
    for path in files:
        path.read_text(encoding="utf-8")  # Fail before building on bad source encoding.
    return version.group(1), sorted(files)


def package_contents(files):
    return {"RoleplayPostSupport/" + path.relative_to(ROOT).as_posix(): path.read_bytes()
            for path in files}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    runtime = parser.add_mutually_exclusive_group()
    runtime.add_argument("--lua", help="Lua executable passed to tests/run.py; prefer Lua 5.1")
    runtime.add_argument("--library", help="Lua shared library passed to tests/run.py")
    args = parser.parse_args()
    version, files = package_files()
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "*_spec.py"],
                   cwd=ROOT, check=True, timeout=120)
    command = [sys.executable, str(ROOT / "tests" / "run.py")]
    if args.lua:
        command += ["--lua", args.lua]
    elif args.library:
        command += ["--library", args.library]
    subprocess.run(command, cwd=ROOT, check=True, timeout=120)

    destination = ROOT / "dist"
    destination.mkdir(exist_ok=True)
    archive = destination / ("RoleplayPostSupport-" + version + ".zip")
    temporary = archive.with_suffix(".zip.tmp")
    contents = package_contents(files)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=9) as bundle:
            for name, data in sorted(contents.items()):
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = 0o100644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, data, compresslevel=9)
        with zipfile.ZipFile(temporary) as bundle:
            if bundle.testzip() is not None or set(bundle.namelist()) != set(contents):
                raise ValueError("Archive integrity/member check failed")
            for name, expected in contents.items():
                if bundle.read(name) != expected:
                    raise ValueError("Archive readback mismatch: " + name)
        temporary.replace(archive)
    finally:
        if temporary.exists():
            temporary.unlink()
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum = archive.with_suffix(".zip.sha256")
    checksum.write_text(digest + "  " + archive.name + "\n", encoding="ascii")
    print(f"Built {archive.relative_to(ROOT)} ({len(files)} files, {archive.stat().st_size} bytes)")
    print("SHA256 " + digest)
    print("Verified integrity, manifest members, UTF-8 source, and byte-for-byte readback.")
    print("Extract into AddOns/ to get AddOns/RoleplayPostSupport/RoleplayPostSupport.txt.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("Packaging failed: " + str(error), file=sys.stderr)
        sys.exit(1)
