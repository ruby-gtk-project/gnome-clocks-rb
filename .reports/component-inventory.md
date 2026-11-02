# gnome-clocks — upstream component inventory

Survey of the upstream GNOME Clocks implementation against the `ruby` branch of
this fork, for the full-parity port. Upstream is read from the `origin/master`
ref in this repo (there is **no** `origin/main`; the upstream default branch is
`master` — `origin/HEAD` points at `origin/ruby`, the port).

Upstream shape: 34 `.vala` files in `src/` (~5 500 lines), 21 GtkBuilder `.ui`
files in `data/ui/` (~2 080 lines), one stylesheet (`data/css/gnome-clocks.css`,
25 app CSS classes), one GSettings schema file with 4 schemas, one GResource
manifest, and 83 languages in `po/` (plus 25 in `help/`).

Port shape on `ruby` today: `lib/gnome_clocks.rb`,
`lib/gnome_clocks/application.rb` (a scaffold: `Adwaita::ApplicationWindow` +
`Adwaita::ToolbarView` + `Adwaita::HeaderBar` + an `Adwaita::StatusPage` reading
"The Ruby port has not been written yet."), and `lib/gnome/clocks/rb/version.rb`.
**No user-facing component is ported yet.** Target paths follow the pilot port
(`gnome-contacts-rb`): flat `lib/<snake_case>.rb`, one file per upstream unit,
with `lib/main.rb` as the app/launcher class.

Upstream splits most components across a `.vala` class and its `.ui` template;
the two halves union into one port file.

---

## src/main.vala + src/application.vala (+ data/ui/header-bar.ui menu) → `lib/main.rb` — the application: actions, accelerators, notifications

| Widget | × | CSS | Signals / behaviour | Notes |
|---|---:|---|---|---|
| `Adw.Application` (`Gtk::Application` in the port — `Adwaita::Application` is broken in the bindings) | 1 | — | `activate`, `startup`, `shutdown`, `dbus_register`/`dbus_unregister`, `handle_local_options` | app id `org.gnome.clocks`, resource base `/org/gnome/clocks/`, default icon name |

Actions installed on `app.`: `stop-alarm` (param `s`), `snooze-alarm` (param
`s`), `quit`, `add-location` (param `v`), plus `app.shortcuts` (referenced by
the menu and the shortcuts dialog). Accelerators set in `startup`:
`win.new`→`<Control>n`, `win.help`→`F1`, `window.close`→`<Control>w`,
`app.quit`→`<Control>q`, `win.navigate-backward`→`<Control><Alt>Page_Up`,
`win.navigate-forward`→`<Control><Alt>Page_Down`. CLI option `--version`/`-v`.
Tracks sent `GLib.Notification` ids and withdraws them when the window becomes
active or on shutdown. **Exists: no.**

## src/window.vala + data/ui/window.ui → `lib/window.rb` — the main window: four panels, two subpages

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only when `PROFILE == "Devel"`) | `notify::is-active` → `on_window_active`, `close_request` → saves window state | title swaps between "Clocks", "Alarm" and the standalone clock's title |
| `Adw.Breakpoint` | 1 | — | — | `max-width` breakpoint; reveals `switcher_bar`, hides the header's switcher |
| `Gtk.EventControllerKey` (controller) | 1 | — | `key-pressed` → `key_press_cb` | Escape pops the navigation view or delegates `escape_pressed` to the panel |
| `Adw.ToastOverlay` | 1 | — | — | `add_toast` entry point used by the alarm face |
| `Adw.NavigationView` | 1 | — | `notify::visible-page` → `visible_page_changed` | |
| `Adw.NavigationPage` | 3 | — | `hidden` on `world_subpage` | `main_page` "Clocks", `world_subpage` "Clock", `alarm_subpage` "Alarm Ringing" |
| `Adw.ToolbarView` | 1 | — | — | top bar = header bar, bottom bar = switcher bar |
| `Adw.ViewStack` | 1 | — | `notify::visible-child` → `pane_changed` | pages `world`/`alarm`/`stopwatch`/`timer`, titles `_World`, `Ala_rms`, `_Stopwatch`, `_Timer`, icons `globe-symbolic`, `alarm-symbolic`, `stopwatch-symbolic`, `timer-symbolic`; `needs_attention` set from stopwatch state and timer `is-running` |
| `Adw.ViewSwitcherBar` | 1 | — | — | revealed at the narrow breakpoint |
| `Adw.AboutDialog` | 1 | — | — | built in `on_about_activate`: name "Clocks", developer "The GNOME Project", GPL-2.0, 15 developers, issue URL, translator credits |

