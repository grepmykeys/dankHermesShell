#!/usr/bin/env python3
"""Manifest and layout checks for the Dank Hermes Shell plugin.

Run: python3 -m unittest discover -s tests
"""

from __future__ import annotations

import json
import os
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPECTED_ID = "dankHermesShell"


class TestManifest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / "plugin.json").read_text(encoding="utf-8"))

    def test_id_is_camel_case_and_matches_directory(self):
        self.assertRegex(self.manifest["id"], r"^[a-zA-Z][a-zA-Z0-9]*$")
        self.assertEqual(self.manifest["id"], EXPECTED_ID)

    def test_version_is_semver(self):
        self.assertRegex(self.manifest["version"], r"^\d+\.\d+\.\d+$")

    def test_settings_and_documentation_match_identity(self):
        self.assertEqual(self.manifest["name"], "Dank Hermes Shell")
        settings = (ROOT / "HermesSettings.qml").read_text(encoding="utf-8")
        self.assertIn(f'pluginId: "{EXPECTED_ID}"', settings)
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertTrue(readme.startswith("# Dank Hermes Shell\n"))
        self.assertIn(f"plugins enable {EXPECTED_ID}", readme)
        self.assertNotRegex(readme, r"\bdankHermes\b")

    def test_composite_declares_daemon_and_widget_only(self):
        self.assertEqual(self.manifest["type"], "composite")
        self.assertEqual(sorted(self.manifest["components"]), ["daemon", "widget"])
        # a composite must not also carry a single-surface component
        self.assertNotIn("component", self.manifest)

    def test_every_referenced_qml_file_exists(self):
        refs = list(self.manifest["components"].values())
        refs += [self.manifest["settings"]]
        for ref in refs:
            self.assertTrue(ref.startswith("./"), ref)
            self.assertTrue(ref.endswith(".qml"), ref)
            self.assertTrue((ROOT / ref[2:]).is_file(), f"missing {ref}")

    def test_settings_permission_matches_settings_component(self):
        if "settings" in self.manifest:
            self.assertIn("settings_write", self.manifest["permissions"])
        self.assertIn("process", self.manifest["permissions"])

    def test_capabilities_match_surfaces(self):
        caps = self.manifest["capabilities"]
        self.assertIn("daemon", caps)
        self.assertIn("dankbar-widget", caps)

    def test_dependencies_declare_python3(self):
        self.assertIn("python3", self.manifest["dependencies"])

    def test_requires_dms_is_a_constraint(self):
        self.assertRegex(self.manifest["requires_dms"], r"^>=\d+\.\d+\.\d+$")


class TestLayout(unittest.TestCase):
    def test_helper_is_executable(self):
        helper = ROOT / "bin" / "dank-hermes-shell"
        self.assertTrue(helper.is_file())
        self.assertTrue(os.access(helper, os.X_OK), "bin/dank-hermes-shell must be executable")

    def test_helper_is_stdlib_only(self):
        source = (ROOT / "bin" / "dank-hermes-shell").read_text(encoding="utf-8")
        imports = set(re.findall(r"^\s*(?:import|from)\s+([a-zA-Z_][\w.]*)", source, re.M))
        stdlib = {
            "argparse", "datetime", "json", "os", "re", "shutil", "sqlite3",
            "subprocess", "sys", "time", "tempfile", "fcntl", "contextlib", "__future__",
        }
        self.assertFalse(imports - stdlib, f"non-stdlib imports: {imports - stdlib}")

    def test_qml_files_never_build_shell_strings(self):
        offenders = []
        for path in ROOT.rglob("*.qml"):
            text = path.read_text(encoding="utf-8")
            for needle in ("sh -c", "bash -c", "/bin/sh", "eval("):
                if needle in text:
                    offenders.append(f"{path.name}: {needle}")
        self.assertEqual(offenders, [])

    def test_helper_open_uses_argv_not_shell(self):
        source = (ROOT / "bin" / "dank-hermes-shell").read_text(encoding="utf-8")
        self.assertNotIn("shell=True", source)
        self.assertNotIn("os.system", source)

    def test_helper_reads_hermes_state_read_only(self):
        source = (ROOT / "bin" / "dank-hermes-shell").read_text(encoding="utf-8")
        self.assertIn("mode=ro", source)

    def test_actions_are_dispatched_without_inline_query_text(self):
        # a query must reach hermes through --query-file, never as a bare argument
        source = (ROOT / "bin" / "dank-hermes-shell").read_text(encoding="utf-8")
        self.assertIn("--query-file", source)
        self.assertNotIn('"-q", text', source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
