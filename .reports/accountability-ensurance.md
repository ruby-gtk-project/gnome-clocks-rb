# Accountability ensurance — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `5c61e85` |

Scanned: `lib/`, `exe/`, `.reports/`. There is no `PORTING.md` anywhere on
`ruby` — confirmed again this round (`find . -iname 'PORTING.md'` → no
output).

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

```
.reports/component-parity.md:102,110  "unported" (x2)
.reports/drive-findings.md:12          "unported"
.reports/component-identification.md:94 "unported"
.reports/component-inventory.md:39,40  "N/A" / "out of scope"
.reports/accountability-ensurance.md:... (the prior round's own report, now superseded)
lib/utils.rb:292                       "does not carry over"
```

## Hit-by-hit

### `lib/utils.rb:292` — unchanged from last round

Still the same, still legitimate: a real, verified binding fact
(`GnomeDesktop::WallClock#clock` is typed `GLib.DateTime` upstream but
marshals back a formatted string in this binding) stated with the
workaround already in place, not used to drop behaviour. Last round's
recommendation (move it into a `FINDINGS.md`) has not been acted on — there
is still no `FINDINGS.md` in the repo — but the note itself is not a false
claim. Repeating the recommendation rather than re-litigating the finding.

### `.reports/component-inventory.md:39-40`, `.reports/component-parity.md:102,110`, `.reports/component-identification.md:94`, `.reports/drive-findings.md:12` — "unported" / "N/A" / "out of scope"

All in `.reports/`, all the mild, named-and-owed case the skill calls
"honest but toothless" — each names a specific missing unit
(search-provider, Shell world-clocks export, the Alarm Ringing panel in
this round's own fresh reports) rather than hiding behind the construct
name. Per the skill's own rule these still carry no owner and no
commitment as prose, but this round's `component-parity.md` and
`component-identification.md` restate them as explicit ranked gaps with
file-level citations, which is the mitigation the skill asks for in place
of a rewrite.

## The more serious finding this round: does "90/90, 7 components" get oversold anywhere?

This round's runtime gate (`drive_ok=true, 90/90, 7 components`) is real —
reproduced live in `test-parity.md`. The question this skill exists to ask
is whether that true number gets stretched into a false claim anywhere in
this round's own output. Checked every one of this round's four other
`.reports/*.md` files for language that could read as "the Alarm panel is
done" or "ringing works":

- `component-parity.md` states explicitly: *"the Alarm panel's CRUD is
  done and driven; its central behaviour (ringing) has neither a widget
  nor a check."* This names the limit of the green rather than letting
  "23/26 units have a port file" stand alone.
- `test-parity.md` states explicitly that the gate's "7 components" does
  not include ringing, snoozing, or the sound chooser, and spells out the
  `grep` that proves it (2 hits, both model-layer, not panel-layer).
- `component-identification.md` names the one missing widget
  (`alarm-ringing-panel`) by file and by upstream line number
  (`src/window.vala:110-117`, `:307`) rather than folding it into a vaguer
  "Alarm panel: mostly done."

None of this round's four other reports claims ringing works, is tested,
or is out of scope. **This is the check this skill exists to make, and this
round passes it** — the true number (90/90) is reported alongside its
actual reach, not instead of it.

## What would have been a false green, and was avoided

Had any report simply written "Alarm panel: ported (`834969c`)" without
separately checking whether the ringing page and the ringing behaviour were
part of that commit, it would have repeated exactly the failure mode the
prior round caught in `.reports/component-inventory.md` (marking units
`Exists: yes` before anything drove them). This round deliberately checked
`lib/window.rb` for a navigation push and `test/drive_clocks.rb` for a
`RINGING`-reaching step, independently of reading `alarm_face.rb`'s own
header comment (which is itself honest about the notification substitution)
— the header comment being honest does not, on its own, tell a reader
whether the thing it describes is also complete, which is why both axes
were checked separately rather than taking the comment's word for the
whole picture.

## What is NOT a hit

- No code comment anywhere in `lib/`/`exe/` uses "simplified",
  "streamlined", "by design", "TODO", "FIXME", "not implemented", "for
  now", or "in a future" — unchanged from last round, now re-confirmed
  against all 33 files in `lib/` (up from 27).
- `lib/main.rb`'s header comment, which names three real omissions
  (Adw.Application substitution, the D-Bus search-provider/Shell export,
  the GWeather-variant add-location path) by upstream file reference, with
  no euphemism — same pattern as `lib/geo_info.rb`'s header, both read in
  full this round and both judged not to be excuses: they state a fact
  about what is missing and why, in first-person-adjacent engineering
  language, not a decision dressed up as made.

## One more staleness risk: `.reports/component-inventory.md` itself

That document (last written at `3f15dda`, before `834969c`'s Alarm-panel
widgets) still says, as of this repo state, "Missing outright: 6 — the
Alarm panel's visible widgets (alarm face, alarm row, alarm setup dialog,
alarm ringing panel...), the sound-chooser UI." Four of those six now
exist (`834969c`); only the ringing panel is still actually missing from
that list of six. This is not a false green — if anything it is a false
*red*, understating this round's progress — but it is the same underlying
hazard the skill is built to catch from the other direction: a document
that reads as current and is not, and nothing on its face says so. It is
superseded by this round's `component-identification.md` and
`component-parity.md`; it should either be refreshed or marked superseded
in its own text rather than left to be read at face value by the next
agent.

## Recommendation

1. Still no `FINDINGS.md` — the `lib/utils.rb:292` note has nowhere
   dedicated to live, two rounds running. Create it.
2. Build a `test/drive_clocks.rb` step that fires an alarm to `RINGING`
   (advance its `ring_time` into the past and call `#tick`, as the model
   checks already do, but through `AlarmFace#ring` so the notification
   path is actually exercised) before the Alarm panel is described as
   "working" in any future report, including this fork's own README or
   release notes if any are written.
3. Either build `lib/alarm_ringing_panel.rb` or, if the notification
   substitution is accepted as the port's permanent design, say so
   explicitly in a `PORTING.md`/`FINDINGS.md` rather than leaving the
   decision implicit in `alarm_face.rb`'s header comment alone — a header
   comment on the *replacement* is not the same as a recorded decision
   about the *thing being replaced*.