Actions on `win.`: `new`, `help`, `navigate-forward`, `navigate-backward`,
`about`, plus the widget action `set-page` (param `s`) bound to `<Alt>1..4`.
Persists `maximized`, `size`, `panel-id` to `org.gnome.clocks.state.window`.
**Exists: no.**

## src/header-bar.vala + data/ui/header-bar.ui → `lib/header_bar.rb` — the header bar and primary menu

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.ViewSwitcher` | 1 | — | — | `wide` policy, bound to the window's stack |
| `Adw.ViewStack` | 1 | — | — | `start_button_stack`, swaps between the "new" button and an empty bin per `button-mode` |
| `Gtk.Button` | 1 | — | `action-name` `win.new` | icon `list-add-symbolic`, tooltip bound to the panel's `new-label` |
| `Adw.Bin` | 1 | — | — | the "no start button" page |
| `Gtk.MenuButton` | 1 | — | — | icon `open-menu-symbolic`, tooltip "Main Menu", menu model `primary-menu` |
| `GMenu` `primary-menu` | 1 | — | — | 3 items: `app.shortcuts` ("Keyboard Shortcuts"), `win.help` ("Help"), `win.about` ("About Clocks") |

Properties `button-mode` (NORMAL/SELECTION-ish enum) and `new-label`, bound per
visible panel by the window. **Exists: no.**

## data/ui/shortcuts-dialog.ui → `lib/shortcuts_dialog.rb` — keyboard shortcuts dialog

Standalone `.ui` with no backing source file.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ShortcutsDialog` | 1 | — | — | opened by `app.shortcuts` |
| `Adw.ShortcutsSection` | 5 | — | — | General, World Clocks, Alarm, Stopwatch, Timer |
| `Adw.ShortcutsItem` | 15 | — | — | Show Help (`win.help`), Open Menu, Keyboard Shortcuts (`app.shortcuts`), Quit (`app.quit`), Next/Previous Section (`win.navigate-forward`/`-backward`), Go to the World/Alarms/Stopwatch/Timer Section (`<Alt>1..4`), Add a World Clock (`win.new`), Add an Alarm (`win.new`), Pause All, Reset, New Timer (`win.new`) |

**Exists: no.**

## src/clock.vala → `lib/clock.rb` — the panel interface and panel id enum

Not a widget: `Clocks.PanelId` (`WORLD`, `ALARM`, `STOPWATCH`, `TIMER`) and the
`Clock` interface (`panel_id`, `button_mode`, `new_label`, `activate_new`,
`escape_pressed`) that all four faces implement and the window drives.
**Exists: no.**

## src/widgets.vala → `lib/widgets.rb` — ContentStore and the AM/PM toggle

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Button` subclass `AmPmToggleButton` | 1 | `clocks-ampm-toggle-button` | `clicked` → flips `choice` | hosts a `Gtk.Stack` with two `Gtk.Label`s (localised `%p` for 00:00 and 12:00) |
| `Gtk.Stack` | 1 | — | — | inside the toggle |
| `Gtk.Label` | 2 | — | — | AM and PM |

Also `ContentItem` (interface) and `ContentStore` (a `GLib.ListModel` over
`GListStore` with add/remove/foreach/find/serialize/deserialize) — the model
every face's list is built on. **Exists: no.**

## src/utils.vala → `lib/utils.rb` — WallClock, time formatting, weekday helpers

Not a widget. The ticking `Utils.WallClock` singleton (`seconds_precision`,
`tick`, system timezone changes), `load_css`, 12/24h detection, time/date
formatting, "Current timezone" / "%s hour(s) ahead|behind" strings, the
`Utils.Weekdays` bitfield with its 7 single-letter symbols (`Alarm|Repeat-On|…`
msgctxt), plural day names, and the "Every Day" / "Weekdays" / "Weekends"
summaries. Every face depends on it. **Exists: no.**

---

## World panel

## src/world-face.vala + data/ui/world-face.ui → `lib/world_face.rb` — the World panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | implements `Clock`, `new-label` = "Add Location" |
| `Adw.ViewStack` | 1 | — | — | swaps `empty_view` / `list_view` on item count |
| `Adw.StatusPage` | 1 | — | — | icon `globe-centered-symbolic`, title/description for the empty world list |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `action-name` `win.new` | "_Add World Clock…" |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` → `item_activated` | bound to a `Gtk.SortListModel` + `Gtk.CustomSorter` over the world clocks store |
| `ClocksWorldRow` | *n* (repeater) | — | — | one per configured location; `show-standalone` signal pushes the subpage |

