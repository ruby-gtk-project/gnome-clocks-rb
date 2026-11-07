# Component identification — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` (fork parent default branch; there is no `origin/main`) |
| Port | `ruby` @ `e85d7e5` |

This document records the raw inventory step. The judged, axis-by-axis
comparison is `.reports/component-parity.md`; this file exists so that
document's claims can be checked against a scan.

## Declarative UI (Step 1)

Upstream ships 21 `.ui` files under `data/ui/`, one per component, each a
`<template class="Clocks...">` root bound to a `.vala` class of the same name.
These are the authoritative unit list:

```
alarm-day-picker-row.ui  alarm-face.ui  alarm-ringing-panel.ui  alarm-row.ui
alarm-setup-dialog.ui    header-bar.ui  shortcuts-dialog.ui     sound-chooser.ui
sound-chooser-row.ui     stopwatch-face.ui  stopwatch-laps-row.ui
timer-face.ui  timer-row.ui  timer-setup-dialog.ui  timer-setup.ui
window.ui  world-face.ui  world-location-dialog-row.ui
world-location-dialog.ui  world-row.ui  world-standalone.ui
```

`shortcuts-dialog.ui` has no backing `.vala` file (a standalone template,
per the `component-identification` skill's Step 2 rule). All other 20 are
`.vala` + `.ui` pairs that union into one port file each.

The port (by house style) has **no `.ui` files** — every unit is built as
memoized Ruby methods. This is a correspondence, not a gap, per
`component-parity`.

## Symbol table / scan (Steps 2–3)

```
component-scan.sh /tmp/up-clocks/src   -> 191 rows
component-scan.sh lib                  -> 209 rows
```

(`gir-symbols.sh` was not rebuilt in this pass; rows that the scan cannot
classify stay `widget` conservatively, per the skill's fallback. The reading
pass in `component-parity.md` strikes known non-widgets by hand — enums
such as `Adw.Easing`-style symbols did not appear in this app's rows.)

## File-level unit map (upstream file(s) → port file)

| Upstream | Port | Ported? |
|---|---|---|
| `src/main.vala`, `src/application.vala` + header-bar.ui menu | `lib/main.rb` | yes |
| `src/window.vala` + `window.ui` | `lib/window.rb` | yes |
| `src/header-bar.vala` + `header-bar.ui` | `lib/header_bar.rb` | yes |
| `shortcuts-dialog.ui` | `lib/shortcuts_dialog.rb` | yes |
| `src/clock.vala` | `lib/clock.rb` | yes |
| `src/widgets.vala` | `lib/widgets.rb` | yes |
| `src/utils.vala`, `src/cutils.c` | `lib/utils.rb` | yes |
| `src/stopwatch-face.vala` + `.ui` | `lib/stopwatch_face.rb` | yes |
| `src/stopwatch-lap.vala` | `lib/stopwatch_lap.rb` | yes |
| `src/stopwatch-laps-row.vala` + `.ui` | `lib/stopwatch_laps_row.rb` | yes |
| `src/timer-face.vala` + `.ui` | `lib/timer_face.rb` | yes |
| `src/timer-item.vala` | `lib/timer_item.rb` | yes |
| `src/timer-row.vala` + `.ui` | `lib/timer_row.rb` | yes |
| `src/timer-setup.vala` + `.ui` | `lib/timer_setup.rb` | yes |
| `src/timer-setup-dialog.vala` + `.ui` | `lib/timer_setup_dialog.rb` | yes |
| `src/world-face.vala` + `.ui` | `lib/world_face.rb` | yes (landed `e85d7e5`, after the 11/02 inventory) |
| `src/world-item.vala`, `src/twilight.c` | `lib/world_item.rb`, `lib/twilight.rb` | yes |
| `src/world-row.vala` + `.ui` | `lib/world_row.rb` | yes |
| `src/world-standalone.vala` + `.ui` | `lib/world_standalone.rb` | yes |
| `src/world-location-dialog.vala` + `.ui` | `lib/world_location_dialog.rb` | yes |
| `src/world-location-dialog-row.vala` + `.ui` | `lib/world_location_dialog_row.rb` | yes |
| `src/geocoding.vala` | — | **no port file** |
| `src/world-shell-world-clocks.vala` | — | **no port file** |
| `src/search-provider.vala` | — | **no port file** |
| `src/alarm-face.vala` + `.ui` | — | **no port file** |
| `src/alarm-item.vala` | — | **no port file** |
| `src/alarm-row.vala` + `.ui` | — | **no port file** |
| `src/alarm-setup-dialog.vala` + `.ui` | — | **no port file** |
| `src/alarm-day-picker-row.vala` + `.ui` | — | **no port file** |
| `src/alarm-ringing-panel.vala` + `.ui` | — | **no port file** |
| `src/sound-chooser.vala` + `.ui` | — | **no port file** |
| `src/sound-chooser-row.vala` + `.ui` | — | **no port file** |
| `src/alarm-sound-model.vala` | — | **no port file** |
| `src/sound.vala` | — | **no port file** |

## What changed since the standing inventory (`.reports/component-inventory.md`)

That document was last re-surveyed 2026-11-02 and recorded the World panel as
entirely missing. Commit `e85d7e5` ("Port the World panel: twilight, item,
row, standalone, location dialog") landed after that survey and closes those
six rows. **The Alarm panel (9 upstream units: face, item, row, setup dialog,
day-picker row, ringing panel, sound chooser, sound-chooser row, sound model
+ playback) and the three support units (`geocoding.rb`, shell D-Bus clocks,
search provider) remain entirely unported.** `.reports/component-inventory.md`
is stale on the World panel's status and should be read together with this
file, not instead of it; `component-parity.md` carries the corrected totals.

## Rule check

Per the skill's Step 4, every "no port file" row above was confirmed by
reading `lib/` directory contents and `git grep -l` for the upstream class
names (`ClocksAlarm`, `AlarmFace`, `SoundChooser`, `Geocoding`,
`SearchProvider`, `ShellWorldClocks`) — none appear anywhere in `lib/` or
`exe/`. This is not a scan artifact; the code does not exist.
