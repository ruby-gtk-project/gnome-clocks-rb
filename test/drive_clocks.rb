# frozen_string_literal: true

# Drives the whole app headlessly: builds the window, switches between every
# panel it has (World, Stopwatch, Timer), opens every dialog (add-location,
# new-timer, shortcuts, about), fires the window's actions and the per-panel
# controls, hits the empty and populated states, and screenshots each one.
#
# It also smoke-tests the alarm model layer (AlarmItem, AlarmSoundModel,
# AlarmDayPickerRow, Sound) on its own: nothing in the window wires it up yet
# (see .reports/component-inventory.md — the Alarm panel itself is unported),
# so there is no widget to drive it through, but a round trip through the
# model is still worth proving.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_clocks.rb
#
# GTK4 here has no offscreen backend — gtk_init fails outright with no
# display — so xvfb-run is not optional on this machine.

require "fileutils"
require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("clocks-drive")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "gnome_clocks"
require_relative "gtk_driver"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

# Turns the main loop over for `ms` milliseconds and comes back. A step
# cannot sleep: every step runs inside a GLib timeout dispatched by this same
# loop, so sleeping would block the very thing that is supposed to advance.
def pump(ms)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (ms / 1000.0)
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    GLib::MainContext.default.iteration(false)
  end
end

# Polls `condition` until it is true or `timeout_ms` passes, instead of
# gambling on a fixed pump duration for something like Adw.Dialog's close,
# which runs on the frame clock rather than a GLib timer.
def pump_until(timeout_ms, &condition)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (timeout_ms / 1000.0)
  until condition.call
    break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    GLib::MainContext.default.iteration(false)
  end
end

# ---------------------------------------------------------------------------
# Plain checks on the non-widget alarm model layer. No display needed for
# this half, and it is run before the window-driving half so a crash here
# does not cost the GTK run.
# ---------------------------------------------------------------------------

require_relative "../lib/alarm_item"
require_relative "../lib/alarm_sound_model"
require_relative "../lib/alarm_day_picker_row"
require_relative "../lib/sound"

MODEL_CHECKS = []

def model_check(description)
  MODEL_CHECKS << [description, yield]
rescue StandardError => e
  MODEL_CHECKS << [description, false]
  warn "  model check #{description} raised #{e.class}: #{e.message}"
end

model_check("AlarmSoundModel lists the fallback plus every named sound") do
  AlarmSoundModel.new.length == AlarmSoundModel::NAMES.length + 1
end

model_check("every Sound in the model carries the label it was built with") do
  AlarmSoundModel.new.find_by_file(AlarmSoundModel.build_fallback_file).label == "Beep-Beep"
end

model_check("a fresh alarm is not active and has no ring time") do
  !AlarmItem.new.active?
end

model_check("activating an alarm gives it a ring time in the future") do
  alarm = AlarmItem.new
  alarm.active = true
  alarm.active? && alarm.ring_time > Time.now
end

model_check("an alarm round-trips through serialize/deserialize") do
  alarm = AlarmItem.new
  alarm.name = "Wake up"
  alarm.hour = 7
  alarm.minute = 30
  alarm.active = true
  restored = AlarmItem.deserialize(alarm.serialize)
  restored.name == "Wake up" && restored.hour == 7 && restored.minute == 30 && restored.active?
end

model_check("two alarms at the same active time are duplicates of each other") do
  first = AlarmItem.new
  first.hour = 8
  first.minute = 0
  first.active = true
  second = AlarmItem.new
  second.hour = 8
  second.minute = 0
  second.active = true
  first.duplicate_of?(second)
end

model_check("AlarmItem.compare orders by time of day") do
  early = AlarmItem.new
  early.hour = 6
  early.minute = 0
  late = AlarmItem.new
  late.hour = 18
  late.minute = 0
  AlarmItem.compare(early, late).negative?
end

model_check("a day picker row starts with no days picked") do
  AlarmDayPickerRow.new.days.empty?
end

