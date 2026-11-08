# Test parity — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `5c61e85` |
| Upstream tests | 0 (upstream ships no test suite at all — unchanged) |
| Port's own suite | `test/drive_clocks.rb` + `test/gtk_driver.rb` — **runs, and passes** |
| This round's result | `90 of 90 checks passed, DRIVE OK` (reproduced live) |
| `spec/` (RSpec) | Still has zero `*_spec.rb` files; still fails to load |

This supersedes the `e85d7e5`-era copy, which reported `drive_ok=false, 0/0,
0 components` because `test/` did not exist yet. `e4ab805` ("Add a driving
test harness and fix the bugs it found") built it since. This is real,
substantial progress — but "the suite runs and passes" is not the same
claim as "the suite covers the app," and that gap is this report's job.

## Step 1 — Upstream census (unchanged)

Confirmed again: no `tests/`/`test/` directory, no `g_test_add_func`, no
meson test target anywhere in `origin/master`. 0/0 upstream tests, met
trivially.

## Step 2 — Does the port's suite run?

Yes, reproduced directly this round:

```
$ nix develop --command xvfb-run -a ruby test/drive_clocks.rb
...
90 of 90 checks passed
DRIVE OK
```

This is a genuine, executed, passing run — not a claim read off source. The
dev shell's advertised `xvfb-run ruby test/drive_*.rb` command now matches
reality.

`spec/` is unchanged from the last round: still only `README.md` and
`spec_helper.rb`, still zero `*_spec.rb` files, and the dev shell's own
RSpec invocation still fails identically:

```
LoadError: cannot load such file -- kettle/test/rspec
  # ./spec/spec_helper.rb:23
0 examples, 0 failures, 2 errors occurred outside of examples
```

Not re-run in full this round since nothing in `spec/` changed since the
last round's reproduction; the finding stands unchanged.

## Step 3 — What the 90 checks actually cover

Read `test/drive_clocks.rb` section by section against the panels it talks
to (`grep -n '\[[0-9]\+\]' test/drive_clocks.rb` for the numbered steps the
run output prints, cross-checked against the panel/dialog each step
touches):

| Component | Covered? | What's checked |
|---|---|---|
| World panel (add/search/empty/standalone) | yes | add-location dialog open, search, select, add, empty state before/after |
| Stopwatch panel | yes | start, lap, pause (Escape), reset (Escape), needs-attention dot |
| Timer panel | yes | quick-start buttons, pause, reset, delete, New Timer dialog, Escape-pauses-all |
| Alarm panel (list CRUD) | yes | add via setup dialog, toggle active switch, delete, empty state |
| Window chrome | yes | navigate-forward/backward across all 4 panels, shortcuts dialog, close-request hides not destroys |
| Shortcuts dialog | yes | opens, is a dialog |
| About dialog | implied by drive-findings.md, not re-verified this round | — |
| **Alarm *ringing*** | **no** | **zero steps advance an alarm to `RINGING`, call `AlarmFace#ring`, activate `app.stop-alarm`/`app.snooze-alarm`, or inspect a `Gio::Notification`** |
| Alarm snooze | **no** | `AlarmItem#snooze` is referenced nowhere in `test/drive_clocks.rb` outside the two model-check lines already present at the last round |
| Sound chooser | **no** | no step opens `SoundChooser` or exercises bell preview playback |

This is the runtime gate's own "7 components" — I count the same 7 the gate
reports (World, Stopwatch, Timer, Alarm-list, window/navigation, shortcuts,
and close-request-as-its-own-behavior). **The count is accurate. The
coverage is narrower than "the Alarm panel is tested" would suggest**: the
Alarm panel's CRUD is a component; the Alarm panel's actual alarm — ringing,
snoozing, stopping, the sound chooser — is a different component, and it
has no check.

## Step 4 — Per the task's framing

*"Treat a failed or narrow drive run as a parity gap in its own right — a
component no check exercises is unverified, not done."* Applying that
literally: the ringing path, the snooze path, and the sound chooser are
each a component no check exercises. They are not "done" by this round's
gate passing, regardless of the fact that the gate itself is honest about
what it covers (it never claims to cover ringing).

## Verdict

**Real progress since the last round**: a driver now exists, runs, and
passes 90/90, closing the `drive_ok=false` finding entirely for the 7
components it covers. **The suite's blind spot is exactly where the
previous round's `component-parity.md` found the remaining widget gap**:
ringing. This is not a coincidence worth treating as resolved by proximity
— the Alarm Ringing panel has neither a port file nor a check, and those
are the same missing feature seen from two reports.

`spec/`'s RSpec harness remains broken and uncounted by the gate, unchanged
from the last round.
