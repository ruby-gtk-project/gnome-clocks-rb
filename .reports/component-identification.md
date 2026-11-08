# Component identification — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `5c61e85` |

This supersedes the `e85d7e5`-era copy of this file. Two commits landed
since that copy was written — `6c9e947` (alarm model layer) and `834969c`
(Alarm panel widgets: face, row, setup dialog, sound chooser) — plus
`5c61e85` (a copyright-string fix). The Alarm panel is now built; this
round's job is to re-check what that changed and what it didn't.

## File-level unit map (upstream file(s) → port file)

| Upstream | Port | Ported? |
|---|---|---|
| `src/main.vala`, `src/application.vala` | `lib/main.rb` | yes (documented partial — see below) |
| `src/window.vala` + `window.ui` | `lib/window.rb` | yes |
| `src/header-bar.vala` + `header-bar.ui` | `lib/header_bar.rb` | yes |
| `data/ui/shortcuts-dialog.ui` (no `.vala`) | `lib/shortcuts_dialog.rb` | yes |
| `src/clock.vala` | `lib/clock.rb` | yes |
| `src/widgets.vala` | `lib/widgets.rb` | yes |
| `src/utils.vala`, `src/cutils.c` | `lib/utils.rb` | yes |
| `src/twilight.c` | `lib/twilight.rb` | yes |
| `src/geocoding.vala` | `lib/geo_info.rb` | yes (landed since last round) |
| `src/stopwatch-face.vala` + `.ui` | `lib/stopwatch_face.rb` | yes |
| `src/stopwatch-lap.vala` | `lib/stopwatch_lap.rb` | yes |
| `src/stopwatch-laps-row.vala` + `.ui` | `lib/stopwatch_laps_row.rb` | yes |
| `src/timer-face.vala` + `.ui` | `lib/timer_face.rb` | yes |
| `src/timer-item.vala` | `lib/timer_item.rb` | yes |
| `src/timer-row.vala` + `.ui` | `lib/timer_row.rb` | yes |
| `src/timer-setup.vala` + `.ui` | `lib/timer_setup.rb` | yes |
| `src/timer-setup-dialog.vala` + `.ui` | `lib/timer_setup_dialog.rb` | yes |
| `src/world-face.vala` + `.ui` | `lib/world_face.rb` | yes |
| `src/world-item.vala` | `lib/world_item.rb` | yes |
| `src/world-row.vala` + `.ui` | `lib/world_row.rb` | yes |
| `src/world-standalone.vala` + `.ui` | `lib/world_standalone.rb` | yes |
| `src/world-location-dialog.vala` + `.ui` | `lib/world_location_dialog.rb` | yes |
| `src/world-location-dialog-row.vala` + `.ui` | `lib/world_location_dialog_row.rb` | yes |
| `src/alarm-item.vala` | `lib/alarm_item.rb` | yes (landed since last round) |
| `src/alarm-sound-model.vala` | `lib/alarm_sound_model.rb` | yes (landed since last round) |
| `src/alarm-day-picker-row.vala` + `.ui` | `lib/alarm_day_picker_row.rb` | yes (landed since last round) |
| `src/sound.vala` | `lib/sound.rb` | yes (landed since last round) |
| `src/alarm-face.vala` + `.ui` | `lib/alarm_face.rb` | yes (landed this round, `834969c`) |
| `src/alarm-row.vala` + `.ui` | `lib/alarm_row.rb` | yes (landed this round) |
| `src/alarm-setup-dialog.vala` + `.ui` | `lib/alarm_setup_dialog.rb` | yes (landed this round) |
| `src/sound-chooser.vala` + `.ui` | `lib/sound_chooser.rb` | yes (landed this round) |
| `src/sound-chooser-row.vala` + `.ui` | `lib/sound_chooser_row.rb` | yes (landed this round) |
| `src/alarm-ringing-panel.vala` + `.ui` | — | **no port file** (see Finding 1) |
| `src/search-provider.vala` | — | **no port file** |
| `src/world-shell-world-clocks.vala` | — | **no port file** |

**23 of 26 upstream user-facing/support units now have a port file (up
from 14 at the last round); the Alarm panel's widgets are no longer the
headline gap.** Three units remain entirely unported.

## Finding 1 — `alarm-ringing-panel.vala` is the one widget-level unit still missing

Confirmed by `grep -rn "RingingPanel\|AlarmRingingPanel" lib/` — zero hits.
Upstream's `src/window.vala` pushes a dedicated `Adw.NavigationPage`
(`alarm_subpage`, hosting `Alarm.RingingPanel`) over the window's
navigation stack the moment any alarm starts ringing
(`alarm.ring.connect { alarm_ringing_panel.alarm = a; navigation_view.push
(alarm_subpage) }`, `src/window.vala:110-117`), and makes the window
**not closable** while that page is showing (`deletable =
(navigation_view.visible_page != alarm_subpage)`, `src/window.vala:307`).
This is a real window/page in the GNOME HIG sense the task asks about, not
an implementation detail — it is the one screen a user sees when an alarm
actually goes off.

`lib/window.rb` has no equivalent push, no `alarm_subpage`, and no
`deletable` toggle. The port's substitute, entirely in `lib/alarm_face.rb`
(`#ring`), is a `Gio::Notification` with Stop/Snooze action buttons. This
substitution is **documented in the port's own comments** (`alarm_face.rb`
lines ~25-27, ~249-251) — it is not hidden — but it is still a missing page
per this skill's rule: the port has no in-app ringing screen at all, and the
window can still be closed (or switched to another panel) while an alarm is
ringing, which upstream explicitly prevents.

The alarm's own bell sound does still play when it rings — that part is at
the model layer (`AlarmItem#tick` → `bell.ring`, `lib/alarm_item.rb:246`)
and is independent of the missing panel — so this is specifically a missing
**visual page**, not a silent alarm.

## Finding 2 — two D-Bus support units remain unported, consistent with last round

`src/search-provider.vala` (GNOME Shell search provider) and
`src/world-shell-world-clocks.vala` (Shell's world-clocks applet export)
have no port file. `lib/main.rb`'s own header comment names this
explicitly: "`dbus_register` exports a search provider and the Shell's
world clocks on the session bus... which arrive with the World panel they
serve" — listed as not-here, not hidden. Unchanged since last round.

## Rule check

Every "no port file" row was confirmed by `grep -rln` for the class name and
by `ls lib/ | grep -i <name>` turning up nothing, per the skill's Step 4.