Persists to the `world-clocks` GSettings key; `add_location` is also reached
from `app.add-location` and the shell search provider. **Exists: no.**

## src/world-item.vala → `lib/world_item.rb` — one world clock (model)

Not a widget: `GWeather.Location` wrapper with name/state/country/city text,
local time, day label ("Today"/"Tomorrow"/"Yesterday"/weekday), day/night state
(drives the `day`/`night` CSS on the standalone view), sunrise/sunset via
`twilight.c`, serialize/deserialize. **Exists: no.**

## src/world-row.vala + data/ui/world-row.ui → `lib/world_row.rb` — one row in the world list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` (template root) | 1 | `clock` | — | title/subtitle bound through a `GBindingGroup` |
| `Gtk.Label` | 1 | `clock-time`, `numeric` | — | the location's time, ticked by `WallClock` |
| `Gtk.Button` | 1 | `circular`, `flat` | `clicked` → `delete` | tooltip "Delete", icon `edit-delete-symbolic` |

**Exists: no.**

## src/world-standalone.vala + data/ui/world-standalone.ui → `lib/world_standalone.rb` — the single-clock subpage

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.BreakpointBin` (template root) | 1 | — | — | |
| `Adw.Breakpoint` | 1 | — | — | switches `time_label` ↔ `time_label_small` |
| `Adw.ToolbarView` + `Adw.HeaderBar` + `Adw.WindowTitle` | 1 each | — | — | title/subtitle bound to the item |
| `Gtk.Stack` | 1 | — | — | large/small time |
| `Gtk.Label` | 8 | `clocks-standalone-label`, `clocks-standalone-label-small`, `clocks-secondary-standalone-label`, `numeric`, `dimmed` | — | time ×2, day label, "Sunrise"/"Sunset" captions, sunrise/sunset values, a spacing dummy |
| `Gtk.Grid` | 2 | `clocks-secondary-standalone-label` | — | |

Dynamic CSS on the page: `day` / `night` (and the `civil`/`naut`/`none`
twilight classes from the stylesheet). `WallClock` is switched to
seconds precision while this page is visible. **Exists: no.**

## src/world-location-dialog.vala + data/ui/world-location-dialog.ui → `lib/world_location_dialog.rb` — "Add World Clock" dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template root) | 1 | — | — | title "Add World Clock" |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | |
| `Gtk.Button` | 2 | `suggested-action` (2nd) | `window.close`; `clicked` → `add_button_clicked` | "_Cancel", "_Add" |
| `Gtk.SearchBar` | 1 | — | `notify::search-mode-enabled` → `on_search_mode_notify` | |
| `Gtk.SearchEntry` | 1 | — | `search-changed` → `on_search_changed` | placeholder "Search cities" |
| `Gtk.Stack` | 1 | — | — | empty search / no results / results |
| `Adw.StatusPage` | 2 | — | — | "Perform a Search" + "The search results will appear here"; "No Results Found" + "Try a different search" — both `edit-find-symbolic` |
| `Adw.PreferencesPage` + `Adw.PreferencesGroup` | 1 each | — | — | |
| `Gtk.ListBox` | 1 | `boxed-list` | `row-activated` → `item_activated` | |
| `ClocksWorldLocationDialogRow` | *n* (repeater) | — | — | one per GWeather search hit |

**Exists: no.**

## src/world-location-dialog-row.vala + data/ui/world-location-dialog-row.ui → `lib/world_location_dialog_row.rb` — one search result row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | — | — | properties `clock-name`, `clock-location`, `clock-description`, `selected` |
| `Gtk.Box` | 3 | — | — | |
| `Gtk.Label` | 3 | `title`; `heading`; `dimmed`+`caption` | — | bound to the three properties |
| `Gtk.Image` | 1 | — | — | `object-select-symbolic`, visible only when selected |

**Exists: no.**

## src/geocoding.vala → `lib/geocoding.rb` — geolocation lookup

Not a widget: GeoClue2-backed "automatic location" support gated on the
`geolocation` GSettings key, used to seed the world list. **Exists: no.**

## src/world-shell-world-clocks.vala → `lib/world_shell_world_clocks.rb` — D-Bus world clocks for the shell

Not a widget: exports the configured world clocks on the app's object path for
the GNOME Shell clock drop-down. **Exists: no.**

## src/search-provider.vala → `lib/search_provider.rb` — shell search provider

Not a widget: `org.gnome.Shell.SearchProvider2` implementation (matches cities,
returns result metadata, activates the window on the World panel). Ships
`data/org.gnome.clocks.search-provider.ini.in`. **Exists: no.**

---

## Alarms panel

## src/alarm-face.vala + data/ui/alarm-face.ui → `lib/alarm_face.rb` — the Alarms panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | implements `Clock`, `new-label` = "New Alarm", `ring` signal |
| `Gtk.Stack` | 1 | — | — | `empty_view` / `list_view` on item count |
| `Adw.StatusPage` | 1 | — | — | icon `alarm-centered-symbolic` |
| `Gtk.Button` | 1 | `suggested-action`, `pill` | `action-name` `win.new` | "Add A_larm…" |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 each | — | — | |
| `Gtk.ListBox` | 1 | `boxed-list` | — | `Gtk.SortListModel` + `Gtk.CustomSorter` over the alarms store |
| `ClocksAlarmRow` | *n* (repeater) | — | — | one per alarm |
| `Adw.Toast` | 1 | — | — | "Alarm set for %s from now" after an alarm is added/edited, pushed into the window's toast overlay |

Handles `app.stop-alarm` / `app.snooze-alarm` activation for the ringing alarm;
persists the `alarms` GSettings key. **Exists: no.**

## src/alarm-item.vala → `lib/alarm_item.rb` — one alarm (model) and its notification

Not a widget: alarm time, name, repeat weekdays, ring/snooze durations, chosen
sound, snooze/stop state machine, and the `GLib.Notification` "Alarm" (body =
name, HIGH priority, buttons "Stop" → `app.stop-alarm::<id>` and "Snooze" →
`app.snooze-alarm::<id>`). **Exists: no.**

## src/alarm-row.vala + data/ui/alarm-row.ui → `lib/alarm_row.rb` — one alarm row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | — | activatable → opens the setup dialog | `GBindingGroup` `alarm_binds` |
| `Gtk.Box` | 3 | — | — | |
| `Gtk.Revealer` | 2 | — | — | title revealer, repeats revealer (reveal only when set) |
| `Gtk.Label` | 3 | `heading`; `alarm-time`+`numeric`; `dimmed`+`caption` | — | name, time, repeats (tooltip "Repeats") |
| `Gtk.Switch` | 1 | — | `notify::active` → enables/disables the alarm | tooltip "Enable Alarm" |
| `Gtk.Button` | 1 | `circular`, `flat` | `clicked` → `delete` | tooltip "Delete", icon `edit-delete-symbolic` |

**Exists: no.**

## src/alarm-setup-dialog.vala + data/ui/alarm-setup-dialog.ui → `lib/alarm_setup_dialog.rb` — new/edit alarm dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template root) | 1 | — | — | title "New Alarm" / "Edit Alarm" |
| `Adw.NavigationView` + `Adw.NavigationPage` | 1 each | — | — | second page is the sound chooser |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | |
| `Gtk.Button` | 2 | `suggested-action` (2nd) | `clicked` → `cancel`; `clicked` → `add` | "_Cancel", "_Add"/"_Done" |
| `Adw.Banner` | 1 | — | — | "You already have an alarm for this time" |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 3 | — | — | time, details, delete |
| `Gtk.Box` | 1 | `clocks-alarm-setup-time` | — | |
| `Gtk.SpinButton` | 2 | — | `value-changed` → `spinbuttons_changed`, `output` → `show_leading_zeros` | Hours, Minutes (+2 `Gtk.Adjustment`) |
| `Gtk.Label` | 2 | — | — | "∶" separator, sound name label |
| `Adw.Bin` | 1 | — | — | `am_pm_bin`, holds the `AmPmToggleButton` in 12h locales (conditional) |
| `ClocksAlarmDayPickerRow` | 1 | — | `days_changed` → `days_changed` | |
| `Adw.EntryRow` | 1 | — | `changed` → `entry_changed` | title "Name" |
| `Adw.ActionRow` | 1 | — | `action-name` `navigation.push` | "Alarm Sound" + value label + `go-next-symbolic` |
| `Adw.ComboRow` | 2 | — | — | "Ring Duration", "Snooze Duration" (`Gtk.CClosureExpression` for the display) |
| `Adw.ButtonRow` | 1 | `destructive-action` | `activated` → `delete` | "R_emove Alarm" — group hidden when creating |
| `ClocksSoundChooser` | 1 | — | — | pushed page, title "Alarm Sound" |

**Exists: no.**

## src/alarm-day-picker-row.vala + data/ui/alarm-day-picker-row.ui → `lib/alarm_day_picker_row.rb` — the weekday repeat picker

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesRow` (template root) | 1 | — | `days_changed` signal | non-activatable, non-focusable, labelled-by relation |
| `Gtk.Box` | 2 | — | — | |
| `Gtk.Label` | 1 | — | — | "Repeat", mnemonic |
| `Gtk.ToggleButton` | 7 (repeater) | — | per-button action `repeats.day-0..6` | built in a loop from the localised weekday symbols; a private `SimpleActionGroup` named `repeats` installs 7 stateful actions |

