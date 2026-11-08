# Translation parity — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `5c61e85` |
| Upstream messages (census) | 217 distinct (msgctxt, msgid) rows, `src/` + `data/` |
| Upstream languages shipped | 83 `.po` files under `po/` |
| Port messages | **0** |
| Port languages shipped | **0** — no `po/` directory in the port |

Unchanged from the last round. This is a re-confirmation, not a new
finding — but it is checked fresh this round because the Alarm panel
landed six new `.rb` files since then, each of them full of user-visible
strings, and the claim "0/217" needs to still hold with those included.

## Census, re-run

```sh
$ grep -rn 'gettext\|FastGettext\|N_(\|n_(\|_("' lib/ exe/
(no output)
```

Zero hits across all 33 files in `lib/` (up from 27 at the last round) and
`exe/gnome-clocks`. No gettext binding is required anywhere, no translation
marker method is defined or aliased, none is called.

```sh
$ ls po/
ls: cannot access 'po/': No such file or directory
```

Still no catalogue, still no `.pot`, still no `LINGUAS`.

## What's new this round specifically

Every string the Alarm panel's six new files introduce is a bare literal,
same as every other file in the port:

- `lib/alarm_face.rb`: `'New Alarm'`, `"Alarm set for #{time_left_string}
  from now"`, the notification title fallback `'Alarm'`, button labels
  `'Stop'`/`'Snooze'`.
- `lib/alarm_row.rb`: `"Snoozed until #{...}"` and its unsnoozed
  counterpart.
- `lib/alarm_setup_dialog.rb`: `'Snooze Duration'` and the rest of the
  setup dialog's row labels.
- `lib/sound_chooser.rb` / `lib/sound_chooser_row.rb`: the sound names
  surfaced from `lib/alarm_sound_model.rb`'s `NAMES` table (`'Crossing
  Bell'`, `'Glass Bell'`, `'School Bell'`, etc.) and the chooser's own
  labels — all bare.

None of these carry `# Translators:` comments or any marker, matching
upstream's own convention for the same strings (upstream's
`alarm-setup-dialog.ui` marks these `translatable="yes"`; the port has no
equivalent property to set).

## Rule check (translation-parity skill)

- **Key sets equal?** No — 0 vs 217, unchanged.
- **Byte-identical where present?** Vacuously true; not a pass.
- **Languages ship unchanged?** No — 0 vs 83, unchanged.

## Verdict

**Still 0/217.** The Alarm panel's addition this round does not change the
verdict — it adds roughly another two dozen message candidates to the
count of what is not translated, but the finding was already "complete
absence of i18n infrastructure," and completeness cannot get more complete.
This remains the single largest parity gap of the five reports in this
round, unchanged in kind and now unchanged in scope too (it was already
app-wide).
