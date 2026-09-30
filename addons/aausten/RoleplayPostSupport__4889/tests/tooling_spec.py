"""Dependency-free tooling regressions: python3 -m unittest discover -s tests -p '*_spec.py'."""

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent


def load_tool(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


packager = load_tool("rps_packager", "tools/package.py")
runner = load_tool("rps_runner", "tests/run.py")
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
ENTRIES = (SOURCES[0], DEFAULT_CATALOG, LANGUAGE_TEMPLATE, *SOURCES[1:])
DOCS = ("README.md", "docs/API-VERIFICATION.md", "docs/TESTING.md")
HEADERS = (
    "## Version: 1.2.2\n"
    "## APIVersion: 101050 101051\n"
    "## SavedVariables: RoleplayPostSupportSavedVariables\n\n"
)


class ToolingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="rps-tooling-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.manifest = self.root / "RoleplayPostSupport.txt"
        for name in (*SOURCES, DEFAULT_CATALOG, *DOCS):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("-- " + name + "\n", encoding="utf-8")
        self.write_manifest(ENTRIES)
        self.enterContext(patch.object(packager, "ROOT", self.root))

    def write_manifest(self, entries, headers=HEADERS):
        self.manifest.write_text(headers + "\n".join(entries) + "\n", encoding="utf-8")

    def test_exact_members_keep_root_sources_and_doc_subpaths(self):
        version, files = packager.package_files()
        self.assertEqual(version, "1.2.2")
        expected = {"RoleplayPostSupport.txt", *SOURCES, DEFAULT_CATALOG, *DOCS}
        self.assertEqual(len(files), 12)
        self.assertFalse((self.root / LANGUAGE_TEMPLATE).exists())
        self.assertEqual({path.relative_to(self.root).as_posix() for path in files}, expected)
        self.assertEqual(files, sorted(files))
        contents = packager.package_contents(files)
        self.assertEqual(set(contents), {"RoleplayPostSupport/" + name for name in expected})
        for path in files:
            member = "RoleplayPostSupport/" + path.relative_to(self.root).as_posix()
            self.assertEqual(contents[member], path.read_bytes())
        self.assertEqual(packager.package_files(), (version, files))

    def test_optional_locales_are_bundled_once_in_deterministic_order(self):
        locales = ("lang/fr.lua", "lang/en.lua", "lang/de.lua")
        for name in locales:
            (self.root / name).write_text('-- explicit override: ' + name, encoding="utf-8")
        version, files = packager.package_files()
        expected = {"RoleplayPostSupport.txt", *SOURCES, DEFAULT_CATALOG, *locales, *DOCS}
        self.assertEqual(len(files), 15)
        self.assertEqual(files, sorted(self.root / name for name in expected))
        contents = packager.package_contents(files)
        self.assertNotIn("RoleplayPostSupport/" + LANGUAGE_TEMPLATE, contents)
        for name in locales:
            self.assertEqual(contents["RoleplayPostSupport/" + name],
                             (self.root / name).read_bytes())
        self.assertEqual(packager.package_files(), (version, files))

    def test_requires_default_catalog_and_localization_helper(self):
        for name in (DEFAULT_CATALOG, "RoleplayPostSupport_Localization.lua"):
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.unlink()
                try:
                    with self.assertRaises(ValueError):
                        packager.package_files()
                finally:
                    path.write_bytes(original)

    def test_rejects_invalid_locale_filenames_including_literal_template(self):
        for name in ("en-US.lua", "DE.lua", "e.lua", "eng.lua", "12.lua", "éé.lua",
                     "de_extra.lua", "$(language).lua", "Default.lua"):
            with self.subTest(name=name):
                path = self.root / "lang" / name
                path.write_text("", encoding="utf-8")
                try:
                    with self.assertRaisesRegex(ValueError, "Unexpected locale file"):
                        packager.package_files()
                finally:
                    path.unlink()

    def test_rejects_nested_locale_sources(self):
        nested = self.root / "lang/nested"
        nested.mkdir()
        (nested / "de.lua").write_text("", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Unexpected locale directory"):
            packager.package_files()

    def test_rejects_bad_locale_encoding(self):
        for name in (DEFAULT_CATALOG, "lang/de.lua"):
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes() if path.exists() else None
                path.write_bytes(b"\xff")
                try:
                    with self.assertRaises(UnicodeDecodeError):
                        packager.package_files()
                finally:
                    if original is None:
                        path.unlink()
                    else:
                        path.write_bytes(original)

    def test_member_mapping_does_not_flatten_equal_basenames(self):
        paths = [self.root / "README.md", self.root / "docs/README.md"]
        paths[1].write_text("different content", encoding="utf-8")
        contents = packager.package_contents(paths)
        self.assertEqual(len(contents), 2)
        self.assertNotEqual(contents["RoleplayPostSupport/README.md"],
                            contents["RoleplayPostSupport/docs/README.md"])

    def test_unrelated_files_are_not_packaged(self):
        for name in ("src/RoleplayPostSupport.lua", "tests/RoleplayPostSupport_Extra.lua",
                     "tests/example.lua", "unrelated.lua", "tools/dev.py",
                     "docs/How to add localization support - ESOUI Wiki.html",
                     "lang/README.md"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("not packaged", encoding="utf-8")
        _, files = packager.package_files()
        self.assertEqual(len(files), 12)

    def test_rejects_unsafe_or_nested_manifest_entries(self):
        for name in ("src/RoleplayPostSupport.lua", "../RoleplayPostSupport.lua",
                     "/RoleplayPostSupport.lua", "src/../RoleplayPostSupport.lua",
                     "src\\RoleplayPostSupport.lua", "src/nested/RoleplayPostSupport.lua",
                     "lang/../RoleplayPostSupport.lua", "/lang/default.lua",
                     "lang\\default.lua", "lang/nested/de.lua", "lang/de.lua",
                     "lang/$(Language).lua", "lang/$(language).lua/../default.lua",
                     "lang//default.lua", "./lang/default.lua"):
            with self.subTest(name=name):
                self.write_manifest((name, *ENTRIES[1:]))
                with self.assertRaisesRegex(ValueError, "Unexpected manifest entry"):
                    packager.package_files()

    def test_rejects_duplicate_missing_and_reordered_entries(self):
        for entries, error in (
            ((*ENTRIES, ENTRIES[0]), "Duplicate"),
            (ENTRIES[:-1], "does not match"),
            ((*ENTRIES[1:], ENTRIES[0]), "Bootstrap must load first"),
            ((), "Bootstrap must load first"),
        ):
            with self.subTest(entries=entries):
                self.write_manifest(entries)
                with self.assertRaisesRegex(ValueError, error):
                    packager.package_files()

    def test_rejects_each_duplicate_missing_or_out_of_order_entry(self):
        for index, name in enumerate(ENTRIES):
            variants = [(*ENTRIES, name), ENTRIES[:index] + ENTRIES[index + 1:]]
            if index:
                reordered = list(ENTRIES)
                reordered[index - 1], reordered[index] = reordered[index], reordered[index - 1]
                variants.append(reordered)
            for entries in variants:
                with self.subTest(name=name, entries=entries):
                    self.write_manifest(entries)
                    with self.assertRaises(ValueError):
                        packager.package_files()

    def test_rejects_unlisted_source(self):
        (self.root / "RoleplayPostSupport_Extra.lua").write_text("", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "does not match"):
            packager.package_files()

    def test_accepts_single_or_multiple_api_versions(self):
        for apis in ("101050", "101051", "101050 101051"):
            with self.subTest(apis=apis):
                self.write_manifest(ENTRIES, HEADERS.replace("101050 101051", apis))
                version, files = packager.package_files()
                self.assertEqual(version, "1.2.2")
                self.assertEqual(len(files), 12)

    def test_rejects_malformed_api_versions(self):
        for apis in ("", "101050,101051", "101050 next", "-101050"):
            with self.subTest(apis=apis):
                self.write_manifest(ENTRIES, HEADERS.replace("101050 101051", apis))
                with self.assertRaisesRegex(ValueError, "APIVersion"):
                    packager.package_files()

    def test_requires_metadata(self):
        for line in HEADERS.splitlines():
            if line:
                with self.subTest(line=line):
                    self.write_manifest(ENTRIES, HEADERS.replace(line, ""))
                    with self.assertRaises(ValueError):
                        packager.package_files()

    def test_rejects_missing_doc_and_bad_encoding(self):
        path = self.root / DOCS[1]
        path.unlink()
        with self.assertRaisesRegex(ValueError, "Missing or symlinked"):
            packager.package_files()
        path.write_bytes(b"\xff")
        with self.assertRaises(UnicodeDecodeError):
            packager.package_files()

    def test_rejects_symlinked_file(self):
        for name in ("RoleplayPostSupport.txt", *SOURCES, DEFAULT_CATALOG, DOCS[1]):
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.unlink()
                path.symlink_to(self.root / "README.md")
                try:
                    with self.assertRaisesRegex(ValueError, "Missing or symlinked"):
                        packager.package_files()
                finally:
                    path.unlink()
                    path.write_bytes(original)

    def test_rejects_symlinked_doc_directory(self):
        original = self.root / "docs"
        moved = self.root / "docs-real"
        original.rename(moved)
        original.symlink_to(moved, target_is_directory=True)
        try:
            with self.assertRaisesRegex(ValueError, "Missing or symlinked"):
                packager.package_files()
        finally:
            original.unlink()
            moved.rename(original)

    def test_rejects_symlinked_locale_directory(self):
        original = self.root / "lang"
        moved = self.root / "lang-real"
        original.rename(moved)
        original.symlink_to(moved, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Missing or symlinked"):
            packager.package_files()

    def test_rejects_symlinked_optional_locale_files_and_directories(self):
        for target in (self.root / "README.md", self.root / "missing.lua", self.root / "docs"):
            for name in ("de.lua", "nested"):
                with self.subTest(target=target, name=name):
                    path = self.root / "lang" / name
                    path.symlink_to(target, target_is_directory=target.is_dir())
                    try:
                        with self.assertRaisesRegex(ValueError, "Missing or symlinked"):
                            packager.package_files()
                    finally:
                        path.unlink()

    def test_rejects_symlinked_root_directory(self):
        alias = self.root / "root-link"
        alias.symlink_to(self.root, target_is_directory=True)
        with (patch.object(packager, "ROOT", alias),
              self.assertRaisesRegex(ValueError, "Missing or symlinked")):
            packager.package_files()

    def test_runner_compiles_root_addon_and_default_without_optional_locale(self):
        for name in ("src/RoleplayPostSupport.lua", "tests/RoleplayPostSupport_Extra.lua",
                     "unrelated.lua"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("invalid Lua", encoding="utf-8")
        self.assert_runner_syntax_checks((*SOURCES, DEFAULT_CATALOG))

    def test_runner_compiles_real_locales_but_never_template(self):
        locales = ("lang/fr.lua", "lang/en.lua", "lang/de.lua")
        for name in (*locales, LANGUAGE_TEMPLATE):
            (self.root / name).write_text("-- catalog", encoding="utf-8")
        self.assert_runner_syntax_checks((*SOURCES, DEFAULT_CATALOG, *locales))

    def assert_runner_syntax_checks(self, expected):
        with (patch.object(runner, "ROOT", self.root),
              patch.object(runner.sys, "argv", ["tests/run.py", "--syntax-only"]),
              patch.object(runner, "choose_runtime") as choose,
              patch.object(runner.os, "chdir") as chdir,
              contextlib.redirect_stdout(io.StringIO())):
            engine = choose.return_value
            engine.description = "mock runtime"
            engine.run.return_value = None
            self.assertEqual(runner.main(), 0)
            chdir.assert_called_once_with(self.root)
            self.assertEqual([call.args for call in engine.run.call_args_list],
                             [(self.root / name, True)
                              for name in sorted(expected)])


if __name__ == "__main__":
    unittest.main()
