# Codex Usage for KDE Plasma 6

An unofficial, native Plasma panel widget showing the remaining Codex usage in every window reported by Codex.

The compact panel display derives labels such as `5h` and `1w` from Codex's reported window lengths. It shows up to two windows plus a `+N` indicator; hover or click for every reported window, reset times, plan, additional-credit balance, reset credits, status, and the last update time.

This project is not affiliated with or endorsed by OpenAI or KDE.

## Features

- Native Plasma 6 compact and expanded representations
- Dynamic labels generated from Codex's reported window durations
- Handles one, two, or multiple quota buckets without assuming a fixed schedule
- Configurable automatic refresh (1–1,440 minutes, five by default) plus manual refresh
- ChatGPT icon identifies the widget; clock/calendar icons distinguish usage windows
- Auto/Dark/Light appearance selection, saved per widget
- Readable local reset dates and times, including Today and Tomorrow
- ChatGPT sign-in through Codex's managed browser login
- Reuses an existing Codex login without copying or exposing credentials
- Clear states for missing Codex, signed-out accounts, and errors

## Requirements

- KDE Plasma 6
- Python 3
- A recent Codex CLI installation
- A ChatGPT account with Codex access

## Compatibility

| Environment | Plasma | Python | Codex | Validation |
| --- | --- | --- | --- | --- |
| Fedora KDE 44 | 6.7.5 | 3.14.7 | 0.158.0-alpha.2.1 | 1.2.1 bridge fetched Plus usage; widget installed in the panel |
| Ubuntu 26.04 | 6.6.6 | 3.14 | 0.155.0-alpha.9.2 | Initial release testing |

These are tested combinations, not minimum version requirements. The widget reads **Codex subscription usage** reported by the local app-server; it does not count general ChatGPT messages or API billing usage.

Version 1.2.1 fixes a pipe-buffering bug that could cause a false timeout when several Codex messages arrived together. The fix is not tied to one Codex version. Future incompatible app-server protocol changes may still require a widget update.

## Install a release

Download the `.plasmoid` file from the [latest release](https://github.com/sthuizen/codex-usage-plasmoid/releases/latest), then run:

```bash
kpackagetool6 --type Plasma/Applet --install codex-usage-*.plasmoid
```

Right-click your Plasma panel, enter **Edit Mode**, open **Add Widgets…**, and add **Codex Usage**. Click the widget to see full usage details or sign in if needed. It refreshes automatically every five minutes by default. Right-click the widget and choose **Configure Codex Usage… → General** to change **Refresh every … minutes** (1–1,440 minutes). Click **Apply** or **OK** to save changes for that widget.

In the same configuration page, choose **Appearance → Auto** to follow KDE’s current theme and live colour changes, or select **Dark** or **Light** to override this widget only. The panel indicator gets a matching background in either forced mode so it stays legible even on an opposite-colour panel. Auto is the default.

Clock icons identify windows shorter than a day; calendar icons identify day/week windows. Healthy short windows use the theme’s link colour and longer windows use its positive colour. Amber/red low-remaining warnings take priority. Reset and update times follow your local timezone and time format; nearby resets show Today or Tomorrow, while later ones show a full date.

### Upgrade an existing installation

Download the new release archive, then run (substitute the downloaded filename):

```bash
kpackagetool6 --type Plasma/Applet --upgrade codex-usage-2.0.0.plasmoid
```

Use `--install` for a first installation and `--upgrade` for an existing one. Run these as your normal desktop user, without `sudo`. After upgrading, remove and re-add the panel widget, or log out and back in, to reload its QML. Signing in again is normally unnecessary.

## Install from source

```bash
git clone https://github.com/sthuizen/codex-usage-plasmoid.git
cd codex-usage-plasmoid
./scripts/install.sh
```

## Authentication and privacy

The widget talks to the local `codex app-server`. Codex owns the ChatGPT login flow and credential storage; this widget never reads, copies, or stores access tokens. If you are signed out, the widget can ask Codex to open its managed ChatGPT browser login.

If Codex is installed in a non-standard location, set `CODEX_USAGE_CODEX_BIN` to its executable path in the Plasma environment.

API-key authentication is intentionally not treated as ChatGPT subscription usage because it has separate billing and limits.

## Troubleshooting

- **Codex not found:** ensure a recent Codex CLI is installed. The widget searches `PATH`, `~/.local/bin/codex`, `/usr/local/bin/codex`, `/usr/bin/codex`, and `/usr/lib/chatgpt/resources/codex`. For another location, set `CODEX_USAGE_CODEX_BIN` in the Plasma session environment; setting it in a terminal alone does not update an already-running panel.
- **Sign-in required:** click the widget and use its ChatGPT sign-in action. API-key login does not provide subscription usage.
- **Timed out while waiting for Codex:** upgrade to 1.2.1 or later and refresh. If it persists, check connectivity and run the diagnostic below.
- **No active usage windows:** Codex returned no windows; the widget does not invent limits. Try refreshing later.

Run the installed bridge directly to isolate account/network issues from the panel:

```bash
python3 ~/.local/share/plasma/plasmoids/io.github.thenailedone.codexusage/contents/code/fetch_usage.py usage
```

When [reporting an issue](https://github.com/sthuizen/codex-usage-plasmoid/issues), include the widget version, distribution, Plasma/Python/Codex versions, the error message, and reproduction steps. Review diagnostic output before sharing: it includes account plan, usage, and reset times. Never attach credential files or access tokens.

## Development and validation

```bash
python3 -m unittest discover -s tests -v
```

The tests cover limit normalization, authentication URL validation, and pipe framing (multiple messages, partial lines, and EOF). They do not require an account or network. Live account compatibility needs a separate manual check with the bridge command above.

## Build

```bash
./scripts/package.sh
```

The installable archive is written to `dist/`.

## Remove

```bash
kpackagetool6 --type Plasma/Applet --remove io.github.thenailedone.codexusage
```

## Limitations

The widget relies on Codex's app-server interface, which may evolve. Window durations and the number of quota buckets adapt automatically, but a future incompatible app-server change could still require a widget update. Browser cookies are never imported or inspected.

## License

MIT — see [LICENSE](LICENSE).