**Exists: no.**

## src/alarm-ringing-panel.vala + data/ui/alarm-ringing-panel.ui → `lib/alarm_ringing_panel.rb` — the alarm-ringing subpage

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | `dismiss` signal | pushed as `alarm_subpage`; window becomes non-deletable while shown |
| `Gtk.WindowHandle` | 1 | — | — | |
| `Gtk.Grid` | 2 | — | — | layout + `button_grid` (re-flows at narrow widths) |
| `Gtk.Button` | 2 | `pill`+`large-button`+`destructive-action`; `pill`+`large-button` | `action-name` set in code to `app.stop-alarm` / `app.snooze-alarm` with the alarm id | "_Stop", "S_nooze" (snooze hidden when the alarm has no snooze) |
| `Gtk.Label` | 2 | `numeric`+`clocks-ringing-label`; `clocks-ringing-title` | — | ringing time, alarm name |

**Exists: no.**

## src/sound-chooser.vala + data/ui/sound-chooser.ui → `lib/sound_chooser.rb` — the alarm-sound chooser page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` (template root) | 1 | — | — | title "Alarm Sound" |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | `silent_group`, `sound_group` |
| `ClocksSoundChooserRow` | 1 + *n* (repeater) | — | `activated` → `row_activated` | the "Silent" row (icon `bell-outline-none-symbolic`) plus one per bundled alarm sound from the sound model |
| `Gtk.Image` | 1 | — | — | the bell icon on the silent row |

