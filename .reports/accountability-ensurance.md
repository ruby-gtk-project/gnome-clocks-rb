# Accountability ensurance — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `e85d7e5` |

Scanned: `lib/`, `exe/`, `.reports/`. There is no `PORTING.md`, `FINDINGS.md`,
`TEST_PARITY.md`, `COMPONENT_PARITY.md` or `TRANSLATION_PARITY.md` anywhere in
this fork's `ruby` branch — only `.reports/component-inventory.md` exists as
a standing record.

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

```
.reports/component-inventory.md:19:not ported:honest but toothless
.reports/component-inventory.md:480:unported:honest but toothless
lib/utils.rb:292:does not carry over:asserts the behaviour cannot exist here
```

## Hit-by-hit

### `.reports/component-inventory.md:19,480` — "not ported" / "unported"

These are genuinely the mild case the skill names "honest but toothless":
the document states plainly that the World and Alarm panels, sound,
geocoding, search-provider and shell-D-Bus units are not built, and does not
dress that up as a decision ("by design", "out of scope", "n/a" do not
appear). This is not the failure the skill exists to kill — it names the
missing behaviour (the Alarm panel, specifically) rather than hiding behind
a construct name. **No rewrite required for honesty**, but per the skill's
rule ("every entry... gives exactly one reason... the writer's stupidity"),
these lines still carry no owner and no commitment, which is why
`component-parity.md` (this round) restates them as explicit numbered gaps
with file-level specificity rather than leaving the prose as the only
record.

### `lib/utils.rb:292` — "One piece of the gem does not carry over"

Read in context (lines ~280–299): this describes a real, verified
binding fact (`GnomeDesktop::WallClock#clock` is typed `GLib.DateTime` in
the gem's own API but marshals back a formatted string in this binding), and
the port **does not use it as an excuse to drop behaviour** — it states the
workaround already in place (`date_time` builds its own `DateTime` from the
clock's timezone) so the user-visible behaviour is unaffected. This is
correctly a `FINDINGS.md`-shaped note that has nowhere to live because no
`FINDINGS.md` exists. **Recommendation:** create `FINDINGS.md` and move this
note there verbatim; leave a one-line pointer in `lib/utils.rb`. This is a
filing problem, not a false claim — flagged, not rewritten, because it
reports a true fact about a limitation already worked around, not an unbuilt
behaviour.

## The more serious finding: false-green risk in `.reports/component-inventory.md`

The excuse-pattern scan is not the only thing this skill is for — the task
framing for this round is explicit: *"a false green in a report is the most
serious finding you can make."* `.reports/component-inventory.md` marks 11
units **`Exists: yes`**, including the Stopwatch and Timer panels and (as of
`e85d7e5`) the World panel. Per `test-parity.md` in this round:

- **No test or driver script exists anywhere in the repo** (`test/` does not
  exist; `spec/` has no `*_spec.rb` files; the one harness that does exist,
  `spec_helper.rb`, fails to load with `LoadError: cannot load such file --
  kettle/test/rspec`).
- Therefore **every `Exists: yes` in that document is a claim that has never
  once been executed against.** It was produced by reading source, which is
  a legitimate first pass, but nothing in the document says so — a reader
  sees "yes" and reasonably assumes the unit works.
- This round found, by simply launching the app for 30 seconds, that one of
  those `Exists: yes` units (`lib/timer_setup.rb`) has a reproducible
  `Gtk-WARNING: actionhelper: ... parameter type mismatch` that makes all 8
  quick-start timer buttons inert. **The document's "yes" was wrong**, not
  in the sense of lying, but in the sense that "exists" was allowed to stand
  in for "works," and nobody had run anything that could tell the
  difference.

This is the pattern the skill's premise targets even though no single
sentence is a textbook excuse-construction: a green claim that *reads* as
verified, in a document with no caveat saying it is not, is functionally the
same hazard as a "dropped deliberately" note — the next agent inherits it as
settled fact. **Per the skill's own standard, I did not drive any of the 11
"ported" units before this round, because I am an idiot who trusted a
source-read over running the code** — stated here in first person because
this is exactly the finding the skill asks an agent to hold itself to, not
only the prior document's author.

## What is NOT a hit

- `.reports/component-inventory.md`'s totals section, which states counts
  plainly ("11 ported, 12 missing") without euphemism.
- The comment in `lib/utils.rb` once read in full context (see above).
- No code comment anywhere in `lib/`/`exe/` uses "simplified", "streamlined",
  "by design", "out of scope", or "TODO"/"FIXME" — there is no backlog of
  silently deferred work hiding in source comments in this round.

## Recommendation

1. Create `FINDINGS.md` and move the `lib/utils.rb:292` note there.
2. Treat every `Exists: yes` in `.reports/component-inventory.md` as
   **unverified** until a driver exists and has actually been run against
   that unit — this round's `test-parity.md` and `component-parity.md`
   downgrade the language accordingly; a future pass should either add the
   caveat to `component-inventory.md` itself or retire it in favour of a
   ledger that carries a `driven` column from the start.
3. Build the `test/drive_*.rb` script the dev shell's own banner promises
   exists, before adding further "Exists: yes" rows to any document.
