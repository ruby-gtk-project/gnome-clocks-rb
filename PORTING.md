# Porting decisions

Decisions about this port's scope that are not obvious from any single
`lib/*.rb` file's header comment.

## Alarm ringing: AlarmRingingPanel exists; the notification path stays too

`src/alarm-ringing-panel.vala` is ported as `lib/alarm_ringing_panel.rb`: a
full-screen `Adw.NavigationPage` the window pushes over itself (with
`can-pop` false, so the window stays non-deletable the way
`src/window.vala`'s `visible_page_changed` keeps it) when `AlarmFace#ring`
fires, mirroring `src/window.vala:110-117` and `:307`. `AlarmFace#ring` still
also sends the `Gio::Notification` with Stop/Snooze buttons it always has —
upstream's own `alarm-item.vala` sends a system notification *and*
`alarm-face.vala` emits the `ring` signal the window turns into the
full-screen page, so both paths are upstream behavior, not a substitution of
one for the other.

Driving an alarm to `RINGING` for the first time (see
`test/drive_clocks.rb`'s "pushing an alarm's ring time into the past…" step)
surfaced a real bug in the notification path that had never executed
before: `Gio::Notification#add_button_with_target` in this binding is the
variadic `g_notification_add_button_with_target(label, action,
target_format, ...)`, so passing a plain string as the third argument reads
an unpassed vararg and segfaults the process. Fixed in `lib/alarm_face.rb`
by building a detailed action string with `GLib::Variant#to_s` and using the
non-variadic `#add_button` instead.

## search-provider and world-shell-world-clocks: out of scope for this port

`src/search-provider.vala` (a `Shell.SearchProvider2` export) and
`src/world-shell-world-clocks.vala` (the `org.gnome.Shell.WorldClocks`
applet export) remain unported, by deliberate choice, not oversight.

Both are session-bus services `src/application.vala`'s `dbus_register`
exports under the app's own well-known name once GApplication registers it.
Building them properly needs: a `dbus_register`/`dbus_unregister` override
on `App` (`lib/main.rb`) wired to `Gio::Application`'s own registration
signals; hand-written GDBus interface XML for both services, since this
port's gems (`gtk4`, `adwaita`, `glib2`, `libgweather`, `geocode-glib`,
`gnome_desktop`) provide none of it; and a live, queryable connection to the
World panel's `ContentStore` from a service object that is *not* a GTK
widget and must survive the window being hidden. None of that overlaps with
this round's gem-wiring or alarm-panel work, and a half-built D-Bus service
that mis-registers its interface is worse than an absent one — it can wedge
the whole app's `dbus_register` or collide with a real `org.gnome.Shell` on
a developer's session bus.

If a future round takes this on: start from `src/application.vala`'s
`dbus_register`/`dbus_unregister`, and build the two services as plain Ruby
objects (not widgets) that `lib/main.rb` registers and unregisters there,
each reading `World::Face#locations` rather than owning any state of their
own.