Selecting a row previews the sound through GSound; the chosen sound is written
back to the alarm. **Exists: no.**

## src/sound-chooser-row.vala + data/ui/sound-chooser-row.ui → `lib/sound_chooser_row.rb` — one sound row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` (template root) | 1 | — | `activated` | |
| `Gtk.Image` | 2 | — | — | `media-playback-pause-symbolic` while previewing, `object-select-symbolic` when chosen |

**Exists: no.**

## src/alarm-sound-model.vala → `lib/alarm_sound_model.rb` — the list model of bundled sounds

Not a widget: a `GLib.ListModel` of `ClocksSound`s discovered from the 22
bundled `data/sounds/alarms/*.flac` files plus `silent`, with their translated
display names. **Exists: no.**

## src/sound.vala → `lib/sound.rb` — one sound, and playback

Not a widget: a sound's uri/display name and the GSound-based play/stop used by
the chooser, the ringing alarm and the finished timer (`sounds/complete.oga`).
**Exists: no.**

---

## Stopwatch panel

## src/stopwatch-face.vala + data/ui/stopwatch-face.ui → `lib/stopwatch_face.rb` — the Stopwatch panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template root) | 1 | `stopwatch-panel` | — | implements `Clock`; `state` property (RESET/RUNNING/PAUSED) drives the window's `needs_attention` |
| `Adw.ToolbarView` | 1 | — | — | |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Gtk.Box` | 3 | — | — | container, time container, button box |
| `Gtk.Label` | 8 | `numeric`; `hours-label`+`dimmed`; `minutes-label`+`dimmed`; `seconds-label`; `milliseconds-label`; plus dynamic `running-stopwatch` / `paused-stopwatch` / `stopped-stopwatch` | — | HH ∶ MM ∶ SS . ms, hours/minutes dimmed until non-zero |
| `Gtk.Revealer` | 1 | — | — | reveals the lap list once a lap exists |
| `Adw.Clamp` | 2 | — | — | laps list, button row |
| `Gtk.ListBox` | 1 | `boxed-list` | — | laps |
| `ClocksStopwatchLapsRow` | *n* (repeater) | — | — | one per lap, newest first |
| `Gtk.Button` | 2 | `large-button`+`pill`+`suggested-action`; `large-button`+`pill` | `clicked` → `on_start_btn_clicked`; `clicked` → `on_clear_btn_clicked` | labels cycle "St_art"/"_Pause"/"R_esume" and "_Clear"/"_Lap" |

Escape resets; the panel has no `win.new` button (`button-mode` hides it).
**Exists: no.**

## src/stopwatch-lap.vala → `lib/stopwatch_lap.rb` — one lap (model)

Not a widget: index, total duration, difference from the previous lap.
**Exists: no.**

## src/stopwatch-laps-row.vala + data/ui/stopwatch-laps-row.ui → `lib/stopwatch_laps_row.rb` — one lap row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | `lap-row` | — | |
| `Gtk.Box` | 1 | — | — | |
| `Gtk.Label` | 3 | `lap-time`+`numeric`; `numeric`; `dimmed` | — | duration (tooltip "Time"), difference (tooltip "Difference"), lap index |

**Exists: no.**

## Timer panel

## src/timer-face.vala + data/ui/timer-face.ui → `lib/timer_face.rb` — the Timer panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | `timer-panel` | `ring` signal | implements `Clock`, `new-label` = "New Timer", `is-running` drives `needs_attention` |
| `Adw.ViewStack` | 1 | — | — | pages `empty` (the setup) and `timers` (the list) |
| `Gtk.ScrolledWindow` | 2 | — | — | |
| `Adw.Bin` | 1 | — | — | `timer_bin`, hosts `ClocksTimerSetup` |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → starts the configured timer | "St_art" |
| `Adw.Clamp` | 1 | — | — | |
| `Gtk.ListBox` | 1 | `boxed-list` | — | `Gtk.SortListModel` + `Gtk.CustomSorter` over the timers store |
| `ClocksTimerRow` | *n* (repeater) | — | — | one per timer |

Sends the `GLib.Notification` "Time is up!" / "Timer countdown finished"
(HIGH priority) when unfocused, plays `complete.oga`, persists the `timers`
GSettings key. **Exists: no.**

## src/timer-item.vala → `lib/timer_item.rb` — one timer (model)

Not a widget: duration, name, running/paused/finished state, remaining time
ticking, serialize/deserialize. **Exists: no.**

## src/timer-row.vala + data/ui/timer-row.ui → `lib/timer_row.rb` — one timer row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | — | — | `Adw.TimedAnimation` + `Adw.CallbackAnimationTarget` pulse the row while paused |
| `Gtk.Box` | 1 | — | — | |
| `Gtk.Label` | 2 | `numeric`+`timer-countdown`; `dimmed` | — | countdown "00 ∶ 00 ∶ 00", timer name |
| `Gtk.Revealer` | 1 | — | — | reveals the name area |
| `Gtk.Stack` | 4 | — | — | name (entry ↔ label), start ↔ pause, reset ↔ bin, delete ↔ bin |
| `Gtk.Entry` | 1 | — | — | placeholder "Title…" |
| `Gtk.Grid` | 1 | — | — | button area |
| `Gtk.Button` | 4 | `circular`+`large-button`; `suggested-action`+`circular`+`large-button`; `circular`; `circular` | `clicked` → `on_pause_button_clicked`, `on_start_button_clicked`, `on_reset_button_clicked`, delete | Pause, Start, Reset, Delete with `media-playback-pause-symbolic`, `media-playback-start-symbolic`, `view-refresh-symbolic`, `user-trash-symbolic` |
| `Adw.Bin` | 3 | — | — | the empty pages of the three button stacks |

**Exists: no.**

## src/timer-setup.vala + data/ui/timer-setup.ui → `lib/timer_setup.rb` — the timer setup pane

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template root) | 1 | — | — | `duration` property; private `SimpleActionGroup` `timer-setup` with the `start-timer` action (variant param) |
| `Adw.Clamp` | 2 | — | — | |
| `Gtk.Box` | 2 | — | — | |
| `Gtk.Label` | 10 | `title-4` ×2, `clocks-timer-label` ×2 on the "∶" separators | — | "Quick Start", "Set Timer", the 8 quick-start captions ("1 m"… "1 h"), separators |
| `Adw.WrapBox` | 1 | — | — | holds the quick-start buttons |
| `Gtk.Button` | 8 | — | `action-name` `timer-setup.start-timer` with a duration target | 1 m, 2 m, 3 m, 5 m, 15 m, 30 m, 45 m, 1 h, each with an accessible label ("One minute"…) |
| `Gtk.Grid` | 1 | — | — | `time_grid` |
| `Gtk.SpinButton` | 3 | `clocks-spinbutton` | `changed` → `update_duration`, `output` → `show_leading_zeros`, `input` → `input_minutes` / `input_seconds` | Hours, Minutes, Seconds (+3 `Gtk.Adjustment`, 1 `Gtk.SizeGroup`) |
| `Gtk.Entry` | 1 | — | — | placeholder "Title" |

**Exists: no.**

## src/timer-setup-dialog.vala + data/ui/timer-setup-dialog.ui → `lib/timer_setup_dialog.rb` — "New Timer" dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template root) | 1 | — | — | title "New Timer" |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Gtk.Box` | 1 | — | — | `timer_box`, hosts a second `ClocksTimerSetup` |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → `create_clicked` | "Start" |

