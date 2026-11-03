# frozen_string_literal: true

require 'adwaita'
require_relative 'timer_setup'

# TimerSetupDialog is the New Timer dialog: a setup pane with a start button
# under it.
#
# Ported from Clocks.Timer.SetupDialog in src/timer-setup-dialog.vala and
# data/ui/timer-setup-dialog.ui. Upstream prepends the setup pane to the box
# the start button already sits in, which is why the button comes first here
# too and the pane lands above it.
#
class TimerSetupDialog < Adwaita::Dialog
  def initialize
    super()
    self.title = 'New Timer'
  end

  def timer_setup = @timer_setup ||= TimerSetup.new

  def build
    tap do |dialog|
      dialog.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scroller
      end

      scroller.child = content_box

      content_box.tap do |box|
        box.append(start_button)
        box.prepend(timer_setup.build)

        start_button.signal_connect('clicked') { done }
      end

      timer_setup.tap do |setup|
        setup.on_duration_changed { |duration| start_button.sensitive = !duration.zero? }
        setup.on_start_timer { done }
      end

      start_button.sensitive = !timer_setup.duration.zero?
    end
  end

  # Upstream's `done` signal: the panel creates the timer and closes the
  # dialog when it fires.
  def on_done(&block)
    @on_done = block
    self
  end

  def done
    @on_done&.call(self)
    self
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.show_title = false }
  end

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.hscrollbar_policy = :never
      sw.propagate_natural_height = true
      sw.propagate_natural_width = true
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

  def start_button
    @start_button ||= Gtk::Button.new(label: 'Start').tap do |button|
      button.halign = :center
      button.valign = :center
      button.margin_top = 26
      button.margin_bottom = 30
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
    end
  end
end
