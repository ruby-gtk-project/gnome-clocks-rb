# frozen_string_literal: true

require 'adwaita'
require 'libgweather'
require_relative 'world_location_dialog_row'

# WorldLocationDialog is the Add World Clock dialog: a search field over the
# GWeather location tree, a list of matches, and the Add button that is only
# live once one of them is picked.
#
# Ported from Clocks.World.LocationDialog in src/world-location-dialog.vala
# and data/ui/world-location-dialog.ui. Upstream keeps the matches in a
# Gtk.ListStore of a private ClockLocation wrapper and binds the listbox to
# it; this port rebuilds the rows itself, for the reason this port's other
# panels keep their own lists instead of GTK models (see widgets.rb).
#
class WorldLocationDialog < Adwaita::Dialog
  RESULT_COUNT_LIMIT = 12

  def initialize(location_exists:)
    super()
    self.title = 'Add World Clock'
    self.content_width = 400
    self.content_height = 540
    @location_exists = location_exists
    @rows = []
    @selected_row = nil
  end

  def selected_location = @selected_row&.location

  def build
    tap do |dialog|
      dialog.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.add_top_bar(search_bar)
        view.content = stack

        header_bar.tap do |bar|
          bar.pack_start(cancel_button)
          bar.pack_end(add_button)
        end

        search_bar.child = location_entry

        stack.tap do |st|
          st.add_child(empty_search)
          st.add_child(no_search_results)
          st.add_child(search_results)
        end

        search_results.add(results_group)
        results_group.add(listbox)
      end

      cancel_button.signal_connect('clicked') { close }
      add_button.signal_connect('clicked') { @on_add&.call }
      location_entry.signal_connect('search-changed') { search_changed }
      listbox.signal_connect('row-activated') { |_box, row| row_activated(row) }

      self.focus_widget = location_entry
      add_button.sensitive = false
      stack.visible_child = empty_search
    end
  end

  def on_add(&block)
    @on_add = block
    self
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_end_title_buttons = false
      bar.show_start_title_buttons = false
    end
  end

  def cancel_button
    @cancel_button ||= Gtk::Button.new(label: '_Cancel').tap do |button|
      button.use_underline = true
      button.valign = :center
    end
  end

  def add_button
    @add_button ||= Gtk::Button.new(label: '_Add').tap do |button|
      button.use_underline = true
      button.valign = :center
      button.add_css_class('suggested-action')
    end
  end

  def search_bar
    @search_bar ||= Gtk::SearchBar.new.tap do |bar|
      bar.search_mode_enabled = true
      bar.receives_default = true
    end
  end

  def location_entry
    @location_entry ||= Gtk::SearchEntry.new.tap do |entry|
      entry.placeholder_text = 'Search cities'
    end
  end

  def stack = @stack ||= Gtk::Stack.new

  def empty_search
    @empty_search ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'edit-find-symbolic'
      page.title = 'Perform a Search'
      page.description = 'The search results will appear here'
    end
  end

  def no_search_results
    @no_search_results ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = 'edit-find-symbolic'
      page.title = 'No Results Found'
      page.description = 'Try a different search'
    end
  end

  def search_results = @search_results ||= Adwaita::PreferencesPage.new
  def results_group = @results_group ||= Adwaita::PreferencesGroup.new

  def listbox
    @listbox ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :none
      list.add_css_class('boxed-list')
    end
  end

  private

    def search_changed
      self.selected_row = nil
      listbox.remove_all
      @rows = []

      query = location_entry.text.to_s.strip
      if query.empty?
        stack.visible_child = empty_search
        return
      end

      matches = walk_locations(query.downcase)
      if matches.empty?
        stack.visible_child = no_search_results
        return
      end

      matches.sort_by { |location| location.sort_name.to_s }.each { |location| append_row(location) }
      stack.visible_child = search_results
    end

    # Guards the recursive walk below against a binding-level use-after-free:
    # GWeather::Location#next_child hands back a borrowed (transfer-none)
    # child of the location it is called on, and the Ruby binding does not
    # keep that child's underlying C struct alive on its own — nothing marks
    # it as still reachable from the GWeather side between one `next_child`
    # call and the next. A GC that runs mid-walk can collect the Ruby wrapper
    # for a node this method is still about to call `next_child` on again,
    # which frees memory GWeather itself still owns; the next access through
    # it is then a stale read into freed memory. That corruption is exactly
    # as likely to come back a wrong Ruby class (observed: an Array in place
    # of a GWeather::Location, raising a bogus NoMethodError) as to crash the
    # process outright with a segfault — both were reproduced driving this
    # dialog, and neither reproduces with GC held off for the walk's short
    # duration (results = {RESULT_COUNT_LIMIT} nodes at most). Disabling GC
    # changes no observable behaviour; it only keeps every node this method
    # touches alive for as long as the walk needs it to be.
    def walk_locations(search)
      gc_was_already_disabled = GC.disable
      matching_locations(GWeather::Location.world, search)
    ensure
      unless gc_was_already_disabled
        GC.enable
      end
    end

    def matching_locations(location, search, results = [])
      return results if results.length >= RESULT_COUNT_LIMIT

      if location.level == GWeather::LocationLevel::CITY
        name_matches = location.sort_name.to_s.include?(search) || location.english_sort_name.to_s.include?(search)
        country_matches = location.country_name.to_s.downcase.include?(search)
        results << location if name_matches || country_matches
        return results
      elsif location.level == GWeather::LocationLevel::NAMED_TIMEZONE
        results << location if location.sort_name.to_s.include?(search)
        return results
      end

      child = location.next_child(nil)
      while child && results.length < RESULT_COUNT_LIMIT
        matching_locations(child, search, results)
        child = location.next_child(child)
      end
      results
    end

    def append_row(location)
      WorldLocationDialogRow.new(location, selected: @location_exists.call(location)).tap do |row|
        row.build
        @rows << row
        listbox.append(row)
      end
    end

    def row_activated(row)
      @selected_row.selected = false if @selected_row && @selected_row != row
      row.selected = !row.selected
      self.selected_row = row.selected ? row : nil
    end

    def selected_row=(row)
      @selected_row = row
      add_button.sensitive = !row.nil?
    end
end
