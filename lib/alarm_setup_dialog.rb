# frozen_string_literal: true

require 'adwaita'
require_relative 'alarm_item'
require_relative 'alarm_day_picker_row'
require_relative 'alarm_sound_model'
require_relative 'sound_chooser'
require_relative 'utils'
require_relative 'widgets'

# AlarmSetupDialog is the New/Edit Alarm dialog: the time, the name, the
# repeat days, the sound and the ring/snooze durations, with a navigation
# page of its own for the sound chooser and a banner that warns about a
# duplicate alarm time.
#
# Ported from Clocks.Alarm.SetupDialog in src/alarm-setup-dialog.vala and
# data/ui/alarm-setup-dialog.ui.
#
# Upstream's DurationModel is a GListModel of Duration objects bound to the
# two Adw.ComboRows through a Gtk.Expression; the Ruby bindings have no
# matching set_expression, so the two rows are given a plain
# Gtk::StringList of the same labels instead, and the minutes behind the
# selected index are read back out of DURATIONS by position.
class AlarmSetupDialog < Adwaita::Dialog
  DURATIONS = [
    [1, '1 minute'],
    [5, '5 minutes'],
    [10, '10 minutes'],
    [15, '15 minutes'],
    [20, '20 minutes'],
    [30, '30 minutes'],
  ].freeze

  def self.duration_index(minutes) = DURATIONS.index { |value, _| value == minutes } || 1

  def initialize(alarm, other_alarms)
    super()
    @alarm = alarm
    @other_alarms = other_alarms.reject { |item| item == alarm }
    self.title = alarm ? 'Edit Alarm' : 'New Alarm'
    self.content_width = 520
    self.content_height = 580
  end

  def build
    tap do |dialog|
      dialog.child = navigation_view

      navigation_view.add(setup_page)

      sound_chooser.build
      navigation_view.add(Adwaita::NavigationPage.new(sound_chooser, 'Alarm Sound').tap { |page| page.tag = 'sound-chooser' })

      setup_toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = content_box
      end

      content_box.tap do |box|
        box.append(banner)
        box.append(preferences_page)
      end

      preferences_page.tap do |page|
        page.add(time_group)
        page.add(details_group)
        page.add(delete_group) if @alarm
      end

      time_group.add(time_row)
      time_row.append(h_spinbutton)
      time_row.append(colon_label)
      time_row.append(m_spinbutton)
      time_row.append(am_pm_bin)

      details_group.tap do |group|
        group.add(repeats.build)
        group.add(name_entry)
        group.add(sound_row)
        group.add(ring_duration)
        group.add(snooze_duration)
      end

      sound_row.tap do |row|
        row.add_suffix(sound_label)
        row.add_suffix(Gtk::Image.new(icon_name: 'go-next-symbolic'))
        row.action_name = 'navigation.push'
        row.action_target_value = GLib::Variant.new('sound-chooser')
      end

      if @alarm
        delete_group.add(delete_row)
        delete_row.signal_connect('activated') { delete_alarm }
      end

      cancel_button.signal_connect('clicked') { cancel }
      add_button.signal_connect('clicked') { add }

      [h_spinbutton, m_spinbutton].each do |spin|
        spin.signal_connect('value-changed') { avoid_duplicate_alarm }
        spin.signal_connect('output') { show_leading_zeros(spin) }
      end
      name_entry.signal_connect('changed') { avoid_duplicate_alarm }
      repeats.on_days_changed { avoid_duplicate_alarm }
      am_pm_button.on_changed { avoid_duplicate_alarm }

      sound_chooser.on_sound_changed { update_sound_label }

      configure_time_format
      load_from_alarm
      avoid_duplicate_alarm
    end
  end

  # Upstream's `response` signal: :add when the Add/Done button fires, :cancel
  # otherwise. Delete is reported through #on_delete instead of a shared
  # response code, since this port has no modal response integer to share it
  # through.
  def on_response(&block)
    @response_listener = block
    self
  end

  def on_delete(&block)
    @delete_listener = block
    self
  end

  # Upstream's apply_to_alarm: writes every field the dialog edited back onto
  # the given alarm and resets its ring time so the change takes effect
  # immediately.
  def apply_to_alarm(alarm)
    alarm.name = name_entry.text
    alarm.hour = dialog_hour
    alarm.minute = m_spinbutton.value_as_int
    alarm.days = repeats.store
    alarm.snooze_minutes = DURATIONS[snooze_duration.selected].first
    alarm.ring_minutes = DURATIONS[ring_duration.selected].first
    alarm.sound_file = (sound_chooser.sound && sound_chooser.sound.uri != SoundChooser::SILENT_SOUND_URI) ? sound_chooser.sound.file : AlarmSoundModel.build_default_file
    alarm.reset
    alarm
  end

  # Memoized widget methods

  def navigation_view = @navigation_view ||= Adwaita::NavigationView.new

  def setup_page = @setup_page ||= Adwaita::NavigationPage.new(setup_toolbar_view, @alarm ? 'Edit Alarm' : 'New Alarm').tap { |page| page.tag = 'setup' }
  def setup_toolbar_view = @setup_toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_start_title_buttons = false
      bar.show_end_title_buttons = false
      bar.pack_start(cancel_button)
      bar.pack_end(add_button)
    end
  end

  def cancel_button = @cancel_button ||= Gtk::Button.new(label: '_Cancel').tap { |b| b.use_underline = true }

  def add_button
    @add_button ||= Gtk::Button.new(label: @alarm ? '_Done' : '_Add').tap do |button|
      button.use_underline = true
      button.add_css_class('suggested-action')
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

  def banner = @banner ||= Adwaita::Banner.new('You already have an alarm for this time')

  def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

  def time_group = @time_group ||= Adwaita::PreferencesGroup.new

  def time_row
    @time_row ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.halign = :center
      box.margin_bottom = 12
      box.direction = :ltr
      box.add_css_class('clocks-alarm-setup-time')
    end
  end

  def h_spinbutton = @h_spinbutton ||= time_spinbutton(23, 'Hours')
  def m_spinbutton = @m_spinbutton ||= time_spinbutton(59, 'Minutes')
  def colon_label = @colon_label ||= Gtk::Label.new(Utils::RATIO)
  def am_pm_bin
    @am_pm_bin ||= Adwaita::Bin.new.tap do |bin|
      bin.margin_start = 6
      bin.margin_end = 6
    end
  end
  def am_pm_button = @am_pm_button ||= AmPmToggleButton.new

  def details_group = @details_group ||= Adwaita::PreferencesGroup.new

  def repeats = @repeats ||= AlarmDayPickerRow.new

  def name_entry = @name_entry ||= Adwaita::EntryRow.new.tap { |row| row.title = 'Name' }

  def sound_row
    @sound_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = 'Alarm Sound'
      row.activatable = true
    end
  end

  def sound_label
    @sound_label ||= Gtk::Label.new.tap do |label|
      label.ellipsize = :end
      label.xalign = 0
    end
  end

  def ring_duration = @ring_duration ||= duration_combo_row('Ring Duration')
  def snooze_duration = @snooze_duration ||= duration_combo_row('Snooze Duration')

  def delete_group = @delete_group ||= Adwaita::PreferencesGroup.new

  def delete_row
    @delete_row ||= Adwaita::ButtonRow.new.tap do |row|
      row.title = 'R_emove Alarm'
      row.use_underline = true
      row.add_css_class('destructive-action')
    end
  end

  def sound_chooser = @sound_chooser ||= SoundChooser.new(AlarmSoundModel.new)

  private

    def time_spinbutton(upper, tooltip)
      Gtk::SpinButton.new(Gtk::Adjustment.new(0, 0, upper, 1, 10, 0), 1, 0).tap do |spin|
        spin.width_request = 60
        spin.xalign = 0.5
        spin.orientation = :vertical
        spin.numeric = true
        spin.tooltip_text = tooltip
        spin.wrap = true
      end
    end

    def duration_combo_row(title)
      Adwaita::ComboRow.new.tap do |row|
        row.title = title
        row.activatable = false
        row.model = Gtk::StringList.new(DURATIONS.map(&:last))
      end
    end

    def dialog_hour
      hour = h_spinbutton.value_as_int
      if twelve_hour?
        if am_pm_button.choice == AmPmToggleButton::AM
          hour == 12 ? 0 : hour
        else
          hour == 12 ? 12 : hour + 12
        end
      else
        hour
      end
    end

    def twelve_hour? = Utils::WallClock.default.format == Utils::WallClock::TWELVE

    def configure_time_format
      if twelve_hour?
        h_spinbutton.adjustment.lower = 1
        h_spinbutton.adjustment.upper = 12
        am_pm_bin.visible = true
        am_pm_bin.child = am_pm_button
      else
        h_spinbutton.adjustment.lower = 0
        h_spinbutton.adjustment.upper = 23
        am_pm_bin.visible = false
      end
      self
    end

    def load_from_alarm
      if @alarm
        load_hour(@alarm.hour)
        m_spinbutton.value = @alarm.minute
        name_entry.text = @alarm.name.to_s
        repeats.load(@alarm.days) if @alarm.days
        ring_duration.selected = AlarmSetupDialog.duration_index(@alarm.ring_minutes)
        snooze_duration.selected = AlarmSetupDialog.duration_index(@alarm.snooze_minutes)
        select_sound(@alarm.sound_file)
      else
        wallclock = Utils::WallClock.default
        load_hour(wallclock.date_time.hour)
        m_spinbutton.value = wallclock.date_time.minute
        ring_duration.selected = AlarmSetupDialog.duration_index(5)
        snooze_duration.selected = AlarmSetupDialog.duration_index(10)
        select_sound(AlarmSoundModel.build_default_file)
      end
      update_sound_label
      self
    end

    def load_hour(hour)
      if twelve_hour?
        am_pm_button.choice = hour < 12 ? AmPmToggleButton::AM : AmPmToggleButton::PM
        hour %= 12
        hour = 12 if hour.zero?
      end
      h_spinbutton.value = hour
      self
    end

    def select_sound(sound_file)
      sound_chooser.sound = sound_chooser.silent_sound.uri == sound_file.uri ? sound_chooser.silent_sound : sound_chooser.find_by_file(sound_file)
      self
    end

    def update_sound_label
      sound_label.label = sound_chooser.sound&.label.to_s
      self
    end

    def avoid_duplicate_alarm
      probe = AlarmItem.new
      apply_to_alarm(probe)
      duplicate = probe.check_duplicate_alarm(@other_alarms)
      add_button.sensitive = !duplicate
      banner.revealed = duplicate
      self
    end

    def show_leading_zeros(spin)
      spin.text = format('%02i', spin.value_as_int)
      true
    end

    def cancel
      @response_listener&.call(:cancel)
      self
    end

    def add
      @response_listener&.call(:add)
      self
    end

    def delete_alarm
      @delete_listener&.call
      self
    end
end
