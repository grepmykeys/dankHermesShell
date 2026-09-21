# Dank Hermes Shell

A DankMaterialShell plugin that puts **Hermes Agent** in the DMS bar: gateway and agent
status, a recent-activity indicator, token/cost usage with a 7-day chart, the recent
session list (click one to reopen it in the Hermes TUI), and one-shot queries that answer
in the background.

It is the DMS counterpart to the Omarchy Hermes plugins (Hermes Deck / Hermes Sessions /
Hermes Harness), written against the DMS 1.6 plugin API for Hyprland + Quickshell.

## What it shows

**Bar pill** (horizontal and vertical):

| State | Icon colour | Label (default `auto` mode) |
|-------|-------------|------------------------------|
| Gateway up, recent agent activity | primary | today's tokens |
| Gateway up, idle, live sessions | surface text | live session count |
| Gateway up, idle, no live sessions | surface text | no label |
| Gateway stopped | error | tokens if recently active, otherwise live count or no label |

Activity is inferred from session updates within the last five minutes; it is not
an exact indication that a turn is currently running.

Right-click the pill opens a fresh Hermes TUI session.

**Popout**

- **Status** — dot for working / running / stopped, gateway pid and version, model,
  provider, reasoning effort, connected messaging platforms, live session count.
- **Ask Hermes** — a one-shot query runs in the background (`hermes chat --oneshot -Q`)
  and the answer appears in the popout when it lands, plus an optional DMS notification.
  "Open TUI" seeds your terminal with the same text instead. "Answer file" opens the raw
  output with your default app.
- **Usage** — today / 7 days / all-time tokens and estimated cost, API calls today, a
  per-day bar chart, and a per-model breakdown for the week.
- **Recent sessions** — most recent first with age, model, branch, tool-call count, tokens
  and cost. Clicking a row runs `hermes chat --resume <id>` in your terminal. Active
  sessions are outlined and marked. **Refresh** updates status, sessions, and usage now;
  the same data also refreshes automatically at the intervals in plugin settings.

## Install

Run from the root of your local clone (this plugin is not in the plugin registry yet):

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
ln -s "$PWD" ~/.config/DankMaterialShell/plugins/dankHermesShell
dms ipc call plugin-scan scan        # discover it
dms ipc call plugins enable dankHermesShell
```

Then place the widget: **Settings → Bar → your bar → Add widget → Dank Hermes Shell**
(bar layout lists are not writable over IPC), or hold the bar's edit mode and drag it in.

Requires DankMaterialShell 1.6+, a configured
Hermes Agent installation, `python3` (stdlib only, no pip packages), and a terminal emulator for the TUI
actions: kitty, ghostty, alacritty, foot, wezterm or konsole, or set an explicit
"Terminal command" in the plugin settings.

## How it gets its data

`bin/dank-hermes-shell` is a stdlib-only Python helper. Every command prints one JSON object on
stdout; QML passes argument arrays, never shell strings. Prompts reach Hermes via
`--query-file`, although the short-lived helper receives the text as an argument.

| Command | Purpose |
|---------|---------|
| `status` | gateway_state.json + active_sessions.json + config.yaml → gateway, model, live sessions |
| `usage --days 7` | aggregates `session_model_usage` from `~/.hermes/state.db` into today / week / month / all-time, per-model and per-day |
| `sessions --limit N` | recent rows from the `sessions` table |
| `terminal-argv [--resume ID] [--query TEXT]` | builds the TUI argv; queries are passed via a temp file, never inline |
| `open`, `prompt --text`, `answer` | launch the TUI, run a background one-shot query, read the last answer |
| `doctor` | hermes executable, state.db readability, terminal detection, gateway state file |

`~/.hermes/state.db` is opened **read-only** (`file:...?mode=ro`), so Hermes' own database
is not modified by monitoring. Provider/model come from `~/.hermes/config.yaml`.
`HERMES_HOME`, when set in the shell's environment, overrides that location.

Usage windows group cumulative session/model totals by their last-seen timestamp.
They are approximate activity-based totals, not exact daily billing: resuming an
older session can move its accumulated usage into today's bucket.

## Settings

Bar label mode (auto / tokens / sessions / model / icon only), status refresh interval,
usage refresh interval, how many sessions to list, the answer notification toggle, and an
optional terminal command override.

## Troubleshooting

```bash
cd ~/.config/DankMaterialShell/plugins/dankHermesShell
./bin/dank-hermes-shell doctor        # dependency + data checks
./bin/dank-hermes-shell status        # what the popout will show
python3 -m unittest discover -s tests
```

- **Pill shows a red icon** — the gateway is stopped. The popout also shows helper
  errors, with a "Run doctor" button when an error is present.
- **No sessions listed** — the list excludes archived and hidden sessions by design.
- **Usage shows a dash** — `hermes` may not have recorded usage yet; the totals come from
  Hermes' own usage table, not from this plugin.
- **Nothing opens on click** — no supported terminal emulator was found; set "Terminal
  command" in the plugin settings (e.g. `kitty -e`).

## Uninstall

```bash
dms ipc call plugins disable dankHermesShell
rm ~/.config/DankMaterialShell/plugins/dankHermesShell   # removes only the symlink
```

Monitoring leaves Hermes' own data untouched; launched Hermes sessions write their
normal session state. The helper's answer log and unique query files live in the
private directory `~/.local/state/dank-hermes-shell` (or `$XDG_STATE_HOME/dank-hermes-shell`).
Only one background query may run at a time. Query files are retained so detached
TUI launches can read them; you can remove this directory after all queries and
TUI launches have finished if you no longer need the saved prompts/answer.

## Layout

```
dankHermesShell/
  plugin.json              # composite: daemon + bar widget
  HermesService.qml        # daemon surface: polls the helper, holds state, owns actions
  HermesWidget.qml         # bar pill(s) + popout wiring
  HermesSettings.qml       # PluginSettings UI
  components/
    HermesPopout.qml       # scrollable popout body
    HermesStatusCard.qml
    HermesAskCard.qml
    HermesUsageCard.qml
    HermesSessionRow.qml
  bin/dank-hermes-shell    # JSON helper (python3, stdlib)
  tests/test_dank_hermes_shell.py
  tests/test_manifest.py
```

## License

MIT — see [LICENSE](LICENSE).
