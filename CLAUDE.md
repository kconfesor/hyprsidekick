# CLAUDE.md — Hyprsidekick

Omarchy 4 Quickshell **bar-widget** plugin (`kconfesor.hyprsidekick`): mnemonic
named-workspace switcher — a pill + a click dropdown + an in-shell Settings panel
that also generates the matching Hyprland keybinds.

## Repos / layout

- **This is the dev/source repo** (`~/source/omarchy-plugins/hyprsidekick/`). Push to GitHub from here.
- **Installed copy** lives at `~/.config/omarchy/plugins/kconfesor.hyprsidekick/` — a git checkout whose `origin` is this repo, installed via `omarchy plugin add "file://…/hyprsidekick"`. The running shell loads that copy, NOT this one.
- The on-disk directory name MUST equal the manifest `id`.

## Dev loop (IMPORTANT)

1. Edit files **here** (source repo).
2. `git commit`.
3. `omarchy plugin update kconfesor.hyprsidekick` — fast-forwards the installed copy from this repo.
4. `omarchy restart shell` — **required**: editing a bar-widget file only reloads the plugin *registry*, it does NOT re-instantiate the already-mounted widget. Structural QML changes appear only after a full shell restart. (Only `shell.json` *settings* apply live.)

Verify a change loaded cleanly: `journalctl --user --since "20 seconds ago" -o cat | grep -i hyprsidekick` (look for QML errors), and `omarchy plugin validate ~/.config/omarchy/plugins/kconfesor.hyprsidekick`.

## Files

- `manifest.json` — `kinds:["bar-widget"]`, entry `Widget.qml`, `barWidget.defaults`. All publish-required fields present (incl. `license`).
- `Widget.qml` — bar entry: the pill, hosts the dropdown + Settings via two `Loader`s, owns the **durable config** (`FileView` on `~/.config/hyprsidekick/config.json`), and the popout contract (`open/close/opened/…` — must cover BOTH panels, see gotchas).
- `Panel.qml` — the dropdown (a `qs.Ui.Panel` + `KeyboardPanel`); rows from `Model.namedRows`/`numberedRows`/`numberedRange`; click → jump.
- `Settings.qml` — the editor panel: workspace rows (key/name/icon picker), display options, bar Position, hide-stock toggle, Apply-to-Hyprland, Cancel/Done. Live-preview via `hostWidget.settings`, commit on Done.
- `Model.js` — pure logic (no QML imports, no `.pragma`): `namedRows`, `numberedRows`, `numberedRange`, `pillLabel`, `jumpTarget`, `hyprBindsLua`. Node-tested.
- `test/model.test.js` — `node test/model.test.js` → "9 checks passed".

## Data flow

`~/.config/hyprsidekick/config.json` (durable source of truth, written by Settings on commit)
→ mirrored to the widget's entry in `~/.config/omarchy/shell.json` (the live injection surface the pill/dropdown read via `setting(...)`)
→ **Apply to Hyprland** generates `~/.config/hypr/hyprsidekick.lua` (`o.bind` loop) + `hyprctl reload`.

`bindings.lua` has `require("hypr.hyprsidekick")` (marker `HYPRSIDEKICK:REQUIRE`); the manual named-workspace loop was retired. On load, `Widget.qml` self-heals `shell.json` from `config.json` if a plugin disable/enable reset the entry to defaults.

## Omarchy gotchas (cost real debugging — do not relearn)

- **`bar.shellQuote` does NOT exist.** Use `Util.shellQuote` (`qs.Commons`).
- **Workspace switching:** this Hyprland (Lua "Quattro") rejects `hyprctl dispatch workspace <id>`. Use `hyprctl dispatch 'hl.dsp.focus({ workspace = "name:web" })'` (single-quoted). In QML: `bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ workspace = "' + target + '" })'))`.
- **Named workspaces have negative ids** — match by `.name`, never numeric id.
- **Popout dismiss routing:** both panels use the Widget as their `KeyboardPanel.owner`, so outside-click dismiss calls `owner.close()` → the Widget's `close()`/`opened`/`closeForPopoutSwitch` MUST cover BOTH panels, or the other stays stuck with a focus grab.
- **File writes:** use `FileView.setText(...)` (UTF-8 safe for icon glyphs) — NOT `Qt.btoa` (may corrupt multibyte).
- **In-card diagnostics** (Timers/logs inside a `KeyboardPanel`) only run once the panel is mapped (opened); root-level ones run immediately.

## Publish

Public GitHub repo + `manifest.json`/`README.md`/`LICENSE` (all present). Validate with `omarchy plugin validate`, then `gh repo create hyprsidekick --public --source=. --remote=origin --push` and submit the marketplace issue form. Marketplace recommends reverse-domain ids (`io.github.<user>.<name>`); current id `kconfesor.hyprsidekick` is valid but not that form.
