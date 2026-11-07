# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'

# AlarmDayPickerRow is the row of seven circular toggle buttons an alarm's
# repeat days are picked from, starting on the locale's first weekday.
#
# Ported from Clocks.Alarm.DayPickerRow in src/alarm-day-picker-row.vala and
# data/ui/alarm-day-picker-row.ui. Upstream wires each button through a
# Gio.PropertyAction on its own boolean property; this port's buttons toggle
# the Weekdays set directly instead, since the items here are plain Ruby
# objects rather than GObjects with per-day properties.
class AlarmDayPickerRow < Adwaita::PreferencesRow
  def initialize
    super()
    @days = Utils::Weekdays.new
    @day_listeners = []
  end

  attr_reader :days

  def build
    tap do |row|
      row.child = box

      box.tap do |container|
        ordered_days.each { |day| container.append(buttons[day]) }
      end

      buttons.each do |day, button|
        button.signal_connect('toggled') { toggle(day, button.active?) }
      end
    end
  end

  # Upstream's load: copies the given days in and refreshes the buttons.
  def load(current_days)
    Utils::Weekdays::DAYS.each { |day| @days[day] = current_days[day] }
    sync_buttons
    self
  end

  # Upstream's store: hands back a fresh copy of the picked days.
  def store
    Utils::Weekdays.new.tap { |copy| Utils::Weekdays::DAYS.each { |day| copy[day] = @days[day] } }
  end

  def on_days_changed(&block)
    @day_listeners << block
    self
  end

  # Memoized widget methods

  def box
    @box ||= Gtk::Box.new(:horizontal, 6).tap { |box| box.halign = :start }
  end

  # One toggle button per day, keyed by Weekdays day number.
  def buttons
    @buttons ||= Utils::Weekdays::DAYS.to_h do |day|
      [day, day_button(day)]
    end
  end

  private

    # Upstream sets the accessible label to the day's full name rather than
    # its single-letter symbol through Gtk::Accessible#update_property, which
    # raises NotImplementedError in these bindings, so the tooltip carries
    # the full name instead and the button's own label stays the symbol.
    def day_button(day)
      Gtk::ToggleButton.new.tap do |button|
        button.label = Utils::Weekdays.symbol(day)
        button.tooltip_text = Utils::Weekdays.name(day)
        button.halign = :start
        button.add_css_class('circular')
      end
    end

    # Upstream lists the buttons starting at the locale's first weekday.
    def ordered_days
      7.times.map { |offset| (Utils::Weekdays.first_weekday + offset) % 7 }
    end

    def toggle(day, on)
      unless @days[day] == on
        @days[day] = on
        @day_listeners.each(&:call)
      end
    end

    def sync_buttons
      buttons.each { |day, button| button.active = @days[day] }
      self
    end
end
