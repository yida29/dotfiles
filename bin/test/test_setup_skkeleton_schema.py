import contextlib
import io
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from urllib.parse import unquote, urlparse


REPO = Path(__file__).resolve().parents[2]
SETUP = runpy.run_path(str(REPO / "bin/setup-skkeleton-schema"))


class SchemaSetupTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=REPO)
        self.addCleanup(self.directory.cleanup)
        self.config = Path(self.directory.name) / "deno.json"
        self.original = (
            '{\n  "imports": {\n'
            '    "jisyo/schema": ' + json.dumps(SETUP["SOURCE"]) + ',\n'
            '    "other": "jsr:other@1"\n'
            '  },\n  "custom": true\n}\n'
        )
        self.config.write_text(self.original)

    def configure(self):
        with contextlib.redirect_stdout(io.StringIO()):
            SETUP["configure"](self.config)

    def test_local_schema_preserves_config_and_backup(self):
        self.config.chmod(0o640)
        self.configure()
        updated = self.config.read_text()
        self.assertEqual(
            updated, self.original.replace(SETUP["SOURCE"], SETUP["SCHEMA"].as_uri()),
        )
        uri = json.loads(updated)["imports"]["jisyo/schema"]
        parsed = urlparse(uri)
        self.assertEqual(parsed.scheme, "file")
        self.assertEqual(
            Path(unquote(parsed.path)).read_bytes(), SETUP["SCHEMA"].read_bytes(),
        )
        backups = list(self.config.parent.glob("deno.json.backup.*/original"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), self.original)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o640)
        self.configure()
        self.assertEqual(self.config.read_text(), updated)
        self.assertEqual(
            list(self.config.parent.glob("deno.json.backup.*/original")), backups,
        )

    def test_unknown_url_is_preserved(self):
        original = self.original.replace(SETUP["SOURCE"], "https://example.org/custom.json")
        self.config.write_text(original)
        with self.assertRaisesRegex(ValueError, "unfamiliar"):
            self.configure()
        self.assertEqual(self.config.read_text(), original)
        self.assertEqual(list(self.config.parent.glob("*.backup.*")), [])

    def test_missing_import_is_preserved(self):
        self.config.write_text('{"imports": {}}\n')
        with self.assertRaises(KeyError):
            self.configure()
        self.assertEqual(self.config.read_text(), '{"imports": {}}\n')
        self.assertEqual(list(self.config.parent.glob("*.backup.*")), [])

    def test_duplicate_import_is_rejected(self):
        original = self.original.replace(
            '    "other": "jsr:other@1"',
            '    "jisyo/schema": ' + json.dumps(SETUP["SOURCE"]),
        )
        self.config.write_text(original)
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.configure()
        self.assertEqual(self.config.read_text(), original)


if __name__ == "__main__":
    unittest.main()
