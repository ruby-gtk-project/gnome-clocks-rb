# Component parity — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `e85d7e5` |
| Units with parity | 11 / 23 user-facing units (same count the standing inventory reports; 0 of the 9 Alarm units have been started) |

This is an adversarial pass against `.reports/component-inventory.md`
(already in the repo) and `.reports/component-identification.md` (this
round). It does not repeat every row of those documents; it states the
verdict per axis and flags every place the standing inventory understates
the gap.

## Axis 1 — Count (widgets)

- **World panel (6 units):** ported in `e85d7e5`. Not independently re-verified
  widget-by-widget in this pass beyond the file-existence check in
  `component-identification.md` — that re-verification is itself owed before
  this unit can be marked `parity` rather than merely `exists`. Treat World as
  **unverified**, not **parity**, until Steps 4–5 of the `component-parity`
  skill (stylesheet diff + driven signals) are actually run against it. No
  driver exists to run them with (see `test-parity.md`), so they have not
  been run.
- **Alarm panel (9 units) — count is 0 vs upstream's dozens of widget rows**
  (`Adw.Dialog`, `Adw.NavigationView`, 7×`Gtk.ToggleButton` day picker,
  `Adw.ComboRow`×2, `Adw.Banner`, `Adw.ButtonRow`, etc.). Every row in the
  standing inventory's "Alarms panel" section is `**Exists: no.**`. This pass
  confirms it: no `alarm_*` or `sound_*` file exists anywhere in `lib/`.
- **Support units — 0 of 3** (`geocoding.rb`, shell world-clocks D-Bus export,
  search provider). `world_location_dialog.rb` exists but its search box has
  no backing geocoding lookup to search against — confirm before counting the
  World panel's search as functional (see Behaviour below).

## Axis 2 — Style

Not evaluated for Alarm (nothing to evaluate). For the ported units, this
pass did not re-diff `data/css/gnome-clocks.css` against the port's
stylesheet source — that diff is still owed. Flagging as **not confirmed**
rather than asserting it passes.

## Axis 3 — Behaviour

Running the port under Xvfb (`nix develop --command xvfb-run -a ruby
exe/gnome-clocks`) surfaces a live defect in a *ported* unit, not a missing
one:

```
Gtk-WARNING: actionhelper: action timer-setup.start-timer can't be
activated due to parameter type mismatch (parameter type i, target type x)
```

Fired once per quick-start button (8 times) on window open. Upstream's
`timer-setup.vala` installs `start-timer` with an `i32` (`i`) parameter and
targets the 8 quick-start durations with `i32` variants
(`data/ui/timer-setup.ui`'s `action-target`); the port's
`lib/timer_setup.rb` installs or targets the action with an `x` (`i64`)
parameter instead, so **every quick-start timer button is non-functional** —
clicking "1 m"/"2 m"/etc. silently does nothing because GTK refuses to
activate a mismatched action. This is a **component-parity gap in a unit the
standing inventory marks `Exists: yes`** — existence is not behaviour.

No further behaviour axis checking was done for the ported units because no
driver exists (see `test-parity.md`) — "driven: ✓" cannot be claimed for a
single row in this port.

## Axis 4 — Text

Zero. See `translation-parity.md`. No widget in the port, ported or not,
carries a translation marker, so every Text cell in a `COMPONENT_PARITY.md`something
-style ledger for this app would read `✗`. This is a parity failure for all
11 built units simultaneously, not a separate concern — `component-parity`
names it as one of the four required axes, and it fails app-wide.

## What the standing inventory undercounts

`.reports/component-inventory.md`'s "Totals" section (last line) says
"11 ported, 12 missing" for user-facing units and treats that as the
headline. Reading it as the whole picture misses:

1. The 11 "ported" units have **never been driven** (no test/ directory, no
   `test/drive_*.rb` — the dev shell banner names a script that does not
   exist). "Ported" here means "a `.rb` file exists that looks right," not
   "verified against upstream."
2. At least one of those 11 (`timer_setup.rb`) has a reproducible functional
   bug found by simply launching the app for 30 seconds.
3. The CSS-axis diff (Step 4 of the skill) has not been run on any unit.
4. The text axis is 0/0 ported across the board (not noted in the standing
   inventory at all).

## Verdict

**No unit in this port currently has component parity** under the skill's
definition — "a unit has parity when every row says `parity`, the stylesheet
and messages lines are clean, and the driven line has no ✗." Every unit here
either doesn't exist (Alarm, 9 units + 3 support files) or hasn't had Steps
4–5 run, and the one unit this pass did drive (Timer setup) failed on first
contact.

## Gaps (ranked)

1. **Alarm panel entirely unported** — 9 units, 0 built. The app ships with
   no way to set an alarm at all.
2. **No translation markers anywhere in `lib/` or `exe/`** — every built
   unit fails the text axis.
3. **`timer-setup.start-timer` action parameter type mismatch** — all 8
   quick-start timer buttons are dead on arrival.
4. **No CSS diff performed** — style axis unverified for all 11 built units.
5. **`geocoding.rb`, shell D-Bus world-clocks export, `search-provider.rb`**
   unported — "automatic location," the GNOME Shell clock applet integration,
   and the Shell search provider do not exist.
6. **World panel's `e85d7e5` commit has not been driven** — "exists" only.
