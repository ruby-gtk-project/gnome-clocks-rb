# frozen_string_literal: true

require 'adwaita'
require_relative 'utils'
require_relative 'timer_item'

# TimerSetup is the pane that sets a timer up: eight quick-start buttons, the
# three spin buttons for hours, minutes and seconds, and the title entry.
#
# Ported from Clocks.Timer.Setup in src/timer-setup.vala and
# data/ui/timer-setup.ui, including the "timer-setup.start-timer" action the
# quick-start buttons activate with the number of minutes as their target, the
# leading zeros its spin buttons render, and the carrying its minute and
# second fields do when a number over 59 is typed into them.
#
class TimerSetup < Gtk::Box
  # The quick-start values, in the order data/ui/timer-setup.ui lists them,
  # with the accessible name each button carries.
  QUICK_START = [
    [1, '1 m', 'One minute'],
    [2, '2 m', 'Two minutes'],
    [3, '3 m', 'Three minutes'],
    [5, '5 m', 'Five minutes'],
    [30, '30 m', 'Thirty minutes'],
    [15, '15 m', 'Fifteen minutes'],
    [45, '45 m', 'Fortyfive minutes'],
    [60, '1 h', 'One hour'],
  ].freeze

  def initialize
    super(:vertical, 0)
    @duration_listeners = []
    @start_listeners = []
  end

  def build
    tap do |setup|
      setup.append(clamp)

      clamp.child = content_box

      content_box.tap do |box|
        box.append(section_label('Quick Start'))
        box.append(quick_start_box)
        box.append(section_label('Set Timer'))
        box.append(time_box)
        box.append(title_clamp)

        quick_start_box.tap do |wrap|
          quick_start_buttons.each do |button|
            wrap.append(button)
            quick_start_size_group.add_widget(button)
          end
        end

        time_box.append(time_grid)

        time_grid.tap do |grid|
          grid.attach(Gtk::Label.new.tap { |label| label.hexpand = true }, 0, 0, 1, 1)
          grid.attach(hours_spinbutton, 1, 0, 1, 1)
          grid.attach(separator_label, 2, 0, 1, 1)
          grid.attach(minutes_spinbutton, 3, 0, 1, 1)
          grid.attach(second_separator_label, 4, 0, 1, 1)
          grid.attach(seconds_spinbutton, 5, 0, 1, 1)
          grid.attach(Gtk::Label.new.tap { |label| label.hexpand = true }, 6, 0, 1, 1)
        end

        title_clamp.child = title_entry
      end

      setup.insert_action_group('timer-setup', action_group)

      [hours_spinbutton, minutes_spinbutton, seconds_spinbutton].each do |spin_button|
        spin_button.signal_connect('changed') { update_duration(spin_button) }
        spin_button.signal_connect('output') { show_leading_zeros(spin_button) }
      end

      minutes_spinbutton.signal_connect('input') { carry_minutes }
      seconds_spinbutton.signal_connect('input') { carry_seconds }
    end
  end

  # Upstream's `duration_changed` signal, which the panel and the dialog use
  # to decide whether their start button is sensitive.
  def on_duration_changed(&block)
    @duration_listeners << block
    self
  end

  # Upstream's `start_timer` signal, emitted by the quick-start action.
  def on_start_timer(&block)
    @start_listeners << block
    self
  end

  # Upstream's get_duration: the total in seconds, with a half-typed negative
  # number treated as zero.
  def duration
    [hours_spinbutton, minutes_spinbutton, seconds_spinbutton]
      .map { |spin_button| [0, spin_button.text.to_i].max }
      .then { |hours, minutes, seconds| (hours * 3600) + (minutes * 60) + seconds }
  end

  def timer = TimerItem.from_seconds(duration, title_entry.text)

  # Memoized widget methods

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.hexpand = true
      clamp.vexpand = true
      clamp.valign = :center
      clamp.margin_start = 12
      clamp.margin_end = 12
      clamp.maximum_size = 336
      clamp.tightening_threshold = 336
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 18)

  def quick_start_box
    @quick_start_box ||= Adwaita::WrapBox.new.tap do |wrap|
      wrap.halign = :center
      wrap.valign = :start
      wrap.line_spacing = 12
      wrap.child_spacing = 12
      wrap.line_homogeneous = true
      wrap.align = 0.5
      wrap.margin_bottom = 12
    end
  end

  # One button per quick-start value. Each activates the action group's
  # start-timer action with its own number of minutes, exactly as the
  # action-target in data/ui/timer-setup.ui does.
  def quick_start_buttons
    @quick_start_buttons ||= QUICK_START.map do |minutes, label, accessible_name|
      Gtk::Button.new.tap do |button|
        button.action_name = 'timer-setup.start-timer'
        button.action_target_value = GLib::Variant.new(minutes, GLib::VariantType.new('i'))
        button.tooltip_text = accessible_name
        button.child = Gtk::Label.new(label)
      end
    end
  end

  def quick_start_size_group = @quick_start_size_group ||= Gtk::SizeGroup.new(:both)

  def time_box = @time_box ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.margin_bottom = 12 }

  # Upstream forces the grid left-to-right so hours stay leftmost.
  def time_grid
    @time_grid ||= Gtk::Grid.new.tap do |grid|
      grid.halign = :center
      grid.valign = :center
      grid.column_spacing = 6
      grid.direction = :ltr
    end
  end

  def hours_spinbutton = @hours_spinbutton ||= spin_button(99, 'Hours')
  def minutes_spinbutton = @minutes_spinbutton ||= spin_button(59, 'Minutes')
  def seconds_spinbutton = @seconds_spinbutton ||= spin_button(59, 'Seconds')

  def separator_label = @separator_label ||= timer_separator
  def second_separator_label = @second_separator_label ||= timer_separator

  def title_clamp = @title_clamp ||= Adwaita::Clamp.new.tap { |clamp| clamp.maximum_size = 302 }

  def title_entry
    @title_entry ||= Gtk::Entry.new.tap { |entry| entry.placeholder_text = 'Title' }
  end

  def action_group
    @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(start_timer_action)
    end
  end

  # Upstream's start-timer action: its parameter is a number of minutes, which
  # it spreads over the hour and minute fields before starting the timer.
  def start_timer_action
    @start_timer_action ||= Gio::SimpleAction.new('start-timer', GLib::VariantType.new('i')).tap do |action|
      action.signal_connect('activate') do |_action, parameter|
        # The Ruby binding hands a simple-typed ('i') action parameter back
        # already unboxed to a plain Integer, not the GLib::Variant upstream's
        # Vala sees.
        parameter.then do |total_minutes|
          hours_spinbutton.value = total_minutes / 60
          minutes_spinbutton.value = total_minutes - ((total_minutes / 60) * 60)
          seconds_spinbutton.value = 0
        end
        @start_listeners.each(&:call)
      end
    end
  end

  private

    def section_label(text)
      Gtk::Label.new(text).tap { |label| label.add_css_class('title-4') }
    end

    def timer_separator
      Gtk::Label.new(Utils::RATIO).tap { |label| label.add_css_class('clocks-timer-label') }
    end

    def spin_button(upper, tooltip)
      Gtk::SpinButton.new(Gtk::Adjustment.new(0, 0, upper, 1, 10, 0), 1, 0).tap do |spin_button|
        spin_button.width_chars = 2
        spin_button.text = '0'
        spin_button.xalign = 0.5
        spin_button.orientation = :vertical
        spin_button.numeric = true
        spin_button.tooltip_text = tooltip
        spin_button.wrap = true
        spin_button.add_css_class('clocks-spinbutton')
      end
    end

    # Upstream listens on `changed` rather than `value-changed` so a typed
    # duration enables the start button straight away, and ignores the empty
    # first `changed` that Gtk.Editable's own set_value emits while the field
    # is unfocused.
    def update_duration(spin_button)
      if spin_button.delegate.has_focus? || !spin_button.text.empty?
        @duration_listeners.each { |listener| listener.call(duration) }
      end
    end

    def show_leading_zeros(spin_button)
      spin_button.text = format('%02i', spin_button.value_as_int)
      true
    end

    # Upstream's input_minutes: minutes over 59 carry the whole hours into the
    # hour field, which saturates at 99.
    def carry_minutes
      minutes_spinbutton.text.to_i.then do |entered|
        if entered > 59
          hours_spinbutton.value = [99, hours_spinbutton.value_as_int + (entered / 60)].min
        end
        [1, (entered % 60).to_f]
      end
    end

    # Upstream's input_seconds: seconds over 59 carry into minutes, and
    # minutes over 59 carry on into hours.
    def carry_seconds
      seconds_spinbutton.text.to_i.then do |entered|
        carry_seconds_into_minutes(entered) if entered > 59
        [1, (entered % 60).to_f]
      end
    end

    def carry_seconds_into_minutes(entered)
      (minutes_spinbutton.value_as_int + (entered / 60)).then do |new_minutes|
        if new_minutes > 59
          hours_spinbutton.value = [99, hours_spinbutton.value_as_int + (new_minutes / 60)].min
          minutes_spinbutton.value = new_minutes % 60
        else
          minutes_spinbutton.value = new_minutes
        end
      end
    end
end
