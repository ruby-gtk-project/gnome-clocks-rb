# Component parity — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `5c61e85` |
| Units with a port file | 23 / 26 (up from 14 at the last round) |
| Units with verified behaviour parity | Unverified for most — see Axis 3 |

Adversarial pass against `.reports/component-identification.md` (this
round) and the runtime gate (`drive_ok=true, 90/90, 7 components`). The
Alarm panel's widgets landed since the last round (`834969c`); this report
asks whether that closes the gap the last round found, or just moves it.

## Axis 1 — Count

- **23/26 units have a port file.** The 3 missing: `alarm-ringing-panel`
  (a real page, not a stub — see `component-identification.md` Finding 1),
  `search-provider`, `world-shell-world-clocks` (both D-Bus services, both
  documented as out-of-gem-scope in `lib/main.rb`'s header comment).
- Within the Alarm panel specifically: face, row, setup dialog (with its
  day-picker row), sound chooser (with its row), the sound/alarm-sound-model
  layer, and the item model are all present. The **ringing panel is the one
  Alarm-panel widget still absent**, and it is the one the user sees most
  urgently — when the alarm they set actually goes off.

## Axis 2 — Style

Not evaluated this round either. `data/css/gnome-clocks.css` has not been
diffed against the port's `Utils.load_css` stylesheet string
(`lib/utils.rb`). Flagging as **not confirmed**, not as passing, consistent
with the last round's finding that this axis has never actually been run.

## Axis 3 — Behaviour

The runtime gate for this round (`drive_ok=true, 90/90, 7 components`) is
real — I re-ran it (`nix develop --command xvfb-run -a ruby
test/drive_clocks.rb`) and reproduced 90/90, `DRIVE OK`. But the gate's
reach needs checking against what it actually exercises, not just its pass
count:

- **It covers World, Stopwatch, Timer, and the Alarm list's CRUD (add,
  toggle active, delete) plus window navigation/shortcuts/close-request** —
  7 components, matching the gate.
- **It never fires an alarm to its ringing state.** `grep -n "ring\b" test/
  drive_clocks.rb` turns up exactly 2 hits, both on the model
  (`AlarmItem#ring_time`/`#active?`) — never `AlarmItem#tick` driven to
  `RINGING`, never `AlarmFace#ring`, never `app.stop-alarm` or
  `app.snooze-alarm` activated, never a `Gio::Notification` inspected.
  **The single most important behaviour an alarm clock has — what happens
  when the alarm goes off — is completely outside this round's 90 checks.**
  This is exactly the task's own standard: *"a component no check
  exercises is unverified, not done."* The Alarm panel's CRUD is driven;
  its ringing path is not.
- The previously-found `timer-setup.start-timer` GVariant-type bug
  (component-parity, prior round) is now fixed and is covered live by the
  drive script's quick-start-button checks (`[49]`/`[50]` in this run's
  output) — a real regression the last round's audit caught has since been
  fixed and is now guarded by a check. Noting this so it is not re-flagged
  as still-broken.

## Axis 4 — Text

Unchanged and still 0/217 — see `translation-parity.md`. This now applies
to the Alarm panel's new strings too (every label in `alarm_face.rb`,
`alarm_row.rb`, `alarm_setup_dialog.rb`, `sound_chooser.rb`,
`sound_chooser_row.rb`, `alarm_day_picker_row.rb` is a bare Ruby literal with
no translation marker — confirmed by the same `grep -rn 'gettext\|N_(\|n_(\|
_("' lib/` that found nothing anywhere in `lib/`).

## Documented, non-hidden design substitutions (not re-litigated as fresh findings)

These are stated plainly in the port's own comments with upstream file:line
references, which is what the `accountability-ensurance` skill asks for —
listed here for completeness, not as new findings:

- `Adw.Application` → `Gtk::Application` (`lib/main.rb` header).
- `dbus_register`'s search provider / Shell world-clocks export: not built
  (`lib/main.rb` header; same gap as Finding 2 in `component-identification.md`).
- `add-location`'s GWeather-variant deserialization (DBus activation path):
  not built (`lib/main.rb` header).
- GeoClue2 fetched via a plain `Gio::DBusConnection` call instead of a
  GObject-Introspection binding, since none exists (`lib/geo_info.rb` header).

## Verdict

**Count parity improved sharply this round (14→23 of 26 units) and the
previously-found `timer-setup` bug is fixed and now guarded.** But the one
remaining missing widget — the Alarm Ringing panel — is not a minor one:
it is the page upstream shows instead of letting the user navigate away or
close the window while an alarm rings, and the port has no page there at
all, only a notification. Combined with the fact that no check in this
round's gate exercises the ringing path either way, "the Alarm panel is
done" is not a safe claim yet — the panel's CRUD is done and driven; its
central behaviour (ringing) has neither a widget nor a check.

## Gaps (ranked)

1. **`alarm-ringing-panel` has no port file.** Alarms ring (the model and
   bell layer work), but the port shows no in-app page for it and does not
   block the window from closing while one rings, unlike upstream.
2. **No check anywhere drives an alarm to ringing.** The gate's "7
   components, 90/90" does not include this path; it is unverified, not
   passing.
3. **Text axis is 0/217, now including every new Alarm-panel string.**
4. **CSS/style axis has never been diffed**, for any of the 23 built units.
5. **`search-provider.rb` and the Shell world-clocks D-Bus export remain
   unported** — documented, unchanged from last round.
