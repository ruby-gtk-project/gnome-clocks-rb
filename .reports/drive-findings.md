# gnome-clocks-rb — driving the port, findings

`test/drive_clocks.rb` (with `test/gtk_driver.rb`, copied from the
`ruby-gtk-testing` skill) builds the real window, works through every
component this port's window actually hosts — World, Stopwatch and Timer
panels, the shortcuts and About dialogs, the Add World Clock dialog, the New
Timer dialog — fires each one's controls and the window's navigation
actions, hits the empty/populated and running/paused/reset states, and
screenshots each one. It also plain-checks the alarm model layer
(`AlarmItem`, `AlarmSoundModel`, `AlarmDayPickerRow`, `Sound`) on its own,
since nothing in the window wires it up yet (see `component-inventory.md` —
the Alarm panel itself is unported, so there is no widget to drive those
classes through).

Run: `nix develop --command xvfb-run -a ruby test/drive_clocks.rb`.
Current result: **74 of 74 checks passed, DRIVE OK**, three runs in a row.

## Port bugs this run found and fixed

All four were invisible to `ruby -c` and to a `require` that never opens a
window — exactly the class of bug driving the app exists to catch.

1. **`Window#needs_attention` called a method that does not exist.**
   `stack.page(panel(panel_id))` — `Adwaita::ViewStack` has no `page`; the
   real accessor is `get_page`. Every needs-attention dot (Stopwatch running,
   Timer counting down) raised `NoMethodError` the first time either panel
   changed state, which is the very first `start`/`activate` on either panel.
   Fixed in `lib/window.rb`.

2. **Every quick-start button's action parameter had the wrong GVariant
   type**, so GTK refused to activate it at all (a `Gtk-WARNING`:
   `actionhelper: action timer-setup.start-timer can't be activated due to
   parameter type mismatch (parameter type i, target type x)`).
   `GLib::Variant.new(minutes)` boxes a plain Integer as `x` (int64) by
   default; the action itself declares `i` (int32). Fixed in
   `lib/timer_setup.rb` by passing `GLib::VariantType.new('i')` explicitly.
   Once that mismatch was fixed, the action's handler itself broke next (see
   below) — the mismatch had been silently hiding it.

3. **The quick-start action's handler called `.value` on an already-unboxed
   parameter.** The Ruby binding hands a simple-typed (`i`) action parameter
   back as a plain Ruby `Integer`, not a `GLib::Variant` the way upstream's
   Vala sees it; calling `.value` on it raised `NoMethodError`. Every
   quick-start button was consequently dead on arrival once bug 2 above
   stopped masking it. Fixed in `lib/timer_setup.rb`.

4. **The window's narrow breakpoint asserted on load.** `add_setter(header_bar,
   'title-widget', nil)` tried to box a `nil` target into a GObject property
   setter, and `header_bar` (this port's own `HeaderBar` class) has no real
   GObject `title-widget` property to box into in the first place — only the
   plain Ruby accessor. Every window build logged
   `Adwaita-CRITICAL **: adw_breakpoint_add_setter: assertion 'G_IS_VALUE
   (value)' failed`, and the breakpoint's header-bar half never actually
   applied. Fixed in `lib/window.rb` by doing the swap on the breakpoint's own
   `apply`/`unapply` signals instead, the same way `WorldStandalone`'s own
   breakpoint already works around the identical gap (see that file's class
   comment) — this is the second panel to need it, not a one-off.

5. **Panels never received the window's own `Settings` instance.**
   `Window#panel` built each panel with `klass.new` and no `settings:`
   keyword, so `WorldFace` and `TimerFace` each constructed their own
   default `Settings`, separate from `@settings` on the `Window` itself (and
   from each other). `Settings#[]=` rewrites the *entire* JSON file from its
   own in-memory `@values` on every write, so the World panel's and Timer
   panel's separate `Settings` objects were set up to silently stomp on each
   other's keys (`world-clocks` vs. `timers`) the moment both had written at
   least once — adding a world clock after starting a timer would have
   erased the timer, and vice versa. This was caught by a drive check reading
   `app.window.settings.world_clocks` straight after adding a clock through
   the panel and finding it still empty (the window's own `Settings` copy had
   never been told). Fixed in `lib/window.rb`: `Window#panel` now hands its
   own `@settings` to any panel class whose `initialize` accepts one.

## A binding gap, worked around rather than left broken

**`GWeather::Location#next_child` is not safe to call repeatedly across a
Ruby garbage collection.** Driving the Add World Clock dialog's search
(`WorldLocationDialog#search_changed`, which recursively walks
`GWeather::Location.world` with `next_child`) crashed the process outright
with a segfault (`[BUG] Segmentation fault`) on one run, and on another run
produced a bogus `NoMethodError` — `next_child` called on what had become an
`Array` instead of a `GWeather::Location` — for the exact same code and the
exact same search term. Both reproduce only once enough other widgets exist
in the process to put real memory pressure on the GC (building the window
alone and searching immediately does not reproduce it; building the window,
opening and closing the shortcuts and About dialogs first and *then*
searching reproduces it reliably). Running the identical search wrapped in
`GC.disable` / `GC.enable` reproduces cleanly across every run attempted (6
in a row, after 2 crashes and 1 corrupted run without the guard).

This is consistent with `next_child` handing back a borrowed
(transfer-none) child whose lifetime the binding does not otherwise pin for
the duration between one `next_child` call and the next — a GC that runs
mid-walk can collect the Ruby wrapper for a node the walk is still about to
call `next_child` on again, which frees memory `libgweather` itself still
owns. The next read through it is a stale read into freed memory, which is
exactly as likely to come back as a wrong Ruby class as to crash the
process outright.

Per this skill's own guidance (and the precedent of Chess-Clock-rb's
`add_breakpoint` / Junction-rb's Breakpoint setter both hitting a real
`GIArgument` binding gap), this is not something to paper over with a
looser check — it is now worked around explicitly: `lib/world_location_dialog.rb`'s
`walk_locations` holds GC off for the walk's short duration (at most
`RESULT_COUNT_LIMIT` = 12 nodes), which changes no observable behaviour and
only keeps every node the walk touches alive for as long as the walk needs
it to be. The comment on `walk_locations` carries this same explanation for
the next person who hits it. If the underlying `libgweather`/`gobject-introspection`
binding fixes `next_child`'s lifetime handling, this guard becomes
unnecessary but still harmless.

## Not exercised

- The Alarm panel itself (`alarm-face`, `alarm-row`, `alarm-setup-dialog`,
  `alarm-ringing-panel`, the sound chooser) — there is no widget to drive;
  see `component-inventory.md`. The model layer underneath it
  (`AlarmItem`, `AlarmSoundModel`, `AlarmDayPickerRow`, `Sound`) is
  plain-checked directly in `test/drive_clocks.rb` instead.
- `spec/` has no example files (only `spec_helper.rb` and `README.md`), and
  the dev shell's own spec command fails outright in this environment —
  `cannot load such file -- kettle/test/rspec` — because the `kettle-test`
  gem `spec_helper.rb` requires is not part of this flake's gem set. That is
  a pre-existing gap in the scaffolding, not something this round of driving
  introduced or could exercise; there is nothing under `spec/` yet for it to
  run regardless.
