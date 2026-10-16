# Codex Usage for GNOME

A native GNOME 51 top-bar extension ported from [thenailedone/codex-usage-plasmoid](https://github.com/thenailedone/codex-usage-plasmoid), upstream commit `4ce67c56b5827ee67a1809e36d47f8cedeea5077`.

Shows **Codex subscription allowance**, not general ChatGPT message counts or API billing. Unofficial; not affiliated with OpenAI or GNOME.

## Features

- Two dynamically labelled usage windows in the top bar (`5h 75%`, `1w 40%`), with `+N` for additional windows.
- Click to see every reported window, remaining allowance bars, local reset dates, plan, additional credits, reset credits, account status and last update.
- Automatic refresh every five minutes by default; configurable from 1 to 1,440 minutes. Manual refresh in the menu.
- ChatGPT sign-in managed by the local Codex app-server; existing Codex login is reused.
- Auto, dark and light appearance; low allowance warning colours.
- Clear missing-Codex, signed-out and failure states. Network failures retain the last successful reading and mark it stale. Signed-out results clear cached data.
- Optional Codex executable path in Preferences for installations outside the usual locations.

The GNOME version uses the top-bar menu rather than a Plasma desktop widget. Settings live in the native Preferences window. It uses a symbolic system-monitor icon rather than the ChatGPT logo. GNOME 51 is the declared target; older versions are not enabled without testing.

## Requirements

GNOME Shell 51, Python 3, and a recent Codex CLI/app-server with a ChatGPT account. To build from source, install `glib-compile-schemas` (normally included with GNOME). No pip or npm packages are needed.

## Install

From this source directory:

```sh
bash scripts/install.sh
```

Or install the supplied archive:

```sh
gnome-extensions install --force /path/to/codex-usage@thenailedone.shell-extension.zip
```

On first installation, log out and back in if GNOME does not discover the extension immediately. Then enable it:

```sh
gnome-extensions enable codex-usage@thenailedone
```

Use your normal desktop user, without sudo. Click the top-bar indicator for allowance and sign-in actions. Open **Preferences…** to set the refresh interval, theme or executable path. After an upgrade, log out and back in to reload extension modules.

## Authentication

The included Python bridge derives from the plasmoid's MIT-licensed bridge. It communicates with `codex app-server --stdio`; Codex owns login and credential storage. The extension never reads or copies token files. API-key authentication does not provide subscription allowance. Nothing is sent to any extra service by this extension.

Executable discovery checks `CODEX_USAGE_CODEX_BIN`, PATH, `~/.local/bin/codex`, `/usr/local/bin/codex`, `/usr/bin/codex` and `/usr/lib/chatgpt/resources/codex`. The Preferences override is passed directly as an environment variable; no shell command is constructed.

## Troubleshooting

- **Install Codex:** install the CLI or enter its absolute executable path in Preferences, then apply the entry.
- **Sign in:** click “Sign in with ChatGPT” and finish the browser flow. The request times out after about five minutes.
- **Update failed:** the displayed values are the last successful reading, with its timestamp. Refresh when connectivity returns.
- **No windows:** Codex returned no active limits; the extension does not invent them.
- The underlying app-server protocol may evolve and require a bridge update.

To isolate the bridge from GNOME:

```sh
python3 bridge/fetch_usage.py usage
```

This diagnostic includes plan, allowance and reset times; do not share credentials.

## Development

```sh
python3 -m unittest discover -s tests -v
gjs -m tests/test_format.js
gjs -m tests/check_syntax.js extension.js prefs.js format.js
glib-compile-schemas --strict schemas
python3 scripts/package.py
```

Automated checks cover normalization, pipe framing, error states, formatting, process cleanup and JavaScript syntax. They do not establish live GNOME rendering or account compatibility. A manual check should cover opening the popup, Preferences, all appearances, refresh, sign-in, and disabling the extension during a request. Confirm no orphan `codex app-server` process remains after disabling.

## Remove

```sh
gnome-extensions disable codex-usage@thenailedone
gnome-extensions uninstall codex-usage@thenailedone
```

MIT license, preserving the upstream copyright; see LICENSE.
