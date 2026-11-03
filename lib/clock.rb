# frozen_string_literal: true

require 'adwaita'

# PanelId names the four panels the window switches between, in the order
# upstream lists them.
#
# Ported from Clocks.PanelId in src/clock.vala. The GSettings nicks in
# data/org.gnome.clocks.gschema.xml.in are the same strings the view stack
# pages are named after, which is how the window restores its panel.
#
module PanelId
  WORLD = :world
  ALARM = :alarm
  STOPWATCH = :stopwatch
  TIMER = :timer

  ALL = [WORLD, ALARM, STOPWATCH, TIMER].freeze

  def self.index(panel_id) = ALL.index(panel_id)
  def self.from_index(index) = ALL[index]

  # Upstream's navigate-forward and navigate-backward walk the panels in a
  # loop, so the list wraps at both ends.
  def self.after(panel_id) = ALL[(ALL.index(panel_id) + 1) % ALL.length]
  def self.before(panel_id) = ALL[(ALL.index(panel_id) - 1) % ALL.length]
end

# ButtonMode says whether the header bar shows its "new" button for the
# panel on screen.
#
# Ported from Clocks.ButtonMode in src/header-bar.vala.
module ButtonMode
  NEW = :new
  NONE = :none
end

# Clock is what every panel implements so the window can drive it without
# knowing which panel it has: the panel's id, whether the header bar offers a
# "new" button and what that button's tooltip says, what the button does, and
# what Escape does.
#
# Ported from the Clocks.Clock interface in src/clock.vala. Upstream's window
# binds the header bar to the panel's `button-mode` and `new-label` properties
# with GObject property bindings; a Ruby module cannot add GObject properties
# to a widget class, so a panel reports a change through #button_mode= and the
# window subscribes with #on_button_mode_changed.
#
module Clock
  def panel_id = raise(NotImplementedError, "#{self.class} must name its panel")

  def button_mode = @button_mode ||= ButtonMode::NONE

  def button_mode=(mode)
    unless mode == button_mode
      @button_mode = mode
      button_mode_listeners.each { |listener| listener.call(mode) }
    end
  end

  def on_button_mode_changed(&block)
    button_mode_listeners << block
    block.call(button_mode)
    self
  end

  # The tooltip on the header bar's "new" button. A panel with nothing to add
  # has no label, which is upstream's default of null.
  def new_label = nil

  # Upstream's Clock.activate_new: what win.new does on this panel. The
  # interface's default does nothing, and so does this one.
  def activate_new = self

  # Upstream's Clock.escape_pressed: true when the panel consumed Escape, so
  # the window knows not to pop its navigation view.
  def escape_pressed = false

  private

    def button_mode_listeners = @button_mode_listeners ||= []
end
