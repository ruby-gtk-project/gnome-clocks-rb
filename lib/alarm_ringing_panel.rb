# frozen_string_literal: true

require 'adwaita'
require_relative 'alarm_item'
require_relative 'utils'

# AlarmRingingPanel is the full-screen page the window pushes over itself
# while an alarm is ringing: a big stop/snooze button grid and a label pair
# showing the alarm's name and time, ticking in step with the rest of the
# app's clocks.
#
# Ported from Clocks.Alarm.RingingPanel in src/alarm-ringing-panel.vala and
# data/ui/alarm-ringing-panel.ui.
class AlarmRingingPanel < Adwaita::Bin
  def initialize
    super()
    @alarm = nil
  end

  attr_reader :alarm

  def build
    tap do |panel|
      panel.child = window_handle
      window_handle.child = grid

      grid.tap do |g|
        g.attach(button_grid, 0, 1, 1, 1)
        g.attach(label_box, 0, 0, 1, 1)
      end

      button_grid.tap do |g|
        g.attach(stop_button, 0, 0, 1, 1)
        g.attach(snooze_button, 0, 1, 1, 1)
      end

      label_box.tap do |box|
        box.append(time_label)
        box.append(title_label)
      end

      Utils::WallClock.default.on_tick { update }
    end
  end

  # Upstream's `alarm` setter: disconnects the previous alarm's state
  # listener, wires the stop/snooze buttons at this alarm's id, and arms a
  # listener that dismisses the panel the moment the alarm leaves RINGING
  # (stopped, snoozed, or missed).
  def alarm=(value)
    @alarm = value
    if @alarm
      stop_button.action_target_value = GLib::Variant.new(@alarm.id)
      stop_button.action_name = 'app.stop-alarm'
      snooze_button.action_target_value = GLib::Variant.new(@alarm.id)
      snooze_button.action_name = 'app.snooze-alarm'
      @alarm.on_state_changed { |state| dismiss if state != AlarmItem::RINGING }
    end
    update
  end

  def on_dismiss(&block)
    @on_dismiss = block
    self
  end

  def dismiss
    @on_dismiss&.call
    self.alarm = nil
    self
  end

  # Memoized widget methods

  def window_handle = @window_handle ||= Gtk::WindowHandle.new

  def grid
    @grid ||= Gtk::Grid.new.tap do |g|
      g.margin_start = 6
      g.margin_end = 6
      g.margin_top = 6
      g.margin_bottom = 6
      g.hexpand = true
      g.vexpand = true
      g.row_spacing = 48
      g.column_spacing = 24
    end
  end

  def button_grid
    @button_grid ||= Gtk::Grid.new.tap do |g|
      g.halign = :center
      g.valign = :center
      g.hexpand = true
      g.vexpand = true
      g.row_spacing = 24
      g.column_spacing = 24
    end
  end

  def stop_button
    @stop_button ||= Gtk::Button.new(label: '_Stop').tap do |button|
      button.use_underline = true
      button.width_request = 200
      button.add_css_class('pill')
      button.add_css_class('large-button')
      button.add_css_class('destructive-action')
    end
  end

  def snooze_button
    @snooze_button ||= Gtk::Button.new(label: 'S_nooze').tap do |button|
      button.use_underline = true
      button.width_request = 200
      button.add_css_class('pill')
      button.add_css_class('large-button')
    end
  end

  def label_box
    @label_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :center
      box.valign = :center
      box.hexpand = true
      box.vexpand = true
    end
  end

  def time_label
    @time_label ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.wrap = true
      label.xalign = 0.5
      label.add_css_class('numeric')
      label.add_css_class('clocks-ringing-label')
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.wrap = true
      label.margin_top = 24
      label.add_css_class('clocks-ringing-title')
    end
  end

  private

    def update
      if @alarm
        title_label.label = @alarm.name.to_s
        time_label.label = @alarm.state == AlarmItem::SNOOZING ? @alarm.ring_time_label : @alarm.time_label
      else
        title_label.label = ''
        time_label.label = ''
      end
      self
    end
end
