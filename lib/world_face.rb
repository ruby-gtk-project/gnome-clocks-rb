# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'
require_relative 'settings'
require_relative 'utils'
require_relative 'widgets'
require_relative 'world_item'
require_relative 'world_row'
require_relative 'world_location_dialog'

# WorldFace is the World panel: the empty state while there are no clocks,
# and the sorted list of clocks once there are, each one ticking on the
# shared wall clock.
#
# Ported from Clocks.World.Face in src/world-face.vala and
# data/ui/world-face.ui.
#
# Upstream sorts its Gtk.ListBox with a Gtk.SortListModel keyed on each
# location's UTC offset; this port sorts its own store the same way and
# rebuilds the rows, for the reason TimerFace's class comment documents.
#
# Upstream also seeds the list with an automatic, geolocated entry through
# Geo.Info, which wraps GeoClue2. Neither GeoClue2 nor the XDG location
# portal has a Ruby binding available to this port (ashpd 0.1.1 ships no
# Location portal), so that seeding is left out; every clock here is one the
# person added by hand.
#
class WorldFace < Adwaita::Bin
  include Clock

  def initialize(settings: nil)
    super()
    @settings = settings || Settings.new
    @locations = ContentStore.new
  end

  attr_reader :locations

  def panel_id = PanelId::WORLD

  # Translators: Tooltip for the + button
  def new_label = 'Add Location'

  def build
    tap do |face|
      face.child = stack

      stack.tap do |view_stack|
        view_stack.hhomogeneous = false
        view_stack.vhomogeneous = false
        view_stack.add_named(empty_view, 'empty')
        view_stack.add_named(list_view, 'list')
      end

      empty_view.child = add_button
      list_view.child = clamp
      clamp.child = listbox

      add_button.signal_connect('clicked') { activate_new }
      listbox.signal_connect('row-activated') { |_box, row| show_standalone(row.item) }

      @locations.on_items_changed do
        save
        refresh_rows
      end

      load
      refresh_rows

      Utils::WallClock.default.on_tick { @locations.each(&:tick) }
    end
  end

  # Upstream's `show-standalone` signal; the window connects to this to push
  # the subpage for the activated clock.
  def on_show_standalone(&block)
    @on_show_standalone = block
    self
  end

  def show_standalone(item)
    @on_show_standalone&.call(item)
    self
  end

  # Upstream's grab_focus override: with no clocks, the focus goes to the
  # add button under the empty view, the same way the other panels send
  # focus to their own call to action.
  def grab_focus_start = @locations.n_items.zero? && add_button.grab_focus

  def location_exists?(location)
    @locations.any? { |item| same_place?(item.location, location) }
  end

  def add_location(location)
    unless location_exists?(location)
      @locations.add(WorldItem.new(location))
      resort
    end
    self
  end

  def activate_new
    WorldLocationDialog.new(location_exists: ->(location) { location_exists?(location) }).tap do |dialog|
      dialog.build
      dialog.on_add do
        add_location(dialog.selected_location) if dialog.selected_location
        dialog.close
      end
      dialog.present(self)
    end
  end

  # Memoized widget methods

  def stack = @stack ||= Adwaita::ViewStack.new

  def empty_view
    @empty_view ||= Adwaita::StatusPage.new.tap { |page| page.icon_name = 'globe-centered-symbolic' }
  end

  def add_button
    @add_button ||= Gtk::Button.new(label: '_Add World Clock…').tap do |button|
      button.use_underline = true
      button.can_shrink = true
      button.halign = :center
      button.add_css_class('suggested-action')
      button.add_css_class('pill')
    end
  end

  def list_view = @list_view ||= Gtk::ScrolledWindow.new
  def clamp = @clamp ||= Adwaita::Clamp.new

  def listbox
    @listbox ||= Gtk::ListBox.new.tap do |list|
      list.valign = :start
      list.selection_mode = :none
      list.margin_top = 18
      list.margin_bottom = 18
      list.margin_start = 12
      list.margin_end = 12
      list.add_css_class('boxed-list')
    end
  end

  private

    def same_place?(first, second)
      first.equal?(second) || (first.coords == second.coords && first.name.to_s == second.name.to_s)
    end

    def load
      @locations.deserialize(@settings.world_clocks) { |values| WorldItem.deserialize(values) }
      resort
    end

    def save = @settings.world_clocks = @locations.serialize

    # Upstream's Gtk.CustomSorter, keyed on each location's current UTC
    # offset from the shared wall clock's timestamp.
    def resort = @locations.sort_items! { |first, second| first.local_offset <=> second.local_offset }

    def refresh_rows
      stack.visible_child_name = @locations.n_items.positive? ? 'list' : 'empty'
      self.button_mode = ButtonMode::NEW
      listbox.remove_all
      @locations.each do |item|
        listbox.append(
          WorldRow.new(item).tap do |row|
            row.build
            row.on_remove { @locations.remove(item) }
          end,
        )
      end
      self
    end
end
