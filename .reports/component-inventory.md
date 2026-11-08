> **Superseded by `component-identification.md` as of commit 6e26ec6 and
> later.** The Alarm panel's widgets (alarm-face, alarm-row,
> alarm-setup-dialog, sound-chooser/-row) this document still lists as
> MISSING below were ported in commit `834969c`, and the ring-handling gap
> this document does not mention at all (no `alarm-ringing-panel` entry) was
> closed afterward. Read `component-identification.md` for the current
> state; this file is kept for its upstream-file-by-file survey structure,
> not for its present/missing verdicts.

# gnome-clocks-rb — upstream component inventory

Survey of upstream `gnome-clocks` (GNOME/gnome-clocks `master`, read via
`origin/master` in this fork — upstream has no `main` ref) against the `ruby`
branch's `lib/` as it stands now. No app code was written for this survey;
this updates the previous inventory (`git log --oneline -- .reports` shows an
earlier "Inventory upstream components" pass) to the current `lib/` tree,
which has since grown an alarm model layer and a geocoding component that the
earlier inventory marked missing. **The headline finding is unchanged in
kind, smaller in size: the Alarm panel's widgets (not just its model), the
sound-chooser UI, the search provider, and the Shell world-clocks exporter
are still absent from the port.**

Upstream tree read: `git ls-tree -r --name-only origin/master` plus every
`src/*.vala`, `src/*.c`, and the corresponding `data/ui/*.ui`,
`data/org.gnome.clocks.gschema.xml.in`, `data/gnome-clocks.gresource.xml`.

Legend: **present** = a `lib/*.rb` file exists that is explicitly ported from
this upstream file (per its header comment) and is wired in (`require`d and
reachable). **partial** = the file exists but something upstream does is
acknowledged as not implemented. **MISSING** = no `lib/*.rb` file exists for
it at all, not even a stub.

## Application shell

| Upstream file | → `lib/*.rb` | Kind | Present? |
|---|---|---|---|
| `src/main.vala` | `lib/main.rb` | app entry / `App` class | present |
| `src/application.vala` | `lib/main.rb` (partial) | app actions, accelerators, About | **partial** — `stop-alarm`/`snooze-alarm` actions and `add-location`'s GWeather-variant deserialization are explicitly listed as not implemented in `lib/main.rb`'s own header comment |
| `src/window.vala` + `data/ui/window.ui` | `lib/window.rb` | main window (`Adw.ApplicationWindow`, nav view, view stack, view switcher, toast overlay) | present, but its `PANELS` constant lists only World, Stopwatch, Timer — no Alarm entry |
| `src/header-bar.vala` + `data/ui/header-bar.ui` | `lib/header_bar.rb` | header bar widget | present |
| (no backing `.vala`) `data/ui/shortcuts-dialog.ui` | `lib/shortcuts_dialog.rb` | keyboard shortcuts window (standalone `.ui`, no source class) | present |
| `src/clock.vala` | `lib/clock.rb` | `PanelId`/`ButtonMode` enums, `Clock` duck-type contract | present (`PanelId::ALARM` is modeled but nothing uses it — see Alarm panel below) |
| `src/utils.vala` | `lib/utils.rb` | time/duration formatting, `WallClock` wrapper | present |
| `src/widgets.vala` | `lib/widgets.rb` | shared widget helpers (`ContentStore`, etc.) | present |
| `src/twilight.c` | `lib/twilight.rb` | sunrise/sunset calculation | present |
| `data/org.gnome.clocks.gschema.xml.in` | `lib/settings.rb` | GSettings schema (`world-clocks`, `alarms`, `timers`, `geolocation`, window state, panel-id) | present (schema modeled; `alarms` key is carried as dead data — nothing reads/writes it) |
| `src/cutils.c` | — | ICU-backed duration/week-start C helpers used by the alarm day-picker and duration formatting | **MISSING** — no `lib/cutils.rb` or equivalent; `lib/utils.rb` and `lib/alarm_day_picker_row.rb` have their own formatting instead, not checked against this file's output |
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
| `src/geocoding.vala` | `lib/geo_info.rb` | reverse-geocodes the device's current location (via `geocode-glib`/GeoClue2) to offer as a world clock | **present (new since last inventory)** — `GeoInfo` is `require_relative`d and called from `lib/world_face.rb` (`GeoInfo.new.seek`), and itself `require`s `geocode-glib` and `libgweather` |
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

## Alarm panel — model layer ported, UI/widgets still missing

Since the last inventory, a model layer has landed: `lib/sound.rb`,
`lib/alarm_sound_model.rb`, `lib/alarm_item.rb` and
`lib/alarm_day_picker_row.rb` all exist, are `require_relative`d from
`lib/main.rb`, and carry correct "ported from `src/<file>.vala`" header
comments. **None of them is reachable from the window yet** — `lib/window.rb`'s
`PANELS` constant still lists only World, Stopwatch and Timer, so there is no
alarm panel page, no alarm list, and no path by which `AlarmItem` or
`AlarmDayPickerRow` is ever instantiated by the running app. The rest of the
upstream Alarm surface — the panel page, the list row, the setup dialog, the
ringing page, and the sound-chooser UI — has no `lib/*.rb` file at all:

