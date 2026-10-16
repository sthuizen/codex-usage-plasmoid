#!/usr/bin/env python3
"""Build an installable extension zip from an explicit file allowlist."""
from pathlib import Path
import subprocess
import tempfile
import zipfile
import shutil

root = Path(__file__).resolve().parents[1]
output = root.parent / 'codex-usage@thenailedone.shell-extension.zip'
with tempfile.TemporaryDirectory() as tmp:
    schema = Path(tmp)
    shutil.copy(root / 'schemas/org.gnome.shell.extensions.codex-usage.gschema.xml', schema)
    subprocess.run(['glib-compile-schemas', '--strict', str(schema)], check=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in ['metadata.json', 'extension.js', 'prefs.js', 'format.js', 'stylesheet.css', 'bridge/fetch_usage.py', 'LICENSE', 'README.md']:
            archive.write(root / name, name)
        for path in schema.iterdir():
            archive.write(path, f'schemas/{path.name}')
print(output)
