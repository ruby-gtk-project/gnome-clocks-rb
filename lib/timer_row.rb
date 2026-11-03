# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'
require_relative 'timer_item'

# TimerRow is one row of the Timer panel's list: the countdown, the title, and
# the three buttons that start, pause, reset and delete the timer.
#
# Ported from Clocks.Timer.Row in src/timer-row.vala and data/ui/timer-row.ui.
# The four stacks are upstream's — start/pause, reset, delete and the title's
# edit/display — and so is the pulse: a paused countdown fades between the
# dimmed and accent styles on a two-second Adw.TimedAnimation that repeats for
# as long as the timer stays paused.
#
class TimerRow < Gtk::ListBoxRow
  PULSE_DURATION = 2000

  def initialize(item)
    super()
    @item = item
    self.activatable = false
  end

  attr_reader :item

  def build
    tap do |row|
      row.child = box

      box.tap do |container|
        container.append(countdown_label)
        container.append(name_revealer)
        container.append(buttons_grid)

        name_revealer.child = name_stack

        name_stack.tap do |stack|
          stack.add_named(title_entry, 'edit')
          stack.add_named(name_label, 'display')
        end

        buttons_grid.tap do |grid|
          grid.attach(reset_stack, 0, 0, 1, 1)
          grid.attach(start_stack, 1, 0, 1, 1)
          grid.attach(delete_stack, 2, 0, 1, 1)

          start_stack.tap do |stack|
            stack.add_named(pause_button, 'pause')
            stack.add_named(start_button, 'start')
          end

          reset_stack.tap do |stack|
            stack.add_named(reset_button, 'button')
            stack.add_named(Adwaita::Bin.new, 'empty')
          end

          delete_stack.tap do |stack|
            stack.add_named(delete_button, 'button')
            stack.add_named(Adwaita::Bin.new, 'empty')
          end
        end
      end

      start_button.signal_connect('clicked') { @item.state = TimerItem::RUNNING }
      pause_button.signal_connect('clicked') { @item.state = TimerItem::PAUSED }
      reset_button.signal_connect('clicked') { @item.state = TimerItem::STOPPED }
      delete_button.signal_connect('clicked') { @on_deleted&.call }

      # Upstream binds the item's name to the display label one way and to the
      # entry both ways, so typing a title renames the timer as it is typed.
      title_entry.signal_connect('changed') { @item.name = title_entry.text }
      @item.on_name_changed { |name| sync_name(name) }
      @item.on_countdown_updated { |h, m, s| update_countdown(h, m, s) }
      @item.on_state_changed { update_state }

      sync_name(@item.name)
      update_state
    end
  end

  # Upstream's `deleted` signal, which the panel connects to in order to drop
  # the item from its store.
  def on_deleted(&block)
    @on_deleted = block
    self
  end

  # Upstream's update_state: which stack page each of the four stacks shows,
  # and how the countdown is styled, for each of the three states.
  def update_state
    case @item.state
    when TimerItem::STOPPED then show_stopped
    when TimerItem::PAUSED then show_paused
    else show_running
    end

    @item.state == TimerItem::PAUSED ? paused_animation.play : paused_animation.pause
    update_countdown(@item.stored_hour, @item.stored_minute, @item.stored_second)
    self
  end

  def update_countdown(hours, minutes, seconds)
    countdown_label.text = format(
      "%<hours>02i #{Utils::RATIO} %<minutes>02i #{Utils::RATIO} %<seconds>02i",
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    )
    self
  end

  # Memoized widget methods

  def box
    @box ||= Gtk::Box.new(:vertical, 6).tap do |box|
      box.valign = :start
      box.margin_top = 24
      box.margin_bottom = 24
    end
  end

  def countdown_label
    @countdown_label ||= Gtk::Label.new('00 ∶ 00 ∶ 00').tap do |label|
      # Forced left-to-right so [hh] : [mm] : [ss] never reverses.
      label.direction = :ltr
      label.add_css_class('numeric')
      label.add_css_class('timer-countdown')
    end
  end

  def name_revealer = @name_revealer ||= Gtk::Revealer.new

  def name_stack = @name_stack ||= Gtk::Stack.new

  def title_entry
    @title_entry ||= Gtk::Entry.new.tap do |entry|
      entry.halign = :center
      entry.width_chars = 26
      entry.placeholder_text = 'Title…'
      entry.text = @item.name.to_s
    end
  end

  def name_label
    @name_label ||= Gtk::Label.new.tap do |label|
      label.halign = :center
      label.valign = :start
      label.add_css_class('dimmed')
    end
  end

  def buttons_grid
    @buttons_grid ||= Gtk::Grid.new.tap do |grid|
      grid.halign = :center
      grid.column_spacing = 18
      grid.column_homogeneous = true
    end
  end

  def start_stack
    @start_stack ||= Gtk::Stack.new.tap do |stack|
      stack.halign = :center
      stack.valign = :center
      stack.hhomogeneous = false
      stack.vhomogeneous = false
    end
  end

  def reset_stack = @reset_stack ||= Gtk::Stack.new
  def delete_stack = @delete_stack ||= Gtk::Stack.new

  def start_button
    @start_button ||= circular_button('media-playback-start-symbolic', 'Start').tap do |button|
      button.add_css_class('suggested-action')
      button.add_css_class('large-button')
    end
  end

  def pause_button
    @pause_button ||= circular_button('media-playback-pause-symbolic', 'Pause').tap do |button|
      button.add_css_class('large-button')
    end
  end

  def reset_button = @reset_button ||= circular_button('view-refresh-symbolic', 'Reset')
  def delete_button = @delete_button ||= circular_button('user-trash-symbolic', 'Delete')

  # Upstream's paused_animation: an infinite linear sweep from 0 to 2 whose
  # callback target swaps the countdown's style class at the halfway point.
  def paused_animation
    @paused_animation ||= Adwaita::TimedAnimation.new(self, 0, 2, PULSE_DURATION, animation_target).tap do |animation|
      animation.repeat_count = Adwaita::DURATION_INFINITE
      animation.easing = :linear
    end
  end

  def animation_target
    @animation_target ||= Adwaita::CallbackAnimationTarget.new do |value|
      value < 1.0 ? dim_countdown : accent_countdown
    end
  end

  private

    def circular_button(icon_name, tooltip)
      Gtk::Button.new.tap do |button|
        button.halign = :center
        button.valign = :center
        button.icon_name = icon_name
        button.tooltip_text = tooltip
        button.add_css_class('circular')
      end
    end

    def sync_name(name)
      name.to_s.then do |text|
        name_label.label = text
        title_entry.text = text unless title_entry.text == text
      end
      self
    end

    def show_stopped
      delete_stack.visible_child_name = 'button'
      name_revealer.reveal_child = true
      name_stack.visible_child_name = 'edit'
      reset_stack.visible_child_name = 'empty'
      start_stack.visible_child_name = 'start'
      dim_countdown
    end

    def show_paused
      delete_stack.visible_child_name = 'button'
      name_revealer.reveal_child = !name_label.label.empty?
      name_stack.visible_child_name = 'display'
      reset_stack.visible_child_name = 'button'
      start_stack.visible_child_name = 'start'
    end

    def show_running
      delete_stack.visible_child_name = 'empty'
      name_revealer.reveal_child = !name_label.label.empty?
      name_stack.visible_child_name = 'display'
      reset_stack.visible_child_name = 'empty'
      start_stack.visible_child_name = 'pause'
      accent_countdown
    end

    def dim_countdown
      countdown_label.add_css_class('dimmed')
      countdown_label.remove_css_class('accent')
    end

    def accent_countdown
      countdown_label.add_css_class('accent')
      countdown_label.remove_css_class('dimmed')
    end
end
