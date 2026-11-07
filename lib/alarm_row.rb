# frozen_string_literal: true

require 'adwaita'
require_relative 'alarm_item'

# AlarmRow is one row of the Alarm panel's list: the on/off switch, the
# alarm's name and time, its repeat days, and the delete button.
#
# Ported from Clocks.Alarm.Row in src/alarm-row.vala and
# data/ui/alarm-row.ui. Upstream binds a GBindingGroup to the alarm's
# `active`/`days-label`/`days` properties and reacts to `notify["name"]`,
# `notify["state"]`, `notify["time"]` and `notify["ring_time"]`; this port
# listens through AlarmItem's own listener blocks instead, the way TimerRow
# already does for TimerItem.
class AlarmRow < Gtk::ListBoxRow
  def initialize(alarm)
    super()
    @alarm = alarm
    self.activatable = true
    self.selectable = false
  end

  attr_reader :alarm

  def build
    tap do |row|
      row.child = outer_box

      outer_box.tap do |box|
        box.append(labels_box)
        box.append(controls_box)

        labels_box.tap do |labels|
          labels.append(title_reveal)
          labels.append(time_label)
          labels.append(repeats_reveal)

          title_reveal.child = title_label
          repeats_reveal.child = repeats_label
        end

        controls_box.tap do |controls|
          controls.append(toggle_switch)
          controls.append(delete_button)
        end
      end

      toggle_switch.signal_connect('notify::active') { @alarm.active = toggle_switch.active? }
      delete_button.signal_connect('clicked') { @on_deleted&.call }

      @alarm.on_active_changed { update }
      @alarm.on_state_changed { update }
      @alarm.on_name_changed { update }

      update
    end
  end

  # Upstream's `remove_alarm` signal, which the panel connects to in order to
  # drop the alarm from its store.
  def on_deleted(&block)
    @on_deleted = block
    self
  end

  # Upstream's update: the active style class, the time, the repeats label,
  # and the title — which borrows the snoozed/missed state to decorate the
  # alarm's own name, or stand in for an unnamed one.
  def update
    @alarm.active? ? add_css_class('active') : remove_css_class('active')
    toggle_switch.active = @alarm.active? unless toggle_switch.active? == @alarm.active?

    time_label.label = @alarm.time_label
    repeats_label.label = @alarm.days_label.to_s
    repeats_reveal.reveal_child = !@alarm.days_label.to_s.empty?

    update_title
    self
  end

  # Memoized widget methods

  def outer_box
    @outer_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.valign = :center
      box.margin_start = 12
      box.margin_end = 12
      box.margin_top = 12
      box.margin_bottom = 12
    end
  end

  def labels_box
    @labels_box ||= Gtk::Box.new(:vertical, 0).tap { |box| box.hexpand = true }
  end

  def title_reveal = @title_reveal ||= Gtk::Revealer.new.tap { |r| r.transition_type = :slide_up }

  def title_label
    @title_label ||= Gtk::Label.new.tap do |label|
      label.hexpand = true
      label.ellipsize = :end
      label.xalign = 0
      label.add_css_class('heading')
    end
  end

  def time_label
    @time_label ||= Gtk::Label.new.tap do |label|
      label.hexpand = true
      label.xalign = 0
      label.add_css_class('alarm-time')
      label.add_css_class('numeric')
    end
  end

  def repeats_reveal = @repeats_reveal ||= Gtk::Revealer.new

  def repeats_label
    @repeats_label ||= Gtk::Label.new.tap do |label|
      label.tooltip_text = 'Repeats'
      label.hexpand = true
      label.ellipsize = :end
      label.xalign = 0
      label.add_css_class('dimmed')
      label.add_css_class('caption')
    end
  end

  def controls_box = @controls_box ||= Gtk::Box.new(:horizontal, 12)

  def toggle_switch
    @toggle_switch ||= Gtk::Switch.new.tap do |switch|
      switch.valign = :center
      switch.tooltip_text = 'Enable Alarm'
    end
  end

  def delete_button
    @delete_button ||= Gtk::Button.new.tap do |button|
      button.tooltip_text = 'Delete'
      button.halign = :center
      button.valign = :center
      button.icon_name = 'edit-delete-symbolic'
      button.add_css_class('circular')
      button.add_css_class('flat')
    end
  end

  private

    # Upstream's title logic: an alarm literally named "Alarm" is treated as
    # unnamed (pre-3.36 compatibility), snoozing appends the ring time to
    # whatever name is shown, missing replaces it and adds the error style,
    # and the title row only reveals when there is something to show.
    def update_title
      label = (@alarm.name.to_s == 'Alarm' ? nil : @alarm.name)

      if @alarm.state == AlarmItem::SNOOZING
        label = label.to_s.empty? ? "Snoozed until #{@alarm.ring_time_label}" : "#{label}: Snoozed until #{@alarm.ring_time_label}"
      end

      if @alarm.state == AlarmItem::MISSED
        label = label.to_s.empty? ? 'Alarm was missed' : "Alarm #{label} was missed"
        title_label.add_css_class('error')
      else
        title_label.remove_css_class('error')
      end

      title_label.label = label.to_s
      title_reveal.reveal_child = !label.to_s.empty?
    end
end
