# Changelog

All notable changes to Dank Hermes Shell are documented here.
This project follows [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-09-20

Initial release.

- Bar pill (horizontal + vertical) showing gateway/agent state, with an auto/tokens/
  sessions/model/icon-only label mode.
- Popout: status card, one-shot "Ask Hermes" card (background query + notification),
  usage card (today / 7-day / all-time tokens and cost, per-model breakdown, 7-day
  chart), and a recent-sessions list that reopens sessions in the Hermes TUI.
- `bin/dank-hermes-shell`: stdlib-only Python helper reading `~/.hermes/state.db`
  read-only, plus `gateway_state.json` / `active_sessions.json` / `config.yaml`.
- Plugin settings: bar label mode, status/usage refresh intervals, sessions shown,
  answer notification toggle, terminal command override.
- `doctor` command for install verification.
- 46 unit tests covering the helper and the plugin manifest.
