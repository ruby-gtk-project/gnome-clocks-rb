# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'
require_relative 'utils'
require_relative 'widgets'
require_relative 'stopwatch_lap'
require_relative 'stopwatch_laps_row'

# StopwatchFace is the Stopwatch panel: the running time, the lap list, and
# the two buttons whose labels change with the state.
#
# Ported from Clocks.Stopwatch.Face in src/stopwatch-face.vala and
# data/ui/stopwatch-face.ui.
#
class StopwatchFace < Gtk::Box
  include Clock

  RESET = :reset
  RUNNING = :running
  STOPPED = :stopped

  def initialize
    super(:vertical, 0)
    add_css_class('stopwatch-panel')
    @state = RESET
    @laps = ContentStore.new
    @timer = GLib::Timer.new
    @tick_id = nil
    @current_lap = 0
    @stored = [nil, nil, nil, nil]
    @state_listeners = []
  end

  attr_reader :state, :laps

  def panel_id = PanelId::STOPWATCH

  # Upstream's Face has button_mode NONE and no new-label: the header bar
  # offers nothing to add on this panel.
  def new_label = nil

  def build
    tap do |face|
      face.append(toolbar_view)

      toolbar_view.tap do |view|
        view.content = scroller
        view.add_bottom_bar(buttons_clamp)
      end

      scroller.child = container

      container.tap do |box|
        box.append(time_container)
        box.append(laps_revealer)

        time_container.tap do |times|
          times.append(hours_label)
          times.append(Gtk::Label.new(Utils::RATIO).tap { |label| label.valign = :baseline_fill })
          times.append(minutes_label)
          times.append(Gtk::Label.new(Utils::RATIO).tap { |label| label.valign = :baseline_fill })
          times.append(seconds_label)
          times.append(Gtk::Label.new('.').tap { |label| label.valign = :baseline_fill })
          times.append(milliseconds_label)
        end

        laps_revealer.child = laps_clamp
        laps_clamp.child = laps_list
      end

      buttons_clamp.child = buttons_box

      buttons_box.tap do |box|
        box.append(start_button)
        box.append(clear_button)

        start_button.signal_connect('clicked') { on_start_clicked }
        clear_button.signal_connect('clicked') { on_clear_clicked }
      end

      laps.on_items_changed { refresh_laps }

      # Upstream drives the time label from a frame clock tick callback while
      # the panel is on screen, and takes it down again when it is not.
      face.signal_connect('map') do
        if @state == RUNNING
          update_time_label
          add_tick
        end
      end
      face.signal_connect('unmap') { remove_tick if @state == RUNNING }

      reset
    end
  end

  # Upstream's window watches the panel's `state` property to put the
  # needs-attention dot on the stopwatch page while it runs.
  def on_state_changed(&block)
    @state_listeners << block
    self
  end

  # Upstream's grab_focus override: the start button takes the focus whenever
  # the panel does.
  def grab_focus_start = start_button.grab_focus

  # Upstream's escape_pressed: Escape pauses a running stopwatch and clears a
  # paused one, and is left for the window to handle when there is nothing to
  # stop.
  def escape_pressed
    case @state
    when RESET then false
    when STOPPED then reset.then { true }
    else stop.then { true }
    end
  end

  def start
    @state == RESET ? @timer.start : @timer.continue
    self.state = RUNNING
    add_tick

    start_button.tap do |button|
      button.label = '_Pause'
      button.remove_css_class('suggested-action')
    end

    clear_button.tap do |button|
      button.sensitive = true
      button.label = '_Lap'
      button.remove_css_class('destructive-action')
    end

    restyle_time('running-stopwatch')
    self
  end

  def stop
    @timer.stop
    self.state = STOPPED
    remove_tick

    start_button.tap do |button|
      button.label = 'R_esume'
      button.remove_css_class('destructive-action')
      button.add_css_class('suggested-action')
    end

    clear_button.tap do |button|
      button.sensitive = true
      button.label = '_Clear'
      button.add_css_class('destructive-action')
    end

    restyle_time('paused-stopwatch')
    self
  end

  def reset
    laps_revealer.reveal_child = false
    @timer.reset
    self.state = RESET
    remove_tick
    update_time_label
    @current_lap = 0

    start_button.tap do |button|
      button.label = 'St_art'
      button.add_css_class('suggested-action')
    end

    clear_button.tap do |button|
      button.sensitive = false
      button.label = '_Lap'
      button.remove_css_class('destructive-action')
    end

    restyle_time('stopped-stopwatch')
    laps.remove_all
    self
  end

  # Upstream's lap(): the newest lap goes in at the front, and its duration is
  # the elapsed time minus every lap already recorded.
  def lap
    @current_lap += 1
    laps_revealer.reveal_child = @current_lap >= 1
    laps.insert(0, StopwatchLap.new(@current_lap, elapsed - total_laps_duration))
  end

  def total_laps_duration = laps.sum(&:duration)

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.hscrollbar_policy = :never
      sw.min_content_width = 300
      sw.vexpand = true
    end
  end

  def container
    @container ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.margin_top = 18
      box.margin_bottom = 18
      box.valign = :center
    end
  end

  # Upstream forces this box left-to-right so the hours never swap sides with
  # the hundredths.
  def time_container
    @time_container ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.halign = :center
      box.margin_top = 18
      box.margin_bottom = 18
      box.direction = :ltr
      box.add_css_class('stopped-stopwatch')
    end
  end

  def hours_label = @hours_label ||= time_label('00', %w[numeric hours-label dimmed])
  def minutes_label = @minutes_label ||= time_label('00', %w[numeric minutes-label dimmed])
  def seconds_label = @seconds_label ||= time_label('00', %w[numeric seconds-label])
  def milliseconds_label = @milliseconds_label ||= time_label('0', %w[milliseconds-label numeric])

  def laps_revealer
    @laps_revealer ||= Gtk::Revealer.new.tap { |revealer| revealer.transition_type = :crossfade }
  end

  def laps_clamp = @laps_clamp ||= Adwaita::Clamp.new.tap { |clamp| clamp.maximum_size = 380 }

  def laps_list
    @laps_list ||= Gtk::ListBox.new.tap do |list|
      list.margin_start = 12
      list.margin_end = 12
      list.selection_mode = :none
      list.valign = :start
      list.add_css_class('boxed-list')
    end
  end

  def buttons_clamp = @buttons_clamp ||= Adwaita::Clamp.new.tap { |clamp| clamp.maximum_size = 380 }

  def buttons_box
    @buttons_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.margin_top = 6
      box.margin_bottom = 6
      box.margin_start = 18
      box.margin_end = 18
    end
  end

  def start_button
    @start_button ||= Gtk::Button.new(label: 'St_art').tap do |button|
      button.use_underline = true
      button.halign = :start
      button.hexpand = true
      button.width_request = 120
      button.add_css_class('large-button')
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
    end
  end

  def clear_button
    @clear_button ||= Gtk::Button.new(label: '_Clear').tap do |button|
      button.use_underline = true
      button.halign = :end
      button.width_request = 120
      button.add_css_class('large-button')
      button.add_css_class('pill')
    end
  end

  private

    def time_label(text, classes)
      Gtk::Label.new(text).tap do |label|
        label.valign = :baseline_fill
        classes.each { |css_class| label.add_css_class(css_class) }
      end
    end

    def state=(value)
      unless value == @state
        @state = value
        @state_listeners.each { |listener| listener.call(value) }
      end
    end

    # The Ruby binding hands GLib::Timer#elapsed back as [seconds, microseconds].
    def elapsed = Array(@timer.elapsed).first

    def on_start_clicked
      case @state
      when RESET, STOPPED then start
      else stop
      end
    end

    def on_clear_clicked
      case @state
      when STOPPED
        start_button.grab_focus
        reset
      when RUNNING
        lap
      end
    end

    # One class at a time, the way upstream swaps them, so the stylesheet's
    # three stopwatch states stay mutually exclusive.
    def restyle_time(active)
      %w[stopped-stopwatch running-stopwatch paused-stopwatch].each do |css_class|
        css_class == active ? time_container.add_css_class(css_class) : time_container.remove_css_class(css_class)
      end
    end

    def add_tick
      @tick_id ||= add_tick_callback { update_time_label.then { true } }
    end

    def remove_tick
      @tick_id.then do |id|
        if id
          remove_tick_callback(id)
          @tick_id = nil
        end
      end
    end

    # Upstream writes each field only when it changed, so a tick that moves
    # nothing but the hundredths does not touch the other three labels.
    def update_time_label
      (@state == RESET ? [0, 0, 0, 0.0] : Utils.time_to_hms(elapsed)).then do |hours, minutes, seconds, remainder|
        [
          [hours, hours_label, "%02i#{Utils::LTR_MARK}"],
          [minutes, minutes_label, "%02i#{Utils::LTR_MARK}"],
          [seconds, seconds_label, '%02i'],
          [(remainder * 10).to_i, milliseconds_label, '%i'],
        ].each_with_index do |(value, label, template), index|
          unless @stored[index] == value
            label.label = format(template, value)
            @stored[index] = value
          end
        end
      end
      self
    end

    # Upstream's bound model rebuilds the row for the newest lap with the lap
    # before it in hand; the rows are rebuilt here for the same reason — a
    # row's difference label depends on its neighbour.
    def refresh_laps
      laps_list.remove_all
      laps.each_with_index do |item, index|
        laps_list.append(StopwatchLapsRow.new(item, laps.get_item(index + 1)).build)
      end
      container.valign = laps.n_items.zero? ? :center : :fill
    end
end