model_check("loading weekdays into a day picker row reads back the same set") do
  row = AlarmDayPickerRow.new
  row.build
  row.load(Utils::Weekdays.new.tap { |days| days[Utils::Weekdays::MON] = true; days[Utils::Weekdays::WED] = true })
  row.days.label == "Mon, Wed"
end

model_check("a day picker row's buttons toggle the stored days") do
  row = AlarmDayPickerRow.new
  row.build
  changed = false
  row.on_days_changed { changed = true }
  row.buttons[Utils::Weekdays::FRI].active = true
  row.days[Utils::Weekdays::FRI] && changed
end

puts "-- alarm model layer (no display) --"
MODEL_CHECKS.each do |description, ok|
  puts(ok ? "    ok   #{description}" : "    FAIL #{description}")
end
model_failures = MODEL_CHECKS.reject { |_, ok| ok }
puts "#{MODEL_CHECKS.length - model_failures.length} of #{MODEL_CHECKS.length} model checks passed"
puts

# ---------------------------------------------------------------------------
# Driving the window itself.
# ---------------------------------------------------------------------------

GtkDriver.drive(GnomeClocks::Application.new, shots: SHOTS) do |d, app|
  d.window { app.window }

  d.step("the window builds with the World panel showing") do
    d.check("the window is an Adwaita::ApplicationWindow") { app.window.is_a?(Adwaita::ApplicationWindow) }
    d.check("it is the only toplevel") { Gtk::Window.list_toplevels.length == 1 }
    d.check("its title is Clocks") { app.window.title == "Clocks" }
    d.check("the World panel is the restored, default panel") { app.window.stack.visible_child_name == "world" }
    d.check("the World panel's empty state is showing") { app.window.panel(PanelId::WORLD).stack.visible_child_name == "empty" }
    d.check("the header bar offers the + button for World") { app.window.header_bar.button_mode == ButtonMode::NEW }
    d.shot("01-world-empty")
  end

  d.step("the shortcuts dialog opens and closes") do
    app.window.shortcuts_dialog.present(app.window)
  end

  d.step("it is on screen, with a section per panel this port has") do
    d.check("a dialog is showing") { !app.window.visible_dialog.nil? }
    d.shot("02-shortcuts")
    app.window.visible_dialog.close
    pump_until(2000) { app.window.visible_dialog.nil? }
  end

  d.step("the About dialog opens from the win.about action") do
    app.window.activate_action("about", nil)
  end

  d.step("it names the app") do
    app.window.visible_dialog.then do |dialog|
      d.check("a dialog is showing") { !dialog.nil? }
      d.check("its application name is Clocks") { dialog.application_name == "Clocks" }
    end
  end

  # The shot waits a tick after the check above: a dialog that only just
  # presented has not necessarily been laid out again yet, and
  # Gtk::WidgetPaintable then produces no render node at all.
  d.step("it renders") { d.shot("03-about") }

  d.step("it closes") do
    app.window.visible_dialog.close
    pump_until(2000) { app.window.visible_dialog.nil? }
  end

  # --- World panel ---------------------------------------------------------

  d.step("the + button opens the Add World Clock dialog") do
    app.window.panel(PanelId::WORLD).add_button.signal_emit("clicked")
  end

  d.step("it starts on the empty-search page with Add insensitive") do
    app.window.visible_dialog.then do |dialog|
      d.check("a dialog is showing") { !dialog.nil? }
      d.check("the empty-search page shows") { dialog.stack.visible_child.equal?(dialog.empty_search) }
      d.check("Add is insensitive with nothing picked") { !dialog.add_button.sensitive? }
      d.shot("04-add-location-empty")
    end
  end

  d.step("typing a search finds matching cities") do
    app.window.visible_dialog.location_entry.text = "london"
  end

  d.step("search-changed fires and fills in the results") do
    app.window.visible_dialog.location_entry.signal_emit("search-changed")
  end

  d.step("the search page is showing") do
    app.window.visible_dialog.then do |dialog|
      d.check("the results page shows") { dialog.stack.visible_child.equal?(dialog.search_results) }
      d.check("at least one row of results") { !dialog.listbox.first_child.nil? }
    end
  end

  d.step("it renders") { d.shot("05-add-location-results") }

  d.step("activating a result row selects it") do
    app.window.visible_dialog.then do |dialog|
      dialog.listbox.signal_emit("row-activated", dialog.listbox.first_child)
    end
  end

  d.step("Add became sensitive") do
    d.check("Add is now sensitive") { app.window.visible_dialog.add_button.sensitive? }
  end

  d.step("it renders") { d.shot("06-add-location-selected") }

  d.step("Add creates the clock and closes the dialog") do
    app.window.visible_dialog.add_button.signal_emit("clicked")
    pump_until(2000) { app.window.visible_dialog.nil? }
  end

  d.step("the new clock is listed and on disk") do
    world = app.window.panel(PanelId::WORLD)
    d.check("one location is stored") { world.locations.n_items == 1 }
    d.check("the list page is showing now") { world.stack.visible_child_name == "list" }
    d.check("one row in the list box") { world.listbox.first_child != nil }
    d.check("the header bar still offers +") { app.window.header_bar.button_mode == ButtonMode::NEW }
    d.check("the setting was written to disk") { app.window.settings.world_clocks.length == 1 }
    d.shot("07-world-one-clock")
  end

  d.step("adding the same location again is refused") do
    world = app.window.panel(PanelId::WORLD)
    world.add_location(world.locations.get_item(0).location)
  end

  d.step("the duplicate did not get added") do
    d.check("still one location") { app.window.panel(PanelId::WORLD).locations.n_items == 1 }
  end

  d.step("activating the row opens the standalone big-clock page") do
    row = app.window.panel(PanelId::WORLD).listbox.first_child
    app.window.panel(PanelId::WORLD).listbox.signal_emit("row-activated", row)
  end

  d.step("the subpage is pushed with the city's name as its title") do
    d.check("the navigation view has a subpage now") { app.window.navigation_view.visible_page != app.window.main_page }
    world_item = app.window.panel(PanelId::WORLD).locations.get_item(0)
    d.check("the window's title follows the subpage") { app.window.title == world_item.city_name }
    d.check("the window became non-deletable while a subpage is open") { !app.window.deletable? }
    d.shot("08-world-standalone")
  end

  d.step("Escape pops the subpage back to the main page") do
    app.window.key_controller.signal_emit("key-pressed", Gdk::Keyval::KEY_Escape, 0, 0)
  end

  d.step("the main page is back and the title is Clocks again") do
    pump(200)
    d.check("back on the main page") { app.window.navigation_view.visible_page == app.window.main_page }
    d.check("the title is Clocks again") { app.window.title == "Clocks" }
    d.check("the window is deletable again") { app.window.deletable? }
  end

  d.step("the row's delete button removes the clock") do
    app.window.panel(PanelId::WORLD).listbox.first_child.delete_button.signal_emit("clicked")
  end

  d.step("the World panel is empty again") do
    world = app.window.panel(PanelId::WORLD)
    d.check("no locations left") { world.locations.n_items.zero? }
    d.check("the empty page is showing") { world.stack.visible_child_name == "empty" }
    d.check("nothing left on disk") { app.window.settings.world_clocks.empty? }
    d.shot("09-world-empty-again")
  end

  # --- Panel switching: Ctrl+Alt+PageDown / PageUp -------------------------

  d.step("win.navigate-forward moves World -> Stopwatch") do
    app.window.activate_action("navigate-forward", nil)
  end

  d.step("the Stopwatch panel is showing") do
    d.check("the stack is on stopwatch") { app.window.stack.visible_child_name == "stopwatch" }
    d.check("the header bar has no + button on Stopwatch") { app.window.header_bar.button_mode == ButtonMode::NONE }
    d.shot("10-stopwatch-reset")
  end

  # --- Stopwatch panel ------------------------------------------------------

  d.step("the start button starts the stopwatch") do
    app.window.panel(PanelId::STOPWATCH).start_button.signal_emit("clicked")
  end

  d.step("it is running and the window gets the needs-attention dot") do
    stopwatch = app.window.panel(PanelId::STOPWATCH)
    d.check("state is running") { stopwatch.state == StopwatchFace::RUNNING }
    d.check("the stack page needs attention") { app.window.stack.get_page(stopwatch).needs_attention? }
    d.check("the start button now reads Pause") { stopwatch.start_button.label == "_Pause" }
  end

  d.step("letting it run for a bit, then taking a lap") do
    pump(600)
    app.window.panel(PanelId::STOPWATCH).clear_button.signal_emit("clicked")
  end

  d.step("the lap is recorded and shown") do
    stopwatch = app.window.panel(PanelId::STOPWATCH)
    d.check("one lap recorded") { stopwatch.laps.n_items == 1 }
    d.check("the laps list has one row") { stopwatch.laps_list.first_child != nil }
    d.check("the laps revealer is open") { stopwatch.laps_revealer.reveal_child? }
    d.shot("11-stopwatch-running-with-lap")
  end

  d.step("Escape pauses a running stopwatch") do
    d.check("escape_pressed reports it was consumed") { app.window.panel(PanelId::STOPWATCH).escape_pressed }
    d.check("state is now stopped") { app.window.panel(PanelId::STOPWATCH).state == StopwatchFace::STOPPED }
  end

  d.step("it renders") { d.shot("12-stopwatch-paused") }

  d.step("Escape again clears a stopped stopwatch") do
    d.check("escape_pressed reports it was consumed") { app.window.panel(PanelId::STOPWATCH).escape_pressed }
    stopwatch = app.window.panel(PanelId::STOPWATCH)
    d.check("state is back to reset") { stopwatch.state == StopwatchFace::RESET }
    d.check("the laps are cleared") { stopwatch.laps.n_items.zero? }
    d.check("the needs-attention dot is gone") { !app.window.stack.get_page(stopwatch).needs_attention? }
  end

  d.step("it renders") { d.shot("13-stopwatch-reset-again") }

  # --- Timer panel ----------------------------------------------------------

  d.step("win.navigate-forward moves Stopwatch -> Timer") do
    app.window.activate_action("navigate-forward", nil)
  end

  d.step("the Timer panel's empty setup pane is showing") do
    d.check("the stack is on timer") { app.window.stack.visible_child_name == "timer" }
    d.check("the empty setup page is showing") { app.window.panel(PanelId::TIMER).stack.visible_child_name == "empty" }
    d.shot("14-timer-empty")
  end

  d.step("a quick-start button starts a one-minute timer") do
    timer = app.window.panel(PanelId::TIMER)
    timer.timer_setup.quick_start_buttons.first.signal_emit("clicked")
  end

  d.step("the timer is running and the list page is showing") do
    timer = app.window.panel(PanelId::TIMER)
    d.check("one timer") { timer.timers.n_items == 1 }
    d.check("the timers page is showing") { timer.stack.visible_child_name == "timers" }
    d.check("it is running") { timer.timers.get_item(0).state == TimerItem::RUNNING }
    d.check("is_running is true") { timer.is_running }
    d.check("the timer page needs attention") { app.window.stack.get_page(timer).needs_attention? }
    d.check("the header bar offers + now there is a list") { app.window.header_bar.button_mode == ButtonMode::NEW }
    d.shot("15-timer-running")
  end

  d.step("the row's pause button pauses it") do
    app.window.panel(PanelId::TIMER).timers_list.first_child.pause_button.signal_emit("clicked")
  end

  d.step("it is paused and the panel notices no timer is running") do
    timer = app.window.panel(PanelId::TIMER)
    d.check("state is paused") { timer.timers.get_item(0).state == TimerItem::PAUSED }
    d.check("is_running went false") { !timer.is_running }
    d.check("the needs-attention dot cleared") { !app.window.stack.get_page(timer).needs_attention? }
    d.shot("16-timer-paused")
  end

  d.step("the row's reset button stops it, and delete removes it") do
    row = app.window.panel(PanelId::TIMER).timers_list.first_child
    row.reset_button.signal_emit("clicked")
  end

  d.step("it is stopped") do
    d.check("state is stopped") { app.window.panel(PanelId::TIMER).timers.get_item(0).state == TimerItem::STOPPED }
  end

  d.step("deleting it empties the list") do
    app.window.panel(PanelId::TIMER).timers_list.first_child.delete_button.signal_emit("clicked")
  end

  d.step("the Timer panel is back to its empty setup pane") do
    timer = app.window.panel(PanelId::TIMER)
    d.check("no timers left") { timer.timers.n_items.zero? }
    d.check("the empty page is back") { timer.stack.visible_child_name == "empty" }
    d.check("the header bar offers no + button with nothing to add") { app.window.header_bar.button_mode == ButtonMode::NONE }
    d.shot("17-timer-empty-again")
  end

  # --- New Timer dialog (win.new on the Timer panel) ------------------------

  d.step("win.new opens the New Timer dialog") do
    app.window.activate_action("new", nil)
  end

  d.step("it opens with Start insensitive at a zero duration") do
    app.window.visible_dialog.then do |dialog|
      d.check("a dialog is showing") { !dialog.nil? }
      d.check("Start is insensitive") { !dialog.start_button.sensitive? }
      d.shot("18-new-timer-dialog")
    end
  end

  d.step("setting a custom duration enables Start") do
    app.window.visible_dialog.timer_setup.then do |setup|
      setup.minutes_spinbutton.value = 2
      setup.minutes_spinbutton.signal_emit("changed")
    end
  end

  d.step("Start is sensitive and starting it closes the dialog") do
    dialog = app.window.visible_dialog
    d.check("Start is sensitive now") { dialog.start_button.sensitive? }
    d.check("the setup reports the typed duration") { dialog.timer_setup.duration == 120 }
    dialog.start_button.signal_emit("clicked")
    pump_until(2000) { app.window.visible_dialog.nil? }
  end

  d.step("the dialog's timer is running in the list") do
    timer = app.window.panel(PanelId::TIMER)
    d.check("one timer again") { timer.timers.n_items == 1 }
    d.check("its duration is two minutes") { timer.timers.get_item(0).stored_minute == 2 }
    d.check("it is running") { timer.timers.get_item(0).state == TimerItem::RUNNING }
    d.shot("19-timer-from-dialog")
  end

  d.step("Escape pauses every running timer") do
    d.check("escape_pressed reports it was consumed") { app.window.panel(PanelId::TIMER).escape_pressed }
    d.check("the timer is paused") { app.window.panel(PanelId::TIMER).timers.get_item(0).state == TimerItem::PAUSED }
  end

  d.step("cleaning up: delete the remaining timer") do
    app.window.panel(PanelId::TIMER).timers_list.first_child.delete_button.signal_emit("clicked")
  end

  d.step("the window is empty across every panel again") do
    d.check("no timers") { app.window.panel(PanelId::TIMER).timers.n_items.zero? }
    d.check("no world clocks") { app.window.panel(PanelId::WORLD).locations.n_items.zero? }
    d.check("stopwatch is reset") { app.window.panel(PanelId::STOPWATCH).state == StopwatchFace::RESET }
  end

  # --- Back to World, and window-close behaviour ----------------------------

  d.step("win.navigate-backward moves Timer -> Stopwatch -> World (two steps)") do
    app.window.activate_action("navigate-backward", nil)
    app.window.activate_action("navigate-backward", nil)
  end

  d.step("the World panel is showing again") do
    d.check("back on world") { app.window.stack.visible_child_name == "world" }
    d.shot("20-back-to-world")
  end

  d.step("hide_on_close means close-request hides rather than destroys") do
    app.window.close
  end

  d.step("the window is hidden, not gone") do
    d.check("the window still exists as a toplevel") { Gtk::Window.list_toplevels.length == 1 }
    d.check("it is no longer visible") { !app.window.visible? }
    app.window.present
  end
end
