#!/usr/bin/env bash
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$source_dir/scripts/package.py"
gnome-extensions install --force "$source_dir/../codex-usage@thenailedone.shell-extension.zip"
if gnome-extensions enable codex-usage@thenailedone; then
    echo 'Codex Usage enabled. If upgrading, log out and back in to reload its code.'
else
    echo 'Installed. Log out and back in, then run: gnome-extensions enable codex-usage@thenailedone'
fi
