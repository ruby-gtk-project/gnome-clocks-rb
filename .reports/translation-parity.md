# Translation parity — gnome-clocks-rb

| | |
|---|---|
| Upstream | `master` @ `99afdd1` |
| Port | `ruby` @ `e85d7e5` |
| Upstream messages (census) | 217 distinct (msgctxt, msgid) rows over `src/` + `data/` |
| Upstream languages shipped | 83 `.po` files under `po/` |
| Port messages | **0** |
| Port languages shipped | **0** (no `po/` directory exists in the port at all) |

## Census

```sh
msgid-census.sh /tmp/up-clocks/src /tmp/up-clocks/data   # worktree of origin/master
```

217 rows: `_()`/`N_()`/`C_()` calls across the `.vala` sources and
`translatable="yes"` / `<property translatable="yes">` strings across the 21
`.ui` templates — covers every title, button label, tooltip, placeholder,
`Adw.StatusPage` heading/description, menu item, and shortcuts-dialog entry
in the app, plus the plural "hour(s) ahead/behind" and weekday-symbol
`msgctxt` strings documented in `.reports/component-inventory.md`.

```sh
msgid-census.sh lib exe
```

**0 rows.** Not "fewer than upstream" — zero. Confirmed independently:

```sh
$ grep -rn 'gettext\|FastGettext\|N_(\|n_(\|_("' lib/ exe/
(no output)
```

No file in `lib/` or `exe/` requires a gettext binding, defines or aliases a
translation marker method, or calls one. Every user-visible string in the
port — "Clocks", "Alarm Ringing", "_World", "Ala_rms", the AM/PM labels,
every button, every status-page heading already built — is a bare Ruby
string literal.

## Catalogue

```sh
$ ls po/
ls: cannot access 'po/': No such file or directory
```

The port ships **no `po/` directory, no `.pot`, no `LINGUAS`, and no build
step that would generate or install one.** Upstream's 83 language `.po`
files have no counterpart anywhere in this fork's `ruby` branch.

## What this means concretely

Every one of the 11 built units in `component-parity.md` fails the text
axis simultaneously:

- The World panel's "Add World Clock", "Search cities", "No Results Found",
  the day/night and sunrise/sunset captions — all bare strings.
- The Timer and Stopwatch panels' "St_art"/"_Pause"/"_Lap" cycling labels,
  the quick-start captions ("1 m" … "1 h"), the accessible labels ("One
  minute" …) — all bare strings.
- The shortcuts dialog's 15 `Adw.ShortcutsItem` labels and 5 section
  headings — all bare strings.
- `lib/utils.rb`'s "Current timezone", the "%s hour(s) ahead|behind" plural,
  and the weekday single-letter `msgctxt` symbols the day-picker row will
  need — none use a plural or context marker; `n_()`/`C_()` are not even
  defined anywhere in the port.

This is not a rounding error or a handful of missed strings. It is the
complete absence of i18n infrastructure. English is the only language this
port can ever display, and none of the 83 languages upstream ships has
anything to attach to, because there is no catalogue for any translator's
work to target.

## Rule check (translation-parity skill)

- **Key sets equal?** No — 0 vs 217.
- **Byte-identical where present?** Vacuously true (there is nothing to
  compare), which is not a pass; the skill's three claims are conjunctive.
- **Languages ship unchanged?** No — 0 vs 83, and no mechanism exists to
  regain them without first building the marker infrastructure upstream's
  `.pot` is extracted from.

## Verdict

**0/217.** This is the largest single gap of the five reports in this
round, larger in absolute count than the entire missing Alarm panel, and it
is invisible in any English screenshot — which is exactly the failure mode
the `translation-parity` skill exists to catch.