**Exists: no.**

---

## Non-widget upstream files with no port file of their own

| Upstream | Why |
|---|---|
| `src/cutils.c`, `src/twilight.c` | C helpers (sunrise/sunset maths, misc utils) — fold into `lib/utils.rb` / `lib/world_item.rb` |
| `src/config.vapi`, `src/meson.build`, `meson.build`, `data/meson.build` | build plumbing; the port uses the fork's Gemfile/flake |
| `data/gnome-clocks.gresource.xml` | resource manifest — in the port, icons/sounds/CSS are loaded from disk |
| `data/css/gnome-clocks.css` | 25 app CSS classes; the port needs a `Gtk::CssProvider` loading an equivalent stylesheet (owned by `lib/utils.rb`) |
| `data/org.gnome.clocks.gschema.xml.in` | 4 schemas / 7 keys (`world-clocks`, `alarms`, `timers`, `geolocation`, `maximized`, `size`, `panel-id`) → a `lib/settings.rb` in the port, as in the pilot |
| `data/org.gnome.clocks.desktop.in.in`, `.metainfo.xml.in.in`, `.service.in`, `.search-provider.ini.in` | packaging metadata |
| `po/` (83 languages, 39 POTFILES entries), `help/` (12 pages, 25 languages) | translation and user-help catalogues; parity work for the translation-parity step |

---

## Totals

- 24 user-facing component units (windows, dialogs, pages, rows, menus, shortcuts, empty/ringing states), 0 ported.
- 10 non-widget support units (models, stores, settings, utils, sound, geocoding, D-Bus providers), 0 ported.
- 25 app CSS classes, 0 defined in the port.
- 11 `app.`/`win.` actions plus 2 scoped action groups (`repeats.day-0..6`, `timer-setup.start-timer`) and 1 widget action (`win.set-page`), 0 installed in the port.
- 6 accelerators + 4 `<Alt>N` bindings, 0 installed in the port.
