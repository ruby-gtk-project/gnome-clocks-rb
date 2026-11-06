# frozen_string_literal: true

require 'adwaita'
require_relative 'world_item'

# WorldStandalone is the subpage a world clock opens into when its row is
# activated: the big clock face, the day it falls on and its sunrise and
# sunset times.
#
# Ported from Clocks.World.Standalone in src/world-standalone.vala and
# data/ui/world-standalone.ui. Upstream swaps between two sizes of the clock
# label with an Adw.Breakpoint at 400sp; this port keeps the same stack and
# breakpoint.
#
class WorldStandalone < Adwaita::BreakpointBin
  def initialize(item)
    super()
    @item = item
    self.width_request = 360
    self.height_request = 294
  end

  attr_reader :item

  def build
    tap do |standalone|
      standalone.add_breakpoint(narrow_breakpoint)
      standalone.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = content_box
      end

      header_bar.title_widget = window_title

      content_box.tap do |box|
        box.append(clock_grid)
        box.append(sun_grid)

        clock_grid.tap do |grid|
          grid.attach(dummy_label, 0, 1, 1, 1)
          grid.attach(time_stack, 0, 0, 1, 1)
          grid.attach(day_label, 0, 2, 1, 1)

          time_stack.tap do |st|
            st.add_child(time_label)
            st.add_child(time_label_small)
          end
        end

        sun_grid.tap do |grid|
          grid.attach(sunrise_caption, 0, 0, 1, 1)
          grid.attach(sunset_caption, 0, 1, 1, 1)
          grid.attach(sunrise_label, 1, 0, 1, 1)
          grid.attach(sunset_label, 1, 1, 1, 1)
        end
      end

      @item.on_tick { sync }
      sync
    end
  end

  def sync
    window_title.title = @item.state_name ? "#{@item.city_name}, #{@item.state_name}" : @item.city_name
    window_title.subtitle = @item.country_name.to_s
    time_label.label = @item.time_label_seconds
    time_label_small.label = @item.time_label_seconds
    day_label.label = @item.day_label.to_s
    sunrise_label.label = @item.sunrise_label
    sunset_label.label = @item.sunset_label
    self
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def window_title = @window_title ||= Adwaita::WindowTitle.new('Clocks', '')

  # Upstream's Adw.Breakpoint setter swaps `stack`'s visible-child property
  # to an object value, which the Ruby bindings cannot box for add_setter
  # (it asserts on anything but a primitive), so the same swap happens by
  # hand on the breakpoint's own apply/unapply signals instead.
  def narrow_breakpoint
    @narrow_breakpoint ||= Adwaita::Breakpoint.new(
      Adwaita::BreakpointCondition.parse('max-width: 400sp'),
    ).tap do |breakpoint|
      breakpoint.signal_connect('apply') { time_stack.visible_child = time_label_small }
      breakpoint.signal_connect('unapply') { time_stack.visible_child = time_label }
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

  def clock_grid
    @clock_grid ||= Gtk::Grid.new.tap do |grid|
      grid.halign = :center
      grid.valign = :center
      grid.margin_start = 12
      grid.margin_end = 12
      grid.hexpand = true
      grid.vexpand = true
    end
  end

  def dummy_label = @dummy_label ||= Gtk::Label.new('  ')

  def time_stack
    @time_stack ||= Gtk::Stack.new.tap do |stack|
      stack.hhomogeneous = false
      stack.vhomogeneous = false
    end
  end

  def time_label
    @time_label ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.wrap = true
      label.add_css_class('clocks-standalone-label')
      label.add_css_class('numeric')
    end
  end

  def time_label_small
    @time_label_small ||= Gtk::Label.new.tap do |label|
      label.justify = :center
      label.wrap = true
      label.add_css_class('clocks-standalone-label-small')
      label.add_css_class('numeric')
    end
  end

  def day_label = @day_label ||= Gtk::Label.new.tap { |label| label.add_css_class('clocks-secondary-standalone-label') }

  def sun_grid
    @sun_grid ||= Gtk::Grid.new.tap do |grid|
      grid.halign = :center
      grid.margin_bottom = 12
      grid.column_spacing = 12
      grid.add_css_class('clocks-secondary-standalone-label')
    end
  end

  def sunrise_caption = @sunrise_caption ||= Gtk::Label.new('Sunrise').tap { |label| label.add_css_class('dimmed') }
  def sunset_caption = @sunset_caption ||= Gtk::Label.new('Sunset').tap { |label| label.add_css_class('dimmed') }
  def sunrise_label = @sunrise_label ||= Gtk::Label.new.tap { |label| label.add_css_class('numeric') }
  def sunset_label = @sunset_label ||= Gtk::Label.new.tap { |label| label.add_css_class('numeric') }
end
