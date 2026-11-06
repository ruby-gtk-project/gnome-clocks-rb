# gnome-clocks component inventory

Surveyed against `origin/master` (upstream has no `main` ref; `master` is
upstream's default branch and `origin/HEAD` on this fork points at `ruby`).
Compared against `lib/` on `ruby` as of this commit.

Upstream: 4 panels (World, Alarm, Stopwatch, Timer). The port currently ships
**2 of 4** (Stopwatch, Timer) end to end, plus the window chrome, settings,
utils and shortcuts dialog that host them. `PanelId` and the `Clock` interface
in `lib/clock.rb` already name `WORLD` and `ALARM`, and `Settings` already
carries the `world-clocks` and `alarms` GSettings-equivalent keys — the
scaffolding expects the two missing panels but nothing builds their widgets
yet.

Legend for **kind**: `window` / `page` / `panel` / `dialog` / `row` / `widget`
(reusable control) / `model` (plain data object, not a widget) / `service`
(non-UI: D-Bus, geocoding, audio) / `entrypoint` / `interface`.

## Already ported (present = yes)

| Upstream file(s) | → lib path | Kind | Present |
|---|---|---|---|
| `src/clock.vala` | `lib/clock.rb` | interface | yes |
| `src/utils.vala` | `lib/utils.rb` | service | yes |
| `src/widgets.vala` | `lib/widgets.rb` | widget | yes |
| `src/main.vala` | `lib/main.rb` | entrypoint | yes |
| `src/window.vala` + `data/ui/window.ui` | `lib/window.rb` | window | yes, but only wires Stopwatch/Timer into `PANELS`; World/Alarm stack pages, `AdwBreakpoint` setters for them, and the `set-page` Alt+1/Alt+2 accelerators for World/Alarm are absent until those panels exist |
| `src/header-bar.vala` + `data/ui/header-bar.ui` | `lib/header_bar.rb` | widget | yes |
| `data/ui/shortcuts-dialog.ui` | `lib/shortcuts_dialog.rb` | dialog | yes, but its sections are built from `PANELS.keys` (see `ShortcutsDialog.new(PANELS.keys)` in `window.rb`), so it only documents Stopwatch/Timer shortcuts until the other two panels are registered |
| `data/org.gnome.clocks.gschema.xml.in` | `lib/settings.rb` | model | yes (JSON-backed equivalent); `world-clocks` and `alarms` keys already present and unused |
| `src/stopwatch-face.vala` + `data/ui/stopwatch-face.ui` | `lib/stopwatch_face.rb` | page | yes |
| `src/stopwatch-lap.vala` | `lib/stopwatch_lap.rb` | model | yes |
| `src/stopwatch-laps-row.vala` + `data/ui/stopwatch-laps-row.ui` | `lib/stopwatch_laps_row.rb` | row | yes |
| `src/timer-face.vala` + `data/ui/timer-face.ui` | `lib/timer_face.rb` | page | yes |
| `src/timer-item.vala` | `lib/timer_item.rb` | model | yes |
| `src/timer-row.vala` + `data/ui/timer-row.ui` | `lib/timer_row.rb` | row | yes |
| `src/timer-setup.vala` + `data/ui/timer-setup.ui` | `lib/timer_setup.rb` | widget | yes |
| `src/timer-setup-dialog.vala` + `data/ui/timer-setup-dialog.ui` | `lib/timer_setup_dialog.rb` | dialog | yes |

## Missing — World panel

| Upstream file(s) | → lib path | Kind | Present |
|---|---|---|---|
| `src/world-face.vala` + `data/ui/world-face.ui` | `lib/world_face.rb` | page | no |
| `src/world-item.vala` | `lib/world_item.rb` | model | no |
| `src/world-row.vala` + `data/ui/world-row.ui` | `lib/world_row.rb` | row | no |
| `src/world-location-dialog.vala` + `data/ui/world-location-dialog.ui` | `lib/world_location_dialog.rb` | dialog | no |
| `src/world-location-dialog-row.vala` + `data/ui/world-location-dialog-row.ui` | `lib/world_location_dialog_row.rb` | row | no |
| `src/world-standalone.vala` + `data/ui/world-standalone.ui` | `lib/world_standalone.rb` | page (standalone subpage, e.g. opened from the search provider) | no |
| `src/world-shell-world-clocks.vala` | `lib/world_shell_world_clocks.rb` | service (D-Bus: exports world clocks to GNOME Shell) | no |
| `src/geocoding.vala` | `lib/geocoding.rb` | service (location lookup backing `world-location-dialog`; needs `GWeather`/`GeocodeGlib`) | no |
| `src/cutils.c` + `src/twilight.c` | `lib/utils.rb` (extend) or `lib/twilight.rb` | service (day/night shading math for `world-row`/`world-face`) | no |

## Missing — Alarm panel

| Upstream file(s) | → lib path | Kind | Present |
|---|---|---|---|
| `src/alarm-face.vala` + `data/ui/alarm-face.ui` | `lib/alarm_face.rb` | page | no |
| `src/alarm-item.vala` | `lib/alarm_item.rb` | model | no |
| `src/alarm-row.vala` + `data/ui/alarm-row.ui` | `lib/alarm_row.rb` | row | no |
| `src/alarm-day-picker-row.vala` + `data/ui/alarm-day-picker-row.ui` | `lib/alarm_day_picker_row.rb` | row (repeat-day picker inside the setup dialog) | no |
| `src/alarm-setup-dialog.vala` + `data/ui/alarm-setup-dialog.ui` | `lib/alarm_setup_dialog.rb` | dialog | no |
| `src/alarm-ringing-panel.vala` + `data/ui/alarm-ringing-panel.ui` | `lib/alarm_ringing_panel.rb` | panel (full-window ringing state, pushed via `navigation_view`/`toast_overlay`) | no |
| `src/alarm-sound-model.vala` | `lib/alarm_sound_model.rb` | model (list model backing the sound chooser) | no |
| `src/sound-chooser.vala` + `data/ui/sound-chooser.ui` | `lib/sound_chooser.rb` | widget | no |
| `src/sound-chooser-row.vala` + `data/ui/sound-chooser-row.ui` | `lib/sound_chooser_row.rb` | row | no |
| `src/sound.vala` | `lib/sound.rb` | service (plays `data/sounds/alarms/*.flac`/`complete.oga`; upstream uses libgsound) | no |

## Missing — application-level

| Upstream file(s) | → lib path | Kind | Present |
|---|---|---|---|
| `src/application.vala` | `lib/main.rb` (extend `App`) | entrypoint | partial — `quit`/`shortcuts` actions and accelerators are ported; `stop-alarm`, `snooze-alarm` and `add-location` actions, the `dbus_register`/`dbus_unregister` override that exports the search provider and `World.ShellWorldClocks`, and `--version` option handling are not |
| `src/search-provider.vala` | `lib/search_provider.rb` | service (D-Bus search provider; `data/org.gnome.clocks.search-provider.ini.in`) | no |

## Non-component upstream files (reference only, no `lib/*.rb` target)

- `data/gnome-clocks.gresource.xml` — GResource manifest; the port loads assets (icons, sounds, CSS) straight from disk/gem data, so nothing to port 1:1.
- `data/css/gnome-clocks.css` — stylesheet; `Utils.load_css` in `lib/utils.rb` already loads a port-side stylesheet, but it has not been checked against upstream's for World/Alarm classes since those widgets don't exist yet.
- `data/org.gnome.clocks.desktop.in.in`, `*.metainfo.xml.in.in`, `*.service.in` — packaging metadata, not UI.
- `po/*.po`, `help/**` — translation catalogue and user documentation; out of scope for this component survey (see the `translation-parity` skill for `po/`).

## Totals

- Upstream user-facing component files (`src/*.vala` with a UI role, plus their `.ui`): 29 source files / 22 `.ui` files across World, Alarm, Stopwatch, Timer, window chrome and app shell.
- Ported on `ruby`: 15 upstream files fully covered (Stopwatch panel, Timer panel, window chrome, settings, utils, widgets, shortcuts dialog, entrypoint).
- Not yet started: World panel (9 files), Alarm panel (10 files), application-level D-Bus/search-provider wiring (2 files) — 21 files, 0 of which have a `lib/*.rb` counterpart yet.
