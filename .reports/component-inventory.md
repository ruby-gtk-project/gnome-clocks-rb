# gnome-clocks-rb — upstream component inventory

Survey of upstream `gnome-clocks` (GNOME/gnome-clocks `master`, read via
`origin/master` in this fork — upstream has no `main` ref) against the `ruby`
branch's `lib/`. No app code was written for this survey; this is the mapping
step `component-identification` asks for, scoped to whole files rather than
per-widget rows, because the headline finding here is file-level: **an entire
upstream panel, and the services the application object wires up around it,
are absent from the port.**

Upstream tree read: `git ls-tree -r --name-only origin/master` plus every
`src/*.vala`, `src/*.c`, and the corresponding `data/ui/*.ui`,
`data/org.gnome.clocks.gschema.xml.in`, `data/gnome-clocks.gresource.xml`.

Legend: **present** = a `lib/*.rb` file exists that is explicitly ported from
this upstream file (per its header comment). **MISSING** = no `lib/*.rb` file
exists for it at all, not even a stub.

## Application shell

| Upstream file | → `lib/*.rb` | Kind | Present? |
|---|---|---|---|
| `src/main.vala` | `lib/main.rb` | app entry / `App` class | present |
| `src/application.vala` | `lib/main.rb` (partial) | app actions, accelerators, About | **partial** — see "Acknowledged gaps" below |
| `src/window.vala` + `data/ui/window.ui` | `lib/window.rb` | main window (`Adw.ApplicationWindow`, nav view, view stack, view switcher, toast overlay) | present |
| `src/header-bar.vala` + `data/ui/header-bar.ui` | `lib/header_bar.rb` | header bar widget | present |
| (no backing `.vala`) `data/ui/shortcuts-dialog.ui` | `lib/shortcuts_dialog.rb` | keyboard shortcuts window (standalone `.ui`, no source class) | present |
| `src/clock.vala` | `lib/clock.rb` | `PanelId`/`ButtonMode` enums, `Clock` duck-type contract | present |
| `src/utils.vala` | `lib/utils.rb` | time/duration formatting, `WallClock` wrapper | present |
| `src/widgets.vala` | `lib/widgets.rb` | shared widget helpers (`ContentStore`, etc.) | present |
| `src/twilight.c` | `lib/twilight.rb` | sunrise/sunset calculation | present |
| `data/org.gnome.clocks.gschema.xml.in` | `lib/settings.rb` | GSettings schema (`world-clocks`, `alarms`, `timers`, `geolocation`, window state, panel-id) | present (schema modeled; `alarms` key is carried as dead data — see below) |
| `src/cutils.c` | — | ICU-backed duration/week-start C helpers used by the alarm day-picker and duration formatting | **MISSING** — no `lib/cutils.rb` or equivalent; `lib/utils.rb` has its own formatting instead, not checked against this file's output format |
| `data/gnome-clocks.gresource.xml` | — | GResource bundle manifest (bundles the `.ui`/CSS/icons for the Vala build) | N/A for the Ruby port — the house style has no `.ui` files, nothing to map |
| `po/*.po`, `po/POTFILES.in` | — | translation catalogue | out of scope here — covered by the `translation-parity` skill, not this inventory |

## World panel

| Upstream file | → `lib/*.rb` | Kind | Present? |
|---|---|---|---|
| `src/world-face.vala` + `data/ui/world-face.ui` | `lib/world_face.rb` | panel page (list of world clocks, empty state, add button) | present |
| `src/world-item.vala` | `lib/world_item.rb` | per-location model/item | present |
| `src/world-row.vala` + `data/ui/world-row.ui` | `lib/world_row.rb` | list row widget | present |
| `src/world-location-dialog.vala` + `data/ui/world-location-dialog.ui` | `lib/world_location_dialog.rb` | "Add a City" search dialog (GWeather location tree) | present |
| `src/world-location-dialog-row.vala` + `data/ui/world-location-dialog-row.ui` | `lib/world_location_dialog_row.rb` | search-result row in that dialog | present |
| `src/world-standalone.vala` + `data/ui/world-standalone.ui` | `lib/world_standalone.rb` | standalone/narrow-width world clock face | present |
| `src/geocoding.vala` | — | reverse-geocodes the device's current location (via `geocode-glib`) to offer as a world clock / to resolve `app.add-location`'s GWeather variant | **MISSING** — no `lib/geocoding.rb`; `geocode-glib` is in the gemspec as a runtime dependency but is not `require`d or referenced anywhere in `lib/` |
| `src/world-shell-world-clocks.vala` | — | exports the current world-clock list over D-Bus for the GNOME Shell clock applet | **MISSING** — no equivalent; acknowledged as dropped in `lib/main.rb`'s header comment |

## Stopwatch panel

| Upstream file | → `lib/*.rb` | Kind | Present? |
|---|---|---|---|
| `src/stopwatch-face.vala` + `data/ui/stopwatch-face.ui` | `lib/stopwatch_face.rb` | panel page | present |
| `src/stopwatch-lap.vala` | `lib/stopwatch_lap.rb` | lap model | present |
| `src/stopwatch-laps-row.vala` + `data/ui/stopwatch-laps-row.ui` | `lib/stopwatch_laps_row.rb` | lap list row | present |

## Timer panel

