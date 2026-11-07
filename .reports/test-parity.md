# Test parity — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `e85d7e5` |
| Upstream tests | 0 (censused — see below) |
| Ported | 0 |
| Gaps (test-count) | 0 |
| Port's own suite | **does not run** |
| Test command (per dev-shell banner) | `xvfb-run ruby test/drive_*.rb` and an inline `rspec`/`spec` invocation |

## Step 1 — Census upstream

```sh
scripts/test-census.sh /tmp/up-clocks   # (worktree of origin/master @ 99afdd1)
```

0 rows. Confirmed by hand: no `tests/` or `test/` directory, no
`g_test_add_func`/`Test.add_func`, no `meson.build` test target anywhere in
upstream `gnome-clocks`. GNOME Clocks genuinely ships no test suite.

Per the skill's "When upstream has no tests" section: **this is not a license
to skip the rest of the skill.** The parity count is 0/0 and is met
trivially — but the port inherits no safety net, and that is a separate,
harder claim that this round's runtime gate speaks to directly.

## Step 2 — Does the port have its own suite, and does it run?

The repo ships `spec/` (RSpec) with exactly two files: `spec/README.md` and
`spec/spec_helper.rb`. **There is not one `*_spec.rb` file in the entire
tree.** `grep -rl` for `describe\|RSpec.describe\|it ['"]` over `spec/`
returns nothing, because there is nothing to match.

The dev shell banner additionally advertises a driver:

```
drive the app: xvfb-run ruby test/drive_*.rb
```

**`test/` does not exist.** Confirmed:

```
$ nix develop --command xvfb-run -a ruby test/drive_main.rb
.../ruby: No such file or directory -- test/drive_main.rb (LoadError)
```

Running the RSpec invocation the banner also advertises:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit \
    RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
...
LoadError: cannot load such file -- kettle/test/rspec
  # ./spec/spec_helper.rb:23
No examples found.
Finished in 0.00009 seconds
0 examples, 0 failures, 2 errors occurred outside of examples
```

`spec_helper.rb` itself fails to load — `kettle/test/rspec` is not resolvable
in the dev shell's bundle — so even an empty spec run cannot complete
cleanly; it errors twice before reporting 0 examples.

This matches, exactly, the runtime gate stated for this round: **drive_ok =
false, 0 checks passed, 0 failed, 0 components covered.** That is not a
flaky or partial run. There is no test code to run, and the one harness that
exists cannot load.

## Step 3 — What this means for the 11 "ported" units

Per the task's framing and the `component-parity` skill: **a component no
check exercises is unverified, not done.** Concretely, that includes:

- The World panel landed in `e85d7e5` with zero accompanying tests or driver
  checks.
- `lib/timer_setup.rb`'s quick-start buttons were found broken
  (`component-parity.md`) by a 30-second manual launch — exactly the kind of
  regression a driver script exists to catch on every change, and exactly
  the kind that ships silently when no driver exists.
- Every other "ported" unit (window, header bar, shortcuts dialog, stopwatch,
  timer) has the same status: present in source, never exercised.

## Extra

None. There is no test code in the port at all to list under `## Extra`.

## Verdict

Test parity on the *count* is 0/0 and trivially met, because upstream ships
no tests. But the port is not merely "untested relative to upstream" — it is
**untested, full stop**, and the one test command the project's own dev shell
documents fails to execute. The standing `.reports/component-inventory.md`
and `PORTING.md`-style documents have at no point recorded this as a gap in
its own right; it should be the single loudest finding in this round, because
every other document's "exists: yes" claims rest on nothing but a visual
read of the source.