| Upstream file | Should become | Kind | Present? |
|---|---|---|---|
| `src/alarm-face.vala` + `data/ui/alarm-face.ui` | `lib/alarm_face.rb` | panel page (alarm list, empty state, add button) | **MISSING** |
| `src/alarm-item.vala` | `lib/alarm_item.rb` | alarm model (time, days, label, snooze/dismiss state) | present (model only; unreachable — see above) |
| `src/alarm-row.vala` + `data/ui/alarm-row.ui` | `lib/alarm_row.rb` | alarm list row (on/off switch, days summary) | **MISSING** |
| `src/alarm-setup-dialog.vala` + `data/ui/alarm-setup-dialog.ui` | `lib/alarm_setup_dialog.rb` | add/edit alarm dialog | **MISSING** |
| `src/alarm-day-picker-row.vala` + `data/ui/alarm-day-picker-row.ui` | `lib/alarm_day_picker_row.rb` | day-of-week picker row inside the setup dialog | present (widget exists; unreachable — nothing builds it, since there is no setup dialog) |
| `src/alarm-ringing-panel.vala` + `data/ui/alarm-ringing-panel.ui` | `lib/alarm_ringing_panel.rb` | full-screen ringing/snooze/dismiss page shown when an alarm fires | **MISSING** |
| `src/alarm-sound-model.vala` | `lib/alarm_sound_model.rb` | `Gio::ListModel` of available alarm sounds | present (model only; unreachable — nothing builds a sound chooser against it) |
| `src/sound-chooser.vala` + `data/ui/sound-chooser.ui` | `lib/sound_chooser.rb` | sound-picker dialog/popover for an alarm's ringtone | **MISSING** |
| `src/sound-chooser-row.vala` + `data/ui/sound-chooser-row.ui` | `lib/sound_chooser_row.rb` | one sound choice row (name + preview-play button) | **MISSING** |
| `src/sound.vala` | `lib/sound.rb` | alarm sound playback (GStreamer-backed) | present (model only; unreachable — nothing plays a sound, since nothing rings) |

Consequences visible elsewhere in the tree because of this gap:

- `data/org.gnome.clocks.gschema.xml.in`'s `alarms` key and the
  `org.gnome.clocks.panelid` enum's `alarm` value are modeled in
  `lib/settings.rb`/`lib/clock.rb` (`PanelId::ALARM` exists, `'alarms' => []`
  exists) but nothing ever reads or writes through them — dead schema surface,
  same as the last inventory.
- `src/application.vala`'s `stop-alarm` and `snooze-alarm` actions (fired by
  notification buttons) and its `add-location` action's GWeather-variant
  deserialization are explicitly listed as not implemented in `lib/main.rb`'s
  own header comment.
- `src/search-provider.vala` — the GNOME Shell search provider that surfaces
  world clocks and (critically) lets Shell's search bar show/stop/snooze a
  ringing alarm — has no `lib/search_provider.rb` and is not mentioned
  anywhere in `lib/`. **MISSING.**

## Binding-gem wiring status (checked, not part of the component count)

The gemspec (`gnome-clocks-rb.gemspec`) declares `gtk4`, `adwaita`, `glib2`,
`libgweather`, `geocode-glib` and `gnome_desktop` as runtime dependencies.
`ashpd`, which the previous inventory found declared-but-unused, has since
been dropped from the gemspec — correctly, since nothing in `lib/` needs it
yet (no background-activation/portal feature exists). Current status of the
three gems this task calls out as mandatory:

- `GnomeDesktop` — `require`d and used in `lib/utils.rb` (`GnomeDesktop::WallClock`). Wired and live.
- `GeocodeGlib` — `require`d and used in `lib/geo_info.rb`, called from `lib/world_face.rb`'s `GeoInfo.new.seek`. Wired and live (the commit history shows a driving test proving this path: `1adaaf0 Prove geocode-glib is reached from WorldFace's live path, not just directly`).
- `GWeather` — `require`d in `lib/geo_info.rb` and `lib/world_location_dialog.rb`/`lib/world_item.rb`. Wired and live.

No regression found: every gem above is `require`d somewhere under `lib/`,
and the gemspec declares nothing beyond `gtk4`/`adwaita`/`glib2` plus those
three. This item needed no repair.

## Totals

- Upstream user-facing component files (`.vala`/`.c` with a widget, dialog,
  panel, or service role, paired with their `.ui` where one exists): 34
  (excluding `config.vapi`, `meson.build`).
- Already present and reachable in `lib/` on `ruby`: 27 files/components
  (Window, header bar, shortcuts dialog, World/Stopwatch/Timer panels end to
  end including geocoding, clock/utils/widgets/twilight/settings/main
  scaffolding).
- Present but unreachable (model layer exists, nothing in the widget tree
  builds or shows it): 4 — `AlarmItem`, `AlarmDayPickerRow`,
  `AlarmSoundModel`, `Sound`.
- Missing outright: 6 — the Alarm panel's visible widgets (alarm face, alarm
  row, alarm setup dialog, alarm ringing panel: 4 files), the sound-chooser
  UI (sound chooser, sound chooser row: 2 files).
- Missing, non-panel: `src/world-shell-world-clocks.vala` (Shell D-Bus
  export), `src/search-provider.vala` (Shell search provider), `src/cutils.c`
  (ICU helpers, not confirmed used) — 3 files.
- Total still missing or unreachable: 13, same count as the previous
  inventory's 13 "missing files," though the composition has shifted: 4 of
  the alarm model files that were previously counted as missing files now
  exist as unreachable code instead, which is forward progress but not yet a
  working Alarm panel a user can reach.