| Upstream file | → `lib/*.rb` | Kind | Present? |
|---|---|---|---|
| `src/timer-face.vala` + `data/ui/timer-face.ui` | `lib/timer_face.rb` | panel page | present |
| `src/timer-item.vala` | `lib/timer_item.rb` | timer model | present |
| `src/timer-row.vala` + `data/ui/timer-row.ui` | `lib/timer_row.rb` | running-timer list row | present |
| `src/timer-setup.vala` + `data/ui/timer-setup.ui` | `lib/timer_setup.rb` | the preset/custom duration picker widget | present |
| `src/timer-setup-dialog.vala` + `data/ui/timer-setup-dialog.ui` | `lib/timer_setup_dialog.rb` | dialog wrapping the setup widget | present |

## Alarm panel — entirely missing

The window's `PANELS` constant in `lib/window.rb` lists only World, Stopwatch
and Timer; its own comment says "The panels it hosts are the ones this port
has." The fourth upstream panel, Alarm, has no `lib/*.rb` file of any kind —
not a stub, not a partial page. Every upstream file below is unported:

| Upstream file | Should become | Kind | Present? |
|---|---|---|---|
| `src/alarm-face.vala` + `data/ui/alarm-face.ui` | `lib/alarm_face.rb` | panel page (alarm list, empty state, add button) | **MISSING** |
| `src/alarm-item.vala` | `lib/alarm_item.rb` | alarm model (time, days, label, snooze/dismiss state) | **MISSING** |
| `src/alarm-row.vala` + `data/ui/alarm-row.ui` | `lib/alarm_row.rb` | alarm list row (on/off switch, days summary) | **MISSING** |
| `src/alarm-setup-dialog.vala` + `data/ui/alarm-setup-dialog.ui` | `lib/alarm_setup_dialog.rb` | add/edit alarm dialog | **MISSING** |
| `src/alarm-day-picker-row.vala` + `data/ui/alarm-day-picker-row.ui` | `lib/alarm_day_picker_row.rb` | day-of-week picker row inside the setup dialog | **MISSING** |
| `src/alarm-ringing-panel.vala` + `data/ui/alarm-ringing-panel.ui` | `lib/alarm_ringing_panel.rb` | full-screen ringing/snooze/dismiss page shown when an alarm fires | **MISSING** |
| `src/alarm-sound-model.vala` | `lib/alarm_sound_model.rb` | `Gio::ListModel` of available alarm sounds | **MISSING** |
| `src/sound-chooser.vala` + `data/ui/sound-chooser.ui` | `lib/sound_chooser.rb` | sound-picker dialog/popover for an alarm's ringtone | **MISSING** |
| `src/sound-chooser-row.vala` + `data/ui/sound-chooser-row.ui` | `lib/sound_chooser_row.rb` | one sound choice row (name + preview-play button) | **MISSING** |
| `src/sound.vala` | `lib/sound.rb` | alarm sound playback (GStreamer-backed) | **MISSING** |

Consequences visible elsewhere in the tree because of this gap:

- `data/org.gnome.clocks.gschema.xml.in`'s `alarms` key and the
  `org.gnome.clocks.panelid` enum's `alarm` value are modeled in
  `lib/settings.rb`/`lib/clock.rb` (`PanelId::ALARM` exists, `'alarms' => []`
  exists) but nothing ever reads or writes through them — dead schema surface.
- `src/application.vala`'s `stop-alarm` and `snooze-alarm` actions (fired by
  notification buttons) and its `add-location` action's GWeather-variant
  deserialization are explicitly listed as not implemented in `lib/main.rb`'s
  own header comment.
- `src/search-provider.vala` — the GNOME Shell search provider that surfaces
  world clocks and (critically) lets Shell's search bar show/stop/snooze a
  ringing alarm — has no `lib/search_provider.rb` and is not mentioned
  anywhere in `lib/`. **MISSING.**
- The `ashpd` gem is declared in the gemspec ("Alarm/world portal access
  (background activation, notifications)") specifically for this feature, but
  is not `require`d or referenced anywhere in `lib/` — there is nothing yet
  for it to back.
- `geocode-glib` (declared in the gemspec for `src/geocoding.vala`) is
  likewise unreferenced in `lib/`, per the World panel section above.

## Binding-gem wiring status (checked, not part of the component count)

The gemspec (`gnome-clocks-rb.gemspec`) already declares `gtk4`, `adwaita`,
`glib2`, `libgweather`, `geocode-glib`, `gnome_desktop` and `ashpd` as runtime
dependencies, and `flake.nix`'s `gtkStack` already carries the matching
nixpkgs typelib packages (`geocode-glib_2`, `gnome-desktop`, `libgweather`,
`libsoup_3`, `json-glib`). Of these, only `GnomeDesktop::WallClock` is
actually used in `lib/` (in `lib/utils.rb`). `GeocodeGlib` and `Ashpd` are
wired into the gemspec/flake but have zero call sites in `lib/`, because the
features that need them (reverse geocoding, alarm background
activation/notifications) are the missing Alarm panel and World-panel
geocoding listed above — this is wiring ahead of the code that will use it,
not a gem that was skipped.

## Totals

- Upstream user-facing component files (`.vala`/`.c` with a widget, dialog,
  panel, or service role, paired with their `.ui` where one exists): 34
  (excluding `config.vapi`, `meson.build`, `cutils.c`'s pure helpers already
  counted above).
- Already present in `lib/` on `ruby`: 23 files/components (Window, header
  bar, shortcuts dialog, World/Stopwatch/Timer panels end to end, clock/
  utils/widgets/twilight/settings/main scaffolding).
- Missing outright: 11 — the entire Alarm panel (7 files: face, item, row,
  setup dialog, day-picker row, ringing panel, sound model), its sound
  subsystem (3 files: sound chooser, sound chooser row, sound playback), and
  the search provider. Plus `src/geocoding.vala` and
  `src/world-shell-world-clocks.vala` as smaller, non-panel gaps — 13 missing
  files in total.
